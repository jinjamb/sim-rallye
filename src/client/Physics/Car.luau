--!strict
local WheelClass = require(script.Parent.Wheel)
local PowertrainClass = require(script.Parent.Powertrain)
local AerodynamicsClass = require(script.Parent.Aerodynamics)
local DifferentialClass = require(script.Parent.Differential)
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
	BrakeBiasFront: number,
	FrontDiff: DifferentialClass.Differential,
	RearDiff: DifferentialClass.Differential,
	CenterDiff: DifferentialClass.Differential, -- sortie 1 = avant, sortie 2 = arrière
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

	La glisse au frein vient de l'ARRIÈRE qui décroche : si seul l'avant bloque,
	la voiture file tout droit, direction morte -- stable, mais impossible à
	placer en travers au freinage. C'est ce que donnait l'ancienne répartition
	70/30 : sur terre, l'avant bloquait dès 0.66, l'arrière jamais.

	Calibrage avec la répartition 65/35 (transfert de charge : hauteur de CdM /
	empattement ~ 0.21) -- force totale à partir de laquelle chaque essieu bloque :

		             avant   arrière
		asphalte      1.22     0.92    -> à 0.85, rien ne bloque : freinage
		                                  franc et stable sur le dur
		terre         0.72     0.72    -> les deux essieux décrochent ensemble :
		                                  la voiture glisse, et pivote dès qu'on
		                                  braque ou qu'on module à la gâchette
		neige, boue   bloquent largement

	Reculer la répartition vers l'arrière accentue la glisse au frein (l'arrière
	décroche en premier : rotation) ; l'avancer la stabilise.
]]
local BRAKE_FORCE_RATIO = 0.85
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
	TRANSMISSION : trois autobloquants à rampes (voir Differential.luau).

	Preload exprimé en fraction du couple d'adhérence statique d'une roue
	(poids/4 x rayon, mu = 1) : il se recale tout seul avec la masse et la gravité.
	Lock : 0 = ouvert, 1 = blocage complet sous charge. TBR = (1+L)/(1-L).

	AVANT, 1.5 voie, doux : un avant trop bloqué refuse de tourner (sous-virage
	à l'accélération) et tire dans le volant.
	ARRIÈRE, plus bloqué : c'est lui qui donne la motricité en sortie de virage et qui fait
	pivoter la voiture au gaz. Le Coast donne de la stabilité au lever de pied.
	CENTRAL : 60 % à l'arrière, comme avant, pour le caractère survireur ; le
	blocage renvoie le couple vers l'essieu qui adhère quand l'autre patine.
	(Une vraie Rally2 n'a PAS de différentiel central : arbre rigide. Pour
	l'imiter, mettre Lock à 1 et un Preload élevé -- la voiture devient plus
	sous-vireuse en épingle, et le frein à main devient indispensable.)
]]
local FRONT_DIFF = { Split = 0.5, PreloadRatio = 0.05, PowerLock = 0.35, CoastLock = 0.15 }
local REAR_DIFF = { Split = 0.5, PreloadRatio = 0.10, PowerLock = 0.5, CoastLock = 0.3 }
local CENTER_DIFF = { Split = 0.6, PreloadRatio = 0.05, PowerLock = 0.4, CoastLock = 0.2 }

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
	self.BrakeBiasFront = 0.65 -- voir le calibrage de BRAKE_FORCE_RATIO
	self.Wheels = {}
	self.WheelsByName = {}

	local weight = chassis.AssemblyMass * workspace.Gravity
	self.MaxBrakeForce = weight * BRAKE_FORCE_RATIO
	self.HandbrakeForce = weight * HANDBRAKE_FORCE_RATIO
	self.BrakePressure = 0
	self.HandbrakePressure = 0

	local wheelGripTorque = (weight / 4) * self.Powertrain.WheelRadius
	local function makeDiff(spec: typeof(FRONT_DIFF)): DifferentialClass.Differential
		return DifferentialClass.new({
			Split = spec.Split,
			Preload = wheelGripTorque * spec.PreloadRatio,
			PowerLock = spec.PowerLock,
			CoastLock = spec.CoastLock,
		})
	end
	self.FrontDiff = makeDiff(FRONT_DIFF)
	self.RearDiff = makeDiff(REAR_DIFF)
	self.CenterDiff = makeDiff(CENTER_DIFF)

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
	Téléportation (remise en piste, retour au départ). Toute la voiture bouge :
	PivotTo déplace le modèle, et le pilote, soudé au châssis, suit l'assembly.
	On remet aussi à zéro tout ce qui garde la mémoire du mouvement -- vitesses
	du châssis, rotation des roues, pédales -- sinon la voiture repartirait avec
	l'élan (et le régime) qu'elle avait avant.
]]
function Car:Teleport(target: CFrame)
	local model = self.Chassis.Parent
	if model and model:IsA("Model") and model.PrimaryPart == self.Chassis then
		model:PivotTo(target)
	else
		self.Chassis.CFrame = target
	end
	self.Chassis.AssemblyLinearVelocity = Vector3.zero
	self.Chassis.AssemblyAngularVelocity = Vector3.zero

	for _, wheel in ipairs(self.Wheels) do
		wheel.AngularVelocity = 0
	end
	self.BrakePressure = 0
	self.HandbrakePressure = 0

	local powertrain = self.Powertrain
	powertrain.EngineRPM = powertrain.IdleRPM
	if powertrain.Gearbox.Automatic then
		powertrain.Gearbox.Gear = 1
	end
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

	local fl, fr = self.WheelsByName.WheelFL, self.WheelsByName.WheelFR
	local rl, rr = self.WheelsByName.WheelRL, self.WheelsByName.WheelRR

	--[[
		Régime moteur : imposé par les roues à travers les différentiels. Un
		différentiel qui partage le couple dans la proportion s tourne, à son
		entrée, à la moyenne de ses sorties PONDÉRÉE par s (conservation de la
		puissance). Moyennes SIGNÉES : en marche arrière, les roues tournent à
		l'envers. Arrière désaccouplé, ses roues bloquées ne comptent plus.
	]]
	local frontAxleSpeed = (fl.AngularVelocity + fr.AngularVelocity) / 2
	local rearAxleSpeed = (rl.AngularVelocity + rr.AngularVelocity) / 2
	local rearShare = if rearDecoupled then 0 else self.CenterDiff.Split
	local drivenAngularVelocity = frontAxleSpeed * (1 - rearShare) + rearAxleSpeed * rearShare

	-- Couple à la roue, plus une force : c'est la roue qui le convertira en
	-- traction, à hauteur de ce que le glissement et l'adhérence permettent.
	local totalWheelTorque = self.Powertrain:Update(dt, drivenAngularVelocity, throttle)

	-- Puissance qui va du moteur vers les roues (traction) ou l'inverse (frein moteur) :
	-- c'est ce qui choisit entre les rampes Power et Coast des autobloquants.
	local isPower = totalWheelTorque * drivenAngularVelocity >= 0

	-- 1) Partie OUVERTE : chaque différentiel partage le couple dans sa proportion fixe.
	local frontAxleTorque = totalWheelTorque * (1 - rearShare)
	local rearAxleTorque = totalWheelTorque * rearShare
	fl:ApplyDriveTorque(dt, frontAxleTorque * (1 - self.FrontDiff.Split))
	fr:ApplyDriveTorque(dt, frontAxleTorque * self.FrontDiff.Split)
	rl:ApplyDriveTorque(dt, rearAxleTorque * (1 - self.RearDiff.Split))
	rr:ApplyDriveTorque(dt, rearAxleTorque * self.RearDiff.Split)

	--[[
		2) Partie AUTOBLOQUANTE : on freine l'écart de vitesse entre les sorties,
		AVANT que le pneu ne réagisse, pour qu'il voie des roues déjà couplées.
		Gauche/droite d'abord : à inerties égales, ça ne change pas la moyenne de
		l'essieu, donc l'ordre avec le central est indifférent.
	]]
	local function solveAxle(
		diff: DifferentialClass.Differential,
		left: WheelClass.Wheel,
		right: WheelClass.Wheel,
		axleTorque: number
	)
		local capacity = diff:GetCapacity(axleTorque, isPower)
		local impulse = diff:Solve(left.AngularVelocity, left.Inertia, right.AngularVelocity, right.Inertia, capacity, dt)
		left.AngularVelocity -= impulse / left.Inertia
		right.AngularVelocity += impulse / right.Inertia
	end
	solveAxle(self.FrontDiff, fl, fr, frontAxleTorque)
	solveAxle(self.RearDiff, rl, rr, rearAxleTorque)

	--[[
		Central : chaque essieu est vu comme une inertie de deux roues (son
		différentiel ouvert partage l'impulsion en deux moitiés égales). Arrière
		désaccouplé, l'arbre est ouvert : rien ne relie plus les deux essieux.
	]]
	if rearDecoupled then
		self.CenterDiff:Disengage()
	else
		local capacity = self.CenterDiff:GetCapacity(totalWheelTorque, isPower)
		local impulse = self.CenterDiff:Solve(
			(fl.AngularVelocity + fr.AngularVelocity) / 2,
			fl.Inertia + fr.Inertia,
			(rl.AngularVelocity + rr.AngularVelocity) / 2,
			rl.Inertia + rr.Inertia,
			capacity,
			dt
		)
		fl.AngularVelocity -= (impulse / 2) / fl.Inertia
		fr.AngularVelocity -= (impulse / 2) / fr.Inertia
		rl.AngularVelocity += (impulse / 2) / rl.Inertia
		rr.AngularVelocity += (impulse / 2) / rr.Inertia
	end

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

		wheel:ApplyForces(dt, brakeForce, wheelSteerAngle)
		wheel:UpdateVisual(dt)
	end

	-- PHASE 4 : aérodynamisme (sur le châssis, indépendant du contact au sol)
	self.Aerodynamics:Apply(self.Chassis, dt)
end

return Car
