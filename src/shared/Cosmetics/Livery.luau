--!strict
--[[
	Livery.luau
	Livrée d'une voiture : une couleur de carrosserie (dans une palette), un
	numéro de course, des bandes de course et leur couleur, le style du rond
	du numéro. Choisie au garage (et, pour la couleur et le numéro, dans le
	menu C), sauvegardée dans le profil (GarageService), appliquée à chaque
	apparition de la voiture (LiveryPainter) : tout le monde la voit.

	ELLE PORTE AUSSI LE MODÈLE ET SES PIÈCES (CarBodies.luau) : Body (le
	modèle), Wing, Bumper, Hood, Flares, Rims (une variante par
	emplacement, 1 = de série). Body = 0 (par défaut) : la carrosserie et
	les pièces de sa VOITURE (CarModels.luau : Design), qui change avec elle ;
	les jantes restent celles du joueur. Même chemin que la couleur : sauvegardé,
	vérifié, débloqué en jouant (Progression.luau), posé par LiveryPainter.

	PEINTURE PAR PIÈCE (Paints) : une couleur de la palette par zone de la
	carrosserie (CarBodies.ZONES : capot, toit, portières, boucliers...) ;
	une zone absente garde sa peinture d'origine.

	MOTIF (Pattern, PatternColor) : une image répétée sur toute la
	carrosserie peinte dans la couleur principale (une zone peinte à part
	reste unie), teintée dans la couleur du motif. Chaque motif est une
	image blanche sur fond transparent (assets/patterns/), importée sur
	Roblox : son identifiant va dans PATTERNS (Image). Tant qu'il vaut 0, le
	motif se choisit mais ne s'affiche pas.

	SPONSORS (SponsorHood, SponsorDoors, SponsorRoof) : un autocollant de
	marque (fictive) par emplacement : le capot, les deux portières, le
	toit (Livery.SPONSORS ; 1 = aucun). Dessinés en texte par
	LiveryPainter : aucune image à importer. « Écurie » affiche le sigle de
	son écurie (Teams.luau), à sa couleur.

	Une palette plutôt qu'une couleur libre : des teintes franches, qui se
	distinguent bien de loin et dans la poussière.

	COSMÉTIQUES À DÉBLOQUER : les FREE_COLORS premières couleurs, la livrée sans
	bandes et le numéro classique sont à tous. Le reste se gagne en jouant
	(Progression.luau) ; le serveur refuse une livrée qui utilise un élément
	verrouillé.
]]

local CarBodies = require(script.Parent.Parent.Vehicle.CarBodies)

local Livery = {}

export type Livery = {
	Color: number,
	Number: number,
	Stripes: number, -- Livery.STRIPES (1 = aucune)
	StripeColor: number, -- Livery.COLORS
	Plate: number, -- Livery.PLATES : style du rond du numéro
	-- Modèle et pièces (CarBodies.luau) : indices, 1 = de série.
	Body: number,
	Wing: number,
	Bumper: number,
	Hood: number,
	Flares: number,
	Rims: number,
	-- Peinture par zone (CarBodies.ZONES) : indice dans COLORS ; zone absente = d'origine.
	Paints: { [string]: number },
	Pattern: number, -- Livery.PATTERNS (1 = aucun)
	PatternColor: number, -- Livery.COLORS
	-- Sponsors (Livery.SPONSORS, 1 = aucun), par emplacement.
	SponsorHood: number,
	SponsorDoors: number,
	SponsorRoof: number,
}
-- Un sponsor : son texte (nil : le sigle de l'écurie), ses couleurs (fond
-- nil : le texte seul, cerné), sa police.
export type SponsorStyle = { Name: string, Text: string?, Ink: Color3, Background: Color3?, Font: Enum.Font }
export type Swatch = { Name: string, Color: Color3 }
-- Une bande : décalage latéral de son axe et largeur (studs, repère du châssis).
export type Lane = { X: number, Width: number }
export type StripeStyle = { Name: string, Lanes: { Lane } }
-- Un motif : l'image (identifiant Roblox, 0 = pas encore importée) et la
-- taille d'une répétition (studs).
export type PatternStyle = { Name: string, Image: number, Tile: number, Transparency: number }
export type PlateStyle = { Name: string, Disc: Color3, Text: Color3, GoldRing: boolean }

Livery.COLORS = {
	{ Name = "Rouge", Color = Color3.fromRGB(200, 30, 35) },
	{ Name = "Bleu", Color = Color3.fromRGB(25, 75, 190) },
	{ Name = "Blanc", Color = Color3.fromRGB(235, 235, 238) },
	{ Name = "Noir", Color = Color3.fromRGB(28, 28, 32) },
	{ Name = "Jaune", Color = Color3.fromRGB(245, 200, 30) },
	{ Name = "Vert", Color = Color3.fromRGB(30, 140, 60) },
	{ Name = "Orange", Color = Color3.fromRGB(245, 120, 20) },
	{ Name = "Violet", Color = Color3.fromRGB(110, 50, 170) },
	{ Name = "Cyan", Color = Color3.fromRGB(30, 170, 200) },
	{ Name = "Rose", Color = Color3.fromRGB(230, 80, 150) },
	{ Name = "Gris", Color = Color3.fromRGB(120, 124, 132) },
	{ Name = "Bordeaux", Color = Color3.fromRGB(110, 20, 35) },
	-- À débloquer (Progression.luau)
	{ Name = "Bleu nuit", Color = Color3.fromRGB(18, 32, 85) },
	{ Name = "Vert pomme", Color = Color3.fromRGB(125, 200, 40) },
	{ Name = "Sable", Color = Color3.fromRGB(212, 184, 125) },
	{ Name = "Turquoise", Color = Color3.fromRGB(0, 168, 150) },
	{ Name = "Rouge corsa", Color = Color3.fromRGB(225, 12, 18) },
	{ Name = "Chrome", Color = Color3.fromRGB(196, 202, 212) },
	{ Name = "Or", Color = Color3.fromRGB(214, 172, 50) },
	{ Name = "Glacier", Color = Color3.fromRGB(165, 228, 245) },
} :: { Swatch }

-- Les couleurs 1 à FREE_COLORS sont à tous (celles d'avant les déblocages).
Livery.FREE_COLORS = 12

Livery.STRIPES = {
	{ Name = "Aucune", Lanes = {} },
	{ Name = "Double bande", Lanes = { { X = -0.6, Width = 0.7 }, { X = 0.6, Width = 0.7 } } },
	{ Name = "Bande large", Lanes = { { X = 0, Width = 1.8 } } },
	{ Name = "Filets latéraux", Lanes = { { X = -1.6, Width = 0.35 }, { X = 1.6, Width = 0.35 } } },
} :: { StripeStyle }

Livery.PATTERNS = {
	{ Name = "Aucun", Image = 0, Tile = 1, Transparency = 0 },
	{ Name = "Damier", Image = 0, Tile = 2, Transparency = 0 }, -- assets/patterns/damier.png
	{ Name = "Pois", Image = 0, Tile = 2.5, Transparency = 0 }, -- assets/patterns/pois.png
	{ Name = "Hexagones", Image = 0, Tile = 3, Transparency = 0 }, -- assets/patterns/hexagones.png
	{ Name = "Carbone", Image = 0, Tile = 1.2, Transparency = 0.15 }, -- assets/patterns/carbone.png
	{ Name = "Camouflage", Image = 0, Tile = 7, Transparency = 0 }, -- assets/patterns/camouflage.png
	{ Name = "Zébrures", Image = 0, Tile = 6, Transparency = 0 }, -- assets/patterns/zebrures.png
	{ Name = "Flammes", Image = 0, Tile = 6, Transparency = 0 }, -- assets/patterns/flammes.png
	{ Name = "Sakura", Image = 0, Tile = 5, Transparency = 0 }, -- assets/patterns/sakura.png
} :: { PatternStyle }

local INK = Color3.fromRGB(16, 16, 20)
local WHITE = Color3.new(1, 1, 1)

-- Les emplacements des sponsors : le champ de la livrée et son nom.
Livery.SPONSOR_SLOTS = {
	{ Field = "SponsorHood", Name = "Capot" },
	{ Field = "SponsorDoors", Name = "Portières" },
	{ Field = "SponsorRoof", Name = "Toit" },
}

-- Marques imaginaires (aucune vraie marque) ; ajouter à la FIN seulement.
Livery.SPONSORS = {
	{ Name = "Aucun", Text = "", Ink = WHITE, Background = nil, Font = Enum.Font.GothamBlack },
	{ Name = "Sim Rallye", Text = "SIM RALLYE", Ink = WHITE, Background = Color3.fromRGB(255, 46, 126), Font = Enum.Font.GothamBlack },
	{ Name = "Kaze Oil", Text = "KAZE OIL", Ink = WHITE, Background = Color3.fromRGB(200, 25, 35), Font = Enum.Font.GothamBlack },
	{ Name = "Sakura Tyres", Text = "SAKURA TYRES", Ink = Color3.fromRGB(230, 60, 140), Background = WHITE, Font = Enum.Font.GothamBold },
	{ Name = "Hayate Racing", Text = "HAYATE RACING", Ink = Color3.fromRGB(255, 210, 30), Background = INK, Font = Enum.Font.GothamBlack },
	{ Name = "Yama Motors", Text = "YAMA MOTORS", Ink = WHITE, Background = Color3.fromRGB(25, 75, 190), Font = Enum.Font.GothamBold },
	{ Name = "Raijin Energy", Text = "RAIJIN ENERGY", Ink = INK, Background = Color3.fromRGB(255, 220, 30), Font = Enum.Font.GothamBlack },
	{ Name = "Hoshi Lubes", Text = "HOSHI LUBES", Ink = WHITE, Background = nil, Font = Enum.Font.GothamBlack },
	{ Name = "Gomu Turbo", Text = "GOMU TURBO", Ink = WHITE, Background = Color3.fromRGB(245, 120, 20), Font = Enum.Font.GothamBlack },
	{ Name = "Kitsune", Text = "KITSUNE", Ink = Color3.fromRGB(210, 30, 40), Background = WHITE, Font = Enum.Font.Bangers },
	{ Name = "Neon Rally", Text = "NEON RALLY", Ink = Color3.fromRGB(0, 230, 255), Background = INK, Font = Enum.Font.GothamBlack },
	{ Name = "Dragon Brakes", Text = "DRAGON BRAKES", Ink = INK, Background = Color3.fromRGB(230, 30, 25), Font = Enum.Font.Bangers },
	{ Name = "Écurie", Text = nil, Ink = WHITE, Background = INK, Font = Enum.Font.GothamBlack },
} :: { SponsorStyle }
Livery.PLATES = {
	{ Name = "Classique", Disc = Color3.new(1, 1, 1), Text = INK, GoldRing = false },
	{ Name = "Noir", Disc = INK, Text = Color3.new(1, 1, 1), GoldRing = false },
	{ Name = "Or", Disc = Color3.fromRGB(240, 205, 80), Text = INK, GoldRing = true },
} :: { PlateStyle }

Livery.MIN_NUMBER, Livery.MAX_NUMBER = 1, 99

-- Livrée par défaut : couleur et numéro tirés de l'identifiant du joueur,
-- pour que deux nouveaux joueurs n'aient pas la même voiture.
function Livery.Default(userId: number): Livery
	local id = math.abs(userId)
	return {
		Color = (id % Livery.FREE_COLORS) + 1,
		Number = (id % Livery.MAX_NUMBER) + 1,
		Stripes = 1,
		StripeColor = 3, -- blanc
		Plate = 1,
		Body = 0, -- la carrosserie de sa voiture (CarModels.luau)
		Wing = 1,
		Bumper = 1,
		Hood = 1,
		Flares = 1,
		Rims = 1,
		Paints = {},
		Pattern = 1,
		PatternColor = 4, -- noir
		SponsorHood = 1,
		SponsorDoors = 1,
		SponsorRoof = 1,
	}
end

local function index(value: any, count: number): number?
	if type(value) == "number" and value == value then
		return math.clamp(math.floor(value), 1, count)
	end
	return nil
end

function Livery.Sanitize(input: any, userId: number): Livery
	local result = Livery.Default(userId)
	if type(input) ~= "table" then
		return result
	end
	result.Color = index(input.Color, #Livery.COLORS) or result.Color
	if type(input.Number) == "number" and input.Number == input.Number then
		result.Number = math.clamp(math.floor(input.Number), Livery.MIN_NUMBER, Livery.MAX_NUMBER)
	end
	result.Stripes = index(input.Stripes, #Livery.STRIPES) or result.Stripes
	result.StripeColor = index(input.StripeColor, #Livery.COLORS) or result.StripeColor
	result.Plate = index(input.Plate, #Livery.PLATES) or result.Plate
	result.Body = if input.Body == 0 then 0 else index(input.Body, #CarBodies.LIST) or result.Body
	for _, slot in ipairs(CarBodies.SLOTS) do
		(result :: any)[slot.Key] = index(input[slot.Key], #slot.Options) or 1
	end
	if type(input.Paints) == "table" then
		for zone, color in pairs(input.Paints) do
			local valid = index(color, #Livery.COLORS)
			if CarBodies.ZoneExists(zone) and valid then
				result.Paints[zone] = valid
			end
		end
	end
	result.Pattern = index(input.Pattern, #Livery.PATTERNS) or 1
	for _, slot in ipairs(Livery.SPONSOR_SLOTS) do
		(result :: any)[slot.Field] = index(input[slot.Field], #Livery.SPONSORS) or 1
	end
	result.PatternColor = index(input.PatternColor, #Livery.COLORS) or result.PatternColor
	return result
end

-- La carrosserie à poser : celle de la voiture (`design`, CarModels.luau)
-- quand la livrée la garde (Body = 0), sinon celle choisie par le joueur.
function Livery.WithDesign(livery: Livery, design: { Body: number, Wing: number, Bumper: number, Hood: number, Flares: number }?): Livery
	if livery.Body ~= 0 then
		return livery
	end
	local resolved = table.clone(livery)
	local chosen = design or { Body = 2, Wing = 1, Bumper = 1, Hood = 1, Flares = 1 }
	resolved.Body = chosen.Body
	resolved.Wing = chosen.Wing
	resolved.Bumper = chosen.Bumper
	resolved.Hood = chosen.Hood
	resolved.Flares = chosen.Flares
	return resolved
end

function Livery.ColorOf(livery: Livery): Color3
	return (Livery.COLORS[livery.Color] or Livery.COLORS[1]).Color
end

function Livery.NameOf(livery: Livery): string
	return (Livery.COLORS[livery.Color] or Livery.COLORS[1]).Name
end

function Livery.StripeColorOf(livery: Livery): Color3
	return (Livery.COLORS[livery.StripeColor] or Livery.COLORS[3]).Color
end

function Livery.PatternColorOf(livery: Livery): Color3
	return (Livery.COLORS[livery.PatternColor] or Livery.COLORS[4]).Color
end

-- La couleur choisie pour une zone (nil : peinture d'origine).
function Livery.ZoneColorOf(livery: Livery, zone: string): Color3?
	local paints = livery.Paints
	local chosen = if paints then paints[zone] else nil
	local swatch = if chosen then Livery.COLORS[chosen] else nil
	return if swatch then swatch.Color else nil
end

function Livery.Equals(a: Livery, b: Livery): boolean
	return Livery.Key(a) == Livery.Key(b)
end

-- Nom lisible d'un élément de livrée (Progression.Kind) : "Couleur Or".
function Livery.ItemName(kind: string, index: number): string
	if kind == "Color" then
		local swatch = Livery.COLORS[index]
		return "Couleur " .. (if swatch then swatch.Name else "?")
	elseif kind == "Stripes" then
		local style = Livery.STRIPES[index]
		return "Bandes : " .. (if style then style.Name else "?")
	elseif kind == "Plate" then
		local plate = Livery.PLATES[index]
		return "Numéro " .. (if plate then plate.Name else "?")
	elseif kind == "Pattern" then
		local pattern = Livery.PATTERNS[index]
		return "Motif " .. (if pattern then pattern.Name else "?")
	elseif kind == "Sponsor" then
		local sponsor = Livery.SPONSORS[index]
		return "Sponsor " .. (if sponsor then sponsor.Name else "?")
	elseif kind == "Body" and index == 0 then
		return "Modèle : celui de la voiture"
	elseif kind == "Body" then
		local body = CarBodies.LIST[index]
		return "Modèle " .. (if body then body.Name else "?")
	end
	local slot = CarBodies.Slot(kind)
	if slot then
		local option = slot.Options[index]
		return slot.Name .. " : " .. (if option then option.Name else "?")
	end
	return "?"
end

-- Clé courte de la livrée (repeindre seulement si elle change).
function Livery.Key(livery: Livery): string
	local paints = {}
	for _, zone in ipairs(CarBodies.ZONES) do
		local chosen = if livery.Paints then livery.Paints[zone.Key] else nil
		table.insert(paints, tostring(chosen or 0))
	end
	return string.format(
		"%d/%d/%d/%d/%d|%d/%d/%d/%d/%d/%d|%d/%d|%s|%d/%d/%d",
		livery.Color,
		livery.Number,
		livery.Stripes,
		livery.StripeColor,
		livery.Plate,
		livery.Body or 1,
		livery.Wing or 1,
		livery.Bumper or 1,
		livery.Hood or 1,
		livery.Flares or 1,
		livery.Rims or 1,
		livery.Pattern or 1,
		livery.PatternColor or 4,
		table.concat(paints, ","),
		livery.SponsorHood or 1,
		livery.SponsorDoors or 1,
		livery.SponsorRoof or 1
	)
end

-- Couleur du texte lisible sur une teinte donnée (numéro, puce du menu).
function Livery.ContrastOf(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then Color3.new(0.08, 0.08, 0.1) else Color3.new(1, 1, 1)
end

return Livery
