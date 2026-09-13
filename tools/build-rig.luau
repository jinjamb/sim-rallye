--[[
	build-rig.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (View > Command Bar).
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil d'édition.

	Construit le gabarit attendu par Car.luau :

		RallyCar (Model)
		 ├── Chassis (PrimaryPart) : LA part physique, tout le reste est cosmétique
		 │    ├── WheelFL/FR/RL/RR (Attachments) + Smoke (ParticleEmitter)
		 │    └── MotorFL/FR/RL/RR (Motor6D) : pilotent les roues visuelles
		 ├── Ballast : lest invisible et dense, placé bas -> descend le centre de masse
		 ├── Cabin / Spoiler : cosmétiques, Massless
		 └── TireFL/FR/RL/RR : roues visuelles, Massless, positionnées par le code

	GÉOMÉTRIE ANTI-TONNEAU — la voiture bascule quand  mu > demi_voie / hauteur_cdm.
	Ici : demi_voie = 2.4, hauteur du centre de masse au-dessus du contact ~ 1.79,
	soit un seuil de 1.34, au-dessus du mu maximal des surfaces (1.05 sur asphalte).
	La voiture glisse donc toujours avant de se retourner, AVANT même l'aide
	apportée par le centre de roulis de Wheel.luau.
]]

local CollectionService = game:GetService("CollectionService")

local SPAWN_POSITION = Vector3.new(0, 6, 0)

local CHASSIS_SIZE = Vector3.new(5.5, 2, 12)
local CHASSIS_DENSITY = 1.0

-- Le lest est le vrai levier de stabilité : dense, bas, invisible.
local BALLAST_SIZE = Vector3.new(4, 0.6, 8)
local BALLAST_DENSITY = 6
local BALLAST_OFFSET = Vector3.new(0, -0.7, 0)

local HALF_TRACK = 2.4 -- X des roues (voie = 4.8)
local HALF_BASE = 4.2 -- Z des roues (empattement = 8.4), l'avant est en -Z
local WHEEL_RADIUS = 1.0
local WHEEL_WIDTH = 0.9
local WHEEL_REST_DROP = 1.12 -- hauteur de repos du centre de roue sous l'attache

local existing = workspace:FindFirstChild("RallyCar")
if existing then
	existing:Destroy()
end
local legacy = workspace:FindFirstChild("Chassis")
if legacy then
	legacy:Destroy()
end

local model = Instance.new("Model")
model.Name = "RallyCar"

local function weldTo(part: BasePart, target: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = target
end

--------------------------------------------------------------------------------
-- Châssis : la seule part qui compte pour la physique
--------------------------------------------------------------------------------

local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Size = CHASSIS_SIZE
chassis.Position = SPAWN_POSITION
chassis.Anchored = false -- OBLIGATOIRE : SetNetworkOwner refuse une part ancrée
chassis.CanCollide = true
chassis.Color = Color3.fromRGB(170, 45, 40)
chassis.Material = Enum.Material.SmoothPlastic
chassis.TopSurface = Enum.SurfaceType.Smooth
chassis.BottomSurface = Enum.SurfaceType.Smooth
chassis.CustomPhysicalProperties = PhysicalProperties.new(CHASSIS_DENSITY, 0.3, 0.1, 1, 1)
chassis.Parent = model

--------------------------------------------------------------------------------
-- Lest : descend le centre de masse sous le centre géométrique
--------------------------------------------------------------------------------

local ballast = Instance.new("Part")
ballast.Name = "Ballast"
ballast.Size = BALLAST_SIZE
ballast.CFrame = chassis.CFrame * CFrame.new(BALLAST_OFFSET)
ballast.Anchored = false
ballast.CanCollide = false
ballast.Transparency = 1
ballast.CustomPhysicalProperties = PhysicalProperties.new(BALLAST_DENSITY, 0.3, 0.1, 1, 1)
ballast.Parent = model
weldTo(ballast, chassis)

--------------------------------------------------------------------------------
-- Cosmétiques : Massless, ils ne doivent RIEN changer à l'inertie
--------------------------------------------------------------------------------

local COSMETICS = {
	{ Name = "Cabin", Size = Vector3.new(4.6, 1.6, 5), Offset = Vector3.new(0, 1.8, 0.5), Color = Color3.fromRGB(60, 60, 65) },
	{ Name = "Spoiler", Size = Vector3.new(5.2, 0.3, 1.2), Offset = Vector3.new(0, 2.0, 5.2), Color = Color3.fromRGB(30, 30, 30) },
	{ Name = "Hood", Size = Vector3.new(5.2, 0.3, 3.5), Offset = Vector3.new(0, 1.05, -3.8), Color = Color3.fromRGB(30, 30, 30) },
}

for _, spec in ipairs(COSMETICS) do
	local part = Instance.new("Part")
	part.Name = spec.Name
	part.Size = spec.Size
	part.CFrame = chassis.CFrame * CFrame.new(spec.Offset)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.Color = spec.Color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	weldTo(part, chassis)
end

--------------------------------------------------------------------------------
-- Roues : Attachment (physique) + Tire (visuel) + Motor6D (liaison)
--------------------------------------------------------------------------------

local ATTACHMENT_Y = -CHASSIS_SIZE.Y / 2

local WHEELS = {
	FL = Vector3.new(-HALF_TRACK, ATTACHMENT_Y, -HALF_BASE),
	FR = Vector3.new(HALF_TRACK, ATTACHMENT_Y, -HALF_BASE),
	RL = Vector3.new(-HALF_TRACK, ATTACHMENT_Y, HALF_BASE),
	RR = Vector3.new(HALF_TRACK, ATTACHMENT_Y, HALF_BASE),
}

for suffix, position in pairs(WHEELS) do
	local attachment = Instance.new("Attachment")
	attachment.Name = "Wheel" .. suffix
	attachment.Position = position
	attachment.Parent = chassis

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Enabled = false -- piloté par Wheel:ApplyForces
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 60
	smoke.Lifetime = NumberRange.new(0.6, 1.2)
	smoke.Speed = NumberRange.new(2, 6)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 3.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Acceleration = Vector3.new(0, 4, 0)
	smoke.Parent = attachment

	-- Un Part cylindrique a son axe sur X : c'est déjà l'axe de rotation d'une roue.
	local tire = Instance.new("Part")
	tire.Name = "Tire" .. suffix
	tire.Shape = Enum.PartType.Cylinder
	tire.Size = Vector3.new(WHEEL_WIDTH, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
	tire.Anchored = false
	tire.CanCollide = false -- la suspension raycast fait tout le travail
	tire.Massless = true
	tire.Color = Color3.fromRGB(25, 25, 28)
	tire.Material = Enum.Material.Rubber
	tire.CFrame = chassis.CFrame * CFrame.new(position + Vector3.new(0, WHEEL_RADIUS - WHEEL_REST_DROP, 0))
	tire.Parent = model

	-- Motor6D plutôt que Weld : le C0 est destiné à être réécrit chaque frame
	-- (débattement, braquage, rotation) par Wheel:UpdateVisual.
	local motor = Instance.new("Motor6D")
	motor.Name = "Motor" .. suffix
	motor.Part0 = chassis
	motor.Part1 = tire
	motor.C0 = CFrame.new(position + Vector3.new(0, WHEEL_RADIUS - WHEEL_REST_DROP, 0))
	motor.C1 = CFrame.new()
	motor.Parent = chassis
end

model.PrimaryPart = chassis
model.Parent = workspace
CollectionService:AddTag(chassis, "RallyCar")

task.wait() -- laisse la physique assembler les welds avant de lire masse et centre de masse

print(string.format(
	"[build-rig] %s | masse = %.0f | centre de masse Y = %.2f (relatif au châssis) | voie = %.1f | empattement = %.1f",
	model:GetFullName(),
	chassis.AssemblyMass,
	(chassis.CFrame:Inverse() * CFrame.new(chassis.AssemblyCenterOfMass)).Y,
	HALF_TRACK * 2,
	HALF_BASE * 2
))
