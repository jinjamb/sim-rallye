--!strict
--[[
	ProgressService.luau
	La progression du pilote (Progression.luau) : XP, niveau, licence et
	cosmétiques débloqués. Elle n'est pas sauvegardée telle quelle : elle se
	DÉDUIT du profil (médailles, statistiques, spéciales terminées, points de
	style, défis, école). Elle est recalculée et envoyée au joueur à chaque
	changement (Push), avec les nouveautés à annoncer (niveau gagné,
	cosmétique débloqué).

	Un niveau gagné ou une nouvelle médaille rapportent aussi des crédits
	(Credits.luau), et un niveau un tirage (Rolls.luau), une fois : à la
	transition, pendant la partie. Au chargement, ce qui est déjà acquis ne
	rapporte rien.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local EconomyService = require(script.Parent.EconomyService)
local PassService = require(script.Parent.PassService)

local ProgressService = {}

local lastProgress: { [Player]: Progression.Snapshot } = {}

--[[
	Palier de médaille par tracé : "stage" pour la spéciale, l'id du circuit
	sinon. Le meilleur des catégories de voitures (chacune a ses seuils) :
	changer de voiture ne fait pas regagner l'XP d'une médaille déjà acquise.
]]
local function medalsOf(profile: ProfileSchema.Profile): { [string]: number }
	local medals: { [string]: number } = { stage = 0 }
	for _, class in ipairs(CarClasses.LIST) do
		local stage = profile.Records[ProfileSchema.StageKey(class.Id)]
		medals.stage = math.max(medals.stage, Medals.TierOf(if stage then stage.Ms else nil, Medals.ForStage(class.Id)))
		for _, id in ipairs(Tracks.List()) do
			local circuit = Tracks.Get(id)
			if circuit then
				local lap = profile.Laps[ProfileSchema.LapKey(circuit.Key, class.Id)]
				medals[id] = math.max(medals[id] or 0, Medals.TierOf(lap, Medals.ForCircuit(id, circuit.Length, class.Id)))
			end
		end
	end
	return medals
end

function ProgressService.SnapshotOf(profile: ProfileSchema.Profile): Progression.Snapshot
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

-- Appelée quand le niveau change (licence affichée sur la voiture) :
-- branchée par Main.server.luau sur CarService.
ProgressService.Changed = function(_player: Player, _snapshot: Progression.Snapshot) end

-- Crédits d'un niveau gagné et des nouvelles médailles.
local function rewardTransition(player: Player, previous: Progression.Snapshot, snapshot: Progression.Snapshot)
	local levels = snapshot.Level - previous.Level
	if levels > 0 then
		EconomyService.Earn(player, Credits.REWARDS.LevelUp * levels, "Niveau " .. snapshot.Level)
		-- Un tirage par niveau gagné (Rolls.luau).
		EconomyService.AddRolls(player, levels, "Niveau " .. snapshot.Level)
	end
	local medalCredits = 0
	for track, tier in pairs(snapshot.Medals) do
		for reached = (previous.Medals[track] or 0) + 1, tier do
			medalCredits += Credits.REWARDS.Medal[reached] or 0
		end
	end
	if medalCredits > 0 then
		EconomyService.Earn(player, medalCredits, "Nouvelle médaille")
	end
end

--[[
	Recalcule la progression et l'envoie au joueur. `announce` : signaler un
	niveau gagné ou un cosmétique débloqué (pas au chargement du profil).
]]
function ProgressService.Push(player: Player, announce: boolean)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	local snapshot = ProgressService.SnapshotOf(profile)
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
	if announce and previous then
		rewardTransition(player, previous, snapshot)
		-- L'XP gagnée compte aussi pour le Rallye Pass de la saison.
		PassService.AddXp(player, snapshot.Xp - previous.Xp)
	end
	if not previous or previous.Level ~= snapshot.Level then
		ProgressService.Changed(player, snapshot)
	end
end

-- Dernière progression envoyée (nil avant le chargement du profil).
function ProgressService.Get(player: Player): Progression.Snapshot?
	return lastProgress[player]
end

-- Spéciales terminées et points de style : comptés, puis la progression suit.
function ProgressService.AddCounters(player: Player, stageRuns: number, style: number)
	if not ProfileStore.Get(player) then
		return
	end
	ProfileStore.AddCounter(player, "StageRuns", stageRuns)
	ProfileStore.AddCounter(player, "Style", style)
	ProgressService.Push(player, true)
end

function ProgressService.Start()
	ProfileStore.OnLoaded(function(player)
		ProgressService.Push(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastProgress[player] = nil
	end)
end

return ProgressService
