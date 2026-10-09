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

	PAR CATÉGORIE DE VOITURE (CarClasses.luau) : chaque catégorie a ses
	records et ses classements -- une Rally4 ne se mesure pas à un Groupe B.
	La Rally2 garde les clés d'avant les catégories.

	C'est aussi ce service qui envoie au joueur son profil à l'arrivée
	(ProfileLoaded : records et fantômes par catégorie, réglages, livrée,
	statistiques).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local ProgressService = require(script.Parent.ProgressService)

local RecordService = {}

local LEADERBOARD_STORE_PREFIX = "RallyBest_"
local LAP_STORE_PREFIX = "RallyLap_"

--[[
	Lectures des classements sauvegardés : Roblox en permet ~5 + 2 x joueurs
	par minute (GetSortedAsync). Avec une catégorie de plus, on ne relit plus
	tout d'un coup : une catégorie à chaque fois, à tour de rôle (une relecture
	complète toutes les 90 s pour la spéciale, 6 min pour les circuits), plus
	la catégorie où un record vient de tomber.
]]
local LEADERBOARD_SIZE = 10
local LEADERBOARD_ROTATE = 30 -- secondes entre deux catégories relues
local LAP_BOARD_SIZE = 5
local LAP_BOARD_ROTATE = 120

-- Session : UserId -> meilleur temps, par clé de classement.
type Session = { [string]: { [number]: number } }

local function sessionOf(session: Session, key: string): { [number]: number }
	local entries = session[key]
	if not entries then
		entries = {}
		session[key] = entries
	end
	return entries
end

--------------------------------------------------------------------------------
-- Classement de la spéciale (un par catégorie)
--------------------------------------------------------------------------------

local sessionBest: Session = {} -- par catégorie
local leaderboards: { [string]: { Boards.Entry } } = {} -- par catégorie

local function leaderboardStore(classId: string): OrderedDataStore?
	return Stores.Ordered(LEADERBOARD_STORE_PREFIX .. ProfileSchema.StageKey(classId))
end

local function refreshLeaderboard(classId: string)
	leaderboards[classId] = Boards.Merge(leaderboardStore(classId), sessionOf(sessionBest, classId), LEADERBOARD_SIZE, "classement")
	Remotes.Leaderboard:FireAllClients(leaderboards)
end

-- Catégories où un record vient de tomber : relues ensemble, un peu après.
local dirtyStage: { [string]: boolean } = {}
local refreshDirtyStage = Boards.Debounced(2, function()
	local classes = dirtyStage
	dirtyStage = {}
	for classId in pairs(classes) do
		refreshLeaderboard(classId)
	end
end)

-- Classement de la spéciale tel qu'affiché (top 10), dans une catégorie.
function RecordService.GetLeaderboard(classId: string): { Boards.Entry }
	return leaderboards[classId] or {}
end

-- Meilleurs temps de la spéciale connus dans la session (UserId -> ms).
function RecordService.GetSessionBest(classId: string): { [number]: number }
	return sessionOf(sessionBest, classId)
end

-- Temps de la spéciale du classement sauvegardé, à partir de `belowMs` en
-- descendant (les rivaux juste devant un pilote hors du top 10).
function RecordService.GetTimesBelow(classId: string, belowMs: number, count: number): { { UserId: number, Ms: number } }
	local list = {}
	local store = leaderboardStore(classId)
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

-- Record de la spéciale d'un joueur connecté, dans une catégorie.
function RecordService.GetStageRecord(player: Player, classId: string): ProfileSchema.StageRecord?
	local profile = ProfileStore.Get(player)
	return if profile then profile.Records[ProfileSchema.StageKey(classId)] else nil
end

export type StageResult = { IsBest: boolean, PreviousMs: number? }

-- Temps validé de la spéciale : record perso et classement de la catégorie.
function RecordService.StageFinish(player: Player, ms: number, classId: string): StageResult?
	local profile = ProfileStore.Get(player)
	if not profile then
		return nil
	end
	local key = ProfileSchema.StageKey(classId)
	local previous = profile.Records[key]
	local isBest = previous == nil or ms < previous.Ms
	if isBest then
		profile.Records[key] = { Ms = ms, Ghost = nil } -- le fantôme suit (GhostService)
		sessionOf(sessionBest, classId)[player.UserId] = ms
		ProfileStore.Update(player.UserId, "record", function(stored)
			local current = stored.Records[key]
			if current and current.Ms <= ms then
				return false -- déjà mieux ailleurs (autre serveur)
			end
			stored.Records[key] = { Ms = ms, Ghost = nil }
			return true
		end)
		Boards.Set(leaderboardStore(classId), player.UserId, ms, "classement")
		dirtyStage[classId] = true
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

-- Relit les records du tour d'une catégorie, sur tous les circuits.
local function refreshLapBoards(classId: string)
	local boards: { [string]: TrackBoard } = {}
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit then
			local key = ProfileSchema.LapKey(circuit.Key, classId)
			boards[id] = {
				Key = key,
				Entries = Boards.Merge(lapStore(key), sessionOf(sessionLaps, key), LAP_BOARD_SIZE, "records du tour"),
			}
		end
	end
	lapBoards[classId] = boards
	Remotes.TrackRecords:FireAllClients(lapBoards)
	RecordService.TrackRecordsChanged(lapBoards)
end

local dirtyLaps: { [string]: boolean } = {}
local refreshDirtyLaps = Boards.Debounced(3, function()
	local classes = dirtyLaps
	dirtyLaps = {}
	for classId in pairs(classes) do
		refreshLapBoards(classId)
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
	dirtyLaps[classId] = true
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
		local stage = {}
		for _, class in ipairs(CarClasses.LIST) do
			local record = profile.Records[ProfileSchema.StageKey(class.Id)]
			if record then
				sessionOf(sessionBest, class.Id)[player.UserId] = record.Ms
				stage[class.Id] = { Ms = record.Ms, Ghost = record.Ghost }
			end
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
		})
		Remotes.Leaderboard:FireClient(player, leaderboards)
		Remotes.TrackRecords:FireClient(player, lapBoards)
	end)

	-- Une catégorie à la fois, à tour de rôle ; le premier tour plus vite
	-- (classements vides au démarrage), sans tout lire d'un coup.
	local function rotate(refresh: (string) -> (), firstWait: number, interval: number)
		task.spawn(function()
			local index = 0
			local firstPass = #CarClasses.LIST
			while true do
				index = index % #CarClasses.LIST + 1
				refresh(CarClasses.LIST[index].Id)
				firstPass -= 1
				task.wait(if firstPass > 0 then firstWait else interval)
			end
		end)
	end
	rotate(refreshLeaderboard, 5, LEADERBOARD_ROTATE)
	rotate(refreshLapBoards, 20, LAP_BOARD_ROTATE)
end

return RecordService
