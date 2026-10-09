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

	POINTS DE STYLE COMPTÉS EN COMPÉTITION SEULEMENT : en spéciale chronométrée
	(passage en cours, ou fini depuis moins de STYLE_GRACE s) ou en course de
	rallycross. Pas aux essais libres : sinon des donuts sur la piste d'essai
	suffiraient à monter de niveau.

	PROGRESSION (Progression.luau) : XP, niveau, licence et cosmétiques
	débloqués se DÉDUISENT du profil (médailles, statistiques, spéciales
	terminées, points de style) ; ils sont recalculés et envoyés au joueur à
	chaque changement. Une livrée qui utilise un cosmétique verrouillé est
	ramenée à ce qui est débloqué.
	POINTS DE STYLE : dérapages et sauts sont détectés par le client (la
	physique tourne chez lui) ; le serveur n'en accepte qu'un débit plausible,
	au volant, et ils ne servent qu'à la progression (des cosmétiques).
	Les dépassements, eux, sont détectés par le serveur (RaceService).
	Spéciales terminées et points de style sont sauvegardés par lots, avec
	les réglages (toutes les 30 s et au départ du joueur).

	DÉFI DE LA SEMAINE (Weekly.luau) : la voiture lancée pour le défi porte
	l'attribut Weekly (clé de la semaine). Son temps va dans le classement de
	la semaine (un OrderedDataStore par semaine : remis à zéro le lundi), et
	dans le meilleur temps de la semaine du profil -- pas dans le record
	habituel, ni son fantôme, ni ses médailles. La première fois de la
	semaine, il compte pour l'XP (WeeklyCompleted).

	DÉFIS DU JOUR (Daily.luau) : leur progression est dans le profil (remise à
	zéro au changement de jour), avancée par DailyEvent : arrivées, spéciale
	sans remise en piste, dépassements (RaceService), points de style
	acceptés. Chaque défi réussi rapporte de l'XP (DailyXp), sauvegardée par
	lots avec les autres compteurs.

	ÉCOLE DE PILOTAGE (Lessons.luau) : la leçon se déroule chez le pilote, qui
	envoie sa médaille (LessonResult) ; le profil garde la meilleure de chaque
	leçon, et elle rapporte de l'XP. Une voiture d'école (attribut Lesson)
	n'est pas chronométrée sur la spéciale.

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
local Progression = require(ReplicatedStorage.Shared.Constants.Progression)
local Weekly = require(ReplicatedStorage.Shared.Constants.Weekly)
local Daily = require(ReplicatedStorage.Shared.Constants.Daily)
local Lessons = require(ReplicatedStorage.Shared.Constants.Lessons)

local RecordService = {}

local STAGE_ID = "s1_" .. tostring(math.floor(StageTrack.GetLength()))
local PROFILE_STORE_NAME = "RallyProfiles_v1"
local LEADERBOARD_STORE_NAME = "RallyBest_" .. STAGE_ID
local LAP_STORE_PREFIX = "RallyLap_"
local WEEKLY_STORE_PREFIX = "RallyWeekly_" .. STAGE_ID .. "_"

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
-- Points de style envoyés par le client : un débit moyen plausible au plus
-- (on ne dérape pas en permanence), et une réserve pour encaisser d'un coup une
-- longue combinaison (15 s au ×5 : ~15 000 points). Un tricheur plafonne donc
-- à ~5 000 XP de l'heure, et seulement en cosmétiques.
local STYLE_RATE = 300 -- points par seconde, en moyenne
local STYLE_BURST = 20000
local STYLE_KINDS = { Drift = true, Jump = true }
local STYLE_GRACE = 5 -- s après l'arrivée où une combinaison finie compte encore

type Ghost = { Rate: number, Frames: { number } }
type StageRecord = { Ms: number, Ghost: Ghost? }
export type Stats = { Races: number, Wins: number, Podiums: number, Points: number }
type Profile = {
	Records: { [string]: StageRecord },
	Setup: CarSetup.Setup,
	Livery: Livery.Livery,
	Laps: { [string]: number }, -- meilleur tour (ms) par circuit (Circuit.Key)
	Stats: Stats,
	StageRuns: number, -- spéciales terminées (temps validés)
	Style: number, -- points de style cumulés
	Weekly: { Key: string, Ms: number }?, -- meilleur temps au défi de la semaine
	WeeklyCompleted: number, -- semaines où le défi a été terminé
	Daily: DailyState?, -- défis du jour : progression du jour en cours
	DailyXp: number, -- XP gagnée aux défis du jour, cumulée
	Lessons: { [string]: number }, -- meilleure médaille (1 à 4) par leçon de l'école
}

type DailyState = {
	Key: string, -- jour (Daily.luau)
	Progress: { [string]: number }, -- par défi
	Done: { [string]: boolean },
	Bonus: boolean, -- bonus des trois défis déjà donné
}

type Run = {
	Running: boolean,
	StartTime: number,
	LastProgress: number?,
	LastTime: number,
	-- Points de style acceptés jusqu'à cette heure (os.clock) : pendant le
	-- passage chronométré, et un peu après (combinaison finie sur la ligne).
	StyleUntil: number,
	-- Remise en piste pendant le passage (défi du jour « sans remise en piste »).
	Recovered: boolean,
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
		StageRuns = 0,
		Style = 0,
		Weekly = nil,
		WeeklyCompleted = 0,
		Daily = nil,
		DailyXp = 0,
		Lessons = {},
	}
	if type(data) ~= "table" then
		return profile
	end
	profile.StageRuns = count(data.StageRuns)
	profile.Style = count(data.Style)
	profile.WeeklyCompleted = count(data.WeeklyCompleted)
	profile.DailyXp = count(data.DailyXp)
	if type(data.Lessons) == "table" then
		for id, tier in pairs(data.Lessons) do
			if type(id) == "string" and Lessons.Get(id) then
				profile.Lessons[id] = math.clamp(count(tier), 0, 4)
			end
		end
	end
	local daily = data.Daily
	if type(daily) == "table" and type(daily.Key) == "string" then
		local state: DailyState = { Key = daily.Key, Progress = {}, Done = {}, Bonus = daily.Bonus == true }
		if type(daily.Progress) == "table" then
			for id, value in pairs(daily.Progress) do
				if type(id) == "string" then
					state.Progress[id] = count(value)
				end
			end
		end
		if type(daily.Done) == "table" then
			for id, done in pairs(daily.Done) do
				if type(id) == "string" and done == true then
					state.Done[id] = true
				end
			end
		end
		profile.Daily = state
	end
	local weekly = data.Weekly
	if type(weekly) == "table" and type(weekly.Key) == "string" and type(weekly.Ms) == "number" and weekly.Ms > 0 then
		profile.Weekly = { Key = weekly.Key, Ms = weekly.Ms }
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

--------------------------------------------------------------------------------
-- Progression : XP, niveau, licence, déblocages (Progression.luau)
--------------------------------------------------------------------------------

local lastProgress: { [Player]: Progression.Snapshot } = {}

-- Palier de médaille par tracé : "stage" pour la spéciale, l'id du circuit sinon.
local function medalsOf(profile: Profile): { [string]: number }
	local medals: { [string]: number } = {}
	local stage = profile.Records[STAGE_ID]
	medals.stage = Medals.TierOf(if stage then stage.Ms else nil, Medals.ForStage())
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit then
			medals[id] = Medals.TierOf(profile.Laps[circuit.Key], Medals.ForCircuit(id, circuit.Length))
		end
	end
	return medals
end

local function snapshotOf(profile: Profile): Progression.Snapshot
	return Progression.Snapshot({
		Races = profile.Stats.Races,
		Wins = profile.Stats.Wins,
		Podiums = profile.Stats.Podiums,
		Points = profile.Stats.Points,
		StageRuns = profile.StageRuns,
		Style = profile.Style,
		WeeklyCompleted = profile.WeeklyCompleted,
		DailyXp = profile.DailyXp,
		Medals = medalsOf(profile),
		Lessons = profile.Lessons,
	})
end

-- Appelée à chaque changement de progression (licence affichée sur la voiture).
RecordService.ProgressChanged = function(_player: Player, _snapshot: Progression.Snapshot) end

--[[
	Recalcule la progression et l'envoie au joueur. `announce` : signaler un
	niveau gagné ou un cosmétique débloqué (pas au chargement du profil).
]]
local function pushProgress(player: Player, announce: boolean)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	local snapshot = snapshotOf(profile)
	local previous = lastProgress[player]
	lastProgress[player] = snapshot
	local news: any = nil
	if announce and previous then
		local unlocks = {}
		for _, item in ipairs(Progression.NewUnlocks(previous, snapshot)) do
			table.insert(unlocks, { Kind = item.Kind, Index = item.Index })
		end
		if snapshot.Level > previous.Level or #unlocks > 0 then
			news = { LevelUp = snapshot.Level > previous.Level, Unlocks = unlocks }
		end
	end
	Remotes.Progress:FireClient(player, snapshot, news)
	if not previous or previous.Level ~= snapshot.Level then
		RecordService.ProgressChanged(player, snapshot)
	end
end

function RecordService.GetProgress(player: Player): Progression.Snapshot?
	return lastProgress[player]
end

local function pushProfile(player: Player)
	local profile = profiles[player]
	if profile and player.Parent then
		Remotes.ProfileUpdated:FireClient(player, profile.Stats, profile.Laps)
		pushProgress(player, true)
	end
end

-- Compteurs sauvegardés par lots (spéciales terminées, points de style, XP
-- des défis du jour) : ce qui s'est ajouté depuis la dernière écriture.
type Pending = { StageRuns: number, Style: number, DailyXp: number, DailyDirty: boolean }
local pendingCounters: { [Player]: Pending } = {}

local function pendingOf(player: Player): Pending
	local pending = pendingCounters[player]
	if not pending then
		pending = { StageRuns = 0, Style = 0, DailyXp = 0, DailyDirty = false }
		pendingCounters[player] = pending
	end
	return pending
end

local function addCounters(player: Player, stageRuns: number, style: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.StageRuns += stageRuns
	profile.Style += style
	local pending = pendingOf(player)
	pending.StageRuns += stageRuns
	pending.Style += style
	pushProgress(player, true)
end

local function copyDaily(state: DailyState): DailyState
	return { Key = state.Key, Progress = table.clone(state.Progress), Done = table.clone(state.Done), Bonus = state.Bonus }
end

local function flushCounters(player: Player)
	local pending = pendingCounters[player]
	if not pending then
		return
	end
	pendingCounters[player] = nil
	local profile = profiles[player]
	local daily = if pending.DailyDirty and profile and profile.Daily then copyDaily(profile.Daily) else nil
	updateStoredProfile(player.UserId, "progression", function(stored)
		stored.StageRuns += pending.StageRuns
		stored.Style += pending.Style
		stored.DailyXp += pending.DailyXp
		if daily then
			stored.Daily = daily
		end
		return true
	end)
end

--------------------------------------------------------------------------------
-- Défis du jour (Daily.luau)
--------------------------------------------------------------------------------

-- La progression du jour en cours (remise à zéro au changement de jour).
local function dailyStateOf(profile: Profile, day: Daily.Day): DailyState
	local state = profile.Daily
	if not state or state.Key ~= day.Key then
		state = { Key = day.Key, Progress = {}, Done = {}, Bonus = false }
		profile.Daily = state
	end
	return state :: DailyState
end

local function sendDaily(player: Player, news: any?)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	local day = Daily.Current()
	local state = dailyStateOf(profile, day)
	local challenges = {}
	for _, challenge in ipairs(day.Challenges) do
		table.insert(challenges, {
			Id = challenge.Id,
			Text = challenge.Text,
			Goal = challenge.Goal,
			Progress = math.min(state.Progress[challenge.Id] or 0, challenge.Goal),
			Done = state.Done[challenge.Id] == true,
		})
	end
	Remotes.Daily:FireClient(player, {
		Key = day.Key,
		EndsAt = day.EndsAt,
		Challenges = challenges,
		Bonus = state.Bonus,
		Xp = Daily.XP,
		BonusXp = Daily.BONUS_XP,
	}, news)
end

--[[
	Un événement de jeu (Daily.POOL : Event) : fait avancer les défis du jour
	qu'il concerne. Count : `value` s'ajoute ; Max : on garde la meilleure.
]]
function RecordService.DailyEvent(player: Player, event: string, value: number)
	local profile = profiles[player]
	if not profile or value <= 0 then
		return
	end
	local day = Daily.Current()
	local state = dailyStateOf(profile, day)
	local changed = false
	local completed = {}
	local xp = 0
	for _, challenge in ipairs(day.Challenges) do
		if challenge.Event == event and not state.Done[challenge.Id] then
			local current = state.Progress[challenge.Id] or 0
			local updated = if challenge.Kind == "Count" then current + value else math.max(current, value)
			if updated ~= current then
				changed = true
				state.Progress[challenge.Id] = math.min(updated, challenge.Goal)
				if updated >= challenge.Goal then
					state.Done[challenge.Id] = true
					table.insert(completed, challenge.Id)
					xp += Daily.XP
				end
			end
		end
	end
	if not changed then
		return
	end
	local allDone = true
	for _, challenge in ipairs(day.Challenges) do
		if not state.Done[challenge.Id] then
			allDone = false
		end
	end
	local bonus = allDone and not state.Bonus
	if bonus then
		state.Bonus = true
		xp += Daily.BONUS_XP
	end
	local pending = pendingOf(player)
	pending.DailyDirty = true
	if xp > 0 then
		profile.DailyXp += xp
		pending.DailyXp += xp
	end
	sendDaily(player, if #completed > 0 then { Completed = completed, AllDone = bonus } else nil)
	if xp > 0 then
		pushProgress(player, true)
	end
end

-- Points de style décidés par le serveur (dépassements, RaceService).
function RecordService.AddStyle(player: Player, points: number)
	if points > 0 then
		addCounters(player, 0, math.floor(points))
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
-- Défi de la semaine (Weekly.luau)
--------------------------------------------------------------------------------

local weeklyStores: { [string]: OrderedDataStore } = {}
local sessionWeekly: { [string]: { [number]: number } } = {} -- par clé de semaine
local weeklyEntries: { Entry } = {}
local weeklyKey = ""

local function weeklyStore(key: string): OrderedDataStore?
	if not storesAvailable then
		return nil
	end
	local existing = weeklyStores[key]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(WEEKLY_STORE_PREFIX .. key)
	end)
	if not ok then
		storeFailed("défi de la semaine", result)
		return nil
	end
	weeklyStores[key] = result
	return result
end

-- Ce qu'on envoie à un joueur : la semaine, sa contrainte, le classement, son temps.
local function weeklyPayload(player: Player): any
	local week = Weekly.Current()
	local profile = profiles[player]
	local mine = if profile and profile.Weekly and profile.Weekly.Key == week.Key then profile.Weekly.Ms else nil
	return {
		Key = week.Key,
		Modifier = week.Modifier.Id,
		EndsAt = week.EndsAt,
		Entries = if weeklyKey == week.Key then weeklyEntries else {},
		Mine = mine,
	}
end

local function sendWeekly(player: Player)
	if player.Parent then
		Remotes.WeeklyBoard:FireClient(player, weeklyPayload(player))
	end
end

local function refreshWeekly()
	local week = Weekly.Current()
	weeklyEntries = mergeBoard(weeklyStore(week.Key), sessionWeekly[week.Key] or {}, LEADERBOARD_SIZE, "défi de la semaine")
	weeklyKey = week.Key
	for _, player in ipairs(Players:GetPlayers()) do
		sendWeekly(player)
	end
end

local weeklyRefreshScheduled = false
local function scheduleWeeklyRefresh()
	if weeklyRefreshScheduled then
		return
	end
	weeklyRefreshScheduled = true
	task.delay(2, function()
		weeklyRefreshScheduled = false
		refreshWeekly()
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

--[[
	Arrivée d'un passage du défi de la semaine `key` : classement de la semaine
	et meilleur temps de la semaine du joueur ; la première fois de la semaine,
	le défi compte comme terminé (XP).
]]
-- Une spéciale terminée (habituelle ou défi) : les défis du jour qui en dépendent.
local function stageFinished(player: Player, clean: boolean, weekly: boolean)
	RecordService.DailyEvent(player, "StageRun", 1)
	if clean then
		RecordService.DailyEvent(player, "CleanStage", 1)
	end
	if weekly then
		RecordService.DailyEvent(player, "WeeklyRun", 1)
	end
end

local function onWeeklyFinish(player: Player, ms: number, key: string, clean: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	local current = profile.Weekly
	local sameWeek = current ~= nil and current.Key == key
	local previous = if current and sameWeek then current.Ms else nil
	local isBest = previous == nil or ms < previous
	if isBest then
		if not sameWeek then
			profile.WeeklyCompleted += 1
		end
		profile.Weekly = { Key = key, Ms = ms }
		local session = sessionWeekly[key]
		if not session then
			session = {}
			sessionWeekly[key] = session
		end
		session[player.UserId] = ms
		updateStoredProfile(player.UserId, "défi de la semaine", function(stored)
			local storedWeekly = stored.Weekly
			if storedWeekly == nil or storedWeekly.Key ~= key then
				stored.WeeklyCompleted += 1
			elseif storedWeekly.Ms <= ms then
				return false
			end
			stored.Weekly = { Key = key, Ms = ms }
			return true
		end)
		local store = weeklyStore(key)
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
					storeFailed("défi de la semaine", err)
				end
			end)
		end
		scheduleWeeklyRefresh()
	end
	Remotes.RunValidated:FireClient(player, {
		Valid = true,
		Ms = ms,
		Weekly = true,
		WeeklyBest = isBest,
		PreviousMs = previous,
	})
	addCounters(player, 1, 0)
	sendWeekly(player)
	stageFinished(player, clean, true)
end

-- `clean` : pas de remise en piste pendant le passage.
local function onFinish(player: Player, ms: number, clean: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	-- Défi de la semaine : son propre classement, pas le record habituel.
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local weeklyKeyOfCar = if car then car:GetAttribute("Weekly") else nil
	if type(weeklyKeyOfCar) == "string" then
		onWeeklyFinish(player, ms, weeklyKeyOfCar, clean)
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
	-- Une spéciale de plus (et peut-être une médaille) : la progression suit.
	addCounters(player, 1, 0)
	stageFinished(player, clean, false)
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
	-- Livrée sauvegardée avec un cosmétique qui n'est plus débloqué (barème retouché).
	local default = Livery.Default(player.UserId)
	profile.Livery = Progression.Enforce(profile.Livery, default, default, snapshotOf(profile))
	profiles[player] = profile
	runs[player] = { Running = false, StartTime = 0, LastProgress = nil, LastTime = 0, StyleUntil = 0, Recovered = false }
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
	sendWeekly(player)
	sendDaily(player)
	pushProgress(player, false)
end

local function carChassisOf(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	if not car or car:GetAttribute("RaceId") ~= nil or car:GetAttribute("Lesson") ~= nil then
		return nil -- en course de rallycross, ou à l'école : pas de chrono de spéciale
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
		-- Un cosmétique pas encore débloqué est remplacé par ce qui l'est.
		profile.Livery = Progression.Enforce(
			Livery.Sanitize(input, player.UserId),
			profile.Livery,
			Livery.Default(player.UserId),
			lastProgress[player]
		)
		setupDirty[player] = true
		RecordService.LiveryChanged(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastLiveryAt[player] = nil
	end)

	-- Points de style (dérapages, sauts) : au volant, à débit plausible.
	type Allowance = { Points: number, At: number }
	local styleAllowance: { [Player]: Allowance } = {}
	Remotes.SubmitStyle.OnServerEvent:Connect(function(player: Player, points: any, kind: any, detail: any)
		if type(points) ~= "number" or points ~= points or points <= 0 or not STYLE_KINDS[kind] then
			return
		end
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local chassis = car and car:FindFirstChild("Chassis")
		if not car or not chassis or chassis:GetAttribute("Driven") ~= true then
			return
		end
		local now = os.clock()
		-- En compétition seulement : course de rallycross, ou spéciale chronométrée.
		local run = runs[player]
		if car:GetAttribute("RaceId") == nil and not (run and now < run.StyleUntil) then
			return
		end
		local allowance: Allowance = styleAllowance[player] or { Points = STYLE_BURST, At = now }
		allowance.Points = math.min(STYLE_BURST, allowance.Points + (now - allowance.At) * STYLE_RATE)
		allowance.At = now
		local accepted = math.floor(math.min(points, allowance.Points))
		allowance.Points -= accepted
		styleAllowance[player] = allowance
		if accepted > 0 then
			addCounters(player, 0, accepted)
			-- Défis du jour : points de style, combinaison, multiplicateur, saut.
			RecordService.DailyEvent(player, "Style", accepted)
			local info = if type(detail) == "table" then detail else {}
			if kind == "Drift" then
				RecordService.DailyEvent(player, "DriftCombo", accepted)
				local multiplier = info.Multiplier
				if type(multiplier) == "number" and multiplier == multiplier then
					RecordService.DailyEvent(player, "DriftMultiplier", math.clamp(math.floor(multiplier), 1, 5))
				end
			elseif kind == "Jump" then
				local air = info.Air
				if type(air) == "number" and air == air and air >= 1 and air <= 10 then
					RecordService.DailyEvent(player, "LongJump", 1)
				end
			end
		end
	end)

	-- École de pilotage : la meilleure médaille de chaque leçon.
	local lastLessonAt: { [Player]: number } = {}
	Remotes.LessonResult.OnServerEvent:Connect(function(player: Player, id: any, tier: any)
		local profile = profiles[player]
		if not profile or type(id) ~= "string" or not Lessons.Get(id) or type(tier) ~= "number" or tier ~= tier then
			return
		end
		local now = os.clock()
		if now - (lastLessonAt[player] or 0) < 1 then
			return
		end
		lastLessonAt[player] = now
		local medal = math.clamp(math.floor(tier), 0, 4)
		if medal <= (profile.Lessons[id] or 0) then
			return
		end
		profile.Lessons[id] = medal
		updateStoredProfile(player.UserId, "école de pilotage", function(stored)
			if (stored.Lessons[id] or 0) >= medal then
				return false
			end
			stored.Lessons[id] = medal
			return true
		end)
		pushProgress(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastLessonAt[player] = nil
	end)

	-- Remise en piste pendant la spéciale : le passage n'est plus « propre ».
	Remotes.Recovered.OnServerEvent:Connect(function(player: Player)
		local run = runs[player]
		if run and run.Running then
			run.Recovered = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		styleAllowance[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SETUP_FLUSH_INTERVAL)
			for player in pairs(setupDirty) do
				flushSetup(player)
			end
			for player in pairs(pendingCounters) do
				flushCounters(player)
			end
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		flushSetup(player)
		flushCounters(player)
		lastProgress[player] = nil
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
		for player in pairs(pendingCounters) do
			flushCounters(player)
		end
		task.wait(2) -- laisse partir les écritures lancées en tâche de fond
	end)

	task.spawn(function()
		refreshLeaderboard()
		refreshWeekly()
		while true do
			task.wait(LEADERBOARD_REFRESH)
			refreshLeaderboard()
			-- Aussi au passage du lundi : nouvelle semaine, nouvelle contrainte.
			refreshWeekly()
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
				run.StyleUntil = now + STYLE_GRACE
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
						onFinish(player, ms, not run.Recovered)
					end
				end
			elseif last < startDistance
				and progress >= startDistance
				and delta <= maxStep
				and math.abs(lateral) <= START_LATERAL_TOLERANCE then
				run.Running = true
				run.Recovered = false
				run.StartTime = crossingTime(startDistance)
			end
		end
	end)
end

return RecordService
