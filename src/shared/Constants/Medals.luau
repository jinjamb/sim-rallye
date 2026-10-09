--!strict
--[[
	Medals.luau
	Médailles de la spéciale et des circuits : bronze, argent, or, platine.

	Un objectif à portée pour chacun : le top 10 mondial est vite hors
	d'atteinte, "il me manque 1,2 s pour l'or" ne l'est pas.

	DÉDUITES DU MEILLEUR TEMPS, JAMAIS STOCKÉES : la médaille d'un joueur est
	celle de son meilleur temps officiel (spéciale) ou de son meilleur tour
	(circuit), tous deux déjà sauvegardés par RecordService. Rien à migrer, et
	un seuil retouché s'applique aussitôt à tout le monde.

	SEUILS EN VITESSE MOYENNE (km/h) plutôt qu'en temps : ils suivent la longueur
	du tracé. Si le tracé change, ses temps repartent de zéro (RecordService) et
	ses seuils se recalculent d'eux-mêmes.
	Spéciale : sur le parcours chronométré (départ -> arrivée).
	Circuit : sur un tour SANS joker (Circuit.Length) ; le tour du joker, plus
	long, rapporte donc rarement une médaille, comme il se doit.

	CALIBRAGE : les vitesses ci-dessous sont un premier jet, à ajuster en
	roulant. Dans Studio, chaque temps validé affiche sa vitesse moyenne dans la
	sortie ([Médailles] ...) : bronze pour un débutant qui reste sur la route,
	platine pour les meilleurs pilotes du jeu.
]]

local StageTrack = require(script.Parent.Parent.Stage.StageTrack)
local Units = require(script.Parent.Units)

local Medals = {}

export type Tier = {
	Name: string,
	Short: string, -- en capitales, pour les bandeaux
	Title: string, -- l'annonce : "MÉDAILLE D'OR"
	Color: Color3,
}

-- Dans l'ordre : l'indice d'un palier est son rang (1 = bronze ... 4 = platine).
-- 0 = aucune médaille.
Medals.TIERS = {
	{ Name = "Bronze", Short = "BRONZE", Title = "MÉDAILLE DE BRONZE", Color = Color3.fromRGB(205, 127, 50) },
	{ Name = "Argent", Short = "ARGENT", Title = "MÉDAILLE D'ARGENT", Color = Color3.fromRGB(200, 205, 215) },
	{ Name = "Or", Short = "OR", Title = "MÉDAILLE D'OR", Color = Color3.fromRGB(245, 200, 55) },
	{ Name = "Platine", Short = "PLATINE", Title = "MÉDAILLE DE PLATINE", Color = Color3.fromRGB(130, 225, 235) },
} :: { Tier }

-- Vitesses moyennes visées (km/h), un palier par case.
local STAGE_SPEEDS = { 55, 70, 82, 92 }
local DEFAULT_CIRCUIT_SPEEDS = { 50, 62, 72, 80 }
local CIRCUIT_SPEEDS: { [string]: { number } } = {
	ajoncs = { 50, 62, 72, 80 },
	valdefaye = { 45, 56, 65, 72 }, -- technique, surtout de la terre
	greves = { 55, 68, 78, 86 }, -- rapide
}

-- Distance (studs) parcourue en `ms` millisecondes -> km/h.
function Medals.AverageKmh(distance: number, ms: number): number
	return Units.ToKmh(distance / math.max(ms / 1000, 1e-3))
end

-- Temps (ms) de chaque palier, arrondis au dixième : des objectifs lisibles.
local function thresholds(distance: number, speeds: { number }): { number }
	local result = table.create(#speeds)
	for i, kmh in ipairs(speeds) do
		local studsPerSecond = kmh / Units.ToKmh(1)
		result[i] = math.floor(distance / studsPerSecond * 10 + 0.5) * 100
	end
	return result
end

local stageCache: { number }? = nil

-- Longueur du parcours chronométré de la spéciale (studs).
function Medals.StageDistance(): number
	return StageTrack.GetFinishDistance() - StageTrack.START_DISTANCE
end

function Medals.ForStage(): { number }
	if not stageCache then
		stageCache = thresholds(Medals.StageDistance(), STAGE_SPEEDS)
	end
	return stageCache :: { number }
end

-- `trackId` : Tracks.luau ; `lapLength` : Circuit.Length (studs).
function Medals.ForCircuit(trackId: string, lapLength: number): { number }
	return thresholds(lapLength, CIRCUIT_SPEEDS[trackId] or DEFAULT_CIRCUIT_SPEEDS)
end

-- Palier atteint par un temps (0 = aucun).
function Medals.TierOf(ms: number?, limits: { number }): number
	if ms == nil then
		return 0
	end
	local tier = 0
	for i, limit in ipairs(limits) do
		if (ms :: number) <= limit then
			tier = i
		end
	end
	return tier
end

-- Prochain palier à décrocher et son temps ; nil si tout est décroché.
function Medals.Next(ms: number?, limits: { number }): (number?, number?)
	local tier = Medals.TierOf(ms, limits)
	if tier >= #limits then
		return nil, nil
	end
	return tier + 1, limits[tier + 1]
end

function Medals.Get(tier: number): Tier?
	return Medals.TIERS[tier]
end

-- "#RRGGBB", pour le texte enrichi (RichText).
function Medals.Hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

-- Un seuil, au dixième (ils sont arrondis ainsi) : "1:12.4".
function Medals.FormatLimit(ms: number): string
	local tenths = math.floor(ms / 100 + 0.5)
	local minutes = tenths // 600
	return string.format("%d:%04.1f", minutes, (tenths - minutes * 600) / 10)
end

-- Texte enrichi : le nom du palier dans sa couleur.
function Medals.Rich(tier: number, text: string?): string
	local info = Medals.TIERS[tier]
	if not info then
		return text or ""
	end
	return string.format('<font color="%s">%s</font>', Medals.Hex(info.Color), text or info.Short)
end

-- Tous les seuils sur une ligne (texte enrichi) : "BRONZE 1:45.8 · ARGENT ...".
function Medals.RichLine(limits: { number }): string
	local parts = {}
	for tier, limit in ipairs(limits) do
		table.insert(parts, Medals.Rich(tier) .. " " .. Medals.FormatLimit(limit))
	end
	return table.concat(parts, "  ·  ")
end

return Medals
