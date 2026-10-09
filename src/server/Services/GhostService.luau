--!strict
--[[
	GhostService.luau
	Les fantômes de la spéciale : la trajectoire d'un passage (10 images par
	seconde), rejouée en transparence pour courir contre.

	SON FANTÔME : après un record perso (StageService -> Expect), le client
	envoie la trajectoire qu'il a enregistrée. Elle n'est acceptée que dans
	les GHOST_WINDOW s qui suivent, et si sa durée correspond au temps validé
	par le serveur.

	DÉFI DU FANTÔME : un joueur peut demander le fantôme d'un autre pilote pour
	courir contre lui -- le rival juste devant lui au classement, le recordman,
	ou un pilote choisi dans le classement. Le fantôme est lu dans le profil de
	ce pilote (en mémoire s'il est connecté, sinon dans le DataStore, puis gardé
	quelques minutes en cache).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Boards = require(script.Parent.Parent.Data.Boards)
local RecordService = require(script.Parent.RecordService)

local GhostService = {}

local STAGE_ID = ProfileSchema.STAGE_ID
local GHOST_WINDOW = 60 -- secondes pour envoyer le fantôme après un record
local GHOST_REQUEST_COOLDOWN = 2 -- secondes entre deux demandes de fantôme d'un autre pilote
local RIVAL_CANDIDATES = 5 -- temps juste devant le sien examinés dans le classement sauvegardé
local OPPONENT_LOADS = 3 -- profils lus au plus pour trouver un fantôme
local OPPONENT_CACHE_TIME = 120 -- secondes : fantôme d'un pilote absent, gardé en mémoire

type StageRecord = ProfileSchema.StageRecord

local pendingGhost: { [Player]: { Ms: number, Expires: number } } = {}

-- Record perso validé : son fantôme est attendu.
function GhostService.Expect(player: Player, ms: number)
	pendingGhost[player] = { Ms = ms, Expires = os.clock() + GHOST_WINDOW }
end

local function onSubmitGhost(player: Player, input: any)
	local pending = pendingGhost[player]
	local profile = ProfileStore.Get(player)
	if not pending or not profile or os.clock() > pending.Expires then
		return
	end
	local ghost = ProfileSchema.SanitizeGhost(input)
	if not ghost then
		return
	end
	-- La durée du fantôme doit correspondre au temps validé par le serveur.
	local frameCount = #ghost.Frames / ProfileSchema.GHOST_VALUES_PER_FRAME
	local duration = (frameCount - 1) / ghost.Rate
	if math.abs(duration - pending.Ms / 1000) > 2 then
		return
	end
	pendingGhost[player] = nil

	local record = profile.Records[STAGE_ID]
	if record and record.Ms == pending.Ms then
		record.Ghost = ghost
	end
	local ms = pending.Ms
	ProfileStore.Update(player.UserId, "fantôme", function(stored)
		local current = stored.Records[STAGE_ID]
		if not current or current.Ms ~= ms then
			return false -- un meilleur temps est arrivé entre-temps
		end
		current.Ghost = ghost
		return true
	end)
end

--------------------------------------------------------------------------------
-- Défi du fantôme : courir contre la trajectoire d'un autre pilote
--------------------------------------------------------------------------------

local opponentCache: { [number]: { Record: StageRecord?, Expires: number } } = {}

-- Record de la spéciale (temps et fantôme) d'un pilote, connecté ou non.
local function stageRecordOf(userId: number): StageRecord?
	local online = Players:GetPlayerByUserId(userId)
	if online and ProfileStore.Get(online) then
		return RecordService.GetStageRecord(online)
	end
	local cached = opponentCache[userId]
	if cached and os.clock() < cached.Expires then
		return cached.Record
	end
	local stored = ProfileStore.Read(userId, "fantôme d'un autre pilote")
	if not stored then
		return nil
	end
	local record = stored.Records[STAGE_ID]
	local now = os.clock()
	for id, entry in pairs(opponentCache) do
		if now >= entry.Expires then
			opponentCache[id] = nil -- un fantôme pèse ~7000 nombres : on ne garde que les récents
		end
	end
	opponentCache[userId] = { Record = record, Expires = now + OPPONENT_CACHE_TIME }
	return record
end

--[[
	Pilotes à affronter, du plus indiqué au moins indiqué :
		Rival  : les temps juste devant le sien, du plus proche au plus lointain
		         (sans temps : le dernier du top 10, puis on remonte) ;
		Record : les meilleurs temps, dans l'ordre.
	Le classement sauvegardé ne contient que le top 10 : pour un joueur plus
	loin, on demande au DataStore les temps juste en dessous du sien.
]]
type Candidate = { UserId: number, Ms: number }

local function opponentCandidates(player: Player, mode: string): { Candidate }
	local mine = RecordService.GetStageRecord(player)
	local times: { [number]: number } = {}
	local function consider(userId: number, ms: number)
		local known = times[userId]
		times[userId] = if known then math.min(known, ms) else ms
	end
	for _, entry in ipairs(RecordService.GetLeaderboard()) do
		consider(entry.UserId, entry.Ms)
	end
	for userId, ms in pairs(RecordService.GetSessionBest()) do
		consider(userId, ms)
	end
	if mode == "Rival" and mine then
		for _, item in ipairs(RecordService.GetTimesBelow(mine.Ms - 1, RIVAL_CANDIDATES)) do
			consider(item.UserId, item.Ms)
		end
	end

	local list: { Candidate } = {}
	for userId, ms in pairs(times) do
		if userId ~= player.UserId and (mode ~= "Rival" or mine == nil or ms < mine.Ms) then
			table.insert(list, { UserId = userId, Ms = ms })
		end
	end
	table.sort(list, function(a, b)
		if mode == "Rival" then
			return a.Ms > b.Ms -- le plus proche de soi d'abord
		end
		return a.Ms < b.Ms
	end)
	return list
end

local function sendOpponent(player: Player, mode: string, userId: number?)
	local function fail(message: string)
		Remotes.GhostOpponent:FireClient(player, { Mode = mode, Error = message })
	end
	local mine = RecordService.GetStageRecord(player)

	local candidates: { number } = {}
	if mode == "Player" then
		if userId == nil or userId == player.UserId then
			fail("C'est ton propre temps.")
			return
		end
		candidates = { userId :: number }
	else
		local list = opponentCandidates(player, mode)
		local first = list[1]
		if mode == "Record" and mine and (first == nil or mine.Ms <= first.Ms) then
			fail("Le record, c'est toi !")
			return
		elseif first == nil then
			fail(if mode == "Rival" and mine then "Personne devant toi : tu es en tête !" else "Aucun autre pilote n'a encore de temps.")
			return
		end
		for _, item in ipairs(list) do
			table.insert(candidates, item.UserId)
		end
	end

	-- Le premier candidat peut ne pas avoir de fantôme (temps antérieur aux
	-- fantômes, envoi perdu) : on passe au suivant, dans la limite des lectures.
	for index, candidate in ipairs(candidates) do
		if index > OPPONENT_LOADS then
			break
		end
		local record = stageRecordOf(candidate)
		if record and record.Ghost then
			if not player.Parent then
				return
			end
			Remotes.GhostOpponent:FireClient(player, {
				Mode = mode,
				UserId = candidate,
				Name = Boards.NameOf(candidate),
				Ms = record.Ms,
				Ghost = record.Ghost,
			})
			return
		end
	end

	fail(if mode == "Player" then "Pas de fantôme enregistré pour ce pilote." else "Pas de fantôme enregistré pour les pilotes devant toi.")
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function GhostService.Start()
	Remotes.SubmitGhost.OnServerEvent:Connect(onSubmitGhost)

	local ghostBusy: { [Player]: boolean } = {}
	local lastRequestAt: { [Player]: number } = {}
	Remotes.RequestGhost.OnServerEvent:Connect(function(player: Player, mode: any, target: any)
		if mode ~= "Rival" and mode ~= "Record" and mode ~= "Player" then
			return
		end
		local userId: number? = nil
		if mode == "Player" then
			if type(target) ~= "number" or target ~= target or target <= 0 or target % 1 ~= 0 then
				return
			end
			userId = target
		end
		local now = os.clock()
		if ghostBusy[player] or now - (lastRequestAt[player] or 0) < GHOST_REQUEST_COOLDOWN then
			Remotes.GhostOpponent:FireClient(player, { Mode = mode, Error = "Patiente un instant." })
			return
		end
		lastRequestAt[player] = now
		ghostBusy[player] = true
		local ok, err = pcall(function()
			sendOpponent(player, mode, userId)
		end)
		ghostBusy[player] = nil
		if not ok then
			warn("[GhostService] Fantôme d'un autre pilote :", err)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingGhost[player] = nil
		ghostBusy[player] = nil
		lastRequestAt[player] = nil
	end)
end

return GhostService
