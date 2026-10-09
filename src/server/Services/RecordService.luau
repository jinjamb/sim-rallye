--!strict
--[[
	RecordService.luau
	Les records : meilleur temps de la spéciale (et son classement), meilleurs
	tours des circuits de rallycross (et leurs classements), statistiques de
	carrière.

	Les temps arrivent déjà validés : par StageService pour la spéciale
	(chronométrée par le serveur), par RaceService pour les tours. Ici, on ne
	fait que les garder : profil (ProfileStore) et classements sauvegardés
	(OrderedDataStore, un par tracé), complétés par la session (Boards.luau).

	C'est aussi ce service qui envoie au joueur son profil à l'arrivée
	(ProfileLoaded : records, fantôme, réglages, livrée, statistiques).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local ProgressService = require(script.Parent.ProgressService)

local RecordService = {}

local STAGE_ID = ProfileSchema.STAGE_ID
local LEADERBOARD_STORE_NAME = "RallyBest_" .. STAGE_ID
local LAP_STORE_PREFIX = "RallyLap_"

local LEADERBOARD_SIZE = 10
local LEADERBOARD_REFRESH = 60 -- secondes
local LAP_BOARD_SIZE = 5
local LAP_BOARD_REFRESH = 120

--------------------------------------------------------------------------------
-- Classement de la spéciale
--------------------------------------------------------------------------------

local sessionBest: { [number]: number } = {}
local leaderboard: { Boards.Entry } = {}

local function leaderboardStore(): OrderedDataStore?
	return Stores.Ordered(LEADERBOARD_STORE_NAME)
end

local function refreshLeaderboard()
	leaderboard = Boards.Merge(leaderboardStore(), sessionBest, LEADERBOARD_SIZE, "classement")
	Remotes.Leaderboard:FireAllClients(leaderboard)
end

local scheduleLeaderboardRefresh = Boards.Debounced(2, refreshLeaderboard)

-- Classement de la spéciale tel qu'affiché (top 10).
function RecordService.GetLeaderboard(): { Boards.Entry }
	return leaderboard
end

-- Meilleurs temps de la spéciale connus dans la session (UserId -> ms).
function RecordService.GetSessionBest(): { [number]: number }
	return sessionBest
end

-- Temps de la spéciale du classement sauvegardé, à partir de `belowMs` en
-- descendant (les rivaux juste devant un pilote hors du top 10).
function RecordService.GetTimesBelow(belowMs: number, count: number): { { UserId: number, Ms: number } }
	local list = {}
	local store = leaderboardStore()
	if not store then
		return list
	end
	local ok, err = pcall(function()
		local pages = store:GetSortedAsync(false, count, nil, belowMs)
		for _, item in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(item.key)
			if userId then
				table.insert(list, { UserId = userId, Ms = item.value })
			end
		end
	end)
	if not ok then
		Stores.Failed("rival", err)
	end
	return list
end

-- Record de la spéciale d'un joueur connecté.
function RecordService.GetStageRecord(player: Player): ProfileSchema.StageRecord?
	local profile = ProfileStore.Get(player)
	return if profile then profile.Records[STAGE_ID] else nil
end

export type StageResult = { IsBest: boolean, PreviousMs: number? }

-- Temps validé de la spéciale : record perso et classement.
function RecordService.StageFinish(player: Player, ms: number): StageResult?
	local profile = ProfileStore.Get(player)
	if not profile then
		return nil
	end
	local previous = profile.Records[STAGE_ID]
	local isBest = previous == nil or ms < previous.Ms
	if isBest then
		profile.Records[STAGE_ID] = { Ms = ms, Ghost = nil } -- le fantôme suit (GhostService)
		sessionBest[player.UserId] = ms
		ProfileStore.Update(player.UserId, "record", function(stored)
			local current = stored.Records[STAGE_ID]
			if current and current.Ms <= ms then
				return false -- déjà mieux ailleurs (autre serveur)
			end
			stored.Records[STAGE_ID] = { Ms = ms, Ghost = nil }
			return true
		end)
		Boards.Set(leaderboardStore(), player.UserId, ms, "classement")
		scheduleLeaderboardRefresh()
	end
	return { IsBest = isBest, PreviousMs = if previous then previous.Ms else nil }
end

--------------------------------------------------------------------------------
-- Records du tour (rallycross)
--------------------------------------------------------------------------------

type TrackBoard = { Key: string, Entries: { Boards.Entry } }

local sessionLaps: { [string]: { [number]: number } } = {}
local lapBoards: { [string]: TrackBoard } = {}

local function lapStore(key: string): OrderedDataStore?
	return Stores.Ordered(LAP_STORE_PREFIX .. key)
end

-- Appelée à chaque mise à jour des records du tour (panneaux du paddock).
RecordService.TrackRecordsChanged = function(_boards: any) end

local function refreshLapBoards()
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit then
			local key = circuit.Key
			lapBoards[id] = {
				Key = key,
				Entries = Boards.Merge(lapStore(key), sessionLaps[key] or {}, LAP_BOARD_SIZE, "records du tour"),
			}
		end
	end
	Remotes.TrackRecords:FireAllClients(lapBoards)
	RecordService.TrackRecordsChanged(lapBoards)
end

local scheduleLapRefresh = Boards.Debounced(3, refreshLapBoards)

local function rememberLap(userId: number, trackKey: string, ms: number)
	local session = sessionLaps[trackKey]
	if not session then
		session = {}
		sessionLaps[trackKey] = session
	end
	session[userId] = ms
end

-- Statistiques et records envoyés au menu, puis la progression qui en découle.
local function pushProfile(player: Player)
	local profile = ProfileStore.Get(player)
	if profile and player.Parent then
		Remotes.ProfileUpdated:FireClient(player, profile.Stats, profile.Laps)
		ProgressService.Push(player, true)
	end
end

-- Tour bouclé en course. Renvoie true si c'est le meilleur tour du joueur sur ce circuit.
function RecordService.SubmitLap(player: Player, trackKey: string, ms: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or ms <= 0 then
		return false
	end
	local previous = profile.Laps[trackKey]
	if previous and previous <= ms then
		return false
	end
	profile.Laps[trackKey] = ms
	rememberLap(player.UserId, trackKey, ms)
	ProfileStore.Update(player.UserId, "record du tour", function(stored)
		local current = stored.Laps[trackKey]
		if current and current <= ms then
			return false
		end
		stored.Laps[trackKey] = ms
		return true
	end)
	Boards.SubmitLowest(lapStore(trackKey), player.UserId, ms, "records du tour")
	scheduleLapRefresh()
	pushProfile(player)
	return true
end

function RecordService.GetLapBest(player: Player, trackKey: string): number?
	local profile = ProfileStore.Get(player)
	return if profile then profile.Laps[trackKey] else nil
end

--------------------------------------------------------------------------------
-- Carrière
--------------------------------------------------------------------------------

-- Fin de course (dernière manche) : statistiques de carrière.
function RecordService.AddRaceResult(player: Player, position: number, points: number)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local function apply(stats: ProfileSchema.Stats)
		stats.Races += 1
		stats.Points += points
		if position == 1 then
			stats.Wins += 1
		end
		if position >= 1 and position <= 3 then
			stats.Podiums += 1
		end
	end
	apply(profile.Stats)
	ProfileStore.Update(player.UserId, "statistiques", function(stored)
		apply(stored.Stats)
		return true
	end)
	pushProfile(player)
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function RecordService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		Boards.RememberName(player)
		local record = profile.Records[STAGE_ID]
		if record then
			sessionBest[player.UserId] = record.Ms
		end
		for key, ms in pairs(profile.Laps) do
			rememberLap(player.UserId, key, ms)
		end
		Remotes.ProfileLoaded:FireClient(player, {
			StageId = STAGE_ID,
			BestMs = if record then record.Ms else nil,
			Ghost = if record then record.Ghost else nil,
			Setup = profile.Setup,
			Livery = profile.Livery,
			Stats = profile.Stats,
			Laps = profile.Laps,
		})
		Remotes.Leaderboard:FireClient(player, leaderboard)
		Remotes.TrackRecords:FireClient(player, lapBoards)
	end)

	task.spawn(function()
		while true do
			refreshLeaderboard()
			task.wait(LEADERBOARD_REFRESH)
		end
	end)
	task.spawn(function()
		while true do
			refreshLapBoards()
			task.wait(LAP_BOARD_REFRESH)
		end
	end)
end

return RecordService
