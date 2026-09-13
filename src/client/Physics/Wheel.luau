--!strict
--[[
	Wheel.luau
	Une roue = un raycast + un ressort + un modèle de pneu + une roue visuelle.

	L'update est scindé en plusieurs phases, car les barres anti-roulis ont besoin
	de connaître la compression des DEUX roues d'un essieu avant d'appliquer la
	moindre force :

		1) UpdateSuspension(dt) -> raycast, compression, force de ressort
		2) (Car.luau calcule les barres anti-roulis et remplit AntiRollForce)
		3) ApplyForces(dt, ...)  -> suspension + pneu, avec la charge corrigée
		4) UpdateVisual(dt)      -> débattement, braquage et rotation de la jante
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Surfaces = require(ReplicatedStorage.Shared.Constants.Surfaces)

local Wheel = {}
Wheel.__index = Wheel

export type Wheel = typeof(setmetatable({}, Wheel)) & {
	Attachment: Attachment,
	Chassis: BasePart,
	IsFront: boolean,
	IsLeft: boolean,

	-- Réglages
	SuspensionLength: number,
	Stiffness: number,
	Damping: number,
	MaxSuspensionForce: number,
	RollCenterHeight: number,

	-- État recalculé à chaque frame (phase 1)
	IsGrounded: boolean,
	Compression: number,
	SpringForce: number,
	NormalForce: number,
	ContactPoint: Vector3,
	ContactNormal: Vector3,
	VelocityAtContact: Vector3,
	Surface: Surfaces.SurfaceProperties,

	-- Rempli par Car.luau entre les phases 1 et 2
	AntiRollForce: number,

	-- Visuel
	Tire: BasePart?,
	Motor: Motor6D?,
	VisualRadius: number,
	SpinAngle: number,
	SteerAngle: number,
	LongitudinalVelocity: number,

	RayParams: RaycastParams,
}

--[[
	CALIBRATION AUTOMATIQUE.
	Les constantes de suspension sont déduites de la masse réelle du véhicule au
	lieu d'être écrites en dur : changer de gabarit (ou ajouter du lest) ne demande
	plus aucun retuning, et surtout on ne peut plus repasser au-dessus des bornes
	de stabilité de l'intégration explicite.
]]
local STATIC_COMPRESSION_RATIO = 0.30 -- part du débattement écrasée à l'arrêt
local DAMPING_RATIO = 0.4 -- ζ : 1.0 = critique, en dessous la suspension respire
local MIN_FRAMERATE_DT = 1 / 30 -- doit correspondre au plafond de Main.client.luau

function Wheel.new(attachment: Attachment, chassis: BasePart, isFront: boolean, isLeft: boolean): Wheel
	local self = (setmetatable({}, Wheel) :: any) :: Wheel
	self.Attachment = attachment
	self.Chassis = chassis
	self.IsFront = isFront
	self.IsLeft = isLeft

	self.SuspensionLength = 1.6

	local cornerMass = chassis.AssemblyMass / 4
	local cornerWeight = cornerMass * workspace.Gravity

	-- Raideur : celle qui donne exactement l'écrasement statique visé.
	self.Stiffness = cornerWeight / (self.SuspensionLength * STATIC_COMPRESSION_RATIO)
	-- Amortissement : ζ = c / (2 * sqrt(k * m)).
	self.Damping = 2 * DAMPING_RATIO * math.sqrt(self.Stiffness * cornerMass)
	-- Garde-fou d'atterrissage : le terme d'amortissement peut exploser sur un gros
	-- impact (vitesse de compression énorme sur une seule frame).
	self.MaxSuspensionForce = self.Stiffness * self.SuspensionLength * 2

	--[[
		STABILITÉ NUMÉRIQUE.
		Les forces sont intégrées en Euler explicite (impulsion = force * dt), ce qui
		impose deux bornes, avec m = masse d'angle :

			amortisseur : Damping   < 2 * m / dt
			ressort     : Stiffness < 4 * m / dt²

		Au-delà, la suspension s'auto-amplifie à chaque frame et la voiture part en
		tonneau. Les valeurs déduites ci-dessus les respectent largement, mais on
		vérifie quand même : c'est un garde-fou gratuit si quelqu'un touche aux ratios.
	]]
	local maxStableDamping = 2 * cornerMass / MIN_FRAMERATE_DT
	local maxStableStiffness = 4 * cornerMass / (MIN_FRAMERATE_DT * MIN_FRAMERATE_DT)
	if self.Damping > maxStableDamping or self.Stiffness > maxStableStiffness then
		warn(string.format(
			"[Wheel] Suspension instable : Damping %.0f (max %.0f), Stiffness %.0f (max %.0f)",
			self.Damping,
			maxStableDamping,
			self.Stiffness,
			maxStableStiffness
		))
		self.Damping = math.min(self.Damping, maxStableDamping)
		self.Stiffness = math.min(self.Stiffness, maxStableStiffness)
	end

	--[[
		CENTRE DE ROULIS — le réglage anti-tonneau.

		Appliquer la force latérale à l'empreinte du pneu crée un couple de
		renversement F * h, où h est la hauteur du centre de masse au-dessus du
		contact : la caisse bascule dès que  mu > demi_voie / h.
		Remonter le point d'application à une hauteur r ramène ce couple à F * (h - r).
		C'est le rôle du centre de roulis sur une vraie suspension, et ça ne touche ni
		à l'adhérence ni au moment de lacet (le point ne bouge qu'en vertical).

			0 = empreinte du pneu : roulis maximal, le plus réaliste
			h = plus aucun roulis, la caisse reste parfaitement plate (arcade)
	]]
	self.RollCenterHeight = 0.6

	self.IsGrounded = false
	self.Compression = 0
	self.SpringForce = 0
	self.NormalForce = 0
	self.AntiRollForce = 0
	self.ContactPoint = Vector3.zero
	self.ContactNormal = Vector3.yAxis
	self.VelocityAtContact = Vector3.zero
	self.Surface = Surfaces.Default

	self.SpinAngle = 0
	self.SteerAngle = 0
	self.LongitudinalVelocity = 0

	-- Roue visuelle : "WheelFL" -> "TireFL" / "MotorFL". Facultative.
	local suffix = string.sub(attachment.Name, 6)
	local model = chassis.Parent
	local tire = if model then model:FindFirstChild("Tire" .. suffix) else nil
	self.Tire = tire :: BasePart?
	self.Motor = chassis:FindFirstChild("Motor" .. suffix) :: Motor6D?
	self.VisualRadius = if tire and tire:IsA("BasePart") then tire.Size.Y / 2 else 1

	-- Alloué une seule fois : le raycast tourne 4x par frame.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { chassis }
	self.RayParams = rayParams

	return self
end

--[[
	Liste d'exclusion des raycasts.
	CRITIQUE : elle doit contenir tout ce qui est solidaire du châssis -- la voiture
	entière, roues visuelles comprises, et le personnage du pilote. Un raycast ignore
	CanCollide : s'il touche une jante ou la jambe du conducteur à 0.1 stud, la
	compression explose et la suspension catapulte la voiture.
]]
function Wheel:SetIgnoreList(instances: { Instance })
	self.RayParams.FilterDescendantsInstances = instances
end

-- Phase 1 : géométrie du contact + force de ressort (sans les barres anti-roulis)
function Wheel:UpdateSuspension(dt: number)
	self.AntiRollForce = 0

	local worldPos = self.Attachment.WorldPosition
	local upVector = self.Chassis.CFrame.UpVector

	local rayResult = workspace:Raycast(worldPos, -upVector * self.SuspensionLength, self.RayParams)
	if not rayResult then
		self.IsGrounded = false
		self.Compression = 0
		self.SpringForce = 0
		self.NormalForce = 0
		return
	end

	self.IsGrounded = true
	self.ContactPoint = rayResult.Position
	self.ContactNormal = rayResult.Normal
	self.Surface = Surfaces.Get(rayResult.Material)
	self.VelocityAtContact = self.Chassis:GetVelocityAtPosition(worldPos)

	-- SUSPENSION (Loi de Hooke)
	self.Compression = self.SuspensionLength - rayResult.Distance
	local suspensionVelocity = self.VelocityAtContact:Dot(upVector)
	local force = (self.Stiffness * self.Compression) - (self.Damping * suspensionVelocity)
	self.SpringForce = math.clamp(force, 0, self.MaxSuspensionForce)
end

-- Phase 3 : suspension (ressort + barre anti-roulis) puis forces du pneu
function Wheel:ApplyForces(dt: number, driveForce: number, brakeForce: number, steerAngle: number)
	self.SteerAngle = steerAngle

	local smoke = self.Attachment:FindFirstChild("Smoke") :: ParticleEmitter?

	if not self.IsGrounded then
		self.NormalForce = 0
		if smoke then
			smoke.Enabled = false
		end
		return
	end

	local upVector = self.Chassis.CFrame.UpVector
	local contactPoint = self.ContactPoint

	-- Direction (Steering) locale
	local wheelCFrame = self.Chassis.CFrame * CFrame.Angles(0, steerAngle, 0)
	local forwardVector = wheelCFrame.LookVector
	local rightVector = wheelCFrame.RightVector

	-- 1. SUSPENSION : ressort + transfert de charge de la barre anti-roulis.
	-- La charge normale ne peut pas être négative (le pneu ne "tire" pas sur le sol),
	-- mais elle peut tomber à zéro : c'est le délestage de la roue intérieure.
	local normalForce = math.max(0, self.SpringForce + self.AntiRollForce)
	self.NormalForce = normalForce
	self.Chassis:ApplyImpulseAtPosition(upVector * normalForce * dt, contactPoint)

	-- 2. DYNAMIQUES DU PNEU (Vitesses locales)
	local velocityAtPoint = self.VelocityAtContact
	local lateralVelocity = velocityAtPoint:Dot(rightVector)
	local longitudinalVelocity = velocityAtPoint:Dot(forwardVector)
	self.LongitudinalVelocity = longitudinalVelocity

	local wheelMass = self.Chassis.AssemblyMass / 4
	local mu = self.Surface.Grip
	local maxLongitudinalImpulse = normalForce * mu * dt

	-- 3. FORCES LONGITUDINALES (Motricité, Freinage, Résistance au roulement)
	local targetDriveImpulse = driveForce * dt
	local brakeImpulse = 0
	local isLocked = false

	if math.abs(longitudinalVelocity) > 0.5 and brakeForce > 0 then
		local requiredBrakeImpulse = math.abs(longitudinalVelocity) * wheelMass
		local targetBrakeImpulse = math.min(brakeForce * dt, requiredBrakeImpulse)
		if targetBrakeImpulse > maxLongitudinalImpulse then
			targetBrakeImpulse = maxLongitudinalImpulse
			isLocked = true
		end
		brakeImpulse = -targetBrakeImpulse * math.sign(longitudinalVelocity)
	end

	local rollingImpulse = 0
	if math.abs(longitudinalVelocity) > 0.5 then
		rollingImpulse = -math.sign(longitudinalVelocity) * normalForce * self.Surface.RollingResistance * dt
	end

	local totalLongImpulse = math.clamp(
		targetDriveImpulse + brakeImpulse + rollingImpulse,
		-maxLongitudinalImpulse,
		maxLongitudinalImpulse
	)
	self.Chassis:ApplyImpulseAtPosition(forwardVector * totalLongImpulse, contactPoint)

	-- 4. FORCES LATÉRALES (Coulomb & Pacejka)
	local appliedLateralImpulse = 0
	if math.abs(longitudinalVelocity) < 2.0 then
		local requiredLateralImpulse = -lateralVelocity * wheelMass
		local maxLatImpulse = normalForce * mu * dt
		appliedLateralImpulse = math.clamp(requiredLateralImpulse, -maxLatImpulse, maxLatImpulse)
	else
		local slipAngle = math.atan2(lateralVelocity, math.abs(longitudinalVelocity))
		local B, C, E = 10.0, 1.9, 0.97
		local D = normalForce * mu
		local pacejkaForce = D * math.sin(C * math.atan(B * slipAngle - E * (B * slipAngle - math.atan(B * slipAngle))))
		appliedLateralImpulse = -pacejkaForce * dt
	end

	-- Appliquée au centre de roulis, pas à l'empreinte : voir RollCenterHeight.
	local lateralApplicationPoint = contactPoint + upVector * self.RollCenterHeight
	self.Chassis:ApplyImpulseAtPosition(rightVector * appliedLateralImpulse, lateralApplicationPoint)

	-- 5. EFFETS VISUELS (Patinage / Drift)
	if smoke then
		local isSpinning = math.abs(targetDriveImpulse) > maxLongitudinalImpulse
		local isDrifting = math.abs(lateralVelocity) > 3.0
		smoke.Enabled = isSpinning or isDrifting or isLocked
		smoke.Color = ColorSequence.new(self.Surface.DustColor)
	end
end

-- Phase 4 : la jante suit le débattement, le braquage et la rotation.
function Wheel:UpdateVisual(dt: number)
	local motor = self.Motor
	if not motor then
		return
	end

	-- Roue en l'air : la suspension se détend complètement.
	local travel = if self.IsGrounded then (self.SuspensionLength - self.Compression) else self.SuspensionLength
	local localPosition = self.Attachment.Position + Vector3.new(0, self.VisualRadius - travel, 0)

	-- L'avant étant en -Z, une rotation négative autour de X fait avancer le haut
	-- de la roue dans le sens de la marche.
	self.SpinAngle -= (self.LongitudinalVelocity / self.VisualRadius) * dt
	self.SpinAngle %= math.pi * 2

	motor.C0 = CFrame.new(localPosition) * CFrame.Angles(0, self.SteerAngle, 0) * CFrame.Angles(self.SpinAngle, 0, 0)
end

return Wheel
