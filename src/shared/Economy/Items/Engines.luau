--!strict
--[[
	Engines.luau
	Sons moteur : la voix de sa voiture, entendue par tous (CarAudio.luau,
	attribut EquippedEngine). Engine désigne une tonalité de SoundBank.luau ;
	« D'origine » garde celle de la catégorie de la voiture.

	Trois sons de base sont donnés d'office ; les autres sortent du Rallye
	Pass ou des tirages. Chacun est un vrai moteur (3, 4, 5 cylindres,
	boxer, V6, 6 à plat, rotatif, V8 : SoundBank.luau), avec son
	traitement.
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{ Id = "engine_origin", Kind = "Engine", Name = "D'origine", Description = "le son de ta catégorie", Rarity = "Serie", Free = true },
	{ Id = "engine_open", Kind = "Engine", Name = "Pot libre", Description = "rauque, ça pétarade", Rarity = "Serie", Free = true, Engine = "Open" },
	{ Id = "engine_sport", Kind = "Engine", Name = "V6 sport", Description = "un V6 qui chante, sans turbo", Rarity = "Serie", Free = true, Engine = "Sport" },
	{ Id = "engine_v8", Kind = "Engine", Name = "V8 muscle", Description = "le grondement brut, sans filtre", Rarity = "Club", Roll = true, Engine = "V8" },
	{ Id = "engine_turbo", Kind = "Engine", Name = "Turbo anti-lag", Description = "sifflant, ça claque au lever de pied", Rarity = "Pro", Pass = true, Engine = "Turbo" },
	{ Id = "engine_screamer", Kind = "Engine", Name = "6 à plat hurlant", Description = "monte dans les tours sans fin", Rarity = "Usine", Roll = true, Engine = "Screamer" },
	{ Id = "engine_vintage", Kind = "Engine", Name = "Vieille école", Description = "V6 à carburateurs, rauque et poussiéreux", Rarity = "Prototype", Roll = true, Engine = "Vintage" },
	{ Id = "engine_boxer", Kind = "Engine", Name = "Boxer", Description = "le grondement irrégulier des 4 à plat", Rarity = "Pro", Roll = true, Engine = "Boxer" },
	{ Id = "engine_rotary", Kind = "Engine", Name = "Rotatif", Description = "deux rotors, un bourdonnement unique", Rarity = "Prototype", Roll = true, Engine = "Rotary" },
	{ Id = "engine_legend", Kind = "Engine", Name = "Légende des années 80", Description = "le 5 cylindres du monstre du Groupe B, pot libre", Rarity = "Legende", Pass = true, Engine = "Legend" },
}

return items
