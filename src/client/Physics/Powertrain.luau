--!strict
local Powertrain = {}
Powertrain.__index = Powertrain

export type Powertrain = typeof(setmetatable({}, Powertrain)) & {
	MaxRPM: number,
	IdleRPM: number,
	CurrentGearRatio: number,
	FinalDrive: number,
	WheelRadius: number,
	TorqueScale: number,
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
	Roblox n'est pas en unités SI : la gravité vaut 196.2 studs/s² et un stud n'est
	pas un mètre. Une courbe de couple "réaliste" en N·m ne produit donc pas
	l'accélération attendue. TorqueScale fait le pont, et se déduit d'une cible
	d'accélération au lieu d'être un nombre magique -- c'est le rapport
	poids/puissance du véhicule.
]]
local TARGET_LAUNCH_ACCELERATION = 90 -- studs/s² au couple maximal (~0.46 g)

local function getPeakTorque(): number
	local peak = 0
	for _, point in ipairs(TorqueCurve) do
		peak = math.max(peak, point.torque)
	end
	return peak
end

function Powertrain.new(vehicleMass: number): Powertrain
	local self = (setmetatable({}, Powertrain) :: any) :: Powertrain
	self.MaxRPM = 8000
	self.IdleRPM = 1000

	-- Rapport unique : c'est un compromis entre couple et vitesse de pointe.
	-- Total 7.63 -> pointe ~110 studs/s au rupteur.
	self.CurrentGearRatio = 1.86
	self.FinalDrive = 4.1
	-- Doit correspondre au rayon des roues visuelles du gabarit (TireXX.Size.Y / 2).
	self.WheelRadius = 1.0

	local totalRatio = self.CurrentGearRatio * self.FinalDrive
	self.TorqueScale = (vehicleMass * TARGET_LAUNCH_ACCELERATION * self.WheelRadius)
		/ (getPeakTorque() * totalRatio)

	return self
end

function Powertrain:GetEngineTorque(rpm: number): number
	if rpm <= TorqueCurve[1].rpm then
		return TorqueCurve[1].torque * self.TorqueScale
	end
	if rpm >= TorqueCurve[#TorqueCurve].rpm then
		return TorqueCurve[#TorqueCurve].torque * self.TorqueScale
	end
	for i = 1, #TorqueCurve - 1 do
		local p1, p2 = TorqueCurve[i], TorqueCurve[i + 1]
		if rpm >= p1.rpm and rpm <= p2.rpm then
			local interpolated = p1.torque + (p2.torque - p1.torque) * ((rpm - p1.rpm) / (p2.rpm - p1.rpm))
			return interpolated * self.TorqueScale
		end
	end
	return 0
end

--[[
	Le régime vient désormais de la ROTATION RÉELLE des roues, plus de la vitesse
	de la voiture. La différence est tout sauf cosmétique : roues bloquées au
	freinage, le moteur redescend au ralenti ; roues qui patinent à l'arrêt, il
	monte dans les tours. C'est ce que la transmission impose physiquement.
]]
function Powertrain:CalculateRPM(wheelAngularVelocity: number): number
	local wheelRPM = math.abs(wheelAngularVelocity) * 9.5492 -- rad/s -> tr/min
	local engineRPM = wheelRPM * self.CurrentGearRatio * self.FinalDrive
	return math.clamp(engineRPM, self.IdleRPM, self.MaxRPM)
end

return Powertrain
