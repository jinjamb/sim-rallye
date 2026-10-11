--!strict
--[[
	Celebrations.luau
	Célébrations de podium : l'effet qui jaillit au-dessus de sa marche à
	la cérémonie (Celebrations.luau, côté serveur : vu par tous). Effect
	désigne l'effet ; Color le teinte s'il en a besoin.
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{ Id = "cel_confetti", Kind = "Celebration", Name = "Confettis", Description = "la fête classique", Rarity = "Serie", Free = true, Effect = "Confetti" },
	{ Id = "cel_flares", Kind = "Celebration", Name = "Fumigènes", Description = "fumée aux couleurs de ta voiture", Rarity = "Club", Roll = true, Effect = "Flares" },
	{ Id = "cel_fireworks", Kind = "Celebration", Name = "Feu d'artifice", Description = "gerbes d'étincelles", Rarity = "Pro", Roll = true, Robux = { ProductId = 0, Suggested = 99 }, Effect = "Fireworks" },
	{ Id = "cel_champagne", Kind = "Celebration", Name = "Champagne", Description = "la douche du vainqueur", Rarity = "Usine", Roll = true, Robux = { ProductId = 0, Suggested = 149 }, Effect = "Champagne" },
	{ Id = "cel_lightning", Kind = "Celebration", Name = "Orage", Description = "éclairs et étincelles bleues", Rarity = "Prototype", Pass = true, Effect = "Lightning", Color = Color3.fromRGB(110, 190, 255) },
	{ Id = "cel_gold", Kind = "Celebration", Name = "Pluie d'or", Description = "des paillettes d'or, et le silence", Rarity = "Legende", Roll = true, Effect = "Gold", Color = Color3.fromRGB(255, 205, 70) },
}

return items
