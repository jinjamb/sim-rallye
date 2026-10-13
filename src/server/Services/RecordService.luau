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

	PAR SPÉCIALE ET PAR CATÉGORIE DE VOITURE (Stages.luau, CarClasses.luau) :
	chaque spéciale a ses records et ses classements dans chaque catégorie --
	une Rally4 ne se mesure pas à un Groupe B. La forêt en Rally2 garde les
	clés d'avant les catégories et les spéciales.

	Un temps qui prend la tête d'un classement s'annonce à tout le serveur
	(AnnounceService), une fois ce classement lu au moins une fois.

	C'est aussi ce service qui envoie au joueur son profil à l'arrivée
	(ProfileLoaded : records et fantômes par spéciale et par catégorie,
	réglages, livrée, statistiques).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ProgressService = require(script.Parent.ProgressService)
local AnnounceService = require(script.Parent.AnnounceService)

local RecordService = {}

local LEADERBOARD_STORE_PREFIX = "RallyBest_"
local LAP_STORE_PREFIX = "RallyLap_"

--[[
	Lectures des classements sauvegardés : Roblox en permet ~5 + 2 x joueurs
	par minute (GetSortedAsync). Avec 10 spéciales, 10 circuits et 3
	catégories (60 classements), on ne relit qu'un classement à la fois, à
	tour de rôle : ~2 lectures par minute pour les spéciales, ~2 pour les
	circuits (un tour complet toutes les 15 min chacun ; 8 min au démarrage),
	plus le classement où un record vient de tomber, aussitôt. Entre deux
	lectures, les temps de la session complètent l'affichage (Boards.luau).
]]
local LEADERBOARD_SIZE = 10
local LEADERBOARD_ROTATE = 30 -- secondes entre deux classements de spéciale relus
local STAGE_FIRST_WAIT = 16 -- premier tour, au démarrage du serveur
local LAP_BOARD_SIZE = 5
local LAP_BOARD_ROTATE = 30 -- secondes entre deux classements de circuit relus
local LAP_FIRST_WAIT = 16

-- Session : UserId -> meilleur temps, par clé de classement.
type Session = { [string]: { [number]: number } }

-- Ce temps prend-il la tête de ce classement ? Pas tant qu'il n'a pas été
-- lu (au démarrage du serveur, il est vide).
local function beatsFirst(entries: { Boards.Entry }?, ms: number): boolean
	if not entries then
		return false
	end
	local first = entries[1]
	return first == nil or ms < first.Ms
end

local function sessionOf(session: Session, key: string): { [number]: number }
	local entries = session[key]
	if not entries then
		entries = {}
		session[key] = entries
	end
	return entries
end

--------------------------------------------------------------------------------
-- Classements des spéciales (un par spéciale et par catégorie)
--------------------------------------------------------------------------------

local ERASE_PACE = 0.8 -- secondes entre deux retraits d'un classement (modération)
local sessionBest: Session = {} -- par Stages.BoardKey
-- Par spéciale, puis par catégorie (ce que reçoit le client).
local leaderboards: { [string]: { [string]: { Boards.Entry } } } = {}

local function leaderboardStore(classId: string, stageId: string): OrderedDataStore?
	return Stores.Ordered(LEADERBOARD_STORE_PREFIX .. ProfileSchema.StageKey(classId, stageId))
end

local function boardsOf(stageId: string): { [string]: { Boards.Entry } }
	local boards = leaderboards[stageId]
	if not boards then
		boards = {}
		leaderboards[stageId] = boards
	end
	return boards
end

local function refreshLeaderboard(classId: string, stageId: string)
	local session = sessionOf(sessionBest, Stages.BoardKey(stageId, classId))
	boardsOf(stageId)[classId] = Boards.Merge(leaderboardStore(classId, stageId), session, LEADERBOARD_SIZE, "classement")
	Remotes.Leaderboard:FireAllClients(leaderboards)
end

-- Classements où un record vient de tomber : relus ensemble, un peu après.
local dirtyStage: { [string]: { Stage: string, Class: string } } = {}
local refreshDirtyStage = Boards.Debounced(2, function()
	local boards = dirtyStage
	dirtyStage = {}
	for _, board in pairs(boards) do
		refreshLeaderboard(board.Class, board.Stage)
	end
end)

-- Classement d'une spéciale tel qu'affiché (top 10), dans une catégorie.
function RecordService.GetLeaderboard(classId: string, stageId: string): { Boards.Entry }
	return boardsOf(stageId)[classId] or {}
end

-- Meilleurs temps d'une spéciale connus dans la session (UserId -> ms).
function RecordService.GetSessionBest(classId: string, stageId: string): { [number]: number }
	return sessionOf(sessionBest, Stages.BoardKey(stageId, classId))
end

-- Temps de la spéciale du classement sauvegardé, à partir de `belowMs` en
-- descendant (les rivaux juste devant un pilote hors du top 10).
function RecordService.GetTimesBelow(classId: string, belowMs: number, count: number, stageId: string): { { UserId: number, Ms: number } }
	local list = {}
	local store = leaderboardStore(classId, stageId)
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

-- Record d'une spéciale d'un joueur connecté, dans une catégorie.
function RecordService.GetStageRecord(player: Player, classId: string, stageId: string): ProfileSchema.StageRecord?
	local profile = ProfileStore.Get(player)
	return if profile then profile.Records[ProfileSchema.StageKey(classId, stageId)] else nil
end

export type StageResult = { IsBest: boolean, PreviousMs: number? }

-- Temps validé d'une spéciale : record perso et classement de la catégorie.
function RecordService.StageFinish(player: Player, ms: number, classId: string, stageId: string): StageResult?
	local profile = ProfileStore.Get(player)
	if not profile then
		return nil
	end
	local key = ProfileSchema.StageKey(classId, stageId)
	local previous = profile.Records[key]
	local isBest = previous == nil or ms < previous.Ms
	if isBest then
		if beatsFirst(boardsOf(stageId)[classId], ms) then
			AnnounceService.Send("Record", player.DisplayName, string.format(
				"bat le record de la spéciale %s en %s : %s",
				Stages.Get(stageId).Name,
				CarClasses.Get(classId).Name,
				Format.Ms(ms)
			))
		end
		profile.Records[key] = { Ms = ms, Ghost = nil } -- le fantôme suit (GhostService)
		sessionOf(sessionBest, Stages.BoardKey(stageId, classId))[player.UserId] = ms
		ProfileStore.Update(player.UserId, "record", function(stored)
			local current = stored.Records[key]
			if current and current.Ms <= ms then
				return false -- déjà mieux ailleurs (autre serveur)
			end
			stored.Records[key] = { Ms = ms, Ghost = nil }
			return true
		end)
		Boards.Set(leaderboardStore(classId, stageId), player.UserId, ms, "classement")
		dirtyStage[Stages.BoardKey(stageId, classId)] = { Stage = stageId, Class = classId }
		refreshDirtyStage()
	end
	return { IsBest = isBest, PreviousMs = if previous then previous.Ms else nil }
end

--------------------------------------------------------------------------------
-- Records du tour (rallycross), par circuit et par catégorie
--------------------------------------------------------------------------------

type TrackBoard = { Key: string, Entries: { Boards.Entry } }

local sessionLaps: Session = {} -- par clé de tour (LapKey)
-- Par catégorie, puis par circuit.
local lapBoards: { [string]: { [string]: TrackBoard } } = {}

local function lapStore(lapKey: string): OrderedDataStore?
	return Stores.Ordered(LAP_STORE_PREFIX .. lapKey)
end

-- Appelée à chaque mise à jour des records du tour (panneaux du paddock).
RecordService.TrackRecordsChanged = function(_boards: any) end

-- Relit les records du tour d'un circuit, dans une catégorie (une lecture).
local function refreshLapBoard(classId: string, trackId: string)
	local circuit = Tracks.Get(trackId)
	if not circuit then
		return
	end
	local boards = lapBoards[classId]
	if not boards then
		boards = {}
		lapBoards[classId] = boards
	end
	local key = ProfileSchema.LapKey(circuit.Key, classId)
	boards[trackId] = {
		Key = key,
		Entries = Boards.Merge(lapStore(key), sessionOf(sessionLaps, key), LAP_BOARD_SIZE, "records du tour"),
	}
	Remotes.TrackRecords:FireAllClients(lapBoards)
	RecordService.TrackRecordsChanged(lapBoards)
end

-- Circuits où un record vient de tomber, par catégorie : relus un peu après.
local dirtyLaps: { [string]: { Class: string, Track: string } } = {}
local refreshDirtyLaps = Boards.Debounced(3, function()
	local pending = dirtyLaps
	dirtyLaps = {}
	for _, board in pairs(pending) do
		refreshLapBoard(board.Class, board.Track)
	end
end)

-- Statistiques et records envoyés au menu, puis la progression qui en découle.
local function pushProfile(player: Player)
	local profile = ProfileStore.Get(player)
	if profile and player.Parent then
		Remotes.ProfileUpdated:FireClient(player, profile.Stats, profile.Laps)
		ProgressService.Push(player, true)
	end
end

--[[
	Modération (ModerationService : /effacer, /bannir) : retire un pilote de
	tous les classements de spéciales et de tours, toutes catégories. Les
	écritures sont espacées (budget des DataStores) : à lancer en tâche de
	fond, ça prend une à deux minutes.
]]
function RecordService.EraseFor(userId: number)
	for _, stageId in ipairs(Stages.List()) do
		for _, class in ipairs(CarClasses.LIST) do
			local session = sessionBest[Stages.BoardKey(stageId, class.Id)]
			if session then
				session[userId] = nil
			end
			Boards.Remove(leaderboardStore(class.Id, stageId), userId, "modération")
			task.wait(ERASE_PACE)
		end
	end
	for _, trackId in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(trackId)
		if circuit then
			for _, class in ipairs(CarClasses.LIST) do
				local key = ProfileSchema.LapKey(circuit.Key, class.Id)
				local session = sessionLaps[key]
				if session then
					session[userId] = nil
				end
				Boards.Remove(lapStore(key), userId, "modération")
				task.wait(ERASE_PACE)
			end
		end
	end
end

-- Records personnels remis à zéro (temps, tours, fantômes) : on repart de rien.
function RecordService.ResetProfile(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	profile.Records = {}
	profile.Laps = {}
	pushProfile(player)
end

-- Tour bouclé en course. Renvoie true si c'est le meilleur tour du joueur
-- sur ce circuit, dans cette catégorie.
function RecordService.SubmitLap(player: Player, trackKey: string, classId: string, ms: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or ms <= 0 then
		return false
	end
	local key = ProfileSchema.LapKey(trackKey, classId)
	local previous = profile.Laps[key]
	if previous and previous <= ms then
		return false
	end
	for id, board in pairs(lapBoards[classId] or {}) do
		local circuit = Tracks.Get(id)
		if board.Key == key and circuit and beatsFirst(board.Entries, ms) then
			AnnounceService.Send("Record", player.DisplayName, string.format(
				"bat le record du tour de %s en %s : %s",
				circuit.Name,
				CarClasses.Get(classId).Name,
				Format.Ms(ms)
			))
		end
	end
	profile.Laps[key] = ms
	sessionOf(sessionLaps, key)[player.UserId] = ms
	ProfileStore.Update(player.UserId, "record du tour", function(stored)
		local current = stored.Laps[key]
		if current and current <= ms then
			return false
		end
		stored.Laps[key] = ms
		return true
	end)
	Boards.SubmitLowest(lapStore(key), player.UserId, ms, "records du tour")
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit and circuit.Key == trackKey then
			dirtyLaps[classId .. "|" .. id] = { Class = classId, Track = id }
		end
	end
	refreshDirtyLaps()
	pushProfile(player)
	return true
end

function RecordService.GetLapBest(player: Player, trackKey: string, classId: string): number?
	local profile = ProfileStore.Get(player)
	return if profile then profile.Laps[ProfileSchema.LapKey(trackKey, classId)] else nil
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
		-- Records par spéciale, puis par catégorie.
		local stage = {}
		for _, stageId in ipairs(Stages.List()) do
			local records = {}
			for _, class in ipairs(CarClasses.LIST) do
				local record = profile.Records[ProfileSchema.StageKey(class.Id, stageId)]
				if record then
					sessionOf(sessionBest, Stages.BoardKey(stageId, class.Id))[player.UserId] = record.Ms
					records[class.Id] = { Ms = record.Ms, Ghost = record.Ghost }
				end
			end
			stage[stageId] = records
		end
		for key, ms in pairs(profile.Laps) do
			sessionOf(sessionLaps, key)[player.UserId] = ms
		end
		Remotes.ProfileLoaded:FireClient(player, {
			Stage = stage,
			Setups = profile.Setups,
			Livery = profile.Livery,
			Stats = profile.Stats,
			Laps = profile.Laps,
			Options = profile.Options,
		})
		Remotes.Leaderboard:FireClient(player, leaderboards)
		Remotes.TrackRecords:FireClient(player, lapBoards)
	end)

	--[[
		Relecture à tour de rôle : un classement à chaque fois (un tracé dans
		une catégorie), le premier tour plus vite (classements vides au
		démarrage) sans tout lire d'un coup. Les records tout juste battus
		sont relus à part (dirtyStage, dirtyLaps).
	]]
	local function rotate(boards: { any }, refresh: (any) -> (), firstWait: number, interval: number)
		task.spawn(function()
			local index = 0
			local firstPass = #boards
			while true do
				index = index % #boards + 1
				refresh(boards[index])
				firstPass -= 1
				task.wait(if firstPass > 0 then firstWait else interval)
			end
		end)
	end
	local stageBoards, lapBoardList = {}, {}
	for _, class in ipairs(CarClasses.LIST) do
		for _, stageId in ipairs(Stages.List()) do
			table.insert(stageBoards, { Stage = stageId, Class = class.Id })
		end
		for _, trackId in ipairs(Tracks.List()) do
			table.insert(lapBoardList, { Track = trackId, Class = class.Id })
		end
	end
	rotate(stageBoards, function(board)
		refreshLeaderboard(board.Class, board.Stage)
	end, STAGE_FIRST_WAIT, LEADERBOARD_ROTATE)
	rotate(lapBoardList, function(board)
		refreshLapBoard(board.Class, board.Track)
	end, LAP_FIRST_WAIT, LAP_BOARD_ROTATE)
end

return RecordService
