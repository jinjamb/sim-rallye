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
		- les COMMANDES DU CHAT, réservées aux admins (le créateur du jeu, les
		  ADMINS ci-dessous, et tout le monde dans Studio) :
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Stores = require(script.Parent.Parent.Data.Stores)

local GiftService = {}

-- Amis : identifiant Roblox -> pass offerts ("vip", "credits_x2", "premium").
-- Exemple : [123456789] = { "premium" },
GiftService.FRIENDS = {} :: { [number]: { string } }

-- Admins en plus du créateur du jeu (identifiants Roblox) : ils peuvent offrir.
GiftService.ADMINS = {} :: { [number]: boolean }

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

local function validKey(key: any): boolean
	return type(key) == "string" and PASS_NAMES[key] ~= nil
end

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

function GiftService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if GiftService.ADMINS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
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
-- Commandes du chat
--------------------------------------------------------------------------------

local function tell(player: Player, text: string)
	Remotes.GiftMessage:FireClient(player, text)
end

-- Le joueur visé : présent (nom ou nom affiché, début suffit), identifiant, ou nom d'un absent.
local function resolve(query: string): (number?, string?)
	local lower = string.lower(query)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == lower or string.lower(player.DisplayName) == lower then
			return player.UserId, player.Name
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(player.Name), 1, #lower) == lower or string.sub(string.lower(player.DisplayName), 1, #lower) == lower then
			return player.UserId, player.Name
		end
	end
	local number = tonumber(query)
	if number and number > 0 then
		return math.floor(number), query
	end
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync(query)
	end)
	if ok and type(id) == "number" then
		return id, query
	end
	return nil, nil
end

local lastCommand: { [Player]: { Text: string, At: number } } = {}

local function run(player: Player, text: string)
	-- La même commande peut arriver deux fois (commande et message de chat).
	local last = lastCommand[player]
	local now = os.clock()
	if last and last.Text == text and now - last.At < 1 then
		return
	end
	lastCommand[player] = { Text = text, At = now }

	local command, argument = string.match(text, "^(/%S+)%s*(.-)%s*$")
	if not command then
		return
	end
	command = string.lower(command)
	if COMMANDS[command] == nil and command ~= "/retirer" and command ~= "/dons" then
		return
	end
	if not GiftService.IsAdmin(player) then
		tell(player, "Commande réservée aux admins du jeu.")
		return
	end

	if command == "/dons" then
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
		tell(player, if #lines == 0
			then string.format("Aucun don par commande. Liste du code : %d ami(s).", friends)
			else string.format("Dons (%d) : %s. Liste du code : %d ami(s).", #lines, table.concat(lines, " · "), friends))
		return
	end

	if argument == nil or argument == "" then
		tell(player, "Précise le joueur : " .. command .. " Pseudo")
		return
	end
	local userId, name = resolve(argument)
	if not userId then
		tell(player, "Joueur introuvable : " .. argument)
		return
	end

	if command == "/retirer" then
		GiftService.Revoke(userId)
		tell(player, string.format("Dons retirés à %s (les pass achetés restent).", name or tostring(userId)))
		return
	end

	local key = COMMANDS[command] :: string
	if not validKey(key) then
		return
	end
	GiftService.Grant(userId, key, player.UserId)
	tell(player, string.format("%s offert à %s.", PASS_NAMES[key], name or tostring(userId)))
	local target = Players:GetPlayerByUserId(userId)
	if target and target ~= player then
		tell(target, string.format("🎁 Tu as reçu le pass %s, offert par %s !", PASS_NAMES[key], player.DisplayName))
	end
end

-- Commandes du chat (TextChatService) ; l'ancien chat passe par Chatted.
local function setupCommands()
	local ok = pcall(function()
		for alias in pairs({ ["/vip"] = true, ["/premium"] = true, ["/credits2"] = true, ["/retirer"] = true, ["/dons"] = true }) do
			local command = Instance.new("TextChatCommand")
			command.Name = "Gift" .. string.sub(alias, 2)
			command.PrimaryAlias = alias
			command.Triggered:Connect(function(source: TextSource, message: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, message)
				end
			end)
			command.Parent = TextChatService
		end
	end)
	if not ok then
		warn("[Dons] Commandes du chat non créées : seules les commandes de l'ancien chat marcheront")
	end
	local function watch(player: Player)
		player.Chatted:Connect(function(message: string)
			if string.sub(message, 1, 1) == "/" then
				run(player, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCommand[player] = nil
	end)
end

function GiftService.Start()
	setupCommands()
	task.spawn(load) -- les joueurs déjà là suivent dès la lecture (notifyChanged)
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			load()
		end
	end)
end

return GiftService
