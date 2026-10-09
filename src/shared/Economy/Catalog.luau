--!strict
--[[
	Catalog.luau
	Tous les objets qu'on possède ou pas : voitures, fumées de pneus,
	klaxons, célébrations de podium, sons moteur. (Les couleurs et décors de
	la livrée, eux, se débloquent avec la progression : Progression.luau.)

	D'OÙ VIENT UN OBJET (un ou plusieurs à la fois) :
		Free     possédé d'office ;
		Credits  acheté en crédits (Credits.luau) ;
		Robux    acheté en Robux : un produit de développeur à créer sur
		         Roblox, dont l'identifiant va dans Robux.ProductId (0 tant
		         qu'il n'existe pas : « bientôt ») ;
		Pass     récompense d'un palier du Rallye Pass (Pass.luau) ;
		Roll     peut sortir d'un tirage (Rolls.luau), selon sa rareté.

	ÉQUIPÉ : un objet de chaque sorte (profil, Equipped) ; sans choix, le
	premier objet gratuit de la sorte. Les objets « visibles par tous »
	(fumée, klaxon, célébration, son moteur) sont portés par la voiture et
	vus ou entendus par les autres joueurs.

	Les objets de chaque sorte sont déclarés dans leur module (Items/), avec
	les données propres à leur sorte (ItemTypes.luau).
]]

local ItemTypes = require(script.Parent.ItemTypes)

local Catalog = {}

export type Kind = ItemTypes.Kind
export type Item = ItemTypes.Item

local KINDS: { Kind } = { "Car", "Engine", "Smoke", "Horn", "Celebration" }
Catalog.KINDS = KINDS

Catalog.KIND_NAMES = {
	Car = "Voiture",
	Smoke = "Fumée de pneus",
	Horn = "Klaxon",
	Celebration = "Célébration",
	Engine = "Son moteur",
} :: { [Kind]: string }

-- Les objets de chaque sorte, chacun dans son module (Items/).
local LISTS: { { Item } } = {
	require(script.Parent.Items.Cars),
	require(script.Parent.Items.Smokes),
	require(script.Parent.Items.Horns),
	require(script.Parent.Items.Celebrations),
}

Catalog.ITEMS = {} :: { Item }

local byId: { [string]: Item } = {}
for _, list in ipairs(LISTS) do
	for _, item in ipairs(list) do
		assert(byId[item.Id] == nil, "objet en double : " .. item.Id)
		byId[item.Id] = item
		table.insert(Catalog.ITEMS, item)
	end
end

function Catalog.Get(id: string?): Item?
	return if id then byId[id] else nil
end

function Catalog.OfKind(kind: Kind): { Item }
	local list = {}
	for _, item in ipairs(Catalog.ITEMS) do
		if item.Kind == kind then
			table.insert(list, item)
		end
	end
	return list
end

-- L'objet porté par défaut : le premier gratuit de sa sorte.
function Catalog.Default(kind: Kind): Item?
	for _, item in ipairs(Catalog.ITEMS) do
		if item.Kind == kind and item.Free then
			return item
		end
	end
	return nil
end

-- Utilisable : un klaxon a besoin d'un son (Items/Horns.luau). Un objet
-- indisponible n'est ni vendu ni tiré au sort.
function Catalog.IsAvailable(item: Item): boolean
	if item.Kind == "Horn" then
		return item.Sound ~= nil and item.Sound ~= ""
	end
	return true
end

-- La voiture du catalogue d'une catégorie (CarClasses.luau).
function Catalog.CarItem(classId: string): Item?
	for _, item in ipairs(Catalog.ITEMS) do
		if item.Kind == "Car" and item.CarClass == classId then
			return item
		end
	end
	return nil
end

-- Possédé : gratuit, ou dans la liste du profil.
function Catalog.Owns(owned: { [string]: boolean }?, id: string): boolean
	local item = byId[id]
	if not item then
		return false
	end
	return item.Free == true or (owned ~= nil and owned[id] == true)
end

-- D'où il peut venir, en clair : "1 500 CR", "Rallye Pass", "Tirage"...
function Catalog.SourceText(item: Item): string
	local parts = {}
	if item.Free then
		table.insert(parts, "de série")
	end
	if item.Credits then
		table.insert(parts, tostring(item.Credits) .. " CR")
	end
	if item.Robux then
		table.insert(parts, "Robux")
	end
	if item.Pass then
		table.insert(parts, "Rallye Pass")
	end
	if item.Roll then
		table.insert(parts, "tirage")
	end
	return table.concat(parts, " · ")
end

return Catalog
