--!strict
--[[
	ReferralService.luau
	Le parrainage (règles et montants : Referral.luau).

	ARRIVÉE D'UN FILLEUL : à sa toute première venue (profil vierge), son
	parrain est noté dans son profil (ReferredBy). Rien n'est encore donné :
	un compte créé juste pour l'invitation ne rapporte rien.

	IL PREND LE VOLANT (Qualify : première spéciale terminée, appelée par
	TutorialService, ou première course de rallycross, par RaceService) :
		- le filleul reçoit son bonus de bienvenue ;
		- le parrain reçoit le sien, qu'il soit là ou non : la récompense
		  est mise de côté dans SON profil sauvegardé (ReferralsPending), puis
		  remise par le serveur où il joue -- tout de suite s'il est connecté
		  (ici, ou ailleurs : prévenu par MessagingService), sinon à sa
		  prochaine venue.
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Referral = require(ReplicatedStorage.Shared.Social.Referral)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local EconomyService = require(script.Parent.EconomyService)
local AchievementService = require(script.Parent.AchievementService)

local ReferralService = {}

local TOPIC = "Referral" -- MessagingService : un parrain à récompenser (son UserId)

local claiming: { [Player]: boolean } = {}

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return if ok and type(name) == "string" then name else "ton ami"
end

-- `news` : { Welcome = parrain } à l'arrivée, { Bonus = crédits, Inviter } quand
-- le filleul prend le volant, { Rewarded = amis, Credits, Rolls } pour le parrain.
local function sendState(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	Remotes.ReferralState:FireClient(player, {
		Referrals = profile.Referrals,
		Max = Referral.MAX_REWARDED,
		InviterCredits = Referral.INVITER_CREDITS,
		InviterRolls = Referral.INVITER_ROLLS,
		NewcomerCredits = Referral.NEWCOMER_CREDITS,
	}, news)
end

-- Un profil qui n'a encore rien fait : la première venue.
local function isNewcomer(profile: any): boolean
	return profile.StageRuns == 0
		and profile.Stats.Races == 0
		and next(profile.Lessons) == nil
		and next(profile.Achievements) == nil
		and not profile.TutorialDone
end

-- Le parrain du joueur qui arrive, ou nil.
local function referrerOf(player: Player): number?
	local joinData = player:GetJoinData() :: any
	-- Donné par Roblox (invitation, lien de partage) : sûr.
	local byRoblox = joinData.ReferredByPlayerId
	if type(byRoblox) == "number" and byRoblox > 0 and byRoblox ~= player.UserId then
		return byRoblox
	end
	-- Porté par l'invitation du jeu : seulement entre amis.
	local referrer = Referral.Decode(joinData.LaunchData).Referrer
	if referrer and referrer ~= player.UserId then
		local ok, friends = pcall(function()
			return player:IsFriendsWith(referrer)
		end)
		if ok and friends then
			return referrer
		end
	end
	return nil
end

-- Remet au parrain connecté ici les récompenses mises de côté dans son profil.
local function claim(player: Player)
	if claiming[player] or not ProfileStore.Get(player) then
		return
	end
	claiming[player] = true
	local count = 0
	local saved = ProfileStore.UpdateNow(player.UserId, "parrainage", function(stored)
		count = stored.ReferralsPending
		if count == 0 then
			return false
		end
		stored.ReferralsPending = 0
		stored.Referrals += count
		return true
	end)
	claiming[player] = nil
	local profile = ProfileStore.Get(player)
	if not saved or count == 0 or not profile or not player.Parent then
		return
	end
	profile.Referrals += count
	profile.ReferralsPending = 0
	local reason = if count > 1 then string.format("Parrainage : %d amis ont pris le volant", count) else "Parrainage : un ami a pris le volant"
	EconomyService.Earn(player, Referral.INVITER_CREDITS * count, reason)
	EconomyService.AddRolls(player, Referral.INVITER_ROLLS * count, "Parrainage")
	AchievementService.Award(player, "recruiter")
	sendState(player, { Rewarded = count, Credits = Referral.INVITER_CREDITS * count, Rolls = Referral.INVITER_ROLLS * count })
end

-- Met la récompense de côté dans le profil du parrain, puis le prévient.
local function rewardInviter(inviterId: number)
	local stored = false
	local saved = ProfileStore.UpdateNow(inviterId, "parrainage", function(profile)
		stored = false
		if profile.Referrals + profile.ReferralsPending >= Referral.MAX_REWARDED then
			return false
		end
		profile.ReferralsPending += 1
		stored = true
		return true
	end)
	if not saved or not stored then
		return
	end
	local here = Players:GetPlayerByUserId(inviterId)
	if here then
		claim(here)
		return
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, inviterId)
	end)
end

--[[
	Le joueur vient de prendre le volant (spéciale terminée, course finie) :
	si c'est un filleul pas encore récompensé, les deux le sont maintenant.
]]
function ReferralService.Qualify(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile or not profile.ReferredBy or profile.ReferralQualified then
		return
	end
	local inviterId = profile.ReferredBy :: number
	profile.ReferralQualified = true
	ProfileStore.Defer(player, "ReferralQualified", function(stored)
		stored.ReferralQualified = true
	end)
	EconomyService.Earn(player, Referral.NEWCOMER_CREDITS, "Bonus de parrainage")
	task.spawn(function()
		local inviterName = nameOf(inviterId)
		sendState(player, { Bonus = Referral.NEWCOMER_CREDITS, Inviter = inviterName })
		rewardInviter(inviterId)
	end)
end

local function onLoaded(player: Player, profile: any)
	if profile.ReferredBy == nil and isNewcomer(profile) then
		local inviterId = referrerOf(player)
		if inviterId and player.Parent then
			profile.ReferredBy = inviterId
			ProfileStore.Defer(player, "ReferredBy", function(stored)
				if stored.ReferredBy == nil then
					stored.ReferredBy = inviterId
				end
			end)
			sendState(player, { Welcome = nameOf(inviterId) })
		else
			sendState(player)
		end
	else
		sendState(player)
	end
	-- Des amis ont pris le volant pendant son absence.
	if profile.ReferralsPending > 0 then
		claim(player)
	end
end

function ReferralService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		task.spawn(onLoaded, player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		claiming[player] = nil
	end)
	-- Un filleul a pris le volant sur un autre serveur : son parrain joue peut-être ici.
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message: any)
				local userId = if type(message) == "table" then message.Data else nil
				local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
				if player then
					claim(player)
				end
			end)
		end)
	end)
end

return ReferralService
