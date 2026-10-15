--!strict
--[[
	Progression.luau
	La progression du pilote : expérience (XP), niveaux, licences, et les
	cosmétiques qu'elle débloque. Partagé : le serveur calcule et fait
	respecter (ProgressService, GarageService), le client affiche (garage, menu, bandeaux).

	XP DÉDUITE DU PROFIL, PAS ACCUMULÉE À PART : elle se recalcule à partir de
	ce que le profil garde déjà -- médailles (meilleurs temps), courses,
	victoires, podiums, points -- plus des compteurs : spéciales terminées,
	points de style (dérapages, sauts, dépassements), XP des défis du jour, et
	XP en plus des événements double XP (XpEvents.luau). Les joueurs existants
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
local Stages = require(script.Parent.Parent.Stage.Stages)
local Lessons = require(script.Parent.Parent.School.Lessons)
local Format = require(script.Parent.Parent.Util.Format)
local Catalog = require(script.Parent.Parent.Economy.Catalog)

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
	(Medals.luau, 0 à 4) par tracé : "stage:<id>" par spéciale
	(Stages.MedalKey), l'identifiant du circuit sinon (Tracks.luau), et
	"stage" : la meilleure des spéciales (déblocages seulement, hors XP).
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
	BonusXp: number, -- XP en plus des événements double XP (XpEvents.luau)
	ChampionshipXp: number, -- XP des rallyes terminés (mode championnat)
	Rallies: number, -- rallyes terminés (mode championnat)
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
		+ record.BonusXp
		+ record.ChampionshipXp
		+ record.Style // Progression.XP.STYLE_PER_XP
	for track, tier in pairs(record.Medals) do
		-- "stage" : la meilleure des spéciales, déjà comptée sous sa propre clé.
		if track ~= Stages.BEST_MEDAL_KEY then
			xp += Progression.MEDAL_XP[tier] or 0
		end
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
	Rallies: number,
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
		Rallies = record.Rallies,
		Medals = record.Medals,
		Lessons = record.Lessons,
	}
end

-- Tracés où le joueur a l'or ou mieux ("stage", la meilleure des spéciales, n'est pas un tracé).
function Progression.GoldMedals(snapshot: Snapshot): number
	local count = 0
	for track, tier in pairs(snapshot.Medals) do
		if track ~= Stages.BEST_MEDAL_KEY and tier >= 3 then
			count += 1
		end
	end
	return count
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
	GoldMedals: number?, -- médailles d'or (ou mieux) sur autant de tracés différents
	Rallies: number?, -- rallyes terminés en mode championnat
	-- Posséder cet objet du catalogue (pièce gagnée à un tirage : Items/Parts.luau).
	Item: string?,
}

-- Objets possédés (identifiant -> true), pour les conditions Item.
export type Owned = { [string]: boolean }

export type Kind = "Color" | "Stripes" | "Plate" | "Pattern" | "Sponsor" | "Finish" | "TrimFinish" | "Custom" | "Body" | "Wing" | "Bumper" | "Hood" | "Flares" | "Rims"
	| "Mirrors" | "Roof" | "Skirts" | "Diffuser" | "Exhaust" | "Mudflaps"
	| "Moustache" | "Grille" | "Canards" | "SunStrip" | "HoodPins" | "Tow" | "LightCovers" | "SideVents" | "WindowNet"
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
	-- Motifs (Livery.PATTERNS). « Item » : seulement aux tirages (Items/Parts.luau).
	{ Kind = "Pattern", Index = 2, Requirement = { Level = 3 } }, -- Damier
	{ Kind = "Pattern", Index = 3, Requirement = { Level = 5 } }, -- Pois
	{ Kind = "Pattern", Index = 4, Requirement = { Level = 7 } }, -- Hexagones
	{ Kind = "Pattern", Index = 5, Requirement = { Level = 10 } }, -- Carbone
	{ Kind = "Pattern", Index = 6, Requirement = { Level = 12 } }, -- Camouflage
	{ Kind = "Pattern", Index = 7, Requirement = { AnyMedal = 3 } }, -- Zébrures
	{ Kind = "Pattern", Index = 8, Requirement = { Item = "part_pattern_flames" } }, -- Flammes
	{ Kind = "Pattern", Index = 9, Requirement = { Item = "part_pattern_sakura" } }, -- Sakura
	{ Kind = "Pattern", Index = 10, Requirement = { Level = 8 } }, -- Crayonné
	-- Finitions (Livery.FINISHES, TRIM_FINISHES) et couleurs sur mesure.
	{ Kind = "Finish", Index = 2, Requirement = { Level = 2 } }, -- Brillant
	{ Kind = "Finish", Index = 3, Requirement = { Level = 3 } }, -- Mat
	{ Kind = "Finish", Index = 4, Requirement = { Level = 4 } }, -- Satiné
	{ Kind = "Finish", Index = 5, Requirement = { Level = 6 } }, -- Métallisé
	{ Kind = "Finish", Index = 6, Requirement = { Level = 10 } }, -- Nacré
	{ Kind = "Finish", Index = 7, Requirement = { Item = "part_finish_chrome" } }, -- Chromé
	{ Kind = "Finish", Index = 8, Requirement = { Level = 13 } }, -- Froissé
	{ Kind = "Finish", Index = 9, Requirement = { Item = "part_finish_neon" } }, -- Néon
	{ Kind = "TrimFinish", Index = 2, Requirement = { Level = 3 } }, -- Noir brillant
	{ Kind = "TrimFinish", Index = 3, Requirement = { Level = 9 } }, -- Chromé
	{ Kind = "TrimFinish", Index = 4, Requirement = { Level = 7 } }, -- Carbone
	{ Kind = "TrimFinish", Index = 5, Requirement = { Level = 5 } }, -- Couleur caisse
	{ Kind = "Custom", Index = 1, Requirement = { Level = 6 } }, -- Couleurs sur mesure (hexa)
	-- Sponsors (Livery.SPONSORS) ; Sim Rallye (2) est libre. « Item » : aux tirages.
	{ Kind = "Sponsor", Index = 3, Requirement = { Level = 2 } }, -- Kaze Oil
	{ Kind = "Sponsor", Index = 4, Requirement = { Level = 3 } }, -- Sakura Tyres
	{ Kind = "Sponsor", Index = 5, Requirement = { Level = 5 } }, -- Hayate Racing
	{ Kind = "Sponsor", Index = 6, Requirement = { Level = 6 } }, -- Yama Motors
	{ Kind = "Sponsor", Index = 7, Requirement = { Level = 8 } }, -- Raijin Energy
	{ Kind = "Sponsor", Index = 8, Requirement = { Wins = 1 } }, -- Hoshi Lubes
	{ Kind = "Sponsor", Index = 9, Requirement = { Level = 11 } }, -- Gomu Turbo
	{ Kind = "Sponsor", Index = 10, Requirement = { AnyMedal = 3 } }, -- Kitsune
	{ Kind = "Sponsor", Index = 11, Requirement = { Item = "part_sponsor_neon" } }, -- Neon Rally
	{ Kind = "Sponsor", Index = 12, Requirement = { Item = "part_sponsor_dragon" } }, -- Dragon Brakes
	-- Modèles (CarBodies.LIST) ; Kaze (2) est libre : c'est la voiture de départ.
	-- Environ un modèle tous les deux niveaux ; les deux légendes du Groupe B
	-- se gagnent par un exploit : Blitz (or sur 3 tracés), Cuneo (3 rallyes).
	{ Kind = "Body", Index = 3, Requirement = { Level = 9 } }, -- Yama
	{ Kind = "Body", Index = 4, Requirement = { Level = 13 } }, -- Raijin
	{ Kind = "Body", Index = 5, Requirement = { Level = 3 } }, -- Hayate
	{ Kind = "Body", Index = 6, Requirement = { Level = 10 } }, -- Hoshi
	{ Kind = "Body", Index = 7, Requirement = { Level = 4 } }, -- Tora
	{ Kind = "Body", Index = 8, Requirement = { Level = 19 } }, -- Kumo
	{ Kind = "Body", Index = 9, Requirement = { Level = 27 } }, -- Ryu
	{ Kind = "Body", Index = 10, Requirement = { Level = 17 } }, -- Tsubasa
	{ Kind = "Body", Index = 11, Requirement = { Level = 12 } }, -- Requin
	{ Kind = "Body", Index = 12, Requirement = { Level = 7 } }, -- Lynx
	{ Kind = "Body", Index = 13, Requirement = { Level = 6 } }, -- Griffe
	{ Kind = "Body", Index = 14, Requirement = { Level = 15 } }, -- Furia
	{ Kind = "Body", Index = 15, Requirement = { GoldMedals = 3 } }, -- Blitz
	{ Kind = "Body", Index = 16, Requirement = { Level = 21 } }, -- Fauve
	{ Kind = "Body", Index = 17, Requirement = { Rallies = 3 } }, -- Cuneo
	-- Pièces (CarBodies.SLOTS). « Item » : seulement aux tirages (Items/Parts.luau).
	{ Kind = "Wing", Index = 2, Requirement = { Level = 2 } }, -- Becquet
	{ Kind = "Wing", Index = 3, Requirement = { Level = 5 } }, -- Aileron rallye
	{ Kind = "Wing", Index = 4, Requirement = { Level = 9 } }, -- Grand aileron
	{ Kind = "Wing", Index = 5, Requirement = { Item = "part_wing_double" } }, -- Double étage
	{ Kind = "Bumper", Index = 2, Requirement = { Level = 4 } }, -- Rallye
	{ Kind = "Bumper", Index = 3, Requirement = { Level = 9 } }, -- Course
	{ Kind = "Hood", Index = 2, Requirement = { Level = 3 } }, -- Prises d'air
	{ Kind = "Hood", Index = 3, Requirement = { Level = 7 } }, -- Écope
	{ Kind = "Hood", Index = 4, Requirement = { Item = "part_hood_lamps" } }, -- Rampe de phares
	{ Kind = "Flares", Index = 2, Requirement = { Item = "part_flares_wide" } }, -- Ailes élargies
	{ Kind = "Rims", Index = 2, Requirement = { Level = 2 } }, -- Noires
	{ Kind = "Rims", Index = 3, Requirement = { Level = 4 } }, -- Blanches
	{ Kind = "Rims", Index = 4, Requirement = { Level = 8 } }, -- Chrome
	{ Kind = "Rims", Index = 5, Requirement = { Item = "part_rims_sakura" } }, -- Sakura
	{ Kind = "Rims", Index = 6, Requirement = { Item = "part_rims_neon" } }, -- Néon
	-- Accessoires (CarBodies.SLOTS : Accessory).
	{ Kind = "Mirrors", Index = 2, Requirement = { Level = 3 } }, -- Course
	{ Kind = "Mirrors", Index = 3, Requirement = { Level = 6 } }, -- Rallye
	{ Kind = "Roof", Index = 2, Requirement = { Level = 4 } }, -- Écope
	{ Kind = "Roof", Index = 3, Requirement = { Level = 8 } }, -- Aileron de requin
	{ Kind = "Skirts", Index = 2, Requirement = { Level = 5 } }, -- Jupes
	{ Kind = "Skirts", Index = 3, Requirement = { Level = 10 } }, -- Lames
	{ Kind = "Diffuser", Index = 2, Requirement = { Level = 6 } }, -- Diffuseur
	{ Kind = "Diffuser", Index = 3, Requirement = { Wins = 3 } }, -- Diffuseur course
	{ Kind = "Exhaust", Index = 2, Requirement = { Level = 4 } }, -- Double
	{ Kind = "Exhaust", Index = 3, Requirement = { Item = "part_exhaust_cannon" } }, -- Canon
	{ Kind = "Mudflaps", Index = 3, Requirement = { Level = 7 } }, -- Longues
	{ Kind = "Exhaust", Index = 4, Requirement = { Level = 9 } }, -- Quadruple
	{ Kind = "Exhaust", Index = 5, Requirement = { Level = 12 } }, -- Latéral
	{ Kind = "Exhaust", Index = 6, Requirement = { Level = 7 } }, -- Relevé
	{ Kind = "Exhaust", Index = 7, Requirement = { Item = "part_exhaust_titanium" } }, -- Titane
	{ Kind = "Moustache", Index = 3, Requirement = { Level = 4 } }, -- Lame
	{ Kind = "Moustache", Index = 4, Requirement = { Level = 8 } }, -- Chromée
	{ Kind = "Moustache", Index = 5, Requirement = { Item = "part_moustache_double" } }, -- Double
	{ Kind = "Grille", Index = 2, Requirement = { Level = 3 } }, -- Nid d'abeille
	{ Kind = "Grille", Index = 3, Requirement = { Level = 6 } }, -- Barres chromées
	{ Kind = "Grille", Index = 4, Requirement = { Level = 9 } }, -- Grillage rallye
	{ Kind = "Canards", Index = 3, Requirement = { Level = 8 } }, -- Doubles
	{ Kind = "SunStrip", Index = 4, Requirement = { Level = 5 } }, -- Couleur caisse
	{ Kind = "HoodPins", Index = 2, Requirement = { Level = 4 } }, -- Chromées
	{ Kind = "Tow", Index = 2, Requirement = { Level = 3 } }, -- Sangles jaunes
	{ Kind = "Tow", Index = 3, Requirement = { Level = 6 } }, -- Sangles bleues
	{ Kind = "LightCovers", Index = 2, Requirement = { Level = 5 } }, -- Adhésif en croix
	{ Kind = "LightCovers", Index = 3, Requirement = { Wins = 1 } }, -- Caches noirs
	{ Kind = "SideVents", Index = 3, Requirement = { Level = 11 } }, -- Prises arrière
	{ Kind = "WindowNet", Index = 3, Requirement = { AnyMedal = 3 } }, -- Rouge
} :: { Item }

function Progression.ItemFor(kind: Kind, index: number): Item?
	for _, item in ipairs(Progression.ITEMS) do
		if item.Kind == kind and item.Index == index then
			return item
		end
	end
	return nil
end

function Progression.Meets(requirement: Requirement, snapshot: Snapshot?, owned: Owned?): boolean
	-- Une pièce de tirage : il suffit de la posséder.
	local item = requirement.Item
	if item then
		return owned ~= nil and owned[item] == true
	end
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
	if requirement.GoldMedals and Progression.GoldMedals(snapshot) < requirement.GoldMedals then
		return false
	end
	if requirement.Rallies and (snapshot.Rallies or 0) < requirement.Rallies then
		return false
	end
	return true
end

-- Un cosmétique est-il à ce joueur ? (libre, ou condition remplie)
-- Clé d'un déblocage acheté en Robux, rangée dans les objets possédés.
function Progression.UnlockKey(kind: string, index: number): string
	return "unlock:" .. kind .. ":" .. tostring(index)
end

function Progression.IsUnlocked(kind: Kind, index: number, snapshot: Snapshot?, owned: Owned?): boolean
	local item = Progression.ItemFor(kind, index)
	if item == nil then
		return true
	end
	-- Débloqué d'avance en Robux (MonetizationService).
	if owned ~= nil and owned[Progression.UnlockKey(kind, index)] == true then
		return true
	end
	return Progression.Meets(item.Requirement, snapshot, owned)
end

local TIER_NAMES = { "Bronze", "Argent", "Or", "Platine" }

local function trackName(id: string): string
	if id == Stages.BEST_MEDAL_KEY then
		return "une spéciale"
	end
	local stageId = Stages.FromMedalKey(id)
	if stageId then
		return Stages.Get(stageId).Name
	end
	local circuit = Tracks.Get(id)
	return if circuit then circuit.Name else id
end

-- "Niveau 3", "Or sur la spéciale", "3 victoires en rallycross"...
function Progression.Describe(requirement: Requirement): string
	local parts = {}
	if requirement.Item then
		local item = Catalog.Get(requirement.Item)
		return "à gagner aux tirages" .. (if item then " (" .. item.Name .. ")" else "")
	end
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
	if requirement.GoldMedals then
		local n = requirement.GoldMedals
		table.insert(parts, string.format("Or sur %d tracé%s différent%s", n, if n > 1 then "s" else "", if n > 1 then "s" else ""))
	end
	if requirement.Rallies then
		local n = requirement.Rallies
		table.insert(parts, string.format("%d rallye%s terminé%s en championnat", n, if n > 1 then "s" else "", if n > 1 then "s" else ""))
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
function Progression.Enforce(wanted: any, current: any, fallback: any, snapshot: Snapshot?, owned: Owned?): any
	local result = table.clone(wanted)
	local function keep(field: string, kind: Kind)
		if not Progression.IsUnlocked(kind, result[field], snapshot, owned) then
			result[field] = if Progression.IsUnlocked(kind, current[field], snapshot, owned) then current[field] else fallback[field]
		end
	end
	keep("Color", "Color")
	keep("StripeColor", "Color")
	keep("Stripes", "Stripes")
	keep("Plate", "Plate")
	for _, field in ipairs({ "SponsorHood", "SponsorDoors", "SponsorRoof" }) do
		if result[field] ~= nil then
			keep(field, "Sponsor")
		end
	end
	if result.Finish ~= nil then
		keep("Finish", "Finish")
	end
	if result.TrimFinish ~= nil then
		keep("TrimFinish", "TrimFinish")
	end
	-- Couleurs sur mesure : tout ou rien, selon le déblocage.
	if type(result.Custom) == "table" and next(result.Custom) ~= nil and not Progression.IsUnlocked("Custom", 1, snapshot, owned) then
		result.Custom = {}
	end
	if result.Pattern ~= nil then
		keep("Pattern", "Pattern")
		keep("PatternColor", "Color")
	end
	-- Peinture par zone : une couleur verrouillée laisse la zone d'origine.
	if type(result.Paints) == "table" then
		local paints = {}
		for zone, color in pairs(result.Paints) do
			if Progression.IsUnlocked("Color", color, snapshot, owned) then
				paints[zone] = color
			end
		end
		result.Paints = paints
	end
	-- Modèle et pièces (CarBodies.luau) : le champ porte le nom de sa sorte.
	for _, kind in ipairs({
		"Body", "Wing", "Bumper", "Hood", "Flares", "Rims",
		"Mirrors", "Roof", "Skirts", "Diffuser", "Exhaust", "Mudflaps",
		"Moustache", "Grille", "Canards", "SunStrip", "HoodPins", "Tow", "LightCovers", "SideVents", "WindowNet",
	} :: { Kind }) do
		if result[kind] ~= nil then
			keep(kind, kind)
		end
	end
	return result
end

return Progression
