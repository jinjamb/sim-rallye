--!strict
--[[
	TeamService.luau
	Les écuries (Teams.luau) : création, invitations, départs, couleurs
	communes, sigle au-dessus des voitures, classement par saison.

	DONNÉES : chaque écurie est un enregistrement (DataStore TEAM_STORE),
	modifié de façon atomique (UpdateAsync) : deux pilotes qui acceptent en
	même temps une invitation ne font pas déborder l'écurie. Le profil d'un
	pilote garde l'identifiant de son écurie (TeamId) ; s'il en a été retiré
	pendant son absence, c'est corrigé à son arrivée.

	CLASSEMENT : l'XP gagnée par les pilotes pendant la saison du Rallye Pass
	(ProgressService -> AddPoints) s'ajoute au score de leur écurie, dans un
	OrderedDataStore par saison, par incréments (IncrementAsync) regroupés
	toutes les POINTS_FLUSH s.

	Sans DataStore (Studio), tout vit en mémoire, pour la session.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Teams = require(ReplicatedStorage.Shared.Teams.Teams)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Pass = require(ReplicatedStorage.Shared.Economy.Pass)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)

type Team = Teams.Team

local TeamService = {}

local TEAM_STORE = "RallyTeams_v1"
local SCORE_PREFIX = "RallyTeamScore_"
local BOARD_SIZE = 10
local BOARD_REFRESH = 90 -- secondes
local POINTS_FLUSH = 60
local TEAM_REFRESH = 120 -- relecture des écuries des joueurs présents (changements faits ailleurs)
local ACTION_COOLDOWN = 1

-- Appelée quand l'écurie d'un joueur change (entrée, départ, couleurs) :
-- sa voiture suit (sigle, livrée), branchée par Main.server.luau.
TeamService.Changed = function(_player: Player) end

local teams: { [string]: Team? } = {} -- écuries connues (celles des joueurs présents)
type Invite = { TeamId: string, TeamName: string, FromName: string, Expires: number }
local invites: { [number]: Invite? } = {} -- par UserId invité
local pendingPoints: { [string]: number } = {} -- par écurie, à ajouter au classement
local memoryScores: { [string]: number } = {} -- sans DataStore
type BoardEntry = { TeamId: string, Name: string, Tag: string, Color: number, Score: number }
local board: { BoardEntry } = {}
local knownNames: { [number]: string } = {} -- noms des membres absents

-- Les noms des membres absents, cherchés en tâche de fond (ils peuvent attendre).
local function learnNames(team: Team?)
	if not team then
		return
	end
	for _, userId in ipairs(team.Members) do
		if not knownNames[userId] and not Players:GetPlayerByUserId(userId) then
			task.spawn(function()
				knownNames[userId] = Boards.NameOf(userId)
			end)
		end
	end
end

local function teamStore(): DataStore?
	return Stores.Get(TEAM_STORE)
end

local function scoreStore(): OrderedDataStore?
	return Stores.Ordered(SCORE_PREFIX .. Pass.Current().Key)
end

local function teamKey(id: string): string
	return "t_" .. id
end

local function sanitize(data: any): Team?
	if type(data) ~= "table" or type(data.Id) ~= "string" or type(data.Name) ~= "string" or type(data.Tag) ~= "string" then
		return nil
	end
	local members = {}
	if type(data.Members) == "table" then
		for _, userId in ipairs(data.Members) do
			if type(userId) == "number" and #members < Teams.MAX_MEMBERS then
				table.insert(members, userId)
			end
		end
	end
	return {
		Id = data.Id,
		Name = data.Name,
		Tag = data.Tag,
		Color = Teams.CleanColor(data.Color) or 1,
		Stripe = Teams.CleanColor(data.Stripe) or 3,
		OwnerId = if type(data.OwnerId) == "number" then data.OwnerId else (members[1] or 0),
		Members = members,
	}
end

-- Lit une écurie (DataStore), et la garde en mémoire. nil si elle n'existe pas.
local function loadTeam(id: string): Team?
	local dataStore = teamStore()
	if not dataStore then
		return teams[id]
	end
	local ok, result = pcall(function()
		return dataStore:GetAsync(teamKey(id))
	end)
	if not ok then
		Stores.Failed("écurie", result)
		return teams[id]
	end
	local team = sanitize(result)
	teams[id] = team
	learnNames(team)
	return team
end

--[[
	Modifie une écurie de façon atomique. `change` reçoit l'écurie
	sauvegardée (nil si elle n'existe pas) et renvoie la nouvelle (nil pour
	la supprimer) ainsi qu'un message d'erreur pour refuser. Renvoie
	(écurie après, erreur).
]]
local function updateTeam(id: string, change: (Team?) -> (Team?, string?)): (Team?, string?)
	local dataStore = teamStore()
	local refusal: string? = nil
	local after: Team? = nil
	if not dataStore then
		after, refusal = change(teams[id])
		if not refusal then
			teams[id] = after
		end
		return if refusal then teams[id] else after, refusal
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(teamKey(id), function(old: any)
			local result, reason = change(sanitize(old))
			refusal = reason
			after = result
			if reason then
				return nil -- rien à écrire
			end
			return result
		end)
	end)
	if not ok then
		Stores.Failed("écurie", err)
		return teams[id], "L'écurie n'a pas pu être enregistrée, réessaie dans un instant."
	end
	if not refusal then
		teams[id] = after
		learnNames(after)
	end
	return if refusal then teams[id] else after, refusal
end

-- Texte passé au filtre de Roblox ; nil s'il a été censuré (ou en cas d'échec).
local function filtered(text: string, userId: number): string?
	local ok, result = pcall(function()
		local filter = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
		return filter:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" or result ~= text then
		return nil
	end
	return result
end

--------------------------------------------------------------------------------
-- Ce qu'on lit d'ailleurs
--------------------------------------------------------------------------------

function TeamService.Get(player: Player): Team?
	local profile = ProfileStore.Get(player)
	local id = if profile then profile.TeamId else nil
	return if id then teams[id] else nil
end

-- La livrée du joueur, aux couleurs de son écurie s'il les porte.
function TeamService.LiveryOf(player: Player, livery: Livery.Livery): Livery.Livery
	local profile = ProfileStore.Get(player)
	local team = TeamService.Get(player)
	if profile and team and profile.UseTeamColors then
		return Teams.ApplyColors(livery, team)
	end
	return livery
end

--------------------------------------------------------------------------------
-- État envoyé au joueur
--------------------------------------------------------------------------------

local function sendState(player: Player, message: string?, isError: boolean?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	local team = TeamService.Get(player)
	local members = {}
	if team then
		for _, userId in ipairs(team.Members) do
			local online = Players:GetPlayerByUserId(userId)
			table.insert(members, {
				UserId = userId,
				Name = if online then online.DisplayName else (knownNames[userId] or "Pilote"),
				Online = online ~= nil,
				Owner = userId == team.OwnerId,
			})
		end
	end
	local invite = invites[player.UserId]
	if invite and os.clock() > invite.Expires then
		invites[player.UserId] = nil
		invite = nil
	end
	local rank: number? = nil
	for index, entry in ipairs(board) do
		if team and entry.TeamId == team.Id then
			rank = index
		end
	end
	Remotes.TeamState:FireClient(player, {
		Team = if team then {
			Id = team.Id,
			Name = team.Name,
			Tag = team.Tag,
			Color = team.Color,
			Stripe = team.Stripe,
			OwnerId = team.OwnerId,
			Members = members,
		} else nil,
		UseColors = profile.UseTeamColors,
		Invite = if invite then { TeamId = invite.TeamId, TeamName = invite.TeamName, FromName = invite.FromName } else nil,
		Board = board,
		Rank = rank,
		Season = Pass.Current().Name,
	}, if message then { Message = message, Error = isError == true } else nil)
end

-- Tous les membres présents d'une écurie : leur état, leur voiture.
local function notifyMembers(team: Team?, others: { number }?)
	local userIds: { number } = {}
	if team then
		for _, userId in ipairs(team.Members) do
			table.insert(userIds, userId)
		end
	end
	for _, userId in ipairs(others or {}) do
		table.insert(userIds, userId)
	end
	for _, userId in ipairs(userIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			sendState(player)
			TeamService.Changed(player)
		end
	end
end

local function setProfileTeam(player: Player, teamId: string?)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	profile.TeamId = teamId
	ProfileStore.Defer(player, "Team", function(stored)
		stored.TeamId = teamId
		stored.UseTeamColors = profile.UseTeamColors
	end)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function create(player: Player, payload: any)
	if TeamService.Get(player) then
		sendState(player, "Tu as déjà une écurie : quitte-la d'abord.", true)
		return
	end
	local name = Teams.CleanName(payload.Name)
	local tag = Teams.CleanTag(payload.Tag)
	local color = Teams.CleanColor(payload.Color)
	local stripe = Teams.CleanColor(payload.Stripe)
	if not name or not tag or not color or not stripe then
		sendState(player, string.format("Nom de %d à %d caractères, sigle de %d à %d lettres ou chiffres.", Teams.NAME_MIN, Teams.NAME_MAX, Teams.TAG_MIN, Teams.TAG_MAX), true)
		return
	end
	if not filtered(name, player.UserId) or not filtered(tag, player.UserId) then
		sendState(player, "Ce nom ou ce sigle a été refusé par le filtre de Roblox.", true)
		return
	end
	local id = tostring(player.UserId) .. "_" .. tostring(os.time())
	local team, refusal = updateTeam(id, function(existing)
		if existing then
			return existing, "Réessaie dans un instant."
		end
		return {
			Id = id,
			Name = name :: string,
			Tag = tag :: string,
			Color = color :: number,
			Stripe = stripe :: number,
			OwnerId = player.UserId,
			Members = { player.UserId },
		}, nil
	end)
	if refusal or not team then
		sendState(player, refusal or "L'écurie n'a pas pu être créée.", true)
		return
	end
	setProfileTeam(player, id)
	sendState(player, "Écurie " .. team.Name .. " créée : invite tes amis !")
	TeamService.Changed(player)
end

local function invite(player: Player, payload: any)
	local team = TeamService.Get(player)
	local target = if type(payload.UserId) == "number" then Players:GetPlayerByUserId(payload.UserId) else nil
	if not team or not target or target == player then
		return
	end
	if #team.Members >= Teams.MAX_MEMBERS then
		sendState(player, "Ton écurie est complète.", true)
		return
	end
	if TeamService.Get(target) then
		sendState(player, target.DisplayName .. " a déjà une écurie.", true)
		return
	end
	invites[target.UserId] = {
		TeamId = team.Id,
		TeamName = team.Name,
		FromName = player.DisplayName,
		Expires = os.clock() + Teams.INVITE_TIME,
	}
	sendState(target, player.DisplayName .. " t'invite dans l'écurie " .. team.Name .. " (menu, onglet ÉCURIE).")
	sendState(player, "Invitation envoyée à " .. target.DisplayName .. ".")
end

local function accept(player: Player)
	local pending = invites[player.UserId]
	invites[player.UserId] = nil
	if not pending or os.clock() > pending.Expires then
		sendState(player, "Cette invitation a expiré.", true)
		return
	end
	if TeamService.Get(player) then
		sendState(player, "Tu as déjà une écurie : quitte-la d'abord.", true)
		return
	end
	local team, refusal = updateTeam(pending.TeamId, function(existing)
		if not existing then
			return nil, "Cette écurie n'existe plus."
		end
		if table.find(existing.Members, player.UserId) then
			return existing, nil
		end
		if #existing.Members >= Teams.MAX_MEMBERS then
			return existing, "Cette écurie est complète."
		end
		table.insert(existing.Members, player.UserId)
		return existing, nil
	end)
	if refusal or not team then
		sendState(player, refusal or "Impossible de rejoindre l'écurie.", true)
		return
	end
	setProfileTeam(player, team.Id)
	sendState(player, "Bienvenue dans l'écurie " .. team.Name .. " !")
	notifyMembers(team)
end

-- Retire `userId` de l'écurie `teamId` (départ ou exclusion). Le fondateur
-- qui part passe la main ; la dernière qui part ferme l'écurie.
local function removeMember(teamId: string, userId: number): Team?
	local team = updateTeam(teamId, function(existing)
		if not existing then
			return nil, nil
		end
		local index = table.find(existing.Members, userId)
		if index then
			table.remove(existing.Members, index)
		end
		if #existing.Members == 0 then
			return nil, nil -- plus personne : l'écurie disparaît
		end
		if existing.OwnerId == userId then
			existing.OwnerId = existing.Members[1]
		end
		return existing, nil
	end)
	return team
end

local function leave(player: Player)
	local team = TeamService.Get(player)
	if not team then
		return
	end
	local after = removeMember(team.Id, player.UserId)
	setProfileTeam(player, nil)
	sendState(player, "Tu as quitté l'écurie " .. team.Name .. ".")
	TeamService.Changed(player)
	notifyMembers(after)
end

local function kick(player: Player, payload: any)
	local team = TeamService.Get(player)
	local userId = payload.UserId
	if not team or team.OwnerId ~= player.UserId or type(userId) ~= "number" or userId == player.UserId then
		return
	end
	local after = removeMember(team.Id, userId)
	local kicked = Players:GetPlayerByUserId(userId)
	if kicked then
		setProfileTeam(kicked, nil)
		sendState(kicked, "Tu ne fais plus partie de l'écurie " .. team.Name .. ".")
		TeamService.Changed(kicked)
	end
	notifyMembers(after)
end

local function setColors(player: Player, payload: any)
	local team = TeamService.Get(player)
	local color = Teams.CleanColor(payload.Color)
	local stripe = Teams.CleanColor(payload.Stripe)
	if not team or team.OwnerId ~= player.UserId or not color or not stripe then
		return
	end
	local after = updateTeam(team.Id, function(existing)
		if not existing then
			return nil, "Cette écurie n'existe plus."
		end
		existing.Color = color :: number
		existing.Stripe = stripe :: number
		return existing, nil
	end)
	notifyMembers(after)
end

local function useColors(player: Player, payload: any)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	profile.UseTeamColors = payload.On == true
	setProfileTeam(player, profile.TeamId)
	sendState(player)
	TeamService.Changed(player)
end

--------------------------------------------------------------------------------
-- Classement
--------------------------------------------------------------------------------

-- XP gagnée par un pilote (ProgressService) : elle compte pour son écurie.
function TeamService.AddPoints(player: Player, points: number)
	local team = TeamService.Get(player)
	if team and points > 0 then
		pendingPoints[team.Id] = (pendingPoints[team.Id] or 0) + math.floor(points)
	end
end

local function flushPoints()
	local points = pendingPoints
	pendingPoints = {}
	local store = scoreStore()
	for teamId, amount in pairs(points) do
		if store then
			local ok, err = pcall(function()
				store:IncrementAsync(teamId, amount)
			end)
			if not ok then
				Stores.Failed("classement des écuries", err)
			end
		else
			memoryScores[teamId] = (memoryScores[teamId] or 0) + amount
		end
	end
end

local function refreshBoard()
	local scores: { { TeamId: string, Score: number } } = {}
	local store = scoreStore()
	if store then
		local ok, err = pcall(function()
			local pages = store:GetSortedAsync(false, BOARD_SIZE)
			for _, item in ipairs(pages:GetCurrentPage()) do
				table.insert(scores, { TeamId = item.key, Score = item.value })
			end
		end)
		if not ok then
			Stores.Failed("classement des écuries", err)
		end
	else
		for teamId, score in pairs(memoryScores) do
			table.insert(scores, { TeamId = teamId, Score = score })
		end
		table.sort(scores, function(a, b)
			return a.Score > b.Score
		end)
	end
	local entries: { BoardEntry } = {}
	for index, item in ipairs(scores) do
		if index > BOARD_SIZE then
			break
		end
		local team = teams[item.TeamId] or loadTeam(item.TeamId)
		if team then
			table.insert(entries, { TeamId = team.Id, Name = team.Name, Tag = team.Tag, Color = team.Color, Score = item.Score })
		end
	end
	board = entries
	for _, player in ipairs(Players:GetPlayers()) do
		sendState(player)
	end
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function TeamService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		local id = profile.TeamId
		if id then
			-- Retiré de l'écurie pendant son absence, ou écurie fermée : on oublie.
			local team = loadTeam(id)
			if not team or not table.find(team.Members, player.UserId) then
				setProfileTeam(player, nil)
			end
		end
		sendState(player)
		TeamService.Changed(player)
	end)

	local busy: { [Player]: boolean } = {}
	local lastActionAt: { [Player]: number } = {}
	local handlers: { [string]: (Player, any) -> () } = {
		Create = create,
		Invite = invite,
		Accept = function(player: Player, _payload: any)
			accept(player)
		end,
		Decline = function(player: Player, _payload: any)
			invites[player.UserId] = nil
			sendState(player)
		end,
		Leave = function(player: Player, _payload: any)
			leave(player)
		end,
		Kick = kick,
		SetColors = setColors,
		UseColors = useColors,
	}
	Remotes.TeamAction.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		local handler = if type(action) == "string" then handlers[action] else nil
		if not handler or busy[player] or not ProfileStore.Get(player) then
			return
		end
		local now = os.clock()
		if now - (lastActionAt[player] or 0) < ACTION_COOLDOWN then
			return
		end
		lastActionAt[player] = now
		busy[player] = true
		local ok, err = pcall(function()
			handler(player, if type(payload) == "table" then payload else {})
		end)
		busy[player] = nil
		if not ok then
			warn("[TeamService] " .. action .. " :", err)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
		lastActionAt[player] = nil
		invites[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(POINTS_FLUSH)
			flushPoints()
		end
	end)
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(BOARD_REFRESH)
		end
	end)
	-- Les écuries des joueurs présents ont pu changer ailleurs (autre serveur).
	task.spawn(function()
		while true do
			task.wait(TEAM_REFRESH)
			local seen: { [string]: boolean } = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = ProfileStore.Get(player)
				local id = if profile then profile.TeamId else nil
				if id and not seen[id] then
					seen[id] = true
					loadTeam(id)
				end
			end
		end
	end)
	game:BindToClose(flushPoints)
end

return TeamService
