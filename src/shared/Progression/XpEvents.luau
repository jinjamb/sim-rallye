--!strict
--[[
	XpEvents.luau
	Les événements « double XP » : pendant un événement, toute l'XP gagnée est
	multipliée (le Rallye Pass et le classement des écuries en profitent
	aussi, puisqu'ils comptent l'XP gagnée).

	Le serveur applique le multiplicateur (ProgressService : un bonus d'XP
	gardé dans le profil, BonusXp) ; le client affiche l'événement en cours
	et le prochain. Tous deux lisent ce calendrier, sur l'heure du serveur.

	DEUX SORTES :
		- WEEKLY : chaque semaine, du jour/heure de début à ceux de fin
		  (jours : 0 = lundi ... 6 = dimanche ; 7 = le lundi suivant) ;
		- SPECIAL : à des dates précises (lancement d'une saison, fêtes...).
	Si plusieurs se chevauchent, le plus fort l'emporte (pas de cumul).

	HEURES EN UTC : Paris a 1 h (hiver) ou 2 h (été) d'avance.
]]

local XpEvents = {}

local DAY = 86400
local WEEK = 7 * DAY

export type Event = {
	Name: string,
	Multiplier: number,
	StartsAt: number, -- os.time
	EndsAt: number,
}

type Weekly = { Name: string, Multiplier: number, FromDay: number, FromHour: number, ToDay: number, ToHour: number }
type Special = { Name: string, Multiplier: number, From: { number }, To: { number } } -- { année, mois, jour, heure } UTC

-- Le week-end, du samedi 0 h au lundi 0 h (UTC).
XpEvents.WEEKLY = {
	{ Name = "Week-end double XP", Multiplier = 2, FromDay = 5, FromHour = 0, ToDay = 7, ToHour = 0 },
} :: { Weekly }

-- Dates précises. Exemple :
-- { Name = "Nuit d'Halloween", Multiplier = 3, From = { 2026, 10, 31, 18 }, To = { 2026, 11, 1, 6 } },
XpEvents.SPECIAL = {} :: { Special }

-- Jours depuis le 1er janvier 1970 d'une date du calendrier (algorithme de
-- H. Hinnant) : indépendant du fuseau de la machine, contrairement à os.time.
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

local function utc(date: { number }): number
	return daysFromCivil(date[1], date[2], date[3]) * DAY + (date[4] or 0) * 3600
end

-- Début (lundi 0 h UTC) de la semaine de `time`. Le 1er janvier 1970 était un jeudi.
local function weekStart(time: number): number
	local days = time // DAY
	return (days - (days + 3) % 7) * DAY
end

-- Les événements qui touchent [from, to[ (chaque semaine, et les dates précises).
local function eventsAround(from: number, to: number): { Event }
	local list: { Event } = {}
	local start = weekStart(from) - WEEK -- un événement commencé la semaine d'avant
	while start < to do
		for _, weekly in ipairs(XpEvents.WEEKLY) do
			local startsAt = start + weekly.FromDay * DAY + weekly.FromHour * 3600
			local endsAt = start + weekly.ToDay * DAY + weekly.ToHour * 3600
			if endsAt > from and startsAt < to then
				table.insert(list, { Name = weekly.Name, Multiplier = weekly.Multiplier, StartsAt = startsAt, EndsAt = endsAt })
			end
		end
		start += WEEK
	end
	for _, special in ipairs(XpEvents.SPECIAL) do
		local startsAt, endsAt = utc(special.From), utc(special.To)
		if endsAt > from and startsAt < to then
			table.insert(list, { Name = special.Name, Multiplier = special.Multiplier, StartsAt = startsAt, EndsAt = endsAt })
		end
	end
	return list
end

-- L'événement en cours à `time` (le plus fort), ou nil.
function XpEvents.Active(time: number): Event?
	local best: Event? = nil
	for _, event in ipairs(eventsAround(time, time + 1)) do
		if event.StartsAt <= time and time < event.EndsAt and (not best or event.Multiplier > best.Multiplier) then
			best = event
		end
	end
	return best
end

-- Multiplicateur d'XP à `time` (1 hors événement).
function XpEvents.Multiplier(time: number): number
	local event = XpEvents.Active(time)
	return if event then event.Multiplier else 1
end

-- Le prochain événement à commencer après `time` (dans les deux semaines), ou nil.
function XpEvents.Next(time: number): Event?
	local first: Event? = nil
	for _, event in ipairs(eventsAround(time, time + 2 * WEEK)) do
		if event.StartsAt > time and (not first or event.StartsAt < first.StartsAt) then
			first = event
		end
	end
	return first
end

return XpEvents
