--!strict
--[[
	Pacenotes.luau
	Les notes du copilote, déduites du tracé (StageTrack.GetSegments) : rien
	n'est saisi à la main. Modifier le tracé met les notes à jour.

	SÉVÉRITÉ DES VIRAGES, convention des jeux de rallye : 1 = le plus serré,
	6 = le plus rapide. Classée sur le RAYON réel (1 stud = 0.28 m) :

		rayon (m)   < 15     15-25   25-40   40-60   60-90   90-130   130-200   > 200
		note        épingle    1       2       3       4       5        6       légère

	Modificateurs : "longue" (virage de 120° ou plus), "courte" (35° ou moins).

	DANGERS, lus dans le profil en long :
		saut      : tremplin (rampe à pente constante) suivi d'une redescente
		bosse     : montée puis descente courtes et arrondies
		montée / descente : ligne droite qui monte ou descend de 25 studs ou plus
		surface   : changement de revêtement (asphalte, terre, boue...)
		arrivée   : la ligne d'arrivée

	ENCHAÎNEMENTS ET DISTANCES : après chaque note, la distance jusqu'à la
	suivante, en mètres. Si la suivante arrive tout de suite, pas de distance :
	elle est liée par "dans" (moins de 15 m) ou "et" (moins de 30 m).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Constants.Units)
local StageTrack = require(script.Parent.StageTrack)

local Pacenotes = {}

export type Note = {
	Distance: number, -- abscisse (studs) où commence ce qui est annoncé
	EndDistance: number, -- fin (sortie du virage, fin du danger)
	Main: string, -- ce qui s'affiche en grand : "GAUCHE 3", "SAUT"...
	Detail: string, -- précisions : "longue · 70"
	IsCorner: boolean,
}

--[[
	Trois natures de note :
		Corner : virage ;
		Danger : saut, bosse -- ce qui se négocie comme un virage ;
		Info   : montée, descente, revêtement -- une précision, pas un obstacle ;
		Finish : l'arrivée.
	Les distances ("80", "150") se mesurent d'un virage/danger au virage/danger
	ou à l'arrivée suivant, en sautant les infos ; les liens "dans"/"et" ne
	relient que virages et dangers ("droite 4 dans saut", jamais "dans montée").
]]
type NoteKind = "Corner" | "Danger" | "Info" | "Finish"

type RawNote = {
	Distance: number,
	EndDistance: number,
	Main: string,
	Modifiers: { string },
	Kind: NoteKind,
	Link: string?,
}

local SEVERITY_LIMITS = { -- rayon maximal (m) de chaque note
	{ 15, "ÉPINGLE" },
	{ 25, "1" },
	{ 40, "2" },
	{ 60, "3" },
	{ 90, "4" },
	{ 130, "5" },
	{ 200, "6" },
}
local LONG_TURN, SHORT_TURN = 120, 35 -- degrés
local SLOPE_CALL = 25 -- studs de dénivelé pour annoncer une montée/descente
local BUMP_MAX_LENGTH = 100 -- studs : au-delà, ce n'est plus une bosse mais une côte
local BUMP_MIN_HEIGHT = 3
local LINK_INTO, LINK_AND = 15, 30 -- mètres
local MERGE_DISTANCE = 2 -- studs : deux annonces au même endroit n'en font qu'une

local SURFACE_NAMES: { [Enum.Material]: string } = {
	[Enum.Material.Asphalt] = "ASPHALTE",
	[Enum.Material.Ground] = "TERRE",
	[Enum.Material.Mud] = "BOUE",
	[Enum.Material.Sand] = "SABLE",
	[Enum.Material.Snow] = "NEIGE",
	[Enum.Material.Grass] = "HERBE",
	[Enum.Material.Ice] = "VERGLAS",
	[Enum.Material.Glacier] = "GLACE",
}

local function severityOf(radiusStuds: number): string
	local radiusMeters = radiusStuds * Units.METERS_PER_STUD
	for _, limit in ipairs(SEVERITY_LIMITS) do
		if radiusMeters < limit[1] then
			return limit[2]
		end
	end
	return "LÉGÈRE"
end

-- Distance annoncée, arrondie comme un copilote : à 10 m près, puis à 50 m près.
local function formatDistance(meters: number): string
	if meters < 100 then
		return tostring(math.max(10, math.floor(meters / 10 + 0.5) * 10))
	end
	return tostring(math.floor(meters / 50 + 0.5) * 50)
end

local function cornerNote(segment: StageTrack.SegmentInfo): RawNote
	local turn = segment.Turn :: number
	local direction = if turn > 0 then "GAUCHE" else "DROITE"
	local severity = severityOf(segment.Radius :: number)
	local angle = math.abs(turn)
	local main = if severity == "ÉPINGLE" then "ÉPINGLE " .. direction else direction .. " " .. severity
	local modifiers = {}
	if severity ~= "ÉPINGLE" then
		if angle >= LONG_TURN then
			table.insert(modifiers, "longue")
		elseif angle <= SHORT_TURN then
			table.insert(modifiers, "courte")
		end
	end
	return {
		Distance = segment.StartDistance,
		EndDistance = segment.EndDistance,
		Main = main,
		Modifiers = modifiers,
		Kind = "Corner",
	}
end

local function hazardNote(distance: number, endDistance: number, main: string, kind: NoteKind): RawNote
	return { Distance = distance, EndDistance = endDistance, Main = main, Modifiers = {}, Kind = kind }
end

local function collectRaw(): { RawNote }
	local segments = StageTrack.GetSegments()
	local raw: { RawNote } = {}

	for i, segment in ipairs(segments) do
		local previous = segments[i - 1]
		local nextSegment = segments[i + 1]
		local rise = segment.EndHeight - segment.StartHeight
		local length = segment.EndDistance - segment.StartDistance

		if segment.Turn then
			table.insert(raw, cornerNote(segment))
		end

		-- Changement de revêtement (pas au premier segment : c'est le départ)
		if previous and previous.Material ~= segment.Material then
			local name = SURFACE_NAMES[segment.Material]
			if name then
				table.insert(raw, hazardNote(segment.StartDistance, segment.StartDistance, name, "Info"))
			end
		end

		-- Saut : tremplin à pente constante, puis redescente.
		local isKicker = segment.Linear
			and rise > 0
			and nextSegment ~= nil
			and nextSegment.EndHeight < nextSegment.StartHeight
		local isLanding = previous ~= nil and previous.Linear and previous.EndHeight > previous.StartHeight and rise < 0
		if isKicker then
			table.insert(raw, hazardNote(segment.StartDistance, segment.EndDistance, "SAUT", "Danger"))
		elseif not isLanding and not segment.Turn then
			-- Bosse : montée courte et arrondie, aussitôt redescendue.
			local isBump = not segment.Linear
				and rise >= BUMP_MIN_HEIGHT
				and length <= BUMP_MAX_LENGTH
				and nextSegment ~= nil
				and (nextSegment.StartHeight - nextSegment.EndHeight) >= BUMP_MIN_HEIGHT
				and (nextSegment.EndDistance - nextSegment.StartDistance) <= BUMP_MAX_LENGTH
			local isBumpDescent = previous ~= nil
				and not previous.Turn
				and (previous.EndHeight - previous.StartHeight) >= BUMP_MIN_HEIGHT
				and (previous.EndDistance - previous.StartDistance) <= BUMP_MAX_LENGTH
				and -rise >= BUMP_MIN_HEIGHT
				and length <= BUMP_MAX_LENGTH
			if isBump then
				table.insert(raw, hazardNote(segment.StartDistance, nextSegment.EndDistance, "BOSSE", "Danger"))
			elseif not isBumpDescent and math.abs(rise) >= SLOPE_CALL then
				local word = if rise > 0 then "MONTÉE" else "DESCENTE"
				table.insert(raw, hazardNote(segment.StartDistance, segment.EndDistance, word, "Info"))
			end
		end
	end

	local finish = StageTrack.GetFinishDistance()
	table.insert(raw, hazardNote(finish, finish, "ARRIVÉE", "Finish"))

	-- Rien avant la ligne de départ ni après l'arrivée.
	local kept = {}
	for _, note in ipairs(raw) do
		if note.Distance >= StageTrack.START_DISTANCE and note.Distance <= finish then
			table.insert(kept, note)
		end
	end
	table.sort(kept, function(a, b)
		if math.abs(a.Distance - b.Distance) < 1e-6 then
			-- Au même endroit, le virage passe en premier (l'info s'y rattache).
			return a.Kind == "Corner" and b.Kind ~= "Corner"
		end
		return a.Distance < b.Distance
	end)
	return kept
end

-- Deux annonces au même endroit (virage + changement de surface) n'en font qu'une.
local function merge(raw: { RawNote }): { RawNote }
	local merged: { RawNote } = {}
	for _, note in ipairs(raw) do
		local last = merged[#merged]
		if last and math.abs(note.Distance - last.Distance) <= MERGE_DISTANCE then
			-- Après la description du virage ("longue"), avant la distance.
			table.insert(last.Modifiers, string.lower(note.Main))
			last.EndDistance = math.max(last.EndDistance, note.EndDistance)
		else
			table.insert(merged, note)
		end
	end
	return merged
end

local cachedNotes: { Note }? = nil

function Pacenotes.Generate(): { Note }
	if cachedNotes then
		return cachedNotes
	end
	local raw = merge(collectRaw())

	--[[
		Liens et distances, pour chaque virage ou danger : mesurés de sa SORTIE à
		l'entrée du prochain virage, danger ou de l'arrivée -- les infos
		intercalées (montée, revêtement) ne coupent pas le compte.
	]]
	for i, note in ipairs(raw) do
		if note.Kind == "Corner" or note.Kind == "Danger" then
			local target: RawNote? = nil
			for j = i + 1, #raw do
				if raw[j].Kind ~= "Info" then
					target = raw[j]
					break
				end
			end
			if target then
				local gapMeters = math.max(0, target.Distance - note.EndDistance) * Units.METERS_PER_STUD
				local linkable = target.Kind == "Corner" or target.Kind == "Danger"
				if linkable and gapMeters < LINK_INTO then
					target.Link = "DANS"
				elseif linkable and gapMeters < LINK_AND then
					target.Link = "ET"
				elseif gapMeters >= LINK_AND then
					table.insert(note.Modifiers, formatDistance(gapMeters))
				end
			end
		end
	end

	local notes: { Note } = {}
	for _, note in ipairs(raw) do
		table.insert(notes, {
			Distance = note.Distance,
			EndDistance = note.EndDistance,
			Main = if note.Link then note.Link .. " " .. note.Main else note.Main,
			Detail = table.concat(note.Modifiers, " · "),
			IsCorner = note.Kind == "Corner",
		})
	end
	cachedNotes = notes
	return notes
end

return Pacenotes
