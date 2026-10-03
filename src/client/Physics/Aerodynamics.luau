--!strict
--[[
	Aerodynamics.luau
	Traînée, appui aérodynamique (downforce) et amortissement du lacet.

	Les coefficients sont "groupés" (lumped) : au lieu de 0.5 * rho * Cx * A, on
	stocke directement un k tel que  F = k * v²  (v en studs/s). Ils sont déduits du
	poids et de l'inertie réels du véhicule, pas écrits en dur : changer de gabarit
	ne demande aucun retuning.

	NOTE IMPORTANTE : l'appui ne protège PAS du tonneau. Il augmente la charge
	normale, donc l'adhérence latérale, donc le couple de renversement, exactement
	dans la même proportion. La condition de basculement (mu > demi_voie / hauteur)
	ne contient ni la masse ni l'appui -- c'est de la géométrie pure.
]]

local Aerodynamics = {}
Aerodynamics.__index = Aerodynamics

export type Aerodynamics = typeof(setmetatable({}, Aerodynamics)) & {
	DragCoefficient: number, -- traînée : F = k * v²
	DownforceFront: number, -- appui avant : F = k * vLongitudinale²
	DownforceRear: number, -- appui arrière
	CenterOfPressureFront: number, -- position (studs, axe Z local) du point d'application avant
	CenterOfPressureRear: number, -- idem à l'arrière
	YawDamping: number, -- stabilité en ligne droite : couple opposé au lacet, croît avec la vitesse
	MaxDownforce: number, -- garde-fou : appui total max, pour ne pas écraser la suspension
	Weight: number,
}

local REFERENCE_SPEED = 100 -- studs/s (~100 km/h, voir Units.luau) : vitesse à laquelle les ratios ci-dessous sont exprimés
local DOWNFORCE_RATIO = 0.25 -- appui total à REFERENCE_SPEED, en fraction du poids
--[[
	Traînée réelle d'une voiture de rallye avec aileron : SCx ~ 0.8 m², soit à
	100 km/h  0.5 * 1.225 * 0.8 * 27.8² ~ 380 N pour ~13 kN de poids -> 3 %.
	(L'ancienne valeur, 18 %, bridait surtout un moteur 3.5 fois trop puissant.)
]]
local DRAG_RATIO = 0.03 -- traînée à REFERENCE_SPEED, en fraction du poids
local REAR_BIAS = 0.6 -- plus d'appui à l'arrière = stabilité en appui et à haute vitesse

--[[
	Amortissement du lacet : décélération angulaire par (rad/s · stud/s), réglé
	à l'origine sous la gravité par défaut de Roblox (196.2). Il doit rester
	proportionnel aux forces de pneu, qui suivent la gravité : sans cette mise à
	l'échelle, sous gravité réelle il serait 5.6 fois trop fort relativement aux
	pneus et étoufferait toute mise en travers.
]]
local YAW_DAMPING_RATE_AT_ROBLOX_GRAVITY = 0.015
local ROBLOX_DEFAULT_GRAVITY = 196.2

function Aerodynamics.new(chassis: BasePart): Aerodynamics
	local self = (setmetatable({}, Aerodynamics) :: any) :: Aerodynamics

	local mass = chassis.AssemblyMass
	local weight = mass * workspace.Gravity
	local referencePressure = REFERENCE_SPEED * REFERENCE_SPEED

	self.DragCoefficient = (weight * DRAG_RATIO) / referencePressure
	self.Weight = weight
	self:SetDownforceRatio(DOWNFORCE_RATIO)

	local size = chassis.Size
	self.CenterOfPressureFront = size.Z * 0.35
	self.CenterOfPressureRear = size.Z * 0.4

	-- Le couple d'amortissement doit suivre l'inertie de lacet, sinon une grosse
	-- voiture tourne comme une toupie et une petite se fige.
	local yawInertia = (mass / 12) * (size.X * size.X + size.Z * size.Z)
	local yawDampingRate = YAW_DAMPING_RATE_AT_ROBLOX_GRAVITY * (workspace.Gravity / ROBLOX_DEFAULT_GRAVITY)
	self.YawDamping = yawInertia * yawDampingRate

	-- L'appui ne doit jamais talonner la suspension à lui seul.
	self.MaxDownforce = weight * 2

	return self
end

-- Appui total à REFERENCE_SPEED, en fraction du poids (réglable : CarSetup).
function Aerodynamics:SetDownforceRatio(ratio: number)
	local totalDownforce = (self.Weight * ratio) / (REFERENCE_SPEED * REFERENCE_SPEED)
	self.DownforceFront = totalDownforce * (1 - REAR_BIAS)
	self.DownforceRear = totalDownforce * REAR_BIAS
end

function Aerodynamics:Apply(chassis: BasePart, dt: number)
	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed < 0.1 then
		return
	end

	local cframe = chassis.CFrame

	-- 1. TRAÎNÉE : toujours opposée au vecteur vitesse réel, donc active aussi en travers.
	local dragForce = self.DragCoefficient * speed * speed
	chassis:ApplyImpulse(-velocity.Unit * dragForce * dt)

	-- 2. APPUI : basé sur la vitesse longitudinale seule (un aileron en crabe ne
	-- produit quasiment plus d'appui), appliqué vers le bas DU CHÂSSIS.
	local forwardSpeed = velocity:Dot(cframe.LookVector)
	local dynamicPressure = forwardSpeed * forwardSpeed

	local frontForce = self.DownforceFront * dynamicPressure
	local rearForce = self.DownforceRear * dynamicPressure

	local total = frontForce + rearForce
	if total > self.MaxDownforce and total > 0 then
		local scale = self.MaxDownforce / total
		frontForce *= scale
		rearForce *= scale
	end

	local down = -cframe.UpVector
	-- Roblox : LookVector = -Z, donc l'avant du châssis est à Z local négatif.
	chassis:ApplyImpulseAtPosition(down * frontForce * dt, cframe * Vector3.new(0, 0, -self.CenterOfPressureFront))
	chassis:ApplyImpulseAtPosition(down * rearForce * dt, cframe * Vector3.new(0, 0, self.CenterOfPressureRear))

	-- 3. AMORTISSEMENT DU LACET : stabilise la voiture en l'air et à haute vitesse.
	local yawAxis = cframe.UpVector
	local yawRate = chassis.AssemblyAngularVelocity:Dot(yawAxis)
	chassis:ApplyAngularImpulse(-yawAxis * yawRate * self.YawDamping * speed * dt)
end

return Aerodynamics
