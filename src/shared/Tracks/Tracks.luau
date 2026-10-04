--!strict
--[[
	Tracks.luau
	Les circuits de rallycross. Chaque description est transformée en géométrie
	par Circuit.luau (à la première demande, puis gardée en cache).

	Modifier un tracé : modifier sa description ici, puis relancer
	tools/build-circuit.luau dans Studio. Les records du tour repartent alors de
	zéro (la clé de sauvegarde dépend de la longueur du tracé).

	Implantation : loin du paddock (Baseplate) et de la spéciale, qui s'étend de
	X = -3600 à +400 et de Z = -1600 à +600, accotements compris. Un circuit
	occupe environ 1700 x 1000 studs avec ses dégagements.

	Échelle : 1 stud = 0.28 m. Piste de 44 studs (12 m), comme en championnat ;
	joker de 34 studs (9.5 m).
]]

local Circuit = require(script.Parent.Circuit)

local Tracks = {}

local ASPHALT = Enum.Material.Asphalt
local GROUND = Enum.Material.Ground

local DEFINITIONS: { Circuit.Definition } = {
	{
		Id = "ajoncs",
		Name = "Les Ajoncs",
		Description = "1,07 km — 55 % asphalte. Long droit de départ, épingle dans l'infield, saut sur la terre.",
		Origin = Vector3.new(3000, 0, 0),
		RoadWidth = 44,
		JokerWidth = 34,
		DefaultLaps = 4,
		Points = {
			{ X = -600, Z = -300, Radius = 80, Material = ASPHALT },
			{ X = 350, Z = -300, Radius = 90 },
			{ X = 650, Z = -50, Radius = 70 },
			{ X = 520, Z = 250, Radius = 60, Material = GROUND },
			{ X = 180, Z = 160, Radius = 40 },
			{ X = 0, Z = -60, Radius = 40, Height = 6 },
			{ X = -200, Z = 150, Radius = 50, Height = 6 },
			{ X = -120, Z = 360, Radius = 50, Height = 0 },
			{ X = -520, Z = 320, Radius = 90, Material = ASPHALT },
			{ X = -760, Z = 20, Radius = 80 },
		},
		StartLine = { Edge = 1, T = 0.55 },
		Joker = {
			From = { Edge = 3, T = 0.4 },
			To = { Edge = 4, T = 0.5 },
			Lead = 20,
			Radius = 50,
			Via = { { X = 820, Z = 470, Radius = 70 } },
			Material = GROUND,
		},
		Jumps = {
			{ Edge = 8, T = 0.5, Height = 3.5, Up = 26, Down = 90 },
		},
	},
	{
		Id = "valdefaye",
		Name = "Val-de-Faye",
		Description = "0,87 km — 70 % terre. Technique : enchaînements serrés, bosse en crête.",
		Origin = Vector3.new(6000, 0, 0),
		RoadWidth = 44,
		JokerWidth = 34,
		DefaultLaps = 5,
		Points = {
			{ X = -500, Z = -250, Radius = 60, Material = ASPHALT },
			{ X = 300, Z = -250, Radius = 50 },
			{ X = 450, Z = 0, Radius = 40, Material = GROUND, Height = 5 },
			{ X = 200, Z = 120, Radius = 40, Height = 5 },
			{ X = 450, Z = 300, Radius = 70, Height = 0 },
			{ X = 100, Z = 420, Radius = 60 },
			{ X = -350, Z = 300, Radius = 50 },
			{ X = -150, Z = 80, Radius = 45 },
			{ X = -550, Z = 50, Radius = 60, Material = ASPHALT },
		},
		StartLine = { Edge = 1, T = 0.5 },
		Joker = {
			From = { Edge = 6, T = 0.45 },
			To = { Edge = 7, T = 0.4 },
			Lead = 20,
			Radius = 45,
			Via = { { X = -540, Z = 540, Radius = 60 } },
			Material = GROUND,
		},
		Jumps = {
			{ Edge = 5, T = 0.45, Height = 3, Up = 22, Down = 70 },
		},
	},
	{
		Id = "greves",
		Name = "Les Grèves",
		Description = "1,06 km — rapide. Grand droit, longues courbes, gros saut sur l'asphalte.",
		Origin = Vector3.new(9000, 0, 0),
		RoadWidth = 44,
		JokerWidth = 34,
		DefaultLaps = 4,
		Points = {
			{ X = -900, Z = -200, Radius = 120, Material = ASPHALT },
			{ X = 500, Z = -200, Radius = 70 },
			{ X = 700, Z = 100, Radius = 100, Material = GROUND, Height = 8 },
			{ X = 300, Z = 350, Radius = 50, Height = 4 },
			{ X = 0, Z = 150, Radius = 60, Height = 0 },
			{ X = -300, Z = 400, Radius = 80, Material = ASPHALT },
			{ X = -800, Z = 250, Radius = 100 },
		},
		StartLine = { Edge = 1, T = 0.55 },
		Joker = {
			From = { Edge = 3, T = 0.5 },
			To = { Edge = 4, T = 0.5 },
			Lead = 20,
			Radius = 50,
			Via = { { X = 300, Z = 580, Radius = 70 } },
			Material = GROUND,
		},
		Jumps = {
			{ Edge = 6, T = 0.5, Height = 5, Up = 34, Down = 120 },
		},
	},
}

local cache: { [string]: Circuit.Circuit } = {}

-- Identifiants, dans l'ordre d'affichage.
function Tracks.List(): { string }
	local ids = {}
	for _, definition in ipairs(DEFINITIONS) do
		table.insert(ids, definition.Id)
	end
	return ids
end

function Tracks.Get(id: string): Circuit.Circuit?
	local cached = cache[id]
	if cached then
		return cached
	end
	for _, definition in ipairs(DEFINITIONS) do
		if definition.Id == id then
			local circuit = Circuit.new(definition)
			cache[id] = circuit
			return circuit
		end
	end
	return nil
end

-- Le circuit dont la zone contient cette position (remise en piste, mini-carte).
function Tracks.FindAt(position: Vector3): Circuit.Circuit?
	for _, definition in ipairs(DEFINITIONS) do
		local origin = definition.Origin
		if math.abs(position.X - origin.X) < 1200 and math.abs(position.Z - origin.Z) < 900 then
			return Tracks.Get(definition.Id)
		end
	end
	return nil
end

return Tracks
