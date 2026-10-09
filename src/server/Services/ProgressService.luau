--!strict
--[[
	ProgressService.luau
	La progression du pilote (Progression.luau) : XP, niveau, licence et
	cosmétiques débloqués. Elle n'est pas sauvegardée telle quelle : elle se
	DÉDUIT du profil (médailles, statistiques, spéciales terminées, points de
	style, défis, école). Elle est recalculée et envoyée au joueur à chaque
	changement (Push), avec les nouveautés à annoncer (niveau gagné,
	cosmétique débloqué).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)

local ProgressService = {}

local lastProgress: { [Player]: Progression.Snapshot } = {}

-- Palier de médaille par tracé : "stage" pour la spéciale, l'id du circuit sinon.
local function medalsOf(profile: ProfileSchema.Profile): { [string]: number }
	local medals: { [string]: number } = {}
	local stage = profile.Records[ProfileSchema.STAGE_ID]
	medals.stage = Medals.TierOf(if stage then stage.Ms else nil, Medals.ForStage())
	for _, id in ipairs(Tracks.List()) do
		local circuit = Tracks.Get(id)
		if circuit then
			medals[id] = Medals.TierOf(profile.Laps[circuit.Key], Medals.ForCircuit(id, circuit.Length))
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
