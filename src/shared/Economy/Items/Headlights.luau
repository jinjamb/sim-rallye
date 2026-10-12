--!strict
--[[
	Headlights.luau
	Phares : la teinte de la lumière des phares (Driving/CarLights.luau,
	attribut EquippedHeadlight de la voiture), vue par tous : les optiques
	et les phares longue portée prennent la couleur, un halo brille à
	l'avant (il perce la poussière), et la nuit les faisceaux éclairent la
	route de cette couleur (StageModifier.luau).
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local items: { ItemTypes.Item } = {
	{ Id = "headlight_halogen", Kind = "Headlight", Name = "Halogène", Description = "blanc chaud, de série", Rarity = "Serie", Free = true, Color = rgb(255, 240, 210) },
	{ Id = "headlight_xenon", Kind = "Headlight", Name = "Xénon", Description = "blanc bleuté, tranchant", Rarity = "Club", Credits = 1200, Roll = true, Color = rgb(215, 232, 255) },
	{ Id = "headlight_yellow", Kind = "Headlight", Name = "Jaune sélectif", Description = "le jaune des rallyes d'antan", Rarity = "Club", Credits = 1500, Roll = true, Color = rgb(255, 205, 40) },
	{ Id = "headlight_amber", Kind = "Headlight", Name = "Ambre", Description = "orangé, rétro", Rarity = "Pro", Roll = true, Color = rgb(255, 150, 40) },
	{ Id = "headlight_ice", Kind = "Headlight", Name = "Glacier", Description = "bleu glacier", Rarity = "Pro", Credits = 3000, Roll = true, Color = rgb(120, 200, 255) },
	{ Id = "headlight_green", Kind = "Headlight", Name = "Vert néon", Description = "vert fluo", Rarity = "Usine", Roll = true, Color = rgb(80, 255, 120) },
	{ Id = "headlight_purple", Kind = "Headlight", Name = "Violet", Description = "violet électrique", Rarity = "Usine", Roll = true, Color = rgb(180, 90, 255) },
	{ Id = "headlight_sakura", Kind = "Headlight", Name = "Sakura", Description = "rose sakura", Rarity = "Prototype", Credits = 8000, Color = rgb(255, 90, 170) },
	{ Id = "headlight_gold", Kind = "Headlight", Name = "Or", Description = "lumière dorée", Rarity = "Legende", Roll = true, Color = rgb(255, 200, 80) },
}

return items
