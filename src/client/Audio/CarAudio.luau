--!strict
--[[
	CarAudio.luau
	Son d'une voiture, piloté par un ÉTAT (AudioState) : régime, charge, vitesse,
	crissement de chaque roue, part des roues sur le meuble ou le dur. Aucun son
	n'est déclenché "à la main".

	Le même mixage sert à toutes les voitures :
		- la sienne : état calculé à partir de la physique (StateFromCar) ;
		- celles des autres joueurs : état reconstitué à partir de la télémétrie
		  qu'ils diffusent (RemoteCars.luau).

	MOTEUR : deux familles d'échantillons bouclés (voir SoundBank.luau).
		- Dans chaque famille, on joue les deux échantillons qui encadrent le
		  régime, en fondu à puissance constante (cos/sin : pas de creux de
		  volume au milieu du fondu), chacun transposé au régime exact.
		- Les deux familles sont mélangées selon la charge : à fond on entend le
		  moteur qui pousse, pied levé le moteur entraîné. Comme la charge tombe
		  à 0 pendant un passage et au rupteur (Powertrain.luau), le "trou" de la
		  montée de rapport et le crépitement du rupteur viennent tout seuls.

	PNEUS, sur surface dure : un crissement PAR ROUE, émis depuis la roue, piloté
	par l'état de CE pneu. Par ordre d'intensité :
		blocage  (glissement longitudinal < 0 au-delà du pic) : le plus fort ;
		travers  (glissement latéral au-delà du pic)          : plus discret ;
		patinage (glissement longitudinal > 0 au-delà du pic) : idem.
	Sur surface meuble : un roulement de cailloux qui enfle quand ça glisse.
	Sur le dur : un roulement de pneus. Sur glace : rien.
	VENT : seulement pour sa propre voiture (il siffle autour de la caméra).

	Tous les sons passent par un SoundGroup commun : SoundBank.MasterVolume règle tout.
]]

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local SoundBank = require(script.Parent.SoundBank)
local CarClass = require(script.Parent.Parent.Physics.Car)
local WheelClass = require(script.Parent.Parent.Physics.Wheel)

local CarAudio = {}
CarAudio.__index = CarAudio

export type AudioState = {
	Rpm: number,
	Load: number, -- 0..1
	Speed: number, -- studs/s
	Screech: { number }, -- par roue (FL, FR, RL, RR), 0..1
	GravelShare: number, -- part des roues au sol sur surface meuble, 0..1
	GravelSlide: number, -- glissement sur le meuble, 0..1
	TarmacShare: number, -- part des roues au sol sur surface dure, 0..1
}

type Voice = {
	Sample: SoundBank.EngineSample,
	Sound: Sound,
	LastAudible: number,
}

type TireVoice = {
	Sound: Sound,
	Level: number,
	PitchOffset: number,
}

export type CarAudio = typeof(setmetatable({}, CarAudio)) & {
	IsLocal: boolean,
	OnLoad: { Voice },
	OffLoad: { Voice },
	Screeches: { TireVoice },
	Gravel: Sound,
	TarmacRoll: Sound,
	Wind: Sound?,
	Load: number,
	GravelLevel: number,
	TarmacLevel: number,
	Active: boolean,
}

-- Le pilote est à ~20 studs (caméra de poursuite) : en dessous de cette
-- distance, aucune atténuation, il entend sa voiture à plein volume.
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

-- Un seul groupe pour toutes les voitures : un seul volume général.
local sharedGroup: SoundGroup? = nil
local function getGroup(): SoundGroup
	local group = sharedGroup
	if group then
		return group
	end
	local created = Instance.new("SoundGroup")
	created.Name = "Voitures"
	created.Volume = SoundBank.MasterVolume
	created.Parent = SoundService
	sharedGroup = created
	return created
end

local function makeSound(name: string, soundId: string, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	sound.SoundGroup = getGroup()
	sound.Parent = parent
	return sound
end

local function makeVoices(samples: { SoundBank.EngineSample }, prefix: string, parent: Instance): { Voice }
	local voices = {}
	for i, sample in ipairs(samples) do
		local sound = makeSound(string.format("%s_%d", prefix, sample.Rpm), sample.Id, parent)
		voices[i] = { Sample = sample, Sound = sound, LastAudible = -math.huge }
	end
	return voices
end

--[[
	chassis : les sons moteur et de roulement émettent depuis lui ;
	wheelAttachments : un crissement par roue, émis depuis chacune (FL, FR, RL, RR) ;
	isLocal : sa propre voiture (vent, préchargement).
	Les sons sont directement sous une BasePart ou une Attachment, jamais dans un
	Folder : un Sound n'est positionnel qu'à cette condition.
]]
function CarAudio.new(chassis: BasePart, wheelAttachments: { Attachment }, isLocal: boolean): CarAudio
	local self = (setmetatable({}, CarAudio) :: any) :: CarAudio
	self.IsLocal = isLocal
	self.Load = 0
	self.GravelLevel = 0
	self.TarmacLevel = 0
	self.Active = false

	local profile = SoundBank.Engine
	self.OnLoad = makeVoices(profile.OnLoad, "EngineOn", chassis)
	self.OffLoad = makeVoices(profile.OffLoad, "EngineOff", chassis)
	self.Gravel = makeSound("GravelRoll", SoundBank.GravelRoll, chassis)
	self.TarmacRoll = makeSound("TarmacRoll", SoundBank.TarmacRoll, chassis)
	-- Le vent n'a pas de source : parent SoundService = son non spatialisé.
	self.Wind = if isLocal then makeSound("Wind", SoundBank.Wind, SoundService) else nil

	self.Screeches = {}
	for i, attachment in ipairs(wheelAttachments) do
		self.Screeches[i] = {
			Sound = makeSound("TireScreech", SoundBank.TireScreech, attachment),
			Level = 0,
			PitchOffset = SCREECH_PITCH_OFFSETS[i] or 0,
		}
	end

	-- Préchargement en tâche de fond : sinon le premier coup d'accélérateur
	-- tombe dans le silence le temps que l'échantillon arrive.
	if isLocal then
		task.spawn(function()
			local toLoad: { Instance } = { self.Gravel, self.TarmacRoll }
			if self.Wind then
				table.insert(toLoad, self.Wind)
			end
			if self.Screeches[1] then
				table.insert(toLoad, self.Screeches[1].Sound)
			end
			for _, voice in ipairs(self.OnLoad) do
				table.insert(toLoad, voice.Sound)
			end
			for _, voice in ipairs(self.OffLoad) do
				table.insert(toLoad, voice.Sound)
			end
			ContentProvider:PreloadAsync(toLoad)
		end)
	end

	return self
end

local function allSounds(self: CarAudio): { Sound }
	local sounds: { Sound } = { self.Gravel, self.TarmacRoll }
	if self.Wind then
		table.insert(sounds, self.Wind)
	end
	for _, layer in ipairs({ self.OnLoad, self.OffLoad }) do
		for _, voice in ipairs(layer) do
			table.insert(sounds, voice.Sound)
		end
	end
	for _, tire in ipairs(self.Screeches) do
		table.insert(sounds, tire.Sound)
	end
	return sounds
end

local function stopAll(self: CarAudio)
	for _, sound in ipairs(allSounds(self)) do
		sound:Stop()
		sound.Volume = 0
	end
	for _, layer in ipairs({ self.OnLoad, self.OffLoad }) do
		for _, voice in ipairs(layer) do
			voice.LastAudible = -math.huge
		end
	end
	for _, tire in ipairs(self.Screeches) do
		tire.Level = 0
	end
	self.Load = 0
	self.GravelLevel = 0
	self.TarmacLevel = 0
end

-- Coupé quand la voiture n'est pas pilotée : rien ne la fait tourner.
function CarAudio:SetActive(active: boolean)
	if self.Active == active then
		return
	end
	self.Active = active
	if not active then
		stopAll(self)
	end
end

function CarAudio:Destroy()
	for _, sound in ipairs(allSounds(self)) do
		sound:Destroy()
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

-- État sonore de sa propre voiture, tiré de la physique. Sert aussi de
-- télémétrie envoyée aux autres joueurs (Main.client.luau).
function CarAudio.StateFromCar(car: CarClass.Car): AudioState
	local screech = {}
	local gravelSlide, gravelWheels, tarmacWheels = 0, 0, 0
	for i, wheel in ipairs(car.Wheels) do
		screech[i] = screechLevel(wheel)
		if wheel.IsGrounded and wheel.Surface.Sound == "Gravel" then
			gravelWheels += 1
			local combined = math.sqrt(wheel.LongSlipNorm ^ 2 + wheel.LatSlipNorm ^ 2)
			gravelSlide = math.max(gravelSlide, beyondPeak(combined))
		elseif wheel.IsGrounded and wheel.Surface.Sound == "Tarmac" then
			tarmacWheels += 1
		end
	end
	local wheelCount = math.max(1, #car.Wheels)
	return {
		Rpm = car.Powertrain.EngineRPM,
		Load = car.Powertrain.Load,
		Speed = car.Chassis.AssemblyLinearVelocity.Magnitude,
		Screech = screech,
		GravelShare = gravelWheels / wheelCount,
		GravelSlide = gravelSlide,
		TarmacShare = tarmacWheels / wheelCount,
	}
end

function CarAudio:Update(dt: number, state: AudioState)
	if not self.Active then
		return
	end
	local now = os.clock()

	-- Moteur
	self.Load = approach(self.Load, state.Load, dt, LOAD_SMOOTH_TIME)
	local master = SoundBank.Engine.Volume
	updateLayer(self.OnLoad, state.Rpm, master * math.sqrt(self.Load), now)
	updateLayer(self.OffLoad, state.Rpm, master * OFF_LOAD_GAIN * math.sqrt(1 - self.Load), now)

	-- Crissement, roue par roue
	for i, tire in ipairs(self.Screeches) do
		tire.Level = approach(tire.Level, state.Screech[i] or 0, dt, TIRE_SMOOTH_TIME)
		tire.Sound.PlaybackSpeed = 0.85 + 0.3 * tire.Level + tire.PitchOffset
		setLooping(tire.Sound, SCREECH_VOLUME * tire.Level)
	end

	-- Roulement, sur le meuble et sur le dur
	local speed = state.Speed
	local roll = state.GravelShare * math.clamp(speed / 40, 0, 1)
	local gravelTarget = GRAVEL_ROLL_VOLUME * roll
		+ (if state.GravelShare > 0 then GRAVEL_SLIDE_VOLUME * state.GravelSlide else 0)
	self.GravelLevel = approach(self.GravelLevel, gravelTarget, dt, TIRE_SMOOTH_TIME)
	self.Gravel.PlaybackSpeed = 0.8 + 0.4 * math.clamp(speed / 120, 0, 1)
	setLooping(self.Gravel, self.GravelLevel)

	local tarmacTarget = TARMAC_ROLL_VOLUME * state.TarmacShare * math.clamp(speed / 60, 0, 1)
	self.TarmacLevel = approach(self.TarmacLevel, tarmacTarget, dt, TIRE_SMOOTH_TIME)
	self.TarmacRoll.PlaybackSpeed = 0.7 + 0.6 * math.clamp(speed / 150, 0, 1)
	setLooping(self.TarmacRoll, self.TarmacLevel)

	-- Vent : carré de la vitesse, comme la traînée ; il monte aussi en aigu.
	local wind = self.Wind
	if wind then
		local windFactor = math.clamp(speed / WIND_FULL_SPEED, 0, 1)
		wind.PlaybackSpeed = 0.8 + 0.4 * windFactor
		setLooping(wind, WIND_VOLUME * windFactor * windFactor)
	end
end

return CarAudio
