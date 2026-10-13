--!strict
--[[
	ToonDecor.luau
	Le décor en style dessin animé : matières lisses (les aplats viennent de
	la couleur et de l'éclairage, pas d'un grain photo), couleurs franches,
	et l'étiquette « Ink » qui demande un trait d'encre autour de la pièce
	(client/World/InkHulls.luau).

	Deux usages :
		- à la construction : Scenery.luau passe chaque pièce par
		  ToonDecor.Material et ToonDecor.Tag ;
		- au démarrage du serveur (RestyleWorld) : ce qui a été construit
		  AVANT ce style (cartes enregistrées dans le place) et les modèles
		  du Creator Store (ServerStorage.SceneryAssets) sont convertis : leurs
		  textures photo sont retirées, leurs pièces recolorées selon leur
		  sorte (pin, feuillu, rocher...). Un modèle fait à la main dans le
		  style porte l'attribut ToonReady : il garde ses couleurs.
]]

local CollectionService = game:GetService("CollectionService")

local ToonDecor = {}

ToonDecor.INK_TAG = "Ink"
ToonDecor.DONE_ATTRIBUTE = "Toon" -- déjà dans le style (pas de seconde conversion)
local MIN_INK_SIZE = 1.5 -- pas de trait autour des toutes petites pièces (public, fleurs...)

local rgb = Color3.fromRGB

-- Les couleurs du décor (clair : la face éclairée, quand un modèle en a deux).
ToonDecor.PALETTE = {
	Leaf = rgb(70, 170, 88),
	LeafLight = rgb(128, 208, 112),
	Pine = rgb(36, 124, 96),
	PineLight = rgb(74, 164, 116),
	Trunk = rgb(122, 78, 64),
	Rock = rgb(150, 144, 136),
	RockLight = rgb(186, 180, 170),
	Wood = rgb(178, 120, 80),
	Snow = rgb(244, 247, 255),
	MushroomCap = rgb(226, 54, 60),
	MushroomStem = rgb(246, 236, 220),
}

-- Matières gardées telles quelles : lumière, verre, champ de force.
local KEEP: { [Enum.Material]: boolean } = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
}

-- La matière d'une pièce de décor : lisse, sauf lumière et verre.
function ToonDecor.Material(material: Enum.Material): Enum.Material
	return if KEEP[material] then material else Enum.Material.SmoothPlastic
end

-- Une couleur plus franche : plus saturée, un peu plus claire.
function ToonDecor.Color(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s * 1.25 + 0.04, 0, 1), math.clamp(v * 1.06 + 0.02, 0, 1))
end

-- Demande un trait d'encre autour de la pièce (assez grande et visible).
function ToonDecor.Tag(part: BasePart)
	if part.Transparency < 0.5 and part.Size.Magnitude >= MIN_INK_SIZE and not KEEP[part.Material] then
		CollectionService:AddTag(part, ToonDecor.INK_TAG)
	end
end

-- Une pièce construite avant le style : lisse, couleur franche, étiquetée.
function ToonDecor.RestylePart(part: BasePart)
	if KEEP[part.Material] or part.Transparency >= 1 or part:GetAttribute(ToonDecor.DONE_ATTRIBUTE) then
		return
	end
	part:SetAttribute(ToonDecor.DONE_ATTRIBUTE, true)
	part.Material = ToonDecor.Material(part.Material)
	part.Color = ToonDecor.Color(part.Color)
	ToonDecor.Tag(part)
end

--[[
	Un modèle du Creator Store : textures photo retirées (TextureID,
	SurfaceAppearance, Decal), pièces recolorées. Pour un arbre, le tronc
	est la pièce étroite (moins d'un tiers de la largeur du modèle) ; le
	reste est le feuillage, plus clair sur le haut.
]]
function ToonDecor.RestyleAsset(model: Model, kind: string)
	if model:GetAttribute(ToonDecor.DONE_ATTRIBUTE) then
		return
	end
	model:SetAttribute(ToonDecor.DONE_ATTRIBUTE, true)
	-- Modèle fait à la main dans le style (attribut ToonReady) : ses couleurs
	-- et ses textures restent ; il reçoit seulement le trait d'encre.
	if model:GetAttribute("ToonReady") then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				ToonDecor.Tag(item)
			end
		end
		return
	end
	local _, box = model:GetBoundingBox()
	local width = math.max(box.X, box.Z)
	local p = ToonDecor.PALETTE
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("SurfaceAppearance") or item:IsA("Decal") then
			item:Destroy()
		elseif item:IsA("BasePart") and item.Transparency < 1 then
			if item:IsA("MeshPart") then
				item.TextureID = ""
			end
			local narrow = math.max(item.Size.X, item.Size.Z) < width / 3
			local high = item.Position.Y > model:GetPivot().Position.Y + box.Y * 0.6
			local color: Color3
			if kind == "Pine" or kind == "PineSnow" then
				color = if narrow then p.Trunk elseif high then p.PineLight else p.Pine
				if kind == "PineSnow" and high and not narrow then
					color = p.Snow
				end
			elseif kind == "Leafy" or kind == "Bush" then
				color = if narrow and kind == "Leafy" then p.Trunk elseif high then p.LeafLight else p.Leaf
			elseif kind == "Rock" then
				color = if high then p.RockLight else p.Rock
			elseif kind == "Logs" or kind == "Fence" then
				color = p.Wood
			elseif kind == "Mushroom" then
				color = if high then p.MushroomCap else p.MushroomStem
			else
				color = ToonDecor.Color(item.Color)
			end
			item.Color = color
			item.Material = ToonDecor.Material(item.Material)
			ToonDecor.Tag(item)
		end
	end
end

-- Les modèles du Creator Store rangés pour le décor (un dossier par sorte).
function ToonDecor.RestyleLibrary(library: Instance): { [string]: string }
	local kinds: { [string]: string } = {} -- nom du modèle -> sorte
	for _, folder in ipairs(library:GetChildren()) do
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				ToonDecor.RestyleAsset(model, folder.Name)
				kinds[model.Name] = folder.Name
			end
		end
	end
	return kinds
end

-- Le décor d'une carte déjà construite (un dossier Decor, Paddock, Spectators...).
local function restyleFolder(folder: Instance, kinds: { [string]: string })
	for _, child in ipairs(folder:GetChildren()) do
		local kind = kinds[child.Name]
		if kind and child:IsA("Model") then
			ToonDecor.RestyleAsset(child, kind)
		elseif child:IsA("BasePart") then
			ToonDecor.RestylePart(child)
		elseif child:IsA("Model") or child:IsA("Folder") then
			restyleFolder(child, kinds)
		end
	end
end

local DECOR_FOLDERS = { "Decor", "Paddock", "Spectators" }

--[[
	Au démarrage du serveur : la bibliothèque du Creator Store, puis le décor
	des spéciales et des circuits enregistrés dans le place. Les routes, le
	terrain et les barrières de piste ne sont pas touchés.
]]
function ToonDecor.RestyleWorld()
	local library = game:GetService("ServerStorage"):FindFirstChild("SceneryAssets")
	local kinds = if library then ToonDecor.RestyleLibrary(library) else {}
	for _, rootName in ipairs({ "Stages", "Circuits" }) do
		local root = workspace:FindFirstChild(rootName)
		if root then
			for _, map in ipairs(root:GetChildren()) do
				for _, name in ipairs(DECOR_FOLDERS) do
					local folder = map:FindFirstChild(name)
					if folder then
						restyleFolder(folder, kinds)
					end
				end
			end
		end
	end
end

return ToonDecor
