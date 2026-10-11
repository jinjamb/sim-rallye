--!strict
--[[
	ItemTypes.luau
	La forme d'un objet du catalogue (Catalog.luau), à part pour que les
	modules d'objets (Items/) puissent la citer sans dépendre du catalogue.
]]

local Rarity = require(script.Parent.Rarity)

export type Kind = "Car" | "Smoke" | "Horn" | "Celebration" | "Engine"

export type Item = {
	Id: string,
	Kind: Kind,
	Name: string,
	Description: string,
	Rarity: Rarity.Id,
	-- Sources (une ou plusieurs) : voir Catalog.luau.
	Free: boolean?,
	Credits: number?,
	Robux: { ProductId: number, Suggested: number }?,
	Pass: boolean?,
	Roll: boolean?,
	-- Données propres à la sorte.
	Color: Color3?, -- fumée : couleur principale
	Color2: Color3?, -- fumée : seconde couleur (fumée bicolore)
	Sound: string?, -- klaxon : identifiant audio
	Pitch: number?, -- klaxon : hauteur
	Effect: string?, -- célébration : effet joué au podium
	Engine: string?, -- son moteur : profil (SoundBank.luau)
	CarClass: string?, -- voiture : catégorie (CarClasses.luau)
}

return {}
