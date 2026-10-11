--!strict
--[[
	PaddockScenery.luau
	Le décor du paddock d'accueil (PaddockService le construit au démarrage,
	dans workspace.Paddock.Scenery). Deux rôles :

	FERMER LA VUE : depuis l'accueil, on ne doit voir que l'accueil, pas la
	piste d'essai (à l'est, X > 24) ni les places des voitures et le départ de
	la spéciale (au sud). Le paddock est donc entouré :
		- à l'est, le bâtiment des stands, haut de 13 studs ;
		- au sud, deux tribunes pleines de public, et derrière elles un rideau
		  d'arbres ;
		- au nord et à l'ouest, des rangées d'arbres jusqu'au bord de la
		  Baseplate (au-delà, les collines de la spéciale font l'horizon).
	Les voitures entrent et sortent par le coin sud-est, sous un torii ; le
	rideau d'arbres en quinconce derrière cache ce qu'il y a plus loin.

	ANIMER : tentes et camions des équipes, voitures exposées sur leurs
	plaques (les modèles du jeu : Hayate, Kaze, Hoshi), oriflammes,
	lanternes, cerisiers en fleur, piles de pneus, mâts d'éclairage.

	Rien de ce décor ne touche aux zones (PaddockLayout.luau) : les pads, le
	garage, le podium et la vue de sa caméra restent dégagés.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scenery = require(ReplicatedStorage.Shared.World.Scenery)
local PaddockLayout = require(ReplicatedStorage.Shared.Paddock.PaddockLayout)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local LiveryPainter = require(ReplicatedStorage.Shared.Cosmetics.LiveryPainter)

local PaddockScenery = {}

local SEED = 2024
local BASE_HALF = 256 -- demi-côté de la Baseplate
local GRASS = Color3.fromRGB(96, 150, 72)

local function slab(parent: Instance, name: string, minX: number, maxX: number, minZ: number, maxZ: number, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = Vector3.new(maxX - minX, 0.2, maxZ - minZ)
	part.Position = Vector3.new((minX + maxX) / 2, 0.1, (minZ + maxZ) / 2)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

-- Une rangée d'arbres de (x0, z0) à (x1, z1), un tous les `spacing` studs, en quinconce.
local function treeRow(parent: Instance, rng: Random, x0: number, z0: number, x1: number, z1: number, spacing: number, sakura: number, depth: number?)
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	local count = math.max(1, math.floor(length / spacing))
	local across = Vector3.new(-dz, 0, dx) / math.max(length, 1e-6)
	for i = 0, count do
		local t = i / count
		local offset = across * ((if i % 2 == 0 then 1 else -1) * (depth or 3) + rng:NextNumber(-1, 1))
		local spot = Vector3.new(x0 + dx * t, 0.2, z0 + dz * t) + offset
		Scenery.Tree(parent, spot, rng, Scenery.PickKind(rng, sakura), rng:NextNumber(1, 1.35))
	end
end

local function colorIndex(name: string): number
	for index, swatch in ipairs(Livery.COLORS) do
		if swatch.Name == name then
			return index
		end
	end
	return 1
end

-- Les voitures exposées : les trois modèles de l'image de référence.
local SHOWCASE = {
	{ Body = 5, Color = "Rouge corsa", Number = 7, Wing = 4, Hood = 2, Bumper = 2, Rims = 2, Z = 80 },
	{ Body = 2, Color = "Blanc", Number = 1, Wing = 3, Hood = 1, Bumper = 3, Rims = 4, Z = 102 },
	{ Body = 6, Color = "Bleu", Number = 55, Wing = 4, Hood = 3, Bumper = 1, Rims = 1, Z = 124 },
}
local SHOWCASE_X = -36

local function showcaseCar(parent: Instance, template: Model, entry: typeof(SHOWCASE[1]))
	local car = template:Clone()
	for _, item in ipairs(car:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanTouch = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	car.Name = "ShowcaseCar"
	-- Plaque tournante sous la voiture.
	local base = Vector3.new(SHOWCASE_X, 0.2, entry.Z)
	local plate = Instance.new("Part")
	plate.Name = "ShowcasePlate"
	plate.Shape = Enum.PartType.Cylinder
	plate.Anchored = true
	plate.CanTouch = false
	plate.Size = Vector3.new(0.8, 18, 18)
	plate.CFrame = CFrame.new(base + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	plate.Color = Color3.fromRGB(36, 37, 44)
	plate.Material = Enum.Material.DiamondPlate
	plate.Parent = parent
	local ring = plate:Clone()
	ring.Name = "ShowcaseRing"
	ring.Size = Vector3.new(0.6, 19.4, 19.4)
	ring.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Neon
	ring.Color = Scenery.SAKURA
	ring.CanCollide = false
	ring.Parent = parent
	-- Nez tourné vers le centre du paddock, de trois quarts.
	local target = base + Vector3.new(-30, 0, 18)
	car:PivotTo(CFrame.lookAt(base + Vector3.new(0, 10, 0), Vector3.new(target.X, 10, target.Z)))
	car.Parent = parent
	local livery = Livery.Default(0)
	livery.Body = entry.Body
	livery.Color = colorIndex(entry.Color)
	livery.Number = entry.Number
	livery.Wing = entry.Wing
	livery.Hood = entry.Hood
	livery.Bumper = entry.Bumper
	livery.Rims = entry.Rims
	livery.Stripes = 2
	LiveryPainter.Prepare(car)
	LiveryPainter.Apply(car, livery)
	-- Posée sur la plaque : le bas de la voiture (les roues) au ras du dessus.
	local cframe, size = car:GetBoundingBox()
	local bottom = cframe.Position.Y - size.Y / 2
	car:PivotTo(car:GetPivot() + Vector3.new(0, 0.8 - bottom, 0))
end

function PaddockScenery.Build(paddock: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	local rng = Random.new(SEED)
	local plazaMin = PaddockLayout.PLAZA_CENTER - Vector3.new(PaddockLayout.PLAZA_SIZE.X / 2, 0, PaddockLayout.PLAZA_SIZE.Y / 2)
	local plazaMax = PaddockLayout.PLAZA_CENTER + Vector3.new(PaddockLayout.PLAZA_SIZE.X / 2, 0, PaddockLayout.PLAZA_SIZE.Y / 2)
	local west, east = plazaMin.X, plazaMax.X -- -245, -15
	local south, north = plazaMin.Z, plazaMax.Z -- 45, 235

	-- Pelouse autour de la dalle : plus de Baseplate grise en vue.
	slab(folder, "Lawn", -BASE_HALF, west, -10, BASE_HALF, GRASS, Enum.Material.Grass)
	slab(folder, "Lawn", west, 24, north, BASE_HALF, GRASS, Enum.Material.Grass)
	slab(folder, "Lawn", east, 24, -10, north, GRASS, Enum.Material.Grass)
	slab(folder, "Lawn", west, east, -10, south, GRASS, Enum.Material.Grass)

	-- EST : le bâtiment des stands, façade vers le paddock.
	Scenery.PitBuilding(folder, CFrame.lookAt(Vector3.new(east + 9, 0, 158), Vector3.new(east - 10, 0, 158)), 150, "PADDOCK · ラリー")

	-- SUD : deux tribunes face aux zones de course, l'entrée des voitures au coin sud-est.
	local standZ = south - 9
	Scenery.Grandstand(folder, CFrame.lookAt(Vector3.new(-197, 0, standZ), Vector3.new(-197, 0, standZ + 10)), 84, 6, rng, "RALLYCROSS ラリー")
	Scenery.Grandstand(folder, CFrame.lookAt(Vector3.new(-104, 0, standZ), Vector3.new(-104, 0, standZ + 10)), 84, 6, rng, "SAISON 1 · さくら")
	Scenery.Torii(folder, CFrame.new(Vector3.new(-37, 0, south - 2)), 30, 18)
	-- Rideau d'arbres derrière les tribunes, et en quinconce derrière l'entrée.
	treeRow(folder, rng, -250, 14, -60, 14, 9, 0.1, 4)
	treeRow(folder, rng, -60, -2, 20, -2, 8, 0.1, 5)
	treeRow(folder, rng, 4, 0, 4, 78, 8, 0.05, 4)
	-- Haie entre les troncs : les panneaux de la piste d'essai ne passent plus.
	for z = 0, 80, 5 do
		Scenery.Tree(folder, Vector3.new(10, 0.2, z), rng, "Bush", 1.5)
	end

	-- NORD et OUEST : rangées d'arbres jusqu'au bord, cerisiers près du spawn.
	treeRow(folder, rng, -250, 246, 16, 246, 9, 0.35, 4)
	treeRow(folder, rng, -251, 20, -251, 240, 9, 0.2, 2)
	treeRow(folder, rng, 14, 70, 14, 240, 10, 0.1, 4)

	-- Tentes d'équipe (au nord, face au spawn) et leurs camions derrière.
	local teams = { "TEAM KAZE", "YAMA WORKS", "RAIJIN GP", "HAYATE RT", "HOSHI SPORT", "SAKURA RACING" }
	for i, name in ipairs(teams) do
		local x = -158 + (i - 1) * 25
		local color = Scenery.TEAM_COLORS[((i - 1) % #Scenery.TEAM_COLORS) + 1]
		Scenery.Tent(folder, CFrame.lookAt(Vector3.new(x, 0.2, 216), Vector3.new(x, 0.2, 200)), 14, 10, color, name)
		Scenery.Flag(folder, Vector3.new(x + 8.5, 0.2, 209), color, Vector3.new(0, 0, -1))
	end
	for i, x in ipairs({ -140, -95, -50 }) do
		Scenery.Truck(folder, CFrame.lookAt(Vector3.new(x, 0.2, 232), Vector3.new(x + 10, 0.2, 232)), Scenery.TEAM_COLORS[i], teams[i * 2])
	end

	-- Allée du spawn : lanternes et cerisiers de part et d'autre.
	local spawn = PaddockLayout.SPAWN
	for _, side in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -12, 6 }) do
			Scenery.Lantern(folder, Vector3.new(spawn.X + side * 13, 0.2, spawn.Z + dz))
		end
		Scenery.Tree(folder, Vector3.new(spawn.X + side * 24, 0.2, spawn.Z + 14), rng, "Sakura", 1.2)
	end

	-- Oriflammes le long des zones de course, piles de pneus, mâts d'éclairage.
	for i, x in ipairs({ -200, -152, -108, -62 }) do
		Scenery.Flag(folder, Vector3.new(x, 0.2, 112), Scenery.TEAM_COLORS[(i % 4) + 1], Vector3.new(0, 0, 1))
	end
	for _, spot in ipairs({ Vector3.new(-236, 0.2, 60), Vector3.new(-160, 0.2, 58), Vector3.new(-58, 0.2, 58), Vector3.new(-24, 0.2, 150), Vector3.new(-236, 0.2, 200) }) do
		Scenery.TireStack(folder, spot, rng)
		Scenery.TireStack(folder, spot + Vector3.new(3.6, 0, 0.5), rng)
	end
	for _, corner in ipairs({ Vector3.new(west + 4, 0.2, south + 4), Vector3.new(west + 4, 0.2, north - 4), Vector3.new(east - 4, 0.2, north - 4), Vector3.new(-66, 0.2, south + 7) }) do
		local toward = (PaddockLayout.PLAZA_CENTER - corner) * Vector3.new(1, 0, 1)
		Scenery.LightTower(folder, corner, (toward.Unit + Vector3.new(0, -0.6, 0)).Unit)
	end

	folder.Parent = paddock

	-- Voitures exposées : le gabarit est rangé par CarService.Start, lancé juste après.
	-- La peinture lance des rayons sur la voiture : elle doit être dans le monde.
	task.defer(function()
		local template = ReplicatedStorage:WaitForChild("CarTemplate", 15)
		if not template or not template:IsA("Model") then
			return
		end
		while not folder:IsDescendantOf(workspace) do
			if folder.Parent == nil and paddock.Parent == nil then
				return
			end
			task.wait()
		end
		for _, entry in ipairs(SHOWCASE) do
			local ok, problem = pcall(showcaseCar, folder, template, entry)
			if not ok then
				warn("[PaddockScenery] voiture exposée : " .. tostring(problem))
			end
		end
	end)
end

return PaddockScenery
