--!strict
local WheelClass = require(script.Parent.Wheel)
local PowertrainClass = require(script.Parent.Powertrain)
local AerodynamicsClass = require(script.Parent.Aerodynamics)
local InputManager = require(script.Parent.Parent.Controllers.InputManager)

local Car = {}
Car.__index = Car

export type Car = typeof(setmetatable({}, Car)) & {
	Chassis: BasePart,
	Wheels: { WheelClass.Wheel },
	WheelsByName: { [string]: WheelClass.Wheel },
	Powertrain: PowertrainClass.Powertrain,
	Aerodynamics: AerodynamicsClass.Aerodynamics,
	MaxSteerAngle: number,
	MaxBrakeForce: number,
	HandbrakeForce: number,
	DriveBiasRear: number,
	BrakeBiasFront: number,
	Wheelbase: number,
	TrackWidth: number,
	AntiRollFront: number,
	AntiRollRear: number,
}

-- Freinage exprimé en fraction du poids : assez pour bloquer l'avant sur asphalte
-- (mu = 1.05) sans jamais bloquer l'arrière en premier.
local BRAKE_FORCE_RATIO = 0.45
local HANDBRAKE_FORCE_RATIO = 0.5

--[[
	Barres anti-roulis, exprimées en fraction de la raideur de ressort.
	Une barre plus raide que le ressort lui-même reporterait l'instabilité de
	l'intégration sur le mode de roulis.
	Règle d'équilibrage : durcir l'AVANT = plus de sous-virage, durcir l'ARRIÈRE =
	plus de survirage (utile pour placer la voiture en rallye).
]]
local ANTI_ROLL_FRONT_RATIO = 0.6
local ANTI_ROLL_REAR_RATIO = 0.42

function Car.new(chassis: BasePart): Car
	local self = (setmetatable({}, Car) :: any) :: Car
	self.Chassis = chassis
	self.Powertrain = PowertrainClass.new(chassis.AssemblyMass)
	self.Aerodynamics = AerodynamicsClass.new(chassis)
	self.MaxSteerAngle = 35
	self.DriveBiasRear = 0.6
	self.BrakeBiasFront = 0.70
	self.Wheels = {}
	self.WheelsByName = {}

	local weight = chassis.AssemblyMass * workspace.Gravity
	self.MaxBrakeForce = weight * BRAKE_FORCE_RATIO
	self.HandbrakeForce = weight * HANDBRAKE_FORCE_RATIO

	local fl = chassis:WaitForChild("WheelFL") :: Attachment
	local fr = chassis:WaitForChild("WheelFR") :: Attachment
	local rl = chassis:WaitForChild("WheelRL") :: Attachment

	self.Wheelbase = math.abs(fl.Position.Z - rl.Position.Z)
	self.TrackWidth = math.abs(fl.Position.X - fr.Position.X)

	local wheelNames = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }
	for _, name in ipairs(wheelNames) do
		local attachment = chassis:WaitForChild(name) :: Attachment
		local isFront = string.match(name, "F") ~= nil
		local isLeft = string.match(name, "L$") ~= nil
		local wheel = WheelClass.new(attachment, chassis, isFront, isLeft)
		table.insert(self.Wheels, wheel)
		self.WheelsByName[name] = wheel
	end

	-- Calées sur la raideur réellement calculée par Wheel.new (elle-même déduite
	-- de la masse) : le gabarit peut changer sans rien retoucher ici.
	local springRate = self.Wheels[1].Stiffness
	self.AntiRollFront = springRate * ANTI_ROLL_FRONT_RATIO
	self.AntiRollRear = springRate * ANTI_ROLL_REAR_RATIO

	return self
end

-- Vitesse au sol le long de l'axe du châssis (studs/s), positive en marche avant.
function Car:GetForwardSpeed(): number
	return self.Chassis.AssemblyLinearVelocity:Dot(self.Chassis.CFrame.LookVector)
end

--[[
	Palettes. Toucher une palette passe la boîte en manuel, comme sur une boîte
	auto à palettes ; ToggleAutomatic la rend à l'électronique.
]]
function Car:ShiftUp(): boolean
	local gearbox = self.Powertrain.Gearbox
	gearbox:SetAutomatic(false)
	return gearbox:ShiftUp(self:GetForwardSpeed())
end

function Car:ShiftDown(): boolean
	local gearbox = self.Powertrain.Gearbox
	gearbox:SetAutomatic(false)
	return gearbox:ShiftDown(self:GetForwardSpeed())
end

function Car:ToggleAutomatic(): boolean
	local gearbox = self.Powertrain.Gearbox
	gearbox:SetAutomatic(not gearbox.Automatic)
	return gearbox.Automatic
end

-- Propagée aux 4 roues : voir Wheel:SetIgnoreList.
function Car:SetIgnoreList(instances: { Instance })
	for _, wheel in ipairs(self.Wheels) do
		wheel:SetIgnoreList(instances)
	end
end

--[[
	Barre anti-roulis : elle ne crée AUCUNE force verticale nette, elle ne fait que
	transférer de la charge d'un côté à l'autre du même essieu.
	Si la roue gauche est plus comprimée (delta > 0), la barre repousse le châssis
	vers le HAUT à gauche et le tire vers le BAS à droite : le roulis diminue, et la
	charge (donc le grip) est transférée vers l'extérieur du virage.
]]
local function applyAxleAntiRoll(left: WheelClass.Wheel, right: WheelClass.Wheel, stiffness: number)
	local delta = left.Compression - right.Compression
	local force = delta * stiffness
	left.AntiRollForce = force
	right.AntiRollForce = -force
end

function Car:Update(dt: number, inputs: InputManager.CarInputs)
	-- PHASE 1 : contact au sol + ressorts (aucune force appliquée pour l'instant)
	for _, wheel in ipairs(self.Wheels) do
		wheel:UpdateSuspension(dt)
	end

	-- PHASE 2 : barres anti-roulis (a besoin des deux roues d'un essieu)
	applyAxleAntiRoll(self.WheelsByName.WheelFL, self.WheelsByName.WheelFR, self.AntiRollFront)
	applyAxleAntiRoll(self.WheelsByName.WheelRL, self.WheelsByName.WheelRR, self.AntiRollRear)

	-- Boîte : la logique auto voit les pédales telles que le joueur les appuie.
	local gearbox = self.Powertrain.Gearbox
	local forwardSpeed = self:GetForwardSpeed()
	if gearbox.Automatic then
		gearbox:UpdateAutomatic(forwardSpeed, inputs.throttle, inputs.brake)
	end

	-- Marche arrière en boîte auto, façon arcade : la touche de frein devient
	-- l'accélérateur, et l'accélérateur freine jusqu'à l'arrêt.
	local throttle, brake = inputs.throttle, inputs.brake
	if gearbox.Automatic and gearbox.Gear == -1 then
		throttle, brake = brake, throttle
	end

	-- Moteur : le régime est imposé par la rotation des roues via la transmission.
	-- Un différentiel ouvert égaliserait les couples et laisserait la roue la moins
	-- adhérente tout prendre ; on garde ici une répartition rigide, moyennée.
	-- Moyenne SIGNÉE : en marche arrière, les roues tournent à l'envers.
	local drivenAngularVelocity = 0
	for _, wheel in ipairs(self.Wheels) do
		drivenAngularVelocity += wheel.AngularVelocity
	end
	drivenAngularVelocity /= #self.Wheels

	-- Couple à la roue, plus une force : c'est la roue qui le convertira en
	-- traction, à hauteur de ce que le glissement et l'adhérence permettent.
	local totalWheelTorque = self.Powertrain:Update(dt, drivenAngularVelocity, throttle)

	-- Différentiel AWD
	local rearTorquePerWheel = (totalWheelTorque * self.DriveBiasRear) / 2
	local frontTorquePerWheel = (totalWheelTorque * (1.0 - self.DriveBiasRear)) / 2

	-- Ackermann Steering
	local targetSteerAngle = math.rad(self.MaxSteerAngle * inputs.steer)
	local leftAngle, rightAngle = 0, 0
	if math.abs(targetSteerAngle) > 0.001 then
		local turnRadius = self.Wheelbase / math.tan(targetSteerAngle)
		leftAngle = math.atan(self.Wheelbase / (turnRadius - (self.TrackWidth / 2)))
		rightAngle = math.atan(self.Wheelbase / (turnRadius + (self.TrackWidth / 2)))
	end

	-- PHASE 3 : distribution aux roues (suspension corrigée + pneus + visuel)
	for _, wheel in ipairs(self.Wheels) do
		local driveTorque = wheel.IsFront and frontTorquePerWheel or rearTorquePerWheel

		local brakeForce = 0
		if brake > 0 then
			local bias = wheel.IsFront and self.BrakeBiasFront or (1.0 - self.BrakeBiasFront)
			brakeForce = self.MaxBrakeForce * brake * bias
		end
		if inputs.handbrake and not wheel.IsFront then
			brakeForce = self.HandbrakeForce
		end

		local wheelSteerAngle = 0
		if wheel.IsFront then
			wheelSteerAngle = wheel.IsLeft and leftAngle or rightAngle
		end

		wheel:ApplyForces(dt, driveTorque, brakeForce, wheelSteerAngle)
		wheel:UpdateVisual(dt)
	end

	-- PHASE 4 : aérodynamisme (sur le châssis, indépendant du contact au sol)
	self.Aerodynamics:Apply(self.Chassis, dt)
end

return Car
