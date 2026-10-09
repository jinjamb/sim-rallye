--!strict
--[[
	StageService.luau
	Chrono officiel de la spéciale, mesuré par le serveur.

	On ne croit jamais un temps envoyé par un client (n'importe qui peut
	envoyer "0:12.00"). Le serveur suit lui-même chaque voiture le long du
	tracé, 10 fois par seconde (StageTrack.Locate, le même calcul que le chrono
	du client), et détecte départ, arrivée et raccourcis. Le passage des lignes
	est interpolé entre deux mesures : la précision est de l'ordre du
	centième, et le délai réseau, identique au départ et à l'arrivée, s'annule.
	Limite honnête : la physique tourne chez le client (il possède sa voiture).
	Un tricheur déterminé peut donc rouler "trop vite" ; le serveur rejette tout
	ce qui dépasse une vitesse plausible, tout bond le long du tracé (raccourci,
	téléportation) et tout temps trop court pour la distance.

	Pas de chrono pour les voitures engagées dans une course de rallycross
	(attribut RaceId : RaceService s'en charge), ni pour celles de l'école de
	pilotage (attribut Lesson). Une voiture lancée pour le défi de la semaine
	(attribut Weekly) a son propre classement (ChallengeService).

	À l'arrivée : le record (RecordService), le fantôme attendu (GhostService),
	le résultat au joueur (RunValidated), la progression et les défis du jour.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local RecordService = require(script.Parent.RecordService)
local GhostService = require(script.Parent.GhostService)
local ChallengeService = require(script.Parent.ChallengeService)
local ProgressService = require(script.Parent.ProgressService)

local StageService = {}

local SAMPLE_INTERVAL = 0.1 -- secondes entre deux mesures de position
local MAX_PLAUSIBLE_SPEED = 250 -- studs/s (~250 km/h) : au-delà, ce n'est pas de la conduite
local JUMP_MARGIN = 25 -- studs de tolérance (à-coup réseau, remise en piste)
local RESTART_BACKWARD = 150 -- recul le long du tracé qui signifie "retour au départ"
local START_LATERAL_TOLERANCE = StageTrack.ROAD_WIDTH / 2 + 8
-- Après l'arrivée, une combinaison de style finie sur la ligne compte encore.
local STYLE_GRACE = 5 -- secondes

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

local runs: { [Player]: Run } = {}

-- Passage chronométré en cours (ou fini depuis moins de STYLE_GRACE s) :
-- les points de style comptent (StyleService).
function StageService.IsInTimedRun(player: Player): boolean
	local run = runs[player]
	return run ~= nil and os.clock() < run.StyleUntil
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

-- Une spéciale terminée (habituelle ou défi) : les défis du jour qui en dépendent.
local function stageFinished(player: Player, clean: boolean, weekly: boolean)
	ChallengeService.DailyEvent(player, "StageRun", 1)
	if clean then
		ChallengeService.DailyEvent(player, "CleanStage", 1)
	end
	if weekly then
		ChallengeService.DailyEvent(player, "WeeklyRun", 1)
	end
end

local function onWeeklyFinish(player: Player, ms: number, key: string, clean: boolean)
	local result = ChallengeService.WeeklyFinish(player, ms, key)
	if not result then
		return
	end
	Remotes.RunValidated:FireClient(player, {
		Valid = true,
		Ms = ms,
		Weekly = true,
		WeeklyBest = result.IsBest,
		PreviousMs = result.PreviousMs,
	})
	ProgressService.AddCounters(player, 1, 0)
	ChallengeService.SendWeekly(player)
	stageFinished(player, clean, true)
end

-- `clean` : pas de remise en piste pendant le passage.
local function onFinish(player: Player, ms: number, clean: boolean)
	if not ProfileStore.Get(player) then
		return
	end
	-- Défi de la semaine : son propre classement, pas le record habituel.
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	local weeklyKey = if car then car:GetAttribute("Weekly") else nil
	if type(weeklyKey) == "string" then
		onWeeklyFinish(player, ms, weeklyKey, clean)
		return
	end
	local result = RecordService.StageFinish(player, ms)
	if not result then
		return
	end
	if result.IsBest then
		GhostService.Expect(player, ms)
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
		PersonalBest = result.IsBest,
		PreviousMs = result.PreviousMs,
	})
	-- Une spéciale de plus (et peut-être une médaille) : la progression suit.
	ProgressService.AddCounters(player, 1, 0)
	stageFinished(player, clean, false)
end

local function onInvalid(player: Player, reason: string)
	Remotes.RunValidated:FireClient(player, { Valid = false, Reason = reason })
end

-- Une mesure de chaque voiture : départ, arrivée, raccourcis.
local function sample(now: number, finishDistance: number, startDistance: number)
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
end

function StageService.Start()
	ProfileStore.OnLoaded(function(player)
		runs[player] = { Running = false, StartTime = 0, LastProgress = nil, LastTime = 0, StyleUntil = 0, Recovered = false }
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		runs[player] = nil
	end)

	-- Remise en piste pendant la spéciale : le passage n'est plus « propre ».
	Remotes.Recovered.OnServerEvent:Connect(function(player: Player)
		local run = runs[player]
		if run and run.Running then
			run.Recovered = true
		end
	end)

	local finishDistance = StageTrack.GetFinishDistance()
	local startDistance = StageTrack.START_DISTANCE
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		accumulator = 0
		sample(os.clock(), finishDistance, startDistance)
	end)
end

return StageService
