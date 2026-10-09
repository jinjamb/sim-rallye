--!strict
--[[
	Teams.luau
	Les écuries : des pilotes qui roulent sous les mêmes couleurs.

		- Une écurie a un nom, un sigle de 2 à 4 caractères (affiché devant le
		  nom de ses pilotes, au-dessus de leur voiture) et deux couleurs
		  (carrosserie et bandes, parmi les couleurs de base de Livery.luau).
		- Un pilote peut porter les couleurs de son écurie (au garage) : sa
		  carrosserie et ses bandes prennent celles de l'écurie.
		- On entre dans une écurie sur invitation d'un de ses pilotes, entre
		  joueurs d'un même serveur (entre amis, typiquement).
		- CLASSEMENT DES ÉCURIES : chaque point d'XP gagné par un pilote pendant
		  la saison du Rallye Pass (Pass.luau) compte pour son écurie. Remis à
		  zéro à chaque saison.

	Le nom et le sigle passent par le filtre de texte de Roblox (serveur,
	TeamService) : refusés s'il les censure.
]]

local Livery = require(script.Parent.Parent.Cosmetics.Livery)

local Teams = {}

Teams.MAX_MEMBERS = 8
Teams.NAME_MIN, Teams.NAME_MAX = 3, 24
Teams.TAG_MIN, Teams.TAG_MAX = 2, 4
Teams.INVITE_TIME = 120 -- secondes pour accepter une invitation

-- Couleurs d'écurie possibles : les couleurs de base de la livrée.
Teams.COLOR_COUNT = Livery.FREE_COLORS

export type Team = {
	Id: string,
	Name: string,
	Tag: string,
	Color: number, -- Livery.COLORS (carrosserie)
	Stripe: number, -- Livery.COLORS (bandes)
	OwnerId: number,
	Members: { number }, -- UserId, le fondateur compris
}

-- Nom propre : espaces simplifiés, longueur bornée. nil s'il est invalide.
function Teams.CleanName(input: any): string?
	if type(input) ~= "string" then
		return nil
	end
	local name = string.gsub(string.gsub(input, "%s+", " "), "^ ", "")
	name = (string.gsub(name, " $", ""))
	local length = utf8.len(name) or #name
	if length < Teams.NAME_MIN or length > Teams.NAME_MAX then
		return nil
	end
	return name
end

-- Sigle : lettres et chiffres, en capitales. nil s'il est invalide.
function Teams.CleanTag(input: any): string?
	if type(input) ~= "string" then
		return nil
	end
	local tag = string.upper(input)
	if not string.match(tag, "^[%u%d]+$") or #tag < Teams.TAG_MIN or #tag > Teams.TAG_MAX then
		return nil
	end
	return tag
end

function Teams.CleanColor(input: any): number?
	if type(input) ~= "number" or input ~= input or input % 1 ~= 0 then
		return nil
	end
	return if input >= 1 and input <= Teams.COLOR_COUNT then input else nil
end

-- La livrée d'un pilote aux couleurs de son écurie (bandes visibles d'office).
function Teams.ApplyColors(livery: Livery.Livery, team: Team): Livery.Livery
	local colored = table.clone(livery)
	colored.Color = team.Color
	colored.StripeColor = team.Stripe
	if colored.Stripes <= 1 then
		colored.Stripes = 2
	end
	return colored
end

return Teams
