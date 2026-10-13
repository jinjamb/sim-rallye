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
	{ File = "asphalte", Image = 0, StudsPerTile = 16, Materials = { Enum.Material.Asphalt } },
	{ File = "herbe", Image = 0, StudsPerTile = 14, Materials = { Enum.Material.Grass, Enum.Material.LeafyGrass } },
	{ File = "terre", Image = 0, StudsPerTile = 14, Materials = { Enum.Material.Ground } },
	{ File = "boue", Image = 0, StudsPerTile = 12, Materials = { Enum.Material.Mud } },
	{ File = "neige", Image = 0, StudsPerTile = 18, Materials = { Enum.Material.Snow } },
	{ File = "glace", Image = 0, StudsPerTile = 20, Materials = { Enum.Material.Ice, Enum.Material.Glacier } },
	{ File = "roche", Image = 0, StudsPerTile = 16, Materials = { Enum.Material.Slate, Enum.Material.Rock } },
	{ File = "sable", Image = 0, StudsPerTile = 16, Materials = { Enum.Material.Sand } },
	{ File = "beton", Image = 0, StudsPerTile = 12, Materials = { Enum.Material.Concrete, Enum.Material.Pavement } },
} :: { Texture }

local PREFIX = "Toon"

-- Pose les variantes des textures importées et en fait les matières par défaut.
function ToonMaterials.Apply()
	local applied = 0
	for _, texture in ipairs(ToonMaterials.TEXTURES) do
		if texture.Image ~= 0 then
			for _, material in ipairs(texture.Materials) do
				local name = PREFIX .. material.Name
				local variant = MaterialService:FindFirstChild(name)
				if not (variant and variant:IsA("MaterialVariant")) then
					local created = Instance.new("MaterialVariant")
					created.Name = name
					variant = created
				end
				local toon = variant :: MaterialVariant
				toon.BaseMaterial = material
				toon.ColorMap = "rbxassetid://" .. tostring(texture.Image)
				toon.StudsPerTile = texture.StudsPerTile
				-- Organique : la répétition se voit moins sur de grandes étendues.
				toon.MaterialPattern = Enum.MaterialPattern.Organic
				toon.Parent = MaterialService
				MaterialService:SetBaseMaterialOverride(material, name)
				applied += 1
			end
		end
	end
	if applied > 0 then
		pcall(function()
			workspace.Terrain.Decoration = false
		end)
	end
end

return ToonMaterials
