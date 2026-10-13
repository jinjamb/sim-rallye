--!strict
--[[
	MonetizationService.luau
	Ce qui se paie en Robux, au-delà des packs de crédits (Products.luau) :

	PALIERS D'ACHAT : le joueur demande un objet ou un déblocage
	(RequestRobuxPurchase) ; le serveur vérifie qu'il est achetable et pas
	déjà à lui, RETIENT la demande, puis ouvre l'achat du palier de son prix.
	À la réception du paiement (EconomyService.ResolveGrant), la demande en
	cours donne l'objet. Sans demande valable (serveur redémarré entre
	l'achat et sa réception, objet obtenu entre-temps, achat lancé à la main),
	le joueur est remboursé en crédits, à la valeur du palier : un paiement
	n'est jamais perdu.

	OFFRES : pack de démarrage (une fois), boost d'XP, tirages. Les tirages
	sont refusés là où les objets aléatoires payants sont interdits
	(PolicyService) ; achetés quand même (achat lancé à la main), ils sont
	remboursés en crédits.

	PASS DE JEU : Crédits ×2, VIP (XP +25 %, badge doré au-dessus de la
	voiture : attribut Vip du joueur, lu par RemoteCars). Vérifiés à
	l'arrivée et à l'achat ; l'effet passe par Perks.luau.

	ROBLOX PREMIUM : +10 % de crédits gagnés (Perks.luau). Premium rapporte
	aussi au jeu selon le temps passé par ses abonnés : la boutique propose
	de s'abonner.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Perks = require(script.Parent.Perks)
local GiftService = require(script.Parent.GiftService)
local EconomyService = require(script.Parent.EconomyService)
local ProgressService = require(script.Parent.ProgressService)
local PassService = require(script.Parent.PassService)
local SessionService = require(script.Parent.SessionService)

local MonetizationService = {}

local REQUEST_COOLDOWN = 1 -- seconde entre deux demandes d'achat
local INTENT_LIFETIME = 900 -- une demande reste valable 15 min (fenêtre d'achat ouverte)

type Intent = { Key: string, Grant: Products.Grant, At: number }

local intents: { [Player]: Intent } = {}
local lastRequestAt: { [Player]: number } = {}

local function refuse(player: Player, message: string)
	EconomyService.SendWallet(player, { Error = message })
end

-- Une clé des objets possédés hors catalogue (pack de démarrage pris...).
local function hasKey(player: Player, key: string): boolean
	local profile = ProfileStore.Get(player)
	return profile ~= nil and profile.Owned[key] == true
end

local function refund(robux: number): Products.Grant
	return { Credits = robux * Products.CREDITS_PER_ROBUX }
end

--------------------------------------------------------------------------------
-- Demandes d'achat
--------------------------------------------------------------------------------

-- Retient la demande puis ouvre l'achat du palier.
local function promptTier(player: Player, product: Products.Product?, grant: Products.Grant)
	if not product or not Products.IsAvailable(product) then
		refuse(player, "Achat en Robux bientôt disponible.")
		return
	end
	intents[player] = { Key = product.Key, Grant = grant, At = os.clock() }
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
end

local function requestItem(player: Player, itemId: any)
	local item = Catalog.Get(if type(itemId) == "string" then itemId else nil)
	if not item or not Catalog.IsAvailable(item) then
		return
	end
	if EconomyService.Owns(player, item.Id) then
		refuse(player, "Tu possèdes déjà « " .. item.Name .. " ».")
		return
	end
	promptTier(player, Products.ForItem(item.Id), { Item = item.Id })
end

local function requestUnlock(player: Player, kind: any, index: any)
	if type(kind) ~= "string" or type(index) ~= "number" then
		return
	end
	local entry = Progression.ItemFor(kind :: any, index)
	local profile = ProfileStore.Get(player)
	if not entry or not profile then
		return
	end
	if Progression.IsUnlocked(entry.Kind, entry.Index, ProgressService.Get(player), profile.Owned) then
		refuse(player, "C'est déjà débloqué.")
		return
	end
	-- Une pièce de tirage : on achète la pièce elle-même.
	local partId = entry.Requirement.Item
	if partId then
		requestItem(player, partId)
		return
	end
	promptTier(player, Products.ForUnlock(entry.Requirement), { Unlock = Progression.UnlockKey(entry.Kind, entry.Index) })
end

-- Une offre à prix fixe (packs, pass premium, démarrage, boost, tirages).
local function requestProduct(player: Player, key: any)
	local product = Products.Get(if type(key) == "string" then key else nil)
	if not product or product.Tier then
		return
	end
	if not Products.IsAvailable(product) then
		refuse(player, "Achat en Robux bientôt disponible.")
		return
	end
	if product.Random and Perks.IsRandomRestricted(player) then
		refuse(player, "Les tirages payants ne sont pas disponibles dans ton pays.")
		return
	end
	if product.Grant.Starter and hasKey(player, Products.STARTER_KEY) then
		refuse(player, "Tu as déjà le pack de démarrage.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
end

--------------------------------------------------------------------------------
-- Ce que donne un achat, au moment où il est reçu
--------------------------------------------------------------------------------

local function resolveGrant(player: Player?, product: Products.Product): Products.Grant
	local tier = product.Tier
	if tier then
		local intent = if player then intents[player] else nil
		if player and intent and intent.Key == product.Key and os.clock() - intent.At < INTENT_LIFETIME then
			local grant = intent.Grant
			local profile = ProfileStore.Get(player)
			local owned = if profile then profile.Owned else {}
			local itemId = grant.Item
			local unlock = grant.Unlock
			-- Obtenu entre-temps (tirage, Pass...) : remboursé.
			if (itemId and Catalog.Owns(owned, itemId)) or (unlock and owned[unlock]) then
				return refund(tier)
			end
			return grant
		end
		return refund(tier)
	end
	if product.Random and player and Perks.IsRandomRestricted(player) then
		return refund(product.SuggestedRobux)
	end
	if product.Grant.Starter and player and hasKey(player, Products.STARTER_KEY) then
		-- Racheté par un achat lancé à la main : les crédits, sans le reste.
		return { Credits = product.Grant.Credits }
	end
	return product.Grant
end

--------------------------------------------------------------------------------
-- Pass de jeu, Premium, règles du pays
--------------------------------------------------------------------------------

local function applyVipTag(player: Player)
	player:SetAttribute("Vip", Perks.Has(player, "vip"))
end

-- Pass Premium : la voie premium du Rallye Pass, et le droit de créer une session privée.
local function applyPremiumPass(player: Player)
	if Perks.HasPremiumPass(player) then
		PassService.EnsurePremium(player)
	end
	SessionService.Refresh(player)
end

local function checkPlayer(player: Player)
	for _, pass in ipairs(Products.PASSES) do
		if Products.IsPassAvailable(pass) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			Perks.SetPass(player, pass.Key, ok and owns == true)
		end
	end
	-- Pass offerts (GiftService : liste du code, commandes des admins), en plus des achetés.
	for key in pairs(GiftService.PassesOf(player.UserId)) do
		Perks.SetPass(player, key, true)
	end
	Perks.SetPremium(player, player.MembershipType == Enum.MembershipType.Premium)
	-- En cas de doute (service indisponible) : on considère les tirages interdits.
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	Perks.SetRandomRestricted(player, not ok or type(policy) ~= "table" or policy.ArePaidRandomItemsRestricted == true)
	applyVipTag(player)
	applyPremiumPass(player)
	if player.Parent then
		EconomyService.SendWallet(player)
	end
end

function MonetizationService.Start()
	-- Un don fait ou retiré : on revérifie tout (les pass achetés restent).
	GiftService.Changed = function(player: Player)
		checkPlayer(player)
	end
	EconomyService.ResolveGrant = resolveGrant
	EconomyService.ReceiptGranted = function(player: Player, product: Products.Product)
		if product.Tier then
			intents[player] = nil
		end
	end

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(checkPlayer, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(checkPlayer, player)
	end
	-- Le profil arrive après : son portefeuille repart avec les avantages.
	ProfileStore.OnLoaded(function(player)
		EconomyService.SendWallet(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		intents[player] = nil
		lastRequestAt[player] = nil
		Perks.Forget(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, purchased: boolean)
		local pass = Products.PassById(gamePassId)
		if not pass or not purchased then
			return
		end
		Perks.SetPass(player, pass.Key, true)
		applyVipTag(player)
		applyPremiumPass(player)
		EconomyService.SendWallet(player, { PassBought = pass.Key })
	end)
	Players.PlayerMembershipChanged:Connect(function(player: Player)
		Perks.SetPremium(player, player.MembershipType == Enum.MembershipType.Premium)
		EconomyService.SendWallet(player)
	end)

	Remotes.RequestRobuxPurchase.OnServerEvent:Connect(function(player: Player, kind: any, a: any, b: any)
		local now = os.clock()
		if now - (lastRequestAt[player] or -math.huge) < REQUEST_COOLDOWN then
			return
		end
		lastRequestAt[player] = now
		if kind == "Item" then
			requestItem(player, a)
		elseif kind == "Unlock" then
			requestUnlock(player, a, b)
		elseif kind == "Product" then
			requestProduct(player, a)
		end
	end)
end

return MonetizationService
