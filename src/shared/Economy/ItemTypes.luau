--!strict
--[[
	ItemTypes.luau
	La forme d'un objet du catalogue (Catalog.luau), à part pour que les
	modules d'objets (Items/) puissent la citer sans dépendre du catalogue.
]]

local Rarity = require(script.Parent.Rarity)

export type Kind = "Car" | "Smoke" | "Horn" | "Celebration" | "Engine" | "Backfire" | "Part"

export type Item = {
	Id: string,
	Kind: Kind,
	Name: string,
	Description: string,
	Rarity: Rarity.Id,
	-- Sources (une ou plusieurs) : voir Catalog.luau.
	Free: boolean?,
	Credits: number?,
	Robux: number?, -- prix en Robux imposé (Products.ForItem) ; sinon, d'après la rareté
	Pass: boolean?,
	Starter: boolean?, -- exclusif au pack de démarrage (Products.luau)
	Roll: boolean?,
	-- Données propres à la sorte.
	Color: Color3?, -- fumée, retour de flamme : couleur principale
	Color2: Color3?, -- fumée : seconde couleur (fumée bicolore) ; flamme : son cœur
	Scale: number?, -- retour de flamme : taille de la gerbe (1 = normale)
	Sound: string?, -- klaxon, retour de flamme : identifiant audio
	Pitch: number?, -- klaxon : hauteur
	Effect: string?, -- célébration : effet joué au podium
	Engine: string?, -- son moteur : profil (SoundBank.luau)
	CarClass: string?, -- voiture : catégorie (CarClasses.luau)
	Slot: string?, -- pièce : emplacement (CarBodies.SLOTS)
	Option: number?, -- pièce : variante débloquée
}

return {}
