--!strict
--[[
	Stages.luau
	Les spéciales du jeu, décrites ici et construites par StageTrack.luau (à
	la première demande, puis gardées en cache). Chacune a son terrain
	(tools/build-stage.luau, STAGE = son identifiant), ses records, son
	classement, ses fantômes et ses médailles, par catégorie de voiture.

	IMPLANTATION : loin les unes des autres et des circuits (Tracks.luau, à
	X = 3000 à 9000, Z = ±700). La forêt part du bord sud de la Baseplate vers
	-Z (X = -3600 à +400, Z = -1600 à +600, accotements compris) ; la
	montagne part de Z = 2400, vers +Z, au nord de tout le reste.

	RECORDS : la clé d'une spéciale est « préfixe_longueur » (RecordId) :
	modifier un tracé change sa longueur, et ses temps repartent de zéro.
	La forêt garde son préfixe d'origine (s1) : ses records sont conservés.

	Le défi de la semaine et l'école de pilotage se courent sur la spéciale
	par défaut (DEFAULT), la forêt.
]]

local StageTrack = require(script.Parent.StageTrack)

local Stages = {}

Stages.DEFAULT = "foret"

local GROUND = Enum.Material.Ground
local ASPHALT = Enum.Material.Asphalt
local MUD = Enum.Material.Mud
local SNOW = Enum.Material.Snow
local ICE = Enum.Material.Ice

local DEFINITIONS: { StageTrack.Definition } = {
	{
		Id = "foret",
		Name = "Forêt des Ajoncs",
		Description = "1,6 km chronométrés, terre et asphalte, un saut et deux épingles.",
		RecordPrefix = "s1",
		Theme = "Forest",
		-- Bord de la Baseplate, au ras de sa surface, cap -Z.
		Origin = Vector3.new(0, 0, -256),
		Heading = 0,
		MedalSpeeds = { 55, 70, 82, 92 },
		--[[
			Tracé vérifié hors jeu : 6035 studs (~1.7 km, dégagement compris),
			ne repasse jamais sur la Baseplate, et deux portions éloignées du
			tracé restent à 113 studs au moins l'une de l'autre (les deux
			branches de la première épingle) ; le dégagement final est à plus de
			500 studs de tout le reste.
		]]
		Segments = {
			-- Départ en terre, longue courbe à gauche
			{ Length = 300, Height = 0, Material = GROUND },
			{ Turn = 60, Radius = 250 },
			{ Length = 250 },
			{ Turn = -90, Radius = 120 },
			{ Length = 150, Height = 20 },
			-- Épingle gauche en montée
			{ Turn = 170, Radius = 45 },
			{ Length = 300, Height = 50 },
			{ Turn = -45, Radius = 300 },
			-- Saut : tremplin à 10 %, réception longue à 12.5 %. Calculé pour qu'à
			-- 90-120 km/h la voiture retombe SUR la pente de réception, pas à plat.
			{ Length = 40, Height = 54, Ease = "linear" },
			{ Length = 200, Height = 29, Ease = "linear" },
			{ Length = 150 },
			-- Enchaînement gauche-droite-gauche, puis longue descente freinée.
			-- (Prévu à l'origine en rocaille : le matériau de terrain Rock est rendu
			-- HÉRISSÉ par Roblox, quelle que soit la hauteur demandée, et sa collision
			-- suit son maillage -- la voiture sautait en permanence et finissait sur le
			-- toit. Même problème attendu sur les autres matériaux rocheux du terrain.)
			{ Turn = 70, Radius = 150 },
			{ Turn = -70, Radius = 150, Height = 22 },
			{ Turn = 70, Radius = 150 },
			{ Length = 400, Height = -10 },
			-- Épingle droite au bas de la descente
			{ Turn = -160, Radius = 40 },
			{ Length = 250 },
			-- Portion asphalte rapide : la seule où passer la 5e, voire la 6e
			{ Turn = 90, Radius = 200, Height = 0, Material = ASPHALT },
			{ Length = 600 },
			{ Turn = -30, Radius = 500 },
			{ Length = 300 },
			-- Retour sur terre, flaque de boue, bosse avant l'arrivée
			{ Turn = 120, Radius = 90, Material = GROUND },
			{ Length = 80, Material = MUD },
			{ Length = 200, Material = GROUND },
			{ Length = 60, Height = 6 },
			{ Length = 60, Height = 0 },
			{ Length = 250 },
			-- Dégagement après l'arrivée, en légère montée pour aider à s'arrêter : il
			-- faut ~140 studs pour stopper depuis 100 km/h sur terre. Au-delà, le
			-- générateur prolonge le sol en plateau, puis en talus (tools/build-stage.luau).
			{ Length = 200, Height = 8 },
		},
	},
	{
		Id = "neige",
		Name = "Col des Neiges",
		Description = "2,4 km de neige damée et de plaques de verglas : épingles en montée, saut au sommet, longue descente.",
		RecordPrefix = "s2",
		Theme = "Snow",
		-- Au nord de tout le reste, cap +Z.
		Origin = Vector3.new(0, 0, 2400),
		Heading = math.pi,
		FirstMaterial = SNOW,
		-- Plus lente que la forêt : la neige adhère moins, le verglas encore moins.
		MedalSpeeds = { 44, 56, 66, 74 },
		Segments = {
			-- Départ sur la neige damée, longue courbe à gauche
			{ Length = 400, Height = 0, Material = SNOW },
			{ Turn = 40, Radius = 300 },
			{ Length = 300, Height = 14 },
			-- Première épingle droite, en montée
			{ Turn = -165, Radius = 46, Height = 24 },
			{ Length = 360, Height = 50 },
			-- Deuxième épingle, gauche
			{ Turn = 165, Radius = 46, Height = 60 },
			{ Length = 320, Height = 86 },
			{ Turn = -55, Radius = 220 },
			-- Plaque de verglas dans la montée : on lève le pied
			{ Length = 120, Height = 96, Material = ICE },
			{ Length = 140, Height = 102, Material = SNOW },
			{ Turn = 90, Radius = 130, Height = 110 },
			-- Traversée à flanc de montagne
			{ Length = 260, Height = 116 },
			{ Turn = -40, Radius = 350 },
			-- Le col : un plateau, puis le saut au sommet (tremplin 10 %, réception 12.5 %)
			{ Length = 360, Height = 118 },
			{ Length = 40, Height = 122, Ease = "linear" },
			{ Length = 170, Height = 101, Ease = "linear" },
			{ Length = 120 },
			-- S dans la descente
			{ Turn = -70, Radius = 170 },
			{ Turn = 70, Radius = 170, Height = 92 },
			-- Longue descente : freiner tôt
			{ Length = 480, Height = 66 },
			-- Épingle droite au bas de la descente, sur le verglas
			{ Turn = -170, Radius = 52, Height = 60, Material = ICE },
			{ Length = 380, Height = 40, Material = SNOW },
			{ Turn = 115, Radius = 110 },
			{ Length = 260, Height = 30 },
			{ Length = 90, Material = ICE },
			{ Turn = -45, Radius = 380, Material = SNOW },
			-- Route dégagée jusqu'au village : asphalte, la seule portion rapide
			{ Length = 560, Height = 10, Material = ASPHALT },
			{ Turn = 80, Radius = 260 },
			{ Length = 380, Height = 0 },
			-- Traversée du village : chicane
			{ Turn = -60, Radius = 140 },
			{ Length = 220 },
			-- Retour sur la neige pour le final
			{ Turn = 60, Radius = 140, Material = SNOW },
			{ Length = 260 },
			{ Turn = -100, Radius = 120 },
			{ Length = 160 },
			-- Bosse avant l'arrivée
			{ Length = 60, Height = 6 },
			{ Length = 60, Height = 0 },
			{ Length = 160 },
			-- Dégagement après l'arrivée, en légère montée
			{ Length = 220, Height = 8 },
		},
	},
}

local cache: { [string]: StageTrack.Track } = {}

-- Identifiants, dans l'ordre du menu.
function Stages.List(): { string }
	local ids = {}
	for _, definition in ipairs(DEFINITIONS) do
		table.insert(ids, definition.Id)
	end
	return ids
end

function Stages.Exists(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	for _, definition in ipairs(DEFINITIONS) do
		if definition.Id == id then
			return true
		end
	end
	return false
end

-- La spéciale `id` (la spéciale par défaut si l'identifiant est inconnu).
function Stages.Get(id: string?): StageTrack.Track
	local key = if Stages.Exists(id) then id :: string else Stages.DEFAULT
	local cached = cache[key]
	if cached then
		return cached
	end
	for _, definition in ipairs(DEFINITIONS) do
		if definition.Id == key then
			local track = StageTrack.new(definition)
			cache[key] = track
			return track
		end
	end
	error("spéciale introuvable : " .. key)
end

--[[
	La spéciale dont le couloir passe par cette position (la plus proche à
	moins de MAX_LATERAL studs de l'axe), ou nil. Pour une voiture sans
	attribut Stage.
]]
local MAX_LATERAL = 150
function Stages.FindAt(position: Vector3): StageTrack.Track?
	local best: StageTrack.Track? = nil
	local bestLateral = MAX_LATERAL
	for _, id in ipairs(Stages.List()) do
		local track = Stages.Get(id)
		local _, progress, lateral = track.Locate(position)
		if progress >= -50 and progress <= track.GetLength() + 300 and math.abs(lateral) < bestLateral then
			best = track
			bestLateral = math.abs(lateral)
		end
	end
	return best
end

-- Clé d'un record par spéciale et par catégorie (classements, fantômes, côté client).
function Stages.BoardKey(stageId: string, classId: string): string
	return stageId .. "|" .. classId
end

return Stages
