--!strict
--[[
	ProfileSchema.luau
	La forme du profil sauvegardé d'un joueur, et sa remise en forme
	(Sanitize) : tout ce qui sort du DataStore passe par ici, qu'il soit
	ancien, incomplet ou abîmé. Ajouter un champ au profil, c'est l'ajouter
	au type Profile, à Empty et à Sanitize -- et nulle part ailleurs.

	IDENTITÉ D'UN TRACÉ : dérivée de sa longueur. Si le tracé change, les temps
	repartent de zéro au lieu de mélanger deux parcours différents.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Lessons = require(ReplicatedStorage.Shared.School.Lessons)

local ProfileSchema = {}

-- Clé de la spéciale dans les records du profil.
ProfileSchema.STAGE_ID = "s1_" .. tostring(math.floor(StageTrack.GetLength()))

ProfileSchema.GHOST_MAX_FRAMES = 3000 -- 5 min à 10 Hz
ProfileSchema.GHOST_VALUES_PER_FRAME = 6 -- x, y, z, rx, ry, rz

export type Ghost = { Rate: number, Frames: { number } }
export type StageRecord = { Ms: number, Ghost: Ghost? }
export type Stats = { Races: number, Wins: number, Podiums: number, Points: number }

export type DailyState = {
	Key: string, -- jour (Daily.luau)
	Progress: { [string]: number }, -- par défi
	Done: { [string]: boolean },
	Bonus: boolean, -- bonus des trois défis déjà donné
}

export type Profile = {
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

-- Compteurs ajoutés par lots (ProfileStore.AddCounter) : des sommes, qu'on
-- peut ajouter à ce qu'un autre serveur a écrit sans rien écraser.
export type Counter = "StageRuns" | "Style" | "DailyXp"

function ProfileSchema.EmptyStats(): Stats
	return { Races = 0, Wins = 0, Podiums = 0, Points = 0 }
end

function ProfileSchema.Empty(userId: number): Profile
	return {
		Records = {},
		Setup = CarSetup.Default(),
		Livery = Livery.Default(userId),
		Laps = {},
		Stats = ProfileSchema.EmptyStats(),
		StageRuns = 0,
		Style = 0,
		Weekly = nil,
		WeeklyCompleted = 0,
		Daily = nil,
		DailyXp = 0,
		Lessons = {},
	}
end

-- Entier positif ou nul (0 pour tout le reste).
function ProfileSchema.Count(value: any): number
	return if type(value) == "number" and value == value and value >= 0 then math.floor(value) else 0
end
local count = ProfileSchema.Count

function ProfileSchema.SanitizeGhost(input: any): Ghost?
	if type(input) ~= "table" or type(input.Rate) ~= "number" or type(input.Frames) ~= "table" then
		return nil
	end
	local rate = input.Rate
	if rate < 1 or rate > 30 then
		return nil
	end
	local perFrame = ProfileSchema.GHOST_VALUES_PER_FRAME
	local frameCount = #input.Frames
	if frameCount < perFrame * 2
		or frameCount % perFrame ~= 0
		or frameCount > ProfileSchema.GHOST_MAX_FRAMES * perFrame then
		return nil
	end
	local frames = table.create(frameCount)
	for i = 1, frameCount do
		local value = input.Frames[i]
		if type(value) ~= "number" or value ~= value or math.abs(value) > 1e6 then
			return nil
		end
		-- Deux décimales suffisent largement : moins de place dans le DataStore.
		frames[i] = math.floor(value * 100 + 0.5) / 100
	end
	return { Rate = rate, Frames = frames }
end

function ProfileSchema.CopyDaily(state: DailyState): DailyState
	return { Key = state.Key, Progress = table.clone(state.Progress), Done = table.clone(state.Done), Bonus = state.Bonus }
end

local function sanitizeDaily(daily: any): DailyState?
	if type(daily) ~= "table" or type(daily.Key) ~= "string" then
		return nil
	end
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
	return state
end

function ProfileSchema.Sanitize(data: any, userId: number): Profile
	local profile = ProfileSchema.Empty(userId)
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
	profile.Daily = sanitizeDaily(data.Daily)
	local weekly = data.Weekly
	if type(weekly) == "table" and type(weekly.Key) == "string" and type(weekly.Ms) == "number" and weekly.Ms > 0 then
		profile.Weekly = { Key = weekly.Key, Ms = weekly.Ms }
	end
	profile.Livery = Livery.Sanitize(data.Livery, userId)
	if type(data.Records) == "table" then
		for stageId, record in pairs(data.Records) do
			if type(stageId) == "string" and type(record) == "table" and type(record.Ms) == "number" then
				profile.Records[stageId] = { Ms = record.Ms, Ghost = ProfileSchema.SanitizeGhost(record.Ghost) }
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

return ProfileSchema
