--!strict
--[[
	Livery.luau
	Livrée d'une voiture : une couleur de carrosserie (dans une palette), un
	numéro de course, des bandes de course et leur couleur, le style du rond
	du numéro. Choisie au garage (et, pour la couleur et le numéro, dans le
	menu C), sauvegardée dans le profil (GarageService), appliquée à chaque
	apparition de la voiture (LiveryPainter) : tout le monde la voit.

	Une palette plutôt qu'une couleur libre : des teintes franches, qui se
	distinguent bien de loin et dans la poussière.

	COSMÉTIQUES À DÉBLOQUER : les FREE_COLORS premières couleurs, la livrée sans
	bandes et le numéro classique sont à tous. Le reste se gagne en jouant
	(Progression.luau) ; le serveur refuse une livrée qui utilise un élément
	verrouillé.
]]

local Livery = {}

export type Livery = {
	Color: number,
	Number: number,
	Stripes: number, -- Livery.STRIPES (1 = aucune)
	StripeColor: number, -- Livery.COLORS
	Plate: number, -- Livery.PLATES : style du rond du numéro
}
export type Swatch = { Name: string, Color: Color3 }
-- Une bande : décalage latéral de son axe et largeur (studs, repère du châssis).
export type Lane = { X: number, Width: number }
export type StripeStyle = { Name: string, Lanes: { Lane } }
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

local INK = Color3.fromRGB(16, 16, 20)
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
	return result
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

function Livery.Equals(a: Livery, b: Livery): boolean
	return a.Color == b.Color and a.Number == b.Number and a.Stripes == b.Stripes
		and a.StripeColor == b.StripeColor and a.Plate == b.Plate
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
	end
	return "?"
end

-- Clé courte de la livrée (repeindre seulement si elle change).
function Livery.Key(livery: Livery): string
	return string.format("%d/%d/%d/%d/%d", livery.Color, livery.Number, livery.Stripes, livery.StripeColor, livery.Plate)
end

-- Couleur du texte lisible sur une teinte donnée (numéro, puce du menu).
function Livery.ContrastOf(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then Color3.new(0.08, 0.08, 0.1) else Color3.new(1, 1, 1)
end

return Livery
