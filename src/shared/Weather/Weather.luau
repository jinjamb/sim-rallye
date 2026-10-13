--!strict
--[[
	Weather.luau
	La météo d'une spéciale ou d'une course de rallycross.

	TROIS MODES, au choix du pilote (spéciale) ou de l'hôte (course) :
		Dry      sec : route sèche du début à la fin ;
		Rain     pluie : il pleut tout le temps, la route est mouillée dès le
		         départ ;
		Dynamic  variable : des averses tombent par moments ; la route se
		         mouille pendant l'averse et sèche ensuite, peu à peu.

	PRÉVISION : { Mode, Seed, StartsAt }. Le serveur la tire au départ (graine
	au hasard, heure du serveur) ; chaque client en déduit EXACTEMENT la même
	chose : quand il pleut, et combien la route est mouillée. Tous les pilotes
	d'une course ont donc la même averse au même moment.

	DEUX GRANDEURS, de 0 à 1 :
		Rain     la pluie qui tombe (intensité de l'averse) ;
		Wetness  l'eau sur la route : elle monte sous la pluie (WET_TIME pour
		         mouiller une route sèche sous une forte averse) et redescend
		         une fois la pluie arrêtée (DRY_TIME pour sécher complètement).
	L'adhérence suit Wetness (Surfaces.luau : chaque surface perd plus ou
	moins sur le mouillé), l'affichage (pluie, ciel, route assombrie) suit les
	deux (WeatherClient.luau).

	Module pur, sans Roblox : son générateur pseudo-aléatoire est le sien
	(Park-Miller), identique sur le serveur et sur chaque client.
]]

local Weather = {}

export type Mode = "Dry" | "Rain" | "Dynamic"

export type Forecast = {
	Mode: Mode,
	Seed: number, -- entier, 1 à 2^31 - 2
	StartsAt: number, -- heure du serveur (workspace:GetServerTimeNow) du début
}

Weather.MODES = { "Dry", "Rain", "Dynamic" } :: { Mode }
Weather.MODE_NAMES = { Dry = "SEC", Rain = "PLUIE", Dynamic = "VARIABLE" } :: { [string]: string }
Weather.MODE_DESCRIPTIONS = {
	Dry = "Route sèche.",
	Rain = "Il pleut tout le temps : route mouillée, freinages plus longs.",
	Dynamic = "Des averses par moments : la route se mouille, puis sèche peu à peu.",
} :: { [string]: string }

-- Temps (s) pour mouiller une route sèche sous une forte averse.
Weather.WET_TIME = 25
-- Temps (s) pour qu'une route trempée sèche complètement, la pluie arrêtée.
Weather.DRY_TIME = 120

-- Averses du mode variable (secondes).
local FIRST_GAP = { 20, 90 } -- avant la première averse
local GAP = { 45, 130 } -- entre deux averses
local SHOWER = { 30, 75 } -- durée d'une averse
local PEAK = { 0.5, 1 } -- intensité au plus fort
local RAMP = 8 -- la pluie forcit et faiblit en quelques secondes
local HORIZON = 3 * 3600 -- averses prévues sur 3 h (au-delà : plus de pluie)
local STEP = 1 -- pas d'intégration de l'eau sur la route

type Shower = { From: number, To: number, Peak: number }

function Weather.Sanitize(mode: any): Mode
	if mode == "Rain" or mode == "Dynamic" then
		return mode
	end
	return "Dry"
end

-- Graine valide pour le générateur (entier de 1 à 2^31 - 2).
local MODULUS = 2147483647
local function cleanSeed(seed: number): number
	local value = math.floor(math.abs(seed)) % (MODULUS - 1)
	return value + 1
end

-- Une prévision qui commence à `startsAt`. `seed` : au hasard si absente.
function Weather.New(mode: any, startsAt: number, seed: number?): Forecast
	return {
		Mode = Weather.Sanitize(mode),
		Seed = cleanSeed(seed or math.random(1, MODULUS - 2)),
		StartsAt = startsAt,
	}
end

-- Prévision lue dans des attributs (voiture : Weather, WeatherSeed, WeatherStart), ou nil.
function Weather.FromAttributes(mode: any, seed: any, startsAt: any): Forecast?
	if type(mode) ~= "string" or type(seed) ~= "number" or type(startsAt) ~= "number" then
		return nil
	end
	return { Mode = Weather.Sanitize(mode), Seed = cleanSeed(seed), StartsAt = startsAt }
end

-- Ajoute la prévision aux attributs d'une voiture (CarService.Spawn) ; les rend.
function Weather.ToAttributes(forecast: Forecast, attributes: { [string]: any }?): { [string]: any }
	local result: { [string]: any } = attributes or {}
	result.Weather = forecast.Mode
	result.WeatherSeed = forecast.Seed
	result.WeatherStart = forecast.StartsAt
	return result
end

-- Générateur de Park-Miller : reproductible partout, à partir de la graine.
local function generator(seed: number): (number, number) -> number
	local state = cleanSeed(seed)
	return function(low: number, high: number): number
		state = (state * 16807) % MODULUS
		return low + (high - low) * (state - 1) / (MODULUS - 2)
	end
end

-- Averses du mode variable, en secondes depuis le début (gardées par graine).
local showerCache: { [number]: { Shower } } = {}
local function showersOf(seed: number): { Shower }
	local cached = showerCache[seed]
	if cached then
		return cached
	end
	local random = generator(seed)
	local list: { Shower } = {}
	local t = random(FIRST_GAP[1], FIRST_GAP[2])
	while t < HORIZON do
		local length = random(SHOWER[1], SHOWER[2])
		table.insert(list, { From = t, To = t + length, Peak = random(PEAK[1], PEAK[2]) })
		t += length + random(GAP[1], GAP[2])
	end
	showerCache[seed] = list
	return list
end

-- La pluie qui tombe (0 à 1), `elapsed` secondes après le début.
local function rainAfter(forecast: Forecast, elapsed: number): number
	if forecast.Mode == "Rain" then
		return 1
	elseif forecast.Mode == "Dry" or elapsed < 0 then
		return 0
	end
	for _, shower in ipairs(showersOf(forecast.Seed)) do
		if elapsed < shower.From then
			return 0
		elseif elapsed < shower.To then
			local fade = math.min(elapsed - shower.From, shower.To - elapsed, RAMP) / RAMP
			return shower.Peak * fade
		end
	end
	return 0
end

-- La pluie qui tombe (0 à 1) à l'heure du serveur `time`.
function Weather.RainAt(forecast: Forecast, time: number): number
	return rainAfter(forecast, time - forecast.StartsAt)
end

-- L'eau sur la route après `dt` secondes sous une pluie `rain`.
local function nextWetness(wetness: number, rain: number, dt: number): number
	if rain > 0 then
		-- Elle monte vers l'intensité de l'averse (une petite pluie ne trempe pas).
		local target = math.max(wetness, rain)
		return math.min(target, wetness + rain * dt / Weather.WET_TIME)
	end
	return math.max(0, wetness - dt / Weather.DRY_TIME)
end

--[[
	Suivi au fil du temps, pour le client (une fois par image) : l'eau sur la
	route est intégrée pas à pas depuis le début de la prévision, puis
	seulement le temps écoulé depuis l'appel précédent.
]]
export type Tracker = {
	Forecast: Forecast,
	Elapsed: number, -- secondes intégrées depuis le début
	Wetness: number,
	Update: (self: Tracker, time: number) -> (number, number),
}

local function update(self: Tracker, time: number): (number, number)
	local forecast = self.Forecast
	if forecast.Mode == "Rain" then
		return 1, 1
	elseif forecast.Mode == "Dry" then
		return 0, 0
	end
	local target = time - forecast.StartsAt
	-- Remonter le temps (horloge recalée) : on repart du début.
	if target < self.Elapsed then
		self.Elapsed, self.Wetness = 0, 0
	end
	while self.Elapsed + STEP <= target do
		self.Wetness = nextWetness(self.Wetness, rainAfter(forecast, self.Elapsed), STEP)
		self.Elapsed += STEP
	end
	local rain = rainAfter(forecast, target)
	local wetness = nextWetness(self.Wetness, rain, math.max(0, target - self.Elapsed))
	return rain, wetness
end

function Weather.Tracker(forecast: Forecast): Tracker
	return {
		Forecast = forecast,
		Elapsed = 0,
		Wetness = 0,
		Update = update,
	}
end

-- L'eau sur la route (0 à 1) à l'heure du serveur `time` (calcul complet).
function Weather.WetnessAt(forecast: Forecast, time: number): number
	local _, wetness = Weather.Tracker(forecast):Update(time)
	return wetness
end

return Weather
