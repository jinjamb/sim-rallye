--!strict
--[[
	Rolls.luau
	Les tirages : un objet au hasard parmi ceux du catalogue marqués Roll
	(Catalog.luau), selon sa rareté (Rarity.luau). Le tirage est fait par le
	serveur (RollService) ; ce module donne les règles et les probabilités,
	affichées telles quelles au joueur.

	ON NE LES ACHÈTE PAS : un tirage se gagne en jouant (un par niveau, un
	pour les trois défis du jour, des paliers du Rallye Pass). Ce ne sont
	donc pas des « objets aléatoires payants » au sens des règles de Roblox.
	Si un jour ils deviennent achetables (en Robux, ou en crédits achetables
	en Robux), il faudra : garder l'affichage des probabilités, et refuser
	l'achat aux joueurs pour qui PolicyService indique
	ArePaidRandomItemsRestricted.

	TIRAGE EN DEUX TEMPS : la rareté d'abord (poids de Rarity.luau), puis un
	objet de cette rareté, au hasard. Une rareté sans objet disponible est
	retirée du tirage (ses chances se répartissent sur les autres).

	GARANTIE : au moins un objet de rareté Usine ou plus tous les PITY_LIMIT
	tirages (le compteur repart à zéro à chaque Usine, Prototype, Légende).

	DOUBLON : un objet déjà possédé est converti en crédits (DUPLICATE_CREDITS).
]]

local Catalog = require(script.Parent.Catalog)
local Rarity = require(script.Parent.Rarity)

local Rolls = {}

Rolls.PITY_LIMIT = 10
Rolls.PITY_RANK = 4 -- rang de rareté garanti (Usine)

Rolls.DUPLICATE_CREDITS = {
	Club = 100,
	Pro = 250,
	Usine = 600,
	Prototype = 1500,
	Legende = 4000,
} :: { [string]: number }

-- Objets qui peuvent sortir d'un tirage, par rareté.
function Rolls.Pool(): { [string]: { Catalog.Item } }
	local pool: { [string]: { Catalog.Item } } = {}
	for _, item in ipairs(Catalog.ITEMS) do
		if item.Roll and Catalog.IsAvailable(item) and Rarity.Get(item.Rarity).Weight > 0 then
			local list = pool[item.Rarity]
			if not list then
				list = {}
				pool[item.Rarity] = list
			end
			table.insert(list, item)
		end
	end
	return pool
end

export type Odds = { Rarity: string, Chance: number, Items: { Catalog.Item } }

--[[
	Probabilités de chaque rareté (0..1, total 1), dans l'ordre des raretés.
	`guaranteed` : la garantie joue (seules les raretés Usine et plus).
]]
function Rolls.Odds(guaranteed: boolean?): { Odds }
	local pool = Rolls.Pool()
	local total = 0
	local list: { Odds } = {}
	for _, id in ipairs(Rarity.ORDER) do
		local info = Rarity.Get(id)
		local items = pool[id]
		if items and #items > 0 and info.Weight > 0 and (not guaranteed or info.Rank >= Rolls.PITY_RANK) then
			total += info.Weight
			local entry: Odds = { Rarity = id, Chance = info.Weight, Items = items }
			table.insert(list, entry)
		end
	end
	for _, entry in ipairs(list) do
		entry.Chance /= math.max(total, 1)
	end
	return list
end

-- La garantie joue-t-elle pour ce tirage ? (`pity` : tirages depuis le dernier Usine+)
function Rolls.IsGuaranteed(pity: number): boolean
	return pity >= Rolls.PITY_LIMIT - 1
end

-- Tire un objet. `random` : le générateur du serveur.
function Rolls.Draw(random: Random, pity: number): Catalog.Item?
	local odds = Rolls.Odds(Rolls.IsGuaranteed(pity))
	if #odds == 0 then
		odds = Rolls.Odds(false)
	end
	if #odds == 0 then
		return nil
	end
	local roll = random:NextNumber()
	local chosen = odds[#odds]
	for _, entry in ipairs(odds) do
		roll -= entry.Chance
		if roll < 0 then
			chosen = entry
			break
		end
	end
	return chosen.Items[random:NextInteger(1, #chosen.Items)]
end

-- Le compteur de garantie après avoir tiré `item`.
function Rolls.NextPity(pity: number, item: Catalog.Item): number
	return if Rarity.Get(item.Rarity).Rank >= Rolls.PITY_RANK then 0 else pity + 1
end

-- "60 %", "3,2 %", "0,8 %" : arrondi lisible.
function Rolls.FormatChance(chance: number): string
	local percent = chance * 100
	local text = if percent >= 10 then string.format("%.0f %%", percent) else string.format("%.1f %%", percent)
	return (string.gsub(text, "%.", ","))
end

return Rolls
