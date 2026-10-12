--!strict
--[[
	Pass.luau
	Le Rallye Pass : une saison de SEASON_WEEKS semaines, TIER_COUNT paliers
	gagnés avec l'XP de la saison (toute l'XP gagnée pendant la saison :
	Progression.luau). Chaque palier a une récompense gratuite, et une
	récompense premium pour qui a acheté la voie premium de la saison
	(produit Robux « pass_premium », Products.luau).

	LES SAISONS commencent un lundi 0 h UTC, comme les semaines du défi
	(Weekly.luau) : la saison 1 a commencé le lundi 5 octobre 2026. Tous les
	serveurs calculent la même, sans rien se dire. La progression repart de
	zéro à chaque saison ; la voie premium se rachète à chaque saison.

	RÉCOMPENSES ACCORDÉES D'OFFICE : un palier atteint donne aussitôt sa
	récompense gratuite (et premium si on l'a) ; passer premium en cours de
	saison donne d'un coup les récompenses premium des paliers déjà
	atteints. Une récompense objet déjà possédée est convertie en crédits.

	NOUVELLE SAISON : les récompenses se changent dans REWARDS ci-dessous
	(les objets marqués Pass dans Items/ doivent y figurer).
]]

local Pass = {}

Pass.SEASON_WEEKS = 8
Pass.TIER_COUNT = 30
Pass.TIER_XP = 1000 -- XP de saison par palier
Pass.FIRST_WEEK = 2962 -- semaine (Weekly.luau) du lundi 5 octobre 2026 : début de la saison 1
Pass.DUPLICATE_CREDITS = 500 -- objet de récompense déjà possédé

local DAY = 86400
local WEEK_OFFSET_DAYS = 3 -- comme Weekly.luau

export type Reward = { Credits: number?, Rolls: number?, Item: string? }
export type Tier = { Free: Reward, Premium: Reward }

export type Season = {
	Index: number,
	Key: string, -- "s1"
	Name: string,
	StartsAt: number,
	EndsAt: number,
}

-- Les paliers : crédits, tirages tous les 5 paliers, et les objets du Pass.
local function buildTiers(): { Tier }
	local tiers: { Tier } = {}
	for tier = 1, Pass.TIER_COUNT do
		local free: Reward = if tier % 5 == 0 then { Rolls = 1 } else { Credits = 150 + tier * 10 }
		local premium: Reward = if tier % 3 == 0 then { Rolls = 1 } else { Credits = 300 + tier * 20 }
		tiers[tier] = { Free = free, Premium = premium }
	end
	-- Les objets du Pass (Items/ : Pass = true).
	tiers[12].Free = { Item = "engine_turbo" }
	tiers[20].Free = { Item = "smoke_tricolore" }
	tiers[8].Premium = { Item = "horn_train" }
	tiers[15].Premium = { Item = "smoke_neon" }
	tiers[25].Premium = { Item = "cel_lightning" }
	tiers[30].Premium = { Item = "engine_legend" }
	return tiers
end

Pass.TIERS = buildTiers()

function Pass.At(time: number): Season
	local days = math.floor(time / DAY)
	local week = (days + WEEK_OFFSET_DAYS) // 7
	local index = math.max(1, (week - Pass.FIRST_WEEK) // Pass.SEASON_WEEKS + 1)
	local firstWeek = Pass.FIRST_WEEK + (index - 1) * Pass.SEASON_WEEKS
	local startsAt = (firstWeek * 7 - WEEK_OFFSET_DAYS) * DAY
	return {
		Index = index,
		Key = "s" .. tostring(index),
		Name = "Saison " .. tostring(index),
		StartsAt = startsAt,
		EndsAt = startsAt + Pass.SEASON_WEEKS * 7 * DAY,
	}
end

function Pass.Current(): Season
	return Pass.At(os.time())
end

-- Palier atteint avec `xp` d'XP de saison (0 à TIER_COUNT).
function Pass.TierOf(xp: number): number
	return math.clamp(math.floor(xp / Pass.TIER_XP), 0, Pass.TIER_COUNT)
end

return Pass
