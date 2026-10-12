--!strict
--[[
	Gearbox.luau
	Boîte séquentielle + marche arrière, avec le pont (transaxle). Rapports,
	pont et régimes de passage viennent de la fiche de la catégorie
	(CarClasses.luau) ; les commentaires ci-dessous décrivent la Rally2.

	Elle ne connaît ni le couple ni l'embrayage : elle dit seulement quel rapport
	est engagé, si un passage est en cours (coupure de couple) et, en mode
	automatique, quand changer. Tout le reste vit dans Powertrain.luau.

	Rapports : -1 = marche arrière, 0 = point mort, 1..6 = marche avant.
	Toutes les vitesses passées en argument sont des vitesses AU SOL, en studs/s,
	signées (positives vers l'avant du châssis).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)

local Gearbox = {}
Gearbox.__index = Gearbox

export type Gearbox = typeof(setmetatable({}, Gearbox)) & {
	Ratios: { number },
	ReverseRatio: number,
	FinalDrive: number,
	LimiterRPM: number,
	WheelRadius: number,
	UpshiftRPM: number, -- point de montée optimal, aussi utilisé par la LED de passage
	DownshiftRPM: number, -- en dessous, la boîte auto descend
	-- Plus haut régime d'arrivée accepté pour une descente automatique.
	DownshiftMaxLandingRPM: number,

	Gear: number,
	Automatic: boolean,
	ShiftTimer: number, -- > 0 : passage en cours, couple coupé
	CooldownTimer: number, -- > 0 : la boîte auto attend avant de redécider
	PendingDownshifts: number, -- descentes demandées, en attente d'un régime sûr
	PendingTimer: number, -- temps restant avant d'oublier ces demandes
}

--[[
	ÉTAGEMENT (gravité réelle, 150 W/kg : voir Units.luau et Powertrain.luau).
	Poussée au couple max, en g : 1re 1.46 | 2e 1.06 | 3e 0.81 | 4e 0.65 | 5e 0.52 | 6e 0.43
	L'adhérence vaut 1.05 g sur asphalte, 0.72 sur terre : la 1re patine partout,
	la 2e sur asphalte est à la limite, et sur terre on patine jusqu'en 3e. C'est
	l'ordre de grandeur d'une vraie Rally2, AWD ou pas.
	Courte comme une boîte de spéciale : la pointe est limitée par le rupteur en
	6e (~180 km/h), pas par la traînée. Les écarts se resserrent en montant :
	gros trou 1-2 pour le départ, rapports serrés là où on reste en régime.

	Vitesse au rupteur (8000 tr/min, roue de 1 stud), en studs/s ~ km/h :
		1re 54 | 2e 75 | 3e 98 | 4e 123 | 5e 152 | 6e 184
]]

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
-- Une descente ne doit jamais faire arriver à moins de cet écart du rupteur.
local DOWNSHIFT_LANDING_MARGIN = 1800 -- tr/min (Rally2 : 7800 - 1800 = 6000)
local AUTO_COOLDOWN = 0.35 -- délai minimal entre deux décisions automatiques

-- En dessous de cette vitesse (studs/s), on considère la voiture arrêtée :
-- seul cas où l'on autorise le passage marche avant <-> marche arrière.
local STANDSTILL_SPEED = 1.5

--[[
	MÉMOIRE DES RÉTROGRADATIONS (boîte manuelle). Une descente refusée -- elle
	ferait dépasser le rupteur, ou un passage est déjà en cours -- n'est pas
	perdue : elle attend, et s'exécute d'elle-même dès que la vitesse le permet.
	Au gros freinage, on tape trois fois "descendre" et les trois rapports
	tombent au fil du ralentissement, chacun dès qu'il est sûr : le frein moteur
	arrive au plus tôt, sans jamais faire sur-régimer.
	Une montée annule les descentes en attente ; elles sont aussi oubliées au
	bout de DOWNSHIFT_QUEUE_TIMEOUT sans nouvel appui (on a changé d'avis).
]]
local DOWNSHIFT_QUEUE_TIMEOUT = 2.5 -- secondes

local RAD_PER_SEC_TO_RPM = 9.5492

function Gearbox.new(limiterRPM: number, wheelRadius: number, class: CarClasses.Class): Gearbox
	local self = (setmetatable({}, Gearbox) :: any) :: Gearbox
	self.Ratios = table.clone(class.GearRatios)
	self.ReverseRatio = class.ReverseRatio
	self.FinalDrive = CarSetup.Default(class.Id).FinalDrive
	self.LimiterRPM = limiterRPM
	self.WheelRadius = wheelRadius
	self.UpshiftRPM = class.UpshiftRPM
	self.DownshiftRPM = class.DownshiftRPM
	self.DownshiftMaxLandingRPM = limiterRPM - DOWNSHIFT_LANDING_MARGIN

	self.Gear = 1
	self.Automatic = true
	self.ShiftTimer = 0
	self.CooldownTimer = 0
	self.PendingDownshifts = 0
	self.PendingTimer = 0
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
	-- Monter, c'est renoncer aux descentes encore en attente.
	self.PendingDownshifts = 0
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

function Gearbox:_tryShiftDown(groundSpeed: number): boolean
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

-- Demande de descente (palette). Refusée maintenant, elle est mémorisée si elle
-- vise un rapport de marche avant (voir MÉMOIRE DES RÉTROGRADATIONS).
function Gearbox:ShiftDown(groundSpeed: number): boolean
	local queuedTarget = self.Gear - self.PendingDownshifts - 1
	if self.PendingDownshifts == 0 and self:_tryShiftDown(groundSpeed) then
		return true
	end
	if queuedTarget >= 1 then
		self.PendingDownshifts += 1
		self.PendingTimer = DOWNSHIFT_QUEUE_TIMEOUT
	end
	return false
end

-- Exécute les descentes en attente dès qu'elles sont sûres. À appeler à chaque
-- frame en boîte manuelle.
function Gearbox:ProcessPendingDownshifts(dt: number, groundSpeed: number)
	if self.PendingDownshifts <= 0 then
		return
	end
	self.PendingTimer -= dt
	if self.PendingTimer <= 0 then
		self.PendingDownshifts = 0
		return
	end
	if self:_tryShiftDown(groundSpeed) then
		self.PendingDownshifts -= 1
	end
end

function Gearbox:SetAutomatic(automatic: boolean)
	if automatic then
		self.PendingDownshifts = 0
	end
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
	if throttle > 0 and rpm >= self.UpshiftRPM and self.Gear < self:GetTopGear() then
		self:_engage(self.Gear + 1)
		return
	end

	--[[
		Descente : on saute directement au bon rapport au lieu de descendre un par
		un. Au gros freinage, la voiture perd des dizaines de studs/s par seconde ; avec un
		délai entre chaque passage, elle arrivait au point de corde trois rapports
		trop haut, et relançait à 1500 tr/min.
		On descend tant que le régime d'arrivée reste sous la limite, et on
		s'arrête au premier rapport qui remet le moteur dans son couple.
	]]
	if rpm < self.DownshiftRPM and self.Gear > 1 then
		local target = self.Gear
		for gear = self.Gear - 1, 1, -1 do
			local landing = math.abs(self:GetGroundRPM(gear, groundSpeed))
			if landing >= self.DownshiftMaxLandingRPM then
				break
			end
			target = gear
			if landing >= self.DownshiftRPM then
				break
			end
		end
		self:_engage(target)
	end
end

return Gearbox
