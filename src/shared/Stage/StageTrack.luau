--!strict
--[[
	StageTrack.luau
	La géométrie d'une spéciale, construite à partir de sa description
	(Stages.luau) et partagée par :
		- tools/build-stage.luau : génère le terrain le long du tracé ;
		- StageService (serveur) et StageTimer (client) : chrono, temps
		  intermédiaires, remise en piste ; le fantôme, le copilote, l'école.
	Tous calculent exactement la même courbe à partir des mêmes segments :
	modifier un tracé, c'est modifier sa liste puis relancer le générateur.

	StageTrack.new(définition) rend une spéciale : ses constantes (ROAD_WIDTH,
	START_DISTANCE, SPLITS...) et ses fonctions (Locate, SampleAt,
	GetFinishDistance...), à appeler avec un point : track.Locate(position).

	DESCRIPTION "À LA TORTUE" : on part de l'origine, au cap donné (Heading),
	et on enchaîne lignes droites et arcs de cercle. Le cap est donc continu
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
		                    précédent. Matériaux de TERRAIN uniquement, et
		                    LISSES : Rock est hérissé par Roblox (voir la
		                    spéciale de la forêt). Ground, Asphalt, Snow et Ice
		                    sont lisses.

	Échelle (Units.luau) : 1 stud = 0.28 m, 1 stud/s ~ 1 km/h.
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

export type Segment = {
	Length: number?,
	Turn: number?,
	Radius: number?,
	Height: number?,
	Ease: string?,
	Material: Enum.Material?,
}

-- Un segment une fois posé sur le tracé : ce que le copilote lit (Pacenotes.luau).
export type SegmentInfo = {
	Index: number,
	StartDistance: number,
	EndDistance: number,
	Turn: number?, -- degrés, positif = à gauche ; nil = ligne droite
	Radius: number?,
	StartHeight: number,
	EndHeight: number,
	Linear: boolean,
	Material: Enum.Material,
}

-- Décor de la spéciale (tools/build-stage.luau, THEMES) : forêt, montagne
-- enneigée, route de col, garrigue, bocage.
export type Theme = "Forest" | "Snow" | "Mountain" | "Garrigue" | "Countryside"

-- Nature de la spéciale, déduite de ses surfaces (menu, filtres) :
-- Tarmac (95 % d'asphalte ou plus), Snow (75 % de neige et de verglas ou
-- plus), Gravel (95 % de terre ou plus), Mixed sinon.
export type SurfaceKind = "Tarmac" | "Snow" | "Gravel" | "Mixed"

export type Definition = {
	Id: string,
	Name: string,
	Description: string, -- une phrase, pour le menu
	RecordPrefix: string, -- clé des records : préfixe_longueur (un tracé modifié repart de zéro)
	Theme: Theme,
	Origin: Vector3, -- départ du tracé, au ras du sol
	Heading: number?, -- cap de départ (radians) : 0 = vers -Z, croissant = vers la gauche
	Segments: { Segment },
	RoadWidth: number?,
	CorridorWidth: number?,
	StartDistance: number?,
	FinishMargin: number?,
	Splits: { number }?,
	MedalSpeeds: { number }, -- vitesses moyennes (km/h) des médailles, en Rally2 (Medals.luau)
	FirstMaterial: Enum.Material?,
}

export type Track = {
	Id: string,
	Name: string,
	Description: string,
	RecordId: string,
	Theme: Theme,
	Surface: SurfaceKind,
	MedalSpeeds: { number },
	ORIGIN: Vector3,
	SAMPLE_STEP: number,
	ROAD_WIDTH: number,
	CORRIDOR_WIDTH: number,
	START_DISTANCE: number,
	FINISH_MARGIN: number,
	SPLITS: { number },
	START_RUN_UP: number,
	DROP_HEIGHT: number,
	GetSamples: () -> { Sample },
	GetSegments: () -> { SegmentInfo },
	GetLength: () -> number,
	GetFinishDistance: () -> number,
	StartFrame: () -> CFrame,
	SampleAt: (distance: number) -> Sample,
	Locate: (position: Vector3) -> (Sample, number, number),
	LocateNear: (position: Vector3, hint: number, window: number) -> (Sample, number, number),
}

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- Cap -> direction horizontale. Cap 0 = -Z ; cap croissant = tourner à gauche.
local function headingToDirection(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

function StageTrack.new(definition: Definition): Track
	local track = {} :: Track
	track.Id = definition.Id
	track.Name = definition.Name
	track.Description = definition.Description
	track.Theme = definition.Theme
	track.MedalSpeeds = definition.MedalSpeeds
	track.ORIGIN = definition.Origin
	track.SAMPLE_STEP = 4 -- studs : la résolution des voxels de terrain
	track.ROAD_WIDTH = definition.RoadWidth or 24 -- ~6.7 m : une route de spéciale étroite
	-- Couloir de terrain (route + accotements). Moins que la séparation minimale
	-- entre deux portions du tracé, sinon deux couloirs se chevauchent.
	track.CORRIDOR_WIDTH = definition.CorridorWidth or 110
	track.START_DISTANCE = definition.StartDistance or 40 -- ligne de départ, après la mise en place
	-- Ligne d'arrivée, avant la fin du tracé (le dégagement qui suit).
	track.FINISH_MARGIN = definition.FinishMargin or 220
	track.SPLITS = definition.Splits or { 0.33, 0.66 } -- inters, en fraction du parcours chronométré
	-- Départ : un peu avant la ligne (départ quasi arrêté), légèrement au-dessus
	-- de la chaussée pour que la suspension se pose.
	track.START_RUN_UP = 10
	track.DROP_HEIGHT = 4

	local samples: { Sample } = {}
	local segments: { SegmentInfo } = {}
	local length = 0

	-- Le tracé, échantillonné tous les SAMPLE_STEP studs.
	local function build()
		local x, z = definition.Origin.X, definition.Origin.Z
		local heading = definition.Heading or 0
		local height = 0
		local distance = 0
		local material = definition.FirstMaterial or Enum.Material.Ground

		local function push(curvature: number)
			table.insert(samples, {
				Index = #samples + 1,
				Position = Vector3.new(x, definition.Origin.Y + height, z),
				Forward = Vector3.zero, -- calculée ensuite, à partir des voisins
				ForwardFlat = headingToDirection(heading),
				Left = headingToDirection(heading + math.pi / 2),
				Distance = distance,
				Curvature = curvature,
				Material = material,
			})
		end

		push(0)
		for _, segment in ipairs(definition.Segments) do
			material = segment.Material or material
			local segmentLength: number
			local curvature = 0
			if segment.Turn and segment.Radius then
				segmentLength = math.abs(math.rad(segment.Turn)) * segment.Radius
				curvature = math.sign(segment.Turn) / segment.Radius
			else
				segmentLength = segment.Length or 0
			end
			local startHeight = height
			local endHeight = segment.Height or height
			local linear = segment.Ease == "linear"
			table.insert(segments, {
				Index = #segments + 1,
				StartDistance = distance,
				EndDistance = distance + segmentLength,
				Turn = if curvature ~= 0 then segment.Turn else nil,
				Radius = if curvature ~= 0 then segment.Radius else nil,
				StartHeight = startHeight,
				EndHeight = endHeight,
				Linear = linear,
				Material = material,
			})
			local steps = math.max(1, math.ceil(segmentLength / track.SAMPLE_STEP))
			local ds = segmentLength / steps
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
		-- Tangente 3D par différence centrée : suit la pente, sert à orienter la
		-- voiture remise en piste.
		for i, sample in ipairs(samples) do
			local previous = samples[math.max(1, i - 1)].Position
			local nextPosition = samples[math.min(#samples, i + 1)].Position
			local delta = nextPosition - previous
			sample.Forward = if delta.Magnitude > 1e-6 then delta.Unit else sample.ForwardFlat
		end
		length = distance
	end
	build()

	track.RecordId = definition.RecordPrefix .. "_" .. tostring(math.floor(length))

	-- Nature de la spéciale : part de chaque famille de surface sur le parcours.
	local tarmac, winter, loose, total = 0, 0, 0, 0
	for _, segment in ipairs(segments) do
		local span = segment.EndDistance - segment.StartDistance
		local material = segment.Material
		total += span
		if material == Enum.Material.Asphalt or material == Enum.Material.Concrete or material == Enum.Material.Pavement then
			tarmac += span
		elseif material == Enum.Material.Snow or material == Enum.Material.Ice or material == Enum.Material.Glacier then
			winter += span
		else
			loose += span
		end
	end
	total = math.max(total, 1)
	track.Surface = if tarmac / total >= 0.95 then "Tarmac"
		elseif winter / total >= 0.75 then "Snow"
		elseif loose / total >= 0.95 then "Gravel"
		else "Mixed"

	function track.GetSamples(): { Sample }
		return samples
	end

	-- Les segments du tracé, avec leurs abscisses de début et de fin.
	function track.GetSegments(): { SegmentInfo }
		return segments
	end

	function track.GetLength(): number
		return length
	end

	function track.GetFinishDistance(): number
		return length - track.FINISH_MARGIN
	end

	-- Premier échantillon dont l'abscisse atteint `distance`.
	function track.SampleAt(distance: number): Sample
		local step = track.SAMPLE_STEP
		local guess = math.clamp(math.floor(distance / step) + 1, 1, #samples)
		while guess > 1 and samples[guess].Distance > distance do
			guess -= 1
		end
		while guess < #samples and samples[guess].Distance < distance do
			guess += 1
		end
		return samples[guess]
	end

	-- Où poser la voiture pour un départ (serveur) ou un retour au départ (client).
	function track.StartFrame(): CFrame
		local sample = track.SampleAt(track.START_DISTANCE - track.START_RUN_UP)
		local position = sample.Position + Vector3.new(0, track.DROP_HEIGHT, 0)
		return CFrame.lookAt(position, position + sample.Forward)
	end

	local function nearest(position: Vector3, first: number, last: number): (Sample, number, number)
		local best = samples[first]
		local bestDistanceSq = math.huge
		for i = first, last do
			local sample = samples[i]
			local dx = position.X - sample.Position.X
			local dz = position.Z - sample.Position.Z
			local distanceSq = dx * dx + dz * dz
			if distanceSq < bestDistanceSq then
				bestDistanceSq = distanceSq
				best = sample
			end
		end
		local offset = Vector3.new(position.X - best.Position.X, 0, position.Z - best.Position.Z)
		return best, best.Distance + offset:Dot(best.ForwardFlat), offset:Dot(best.Left)
	end

	--[[
		Où est-on sur le tracé ? Recherche du point le plus proche dans le plan
		horizontal (le tracé ne passe jamais au-dessus de lui-même), puis
		projection sur la tangente pour une abscisse continue entre deux points.
		Renvoie : l'échantillon, l'abscisse curviligne, l'écart latéral (signé,
		positif à gauche). ~2000 points : une recherche complète par frame reste
		négligeable.
	]]
	function track.Locate(position: Vector3): (Sample, number, number)
		return nearest(position, 1, #samples)
	end

	--[[
		Comme Locate, mais en ne cherchant qu'autour d'un échantillon connu (±window) :
		pour suivre une trajectoire point après point (le fantôme, Ghost.luau) sans
		parcourir tout le tracé à chaque point.
	]]
	function track.LocateNear(position: Vector3, hint: number, window: number): (Sample, number, number)
		return nearest(position, math.max(1, hint - window), math.min(#samples, hint + window))
	end

	return track
end

return StageTrack
