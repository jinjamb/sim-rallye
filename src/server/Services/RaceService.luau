--!strict
--[[
	RaceService.luau
	Courses de rallycross : salles d'attente, grille, départ, suivi, résultats.

	CYCLE D'UNE COURSE
		Lobby     : salle d'attente, liée à une ZONE du paddock (un circuit par
		            zone, PaddockService). On la rejoint de deux façons :
		              - par le menu (« Rallycross », PaddockService) : on y reste
		                où qu'on soit, jusqu'à QUITTER ;
		              - en entrant dans la zone : en sortir fait quitter la salle.
		            1 à 6 joueurs : on peut courir seul. Compte à rebours dès le
		            1er pilote (PAD_COUNTDOWN), pour laisser les autres rejoindre,
		            raccourci quand la salle est pleine ; l'hôte (le premier
		            arrivé) peut lancer tout de suite et choisir tours, format,
		            contacts.
		Grid      : les voitures sont recréées sur la grille, retenues (attribut Held).
		Countdown : cinq feux rouges s'allument un à un, puis s'éteignent après un
		            délai aléatoire : c'est le départ. Bouger avant = faux départ.
		Racing    : suivi des tours, du joker, des positions.
		Results   : classement de la manche. Format "Qualif + Finale" : la finale
		            suit, grille dans l'ordre de la qualification. Puis tout le monde
		            revient au paddock À PIED, les trois premiers sur le podium ; la
		            salle est dissoute...
		REVANCHE  : ... sauf si quelqu'un a voté REVANCHE à l'écran des
		            résultats : la salle reste ouverte pour ceux qui ont voté,
		            mêmes réglages, départ REMATCH_COUNTDOWN secondes plus tard
		            (le temps du podium) ; les autres rentrent. Si tout le monde
		            vote, on n'attend pas la fin des résultats.

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

	COURSE EN SOLO : même déroulement, mais elle ne compte pas pour la carrière
	(points, victoires, podiums) : une victoire seul n'en est pas une. Les
	records du tour, eux, comptent.

	DÉPASSEMENTS : comparés deux à deux, sur l'avancement intégré (un pilote
	dépassé d'un tour reste derrière : le prendre d'un tour n'est pas un
	dépassement). Le nouvel ordre doit tenir OVERTAKE_CONFIRM secondes (pas de
	points pour deux voitures qui se chamaillent sur la ligne). Ils rapportent
	des points de style (StyleService.Add, progression), au plus
	MAX_PASSES_PER_PAIR fois par paire et par manche : deux amis qui
	s'échangent la place ne font pas fortune.

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
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local CarService = require(script.Parent.CarService)
local RecordService = require(script.Parent.RecordService)
local StyleService = require(script.Parent.StyleService)
local ChallengeService = require(script.Parent.ChallengeService)
local EconomyService = require(script.Parent.EconomyService)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)

local RaceService = {}

local MIN_PLAYERS = 1 -- on peut courir seul
local CAREER_MIN_RUNNERS = 2 -- en dessous, la course ne compte pas pour la carrière
local MAX_PLAYERS = 6
local MAX_RACES = 8
local MIN_LAPS, MAX_LAPS = 2, 8
local ACTION_COOLDOWN = 0.25

local PAD_COUNTDOWN = 20 -- départ 20 s après l'arrivée du 2e pilote
local STUDIO_COUNTDOWN = 10 -- dans Studio, seul : on n'attend personne
local FULL_COUNTDOWN = 5 -- salle pleine : départ dans 5 s au plus
local RETURN_TIMEOUT = 10 -- attente maximale du retour au paddock avant le podium
local FINISHED_RETURN_DELAY = 6 -- après l'arrivée, retour à pied au paddock
local SPAWN_TIMEOUT = 15 -- attente maximale de la mise en grille
local GRID_SETTLE = 2.5 -- les voitures se posent avant les feux
local LIGHT_COUNT = 5
local LIGHT_INTERVAL = 0.7
local LIGHTS_OUT_MIN, LIGHTS_OUT_MAX = 0.4, 1.8 -- délai aléatoire après le 5e feu
local FINISH_WINDOW = 30 -- après le vainqueur, les autres ont 30 s pour finir
local RESULTS_TIME = 12
local REMATCH_COUNTDOWN = 25 -- départ de la revanche : podium, puis grille
local PODIUM_DELAY = 3 -- le temps que chacun soit revenu au paddock

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
local OVERTAKE_CONFIRM = 2 -- s : la nouvelle position doit tenir
local OVERTAKE_POINTS = 2000 -- points de style par dépassement (10 XP)
local MAX_PASSES_PER_PAIR = 2 -- dépassements récompensés par paire, sens et manche

local POINTS = { 10, 8, 6, 4, 2, 1 }

type RaceState = "Lobby" | "Grid" | "Countdown" | "Racing" | "Results"
type Format = "Sprint" | "Event"

type Member = {
	Player: Player,
	UserId: number,
	Name: string,
	-- Inscrit par le menu : reste dans la salle hors de la zone du paddock.
	Pinned: boolean,
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

	Overtakes: number, -- dépassements récompensés dans cette manche (défis du jour)

	-- Après l'arrivée : ramené à pied au paddock (Returned), sauf s'il a choisi
	-- de rester regarder la course (Watching).
	Watching: boolean,
	Returned: boolean,
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

-- Deux pilotes : qui est devant (A = le premier de la clé), depuis quand.
type PairState = { Ahead: boolean, Since: number, Stable: boolean, PassesA: number, PassesB: number }

type Race = {
	Id: string,
	PadId: string, -- zone du paddock d'où vient la course
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
	Pairs: { [string]: PairState }, -- dépassements, par paire de pilotes
	-- Écran des résultats de la dernière manche : votes pour la revanche.
	RematchOpen: boolean,
	RematchVotes: { [number]: boolean },
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
		table.insert(members, { UserId = member.UserId, Name = member.Name })
	end
	return {
		Id = race.Id,
		PadId = race.PadId,
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
		MinPlayers = MIN_PLAYERS,
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
local closeEvent: (Race) -> ()

local function deleteRace(race: Race)
	race.Token += 1
	races[race.Id] = nil
	local index = table.find(raceOrder, race.Id)
	if index then
		table.remove(raceOrder, index)
	end
end

--[[
	Fin de la course : tout le monde revient à pied au paddock, la salle est
	dissoute. Après la dernière manche, les trois premiers montent sur le
	podium (PodiumHandler, branché par Main.server.luau sur PaddockService).
]]
local function dissolve(race: Race, podium: { ResultRow }?)
	deleteRace(race)
	local members = table.clone(race.Members)
	race.Members = {}
	local pending = #members
	for _, member in ipairs(members) do
		local player = member.Player
		raceOf[player] = nil
		-- Déjà revenu au paddock après son arrivée : on ne le redéplace pas.
		local runner = runnerOf(race, player)
		local alreadyBack = runner ~= nil and runner.Returned
		task.spawn(function()
			if player.Parent then
				Remotes.RaceState:FireClient(player, nil)
				if not alreadyBack then
					CarService.ReturnToPaddock(player)
				end
			end
			pending -= 1
		end)
	end
	broadcastLobby()

	if podium and #podium > 0 then
		task.spawn(function()
			local waited = 0
			while pending > 0 and waited < RETURN_TIMEOUT do
				waited += task.wait(0.1)
			end
			local players: { Player } = {}
			for _, member in ipairs(members) do
				if member.Player.Parent then
					table.insert(players, member.Player)
				end
			end
			RaceService.PodiumHandler(players, podium)
		end)
	end
end

-- Cérémonie du podium : (pilotes de la course, trois premiers arrivés).
RaceService.PodiumHandler = function(_players: { Player }, _podium: { ResultRow }) end

-- Crédits d'une arrivée en finale (ou course simple) : seul, une petite somme.
local function raceCredits(position: number, counts: boolean): number
	local rewards = Credits.REWARDS
	if not counts then
		return rewards.SoloRace
	end
	local amount = rewards.RaceFinish
	if position <= 3 then
		amount += rewards.RacePodium
	end
	if position == 1 then
		amount += rewards.RaceWin
	end
	return amount
end

local function endRound(race: Race)
	if race.State ~= "Racing" then
		return
	end
	race.State = "Results"
	race.Token += 1
	local final = race.Round >= race.RoundCount
	-- Seul en piste : pas de points, la carrière n'en tient pas compte.
	local counts = #race.Runners >= CAREER_MIN_RUNNERS

	local sorted = sortRunners(race)
	local rows: { ResultRow } = {}
	local order: { number } = {}
	for position, runner in ipairs(sorted) do
		local points = if final and counts and runner.Finished then (POINTS[position] or 0) else 0
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
		if final and counts and runner.Player.Parent then
			RecordService.AddRaceResult(runner.Player, if runner.Finished then position else 0, points)
		end
		if final and runner.Finished and runner.Player.Parent then
			EconomyService.Earn(runner.Player, raceCredits(position, counts), "Course terminée")
		end
	end
	race.LastResults = rows
	race.GridOrder = order
	-- Dernière manche : on peut voter pour la revanche jusqu'à la fin des résultats.
	race.RematchOpen = final
	race.RematchVotes = {}

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
		elseif final then
			closeEvent(race)
		else
			dissolve(race, nil)
		end
	end)
end

-- Pilote arrivé, ramené à pied au paddock ; il reste membre de la course
-- (classement en direct, résultats, podium).
local function returnRunner(runner: Runner)
	if runner.Returned or not runner.Player.Parent then
		return
	end
	runner.Returned = true
	local player = runner.Player
	task.spawn(function()
		CarService.ReturnToPaddock(player)
	end)
end

local function finishRunner(race: Race, runner: Runner, crossing: number)
	runner.Finished = true
	if runner.Player.Parent then
		ChallengeService.DailyEvent(runner.Player, "RaceFinished", 1)
	end
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
	sendEvent(race, runner.Player, "Finished", {
		Position = position,
		TotalTime = runner.TotalTime,
		Penalty = runner.Penalty,
		ReturnIn = FINISHED_RETURN_DELAY,
	})
	-- Retour au paddock, sauf s'il a choisi entre-temps de regarder la course.
	task.delay(FINISHED_RETURN_DELAY, function()
		if raceOf[runner.Player] == race and table.find(race.Runners, runner) and not runner.Watching then
			returnRunner(runner)
		end
	end)
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
	race.Pairs = {}
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
			Overtakes = 0,
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
			Watching = false,
			Returned = false,
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

local function minimumPlayers(): number
	return MIN_PLAYERS
end

local function scheduleStart(race: Race, at: number)
	race.Token += 1
	local token = race.Token
	race.AutoStartAt = at
	task.delay(math.max(0, at - serverNow()), function()
		if race.Token == token and race.State == "Lobby" and races[race.Id] == race then
			startRace(race)
		end
	end)
end

--[[
	Compte à rebours de la salle : il démarre quand il y a assez de pilotes, et
	ne repart pas de zéro à chaque nouvel arrivant (ceux qui attendent depuis le
	début ne patientent pas plus). Salle pleine : départ dans FULL_COUNTDOWN au plus.
]]
updateAutoStart = function(race: Race)
	if race.State ~= "Lobby" then
		return
	end
	local now = serverNow()
	if #race.Members < minimumPlayers() then
		if race.AutoStartAt ~= nil then
			race.Token += 1
			race.AutoStartAt = nil
		end
		return
	end
	local countdown = if RunService:IsStudio() and #race.Members == 1 then STUDIO_COUNTDOWN else PAD_COUNTDOWN
	local current = race.AutoStartAt
	if current == nil then
		scheduleStart(race, now + countdown)
	elseif #race.Members >= MAX_PLAYERS and current - now > FULL_COUNTDOWN then
		scheduleStart(race, now + FULL_COUNTDOWN)
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

local function addMember(race: Race, player: Player, pinned: boolean)
	table.insert(race.Members, {
		Player = player,
		UserId = player.UserId,
		Name = player.DisplayName,
		Pinned = pinned,
	})
	raceOf[player] = race
end

local function createRace(padId: string, circuit: Circuit.Circuit, host: Player): Race
	local id = tostring(nextRaceId)
	nextRaceId += 1
	local race: Race = {
		Id = id,
		PadId = padId,
		TrackId = circuit.Id,
		Circuit = circuit,
		Laps = circuit.DefaultLaps,
		Format = "Sprint",
		Contacts = true,
		HostUserId = host.UserId,
		Members = {},
		State = "Lobby",
		Round = 1,
		RoundCount = 1,
		Token = 0,
		AutoStartAt = nil,
		LightsStart = nil,
		StartTime = nil,
		FinishDeadline = nil,
		Timeout = nil,
		Runners = {},
		LastResults = nil,
		GridOrder = nil,
		Pairs = {},
		RematchOpen = false,
		RematchVotes = {},
	}
	races[id] = race
	table.insert(raceOrder, id)
	return race
end

--[[
	Rejoint la salle d'attente d'un circuit, ou en ouvre une si elle est pleine
	ou déjà partie (plusieurs courses peuvent tourner sur le même circuit).
	`pinned` : par le menu (on reste inscrit hors de la zone) ; sinon, entrée
	dans la zone du paddock (PaddockService), qu'il ne faut pas quitter.
]]
function RaceService.JoinPad(player: Player, padId: string, pinned: boolean?): boolean
	if raceOf[player] then
		return false
	end
	local circuit = Tracks.Get(padId)
	if not circuit then
		return false
	end
	local race: Race? = nil
	for _, id in ipairs(raceOrder) do
		local candidate = races[id]
		if candidate and candidate.PadId == padId and candidate.State == "Lobby" and #candidate.Members < MAX_PLAYERS then
			race = candidate
			break
		end
	end
	if not race then
		if #raceOrder >= MAX_RACES then
			Remotes.RaceEvent:FireClient(player, "Error", { Message = "Trop de courses en même temps : patiente un peu." })
			return false
		end
		race = createRace(padId, circuit, player)
	end
	local joined = race :: Race
	addMember(joined, player, pinned == true)
	updateAutoStart(joined)
	sendRaceState(joined)
	broadcastLobby()
	return true
end

-- Zone de la salle d'attente du joueur, s'il l'a rejointe PAR LA ZONE et
-- attend un départ (nil sinon) : en sortir fait quitter la salle.
function RaceService.GetLobbyPad(player: Player): string?
	local race = raceOf[player]
	if race and race.State == "Lobby" then
		for _, member in ipairs(race.Members) do
			if member.Player == player and not member.Pinned then
				return race.PadId
			end
		end
	end
	return nil
end

-- Circuit de la salle d'attente du joueur (nil s'il n'attend pas de départ).
function RaceService.GetLobbyTrack(player: Player): string?
	local race = raceOf[player]
	return if race and race.State == "Lobby" then race.TrackId else nil
end

--[[
	Le joueur choisit autre chose dans le menu (spéciale, essais libres, autre
	circuit) : il quitte sa salle d'attente. Refusé en pleine course (on passe
	par "Abandonner") ; une fois arrivé et revenu au paddock, il est libre.
	Renvoie false et la raison si c'est refusé.
]]
function RaceService.ReleaseForMode(player: Player): (boolean, string?)
	local race = raceOf[player]
	if not race then
		return true, nil
	end
	if race.State == "Lobby" then
		removeMember(race, player)
		return true, nil
	end
	local runner = runnerOf(race, player)
	if runner and runner.Returned then
		return true, nil
	end
	return false, "Tu es en course : abandonne d'abord (menu), ou attends l'arrivée."
end

function RaceService.IsInRace(player: Player): boolean
	return raceOf[player] ~= nil
end

-- En piste : course partie, et pas encore revenu au paddock après son arrivée.
function RaceService.IsRacing(player: Player): boolean
	local race = raceOf[player]
	if not race or race.State == "Lobby" then
		return false
	end
	local runner = runnerOf(race, player)
	return runner == nil or not runner.Returned
end

--[[
	Demande de retour au paddock (touche H, menu, bouton tactile) :
		"free"    : hors course ou en salle d'attente, retour normal ;
		"handled" : arrivé, ramené au paddock en restant membre de la course ;
		"blocked" : en pleine course, on passe par "Abandonner".
]]
function RaceService.PaddockRequest(player: Player): string
	local race = raceOf[player]
	if not race or race.State == "Lobby" then
		return "free"
	end
	local runner = runnerOf(race, player)
	if runner and (runner.Finished or race.State == "Results") then
		runner.Watching = false
		returnRunner(runner)
		return "handled"
	end
	return "blocked"
end

--[[
	Fin de l'épreuve (après la dernière manche) : revanche pour ceux qui l'ont
	votée, sinon dissolution. Dans les deux cas, podium.
]]
closeEvent = function(race: Race)
	race.Token += 1
	race.RematchOpen = false
	local podium: { ResultRow } = {}
	for _, row in ipairs(race.LastResults or {}) do
		if not row.Dnf and #podium < 3 then
			table.insert(podium, row)
		end
	end
	local voters: { [number]: boolean } = {}
	local voterCount = 0
	for _, member in ipairs(race.Members) do
		if race.RematchVotes[member.UserId] and member.Player.Parent then
			voters[member.UserId] = true
			voterCount += 1
		end
	end
	if voterCount == 0 then
		dissolve(race, podium)
		return
	end

	-- Ceux qui n'ont pas voté rentrent (et verront le podium quand même).
	local everyone: { Player } = {}
	for _, member in ipairs(table.clone(race.Members)) do
		table.insert(everyone, member.Player)
		if not voters[member.UserId] then
			removeMember(race, member.Player)
		end
	end
	-- Les autres reviennent au paddock à pied et attendent la revanche, inscrits
	-- comme par le menu (ils peuvent se promener).
	for _, member in ipairs(race.Members) do
		member.Pinned = true
		local runner = runnerOf(race, member.Player)
		if not (runner and runner.Returned) then
			local player = member.Player
			task.spawn(function()
				CarService.ReturnToPaddock(player)
			end)
		end
	end
	race.State = "Lobby"
	race.Round = 1
	race.RoundCount = if race.Format == "Event" then 2 else 1
	race.Runners = {}
	race.Pairs = {}
	race.GridOrder = nil
	race.LastResults = nil
	race.StartTime = nil
	race.LightsStart = nil
	race.FinishDeadline = nil
	race.Timeout = nil
	race.RematchVotes = {}
	scheduleStart(race, serverNow() + REMATCH_COUNTDOWN)
	sendRaceState(race)
	sendEvent(race, nil, "RematchStart", { Count = voterCount })
	broadcastLobby()

	if #podium > 0 then
		task.delay(PODIUM_DELAY, function()
			local present: { Player } = {}
			for _, player in ipairs(everyone) do
				if player.Parent then
					table.insert(present, player)
				end
			end
			RaceService.PodiumHandler(present, podium)
		end)
	end
end

-- Vote pour la revanche (écran des résultats de la dernière manche).
local function onRematch(player: Player)
	local race = raceOf[player]
	if not race or race.State ~= "Results" or not race.RematchOpen then
		return
	end
	-- Un second clic retire le vote.
	if race.RematchVotes[player.UserId] then
		race.RematchVotes[player.UserId] = nil
	else
		race.RematchVotes[player.UserId] = true
	end
	local votes, voters = 0, {}
	for _, member in ipairs(race.Members) do
		if race.RematchVotes[member.UserId] then
			votes += 1
			table.insert(voters, member.UserId)
		end
	end
	sendEvent(race, nil, "Rematch", { Votes = votes, Members = #race.Members, Voters = voters })
	-- Tout le monde est partant : inutile d'attendre la fin des résultats.
	if votes == #race.Members then
		closeEvent(race)
	end
end

-- Arrivé, il préfère rester regarder la course plutôt que rentrer au paddock.
local function onWatch(player: Player)
	local race = raceOf[player]
	local runner = race and runnerOf(race, player)
	if runner and runner.Finished and not runner.Returned then
		runner.Watching = true
	end
end

-- Sortie de la zone : quitte la salle d'attente (sans effet une fois la course partie).
function RaceService.LeavePad(player: Player)
	local race = raceOf[player]
	if race and race.State == "Lobby" then
		removeMember(race, player)
	end
end

export type PadStatus = { Waiting: number, Max: number, AutoStartAt: number?, Racing: number }

-- Pour le panneau de la zone : pilotes en attente, départ, pilotes en course.
function RaceService.GetPadStatus(padId: string): PadStatus
	local status: PadStatus = { Waiting = 0, Max = MAX_PLAYERS, AutoStartAt = nil, Racing = 0 }
	for _, id in ipairs(raceOrder) do
		local race = races[id]
		if race and race.PadId == padId then
			if race.State == "Lobby" then
				if #race.Members >= status.Waiting then
					status.Waiting = #race.Members
					status.AutoStartAt = race.AutoStartAt
				end
			else
				status.Racing += #race.Members
			end
		end
	end
	return status
end

-- Réglages de la course, par l'hôte, avant le départ.
local function onSettings(player: Player, payload: any)
	local race = raceOf[player]
	if not race or race.State ~= "Lobby" or race.HostUserId ~= player.UserId or type(payload) ~= "table" then
		return
	end
	if type(payload.Laps) == "number" and payload.Laps == payload.Laps then
		race.Laps = math.clamp(math.floor(payload.Laps), MIN_LAPS, MAX_LAPS)
	end
	if payload.Format == "Event" or payload.Format == "Sprint" then
		race.Format = payload.Format
		race.RoundCount = if race.Format == "Event" then 2 else 1
	end
	if type(payload.Contacts) == "boolean" then
		race.Contacts = payload.Contacts
	end
	sendRaceState(race)
	broadcastLobby()
end

local function onStart(player: Player)
	local race = raceOf[player]
	if not race or race.State ~= "Lobby" or race.HostUserId ~= player.UserId then
		return
	end
	if #race.Members < minimumPlayers() then
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
		-- Le premier tour part arrêté de la grille : il ne compte ni pour le
		-- record ni pour les médailles (Medals.luau : seuils d'un tour lancé).
		local record = false
		local medal: number? = nil
		if runner.Laps > 1 then
			local lapMs = math.floor(lapTime * 1000 + 0.5)
			local limits = Medals.ForCircuit(race.TrackId, length)
			local before = Medals.TierOf(RecordService.GetLapBest(player, circuit.Key), limits)
			record = RecordService.SubmitLap(player, circuit.Key, lapMs)
			local after = Medals.TierOf(lapMs, limits)
			if record and after > before then
				medal = after -- nouvelle médaille sur ce circuit
			end
			if RunService:IsStudio() then
				print(string.format("[Médailles] %s, tour %d : %.2f s, %.1f km/h de moyenne", race.TrackId, runner.Laps, lapTime, Medals.AverageKmh(length, lapMs)))
			end
		end
		sendEvent(race, player, "Lap", { Lap = runner.Laps, Time = lapTime, Best = isBest, Record = record, Medal = medal })
		if runner.Laps >= race.Laps then
			finishRunner(race, runner, crossing)
		end
	end
end

--[[
	Dépassements : pour chaque paire de pilotes encore en course, l'ordre sur
	l'avancement. Un changement d'ordre qui tient OVERTAKE_CONFIRM secondes
	est un dépassement : points de style pour celui qui passe, message pour
	les deux.
]]
local function checkOvertakes(race: Race, now: number)
	local runners = race.Runners
	for i = 1, #runners - 1 do
		for j = i + 1, #runners do
			local a, b = runners[i], runners[j]
			if a.Finished or b.Finished or a.Dnf or b.Dnf then
				continue
			end
			local key = a.UserId .. ":" .. b.UserId
			local ahead = a.Valid > b.Valid
			local state = race.Pairs[key]
			if not state then
				race.Pairs[key] = { Ahead = ahead, Since = now, Stable = ahead, PassesA = 0, PassesB = 0 }
				continue
			end
			if ahead ~= state.Ahead then
				state.Ahead = ahead
				state.Since = now
			end
			if state.Ahead ~= state.Stable and now - state.Since >= OVERTAKE_CONFIRM then
				state.Stable = state.Ahead
				local passer, passed = a, b
				if not state.Ahead then
					passer, passed = b, a
				end
				local passes = if passer == a then state.PassesA else state.PassesB
				local points = if passes < MAX_PASSES_PER_PAIR then OVERTAKE_POINTS else 0
				if passer == a then
					state.PassesA += 1
				else
					state.PassesB += 1
				end
				if points > 0 and passer.Player.Parent then
					StyleService.Add(passer.Player, points)
					-- Défi du jour : dépassements dans UNE course.
					passer.Overtakes += 1
					ChallengeService.DailyEvent(passer.Player, "Overtakes", passer.Overtakes)
				end
				sendEvent(race, passer.Player, "Overtake", { Name = passed.Name, Points = points })
				sendEvent(race, passed.Player, "Overtaken", { Name = passer.Name })
			end
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
		if action == "Leave" or action == "Abandon" then
			onLeave(player)
		elseif action == "Start" then
			onStart(player)
		elseif action == "Settings" then
			onSettings(player, payload)
		elseif action == "Watch" then
			onWatch(player)
		elseif action == "Rematch" then
			onRematch(player)
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
					if race.State == "Racing" then
						checkOvertakes(race, now)
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
