--!strict
--[[
	RecordService.server.luau
	Temps officiels, meilleurs temps sauvegardés, classement, fantômes, réglages.

	CHRONO OFFICIEL, MESURÉ PAR LE SERVEUR : on ne croit jamais un temps envoyé
	par un client (n'importe qui peut envoyer "0:12.00"). Le serveur suit lui-même
	chaque voiture le long du tracé, 10 fois par seconde (StageTrack.Locate, le
	même calcul que le chrono du client), et détecte départ, arrivée et
	raccourcis. Le passage des lignes est interpolé entre deux mesures : la
	précision est de l'ordre du centième, et le délai réseau, identique au départ
	et à l'arrivée, s'annule.
	Limite honnête : la physique tourne chez le client (il possède sa voiture).
	Un tricheur déterminé peut donc rouler "trop vite" ; le serveur rejette tout
	ce qui dépasse une vitesse plausible, tout bond le long du tracé (raccourci,
	téléportation) et tout temps trop court pour la distance.

	SAUVEGARDE (DataStore) : un profil par joueur -- meilleur temps et fantôme par
	spéciale, réglages de la voiture -- plus un classement (OrderedDataStore).
	Écritures rares par construction : un record perso, un fantôme, des réglages
	regroupés toutes les 30 s et au départ du joueur. Bien en deçà des limites
	de Roblox (~60 + 10 x joueurs écritures par minute).
	Dans Studio, les DataStores exigent "Activer l'accès Studio aux services
	d'API" (Paramètres du jeu > Sécurité). Sans ça, tout fonctionne quand même,
	en mémoire, pour la session.

	IDENTITÉ DE LA SPÉCIALE : dérivée de sa longueur. Si le tracé change, les
	temps repartent de zéro au lieu de mélanger deux parcours différents.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)

local STAGE_ID = "s1_" .. tostring(math.floor(StageTrack.GetLength()))
local PROFILE_STORE_NAME = "RallyProfiles_v1"
local LEADERBOARD_STORE_NAME = "RallyBest_" .. STAGE_ID

local SAMPLE_INTERVAL = 0.1 -- secondes entre deux mesures de position
local MAX_PLAUSIBLE_SPEED = 250 -- studs/s (~250 km/h) : au-delà, ce n'est pas de la conduite
local JUMP_MARGIN = 25 -- studs de tolérance (à-coup réseau, remise en piste)
local RESTART_BACKWARD = 150 -- recul le long du tracé qui signifie "retour au départ"
local START_LATERAL_TOLERANCE = StageTrack.ROAD_WIDTH / 2 + 8

local LEADERBOARD_SIZE = 10
local LEADERBOARD_REFRESH = 60 -- secondes
local SETUP_FLUSH_INTERVAL = 30
local GHOST_WINDOW = 60 -- secondes pour envoyer le fantôme après un record
local GHOST_MAX_FRAMES = 3000 -- 5 min à 10 Hz
local GHOST_VALUES_PER_FRAME = 6 -- x, y, z, rx, ry, rz

type Ghost = { Rate: number, Frames: { number } }
type StageRecord = { Ms: number, Ghost: Ghost? }
type Profile = { Records: { [string]: StageRecord }, Setup: CarSetup.Setup }

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
local warnedStores = false
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

local function profileKey(userId: number): string
	return "u_" .. tostring(userId)
end

--------------------------------------------------------------------------------
-- Profils
--------------------------------------------------------------------------------

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

local function sanitizeProfile(data: any): Profile
	local profile: Profile = { Records = {}, Setup = CarSetup.Default() }
	if type(data) ~= "table" then
		return profile
	end
	if type(data.Records) == "table" then
		for stageId, record in pairs(data.Records) do
			if type(stageId) == "string" and type(record) == "table" and type(record.Ms) == "number" then
				profile.Records[stageId] = { Ms = record.Ms, Ghost = sanitizeGhost(record.Ghost) }
			end
		end
	end
	profile.Setup = CarSetup.Sanitize(data.Setup)
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
				local profile = sanitizeProfile(old)
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
-- Classement
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

-- Meilleurs temps de la session : sert de classement quand le DataStore manque,
-- et complète le classement sauvegardé avec les records tout juste battus.
local sessionBest: { [number]: number } = {}
local leaderboard: { Entry } = {}

local function refreshLeaderboard()
	local entries: { Entry } = {}
	local seen: { [number]: boolean } = {}

	local store = leaderboardStore
	if storesAvailable and store then
		local ok, err = pcall(function()
			local pages = store:GetSortedAsync(true, LEADERBOARD_SIZE)
			for _, item in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(item.key)
				if userId then
					table.insert(entries, { UserId = userId, Name = nameOf(userId), Ms = item.value })
					seen[userId] = true
				end
			end
		end)
		if not ok then
			storeFailed("classement", err)
		end
	end
	for userId, ms in pairs(sessionBest) do
		if not seen[userId] then
			table.insert(entries, { UserId = userId, Name = nameOf(userId), Ms = ms })
		else
			for _, entry in ipairs(entries) do
				if entry.UserId == userId then
					entry.Ms = math.min(entry.Ms, ms)
				end
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.Ms < b.Ms
	end)
	while #entries > LEADERBOARD_SIZE do
		table.remove(entries)
	end
	leaderboard = entries
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
-- Arrivée et fantômes
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

--------------------------------------------------------------------------------
-- Réglages
--------------------------------------------------------------------------------

local lastSetupAt: { [Player]: number } = {}

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

local function flushSetup(player: Player)
	local profile = profiles[player]
	if not profile or not setupDirty[player] then
		return
	end
	setupDirty[player] = nil
	local setup = profile.Setup
	updateStoredProfile(player.UserId, "réglages", function(stored)
		stored.Setup = setup
		return true
	end)
end

task.spawn(function()
	while true do
		task.wait(SETUP_FLUSH_INTERVAL)
		for player in pairs(setupDirty) do
			flushSetup(player)
		end
	end
end)

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
	local profile = sanitizeProfile(data)
	profiles[player] = profile
	runs[player] = { Running = false, StartTime = 0, LastProgress = nil, LastTime = 0 }
	nameCache[player.UserId] = player.DisplayName

	local record = profile.Records[STAGE_ID]
	if record then
		sessionBest[player.UserId] = record.Ms
	end
	Remotes.ProfileLoaded:FireClient(player, {
		StageId = STAGE_ID,
		BestMs = if record then record.Ms else nil,
		Ghost = if record then record.Ghost else nil,
		Setup = profile.Setup,
	})
	Remotes.Leaderboard:FireClient(player, leaderboard)
end

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

--------------------------------------------------------------------------------
-- Chronométrage officiel
--------------------------------------------------------------------------------

local function carChassisOf(player: Player): BasePart?
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local chassis = car and car:FindFirstChild("Chassis")
	if chassis and chassis:IsA("BasePart") and chassis:GetAttribute("Driven") == true then
		return chassis
	end
	return nil
end

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
