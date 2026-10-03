--!strict
--[[
	StageTrack.luau
	La spéciale, décrite UNE fois et partagée par :
		- tools/build-stage.luau : génère le terrain le long du tracé ;
		- StageTimer.luau (client) : chrono, temps intermédiaires, remise en piste.
	Les deux calculent exactement la même courbe à partir des segments ci-dessous :
	modifier le tracé, c'est modifier cette liste puis relancer le générateur.

	DESCRIPTION "À LA TORTUE" : on part du bord de la Baseplate, cap vers -Z, et
	on enchaîne lignes droites et arcs de cercle. Le cap est donc continu
	(aucune cassure entre deux segments), et un virage se décrit comme un
	copilote l'annoncerait : un angle et un rayon.

		Length            : ligne droite (studs)
		Turn + Radius     : arc ; Turn en degrés, positif = à GAUCHE
		Height            : hauteur visée en FIN de segment (studs, relative au
		                    départ) ; absente = on garde la hauteur précédente
		Ease              : "smooth" (défaut) : raccord en douceur, pente nulle
		                    aux extrémités ; "linear" : pente constante -- pour
		                    les tremplins, dont l'arête doit rester vive
		Material          : surface de la route ; absente = celle du segment
		                    précédent. Matériaux de TERRAIN uniquement (Pebble,
		                    par exemple, n'existe pas en terrain), et LISSES :
		                    Rock est hérissé par Roblox (voir le segment
		                    concerné). Ground et Asphalt sont vérifiés en
		                    roulant ; Mud pas encore.

	Échelle (Units.luau) : 1 stud = 0.28 m, 1 stud/s ~ 1 km/h.
	Tracé vérifié hors jeu : 6035 studs (~1.7 km, dégagement compris), ne
	repasse jamais sur la Baseplate, et deux portions éloignées du tracé restent
	à 113 studs au moins l'une de l'autre (les deux branches de la première
	épingle) ; le dégagement final est à plus de 500 studs de tout le reste.
]]

local StageTrack = {}

export type Sample = {
	Index: number,
	Position: Vector3, -- centre de la route, au niveau de la chaussée
	Forward: Vector3, -- tangente 3D (suit la pente)
	ForwardFlat: Vector3, -- tangente horizontale
	Left: Vector3, -- horizontale, vers la gauche du sens de course
	Distance: number, -- abscisse curviligne depuis l'origine (studs)
	Curvature: number, -- 1/rayon, signée (positive = virage à gauche)
	Material: Enum.Material,
}

type Segment = {
	Length: number?,
	Turn: number?,
	Radius: number?,
	Height: number?,
	Ease: string?,
	Material: Enum.Material?,
}

StageTrack.ORIGIN = Vector3.new(0, 0, -256) -- bord de la Baseplate, au ras de sa surface
StageTrack.SAMPLE_STEP = 4 -- studs : la résolution des voxels de terrain
StageTrack.ROAD_WIDTH = 24 -- ~6.7 m : une route de spéciale étroite
-- Couloir de terrain (route + accotements en herbe). Moins que la séparation
-- minimale entre portions du tracé (113), sinon deux couloirs se chevauchent.
StageTrack.CORRIDOR_WIDTH = 110

StageTrack.START_DISTANCE = 40 -- ligne de départ, après une petite zone de mise en place
-- Ligne d'arrivée, avant la fin du tracé : elle tombe juste avant le dégagement
-- en montée (le dernier segment, 200 studs).
StageTrack.FINISH_MARGIN = 220
StageTrack.SPLITS = { 0.33, 0.66 } -- temps intermédiaires, en fraction du parcours chronométré

local SEGMENTS: { Segment } = {
	-- Départ en terre, longue courbe à gauche
	{ Length = 300, Height = 0, Material = Enum.Material.Ground },
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
	{ Turn = 90, Radius = 200, Height = 0, Material = Enum.Material.Asphalt },
	{ Length = 600 },
	{ Turn = -30, Radius = 500 },
	{ Length = 300 },
	-- Retour sur terre, flaque de boue, bosse avant l'arrivée
	{ Turn = 120, Radius = 90, Material = Enum.Material.Ground },
	{ Length = 80, Material = Enum.Material.Mud },
	{ Length = 200, Material = Enum.Material.Ground },
	{ Length = 60, Height = 6 },
	{ Length = 60, Height = 0 },
	{ Length = 250 },
	-- Dégagement après l'arrivée, en légère montée pour aider à s'arrêter : il
	-- faut ~140 studs pour stopper depuis 100 km/h sur terre. Au-delà, le
	-- générateur prolonge le sol en plateau, puis en talus (tools/build-stage.luau).
	{ Length = 200, Height = 8 },
}

local cachedSamples: { Sample }? = nil
local cachedLength = 0

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- Cap -> direction horizontale. Cap 0 = -Z ; cap croissant = tourner à gauche.
local function headingToDirection(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

local function build(): { Sample }
	local samples: { Sample } = {}
	local x, z = StageTrack.ORIGIN.X, StageTrack.ORIGIN.Z
	local heading = 0
	local height = 0
	local distance = 0
	local material = Enum.Material.Ground

	local function push(curvature: number)
		table.insert(samples, {
			Index = #samples + 1,
			Position = Vector3.new(x, StageTrack.ORIGIN.Y + height, z),
			Forward = Vector3.zero, -- calculée ensuite, à partir des voisins
			ForwardFlat = headingToDirection(heading),
			Left = headingToDirection(heading + math.pi / 2),
			Distance = distance,
			Curvature = curvature,
			Material = material,
		})
	end

	push(0)

	for _, segment in ipairs(SEGMENTS) do
		material = segment.Material or material

		local length: number
		local curvature = 0
		if segment.Turn and segment.Radius then
			length = math.abs(math.rad(segment.Turn)) * segment.Radius
			curvature = math.sign(segment.Turn) / segment.Radius
		else
			length = segment.Length or 0
		end

		local startHeight = height
		local endHeight = segment.Height or height
		local linear = segment.Ease == "linear"
		local steps = math.max(1, math.ceil(length / StageTrack.SAMPLE_STEP))
		local ds = length / steps

		for i = 1, steps do
			-- Intégration au point milieu : l'arc reste un vrai arc de cercle.
			heading += curvature * ds / 2
			local direction = headingToDirection(heading)
			x += direction.X * ds
			z += direction.Z * ds
			heading += curvature * ds / 2
			distance += ds

			local t = i / steps
			height = startHeight + (endHeight - startHeight) * (if linear then t else smoothstep(t))
			push(curvature)
		end
	end

	-- Tangente 3D par différence centrée : suit la pente, sert à incliner les
	-- blocs de terrain et à orienter la voiture remise en piste.
	for i, sample in ipairs(samples) do
		local previous = samples[math.max(1, i - 1)].Position
		local nextPosition = samples[math.min(#samples, i + 1)].Position
		local delta = nextPosition - previous
		sample.Forward = if delta.Magnitude > 1e-6 then delta.Unit else sample.ForwardFlat
	end

	cachedLength = distance
	return samples
end

function StageTrack.GetSamples(): { Sample }
	if not cachedSamples then
		cachedSamples = build()
	end
	return cachedSamples :: { Sample }
end

function StageTrack.GetLength(): number
	StageTrack.GetSamples()
	return cachedLength
end

function StageTrack.GetFinishDistance(): number
	return StageTrack.GetLength() - StageTrack.FINISH_MARGIN
end

-- Premier échantillon dont l'abscisse atteint `distance`.
function StageTrack.SampleAt(distance: number): Sample
	local samples = StageTrack.GetSamples()
	local step = StageTrack.SAMPLE_STEP
	local guess = math.clamp(math.floor(distance / step) + 1, 1, #samples)
	while guess > 1 and samples[guess].Distance > distance do
		guess -= 1
	end
	while guess < #samples and samples[guess].Distance < distance do
		guess += 1
	end
	return samples[guess]
end

--[[
	Où est-on sur le tracé ? Recherche du point le plus proche dans le plan
	horizontal (le tracé ne passe jamais au-dessus de lui-même), puis
	projection sur la tangente pour une abscisse continue entre deux points.
	Renvoie : l'échantillon, l'abscisse curviligne, l'écart latéral (signé,
	positif à gauche).
	~1500 points : une recherche complète par frame reste négligeable.
]]
function StageTrack.Locate(position: Vector3): (Sample, number, number)
	local samples = StageTrack.GetSamples()
	local best = samples[1]
	local bestDistanceSq = math.huge
	for _, sample in ipairs(samples) do
		local dx = position.X - sample.Position.X
		local dz = position.Z - sample.Position.Z
		local distanceSq = dx * dx + dz * dz
		if distanceSq < bestDistanceSq then
			bestDistanceSq = distanceSq
			best = sample
		end
	end
	local offset = Vector3.new(position.X - best.Position.X, 0, position.Z - best.Position.Z)
	local progress = best.Distance + offset:Dot(best.ForwardFlat)
	local lateral = offset:Dot(best.Left)
	return best, progress, lateral
end

return StageTrack
