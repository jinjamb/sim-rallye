--!strict
--[[
	ProfileSchema.luau
	La forme du profil sauvegardé d'un joueur, et sa remise en forme
	(Sanitize) : tout ce qui sort du DataStore passe par ici, qu'il soit
	ancien, incomplet ou abîmé. Ajouter un champ au profil, c'est l'ajouter
	au type Profile, à Empty et à Sanitize -- et nulle part ailleurs.

	IDENTITÉ D'UN TRACÉ : dérivée de sa longueur. Si le tracé change, les temps
	repartent de zéro au lieu de mélanger deux parcours différents.

	PAR CATÉGORIE DE VOITURE (CarClasses.luau) : les records de la spéciale
	et des circuits ont une clé par catégorie (CarClasses.RecordKey : la
	Rally2 garde les clés d'avant les catégories), et les réglages un jeu
	par catégorie (Setups ; l'ancien champ Setup devient celui de la Rally2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Lessons = require(ReplicatedStorage.Shared.School.Lessons)

local ProfileSchema = {}

-- Clé de la spéciale dans les records du profil (Rally2 ; StageKey pour une catégorie).
ProfileSchema.STAGE_ID = "s1_" .. tostring(math.floor(StageTrack.GetLength()))

function ProfileSchema.StageKey(classId: string): string
	return CarClasses.RecordKey(ProfileSchema.STAGE_ID, classId)
end

-- Clé d'un circuit dans les records du tour (Circuit.Key, par catégorie).
function ProfileSchema.LapKey(trackKey: string, classId: string): string
	return CarClasses.RecordKey(trackKey, classId)
end

ProfileSchema.GHOST_MAX_FRAMES = 3000 -- 5 min à 10 Hz
ProfileSchema.GHOST_VALUES_PER_FRAME = 6 -- x, y, z, rx, ry, rz
ProfileSchema.MAX_RECEIPTS = 50 -- achats Robux retenus (Roblox ne rejoue que les récents)

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
	Records: { [string]: StageRecord }, -- par clé de spéciale (StageKey)
	Setups: { [string]: CarSetup.Setup }, -- réglages, par catégorie
	Livery: Livery.Livery,
	Laps: { [string]: number }, -- meilleur tour (ms) par circuit (LapKey)
	Stats: Stats,
	StageRuns: number, -- spéciales terminées (temps validés)
	Style: number, -- points de style cumulés
	Weekly: { Key: string, Ms: number }?, -- meilleur temps au défi de la semaine
	WeeklyCompleted: number, -- semaines où le défi a été terminé
	Daily: DailyState?, -- défis du jour : progression du jour en cours
	DailyXp: number, -- XP gagnée aux défis du jour, cumulée
	BonusXp: number, -- XP en plus gagnée pendant les événements double XP (XpEvents.luau)
	Lessons: { [string]: number }, -- meilleure médaille (1 à 4) par leçon de l'école
	Credits: number, -- monnaie du jeu (Credits.luau)
	Owned: { [string]: boolean }, -- objets possédés (Catalog.luau), hors objets gratuits
	Equipped: { [string]: string }, -- objet porté, par sorte (Catalog.Kind -> id)
	Receipts: { string }, -- derniers achats Robux accordés (jamais deux fois)
	Rolls: number, -- tirages disponibles (Rolls.luau)
	RollPity: number, -- tirages depuis le dernier objet Usine ou plus (garantie)
	Pass: PassState?, -- Rallye Pass de la saison en cours (Pass.luau)
	DriftKing: { Key: string, Score: number }?, -- meilleure combinaison de la semaine
	TeamId: string?, -- écurie (Teams.luau)
	UseTeamColors: boolean, -- porte les couleurs de son écurie
	Achievements: { [string]: number }, -- trophées obtenus (Achievements.luau) : date (os.time)
	Badges: { [string]: number }, -- badge Roblox déjà donné, par trophée (son BadgeId)
}

export type PassState = {
	Key: string, -- saison ("s1")
	Xp: number, -- XP gagnée pendant la saison
	Premium: boolean, -- voie premium achetée pour cette saison
	FreeUpTo: number, -- dernier palier dont la récompense gratuite a été donnée
	PremiumUpTo: number, -- idem, voie premium
}

-- Compteurs ajoutés par lots (ProfileStore.AddCounter) : des sommes, qu'on
-- peut ajouter à ce qu'un autre serveur a écrit sans rien écraser.
export type Counter = "StageRuns" | "Style" | "DailyXp" | "BonusXp" | "Credits" | "Rolls"

function ProfileSchema.EmptyStats(): Stats
	return { Races = 0, Wins = 0, Podiums = 0, Points = 0 }
end

function ProfileSchema.Empty(userId: number): Profile
	return {
		Records = {},
		Setups = {},
		Livery = Livery.Default(userId),
		Laps = {},
		Stats = ProfileSchema.EmptyStats(),
		StageRuns = 0,
		Style = 0,
		Weekly = nil,
		WeeklyCompleted = 0,
		Daily = nil,
		DailyXp = 0,
		BonusXp = 0,
		Lessons = {},
		Credits = 0,
		Owned = {},
		Equipped = {},
		Receipts = {},
		Rolls = 0,
		RollPity = 0,
		Pass = nil,
		DriftKing = nil,
		TeamId = nil,
		UseTeamColors = false,
		Achievements = {},
		Badges = {},
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
	profile.BonusXp = count(data.BonusXp)
	if type(data.Lessons) == "table" then
		for id, tier in pairs(data.Lessons) do
			if type(id) == "string" and Lessons.Get(id) then
				profile.Lessons[id] = math.clamp(count(tier), 0, 4)
			end
		end
	end
	profile.Daily = sanitizeDaily(data.Daily)
	profile.Credits = count(data.Credits)
	profile.Rolls = count(data.Rolls)
	profile.RollPity = count(data.RollPity)
	profile.TeamId = if type(data.TeamId) == "string" and #data.TeamId <= 64 then data.TeamId else nil
	profile.UseTeamColors = data.UseTeamColors == true
	-- Trophées : gardés même s'ils ont quitté la liste (un exploit ne se perd pas).
	if type(data.Achievements) == "table" then
		for id, at in pairs(data.Achievements) do
			if type(id) == "string" and type(at) == "number" then
				profile.Achievements[id] = count(at)
			end
		end
	end
	if type(data.Badges) == "table" then
		for id, badgeId in pairs(data.Badges) do
			if type(id) == "string" and type(badgeId) == "number" then
				profile.Badges[id] = count(badgeId)
			end
		end
	end
	local drift = data.DriftKing
	if type(drift) == "table" and type(drift.Key) == "string" and type(drift.Score) == "number" and drift.Score > 0 then
		profile.DriftKing = { Key = drift.Key, Score = math.floor(drift.Score) }
	end
	local pass = data.Pass
	if type(pass) == "table" and type(pass.Key) == "string" then
		profile.Pass = {
			Key = pass.Key,
			Xp = count(pass.Xp),
			Premium = pass.Premium == true,
			FreeUpTo = count(pass.FreeUpTo),
			PremiumUpTo = count(pass.PremiumUpTo),
		}
	end
	-- Objets : gardés même s'ils ont quitté le catalogue (un achat ne se perd pas).
	if type(data.Owned) == "table" then
		for id, owned in pairs(data.Owned) do
			if type(id) == "string" and owned == true then
				profile.Owned[id] = true
			end
		end
	end
	if type(data.Equipped) == "table" then
		for kind, id in pairs(data.Equipped) do
			if type(kind) == "string" and type(id) == "string" then
				profile.Equipped[kind] = id
			end
		end
	end
	if type(data.Receipts) == "table" then
		for _, receipt in ipairs(data.Receipts) do
			if type(receipt) == "string" and #profile.Receipts < ProfileSchema.MAX_RECEIPTS then
				table.insert(profile.Receipts, receipt)
			end
		end
	end
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
	if type(data.Setups) == "table" then
		for classId, setup in pairs(data.Setups) do
			if CarClasses.Exists(classId) then
				profile.Setups[classId] = CarSetup.Sanitize(setup, classId)
			end
		end
	end
	-- Avant les catégories : un seul jeu de réglages, celui de la Rally2.
	if profile.Setups[CarClasses.DEFAULT] == nil and type(data.Setup) == "table" then
		profile.Setups[CarClasses.DEFAULT] = CarSetup.Sanitize(data.Setup, CarClasses.DEFAULT)
	end
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
