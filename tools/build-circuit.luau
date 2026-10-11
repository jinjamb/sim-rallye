--[[
	build-circuit.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée).
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil d'édition.
	Rojo doit tourner (rojo serve) : les tracés sont lus dans
	ReplicatedStorage.Shared.Tracks, les mêmes modules que le serveur de course.

	Génère les circuits de rallycross en terrain, chacun à son emplacement
	(Tracks.luau, champ Origin), puis pose dans workspace.Circuits.<id> :
		- le portique de départ et ses cinq feux (allumés par RaceHud.luau) ;
		- la ligne de départ / arrivée en damier, les places de grille ;
		- les panneaux du joker ;
		- les murs de pneus en bordure des dégagements ;
		- quelques arbres au-delà.
	Relançable autant de fois que voulu : il réécrit toute la zone du circuit.

	ONLY = nil construit tous les circuits ; ONLY = "ajoncs" un seul.

	MÉTHODE : champ de hauteur, comme la spéciale (tools/build-stage.luau). Pour
	chaque colonne de 4 x 4 studs, la hauteur exacte du sol est calculée, puis
	les voxels sont écrits d'un coup avec une OCCUPATION FRACTIONNAIRE pour le
	voxel de surface : pas de marches.
	PROFIL EN TRAVERS : piste (surface du tracé) ; dégagement plat en herbe ;
	talus jusqu'au sol du circuit, là où la piste est surélevée (sauts, buttes).
	Au-delà, des COLLINES (Scenery.Hills) qui montent en douceur loin de la
	piste : le circuit est dans un creux, pas sur une plaine.

	DÉCOR (Shared/World/Scenery.luau) : forêts de feuillus, de pins et de
	cerisiers ; le long de la ligne droite de départ, côté extérieur, une
	tribune puis le PADDOCK des équipes (tentes, camions, stands, oriflammes),
	sur une zone gardée à plat.
]]

local ONLY: string? = nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
--[[
	On charge une COPIE des modules : dans Studio, `require` garde un module en
	cache pour toute la session. Après une modification d'un tracé synchronisée
	par Rojo, la barre de commandes relirait sinon l'ancienne version.
	Le dossier entier est cloné : Tracks.luau y retrouve Circuit.luau.
]]
local tracksFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tracks"):Clone()
local Tracks = require(tracksFolder:WaitForChild("Tracks"))
local Scenery = require(ReplicatedStorage.Shared:WaitForChild("World"):WaitForChild("Scenery"):Clone())

local terrain = workspace.Terrain
local VOXEL = 4
local CHUNK = 64
local RUNOFF = 26 -- dégagement en herbe de part et d'autre de la piste
local SHOULDER_DROP = 3
local EMBANK_SLOPE = 0.5
local EMBANK_REACH = 40
local FLOOR_MARGIN = 240 -- sol autour du circuit (les collines y montent)
local HILL_AMPLITUDE = 34 -- hauteur maximale des collines
local HILL_FADE = 110 -- distance sur laquelle elles montent depuis la piste
local HILL_MATERIAL = Enum.Material.LeafyGrass
local SURFACE_LAYER = 8
local RUNOFF_MATERIAL = Enum.Material.Grass
local FLOOR_MATERIAL = Enum.Material.Grass
local SUBSOIL_MATERIAL = Enum.Material.Ground

-- Une pile de pneus tous les 8 studs : 4 studs de vide entre deux piles, moins
-- que la largeur d'une voiture (6).
local TIRE_SPACING = 8
-- Pas de pneus à moins de ça du bord d'une AUTRE portion de piste (épingles,
-- joker) : le dégagement de l'une ne doit pas fermer l'autre.
local TIRE_CLEARANCE = RUNOFF - 6
local TREE_COUNT = 460
local TREE_CLEARANCE = 70
-- Paddock des équipes, côté extérieur de la ligne droite de départ (écart à l'axe).
local STAND_LATERAL = 68 -- la tribune, juste derrière les pneus
local PADDOCK_NEAR, PADDOCK_FAR = 52, 200 -- zone gardée à plat
local PADDOCK_HALF_LENGTH = 110

local startClock = os.clock()

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function anchoredPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid -- invisible pour les rayons de suspension s'il n'est pas solide
	part.CanTouch = false
	part.CastShadow = solid
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function banner(part: Part, text: string, color: Color3, faces: { Enum.NormalId })
	for _, face in ipairs(faces) do
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

local function buildCircuit(circuit)
	local samples = {}
	for _, sample in ipairs(circuit.Samples) do
		table.insert(samples, sample)
	end
	for _, sample in ipairs(circuit.JokerSamples) do
		table.insert(samples, sample)
	end

	------------------------------------------------------------------------
	-- 1. Grille des colonnes
	------------------------------------------------------------------------
	local maxHalf = circuit.RoadWidth / 2 + RUNOFF + EMBANK_REACH
	local minSX, maxSX, minSZ, maxSZ = math.huge, -math.huge, math.huge, -math.huge
	local minSY, maxSY = math.huge, -math.huge
	for _, sample in ipairs(samples) do
		local p = sample.Position
		minSX, maxSX = math.min(minSX, p.X), math.max(maxSX, p.X)
		minSZ, maxSZ = math.min(minSZ, p.Z), math.max(maxSZ, p.Z)
		minSY, maxSY = math.min(minSY, p.Y), math.max(maxSY, p.Y)
	end
	local margin = maxHalf + FLOOR_MARGIN
	local minX = math.floor((minSX - margin) / VOXEL) * VOXEL
	local maxX = math.ceil((maxSX + margin) / VOXEL) * VOXEL
	local minZ = math.floor((minSZ - margin) / VOXEL) * VOXEL
	local maxZ = math.ceil((maxSZ + margin) / VOXEL) * VOXEL
	local nx = (maxX - minX) / VOXEL
	local nz = (maxZ - minZ) / VOXEL

	local floorY = minSY
	local yMin = math.floor((floorY - 3 * VOXEL) / VOXEL) * VOXEL
	local yMax = math.ceil((math.max(maxSY, floorY + HILL_AMPLITUDE) + 3 * VOXEL) / VOXEL) * VOXEL
	local ny = (yMax - yMin) / VOXEL

	local function columnIndex(ix: number, iz: number): number
		return (ix - 1) * nz + iz
	end

	local heights = table.create(nx * nz, floorY)
	local roadHeight: { [number]: number } = {}
	local roadMaterial: { [number]: Enum.Material } = {}
	local roadDistanceSq: { [number]: number } = {}
	-- Colonnes à l'abri des collines : la piste et ses talus, le paddock.
	local reserved: { [number]: boolean } = {}

	------------------------------------------------------------------------
	-- 2. Hauteur de chaque colonne
	------------------------------------------------------------------------
	local step = 4
	for sampleIndex, sample in ipairs(samples) do
		local p = sample.Position
		local forward, left = sample.ForwardFlat, sample.Left
		local horizontal = math.sqrt(sample.Forward.X ^ 2 + sample.Forward.Z ^ 2)
		local slope = if horizontal > 1e-6 then sample.Forward.Y / horizontal else 0
		local curvature = math.abs(sample.Curvature)
		local roadHalf = sample.HalfWidth
		local flatHalf = roadHalf + RUNOFF
		local stampHalf = flatHalf + EMBANK_REACH

		local ix0 = math.max(1, math.floor((p.X - stampHalf - minX) / VOXEL) + 1)
		local ix1 = math.min(nx, math.ceil((p.X + stampHalf - minX) / VOXEL))
		local iz0 = math.max(1, math.floor((p.Z - stampHalf - minZ) / VOXEL) + 1)
		local iz1 = math.min(nz, math.ceil((p.Z + stampHalf - minZ) / VOXEL))

		for ix = ix0, ix1 do
			local dx = minX + (ix - 0.5) * VOXEL - p.X
			for iz = iz0, iz1 do
				local dz = minZ + (iz - 0.5) * VOXEL - p.Z
				local lateral = math.abs(dx * left.X + dz * left.Z)
				if lateral <= stampHalf then
					local along = dx * forward.X + dz * forward.Z
					-- Tranches élargies sur l'extérieur des virages : aucun trou.
					local sliceHalf = (step / 2) * (1 + lateral * curvature) + 1
					if math.abs(along) <= sliceHalf then
						local index = columnIndex(ix, iz)
						reserved[index] = true
						local h = p.Y + along * slope
						if lateral <= roadHalf + 1 then
							local distanceSq = along * along + lateral * lateral
							local best = roadDistanceSq[index]
							if best == nil or distanceSq < best then
								roadDistanceSq[index] = distanceSq
								roadHeight[index] = h
								roadMaterial[index] = sample.Material
							end
						end
						local proposal
						if lateral <= flatHalf - 6 then
							proposal = h
						elseif lateral <= flatHalf then
							proposal = h - SHOULDER_DROP * smoothstep((lateral - (flatHalf - 6)) / 6)
						else
							proposal = h - SHOULDER_DROP - (lateral - flatHalf) * EMBANK_SLOPE
						end
						if proposal > heights[index] then
							heights[index] = proposal
						end
					end
				end
			end
		end
		if sampleIndex % 60 == 0 then
			task.wait()
		end
	end

	------------------------------------------------------------------------
	-- 2 bis. Paddock à plat, puis les collines tout autour
	------------------------------------------------------------------------
	local start = circuit.Samples[1]
	local centroid = Vector3.zero
	for _, sample in ipairs(circuit.Samples) do
		centroid += sample.Position
	end
	centroid /= #circuit.Samples
	-- Côté extérieur de la ligne droite : à l'opposé du centre de la boucle.
	local outward = start.Left * (if (start.Position - centroid):Dot(start.Left) >= 0 then 1 else -1)
	local function paddockCoords(x: number, z: number): (number, number)
		local dx, dz = x - start.Position.X, z - start.Position.Z
		return dx * start.ForwardFlat.X + dz * start.ForwardFlat.Z, dx * outward.X + dz * outward.Z
	end
	local function inPaddock(x: number, z: number): boolean
		local along, out = paddockCoords(x, z)
		return math.abs(along) <= PADDOCK_HALF_LENGTH and out >= PADDOCK_NEAR and out <= PADDOCK_FAR
	end
	for ix = 1, nx do
		local x = minX + (ix - 0.5) * VOXEL
		for iz = 1, nz do
			if inPaddock(x, minZ + (iz - 0.5) * VOXEL) then
				reserved[columnIndex(ix, iz)] = true
			end
		end
	end
	Scenery.Hills({
		Heights = heights,
		Reserved = reserved,
		NX = nx,
		NZ = nz,
		MinX = minX,
		MinZ = minZ,
		Voxel = VOXEL,
		FloorY = floorY,
		Amplitude = HILL_AMPLITUDE,
		Fade = HILL_FADE,
		Seed = #circuit.Id * 13,
	})

	------------------------------------------------------------------------
	-- 3. Écriture des voxels (toute la zone, air compris)
	------------------------------------------------------------------------
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
					local surface = if roadH then roadMaterial[index]
						elseif not reserved[index] and h > floorY + 8 then HILL_MATERIAL
						elseif h > floorY + 0.5 then RUNOFF_MATERIAL
						else FLOOR_MATERIAL
					for j = 1, ny do
						local bottom = yMin + (j - 1) * VOXEL
						local occupancy = math.clamp((h - bottom) / VOXEL, 0, 1)
						occPlane[j][k] = occupancy
						if occupancy <= 0 then
							matPlane[j][k] = Enum.Material.Air
						elseif bottom >= h - SURFACE_LAYER then
							matPlane[j][k] = surface
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

	local function groundHeightAt(x: number, z: number): number
		local ix = math.floor((x - minX) / VOXEL) + 1
		local iz = math.floor((z - minZ) / VOXEL) + 1
		if ix < 1 or ix > nx or iz < 1 or iz > nz then
			return floorY
		end
		local index = columnIndex(ix, iz)
		return roadHeight[index] or heights[index]
	end

	-- Distance horizontale au bord de chaussée le plus proche (négative sur la piste).
	local function roadClearance(position: Vector3): number
		local best = math.huge
		for _, sample in ipairs(samples) do
			local dx, dz = position.X - sample.Position.X, position.Z - sample.Position.Z
			local d = math.sqrt(dx * dx + dz * dz) - sample.HalfWidth
			if d < best then
				best = d
			end
		end
		return best
	end

	------------------------------------------------------------------------
	-- 4. Éléments posés
	------------------------------------------------------------------------
	local circuitsFolder = workspace:FindFirstChild("Circuits")
	if not circuitsFolder then
		circuitsFolder = Instance.new("Folder")
		circuitsFolder.Name = "Circuits"
		circuitsFolder.Parent = workspace
	end
	local existing = circuitsFolder:FindFirstChild(circuit.Id)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = circuit.Id

	local roadHalf = circuit.RoadWidth / 2

	-- Portique de départ, face à la grille, et ses cinq feux.
	local gantry = Instance.new("Model")
	gantry.Name = "Gantry"
	gantry.Parent = folder
	local postHeight = 16
	local halfSpan = roadHalf + 4
	local base = start.Position
	for _, side in ipairs({ -1, 1 }) do
		local position = base + start.Left * (halfSpan * side) + Vector3.new(0, postHeight / 2, 0)
		anchoredPart(gantry, "Post", Vector3.new(2, postHeight, 2), CFrame.new(position), Color3.fromRGB(40, 40, 45), true)
	end
	local beamCenter = base + Vector3.new(0, postHeight - 1.5, 0)
	local facing = CFrame.lookAt(beamCenter, beamCenter - start.ForwardFlat) -- regarde vers la grille
	local beam = anchoredPart(gantry, "Beam", Vector3.new(halfSpan * 2 + 2, 3, 1.5), facing, Color3.fromRGB(20, 20, 24), false)
	banner(beam, "RALLYCROSS — " .. string.upper(circuit.Name), Color3.fromRGB(20, 20, 24), { Enum.NormalId.Front })
	for i = 1, 5 do
		local offset = (i - 3) * 3.2
		local light = anchoredPart(
			gantry,
			"Light" .. i,
			Vector3.new(2.4, 2.4, 0.6),
			facing * CFrame.new(offset, -3.2, -1),
			Color3.fromRGB(45, 20, 20),
			false
		)
		light.Material = Enum.Material.Neon
		light.Shape = Enum.PartType.Block
	end

	-- Ligne de départ / arrivée en damier, posée sur la chaussée.
	local squares = math.floor(circuit.RoadWidth / 2)
	for row = 0, 1 do
		for column = 0, squares - 1 do
			local lateral = -roadHalf + 1 + column * 2
			local position = start.Position + start.Left * lateral + start.ForwardFlat * (row * 2 - 1) + Vector3.new(0, 0.06, 0)
			local white = (row + column) % 2 == 0
			anchoredPart(
				folder,
				"Line",
				Vector3.new(2, 0.1, 2),
				CFrame.lookAt(position, position + start.ForwardFlat),
				if white then Color3.new(1, 1, 1) else Color3.new(0.05, 0.05, 0.05),
				false
			)
		end
	end

	-- Places de grille : une barre blanche devant chaque voiture.
	for slot = 1, 6 do
		local frame = circuit:GridSlot(slot)
		local front = frame.Position + frame.LookVector * 8
		local ground = groundHeightAt(front.X, front.Z)
		local position = Vector3.new(front.X, ground + 0.06, front.Z)
		anchoredPart(folder, "GridBox", Vector3.new(9, 0.1, 0.7), CFrame.lookAt(position, position + frame.LookVector), Color3.new(1, 1, 1), false)
	end

	-- Panneaux du joker : à l'embranchement et au milieu de la branche.
	local jokerSamples = circuit.JokerSamples
	local function jokerSign(sample, text: string)
		local position = sample.Position + sample.Left * (sample.HalfWidth + 6) + Vector3.new(0, 5, 0)
		-- Sans collision : selon le tracé, le bord du joker peut longer la boucle.
		local sign = anchoredPart(folder, "JokerSign", Vector3.new(10, 4, 0.5), CFrame.lookAt(position, position - sample.ForwardFlat), Color3.fromRGB(255, 140, 40), false)
		banner(sign, text, Color3.fromRGB(230, 120, 20), { Enum.NormalId.Front, Enum.NormalId.Back })
		anchoredPart(folder, "JokerPost", Vector3.new(0.6, 5, 0.6), CFrame.new(position - Vector3.new(0, 4.5, 0)), Color3.fromRGB(60, 60, 60), false)
	end
	if #jokerSamples > 10 then
		jokerSign(jokerSamples[math.min(#jokerSamples, 12)], "JOKER ➜")
		jokerSign(jokerSamples[math.floor(#jokerSamples / 2)], "JOKER")
	end

	-- Murs de pneus au bord des dégagements, là où ils ne gênent aucune piste.
	local barriers = Instance.new("Folder")
	barriers.Name = "Barriers"
	barriers.Parent = folder
	local tireCount = 0
	for _, list in ipairs({ circuit.Samples, circuit.JokerSamples }) do
		local stride = math.max(1, math.floor(TIRE_SPACING / 4))
		for index = 1, #list, stride do
			local sample = list[index]
			for _, side in ipairs({ -1, 1 }) do
				local lateral = sample.HalfWidth + RUNOFF - 2
				local spot = sample.Position + sample.Left * (lateral * side)
				if roadClearance(spot) >= TIRE_CLEARANCE then
					local ground = groundHeightAt(spot.X, spot.Z)
					tireCount += 1
					local tire = anchoredPart(
						barriers,
						"Tires",
						Vector3.new(3, 3.6, 3.6),
						CFrame.new(spot.X, ground + 1.5, spot.Z) * CFrame.Angles(0, 0, math.pi / 2),
						if tireCount % 6 == 0 then Color3.fromRGB(200, 40, 40) else Color3.fromRGB(25, 25, 28),
						true
					)
					tire.Shape = Enum.PartType.Cylinder
				end
			end
			if index % 120 == 1 then
				task.wait()
			end
		end
	end

	-- Forêts au-delà des dégagements : elles donnent la profondeur et la vitesse.
	-- Le bruit de Perlin les groupe en bosquets, avec des clairières entre eux.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	local rng = Random.new(#circuit.Id * 7919)
	local treeCount = 0
	for attempt = 1, TREE_COUNT * 6 do
		if treeCount >= TREE_COUNT then
			break
		end
		local x = rng:NextNumber(minX + 20, maxX - 20)
		local z = rng:NextNumber(minZ + 20, maxZ - 20)
		local grove = math.noise(x / 180, z / 180, #circuit.Id + 0.5)
		if (grove > -0.05 or rng:NextNumber() < 0.15) and not inPaddock(x, z) and roadClearance(Vector3.new(x, 0, z)) >= TREE_CLEARANCE then
			Scenery.Tree(decor, Vector3.new(x, groundHeightAt(x, z), z), rng, Scenery.PickKind(rng, 0.07), rng:NextNumber(1, 1.4))
			treeCount += 1
		end
		if attempt % 100 == 0 then
			task.wait()
		end
	end

	-- Tribune et paddock des équipes, côté extérieur de la ligne droite de départ.
	local paddock = Instance.new("Folder")
	paddock.Name = "Paddock"
	paddock.Parent = folder
	local forward = start.ForwardFlat
	local function spotAt(along: number, out: number): Vector3
		local p = start.Position + forward * along + outward * out
		return Vector3.new(p.X, groundHeightAt(p.X, p.Z), p.Z)
	end
	-- Libre : loin de toute AUTRE portion de piste.
	local function free(spot: Vector3, margin: number): boolean
		return roadClearance(spot) >= margin
	end
	local stand = spotAt(0, STAND_LATERAL)
	if free(stand, STAND_LATERAL - roadHalf - 10) then
		Scenery.Grandstand(paddock, CFrame.lookAt(stand, stand - outward), 96, 7, rng, "RALLYCROSS · " .. string.upper(circuit.Name))
	end
	local teams = { "TEAM KAZE", "YAMA WORKS", "RAIJIN GP", "HAYATE RT", "HOSHI SPORT", "SAKURA RACING", "TORA MOTORS" }
	for i, name in ipairs(teams) do
		local along = (i - 4) * 27
		local color = Scenery.TEAM_COLORS[((i - 1) % #Scenery.TEAM_COLORS) + 1]
		local tent = spotAt(along, 112)
		if free(tent, 60) then
			Scenery.Tent(paddock, CFrame.lookAt(tent, tent - outward), 14, 10, color, name)
			Scenery.Flag(paddock, spotAt(along + 9, 104), color, -outward)
		end
		if i % 2 == 1 then
			local truck = spotAt(along, 140)
			if free(truck, 80) then
				Scenery.Truck(paddock, CFrame.lookAt(truck, truck + forward), color, name)
			end
		end
	end
	local pits = spotAt(0, 180)
	if free(pits, 120) then
		Scenery.PitBuilding(paddock, CFrame.lookAt(pits, pits - outward), 170, "PADDOCK · " .. string.upper(circuit.Name))
	end
	for _, along in ipairs({ -PADDOCK_HALF_LENGTH + 6, PADDOCK_HALF_LENGTH - 6 }) do
		local corner = spotAt(along, 96)
		if free(corner, 40) then
			local toward = (stand - corner) * Vector3.new(1, 0, 1)
			Scenery.LightTower(paddock, corner, (toward.Unit + Vector3.new(0, -0.5, 0)).Unit)
		end
		for out = 100, 190, 18 do
			local edge = spotAt(along + (if along > 0 then 8 else -8), out)
			if free(edge, 40) then
				Scenery.Tree(paddock, edge, rng, if out % 36 == 28 then "Sakura" else Scenery.PickKind(rng, 0.3), 1.1)
			end
		end
	end
	for _ = 1, 8 do
		local pile = spotAt(rng:NextNumber(-90, 90), rng:NextNumber(122, 130))
		if free(pile, 60) then
			Scenery.TireStack(paddock, pile, rng)
		end
	end

	folder.Parent = circuitsFolder

	-- Ce qui a VRAIMENT été peint (vérifie que Rojo a bien synchronisé les tracés).
	local roadCounts: { [string]: number } = {}
	for _, material in pairs(roadMaterial) do
		roadCounts[material.Name] = (roadCounts[material.Name] or 0) + 1
	end
	local summary = {}
	for name, count in pairs(roadCounts) do
		table.insert(summary, string.format("%s %d", name, count))
	end
	table.sort(summary)
	print(string.format(
		"[build-circuit] %s : boucle %.0f studs (%.2f km), joker %.0f studs ; %d x %d colonnes ; %d pneus, %d arbres (+ paddock). Route : %s",
		circuit.Name,
		circuit.Length,
		circuit.Length * 0.28 / 1000,
		circuit.JokerLength,
		nx,
		nz,
		tireCount,
		treeCount,
		table.concat(summary, ", ")
	))
end

for _, id in ipairs(Tracks.List()) do
	if ONLY == nil or ONLY == id then
		local circuit = Tracks.Get(id)
		if circuit then
			buildCircuit(circuit)
		end
	end
end
print(string.format("[build-circuit] Terminé en %.1f s.", os.clock() - startClock))
