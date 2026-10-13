--!strict
--[[
	Plausibility.luau
	Ce qu'une voiture peut réellement faire, pour juger les passages
	chronométrés (StageService, RaceService). La physique tourne chez le
	joueur : un tricheur peut faire aller sa voiture plus vite. Deux garde-fous
	s'ajoutent à la vitesse instantanée maximale (250 studs/s, déjà vérifiée) :

	VITESSE MOYENNE : un temps est refusé s'il est plus court que le temps de
	la médaille de platine divisé par MIN_TIME_FACTOR. Le platine, c'est le
	niveau des meilleurs pilotes du jeu (Medals.luau, calibré en roulant) :
	aller 60 % plus vite qu'eux sur tout un parcours n'arrive pas en
	conduisant. (Pourquoi pas une vitesse de pointe par voiture : avec un pont
	long, toutes les voitures du jeu approchent légitimement 230 studs/s en
	ligne droite ; ce plafond ne resserrerait presque rien.)

	ACCÉLÉRATION : la vitesse le long du tracé, mesurée sur une seconde, ne
	peut pas gagner plus de MAX_ACCELERATION par seconde (~2 g : au-delà de
	l'adhérence et de la puissance de toutes les voitures, même en descente).
	Les à-coups du réseau peuvent fausser une mesure : le passage n'est refusé
	qu'au MAX_STRIKES-ième dépassement.

	Recaler les médailles (_G.MedalReport) recale ces garde-fous du même coup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Medals = require(ReplicatedStorage.Shared.Progression.Medals)

local Plausibility = {}

Plausibility.MIN_TIME_FACTOR = 1.6
Plausibility.MAX_ACCELERATION = 70 -- studs/s²
Plausibility.MAX_STRIKES = 3

local PLATINUM = 4 -- rang du platine dans les seuils (Medals.TIERS)

-- Temps minimal (ms) d'un passage de spéciale pour cette catégorie.
function Plausibility.MinimumStageMs(classId: string?, stageId: string?): number
	local limits = Medals.ForStage(classId, stageId)
	return (limits[PLATINUM] or 0) / Plausibility.MIN_TIME_FACTOR
end

-- Temps minimal (ms) d'un tour de circuit pour cette catégorie.
function Plausibility.MinimumLapMs(trackId: string, lapLength: number, classId: string?): number
	local limits = Medals.ForCircuit(trackId, lapLength, classId)
	return (limits[PLATINUM] or 0) / Plausibility.MIN_TIME_FACTOR
end

--[[
	Suivi de l'accélération d'une voiture : on lui donne (instant, avancement
	le long du tracé) à chaque mesure ; il compte les fois où la vitesse sur
	une seconde monte plus vite que MAX_ACCELERATION. Rend true quand c'est trop.
]]
export type Tracker = { Samples: { { T: number, P: number } }, LastSpeed: number?, LastSpeedAt: number, Strikes: number }

function Plausibility.NewTracker(): Tracker
	return { Samples = {}, LastSpeed = nil, LastSpeedAt = 0, Strikes = 0 }
end

local WINDOW = 1 -- secondes

function Plausibility.Accelerating(tracker: Tracker, now: number, progress: number): boolean
	local samples = tracker.Samples
	table.insert(samples, { T = now, P = progress })
	while #samples > 2 and now - samples[2].T >= WINDOW do
		table.remove(samples, 1)
	end
	local first = samples[1]
	if now - first.T < WINDOW * 0.9 then
		return false
	end
	local speed = (progress - first.P) / (now - first.T)
	local last = tracker.LastSpeed
	if last == nil then
		tracker.LastSpeed = speed
		tracker.LastSpeedAt = now
	elseif now - tracker.LastSpeedAt >= WINDOW then
		if (speed - last) / (now - tracker.LastSpeedAt) > Plausibility.MAX_ACCELERATION then
			tracker.Strikes += 1
		end
		tracker.LastSpeed = speed
		tracker.LastSpeedAt = now
	end
	return tracker.Strikes >= Plausibility.MAX_STRIKES
end

return Plausibility
