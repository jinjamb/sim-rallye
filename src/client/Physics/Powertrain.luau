--!strict
--[[
	Powertrain.luau
	Moteur + embrayage + boîte (Gearbox.luau). Entrée : la rotation moyenne des
	roues motrices et la pédale d'accélérateur. Sortie : le couple total à
	répartir sur les roues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Util.Units)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local GearboxClass = require(script.Parent.Gearbox)

local Powertrain = {}
Powertrain.__index = Powertrain

export type Powertrain = typeof(setmetatable({}, Powertrain)) & {
	MaxRPM: number,
	IdleRPM: number,
	LimiterRPM: number,
	LaunchRPM: number,
	WheelRadius: number,
	TorqueScale: number,
	EngineBrakeTorque: number,
	Gearbox: GearboxClass.Gearbox,

	-- État
	EngineRPM: number,
	ClutchSlipping: boolean,
	FuelCut: boolean,
	Load: number, -- 0..1 : le moteur pousse (1) ou est entraîné (0). Pilote le son.
	-- Embrayage tenu ouvert (voiture retenue sur la grille, Car.Held) : le moteur
	-- monte en régime sans entraîner les roues, plafonné au régime de départ.
	ClutchHeld: boolean,

	-- Fiche de la catégorie (CarClasses.luau)
	TorqueCurve: { CarClasses.TorquePoint },
	TurboLag: number,
	TurboShare: number,
	-- Pression du turbo (0..1) : la part TurboShare du couple la suit.
	Boost: number,
}

-- Courbe en N·m (fiche de la catégorie, CarClasses.luau), tracée comme sur un
-- banc réel. Elle n'est PAS directement utilisable telle quelle : voir TorqueScale.

--[[
	CALIBRATION : RAPPORT POIDS/PUISSANCE RÉEL.
	La masse d'une assembly Roblox n'est pas en kg et un stud n'est pas un mètre :
	la courbe en N·m ne peut pas être appliquée telle quelle. TorqueScale fait le
	pont, en imposant que la puissance MAXIMALE de la courbe, ramenée à la masse
	du véhicule, soit celle d'une vraie voiture de rallye (voir Units.luau pour
	la conversion d'échelle). La forme de la courbe est conservée, seule son
	amplitude est recalée ; l'étagement de la boîte n'y entre pas.

	Rally2 : ~290 ch (213 kW) pour ~1400 kg équipage compris -> ~150 W/kg.
	En 1re, la poussée au couple max dépasse alors nettement l'adhérence sur
	asphalte (voir Gearbox.luau), comme sur la vraie : d'où les launch controls.
	Le rapport de chaque catégorie est dans sa fiche (PowerToWeight).
]]

--[[
	EMBRAYAGE.
	Le régime est imposé par les roues tant que l'embrayage est collé. Mais à
	l'arrêt, ça voudrait dire démarrer au ralenti, avec 23 % du couple : la
	voiture "cale" et se traîne jusqu'à 3500 tr/min. Un pilote fait patiner
	l'embrayage pour garder le moteur dans son couple ; on le modélise par un
	régime plancher qui monte avec l'accélérateur. Tant que les roues tournent
	moins vite que ce plancher, l'embrayage patine et transmet le couple du
	moteur à ce régime ; au-delà, il colle.
	À pédale relâchée, le plancher est le ralenti : l'embrayage s'ouvre sous ce
	régime, et la voiture ne cale ni ne rampe.

	Ce plancher de départ n'existe qu'en 1re et en marche arrière. Dans les autres
	rapports, l'embrayage ne patine que pour ne pas caler, au ralenti : repartir
	en 4e à basse vitesse doit être mou, sinon le choix du rapport ne compte plus
	et la boîte se comporte comme un convertisseur de couple.
]]
-- Plancher à fond : en plein plateau de couple (LaunchRPM de la fiche).

-- Inertie du moteur, ressentie quand il tourne libre (embrayage ouvert ou patinant).
local REV_UP_RATE = 18000 -- tr/min par seconde
local REV_DOWN_RATE = 9000

--[[
	FREIN MOTEUR : couple résistant quand on lève le pied, proportionnel au régime.
	Multiplié par le rapport engagé, il devient sensible en 1re-2e : c'est ce qui
	donne son sens au rétrogradage et au lever de pied en entrée de virage.
	Exprimé en fraction du couple max, au régime max.
]]
local ENGINE_BRAKE_RATIO = 0.25

-- Rupteur (LimiterRPM de la fiche) : coupure d'injection, réarmée un peu plus
-- bas (le régime "rebondit").
local LIMITER_HYSTERESIS = 250

--[[
	TURBO À RETARDEMENT (Groupe B) : la part TurboShare du couple suit la
	pression, qui monte en TurboLag secondes quand on accélère et retombe
	plus vite au lever de pied. Ré-accélérer en sortie de virage, c'est
	attendre que ça pousse : il faut anticiper.
]]
local BOOST_FALL_FACTOR = 3

local RAD_PER_SEC_TO_RPM = 9.5492

type Curve = { CarClasses.TorquePoint }

-- Couple de la courbe brute (N·m), interpolé linéairement.
local function sampleCurve(curve: Curve, rpm: number): number
	if rpm <= curve[1].rpm then
		return curve[1].torque
	end
	if rpm >= curve[#curve].rpm then
		return curve[#curve].torque
	end
	for i = 1, #curve - 1 do
		local p1, p2 = curve[i], curve[i + 1]
		if rpm >= p1.rpm and rpm <= p2.rpm then
			return p1.torque + (p2.torque - p1.torque) * ((rpm - p1.rpm) / (p2.rpm - p1.rpm))
		end
	end
	return 0
end

local function getPeakTorque(curve: Curve): number
	local peak = 0
	for _, point in ipairs(curve) do
		peak = math.max(peak, point.torque)
	end
	return peak
end

-- Puissance maximale de la courbe brute (N·m x rad/s), échantillonnée : le pic ne
-- tombe pas forcément sur un point de la courbe.
local function getPeakPower(curve: Curve): number
	local peak = 0
	local lastRpm = curve[#curve].rpm
	for rpm = 0, lastRpm, 25 do
		peak = math.max(peak, sampleCurve(curve, rpm) * rpm / RAD_PER_SEC_TO_RPM)
	end
	return peak
end

function Powertrain.new(vehicleMass: number, wheelRadius: number, class: CarClasses.Class): Powertrain
	local self = (setmetatable({}, Powertrain) :: any) :: Powertrain
	self.MaxRPM = class.MaxRPM
	self.IdleRPM = class.IdleRPM
	self.LimiterRPM = class.LimiterRPM
	self.LaunchRPM = class.LaunchRPM
	self.TorqueCurve = class.TorqueCurve
	self.TurboLag = class.TurboLag
	self.TurboShare = class.TurboShare
	self.Boost = 1

	-- Rayon réel des roues du gabarit (Wheel.Radius = TireXX.Size.Y / 2), fourni
	-- par Car.luau. Les vitesses par rapport de Gearbox.luau sont données pour
	-- un rayon de 1 stud : elles varient en proportion.
	self.WheelRadius = wheelRadius

	-- Puissance (masse * studs² / s³) = couple (masse * studs² / s²) x rad/s.
	local targetPower = vehicleMass * Units.PowerToWeightToStuds(class.PowerToWeight)
	self.TorqueScale = targetPower / getPeakPower(self.TorqueCurve)
	self.EngineBrakeTorque = getPeakTorque(self.TorqueCurve) * self.TorqueScale * ENGINE_BRAKE_RATIO

	self.Gearbox = GearboxClass.new(self.LimiterRPM, self.WheelRadius, class)

	self.EngineRPM = self.IdleRPM
	self.ClutchSlipping = false
	self.FuelCut = false
	self.Load = 0
	self.ClutchHeld = false
	return self
end

function Powertrain:GetEngineTorque(rpm: number): number
	return sampleCurve(self.TorqueCurve, rpm) * self.TorqueScale
end

-- Pression du turbo : elle suit l'accélérateur, avec retard.
function Powertrain:_updateBoost(dt: number, throttle: number)
	if self.TurboLag <= 0 then
		self.Boost = 1
		return
	end
	local rate = if throttle > self.Boost then 1 / self.TurboLag else BOOST_FALL_FACTOR / self.TurboLag
	local step = rate * dt
	self.Boost += math.clamp(throttle - self.Boost, -step, step)
end

function Powertrain:_revFreely(dt: number, target: number)
	local rate = if target > self.EngineRPM then REV_UP_RATE else REV_DOWN_RATE
	local maxStep = rate * dt
	self.EngineRPM += math.clamp(target - self.EngineRPM, -maxStep, maxStep)
end

--[[
	Avance d'une frame et renvoie le couple total aux roues, SIGNÉ : positif pour
	faire avancer la voiture, négatif en marche arrière ou en frein moteur.

	wheelAngularVelocity : vitesse angulaire moyenne des roues motrices (rad/s,
	signée). Le régime vient de la ROTATION RÉELLE des roues, pas de la vitesse de
	la voiture : roues bloquées au freinage, le moteur redescend ; roues qui
	patinent, il monte dans les tours.
]]
function Powertrain:Update(dt: number, wheelAngularVelocity: number, throttle: number): number
	local gearbox = self.Gearbox
	gearbox:Update(dt)

	local totalRatio = gearbox:GetTotalRatio()
	-- Régime que les roues imposent au moteur à travers la boîte. Signé : négatif
	-- si la voiture roule à l'envers du rapport engagé (recul en 1re, avance en R).
	local coupledRPM = wheelAngularVelocity * totalRatio * RAD_PER_SEC_TO_RPM

	local clutchOpen = gearbox.Gear == 0 or gearbox:IsShifting() or self.ClutchHeld
	local isLaunchGear = gearbox.Gear == 1 or gearbox.Gear == -1
	local slipFloorRPM = if isLaunchGear
		then self.IdleRPM + throttle * (self.LaunchRPM - self.IdleRPM)
		else self.IdleRPM
	local clutchLocked = not clutchOpen and coupledRPM >= slipFloorRPM
	self.ClutchSlipping = not clutchOpen and not clutchLocked

	if clutchLocked then
		self.EngineRPM = math.min(coupledRPM, self.MaxRPM)
	elseif clutchOpen then
		-- Point mort : le moteur monte librement. Pendant un passage : il se
		-- synchronise sur le nouveau rapport (chute à la montée, coup de gaz à la descente).
		-- Embrayage tenu : "launch control", le régime plafonne au régime de départ,
		-- en plein couple quand l'embrayage se fermera.
		local target = if self.ClutchHeld
			then self.IdleRPM + throttle * (self.LaunchRPM - self.IdleRPM)
			elseif gearbox.Gear == 0 then self.IdleRPM + throttle * (self.LimiterRPM - self.IdleRPM)
			else math.clamp(coupledRPM, self.IdleRPM, self.MaxRPM)
		self:_revFreely(dt, target)
	else
		self:_revFreely(dt, slipFloorRPM)
	end

	if self.EngineRPM >= self.LimiterRPM then
		self.FuelCut = true
	elseif self.EngineRPM < self.LimiterRPM - LIMITER_HYSTERESIS then
		self.FuelCut = false
	end

	-- Charge : coupée pendant un passage (coupure d'allumage) et au rupteur, ce
	-- qui donne au son le "trou" de la montée de rapport et le crépitement du rupteur.
	self.Load = if gearbox:IsShifting() or self.FuelCut then 0 else throttle

	if clutchOpen then
		return 0
	end

	local effectiveThrottle = if self.FuelCut then 0 else throttle
	self:_updateBoost(dt, effectiveThrottle)
	local boostFactor = 1 - self.TurboShare + self.TurboShare * self.Boost
	local engineTorque = self:GetEngineTorque(self.EngineRPM) * effectiveThrottle * boostFactor

	-- Le frein moteur n'existe que si le moteur est entraîné par les roues :
	-- embrayage collé. En patinage, l'embrayage transmet le couple moteur, point.
	if clutchLocked then
		engineTorque -= self.EngineBrakeTorque * (self.EngineRPM / self.MaxRPM) * (1 - effectiveThrottle)
	end

	-- Le rapport signé retourne le couple en marche arrière.
	return engineTorque * totalRatio
end

return Powertrain
