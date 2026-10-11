--!strict
--[[
	PassService.luau
	Le Rallye Pass (Pass.luau) : l'XP de la saison (chaque gain d'XP du
	joueur, ProgressService), les paliers atteints et leurs récompenses,
	données aussitôt (crédits, tirages, objets : EconomyService). La voie
	premium s'achète en Robux (EconomyService : produit pass_premium) ;
	achetée en cours de saison, elle donne d'un coup les récompenses premium
	des paliers déjà atteints.

	SAUVEGARDE regroupée (ProfileStore.Defer), écrite d'après l'état en
	mémoire au moment d'écrire : un achat premium enregistré entre-temps
	(ProcessReceipt) n'est jamais écrasé.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Pass = require(ReplicatedStorage.Shared.Economy.Pass)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local EconomyService = require(script.Parent.EconomyService)
local AchievementService = require(script.Parent.AchievementService)

local PassService = {}

type PassState = ProfileSchema.PassState

-- L'état de la saison en cours (une saison passée repart de zéro).
local function stateOf(profile: ProfileSchema.Profile): PassState
	local season = Pass.Current()
	local state = profile.Pass
	if not state or state.Key ~= season.Key then
		state = { Key = season.Key, Xp = 0, Premium = false, FreeUpTo = 0, PremiumUpTo = 0 }
		profile.Pass = state
	end
	return state :: PassState
end

local function save(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	ProfileStore.Defer(player, "Pass", function(stored)
		local live = profile.Pass
		if not live then
			return
		end
		local copy = table.clone(live)
		local old = stored.Pass
		if old and old.Key == copy.Key and old.Premium then
			copy.Premium = true -- acheté ailleurs, ou juste avant : jamais perdu
		end
		stored.Pass = copy
	end)
end

local function sendPass(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	local state = stateOf(profile)
	local season = Pass.Current()
	Remotes.PassState:FireClient(player, {
		Key = season.Key,
		Name = season.Name,
		EndsAt = season.EndsAt,
		Xp = state.Xp,
		Premium = state.Premium,
	}, news)
end

local function giveReward(player: Player, reward: Pass.Reward, label: string)
	if reward.Credits then
		EconomyService.Earn(player, reward.Credits, label)
	end
	if reward.Rolls then
		EconomyService.AddRolls(player, reward.Rolls, label)
	end
	local item = reward.Item
	if item and not EconomyService.Grant(player, item, label) then
		EconomyService.Earn(player, Pass.DUPLICATE_CREDITS, label .. " (déjà possédé)")
	end
end

-- Donne les récompenses des paliers atteints qui ne l'ont pas encore été.
-- Renvoie le nombre de paliers nouvellement atteints.
local function grantReached(player: Player, state: PassState): number
	local tier = Pass.TierOf(state.Xp)
	local reached = 0
	for index = state.FreeUpTo + 1, tier do
		giveReward(player, Pass.TIERS[index].Free, "Rallye Pass, palier " .. index)
		reached += 1
	end
	state.FreeUpTo = math.max(state.FreeUpTo, tier)
	if tier >= #Pass.TIERS then
		AchievementService.Award(player, "pass_complete")
	end
	if state.Premium then
		for index = state.PremiumUpTo + 1, tier do
			giveReward(player, Pass.TIERS[index].Premium, "Rallye Pass premium, palier " .. index)
		end
		state.PremiumUpTo = math.max(state.PremiumUpTo, tier)
	end
	return reached
end

-- XP gagnée par le joueur (ProgressService) : elle compte pour la saison.
function PassService.AddXp(player: Player, xp: number)
	local profile = ProfileStore.Get(player)
	if not profile or xp <= 0 then
		return
	end
	local state = stateOf(profile)
	local before = Pass.TierOf(state.Xp)
	state.Xp += math.floor(xp)
	local reached = grantReached(player, state)
	save(player)
	sendPass(player, if reached > 0 then { TierReached = Pass.TierOf(state.Xp), From = before } else nil)
end

-- Voie premium achetée (EconomyService) : les récompenses premium déjà atteintes.
function PassService.OnPremium(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local state = stateOf(profile)
	state.Premium = true
	grantReached(player, state)
	save(player)
	sendPass(player, { Premium = true })
end

function PassService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		-- Nouvelle saison, ou premium acheté hors ligne : on met à jour.
		grantReached(player, stateOf(profile))
		save(player)
		sendPass(player)
	end)
end

return PassService
