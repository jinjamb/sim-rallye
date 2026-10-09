--!strict
--[[
	Daily.luau
	Les défis du jour : trois petits objectifs, renouvelés chaque jour à
	minuit (UTC, l'horloge des serveurs Roblox), les mêmes pour tous.

	Tirés au sort dans la liste ci-dessous à partir du numéro du jour : tous
	les serveurs tirent les mêmes sans se parler. Tous se font seul (le
	rallycross se court seul), en compétition : spéciale chronométrée, défi
	de la semaine ou course (comme les points de style).

	SUIVI PAR LE SERVEUR (RecordService.DailyEvent) : il sait déjà les
	arrivées, les dépassements, les points de style acceptés ; le client lui
	dit en plus les remises en piste, le temps en l'air d'un saut et le
	multiplicateur d'une combinaison.
		Count : on additionne (3 sauts, 3 spéciales, 15 000 points...).
		Max   : on garde la meilleure valeur (une combinaison de 3 000 points,
		        2 dépassements dans UNE course...).

	RÉCOMPENSE : XP par défi réussi, et un bonus pour les trois
	(Progression.luau : DailyXp).
]]

local Daily = {}

export type Kind = "Count" | "Max"

export type Challenge = {
	Id: string,
	Event: string, -- l'événement qui le fait avancer
	Kind: Kind,
	Goal: number,
	Text: string,
}

Daily.POOL = {
	{ Id = "jumps", Event = "LongJump", Kind = "Count", Goal = 3, Text = "Fais 3 sauts de plus d'1 s" },
	{ Id = "clean", Event = "CleanStage", Kind = "Count", Goal = 1, Text = "Termine une spéciale sans remise en piste" },
	{ Id = "overtakes", Event = "Overtakes", Kind = "Max", Goal = 2, Text = "Fais 2 dépassements dans une course" },
	{ Id = "stages", Event = "StageRun", Kind = "Count", Goal = 3, Text = "Termine 3 spéciales" },
	{ Id = "races", Event = "RaceFinished", Kind = "Count", Goal = 2, Text = "Termine 2 courses de rallycross" },
	{ Id = "drift", Event = "DriftCombo", Kind = "Max", Goal = 3000, Text = "Un dérapage de 3 000 points en une combinaison" },
	{ Id = "combo", Event = "DriftMultiplier", Kind = "Max", Goal = 4, Text = "Une combinaison au ×4" },
	{ Id = "style", Event = "Style", Kind = "Count", Goal = 15000, Text = "Gagne 15 000 points de style" },
	{ Id = "weekly", Event = "WeeklyRun", Kind = "Count", Goal = 1, Text = "Termine le défi de la semaine" },
} :: { Challenge }

Daily.PER_DAY = 3
Daily.XP = 100 -- par défi réussi
Daily.BONUS_XP = 100 -- les trois du jour

local DAY = 86400

export type Day = { Index: number, Key: string, Challenges: { Challenge }, EndsAt: number }

function Daily.At(time: number): Day
	local index = math.floor(time / DAY)
	-- Mélange (Fisher-Yates) déterministe : graine = numéro du jour.
	local order = {}
	for i = 1, #Daily.POOL do
		order[i] = i
	end
	local random = Random.new(index * 104729 + 3)
	for i = #order, 2, -1 do
		local j = random:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local challenges = {}
	for i = 1, Daily.PER_DAY do
		table.insert(challenges, Daily.POOL[order[i]])
	end
	return {
		Index = index,
		Key = "d" .. tostring(index),
		Challenges = challenges,
		EndsAt = (index + 1) * DAY,
	}
end

function Daily.Current(): Day
	return Daily.At(os.time())
end

return Daily
