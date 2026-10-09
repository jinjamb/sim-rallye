--!strict
--[[
	Rarity.luau
	Raretés des objets, du plus courant au plus rare. Les noms suivent
	l'échelle d'une voiture de course, de la série au mythe :
		Série      objets de base, donnés d'office ;
		Club       rare -- ce qu'on voit au rallye du coin ;
		Pro        très rare -- le niveau championnat ;
		Usine      incroyable -- les équipes officielles des constructeurs ;
		Prototype  hors normes -- ce qui n'est pas encore homologué ;
		Légende    le mythe -- les objets dont on parle au paddock.
	Le poids sert aux tirages (Rolls.luau) : plus il est petit, plus l'objet
	est rare. Série ne sort jamais d'un tirage (déjà possédé).
]]

local Rarity = {}

export type Id = "Serie" | "Club" | "Pro" | "Usine" | "Prototype" | "Legende"

export type Info = {
	Id: Id,
	Name: string,
	Rank: number, -- 1 (Série) à 6 (Légende)
	Color: Color3,
	Weight: number, -- chances relatives dans un tirage
}

Rarity.ORDER = { "Serie", "Club", "Pro", "Usine", "Prototype", "Legende" } :: { Id }

Rarity.INFO = {
	Serie = { Id = "Serie", Name = "Série", Rank = 1, Color = Color3.fromRGB(170, 174, 182), Weight = 0 },
	Club = { Id = "Club", Name = "Club", Rank = 2, Color = Color3.fromRGB(80, 170, 255), Weight = 600 },
	Pro = { Id = "Pro", Name = "Pro", Rank = 3, Color = Color3.fromRGB(170, 110, 255), Weight = 260 },
	Usine = { Id = "Usine", Name = "Usine", Rank = 4, Color = Color3.fromRGB(255, 140, 40), Weight = 100 },
	Prototype = { Id = "Prototype", Name = "Prototype", Rank = 5, Color = Color3.fromRGB(255, 70, 90), Weight = 32 },
	Legende = { Id = "Legende", Name = "Légende", Rank = 6, Color = Color3.fromRGB(255, 204, 0), Weight = 8 },
} :: { [Id]: Info }

function Rarity.Get(id: Id): Info
	return Rarity.INFO[id]
end

return Rarity
