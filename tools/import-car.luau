--[[
	import-car.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée),
	en mode ÉDITION (pas en Play). Rojo le range dans ServerStorage.Tools
	(jamais exécuté en jeu). Rojo doit tourner (rojo serve) : la description
	du modèle est lue dans ReplicatedStorage.Shared.Vehicle.MeshBodies.

	Range une carrosserie faite dans Blender (assets/meshes/<modèle>) pour
	que le jeu l'utilise à la place de la carrosserie en pièces (CarMeshes.luau) :
		0. importe le fichier .glb du modèle : onglet Accueil > Importer 3D
		   (ou Fichier > Importer 3D), réglages par défaut, puis « Importer » ;
		1. sélectionne le modèle importé dans l'Explorateur ;
		2. règle BODY ci-dessous (le nom du modèle : "Hayate"...) ;
		3. lance ce script, puis enregistre la place.
	Il fait, dans l'ordre :
		- retrouve chaque pièce par son nom (celui de l'objet dans Blender) ;
		- corrige l'ÉCHELLE et l'ORIENTATION de l'import, quelles qu'elles
		  soient (unités, axe vertical) : il compare la place des pièces à
		  celle attendue et choisit la rotation qui colle le mieux ;
		- pose sur chaque pièce sa place dans le repère du châssis (attribut
		  LocalCFrame), retire textures et apparences de l'import (la
		  peinture vient du jeu) ;
		- range le tout dans ReplicatedStorage.CarMeshes.<BODY> (remplace
		  un import précédent) et supprime ce qui reste de l'import.
	Relançable : réimporter un modèle retouché, puis relancer.
	Le compte rendu (pièces trouvées, manquantes, en trop) s'affiche dans la Sortie.
]]

local BODY = "Hayate"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local folder = ReplicatedStorage:FindFirstChild("Shared")
	and ReplicatedStorage.Shared:FindFirstChild("Vehicle")
	and ReplicatedStorage.Shared.Vehicle:FindFirstChild("MeshBodies")
local module = folder and folder:FindFirstChild(BODY)
if not module then
	error("[import-car] Description introuvable : ReplicatedStorage.Shared.Vehicle.MeshBodies." .. BODY .. " (rojo serve tourne ?)")
end
local data = require(module)

local selected = Selection:Get()[1]
if not selected then
	error("[import-car] Sélectionne d'abord le modèle importé dans l'Explorateur.")
end

-- Les pièces importées, par nom (sans les suffixes ajoutés à l'import : « .001 »).
local byName: { [string]: MeshPart } = {}
local extras = {}
local candidates = selected:GetDescendants()
table.insert(candidates, selected)
for _, item in ipairs(candidates) do
	if item:IsA("MeshPart") then
		local name = string.gsub(item.Name, "%.%d+$", "")
		if byName[name] then
			table.insert(extras, item.Name .. " (en double)")
		else
			byName[name] = item
		end
	end
end

local pairsFound = {}
local missing = {}
local known: { [string]: boolean } = {}
for _, info in ipairs(data.Parts) do
	known[info.Name] = true
	local part = byName[info.Name]
	if part then
		table.insert(pairsFound, { Part = part, Info = info })
	else
		table.insert(missing, info.Name)
	end
end
for name in pairs(byName) do
	if not known[name] then
		table.insert(extras, name)
	end
end
if #pairsFound < 4 then
	error(string.format("[import-car] %d pièce(s) reconnue(s) seulement : est-ce bien le modèle %s ?", #pairsFound, BODY))
end

-- Échelle et orientation : centre de chaque pièce importée contre celui attendu.
local actualSum, expectedSum = Vector3.zero, Vector3.zero
for _, pair in ipairs(pairsFound) do
	actualSum += pair.Part.Position
	expectedSum += pair.Info.Center
end
local actualMid = actualSum / #pairsFound
local expectedMid = expectedSum / #pairsFound
local actualSpread, expectedSpread = 0, 0
for _, pair in ipairs(pairsFound) do
	actualSpread += (pair.Part.Position - actualMid).Magnitude ^ 2
	expectedSpread += (pair.Info.Center - expectedMid).Magnitude ^ 2
end
local scale = math.sqrt(expectedSpread / math.max(actualSpread, 1e-9))

-- Les 24 rotations d'axe en axe : on garde celle qui remet les pièces à leur place.
local axes = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
local best, bestError = CFrame.identity, math.huge
for _, right in ipairs(axes) do
	for _, up in ipairs(axes) do
		if math.abs(right:Dot(up)) < 0.5 then
			local rotation = CFrame.fromMatrix(Vector3.zero, right, up)
			local total = 0
			for _, pair in ipairs(pairsFound) do
				local predicted = rotation:VectorToWorldSpace((pair.Part.Position - actualMid) * scale)
				total += (predicted - (pair.Info.Center - expectedMid)).Magnitude
			end
			if total < bestError then
				best, bestError = rotation, total
			end
		end
	end
end
local meanError = bestError / #pairsFound
if meanError > 0.25 then
	warn(string.format("[import-car] Les pièces ne tombent pas juste (écart moyen %.2f studs) : vérifie le fichier importé.", meanError))
end

-- Rangement : ReplicatedStorage.CarMeshes.<BODY>
local root = ReplicatedStorage:FindFirstChild("CarMeshes")
if not root then
	root = Instance.new("Folder")
	root.Name = "CarMeshes"
	root.Parent = ReplicatedStorage
end
local old = root:FindFirstChild(BODY)
if old then
	old:Destroy()
end
local template = Instance.new("Model")
template.Name = BODY

local PREVIEW = {
	Body = Color3.fromRGB(236, 236, 240), Trim = Color3.fromRGB(28, 29, 33), Glass = Color3.fromRGB(22, 30, 46),
	Head = Color3.fromRGB(255, 250, 232), Tail = Color3.fromRGB(255, 38, 52), Lamp = Color3.fromRGB(255, 232, 150),
	Chrome = Color3.fromRGB(200, 205, 215), Accent = Color3.fromRGB(220, 30, 40),
}

for _, pair in ipairs(pairsFound) do
	local part: MeshPart = pair.Part
	local info = pair.Info
	local rotation = part.CFrame.Rotation
	local place = CFrame.new(info.Center) * best * rotation
	part.Size = part.Size * scale
	part.Name = info.Name
	part:ClearAllChildren() -- apparences et textures de l'import : la peinture vient du jeu
	part.TextureID = ""
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = not info.Detail
	part.Massless = true
	part.CastShadow = info.Paint ~= "Glass" and not info.Detail
	part.Material = Enum.Material.SmoothPlastic
	part.Color = PREVIEW[info.Paint] or PREVIEW.Body
	part:SetAttribute("LocalCFrame", place)
	-- Les rayons (numéros, bandes) suivent la forme des panneaux peints.
	if info.Paint == "Body" and not info.Detail then
		pcall(function()
			part.CollisionFidelity = Enum.CollisionFidelity.Hull
		end)
	end
	part.CFrame = place -- le modèle rangé est à l'origine, comme sur un châssis à (0, 0, 0)
	part.Parent = template
end
template.Parent = root
if selected.Parent and not selected:IsDescendantOf(template) then
	selected:Destroy()
end
Selection:Set({ template })

print(string.format("[import-car] %s : %d pièce(s) rangée(s) dans ReplicatedStorage.CarMeshes.%s (échelle %.3f, écart %.3f studs).",
	BODY, #pairsFound, BODY, scale, meanError))
if #missing > 0 then
	warn("[import-car] Pièces manquantes (elles n'apparaîtront pas sur la voiture) : " .. table.concat(missing, ", "))
end
if #extras > 0 then
	warn("[import-car] Pièces importées inconnues (ignorées) : " .. table.concat(extras, ", "))
end
print("[import-car] Enregistre la place : en jeu, la carrosserie " .. BODY .. " utilise maintenant ce modèle.")
