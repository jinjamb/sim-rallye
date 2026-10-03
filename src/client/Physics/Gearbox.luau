--!strict
--[[
	Gearbox.luau
	Boîte séquentielle 6 rapports + marche arrière, avec le pont (transaxle).

	Elle ne connaît ni le couple ni l'embrayage : elle dit seulement quel rapport
	est engagé, si un passage est en cours (coupure de couple) et, en mode
	automatique, quand changer. Tout le reste vit dans Powertrain.luau.

	Rapports : -1 = marche arrière, 0 = point mort, 1..6 = marche avant.
	Toutes les vitesses passées en argument sont des vitesses AU SOL, en studs/s,
	signées (positives vers l'avant du châssis).
]]

local Gearbox = {}
Gearbox.__index = Gearbox

export type Gearbox = typeof(setmetatable({}, Gearbox)) & {
	Ratios: { number },
	ReverseRatio: number,
	FinalDrive: number,
	LimiterRPM: number,
	WheelRadius: number,

	Gear: number,
	Automatic: boolean,
	ShiftTimer: number, -- > 0 : passage en cours, couple coupé
	CooldownTimer: number, -- > 0 : la boîte auto attend avant de redécider
}

--[[
	ÉTAGEMENT.
	Le 1er rapport est calé pour ~1.1 g de poussée au couple max : nettement plus
	que ce que les pneus peuvent passer sur terre (mu 0.72), à peu près la limite
	sur asphalte. Le 6e place la vitesse de pointe, limitée par la traînée
	(~123 studs/s), vers 6300 tr/min, juste après le pic de puissance.
	Entre les deux, les écarts se resserrent en montant, comme sur une boîte de
	rallye : gros trou 1-2 pour le départ, rapports serrés là où on reste en régime.

	Vitesse au rupteur (8000 tr/min, roue de 1 stud) :
		1re 46 | 2e 64 | 3e 83 | 4e 105 | 5e 129 | 6e 157 studs/s
]]
local GEAR_RATIOS = { 4.40, 3.20, 2.45, 1.95, 1.58, 1.30 }
local REVERSE_RATIO = 3.80
local FINAL_DRIVE = 4.1

--[[
	Durées de passage : couple coupé pendant ce temps. Une séquentielle de rallye
	passe en un éclair à la montée (coupure d'allumage, pas d'embrayage) ; la
	descente est un peu plus lente (coup de gaz de synchronisation).
]]
local UPSHIFT_TIME = 0.12
local DOWNSHIFT_TIME = 0.18

--[[
	LOGIQUE AUTOMATIQUE.
	Point de montée : là où la poussée du rapport suivant dépasse celle du rapport
	actuel. La courbe chute après 5500 tr/min, et avec ~1.3 d'écart entre rapports
	le croisement tombe vers 6800. Monter plus tard, c'est accélérer moins fort.

	La descente vise le bas du plateau de couple. Les deux seuils sont choisis pour
	que la boîte ne "pompe" jamais : après une montée à 6800 on retombe au-dessus
	de 4900, bien loin du seuil de descente.
]]
local UPSHIFT_RPM = 6800
local DOWNSHIFT_RPM = 3500
local DOWNSHIFT_MAX_LANDING_RPM = 6000 -- jamais de descente qui ferait arriver au-dessus
local AUTO_COOLDOWN = 0.35 -- délai minimal entre deux décisions automatiques

-- En dessous de cette vitesse (studs/s), on considère la voiture arrêtée :
-- seul cas où l'on autorise le passage marche avant <-> marche arrière.
local STANDSTILL_SPEED = 1.5

local RAD_PER_SEC_TO_RPM = 9.5492

function Gearbox.new(limiterRPM: number, wheelRadius: number): Gearbox
	local self = (setmetatable({}, Gearbox) :: any) :: Gearbox
	self.Ratios = table.clone(GEAR_RATIOS)
	self.ReverseRatio = REVERSE_RATIO
	self.FinalDrive = FINAL_DRIVE
	self.LimiterRPM = limiterRPM
	self.WheelRadius = wheelRadius

	self.Gear = 1
	self.Automatic = true
	self.ShiftTimer = 0
	self.CooldownTimer = 0
	return self
end

-- Rapport total (boîte x pont) SIGNÉ : négatif en marche arrière, 0 au point mort.
function Gearbox:GetTotalRatio(gear: number?): number
	local g = gear or self.Gear
	if g == 0 then
		return 0
	elseif g < 0 then
		return -self.ReverseRatio * self.FinalDrive
	end
	return self.Ratios[g] * self.FinalDrive
end

function Gearbox:GetTopGear(): number
	return #self.Ratios
end

function Gearbox:IsShifting(): boolean
	return self.ShiftTimer > 0
end

--[[
	Régime qu'aurait le moteur dans un rapport donné si les roues roulaient sans
	glisser, déduit de la vitesse au sol. La boîte auto décide sur cette valeur,
	et pas sur le régime réel : sinon une roue qui patine sur la glace ferait
	monter les rapports en cascade jusqu'en 6e, à l'arrêt.
]]
function Gearbox:GetGroundRPM(gear: number, groundSpeed: number): number
	return (groundSpeed / self.WheelRadius) * self:GetTotalRatio(gear) * RAD_PER_SEC_TO_RPM
end

function Gearbox:_engage(gear: number)
	if gear == self.Gear then
		return
	end
	-- Point mort -> rapport (ou l'inverse) : pas de couple à couper.
	if self.Gear ~= 0 and gear ~= 0 then
		self.ShiftTimer = if gear > self.Gear then UPSHIFT_TIME else DOWNSHIFT_TIME
	end
	self.Gear = gear
	self.CooldownTimer = AUTO_COOLDOWN
end

function Gearbox:_wouldOverRev(gear: number, groundSpeed: number): boolean
	return gear ~= 0 and math.abs(self:GetGroundRPM(gear, groundSpeed)) > self.LimiterRPM
end

--[[
	Demandes de passage (palettes, ou décisions de la boîte auto).
	Comme sur une vraie séquentielle à gestion électronique, les passages
	dangereux sont refusés plutôt que subis :
		- descente qui enverrait le moteur au-delà du rupteur ;
		- inversion du sens de marche tant que la voiture roule.
	Renvoient true si le rapport a changé.
]]
function Gearbox:ShiftUp(groundSpeed: number): boolean
	if self.Gear >= self:GetTopGear() or self:IsShifting() then
		return false
	end
	local target = self.Gear + 1
	-- R -> N : quitter la marche arrière en roulant casserait la boîte.
	if self.Gear == -1 and math.abs(groundSpeed) > STANDSTILL_SPEED then
		return false
	end
	-- N -> 1 lancé à pleine vitesse : même protection qu'à la descente.
	if self:_wouldOverRev(target, groundSpeed) then
		return false
	end
	self:_engage(target)
	return true
end

function Gearbox:ShiftDown(groundSpeed: number): boolean
	if self.Gear <= -1 or self:IsShifting() then
		return false
	end
	local target = self.Gear - 1
	-- N -> R : même garde-fou dans l'autre sens.
	if target == -1 and math.abs(groundSpeed) > STANDSTILL_SPEED then
		return false
	end
	if self:_wouldOverRev(target, groundSpeed) then
		return false
	end
	self:_engage(target)
	return true
end

function Gearbox:SetAutomatic(automatic: boolean)
	self.Automatic = automatic
	-- La boîte auto ne gère pas le point mort.
	if automatic and self.Gear == 0 then
		self:_engage(1)
	end
end

function Gearbox:Update(dt: number)
	self.ShiftTimer = math.max(0, self.ShiftTimer - dt)
	self.CooldownTimer = math.max(0, self.CooldownTimer - dt)
end

--[[
	Boîte automatique, à appeler à chaque frame en mode auto, avec les pédales
	TELLES QUE LE JOUEUR LES APPUIE (avant l'inversion faite en marche arrière).
	Marche arrière façon arcade : arrêté, frein maintenu sans gaz -> R ; en R,
	l'accélérateur repasse en 1re dès l'arrêt. Car.luau inverse les pédales en R,
	si bien qu'en reculant, l'accélérateur freine.
]]
function Gearbox:UpdateAutomatic(groundSpeed: number, throttle: number, brake: number)
	if self:IsShifting() or self.CooldownTimer > 0 then
		return
	end

	local stopped = math.abs(groundSpeed) < STANDSTILL_SPEED

	if self.Gear == -1 then
		if stopped and throttle > 0 and brake == 0 then
			self:_engage(1)
		end
		return
	end

	if stopped and brake > 0 and throttle == 0 then
		self:_engage(-1)
		return
	end

	-- Valeur absolue : une voiture qui recule en 1re (pente, tête-à-queue) doit
	-- quand même pouvoir rétrograder, pas rester bloquée sur un régime négatif.
	local rpm = math.abs(self:GetGroundRPM(self.Gear, groundSpeed))

	-- On ne monte qu'à l'accélération : lever le pied en appui garde le rapport,
	-- et donc le frein moteur. C'est ce qu'on attend en rallye.
	if throttle > 0 and rpm >= UPSHIFT_RPM and self.Gear < self:GetTopGear() then
		self:_engage(self.Gear + 1)
		return
	end

	--[[
		Descente : on saute directement au bon rapport au lieu de descendre un par
		un. Au gros freinage, la voiture perd 80 studs/s en une seconde ; avec un
		délai entre chaque passage, elle arrivait au point de corde trois rapports
		trop haut, et relançait à 1500 tr/min.
		On descend tant que le régime d'arrivée reste sous la limite, et on
		s'arrête au premier rapport qui remet le moteur dans son couple.
	]]
	if rpm < DOWNSHIFT_RPM and self.Gear > 1 then
		local target = self.Gear
		for gear = self.Gear - 1, 1, -1 do
			local landing = math.abs(self:GetGroundRPM(gear, groundSpeed))
			if landing >= DOWNSHIFT_MAX_LANDING_RPM then
				break
			end
			target = gear
			if landing >= DOWNSHIFT_RPM then
				break
			end
		end
		self:_engage(target)
	end
end

return Gearbox
