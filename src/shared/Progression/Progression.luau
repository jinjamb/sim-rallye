--!strict
--[[
	Progression.luau
	La progression du pilote : expérience (XP), niveaux, licences, et les
	cosmétiques qu'elle débloque. Partagé : le serveur calcule et fait
	respecter (ProgressService, GarageService), le client affiche (garage, menu, bandeaux).

	XP DÉDUITE DU PROFIL, PAS ACCUMULÉE À PART : elle se recalcule à partir de
	ce que le profil garde déjà -- médailles (meilleurs temps), courses,
	victoires, podiums, points -- plus deux compteurs : spéciales terminées et
	points de style (dérapages, sauts, dépassements). Les joueurs existants
	partent donc avec l'XP de ce qu'ils ont déjà fait, et un barème retouché
	s'applique à tous. Revers : baisser un barème peut faire redescendre un
	niveau (et reverrouiller un cosmétique) ; on ne le fait qu'en connaissance
	de cause.

	COSMÉTIQUES, JAMAIS DE PERFORMANCE : couleurs, bandes, style du numéro.
	La voiture est la même pour tous.

	RYTHME (premier jet, à ajuster en jouant) : ~1 000 à 1 800 XP par heure de
	jeu (une spéciale : 20 XP + ~20 XP de style ; une course de rallycross :
	~100 XP) ; licence Élite (niveau 22) vers 10 heures, niveau 30 vers
	20 heures. Les points de style ne comptent qu'en compétition (spéciale
	chronométrée, course : StyleService), pas aux essais libres.
]]

local Tracks = require(script.Parent.Parent.Tracks.Tracks)
local Lessons = require(script.Parent.Parent.School.Lessons)
local Format = require(script.Parent.Parent.Util.Format)

local Progression = {}

-- Barème ------------------------------------------------------------------------

Progression.XP = {
	RACE = 50, -- course de rallycross terminée (comptant pour la carrière)
	WIN = 150,
	PODIUM = 75,
	POINT = 5, -- par point de championnat
	STAGE_RUN = 20, -- spéciale terminée, temps validé
	WEEKLY = 150, -- défi de la semaine terminé (une fois par semaine)
	STYLE_PER_XP = 200, -- 200 points de style = 1 XP (un beau dérapage : ~1 000 points)
}
-- XP d'une médaille sur un tracé, cumulée : platine = 1000 au total.
Progression.MEDAL_XP = { 100, 250, 500, 1000 }

Progression.MAX_LEVEL = 30
local LEVEL_BASE = 100
local LEVEL_EXPONENT = 1.6

export type Licence = { Name: string, Short: string, Level: number, Color: Color3 }

Progression.LICENCES = {
	{ Name = "Débutant", Short = "DÉBUTANT", Level = 1, Color = Color3.fromRGB(170, 175, 185) },
	{ Name = "Régionale", Short = "RÉGIONALE", Level = 5, Color = Color3.fromRGB(80, 200, 110) },
	{ Name = "Nationale", Short = "NATIONALE", Level = 10, Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Internationale", Short = "INTERNATIONALE", Level = 15, Color = Color3.fromRGB(190, 110, 255) },
	{ Name = "Élite", Short = "ÉLITE", Level = 22, Color = Color3.fromRGB(245, 200, 55) },
} :: { Licence }

-- XP totale qu'il faut pour atteindre `level` (arrondie à la dizaine).
function Progression.XpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(LEVEL_BASE * (level - 1) ^ LEVEL_EXPONENT / 10 + 0.5) * 10
end

function Progression.LevelOf(xp: number): number
	local level = 1
	while level < Progression.MAX_LEVEL and xp >= Progression.XpForLevel(level + 1) do
		level += 1
	end
	return level
end

function Progression.LicenceOf(level: number): (number, Licence)
	local index = 1
	for i, licence in ipairs(Progression.LICENCES) do
		if level >= licence.Level then
			index = i
		end
	end
	return index, Progression.LICENCES[index]
end

--[[
	Ce que le profil sait, et dont tout se déduit. `Medals` : palier de médaille
	(Medals.luau, 0 à 4) par tracé : "stage" pour la spéciale, l'identifiant
	du circuit sinon (Tracks.luau).
]]
export type Record = {
	Races: number,
	Wins: number,
	Podiums: number,
	Points: number,
	StageRuns: number,
	Style: number,
	WeeklyCompleted: number, -- semaines où le défi a été terminé
	DailyXp: number, -- XP gagnée aux défis du jour (Daily.luau)
	Medals: { [string]: number },
	Lessons: { [string]: number }, -- médaille (0 à 4) par leçon de l'école (Lessons.luau)
}

function Progression.XpOf(record: Record): number
	local xp = record.Races * Progression.XP.RACE
		+ record.Wins * Progression.XP.WIN
		+ record.Podiums * Progression.XP.PODIUM
		+ record.Points * Progression.XP.POINT
		+ record.StageRuns * Progression.XP.STAGE_RUN
		+ record.WeeklyCompleted * Progression.XP.WEEKLY
		+ record.DailyXp
		+ record.Style // Progression.XP.STYLE_PER_XP
	for _, tier in pairs(record.Medals) do
		xp += Progression.MEDAL_XP[tier] or 0
	end
	for _, tier in pairs(record.Lessons) do
		xp += Lessons.MEDAL_XP[tier] or 0
	end
	return xp
end

-- Ce qu'envoie le serveur au client (ProgressService), et que lisent les écrans.
export type Snapshot = {
	Xp: number,
	Level: number,
	LevelXp: number, -- XP du début du niveau
	NextXp: number?, -- XP du niveau suivant (nil au niveau maximal)
	Licence: number,
	Style: number,
	StageRuns: number,
	Wins: number,
	Medals: { [string]: number },
	Lessons: { [string]: number },
}

function Progression.Snapshot(record: Record): Snapshot
	local xp = Progression.XpOf(record)
	local level = Progression.LevelOf(xp)
	local licence = Progression.LicenceOf(level)
	return {
		Xp = xp,
		Level = level,
		LevelXp = Progression.XpForLevel(level),
		NextXp = if level < Progression.MAX_LEVEL then Progression.XpForLevel(level + 1) else nil,
		Licence = licence,
		Style = record.Style,
		StageRuns = record.StageRuns,
		Wins = record.Wins,
		Medals = record.Medals,
		Lessons = record.Lessons,
	}
end

-- Cosmétiques à débloquer ---------------------------------------------------------

--[[
	Une condition : un niveau, une médaille sur un tracé précis, une médaille
	sur n'importe quel tracé, des victoires, des points de style. Toutes celles
	données doivent être remplies.
]]
export type Requirement = {
	Level: number?,
	Medal: { Track: string, Tier: number }?,
	AnyMedal: number?,
	Wins: number?,
	Style: number?,
}

export type Kind = "Color" | "Stripes" | "Plate"
export type Item = { Kind: Kind, Index: number, Requirement: Requirement }

-- Tout ce qui n'est pas listé ici est libre (Livery.FREE_COLORS, etc.).
Progression.ITEMS = {
	-- Couleurs (Livery.COLORS, au-delà des 12 libres)
	{ Kind = "Color", Index = 13, Requirement = { Level = 3 } }, -- Bleu nuit
	{ Kind = "Color", Index = 14, Requirement = { Level = 6 } }, -- Vert pomme
	{ Kind = "Color", Index = 15, Requirement = { Level = 8 } }, -- Sable
	{ Kind = "Color", Index = 16, Requirement = { Medal = { Track = "stage", Tier = 2 } } }, -- Turquoise
	{ Kind = "Color", Index = 17, Requirement = { Wins = 3 } }, -- Rouge corsa
	{ Kind = "Color", Index = 18, Requirement = { Level = 15 } }, -- Chrome
	{ Kind = "Color", Index = 19, Requirement = { Medal = { Track = "stage", Tier = 3 } } }, -- Or
	{ Kind = "Color", Index = 20, Requirement = { AnyMedal = 4 } }, -- Glacier
	-- Bandes (Livery.STRIPES)
	{ Kind = "Stripes", Index = 2, Requirement = { Level = 2 } }, -- Double bande
	{ Kind = "Stripes", Index = 3, Requirement = { Style = 100000 } }, -- Bande large
	{ Kind = "Stripes", Index = 4, Requirement = { Wins = 1 } }, -- Filets latéraux
	-- Style du numéro (Livery.PLATES)
	{ Kind = "Plate", Index = 2, Requirement = { Level = 4 } }, -- Noir
	{ Kind = "Plate", Index = 3, Requirement = { Level = 22 } }, -- Or (licence Élite)
} :: { Item }

function Progression.ItemFor(kind: Kind, index: number): Item?
	for _, item in ipairs(Progression.ITEMS) do
		if item.Kind == kind and item.Index == index then
			return item
		end
	end
	return nil
end

function Progression.Meets(requirement: Requirement, snapshot: Snapshot?): boolean
	if not snapshot then
		return false
	end
	if requirement.Level and snapshot.Level < requirement.Level then
		return false
	end
	local medal = requirement.Medal
	if medal and (snapshot.Medals[medal.Track] or 0) < medal.Tier then
		return false
	end
	local anyMedal = requirement.AnyMedal
	if anyMedal then
		local best = 0
		for _, tier in pairs(snapshot.Medals) do
			best = math.max(best, tier)
		end
		if best < anyMedal then
			return false
		end
	end
	if requirement.Wins and snapshot.Wins < requirement.Wins then
		return false
	end
	if requirement.Style and snapshot.Style < requirement.Style then
		return false
	end
	return true
end

-- Un cosmétique est-il à ce joueur ? (libre, ou condition remplie)
function Progression.IsUnlocked(kind: Kind, index: number, snapshot: Snapshot?): boolean
	local item = Progression.ItemFor(kind, index)
	return item == nil or Progression.Meets(item.Requirement, snapshot)
end

local TIER_NAMES = { "Bronze", "Argent", "Or", "Platine" }

local function trackName(id: string): string
	if id == "stage" then
		return "la spéciale"
	end
	local circuit = Tracks.Get(id)
	return if circuit then circuit.Name else id
end

-- "Niveau 3", "Or sur la spéciale", "3 victoires en rallycross"...
function Progression.Describe(requirement: Requirement): string
	local parts = {}
	if requirement.Level then
		local _, licence = Progression.LicenceOf(requirement.Level)
		local text = "Niveau " .. requirement.Level
		if licence.Level == requirement.Level and requirement.Level > 1 then
			text ..= " (licence " .. licence.Name .. ")"
		end
		table.insert(parts, text)
	end
	local medal = requirement.Medal
	if medal then
		table.insert(parts, string.format("%s sur %s", TIER_NAMES[medal.Tier] or "?", trackName(medal.Track)))
	end
	if requirement.AnyMedal then
		table.insert(parts, string.format("%s sur un tracé", TIER_NAMES[requirement.AnyMedal] or "?"))
	end
	if requirement.Wins then
		table.insert(parts, string.format("%d victoire%s en rallycross", requirement.Wins, if requirement.Wins > 1 then "s" else ""))
	end
	if requirement.Style then
		table.insert(parts, Format.Thousands(requirement.Style) .. " points de style")
	end
	return table.concat(parts, " et ")
end

-- Les cosmétiques débloqués par `after` qui ne l'étaient pas par `before`.
function Progression.NewUnlocks(before: Snapshot?, after: Snapshot): { Item }
	local list = {}
	for _, item in ipairs(Progression.ITEMS) do
		if Progression.Meets(item.Requirement, after) and not Progression.Meets(item.Requirement, before) then
			table.insert(list, item)
		end
	end
	return list
end

--[[
	Livrée demandée -> livrée autorisée : chaque élément verrouillé est
	remplacé par celui de la livrée actuelle (ou, s'il est lui aussi
	verrouillé, par celui de la livrée par défaut).
]]
function Progression.Enforce(wanted: any, current: any, fallback: any, snapshot: Snapshot?): any
	local result = table.clone(wanted)
	local function keep(field: string, kind: Kind)
		if not Progression.IsUnlocked(kind, result[field], snapshot) then
			result[field] = if Progression.IsUnlocked(kind, current[field], snapshot) then current[field] else fallback[field]
		end
	end
	keep("Color", "Color")
	keep("StripeColor", "Color")
	keep("Stripes", "Stripes")
	keep("Plate", "Plate")
	return result
end

return Progression
