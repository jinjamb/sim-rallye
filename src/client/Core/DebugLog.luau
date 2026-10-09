--!strict
--[[
	DebugLog.luau
	Journal console (F3) : deux fois par seconde, l'état de la voiture en une
	ligne -- commandes, roues au sol, surface sous chaque roue, vitesse,
	rapport, régime, glissement. Utile pour garder une trace écrite d'un essai.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Shared.Util.Units)
local InputManager = require(script.Parent.InputManager)
local CarClass = require(script.Parent.Parent.Physics.Car)

local DebugLog = {}

function DebugLog.Print(car: CarClass.Car, chassis: BasePart)
	local inputs = InputManager:GetInputs()
	local grounded = 0
	local totalLoad = 0
	local maxSlip = 0
	local maxUsage = 0
	for _, wheel in ipairs(car.Wheels) do
		if wheel.IsGrounded then
			grounded += 1
			totalLoad += wheel.NormalForce
		end
		maxSlip = math.max(maxSlip, math.abs(wheel.SlipRatio))
		maxUsage = math.max(maxUsage, wheel.FrictionUsage)
	end

	-- Surface sous chaque roue : un seul nom si les quatre sont d'accord, sinon le
	-- détail (utile en travers d'une limite de surface, ou sur une bande split-mu).
	local surfaceNames: { string } = {}
	local sameSurface = true
	for i, suffix in ipairs({ "FL", "FR", "RL", "RR" }) do
		local wheel = car.WheelsByName["Wheel" .. suffix]
		local name = if wheel.IsGrounded
			then string.format("%s %.2f", wheel.Surface.Name, wheel.Surface.Grip)
			else "en l'air"
		surfaceNames[i] = name
		if name ~= surfaceNames[1] then
			sameSurface = false
		end
	end
	local surfaceLabel = if sameSurface
		then surfaceNames[1]
		else string.format("AVG %s / AVD %s / ARG %s / ARD %s", table.unpack(surfaceNames))

	local powertrain = car.Powertrain
	local gearbox = powertrain.Gearbox
	local gearLabel = if gearbox.Gear == -1 then "R" elseif gearbox.Gear == 0 then "N" else tostring(gearbox.Gear)
	local flags = (if gearbox:IsShifting() then " passage" else "")
		.. (if powertrain.ClutchSlipping then " embrayage-patine" else "")
		.. (if powertrain.FuelCut then " RUPTEUR" else "")
		.. (if car.Held then " RETENUE" else "")

	print(string.format(
		"[Car] %s throttle=%.2f brake=%.2f steer=%+.2f%s | sol=%d/4 charge=%.0f (poids=%.0f) | surface=%s | %.0f km/h | %s %s %.0f tr/min%s | glissement=%.2f | cercle=%.0f%%",
		InputManager:GetActiveSource(),
		inputs.throttle,
		inputs.brake,
		inputs.steer,
		if inputs.handbrake then " FREIN-À-MAIN" else "",
		grounded,
		totalLoad,
		chassis.AssemblyMass * workspace.Gravity,
		surfaceLabel,
		Units.ToKmh(chassis.AssemblyLinearVelocity.Magnitude),
		if gearbox.Automatic then "A" else "M",
		gearLabel,
		powertrain.EngineRPM,
		flags,
		maxSlip,
		maxUsage * 100
	))
end

return DebugLog
