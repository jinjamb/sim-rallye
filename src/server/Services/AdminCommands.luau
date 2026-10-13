--!strict
--[[
	AdminCommands.luau
	Les commandes du chat réservées aux admins (pass offerts : GiftService ;
	modération des classements : ModerationService). Un seul endroit décide
	qui est admin, sur le SERVEUR, d'après l'identifiant du compte (UserId)
	que Roblox fournit : un joueur ne peut ni le choisir ni le falsifier.

	ADMINS : le créateur du jeu (s'il est publié au nom d'un compte), les
	identifiants ci-dessous (indispensable si le jeu appartient à un groupe),
	et tout le monde quand le serveur tourne dans Roblox Studio (essais).

	Une commande : un alias (« /vip ») et une fonction (joueur, argument).
	Elles passent par TextChatService (commandes du chat) et, pour l'ancien
	chat, par Player.Chatted ; un même message n'est traité qu'une fois.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

local AdminCommands = {}

-- Admins en plus du créateur du jeu (identifiants Roblox) : [123456789] = true,
AdminCommands.ADMINS = {} :: { [number]: boolean }

type Handler = (player: Player, argument: string) -> ()
local handlers: { [string]: Handler } = {}
local started = false
local lastCommand: { [Player]: { Text: string, At: number } } = {}

function AdminCommands.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if AdminCommands.ADMINS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- Une notification chez ce joueur (réponse à une commande, cadeau reçu...).
function AdminCommands.Tell(player: Player, text: string)
	Remotes.GiftMessage:FireClient(player, text)
end

--[[
	Le joueur visé : présent (nom ou nom affiché, exact puis début), sinon un
	identifiant Roblox, sinon le nom exact d'un joueur absent.
]]
function AdminCommands.Resolve(query: string): (number?, string?)
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

-- Déclare une commande (avant AdminCommands.Start).
function AdminCommands.Register(alias: string, handler: Handler)
	handlers[string.lower(alias)] = handler
end

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
	local handler = handlers[string.lower(command)]
	if not handler then
		return
	end
	if not AdminCommands.IsAdmin(player) then
		AdminCommands.Tell(player, "Commande réservée aux admins du jeu.")
		return
	end
	local ok, problem = pcall(function()
		handler(player, argument or "")
	end)
	if not ok then
		warn("[Admin] " .. command .. " : " .. tostring(problem))
		AdminCommands.Tell(player, "La commande a échoué : " .. tostring(problem))
	end
end

function AdminCommands.Start()
	if started then
		return
	end
	started = true
	local ok = pcall(function()
		for alias in pairs(handlers) do
			local command = Instance.new("TextChatCommand")
			command.Name = "Admin_" .. string.sub(alias, 2)
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
		warn("[Admin] Commandes du chat non créées : seules celles de l'ancien chat marcheront")
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

return AdminCommands
