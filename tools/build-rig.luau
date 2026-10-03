--[[
	build-rig.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée).
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil d'édition.

	Construit le gabarit attendu par Car.luau :

		RallyCar (Model)
		 ├── Chassis (PrimaryPart) : LA part physique, tout le reste est cosmétique
		 │    ├── WheelFL/FR/RL/RR (Attachments) + Smoke (ParticleEmitter)
		 │    └── MotorFL/FR/RL/RR (Motor6D) : pilotent les roues visuelles
		 ├── Ballast : lest invisible et dense, placé bas -> descend le centre de masse
		 ├── Body : carrosserie, Massless, sans collision (soudée au châssis)
		 └── TireFL/FR/RL/RR : roues visuelles + jantes, Massless, positionnées par le code

	PROPORTIONS D'UNE RALLY2 (type Fiesta), à 1 stud = 0.28 m (Units.luau) :
		longueur 14 studs (3.9 m) | largeur aux ailes 6.6 (1.85 m)
		empattement 8.9 (2.49 m)  | voie 5.5 (1.54 m)
	Rayon de roue gardé à 1 stud : il calibre la boîte (Powertrain.WheelRadius).
	Tout le reste du modèle physique se recale seul sur la masse et la géométrie
	(suspension, freins, aéro, Ackermann) : rien à retoucher ailleurs.

	GÉOMÉTRIE ANTI-TONNEAU — la voiture bascule quand  mu > demi_voie / hauteur_cdm.
	Ici : demi_voie = 2.75, hauteur du centre de masse au-dessus du contact ~ 1.79,
	soit un seuil de 1.54, bien au-dessus du mu maximal des surfaces (1.05 sur
	asphalte). La voiture glisse donc toujours avant de se retourner.
	(Avec l'ancien gabarit, voie de 4.8 : seuil 1.34.)

	Si le capot ou le pare-brise apparaissent "à l'envers" (pente vers l'arrière),
	inverser WEDGE_FLIP ci-dessous.
]]

local CollectionService = game:GetService("CollectionService")

local SPAWN_POSITION = Vector3.new(0, 6, 0)

local CHASSIS_SIZE = Vector3.new(6.0, 2, 14)
local CHASSIS_DENSITY = 1.0

-- Le lest est le vrai levier de stabilité : dense, bas, invisible.
local BALLAST_SIZE = Vector3.new(4.4, 0.6, 9)
local BALLAST_DENSITY = 6
local BALLAST_OFFSET = Vector3.new(0, -0.7, 0)

local HALF_TRACK = 2.75 -- X des roues (voie = 5.5)
local HALF_BASE = 4.45 -- Z des roues (empattement = 8.9), l'avant est en -Z
local WHEEL_RADIUS = 1.0
local WHEEL_WIDTH = 0.9
local WHEEL_REST_DROP = 1.12 -- hauteur de repos du centre de roue sous l'attache

-- Une WedgePart a sa face inclinée vers l'avant (-Z) : basse devant, haute derrière.
local WEDGE_FLIP = false

-- Livrée
local BODY = Color3.fromRGB(238, 238, 240)
local ACCENT = Color3.fromRGB(200, 30, 40)
local ACCENT2 = Color3.fromRGB(25, 60, 150)
local DARK = Color3.fromRGB(32, 32, 36)
local GLASS = Color3.fromRGB(20, 26, 36)
local RIM = Color3.fromRGB(205, 165, 60)
local RACE_NUMBER = "7"

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
-- Châssis : la seule part qui compte pour la physique (c'est aussi le bas de caisse)
--------------------------------------------------------------------------------

local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Size = CHASSIS_SIZE
chassis.Position = SPAWN_POSITION
chassis.Anchored = false -- OBLIGATOIRE : SetNetworkOwner refuse une part ancrée
chassis.CanCollide = true
chassis.Color = BODY
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
-- Carrosserie : Massless, sans collision, invisible aux raycasts.
-- Elle ne doit RIEN changer à la physique : masse, inertie et collision ne
-- viennent que du châssis et du lest.
--------------------------------------------------------------------------------

local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model

type Shape = "Block" | "Wedge" | "Cylinder"

local function cosmetic(
	name: string,
	shape: Shape,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		end
		part = block
	end
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = body
	weldTo(part, chassis)
	return part
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Rampe inclinée vers l'avant (capot, pare-brise) ou vers l'arrière (lunette).
local function slopeForward(x: number, y: number, z: number): CFrame
	return if WEDGE_FLIP then at(x, y, z) * CFrame.Angles(0, math.pi, 0) else at(x, y, z)
end
local function slopeBackward(x: number, y: number, z: number): CFrame
	return if WEDGE_FLIP then at(x, y, z) else at(x, y, z) * CFrame.Angles(0, math.pi, 0)
end

-- Le châssis va de y = -1 à +1, z = -7 (avant) à +7, x = -3 à +3.

-- Avant : capot plongeant, pare-chocs, phares, rampe de phares de rallye
cosmetic("Hood", "Wedge", Vector3.new(5.8, 0.8, 4.2), slopeForward(0, 1.4, -4.6), BODY)
cosmetic("HoodStripe", "Wedge", Vector3.new(1.4, 0.82, 4.22), slopeForward(0, 1.41, -4.6), ACCENT)
cosmetic("FrontBumper", "Block", Vector3.new(6.0, 1.0, 0.6), at(0, -0.45, -7.2), DARK)
for _, x in ipairs({ -2.1, 2.1 }) do
	cosmetic("Headlight", "Block", Vector3.new(1.1, 0.4, 0.1), at(x, 0.35, -7.05), Color3.fromRGB(250, 250, 235), Enum.Material.Neon)
end
for _, x in ipairs({ -2.1, -0.7, 0.7, 2.1 }) do
	-- Un cylindre a son axe sur X : tourné pour regarder vers l'avant.
	cosmetic("RallyLight", "Cylinder", Vector3.new(0.3, 0.9, 0.9), at(x, 1.15, -6.75) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
end

-- Habitacle : pare-brise, vitrage, lunette, toit, rétroviseurs
cosmetic("Windshield", "Wedge", Vector3.new(5.4, 1.9, 1.6), slopeForward(0, 2.35, -3.0), GLASS, Enum.Material.Glass, 0.2)
cosmetic("Greenhouse", "Block", Vector3.new(5.4, 1.9, 5.0), at(0, 2.35, 0.3), GLASS, Enum.Material.Glass, 0.2)
cosmetic("RearWindow", "Wedge", Vector3.new(5.4, 1.9, 1.4), slopeBackward(0, 2.35, 3.5), GLASS, Enum.Material.Glass, 0.2)
cosmetic("Roof", "Block", Vector3.new(5.5, 0.25, 5.4), at(0, 3.42, 0.35), BODY)
cosmetic("RoofStripe", "Block", Vector3.new(1.4, 0.27, 5.42), at(0, 3.43, 0.35), ACCENT)
for _, side in ipairs({ -1, 1 }) do
	cosmetic("Pillar", "Block", Vector3.new(0.25, 1.9, 0.3), at(side * 2.62, 2.35, -2.25), BODY)
	cosmetic("Pillar", "Block", Vector3.new(0.25, 1.9, 0.3), at(side * 2.62, 2.35, 2.75), BODY)
	cosmetic("Mirror", "Block", Vector3.new(0.5, 0.35, 0.45), at(side * 3.15, 1.95, -2.3), BODY)
end

-- Arrière : plage, aileron, pare-chocs, feux, échappement
cosmetic("RearDeck", "Block", Vector3.new(6.0, 0.4, 2.8), at(0, 1.2, 5.6), BODY)
cosmetic("RearBumper", "Block", Vector3.new(6.0, 1.0, 0.6), at(0, -0.45, 7.2), DARK)
for _, x in ipairs({ -2.2, 2.2 }) do
	cosmetic("TailLight", "Block", Vector3.new(1.0, 0.4, 0.1), at(x, 0.85, 7.05), Color3.fromRGB(220, 30, 30), Enum.Material.Neon)
end
cosmetic("Wing", "Block", Vector3.new(6.2, 0.18, 1.4), at(0, 3.95, 3.95), DARK)
for _, x in ipairs({ -2.0, 2.0 }) do
	cosmetic("WingPost", "Block", Vector3.new(0.25, 0.6, 0.6), at(x, 3.6, 3.95), DARK)
end
cosmetic("Exhaust", "Cylinder", Vector3.new(0.9, 0.45, 0.45), at(1.8, -0.75, 7.35) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)

-- Flancs : bande de livrée, numéro de course
for _, side in ipairs({ -1, 1 }) do
	cosmetic("SideStripe", "Block", Vector3.new(0.06, 0.35, 13.4), at(side * 3.02, 0.55, 0), ACCENT)
	cosmetic("SideStripe2", "Block", Vector3.new(0.06, 0.2, 13.4), at(side * 3.02, 0.15, 0), ACCENT2)
	local plate = cosmetic("NumberPlate", "Block", Vector3.new(0.06, 1.3, 1.7), at(side * 3.03, 0.3, -0.4), Color3.new(1, 1, 1))
	local gui = Instance.new("SurfaceGui")
	gui.Face = if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	gui.CanvasSize = Vector2.new(170, 130)
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = DARK
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = RACE_NUMBER
	label.Parent = gui
end

-- Ailes élargies au-dessus de chaque roue, et bavettes derrière
for _, z in ipairs({ -HALF_BASE, HALF_BASE }) do
	for _, side in ipairs({ -1, 1 }) do
		cosmetic("FenderFlare", "Block", Vector3.new(0.5, 1.1, 3.0), at(side * 3.15, 0.6, z), DARK)
		cosmetic("MudFlap", "Block", Vector3.new(0.9, 1.2, 0.08), at(side * HALF_TRACK, -1.15, z + 1.35), ACCENT2)
	end
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

	-- Jante + deux bâtons croisés : soudés au pneu, ils tournent avec lui. Une
	-- roue unie ne montre pas sa rotation ; ici on VOIT une roue bloquée ou
	-- qui patine.
	local function wheelDecor(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = tire.CFrame * offset
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Color = color
		part.Material = Enum.Material.Metal
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = tire
		weldTo(part, tire)
		return part
	end
	local rim = wheelDecor("Rim", Vector3.new(WHEEL_WIDTH + 0.06, 1.3, 1.3), CFrame.new(), RIM)
	rim.Shape = Enum.PartType.Cylinder
	wheelDecor("Spoke", Vector3.new(WHEEL_WIDTH + 0.1, 0.22, 1.25), CFrame.new(), DARK)
	wheelDecor("Spoke", Vector3.new(WHEEL_WIDTH + 0.1, 0.22, 1.25), CFrame.Angles(math.pi / 2, 0, 0), DARK)

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
