--!strict
--[[
	InkHulls.luau
	Le trait d'encre autour du décor (arbres, rochers, tribunes, tentes...),
	par COQUE INVERSÉE : derrière chaque pièce étiquetée « Ink »
	(ToonDecor.luau), une copie un peu plus grande, couleur encre, aux faces
	retournées. Roblox ne dessine que les faces tournées vers la caméra : de
	la coque, on ne voit que le fond, qui dépasse autour de la pièce comme un
	trait. Contrairement au Highlight des voitures (31 au plus), ça marche sur
	des milliers de pièces.

	Les coques sont des maillages (assets/meshes, générés par generate.py) :
	importer les quatre .obj dans Studio (Asset Manager > Importer), puis
	coller l'identifiant de chacun (MeshId du MeshPart importé) dans MESHES.
	Une forme sans identifiant n'a pas de trait.

	Tout est local (chaque joueur crée ses coques) et limité à une distance
	autour de la caméra, qui suit la qualité graphique du joueur ; les
	coques au-delà sont retirées. InkHulls.SetEnabled(false) coupe tout.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Ambiance = require(script.Parent.Ambiance)

local InkHulls = {}

-- Identifiants des maillages importés (0 : pas encore importé).
InkHulls.MESHES = {
	Box = 100989789782785, -- assets/meshes/InkBox.obj
	Ball = 78111543013611, -- assets/meshes/InkBall.obj
	Cylinder = 93265359356053, -- assets/meshes/InkCylinder.obj
	Wedge = 104447835953854, -- assets/meshes/InkWedge.obj
}

local TAG = "Ink" -- ToonDecor.INK_TAG
local REFRESH = 0.4 -- secondes entre deux passes
local BATCH = 700 -- pièces examinées par passe (le reste à la suivante)
local MIN_THICKNESS, MAX_THICKNESS = 0.06, 0.3 -- épaisseur du trait (studs)

local tracked: { BasePart } = {}
local index: { [BasePart]: number } = {}
local hulls: { [BasePart]: Part } = {}
local cursor = 1
local enabled = true
local started = false
local folder: Folder? = nil

-- Distance d'affichage selon la qualité graphique (réglage du joueur).
local function range(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return 300
	end
	local number = tonumber(string.match(tostring(level), "%d+")) or 5
	return 60 + number * 34 -- de 94 (qualité 1) à 400 (qualité 10)
end

local function shapeOf(part: BasePart): string?
	if part:IsA("WedgePart") then
		return "Wedge"
	elseif part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			return "Ball"
		elseif part.Shape == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif part.Shape == Enum.PartType.Block then
			return "Box"
		end
	end
	return nil -- maillages et autres formes : pas de coque
end

local function scaleOf(part: BasePart, shape: string, thickness: number): Vector3
	local size = part.Size
	local t = thickness * 2
	if shape == "Ball" then
		local d = math.min(size.X, size.Y, size.Z) + t
		return Vector3.new(d, d, d)
	elseif shape == "Cylinder" then
		local d = math.min(size.Y, size.Z) + t
		return Vector3.new(size.X + t, d, d)
	end
	return size + Vector3.new(t, t, t)
end

local function makeHull(part: BasePart): Part?
	local shape = shapeOf(part)
	local id = if shape then (InkHulls.MESHES :: any)[shape] else 0
	if not shape or id == 0 then
		return nil
	end
	local thickness = math.clamp(part.Size.Magnitude * 0.015, MIN_THICKNESS, MAX_THICKNESS)
	local hull = Instance.new("Part")
	hull.Name = "InkHull"
	hull.Anchored = true
	hull.CanCollide = false
	hull.CanQuery = false
	hull.CanTouch = false
	hull.CastShadow = false
	hull.Material = Enum.Material.SmoothPlastic
	hull.Color = Ambiance.Current().Ink
	-- Mêmes dimensions que la pièce : Roblox décide de l'afficher d'après elles.
	hull.Size = part.Size
	hull.CFrame = part.CFrame
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://" .. tostring(id)
	mesh.Scale = scaleOf(part, shape, thickness)
	mesh.Parent = hull
	hull.Parent = folder
	return hull
end

local function removeHull(part: BasePart)
	local hull = hulls[part]
	if hull then
		hull:Destroy()
		hulls[part] = nil
	end
end

local function add(instance: Instance)
	if instance:IsA("BasePart") and not index[instance] then
		table.insert(tracked, instance)
		index[instance] = #tracked
	end
end

local function remove(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local i = index[instance]
	if not i then
		return
	end
	-- Retrait en échangeant avec la dernière (ordre sans importance).
	local last = tracked[#tracked]
	tracked[i] = last
	index[last] = i
	tracked[#tracked] = nil
	index[instance] = nil
	removeHull(instance)
end

local function anyMesh(): boolean
	for _, id in pairs(InkHulls.MESHES) do
		if id ~= 0 then
			return true
		end
	end
	return false
end

-- Une passe : un lot de pièces, coque posée si proche, retirée si loin.
local function step()
	local camera = workspace.CurrentCamera
	if not camera or #tracked == 0 then
		return
	end
	local eye = camera.CFrame.Position
	local limit = range()
	local ink = Ambiance.Current().Ink
	for _ = 1, math.min(BATCH, #tracked) do
		if cursor > #tracked then
			cursor = 1
		end
		local part = tracked[cursor]
		cursor += 1
		local near = enabled and part.Transparency < 0.5 and part:IsDescendantOf(workspace) and (part.Position - eye).Magnitude < limit + part.Size.Magnitude / 2
		local hull = hulls[part]
		if near and not hull then
			local made = makeHull(part)
			if made then
				hulls[part] = made
			end
		elseif near and hull then
			hull.Color = ink
		elseif not near and hull then
			removeHull(part)
		end
	end
end

function InkHulls.SetEnabled(on: boolean)
	enabled = on
	if not on then
		for part in pairs(hulls) do
			removeHull(part)
		end
	end
end

function InkHulls.IsEnabled(): boolean
	return enabled
end

function InkHulls.Start()
	if started or not anyMesh() then
		return
	end
	started = true
	local created = Instance.new("Folder")
	created.Name = "InkHulls"
	created.Parent = workspace
	folder = created
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			step()
		end
	end)
end

return InkHulls
