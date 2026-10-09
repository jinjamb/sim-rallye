--!strict
--[[
	Achievements.luau
	Les trophées : les grands exploits d'un pilote. Chacun peut être relié à
	un BADGE ROBLOX, visible sur le profil du joueur.

	DEUX SORTES :
		- déduits du profil (Check) : vérifiés à chaque progression, et au
		  chargement du profil (un exploit d'avant les trophées compte) ;
		- décernés par un événement (sans Check) : le service concerné appelle
		  AchievementService.Award (roi du drift, écurie fondée...).

	BADGES : chaque badge se crée dans le Creator Dashboard de l'expérience
	(Engagement > Badges). Son identifiant va dans BadgeId. Tant qu'il vaut
	0, le trophée existe dans le jeu (menu CARRIÈRE) mais aucun badge n'est
	donné. Une fois l'identifiant renseigné, les pilotes qui ont déjà le
	trophée reçoivent le badge à leur prochaine connexion.
]]

local Tracks = require(script.Parent.Parent.Tracks.Tracks)
local Lessons = require(script.Parent.Parent.School.Lessons)

local Achievements = {}

-- Ce que le serveur sait du pilote, et dont se déduisent les trophées.
export type Facts = {
	Level: number,
	Races: number,
	Wins: number,
	Podiums: number,
	StageRuns: number,
	WeeklyCompleted: number,
	Medals: { [string]: number }, -- palier (0 à 4) par tracé : "stage", ou l'id du circuit
	Lessons: { [string]: number }, -- palier (0 à 4) par leçon de l'école
}

export type Achievement = {
	Id: string,
	Name: string,
	Description: string,
	BadgeId: number, -- badge Roblox (0 : pas encore créé)
	Check: ((Facts) -> boolean)?, -- nil : décerné par un événement
}

local GOLD, PLATINUM = 3, 4

-- Tous les tracés à médailles : la spéciale et chaque circuit.
local function allTracks(): { string }
	local list = { "stage" }
	for _, id in ipairs(Tracks.List()) do
		table.insert(list, id)
	end
	return list
end

local function everyMedal(facts: Facts, tier: number): boolean
	for _, track in ipairs(allTracks()) do
		if (facts.Medals[track] or 0) < tier then
			return false
		end
	end
	return true
end

local function anyMedal(facts: Facts, tier: number): boolean
	for _, reached in pairs(facts.Medals) do
		if reached >= tier then
			return true
		end
	end
	return false
end

Achievements.LIST = {
	{
		Id = "first_stage",
		Name = "Premier chrono",
		Description = "Terminer une spéciale chronométrée.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.StageRuns >= 1
		end,
	},
	{
		Id = "first_race",
		Name = "Baptême du rallycross",
		Description = "Terminer une course de rallycross.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Races >= 1
		end,
	},
	{
		Id = "first_podium",
		Name = "Premier podium",
		Description = "Finir dans les trois premiers d'une course.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Podiums >= 1
		end,
	},
	{
		Id = "first_win",
		Name = "Première victoire",
		Description = "Gagner une course de rallycross.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Wins >= 1
		end,
	},
	{
		Id = "wins_25",
		Name = "Habitué de la plus haute marche",
		Description = "Gagner 25 courses.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Wins >= 25
		end,
	},
	{
		Id = "first_platinum",
		Name = "Platine",
		Description = "Décrocher une médaille de platine.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return anyMedal(facts, PLATINUM)
		end,
	},
	{
		Id = "all_gold",
		Name = "Grand chelem d'or",
		Description = "La médaille d'or sur la spéciale et sur chaque circuit.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return everyMedal(facts, GOLD)
		end,
	},
	{
		Id = "all_platinum",
		Name = "Intouchable",
		Description = "La médaille de platine sur la spéciale et sur chaque circuit.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return everyMedal(facts, PLATINUM)
		end,
	},
	{
		Id = "school_gold",
		Name = "Major de promo",
		Description = "L'or ou mieux à toutes les leçons de l'école de pilotage.",
		BadgeId = 0,
		Check = function(facts: Facts)
			for _, lesson in ipairs(Lessons.LIST) do
				if (facts.Lessons[lesson.Id] or 0) < GOLD then
					return false
				end
			end
			return true
		end,
	},
	{
		Id = "weekly_first",
		Name = "Défi relevé",
		Description = "Terminer un défi de la semaine.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.WeeklyCompleted >= 1
		end,
	},
	{
		Id = "level_10",
		Name = "Licence nationale",
		Description = "Atteindre le niveau 10.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Level >= 10
		end,
	},
	{
		Id = "level_22",
		Name = "Licence élite",
		Description = "Atteindre le niveau 22.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Level >= 22
		end,
	},
	{
		Id = "level_30",
		Name = "Légende du rallye",
		Description = "Atteindre le niveau 30, le plus haut.",
		BadgeId = 0,
		Check = function(facts: Facts)
			return facts.Level >= 30
		end,
	},
	-- Décernés par un événement (AchievementService.Award).
	{
		Id = "drift_king",
		Name = "Roi du drift",
		Description = "Être en tête du classement Roi du drift de la semaine.",
		BadgeId = 0,
	},
	{
		Id = "team_founder",
		Name = "Patron d'écurie",
		Description = "Fonder une écurie.",
		BadgeId = 0,
	},
	{
		Id = "legend_roll",
		Name = "Main en or",
		Description = "Tirer un objet de rareté Légende.",
		BadgeId = 0,
	},
	{
		Id = "pass_complete",
		Name = "Saison bouclée",
		Description = "Atteindre le dernier palier du Rallye Pass.",
		BadgeId = 0,
	},
} :: { Achievement }

local byId: { [string]: Achievement } = {}
for _, achievement in ipairs(Achievements.LIST) do
	byId[achievement.Id] = achievement
end

function Achievements.Get(id: string): Achievement?
	return byId[id]
end

-- Les trophées déduits du profil que `facts` remplit.
function Achievements.Reached(facts: Facts): { string }
	local reached = {}
	for _, achievement in ipairs(Achievements.LIST) do
		local check = achievement.Check
		if check and check(facts) then
			table.insert(reached, achievement.Id)
		end
	end
	return reached
end

return Achievements
