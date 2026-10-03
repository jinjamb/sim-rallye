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

	-- Pression réellement appliquée (0..1), qui suit la pédale avec un temps de montée
	BrakePressure: number,
	HandbrakePressure: number,
}

--[[
	FREINAGE, exprimé en fraction du poids. MaxBrakeForce est la force TOTALE des
	quatre freins : la répartition avant/arrière la partage entre les essieux, puis
	chaque essieu entre ses deux roues.
	Calibrage (transfert de charge avec hauteur de CdM / empattement ~ 0.21) :
	sur asphalte, rien ne bloque (il faudrait plus de 1.0) ; sur terre, l'avant
	bloque mais pas l'arrière (seuils 0.66 et 0.8), ce qui garde la voiture droite
	au freinage plutôt que de la faire partir en tête-à-queue.
]]
local BRAKE_FORCE_RATIO = 0.75
-- Par roue arrière : volontairement de quoi bloquer sur n'importe quelle surface.
local HANDBRAKE_FORCE_RATIO = 0.5

--[[
	TEMPS DE MONTÉE EN PRESSION. Le circuit hydraulique et le pied du pilote ne
	passent pas de 0 à 100 % en une frame : sans ça, le clavier fait tomber
	d'un coup toute la décélération, la caisse plonge sèchement et le freinage
	"pince" au lieu de s'installer. Le relâchement est plus rapide que l'appui.
	Le frein à main hydraulique de rallye, lui, est quasi instantané.
]]
local BRAKE_APPLY_TIME = 0.3 -- secondes de 0 à 100 %
local BRAKE_RELEASE_TIME = 0.1
local HANDBRAKE_APPLY_TIME = 0.08
local HANDBRAKE_RELEASE_TIME = 0.08

local function approachPressure(current: number, target: number, dt: number, applyTime: number, releaseTime: number): number
	if target > current then
		return math.min(target, current + dt / applyTime)
	end
	return math.max(target, current - dt / releaseTime)
end

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
	self.BrakePressure = 0
	self.HandbrakePressure = 0

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

	self.BrakePressure = approachPressure(self.BrakePressure, brake, dt, BRAKE_APPLY_TIME, BRAKE_RELEASE_TIME)
	self.HandbrakePressure = approachPressure(
		self.HandbrakePressure,
		if inputs.handbrake then 1 else 0,
		dt,
		HANDBRAKE_APPLY_TIME,
		HANDBRAKE_RELEASE_TIME
	)

	--[[
		DÉSACCOUPLEMENT DE L'ARRIÈRE. Sur une 4 roues motrices de rallye, tirer le
		frein à main ouvre un embrayage dans la transmission centrale : l'arrière
		n'est plus entraîné, tout le couple part à l'avant. Sans ça, le frein à main
		lutte contre le moteur sur l'essieu arrière, le moteur l'emporte en partie,
		et l'épingle au frein à main reste molle. Avec : l'arrière se bloque net
		pendant que l'avant continue de tirer la voiture dans le virage.
	]]
	local rearDecoupled = inputs.handbrake

	-- Moteur : le régime est imposé par la rotation des roues ENTRAÎNÉES via la
	-- transmission. Un différentiel ouvert égaliserait les couples et laisserait la
	-- roue la moins adhérente tout prendre ; on garde ici une répartition rigide,
	-- moyennée. Moyenne SIGNÉE : en marche arrière, les roues tournent à l'envers.
	-- Arrière désaccouplé, ses roues bloquées ne doivent plus tirer le régime vers le bas.
	local drivenAngularVelocity = 0
	local drivenCount = 0
	for _, wheel in ipairs(self.Wheels) do
		if wheel.IsFront or not rearDecoupled then
			drivenAngularVelocity += wheel.AngularVelocity
			drivenCount += 1
		end
	end
	drivenAngularVelocity /= drivenCount

	-- Couple à la roue, plus une force : c'est la roue qui le convertira en
	-- traction, à hauteur de ce que le glissement et l'adhérence permettent.
	local totalWheelTorque = self.Powertrain:Update(dt, drivenAngularVelocity, throttle)

	-- Différentiel AWD
	local rearShare = if rearDecoupled then 0 else self.DriveBiasRear
	local rearTorquePerWheel = (totalWheelTorque * rearShare) / 2
	local frontTorquePerWheel = (totalWheelTorque * (1.0 - rearShare)) / 2

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

		-- Part de l'essieu, puis moitié par roue.
		local axleBias = if wheel.IsFront then self.BrakeBiasFront else (1.0 - self.BrakeBiasFront)
		local brakeForce = self.MaxBrakeForce * self.BrakePressure * axleBias / 2
		if not wheel.IsFront then
			-- Les deux commandes agissent sur les mêmes étriers : la plus forte l'emporte.
			brakeForce = math.max(brakeForce, self.HandbrakeForce * self.HandbrakePressure)
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
