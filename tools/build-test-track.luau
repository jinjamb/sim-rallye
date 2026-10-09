--[[
	build-test-track.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (View > Command Bar).
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil d'édition.
	Rojo doit tourner (rojo serve) : le script lit Surfaces.luau dans ReplicatedStorage.

	Construit une piste d'essai sur la Baseplate : une bande par surface, côte à
	côte, triées de la plus adhérente à la moins adhérente, plus une bande
	"split-mu" (asphalte à gauche, verglas à droite) pour tester la stabilité au
	freinage et la répartition de couple quand les deux côtés n'adhèrent pas pareil.

	Les bandes courent le long de Z, comme la voiture au spawn (avant en -Z), et
	commencent à droite du spawn (+X). Elles sont jointives : on peut aussi les
	traverser en travers pour sentir le changement d'adhérence en plein virage.

	Les noms et coefficients affichés viennent de Surfaces.luau lui-même : si un
	matériau n'y est pas reconnu, son panneau affiche "Default", ce qui sert
	aussi de vérification de la table.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Surfaces = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicle"):WaitForChild("Surfaces"))

local MATERIALS = {
	Enum.Material.Asphalt,
	Enum.Material.Concrete,
	Enum.Material.Pavement,
	Enum.Material.Rock,
	Enum.Material.Slate,
	Enum.Material.Pebble,
	Enum.Material.Ground,
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Mud,
	Enum.Material.Sand,
	Enum.Material.Snow,
	Enum.Material.Glacier,
	Enum.Material.Ice,
}

local LANE_WIDTH = 15
local LANE_LENGTH = 440
local FIRST_LANE_X = 24 -- bord gauche de la première bande ; le spawn est en X = 0
local GROUND_TOP_Y = 0 -- dessus de la Baseplate (Position Y -10, épaisseur 20)

-- Assez fin pour que la marche entre Baseplate et bande ne secoue pas la suspension.
local PLATE_THICKNESS = 0.2

-- Panneaux : le long de chaque bande, pour savoir où on est en roulant.
local SIGN_POSITIONS_Z = { 180, 60, -60, -180 }
local SIGN_HEIGHT = 7

local existing = workspace:FindFirstChild("TestTrack")
if existing then
	existing:Destroy()
end

local track = Instance.new("Folder")
track.Name = "TestTrack"

local function makePlate(name: string, material: Enum.Material, color: Color3, centerX: number, width: number): Part
	local plate = Instance.new("Part")
	plate.Name = name
	plate.Anchored = true
	plate.Material = material
	plate.Color = color
	plate.Size = Vector3.new(width, PLATE_THICKNESS, LANE_LENGTH)
	plate.Position = Vector3.new(centerX, GROUND_TOP_Y + PLATE_THICKNESS / 2, 0)
	plate.TopSurface = Enum.SurfaceType.Smooth
	plate.BottomSurface = Enum.SurfaceType.Smooth
	plate.Parent = track
	return plate
end

local function makeSign(text: string, centerX: number)
	for _, z in ipairs(SIGN_POSITIONS_Z) do
		-- Point d'ancrage invisible et non collidable : le raycast de suspension
		-- ignore CanCollide, donc on le place bien au-dessus de la hauteur des roues.
		local anchor = Instance.new("Part")
		anchor.Name = "Sign"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = Vector3.new(centerX, GROUND_TOP_Y + SIGN_HEIGHT, z)
		anchor.Parent = track

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(160, 44)
		billboard.MaxDistance = 250
		billboard.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
		label.BackgroundTransparency = 0.3
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = text
		label.Parent = billboard
	end
end

local function laneCenterX(index: number): number
	return FIRST_LANE_X + (index - 0.5) * LANE_WIDTH
end

-- Tri par adhérence décroissante, d'après la table elle-même.
table.sort(MATERIALS, function(a, b)
	return Surfaces.Get(a).Grip > Surfaces.Get(b).Grip
end)

for index, material in ipairs(MATERIALS) do
	local surface = Surfaces.Get(material)
	local x = laneCenterX(index)
	makePlate(surface.Name, material, surface.DustColor, x, LANE_WIDTH)
	makeSign(string.format("%s  μ %.2f", surface.Name, surface.Grip), x)
end

-- Bande split-mu : deux demi-bandes, roues gauches sur l'une, droites sur l'autre
-- (voie de la voiture = 4.8, chaque demi-bande fait 7.5 de large).
local splitIndex = #MATERIALS + 1
local splitX = laneCenterX(splitIndex)
local high = Surfaces.Get(Enum.Material.Asphalt)
local low = Surfaces.Get(Enum.Material.Ice)
makePlate("SplitMu-" .. high.Name, Enum.Material.Asphalt, high.DustColor, splitX - LANE_WIDTH / 4, LANE_WIDTH / 2)
makePlate("SplitMu-" .. low.Name, Enum.Material.Ice, low.DustColor, splitX + LANE_WIDTH / 4, LANE_WIDTH / 2)
makeSign(string.format("Split-μ  %.2f | %.2f", high.Grip, low.Grip), splitX)

track.Parent = workspace

local lastEdge = FIRST_LANE_X + splitIndex * LANE_WIDTH
print(string.format(
	"[build-test-track] %d bandes de X = %d à X = %d, Z de %d à %d. Depuis le spawn : tourner à droite.",
	splitIndex,
	FIRST_LANE_X,
	lastEdge,
	-LANE_LENGTH / 2,
	LANE_LENGTH / 2
))
if lastEdge > 256 then
	warn("[build-test-track] La piste dépasse la Baseplate (512 x 512) : réduire LANE_WIDTH")
end
