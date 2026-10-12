--!strict
--[[
	TutorialService.luau
	Le tutoriel express : un nouveau pilote est au volant en quelques
	secondes, sur la spéciale par défaut, au sec, guidé pas à pas (le
	client : Tutorial.luau), avec un seul objectif : passer la ligne
	d'arrivée. La première spéciale terminée boucle le tutoriel et rapporte
	une récompense de bienvenue.

	QUI : un profil qui n'a encore rien fait (ni spéciale, ni course, ni
	leçon). Un ancien joueur arrivé avant le tutoriel en est dispensé. On
	peut le passer (bouton PASSER) : il n'est plus proposé.

	Le client lance lui-même la spéciale (PlayMode, comme depuis le menu) ;
	StageService prévient ce service à chaque arrivée (StageFinished).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local EconomyService = require(script.Parent.EconomyService)
local ReferralService = require(script.Parent.ReferralService)

local TutorialService = {}

local REWARD_CREDITS = 250
local REWARD_ROLLS = 1

local function markDone(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	profile.TutorialDone = true
	ProfileStore.Defer(player, "TutorialDone", function(stored)
		stored.TutorialDone = true
	end)
end

-- `news` : { Completed = true, Credits, Rolls } à l'arrivée du tutoriel.
local function sendState(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	Remotes.Tutorial:FireClient(player, {
		Active = not profile.TutorialDone,
		StageId = Stages.DEFAULT,
		Credits = REWARD_CREDITS,
		Rolls = REWARD_ROLLS,
	}, news)
end

-- Une spéciale terminée (temps validé) : la première boucle le tutoriel.
function TutorialService.StageFinished(player: Player)
	local profile = ProfileStore.Get(player)
	if profile and not profile.TutorialDone then
		markDone(player)
		EconomyService.Earn(player, REWARD_CREDITS, "Tutoriel terminé")
		EconomyService.AddRolls(player, REWARD_ROLLS, "Bienvenue")
		sendState(player, { Completed = true, Credits = REWARD_CREDITS, Rolls = REWARD_ROLLS })
	end
	-- Un filleul qui prend le volant : le parrainage récompense les deux.
	ReferralService.Qualify(player)
end

function TutorialService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		-- Déjà joué avant le tutoriel : dispensé.
		if not profile.TutorialDone
			and (profile.StageRuns > 0 or profile.Stats.Races > 0 or next(profile.Lessons) ~= nil) then
			markDone(player)
		end
		sendState(player)
	end)
	Remotes.TutorialAction.OnServerEvent:Connect(function(player: Player, action: any)
		if action == "Skip" then
			local profile = ProfileStore.Get(player)
			if profile and not profile.TutorialDone then
				markDone(player)
				sendState(player)
			end
		end
	end)
end

return TutorialService
