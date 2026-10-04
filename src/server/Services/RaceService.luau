--!strict
--[[
	RaceService.luau
	Courses de rallycross : salles d'attente, grille, départ, suivi, résultats.

	CYCLE D'UNE COURSE
		Lobby     : salle d'attente. On crée (circuit, tours, format, contacts), on
		            rejoint, on se déclare prêt. 2 à 6 joueurs. Départ quand tout le
		            monde est prêt (après AUTO_START_DELAY), ou quand l'hôte lance.
		Grid      : les voitures sont recréées sur la grille, retenues (attribut Held).
		Countdown : cinq feux rouges s'allument un à un, puis s'éteignent après un
		            délai aléatoire : c'est le départ. Bouger avant = faux départ.
		Racing    : suivi des tours, du joker, des positions.
		Results   : classement de la manche. Format "Qualif + Finale" : la finale
		            suit, grille dans l'ordre de la qualification. Puis tout le monde
		            revient au paddock, dans la même salle d'attente (revanche possible).

	INSTANCES : plusieurs courses peuvent tourner en même temps, même sur le même
	circuit. Chaque client ne montre que les voitures de sa propre course
	(RemoteCars.luau) et le contact n'existe qu'entre voitures d'une même course.

	SUIVI, PAR LE SERVEUR : comme le chrono de la spéciale, on ne croit pas le
	client. Dix fois par seconde, chaque voiture est située sur le tracé
	(Circuit:Locate) et son AVANCEMENT est intégré mesure après mesure.
	ANTI-RACCOURCI SANS PORTES : l'avancement gagné entre deux mesures est borné
	par la distance réellement parcourue (x 1.6 sur la piste : l'intérieur d'un
	virage avance plus vite que l'axe ; x 1.05 hors piste). Couper un virage
	par l'herbe ne fait donc rien gagner : la distance "coupée" n'est jamais
	comptée, et il faudra la rouler quand même avant de franchir la ligne. Une
	téléportation (remise en piste) ne fait gagner que quelques studs.

	JOKER : obligatoire une fois par course. Il est compté quand la voiture passe
	le milieu de la branche joker. Pas de joker à l'arrivée : +5 s.
	FAUX DÉPART : +1 s.

	POSITIONS : arrivés d'abord (temps total, pénalités comprises), puis selon
	l'avancement. ÉCARTS : le temps de passage de chacun est noté tous les
	MILESTONE studs d'avancement ; l'écart avec le leader est la différence des
	temps au même point du circuit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Circuit = require(ReplicatedStorage.Shared.Tracks.Circuit)
local CarService = require(script.Parent.CarService)
local RecordService = require(script.Parent.RecordService)

local RaceService = {}

local MIN_PLAYERS = 2
local MAX_PLAYERS = 6
local MAX_RACES = 8
local MIN_LAPS, MAX_LAPS = 2, 8
local ACTION_COOLDOWN = 0.25

local AUTO_START_DELAY = 5 -- tout le monde prêt : départ dans 5 s
local SPAWN_TIMEOUT = 15 -- attente maximale de la mise en grille
local GRID_SETTLE = 2.5 -- les voitures se posent avant les feux
local LIGHT_COUNT = 5
local LIGHT_INTERVAL = 0.7
local LIGHTS_OUT_MIN, LIGHTS_OUT_MAX = 0.4, 1.8 -- délai aléatoire après le 5e feu
local FINISH_WINDOW = 30 -- après le vainqueur, les autres ont 30 s pour finir
local RESULTS_TIME = 12

local SAMPLE_INTERVAL = 0.1
local LIVE_INTERVAL = 0.25
local MAX_PLAUSIBLE_SPEED = 250 -- studs/s
local TELEPORT_MARGIN = 25
local ON_TRACK_RATIO = 1.6
local OFF_TRACK_RATIO = 1.05
local PROGRESS_MARGIN = 6
local TELEPORT_ALLOWANCE = 20 -- avancement maximal concédé à une remise en piste
local JOKER_ZONE_MIN, JOKER_ZONE_MAX = 0.3, 0.7
local JUMP_START_DISTANCE = 4
local JUMP_START_PENALTY = 1
local JOKER_MISSED_PENALTY = 5
local MILESTONE = 40 -- studs entre deux points de mesure des écarts

local POINTS = { 10, 8, 6, 4, 2, 1 }

type RaceState = "Lobby" | "Grid" | "Countdown" | "Racing" | "Results"
type Format = "Sprint" | "Event"

type Member = {
	Player: Player,
	UserId: number,
	Name: string,
	Ready: boolean,
}

type Runner = {
	Player: Player,
	UserId: number,
	Name: string,
	Slot: number,
	GridPosition: Vector3?,

	Location: Circuit.Location?,
	LastRaw: number?,
	Valid: number, -- avancement intégré (studs), négatif sur la grille
	LastPosition: Vector3,
	LastTime: number,

	Laps: number, -- tours bouclés
	LapStart: number, -- heure serveur du début du tour en cours
	LapTimes: { number },
	BestLap: number?,
	LastLap: number?,

	JokerCount: number,
	InJoker: boolean,
	JumpStart: boolean,
	Penalty: number,

	Finished: boolean,
	RaceTime: number?, -- temps de course, sans pénalité
	TotalTime: number?, -- avec pénalités
	Dnf: boolean,
	DnfReason: string?,

	Milestones: { [number]: number },
	LastMilestone: number,
}

type ResultRow = {
	UserId: number,
	Name: string,
	Position: number,
	TotalTime: number?,
	Penalty: number,
	BestLap: number?,
	Dnf: boolean,
	DnfReason: string?,
	Points: number,
}

type Race = {
	Id: string,
	TrackId: string,
	Circuit: Circuit.Circuit,
	Laps: number,
	Format: Format,
	Contacts: boolean,
	HostUserId: number,
	Members: { Member },
	State: RaceState,
	Round: number,
	RoundCount: number,
	Token: number,
	AutoStartAt: number?,
	LightsStart: number?,
	StartTime: number?,
	FinishDeadline: number?,
	Timeout: number?,
	Runners: { Runner },
	LastResults: { ResultRow }?,
	GridOrder: { number }?, -- UserIds, pole en premier (manche suivante)
}

local races: { [string]: Race } = {}
local raceOrder: { string } = {}
local raceOf: { [Player]: Race } = {}
local lastActionAt: { [Player]: number } = {}
local nextRaceId = 1

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function roundName(race: Race, round: number): string
	if race.Format == "Event" then
		return if round == 1 then "MANCHE QUALIFICATIVE" else "FINALE"
	end
	return "COURSE"
end

local function memberOf(race: Race, player: Player): Member?
	for _, member in ipairs(race.Members) do
		if member.Player == player then
			return member
		end
	end
	return nil
end

local function runnerOf(race: Race, player: Player): Runner?
	for _, runner in ipairs(race.Runners) do
		if runner.Player == player then
			return runner
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Diffusion
--------------------------------------------------------------------------------

local function lobbyList()
	local list = {}
	for _, id in ipairs(raceOrder) do
		local race = races[id]
		if race then
			local hostName = ""
			for _, member in ipairs(race.Members) do
				if member.UserId == race.HostUserId then
					hostName = member.Name
				end
			end
			table.insert(list, {
				Id = race.Id,
				TrackId = race.TrackId,
				Laps = race.Laps,
				Format = race.Format,
				Contacts = race.Contacts,
				Host = hostName,
				Count = #race.Members,
				Max = MAX_PLAYERS,
				State = race.State,
			})
		end
	end
	return list
end

local function broadcastLobby()
	Remotes.LobbyState:FireAllClients(lobbyList())
end

local function raceSnapshot(race: Race)
	local members = {}
	for _, member in ipairs(race.Members) do
		table.insert(members, { UserId = member.UserId, Name = member.Name, Ready = member.Ready })
	end
	return {
		Id = race.Id,
		TrackId = race.TrackId,
		Laps = race.Laps,
		Format = race.Format,
		Contacts = race.Contacts,
		HostUserId = race.HostUserId,
		State = race.State,
		Round = race.Round,
		RoundCount = race.RoundCount,
		RoundName = roundName(race, race.Round),
		Members = members,
		MinPlayers = if RunService:IsStudio() then 1 else MIN_PLAYERS,
		MaxPlayers = MAX_PLAYERS,
		AutoStartAt = race.AutoStartAt,
		LightsStart = race.LightsStart,
		LightCount = LIGHT_COUNT,
		LightInterval = LIGHT_INTERVAL,
		StartTime = race.StartTime,
	}
end

local function sendRaceState(race: Race)
	local snapshot = raceSnapshot(race)
	for _, member in ipairs(race.Members) do
		Remotes.RaceState:FireClient(member.Player, snapshot)
	end
end

local function sendEvent(race: Race, player: Player?, kind: string, data: any)
	if player then
		if player.Parent then
			Remotes.RaceEvent:FireClient(player, kind, data)
		end
		return
	end
	for _, member in ipairs(race.Members) do
		Remotes.RaceEvent:FireClient(member.Player, kind, data)
	end
end

--------------------------------------------------------------------------------
-- Classement
--------------------------------------------------------------------------------

local function sortRunners(race: Race): { Runner }
	local sorted = table.clone(race.Runners)
	table.sort(sorted, function(a, b)
		if a.Finished ~= b.Finished then
			return a.Finished
		end
		if a.Finished and b.Finished then
			return (a.TotalTime :: number) < (b.TotalTime :: number)
		end
		if a.Dnf ~= b.Dnf then
			return not a.Dnf
		end
		return a.Valid > b.Valid
	end)
	return sorted
end

-- Écart au leader (secondes) et tours de retard.
local function gapTo(leader: Runner, runner: Runner, length: number): (number?, number)
	if runner == leader then
		return 0, 0
	end
	if runner.Finished and leader.Finished then
		return (runner.TotalTime :: number) - (leader.TotalTime :: number), 0
	end
	local lapsDown = math.max(0, math.floor((leader.Valid - runner.Valid) / length))
	local k = runner.LastMilestone
	local mine = runner.Milestones[k]
	local theirs = leader.Milestones[k]
	if mine and theirs then
		return math.max(0, mine - theirs), lapsDown
	end
	return nil, lapsDown
end

local function sendLive(race: Race)
	if #race.Runners == 0 then
		return
	end
	local sorted = sortRunners(race)
	local leader = sorted[1]
	local rows = {}
	for position, runner in ipairs(sorted) do
		local gap, lapsDown = gapTo(leader, runner, race.Circuit.Length)
		table.insert(rows, {
			U = runner.UserId,
			N = runner.Name,
			P = position,
			L = runner.Laps,
			G = gap,
			LD = lapsDown,
			J = runner.JokerCount,
			F = runner.Finished,
			D = runner.Dnf,
			B = runner.BestLap,
			LL = runner.LastLap,
			LS = runner.LapStart,
			PEN = runner.Penalty,
			T = runner.TotalTime,
		})
	end
	local payload = { Id = race.Id, Rows = rows, Time = serverNow() }
	for _, member in ipairs(race.Members) do
		Remotes.RaceLive:FireClient(member.Player, payload)
	end
end

--------------------------------------------------------------------------------
-- Cycle de vie
--------------------------------------------------------------------------------

local startRound: (Race, number) -> ()
local updateAutoStart: (Race) -> ()

local function backToLobby(race: Race)
	race.Token += 1
	race.State = "Lobby"
	race.Round = 1
	race.Runners = {}
	race.AutoStartAt = nil
	race.LightsStart = nil
	race.StartTime = nil
	race.FinishDeadline = nil
	race.Timeout = nil
	race.GridOrder = nil
	for _, member in ipairs(race.Members) do
		member.Ready = false
		local player = member.Player
		task.spawn(function()
			CarService.ReturnToPaddock(player)
		end)
	end
	sendRaceState(race)
	broadcastLobby()
end

local function endRound(race: Race)
	if race.State ~= "Racing" then
		return
	end
	race.State = "Results"
	race.Token += 1
	local final = race.Round >= race.RoundCount

	local sorted = sortRunners(race)
	local rows: { ResultRow } = {}
	local order: { number } = {}
	for position, runner in ipairs(sorted) do
		local points = if final and runner.Finished then (POINTS[position] or 0) else 0
		table.insert(rows, {
			UserId = runner.UserId,
			Name = runner.Name,
			Position = position,
			TotalTime = runner.TotalTime,
			Penalty = runner.Penalty,
			BestLap = runner.BestLap,
			Dnf = runner.Dnf,
			DnfReason = runner.DnfReason,
			Points = points,
		})
		table.insert(order, runner.UserId)
		if final and runner.Player.Parent then
			RecordService.AddRaceResult(runner.Player, if runner.Finished then position else 0, points)
		end
	end
	race.LastResults = rows
	race.GridOrder = order

	local nextAt = serverNow() + RESULTS_TIME
	sendRaceState(race)
	sendEvent(race, nil, "Results", {
		Round = race.Round,
		RoundName = roundName(race, race.Round),
		Final = final,
		NextRoundName = if final then nil else roundName(race, race.Round + 1),
		NextAt = nextAt,
		TrackId = race.TrackId,
		Rows = rows,
	})
	sendLive(race)
	broadcastLobby()

	local token = race.Token
	task.delay(RESULTS_TIME, function()
		if race.Token ~= token or races[race.Id] ~= race then
			return
		end
		if not final and #race.Members > 0 then
			startRound(race, race.Round + 1)
		else
			backToLobby(race)
		end
	end)
end

local function finishRunner(race: Race, runner: Runner, crossing: number)
	runner.Finished = true
	runner.RaceTime = crossing - (race.StartTime :: number)
	if runner.JokerCount == 0 then
		runner.Penalty += JOKER_MISSED_PENALTY
		sendEvent(race, runner.Player, "Penalty", { Reason = "joker", Seconds = JOKER_MISSED_PENALTY })
	end
	runner.TotalTime = (runner.RaceTime :: number) + runner.Penalty
	if not race.FinishDeadline then
		race.FinishDeadline = serverNow() + FINISH_WINDOW
		sendEvent(race, nil, "Chequered", { Winner = runner.Name, Deadline = race.FinishDeadline })
	end
	local position = 0
	for index, other in ipairs(sortRunners(race)) do
		if other == runner then
			position = index
		end
	end
	sendEvent(race, runner.Player, "Finished", { Position = position, TotalTime = runner.TotalTime, Penalty = runner.Penalty })
end

local function markDnf(race: Race, runner: Runner, reason: string)
	if runner.Finished or runner.Dnf then
		return
	end
	runner.Dnf = true
	runner.DnfReason = reason
end

local function checkRoundEnd(race: Race)
	if race.State ~= "Racing" then
		return
	end
	local now = serverNow()
	local deadline = race.FinishDeadline
	local timeout = race.Timeout
	local expired = (deadline ~= nil and now > deadline) or (timeout ~= nil and now > timeout)
	local done = true
	for _, runner in ipairs(race.Runners) do
		if not runner.Finished and not runner.Dnf then
			if expired then
				markDnf(race, runner, "hors délai")
			else
				done = false
			end
		end
	end
	if done then
		endRound(race)
	end
end

local function lightsOut(race: Race, token: number)
	if race.Token ~= token or race.State ~= "Countdown" then
		return
	end
	local now = serverNow()
	race.State = "Racing"
	race.StartTime = now
	race.Timeout = now + 90 + race.Laps * 150
	for _, runner in ipairs(race.Runners) do
		runner.LapStart = now
		if runner.Player.Parent then
			CarService.SetHeld(runner.Player, false)
		end
	end
	sendRaceState(race)
	sendEvent(race, nil, "Go", { StartTime = now })
end

startRound = function(race: Race, round: number)
	race.Token += 1
	local token = race.Token
	race.Round = round
	race.State = "Grid"
	race.AutoStartAt = nil
	race.LightsStart = nil
	race.StartTime = nil
	race.FinishDeadline = nil
	race.Timeout = nil

	-- Ordre de grille : tirage au sort, puis l'ordre de la manche précédente.
	local members = table.clone(race.Members)
	local previous = race.GridOrder
	if previous and round > 1 then
		local rank: { [number]: number } = {}
		for index, userId in ipairs(previous) do
			rank[userId] = index
		end
		table.sort(members, function(a, b)
			return (rank[a.UserId] or 99) < (rank[b.UserId] or 99)
		end)
	else
		local rng = Random.new()
		for i = #members, 2, -1 do
			local j = rng:NextInteger(1, i)
			members[i], members[j] = members[j], members[i]
		end
	end

	race.Runners = {}
	for slot, member in ipairs(members) do
		table.insert(race.Runners, {
			Player = member.Player,
			UserId = member.UserId,
			Name = member.Name,
			Slot = slot,
			GridPosition = nil,
			Location = nil,
			LastRaw = nil,
			Valid = 0,
			LastPosition = Vector3.zero,
			LastTime = 0,
			Laps = 0,
			LapStart = 0,
			LapTimes = {},
			BestLap = nil,
			LastLap = nil,
			JokerCount = 0,
			InJoker = false,
			JumpStart = false,
			Penalty = 0,
			Finished = false,
			RaceTime = nil,
			TotalTime = nil,
			Dnf = false,
			DnfReason = nil,
			Milestones = {},
			LastMilestone = -math.huge,
		})
	end
	sendRaceState(race)
	broadcastLobby()

	-- Mise en grille, en parallèle (chaque apparition attend le chargement de la zone).
	local pending = #race.Runners
	for _, runner in ipairs(race.Runners) do
		local player = runner.Player
		CarService.SetLocked(player, true)
		task.spawn(function()
			CarService.Spawn(player, race.Circuit:GridSlot(runner.Slot), {
				RaceId = race.Id,
				Contacts = race.Contacts,
				Held = true,
			})
			pending -= 1
			-- Parti de la course pendant le chargement : sa voiture n'a rien à faire sur la grille.
			if player.Parent and raceOf[player] ~= race then
				CarService.ReturnToPaddock(player)
			end
		end)
	end
	local waited = 0
	while pending > 0 and waited < SPAWN_TIMEOUT do
		waited += task.wait(0.1)
	end
	task.wait(GRID_SETTLE)
	if race.Token ~= token then
		return
	end

	-- Position de référence de chaque voiture pour les faux départs.
	for _, runner in ipairs(race.Runners) do
		local chassis = CarService.GetChassis(runner.Player)
		if chassis then
			runner.GridPosition = chassis.Position
		end
	end
	race.State = "Countdown"
	race.LightsStart = serverNow() + 0.5
	sendRaceState(race)
	broadcastLobby()

	local delay = 0.5 + LIGHT_COUNT * LIGHT_INTERVAL + Random.new():NextNumber(LIGHTS_OUT_MIN, LIGHTS_OUT_MAX)
	task.delay(delay, function()
		lightsOut(race, token)
	end)
end

local function startRace(race: Race)
	race.Round = 1
	race.RoundCount = if race.Format == "Event" then 2 else 1
	race.GridOrder = nil
	task.spawn(startRound, race, 1)
end

updateAutoStart = function(race: Race)
	if race.State ~= "Lobby" then
		return
	end
	local allReady = #race.Members >= MIN_PLAYERS
	for _, member in ipairs(race.Members) do
		if not member.Ready then
			allReady = false
		end
	end
	if allReady then
		if race.AutoStartAt == nil then
			race.Token += 1
			local token = race.Token
			race.AutoStartAt = serverNow() + AUTO_START_DELAY
			task.delay(AUTO_START_DELAY, function()
				if race.Token == token and race.State == "Lobby" and races[race.Id] == race then
					startRace(race)
				end
			end)
		end
	elseif race.AutoStartAt ~= nil then
		race.Token += 1
		race.AutoStartAt = nil
	end
end

local function deleteRace(race: Race)
	race.Token += 1
	races[race.Id] = nil
	local index = table.find(raceOrder, race.Id)
	if index then
		table.remove(raceOrder, index)
	end
end

local function removeMember(race: Race, player: Player)
	local index: number? = nil
	for i, member in ipairs(race.Members) do
		if member.Player == player then
			index = i
		end
	end
	if not index then
		return
	end
	table.remove(race.Members, index)
	raceOf[player] = nil

	local runner = runnerOf(race, player)
	if runner and race.State ~= "Lobby" and race.State ~= "Results" then
		markDnf(race, runner, "abandon")
	end
	-- Retour au paddock si la voiture est sur le circuit.
	if player.Parent then
		Remotes.RaceState:FireClient(player, nil)
		if race.State ~= "Lobby" then
			task.spawn(function()
				CarService.ReturnToPaddock(player)
			end)
		else
			CarService.SetLocked(player, false)
		end
	end

	if #race.Members == 0 then
		deleteRace(race)
		broadcastLobby()
		return
	end
	if race.HostUserId == player.UserId then
		race.HostUserId = race.Members[1].UserId
	end
	if race.State == "Lobby" then
		race.Token += 1
		race.AutoStartAt = nil
		updateAutoStart(race)
	elseif race.State == "Racing" then
		checkRoundEnd(race)
	end
	sendRaceState(race)
	broadcastLobby()
end

--------------------------------------------------------------------------------
-- Actions des joueurs
--------------------------------------------------------------------------------

local function addMember(race: Race, player: Player)
	table.insert(race.Members, {
		Player = player,
		UserId = player.UserId,
		Name = player.DisplayName,
		Ready = false,
	})
	raceOf[player] = race
end

local function onCreate(player: Player, payload: any)
	if raceOf[player] or type(payload) ~= "table" then
		return
	end
	if #raceOrder >= MAX_RACES then
		Remotes.RaceEvent:FireClient(player, "Error", { Message = "Trop de courses en même temps : rejoins-en une." })
		return
	end
	local trackId = payload.TrackId
	local circuit = if type(trackId) == "string" then Tracks.Get(trackId) else nil
	if not circuit then
		return
	end
	local laps = if type(payload.Laps) == "number" then math.clamp(math.floor(payload.Laps), MIN_LAPS, MAX_LAPS) else circuit.DefaultLaps
	local format: Format = if payload.Format == "Event" then "Event" else "Sprint"

	local id = tostring(nextRaceId)
	nextRaceId += 1
	local race: Race = {
		Id = id,
		TrackId = circuit.Id,
		Circuit = circuit,
		Laps = laps,
		Format = format,
		Contacts = payload.Contacts == true,
		HostUserId = player.UserId,
		Members = {},
		State = "Lobby",
		Round = 1,
		RoundCount = if format == "Event" then 2 else 1,
		Token = 0,
		AutoStartAt = nil,
		LightsStart = nil,
		StartTime = nil,
		FinishDeadline = nil,
		Timeout = nil,
		Runners = {},
		LastResults = nil,
		GridOrder = nil,
	}
	races[id] = race
	table.insert(raceOrder, id)
	addMember(race, player)
	sendRaceState(race)
	broadcastLobby()
end

local function onJoin(player: Player, payload: any)
	if raceOf[player] or type(payload) ~= "table" or type(payload.RaceId) ~= "string" then
		return
	end
	local race = races[payload.RaceId]
	if not race then
		return
	end
	if race.State ~= "Lobby" then
		Remotes.RaceEvent:FireClient(player, "Error", { Message = "Cette course a déjà commencé." })
		return
	end
	if #race.Members >= MAX_PLAYERS then
		Remotes.RaceEvent:FireClient(player, "Error", { Message = "Cette course est complète." })
		return
	end
	addMember(race, player)
	race.Token += 1
	race.AutoStartAt = nil
	updateAutoStart(race)
	sendRaceState(race)
	broadcastLobby()
end

local function onReady(player: Player, payload: any)
	local race = raceOf[player]
	if not race or race.State ~= "Lobby" then
		return
	end
	local member = memberOf(race, player)
	if not member then
		return
	end
	member.Ready = type(payload) == "table" and payload.Ready == true
	updateAutoStart(race)
	sendRaceState(race)
end

local function onStart(player: Player)
	local race = raceOf[player]
	if not race or race.State ~= "Lobby" or race.HostUserId ~= player.UserId then
		return
	end
	local minimum = if RunService:IsStudio() then 1 else MIN_PLAYERS
	if #race.Members < minimum then
		Remotes.RaceEvent:FireClient(player, "Error", { Message = string.format("Il faut au moins %d pilotes.", MIN_PLAYERS) })
		return
	end
	race.Token += 1
	race.AutoStartAt = nil
	startRace(race)
end

local function onLeave(player: Player)
	local race = raceOf[player]
	if race then
		removeMember(race, player)
	end
end

--------------------------------------------------------------------------------
-- Suivi des voitures
--------------------------------------------------------------------------------

local function trackRunner(race: Race, runner: Runner, now: number)
	local player = runner.Player
	local chassis = CarService.GetChassis(player)
	if not chassis then
		return
	end
	local car = chassis.Parent
	if not car or car:GetAttribute("RaceId") ~= race.Id then
		return -- pas encore recréée sur la grille
	end
	local circuit = race.Circuit
	local position = chassis.Position

	-- Faux départ : la voiture bouge avant l'extinction des feux.
	if race.State == "Countdown" then
		local grid = runner.GridPosition
		if grid and not runner.JumpStart and (position - grid).Magnitude > JUMP_START_DISTANCE then
			runner.JumpStart = true
			runner.Penalty += JUMP_START_PENALTY
			sendEvent(race, player, "Penalty", { Reason = "faux départ", Seconds = JUMP_START_PENALTY })
		end
		return
	end
	if runner.Finished or runner.Dnf then
		return
	end

	local location = circuit:Locate(position, runner.Location)
	local length = circuit.Length
	local lastRaw = runner.LastRaw
	if lastRaw == nil then
		-- Première mesure : la grille est derrière la ligne, avancement négatif.
		local progress = location.Progress
		runner.Valid = if progress > length / 2 then progress - length else progress
		runner.LastRaw = progress
		runner.LastPosition = position
		runner.LastTime = now
		runner.Location = location
		return
	end

	local elapsed = math.max(1e-3, now - runner.LastTime)
	local flat = Vector3.new(position.X - runner.LastPosition.X, 0, position.Z - runner.LastPosition.Z)
	local displacement = flat.Magnitude
	local delta = circuit:ProgressDelta(lastRaw, location.Progress)

	local maxDelta, minDelta
	if displacement > MAX_PLAUSIBLE_SPEED * elapsed + TELEPORT_MARGIN then
		-- Téléportation (remise en piste) : quasiment rien à gagner.
		maxDelta = TELEPORT_ALLOWANCE
		minDelta = -math.huge
	else
		local onTrack = math.abs(location.Lateral) <= location.Sample.HalfWidth + 4
		local ratio = if onTrack then ON_TRACK_RATIO else OFF_TRACK_RATIO
		maxDelta = displacement * ratio + PROGRESS_MARGIN
		minDelta = -(displacement * ON_TRACK_RATIO + PROGRESS_MARGIN)
	end
	local gained = math.clamp(delta, minDelta, maxDelta)

	local previousValid = runner.Valid
	runner.Valid += gained
	runner.LastRaw = location.Progress
	runner.LastPosition = position
	runner.LastTime = now
	runner.Location = location

	-- Joker : compté au milieu de la branche.
	if location.OnJoker then
		if location.JokerFraction >= JOKER_ZONE_MIN and location.JokerFraction <= JOKER_ZONE_MAX and not runner.InJoker then
			runner.InJoker = true
			runner.JokerCount += 1
			sendEvent(race, player, "Joker", { Count = runner.JokerCount })
		end
	else
		runner.InJoker = false
	end

	-- Points de mesure des écarts.
	local milestone = math.floor(runner.Valid / MILESTONE)
	if milestone > runner.LastMilestone then
		if runner.LastMilestone == -math.huge then
			runner.LastMilestone = milestone - 1
		end
		for k = runner.LastMilestone + 1, milestone do
			runner.Milestones[k] = now
		end
		runner.LastMilestone = milestone
	end

	-- Passages de ligne (interpolés entre les deux mesures).
	while runner.Laps < race.Laps do
		local line = (runner.Laps + 1) * length
		if not (previousValid < line and runner.Valid >= line) then
			break
		end
		local fraction = if runner.Valid > previousValid then (line - previousValid) / (runner.Valid - previousValid) else 1
		local crossing = (now - elapsed) + elapsed * math.clamp(fraction, 0, 1)
		local lapTime = crossing - runner.LapStart
		runner.Laps += 1
		runner.LapStart = crossing
		table.insert(runner.LapTimes, lapTime)
		runner.LastLap = lapTime
		local isBest = runner.BestLap == nil or lapTime < (runner.BestLap :: number)
		if isBest then
			runner.BestLap = lapTime
		end
		-- Le premier tour part arrêté de la grille : il ne compte pas pour le record.
		local record = false
		if runner.Laps > 1 then
			record = RecordService.SubmitLap(player, circuit.Key, math.floor(lapTime * 1000 + 0.5))
		end
		sendEvent(race, player, "Lap", { Lap = runner.Laps, Time = lapTime, Best = isBest, Record = record })
		if runner.Laps >= race.Laps then
			finishRunner(race, runner, crossing)
		end
	end
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function RaceService.Start()
	Remotes.RaceAction.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		local now = os.clock()
		if now - (lastActionAt[player] or 0) < ACTION_COOLDOWN then
			return
		end
		lastActionAt[player] = now
		if action == "Create" then
			onCreate(player, payload)
		elseif action == "Join" then
			onJoin(player, payload)
		elseif action == "Leave" or action == "Abandon" then
			onLeave(player)
		elseif action == "Ready" then
			onReady(player, payload)
		elseif action == "Start" then
			onStart(player)
		end
	end)

	-- Le menu d'un nouveau joueur affiche tout de suite les courses ouvertes.
	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(1)
		if player.Parent then
			Remotes.LobbyState:FireClient(player, lobbyList())
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local race = raceOf[player]
		if race then
			removeMember(race, player)
		end
		lastActionAt[player] = nil
	end)

	local sampleAccumulator = 0
	local liveAccumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sampleAccumulator += dt
		liveAccumulator += dt
		if sampleAccumulator >= SAMPLE_INTERVAL then
			sampleAccumulator = 0
			local now = serverNow()
			for _, race in pairs(races) do
				if race.State == "Countdown" or race.State == "Racing" then
					for _, runner in ipairs(race.Runners) do
						if runner.Player.Parent then
							trackRunner(race, runner, now)
						else
							markDnf(race, runner, "déconnecté")
						end
					end
					checkRoundEnd(race)
				end
			end
		end
		if liveAccumulator >= LIVE_INTERVAL then
			liveAccumulator = 0
			for _, race in pairs(races) do
				if race.State == "Countdown" or race.State == "Racing" then
					sendLive(race)
				end
			end
		end
	end)
end

return RaceService
