--!strict
--[[
	Products.luau
	Tout ce qui s'achète en Robux : des « produits de développeur »
	(Developer Products). Les packs de crédits sont déclarés ici ; les objets
	achetables en Robux le sont dans leur module (Items/, champ Robux), et
	réunis ici.

	À FAIRE SUR ROBLOX (une fois) : créer chaque produit dans le Creator
	Dashboard (Expérience > Monétisation > Produits de développeur), avec le
	prix suggéré ci-dessous (ou un autre), puis recopier son identifiant dans
	ProductId. Tant qu'il vaut 0, le produit s'affiche « bientôt » et ne peut
	pas être acheté : rien ne casse.

	Le prix affiché en jeu est lu chez Roblox (GetProductInfo) : c'est
	toujours celui du Creator Dashboard, pas SuggestedRobux.

	L'achat est accordé par le serveur seul (EconomyService, ProcessReceipt) :
	sauvegardé avant d'être confirmé à Roblox, et jamais deux fois.
]]

local Catalog = require(script.Parent.Catalog)

local Products = {}

export type Grant = {
	Credits: number?, -- crédits ajoutés
	Item: string?, -- objet du catalogue débloqué (Catalog.luau)
	PassPremium: boolean?, -- voie premium du Rallye Pass, pour la saison en cours
}

export type Product = {
	Key: string,
	ProductId: number, -- identifiant Roblox ; 0 = pas encore créé
	Name: string,
	Grant: Grant,
	SuggestedRobux: number,
}

Products.LIST = {
	-- Packs de crédits : plus le pack est gros, plus le crédit est bon marché.
	{ Key = "credits_s", ProductId = 0, Name = "Sacoche", Grant = { Credits = 1000 }, SuggestedRobux = 49 },
	{ Key = "credits_m", ProductId = 0, Name = "Coffre", Grant = { Credits = 3000 }, SuggestedRobux = 129 },
	{ Key = "credits_l", ProductId = 0, Name = "Caisse d'équipe", Grant = { Credits = 8000 }, SuggestedRobux = 299 },
	{ Key = "credits_xl", ProductId = 0, Name = "Budget d'usine", Grant = { Credits = 20000 }, SuggestedRobux = 649 },
	-- Rallye Pass : la voie premium de la saison en cours (Pass.luau), à racheter à chaque saison.
	{ Key = "pass_premium", ProductId = 0, Name = "Rallye Pass premium", Grant = { PassPremium = true }, SuggestedRobux = 399 },
} :: { Product }

local byKey: { [string]: Product } = {}
local byProductId: { [number]: Product } = {}

local function index(product: Product)
	byKey[product.Key] = product
	if product.ProductId ~= 0 then
		byProductId[product.ProductId] = product
	end
end

-- Les objets du catalogue achetables en Robux : un produit chacun.
for _, item in ipairs(Catalog.ITEMS) do
	local robux = item.Robux
	if robux then
		table.insert(Products.LIST, {
			Key = "item_" .. item.Id,
			ProductId = robux.ProductId,
			Name = item.Name,
			Grant = { Item = item.Id },
			SuggestedRobux = robux.Suggested,
		})
	end
end

for _, product in ipairs(Products.LIST) do
	assert(byKey[product.Key] == nil, "produit en double : " .. product.Key)
	index(product)
end

-- Produit Robux d'un objet du catalogue (nil s'il ne s'achète pas en Robux).
function Products.ForItem(itemId: string): Product?
	return byKey["item_" .. itemId]
end

function Products.Get(key: string?): Product?
	return if key then byKey[key] else nil
end

function Products.ByProductId(productId: number): Product?
	return byProductId[productId]
end

-- Créé sur Roblox (identifiant renseigné) : achetable.
function Products.IsAvailable(product: Product): boolean
	return product.ProductId ~= 0
end

-- Les packs de crédits, dans l'ordre de la boutique.
function Products.CreditPacks(): { Product }
	local list = {}
	for _, product in ipairs(Products.LIST) do
		if product.Grant.Credits and not product.Grant.Item then
			table.insert(list, product)
		end
	end
	return list
end

return Products
