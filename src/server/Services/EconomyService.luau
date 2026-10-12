--!strict
--[[
	EconomyService.luau
	Crédits, objets possédés, objets portés, achats en Robux.

	GAGNER (Earn) : appelé par les autres services selon le barème de
	Credits.luau. Les gains sont des sommes : ajoutés au profil par lots
	(ProfileStore.AddCounter), sans jamais écraser ce qu'un autre serveur a
	écrit.

	ACHETER EN CRÉDITS (BuyItem) : le serveur vérifie l'objet, son prix et le
	solde, puis débite et donne l'objet dans la MÊME écriture (on ne peut
	pas perdre l'un sans l'autre), écrite aussitôt.

	ACHETER EN ROBUX (ProcessReceipt) : Roblox appelle le serveur pour chaque
	achat, et le rappelle tant qu'on n'a pas répondu « accordé ». On ne
	répond « accordé » qu'une fois l'achat SAUVEGARDÉ, et l'identifiant de
	l'achat est gardé dans le profil : un achat rejoué n'est jamais accordé
	deux fois. Sans DataStore (Studio), l'achat de test est accordé en
	mémoire, pour la session.
	Ce que donne un palier d'achat (objet ou déblocage demandé) ou un tirage
	(remboursé en crédits là où c'est interdit) est décidé au moment de
	l'achat par MonetizationService (ResolveGrant).

	AVANTAGES (Perks.luau) : les crédits gagnés en jouant sont multipliés
	(pass Crédits ×2, bonus Roblox Premium) ; les achats, eux, ne le sont pas.

	NOUVELLE GAMME (GarageVersion) : la Rally2 était de série, c'est
	maintenant la Rally4. Un pilote arrivé avant garde sa Rally2 (possédée,
	et portée s'il n'avait rien choisi d'autre).

	PORTER (EquipItem) : un objet de chaque sorte, s'il est possédé. Les
	objets portés sont montrés aux autres joueurs par la voiture
	(EquippedChanged, branché sur CarService par Main.server.luau).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Pass = require(ReplicatedStorage.Shared.Economy.Pass)
local Perks = require(script.Parent.Perks)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)

local EconomyService = {}

local ACTION_COOLDOWN = 0.4 -- seconde entre deux achats ou changements d'objet

type Profile = ProfileSchema.Profile

-- Appelée quand un joueur change d'objet porté (ou au chargement) : la voiture
-- montre ses objets aux autres (CarService).
EconomyService.EquippedChanged = function(_player: Player) end

--------------------------------------------------------------------------------
-- Ce que le joueur voit : solde, objets
--------------------------------------------------------------------------------

local function walletOf(profile: Profile): any
	local owned = {}
	for id in pairs(profile.Owned) do
		table.insert(owned, id)
	end
	return { Credits = profile.Credits, Owned = owned, Equipped = profile.Equipped, Rolls = profile.Rolls, Pity = profile.RollPity }
end

-- `news` : { Gain, Reason } (crédits gagnés), { Bought = itemId }...
local function sendWallet(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if profile and player.Parent then
		local wallet = walletOf(profile)
		wallet.Perks = Perks.Snapshot(player)
		Remotes.Wallet:FireClient(player, wallet, news)
	end
end
EconomyService.SendWallet = sendWallet

-- Tirages gagnés (niveau, défis, Rallye Pass) : Rolls.luau, RollService.
function EconomyService.AddRolls(player: Player, count: number, reason: string)
	if count <= 0 or not ProfileStore.Get(player) then
		return
	end
	ProfileStore.AddCounter(player, "Rolls", count)
	sendWallet(player, { RollsGained = count, Reason = reason })
end

--------------------------------------------------------------------------------
-- Crédits
--------------------------------------------------------------------------------

-- Crédits gagnés en jouant. `reason` : affiché au joueur ("Spéciale terminée").
-- Multipliés par les avantages du joueur (Crédits ×2, Premium).
function EconomyService.Earn(player: Player, amount: number, reason: string)
	if amount <= 0 or not ProfileStore.Get(player) then
		return
	end
	local gain = math.floor(amount * Perks.CreditMultiplier(player))
	ProfileStore.AddCounter(player, "Credits", gain)
	sendWallet(player, { Gain = gain, Reason = reason })
end

function EconomyService.GetCredits(player: Player): number
	local profile = ProfileStore.Get(player)
	return if profile then profile.Credits else 0
end

--------------------------------------------------------------------------------
-- Objets
--------------------------------------------------------------------------------

function EconomyService.Owns(player: Player, itemId: string): boolean
	local profile = ProfileStore.Get(player)
	return Catalog.Owns(if profile then profile.Owned else nil, itemId)
end

-- L'objet porté d'une sorte (le défaut de la sorte sans choix, ou si
-- l'objet choisi n'est plus possédé).
function EconomyService.Equipped(player: Player, kind: Catalog.Kind): Catalog.Item?
	local profile = ProfileStore.Get(player)
	if profile then
		local id = profile.Equipped[kind]
		local item = Catalog.Get(id)
		if item and item.Kind == kind and Catalog.Owns(profile.Owned, item.Id) then
			return item
		end
	end
	return Catalog.Default(kind)
end

--[[
	Donne un objet (tirage, Rallye Pass, achat Robux), écrit aussitôt.
	Renvoie false s'il était déjà possédé.
]]
function EconomyService.Grant(player: Player, itemId: string, reason: string): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not Catalog.Get(itemId) or Catalog.Owns(profile.Owned, itemId) then
		return false
	end
	profile.Owned[itemId] = true
	ProfileStore.Update(player.UserId, "objet", function(stored)
		if stored.Owned[itemId] then
			return false
		end
		stored.Owned[itemId] = true
		return true
	end)
	sendWallet(player, { Unlocked = itemId, Reason = reason })
	return true
end

local function buyItem(player: Player, itemId: any)
	local profile = ProfileStore.Get(player)
	local item = Catalog.Get(if type(itemId) == "string" then itemId else nil)
	if not profile or not item then
		return
	end
	local listed = item.Credits
	if not listed or not Catalog.IsAvailable(item) or Catalog.Owns(profile.Owned, item.Id) then
		return
	end
	-- Événement éclair « Voiture rare » : sa voiture est moins chère.
	local price = FlashEvents.CreditPrice(listed, if item.Kind == "Car" then item.CarClass else nil, os.time())
	if profile.Credits < price then
		sendWallet(player, { Error = "Pas assez de crédits : il en manque " .. Credits.Format(price - profile.Credits) .. "." })
		return
	end
	-- Débit et objet dans la même écriture, partie tout de suite.
	ProfileStore.AddCounter(player, "Credits", -price)
	profile.Owned[item.Id] = true
	local id = item.Id
	ProfileStore.Defer(player, "own:" .. id, function(stored)
		stored.Owned[id] = true
	end)
	ProfileStore.Flush(player)
	sendWallet(player, { Bought = id })
end

local function equipItem(player: Player, kind: any, itemId: any)
	local profile = ProfileStore.Get(player)
	local item = Catalog.Get(if type(itemId) == "string" then itemId else nil)
	if not profile or not item or item.Kind ~= kind or not Catalog.Owns(profile.Owned, item.Id) then
		return
	end
	if profile.Equipped[item.Kind] == item.Id then
		return
	end
	profile.Equipped[item.Kind] = item.Id
	local equipped = table.clone(profile.Equipped)
	ProfileStore.Defer(player, "Equipped", function(stored)
		stored.Equipped = equipped
	end)
	sendWallet(player)
	EconomyService.EquippedChanged(player)
end

--------------------------------------------------------------------------------
-- Achats en Robux
--------------------------------------------------------------------------------

-- Ce qu'un produit donne, appliqué à un profil (sauvegardé ou en mémoire).
local function applyGrant(profile: Profile, grant: Products.Grant)
	if grant.Credits then
		profile.Credits += grant.Credits
	end
	if grant.Item then
		profile.Owned[grant.Item] = true
	end
	if grant.Unlock then
		profile.Owned[grant.Unlock] = true
	end
	if grant.Starter then
		profile.Owned[Products.STARTER_KEY] = true
	end
	if grant.Rolls then
		profile.Rolls += grant.Rolls
	end
	if grant.XpBoostMinutes then
		-- Cumulable : une heure de plus après celle en cours.
		profile.XpBoostUntil = math.max(profile.XpBoostUntil, os.time()) + grant.XpBoostMinutes * 60
	end
	if grant.PassPremium then
		-- Voie premium de la saison en cours (une saison passée repart de zéro).
		local season = Pass.Current()
		local state = profile.Pass
		if not state or state.Key ~= season.Key then
			state = { Key = season.Key, Xp = 0, Premium = false, FreeUpTo = 0, PremiumUpTo = 0 }
			profile.Pass = state
		end
		(state :: ProfileSchema.PassState).Premium = true
	end
end

-- Appelée quand la voie premium du Rallye Pass vient d'être achetée (joueur
-- connecté) : PassService donne les récompenses premium déjà atteintes.
EconomyService.PassPremiumGranted = function(_player: Player) end

--[[
	Ce que donne vraiment un produit, au moment de l'achat : branchée par
	MonetizationService (l'objet demandé pour un palier, un remboursement en
	crédits...). `player` : nil si le joueur n'est plus connecté.
]]
EconomyService.ResolveGrant = function(_player: Player?, product: Products.Product): Products.Grant
	return product.Grant
end
-- Achat accordé et sauvegardé (joueur connecté) : MonetizationService oublie la demande.
EconomyService.ReceiptGranted = function(_player: Player, _product: Products.Product) end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local product = Products.ByProductId(receipt.ProductId)
	if not product then
		warn("[EconomyService] Produit inconnu :", receipt.ProductId, "(identifiant à renseigner dans Products.luau ?)")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local userId: number = receipt.PlayerId
	local purchaseId = tostring(receipt.PurchaseId)
	local player = Players:GetPlayerByUserId(userId)
	local profile = if player then ProfileStore.Get(player) else nil
	if player and not profile then
		-- Profil en cours de chargement : Roblox redemandera.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grant = EconomyService.ResolveGrant(player, product)

	-- Studio sans DataStore : achat de test accordé pour la session. (En
	-- ligne, sans DataStore, on attend : Roblox redemandera.)
	if not Stores.Available() and RunService:IsStudio() then
		if player and profile then
			applyGrant(profile, grant)
			sendWallet(player, { Purchased = product.Key, Granted = grant })
			if grant.Item or grant.Unlock then
				EconomyService.EquippedChanged(player)
			end
			if grant.PassPremium then
				EconomyService.PassPremiumGranted(player)
			end
			EconomyService.ReceiptGranted(player, product)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Sauvegardé d'abord, et jamais deux fois (identifiant de l'achat retenu).
	local alreadyGranted = false
	local saved = ProfileStore.UpdateNow(userId, "achat Robux", function(stored)
		alreadyGranted = table.find(stored.Receipts, purchaseId) ~= nil
		if alreadyGranted then
			return false
		end
		applyGrant(stored, grant)
		table.insert(stored.Receipts, purchaseId)
		while #stored.Receipts > ProfileSchema.MAX_RECEIPTS do
			table.remove(stored.Receipts, 1)
		end
		return true
	end)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if player and profile and not alreadyGranted then
		applyGrant(profile, grant) -- la copie en mémoire suit
		sendWallet(player, { Purchased = product.Key, Granted = grant })
		if grant.Item or grant.Unlock then
			EconomyService.EquippedChanged(player)
		end
		if grant.PassPremium then
			EconomyService.PassPremiumGranted(player)
		end
	end
	if player then
		EconomyService.ReceiptGranted(player, product)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

-- La Rally2 de série d'avant la nouvelle gamme : gardée par ceux qui l'avaient.
local LEGACY_CAR = "car_rally2"
local function migrateGarage(player: Player, profile: Profile)
	if profile.GarageVersion >= ProfileSchema.GARAGE_VERSION then
		return
	end
	local equipNow = profile.Equipped.Car == nil
	profile.Owned[LEGACY_CAR] = true
	if equipNow then
		profile.Equipped.Car = LEGACY_CAR
	end
	profile.GarageVersion = ProfileSchema.GARAGE_VERSION
	ProfileStore.Update(player.UserId, "nouvelle gamme", function(stored)
		if stored.GarageVersion >= ProfileSchema.GARAGE_VERSION then
			return false
		end
		stored.Owned[LEGACY_CAR] = true
		if stored.Equipped.Car == nil then
			stored.Equipped.Car = LEGACY_CAR
		end
		stored.GarageVersion = ProfileSchema.GARAGE_VERSION
		return true
	end)
end

function EconomyService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		migrateGarage(player, profile)
		sendWallet(player)
		EconomyService.EquippedChanged(player)
	end)

	local lastActionAt: { [Player]: number } = {}
	local function allowed(player: Player): boolean
		local now = os.clock()
		if now - (lastActionAt[player] or 0) < ACTION_COOLDOWN then
			return false
		end
		lastActionAt[player] = now
		return true
	end
	Remotes.BuyItem.OnServerEvent:Connect(function(player: Player, itemId: any)
		if allowed(player) then
			buyItem(player, itemId)
		end
	end)
	Remotes.EquipItem.OnServerEvent:Connect(function(player: Player, kind: any, itemId: any)
		if allowed(player) then
			equipItem(player, kind, itemId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return EconomyService
