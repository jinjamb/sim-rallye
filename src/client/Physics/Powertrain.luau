--!strict
--[[
	Powertrain.luau
	Moteur + embrayage + boîte (Gearbox.luau). Entrée : la rotation moyenne des
	roues motrices et la pédale d'accélérateur. Sortie : le couple total à
	répartir sur les roues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Constants.Units)
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
}

-- Courbe en N·m, tracée comme sur un banc réel. Elle n'est PAS directement
-- utilisable telle quelle : voir TorqueScale.
local TorqueCurve = {
	{ rpm = 0, torque = 0 },
	{ rpm = 1000, torque = 150 },
	{ rpm = 3500, torque = 600 },
	{ rpm = 5500, torque = 650 },
	{ rpm = 7500, torque = 400 },
	{ rpm = 8000, torque = 0 },
}

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
]]
local TARGET_POWER_TO_WEIGHT = 150 -- W/kg

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
local LAUNCH_RPM = 4500 -- plancher à fond : en plein plateau de couple

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

-- Rupteur : coupure d'injection, réarmée un peu plus bas (le régime "rebondit").
local LIMITER_RPM = 7800
local LIMITER_HYSTERESIS = 250

local RAD_PER_SEC_TO_RPM = 9.5492

-- Couple de la courbe brute (N·m), interpolé linéairement.
local function sampleCurve(rpm: number): number
	if rpm <= TorqueCurve[1].rpm then
		return TorqueCurve[1].torque
	end
	if rpm >= TorqueCurve[#TorqueCurve].rpm then
		return TorqueCurve[#TorqueCurve].torque
	end
	for i = 1, #TorqueCurve - 1 do
		local p1, p2 = TorqueCurve[i], TorqueCurve[i + 1]
		if rpm >= p1.rpm and rpm <= p2.rpm then
			return p1.torque + (p2.torque - p1.torque) * ((rpm - p1.rpm) / (p2.rpm - p1.rpm))
		end
	end
	return 0
end

local function getPeakTorque(): number
	local peak = 0
	for _, point in ipairs(TorqueCurve) do
		peak = math.max(peak, point.torque)
	end
	return peak
end

-- Puissance maximale de la courbe brute (N·m x rad/s), échantillonnée : le pic ne
-- tombe pas forcément sur un point de la courbe.
local function getPeakPower(): number
	local peak = 0
	local lastRpm = TorqueCurve[#TorqueCurve].rpm
	for rpm = 0, lastRpm, 25 do
		peak = math.max(peak, sampleCurve(rpm) * rpm / RAD_PER_SEC_TO_RPM)
	end
	return peak
end

function Powertrain.new(vehicleMass: number): Powertrain
	local self = (setmetatable({}, Powertrain) :: any) :: Powertrain
	self.MaxRPM = 8000
	self.IdleRPM = 1000
	self.LimiterRPM = LIMITER_RPM
	self.LaunchRPM = LAUNCH_RPM

	-- Doit correspondre au rayon des roues visuelles du gabarit (TireXX.Size.Y / 2).
	self.WheelRadius = 1.0

	-- Puissance (masse * studs² / s³) = couple (masse * studs² / s²) x rad/s.
	local targetPower = vehicleMass * Units.PowerToWeightToStuds(TARGET_POWER_TO_WEIGHT)
	self.TorqueScale = targetPower / getPeakPower()
	self.EngineBrakeTorque = getPeakTorque() * self.TorqueScale * ENGINE_BRAKE_RATIO

	self.Gearbox = GearboxClass.new(self.LimiterRPM, self.WheelRadius)

	self.EngineRPM = self.IdleRPM
	self.ClutchSlipping = false
	self.FuelCut = false
	self.Load = 0
	return self
end

function Powertrain:GetEngineTorque(rpm: number): number
	return sampleCurve(rpm) * self.TorqueScale
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

	local clutchOpen = gearbox.Gear == 0 or gearbox:IsShifting()
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
		local target = if gearbox.Gear == 0
			then self.IdleRPM + throttle * (self.LimiterRPM - self.IdleRPM)
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
	local engineTorque = self:GetEngineTorque(self.EngineRPM) * effectiveThrottle

	-- Le frein moteur n'existe que si le moteur est entraîné par les roues :
	-- embrayage collé. En patinage, l'embrayage transmet le couple moteur, point.
	if clutchLocked then
		engineTorque -= self.EngineBrakeTorque * (self.EngineRPM / self.MaxRPM) * (1 - effectiveThrottle)
	end

	-- Le rapport signé retourne le couple en marche arrière.
	return engineTorque * totalRatio
end

return Powertrain
