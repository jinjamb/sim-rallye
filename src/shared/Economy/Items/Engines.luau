--!strict
--[[
	Engines.luau
	Sons moteur : la voix de sa voiture, entendue par tous (CarAudio.luau,
	attribut EquippedEngine). Engine désigne une tonalité de SoundBank.luau ;
	« D'origine » garde celle de la catégorie de la voiture.

	Trois sons de base sont donnés d'office ; les autres sortent du Rallye
	Pass ou des tirages. Pour l'instant, ce sont des variations d'un même
	enregistrement (voir SoundBank.luau) : des caractères différents, pas
	encore de vrais moteurs distincts.
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{ Id = "engine_origin", Kind = "Engine", Name = "D'origine", Description = "le son de ta catégorie", Rarity = "Serie", Free = true },
	{ Id = "engine_open", Kind = "Engine", Name = "Pot libre", Description = "rauque, ça pétarade", Rarity = "Serie", Free = true, Engine = "Open" },
	{ Id = "engine_sport", Kind = "Engine", Name = "Sport", Description = "plus aigu, plus nerveux", Rarity = "Serie", Free = true, Engine = "Sport" },
	{ Id = "engine_v8", Kind = "Engine", Name = "V8 muscle", Description = "le grondement brut, sans filtre", Rarity = "Club", Roll = true, Engine = "V8" },
	{ Id = "engine_turbo", Kind = "Engine", Name = "Turbo", Description = "sifflant, tout en aigus", Rarity = "Pro", Pass = true, Engine = "Turbo" },
	{ Id = "engine_screamer", Kind = "Engine", Name = "Atmosphérique hurlant", Description = "monte dans les tours sans fin", Rarity = "Usine", Roll = true, Engine = "Screamer" },
	{ Id = "engine_vintage", Kind = "Engine", Name = "Vieille école", Description = "carburateurs et poussière", Rarity = "Prototype", Roll = true, Engine = "Vintage" },
	{ Id = "engine_legend", Kind = "Engine", Name = "Légende des années 80", Description = "le monstre du Groupe B", Rarity = "Legende", Pass = true, Engine = "Legend" },
}

return items
