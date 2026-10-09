--!strict
--[[
	ChallengeService.luau
	Les défis qui font revenir : du jour et de la semaine.

	DÉFIS DU JOUR (Daily.luau) : leur progression est dans le profil (remise à
	zéro au changement de jour), avancée par DailyEvent : arrivées, spéciale
	sans remise en piste, dépassements (RaceService), points de style
	acceptés (StyleService). Chaque défi réussi rapporte de l'XP (DailyXp),
	sauvegardée par lots avec les autres compteurs.

	DÉFI DE LA SEMAINE (Weekly.luau) : la voiture lancée pour le défi porte
	l'attribut Weekly (clé de la semaine) ; StageService lui envoie son temps
	(WeeklyFinish). Il va dans le classement de la semaine (un
	OrderedDataStore par semaine : remis à zéro le lundi), et dans le meilleur
	temps de la semaine du profil -- pas dans le record habituel, ni son
	fantôme, ni ses médailles. La première fois de la semaine, il compte pour
	l'XP (WeeklyCompleted).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Weekly = require(ReplicatedStorage.Shared.Challenges.Weekly)
local Daily = require(ReplicatedStorage.Shared.Challenges.Daily)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local ProgressService = require(script.Parent.ProgressService)
local EconomyService = require(script.Parent.EconomyService)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)

local ChallengeService = {}

local WEEKLY_STORE_PREFIX = "RallyWeekly_" .. ProfileSchema.STAGE_ID .. "_"
local BOARD_SIZE = 10
local REFRESH_INTERVAL = 60 -- secondes (et au passage du lundi : nouvelle semaine)

--------------------------------------------------------------------------------
-- Défis du jour
--------------------------------------------------------------------------------

-- La progression du jour en cours (remise à zéro au changement de jour).
local function dailyStateOf(profile: ProfileSchema.Profile, day: Daily.Day): ProfileSchema.DailyState
	local state = profile.Daily
	if not state or state.Key ~= day.Key then
		state = { Key = day.Key, Progress = {}, Done = {}, Bonus = false }
		profile.Daily = state
	end
	return state :: ProfileSchema.DailyState
end

local function sendDaily(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
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
function ChallengeService.DailyEvent(player: Player, event: string, value: number)
	local profile = ProfileStore.Get(player)
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
	-- La progression du jour s'écrit avec la prochaine sauvegarde regroupée.
	local copy = ProfileSchema.CopyDaily(state)
	ProfileStore.Defer(player, "Daily", function(stored)
		stored.Daily = copy
	end)
	if xp > 0 then
		ProfileStore.AddCounter(player, "DailyXp", xp)
	end
	sendDaily(player, if #completed > 0 then { Completed = completed, AllDone = bonus } else nil)
	if #completed > 0 then
		EconomyService.Earn(player, Credits.REWARDS.DailyChallenge * #completed, "Défi du jour réussi")
	end
	if bonus then
		EconomyService.Earn(player, Credits.REWARDS.DailyBonus, "Les trois défis du jour")
		EconomyService.AddRolls(player, 1, "Les trois défis du jour")
	end
	if xp > 0 then
		ProgressService.Push(player, true)
	end
end

--------------------------------------------------------------------------------
-- Défi de la semaine
--------------------------------------------------------------------------------

local sessionWeekly: { [string]: { [number]: number } } = {} -- par clé de semaine
local weeklyEntries: { Boards.Entry } = {}
local weeklyKey = ""

local function weeklyStore(key: string): OrderedDataStore?
	return Stores.Ordered(WEEKLY_STORE_PREFIX .. key)
end

-- Ce qu'on envoie à un joueur : la semaine, sa contrainte, le classement, son temps.
local function weeklyPayload(player: Player): any
	local week = Weekly.Current()
	local profile = ProfileStore.Get(player)
	local mine = if profile and profile.Weekly and profile.Weekly.Key == week.Key then profile.Weekly.Ms else nil
	return {
		Key = week.Key,
		Modifier = week.Modifier.Id,
		CarClass = week.CarClass,
		EndsAt = week.EndsAt,
		Entries = if weeklyKey == week.Key then weeklyEntries else {},
		Mine = mine,
	}
end

function ChallengeService.SendWeekly(player: Player)
	if player.Parent then
		Remotes.WeeklyBoard:FireClient(player, weeklyPayload(player))
	end
end

local function refreshWeekly()
	local week = Weekly.Current()
	weeklyEntries = Boards.Merge(weeklyStore(week.Key), sessionWeekly[week.Key] or {}, BOARD_SIZE, "défi de la semaine")
	weeklyKey = week.Key
	for _, player in ipairs(Players:GetPlayers()) do
		ChallengeService.SendWeekly(player)
	end
end

local scheduleWeeklyRefresh = Boards.Debounced(2, refreshWeekly)

export type WeeklyResult = { IsBest: boolean, PreviousMs: number?, FirstOfWeek: boolean }

--[[
	Arrivée d'un passage du défi de la semaine `key` : classement de la semaine
	et meilleur temps de la semaine du joueur ; la première fois de la semaine,
	le défi compte comme terminé (XP). L'appelant renvoie ensuite la semaine
	au joueur (SendWeekly), une fois le résultat annoncé.
]]
function ChallengeService.WeeklyFinish(player: Player, ms: number, key: string): WeeklyResult?
	local profile = ProfileStore.Get(player)
	if not profile then
		return nil
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
		ProfileStore.Update(player.UserId, "défi de la semaine", function(stored)
			local storedWeekly = stored.Weekly
			if storedWeekly == nil or storedWeekly.Key ~= key then
				stored.WeeklyCompleted += 1
			elseif storedWeekly.Ms <= ms then
				return false
			end
			stored.Weekly = { Key = key, Ms = ms }
			return true
		end)
		Boards.SubmitLowest(weeklyStore(key), player.UserId, ms, "défi de la semaine")
		scheduleWeeklyRefresh()
	end
	return { IsBest = isBest, PreviousMs = previous, FirstOfWeek = not sameWeek }
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

function ChallengeService.Start()
	ProfileStore.OnLoaded(function(player)
		ChallengeService.SendWeekly(player)
		sendDaily(player)
	end)
	task.spawn(function()
		while true do
			refreshWeekly()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return ChallengeService
