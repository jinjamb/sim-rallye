--!strict
--[[
	CarBodies.luau
	Les MODÈLES de voitures et leurs PIÈCES à personnaliser. Chaque modèle
	est une carrosserie construite par le jeu, en pièces Roblox (style
	low-poly), posée sur le même châssis physique (build-rig.luau) : le
	modèle ne change rien à la conduite, seulement le look. La catégorie
	(Rally4, Rally2, WRC, Groupe B : CarClasses.luau) reste celle de la voiture.

		1 Origine   la carrosserie du gabarit (modèle importé), telle quelle ;
		2 Kaze      (« vent ») citadine WRC moderne à hayon, nez plongeant ;
		3 Yama      (« montagne ») berline trois volumes des années 70 ;
		4 Raijin    (« dieu du tonnerre ») coupé en coin des années 80, ailes
		            larges, lunette à persiennes ;
		5 Hayate    (« ouragan ») berline de rallye japonaise, capot
		            plongeant, grande prise d'air (façon Evo) ;
		6 Hoshi     (« étoile ») berline de rallye à phares ronds et
		            antibrouillards (façon Impreza) ;
		7 Tora      (« tigre ») citadine compacte moderne ;
		8 Kumo      (« nuage ») petite bombe à moteur central des années 80 ;
		9 Ryu       (« dragon ») coupé long et bas, quatre phares ronds ;
	et, inspirés des légendes du rallye, faits dans Blender (CarMeshes) :
		10 Tsubasa  (« aile ») compacte de WRC moderne, aéro démesurée (Yaris WRC) ;
		11 Requin   compacte au toit flottant, montant en aileron de requin (DS3 WRC) ;
		12 Lynx     petite compacte aux yeux de félin (206 WRC) ;
		13 Griffe   compacte moderne aux feux en griffes (208) ;
		14 Furia    cinq portes très carrée, quatre phares carrés (Delta Integrale) ;
		15 Blitz    coupé Groupe B au long nez, aileron géant (Quattro S1) ;
		16 Fauve    petite bombe Groupe B, prises d'air derrière les portes (205 T16) ;
		17 Cuneo    coupé à moteur central en coin arrondi (Stratos).
	Les voitures (CarModels.luau) ont chacune leur modèle et leurs pièces ;
	le joueur peut garder ceux de sa voiture (Livery : Body = 0) ou choisir
	les siens.
	Les trois derniers s'inspirent des voitures de rallye low-poly de
	référence (berline rouge, citadine blanche, berline bleue).

	PIÈCES : cinq emplacements, chacun avec ses variantes (la 1re est celle
	de série). Une pièce s'adapte au modèle grâce à ses repères (MOUNTS :
	où est le toit, le capot, le nez...).
		Aileron      aucun, becquet, aileron rallye, grand aileron (hauts
		             montants, façon Evo / Impreza), double étage ;
		Bouclier     route, rallye (sabot + phares longue portée), course ;
		Capot        lisse, prises d'air, écope, rampe de phares ;
		Ailes        d'origine, élargies ;
		Jantes       or, noires, blanches, chrome, sakura, néon.
	Certaines pièces ne se gagnent qu'aux TIRAGES (objets « Part » du
	catalogue, Items/Parts.luau ; Progression.luau : condition Item).
	La carrosserie d'origine (importée, de forme inconnue) ne prend que les
	jantes : les autres pièces n'auraient pas où se poser.

	ZONES DE PEINTURE (ZONES) : chaque pièce appartient à une zone (capot,
	toit, portières, boucliers...) que le joueur peut peindre d'une autre
	couleur que la carrosserie (Livery.Paints) ; sans choix, la pièce garde
	sa peinture d'origine (couleur de la livrée, ou noir des garnitures).
	Les zones n'existent que sur les modèles du jeu (pas sur l'Origine).

	OÙ C'EST CHOISI : dans la livrée (Livery.luau : champs Body, Wing,
	Bumper, Hood, Flares, Rims), donc sauvegardé, vérifié (déblocages :
	Progression.luau) et appliqué partout où la livrée l'est
	(LiveryPainter.Apply appelle CarBodies.Apply en premier).

	CONSTRUCTION, en cinq passes :
		1 VOLUMES     la caisse (lowerBody) : caisse centrale, portes, ailes,
		              coins ; les roues restent visibles ;
		2 SILHOUETTE  nez et coffre plongeants, habitacle (cabin), arrière
		              incliné (slopedRear) : ce qui fait reconnaître le modèle ;
		3 STRUCTURE   montants, ailes bombées, prises d'air, persiennes ;
		4 DÉTAILS     phares, calandre, feux, puis les pièces choisies
		              (aileron, bouclier, capot, ailes, accessoires) et les
		              détails communs (poignées, essuie-glaces, trappe à
		              carburant, anneaux de remorquage : detailParts) et
		              les lignes de carrosserie à l'encre (panelLineParts) ;
		5 GAME READY  petites pièces hors des rayons et sans ombre
		              (DETAIL_NAMES), budget de pièces (PART_BUDGET), tout
		              sans masse ni collision.
	ACCESSOIRES (emplacements Accessory) : rétroviseurs, toit, bas de caisse,
	arrière, échappement, bavettes, moustache, calandre, ailettes, bandeau de
	pare-brise, goupilles de capot, remorquage, caches-phares, ouïes, filet
	de vitre. Ils restent au choix du joueur même sur la carrosserie de sa
	voiture ; calandre, moustache et caches-phares s'ajustent aux pièces du
	modèle (named).

	Les pièces sont sans masse, sans collision, soudées au
	châssis. La peinture de la livrée se pose sur celles marquées
	« LiveryPaint » (comme sur le gabarit). Changer de modèle masque la
	carrosserie importée (elle est gardée, pour revenir à l'Origine) et le
	kit de la catégorie (BodyKits.luau), qui ne tomberait pas juste.

	REPÈRE : celui du châssis. X à droite, Y en haut, l'avant en -Z. Le sol
	est vers Y = -2.1 ; les roues à X = ±2.58, Z = ±4.05, rayon 1.08.
]]

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local BodyKits = require(script.Parent.BodyKits)
local CarMeshes = require(script.Parent.CarMeshes)

local CarBodies = {}

-- Peintures (hors couleur de la livrée).
local TRIM = Color3.fromRGB(28, 29, 33)
local GLASS = Color3.fromRGB(22, 30, 46)
local HEAD = Color3.fromRGB(255, 250, 232)
local TAIL = Color3.fromRGB(255, 38, 52)
local LAMP = Color3.fromRGB(255, 232, 150)
local CHROME = Color3.fromRGB(200, 205, 215)
local ACCENT = Color3.fromRGB(220, 30, 40) -- anneaux de remorquage, rouges comme en rallye

local FOLDER = "CustomBody"
local PAINT_ATTRIBUTE = "LiveryPaint" -- comme LiveryPainter
local DESIGN_ATTRIBUTE = "DesignKey"
local HIDDEN_ATTRIBUTE = "BodyTransparency" -- transparence d'origine d'une pièce masquée
local ZONE_ATTRIBUTE = "PaintZone" -- zone de peinture de la pièce (ZONES)
local BASE_COLOR_ATTRIBUTE = "BaseColor" -- couleur d'origine d'une pièce non peinte (garnitures)
local CAR_COLLISION_GROUP = "Cars" -- CarService : les rayons des autres voitures traversent
local PART_BUDGET = 190 -- pièces par carrosserie au plus (alerte dans Studio au-delà)

type Paint = "Body" | "Trim" | "Glass" | "Head" | "Tail" | "Lamp" | "Chrome" | "Accent"
type Shape = "Block" | "Wedge" | "Cylinder"
-- Color : une teinte propre (sangles, filets, titane), à la place de celle de sa peinture.
export type Spec = { Name: string, Shape: Shape?, Size: Vector3, At: CFrame, Paint: Paint, Color: Color3? }

-- Repères d'un modèle, où se posent les pièces.
export type Mounts = {
	NoseZ: number, -- face avant
	TailZ: number, -- face arrière
	BottomY: number, -- bas de caisse
	BeltY: number, -- dessus de la caisse (capot, coffre)
	HalfWidth: number, -- demi-largeur aux flancs
	NoseHalfWidth: number?, -- demi-largeur de la face avant (modèles Blender : coins coupés ou arrondis)
	HoodFrontZ: number,
	HoodRearZ: number, -- pied du pare-brise
	HoodHalfWidth: number,
	Wing: { Mount: "Roof" | "Deck", Z: number, Y: number, Width: number },
	-- Nez et coffre plongeants : sur `Length` studs, le dessus descend de `Drop`.
	NoseSlope: { Length: number, Drop: number }?,
	TailSlope: { Length: number, Drop: number }?,
}

export type Body = {
	Id: string,
	Name: string,
	Description: string,
	Custom: boolean, -- false : la carrosserie importée du gabarit
	Slots: { string }, -- emplacements de pièces proposés
	Mounts: Mounts?,
	Cabin: Cabin?, -- l'habitacle (rétroviseurs, toit, essuie-glaces : passe DÉTAILS)
	Parts: { Spec },
}

export type Option = { Name: string }
-- Accessory : un accessoire, toujours au choix du joueur, même quand il garde
-- la carrosserie de sa voiture (CarModels.luau : Design).
export type Slot = { Key: string, Name: string, Options: { Option }, Accessory: boolean? }

--------------------------------------------------------------------------------
-- Petits constructeurs de description
--------------------------------------------------------------------------------

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Une WedgePart a sa pente vers l'avant (basse devant, haute derrière) ; retournée,
-- elle descend vers l'arrière (lunette, hayon).
local FLIP = CFrame.Angles(0, math.pi, 0)
-- Un cylindre a son axe en X : tourné, il regarde vers l'avant (phares ronds).
local FACING = CFrame.Angles(0, math.rad(90), 0)

local function block(name: string, size: Vector3, cf: CFrame, paint: Paint): Spec
	return { Name = name, Shape = "Block", Size = size, At = cf, Paint = paint }
end

local function wedge(name: string, size: Vector3, cf: CFrame, paint: Paint): Spec
	return { Name = name, Shape = "Wedge", Size = size, At = cf, Paint = paint }
end

local function disc(name: string, diameter: number, depth: number, cf: CFrame, paint: Paint): Spec
	return { Name = name, Shape = "Cylinder", Size = Vector3.new(depth, diameter, diameter), At = cf * FACING, Paint = paint }
end

-- La même pièce à gauche et à droite (x > 0 : position à droite).
local function pair(list: { Spec }, make: (side: number) -> Spec)
	table.insert(list, make(-1))
	table.insert(list, make(1))
end

local function add(list: { Spec }, spec: Spec)
	table.insert(list, spec)
end

--[[
	Le dessous commun : une caisse centrale (entre les roues), des bas de
	caisse entre les passages de roue, des ailes au-dessus des roues, les
	coins avant et arrière. Les roues restent visibles dans leurs passages.
]]
local ARCH_HALF = 1.4 -- demi-longueur d'un passage de roue (autour de Z = ±4.05)
local WHEEL_Z = 4.05
local TIRE_TOP = 0.1 -- dessous des ailes, au-dessus du pneu
local function lowerBody(list: { Spec }, m: Mounts)
	local height = m.BeltY - m.BottomY
	local midY = (m.BeltY + m.BottomY) / 2
	-- Nez et coffre plongeants : la caisse s'arrête avant, une pente les coiffe.
	local nose = m.NoseSlope
	local tail = m.TailSlope
	local frontZ = m.NoseZ + (if nose then nose.Length else 0)
	local rearZ = m.TailZ - (if tail then tail.Length else 0)
	local length = rearZ - frontZ
	local inner = 2.05 -- demi-largeur de la caisse centrale (intérieur des roues)
	local side = m.HalfWidth - inner
	local sideX = inner + side / 2
	add(list, block("Tub", Vector3.new(inner * 2, height, length), at(0, midY, (frontZ + rearZ) / 2), "Body"))
	local slopeBottom = m.BottomY + 0.2
	if nose then
		local top = m.BeltY - nose.Drop
		add(list, block("Nose", Vector3.new(m.HalfWidth * 2, top - slopeBottom, nose.Length), at(0, (top + slopeBottom) / 2, m.NoseZ + nose.Length / 2), "Body"))
		add(list, wedge("NoseSlope", Vector3.new(m.HalfWidth * 2, nose.Drop, nose.Length), at(0, top + nose.Drop / 2, m.NoseZ + nose.Length / 2), "Body"))
	end
	if tail then
		local top = m.BeltY - tail.Drop
		add(list, block("Tail", Vector3.new(m.HalfWidth * 2, top - slopeBottom, tail.Length), at(0, (top + slopeBottom) / 2, m.TailZ - tail.Length / 2), "Body"))
		add(list, wedge("TailSlope", Vector3.new(m.HalfWidth * 2, tail.Drop, tail.Length), at(0, top + tail.Drop / 2, m.TailZ - tail.Length / 2) * FLIP, "Body"))
	end
	-- Bas de caisse, entre les passages.
	local doorLength = (WHEEL_Z - ARCH_HALF) * 2
	pair(list, function(s)
		return block("Door", Vector3.new(side, height, doorLength), at(s * sideX, midY, 0), "Body")
	end)
	-- Ailes : du dessus du pneu au dessus de la caisse.
	local fenderHeight = m.BeltY - TIRE_TOP
	for _, z in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Fender", Vector3.new(side, fenderHeight, ARCH_HALF * 2), at(s * sideX, TIRE_TOP + fenderHeight / 2, z), "Body")
		end)
	end
	-- Coins avant et arrière, devant et derrière les roues.
	local noseLength = -(WHEEL_Z + ARCH_HALF) - frontZ
	local tailLength = rearZ - (WHEEL_Z + ARCH_HALF)
	local cornerBottom = m.BottomY + 0.35
	local cornerHeight = m.BeltY - cornerBottom
	if noseLength > 0.05 then
		pair(list, function(s)
			return block("Corner", Vector3.new(side, cornerHeight, noseLength), at(s * sideX, cornerBottom + cornerHeight / 2, frontZ + noseLength / 2), "Body")
		end)
	end
	if tailLength > 0.05 then
		pair(list, function(s)
			return block("Corner", Vector3.new(side, cornerHeight, tailLength), at(s * sideX, cornerBottom + cornerHeight / 2, rearZ - tailLength / 2), "Body")
		end)
	end
	-- Bas de caisse noir, comme une jupe.
	pair(list, function(s)
		return block("Skirt", Vector3.new(0.12, 0.3, doorLength), at(s * (m.HalfWidth + 0.03), m.BottomY + 0.2, 0), "Trim")
	end)
end

--[[
	L'habitacle : pare-brise (coin), toit, vitres latérales, montants, et
	l'arrière (hayon, lunette ou fastback, décrit par le modèle).
]]
type Cabin = {
	HalfWidth: number,
	BaseY: number, -- pied des vitres (= BeltY)
	TopY: number, -- dessous du toit
	WindshieldFrontZ: number,
	RoofFrontZ: number,
	RoofRearZ: number,
}
local function cabin(list: { Spec }, c: Cabin)
	local width = c.HalfWidth * 2
	local height = c.TopY - c.BaseY
	local midY = (c.TopY + c.BaseY) / 2
	local shieldLength = c.RoofFrontZ - c.WindshieldFrontZ
	add(list, wedge("Windshield", Vector3.new(width - 0.24, height, shieldLength), at(0, midY, c.WindshieldFrontZ + shieldLength / 2), "Glass"))
	pair(list, function(s)
		return wedge("Pillar", Vector3.new(0.14, height, shieldLength), at(s * (c.HalfWidth - 0.07), midY, c.WindshieldFrontZ + shieldLength / 2), "Body")
	end)
	local roofLength = c.RoofRearZ - c.RoofFrontZ
	add(list, block("Roof", Vector3.new(width, 0.24, roofLength), at(0, c.TopY + 0.12, c.RoofFrontZ + roofLength / 2), "Body"))
	add(list, block("Window", Vector3.new(width - 0.1, height, roofLength), at(0, midY, c.RoofFrontZ + roofLength / 2), "Glass"))
	add(list, block("Pillar", Vector3.new(width + 0.02, height, 0.3), at(0, midY, c.RoofFrontZ + roofLength * 0.48), "Body"))
	-- Les rétroviseurs sont un emplacement (Mirrors) : passe DÉTAILS.
end

-- Arrière incliné (hayon, lunette, fastback) : coin retourné, descendant vers l'arrière.
local function slopedRear(list: { Spec }, c: Cabin, rearZ: number, paint: Paint)
	local width = c.HalfWidth * 2
	local height = c.TopY - c.BaseY
	local midY = (c.TopY + c.BaseY) / 2
	local length = rearZ - c.RoofRearZ
	local center = at(0, midY, c.RoofRearZ + length / 2) * FLIP
	add(list, wedge(if paint == "Glass" then "RearWindow" else "Fastback", Vector3.new(width - 0.24, height, length), center, paint))
	pair(list, function(s)
		return wedge("Pillar", Vector3.new(0.14, height, length), at(s * (c.HalfWidth - 0.07), midY, c.RoofRearZ + length / 2) * FLIP, "Body")
	end)
end

--------------------------------------------------------------------------------
-- Les modèles
--------------------------------------------------------------------------------

local function kaze(): Body
	local m: Mounts = {
		NoseZ = -6.5, TailZ = 6.3, BottomY = -1.5, BeltY = 0.45, HalfWidth = 3.0,
		HoodFrontZ = -5.6, HoodRearZ = -2.8, HoodHalfWidth = 2.0,
		Wing = { Mount = "Roof", Z = 3.4, Y = 2.3, Width = 4.6 },
		NoseSlope = { Length = 0.9, Drop = 0.32 },
	}
	local c: Cabin = { HalfWidth = 2.3, BaseY = 0.45, TopY = 2.05, WindshieldFrontZ = -2.8, RoofFrontZ = -0.6, RoofRearZ = 3.4 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 4.8, "Glass")
	-- Face avant : phares étirés, calandre ; feux arrière.
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.25, 0.42, 0.12), at(s * 2.0, 0.08, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(2.3, 0.55, 0.12), at(0, -0.3, m.NoseZ - 0.04), "Trim"))
	add(list, block("Valance", Vector3.new(5.8, 0.3, 0.14), at(0, m.BottomY + 0.5, m.NoseZ - 0.05), "Trim"))
	pair(list, function(s)
		return block("TailLight", Vector3.new(1.0, 0.42, 0.12), at(s * 2.25, 0.1, m.TailZ + 0.04), "Tail")
	end)
	add(list, block("Diffuser", Vector3.new(4.4, 0.3, 0.14), at(0, m.BottomY + 0.45, m.TailZ + 0.05), "Trim"))
	return {
		Id = "kaze",
		Name = "Kaze",
		Description = "citadine WRC moderne à hayon",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

local function yama(): Body
	local m: Mounts = {
		NoseZ = -6.5, TailZ = 6.5, BottomY = -1.45, BeltY = 0.55, HalfWidth = 2.95,
		HoodFrontZ = -6.5, HoodRearZ = -2.3, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 6.1, Y = 0.55, Width = 4.2 },
	}
	local c: Cabin = { HalfWidth = 2.2, BaseY = 0.55, TopY = 2.05, WindshieldFrontZ = -2.3, RoofFrontZ = -0.9, RoofRearZ = 2.5 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 3.7, "Glass")
	-- Phares ronds, pare-chocs chromés, feux carrés.
	pair(list, function(s)
		return disc("HeadLight", 0.72, 0.14, at(s * 2.0, 0.05, m.NoseZ - 0.05), "Head")
	end)
	pair(list, function(s)
		return disc("HeadLightRim", 0.86, 0.1, at(s * 2.0, 0.05, m.NoseZ - 0.02), "Chrome")
	end)
	add(list, block("Grille", Vector3.new(2.6, 0.6, 0.12), at(0, -0.15, m.NoseZ - 0.04), "Trim"))
	add(list, block("Bumper", Vector3.new(6.0, 0.26, 0.28), at(0, -0.8, m.NoseZ - 0.12), "Chrome"))
	add(list, block("Bumper", Vector3.new(6.0, 0.26, 0.28), at(0, -0.75, m.TailZ + 0.12), "Chrome"))
	pair(list, function(s)
		return block("TailLight", Vector3.new(0.95, 0.5, 0.12), at(s * 2.2, 0.15, m.TailZ + 0.04), "Tail")
	end)
	-- Ligne de caisse chromée, d'un bout à l'autre.
	pair(list, function(s)
		return block("Trim", Vector3.new(0.06, 0.08, 4.8), at(s * (m.HalfWidth + 0.02), 0.25, 0), "Chrome")
	end)
	return {
		Id = "yama",
		Name = "Yama",
		Description = "berline trois volumes, années 70",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

local function raijin(): Body
	local m: Mounts = {
		NoseZ = -6.7, TailZ = 6.7, BottomY = -1.55, BeltY = 0.2, HalfWidth = 3.1,
		HoodFrontZ = -6.7, HoodRearZ = -1.2, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 6.25, Y = 0.3, Width = 4.6 },
	}
	local c: Cabin = { HalfWidth = 2.2, BaseY = 0.2, TopY = 1.6, WindshieldFrontZ = -1.2, RoofFrontZ = 0.8, RoofRearZ = 2.7 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 6.0, "Body")
	-- Persiennes sur le fastback (pente de ~23°).
	local slope = math.atan2(c.TopY - c.BaseY, 6.0 - c.RoofRearZ)
	for _, t in ipairs({ 0.22, 0.38, 0.54, 0.7 }) do
		local z = c.RoofRearZ + (6.0 - c.RoofRearZ) * t
		local y = c.TopY - (c.TopY - c.BaseY) * t + 0.05
		add(list, block("Louver", Vector3.new(3.6, 0.07, 0.3), at(0, y, z) * CFrame.Angles(slope, 0, 0), "Trim"))
	end
	-- Ailes bombées des années Groupe B, au-dessus de la ligne de caisse.
	for _, z in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Arch", Vector3.new(1.2, 0.5, ARCH_HALF * 2 + 0.3), at(s * (m.HalfWidth - 0.55), m.BeltY + 0.2, z), "Body")
		end)
	end
	-- Prises d'air latérales devant les roues arrière.
	pair(list, function(s)
		return block("Intake", Vector3.new(0.12, 0.55, 1.3), at(s * (m.HalfWidth + 0.03), -0.35, 2.0), "Trim")
	end)
	-- Phares rectangulaires bas, bandeau de feux arrière.
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.35, 0.3, 0.12), at(s * 2.05, -0.2, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(2.3, 0.3, 0.12), at(0, -0.2, m.NoseZ - 0.04), "Trim"))
	add(list, block("TailLight", Vector3.new(5.4, 0.24, 0.12), at(0, -0.05, m.TailZ + 0.04), "Tail"))
	add(list, block("RearPanel", Vector3.new(4.2, 0.5, 0.12), at(0, -0.6, m.TailZ + 0.04), "Trim"))
	return {
		Id = "raijin",
		Name = "Raijin",
		Description = "coupé en coin des années 80, ailes larges",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

-- Berline de rallye japonaise, nez plongeant, grande bouche d'air (façon Evo).
local function hayate(): Body
	local m: Mounts = {
		NoseZ = -6.8, TailZ = 6.6, BottomY = -1.45, BeltY = 0.5, HalfWidth = 3.0,
		HoodFrontZ = -5.8, HoodRearZ = -2.5, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 6.0, Y = 0.5, Width = 4.6 },
		NoseSlope = { Length = 1.0, Drop = 0.36 },
		TailSlope = { Length = 0.6, Drop = 0.15 },
	}
	local c: Cabin = { HalfWidth = 2.3, BaseY = 0.5, TopY = 1.95, WindshieldFrontZ = -2.5, RoofFrontZ = -0.3, RoofRearZ = 2.4 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 3.9, "Glass")
	-- Phares effilés, petite calandre, grande bouche d'air en bas.
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.35, 0.3, 0.12), at(s * 1.95, -0.02, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(1.7, 0.28, 0.12), at(0, -0.05, m.NoseZ - 0.04), "Trim"))
	add(list, block("Intake", Vector3.new(3.8, 0.5, 0.12), at(0, -0.72, m.NoseZ - 0.04), "Trim"))
	pair(list, function(s)
		return block("Intake", Vector3.new(0.9, 0.3, 0.12), at(s * 2.4, -0.8, m.NoseZ - 0.04), "Trim")
	end)
	pair(list, function(s)
		return block("TailLight", Vector3.new(1.15, 0.36, 0.12), at(s * 2.2, 0.08, m.TailZ + 0.04), "Tail")
	end)
	add(list, block("Diffuser", Vector3.new(4.2, 0.3, 0.14), at(0, m.BottomY + 0.45, m.TailZ + 0.05), "Trim"))
	return {
		Id = "hayate",
		Name = "Hayate",
		Description = "berline de rallye, nez plongeant (façon Evo)",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

-- Berline de rallye à phares ronds et antibrouillards (façon Impreza).
local function hoshi(): Body
	local m: Mounts = {
		NoseZ = -6.6, TailZ = 6.4, BottomY = -1.45, BeltY = 0.55, HalfWidth = 3.0,
		HoodFrontZ = -5.7, HoodRearZ = -2.4, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 5.9, Y = 0.55, Width = 4.5 },
		NoseSlope = { Length = 0.9, Drop = 0.3 },
		TailSlope = { Length = 0.5, Drop = 0.12 },
	}
	local c: Cabin = { HalfWidth = 2.25, BaseY = 0.55, TopY = 2.05, WindshieldFrontZ = -2.4, RoofFrontZ = -0.4, RoofRearZ = 2.3 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 3.7, "Glass")
	-- Phares ronds, calandre étroite, antibrouillards dans le bouclier.
	pair(list, function(s)
		return disc("HeadLight", 0.62, 0.14, at(s * 2.05, 0.0, m.NoseZ - 0.05), "Head")
	end)
	add(list, block("Grille", Vector3.new(1.6, 0.34, 0.12), at(0, -0.02, m.NoseZ - 0.04), "Trim"))
	add(list, block("Intake", Vector3.new(2.6, 0.36, 0.12), at(0, -0.72, m.NoseZ - 0.04), "Trim"))
	pair(list, function(s)
		return disc("FogLight", 0.42, 0.12, at(s * 1.85, -0.7, m.NoseZ - 0.05), "Lamp")
	end)
	pair(list, function(s)
		return block("TailLight", Vector3.new(1.0, 0.42, 0.12), at(s * 2.15, 0.12, m.TailZ + 0.04), "Tail")
	end)
	return {
		Id = "hoshi",
		Name = "Hoshi",
		Description = "berline de rallye à phares ronds (façon Impreza)",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

-- Citadine compacte moderne, porte-à-faux très courts, hayon presque droit.
local function tora(): Body
	local m: Mounts = {
		NoseZ = -6.0, TailZ = 5.6, BottomY = -1.45, BeltY = 0.5, HalfWidth = 3.0,
		HoodFrontZ = -5.2, HoodRearZ = -2.6, HoodHalfWidth = 2.0,
		Wing = { Mount = "Roof", Z = 3.0, Y = 2.25, Width = 4.4 },
		NoseSlope = { Length = 0.8, Drop = 0.3 },
	}
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.5, TopY = 2.15, WindshieldFrontZ = -2.6, RoofFrontZ = -0.5, RoofRearZ = 3.0 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 4.4, "Glass")
	-- Phares en amande, grande calandre trapézoïdale, feux verticaux.
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.2, 0.36, 0.12), at(s * 1.95, 0.1, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(2.6, 0.6, 0.12), at(0, -0.45, m.NoseZ - 0.04), "Trim"))
	pair(list, function(s)
		return block("TailLight", Vector3.new(0.5, 0.8, 0.12), at(s * 2.45, 0.35, m.TailZ + 0.04), "Tail")
	end)
	add(list, block("Diffuser", Vector3.new(4.2, 0.3, 0.14), at(0, m.BottomY + 0.45, m.TailZ + 0.05), "Trim"))
	return {
		Id = "tora",
		Name = "Tora",
		Description = "citadine compacte moderne, porte-à-faux courts",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

-- Petite bombe à moteur central des années 80 : cabine avancée, long capot moteur arrière.
local function kumo(): Body
	local m: Mounts = {
		NoseZ = -6.2, TailZ = 6.3, BottomY = -1.5, BeltY = 0.45, HalfWidth = 3.15,
		HoodFrontZ = -5.6, HoodRearZ = -2.4, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 5.9, Y = 0.45, Width = 4.8 },
		NoseSlope = { Length = 0.9, Drop = 0.3 },
	}
	local c: Cabin = { HalfWidth = 2.25, BaseY = 0.45, TopY = 2.0, WindshieldFrontZ = -2.4, RoofFrontZ = -0.4, RoofRearZ = 1.7 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 5.3, "Body")
	-- Ailes arrière bombées et grandes prises d'air du moteur.
	for _, z in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Arch", Vector3.new(1.0, 0.45, ARCH_HALF * 2 + 0.3), at(s * (m.HalfWidth - 0.5), m.BeltY + 0.18, z), "Body")
		end)
	end
	pair(list, function(s)
		return block("Intake", Vector3.new(0.14, 0.8, 1.4), at(s * (m.HalfWidth + 0.03), -0.2, 2.1), "Trim")
	end)
	add(list, block("Louver", Vector3.new(3.4, 0.07, 1.6), at(0, 1.1, 3.6) * CFrame.Angles(math.rad(22), 0, 0), "Trim"))
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.3, 0.28, 0.12), at(s * 1.95, 0.05, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(1.8, 0.24, 0.12), at(0, 0.05, m.NoseZ - 0.04), "Trim"))
	add(list, block("TailLight", Vector3.new(5.2, 0.3, 0.12), at(0, 0.0, m.TailZ + 0.04), "Tail"))
	add(list, block("RearPanel", Vector3.new(4.4, 0.5, 0.12), at(0, -0.6, m.TailZ + 0.04), "Trim"))
	return {
		Id = "kumo",
		Name = "Kumo",
		Description = "bombe à moteur central des années 80",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

-- Coupé bas et long, capot interminable, cabine reculée (propulsion des années 80).
local function ryu(): Body
	local m: Mounts = {
		NoseZ = -6.9, TailZ = 6.6, BottomY = -1.55, BeltY = 0.2, HalfWidth = 3.05,
		HoodFrontZ = -5.7, HoodRearZ = -1.0, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 6.15, Y = 0.2, Width = 4.6 },
		NoseSlope = { Length = 1.2, Drop = 0.35 },
	}
	local c: Cabin = { HalfWidth = 2.15, BaseY = 0.2, TopY = 1.55, WindshieldFrontZ = -1.0, RoofFrontZ = 0.7, RoofRearZ = 2.4 }
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, 5.2, "Body")
	-- Quatre phares ronds, ailes élargies, feux ronds par paires.
	for _, x in ipairs({ -2.25, -1.45, 1.45, 2.25 }) do
		add(list, disc("HeadLight", 0.5, 0.14, at(x, -0.15, m.NoseZ - 0.05), "Head"))
	end
	add(list, block("Grille", Vector3.new(1.6, 0.26, 0.12), at(0, -0.2, m.NoseZ - 0.04), "Trim"))
	for _, z in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Arch", Vector3.new(1.1, 0.45, ARCH_HALF * 2 + 0.3), at(s * (m.HalfWidth - 0.5), m.BeltY + 0.18, z), "Body")
		end)
	end
	for _, x in ipairs({ -2.2, -1.6, 1.6, 2.2 }) do
		add(list, disc("TailLight", 0.45, 0.12, at(x, -0.1, m.TailZ + 0.05), "Tail"))
	end
	add(list, block("RearPanel", Vector3.new(4.0, 0.45, 0.12), at(0, -0.65, m.TailZ + 0.04), "Trim"))
	return {
		Id = "ryu",
		Name = "Ryu",
		Description = "coupé long et bas des années 80, quatre phares ronds",
		Custom = true,
		Slots = { "Wing", "Bumper", "Hood", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" },
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

--[[
	MODÈLES INSPIRÉS DES LÉGENDES DU RALLYE, faits dans Blender (CarMeshes.luau,
	assets/meshes) : leur vrai look vient du maillage importé. Ici, une version
	en pièces toute simple, aux mêmes mesures, le temps de l'import.
]]
local SLOTS_ALL = { "Wing", "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" }
local SLOTS_FIXED_WING = { "Bumper", "Hood", "Flares", "Rims", "Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps", "Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet" }

local function legend(id: string, name: string, description: string, m: Mounts, c: Cabin, rearZ: number, fixedWing: boolean): Body
	local list: { Spec } = {}
	lowerBody(list, m)
	cabin(list, c)
	slopedRear(list, c, rearZ, "Glass")
	pair(list, function(s)
		return block("HeadLight", Vector3.new(1.0, 0.3, 0.12), at(s * 1.75, m.BeltY - 0.45, m.NoseZ - 0.04), "Head")
	end)
	add(list, block("Grille", Vector3.new(2.4, 0.55, 0.12), at(0, m.BeltY - 1.15, m.NoseZ - 0.04), "Trim"))
	pair(list, function(s)
		return block("TailLight", Vector3.new(0.9, 0.36, 0.12), at(s * 2.0, m.BeltY - 0.45, m.TailZ + 0.04), "Tail")
	end)
	return {
		Id = id,
		Name = name,
		Description = description,
		Custom = true,
		Slots = if fixedWing then SLOTS_FIXED_WING else SLOTS_ALL,
		Mounts = m,
		Cabin = c,
		Parts = list,
	}
end

local function hatch(noseZ: number, tailZ: number, beltY: number, hoodFrontZ: number, hoodRearZ: number, roofRearZ: number, topY: number): Mounts
	return {
		NoseZ = noseZ, TailZ = tailZ, BottomY = -1.45, BeltY = beltY, HalfWidth = 3.0,
		HoodFrontZ = hoodFrontZ, HoodRearZ = hoodRearZ, HoodHalfWidth = 2.0,
		Wing = { Mount = "Roof", Z = roofRearZ, Y = topY, Width = 4.6 },
		NoseSlope = { Length = 0.8, Drop = 0.3 },
	}
end

local function tsubasa(): Body
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.6, TopY = 2.36, WindshieldFrontZ = -2.3, RoofFrontZ = -0.55, RoofRearZ = 4.35 }
	return legend("tsubasa", "Tsubasa", "compacte de WRC moderne, aéro démesurée (façon Yaris WRC)", hatch(-6.35, 5.55, 0.6, -5.5, -2.3, 4.35, 2.36), c, 5.0, true)
end

local function requin(): Body
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.62, TopY = 2.34, WindshieldFrontZ = -2.35, RoofFrontZ = -0.45, RoofRearZ = 4.3 }
	return legend("requin", "Requin", "compacte au toit flottant et montant en aileron de requin (façon DS3 WRC)", hatch(-6.3, 5.6, 0.62, -5.45, -2.35, 4.3, 2.34), c, 4.95, false)
end

local function lynx(): Body
	local c: Cabin = { HalfWidth = 2.33, BaseY = 0.6, TopY = 2.3, WindshieldFrontZ = -2.3, RoofFrontZ = -0.6, RoofRearZ = 4.1 }
	return legend("lynx", "Lynx", "petite compacte aux yeux de félin (façon 206 WRC)", hatch(-6.2, 5.45, 0.6, -5.4, -2.3, 4.1, 2.3), c, 4.85, false)
end

local function griffe(): Body
	local c: Cabin = { HalfWidth = 2.37, BaseY = 0.66, TopY = 2.34, WindshieldFrontZ = -2.3, RoofFrontZ = -0.5, RoofRearZ = 4.2 }
	return legend("griffe", "Griffe", "compacte moderne aux feux en griffes (façon 208)", hatch(-6.25, 5.5, 0.66, -5.45, -2.3, 4.2, 2.34), c, 4.9, false)
end

local function furia(): Body
	local c: Cabin = { HalfWidth = 2.43, BaseY = 0.72, TopY = 2.46, WindshieldFrontZ = -2.5, RoofFrontZ = -1.05, RoofRearZ = 4.75 }
	return legend("furia", "Furia", "cinq portes très carrée, quatre phares carrés (façon Delta Integrale)", hatch(-6.3, 5.7, 0.72, -5.6, -2.5, 4.75, 2.46), c, 5.15, false)
end

local function blitz(): Body
	local m: Mounts = {
		NoseZ = -7.0, TailZ = 6.1, BottomY = -1.45, BeltY = 0.62, HalfWidth = 3.0,
		HoodFrontZ = -5.9, HoodRearZ = -2.0, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 5.4, Y = 0.78, Width = 5.6 },
		NoseSlope = { Length = 1.1, Drop = 0.4 },
	}
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.62, TopY = 2.22, WindshieldFrontZ = -2.0, RoofFrontZ = -0.3, RoofRearZ = 2.45 }
	return legend("blitz", "Blitz", "coupé Groupe B au long nez et aileron géant (façon Quattro S1)", m, c, 4.0, true)
end

local function fauve(): Body
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.66, TopY = 2.38, WindshieldFrontZ = -2.35, RoofFrontZ = -0.55, RoofRearZ = 4.25 }
	return legend("fauve", "Fauve", "petite bombe Groupe B à moteur central, prises d'air derrière les portes (façon 205 T16)", hatch(-6.15, 5.45, 0.66, -5.45, -2.35, 4.25, 2.38), c, 4.95, false)
end

local function cuneo(): Body
	local m: Mounts = {
		NoseZ = -6.1, TailZ = 5.5, BottomY = -1.45, BeltY = 0.62, HalfWidth = 3.0,
		HoodFrontZ = -5.3, HoodRearZ = -2.2, HoodHalfWidth = 2.0,
		Wing = { Mount = "Deck", Z = 5.2, Y = 0.96, Width = 5.4 },
		NoseSlope = { Length = 1.2, Drop = 0.5 },
	}
	local c: Cabin = { HalfWidth = 2.35, BaseY = 0.62, TopY = 2.06, WindshieldFrontZ = -2.2, RoofFrontZ = -0.1, RoofRearZ = 1.35 }
	return legend("cuneo", "Cuneo", "coupé à moteur central en coin arrondi, persiennes et feux ronds (façon Stratos)", m, c, 4.75, false)
end

CarBodies.LIST = {
	{
		Id = "origine",
		Name = "Origine",
		Description = "la carrosserie de série du gabarit",
		Custom = false,
		Slots = { "Rims" },
		Mounts = nil,
		Parts = {},
	},
	kaze(),
	yama(),
	raijin(),
	hayate(),
	hoshi(),
	tora(),
	kumo(),
	ryu(),
	tsubasa(),
	requin(),
	lynx(),
	griffe(),
	furia(),
	blitz(),
	fauve(),
	cuneo(),
} :: { Body }

--------------------------------------------------------------------------------
-- Les pièces
--------------------------------------------------------------------------------

CarBodies.SLOTS = {
	{ Key = "Wing", Name = "Aileron", Options = { { Name = "Aucun" }, { Name = "Becquet" }, { Name = "Aileron rallye" }, { Name = "Grand aileron" }, { Name = "Double étage" } } },
	{ Key = "Bumper", Name = "Bouclier", Options = { { Name = "Route" }, { Name = "Rallye" }, { Name = "Course" } } },
	{ Key = "Hood", Name = "Capot", Options = { { Name = "Lisse" }, { Name = "Prises d'air" }, { Name = "Écope" }, { Name = "Rampe de phares" } } },
	{ Key = "Flares", Name = "Ailes", Options = { { Name = "D'origine" }, { Name = "Élargies" } } },
	{ Key = "Rims", Name = "Jantes", Options = { { Name = "Or" }, { Name = "Noires" }, { Name = "Blanches" }, { Name = "Chrome" }, { Name = "Sakura" }, { Name = "Néon" } } },
	-- Accessoires : au choix du joueur, même sur la carrosserie de sa voiture.
	{ Key = "Mirrors", Name = "Rétroviseurs", Accessory = true, Options = { { Name = "Route" }, { Name = "Course" }, { Name = "Rallye" } } },
	{ Key = "Roof", Name = "Toit", Accessory = true, Options = { { Name = "Lisse" }, { Name = "Écope" }, { Name = "Aileron de requin" }, { Name = "Antenne" } } },
	{ Key = "Skirts", Name = "Bas de caisse", Accessory = true, Options = { { Name = "D'origine" }, { Name = "Jupes" }, { Name = "Lames" } } },
	{ Key = "Diffuser", Name = "Arrière", Accessory = true, Options = { { Name = "D'origine" }, { Name = "Diffuseur" }, { Name = "Diffuseur course" } } },
	{ Key = "Exhaust", Name = "Échappement", Accessory = true, Options = { { Name = "Simple" }, { Name = "Double" }, { Name = "Canon" }, { Name = "Quadruple" }, { Name = "Latéral" }, { Name = "Relevé" }, { Name = "Titane" } } },
	{ Key = "Mudflaps", Name = "Bavettes", Accessory = true, Options = { { Name = "Aucune" }, { Name = "Rallye" }, { Name = "Longues" } } },
	{ Key = "Moustache", Name = "Moustache", Accessory = true, Options = { { Name = "Aucune" }, { Name = "Fine" }, { Name = "Lame" }, { Name = "Chromée" }, { Name = "Double" } } },
	{ Key = "Grille", Name = "Calandre", Accessory = true, Options = { { Name = "D'origine" }, { Name = "Nid d'abeille" }, { Name = "Barres chromées" }, { Name = "Grillage rallye" } } },
	{ Key = "Canards", Name = "Ailettes", Accessory = true, Options = { { Name = "Aucune" }, { Name = "Simples" }, { Name = "Doubles" } } },
	{ Key = "SunStrip", Name = "Bandeau de pare-brise", Accessory = true, Options = { { Name = "Aucun" }, { Name = "Noir" }, { Name = "Blanc" }, { Name = "Couleur caisse" } } },
	{ Key = "HoodPins", Name = "Goupilles de capot", Accessory = true, Options = { { Name = "Aucune" }, { Name = "Chromées" }, { Name = "Noires" } } },
	{ Key = "Tow", Name = "Remorquage", Accessory = true, Options = { { Name = "Anneaux rouges" }, { Name = "Sangles jaunes" }, { Name = "Sangles bleues" }, { Name = "Aucun" } } },
	{ Key = "LightCovers", Name = "Caches-phares", Accessory = true, Options = { { Name = "Aucun" }, { Name = "Adhésif en croix" }, { Name = "Caches noirs" } } },
	{ Key = "SideVents", Name = "Ouïes", Accessory = true, Options = { { Name = "Aucune" }, { Name = "Ailes avant" }, { Name = "Prises arrière" } } },
	{ Key = "WindowNet", Name = "Filet de vitre", Accessory = true, Options = { { Name = "Aucun" }, { Name = "Noir" }, { Name = "Rouge" } } },
} :: { Slot }

-- Couleurs des jantes : le cercle (Rim) et les branches (Spoke) des roues du gabarit.
local RIMS = {
	{ Rim = Color3.fromRGB(205, 165, 60), Spoke = Color3.fromRGB(32, 32, 36), Material = Enum.Material.SmoothPlastic },
	{ Rim = Color3.fromRGB(30, 30, 34), Spoke = Color3.fromRGB(70, 70, 78), Material = Enum.Material.SmoothPlastic },
	{ Rim = Color3.fromRGB(236, 236, 240), Spoke = Color3.fromRGB(190, 190, 198), Material = Enum.Material.SmoothPlastic },
	{ Rim = CHROME, Spoke = Color3.fromRGB(140, 146, 156), Material = Enum.Material.Metal },
	{ Rim = Color3.fromRGB(255, 46, 126), Spoke = Color3.fromRGB(30, 30, 34), Material = Enum.Material.SmoothPlastic },
	{ Rim = Color3.fromRGB(0, 214, 255), Spoke = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Neon },
}

local function wingParts(list: { Spec }, m: Mounts, option: number)
	local w = m.Wing
	if option == 2 then
		if w.Mount == "Roof" then
			-- Becquet de pavillon, relevé vers l'arrière.
			add(list, block("Spoiler", Vector3.new(w.Width, 0.12, 0.8), at(0, w.Y + 0.02, w.Z + 0.3) * CFrame.Angles(math.rad(-10), 0, 0), "Body"))
		else
			add(list, block("Spoiler", Vector3.new(w.Width, 0.22, 0.45), at(0, w.Y + 0.11, w.Z), "Body"))
		end
		return
	end
	-- 3 aileron rallye ; 4 grand aileron (hauts montants peints, large plan,
	-- grandes dérives : façon Evo / Impreza) ; 5 double étage.
	local tall = option == 4
	local lift = if w.Mount == "Roof" then (if tall then 0.75 else 0.45) else (if tall then 1.35 else 0.85)
	local span = w.Width + (if tall then 0.9 else 0.6)
	local chord = if tall then 1.45 else 1.25
	pair(list, function(s)
		return block("WingPost", Vector3.new(if tall then 0.24 else 0.16, lift, if tall then 0.7 else 0.5), at(s * w.Width * 0.34, w.Y + lift / 2, w.Z) * CFrame.Angles(math.rad(if tall then -8 else 0), 0, 0), if tall then "Body" else "Trim")
	end)
	add(list, block("Wing", Vector3.new(span, if tall then 0.18 else 0.14, chord), at(0, w.Y + lift + 0.05, w.Z + 0.2) * CFrame.Angles(math.rad(-6), 0, 0), "Body"))
	pair(list, function(s)
		return block("WingPlate", Vector3.new(0.1, if tall then 0.95 else 0.65, chord + 0.2), at(s * span / 2, w.Y + lift, w.Z + 0.2), if tall then "Body" else "Trim")
	end)
	if option == 5 then
		add(list, block("Wing", Vector3.new(span - 0.2, 0.12, 0.9), at(0, w.Y + lift + 0.42, w.Z + 0.3) * CFrame.Angles(math.rad(-12), 0, 0), "Trim"))
	end
end

-- Demi-largeur de la face avant : les pièces qui s'y posent n'en dépassent pas.
local function noseHalf(m: Mounts): number
	return m.NoseHalfWidth or m.HalfWidth
end

local function bumperParts(list: { Spec }, m: Mounts, option: number)
	if option == 2 then
		-- Rallye : sabot, lèvre, deux phares longue portée.
		add(list, block("SkidPlate", Vector3.new(noseHalf(m) * 2 - 1.0, 0.12, 1.6), at(0, m.BottomY + 0.02, m.NoseZ + 0.6), "Trim"))
		add(list, block("Lip", Vector3.new(noseHalf(m) * 2, 0.32, 0.26), at(0, m.BottomY + 0.18, m.NoseZ - 0.12), "Trim"))
		pair(list, function(s)
			return disc("SpotLamp", 0.62, 0.16, at(s * 1.25, m.BottomY + 0.62, m.NoseZ - 0.16), "Lamp")
		end)
		pair(list, function(s)
			return disc("SpotLampRim", 0.76, 0.12, at(s * 1.25, m.BottomY + 0.62, m.NoseZ - 0.1), "Trim")
		end)
	elseif option == 3 then
		-- Course : grande lame avant et ailettes.
		add(list, block("Splitter", Vector3.new(noseHalf(m) * 2 + 0.1, 0.1, 0.6), at(0, m.BottomY + 0.1, m.NoseZ - 0.1), "Trim"))
		pair(list, function(s)
			return block("Canard", Vector3.new(0.55, 0.06, 0.45), at(s * (noseHalf(m) - 0.05), m.BottomY + 0.7, m.NoseZ - 0.15) * CFrame.Angles(0, 0, s * math.rad(-12)), "Trim")
		end)
	end
end

local function hoodParts(list: { Spec }, m: Mounts, option: number)
	local mid = (m.HoodFrontZ + m.HoodRearZ) / 2
	local y = m.BeltY
	if option == 2 then
		pair(list, function(s)
			return block("Vent", Vector3.new(0.9, 0.08, 1.3), at(s * 0.95, y + 0.04, mid), "Trim")
		end)
	elseif option == 3 then
		add(list, block("Bulge", Vector3.new(1.7, 0.22, 2.4), at(0, y + 0.11, mid + 0.3), "Body"))
		add(list, block("Vent", Vector3.new(1.2, 0.18, 0.1), at(0, y + 0.13, mid - 0.92), "Trim"))
	elseif option == 4 then
		-- Rampe de phares de nuit, à l'avant du capot.
		local z = m.HoodFrontZ + 0.55
		add(list, block("LampBar", Vector3.new(3.3, 0.5, 0.3), at(0, y + 0.3, z), "Trim"))
		for _, x in ipairs({ -1.2, -0.4, 0.4, 1.2 }) do
			add(list, disc("SpotLamp", 0.44, 0.12, at(x, y + 0.3, z - 0.17), "Lamp"))
		end
	end
end

local function flareParts(list: { Spec }, m: Mounts, option: number)
	if option ~= 2 then
		return
	end
	for _, z in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Flare", Vector3.new(0.4, 0.8, ARCH_HALF * 2 + 0.2), at(s * (m.HalfWidth + 0.18), m.BeltY - 0.3, z), "Body")
		end)
		pair(list, function(s)
			return block("FlareLip", Vector3.new(0.46, 0.1, ARCH_HALF * 2 + 0.2), at(s * (m.HalfWidth + 0.2), m.BeltY - 0.72, z), "Trim")
		end)
	end
end

--------------------------------------------------------------------------------
-- Accessoires (emplacements Accessory) et passe DÉTAILS
--------------------------------------------------------------------------------

local function mirrorParts(list: { Spec }, c: Cabin, option: number)
	local y = c.BaseY + 0.55
	local z = c.RoofFrontZ - 0.3
	pair(list, function(s)
		local x = s * (c.HalfWidth + 0.25)
		if option == 2 then
			-- Course : petite coque profilée, peinte.
			return block("Mirror", Vector3.new(0.34, 0.2, 0.62), at(x, y, z) * CFrame.Angles(0, s * math.rad(-8), 0), "Body")
		elseif option == 3 then
			-- Rallye : grande coque, bien écartée.
			return block("Mirror", Vector3.new(0.55, 0.36, 0.42), at(s * (c.HalfWidth + 0.42), y, z), "Trim")
		end
		return block("Mirror", Vector3.new(0.45, 0.28, 0.5), at(x, y, z), "Trim")
	end)
	if option == 3 then
		pair(list, function(s)
			return block("MirrorArm", Vector3.new(0.34, 0.06, 0.08), at(s * (c.HalfWidth + 0.15), y - 0.1, z), "Trim")
		end)
	end
end

local function roofParts(list: { Spec }, c: Cabin, option: number)
	local top = c.TopY + 0.24
	if option == 2 then
		-- Écope : l'air frais de l'habitacle, à l'avant du toit.
		add(list, block("RoofScoop", Vector3.new(1.1, 0.26, 1.0), at(0, top + 0.13, c.RoofFrontZ + 0.7), "Body"))
		add(list, block("Vent", Vector3.new(0.9, 0.16, 0.06), at(0, top + 0.13, c.RoofFrontZ + 0.18), "Trim"))
	elseif option == 3 then
		-- Aileron de requin : la dérive de toit des voitures de course.
		add(list, wedge("SharkFin", Vector3.new(0.1, 0.45, 1.5), at(0, top + 0.22, (c.RoofFrontZ + c.RoofRearZ) / 2 + 0.3) * FLIP, "Body"))
	elseif option == 4 then
		add(list, block("Antenna", Vector3.new(0.05, 1.3, 0.05), at(0.8, top + 0.65, c.RoofRearZ - 0.5), "Trim"))
	end
end

local function skirtParts(list: { Spec }, m: Mounts, option: number)
	local length = (WHEEL_Z - ARCH_HALF) * 2
	if option == 2 then
		pair(list, function(s)
			return block("SideSkirt", Vector3.new(0.26, 0.36, length), at(s * (m.HalfWidth + 0.1), m.BottomY + 0.16, 0), "Body")
		end)
	elseif option == 3 then
		pair(list, function(s)
			return block("SideBlade", Vector3.new(0.5, 0.08, length), at(s * (m.HalfWidth + 0.15), m.BottomY + 0.02, 0), "Trim")
		end)
	end
end

local function diffuserParts(list: { Spec }, m: Mounts, option: number)
	if option == 1 then
		return
	end
	local race = option == 3
	local width = if race then 5.2 else 4.2
	add(list, block("Diffuser", Vector3.new(width, 0.2, 0.6), at(0, m.BottomY + 0.12, m.TailZ + 0.22), "Trim"))
	local fins = if race then { -2.0, -1.0, 0, 1.0, 2.0 } else { -1.2, 0, 1.2 }
	for _, x in ipairs(fins) do
		add(list, block("DiffuserFin", Vector3.new(0.08, if race then 0.5 else 0.34, 0.6), at(x, m.BottomY + 0.3, m.TailZ + 0.22), "Trim"))
	end
end

local TITANIUM = Color3.fromRGB(125, 115, 205) -- titane bleui par la chaleur

-- Embouts d'échappement ; renvoie où sortent les flammes (Exhaust.luau) : X, Y, Z.
local function exhaustParts(list: { Spec }, m: Mounts, option: number): (number, number, number)
	local z = m.TailZ + 0.15
	local y = m.BottomY + 0.5
	if option == 2 then
		-- Double, au centre.
		pair(list, function(s)
			return disc("ExhaustTip", 0.34, 0.45, at(s * 0.45, y - 0.05, z), "Chrome")
		end)
		return 0.45, y - 0.05, z
	elseif option == 3 then
		-- Canon : un seul gros embout, au centre.
		add(list, disc("ExhaustTip", 0.62, 0.5, at(0, y, z), "Chrome"))
		return 0, y, z
	elseif option == 4 then
		-- Quadruple : deux paires, aux coins.
		for _, x in ipairs({ -1.75, -1.35, 1.35, 1.75 }) do
			add(list, disc("ExhaustTip", 0.3, 0.45, at(x, y - 0.05, z), "Chrome"))
		end
		return 1.55, y - 0.05, z
	elseif option == 5 then
		-- Latéral : sortie sur le flanc, devant la roue arrière.
		local x = m.HalfWidth + 0.12
		add(list, { Name = "ExhaustTip", Shape = "Cylinder", Size = Vector3.new(0.45, 0.36, 0.36), At = at(x, m.BottomY + 0.25, WHEEL_Z - ARCH_HALF - 0.4), Paint = "Chrome" })
		return x, m.BottomY + 0.25, WHEEL_Z - ARCH_HALF - 0.4
	elseif option == 6 then
		-- Relevé : l'embout pointe vers le haut, façon rallye d'autrefois.
		add(list, disc("ExhaustTip", 0.38, 0.55, at(1.6, y + 0.1, z) * CFrame.fromAxisAngle(Vector3.xAxis, math.rad(-25)), "Chrome"))
		return 1.6, y + 0.15, z
	elseif option == 7 then
		-- Titane : simple, bleui.
		local tip = disc("ExhaustTip", 0.4, 0.5, at(1.6, y, z), "Chrome")
		tip.Color = TITANIUM
		add(list, tip)
		return 1.6, y, z
	end
	add(list, disc("ExhaustTip", 0.36, 0.45, at(1.6, y, z), "Chrome"))
	return 1.6, y, z
end


-- Les pièces déjà posées qui portent ce nom (calandre, phares) : les accessoires s'y ajustent.
local function named(list: { Spec }, name: string): { Spec }
	local found = {}
	for _, spec in ipairs(list) do
		if spec.Name == name then
			table.insert(found, spec)
		end
	end
	return found
end

local WHITE = Color3.fromRGB(236, 236, 240)
local STRAP_YELLOW = Color3.fromRGB(255, 205, 30)
local STRAP_BLUE = Color3.fromRGB(40, 110, 230)
local NET_RED = Color3.fromRGB(205, 30, 40)
local AHEAD = 0.06 -- un accessoire posé devant la pièce qu'il habille (studs, vers l'avant)

--[[
	MOUSTACHE : la lame sous la calandre (le « sourire » des voitures de
	rallye). Posée sous la calandre du modèle, à sa largeur.
]]
local function moustacheParts(list: { Spec }, m: Mounts, option: number)
	if option == 1 then
		return
	end
	local grille = named(list, "Grille")[1]
	local grilleY = if grille then grille.At.Position.Y - grille.Size.Y / 2 else m.BottomY + 0.9
	local z = m.NoseZ - 0.1
	if option == 2 then
		-- Fine : un trait sous la calandre.
		add(list, block("Moustache", Vector3.new(3.0, 0.08, 0.14), at(0, grilleY - 0.1, z), "Trim"))
	elseif option == 3 then
		-- Lame : toute la largeur, au ras du sol.
		add(list, block("Moustache", Vector3.new(m.HalfWidth * 2 - 0.2, 0.12, 0.45), at(0, m.BottomY + 0.28, z - 0.12), "Trim"))
	elseif option == 4 then
		local tip = block("Moustache", Vector3.new(2.6, 0.09, 0.12), at(0, grilleY - 0.08, z), "Chrome")
		add(list, tip)
	elseif option == 5 then
		-- Double : deux traits, comme une moustache retroussée.
		pair(list, function(s)
			return block("Moustache", Vector3.new(1.5, 0.08, 0.14), at(s * 0.8, grilleY - 0.1, z) * CFrame.Angles(0, 0, s * math.rad(8)), "Trim")
		end)
	end
end

-- CALANDRE : une grille posée devant celle du modèle, à sa taille.
local function grilleParts(list: { Spec }, option: number)
	if option == 1 then
		return
	end
	for _, grille in ipairs(named(list, "Grille")) do
		local front = CFrame.new(0, 0, -AHEAD) * grille.At
		local size = grille.Size
		if option == 2 then
			-- Nid d'abeille : un maillage sombre, cerné de noir.
			add(list, block("GrilleMesh", Vector3.new(size.X - 0.1, size.Y - 0.06, 0.04), front, "Trim"))
			add(list, block("GrilleFrame", Vector3.new(size.X + 0.12, 0.06, 0.06), front * CFrame.new(0, size.Y / 2 + 0.02, 0), "Trim"))
		elseif option == 3 then
			-- Barres horizontales chromées.
			for _, t in ipairs({ -0.3, 0, 0.3 }) do
				add(list, block("GrilleBar", Vector3.new(size.X - 0.05, 0.05, 0.05), front * CFrame.new(0, t * size.Y, 0), "Chrome"))
			end
		elseif option == 4 then
			-- Grillage de rallye : plus grand que la calandre, pour les cailloux.
			add(list, block("GrilleMesh", Vector3.new(size.X + 0.3, size.Y + 0.15, 0.04), front, "Trim"))
			for _, x in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
				add(list, block("GrilleBar", Vector3.new(0.04, size.Y + 0.15, 0.05), front * CFrame.new(x * size.X, 0, -0.02), "Chrome"))
			end
		end
	end
end

-- AILETTES (canards) aux coins du bouclier avant.
local function canardParts(list: { Spec }, m: Mounts, option: number)
	if option == 1 then
		return
	end
	local rows = if option == 3 then { 0.55, 0.85 } else { 0.7 }
	for _, height in ipairs(rows) do
		pair(list, function(s)
			return block("Canard", Vector3.new(0.6, 0.06, 0.5), at(s * (noseHalf(m) - 0.1), m.BottomY + height, m.NoseZ - 0.12) * CFrame.Angles(0, 0, s * math.rad(-14)), "Trim")
		end)
	end
end

-- BANDEAU DE PARE-BRISE : la bande en haut du pare-brise (noire, blanche, ou à la couleur).
local function sunStripParts(list: { Spec }, c: Cabin, option: number)
	if option == 1 then
		return
	end
	local length = c.RoofFrontZ - c.WindshieldFrontZ
	local height = c.TopY - c.BaseY
	local slope = math.atan2(height, length)
	local t = 0.84
	local normal = Vector3.new(0, length, -height).Unit
	local point = Vector3.new(0, c.BaseY + height * t, c.WindshieldFrontZ + length * t) + normal * 0.03
	local strip = block("SunStrip", Vector3.new(c.HalfWidth * 2 - 0.3, 0.04, length * 0.3), CFrame.new(point) * CFrame.Angles(-slope, 0, 0), if option == 4 then "Body" else "Trim")
	if option == 3 then
		strip.Color = WHITE
	end
	add(list, strip)
end

-- GOUPILLES DE CAPOT : deux attaches rondes à l'avant du capot.
local function hoodPinParts(list: { Spec }, m: Mounts, option: number)
	if option == 1 then
		return
	end
	pair(list, function(s)
		local pin: Spec = { Name = "HoodPin", Shape = "Cylinder", Size = Vector3.new(0.06, 0.24, 0.24), At = at(s * 1.35, m.BeltY + 0.03, m.HoodFrontZ + 0.4) * CFrame.Angles(0, 0, math.pi / 2), Paint = if option == 2 then "Chrome" else "Trim" }
		return pin
	end)
end

-- ANNEAUX DE REMORQUAGE (avant et arrière) : anneaux rouges, sangles de couleur, ou rien.
local function towParts(list: { Spec }, m: Mounts, option: number)
	if option == 4 then
		return
	end
	local strap = option == 2 or option == 3
	for _, spot in ipairs({ { X = 1.35, Z = m.NoseZ - 0.12 }, { X = -1.35, Z = m.TailZ + 0.12 } }) do
		local spec = if strap
			then block("TowStrap", Vector3.new(0.3, 0.55, 0.04), at(spot.X, m.BottomY + 0.35, spot.Z), "Trim")
			else block("TowHook", Vector3.new(0.12, 0.26, 0.26), at(spot.X, m.BottomY + 0.3, spot.Z), "Accent")
		if strap then
			spec.Color = if option == 2 then STRAP_YELLOW else STRAP_BLUE
		end
		add(list, spec)
	end
end

-- CACHES-PHARES : posés devant chaque phare du modèle, à sa forme.
local function lightCoverParts(list: { Spec }, option: number)
	if option == 1 then
		return
	end
	for _, light in ipairs(named(list, "HeadLight")) do
		local front = CFrame.new(0, 0, -AHEAD) * light.At
		if option == 2 then
			-- Adhésif en croix : contre les éclats de verre, comme en course.
			local size = light.Size
			local span = math.max(size.X, size.Y, size.Z)
			for _, angle in ipairs({ math.rad(35), math.rad(-35) }) do
				add(list, block("LightTape", Vector3.new(span * 1.05, 0.06, 0.03), CFrame.new(front.Position) * CFrame.Angles(0, 0, angle), "Trim"))
			end
		else
			-- Caches noirs : le phare disparaît (rallye de jour).
			local cover = table.clone(light)
			cover.Name = "LightCover"
			cover.At = front
			cover.Size = light.Size + Vector3.new(0.04, 0.04, 0.04)
			cover.Paint = "Trim"
			add(list, cover)
		end
	end
end

-- OUÏES : fentes d'aération sur les ailes avant, ou grandes prises sur les ailes arrière.
local function sideVentParts(list: { Spec }, m: Mounts, option: number)
	if option == 1 then
		return
	end
	if option == 2 then
		for _, dy in ipairs({ -0.15, -0.35, -0.55 }) do
			pair(list, function(s)
				return block("SideVent", Vector3.new(0.06, 0.08, 0.7), at(s * (m.HalfWidth + 0.03), m.BeltY + dy, -WHEEL_Z + ARCH_HALF + 0.25), "Trim")
			end)
		end
	else
		pair(list, function(s)
			return block("SideVent", Vector3.new(0.1, 0.55, 1.1), at(s * (m.HalfWidth + 0.04), m.BeltY - 0.45, WHEEL_Z - ARCH_HALF - 0.75), "Trim")
		end)
	end
end

-- FILET DE VITRE : côté pilote, le filet de sécurité des voitures de course.
local function windowNetParts(list: { Spec }, c: Cabin, option: number)
	if option == 1 then
		return
	end
	local x = -(c.HalfWidth + 0.03)
	local bottom, top = c.BaseY + 0.15, c.TopY - 0.15
	local front, back = c.RoofFrontZ + 0.15, c.RoofFrontZ + 1.35
	local color = if option == 3 then NET_RED else nil
	local function strand(size: Vector3, position: Vector3)
		local spec = block("WindowNet", size, CFrame.new(position), "Trim")
		spec.Color = color
		add(list, spec)
	end
	for _, t in ipairs({ 0, 1 / 3, 2 / 3, 1 }) do
		strand(Vector3.new(0.03, top - bottom, 0.04), Vector3.new(x, (top + bottom) / 2, front + (back - front) * t))
	end
	for _, t in ipairs({ 0, 0.5, 1 }) do
		strand(Vector3.new(0.03, 0.04, back - front), Vector3.new(x, bottom + (top - bottom) * t, (front + back) / 2))
	end
end

local function mudflapParts(list: { Spec }, option: number)
	if option == 1 then
		return
	end
	local long = option == 3
	local height = if long then 1.25 else 0.95
	for _, wheelZ in ipairs({ -WHEEL_Z, WHEEL_Z }) do
		pair(list, function(s)
			return block("Mudflap", Vector3.new(if long then 1.15 else 0.95, height, 0.06), at(s * 2.58, -1.95 + height / 2, wheelZ + ARCH_HALF - 0.1), "Trim")
		end)
	end
end

--[[
	PASSE DÉTAILS, commune à tous les modèles du jeu : poignées de porte,
	essuie-glaces, trappe à carburant. Petites pièces
	sans effet sur les rayons (game ready : voir DETAIL_NAMES).
]]
local function detailParts(list: { Spec }, m: Mounts, c: Cabin)
	pair(list, function(s)
		return block("DoorHandle", Vector3.new(0.07, 0.1, 0.45), at(s * (m.HalfWidth + 0.02), m.BeltY - 0.22, 1.3), "Trim")
	end)
	local shieldLength = c.RoofFrontZ - c.WindshieldFrontZ
	local slope = math.atan2(c.TopY - c.BaseY, shieldLength)
	pair(list, function(s)
		return block("Wiper", Vector3.new(1.3, 0.05, 0.06), at(s * 0.7, c.BaseY + 0.1, c.WindshieldFrontZ + 0.2) * CFrame.Angles(-slope, 0, s * math.rad(-6)), "Trim")
	end)
	-- Trappe à carburant : sur l'aile arrière droite, tournée vers le côté.
	add(list, { Name = "FuelCap", Shape = "Cylinder", Size = Vector3.new(0.04, 0.42, 0.42), At = at(m.HalfWidth + 0.02, m.BeltY - 0.3, WHEEL_Z + 0.1), Paint = "Chrome" })
end

--[[
	LIGNES DE CARROSSERIE (style anime, avec le trait d'encre autour de la
	voiture : client/World/CarOutlines.luau) : les traits qu'un dessinateur
	poserait à l'intérieur de la silhouette, en fines baguettes couleur encre
	posées à fleur de tôle :
		- les jonctions des portières (avant, milieu, arrière), sur chaque flanc ;
		- la ligne d'épaule, d'un bout à l'autre du flanc ;
		- le contour du capot (deux côtés et le bord avant).
	Hors des rayons et sans ombre (DETAIL_NAMES), sans zone de peinture :
	elles gardent leur encre quelle que soit la livrée.
]]
local INK = Color3.fromRGB(26, 18, 40)
local LINE = 0.08 -- largeur d'un trait (studs)
local LINE_DEPTH = 0.03 -- épaisseur : dépasse à peine de la tôle
local function panelLineParts(list: { Spec }, m: Mounts, c: Cabin)
	local function line(size: Vector3, cf: CFrame): Spec
		return { Name = "PanelLine", Shape = "Block", Size = size, At = cf, Paint = "Trim", Color = INK }
	end
	local nose = m.NoseSlope
	local tail = m.TailSlope
	local frontZ = m.NoseZ + (if nose then nose.Length else 0)
	local rearZ = m.TailZ - (if tail then tail.Length else 0)
	local flankX = m.HalfWidth + LINE_DEPTH / 2

	-- Portières : bord avant, séparation sous le montant central, bord arrière.
	local doorEdge = WHEEL_Z - ARCH_HALF - 0.2
	local roofLength = c.RoofRearZ - c.RoofFrontZ
	local split = math.clamp(c.RoofFrontZ + roofLength * 0.48, -doorEdge + 0.8, doorEdge - 0.8)
	local bottom = m.BottomY + 0.38 -- au-dessus de la jupe noire
	local top = m.BeltY - 0.04
	for _, z in ipairs({ -doorEdge, split, doorEdge }) do
		pair(list, function(s)
			return line(Vector3.new(LINE_DEPTH, top - bottom, LINE), at(s * flankX, (top + bottom) / 2, z))
		end)
	end

	-- Ligne d'épaule, sous le bord de caisse : d'un bout à l'autre si elle passe
	-- au-dessus des pneus, sinon (caisse basse) le long des portières seulement.
	local shoulderY = m.BeltY - 0.1 -- au-dessus des poignées de porte
	local fromZ, toZ = frontZ, rearZ
	if shoulderY < TIRE_TOP + 0.12 then
		fromZ, toZ = -(WHEEL_Z - ARCH_HALF), WHEEL_Z - ARCH_HALF
	end
	pair(list, function(s)
		return line(Vector3.new(LINE_DEPTH, LINE, toZ - fromZ), at(s * flankX, shoulderY, (fromZ + toZ) / 2))
	end)

	-- Capot : ses deux côtés et son bord avant (après la pente du nez).
	local hoodFront = math.max(m.HoodFrontZ, frontZ + 0.05)
	local hoodLength = m.HoodRearZ - hoodFront
	if hoodLength > 0.4 then
		local y = m.BeltY + LINE_DEPTH / 2
		pair(list, function(s)
			return line(Vector3.new(LINE, LINE_DEPTH, hoodLength), at(s * m.HoodHalfWidth, y, hoodFront + hoodLength / 2))
		end)
		add(list, line(Vector3.new(m.HoodHalfWidth * 2, LINE_DEPTH, LINE), at(0, y, hoodFront)))
	end
end

--------------------------------------------------------------------------------
-- Zones de peinture
--------------------------------------------------------------------------------

export type Zone = { Key: string, Name: string, Parts: { string } }

--[[
	Les zones, dans l'ordre du garage. « Avant » et « Arrière » se partagent
	les coins (Corner) selon leur position. Les vitres et les feux ne se
	peignent pas.
]]
CarBodies.ZONES = {
	{ Key = "Hood", Name = "Capot et coffre", Parts = { "Tub", "Bulge" } },
	{ Key = "Front", Name = "Avant", Parts = { "Nose", "NoseSlope", "Corner" } },
	{ Key = "Rear", Name = "Arrière", Parts = { "Tail", "TailSlope", "Fastback", "Corner" } },
	{ Key = "Doors", Name = "Portières", Parts = { "Door" } },
	{ Key = "Fenders", Name = "Ailes", Parts = { "Fender", "Arch", "Flare" } },
	{ Key = "Roof", Name = "Toit", Parts = { "Roof", "RoofScoop", "SharkFin" } },
	{ Key = "Pillars", Name = "Montants", Parts = { "Pillar" } },
	{ Key = "Wing", Name = "Aileron", Parts = { "Wing", "WingPost", "WingPlate", "Spoiler" } },
	{ Key = "Bumpers", Name = "Boucliers", Parts = { "Grille", "Valance", "Diffuser", "DiffuserFin", "Lip", "Splitter", "SkidPlate", "Canard", "RearPanel", "Intake", "Moustache", "GrilleMesh", "GrilleFrame" } },
	{ Key = "Skirts", Name = "Bas de caisse", Parts = { "Skirt", "FlareLip", "SideSkirt", "SideBlade" } },
	{ Key = "Mirrors", Name = "Rétroviseurs", Parts = { "Mirror", "MirrorArm" } },
	{ Key = "Mudflaps", Name = "Bavettes", Parts = { "Mudflap" } },
	{ Key = "Details", Name = "Accessoires", Parts = { "Vent", "Louver", "LampBar", "SpotLampRim", "Antenna", "DoorHandle", "Wiper", "SideVent", "LightCover", "SunStrip" } },
} :: { Zone }

local zoneByPart: { [string]: string } = {}
local zoneExists: { [string]: boolean } = {}
for _, zone in ipairs(CarBodies.ZONES) do
	zoneExists[zone.Key] = true
	for _, name in ipairs(zone.Parts) do
		if zoneByPart[name] == nil then
			zoneByPart[name] = zone.Key
		end
	end
end

function CarBodies.ZoneExists(key: any): boolean
	return type(key) == "string" and zoneExists[key] == true
end

-- La zone d'une pièce décrite (nil : vitre, feu, chrome : pas de peinture).
local function zoneOf(spec: Spec): string?
	if spec.Paint ~= "Body" and spec.Paint ~= "Trim" then
		return nil
	end
	if spec.Name == "Corner" then
		return if spec.At.Position.Z < 0 then "Front" else "Rear"
	end
	return zoneByPart[spec.Name]
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- Ce qui décide du look : le modèle et ses pièces (les champs de la livrée).
-- Les accessoires (Mirrors, Roof...) sont lus par leur nom d'emplacement s'ils sont là.
export type Design = { Body: number, Wing: number, Bumper: number, Hood: number, Flares: number, Rims: number }

function CarBodies.Get(index: number): Body
	return CarBodies.LIST[index] or CarBodies.LIST[1]
end

function CarBodies.Slot(key: string): Slot?
	for _, slot in ipairs(CarBodies.SLOTS) do
		if slot.Key == key then
			return slot
		end
	end
	return nil
end

-- Le modèle propose-t-il cet emplacement ?
function CarBodies.HasSlot(body: Body, key: string): boolean
	return table.find(body.Slots, key) ~= nil
end

--[[
	Clé de la FORME (modèle et pièces de carrosserie, sans les jantes) : les
	emplacements des numéros et le tracé des bandes en dépendent
	(LiveryPainter les calcule une fois par forme).
]]
function CarBodies.ShapeKey(design: Design): string
	local body = CarBodies.Get(design.Body)
	if not body.Custom then
		return body.Id
	end
	-- Tous les emplacements sauf les jantes (qui ne changent pas la forme).
	local parts = {}
	for _, slot in ipairs(CarBodies.SLOTS) do
		if slot.Key ~= "Rims" then
			table.insert(parts, tostring(if CarBodies.HasSlot(body, slot.Key) then (design :: any)[slot.Key] or 1 else 1))
		end
	end
	return body.Id .. "/" .. table.concat(parts, "/")
end

-- Petites pièces de détail (game ready : hors des rayons, sans ombre).
local DETAIL_NAMES: { [string]: boolean } = {
	DoorHandle = true, Wiper = true, FuelCap = true, TowHook = true, TowStrap = true, Antenna = true,
	MirrorArm = true, ExhaustTip = true, DiffuserFin = true, Mudflap = true, HoodPin = true,
	GrilleBar = true, GrilleMesh = true, GrilleFrame = true, LightTape = true, LightCover = true,
	SideVent = true, WindowNet = true, Canard = true, Moustache = true, SunStrip = true,
	PanelLine = true,
}

--[[
	Habille une pièce de carrosserie (en pièces Roblox ou en maillage) : sans
	masse ni collision, sa peinture et sa zone, soudée au châssis.
]]
local function dress(part: BasePart, paint: Paint, zone: string?, own: Color3?, detail: boolean, chassis: BasePart, livery: Color3)
	part.Anchored = chassis.Anchored
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = paint ~= "Glass"
	part.Material = Enum.Material.SmoothPlastic
	if zone then
		part:SetAttribute(ZONE_ATTRIBUTE, zone)
	end
	if paint == "Body" then
		part.Color = livery
		part:SetAttribute(PAINT_ATTRIBUTE, true)
	elseif paint == "Trim" then
		part.Color = TRIM
		part:SetAttribute(BASE_COLOR_ATTRIBUTE, TRIM)
	elseif paint == "Glass" then
		part.Color = GLASS
		part.Material = Enum.Material.Glass
		part.Reflectance = 0.15
	elseif paint == "Head" then
		part.Color = HEAD
		part.Material = Enum.Material.Neon
	elseif paint == "Tail" then
		part.Color = TAIL
		part.Material = Enum.Material.Neon
	elseif paint == "Lamp" then
		part.Color = LAMP
		part.Material = Enum.Material.Neon
	elseif paint == "Chrome" then
		part.Color = CHROME
		part.Material = Enum.Material.Metal
	elseif paint == "Accent" then
		part.Color = ACCENT
		part:SetAttribute(BASE_COLOR_ATTRIBUTE, ACCENT)
	end
	if own then
		part.Color = own
		part:SetAttribute(BASE_COLOR_ATTRIBUTE, own)
	end
	-- Game ready : les petits détails ne gênent ni les rayons (numéros,
	-- bandes, sponsors) ni l'éclairage (pas d'ombre).
	if detail then
		part.CanQuery = false
		part.CastShadow = false
	end
	if PhysicsService:IsCollisionGroupRegistered(CAR_COLLISION_GROUP) then
		part.CollisionGroup = CAR_COLLISION_GROUP
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
end

local function newPart(spec: Spec, chassis: BasePart, livery: Color3): BasePart
	local part: BasePart
	if spec.Shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if spec.Shape == "Cylinder" then
			basic.Shape = Enum.PartType.Cylinder
		end
		part = basic
	end
	part.Name = spec.Name
	part.Size = spec.Size
	part.CFrame = chassis.CFrame * spec.At
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	dress(part, spec.Paint, zoneOf(spec), spec.Color, DETAIL_NAMES[spec.Name] == true, chassis, livery)
	return part
end

-- Une pièce de carrosserie faite dans Blender (CarMeshes.luau), copiée du modèle importé.
local function newMeshPart(source: BasePart, info: CarMeshes.PartInfo, chassis: BasePart, livery: Color3): BasePart
	local part = source:Clone()
	for _, child in ipairs(part:GetChildren()) do
		child:Destroy()
	end
	local place = part:GetAttribute(CarMeshes.PLACE_ATTRIBUTE)
	part.CFrame = chassis.CFrame * (if typeof(place) == "CFrame" then place else CFrame.new(info.Center))
	dress(part, info.Paint :: Paint, info.Zone, nil, info.Detail == true, chassis, livery)
	return part
end

-- Masque (ou rend) une carrosserie d'origine, en retenant sa transparence.
local function setHidden(root: Instance?, hidden: boolean)
	if not root then
		return
	end
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			local original = part:GetAttribute(HIDDEN_ATTRIBUTE)
			if original == nil then
				original = part.Transparency
				part:SetAttribute(HIDDEN_ATTRIBUTE, original)
			end
			part.Transparency = if hidden then 1 else original :: number
			part.CanQuery = not hidden -- les rayons de la livrée ne doivent plus la voir
		elseif part:IsA("Decal") or part:IsA("Texture") then
			part.Transparency = if hidden then 1 else 0
		end
	end
end

-- Couleurs d'une variante de jantes (vignettes de l'inventaire et des tirages).
function CarBodies.RimColors(option: number): { Rim: Color3, Spoke: Color3, Material: Enum.Material }
	return RIMS[option] or RIMS[1]
end

-- Couleur des jantes (roues visuelles TireFL... : pièces « Rim » et « Spoke »).
local function paintRims(car: Model, option: number)
	local colors = RIMS[option] or RIMS[1]
	for _, suffix in ipairs({ "FL", "FR", "RL", "RR" }) do
		local tire = car:FindFirstChild("Tire" .. suffix)
		if tire then
			for _, item in ipairs(tire:GetChildren()) do
				if item:IsA("BasePart") then
					if item.Name == "Rim" then
						item.Color = colors.Rim
						item.Material = colors.Material
					elseif item.Name == "Spoke" then
						item.Color = colors.Spoke
					end
				end
			end
		end
	end
end

--[[
	Pose le modèle et les pièces de `design` sur la voiture (ne fait rien si
	c'est déjà ceux-là). `livery` : couleur de carrosserie, pour les pièces
	peintes (LiveryPainter repeint ensuite tout ce qui est marqué).
]]
function CarBodies.Apply(car: Model, design: Design, livery: Color3)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return
	end
	local body = CarBodies.Get(design.Body)
	paintRims(car, if CarBodies.HasSlot(body, "Rims") then design.Rims else 1)
	local key = CarBodies.ShapeKey(design)
	if car:GetAttribute(DESIGN_ATTRIBUTE) == key then
		return
	end
	car:SetAttribute(DESIGN_ATTRIBUTE, key)
	car:SetAttribute("CustomBody", body.Custom)
	-- Version faite dans Blender (CarMeshes.luau) : ses maillages et ses repères.
	local meshData, meshTemplate = CarMeshes.Find(body.Name)
	-- Numéros de flanc (LiveryPainter) : sur la porte, à sa taille.
	local m: Mounts? = if meshData then meshData.Mounts else body.Mounts
	car:SetAttribute("FlankY", if m then (m.BeltY + m.BottomY) / 2 + 0.1 else nil)
	car:SetAttribute("FlankPanel", if m then math.min(3.2, m.BeltY - m.BottomY - 0.15) else nil)
	-- Sortie d'échappement (Exhaust.luau) : sous le pare-chocs arrière du modèle.
	car:SetAttribute("ExhaustZ", if m then m.TailZ + 0.1 else nil)
	-- Feux (CarLights.luau) : juste devant les phares et derrière les feux du modèle.
	car:SetAttribute("TailLightZ", if m then m.TailZ + 0.12 else nil)
	car:SetAttribute("TailLightY", if m then 0.1 else nil)
	car:SetAttribute("HeadLightZ", if m then m.NoseZ - 0.12 else nil)
	-- Sponsor du capot (LiveryPainter) : au milieu du capot.
	car:SetAttribute("HoodZ", if m then (m.HoodFrontZ + m.HoodRearZ) / 2 else nil)
	-- Embouts d'échappement (Exhaust.luau) : posés plus bas, selon l'accessoire choisi.
	car:SetAttribute("ExhaustX", nil)
	car:SetAttribute("ExhaustY", nil)

	local old = car:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	setHidden(car:FindFirstChild("ImportedBody"), body.Custom)
	setHidden(car:FindFirstChild("Body"), body.Custom)
	-- Le kit de la catégorie va avec la carrosserie d'origine seulement.
	BodyKits.Apply(car, car:GetAttribute("KitId") :: string? or "Rally2")
	if not body.Custom then
		return
	end

	local function option(slotKey: string): number
		return if CarBodies.HasSlot(body, slotKey) then (design :: any)[slotKey] or 1 else 1
	end
	-- Version Blender : la caisse est le maillage (ailes élargies, rétroviseurs,
	-- poignées et traits d'encre compris) ; les options qu'il a en maillage
	-- remplacent celles en pièces.
	local function meshHas(slotKey: string): boolean
		return meshData ~= nil and CarMeshes.HasOption(meshData, slotKey, option(slotKey))
	end
	local specs = if meshData then {} else table.clone(body.Parts)
	local mounts: Mounts? = m
	if mounts then
		if option("Wing") > 1 and not meshHas("Wing") then
			wingParts(specs, mounts, option("Wing"))
		end
		if not meshHas("Bumper") then
			bumperParts(specs, mounts, option("Bumper"))
		end
		if not meshHas("Hood") then
			hoodParts(specs, mounts, option("Hood"))
		end
		if not meshData then
			flareParts(specs, mounts, option("Flares"))
		end
		-- Accessoires.
		local cab: Cabin? = if meshData then meshData.Cabin else body.Cabin
		if cab then
			if not meshData then
				mirrorParts(specs, cab, option("Mirrors"))
			end
			roofParts(specs, cab, option("Roof"))
			if not meshData then
				detailParts(specs, mounts, cab)
				panelLineParts(specs, mounts, cab)
			end
		end
		skirtParts(specs, mounts, option("Skirts"))
		diffuserParts(specs, mounts, option("Diffuser"))
		-- Échappement : sur un modèle Blender, celui de série est dans le
		-- maillage (les flammes sortent de son embout) ; un autre le remplace.
		local meshExhaust: CarMeshes.PartInfo? = nil
		if meshData and option("Exhaust") == 1 then
			for _, info in ipairs(meshData.Parts) do
				if info.Name == "Exhaust" then
					meshExhaust = info
				end
			end
		end
		if meshExhaust then
			car:SetAttribute("ExhaustX", meshExhaust.Center.X)
			car:SetAttribute("ExhaustY", meshExhaust.Center.Y)
			car:SetAttribute("ExhaustZ", meshExhaust.Center.Z + meshExhaust.Size.Z / 2)
		else
			local exhaustX, exhaustY, exhaustZ = exhaustParts(specs, mounts, option("Exhaust"))
			car:SetAttribute("ExhaustX", exhaustX)
			car:SetAttribute("ExhaustY", exhaustY)
			car:SetAttribute("ExhaustZ", exhaustZ)
		end
		mudflapParts(specs, option("Mudflaps"))
		-- Habillages ajustés aux pièces déjà posées (calandre, phares), puis le reste.
		lightCoverParts(specs, option("LightCovers"))
		grilleParts(specs, option("Grille"))
		moustacheParts(specs, mounts, option("Moustache"))
		canardParts(specs, mounts, option("Canards"))
		hoodPinParts(specs, mounts, option("HoodPins"))
		towParts(specs, mounts, option("Tow"))
		sideVentParts(specs, mounts, option("SideVents"))
		if cab then
			sunStripParts(specs, cab, option("SunStrip"))
			windowNetParts(specs, cab, option("WindowNet"))
		end
	end
	-- Game ready : un budget de pièces par voiture (six voitures à l'écran).
	if #specs > PART_BUDGET and RunService:IsStudio() then
		warn(string.format("[CarBodies] %s : %d pièces (budget %d)", body.Name, #specs, PART_BUDGET))
	end
	local folder = Instance.new("Model")
	folder.Name = FOLDER
	if meshData and meshTemplate then
		for _, info in ipairs(meshData.Parts) do
			local source = meshTemplate:FindFirstChild(info.Name)
			local replaced = info.Name == "Exhaust" and option("Exhaust") > 1 -- remplacé par l'échappement choisi
			if source and source:IsA("BasePart") and CarMeshes.Wanted(info, option) and not replaced then
				newMeshPart(source, info, chassis, livery).Parent = folder
			end
		end
	end
	for _, spec in ipairs(specs) do
		newPart(spec, chassis, livery).Parent = folder
	end
	folder.Parent = car
end

return CarBodies
