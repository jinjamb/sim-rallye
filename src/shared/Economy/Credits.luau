--!strict
--[[
	Credits.luau
	La monnaie du jeu : les crédits (CR). On les gagne en jouant (barème
	ci-dessous, appliqué par le serveur), on peut en acheter en Robux
	(Products.luau), et on les dépense pour débloquer des voitures et
	certains objets (Catalog.luau).

	BARÈME : de quoi débloquer une voiture en quelques soirées sans payer, et
	récompenser surtout ce qui fait revenir (défis, médailles, niveaux)
	plutôt que la répétition (une spéciale terminée rapporte peu).
	Course en solo : une petite somme seulement (sinon on gagnerait seul,
	sans adversaire, autant qu'en vraie course).
]]

local Format = require(script.Parent.Parent.Util.Format)

local Credits = {}

Credits.NAME = "crédits"
Credits.SHORT = "CR"

Credits.REWARDS = {
	StageRun = 25, -- spéciale terminée (temps validé)
	WeeklyFirst = 150, -- défi de la semaine, première arrivée de la semaine
	RaceFinish = 40, -- course à plusieurs, arrivée
	RacePodium = 60, -- en plus, sur le podium
	RaceWin = 120, -- en plus, vainqueur
	SoloRace = 15, -- course seul, arrivée
	DailyChallenge = 50, -- chaque défi du jour réussi
	DailyBonus = 100, -- les trois défis du jour
	LevelUp = 150, -- chaque niveau gagné
	-- Première médaille à ce palier (bronze -> platine), sur chaque tracé.
	Medal = { 100, 200, 400, 800 },
}

-- 12500 -> "12 500 CR"
function Credits.Format(amount: number): string
	return Format.Thousands(amount) .. " " .. Credits.SHORT
end

return Credits
