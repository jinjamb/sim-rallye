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

	RETOUR DE FLAMME PORTÉ (Items/Backfires.luau, attribut EquippedBackfire
	de la voiture) : couleur des flammes et de leur cœur, taille de la
	gerbe, détonation propre. Sans choix : les flammes classiques.

	UNE EXPLOSION : une gerbe de flammes projetée vers l'arrière, une
	boule de feu, des étincelles, une bouffée de fumée et un éclair qui
	éclaire la route. Un crépitement d'anti-lag n'en est qu'une petite.
	Sons : la détonation de l'objet porté, sinon SoundBank.Backfire ;
	SoundBank.AntiLagPops pour les crépitements (rien tant qu'ils sont
	vides : les flammes restent).
	La sortie est sous le pare-chocs arrière : ExhaustZ, posé par
	CarBodies sur les modèles du jeu, sinon celle du gabarit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local SoundBank = require(script.Parent.Parent.Audio.SoundBank)

local Exhaust = {}
Exhaust.__index = Exhaust

export type Exhaust = typeof(setmetatable({}, Exhaust)) & {
	Chassis: BasePart,
	Model: Model?,
	Attachment: Attachment,
	Flames: ParticleEmitter, -- la gerbe, projetée vers l'arrière
	Fireball: ParticleEmitter, -- la boule de feu, sur place
	Sparks: ParticleEmitter,
	Smoke: ParticleEmitter,
	Light: PointLight,
	Bangs: { Sound },
	OwnBang: Sound, -- la détonation de l'objet porté (sans identifiant : celles de SoundBank)
	Pops: { Sound },
	Style: string, -- identifiant de l'objet porté, appliqué aux émetteurs
	Scale: number,
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
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

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

local function emitter(name: string, texture: string, parent: Instance): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Texture = texture
	particles.Rate = 0
	particles.LockedToPart = false
	particles.EmissionDirection = Enum.NormalId.Back -- vers l'arrière de la voiture (+Z du châssis)
	particles.Parent = parent
	return particles
end

function Exhaust.new(chassis: BasePart, model: Model?): Exhaust
	local self = (setmetatable({}, Exhaust) :: any) :: Exhaust
	self.Chassis = chassis
	self.Model = model
	self.LastLoad = 0
	self.LastBang = -math.huge
	self.AntiLagTime = 0
	self.LightLevel = 0
	self.Style = ""
	self.Scale = 1

	local attachment = Instance.new("Attachment")
	attachment.Name = "ExhaustOutlet"
	attachment.Parent = chassis
	self.Attachment = attachment
	self:_place()

	local flames = emitter("ExhaustFlames", FIRE_TEXTURE, attachment)
	flames.LightEmission = 1
	flames.Brightness = 3
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.06, 0.16)
	flames.Speed = NumberRange.new(14, 26)
	flames.SpreadAngle = Vector2.new(10, 10)
	self.Flames = flames

	local fireball = emitter("ExhaustFireball", FIRE_TEXTURE, attachment)
	fireball.LightEmission = 1
	fireball.Brightness = 4
	fireball.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	fireball.Lifetime = NumberRange.new(0.08, 0.14)
	fireball.Speed = NumberRange.new(3, 6)
	fireball.SpreadAngle = Vector2.new(60, 60)
	fireball.Rotation = NumberRange.new(0, 360)
	self.Fireball = fireball

	local sparks = emitter("ExhaustSparks", SPARK_TEXTURE, attachment)
	sparks.LightEmission = 1
	sparks.Brightness = 3
	sparks.Size = NumberSequence.new(0.12, 0.02)
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	self.Sparks = sparks

	local smoke = emitter("ExhaustSmoke", SMOKE_TEXTURE, attachment)
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 68, 66))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(30, 30)
	smoke.Drag = 3
	smoke.Rotation = NumberRange.new(0, 360)
	self.Smoke = smoke

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = attachment
	self.Light = light

	self.Bangs = makeSounds(SoundBank.Backfire, attachment, 0.9)
	local own = Instance.new("Sound")
	own.Name = "OwnBackfire"
	own.Volume = 0.9
	own.RollOffMode = Enum.RollOffMode.InverseTapered
	own.RollOffMinDistance = 12
	own.RollOffMaxDistance = 300
	own.Parent = attachment
	self.OwnBang = own
	self.Pops = makeSounds(SoundBank.AntiLagPops, attachment, 0.5)
	self:_applyStyle()
	return self
end

-- Le retour de flamme porté (attribut EquippedBackfire) : couleurs, taille, détonation.
function Exhaust:_applyStyle()
	local id = if self.Model then self.Model:GetAttribute("EquippedBackfire") else nil
	local key = if type(id) == "string" then id else ""
	if key == self.Style then
		return
	end
	self.Style = key
	local item = Catalog.Get(key)
	if not item or item.Kind ~= "Backfire" then
		item = Catalog.Default("Backfire")
	end
	local outer = if item and item.Color then item.Color else Color3.fromRGB(255, 110, 25)
	local core = if item and item.Color2 then item.Color2 else Color3.fromRGB(255, 215, 110)
	local scale = if item and item.Scale then item.Scale else 1
	self.Scale = scale
	local colors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, core),
		ColorSequenceKeypoint.new(0.3, core:Lerp(outer, 0.5)),
		ColorSequenceKeypoint.new(1, outer),
	})
	self.Flames.Color = colors
	self.Flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * scale), NumberSequenceKeypoint.new(1, 0.12 * scale) })
	self.Flames.Speed = NumberRange.new(14 * scale, 26 * scale)
	self.Fireball.Color = colors
	self.Fireball.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(0.4, 1.6 * scale), NumberSequenceKeypoint.new(1, 0.4 * scale) })
	self.Sparks.Color = ColorSequence.new(core, outer)
	self.Light.Color = outer:Lerp(core, 0.3)
	self.Light.Range = 10 * scale
	self.OwnBang.SoundId = if item and item.Sound and item.Sound ~= "" then item.Sound else ""
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

-- Une détonation : `big` pour un retour de flamme (une explosion), sinon un crépitement.
function Exhaust:_fire(big: boolean)
	self:_place()
	self:_applyStyle()
	if big then
		self.Flames:Emit(math.random(8, 12))
		self.Fireball:Emit(math.random(3, 5))
		self.Sparks:Emit(math.random(6, 12))
		self.Smoke:Emit(math.random(2, 3))
		self.LightLevel = math.max(self.LightLevel, 6 * self.Scale)
		if self.OwnBang.SoundId ~= "" then
			self.OwnBang.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.15
			self.OwnBang.TimePosition = 0
			self.OwnBang:Play()
		else
			playOne(self.Bangs, 0.2)
		end
	else
		self.Flames:Emit(math.random(2, 4))
		self.Sparks:Emit(math.random(0, 2))
		self.LightLevel = math.max(self.LightLevel, 2 * self.Scale)
		playOne(self.Pops, 0.35)
	end
end

function Exhaust:Update(dt: number, rpm: number, load: number)
	local now = os.clock()
	local model = self.Model
	local class = CarClasses.ForCar(if model then model:GetAttribute("CarClass") else nil, if model then model:GetAttribute("CarModel") else nil)

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
