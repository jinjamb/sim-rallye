--!strict
--[[
	CarAudio.luau
	Son de la voiture, piloté par l'état physique (aucun son n'est déclenché
	"à la main" : tout découle du régime, de la charge et des glissements).

	MOTEUR : deux familles d'échantillons bouclés (voir SoundBank.luau).
		- Dans chaque famille, on joue les deux échantillons qui encadrent le
		  régime, en fondu à puissance constante (cos/sin : pas de creux de
		  volume au milieu du fondu), chacun transposé au régime exact.
		- Les deux familles sont mélangées selon la charge : à fond on entend le
		  moteur qui pousse, pied levé le moteur entraîné. Comme la charge tombe
		  à 0 pendant un passage et au rupteur (Powertrain.luau), le "trou" de la
		  montée de rapport et le crépitement du rupteur viennent tout seuls.

	PNEUS, sur surface dure : un crissement PAR ROUE, émis depuis la roue et
	piloté uniquement par l'état de CE pneu. Une roue qui bloque au freinage
	crie, à sa place dans l'espace ; les trois autres restent muettes tant
	qu'elles adhèrent. Par ordre d'intensité :
		blocage  (glissement longitudinal < 0 au-delà du pic) : le plus fort ;
		travers  (glissement latéral au-delà du pic)          : plus discret ;
		patinage (glissement longitudinal > 0 au-delà du pic) : idem.
	Sur surface meuble (Gravel) : un roulement de cailloux global, qui enfle
	quand ça glisse. Sur glace : rien.

	Tous les sons passent par un SoundGroup : SoundBank.MasterVolume règle le tout.
	Ils sont créés côté client : seul le pilote les entend (multijoueur : à
	reprendre, en jouant la même logique sur la voiture des autres).
]]

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local SoundBank = require(script.Parent.SoundBank)
local CarClass = require(script.Parent.Parent.Physics.Car)
local WheelClass = require(script.Parent.Parent.Physics.Wheel)

local CarAudio = {}
CarAudio.__index = CarAudio

type Voice = {
	Sample: SoundBank.EngineSample,
	Sound: Sound,
	LastAudible: number,
}

type TireVoice = {
	Wheel: WheelClass.Wheel,
	Sound: Sound,
	Level: number,
	PitchOffset: number,
}

export type CarAudio = typeof(setmetatable({}, CarAudio)) & {
	Car: CarClass.Car,
	Group: SoundGroup,
	OnLoad: { Voice },
	OffLoad: { Voice },
	Screeches: { TireVoice },
	Gravel: Sound,
	TarmacRoll: Sound,
	Wind: Sound,
	Load: number,
	GravelLevel: number,
	TarmacLevel: number,
	Active: boolean,
}

-- Le pilote est à ~20 studs (caméra de poursuite) : en dessous de cette
-- distance, aucune atténuation, il entend la voiture à plein volume.
local ROLLOFF_MIN = 40
local ROLLOFF_MAX = 600

local OFF_LOAD_GAIN = 0.75 -- pied levé, le moteur est un peu moins fort
local LOAD_SMOOTH_TIME = 0.04 -- assez court pour garder le crépitement du rupteur
local MIN_PITCH, MAX_PITCH = 0.5, 2.0
local AUDIBLE_THRESHOLD = 0.002
-- Un échantillon redevenu muet continue de tourner un moment : s'il est
-- rappelé (régime qui oscille autour d'une frontière), il ne redémarre pas
-- au début de sa boucle, ce qui s'entendrait.
local STOP_DELAY = 1.0

-- Crissement, par roue (quatre roues qui bloquent ensemble s'additionnent).
local SCREECH_VOLUME = 0.4
local LOCK_GAIN = 1.0
local SLIDE_GAIN = 0.55
local SPIN_GAIN = 0.45
-- Légers décalages de hauteur entre roues : quatre copies exactes du même son
-- en phase sonnent comme un seul son "métallique".
local SCREECH_PITCH_OFFSETS = { 0, 0.04, -0.03, 0.02 }

local GRAVEL_ROLL_VOLUME = 0.25
local GRAVEL_SLIDE_VOLUME = 0.35
local TARMAC_ROLL_VOLUME = 0.2
-- Vent : proportionnel au carré de la vitesse, plein à WIND_FULL_SPEED.
local WIND_VOLUME = 0.35
local WIND_FULL_SPEED = 160 -- studs/s (~km/h)
local TIRE_SMOOTH_TIME = 0.08
-- Glissement normalisé (1 = pic d'adhérence) à partir duquel un pneu fait du
-- bruit, et largeur de la montée jusqu'au plein volume.
local SLIDE_START = 0.9
local SLIDE_RANGE = 1.5

local function makeSound(name: string, soundId: string, parent: Instance, group: SoundGroup): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

local function makeVoices(samples: { SoundBank.EngineSample }, prefix: string, parent: Instance, group: SoundGroup): { Voice }
	local voices = {}
	for i, sample in ipairs(samples) do
		local sound = makeSound(string.format("%s_%d", prefix, sample.Rpm), sample.Id, parent, group)
		voices[i] = { Sample = sample, Sound = sound, LastAudible = -math.huge }
	end
	return voices
end

function CarAudio.new(car: CarClass.Car): CarAudio
	local self = (setmetatable({}, CarAudio) :: any) :: CarAudio
	self.Car = car
	self.Load = 0
	self.GravelLevel = 0
	self.Active = false

	local group = Instance.new("SoundGroup")
	group.Name = "Voiture"
	group.Volume = SoundBank.MasterVolume
	group.Parent = SoundService
	self.Group = group

	-- Moteur et roulement émettent depuis le châssis, chaque crissement depuis
	-- sa roue. Directement sous la part ou l'Attachment, pas dans un Folder :
	-- un Sound n'est positionnel que si son parent est une BasePart ou une Attachment.
	local profile = SoundBank.Engine
	self.OnLoad = makeVoices(profile.OnLoad, "EngineOn", car.Chassis, group)
	self.OffLoad = makeVoices(profile.OffLoad, "EngineOff", car.Chassis, group)
	self.Gravel = makeSound("GravelRoll", SoundBank.GravelRoll, car.Chassis, group)
	self.TarmacRoll = makeSound("TarmacRoll", SoundBank.TarmacRoll, car.Chassis, group)
	-- Le vent n'a pas de source : il siffle autour de la caméra, pas de la voiture.
	-- Parent SoundService = son non spatialisé.
	self.Wind = makeSound("Wind", SoundBank.Wind, SoundService, group)
	self.TarmacLevel = 0

	self.Screeches = {}
	for i, wheel in ipairs(car.Wheels) do
		self.Screeches[i] = {
			Wheel = wheel,
			Sound = makeSound("TireScreech", SoundBank.TireScreech, wheel.Attachment, group),
			Level = 0,
			PitchOffset = SCREECH_PITCH_OFFSETS[i] or 0,
		}
	end

	-- Préchargement en tâche de fond : sinon le premier coup d'accélérateur
	-- tombe dans le silence le temps que l'échantillon arrive.
	task.spawn(function()
		local toLoad: { Instance } = { self.Gravel, self.TarmacRoll, self.Wind, self.Screeches[1].Sound }
		for _, voice in ipairs(self.OnLoad) do
			table.insert(toLoad, voice.Sound)
		end
		for _, voice in ipairs(self.OffLoad) do
			table.insert(toLoad, voice.Sound)
		end
		ContentProvider:PreloadAsync(toLoad)
	end)

	return self
end

local function stopAll(self: CarAudio)
	for _, layer in ipairs({ self.OnLoad, self.OffLoad }) do
		for _, voice in ipairs(layer) do
			voice.Sound:Stop()
			voice.Sound.Volume = 0
			voice.LastAudible = -math.huge
		end
	end
	for _, tire in ipairs(self.Screeches) do
		tire.Sound:Stop()
		tire.Level = 0
	end
	self.Gravel:Stop()
	self.TarmacRoll:Stop()
	self.Wind:Stop()
	self.Load = 0
	self.GravelLevel = 0
	self.TarmacLevel = 0
end

-- Coupé quand on descend de la voiture : la physique ne tourne plus, le
-- régime affiché serait figé.
function CarAudio:SetActive(active: boolean)
	if self.Active == active then
		return
	end
	self.Active = active
	if not active then
		stopAll(self)
	end
end

local function approach(current: number, target: number, dt: number, time: number): number
	local alpha = 1 - math.exp(-dt / time)
	return current + (target - current) * alpha
end

local function setLooping(sound: Sound, volume: number)
	sound.Volume = volume
	if volume > AUDIBLE_THRESHOLD then
		if not sound.IsPlaying then
			sound:Play()
		end
	elseif sound.IsPlaying then
		sound:Stop()
	end
end

-- Mixe une famille d'échantillons : les deux voisins du régime, en fondu.
local function updateLayer(voices: { Voice }, rpm: number, gain: number, now: number)
	local count = #voices
	local lowIndex, highIndex = 1, 1
	local t = 0
	if rpm >= voices[count].Sample.Rpm then
		lowIndex, highIndex = count, count
	elseif rpm > voices[1].Sample.Rpm then
		for i = 1, count - 1 do
			local lowRpm, highRpm = voices[i].Sample.Rpm, voices[i + 1].Sample.Rpm
			if rpm <= highRpm then
				lowIndex, highIndex = i, i + 1
				t = (rpm - lowRpm) / (highRpm - lowRpm)
				break
			end
		end
	end

	for i, voice in ipairs(voices) do
		local weight = 0
		if i == lowIndex then
			weight += math.cos(t * math.pi / 2)
		end
		if i == highIndex and highIndex ~= lowIndex then
			weight += math.sin(t * math.pi / 2)
		end

		local volume = weight * gain
		local sound = voice.Sound
		sound.PlaybackSpeed = math.clamp(rpm / voice.Sample.Rpm, MIN_PITCH, MAX_PITCH)
		sound.Volume = volume

		if volume > AUDIBLE_THRESHOLD then
			voice.LastAudible = now
			if not sound.IsPlaying then
				sound:Play()
			end
		elseif sound.IsPlaying and now - voice.LastAudible > STOP_DELAY then
			sound:Stop()
		end
	end
end

local function beyondPeak(normalizedSlip: number): number
	return math.clamp((normalizedSlip - SLIDE_START) / SLIDE_RANGE, 0, 1)
end

-- Intensité du crissement d'UN pneu sur surface dure (0..1).
local function screechLevel(wheel: WheelClass.Wheel): number
	if not wheel.IsGrounded or wheel.Surface.Sound ~= "Tarmac" then
		return 0
	end
	local lock = beyondPeak(-wheel.LongSlipNorm)
	local spin = beyondPeak(wheel.LongSlipNorm)
	local slide = beyondPeak(math.abs(wheel.LatSlipNorm))
	return math.max(lock * LOCK_GAIN, slide * SLIDE_GAIN, spin * SPIN_GAIN)
end

function CarAudio:Update(dt: number)
	if not self.Active then
		return
	end
	local car = self.Car
	local powertrain = car.Powertrain
	local now = os.clock()

	-- Moteur
	self.Load = approach(self.Load, powertrain.Load, dt, LOAD_SMOOTH_TIME)
	local rpm = powertrain.EngineRPM
	local master = SoundBank.Engine.Volume
	updateLayer(self.OnLoad, rpm, master * math.sqrt(self.Load), now)
	updateLayer(self.OffLoad, rpm, master * OFF_LOAD_GAIN * math.sqrt(1 - self.Load), now)

	-- Crissement, roue par roue
	for _, tire in ipairs(self.Screeches) do
		tire.Level = approach(tire.Level, screechLevel(tire.Wheel), dt, TIRE_SMOOTH_TIME)
		tire.Sound.PlaybackSpeed = 0.85 + 0.3 * tire.Level + tire.PitchOffset
		setLooping(tire.Sound, SCREECH_VOLUME * tire.Level)
	end

	-- Roulement, sur surface meuble et sur le dur
	local gravelSlide = 0
	local gravelWheels = 0
	local tarmacWheels = 0
	for _, wheel in ipairs(car.Wheels) do
		if wheel.IsGrounded and wheel.Surface.Sound == "Gravel" then
			gravelWheels += 1
			local combined = math.sqrt(wheel.LongSlipNorm ^ 2 + wheel.LatSlipNorm ^ 2)
			gravelSlide = math.max(gravelSlide, beyondPeak(combined))
		elseif wheel.IsGrounded and wheel.Surface.Sound == "Tarmac" then
			tarmacWheels += 1
		end
	end

	local speed = car.Chassis.AssemblyLinearVelocity.Magnitude
	local roll = (gravelWheels / #car.Wheels) * math.clamp(speed / 40, 0, 1)
	local gravelTarget = GRAVEL_ROLL_VOLUME * roll + (if gravelWheels > 0 then GRAVEL_SLIDE_VOLUME * gravelSlide else 0)

	self.GravelLevel = approach(self.GravelLevel, gravelTarget, dt, TIRE_SMOOTH_TIME)
	self.Gravel.PlaybackSpeed = 0.8 + 0.4 * math.clamp(speed / 120, 0, 1)
	setLooping(self.Gravel, self.GravelLevel)

	local tarmacTarget = TARMAC_ROLL_VOLUME * (tarmacWheels / #car.Wheels) * math.clamp(speed / 60, 0, 1)
	self.TarmacLevel = approach(self.TarmacLevel, tarmacTarget, dt, TIRE_SMOOTH_TIME)
	self.TarmacRoll.PlaybackSpeed = 0.7 + 0.6 * math.clamp(speed / 150, 0, 1)
	setLooping(self.TarmacRoll, self.TarmacLevel)

	-- Vent : carré de la vitesse, comme la traînée ; il monte aussi en aigu.
	local windFactor = math.clamp(speed / WIND_FULL_SPEED, 0, 1)
	self.Wind.PlaybackSpeed = 0.8 + 0.4 * windFactor
	setLooping(self.Wind, WIND_VOLUME * windFactor * windFactor)
end

return CarAudio
