--!strict
--[[
	StyleService.luau
	Points de style : dérapages et sauts (détectés par le client, la physique
	tourne chez lui), dépassements (détectés par le serveur, RaceService).
	Ils ne servent qu'à la progression (XP, donc des cosmétiques) et aux
	défis du jour.

	COMPTÉS EN COMPÉTITION SEULEMENT : en spéciale chronométrée (passage en
	cours, ou fini depuis quelques secondes : StageService) ou en course de
	rallycross. Pas aux essais libres : sinon des donuts sur la piste d'essai
	suffiraient à monter de niveau.

	DÉBIT PLAUSIBLE : le serveur n'accepte qu'un débit moyen (on ne dérape pas
	en permanence), avec une réserve pour encaisser d'un coup une longue
	combinaison (15 s au ×5 : ~15 000 points). Un tricheur plafonne donc à
	~5 000 XP de l'heure, et seulement en cosmétiques.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local ProgressService = require(script.Parent.ProgressService)
local ChallengeService = require(script.Parent.ChallengeService)
local StageService = require(script.Parent.StageService)

local StyleService = {}

local STYLE_RATE = 300 -- points par seconde, en moyenne
local STYLE_BURST = 20000
local STYLE_KINDS = { Drift = true, Jump = true }

type Allowance = { Points: number, At: number }

-- Points de style décidés par le serveur (dépassements, RaceService).
function StyleService.Add(player: Player, points: number)
	if points > 0 then
		ProgressService.AddCounters(player, 0, math.floor(points))
	end
end

-- Défis du jour : points de style, combinaison, multiplicateur, saut.
local function dailyEvents(player: Player, kind: string, accepted: number, detail: any)
	ChallengeService.DailyEvent(player, "Style", accepted)
	local info = if type(detail) == "table" then detail else {}
	if kind == "Drift" then
		ChallengeService.DailyEvent(player, "DriftCombo", accepted)
		local multiplier = info.Multiplier
		if type(multiplier) == "number" and multiplier == multiplier then
			ChallengeService.DailyEvent(player, "DriftMultiplier", math.clamp(math.floor(multiplier), 1, 5))
		end
	elseif kind == "Jump" then
		local air = info.Air
		if type(air) == "number" and air == air and air >= 1 and air <= 10 then
			ChallengeService.DailyEvent(player, "LongJump", 1)
		end
	end
end

function StyleService.Start()
	local allowances: { [Player]: Allowance } = {}
	Remotes.SubmitStyle.OnServerEvent:Connect(function(player: Player, points: any, kind: any, detail: any)
		if type(points) ~= "number" or points ~= points or points <= 0 or not STYLE_KINDS[kind] then
			return
		end
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local chassis = car and car:FindFirstChild("Chassis")
		if not car or not chassis or chassis:GetAttribute("Driven") ~= true then
			return
		end
		-- En compétition seulement : course de rallycross, ou spéciale chronométrée.
		if car:GetAttribute("RaceId") == nil and not StageService.IsInTimedRun(player) then
			return
		end
		local now = os.clock()
		local allowance: Allowance = allowances[player] or { Points = STYLE_BURST, At = now }
		allowance.Points = math.min(STYLE_BURST, allowance.Points + (now - allowance.At) * STYLE_RATE)
		allowance.At = now
		local accepted = math.floor(math.min(points, allowance.Points))
		allowance.Points -= accepted
		allowances[player] = allowance
		if accepted > 0 then
			ProgressService.AddCounters(player, 0, accepted)
			dailyEvents(player, kind, accepted, detail)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		allowances[player] = nil
	end)
end

return StyleService
