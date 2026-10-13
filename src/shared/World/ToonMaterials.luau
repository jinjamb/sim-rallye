--!strict
--[[
	ToonMaterials.luau
	Les textures de sol style anime (assets/textures, générées par
	assets/textures/generate.py) : aplats en trois tons, détails dessinés,
	traits au crayon à papier. Chacune remplace une matière de Roblox
	PARTOUT (terrain des spéciales et des circuits, pièces du décor), par
	une variante de matériau (MaterialVariant) posée dans MaterialService.

	BRANCHER UNE TEXTURE : importer le PNG dans Roblox (Creator Hub, ou
	Asset Manager dans Studio), puis coller son identifiant dans Image
	ci-dessous. Tant qu'une texture vaut 0, sa matière garde le rendu de
	Roblox. StudsPerTile : taille d'une répétition au sol (en studs).

	Appelé une fois par le serveur au démarrage (Main.server.luau) : les
	variantes et les remplacements se répliquent chez tous les joueurs.
	L'herbe en 3D du terrain (Decoration) est coupée : elle ferait réaliste
	à côté des aplats.
]]

local MaterialService = game:GetService("MaterialService")

local ToonMaterials = {}

export type Texture = {
	File: string, -- assets/textures/<File>.png
	Image: number, -- identifiant Roblox (0 : pas encore importée)
	StudsPerTile: number,
	Materials: { Enum.Material }, -- matières de Roblox remplacées
}

ToonMaterials.TEXTURES = {
	{ File = "asphalte", Image = 119551297644960, StudsPerTile = 16, Materials = { Enum.Material.Asphalt } },
	{ File = "herbe", Image = 126014134345550, StudsPerTile = 14, Materials = { Enum.Material.Grass, Enum.Material.LeafyGrass } },
	{ File = "terre", Image = 131273025012332, StudsPerTile = 14, Materials = { Enum.Material.Ground } },
	{ File = "boue", Image = 93431365906890, StudsPerTile = 12, Materials = { Enum.Material.Mud } },
	{ File = "neige", Image = 95178479257819, StudsPerTile = 18, Materials = { Enum.Material.Snow } },
	{ File = "glace", Image = 85761994579439, StudsPerTile = 20, Materials = { Enum.Material.Ice, Enum.Material.Glacier } },
	{ File = "roche", Image = 112242242025548, StudsPerTile = 16, Materials = { Enum.Material.Slate, Enum.Material.Rock } },
	{ File = "sable", Image = 120244671042629, StudsPerTile = 16, Materials = { Enum.Material.Sand } },
	{ File = "beton", Image = 107541539264992, StudsPerTile = 12, Materials = { Enum.Material.Concrete, Enum.Material.Pavement } },
} :: { Texture }

local PREFIX = "Toon"

--[[
	Couleur d'une pièce (Part) faite dans une de ces matières : sur une pièce,
	la couleur TEINTE la texture ; une texture déjà peinte veut du blanc. Sans
	texture importée pour cette matière : la couleur prévue (fallback).
]]
function ToonMaterials.PartColor(material: Enum.Material, fallback: Color3): Color3
	for _, texture in ipairs(ToonMaterials.TEXTURES) do
		if texture.Image ~= 0 and table.find(texture.Materials, material) then
			return Color3.new(1, 1, 1)
		end
	end
	return fallback
end

--[[
	Pose les variantes des textures importées et en fait les matières par défaut.

	ColorMap n'est modifiable que depuis Studio (plugin ou barre de commande) :
	en jeu, un script ne peut pas texturer une variante. Après un changement
	d'identifiant, lancer donc une fois dans la barre de commande de Studio :
		require(game.ReplicatedStorage.Shared.World.ToonMaterials).Apply()
	puis enregistrer le place. En jeu, Apply ne fait qu'activer les variantes
	déjà prêtes ; une variante manquante est signalée, sans faire planter le
	serveur (sa matière garde le rendu de Roblox).
]]
function ToonMaterials.Apply()
	local applied = 0
	local missing = {}
	for _, texture in ipairs(ToonMaterials.TEXTURES) do
		if texture.Image ~= 0 then
			local colorMap = "rbxassetid://" .. tostring(texture.Image)
			for _, material in ipairs(texture.Materials) do
				local name = PREFIX .. material.Name
				local ok = pcall(function()
					local variant = MaterialService:FindFirstChild(name)
					if not (variant and variant:IsA("MaterialVariant")) then
						local created = Instance.new("MaterialVariant")
						created.Name = name
						created.BaseMaterial = material
						variant = created
					end
					local toon = variant :: MaterialVariant
					-- N'écrit que ce qui change : en jeu, une variante prête n'est pas touchée.
					if toon.ColorMap ~= colorMap then
						toon.ColorMap = colorMap
					end
					if toon.StudsPerTile ~= texture.StudsPerTile then
						toon.StudsPerTile = texture.StudsPerTile
					end
					-- Organique : la répétition se voit moins sur de grandes étendues.
					if toon.MaterialPattern ~= Enum.MaterialPattern.Organic then
						toon.MaterialPattern = Enum.MaterialPattern.Organic
					end
					toon.Parent = MaterialService
					MaterialService:SetBaseMaterialOverride(material, name)
				end)
				if ok then
					applied += 1
				else
					table.insert(missing, name)
				end
			end
		end
	end
	if #missing > 0 then
		warn("[ToonMaterials] variantes à préparer dans Studio (voir ToonMaterials.Apply) : " .. table.concat(missing, ", "))
	end
	if applied > 0 then
		pcall(function()
			workspace.Terrain.Decoration = false
		end)
	end
end

return ToonMaterials
