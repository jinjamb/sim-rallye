--!strict
--[[
	AchievementService.luau
	Les trophées (Achievements.luau) et leurs badges Roblox.

	Un trophée obtenu est gardé dans le profil (Achievements : id -> date).
	Son badge Roblox est donné à part, dès que le trophée a un BadgeId : le
	profil retient quel badge a été donné (Badges : id -> BadgeId), pour ne
	le redemander à Roblox que s'il ne l'a pas encore été (badge créé après
	coup, ou échec passager de BadgeService). On réessaie à chaque connexion.

	Ne dépend que des données (et des annonces) : les autres services
	l'appellent (Award, CheckProgress) sans risque de cycle.

	Les trophées les plus rares (Announce) s'annoncent à tout le serveur.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Achievements = require(ReplicatedStorage.Shared.Progression.Achievements)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local AnnounceService = require(script.Parent.AnnounceService)

local AchievementService = {}

-- Badges en cours de demande, par joueur (une seule demande à la fois par badge).
local inFlight: { [Player]: { [string]: boolean } } = {}
local warnedStudio = false

local function sendState(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	Remotes.Achievements:FireClient(player, profile.Achievements, news)
end

-- Donne le badge Roblox du trophée, s'il en a un et qu'il n'a pas déjà été donné.
local function awardBadge(player: Player, id: string)
	local achievement = Achievements.Get(id)
	local profile = ProfileStore.Get(player)
	if not achievement or not profile or achievement.BadgeId == 0 then
		return
	end
	local badgeId = achievement.BadgeId
	if profile.Badges[id] == badgeId then
		return
	end
	local busy = inFlight[player]
	if not busy then
		busy = {}
		inFlight[player] = busy
	end
	if busy[id] then
		return
	end
	busy[id] = true
	task.spawn(function()
		local ok, result = pcall(function()
			if BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				return true
			end
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		busy[id] = nil
		if ok and result == true then
			profile.Badges[id] = badgeId
			ProfileStore.Defer(player, "badge:" .. id, function(stored)
				stored.Badges[id] = badgeId
			end)
		elseif not ok and not (RunService:IsStudio() and warnedStudio) then
			warnedStudio = RunService:IsStudio()
			warn("[Badges] « " .. achievement.Name .. " » non donné :", result)
		end
	end)
end

-- Les trophées les plus rares s'annoncent à tout le serveur.
local function announceToServer(player: Player, id: string)
	local achievement = Achievements.Get(id)
	if achievement and achievement.Announce then
		AnnounceService.Send("Trophy", player.DisplayName, "obtient le trophée « " .. achievement.Name .. " »")
	end
end

-- Le trophée `id` est obtenu : gardé, annoncé (sauf `quiet`), et son badge donné.
local function earn(player: Player, id: string, quiet: boolean): boolean
	local profile = ProfileStore.Get(player)
	if not profile or profile.Achievements[id] or not Achievements.Get(id) then
		return false
	end
	local at = os.time()
	profile.Achievements[id] = at
	ProfileStore.Defer(player, "achievement:" .. id, function(stored)
		if not stored.Achievements[id] then
			stored.Achievements[id] = at
		end
	end)
	awardBadge(player, id)
	if not quiet then
		sendState(player, { New = { id } })
		announceToServer(player, id)
	end
	return true
end

-- Trophée décerné par un événement (roi du drift, écurie fondée...).
function AchievementService.Award(player: Player, id: string)
	earn(player, id, false)
end

--[[
	Les trophées déduits du profil, après chaque progression
	(ProgressService). `announce` : faux au chargement du profil, où les
	trophées d'avant arrivent en silence (Roblox signale tout de même un
	nouveau badge).
]]
function AchievementService.CheckProgress(player: Player, snapshot: Progression.Snapshot, announce: boolean)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local facts: Achievements.Facts = {
		Level = snapshot.Level,
		Races = profile.Stats.Races,
		Wins = profile.Stats.Wins,
		Podiums = profile.Stats.Podiums,
		StageRuns = profile.StageRuns,
		WeeklyCompleted = profile.WeeklyCompleted,
		Medals = snapshot.Medals,
		Lessons = profile.Lessons,
	}
	local new = {}
	for _, id in ipairs(Achievements.Reached(facts)) do
		if earn(player, id, true) then
			table.insert(new, id)
		end
	end
	if #new > 0 or not announce then
		sendState(player, if announce then { New = new } else nil)
	end
	if announce then
		for _, id in ipairs(new) do
			announceToServer(player, id)
		end
	end
end

function AchievementService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		-- Badges des trophées déjà obtenus mais pas encore donnés.
		-- La liste part avec la première progression (CheckProgress).
		for id in pairs(profile.Achievements) do
			awardBadge(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		inFlight[player] = nil
	end)
end

return AchievementService
