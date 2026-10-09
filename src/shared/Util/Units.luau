--!strict
--[[
	Units.luau
	L'échelle du monde : combien mesure un stud, et donc ce que vaut la gravité.

	Roblox ne fixe pas d'unité, mais sa convention officielle est 1 stud = 0.28 m
	(notre châssis de 12 studs fait donc ~3.4 m, une citadine ; la roue de
	1 stud de rayon, 0.28 m). À cette échelle, la gravité réelle vaut
	9.81 / 0.28 = 35 studs/s², alors que celle de Roblox par défaut, 196.2,
	vaut ~5.6 g. Avec la gravité par défaut, tout ce qui se calcule en
	mu * poids (adhérence, freinage, virage) était 5.6 fois trop fort pour
	des vitesses, elles, réalistes.

	Coïncidence pratique : à 0.28 m/stud, 1 stud/s = 1.008 km/h. Une vitesse
	en studs/s se lit donc quasiment telle quelle en km/h.

	workspace.Gravity est réglée dans default.project.json (Rojo l'écrit dans
	le place). Main.client.luau vérifie au démarrage que les deux concordent.
]]

local Units = {}

Units.METERS_PER_STUD = 0.28
Units.REAL_GRAVITY = 9.81 / Units.METERS_PER_STUD -- ~35.04 studs/s²

function Units.ToKmh(studsPerSecond: number): number
	return studsPerSecond * Units.METERS_PER_STUD * 3.6
end

-- Puissance massique : W/kg (= m²/s³) -> studs²/s³, l'unité des couples Roblox
-- (masse * studs² / s²) multipliés par des rad/s, ramenés à la masse.
function Units.PowerToWeightToStuds(wattsPerKg: number): number
	return wattsPerKg / (Units.METERS_PER_STUD * Units.METERS_PER_STUD)
end

return Units
