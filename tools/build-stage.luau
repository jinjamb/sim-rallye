--[[
	build-stage.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée).
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil d'édition.
	Rojo doit tourner (rojo serve) : le tracé est lu dans
	ReplicatedStorage.Shared.Stage.StageTrack, le même module que le chrono.

	Génère la spéciale en terrain, au bout de la Baseplate (cap -Z depuis le spawn),
	puis pose départ, arrivée, inters et balises dans workspace.Stage.
	Relançable autant de fois que voulu : il réécrit toute la zone.

	MÉTHODE : CHAMP DE HAUTEUR.
	La première version empilait des blocs (FillBlock) tournés selon le cap. Sur
	une grille de voxels de 4 studs, leurs bords se raccordaient mal dans les
	virages en pente : des marches de 1 à 2 studs, soit 30 à 50 cm à l'échelle
	de la voiture, qui la faisaient sauter en permanence.
	Ici, on calcule d'abord la hauteur exacte du sol pour chaque colonne de
	4 x 4 studs, puis on écrit les voxels d'un coup (WriteVoxels) avec une
	OCCUPATION FRACTIONNAIRE pour le voxel de surface : le terrain lisse de
	Roblox place alors la surface à la hauteur voulue, au sein du voxel, au
	lieu de l'arrondir à la grille. Plus de marches.

	PROFIL EN TRAVERS d'une colonne, selon son écart latéral à l'axe :
		route (|écart| <= demi-largeur)    : hauteur du tracé, surface du segment
		accotement plat                    : même hauteur, en herbe
		bord du couloir                    : arrondi qui descend de SHOULDER_DROP
		talus                              : pente douce jusqu'au fond de vallée
	Fini les falaises au bord du couloir : une sortie de route se termine dans
	un talus, pas dans le vide.
	Là où deux portions du tracé se rapprochent (épingles), chaque colonne prend
	la plus haute des propositions -- sauf la route, toujours à sa hauteur exacte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
--[[
	On charge une COPIE du module, pas le module lui-même : dans Studio,
	`require` garde un module en cache pour toute la session. Après une
	modification du tracé synchronisée par Rojo, la barre de commandes
	relirait sinon l'ancienne version, chargée à la première exécution.
	Le clone est un nouvel objet : il est réexécuté à chaque fois.
]]
local stageTrackModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stage"):WaitForChild("StageTrack")
local StageTrack = require(stageTrackModule:Clone())

local terrain = workspace.Terrain
local samples = StageTrack.GetSamples()
local step = StageTrack.SAMPLE_STEP
local roadHalf = StageTrack.ROAD_WIDTH / 2
local corridorHalf = StageTrack.CORRIDOR_WIDTH / 2

local VOXEL = 4
local CHUNK = 64 -- colonnes par bloc d'écriture (64 x 64 x hauteur)
local FLAT_HALF = corridorHalf - 12 -- accotement plat, avant l'arrondi
local SHOULDER_DROP = 6 -- l'arrondi du bord du couloir descend de ça
local EMBANK_SLOPE = 0.6 -- pente du talus (studs de descente par stud)
local EMBANK_REACH = 60 -- largeur du talus au-delà du couloir
local FLOOR_DEPTH = 8 -- le fond de vallée est à (point le plus bas du tracé - ça)
local SHOULDER_MATERIAL = Enum.Material.Grass
local SUBSOIL_MATERIAL = Enum.Material.Ground -- visible seulement dans les talus raides
local SURFACE_LAYER = 8 -- épaisseur peinte avec le matériau de surface
-- Balises de bord de route : rapprochées, elles rythment la vitesse.
local MARKER_SPACING = 20

--[[
	DÉCOR. La vitesse se lit à ce qui défile dans la vision périphérique : une
	herbe uniforme ne donne aucun repère. Deux couches :
		- rochers sur l'accotement, près de la route : ils défilent vite dans
		  le champ. Décor pur, sans collision (pas de casse sur une erreur de
		  quelques studs) ;
		- arbres dans les talus, au-delà du couloir : ils donnent la profondeur.
		  Troncs solides : une grosse sortie de route doit coûter.
	Placement pseudo-aléatoire mais reproductible (graine fixe).
]]
local DECOR_SEED = 1973
local ROCK_SPACING, ROCK_DENSITY = 10, 0.35
local ROCK_LATERAL_MIN, ROCK_LATERAL_MAX = 18, 46
local TREE_SPACING, TREE_DENSITY = 14, 0.55
local TREE_LATERAL_MIN, TREE_LATERAL_MAX = 62, 105
-- Un objet de décor ne doit jamais tomber sur une AUTRE portion de route
-- (épingles) : distance minimale à l'axe du tracé le plus proche.
local ROCK_CLEARANCE = 16
local TREE_CLEARANCE = 58
-- Au bout du tracé : plateau d'herbe dans le prolongement, puis talus. Sans
-- lui, une voiture qui ne s'arrête pas après l'arrivée tombe dans le vide.
local END_PLATEAU = 120
-- Le fond de vallée s'étend bien au-delà des talus : une grosse sortie de route
-- doit finir dans l'herbe, pas au bord du monde.
local FLOOR_MARGIN = 200

local startClock = os.clock()

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

--------------------------------------------------------------------------------
-- 1. Grille des colonnes
--------------------------------------------------------------------------------

local stampHalf = corridorHalf + EMBANK_REACH
local minSX, maxSX, minSZ, maxSZ = math.huge, -math.huge, math.huge, -math.huge
local minSY, maxSY = math.huge, -math.huge
for _, sample in ipairs(samples) do
	local p = sample.Position
	minSX, maxSX = math.min(minSX, p.X), math.max(maxSX, p.X)
	minSZ, maxSZ = math.min(minSZ, p.Z), math.max(maxSZ, p.Z)
	minSY, maxSY = math.min(minSY, p.Y), math.max(maxSY, p.Y)
end

-- Alignée sur la grille des voxels de terrain (multiples de 4).
local worldMargin = stampHalf + FLOOR_MARGIN
local minX = math.floor((minSX - worldMargin) / VOXEL) * VOXEL
local maxX = math.ceil((maxSX + worldMargin) / VOXEL) * VOXEL
local minZ = math.floor((minSZ - worldMargin) / VOXEL) * VOXEL
local maxZ = math.ceil((maxSZ + worldMargin) / VOXEL) * VOXEL
local nx = (maxX - minX) / VOXEL
local nz = (maxZ - minZ) / VOXEL

local floorY = minSY - FLOOR_DEPTH
local yMin = math.floor((floorY - VOXEL) / VOXEL) * VOXEL
local yMax = math.ceil((maxSY + 2 * VOXEL) / VOXEL) * VOXEL
local ny = (yMax - yMin) / VOXEL

local function columnIndex(ix: number, iz: number): number
	return (ix - 1) * nz + iz
end

local heights = table.create(nx * nz, floorY) -- hauteur proposée (max des propositions)
local roadHeight: { [number]: number } = {}
local roadMaterial: { [number]: Enum.Material } = {}
local roadDistanceSq: { [number]: number } = {}

--------------------------------------------------------------------------------
-- 2. Hauteur de chaque colonne
--------------------------------------------------------------------------------

for sampleIndex, sample in ipairs(samples) do
	local p = sample.Position
	local forward, left = sample.ForwardFlat, sample.Left
	local horizontal = math.sqrt(sample.Forward.X ^ 2 + sample.Forward.Z ^ 2)
	local slope = if horizontal > 1e-6 then sample.Forward.Y / horizontal else 0
	local curvature = math.abs(sample.Curvature)
	-- Le dernier échantillon couvre en plus le plateau de fin et son talus.
	local isLast = sampleIndex == #samples
	local reach = if isLast then stampHalf + END_PLATEAU else stampHalf

	local ix0 = math.max(1, math.floor((p.X - reach - minX) / VOXEL) + 1)
	local ix1 = math.min(nx, math.ceil((p.X + reach - minX) / VOXEL))
	local iz0 = math.max(1, math.floor((p.Z - reach - minZ) / VOXEL) + 1)
	local iz1 = math.min(nz, math.ceil((p.Z + reach - minZ) / VOXEL))

	for ix = ix0, ix1 do
		local dx = minX + (ix - 0.5) * VOXEL - p.X
		for iz = iz0, iz1 do
			local dz = minZ + (iz - 0.5) * VOXEL - p.Z
			local lateral = math.abs(dx * left.X + dz * left.Z)
			if lateral <= stampHalf then
				local along = dx * forward.X + dz * forward.Z
				-- Chaque échantillon ne couvre que sa "tranche" de route. Sur
				-- l'extérieur d'un virage les tranches s'écartent en éventail :
				-- on les élargit avec l'écart latéral pour ne laisser aucun trou.
				local sliceHalf = (step / 2) * (1 + lateral * curvature) + 1
				local inSlice = math.abs(along) <= sliceHalf
				-- Au-delà du bout du tracé : plateau à hauteur constante, puis
				-- un talus qui s'arrondit avant de descendre.
				local beyondEnd = isLast and along > sliceHalf
				if beyondEnd then
					inSlice = along <= END_PLATEAU + EMBANK_REACH
				end
				if inSlice then
					local index = columnIndex(ix, iz)
					local h = if beyondEnd then p.Y else p.Y + along * slope
					local endDrop = 0
					if beyondEnd and along > END_PLATEAU then
						local past = along - END_PLATEAU
						endDrop = SHOULDER_DROP * smoothstep(math.min(1, past / 12)) + math.max(0, past - 12) * EMBANK_SLOPE
					end

					if not beyondEnd and lateral <= roadHalf + 1 then
						local distanceSq = along * along + lateral * lateral
						local best = roadDistanceSq[index]
						if best == nil or distanceSq < best then
							roadDistanceSq[index] = distanceSq
							roadHeight[index] = h
							roadMaterial[index] = sample.Material
						end
					end

					local proposal
					if lateral <= FLAT_HALF then
						proposal = h
					elseif lateral <= corridorHalf then
						proposal = h - SHOULDER_DROP * smoothstep((lateral - FLAT_HALF) / (corridorHalf - FLAT_HALF))
					else
						proposal = h - SHOULDER_DROP - (lateral - corridorHalf) * EMBANK_SLOPE
					end
					proposal -= endDrop
					if proposal > heights[index] then
						heights[index] = proposal
					end
				end
			end
		end
	end

	if sampleIndex % 40 == 0 then
		task.wait()
	end
end

--------------------------------------------------------------------------------
-- 3. Écriture des voxels, par blocs (elle remplace aussi l'ancien terrain :
--    toute la zone est réécrite, air compris)
--------------------------------------------------------------------------------

for cx = 1, nx, CHUNK do
	local sx = math.min(CHUNK, nx - cx + 1)
	for cz = 1, nz, CHUNK do
		local sz = math.min(CHUNK, nz - cz + 1)
		local materials = table.create(sx)
		local occupancies = table.create(sx)

		for i = 1, sx do
			local matPlane = table.create(ny)
			local occPlane = table.create(ny)
			for j = 1, ny do
				matPlane[j] = table.create(sz)
				occPlane[j] = table.create(sz)
			end
			materials[i] = matPlane
			occupancies[i] = occPlane

			for k = 1, sz do
				local index = columnIndex(cx + i - 1, cz + k - 1)
				local roadH = roadHeight[index]
				local h = roadH or heights[index]
				local surfaceMaterial = if roadH then roadMaterial[index] else SHOULDER_MATERIAL

				for j = 1, ny do
					local bottom = yMin + (j - 1) * VOXEL
					-- Occupation fractionnaire du voxel de surface : c'est elle qui
					-- place la surface à la bonne hauteur à l'intérieur du voxel.
					local occupancy = math.clamp((h - bottom) / VOXEL, 0, 1)
					occPlane[j][k] = occupancy
					if occupancy <= 0 then
						matPlane[j][k] = Enum.Material.Air
					elseif bottom >= h - SURFACE_LAYER then
						matPlane[j][k] = surfaceMaterial
					else
						matPlane[j][k] = SUBSOIL_MATERIAL
					end
				end
			end
		end

		local regionMin = Vector3.new(minX + (cx - 1) * VOXEL, yMin, minZ + (cz - 1) * VOXEL)
		local regionMax = regionMin + Vector3.new(sx * VOXEL, ny * VOXEL, sz * VOXEL)
		terrain:WriteVoxels(Region3.new(regionMin, regionMax), VOXEL, materials, occupancies)
		task.wait()
	end
end

--------------------------------------------------------------------------------
-- 4. Signalétique (décor pur : ni collision, ni raycast de suspension)
--------------------------------------------------------------------------------

local existing = workspace:FindFirstChild("Stage")
if existing then
	existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Stage"

local function ghostPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- invisible pour les raycasts de suspension
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local function banner(part: Part, text: string, color: Color3)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(800, 120)
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = color
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = text
		label.Parent = gui
	end
end

-- Portique au-dessus de la route, à une abscisse donnée.
local function gate(name: string, distance: number, text: string, color: Color3)
	local sample = StageTrack.SampleAt(distance)
	local base = sample.Position
	local postHeight = 14
	local halfSpan = roadHalf + 3
	for _, side in ipairs({ -1, 1 }) do
		local position = base + sample.Left * (halfSpan * side) + Vector3.new(0, postHeight / 2, 0)
		ghostPart(name .. "Post", Vector3.new(1.5, postHeight, 1.5), CFrame.new(position), color)
	end
	local bannerCenter = base + Vector3.new(0, postHeight - 1.5, 0)
	local bannerPart = ghostPart(
		name .. "Banner",
		Vector3.new(halfSpan * 2 + 1.5, 3, 0.5),
		CFrame.lookAt(bannerCenter, bannerCenter + sample.ForwardFlat),
		color
	)
	banner(bannerPart, text, color)
end

local timedLength = StageTrack.GetFinishDistance() - StageTrack.START_DISTANCE
gate("Start", StageTrack.START_DISTANCE, "DÉPART", Color3.fromRGB(40, 160, 70))
for index, fraction in ipairs(StageTrack.SPLITS) do
	gate("Split" .. index, StageTrack.START_DISTANCE + timedLength * fraction, "INTER " .. index, Color3.fromRGB(50, 110, 200))
end
gate("Finish", StageTrack.GetFinishDistance(), "ARRIVÉE", Color3.fromRGB(200, 50, 45))

-- Balises de bord de route, alternées rouge/blanc : elles dessinent la route
-- au loin et donnent la sensation de vitesse.
local markerCount = 0
for distance = 0, StageTrack.GetLength(), MARKER_SPACING do
	local sample = StageTrack.SampleAt(distance)
	markerCount += 1
	local color = if markerCount % 2 == 0 then Color3.fromRGB(220, 40, 40) else Color3.fromRGB(240, 240, 240)
	for _, side in ipairs({ -1, 1 }) do
		local position = sample.Position + sample.Left * ((roadHalf + 2) * side) + Vector3.new(0, 1.5, 0)
		ghostPart("Marker", Vector3.new(0.6, 3, 0.6), CFrame.new(position), color)
	end
end

-- Hauteur du sol généré en un point (lue dans le champ de hauteur).
local function groundHeightAt(x: number, z: number): number?
	local ix = math.floor((x - minX) / VOXEL) + 1
	local iz = math.floor((z - minZ) / VOXEL) + 1
	if ix < 1 or ix > nx or iz < 1 or iz > nz then
		return nil
	end
	local index = columnIndex(ix, iz)
	return roadHeight[index] or heights[index]
end

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = folder
local rng = Random.new(DECOR_SEED)

local function decorPart(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, solid: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid -- Roblox impose CanQuery = true sur une part solide
	part.CanTouch = false
	part.CastShadow = solid
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = decor
	return part
end

-- Point de décor valide : sur le terrain généré, et loin de TOUTE portion de route.
local function decorSpot(sample: StageTrack.Sample, lateral: number, clearance: number): Vector3?
	local position = sample.Position + sample.Left * lateral + sample.ForwardFlat * rng:NextNumber(-4, 4)
	local _, _, nearestLateral = StageTrack.Locate(position)
	if math.abs(nearestLateral) < clearance then
		return nil
	end
	local ground = groundHeightAt(position.X, position.Z)
	if ground == nil then
		return nil
	end
	return Vector3.new(position.X, ground, position.Z)
end

local rockCount, treeCount = 0, 0
local trackLength = StageTrack.GetLength()

for distance = 0, trackLength, ROCK_SPACING do
	local sample = StageTrack.SampleAt(distance)
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < ROCK_DENSITY then
			local spot = decorSpot(sample, side * rng:NextNumber(ROCK_LATERAL_MIN, ROCK_LATERAL_MAX), ROCK_CLEARANCE)
			if spot then
				local size = rng:NextNumber(1.2, 3.5)
				local grey = rng:NextInteger(95, 135)
				decorPart(
					"Rock",
					Enum.PartType.Ball,
					Vector3.new(size, size, size),
					CFrame.new(spot + Vector3.new(0, size * 0.25, 0)), -- à moitié enfoncé
					Color3.fromRGB(grey, grey - 5, grey - 12),
					Enum.Material.Slate,
					false
				)
				rockCount += 1
			end
		end
	end
	if distance % 400 == 0 then
		task.wait()
	end
end

for distance = 0, trackLength, TREE_SPACING do
	local sample = StageTrack.SampleAt(distance)
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < TREE_DENSITY then
			local spot = decorSpot(sample, side * rng:NextNumber(TREE_LATERAL_MIN, TREE_LATERAL_MAX), TREE_CLEARANCE)
			if spot then
				local trunkHeight = rng:NextNumber(10, 18)
				local trunkRadius = rng:NextNumber(0.6, 1.1)
				-- Un cylindre Roblox a son axe sur X : on le redresse.
				decorPart(
					"Trunk",
					Enum.PartType.Cylinder,
					Vector3.new(trunkHeight, trunkRadius * 2, trunkRadius * 2),
					CFrame.new(spot + Vector3.new(0, trunkHeight / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(rng:NextInteger(85, 105), rng:NextInteger(62, 75), rng:NextInteger(45, 55)),
					Enum.Material.Wood,
					true
				)
				-- Feuillage : deux boules décalées, plus naturel qu'une sphère parfaite.
				local green = Color3.fromRGB(rng:NextInteger(45, 70), rng:NextInteger(85, 115), rng:NextInteger(40, 60))
				local crown = rng:NextNumber(7, 11)
				local top = spot + Vector3.new(0, trunkHeight, 0)
				decorPart("Leaves", Enum.PartType.Ball, Vector3.new(crown, crown, crown), CFrame.new(top), green, Enum.Material.Grass, false)
				local second = crown * rng:NextNumber(0.6, 0.8)
				local shift = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1, 3), rng:NextNumber(-2, 2))
				decorPart("Leaves", Enum.PartType.Ball, Vector3.new(second, second, second), CFrame.new(top + shift), green, Enum.Material.Grass, false)
				treeCount += 1
			end
		end
	end
	if distance % 280 == 0 then
		task.wait()
	end
end

folder.Parent = workspace

print(string.format("[build-stage] décor : %d rochers, %d arbres.", rockCount, treeCount))
print(string.format(
	"[build-stage] %d échantillons, %.0f studs (%.2f km), dont %.0f chronométrés ; %d x %d colonnes. Terminé en %.1f s.",
	#samples,
	StageTrack.GetLength(),
	StageTrack.GetLength() * 0.28 / 1000,
	timedLength,
	nx,
	nz,
	os.clock() - startClock
))

-- Ce qui a VRAIMENT été peint : permet de vérifier que le place utilise bien la
-- dernière version de StageTrack (Rojo synchronisé avant de lancer ce script).
local roadCounts: { [string]: number } = {}
for _, material in pairs(roadMaterial) do
	roadCounts[material.Name] = (roadCounts[material.Name] or 0) + 1
end
local summary = {}
for name, count in pairs(roadCounts) do
	table.insert(summary, string.format("%s %d", name, count))
end
table.sort(summary)
print("[build-stage] route peinte en (colonnes) : " .. table.concat(summary, ", "))
if roadCounts.Rock then
	warn("[build-stage] La route contient du Rock : le StageTrack du place n'est pas à jour. Rojo est-il connecté ?")
end
