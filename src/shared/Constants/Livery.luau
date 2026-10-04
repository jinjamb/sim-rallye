--!strict
--[[
	Livery.luau
	Livrée d'une voiture : une couleur de carrosserie (dans une palette) et un
	numéro de course. Choisie dans le menu C, sauvegardée dans le profil
	(RecordService), appliquée par le serveur à chaque apparition de la voiture
	(CarService) : tout le monde la voit.

	Une palette plutôt qu'une couleur libre : des teintes franches, qui se
	distinguent bien de loin et dans la poussière.
]]

local Livery = {}

export type Livery = { Color: number, Number: number }
export type Swatch = { Name: string, Color: Color3 }

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
} :: { Swatch }

Livery.MIN_NUMBER, Livery.MAX_NUMBER = 1, 99

-- Livrée par défaut : couleur et numéro tirés de l'identifiant du joueur,
-- pour que deux nouveaux joueurs n'aient pas la même voiture.
function Livery.Default(userId: number): Livery
	local id = math.abs(userId)
	return {
		Color = (id % #Livery.COLORS) + 1,
		Number = (id % Livery.MAX_NUMBER) + 1,
	}
end

function Livery.Sanitize(input: any, userId: number): Livery
	local result = Livery.Default(userId)
	if type(input) ~= "table" then
		return result
	end
	if type(input.Color) == "number" and input.Color == input.Color then
		result.Color = math.clamp(math.floor(input.Color), 1, #Livery.COLORS)
	end
	if type(input.Number) == "number" and input.Number == input.Number then
		result.Number = math.clamp(math.floor(input.Number), Livery.MIN_NUMBER, Livery.MAX_NUMBER)
	end
	return result
end

function Livery.ColorOf(livery: Livery): Color3
	return (Livery.COLORS[livery.Color] or Livery.COLORS[1]).Color
end

function Livery.NameOf(livery: Livery): string
	return (Livery.COLORS[livery.Color] or Livery.COLORS[1]).Name
end

-- Couleur du texte lisible sur une teinte donnée (numéro, puce du menu).
function Livery.ContrastOf(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then Color3.new(0.08, 0.08, 0.1) else Color3.new(1, 1, 1)
end

return Livery
