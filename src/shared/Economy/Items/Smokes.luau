--!strict
--[[
	Smokes.luau
	Fumées de pneus : la couleur de la fumée quand la voiture glisse ou
	bloque sur le dur (TireSmoke.luau), vue par tous les joueurs. Bicolore
	avec Color2 (la fumée passe d'une couleur à l'autre en se dissipant).
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local items: { ItemTypes.Item } = {
	{ Id = "smoke_white", Kind = "Smoke", Name = "Fumée blanche", Description = "la gomme qui chauffe", Rarity = "Serie", Free = true, Color = rgb(225, 225, 230) },
	{ Id = "smoke_black", Kind = "Smoke", Name = "Fumée noire", Description = "épaisse, comme un vieux diesel", Rarity = "Club", Roll = true, Color = rgb(45, 45, 50) },
	{ Id = "smoke_red", Kind = "Smoke", Name = "Fumée rouge", Description = "rouge vif", Rarity = "Club", Roll = true, Robux = { ProductId = 0, Suggested = 49 }, Color = rgb(235, 50, 45) },
	{ Id = "smoke_blue", Kind = "Smoke", Name = "Fumée bleue", Description = "bleu électrique", Rarity = "Club", Roll = true, Robux = { ProductId = 0, Suggested = 49 }, Color = rgb(55, 130, 255) },
	{ Id = "smoke_yellow", Kind = "Smoke", Name = "Fumée jaune course", Description = "le jaune du jeu", Rarity = "Pro", Roll = true, Robux = { ProductId = 0, Suggested = 79 }, Color = rgb(255, 204, 0) },
	{ Id = "smoke_green", Kind = "Smoke", Name = "Fumée verte", Description = "vert fluo", Rarity = "Pro", Roll = true, Color = rgb(60, 230, 110) },
	{ Id = "smoke_purple", Kind = "Smoke", Name = "Fumée violette", Description = "violet profond", Rarity = "Pro", Roll = true, Robux = { ProductId = 0, Suggested = 79 }, Color = rgb(160, 80, 255) },
	{ Id = "smoke_sunset", Kind = "Smoke", Name = "Coucher de soleil", Description = "orange qui vire au violet", Rarity = "Usine", Roll = true, Robux = { ProductId = 0, Suggested = 149 }, Color = rgb(255, 130, 40), Color2 = rgb(150, 60, 220) },
	{ Id = "smoke_tricolore", Kind = "Smoke", Name = "Bleu-blanc-rouge", Description = "bleu qui vire au rouge", Rarity = "Usine", Pass = true, Color = rgb(40, 90, 230), Color2 = rgb(235, 45, 50) },
	{ Id = "smoke_aurora", Kind = "Smoke", Name = "Aurore boréale", Description = "vert qui vire au cyan", Rarity = "Prototype", Roll = true, Color = rgb(60, 255, 140), Color2 = rgb(70, 200, 255) },
	{ Id = "smoke_neon", Kind = "Smoke", Name = "Néon", Description = "rose qui vire au cyan", Rarity = "Prototype", Pass = true, Robux = { ProductId = 0, Suggested = 199 }, Color = rgb(255, 60, 200), Color2 = rgb(40, 230, 255) },
	{ Id = "smoke_gold", Kind = "Smoke", Name = "Or massif", Description = "doré, scintillant", Rarity = "Legende", Roll = true, Color = rgb(255, 205, 70), Color2 = rgb(255, 250, 225) },
}

return items
