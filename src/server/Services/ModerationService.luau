--!strict
--[[
	ModerationService.luau
	Modération des classements, par les commandes du chat des admins
	(AdminCommands.luau) :
		/effacer Pseudo    retire ses temps de tous les classements (spéciales,
		                   tours, défi de la semaine, roi du drift) et remet
		                   ses records personnels à zéro ; il peut rejouer
		                   proprement
		/bannir Pseudo     l'exclut de TOUS les classements (rien de ce qu'il
		                   fait n'y entre plus, et il n'y apparaît plus), puis
		                   efface ses temps ; il peut toujours jouer
		/debannir Pseudo   le réintègre (ses temps effacés ne reviennent pas)
		/bannis            liste les exclus
	Pseudo : un joueur présent, un identifiant Roblox, ou le nom d'un absent.

	Les exclus et les effacements en attente (pilote absent : appliqués à sa
	prochaine venue) sont gardés dans un DataStore (Moderation), relu par
	chaque serveur toutes les deux minutes ; l'exclusion passe par
	Boards.Excluded, que tous les classements consultent.
]]

local Players = game:GetService("Players")

local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local AdminCommands = require(script.Parent.AdminCommands)
local RecordService = require(script.Parent.RecordService)
local ChallengeService = require(script.Parent.ChallengeService)

local ModerationService = {}

local STORE_NAME = "Moderation"
local STORE_KEY = "v1"
local REFRESH = 120 -- secondes

type Ban = { By: number, At: number }
type State = { Banned: { [string]: Ban }, Resets: { [string]: boolean } }
local state: State = { Banned = {}, Resets = {} }

local function sanitize(data: any): State
	local clean: State = { Banned = {}, Resets = {} }
	if type(data) ~= "table" then
		return clean
	end
	if type(data.Banned) == "table" then
		for id, ban in pairs(data.Banned) do
			if type(id) == "string" and tonumber(id) and type(ban) == "table" then
				clean.Banned[id] = {
					By = if type(ban.By) == "number" then ban.By else 0,
					At = if type(ban.At) == "number" then ban.At else 0,
				}
			end
		end
	end
	if type(data.Resets) == "table" then
		for id, flag in pairs(data.Resets) do
			if type(id) == "string" and tonumber(id) and flag == true then
				clean.Resets[id] = true
			end
		end
	end
	return clean
end

-- Boards.Excluded suit la liste des bannis.
local function applyExclusions()
	table.clear(Boards.Excluded)
	for id in pairs(state.Banned) do
		Boards.Excluded[tonumber(id) :: number] = true
	end
end

-- Effacement en attente pour un joueur présent : appliqué tout de suite.
local resetLocal: (player: Player) -> ()

local function load()
	local store = Stores.Get(STORE_NAME)
	if not store then
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync(STORE_KEY)
	end)
	if not ok then
		Stores.Failed("modération", data)
		return
	end
	state = sanitize(data)
	applyExclusions()
	for _, player in ipairs(Players:GetPlayers()) do
		if state.Resets[tostring(player.UserId)] then
			resetLocal(player)
		end
	end
end

local function change(mutate: (State) -> ())
	local store = Stores.Get(STORE_NAME)
	if store then
		local ok, result = pcall(function()
			return store:UpdateAsync(STORE_KEY, function(old: any)
				local data = sanitize(old)
				mutate(data)
				return data
			end)
		end)
		if ok then
			state = sanitize(result)
		else
			Stores.Failed("modération", result)
			mutate(state)
		end
	else
		mutate(state)
	end
	applyExclusions()
end

function resetLocal(player: Player)
	if not ProfileStore.Get(player) then
		return -- profil pas encore chargé : OnLoaded s'en chargera
	end
	RecordService.ResetProfile(player)
	local id = tostring(player.UserId)
	if state.Resets[id] then
		task.spawn(change, function(data: State)
			data.Resets[id] = nil
		end)
	end
end

-- Efface un pilote (classements et records) ; long : en tâche de fond.
local function erase(userId: number, done: () -> ())
	task.spawn(function()
		local player = Players:GetPlayerByUserId(userId)
		if player then
			RecordService.ResetProfile(player)
		else
			change(function(data: State)
				data.Resets[tostring(userId)] = true
			end)
		end
		ChallengeService.EraseFor(userId)
		RecordService.EraseFor(userId)
		done()
	end)
end

local function target(admin: Player, argument: string, usage: string): (number?, string?)
	if argument == "" then
		AdminCommands.Tell(admin, "Précise le joueur : " .. usage)
		return nil, nil
	end
	local userId, name = AdminCommands.Resolve(argument)
	if not userId then
		AdminCommands.Tell(admin, "Joueur introuvable : " .. argument)
	end
	return userId, name
end

function ModerationService.IsBanned(userId: number): boolean
	return state.Banned[tostring(userId)] ~= nil
end

function ModerationService.Start()
	AdminCommands.Register("/effacer", function(admin: Player, argument: string)
		local userId, name = target(admin, argument, "/effacer Pseudo")
		if not userId then
			return
		end
		AdminCommands.Tell(admin, string.format("Effacement des temps de %s en cours (une à deux minutes)...", name or tostring(userId)))
		erase(userId, function()
			if admin.Parent then
				AdminCommands.Tell(admin, string.format("Temps de %s effacés de tous les classements.", name or tostring(userId)))
			end
		end)
	end)

	AdminCommands.Register("/bannir", function(admin: Player, argument: string)
		local userId, name = target(admin, argument, "/bannir Pseudo")
		if not userId then
			return
		end
		if userId == admin.UserId then
			AdminCommands.Tell(admin, "Tu ne peux pas te bannir toi-même.")
			return
		end
		change(function(data: State)
			data.Banned[tostring(userId)] = { By = admin.UserId, At = os.time() }
		end)
		AdminCommands.Tell(admin, string.format("%s exclu des classements ; effacement de ses temps en cours...", name or tostring(userId)))
		erase(userId, function()
			if admin.Parent then
				AdminCommands.Tell(admin, string.format("Temps de %s effacés.", name or tostring(userId)))
			end
		end)
	end)

	AdminCommands.Register("/debannir", function(admin: Player, argument: string)
		local userId, name = target(admin, argument, "/debannir Pseudo")
		if not userId then
			return
		end
		change(function(data: State)
			data.Banned[tostring(userId)] = nil
		end)
		AdminCommands.Tell(admin, string.format("%s réintégré dans les classements.", name or tostring(userId)))
	end)

	AdminCommands.Register("/bannis", function(admin: Player, _argument: string)
		local names = {}
		for id in pairs(state.Banned) do
			local present = Players:GetPlayerByUserId(tonumber(id) :: number)
			table.insert(names, if present then present.Name else id)
		end
		AdminCommands.Tell(admin, if #names == 0 then "Aucun pilote exclu des classements." else "Exclus (" .. #names .. ") : " .. table.concat(names, ", "))
	end)

	-- Un pilote effacé pendant son absence : remis à zéro à son arrivée.
	ProfileStore.OnLoaded(function(player: Player)
		if state.Resets[tostring(player.UserId)] then
			resetLocal(player)
		end
	end)

	task.spawn(function()
		load()
		while true do
			task.wait(REFRESH)
			load()
		end
	end)
end

return ModerationService
