--!strict
--[[
	Championships.luau
	Les rallyes du mode championnat : plusieurs spéciales enchaînées, courues
	l'une après l'autre (une seule tentative chacune), au TEMPS CUMULÉ.

	RÈGLES (ChampionshipService) :
		- les spéciales se courent dans l'ordre ; la suivante est lancée
		  quelques secondes après l'arrivée (la liaison) ;
		- un retour au départ ou un passage refusé (raccourci) coûte
		  RESTART_PENALTY au cumul, et la spéciale se recourt ;
		- on peut quitter un rallye et le reprendre plus tard, là où on
		  l'avait laissé (il est gardé dans le profil) ; ou l'abandonner ;
		- le temps total fait le classement du rallye, par catégorie de
		  voiture (comme les spéciales), et rapporte crédits et XP.

	RALLYE DE LA SEMAINE : ses spéciales et leur météo changent chaque semaine
	(tirées de la semaine, Weekly.luau) ; son classement repart de zéro.

	La météo de chaque spéciale est fixée par le rallye (Weather.luau) :
	« Dynamic » donne des averses différentes à chaque passage.
]]

local Stages = require(script.Parent.Parent.Stage.Stages)
local Weekly = require(script.Parent.Parent.Challenges.Weekly)

local Championships = {}

Championships.RESTART_PENALTY = 30 -- secondes ajoutées au cumul
Championships.LIAISON_TIME = 8 -- secondes entre l'arrivée et le départ de la suivante
Championships.WEEKLY_ID = "semaine"
local WEEKLY_STAGE_COUNT = 4

export type Leg = { Stage: string, Weather: string } -- Weather : Weather.Mode
export type Championship = {
	Id: string,
	Name: string,
	Description: string,
	Legs: { Leg },
	Credits: number, -- à l'arrivée du rallye
	Xp: number,
	Weekly: boolean, -- le rallye de la semaine (spéciales tirées chaque semaine)
	Key: string, -- clé du classement : l'id, ou l'id et la semaine
}

type Definition = { Id: string, Name: string, Description: string, Legs: { Leg }, Credits: number, Xp: number }

local DEFINITIONS: { Definition } = {
	{
		Id = "cote",
		Name = "Rallye de la Côte",
		Description = "Trois spéciales d'asphalte, de la mer aux vignes puis au col.",
		Legs = {
			{ Stage = "corniche", Weather = "Dry" },
			{ Stage = "vignes", Weather = "Dry" },
			{ Stage = "col", Weather = "Dynamic" },
		},
		Credits = 300,
		Xp = 150,
	},
	{
		Id = "hiver",
		Name = "Rallye des Neiges",
		Description = "Trois spéciales sur la neige et le verglas, du grand nord au col.",
		Legs = {
			{ Stage = "laponie", Weather = "Dry" },
			{ Stage = "givre", Weather = "Dry" },
			{ Stage = "neige", Weather = "Dry" },
		},
		Credits = 300,
		Xp = 150,
	},
	{
		Id = "terre",
		Name = "Rallye des Terres",
		Description = "Trois spéciales de terre : garrigue, causses et forêt, sous les averses.",
		Legs = {
			{ Stage = "garrigue", Weather = "Dry" },
			{ Stage = "causses", Weather = "Dynamic" },
			{ Stage = "foret", Weather = "Dynamic" },
		},
		Credits = 300,
		Xp = 150,
	},
	{
		Id = "tour",
		Name = "Grand Tour",
		Description = "Cinq spéciales, toutes les surfaces, pluie comprise : le rallye complet.",
		Legs = {
			{ Stage = "bocage", Weather = "Dry" },
			{ Stage = "foret", Weather = "Dynamic" },
			{ Stage = "col", Weather = "Rain" },
			{ Stage = "garrigue", Weather = "Dry" },
			{ Stage = "laponie", Weather = "Dry" },
		},
		Credits = 600,
		Xp = 300,
	},
}

local WEEKLY_WEATHERS = { "Dry", "Dry", "Dynamic", "Rain" }

-- Le rallye de la semaine `index` : WEEKLY_STAGE_COUNT spéciales différentes et leur météo.
local function weeklyChampionship(week: Weekly.Week): Championship
	local random = Random.new(week.Index * 6151 + 29)
	local pool = table.clone(Stages.List())
	local legs: { Leg } = {}
	for _ = 1, math.min(WEEKLY_STAGE_COUNT, #pool) do
		local stage = table.remove(pool, random:NextInteger(1, #pool)) :: string
		table.insert(legs, { Stage = stage, Weather = WEEKLY_WEATHERS[random:NextInteger(1, #WEEKLY_WEATHERS)] })
	end
	return {
		Id = Championships.WEEKLY_ID,
		Name = "Rallye de la semaine",
		Description = "Quatre spéciales et leur météo, tirées chaque semaine. Classement remis à zéro le lundi.",
		Legs = legs,
		Credits = 450,
		Xp = 200,
		Weekly = true,
		Key = Championships.WEEKLY_ID .. "_" .. week.Key,
	}
end

local function fromDefinition(definition: Definition): Championship
	return {
		Id = definition.Id,
		Name = definition.Name,
		Description = definition.Description,
		Legs = definition.Legs,
		Credits = definition.Credits,
		Xp = definition.Xp,
		Weekly = false,
		Key = definition.Id,
	}
end

-- Tous les rallyes : celui de la semaine d'abord.
function Championships.List(): { Championship }
	local list = { weeklyChampionship(Weekly.Current()) }
	for _, definition in ipairs(DEFINITIONS) do
		table.insert(list, fromDefinition(definition))
	end
	return list
end

-- Le rallye `id` tel qu'il est cette semaine, ou nil.
function Championships.Get(id: any): Championship?
	if id == Championships.WEEKLY_ID then
		return weeklyChampionship(Weekly.Current())
	end
	for _, definition in ipairs(DEFINITIONS) do
		if definition.Id == id then
			return fromDefinition(definition)
		end
	end
	return nil
end

return Championships
