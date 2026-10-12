--!strict
--[[
	Parts.luau
	Pièces de carrosserie qui ne se gagnent qu'aux TIRAGES (CarBodies.luau :
	emplacement Slot, variante Option ; Slot « Pattern » : un motif,
	Livery.PATTERNS). Les posséder les débloque au garage
	et dans l'inventaire (Progression.luau : condition Item) ; elles ne se
	« portent » pas comme une fumée : on les choisit sur sa voiture.
	Doublon : converti en crédits, comme tout objet tiré.
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{ Id = "part_flares_wide", Kind = "Part", Name = "Ailes élargies", Description = "passages de roue élargis", Rarity = "Club", Roll = true, Slot = "Flares", Option = 2 },
	{ Id = "part_hood_lamps", Kind = "Part", Name = "Rampe de phares", Description = "quatre phares de nuit sur le capot", Rarity = "Pro", Roll = true, Slot = "Hood", Option = 4 },
	{ Id = "part_wing_double", Kind = "Part", Name = "Aileron double étage", Description = "deux plans, comme un Groupe B", Rarity = "Usine", Roll = true, Slot = "Wing", Option = 5 },
	{ Id = "part_rims_sakura", Kind = "Part", Name = "Jantes sakura", Description = "rose sakura, branches noires", Rarity = "Prototype", Roll = true, Slot = "Rims", Option = 5 },
	{ Id = "part_pattern_flames", Kind = "Part", Name = "Motif flammes", Description = "des flammes sur toute la carrosserie", Rarity = "Pro", Roll = true, Slot = "Pattern", Option = 8 },
	{ Id = "part_pattern_sakura", Kind = "Part", Name = "Motif sakura", Description = "pluie de pétales de cerisier", Rarity = "Prototype", Roll = true, Slot = "Pattern", Option = 9 },
	{ Id = "part_sponsor_neon", Kind = "Part", Name = "Sponsor Neon Rally", Description = "l'autocollant cyan sur fond noir", Rarity = "Pro", Roll = true, Slot = "Sponsor", Option = 11 },
	{ Id = "part_sponsor_dragon", Kind = "Part", Name = "Sponsor Dragon Brakes", Description = "l'autocollant rouge du dragon", Rarity = "Usine", Roll = true, Slot = "Sponsor", Option = 12 },
	{ Id = "part_exhaust_cannon", Kind = "Part", Name = "Échappement canon", Description = "un seul gros embout, au centre", Rarity = "Pro", Roll = true, Slot = "Exhaust", Option = 3 },
	{ Id = "part_exhaust_titanium", Kind = "Part", Name = "Échappement titane", Description = "embout bleui par la chaleur", Rarity = "Usine", Roll = true, Slot = "Exhaust", Option = 7 },
	{ Id = "part_moustache_double", Kind = "Part", Name = "Moustache double", Description = "deux traits retroussés sous la calandre", Rarity = "Pro", Roll = true, Slot = "Moustache", Option = 5 },
	{ Id = "part_rims_neon", Kind = "Part", Name = "Jantes néon", Description = "cyan lumineux, même la nuit", Rarity = "Legende", Roll = true, Slot = "Rims", Option = 6 },
}

return items
