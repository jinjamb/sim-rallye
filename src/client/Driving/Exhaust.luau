--!strict
--[[
	Exhaust.luau
	L'échappement : retours de flamme et crépitements d'anti-lag, vus et
	entendus par tous. Piloté par le même état que le son (CarAudio.luau) :
	régime et charge, ceux de sa voiture comme ceux des autres (télémétrie).

		RETOUR DE FLAMME : un lever de pied franc à haut régime (ou une
		montée de rapport, ou le rupteur : la charge tombe d'un coup)
		fait détoner l'essence dans l'échappement : une détonation, une
		gerbe de flammes, un éclair. Toutes les voitures.
		ANTI-LAG (CarClasses : AntiLag) : pied levé, tant que le moteur
		tourne vite, l'allumage retardé fait crépiter l'échappement en
		continu, avec de petites flammes, pendant ANTI_LAG_MAX secondes
		au plus. Plus l'anti-lag est fort, plus ça crépite.

	Flammes : particules de feu (texture de Roblox) projetées vers
	l'arrière depuis la sortie d'échappement, et une lumière brève. Sons :
	SoundBank.Backfire et SoundBank.AntiLagPops (rien tant qu'ils sont
	vides : les flammes restent).
	La sortie est sous le pare-chocs arrière : ExhaustZ, posé par
	CarBodies sur les modèles du jeu, sinon celle du gabarit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local SoundBank = require(script.Parent.Parent.Audio.SoundBank)

local Exhaust = {}
Exhaust.__index = Exhaust

export type Exhaust = typeof(setmetatable({}, Exhaust)) & {
	Chassis: BasePart,
	Model: Model?,
	Attachment: Attachment,
	Flames: ParticleEmitter,
	Light: PointLight,
	Bangs: { Sound },
	Pops: { Sound },
	LastLoad: number,
	LastBang: number,
	AntiLagTime: number, -- secondes pied levé, anti-lag actif
	LightLevel: number,
}

local EXHAUST_X = 1.6 -- côté droit, comme sur le gabarit
local EXHAUST_Y = -0.9
local DEFAULT_Z = 7.4 -- sortie du gabarit (build-rig.luau)
local BANG_RPM = 4800 -- régime minimal d'un retour de flamme
local BANG_FROM_LOAD = 0.7 -- la charge d'avant...
local BANG_TO_LOAD = 0.2 -- ...et celle d'après : un lever de pied franc
local BANG_COOLDOWN = 0.22
local ANTI_LAG_RPM = 3200
local ANTI_LAG_MAX = 2.5 -- secondes de crépitement après un lever de pied
local ANTI_LAG_RATE = 10 -- détonations par seconde, anti-lag complet à haut régime
local LIGHT_FADE = 0.08 -- secondes

local FLAME_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 210, 255)), -- cœur bleuté
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 20)),
})

local function makeSounds(ids: { string }, parent: Instance, volume: number): { Sound }
	local sounds = {}
	for _, soundId in ipairs(ids) do
		if soundId ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = soundId
			sound.Volume = volume
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 12
			sound.RollOffMaxDistance = 300
			sound.Parent = parent
			table.insert(sounds, sound)
		end
	end
	return sounds
end

function Exhaust.new(chassis: BasePart, model: Model?): Exhaust
	local self = (setmetatable({}, Exhaust) :: any) :: Exhaust
	self.Chassis = chassis
	self.Model = model
	self.LastLoad = 0
	self.LastBang = -math.huge
	self.AntiLagTime = 0
	self.LightLevel = 0

	local attachment = Instance.new("Attachment")
	attachment.Name = "ExhaustOutlet"
	attachment.Parent = chassis
	self.Attachment = attachment
	self:_place()

	local flames = Instance.new("ParticleEmitter")
	flames.Name = "ExhaustFlames"
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = FLAME_COLORS
	flames.LightEmission = 1
	flames.Brightness = 3
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.1) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.06, 0.14)
	flames.Speed = NumberRange.new(14, 24)
	flames.SpreadAngle = Vector2.new(10, 10)
	flames.EmissionDirection = Enum.NormalId.Back -- vers l'arrière de la voiture (+Z du châssis)
	flames.Rate = 0
	flames.LockedToPart = false
	flames.Parent = attachment
	self.Flames = flames

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 9
	light.Brightness = 0
	light.Shadows = false
	light.Parent = attachment
	self.Light = light

	self.Bangs = makeSounds(SoundBank.Backfire, attachment, 0.9)
	self.Pops = makeSounds(SoundBank.AntiLagPops, attachment, 0.5)
	return self
end

-- La sortie, selon la carrosserie (elle peut changer au garage).
function Exhaust:_place()
	local z = if self.Model then self.Model:GetAttribute("ExhaustZ") else nil
	self.Attachment.Position = Vector3.new(EXHAUST_X, EXHAUST_Y, if type(z) == "number" then z else DEFAULT_Z)
end

local function playOne(sounds: { Sound }, pitchSpread: number)
	if #sounds == 0 then
		return
	end
	local sound = sounds[math.random(1, #sounds)]
	sound.PlaybackSpeed = 1 + (math.random() - 0.5) * pitchSpread
	sound.TimePosition = 0
	sound:Play()
end

-- Une détonation : `big` pour un retour de flamme, sinon un crépitement.
function Exhaust:_fire(big: boolean)
	self:_place()
	self.Flames:Emit(if big then math.random(7, 11) else math.random(2, 4))
	self.LightLevel = math.max(self.LightLevel, if big then 5 else 2)
	if big then
		playOne(self.Bangs, 0.2)
	else
		playOne(self.Pops, 0.35)
	end
end

function Exhaust:Update(dt: number, rpm: number, load: number)
	local now = os.clock()
	local class = CarClasses.Get(if self.Model then self.Model:GetAttribute("CarClass") else nil)

	-- Retour de flamme : la charge s'effondre à haut régime.
	if self.LastLoad >= BANG_FROM_LOAD and load <= BANG_TO_LOAD and rpm >= BANG_RPM and now - self.LastBang >= BANG_COOLDOWN then
		self.LastBang = now
		self:_fire(true)
	end

	-- Anti-lag : pied levé, ça crépite tant que le moteur tourne vite.
	if class.AntiLag > 0 and load <= BANG_TO_LOAD and rpm >= ANTI_LAG_RPM then
		self.AntiLagTime += dt
		if self.AntiLagTime <= ANTI_LAG_MAX then
			local rate = ANTI_LAG_RATE * class.AntiLag * math.clamp((rpm - ANTI_LAG_RPM) / 3000, 0.25, 1)
			if math.random() < rate * dt then
				self:_fire(false)
			end
		end
	else
		self.AntiLagTime = 0
	end
	self.LastLoad = load

	self.LightLevel = math.max(0, self.LightLevel - dt / LIGHT_FADE * self.LightLevel)
	self.Light.Brightness = self.LightLevel
end

-- Voiture à l'arrêt ou plus pilotée : plus rien ne détone.
function Exhaust:Reset()
	self.LastLoad = 0
	self.AntiLagTime = 0
	self.LightLevel = 0
	self.Light.Brightness = 0
end

function Exhaust:Destroy()
	self.Attachment:Destroy()
end

return Exhaust
