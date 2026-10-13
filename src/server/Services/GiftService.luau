--!strict
--[[
	GiftService.luau
	Les pass offerts (VIP, Crédits ×2, Premium : Products.PASSES), sans achat.
	Roblox ne permet pas d'offrir un pass de jeu : le jeu les accorde lui-même,
	exactement comme s'ils avaient été achetés (Perks.SetPass), avec tout ce
	qui suit (XP, badge, crédits, sessions privées, Rallye Pass premium).

	DEUX FAÇONS D'OFFRIR :
		- FRIENDS, ci-dessous : une liste dans le code (identifiant Roblox ->
		  pass). L'identifiant est le nombre dans l'adresse du profil :
		  roblox.com/users/123456789/profile. Changer la liste = republier ;
		- les COMMANDES DU CHAT, réservées aux admins (AdminCommands.luau : le
		  créateur du jeu, ses ADMINS, et tout le monde dans Studio) :
			/vip Pseudo         offre le VIP
			/premium Pseudo     offre le Premium (tous les avantages)
			/credits2 Pseudo    offre Crédits ×2
			/retirer Pseudo     retire tout ce qui a été offert par commande
			/dons               liste les dons faits par commande
		  Pseudo : un joueur présent (nom ou nom affiché, début suffit), ou
		  l'identifiant Roblox, ou le nom d'un joueur absent. Ces dons sont
		  gardés dans un DataStore (GiftedPasses), lu par tous les serveurs.

	Un don s'ajoute à ce que le joueur a acheté : acheter ensuite le vrai pass
	ne fait rien perdre ; retirer un don n'enlève jamais un pass acheté.
]]

local Players = game:GetService("Players")

local Stores = require(script.Parent.Parent.Data.Stores)
local AdminCommands = require(script.Parent.AdminCommands)

local GiftService = {}

-- Amis : identifiant Roblox -> pass offerts ("vip", "credits_x2", "premium").
-- Exemple : [123456789] = { "premium" },
GiftService.FRIENDS = {} :: { [number]: { string } }

-- Prévenu quand les pass offerts d'un joueur présent changent (MonetizationService).
GiftService.Changed = nil :: ((player: Player) -> ())?

local STORE_NAME = "GiftedPasses"
local STORE_KEY = "v1"
local REFRESH = 120 -- secondes : relecture des dons faits sur les autres serveurs

type Entry = { Keys: { string }, By: number, At: number }
local gifts: { [string]: Entry } = {} -- identifiant (texte) -> dons par commande

-- Commandes qui offrent un pass (en plus : /retirer et /dons).
local COMMANDS: { [string]: string } = {
	["/vip"] = "vip",
	["/premium"] = "premium",
	["/credits2"] = "credits_x2",
}
local PASS_NAMES: { [string]: string } = { vip = "VIP", premium = "Premium", credits_x2 = "Crédits ×2" }

-- Les pass offerts à un joueur : la liste du code et les dons par commande.
function GiftService.PassesOf(userId: number): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, key in ipairs(GiftService.FRIENDS[userId] or {}) do
		set[key] = true
	end
	local entry = gifts[tostring(userId)]
	if entry then
		for _, key in ipairs(entry.Keys) do
			set[key] = true
		end
	end
	return set
end


local function sanitize(data: any): { [string]: Entry }
	local clean: { [string]: Entry } = {}
	if type(data) ~= "table" then
		return clean
	end
	for id, entry in pairs(data) do
		if type(id) == "string" and tonumber(id) and type(entry) == "table" and type(entry.Keys) == "table" then
			local keys = {}
			for _, key in ipairs(entry.Keys) do
				if PASS_NAMES[key] and not table.find(keys, key) then
					table.insert(keys, key)
				end
			end
			if #keys > 0 then
				clean[id] = {
					Keys = keys,
					By = if type(entry.By) == "number" then entry.By else 0,
					At = if type(entry.At) == "number" then entry.At else 0,
				}
			end
		end
	end
	return clean
end

local function notifyChanged(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local changed = GiftService.Changed
	if player and changed then
		task.spawn(changed, player)
	end
end

local function load()
	local store = Stores.Get(STORE_NAME)
	if not store then
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync(STORE_KEY)
	end)
	if not ok then
		Stores.Failed("dons", data)
		return
	end
	local before = gifts
	gifts = sanitize(data)
	-- Un don fait ou retiré sur un autre serveur : les joueurs présents suivent.
	for _, player in ipairs(Players:GetPlayers()) do
		local id = tostring(player.UserId)
		local a, b = before[id], gifts[id]
		if (a and table.concat(a.Keys, ",") or "") ~= (b and table.concat(b.Keys, ",") or "") then
			notifyChanged(player.UserId)
		end
	end
end

-- Écrit un changement de dons (dans le DataStore s'il est là, en mémoire sinon).
local function change(userId: number, mutate: (Entry?) -> Entry?)
	local id = tostring(userId)
	local store = Stores.Get(STORE_NAME)
	if store then
		local ok, result = pcall(function()
			return store:UpdateAsync(STORE_KEY, function(old: any)
				local data = sanitize(old)
				data[id] = mutate(data[id]) :: any
				return data
			end)
		end)
		if ok then
			gifts = sanitize(result)
		else
			Stores.Failed("dons", result)
			gifts[id] = mutate(gifts[id]) :: any
		end
	else
		gifts[id] = mutate(gifts[id]) :: any
	end
	notifyChanged(userId)
end

function GiftService.Grant(userId: number, key: string, by: number)
	change(userId, function(entry: Entry?): Entry?
		local keys = if entry then table.clone(entry.Keys) else {}
		if not table.find(keys, key) then
			table.insert(keys, key)
		end
		return { Keys = keys, By = by, At = os.time() }
	end)
end

function GiftService.Revoke(userId: number)
	change(userId, function(_entry: Entry?): Entry?
		return nil
	end)
end

--------------------------------------------------------------------------------
-- Commandes du chat (AdminCommands : réservées aux admins)
--------------------------------------------------------------------------------

local function offer(key: string): (Player, string) -> ()
	return function(player: Player, argument: string)
		if argument == "" then
			AdminCommands.Tell(player, "Précise le joueur : /" .. key .. " Pseudo")
			return
		end
		local userId, name = AdminCommands.Resolve(argument)
		if not userId then
			AdminCommands.Tell(player, "Joueur introuvable : " .. argument)
			return
		end
		GiftService.Grant(userId, key, player.UserId)
		AdminCommands.Tell(player, string.format("%s offert à %s.", PASS_NAMES[key], name or tostring(userId)))
		local target = Players:GetPlayerByUserId(userId)
		if target and target ~= player then
			AdminCommands.Tell(target, string.format("🎁 Tu as reçu le pass %s, offert par %s !", PASS_NAMES[key], player.DisplayName))
		end
	end
end

local function revoke(player: Player, argument: string)
	if argument == "" then
		AdminCommands.Tell(player, "Précise le joueur : /retirer Pseudo")
		return
	end
	local userId, name = AdminCommands.Resolve(argument)
	if not userId then
		AdminCommands.Tell(player, "Joueur introuvable : " .. argument)
		return
	end
	GiftService.Revoke(userId)
	AdminCommands.Tell(player, string.format("Dons retirés à %s (les pass achetés restent).", name or tostring(userId)))
end

local function list(player: Player, _argument: string)
	local lines = {}
	for id, entry in pairs(gifts) do
		local names = {}
		for _, key in ipairs(entry.Keys) do
			table.insert(names, PASS_NAMES[key])
		end
		local present = Players:GetPlayerByUserId(tonumber(id) :: number)
		table.insert(lines, string.format("%s : %s", if present then present.Name else id, table.concat(names, ", ")))
	end
	local friends = 0
	for _ in pairs(GiftService.FRIENDS) do
		friends += 1
	end
	AdminCommands.Tell(player, if #lines == 0
		then string.format("Aucun don par commande. Liste du code : %d ami(s).", friends)
		else string.format("Dons (%d) : %s. Liste du code : %d ami(s).", #lines, table.concat(lines, " · "), friends))
end

function GiftService.Start()
	for alias, key in pairs(COMMANDS) do
		AdminCommands.Register(alias, offer(key))
	end
	AdminCommands.Register("/retirer", revoke)
	AdminCommands.Register("/dons", list)
	task.spawn(load) -- les joueurs déjà là suivent dès la lecture (notifyChanged)
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			load()
		end
	end)
end

return GiftService
