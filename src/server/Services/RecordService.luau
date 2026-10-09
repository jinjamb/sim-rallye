--!strict
--[[
	RecordService.luau
	Profils sauvegardés : temps officiels de la spéciale, fantômes, réglages,
	records du tour des circuits de rallycross et statistiques de course.

	CHRONO OFFICIEL DE LA SPÉCIALE, MESURÉ PAR LE SERVEUR : on ne croit jamais un
	temps envoyé par un client (n'importe qui peut envoyer "0:12.00"). Le serveur
	suit lui-même chaque voiture le long du tracé, 10 fois par seconde
	(StageTrack.Locate, le même calcul que le chrono du client), et détecte
	départ, arrivée et raccourcis. Le passage des lignes est interpolé entre deux
	mesures : la précision est de l'ordre du centième, et le délai réseau,
	identique au départ et à l'arrivée, s'annule.
	Limite honnête : la physique tourne chez le client (il possède sa voiture).
	Un tricheur déterminé peut donc rouler "trop vite" ; le serveur rejette tout
	ce qui dépasse une vitesse plausible, tout bond le long du tracé (raccourci,
	téléportation) et tout temps trop court pour la distance.
	Les voitures engagées dans une course de rallycross (attribut RaceId) ne sont
	pas chronométrées ici : RaceService s'en charge.

	SAUVEGARDE (DataStore) : un profil par joueur -- meilleur temps et fantôme par
	spéciale, réglages, meilleurs tours par circuit, statistiques -- plus un
	classement par spéciale et par circuit (OrderedDataStore).
	Écritures rares par construction : un record perso, un fantôme, une fin de
	course, des réglages regroupés toutes les 30 s et au départ du joueur. Bien
	en deçà des limites de Roblox (~60 + 10 x joueurs écritures par minute).
	Dans Studio, les DataStores exigent "Activer l'accès Studio aux services
	d'API" (Paramètres du jeu > Sécurité). Sans ça, tout fonctionne quand même,
	en mémoire, pour la session.

	IDENTITÉ D'UN TRACÉ : dérivée de sa longueur. Si le tracé change, les temps
	repartent de zéro au lieu de mélanger deux parcours différents.

	DÉFI DU FANTÔME : un joueur peut demander le fantôme d'un autre pilote pour
	courir contre lui -- le rival juste devant lui au classement, le recordman,
	ou un pilote choisi dans le classement. Le fantôme est lu dans le profil de
	ce pilote (en mémoire s'il est connecté, sinon dans le DataStore, puis gardé
	quelques minutes en cache).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)
local Livery = require(ReplicatedStorage.Shared.Constants.Livery)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Medals = require(ReplicatedStorage.Shared.Constants.Medals)

local RecordService = {}

local STAGE_ID = "s1_" .. tostring(math.floor(StageTrack.GetLength()))
local PROFILE_STORE_NAME = "RallyProfiles_v1"
local LEADERBOARD_STORE_NAME = "RallyBest_" .. STAGE_ID
local LAP_STORE_PREFIX = "RallyLap_"

local SAMPLE_INTERVAL = 0.1 -- secondes entre deux mesures de position
local MAX_PLAUSIBLE_SPEED = 250 -- studs/s (~250 km/h) : au-delà, ce n'est pas de la conduite
local JUMP_MARGIN = 25 -- studs de tolérance (à-coup réseau, remise en piste)
local RESTART_BACKWARD = 150 -- recul le long du tracé qui signifie "retour au départ"
local START_LATERAL_TOLERANCE = StageTrack.ROAD_WIDTH / 2 + 8

local LEADERBOARD_SIZE = 10
local LEADERBOARD_REFRESH = 60 -- secondes
local LAP_BOARD_SIZE = 5
local LAP_BOARD_REFRESH = 120
local SETUP_FLUSH_INTERVAL = 30
local GHOST_WINDOW = 60 -- secondes pour envoyer le fantôme après un record
local GHOST_MAX_FRAMES = 3000 -- 5 min à 10 Hz
local GHOST_VALUES_PER_FRAME = 6 -- x, y, z, rx, ry, rz
local GHOST_REQUEST_COOLDOWN = 2 -- secondes entre deux demandes de fantôme d'un autre pilote
local RIVAL_CANDIDATES = 5 -- temps juste devant le sien examinés dans le classement sauvegardé
local OPPONENT_LOADS = 3 -- profils lus au plus pour trouver un fantôme
local OPPONENT_CACHE_TIME = 120 -- secondes : fantôme d'un pilote absent, gardé en mémoire

type Ghost = { Rate: number, Frames: { number } }
type StageRecord = { Ms: number, Ghost: Ghost? }
export type Stats = { Races: number, Wins: number, Podiums: number, Points: number }
type Profile = {
	Records: { [string]: StageRecord },
	Setup: CarSetup.Setup,
	Livery: Livery.Livery,
	Laps: { [string]: number }, -- meilleur tour (ms) par circuit (Circuit.Key)
	Stats: Stats,
}

type Run = {
	Running: boolean,
	StartTime: number,
	LastProgress: number?,
	LastTime: number,
}

--------------------------------------------------------------------------------
-- DataStores (avec repli en mémoire)
--------------------------------------------------------------------------------

local storesAvailable = true
local profileStore: DataStore? = nil
local leaderboardStore: OrderedDataStore? = nil
local lapStores: { [string]: OrderedDataStore } = {}
local warnedStores = false

local function storeFailed(context: string, err: any)
	local message = tostring(err)
	-- Accès aux API refusé (Studio) : inutile d'insister, on passe en mémoire.
	if string.find(message, "Studio", 1, true) or string.find(message, "403", 1, true) then
		storesAvailable = false
	end
	if not warnedStores then
		warnedStores = true
		warn(string.format(
			"[RecordService] DataStore indisponible (%s : %s). Temps gardés en mémoire pour la session. "
				.. "Dans Studio : Paramètres du jeu > Sécurité > Activer l'accès Studio aux services d'API.",
			context,
			message
		))
	end
end

local function lapStore(key: string): OrderedDataStore?
	if not storesAvailable then
		return nil
	end
	local existing = lapStores[key]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(LAP_STORE_PREFIX .. key)
	end)
	if not ok then
		storeFailed("records du tour", result)
		return nil
	end
	lapStores[key] = result
	return result
end

local function profileKey(userId: number): string
	return "u_" .. tostring(userId)
end

--------------------------------------------------------------------------------
-- Profils
--------------------------------------------------------------------------------

local function emptyStats(): Stats
	return { Races = 0, Wins = 0, Podiums = 0, Points = 0 }
end

local function sanitizeGhost(input: any): Ghost?
	if type(input) ~= "table" or type(input.Rate) ~= "number" or type(input.Frames) ~= "table" then
		return nil
	end
	local rate = input.Rate
	if rate < 1 or rate > 30 then
		return nil
	end
	local count = #input.Frames
	if count < GHOST_VALUES_PER_FRAME * 2
		or count % GHOST_VALUES_PER_FRAME ~= 0
		or count > GHOST_MAX_FRAMES * GHOST_VALUES_PER_FRAME then
		return nil
	end
	local frames = table.create(count)
	for i = 1, count do
		local value = input.Frames[i]
		if type(value) ~= "number" or value ~= value or math.abs(value) > 1e6 then
			return nil
		end
		-- Deux décimales suffisent largement : moins de place dans le DataStore.
		frames[i] = math.floor(value * 100 + 0.5) / 100
	end
	return { Rate = rate, Frames = frames }
end

local function count(value: any): number
	return if type(value) == "number" and value == value and value >= 0 then math.floor(value) else 0
end

local function sanitizeProfile(data: any, userId: number): Profile
	local profile: Profile = {
		Records = {},
		Setup = CarSetup.Default(),
		Livery = Livery.Default(userId),
		Laps = {},
		Stats = emptyStats(),
	}
	if type(data) ~= "table" then
		return profile
	end
	profile.Livery = Livery.Sanitize(data.Livery, userId)
	if type(data.Records) == "table" then
		for stageId, record in pairs(data.Records) do
			if type(stageId) == "string" and type(record) == "table" and type(record.Ms) == "number" then
				profile.Records[stageId] = { Ms = record.Ms, Ghost = sanitizeGhost(record.Ghost) }
			end
		end
	end
	profile.Setup = CarSetup.Sanitize(data.Setup)
	if type(data.Laps) == "table" then
		for key, ms in pairs(data.Laps) do
			if type(key) == "string" and type(ms) == "number" and ms > 0 then
				profile.Laps[key] = ms
			end
		end
	end
	if type(data.Stats) == "table" then
		profile.Stats = {
			Races = count(data.Stats.Races),
			Wins = count(data.Stats.Wins),
			Podiums = count(data.Stats.Podiums),
			Points = count(data.Stats.Points),
		}
	end
	return profile
end

local profiles: { [Player]: Profile } = {}
local setupDirty: { [Player]: boolean } = {}

-- Modifie le profil sauvegardé de façon atomique (UpdateAsync) : un autre
-- serveur a pu écrire entre-temps. `change` renvoie false pour annuler.
local function updateStoredProfile(userId: number, context: string, change: (Profile) -> boolean)
	local store = profileStore
	if not storesAvailable or not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(profileKey(userId), function(old: any)
				local profile = sanitizeProfile(old, userId)
				if not change(profile) then
					return nil -- rien à écrire
				end
				return profile
			end)
		end)
		if not ok then
			storeFailed(context, err)
		end
	end)
end

local function pushProfile(player: Player)
	local profile = profiles[player]
	if profile and player.Parent then
		Remotes.ProfileUpdated:FireClient(player, profile.Stats, profile.Laps)
	end
end

--------------------------------------------------------------------------------
-- Noms
--------------------------------------------------------------------------------

type Entry = { UserId: number, Name: string, Ms: number }

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else ("Pilote " .. tostring(userId))
	nameCache[userId] = resolved
	return resolved
end

-- Classement trié et tronqué : sauvegardé, complété des records de la session.
local function mergeBoard(store: OrderedDataStore?, session: { [number]: number }, size: number, context: string): { Entry }
	local entries: { Entry } = {}
	local byUser: { [number]: Entry } = {}
	if storesAvailable and store then
		local ok, err = pcall(function()
			local pages = store:GetSortedAsync(true, size)
			for _, item in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(item.key)
				if userId then
					local entry = { UserId = userId, Name = nameOf(userId), Ms = item.value }
					table.insert(entries, entry)
					byUser[userId] = entry
				end
			end
		end)
		if not ok then
			storeFailed(context, err)
		end
	end
	for userId, ms in pairs(session) do
		local existing = byUser[userId]
		if existing then
			existing.Ms = math.min(existing.Ms, ms)
		else
			table.insert(entries, { UserId = userId, Name = nameOf(userId), Ms = ms })
		end
	end
	table.sort(entries, function(a, b)
		return a.Ms < b.Ms
	end)
	while #entries > size do
		table.remove(entries)
	end
	return entries
end

--------------------------------------------------------------------------------
-- Classement de la spéciale
--------------------------------------------------------------------------------

-- Meilleurs temps de la session : sert de classement quand le DataStore manque,
-- et complète le classement sauvegardé avec les records tout juste battus.
local sessionBest: { [number]: number } = {}
local leaderboard: { Entry } = {}

local function refreshLeaderboard()
	leaderboard = mergeBoard(leaderboardStore, sessionBest, LEADERBOARD_SIZE, "classement")
	Remotes.Leaderboard:FireAllClients(leaderboard)
end

local refreshScheduled = false
local function scheduleLeaderboardRefresh()
	if refreshScheduled then
		return
	end
	refreshScheduled = true
	task.delay(2, function()
		refreshScheduled = false
		refreshLeaderboard()
	end)
end

--------------------------------------------------------------------------------
-- Records du tour (rallycross)
--------------------------------------------------------------------------------

type TrackBoard = { Key: string, Entries: { Entry } }

local sessionLaps: { [string]: { [number]: number } } = {}
local lapBoards: { [string]: TrackBoard } = {}

local function refreshLapBoards()
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit then
			local key = circuit.Key
			lapBoards[id] = {
				Key = key,
				Entries = mergeBoard(lapStore(key), sessionLaps[key] or {}, LAP_BOARD_SIZE, "records du tour"),
			}
		end
	end
	Remotes.TrackRecords:FireAllClients(lapBoards)
	RecordService.TrackRecordsChanged(lapBoards)
end

-- Appelée à chaque mise à jour des records du tour (panneaux du paddock).
RecordService.TrackRecordsChanged = function(_boards: any) end

local lapRefreshScheduled = false
local function scheduleLapRefresh()
	if lapRefreshScheduled then
		return
	end
	lapRefreshScheduled = true
	task.delay(3, function()
		lapRefreshScheduled = false
		refreshLapBoards()
	end)
end

-- Tour bouclé en course. Renvoie true si c'est le meilleur tour du joueur sur ce circuit.
function RecordService.SubmitLap(player: Player, trackKey: string, ms: number): boolean
	local profile = profiles[player]
	if not profile or ms <= 0 then
		return false
	end
	local previous = profile.Laps[trackKey]
	if previous and previous <= ms then
		return false
	end
	profile.Laps[trackKey] = ms
	local session = sessionLaps[trackKey]
	if not session then
		session = {}
		sessionLaps[trackKey] = session
	end
	session[player.UserId] = ms

	updateStoredProfile(player.UserId, "record du tour", function(stored)
		local current = stored.Laps[trackKey]
		if current and current <= ms then
			return false
		end
		stored.Laps[trackKey] = ms
		return true
	end)
	local store = lapStore(trackKey)
	if store then
		task.spawn(function()
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(old: any)
					if type(old) == "number" and old <= ms then
						return nil
					end
					return ms
				end)
			end)
			if not ok then
				storeFailed("records du tour", err)
			end
		end)
	end
	scheduleLapRefresh()
	pushProfile(player)
	return true
end

-- Fin de course (dernière manche) : statistiques de carrière.
function RecordService.AddRaceResult(player: Player, position: number, points: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local function apply(stats: Stats)
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
	updateStoredProfile(player.UserId, "statistiques", function(stored)
		apply(stored.Stats)
		return true
	end)
	pushProfile(player)
end

function RecordService.GetLapBest(player: Player, trackKey: string): number?
	local profile = profiles[player]
	return if profile then profile.Laps[trackKey] else nil
end

--------------------------------------------------------------------------------
-- Arrivée de la spéciale et fantômes
--------------------------------------------------------------------------------

local pendingGhost: { [Player]: { Ms: number, Expires: number } } = {}

local function onFinish(player: Player, ms: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local previous = profile.Records[STAGE_ID]
	local isBest = previous == nil or ms < previous.Ms

	if isBest then
		profile.Records[STAGE_ID] = { Ms = ms, Ghost = nil } -- le fantôme suit (SubmitGhost)
		sessionBest[player.UserId] = ms
		pendingGhost[player] = { Ms = ms, Expires = os.clock() + GHOST_WINDOW }

		updateStoredProfile(player.UserId, "record", function(stored)
			local current = stored.Records[STAGE_ID]
			if current and current.Ms <= ms then
				return false -- déjà mieux ailleurs (autre serveur)
			end
			stored.Records[STAGE_ID] = { Ms = ms, Ghost = nil }
			return true
		end)
		local store = leaderboardStore
		if storesAvailable and store then
			task.spawn(function()
				local ok, err = pcall(function()
					store:SetAsync(tostring(player.UserId), ms)
				end)
				if not ok then
					storeFailed("classement", err)
				end
			end)
		end
		scheduleLeaderboardRefresh()
	end

	-- Calibrage des médailles (Medals.luau) : la vitesse moyenne de chaque temps validé.
	if RunService:IsStudio() then
		print(string.format(
			"[Médailles] Spéciale : %.2f s, %.1f km/h de moyenne",
			ms / 1000,
			Medals.AverageKmh(Medals.StageDistance(), ms)
		))
	end

	Remotes.RunValidated:FireClient(player, {
		Valid = true,
		Ms = ms,
		PersonalBest = isBest,
		PreviousMs = if previous then previous.Ms else nil,
	})
end

local function onInvalid(player: Player, reason: string)
	Remotes.RunValidated:FireClient(player, { Valid = false, Reason = reason })
end

--------------------------------------------------------------------------------
-- Défi du fantôme : courir contre la trajectoire d'un autre pilote
--------------------------------------------------------------------------------

local opponentCache: { [number]: { Record: StageRecord?, Expires: number } } = {}
local ghostBusy: { [Player]: boolean } = {}
local lastGhostRequestAt: { [Player]: number } = {}

-- Record de la spéciale (temps et fantôme) d'un pilote, connecté ou non.
local function stageRecordOf(userId: number): StageRecord?
	local online = Players:GetPlayerByUserId(userId)
	local profile = if online then profiles[online] else nil
	if profile then
		return profile.Records[STAGE_ID]
	end
	local cached = opponentCache[userId]
	if cached and os.clock() < cached.Expires then
		return cached.Record
	end
	local store = profileStore
	if not storesAvailable or not store then
		return nil
	end
	local ok, result = pcall(function()
		return store:GetAsync(profileKey(userId))
	end)
	if not ok then
		storeFailed("fantôme d'un autre pilote", result)
		return nil
	end
	local record = sanitizeProfile(result, userId).Records[STAGE_ID]
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
	local profile = profiles[player]
	local mine = if profile then profile.Records[STAGE_ID] else nil
	local times: { [number]: number } = {}
	local function consider(userId: number, ms: number)
		local known = times[userId]
		times[userId] = if known then math.min(known, ms) else ms
	end
	for _, entry in ipairs(leaderboard) do
		consider(entry.UserId, entry.Ms)
	end
	for userId, ms in pairs(sessionBest) do
		consider(userId, ms)
	end
	local store = leaderboardStore
	if mode == "Rival" and mine and storesAvailable and store then
		local ok, err = pcall(function()
			local pages = store:GetSortedAsync(false, RIVAL_CANDIDATES, nil, mine.Ms - 1)
			for _, item in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(item.key)
				if userId then
					consider(userId, item.value)
				end
			end
		end)
		if not ok then
			storeFailed("rival", err)
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
	local profile = profiles[player]
	local mine = if profile then profile.Records[STAGE_ID] else nil

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
				Name = nameOf(candidate),
				Ms = record.Ms,
				Ghost = record.Ghost,
			})
			return
		end
	end

	fail(if mode == "Player" then "Pas de fantôme enregistré pour ce pilote." else "Pas de fantôme enregistré pour les pilotes devant toi.")
end

--------------------------------------------------------------------------------
-- Réglages
--------------------------------------------------------------------------------

local lastSetupAt: { [Player]: number } = {}

-- Réglages et livrée : écrits ensemble, regroupés (toutes les 30 s, au départ).
local function flushSetup(player: Player)
	local profile = profiles[player]
	if not profile or not setupDirty[player] then
		return
	end
	setupDirty[player] = nil
	local setup = profile.Setup
	local livery = profile.Livery
	updateStoredProfile(player.UserId, "réglages", function(stored)
		stored.Setup = setup
		stored.Livery = livery
		return true
	end)
end

function RecordService.GetLivery(player: Player): Livery.Livery
	local profile = profiles[player]
	return if profile then profile.Livery else Livery.Default(player.UserId)
end

-- Appelée quand la livrée d'un joueur change (ou au chargement du profil) :
-- branchée par Main.server.luau sur CarService, qui repeint la voiture.
RecordService.LiveryChanged = function(_player: Player) end

--------------------------------------------------------------------------------
-- Joueurs
--------------------------------------------------------------------------------

local runs: { [Player]: Run } = {}

local function onPlayerAdded(player: Player)
	local data: any = nil
	local store = profileStore
	if storesAvailable and store then
		local ok, result = pcall(function()
			return store:GetAsync(profileKey(player.UserId))
		end)
		if ok then
			data = result
		else
			storeFailed("chargement du profil", result)
		end
	end
	if not player.Parent then
		return -- parti pendant le chargement
	end
	local profile = sanitizeProfile(data, player.UserId)
	profiles[player] = profile
	runs[player] = { Running = false, StartTime = 0, LastProgress = nil, LastTime = 0 }
	nameCache[player.UserId] = player.DisplayName

	local record = profile.Records[STAGE_ID]
	if record then
		sessionBest[player.UserId] = record.Ms
	end
	for key, ms in pairs(profile.Laps) do
		local session = sessionLaps[key]
		if not session then
			session = {}
			sessionLaps[key] = session
		end
		session[player.UserId] = ms
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
	RecordService.LiveryChanged(player)
	Remotes.Leaderboard:FireClient(player, leaderboard)
	Remotes.TrackRecords:FireClient(player, lapBoards)
end

local function carChassisOf(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	if not car or car:GetAttribute("RaceId") ~= nil then
		return nil -- en course de rallycross : pas de chrono de spéciale
	end
	local chassis = car:FindFirstChild("Chassis")
	if chassis and chassis:IsA("BasePart") and chassis:GetAttribute("Driven") == true then
		return chassis
	end
	return nil
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function RecordService.Start()
	do
		local ok, err = pcall(function()
			profileStore = DataStoreService:GetDataStore(PROFILE_STORE_NAME)
			leaderboardStore = DataStoreService:GetOrderedDataStore(LEADERBOARD_STORE_NAME)
		end)
		storesAvailable = ok
		if not ok then
			-- Typiquement : place jamais publiée sur Roblox.
			warnedStores = true
			warn("[RecordService] DataStore indisponible (" .. tostring(err) .. "). Temps gardés en mémoire pour la session.")
		end
	end

	Remotes.SubmitGhost.OnServerEvent:Connect(function(player: Player, input: any)
		local pending = pendingGhost[player]
		local profile = profiles[player]
		if not pending or not profile or os.clock() > pending.Expires then
			return
		end
		local ghost = sanitizeGhost(input)
		if not ghost then
			return
		end
		-- La durée du fantôme doit correspondre au temps validé par le serveur.
		local frameCount = #ghost.Frames / GHOST_VALUES_PER_FRAME
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
		updateStoredProfile(player.UserId, "fantôme", function(stored)
			local current = stored.Records[STAGE_ID]
			if not current or current.Ms ~= ms then
				return false -- un meilleur temps est arrivé entre-temps
			end
			current.Ghost = ghost
			return true
		end)
	end)

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
		if ghostBusy[player] or now - (lastGhostRequestAt[player] or 0) < GHOST_REQUEST_COOLDOWN then
			Remotes.GhostOpponent:FireClient(player, { Mode = mode, Error = "Patiente un instant." })
			return
		end
		lastGhostRequestAt[player] = now
		ghostBusy[player] = true
		local ok, err = pcall(function()
			sendOpponent(player, mode, userId)
		end)
		ghostBusy[player] = nil
		if not ok then
			warn("[RecordService] Fantôme d'un autre pilote :", err)
		end
	end)

	Remotes.SaveSetup.OnServerEvent:Connect(function(player: Player, input: any)
		local profile = profiles[player]
		if not profile then
			return
		end
		local now = os.clock()
		if now - (lastSetupAt[player] or 0) < 0.5 then
			return
		end
		lastSetupAt[player] = now
		profile.Setup = CarSetup.Sanitize(input)
		setupDirty[player] = true
	end)

	local lastLiveryAt: { [Player]: number } = {}
	Remotes.SaveLivery.OnServerEvent:Connect(function(player: Player, input: any)
		local profile = profiles[player]
		if not profile then
			return
		end
		local now = os.clock()
		if now - (lastLiveryAt[player] or 0) < 0.5 then
			return
		end
		lastLiveryAt[player] = now
		profile.Livery = Livery.Sanitize(input, player.UserId)
		setupDirty[player] = true
		RecordService.LiveryChanged(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastLiveryAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SETUP_FLUSH_INTERVAL)
			for player in pairs(setupDirty) do
				flushSetup(player)
			end
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		flushSetup(player)
		profiles[player] = nil
		runs[player] = nil
		pendingGhost[player] = nil
		lastSetupAt[player] = nil
		ghostBusy[player] = nil
		lastGhostRequestAt[player] = nil
	end)

	game:BindToClose(function()
		for player in pairs(setupDirty) do
			flushSetup(player)
		end
		task.wait(2) -- laisse partir les écritures lancées en tâche de fond
	end)

	task.spawn(function()
		refreshLeaderboard()
		while true do
			task.wait(LEADERBOARD_REFRESH)
			refreshLeaderboard()
		end
	end)
	task.spawn(function()
		refreshLapBoards()
		while true do
			task.wait(LAP_BOARD_REFRESH)
			refreshLapBoards()
		end
	end)

	-- Chronométrage officiel de la spéciale
	local finishDistance = StageTrack.GetFinishDistance()
	local startDistance = StageTrack.START_DISTANCE

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		local now = os.clock()

		for player, run in pairs(runs) do
			local chassis = carChassisOf(player)
			if not chassis then
				-- Hors de la voiture : pas de chrono (et la reprise repart de zéro).
				run.Running = false
				run.LastProgress = nil
				continue
			end

			local _, progress, lateral = StageTrack.Locate(chassis.Position)
			local last = run.LastProgress
			local elapsed = now - run.LastTime
			run.LastProgress = progress
			run.LastTime = now
			if last == nil or elapsed <= 0 then
				continue
			end

			local delta = progress - last
			local maxStep = MAX_PLAUSIBLE_SPEED * elapsed + JUMP_MARGIN
			-- Instant (interpolé) où l'abscisse a franchi `line` entre les deux mesures.
			local function crossingTime(line: number): number
				return (now - elapsed) + elapsed * math.clamp((line - last) / delta, 0, 1)
			end

			if run.Running then
				if delta > maxStep then
					run.Running = false
					onInvalid(player, "raccourci")
				elseif delta < -RESTART_BACKWARD then
					run.Running = false -- retour au départ : rien à signaler
				elseif last < finishDistance and progress >= finishDistance then
					run.Running = false
					local ms = math.floor((crossingTime(finishDistance) - run.StartTime) * 1000 + 0.5)
					-- Garde-fou ultime : impossible de couvrir la distance plus vite que ça.
					local minimumMs = (finishDistance - startDistance) / MAX_PLAUSIBLE_SPEED * 1000
					if ms < minimumMs then
						onInvalid(player, "temps impossible")
					else
						onFinish(player, ms)
					end
				end
			elseif last < startDistance
				and progress >= startDistance
				and delta <= maxStep
				and math.abs(lateral) <= START_LATERAL_TOLERANCE then
				run.Running = true
				run.StartTime = crossingTime(startDistance)
			end
		end
	end)
end

return RecordService
