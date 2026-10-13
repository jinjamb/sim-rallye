--!strict
--[[
	MedalCalibration.luau
	Recaler les médailles en roulant, dans Studio seulement.

	Chaque temps validé (spéciale : StageService ; tour de circuit :
	RaceService) est retenu ici : le meilleur, par tracé et par catégorie.
	Ensuite, dans la barre de commande de Studio (côté serveur) :

		_G.MedalReport()

	affiche, pour chaque tracé roulé, la vitesse moyenne de son meilleur
	passage par catégorie et la médaille qu'il vaut ; puis :
		- les VITESSES SUGGÉRÉES du tracé (Stages.luau : MedalSpeeds, ou
		  Medals.luau pour un circuit), en partant du principe que ton
		  meilleur passage en Rally2 vaut l'OR (les écarts entre paliers sont
		  gardés) ;
		- les MEDALSCALE MESURÉS de chaque catégorie, par surface et pour
		  les circuits (CarClasses.luau) : sa vitesse rapportée à celle de la
		  Rally2, sur les tracés roulés avec les deux.
	Il suffit de recopier les chiffres. Plus on roule de tracés avec chaque
	voiture, plus ils sont justes. Rien n'est sauvegardé : tout repart à
	zéro au prochain lancement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)

local MedalCalibration = {}

local REFERENCE = "Rally2"
local GOLD = 3

type Best = { Kmh: number, Ms: number }
-- Tracé -> catégorie -> meilleur passage. Tracé : "stage:<id>" ou "circuit:<id>".
local bests: { [string]: { [string]: Best } } = {}
local enabled = RunService:IsStudio()

local function remember(key: string, classId: string, kmh: number, ms: number)
	if not enabled then
		return
	end
	local byClass = bests[key] or {}
	bests[key] = byClass
	local previous = byClass[classId]
	if not previous or kmh > previous.Kmh then
		byClass[classId] = { Kmh = kmh, Ms = ms }
	end
end

-- Un temps validé sur une spéciale.
function MedalCalibration.Stage(stageId: string, classId: string, ms: number)
	remember("stage:" .. stageId, classId, Medals.AverageKmh(Medals.StageDistance(stageId), ms), ms)
end

-- Un tour de circuit validé (sans joker).
function MedalCalibration.Lap(trackId: string, classId: string, lapLength: number, lapMs: number)
	remember("circuit:" .. trackId, classId, Medals.AverageKmh(lapLength, lapMs), lapMs)
end

local function speedsText(speeds: { number }): string
	local parts = {}
	for _, kmh in ipairs(speeds) do
		table.insert(parts, string.format("%d", math.floor(kmh + 0.5)))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Vitesses visées (Rally2) et surface d'un tracé.
local function trackInfo(key: string): ({ number }, string, string)
	local kind, id = string.match(key, "^(%a+):(.+)$")
	if kind == "stage" and id then
		local track = Stages.Get(id)
		return track.MedalSpeeds, track.Surface, track.Name
	end
	return Medals.CircuitSpeeds(id or ""), "Circuit", id or key
end

local function report()
	if next(bests) == nil then
		print("[Calibrage] Aucun temps validé pour l'instant : roule quelques spéciales ou tours de circuit, puis relance _G.MedalReport().")
		return
	end
	print("[Calibrage] ===== Médailles : meilleurs passages de cette session =====")
	-- Ratios par catégorie et par surface (moyenne géométrique), d'après la Rally2.
	local ratios: { [string]: { [string]: { number } } } = {}
	local keys = {}
	for key in pairs(bests) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local byClass = bests[key]
		local speeds, surface, name = trackInfo(key)
		print(string.format("[Calibrage] %s (%s)", name, surface))
		for _, class in ipairs(CarClasses.LIST) do
			local best = byClass[class.Id]
			if best then
				local scale = (class.MedalScale :: any)[surface] or 1
				local tier = 0
				for i, kmh in ipairs(speeds) do
					if best.Kmh >= kmh * scale then
						tier = i
					end
				end
				local tierName = if tier > 0 then Medals.TIERS[tier].Name else "aucune"
				print(string.format("[Calibrage]    %-8s %6.1f km/h  (%.2f s) -> %s", class.Name, best.Kmh, best.Ms / 1000, tierName))
			end
		end
		local reference = byClass[REFERENCE]
		if reference then
			-- Ton meilleur passage en Rally2 vaut l'or : les autres paliers gardent leurs écarts.
			local suggested = {}
			for i, kmh in ipairs(speeds) do
				suggested[i] = reference.Kmh * kmh / speeds[GOLD]
			end
			print(string.format("[Calibrage]    vitesses suggérées : %s (actuelles : %s)", speedsText(suggested), speedsText(speeds)))
			for classId, best in pairs(byClass) do
				if classId ~= REFERENCE then
					local bySurface = ratios[classId] or {}
					ratios[classId] = bySurface
					local list = bySurface[surface] or {}
					bySurface[surface] = list
					table.insert(list, best.Kmh / reference.Kmh)
				end
			end
		end
	end
	print("[Calibrage] ----- MedalScale mesurés (CarClasses.luau) -----")
	local any = false
	for _, class in ipairs(CarClasses.LIST) do
		local bySurface = ratios[class.Id]
		if bySurface then
			for surface, list in pairs(bySurface) do
				local logSum = 0
				for _, ratio in ipairs(list) do
					logSum += math.log(ratio)
				end
				local measured = math.exp(logSum / #list)
				local current = (class.MedalScale :: any)[surface] or 1
				print(string.format("[Calibrage]    %-8s %-7s %.2f (actuel %.2f, sur %d tracé%s)", class.Name, surface, measured, current, #list, if #list > 1 then "s" else ""))
				any = true
			end
		end
	end
	if not any then
		print("[Calibrage]    Il faut au moins un tracé roulé en Rally2 ET avec une autre voiture.")
	end
end

function MedalCalibration.Start()
	if enabled then
		(_G :: any).MedalReport = report
	end
end

return MedalCalibration
