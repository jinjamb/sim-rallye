--!strict
--[[
	FlashEvents.luau
	Les ÉVÉNEMENTS ÉCLAIR : au début de chaque quart d'heure (h00, h15, h30,
	h45, heure du serveur), un coup de boost de DURATION secondes, annoncé
	WARNING secondes avant. Le même au même moment sur tous les serveurs :
	il se déduit de l'heure (pas de stockage, pas de message entre serveurs).

	LES SORTES (KINDS), tirées dans un ordre mélangé qui change à chaque tour
	(jamais deux fois la même d'affilée) :
		Rolls     tirages boostés : chances ×ROLL_BOOST pour les objets Usine,
		          Prototype et Légende (Rolls.luau) ;
		FreeRoll  tirage offert : terminer une spéciale ou une course pendant
		          l'événement rapporte un tirage (une fois par événement) ;
		Credits   pluie de crédits : crédits gagnés ×CREDIT_MULTIPLIER ;
		Xp        XP éclair : XP gagnée ×XP_MULTIPLIER (sans se cumuler avec
		          un week-end double XP : le plus fort l'emporte) ;
		RareCar   voiture rare : une voiture d'exception (WRC ou Groupe B)
		          prêtée à tous pour les spéciales, et les voitures de sa
		          catégorie CAR_DISCOUNT moins cher en crédits.

	Le serveur applique les effets (RollService, Perks, ProgressService,
	EconomyService, PaddockService, FlashEventService) ; le client affiche
	l'événement (EventNotice.luau, menu JOUER). Heure : os.time() côté
	serveur, workspace:GetServerTimeNow() côté client.
]]

local FlashEvents = {}

FlashEvents.PERIOD = 15 * 60 -- un événement par quart d'heure
FlashEvents.DURATION = 5 * 60 -- secondes de boost
FlashEvents.WARNING = 60 -- annoncé une minute avant

FlashEvents.ROLL_BOOST = 3
FlashEvents.CREDIT_MULTIPLIER = 2
FlashEvents.XP_MULTIPLIER = 2
FlashEvents.CAR_DISCOUNT = 0.3
FlashEvents.RARE_CARS = { "WRC", "GroupB" }

export type KindId = "Rolls" | "FreeRoll" | "Credits" | "Xp" | "RareCar"
export type Kind = { Id: KindId, Name: string, Description: string, Icon: string }

FlashEvents.KINDS = {
	{ Id = "Rolls", Name = "Tirages boostés", Icon = "🎁", Description = "Chances ×3 pour les objets Usine, Prototype et Légende." },
	{ Id = "FreeRoll", Name = "Tirage offert", Icon = "🎟", Description = "Termine une spéciale ou une course : un tirage offert." },
	{ Id = "Credits", Name = "Pluie de crédits", Icon = "💰", Description = "Tous les crédits gagnés comptent double." },
	{ Id = "Xp", Name = "XP éclair", Icon = "⚡", Description = "Toute l'XP gagnée compte double." },
	{ Id = "RareCar", Name = "Voiture rare", Icon = "🏎", Description = "Prêtée à tous sur les spéciales, et -30 % en crédits sur les voitures de sa catégorie." },
} :: { Kind }

export type Event = {
	Kind: Kind,
	Slot: number, -- numéro du quart d'heure (identifie l'événement)
	StartsAt: number,
	EndsAt: number,
	CarClass: string?, -- RareCar : la voiture du moment (CarClasses.luau)
}

-- Ordre mélangé des sortes pour le tour `round` (un tour = #KINDS quarts d'heure).
local function shuffled(round: number): { number }
	local order = {}
	for i = 1, #FlashEvents.KINDS do
		order[i] = i
	end
	local random = Random.new(round * 7919 + 17)
	for i = #order, 2, -1 do
		local j = random:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local orderCache: { [number]: { number } } = {}
local function orderOf(round: number): { number }
	local cached = orderCache[round]
	if cached then
		return cached
	end
	local order = shuffled(round)
	-- Jamais deux fois la même d'affilée, d'un tour à l'autre (l'échange des
	-- deux premières ne touche pas la dernière du tour d'avant).
	local previous = shuffled(round - 1)
	if order[1] == previous[#previous] then
		order[1], order[2] = order[2], order[1]
	end
	orderCache[round] = order
	return order
end

local function eventOfSlot(slot: number): Event
	local count = #FlashEvents.KINDS
	local kind = FlashEvents.KINDS[orderOf(slot // count)[slot % count + 1]]
	local startsAt = slot * FlashEvents.PERIOD
	local carClass = if kind.Id == "RareCar"
		then FlashEvents.RARE_CARS[(slot // count) % #FlashEvents.RARE_CARS + 1]
		else nil
	return { Kind = kind, Slot = slot, StartsAt = startsAt, EndsAt = startsAt + FlashEvents.DURATION, CarClass = carClass }
end

-- L'événement en cours à `time`, ou nil (entre deux événements).
function FlashEvents.Active(time: number): Event?
	local slot = math.floor(time / FlashEvents.PERIOD)
	local event = eventOfSlot(slot)
	return if time < event.EndsAt then event else nil
end

-- Le prochain événement à commencer après `time`.
function FlashEvents.Next(time: number): Event
	return eventOfSlot(math.floor(time / FlashEvents.PERIOD) + 1)
end

local function activeKind(time: number): KindId?
	local event = FlashEvents.Active(time)
	return if event then event.Kind.Id else nil
end

-- Multiplicateur des chances des raretés Usine et plus (1 hors événement).
function FlashEvents.RollBoost(time: number): number
	return if activeKind(time) == "Rolls" then FlashEvents.ROLL_BOOST else 1
end

function FlashEvents.CreditMultiplier(time: number): number
	return if activeKind(time) == "Credits" then FlashEvents.CREDIT_MULTIPLIER else 1
end

function FlashEvents.XpMultiplier(time: number): number
	return if activeKind(time) == "Xp" then FlashEvents.XP_MULTIPLIER else 1
end

-- La voiture rare du moment (nil hors événement RareCar).
function FlashEvents.RareCar(time: number): string?
	local event = FlashEvents.Active(time)
	return if event and event.Kind.Id == "RareCar" then event.CarClass else nil
end

-- Prix en crédits d'une voiture à `time` (réduit pendant son événement).
function FlashEvents.CreditPrice(price: number, carClass: string?, time: number): number
	local rare = FlashEvents.RareCar(time)
	if rare and carClass == rare then
		return math.floor(price * (1 - FlashEvents.CAR_DISCOUNT) / 50 + 0.5) * 50
	end
	return price
end

return FlashEvents
