--!strict
--[[
	SessionService.luau
	Jouer entre amis.

	INVITER : le bouton du menu ouvre l'invitation de Roblox (côté client,
	SocialService). Un ami qui accepte rejoint le jeu ; s'il était invité
	depuis une session privée, l'invitation porte son code (LaunchData), et
	ce service l'y emmène dès son arrivée.

	SESSION PRIVÉE (création réservée au pass Premium ; la rejoindre avec un
	code, ou par invitation, reste ouvert à tous) : un serveur réservé (TeleportService:ReserveServerAsync),
	où n'entrent que ceux qui ont son code. Le créateur y est téléporté ; le
	code (6 caractères, sans lettres ambiguës) s'affiche dans le menu, à
	donner aux amis ou à envoyer avec l'invitation. Tout y fonctionne comme
	ailleurs : spéciales, courses, records, progression (mêmes sauvegardes).

	CODES : rangés dans une MemoryStore (code -> accès au serveur réservé),
	valables SESSION_LIFETIME après la création. Un serveur réservé reste
	joignable tant que son code l'est : Roblox le relance s'il s'était
	arrêté.

	Ne fonctionne pas dans Studio (pas de téléportation en test) : le menu le
	dit.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Perks = require(script.Parent.Perks)

local SessionService = {}

local CODE_LENGTH = 6
local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- ni O/0, ni I/1
local SESSION_LIFETIME = 24 * 3600 -- secondes
local ACTION_COOLDOWN = 3 -- secondes entre deux demandes d'un joueur
local CREATE_COOLDOWN = 60 -- une session créée par minute et par joueur

type SessionInfo = { AccessCode: string, HostId: number, CreatedAt: number }

-- Ce serveur est-il une session privée ? Son code, appris des arrivants.
local isPrivate = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local serverCode: string? = nil

local lastActionAt: { [Player]: number } = {}
local lastCreateAt: { [number]: number } = {}

local function sessionMap(): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("PrivateSessions")
	end)
	return if ok then map else nil
end

local function sendState(player: Player, message: string?, isError: boolean?)
	if not player.Parent then
		return
	end
	Remotes.SessionState:FireClient(player, {
		Private = isPrivate,
		Code = serverCode,
		Players = #Players:GetPlayers(),
		MaxPlayers = Players.MaxPlayers,
		Studio = RunService:IsStudio(),
		CanCreate = Perks.HasPremiumPass(player), -- créer une session : pass Premium
	}, if message then { Message = message, Error = isError == true } else nil)
end

local function sendAll()
	for _, player in ipairs(Players:GetPlayers()) do
		sendState(player)
	end
end

-- Code propre (majuscules, alphabet des codes), ou nil.
local function cleanCode(input: any): string?
	if type(input) ~= "string" then
		return nil
	end
	local code = string.upper((string.gsub(input, "%s", "")))
	if #code ~= CODE_LENGTH then
		return nil
	end
	for i = 1, #code do
		if not string.find(CODE_ALPHABET, string.sub(code, i, i), 1, true) then
			return nil
		end
	end
	return code
end

local function newCode(): string
	local chars = table.create(CODE_LENGTH)
	for i = 1, CODE_LENGTH do
		local index = math.random(1, #CODE_ALPHABET)
		chars[i] = string.sub(CODE_ALPHABET, index, index)
	end
	return table.concat(chars)
end

-- Téléporte `player` dans la session `code` (accès connu). Renvoie un message d'erreur.
local function teleportTo(player: Player, code: string, accessCode: string): string?
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ SessionCode = code })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[Session] Téléportation impossible :", err)
		return "La téléportation a échoué. Réessaie dans un instant."
	end
	return nil
end

local function lookup(code: string): SessionInfo?
	local map = sessionMap()
	if not map then
		return nil
	end
	local ok, value = pcall(function()
		return map:GetAsync(code)
	end)
	if ok and type(value) == "table" and type(value.AccessCode) == "string" then
		return value :: any
	end
	return nil
end

local function create(player: Player)
	if not Perks.HasPremiumPass(player) then
		sendState(player, "Créer une session privée est réservé au Premium Sim Rallye (boutique). Rejoindre celle d'un ami reste gratuit.", true)
		return
	end
	local now = os.clock()
	if now - (lastCreateAt[player.UserId] or -math.huge) < CREATE_COOLDOWN then
		sendState(player, "Une session par minute : patiente un peu.", true)
		return
	end
	local map = sessionMap()
	if not map then
		sendState(player, "Les sessions privées sont indisponibles pour l'instant.", true)
		return
	end
	lastCreateAt[player.UserId] = now
	local okReserve, accessCode = pcall(function()
		return (TeleportService:ReserveServerAsync(game.PlaceId))
	end)
	if not okReserve or type(accessCode) ~= "string" then
		warn("[Session] Réservation impossible :", accessCode)
		sendState(player, "Impossible de créer la session. Réessaie dans un instant.", true)
		return
	end
	-- Un code libre (les collisions sont rarissimes : quelques essais suffisent).
	local code: string? = nil
	for _ = 1, 5 do
		local candidate = newCode()
		local stored = false
		local ok = pcall(function()
			map:UpdateAsync(candidate, function(existing: any)
				if existing ~= nil then
					return nil
				end
				stored = true
				return { AccessCode = accessCode, HostId = player.UserId, CreatedAt = os.time() }
			end, SESSION_LIFETIME)
		end)
		if ok and stored then
			code = candidate
			break
		end
	end
	if not code then
		sendState(player, "Impossible de créer la session. Réessaie dans un instant.", true)
		return
	end
	sendState(player, "Session créée (code " .. code .. ") : en route !")
	local problem = teleportTo(player, code, accessCode)
	if problem then
		sendState(player, problem, true)
	end
end

local function join(player: Player, input: any)
	local code = cleanCode(input)
	if not code then
		sendState(player, string.format("Un code de session a %d caractères (lettres et chiffres).", CODE_LENGTH), true)
		return
	end
	if isPrivate and code == serverCode then
		sendState(player, "Tu es déjà dans cette session.", true)
		return
	end
	local info = lookup(code)
	if not info then
		sendState(player, "Aucune session avec ce code (ou elle a expiré).", true)
		return
	end
	sendState(player, "Session " .. code .. " trouvée : en route !")
	local problem = teleportTo(player, code, info.AccessCode)
	if problem then
		sendState(player, problem, true)
	end
end

-- Retour aux serveurs publics : un serveur public au hasard.
local function leave(player: Player)
	if not isPrivate then
		return
	end
	sendState(player, "Retour aux serveurs publics…")
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		warn("[Session] Retour impossible :", err)
		sendState(player, "La téléportation a échoué. Réessaie dans un instant.", true)
	end
end

local function onAction(player: Player, action: any, payload: any)
	local now = os.clock()
	if now - (lastActionAt[player] or -math.huge) < ACTION_COOLDOWN then
		return
	end
	lastActionAt[player] = now
	if RunService:IsStudio() and (action == "Create" or action == "Join" or action == "Leave") then
		sendState(player, "Les sessions privées ne marchent qu'en jeu publié (pas dans Studio).", true)
		return
	end
	if action == "Create" then
		create(player)
	elseif action == "Join" then
		join(player, payload)
	elseif action == "Leave" then
		leave(player)
	elseif action == "State" then
		sendState(player)
	end
end

local function onPlayerAdded(player: Player)
	local joinData = player:GetJoinData()
	-- Arrivé dans une session privée : son code vient avec la téléportation.
	local teleportData = joinData.TeleportData
	if isPrivate and serverCode == nil and type(teleportData) == "table" then
		serverCode = cleanCode((teleportData :: any).SessionCode)
	end
	-- Invité depuis une session privée : l'invitation porte son code.
	local invited = cleanCode(joinData.LaunchData)
	if invited and not (isPrivate and invited == serverCode) and not RunService:IsStudio() then
		task.spawn(function()
			local info = lookup(invited)
			if info and player.Parent then
				sendState(player, "Invitation : direction la session de ton ami…")
				teleportTo(player, invited, info.AccessCode)
			end
		end)
	end
	sendAll()
end

-- Avantages changés (pass Premium acheté, ou vérifié à l'arrivée) : le menu suit.
function SessionService.Refresh(player: Player)
	sendState(player)
end

function SessionService.Start()
	Remotes.SessionAction.OnServerEvent:Connect(onAction)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
		task.defer(sendAll)
	end)
	-- Téléportation refusée (serveur plein, souci réseau) : on le dit.
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		warn("[Session] Téléportation refusée :", message)
		sendState(player, "La téléportation a échoué : " .. message, true)
	end)
end

return SessionService
