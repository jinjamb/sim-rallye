--!strict
--[[
	Horns.luau
	Klaxons (touche K, bouton KLAXON sur mobile), entendus par tous les
	joueurs autour de la voiture (HornService, Horn.luau).

	SONS À CHOISIR : un klaxon sans identifiant audio (Sound vide) n'est ni
	proposé à la boutique, ni tiré au sort, et le klaxon de série reste
	muet. Dans le Creator Store (create.roblox.com/store/audio), chercher
	« car horn », « horn », « air horn »... puis coller l'identifiant :
	Sound = "rbxassetid://123456". Pitch ajuste la hauteur (1 = tel quel).
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{ Id = "horn_standard", Kind = "Horn", Name = "Klaxon de série", Description = "deux tons, poli", Rarity = "Serie", Free = true, Sound = "", Pitch = 1 },
	{ Id = "horn_truck", Kind = "Horn", Name = "Trompe de camion", Description = "grave, imposant", Rarity = "Club", Roll = true, Robux = { ProductId = 0, Suggested = 49 }, Sound = "", Pitch = 0.8 },
	{ Id = "horn_italian", Kind = "Horn", Name = "Klaxon italien", Description = "la mélodie qui fait sourire", Rarity = "Pro", Roll = true, Robux = { ProductId = 0, Suggested = 99 }, Sound = "", Pitch = 1 },
	{ Id = "horn_rally", Kind = "Horn", Name = "Avertisseur de rallye", Description = "sec, pour se faire entendre", Rarity = "Usine", Roll = true, Sound = "", Pitch = 1.1 },
	{ Id = "horn_train", Kind = "Horn", Name = "Sifflet de locomotive", Description = "on l'entend de loin", Rarity = "Prototype", Pass = true, Sound = "", Pitch = 1 },
	{ Id = "horn_fanfare", Kind = "Horn", Name = "Fanfare de victoire", Description = "pour les grands jours", Rarity = "Legende", Roll = true, Sound = "", Pitch = 1 },
}

return items
