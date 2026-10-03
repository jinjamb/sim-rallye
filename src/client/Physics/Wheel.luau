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
local PhysicsService = game:GetService("PhysicsService")
local Surfaces = require(ReplicatedStorage.Shared.Constants.Surfaces)

local CAR_COLLISION_GROUP = "Cars" -- voir CarService.server.luau

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
	Radius: number,
	Inertia: number,

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

	-- Dynamique de rotation : la roue est un corps à part entière
	AngularVelocity: number,
	SlipRatio: number,
	SlipAngle: number,
	FrictionUsage: number, -- part du cercle de friction consommée (1 = pneu saturé)
	-- Glissements normalisés par leur valeur au pic (|x| > 1 : au-delà du pic).
	-- Longitudinal > 0 : la roue patine ; < 0 : elle bloque.
	LongSlipNorm: number,
	LatSlipNorm: number,

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
--[[
	DYNAMIQUE DE ROTATION DE LA ROUE.

	Chaque roue possède sa vitesse angulaire. Le couple moteur l'accélère, le pneu
	la freine par réaction, le frein la ralentit. L'écart entre la vitesse de la
	jante (omega * R) et celle du sol est le TAUX DE GLISSEMENT : c'est lui qui
	produit la motricité, le patinage et le blocage de roue.

	Formulation par impulsions plutôt que par courbe intégrée explicitement.
	On calcule d'abord l'impulsion qui annulerait EXACTEMENT le glissement --
	en tenant compte des deux inerties en jeu, celle de la roue et celle du quart
	de voiture -- puis on l'écrête à la limite d'adhérence :

		J_adherence = glissement / (R² / I + 1 / m)

	C'est une résolution implicite : non écrêtée, elle annule le glissement en une
	étape sans jamais osciller ; écrêtée, elle est par construction insuffisante à
	le faire changer de signe. Aucune des deux branches ne peut diverger, quelle que
	soit la petitesse de l'inertie de roue -- là où intégrer une courbe de Pacejka
	en Euler explicite exigerait une inertie ~100x trop grande pour rester stable.
]]
local WHEEL_MASS_RATIO = 0.06 -- masse d'une roue + transmission ramenée à la roue, en fraction du véhicule
local SLIP_REFERENCE_SPEED = 4 -- studs/s : plancher au dénominateur des glissements

--[[
	CERCLE DE FRICTION.

	Un pneu ne dispose que d'UN budget d'adhérence, mu * N, qu'il répartit entre le
	longitudinal et le latéral. Tant que les deux axes étaient écrêtés séparément,
	une roue pouvait délivrer jusqu'à 1.41 * mu * N en combiné : on pouvait freiner
	à fond ET tourner à l'adhérence maximale, ce qui supprimait tout l'intérêt de
	gérer les transferts de charge.

	Les deux glissements sont normalisés par leur valeur au pic, ce qui les rend
	comparables, puis combinés en un seul scalaire. La courbe donne alors la part
	d'adhérence disponible.

	Quand le pneu sature, ce budget est réparti SELON LA DIRECTION DU GLISSEMENT
	(normalisé) : un pneu qui frotte pousse à l'opposé de la direction dans
	laquelle il glisse. Roue bloquée à 68 km/h qui dérape de côté à 7 studs/s :
	~12 % de l'adhérence en latéral, comme en vrai.
	(La première version répartissait au prorata des impulsions d'annulation.
	Or le glissement longitudinal s'annule avec une impulsion minuscule -- la
	roue est légère -- et le latéral avec une grosse -- il faut déplacer un quart
	de voiture. La même roue bloquée gardait alors 69 % de son adhérence en
	latéral : un train arrière bloqué tenait la route, le frein à main ne
	faisait pas pivoter la voiture, et un patinage ne faisait pas décrocher
	l'arrière à l'accélération.)
]]
--[[
	Glissement au pic et forme de la courbe dépendent du SOL (Surfaces.luau,
	champ Tire) : un pneu sur terre travaille à bien plus fort glissement que
	sur asphalte, et perd beaucoup moins d'adhérence au-delà de son pic.
]]

-- Part de l'adhérence disponible selon le glissement combiné normalisé :
-- 1 au pic. Au-delà (roue bloquée, patinage, gros travers) : ~0.77 sur le dur,
-- ~0.95 à ~0.87 sur le meuble.
local function combinedGrip(normalizedSlip: number, tire: Surfaces.TireProfile): number
	local bs = tire.B * math.abs(normalizedSlip)
	return math.sin(tire.C * math.atan(bs - tire.E * (bs - math.atan(bs))))
end

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
	self.AngularVelocity = 0
	self.SlipRatio = 0
	self.SlipAngle = 0
	self.FrictionUsage = 0
	self.LongSlipNorm = 0
	self.LatSlipNorm = 0

	-- Roue visuelle : "WheelFL" -> "TireFL" / "MotorFL". Facultative.
	local suffix = string.sub(attachment.Name, 6)
	local model = chassis.Parent
	local tire = if model then model:FindFirstChild("Tire" .. suffix) else nil
	self.Tire = tire :: BasePart?
	self.Motor = chassis:FindFirstChild("Motor" .. suffix) :: Motor6D?
	self.VisualRadius = if tire and tire:IsA("BasePart") then tire.Size.Y / 2 else 1

	-- Rayon physique = rayon visuel. Car.luau le transmet à Powertrain, qui en
	-- déduit le couple et la vitesse à la roue.
	self.Radius = self.VisualRadius
	-- I = 1/2 * m * R² (disque plein). La fraction englobe aussi l'inertie de la
	-- transmission ramenée à la roue, qui freine le patinage dans la réalité.
	self.Inertia = 0.5 * (chassis.AssemblyMass * WHEEL_MASS_RATIO) * self.Radius * self.Radius

	-- Alloué une seule fois : le raycast tourne 4x par frame.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { chassis }
	-- Le rayon se comporte comme une voiture : il traverse les AUTRES voitures
	-- (groupe "Cars", non collisionnant avec lui-même, créé par CarService).
	-- Sinon une voiture qui en croise une autre s'appuierait sur son toit.
	if PhysicsService:IsCollisionGroupRegistered(CAR_COLLISION_GROUP) then
		rayParams.CollisionGroup = CAR_COLLISION_GROUP
	end
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

-- Applique le couple de freinage et la résistance au roulement à la rotation de
-- la roue. Ils ne peuvent jamais l'inverser : au pire ils l'arrêtent net.
-- Appelé APRÈS l'impulsion du pneu, sinon une roue bloquée se verrait relancée
-- par l'adhérence à chaque frame et clignoterait visuellement.
function Wheel:_applyResistiveTorque(dt: number, torque: number)
	local delta = (torque / self.Inertia) * dt
	if math.abs(self.AngularVelocity) <= delta then
		self.AngularVelocity = 0
	else
		self.AngularVelocity -= math.sign(self.AngularVelocity) * delta
	end
end

--[[
	Couple de la transmission. Appelé par Car.luau AVANT le couplage des
	différentiels et AVANT ApplyForces : le pneu voit ainsi la vitesse de roue
	déjà accélérée par le moteur et égalisée par les autobloquants.
	En l'air, plus rien ne s'oppose au couple : la roue s'emballe.
]]
function Wheel:ApplyDriveTorque(dt: number, driveTorque: number)
	self.AngularVelocity += (driveTorque / self.Inertia) * dt
end

-- Phase 3 : suspension (ressort + barre anti-roulis) puis forces du pneu
function Wheel:ApplyForces(dt: number, brakeForce: number, steerAngle: number)
	self.SteerAngle = steerAngle

	local smoke = self.Attachment:FindFirstChild("Smoke") :: ParticleEmitter?

	if not self.IsGrounded then
		self.NormalForce = 0
		self.SlipRatio = 0
		self.SlipAngle = 0
		self.FrictionUsage = 0
		self.LongSlipNorm = 0
		self.LatSlipNorm = 0
		self:_applyResistiveTorque(dt, brakeForce * self.Radius)
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

	-- 3. GLISSEMENT COMBINÉ : un seul budget d'adhérence pour les deux axes

	-- a) Le couple moteur a déjà été appliqué (ApplyDriveTorque, puis différentiels).

	-- b) Les deux glissements, normalisés par leur valeur au pic pour être comparables.
	local referenceSpeed = math.max(math.abs(longitudinalVelocity), SLIP_REFERENCE_SPEED)
	local slipVelocity = (self.AngularVelocity * self.Radius) - longitudinalVelocity

	self.SlipRatio = slipVelocity / referenceSpeed
	self.SlipAngle = math.atan2(lateralVelocity, referenceSpeed)

	local tire = self.Surface.Tire
	local normalizedLong = self.SlipRatio / tire.PeakSlipRatio
	local normalizedLat = (lateralVelocity / referenceSpeed) / tire.PeakSlipAngle
	local combinedSlip = math.sqrt(normalizedLong * normalizedLong + normalizedLat * normalizedLat)
	self.LongSlipNorm = normalizedLong
	self.LatSlipNorm = normalizedLat

	-- c) Le budget d'adhérence, unique et partagé.
	local frictionBudget = normalForce * mu * combinedGrip(combinedSlip, tire) * dt

	--[[
		d) Les impulsions DÉSIRÉES : celles qui annuleraient exactement chaque
		glissement. Le longitudinal tient compte des deux inerties (roue + quart de
		voiture), le latéral seulement de la masse.

		Si leur somme tient dans le budget, le pneu adhère : on les applique telles
		quelles. Sinon il glisse, et le budget se répartit selon la direction du
		glissement normalisé (voir CERCLE DE FRICTION).
		Chaque composante reste plafonnée à son impulsion d'annulation : c'est la
		propriété implicite du solveur, aucun glissement ne peut changer de signe
		ni osciller. Si un axe est ainsi plafonné (son glissement s'annule dans la
		frame), le budget qu'il n'utilise pas revient à l'autre axe : un pneu dont
		le glissement devient purement latéral pousse entièrement en latéral.
	]]
	local inverseEffectiveMass = (self.Radius * self.Radius / self.Inertia) + (1 / wheelMass)
	local desiredLong = slipVelocity / inverseEffectiveMass
	local desiredLat = -lateralVelocity * wheelMass
	local desiredMagnitude = math.sqrt(desiredLong * desiredLong + desiredLat * desiredLat)
	self.FrictionUsage = if frictionBudget > 0 then math.min(1, desiredMagnitude / frictionBudget) else 0

	local longitudinalImpulse = desiredLong
	local lateralImpulse = desiredLat
	if desiredMagnitude > frictionBudget then
		local absLong, absLat = math.abs(desiredLong), math.abs(desiredLat)
		local longCap, latCap
		if combinedSlip > 1e-6 then
			longCap = frictionBudget * math.abs(normalizedLong) / combinedSlip
			latCap = frictionBudget * math.abs(normalizedLat) / combinedSlip
		else
			longCap = frictionBudget * absLong / desiredMagnitude
			latCap = frictionBudget * absLat / desiredMagnitude
		end
		-- Budget non utilisé par un axe plafonné : rendu à l'autre (cercle exact).
		if absLong < longCap then
			latCap = math.sqrt(math.max(0, frictionBudget * frictionBudget - absLong * absLong))
		elseif absLat < latCap then
			longCap = math.sqrt(math.max(0, frictionBudget * frictionBudget - absLat * absLat))
		end
		longitudinalImpulse = math.sign(desiredLong) * math.min(absLong, longCap)
		lateralImpulse = math.sign(desiredLat) * math.min(absLat, latCap)
	end

	-- e) Troisième loi de Newton : ce que le sol pousse, le pneu le rend à la jante.
	self.AngularVelocity -= (longitudinalImpulse * self.Radius) / self.Inertia
	self.Chassis:ApplyImpulseAtPosition(forwardVector * longitudinalImpulse, contactPoint)

	-- Appliquée au centre de roulis, pas à l'empreinte : voir RollCenterHeight.
	local lateralApplicationPoint = contactPoint + upVector * self.RollCenterHeight
	self.Chassis:ApplyImpulseAtPosition(rightVector * lateralImpulse, lateralApplicationPoint)

	-- f) Frein et résistance au roulement, en dernier (voir _applyResistiveTorque).
	local resistiveTorque = (brakeForce + normalForce * self.Surface.RollingResistance) * self.Radius
	self:_applyResistiveTorque(dt, resistiveTorque)

	-- Roue bloquée : le frein l'a arrêtée alors que la voiture avance encore.
	local isLocked = brakeForce > 0
		and math.abs(self.AngularVelocity) < 0.5
		and math.abs(longitudinalVelocity) > 2

	-- 5. EFFETS VISUELS (Patinage / Drift)
	if smoke then
		-- Le pneu sature : il glisse, peu importe dans quelle direction.
		local isSliding = self.FrictionUsage >= 1 and math.abs(combinedSlip) > 1
		smoke.Enabled = isSliding or isLocked
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

	-- La jante suit la vraie vitesse angulaire : une roue bloquée s'arrête pour de
	-- bon, une roue qui patine s'emballe. L'avant étant en -Z, une rotation
	-- négative autour de X fait avancer le haut de la roue dans le sens de la marche.
	self.SpinAngle -= self.AngularVelocity * dt
	self.SpinAngle %= math.pi * 2

	motor.C0 = CFrame.new(localPosition) * CFrame.Angles(0, self.SteerAngle, 0) * CFrame.Angles(self.SpinAngle, 0, 0)
end

return Wheel
