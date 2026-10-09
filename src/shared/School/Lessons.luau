--!strict
--[[
	Lessons.luau
	L'école de pilotage : de courtes leçons, chacune sur un passage de la
	spéciale (pas de piste à construire), notées par les médailles du jeu
	(bronze à platine, Medals.luau).

		Freinage     : la ligne droite du départ. Prendre de l'élan, puis
		               s'arrêter dans la zone : noté sur la précision.
		Frein à main : l'épingle droite au bas de la descente, au chrono.
		Épingle      : l'épingle gauche en montée, au chrono, SANS frein à
		               main : la trajectoire et le freinage seuls.
		Saut         : le tremplin. Décoller à la bonne vitesse (la réception
		               est calculée pour 90-120 km/h) et retomber sur ses roues.

	Les passages sont repérés par les SEGMENTS de la spéciale (StageTrack :
	numéro de segment), pas par des distances écrites en dur : si le tracé
	bouge, les leçons suivent.

	Le déroulement est chez le pilote (DrivingSchool.luau, la physique tourne
	chez lui) ; le serveur garde la meilleure médaille de chaque leçon et en
	tire de l'XP (Progression.luau). Ce n'est qu'un apprentissage : rien
	n'entre dans les classements.

	SEUILS : premier jet, à ajuster en roulant (la sortie de Studio affiche le
	résultat de chaque essai : [École] ...).
]]

local StageTrack = require(script.Parent.Parent.Stage.StageTrack)

local Lessons = {}

export type Kind = "Brake" | "Timed" | "Jump"

export type Lesson = {
	Id: string,
	Name: string,
	Kind: Kind,
	Goal: string, -- l'objectif, en une phrase
	Tips: string, -- comment s'y prendre
	-- Passage, en segments de la spéciale (StageTrack.GetSegments).
	StartSegment: number, -- départ de la leçon : début de ce segment
	StartOffset: number, -- studs après le début du segment
	EndSegment: number, -- fin de la leçon : fin de ce segment...
	EndOffset: number, -- ... plus ces studs
	-- Seuils des médailles (bronze -> platine), du moins bon au meilleur :
	-- Brake : écart à la cible (studs) ; Timed : temps (s) ; Jump : écart à la
	-- vitesse idéale (km/h).
	Limits: { number },
	NoHandbrake: boolean?,
	-- Brake : vitesse à atteindre (km/h), début de la zone jaune et cible
	-- (studs après le début du segment de départ).
	MinSpeed: number?,
	ZoneOffset: number?,
	TargetOffset: number?,
	-- Jump : vitesse idéale au décollage (km/h), et le segment du tremplin
	-- (le décollage est à sa fin).
	IdealSpeed: number?,
	RampSegment: number?,
}

Lessons.LIST = {
	{
		Id = "brake",
		Name = "Freinage",
		Kind = "Brake",
		Goal = "Prends de l'élan (70 km/h au moins), puis arrête-toi dans la zone jaune.",
		Tips = "Freine fort et tôt, en ligne droite ; relâche un peu à la fin pour t'arrêter pile.",
		-- ~110 studs pour atteindre 70 km/h, ~95 pour s'arrêter sur la terre.
		StartSegment = 1,
		StartOffset = 30,
		EndSegment = 1,
		EndOffset = 0,
		Limits = { 10, 5, 2.5, 1 },
		MinSpeed = 70,
		ZoneOffset = 230,
		TargetOffset = 275,
	},
	{
		Id = "handbrake",
		Name = "Frein à main",
		Kind = "Timed",
		Goal = "Passe l'épingle droite le plus vite possible.",
		Tips = "Freine en ligne droite, braque, un coup de frein à main (Espace) pour faire pivoter l'arrière, puis remets les gaz.",
		StartSegment = 15,
		StartOffset = 250,
		EndSegment = 16,
		EndOffset = 60,
		Limits = { 12, 10.5, 9.5, 8.8 },
	},
	{
		Id = "hairpin",
		Name = "Épingle",
		Kind = "Timed",
		Goal = "Passe l'épingle gauche en montée, sans frein à main.",
		Tips = "Freine avant de tourner, reste à l'extérieur, vise la corde tard et réaccélère tôt.",
		StartSegment = 5,
		StartOffset = 0,
		EndSegment = 6,
		EndOffset = 80,
		Limits = { 14, 12, 11, 10.3 },
		NoHandbrake = true,
	},
	{
		Id = "jump",
		Name = "Saut",
		Kind = "Jump",
		Goal = "Décolle du tremplin vers 105 km/h et retombe sur tes roues, sur la route.",
		Tips = "Trop lent, tu retombes à plat ; trop vite, tu dépasses la pente. Stabilise la voiture avant le tremplin.",
		-- ~475 studs d'élan jusqu'au tremplin : il en faut ~300 pour 105 km/h.
		StartSegment = 7,
		StartOffset = 100,
		EndSegment = 10,
		EndOffset = 0,
		Limits = { 12, 7, 4, 2 },
		IdealSpeed = 105,
		RampSegment = 9,
	},
} :: { Lesson }

-- XP d'une médaille d'école, cumulée par leçon (platine = 150 au total).
Lessons.MEDAL_XP = { 25, 50, 100, 150 }

function Lessons.Get(id: string?): Lesson?
	for _, lesson in ipairs(Lessons.LIST) do
		if lesson.Id == id then
			return lesson
		end
	end
	return nil
end

-- Abscisse (studs le long de la spéciale) du départ et de la fin de la leçon.
function Lessons.Distances(lesson: Lesson): (number, number)
	local segments = StageTrack.GetSegments()
	local first = segments[lesson.StartSegment]
	local last = segments[lesson.EndSegment]
	return first.StartDistance + lesson.StartOffset, last.EndDistance + lesson.EndOffset
end

-- Où poser la voiture : au départ de la leçon, dans l'axe de la route.
function Lessons.StartFrame(lesson: Lesson): CFrame
	local start = Lessons.Distances(lesson)
	local sample = StageTrack.SampleAt(start)
	local position = sample.Position + Vector3.new(0, StageTrack.DROP_HEIGHT, 0)
	return CFrame.lookAt(position, position + sample.Forward)
end

-- Médaille (0 à 4) d'un score : plus petit = meilleur.
function Lessons.TierOf(lesson: Lesson, score: number): number
	local tier = 0
	for i, limit in ipairs(lesson.Limits) do
		if score <= limit then
			tier = i
		end
	end
	return tier
end

return Lessons
