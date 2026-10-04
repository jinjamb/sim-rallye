--!strict
--[[
	Circuit.luau
	Géométrie d'un circuit de rallycross, construite à partir de sa description
	(Tracks/Definitions). Partagée par :
		- tools/build-circuit.luau : terrain, barrières, portique, grille ;
		- RaceService (serveur)    : tours, joker, positions, anti-raccourci ;
		- le client                : remise en piste, mini-carte, HUD.
	Tous calculent exactement la même courbe.

	DESCRIPTION PAR SOMMETS : un circuit est une BOUCLE FERMÉE de sommets ; chaque
	sommet est arrondi par un arc de cercle de rayon donné (raccord tangent avec
	les deux lignes droites voisines). Contrairement au tracé "à la tortue" de la
	spéciale, la boucle se ferme d'elle-même : pas d'erreur de fermeture à
	corriger. Un rayon trop grand pour la place disponible est réduit.

		Material : surface à partir de ce sommet (son virage et la ligne droite qui
		           suit) ; absente = celle du sommet précédent.
		Height   : hauteur au milieu du virage (studs, relative à Origin.Y) ; le
		           profil est raccordé en douceur d'un sommet à l'autre.

	JOKER : branche obligatoire une fois par course. Elle quitte la boucle sur une
	ligne droite (From), la longe sur Lead studs puis s'en écarte, contourne ses
	points Via et la rejoint (To). Son avancement est rapporté à celui de la
	boucle, au prorata : le classement reste continu sur le joker.

	SAUTS : bosse en lame, montée rectiligne de Up studs jusqu'à l'arête, descente
	de Down studs. Plus la descente est longue, plus la réception est douce.

	ABSCISSE : la ligne de départ / arrivée est à 0 ; elle croît dans le sens de
	course et revient à 0 à chaque tour (Length).

	Repère : X, Z horizontaux, Y vertical. Un "sommet" X/Z est relatif à Origin.
	Gauche d'une direction horizontale d = (d.Z, -d.X), comme StageTrack.
]]

local Circuit = {}
Circuit.__index = Circuit

export type PointDef = {
	X: number,
	Z: number,
	Radius: number?,
	Material: Enum.Material?,
	Height: number?,
}

export type EdgeRef = { Edge: number, T: number }

export type JumpDef = {
	Edge: number,
	T: number,
	Height: number,
	Up: number,
	Down: number,
}

export type JokerDef = {
	From: EdgeRef,
	To: EdgeRef,
	Lead: number,
	Radius: number,
	Via: { PointDef },
	Material: Enum.Material?,
}

export type Definition = {
	Id: string,
	Name: string,
	Description: string,
	Origin: Vector3,
	RoadWidth: number,
	JokerWidth: number,
	Points: { PointDef },
	StartLine: EdgeRef,
	Joker: JokerDef,
	Jumps: { JumpDef }?,
	DefaultLaps: number,
}

export type Sample = {
	Index: number,
	Position: Vector3, -- centre de la piste, au niveau de la chaussée
	Forward: Vector3, -- tangente 3D (suit la pente)
	ForwardFlat: Vector3,
	Left: Vector3,
	Distance: number, -- boucle : depuis la ligne ; joker : depuis l'embranchement
	Curvature: number,
	Material: Enum.Material,
	HalfWidth: number,
	IsJoker: boolean,
}

export type Location = {
	Sample: Sample,
	OnJoker: boolean,
	Progress: number, -- abscisse ramenée à la boucle, dans [0, Length)
	Lateral: number, -- écart à l'axe, positif à gauche
	JokerFraction: number, -- avancement dans le joker (0..1), 0 hors joker
}

export type Circuit = typeof(setmetatable({}, Circuit)) & {
	Id: string,
	Name: string,
	Description: string,
	Key: string, -- identifiant de sauvegarde : change si le tracé change
	Definition: Definition,
	Origin: Vector3,
	RoadWidth: number,
	JokerWidth: number,
	DefaultLaps: number,
	Length: number,
	JokerLength: number,
	JokerStartProgress: number,
	JokerEndProgress: number,
	Samples: { Sample },
	JokerSamples: { Sample },
	Corners: number,
	HeightFunction: (number) -> number, -- abscisse brute -> hauteur
	StartRaw: number, -- abscisse brute de la ligne de départ
}

Circuit.SAMPLE_STEP = 4 -- studs : la résolution des voxels de terrain
local MIN_STRAIGHT = 8 -- ligne droite minimale gardée entre deux virages
local SEARCH_WINDOW = 60 -- échantillons explorés autour du dernier repère connu

-- Grille : rangées de trois, celle du milieu décalée (départ en quinconce).
local GRID_FIRST_ROW = 18 -- studs entre la ligne et la première rangée
local GRID_ROW_SPACING = 28
local GRID_STAGGER = 9
local GRID_LATERAL = 0.3 -- en fraction de la largeur de piste
local DROP_HEIGHT = 3.5 -- la voiture est posée un peu au-dessus de la chaussée

--------------------------------------------------------------------------------
-- Construction d'un chemin à virages arrondis
--------------------------------------------------------------------------------

type RawPoint = {
	P: Vector2,
	D: Vector2,
	Curvature: number,
	Owner: number, -- sommet dont la surface s'applique
	Raw: number, -- abscisse brute depuis le début du chemin
}

type CornerInfo = { U1: Vector2, U2: Vector2, Phi: number, Radius: number }
type HeightKey = { D: number, H: number }
type Lip = { D: number, Height: number, Up: number, Down: number }

local function leftOf(d: Vector2): Vector2
	return Vector2.new(d.Y, -d.X)
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function tangentLength(corner: CornerInfo?): number
	if not corner then
		return 0
	end
	return corner.Radius * math.tan(math.abs(corner.Phi) / 2)
end

--[[
	points : sommets (X, Z, rayon) ; closed : boucle ou chemin ouvert (le premier et
	le dernier sommet d'un chemin ouvert ne sont pas arrondis).
	Renvoie les points échantillonnés, la longueur, et l'abscisse brute du milieu
	de chaque virage (pour le profil en long).
]]
local function buildPath(points: { Vector2 }, radii: { number }, closed: boolean): ({ RawPoint }, number, { [number]: number }, number)
	local n = #points
	local corners: { [number]: CornerInfo } = {}
	local first, last = if closed then 1 else 2, if closed then n else n - 1
	for i = first, last do
		local a = points[((i - 2) % n) + 1]
		local b = points[i]
		local c = points[(i % n) + 1]
		local u1 = (b - a).Unit
		local u2 = (c - b).Unit
		local phi = math.atan2(u2:Dot(leftOf(u1)), u2:Dot(u1))
		if math.abs(phi) > 1e-4 and radii[i] > 0 then
			corners[i] = { U1 = u1, U2 = u2, Phi = phi, Radius = radii[i] }
		end
	end

	-- Rayons trop grands pour la place : réduits jusqu'à laisser une ligne droite.
	local reduced = 0
	for _ = 1, 4 do
		local edgeCount = if closed then n else n - 1
		for i = 1, edgeCount do
			local j = (i % n) + 1
			local length = (points[j] - points[i]).Magnitude
			local ti, tj = tangentLength(corners[i]), tangentLength(corners[j])
			if ti + tj > length - MIN_STRAIGHT then
				local k = math.max(0.05, (length - MIN_STRAIGHT) / (ti + tj))
				for _, index in ipairs({ i, j }) do
					local corner = corners[index]
					if corner then
						corner.Radius *= k
						reduced += 1
					end
				end
			end
		end
	end

	local raw: { RawPoint } = {}
	local keyDistances: { [number]: number } = {}
	local distance = 0
	local previous: Vector2? = nil

	local function emit(p: Vector2, d: Vector2, curvature: number, owner: number)
		if previous then
			distance += (p - previous).Magnitude
		end
		previous = p
		table.insert(raw, { P = p, D = d, Curvature = curvature, Owner = owner, Raw = distance })
	end

	local function arcEnds(i: number): (Vector2, Vector2)
		local corner = corners[i]
		if not corner then
			return points[i], points[i]
		end
		local t = tangentLength(corner)
		return points[i] - corner.U1 * t, points[i] + corner.U2 * t
	end

	local cursor: Vector2
	local owner: number
	local sequence: { number } = {}
	if closed then
		local _, endOfFirst = arcEnds(1)
		cursor = endOfFirst
		owner = 1
		for i = 2, n do
			table.insert(sequence, i)
		end
		table.insert(sequence, 1)
	else
		cursor = points[1]
		owner = 1
		for i = 2, n do
			table.insert(sequence, i)
		end
	end

	local step = Circuit.SAMPLE_STEP
	for _, i in ipairs(sequence) do
		local isEnd = not closed and i == n
		local arcStart, arcEnd = points[n], points[n]
		if not isEnd then
			arcStart, arcEnd = arcEnds(i)
		end

		-- Ligne droite jusqu'au début du virage.
		local delta = arcStart - cursor
		local length = delta.Magnitude
		if length > 1e-6 then
			local direction = delta.Unit
			local count = math.max(1, math.ceil(length / step))
			for m = 0, count - 1 do
				emit(cursor + direction * (length * m / count), direction, 0, owner)
			end
		end

		local corner = if isEnd then nil else corners[i]
		if corner then
			local sign = if corner.Phi > 0 then 1 else -1
			local leftDir = leftOf(corner.U1)
			local center = arcStart + leftDir * corner.Radius * sign
			local v = arcStart - center
			local leftV = leftOf(v)
			local arcLength = math.abs(corner.Phi) * corner.Radius
			local count = math.max(1, math.ceil(arcLength / step))
			local arcStartDistance = distance + (if previous then (arcStart - (previous :: Vector2)).Magnitude else 0)
			keyDistances[i] = arcStartDistance + arcLength / 2
			for m = 0, count - 1 do
				local a = corner.Phi * m / count
				local p = center + v * math.cos(a) + leftV * math.sin(a)
				local d = corner.U1 * math.cos(a) + leftDir * math.sin(a)
				emit(p, d, sign / corner.Radius, i)
			end
		elseif not isEnd then
			keyDistances[i] = distance + (if previous then (arcStart - (previous :: Vector2)).Magnitude else 0)
		end
		owner = i
		cursor = arcEnd
	end

	if closed then
		distance += (raw[1].P - (previous :: Vector2)).Magnitude
	else
		emit(points[n], raw[#raw].D, 0, n - 1)
	end
	return raw, distance, keyDistances, reduced
end

--------------------------------------------------------------------------------
-- Circuit
--------------------------------------------------------------------------------

local function pointOnEdge(points: { Vector2 }, ref: EdgeRef): (Vector2, Vector2)
	local a = points[ref.Edge]
	local b = points[(ref.Edge % #points) + 1]
	return a + (b - a) * ref.T, (b - a).Unit
end

local function nearestRaw(raw: { RawPoint }, p: Vector2): number
	local best, bestIndex = math.huge, 1
	for index, point in ipairs(raw) do
		local d = (point.P - p).Magnitude
		if d < best then
			best, bestIndex = d, index
		end
	end
	return bestIndex
end

local function wrap(value: number, length: number): number
	return value % length
end

-- Écart signé le plus court entre deux abscisses d'une boucle.
local function wrappedDelta(value: number, length: number): number
	local d = value % length
	if d > length / 2 then
		d -= length
	end
	return d
end

function Circuit.new(definition: Definition): Circuit
	local self = (setmetatable({}, Circuit) :: any) :: Circuit
	self.Id = definition.Id
	self.Name = definition.Name
	self.Description = definition.Description
	self.Definition = definition
	self.Origin = definition.Origin
	self.RoadWidth = definition.RoadWidth
	self.JokerWidth = definition.JokerWidth
	self.DefaultLaps = definition.DefaultLaps

	local origin = definition.Origin
	local points: { Vector2 } = {}
	local radii: { number } = {}
	for i, point in ipairs(definition.Points) do
		points[i] = Vector2.new(point.X, point.Z)
		radii[i] = point.Radius or 0
	end
	local n = #points
	self.Corners = n

	-- Boucle principale -----------------------------------------------------------
	local raw, length, keyDistances, _ = buildPath(points, radii, true)
	self.Length = length

	-- Surface par sommet, héritée du précédent.
	local materials: { Enum.Material } = {}
	local currentMaterial = definition.Points[1].Material or Enum.Material.Asphalt
	for i = 1, n do
		currentMaterial = definition.Points[i].Material or currentMaterial
		materials[i] = currentMaterial
	end

	-- Profil en long : clés au milieu de chaque virage, raccord en douceur.
	local keys: { HeightKey } = {}
	for i = 1, n do
		local d = keyDistances[i]
		if d then
			table.insert(keys, { D = d, H = definition.Points[i].Height or 0 })
		end
	end
	table.sort(keys, function(a, b)
		return a.D < b.D
	end)
	local function baseHeight(d: number): number
		if #keys == 0 then
			return 0
		end
		d = wrap(d, length)
		local count = #keys
		for k = 1, count do
			local a = keys[k]
			local b = keys[(k % count) + 1]
			local da, db = a.D, b.D
			if k == count then
				db += length
			end
			local dd = d
			if dd < da then
				dd += length
			end
			if dd >= da and dd <= db then
				local t = if db > da then (dd - da) / (db - da) else 0
				return a.H + (b.H - a.H) * smoothstep(t)
			end
		end
		return keys[1].H
	end

	-- Sauts.
	local lips: { Lip } = {}
	for _, jump in ipairs(definition.Jumps or {}) do
		local p = pointOnEdge(points, { Edge = jump.Edge, T = jump.T })
		local index = nearestRaw(raw, p)
		table.insert(lips, { D = raw[index].Raw, Height = jump.Height, Up = jump.Up, Down = jump.Down })
	end
	local function height(d: number): number
		local h = baseHeight(d)
		for _, lip in ipairs(lips) do
			local delta = wrappedDelta(d - lip.D, length)
			if delta >= -lip.Up and delta <= 0 then
				h += lip.Height * (1 + delta / lip.Up)
			elseif delta > 0 and delta <= lip.Down then
				h += lip.Height * (1 - delta / lip.Down)
			end
		end
		return h
	end
	self.HeightFunction = height

	-- Ligne de départ : la boucle est renumérotée pour commencer sur elle.
	local startPoint = pointOnEdge(points, definition.StartLine)
	local startIndex = nearestRaw(raw, startPoint)
	local startRaw = raw[startIndex].Raw
	self.StartRaw = startRaw

	local samples: { Sample } = {}
	local count = #raw
	for k = 0, count - 1 do
		local point = raw[((startIndex - 1 + k) % count) + 1]
		local d = Vector3.new(point.D.X, 0, point.D.Y)
		table.insert(samples, {
			Index = k + 1,
			Position = origin + Vector3.new(point.P.X, height(point.Raw), point.P.Y),
			Forward = d,
			ForwardFlat = d,
			Left = Vector3.new(d.Z, 0, -d.X),
			Distance = wrap(point.Raw - startRaw, length),
			Curvature = point.Curvature,
			Material = materials[point.Owner],
			HalfWidth = definition.RoadWidth / 2,
			IsJoker = false,
		})
	end
	for i, sample in ipairs(samples) do
		local before = samples[((i - 2) % count) + 1].Position
		local after = samples[(i % count) + 1].Position
		local delta = after - before
		sample.Forward = if delta.Magnitude > 1e-6 then delta.Unit else sample.ForwardFlat
	end
	self.Samples = samples

	-- Joker ---------------------------------------------------------------------
	local joker = definition.Joker
	local from, fromDir = pointOnEdge(points, joker.From)
	local to, toDir = pointOnEdge(points, joker.To)
	local jokerPoints: { Vector2 } = { from, from + fromDir * joker.Lead }
	local jokerRadii: { number } = { 0, joker.Radius }
	for _, via in ipairs(joker.Via) do
		table.insert(jokerPoints, Vector2.new(via.X, via.Z))
		table.insert(jokerRadii, via.Radius or joker.Radius)
	end
	table.insert(jokerPoints, to - toDir * joker.Lead)
	table.insert(jokerRadii, joker.Radius)
	table.insert(jokerPoints, to)
	table.insert(jokerRadii, 0)

	local jokerRaw, jokerLength = buildPath(jokerPoints, jokerRadii, false)
	self.JokerLength = jokerLength
	self.JokerStartProgress = wrap(raw[nearestRaw(raw, from)].Raw - startRaw, length)
	self.JokerEndProgress = wrap(raw[nearestRaw(raw, to)].Raw - startRaw, length)
	local startHeight = height(raw[nearestRaw(raw, from)].Raw)
	local endHeight = height(raw[nearestRaw(raw, to)].Raw)
	local jokerMaterial = joker.Material or Enum.Material.Ground

	local jokerSamples: { Sample } = {}
	for k, point in ipairs(jokerRaw) do
		local d = Vector3.new(point.D.X, 0, point.D.Y)
		local fraction = if jokerLength > 0 then point.Raw / jokerLength else 0
		table.insert(jokerSamples, {
			Index = k,
			Position = origin + Vector3.new(point.P.X, startHeight + (endHeight - startHeight) * smoothstep(fraction), point.P.Y),
			Forward = d,
			ForwardFlat = d,
			Left = Vector3.new(d.Z, 0, -d.X),
			Distance = point.Raw,
			Curvature = point.Curvature,
			Material = jokerMaterial,
			HalfWidth = definition.JokerWidth / 2,
			IsJoker = true,
		})
	end
	for i, sample in ipairs(jokerSamples) do
		local before = jokerSamples[math.max(1, i - 1)].Position
		local after = jokerSamples[math.min(#jokerSamples, i + 1)].Position
		local delta = after - before
		sample.Forward = if delta.Magnitude > 1e-6 then delta.Unit else sample.ForwardFlat
	end
	self.JokerSamples = jokerSamples

	self.Key = string.format("rx_%s_%d", definition.Id, math.floor(length))
	return self
end

--------------------------------------------------------------------------------
-- Requêtes
--------------------------------------------------------------------------------

-- Hauteur de la chaussée (relative à Origin.Y) à une abscisse de la boucle.
function Circuit:HeightAt(progress: number): number
	return self.HeightFunction(progress + self.StartRaw)
end

-- Échantillon de la boucle à une abscisse (ramenée dans [0, Length)).
function Circuit:SampleAt(progress: number): Sample
	local samples = self.Samples
	progress = wrap(progress, self.Length)
	local guess = math.clamp(math.floor(progress / Circuit.SAMPLE_STEP) + 1, 1, #samples)
	while guess > 1 and samples[guess].Distance > progress do
		guess -= 1
	end
	while guess < #samples and samples[guess + 1].Distance <= progress do
		guess += 1
	end
	return samples[guess]
end

local function horizontalDistanceSq(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return dx * dx + dz * dz
end

-- Échantillon le plus proche, cherché autour d'un indice connu (ou partout).
local function nearest(samples: { Sample }, position: Vector3, hint: number?, closed: boolean): (Sample, number)
	local count = #samples
	local best, bestSq = samples[1], math.huge
	if hint then
		for offset = -SEARCH_WINDOW, SEARCH_WINDOW do
			local index = hint + offset
			if closed then
				index = ((index - 1) % count) + 1
			elseif index < 1 or index > count then
				continue
			end
			local sample = samples[index]
			local sq = horizontalDistanceSq(position, sample.Position)
			if sq < bestSq then
				best, bestSq = sample, sq
			end
		end
		-- Trop loin : téléportation, ou repère perdu. Recherche complète.
		if bestSq <= (best.HalfWidth * 3) ^ 2 then
			return best, bestSq
		end
		bestSq = math.huge
	end
	for _, sample in ipairs(samples) do
		local sq = horizontalDistanceSq(position, sample.Position)
		if sq < bestSq then
			best, bestSq = sample, sq
		end
	end
	return best, bestSq
end

--[[
	Où est-on ? Sur la boucle tant qu'on est sur sa chaussée ; sinon, sur le
	joker si on est sur la sienne ; sinon, sur le plus proche des deux.
	hint : la dernière réponse pour cette voiture (recherche locale, plus rapide
	et sans saut vers une autre portion de piste proche).
]]
function Circuit:Locate(position: Vector3, hint: Location?): Location
	local mainHint = if hint and not hint.OnJoker then hint.Sample.Index else nil
	local jokerHint = if hint and hint.OnJoker then hint.Sample.Index else nil

	local mainSample, mainSq = nearest(self.Samples, position, mainHint, true)
	local mainOffset = Vector3.new(position.X - mainSample.Position.X, 0, position.Z - mainSample.Position.Z)
	local mainLateral = mainOffset:Dot(mainSample.Left)

	local useJoker = false
	local jokerSample: Sample? = nil
	local jokerLateral = 0
	local jokerOffset = Vector3.zero
	if math.abs(mainLateral) > mainSample.HalfWidth + 2 then
		local candidate, jokerSq = nearest(self.JokerSamples, position, jokerHint, false)
		jokerOffset = Vector3.new(position.X - candidate.Position.X, 0, position.Z - candidate.Position.Z)
		jokerLateral = jokerOffset:Dot(candidate.Left)
		if math.abs(jokerLateral) <= candidate.HalfWidth + 2 or jokerSq < mainSq then
			useJoker = true
			jokerSample = candidate
		end
	end

	if useJoker and jokerSample then
		local along = math.clamp(jokerSample.Distance + jokerOffset:Dot(jokerSample.ForwardFlat), 0, self.JokerLength)
		local fraction = if self.JokerLength > 0 then along / self.JokerLength else 0
		local span = wrap(self.JokerEndProgress - self.JokerStartProgress, self.Length)
		return {
			Sample = jokerSample,
			OnJoker = true,
			Progress = wrap(self.JokerStartProgress + span * fraction, self.Length),
			Lateral = jokerLateral,
			JokerFraction = fraction,
		}
	end
	return {
		Sample = mainSample,
		OnJoker = false,
		Progress = wrap(mainSample.Distance + mainOffset:Dot(mainSample.ForwardFlat), self.Length),
		Lateral = mainLateral,
		JokerFraction = 0,
	}
end

local function frameOn(sample: Sample, lateral: number, back: number): CFrame
	local position = sample.Position + sample.Left * lateral - sample.ForwardFlat * back + Vector3.new(0, DROP_HEIGHT, 0)
	return CFrame.lookAt(position, position + sample.Forward)
end

-- Place de grille (1 = pole position), derrière la ligne de départ.
function Circuit:GridSlot(slot: number): CFrame
	local index = slot - 1
	local row = index // 3
	local column = index % 3
	local back = GRID_FIRST_ROW + row * GRID_ROW_SPACING + (if column == 1 then GRID_STAGGER else 0)
	local sample = self:SampleAt(self.Length - back)
	-- Colonnes : pole au centre-gauche, puis gauche, puis droite, rangée après rangée.
	local lateral = (if column == 0 then 1 elseif column == 1 then 0 else -1) * self.RoadWidth * GRID_LATERAL
	local position = sample.Position + sample.Left * lateral + Vector3.new(0, DROP_HEIGHT, 0)
	return CFrame.lookAt(position, position + sample.Forward)
end

--[[
	Remise en piste : sur l'axe le plus proche (boucle ou joker), face au sens de
	course. Si une voiture occupe déjà la place, on essaie à côté puis un peu en
	arrière : deux voitures posées l'une dans l'autre seraient éjectées.
]]
function Circuit:RecoverFrame(position: Vector3, occupied: { Vector3 }?): CFrame
	local location = self:Locate(position)
	local sample = location.Sample
	local quarter = sample.HalfWidth / 2
	local candidates = {
		{ 0, 0 }, { quarter, 0 }, { -quarter, 0 },
		{ 0, 20 }, { quarter, 20 }, { -quarter, 20 },
		{ 0, 40 },
	}
	for _, candidate in ipairs(candidates) do
		local frame = frameOn(sample, candidate[1], candidate[2])
		local free = true
		for _, other in ipairs(occupied or {}) do
			if horizontalDistanceSq(frame.Position, other) < 12 * 12 then
				free = false
				break
			end
		end
		if free then
			return frame
		end
	end
	return frameOn(sample, 0, 0)
end

-- Emprise horizontale (boucle + joker), pour la mini-carte.
function Circuit:GetBounds(): (Vector2, Vector2)
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, list in ipairs({ self.Samples, self.JokerSamples }) do
		for _, sample in ipairs(list) do
			local p = sample.Position
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
	end
	return Vector2.new(minX, minZ), Vector2.new(maxX, maxZ)
end

-- Avancement signé le plus court entre deux abscisses (gère le passage de ligne).
function Circuit:ProgressDelta(from: number, to: number): number
	return wrappedDelta(to - from, self.Length)
end

return Circuit
