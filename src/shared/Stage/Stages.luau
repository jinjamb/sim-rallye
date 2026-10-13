--!strict
--[[
	Stages.luau
	Les spéciales du jeu, décrites ici et construites par StageTrack.luau (à
	la première demande, puis gardées en cache). Chacune a son terrain
	(tools/build-stage.luau, STAGE = son identifiant), ses records, son
	classement, ses fantômes et ses médailles, par catégorie de voiture.

	SURFACES (StageTrack.Surface, déduite des segments) : asphalte (corniche,
	col, bocage), neige (neige, laponie, givre), terre (garrigue, causses),
	mixtes asphalte et terre (forêt, vignes).

	IMPLANTATION : chaque spéciale occupe son tracé plus ~400 studs tout
	autour (couloir, talus, fond de vallée : tools/build-stage.luau), et ces
	zones ne doivent jamais se chevaucher, ni entre elles, ni avec les
	circuits (Tracks.luau, à l'est), ni avec le paddock (autour de l'origine).
		- la forêt part du bord sud de la Baseplate vers -Z ;
		- la neige part de Z = 2400, vers +Z ;
		- à l'ouest (X < -4100), deux rangées : corniche, col, laponie, givre
		  au nord (départ à Z = 7000), bocage, garrigue, causses au sud
		  (départ à Z = -200), toutes cap -Z ;
		- les vignes au sud de la forêt.
	Un tracé modifié se revérifie hors jeu (séparation, pentes, zones) avant
	de relancer le générateur.

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
	{
		Id = "corniche",
		Name = "Corniche des Calanques",
		Description = "2,2 km d'asphalte au-dessus de la mer : enchaînements, deux épingles au sommet de la falaise, descente vers le port.",
		RecordPrefix = "s3",
		Theme = "Garrigue",
		Origin = Vector3.new(-4928, 0, 7000),
		Heading = 0,
		FirstMaterial = ASPHALT,
		MedalSpeeds = { 60, 76, 88, 98 },
		Segments = {
			-- Départ au-dessus de la mer, asphalte de bout en bout
			{ Length = 300, Height = 0, Material = ASPHALT },
			{ Turn = 45, Radius = 200 },
			{ Length = 200, Height = 12 },
			{ Turn = -90, Radius = 110 },
			{ Length = 150 },
			-- Enchaînement gauche-droite en montée
			{ Turn = 70, Radius = 90, Height = 20 },
			{ Turn = -60, Radius = 140 },
			{ Length = 350, Height = 32 },
			{ Turn = 120, Radius = 70 },
			{ Length = 180, Height = 40 },
			{ Turn = -100, Radius = 85 },
			{ Length = 260 },
			{ Turn = 35, Radius = 400 },
			{ Length = 400, Height = 55 },
			-- Deux épingles au sommet de la falaise
			{ Turn = -150, Radius = 55, Height = 58 },
			{ Length = 280, Height = 70 },
			{ Turn = 140, Radius = 58 },
			{ Length = 300, Height = 60 },
			-- Descente vers le port
			{ Turn = -50, Radius = 180 },
			{ Turn = 50, Radius = 180, Height = 48 },
			{ Length = 500, Height = 30 },
			{ Turn = -80, Radius = 120 },
			{ Length = 220, Height = 25 },
			{ Turn = 95, Radius = 95 },
			{ Length = 300, Height = 12 },
			{ Turn = -30, Radius = 350 },
			{ Length = 400, Height = 4 },
			{ Turn = 60, Radius = 150 },
			{ Length = 250 },
			-- Dégagement après l'arrivée, en légère montée
			{ Turn = -70, Radius = 130 },
			{ Length = 300, Height = 8 },
			{ Turn = 50, Radius = 220 },
			{ Length = 350, Height = 14 },
			{ Turn = -85, Radius = 110 },
			{ Length = 300, Height = 6 },
			{ Length = 220, Height = 10 },
		},
	},
	{
		Id = "col",
		Name = "Col de l'Échine",
		Description = "2,2 km d'asphalte de montagne : quatre lacets en montée, le col, puis une longue descente rapide.",
		RecordPrefix = "s4",
		Theme = "Mountain",
		Origin = Vector3.new(-8158, 0, 7000),
		Heading = 0,
		FirstMaterial = ASPHALT,
		MedalSpeeds = { 56, 71, 83, 93 },
		Segments = {
			{ Length = 250, Height = 0, Material = ASPHALT },
			{ Turn = 30, Radius = 300 },
			{ Length = 300, Height = 20 },
			-- Les lacets : quatre épingles en montée
			{ Turn = -170, Radius = 56, Height = 26 },
			{ Length = 380, Height = 50 },
			{ Turn = 170, Radius = 56, Height = 56 },
			{ Length = 380, Height = 80 },
			{ Turn = -165, Radius = 58, Height = 86 },
			{ Length = 360, Height = 110 },
			{ Turn = 160, Radius = 60, Height = 115 },
			{ Length = 250, Height = 130 },
			{ Turn = -75, Radius = 160 },
			-- Le col, puis la descente rapide
			{ Length = 300, Height = 140 },
			{ Turn = 60, Radius = 220 },
			{ Length = 200 },
			{ Turn = -90, Radius = 100, Height = 135 },
			{ Length = 350, Height = 115 },
			{ Turn = 110, Radius = 80 },
			{ Length = 300, Height = 95 },
			{ Turn = -60, Radius = 200 },
			{ Length = 420, Height = 70 },
			{ Turn = 80, Radius = 120 },
			{ Length = 250, Height = 60 },
			{ Turn = -40, Radius = 300 },
			{ Length = 300 },
			{ Turn = -100, Radius = 90, Height = 55 },
			{ Length = 350, Height = 45 },
			{ Turn = 70, Radius = 160 },
			{ Length = 300, Height = 38 },
			{ Turn = -50, Radius = 240 },
			{ Length = 300, Height = 30 },
			{ Length = 220, Height = 66 },
		},
	},
	{
		Id = "bocage",
		Name = "Routes du Bocage",
		Description = "2,2 km d'asphalte : la plus rapide, longs droits entre les haies, bosses et courbes à fond.",
		RecordPrefix = "s5",
		Theme = "Countryside",
		Origin = Vector3.new(-7675, 0, -200),
		Heading = 0,
		FirstMaterial = ASPHALT,
		MedalSpeeds = { 64, 80, 92, 102 },
		Segments = {
			{ Length = 400, Height = 0, Material = ASPHALT },
			{ Turn = -60, Radius = 250 },
			{ Length = 500, Height = 8 },
			{ Turn = 90, Radius = 140 },
			{ Length = 300, Height = 4 },
			{ Turn = -45, Radius = 300 },
			{ Length = 200 },
			-- Bosse : la voiture s'allège
			{ Length = 60, Height = 10 },
			{ Length = 80, Height = 2 },
			{ Length = 350 },
			{ Turn = -100, Radius = 110 },
			{ Length = 450, Height = 14 },
			{ Turn = 70, Radius = 180 },
			{ Turn = -70, Radius = 180 },
			{ Length = 380, Height = 6 },
			{ Turn = 110, Radius = 90 },
			{ Length = 300 },
			{ Turn = -30, Radius = 400, Height = 12 },
			{ Length = 600 },
			{ Turn = 80, Radius = 130 },
			{ Length = 260, Height = 4 },
			{ Turn = -90, Radius = 120 },
			{ Length = 500, Height = 0 },
			{ Turn = 60, Radius = 200 },
			{ Length = 450, Height = 6 },
			{ Turn = -75, Radius = 140 },
			{ Length = 400 },
			{ Length = 220, Height = 8 },
		},
	},
	{
		Id = "laponie",
		Name = "Lacs de Laponie",
		Description = "2,1 km de neige : rapide et fluide entre les lacs gelés, grand saut et longues courbes.",
		RecordPrefix = "s6",
		Theme = "Snow",
		Origin = Vector3.new(-9420, 0, 7000),
		Heading = 0,
		FirstMaterial = SNOW,
		MedalSpeeds = { 46, 58, 68, 76 },
		Segments = {
			{ Length = 400, Height = 0, Material = SNOW },
			{ Turn = 40, Radius = 350 },
			{ Length = 350, Height = 6 },
			{ Turn = -80, Radius = 200 },
			{ Length = 300 },
			-- Le grand saut (tremplin 10 %, réception 12.5 %)
			{ Length = 40, Height = 10, Ease = "linear" },
			{ Length = 200, Height = -15, Ease = "linear" },
			{ Length = 150 },
			{ Turn = 90, Radius = 160 },
			{ Length = 400, Height = -10 },
			{ Turn = -60, Radius = 250 },
			{ Turn = 60, Radius = 250 },
			{ Length = 350, Height = 0 },
			{ Turn = -110, Radius = 110 },
			{ Length = 300 },
			{ Turn = 45, Radius = 300, Height = 8 },
			{ Length = 450 },
			{ Turn = 100, Radius = 120 },
			{ Length = 250, Height = 2 },
			{ Turn = -70, Radius = 200 },
			{ Length = 500 },
			{ Length = 60, Height = 8 },
			{ Length = 60, Height = 2 },
			{ Length = 200 },
			{ Turn = 80, Radius = 180 },
			{ Length = 400, Height = 6 },
			{ Turn = -55, Radius = 260 },
			{ Length = 450 },
			{ Length = 220, Height = 10 },
		},
	},
	{
		Id = "givre",
		Name = "Vallée du Givre",
		Description = "1,8 km de neige : étroit et technique, épingles et enchaînements serrés au fond de la vallée.",
		RecordPrefix = "s7",
		Theme = "Snow",
		Origin = Vector3.new(-14365, 0, 7000),
		Heading = 0,
		FirstMaterial = SNOW,
		MedalSpeeds = { 40, 51, 60, 68 },
		Segments = {
			{ Length = 250, Height = 0, Material = SNOW },
			{ Turn = -90, Radius = 90 },
			{ Length = 200, Height = 10 },
			{ Turn = 120, Radius = 60 },
			{ Length = 180, Height = 18 },
			{ Turn = -150, Radius = 56, Height = 22 },
			{ Length = 300, Height = 40 },
			{ Turn = 140, Radius = 58 },
			{ Length = 250, Height = 52 },
			{ Turn = -60, Radius = 120 },
			{ Length = 220 },
			{ Turn = 80, Radius = 90, Height = 60 },
			{ Length = 260, Height = 50 },
			{ Turn = -120, Radius = 70 },
			{ Length = 300, Height = 34 },
			{ Turn = 90, Radius = 100 },
			{ Length = 240, Height = 24 },
			{ Turn = -45, Radius = 200 },
			{ Length = 200 },
			{ Turn = -80, Radius = 85 },
			{ Length = 280, Height = 10 },
			{ Turn = 110, Radius = 75 },
			{ Length = 300, Height = 0 },
			{ Turn = -70, Radius = 110 },
			{ Length = 260, Height = 6 },
			{ Turn = 130, Radius = 62 },
			{ Length = 300, Height = 16 },
			{ Turn = -60, Radius = 150 },
			{ Length = 320, Height = 8 },
			{ Turn = 75, Radius = 120 },
			{ Length = 280, Height = 0 },
			{ Length = 220, Height = 8 },
		},
	},
	{
		Id = "garrigue",
		Name = "Pistes de la Garrigue",
		Description = "1,9 km de terre sèche : deux sauts, une épingle et des pistes cassantes dans la garrigue.",
		RecordPrefix = "s8",
		Theme = "Garrigue",
		Origin = Vector3.new(-8699, 0, -200),
		Heading = 0,
		FirstMaterial = GROUND,
		MedalSpeeds = { 52, 67, 79, 89 },
		Segments = {
			{ Length = 300, Height = 0, Material = GROUND },
			{ Turn = 70, Radius = 160 },
			{ Length = 250, Height = 10 },
			{ Turn = -50, Radius = 220 },
			{ Length = 200, Height = 14 },
			{ Length = 40, Height = 18, Ease = "linear" },
			{ Length = 200, Height = -7, Ease = "linear" },
			{ Length = 200 },
			{ Turn = -110, Radius = 80 },
			{ Length = 300, Height = 0 },
			{ Turn = 90, Radius = 120 },
			{ Turn = -40, Radius = 250 },
			{ Length = 400, Height = 16 },
			{ Turn = 130, Radius = 60 },
			{ Length = 250, Height = 24 },
			{ Turn = -70, Radius = 150 },
			{ Length = 300 },
			{ Length = 40, Height = 28, Ease = "linear" },
			{ Length = 200, Height = 3, Ease = "linear" },
			{ Length = 150 },
			{ Turn = 60, Radius = 200 },
			{ Length = 350, Height = -4 },
			{ Turn = -90, Radius = 110 },
			{ Length = 250 },
			{ Length = 60, Height = 4 },
			{ Length = 60, Height = -4 },
			{ Length = 200 },
			{ Turn = 80, Radius = 130 },
			{ Length = 350, Height = 10 },
			{ Turn = -60, Radius = 200 },
			{ Length = 300 },
			{ Turn = 45, Radius = 260 },
			{ Length = 300, Height = 0 },
			{ Length = 220, Height = 4 },
		},
	},
	{
		Id = "causses",
		Name = "Bois des Causses",
		Description = "2 km de terre en forêt : crêtes, un grand saut et des courbes rapides à la finlandaise.",
		RecordPrefix = "s9",
		Theme = "Forest",
		Origin = Vector3.new(-13608, 0, -200),
		Heading = 0,
		FirstMaterial = GROUND,
		MedalSpeeds = { 54, 69, 81, 91 },
		Segments = {
			{ Length = 350, Height = 0, Material = GROUND },
			{ Turn = -45, Radius = 300 },
			{ Length = 300, Height = 12 },
			{ Length = 60, Height = 18 },
			{ Length = 80, Height = 10 },
			{ Turn = 80, Radius = 140 },
			{ Length = 400 },
			{ Turn = -60, Radius = 220, Height = 20 },
			{ Turn = 60, Radius = 220 },
			{ Length = 300, Height = 26 },
			{ Length = 40, Height = 30, Ease = "linear" },
			{ Length = 200, Height = 5, Ease = "linear" },
			{ Length = 200 },
			{ Turn = -120, Radius = 90 },
			{ Length = 350, Height = 12 },
			{ Turn = 95, Radius = 110 },
			{ Length = 300 },
			{ Turn = -35, Radius = 350, Height = 22 },
			{ Length = 450 },
			{ Turn = -90, Radius = 100 },
			{ Length = 300, Height = 14 },
			{ Turn = 110, Radius = 85 },
			{ Length = 400, Height = 6 },
			{ Length = 60, Height = 12 },
			{ Length = 60, Height = 6 },
			{ Length = 200 },
			{ Turn = -70, Radius = 160 },
			{ Length = 400, Height = 12 },
			{ Turn = 55, Radius = 240 },
			{ Length = 350, Height = 4 },
			{ Length = 220, Height = 14 },
		},
	},
	{
		Id = "vignes",
		Name = "Coteaux des Vignes",
		Description = "2 km mi-asphalte, mi-terre : route du village et chemins entre les vignes, un saut.",
		RecordPrefix = "s10",
		Theme = "Countryside",
		Origin = Vector3.new(-2000, 0, -2400),
		Heading = 0,
		FirstMaterial = ASPHALT,
		MedalSpeeds = { 57, 72, 84, 94 },
		Segments = {
			{ Length = 300, Height = 0, Material = ASPHALT },
			{ Turn = 60, Radius = 180 },
			{ Length = 350, Height = 10 },
			{ Turn = -90, Radius = 110 },
			{ Length = 250 },
			-- Chemin de terre entre les vignes
			{ Turn = 110, Radius = 80, Material = GROUND },
			{ Length = 300, Height = 18 },
			{ Turn = -60, Radius = 160 },
			{ Length = 40, Height = 22, Ease = "linear" },
			{ Length = 200, Height = -3, Ease = "linear" },
			{ Length = 200 },
			{ Turn = -100, Radius = 90 },
			{ Length = 300, Height = 6 },
			-- Retour sur la route du village
			{ Turn = 70, Radius = 150, Material = ASPHALT },
			{ Length = 500, Height = 12 },
			{ Turn = -45, Radius = 300 },
			{ Length = 300 },
			{ Turn = -120, Radius = 70 },
			{ Length = 250, Height = 4, Material = GROUND },
			{ Turn = 90, Radius = 120 },
			{ Length = 300 },
			{ Turn = -60, Radius = 200, Material = ASPHALT },
			{ Length = 400, Height = 0 },
			{ Turn = 80, Radius = 140, Material = GROUND },
			{ Length = 350, Height = 10 },
			{ Turn = -50, Radius = 220 },
			{ Length = 300, Material = ASPHALT },
			{ Turn = 40, Radius = 300 },
			{ Length = 300, Height = 0 },
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

--[[
	Clé de la médaille d'une spéciale dans la progression (Progression.luau,
	Snapshot.Medals). La clé "stage" seule garde la MEILLEURE médaille des
	spéciales, pour les déblocages (« or sur une spéciale ») ; elle ne compte
	pas dans l'XP ni dans les crédits, chaque spéciale comptant déjà sous sa
	propre clé.
]]
Stages.BEST_MEDAL_KEY = "stage"
local MEDAL_PREFIX = "stage:"

function Stages.MedalKey(stageId: string): string
	return MEDAL_PREFIX .. stageId
end

-- La spéciale d'une clé de médaille ("stage:col" -> "col"), ou nil.
function Stages.FromMedalKey(key: string): string?
	if string.sub(key, 1, #MEDAL_PREFIX) == MEDAL_PREFIX then
		local id = string.sub(key, #MEDAL_PREFIX + 1)
		return if Stages.Exists(id) then id else nil
	end
	return nil
end

-- Clé d'un record par spéciale et par catégorie (classements, fantômes, côté client).
function Stages.BoardKey(stageId: string, classId: string): string
	return stageId .. "|" .. classId
end

return Stages
