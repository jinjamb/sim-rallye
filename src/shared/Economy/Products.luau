--!strict
--[[
	Products.luau
	Tout ce qui s'achète en Robux.

	PRODUITS DE DÉVELOPPEUR (achats répétables) :
		- packs de crédits, voie premium du Rallye Pass ;
		- PALIERS D'ACHAT (Tier) : un produit par prix (49, 99, 199, 399,
		  799 R$). TOUS les objets du catalogue (voitures, moteurs, fumées,
		  klaxons, fêtes, pièces, même celles des tirages et du Pass) et les
		  déblocages de progression (modèles, pièces, couleurs liés au niveau)
		  s'achètent par le palier de leur prix : le serveur retient ce que le
		  joueur a demandé (MonetizationService), ouvre l'achat du palier, et
		  donne la chose à la réception du paiement. Cinq produits suffisent
		  pour tout le catalogue, présent et futur ;
		- pack de démarrage (une fois), boost d'XP, tirages.
	PASS DE JEU (achat unique, permanent) : Premium (tout d'un coup), Crédits ×2, VIP.

	À FAIRE SUR ROBLOX (une fois) : créer chaque produit dans le Creator
	Dashboard (Expérience > Monétisation > Produits de développeur ; et Pass
	pour les pass de jeu), au prix suggéré (SuggestedRobux) -- pour un palier,
	EXACTEMENT ce prix -- puis recopier son identifiant ici (ProductId,
	GamePassId). Tant qu'il vaut 0, l'offre s'affiche « bientôt » et ne peut
	pas être achetée : rien ne casse.

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
	Unlock: string?, -- déblocage de progression (Progression.UnlockKey)
	PassPremium: boolean?, -- voie premium du Rallye Pass, pour la saison en cours
	Rolls: number?, -- tirages ajoutés (Rolls.luau)
	XpBoostMinutes: number?, -- XP ×2 pendant ce temps (cumulable)
	Starter: boolean?, -- pack de démarrage (marqué possédé : une fois)
}

export type Product = {
	Key: string,
	ProductId: number, -- identifiant Roblox ; 0 = pas encore créé
	Name: string,
	Description: string?,
	Grant: Grant,
	SuggestedRobux: number,
	-- Palier d'achat : ce qu'il donne est choisi au moment de l'achat
	-- (l'objet ou le déblocage demandé), pas fixé ici.
	Tier: number?,
	-- Contenu aléatoire (tirages) : interdit à la vente dans certains pays
	-- (PolicyService) ; MonetizationService le refuse et le rembourse en crédits.
	Random: boolean?,
}

export type GamePass = {
	Key: string,
	GamePassId: number, -- identifiant Roblox ; 0 = pas encore créé
	Name: string,
	Description: string,
	SuggestedRobux: number,
}

-- Valeur d'un Robux en crédits, d'après le premier pack (1 000 CR pour 49 R$) :
-- ce qu'on rend si un palier payé ne peut plus donner l'objet demandé.
Products.CREDITS_PER_ROBUX = 20

-- Le pack de démarrage : son objet exclusif.
Products.STARTER_ITEM = "smoke_founder"
-- Marque « pack de démarrage acheté » dans les objets possédés.
Products.STARTER_KEY = "starter_pack"

Products.LIST = {
	-- Packs de crédits : plus le pack est gros, plus le crédit est bon marché.
	{ Key = "credits_s", ProductId = 0, Name = "Sacoche", Grant = { Credits = 1000 }, SuggestedRobux = 49 },
	{ Key = "credits_m", ProductId = 0, Name = "Coffre", Grant = { Credits = 3000 }, SuggestedRobux = 129 },
	{ Key = "credits_l", ProductId = 0, Name = "Caisse d'équipe", Grant = { Credits = 8000 }, SuggestedRobux = 299 },
	{ Key = "credits_xl", ProductId = 0, Name = "Budget d'usine", Grant = { Credits = 20000 }, SuggestedRobux = 649 },
	-- Rallye Pass : la voie premium de la saison en cours (Pass.luau), à racheter à chaque saison.
	{ Key = "pass_premium", ProductId = 0, Name = "Rallye Pass premium", Grant = { PassPremium = true }, SuggestedRobux = 399 },

	-- Paliers d'achat : objets et déblocages (voir plus haut).
	{ Key = "tier_49", ProductId = 0, Name = "Achat · 49 R$", Grant = {}, SuggestedRobux = 49, Tier = 49 },
	{ Key = "tier_99", ProductId = 0, Name = "Achat · 99 R$", Grant = {}, SuggestedRobux = 99, Tier = 99 },
	{ Key = "tier_199", ProductId = 0, Name = "Achat · 199 R$", Grant = {}, SuggestedRobux = 199, Tier = 199 },
	{ Key = "tier_399", ProductId = 0, Name = "Achat · 399 R$", Grant = {}, SuggestedRobux = 399, Tier = 399 },
	{ Key = "tier_799", ProductId = 0, Name = "Achat · 799 R$", Grant = {}, SuggestedRobux = 799, Tier = 799 },

	-- Pack de démarrage : une fois par joueur, nettement moins cher que le détail.
	{
		Key = "starter",
		ProductId = 0,
		Name = "Pack de démarrage",
		Description = "6 000 crédits + la fumée exclusive « Fondateur ». Une seule fois.",
		Grant = { Credits = 6000, Item = "smoke_founder", Starter = true },
		SuggestedRobux = 149,
	},
	-- Boost d'XP : une heure d'XP doublée (cumulable avec les événements double XP).
	{
		Key = "xp_boost",
		ProductId = 0,
		Name = "Boost XP ×2 · 1 h",
		Description = "Toute l'XP gagnée compte double pendant une heure (cumulable).",
		Grant = { XpBoostMinutes = 60 },
		SuggestedRobux = 79,
	},
	-- Tirages : probabilités affichées en boutique (obligatoire), et masqués
	-- là où les objets aléatoires payants sont interdits.
	{ Key = "rolls_1", ProductId = 0, Name = "1 tirage", Grant = { Rolls = 1 }, SuggestedRobux = 39, Random = true },
	{ Key = "rolls_5", ProductId = 0, Name = "5 tirages", Grant = { Rolls = 5 }, SuggestedRobux = 169, Random = true },
	{ Key = "rolls_12", ProductId = 0, Name = "12 tirages", Grant = { Rolls = 12 }, SuggestedRobux = 349, Random = true },
} :: { Product }

Products.PASSES = {
	{
		-- Tout d'un coup : les deux pass ci-dessous, les sessions privées et,
		-- en cadeau, la voie premium du Rallye Pass de la saison d'achat
		-- (PassService) ; les saisons suivantes se rachètent comme pour tout
		-- le monde. Les voitures et les cosmétiques restent à gagner en jouant.
		-- Prix : les deux pass seuls valent déjà 698 R$.
		Key = "premium",
		GamePassId = 0,
		Name = "Premium Sim Rallye",
		Description = "Tout d'un coup, pour toujours : VIP (XP +25 %, badge doré), crédits ×2 et sessions privées entre amis. En cadeau : le Rallye Pass premium de la saison en cours.",
		SuggestedRobux = 699,
	},
	{
		Key = "credits_x2",
		GamePassId = 0,
		Name = "Crédits ×2",
		Description = "Tous les crédits gagnés en jouant comptent double, pour toujours.",
		SuggestedRobux = 299,
	},
	{
		Key = "vip",
		GamePassId = 0,
		Name = "VIP",
		Description = "XP +25 % pour toujours, et le badge VIP doré au-dessus de ta voiture.",
		SuggestedRobux = 399,
	},
} :: { GamePass }

local byKey: { [string]: Product } = {}
local byProductId: { [number]: Product } = {}
local passByKey: { [string]: GamePass } = {}
local passById: { [number]: GamePass } = {}

for _, product in ipairs(Products.LIST) do
	assert(byKey[product.Key] == nil, "produit en double : " .. product.Key)
	byKey[product.Key] = product
	if product.ProductId ~= 0 then
		byProductId[product.ProductId] = product
	end
end
for _, pass in ipairs(Products.PASSES) do
	passByKey[pass.Key] = pass
	if pass.GamePassId ~= 0 then
		passById[pass.GamePassId] = pass
	end
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

function Products.Pass(key: string): GamePass?
	return passByKey[key]
end

function Products.PassById(gamePassId: number): GamePass?
	return passById[gamePassId]
end

function Products.IsPassAvailable(pass: GamePass): boolean
	return pass.GamePassId ~= 0
end

-- Le palier d'un prix (le premier palier au moins aussi cher).
function Products.TierFor(robux: number): Product
	local best: Product? = nil
	for _, product in ipairs(Products.LIST) do
		local tier = product.Tier
		if tier and tier >= robux and (best == nil or tier < (best.Tier :: number)) then
			best = product
		end
	end
	return best or byKey.tier_799
end

-- Prix d'un objet du catalogue, selon sa rareté.
local RARITY_ROBUX: { [string]: number } = {
	Serie = 49,
	Club = 49,
	Pro = 99,
	Usine = 199,
	Prototype = 399,
	Legende = 799,
}

--[[
	Palier d'achat d'un objet du catalogue (nil : gratuit, ou réservé au pack
	de démarrage).
]]
function Products.ForItem(itemId: string): Product?
	local item = Catalog.Get(itemId)
	if not item or item.Free or item.Starter then
		return nil
	end
	-- Prix imposé par l'objet (les voitures : voir Items/Cars.luau), sinon
	-- d'après sa rareté.
	local robux = item.Robux or RARITY_ROBUX[item.Rarity] or 99
	return Products.TierFor(robux)
end

--[[
	Palier d'achat d'un déblocage de progression, selon ce qu'il demande :
	un petit niveau coûte peu, un exploit (médaille, victoires) davantage.
	`requirement` : Progression.Requirement.
]]
function Products.ForUnlock(requirement: any): Product?
	if type(requirement) ~= "table" or requirement.Item then
		return nil -- une pièce de tirage s'achète comme objet (ForItem)
	end
	local level = requirement.Level
	if level and not requirement.Medal and not requirement.AnyMedal and not requirement.Wins and not requirement.Style then
		return Products.TierFor(if level <= 4 then 49 elseif level <= 10 then 99 else 199)
	end
	return Products.TierFor(199)
end

-- Les packs de crédits, dans l'ordre de la boutique.
function Products.CreditPacks(): { Product }
	local list = {}
	for _, product in ipairs(Products.LIST) do
		local grant = product.Grant
		if grant.Credits and not grant.Item and not grant.Starter then
			table.insert(list, product)
		end
	end
	return list
end

-- Les offres de tirages, dans l'ordre affiché en boutique.
function Products.RollPacks(): { Product }
	local list = {}
	for _, product in ipairs(Products.LIST) do
		if product.Random then
			table.insert(list, product)
		end
	end
	return list
end

return Products
