--!strict
--[[
	Weekly.luau
	Le défi de la semaine : la spéciale, avec une contrainte, et un classement
	remis à zéro chaque lundi.

	LA SEMAINE va du lundi 0 h au dimanche 23 h 59, en temps universel (UTC :
	l'horloge des serveurs Roblox). Tous les serveurs calculent la même, sans
	rien se dire : numéro de semaine depuis le 1er janvier 1970 (un jeudi,
	d'où le décalage de 3 jours pour commencer un lundi).

	LA CONTRAINTE est tirée au sort à partir du numéro de semaine (même tirage
	partout), jamais deux semaines de suite la même. Elle est appliquée chez le
	pilote (StageModifier.luau : la physique tourne chez lui) ; le chrono, lui,
	reste mesuré par le serveur.

	LA VOITURE est imposée, elle aussi tirée au sort (CLASS_WEIGHTS) : tout le
	monde court dans la même catégorie, prêtée pour le défi si on ne l'a pas.
	Un seul classement, équitable, et l'occasion d'essayer une voiture.

	Le défi a son propre classement, et ne touche ni le record habituel de la
	spéciale, ni son fantôme, ni ses médailles (ChallengeService). Le terminer
	une fois dans la semaine rapporte de l'XP (Progression.luau).
]]

local CarClasses = require(script.Parent.Parent.Vehicle.CarClasses)

local Weekly = {}

export type Modifier = {
	Id: string,
	Name: string,
	Description: string,
}

Weekly.MODIFIERS = {
	{ Id = "Night", Name = "Nuit", Description = "Spéciale de nuit, aux phares." },
	{ Id = "Rain", Name = "Pluie", Description = "Route mouillée : 20 % d'adhérence en moins partout." },
	{ Id = "Gear3", Name = "Boîte bloquée en 3e", Description = "Un seul rapport, du départ à l'arrivée (T si tu cales en côte)." },
	{ Id = "Fog", Name = "Brouillard", Description = "On voit à peine le virage suivant : écoute le copilote." },
	{ Id = "NoHandbrake", Name = "Sans frein à main", Description = "Les épingles au frein et au volant seulement." },
} :: { Modifier }

-- Chances relatives de chaque catégorie d'être la voiture de la semaine.
local CLASS_WEIGHTS: { { Id: string, Weight: number } } = {
	{ Id = "Rally2", Weight = 2 },
	{ Id = "Rally4", Weight = 1 },
	{ Id = "GroupB", Weight = 1 },
}

local DAY = 86400
local WEEK_OFFSET_DAYS = 3 -- le 1er janvier 1970 était un jeudi

export type Week = {
	Index: number,
	Key: string, -- "w2962" : nom du classement, clé de sauvegarde
	Modifier: Modifier,
	CarClass: string, -- la voiture imposée (CarClasses.luau)
	StartsAt: number, -- os.time() du lundi 0 h UTC
	EndsAt: number, -- os.time() du lundi suivant
}

local function rawPick(index: number): number
	return Random.new(index * 7919 + 17):NextInteger(1, #Weekly.MODIFIERS)
end

-- Contrainte de la semaine `index` : tirée au sort, différente de la précédente.
local function pick(index: number): number
	local choice = rawPick(index)
	if choice == rawPick(index - 1) then
		choice = choice % #Weekly.MODIFIERS + 1
	end
	return choice
end

local function pickClass(index: number): string
	local total = 0
	for _, entry in ipairs(CLASS_WEIGHTS) do
		total += entry.Weight
	end
	local roll = Random.new(index * 104729 + 3):NextNumber() * total
	for _, entry in ipairs(CLASS_WEIGHTS) do
		roll -= entry.Weight
		if roll < 0 and CarClasses.Exists(entry.Id) then
			return entry.Id
		end
	end
	return CarClasses.DEFAULT
end

function Weekly.At(time: number): Week
	local days = math.floor(time / DAY)
	local index = (days + WEEK_OFFSET_DAYS) // 7
	local startsAt = (index * 7 - WEEK_OFFSET_DAYS) * DAY
	return {
		Index = index,
		Key = "w" .. tostring(index),
		Modifier = Weekly.MODIFIERS[pick(index)],
		CarClass = pickClass(index),
		StartsAt = startsAt,
		EndsAt = startsAt + 7 * DAY,
	}
end

function Weekly.Current(): Week
	return Weekly.At(os.time())
end

function Weekly.ModifierById(id: string?): Modifier?
	for _, modifier in ipairs(Weekly.MODIFIERS) do
		if modifier.Id == id then
			return modifier
		end
	end
	return nil
end

return Weekly
