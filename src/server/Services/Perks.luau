--!strict
--[[
	Perks.luau
	Les avantages d'un joueur, lus par l'économie et la progression :
		- pass de jeu possédés (Products.PASSES : Premium, Crédits ×2, VIP) ;
		  le Premium vaut tous les autres (Perks.Has), plus les sessions
		  privées (SessionService) et la voie premium du Rallye Pass de la
		  saison d'achat (PassService) ;
		- abonné Roblox Premium ;
		- boost d'XP acheté (profil, XpBoostUntil) ;
		- objets aléatoires payants interdits dans son pays (PolicyService) ;
		- l'événement éclair « Pluie de crédits » (FlashEvents.luau).

	Tenu à jour par MonetizationService ; volontairement sans dépendance vers
	les services, pour qu'EconomyService et ProgressService puissent le lire
	sans boucle de require.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)

local Perks = {}

-- Bonus des abonnés Roblox Premium (crédits gagnés en jouant).
Perks.PREMIUM_CREDIT_BONUS = 0.1
-- VIP : XP en plus (pass de jeu).
Perks.VIP_XP_BONUS = 0.25

type State = {
	Passes: { [string]: boolean },
	Premium: boolean,
	RandomRestricted: boolean,
}

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { Passes = {}, Premium = false, RandomRestricted = false }
		states[player] = state
	end
	return state
end

function Perks.SetPass(player: Player, key: string, owned: boolean)
	stateOf(player).Passes[key] = owned
end

function Perks.HasPass(player: Player, key: string): boolean
	return stateOf(player).Passes[key] == true
end

-- Le pass Premium de Sim Rallye (à ne pas confondre avec Roblox Premium : IsPremium).
function Perks.HasPremiumPass(player: Player): boolean
	return Perks.HasPass(player, "premium")
end

-- Un avantage de pass : le pass lui-même, ou le Premium qui les contient tous.
function Perks.Has(player: Player, key: string): boolean
	return Perks.HasPass(player, key) or Perks.HasPremiumPass(player)
end

function Perks.SetPremium(player: Player, premium: boolean)
	stateOf(player).Premium = premium
end

function Perks.IsPremium(player: Player): boolean
	return stateOf(player).Premium
end

function Perks.SetRandomRestricted(player: Player, restricted: boolean)
	stateOf(player).RandomRestricted = restricted
end

function Perks.IsRandomRestricted(player: Player): boolean
	return stateOf(player).RandomRestricted
end

-- Fin du boost d'XP (os.time), 0 sans boost.
function Perks.XpBoostUntil(player: Player): number
	local profile = ProfileStore.Get(player)
	return if profile then profile.XpBoostUntil else 0
end

-- Multiplicateur des crédits gagnés en jouant (pas des achats).
function Perks.CreditMultiplier(player: Player): number
	local multiplier = if Perks.Has(player, "credits_x2") then 2 else 1
	if Perks.IsPremium(player) then
		multiplier += Perks.PREMIUM_CREDIT_BONUS
	end
	return multiplier * FlashEvents.CreditMultiplier(os.time())
end

-- Multiplicateur de l'XP gagnée (en plus des événements double XP).
function Perks.XpMultiplier(player: Player): number
	local multiplier = 1
	if Perks.Has(player, "vip") then
		multiplier += Perks.VIP_XP_BONUS
	end
	if Perks.XpBoostUntil(player) > os.time() then
		multiplier *= 2
	end
	return multiplier
end

-- Ce que le joueur voit de ses avantages (boutique, HUD).
function Perks.Snapshot(player: Player): any
	local state = stateOf(player)
	return {
		Passes = table.clone(state.Passes),
		Premium = state.Premium,
		RandomRestricted = state.RandomRestricted,
		XpBoostUntil = Perks.XpBoostUntil(player),
	}
end

function Perks.Forget(player: Player)
	states[player] = nil
end

return Perks
