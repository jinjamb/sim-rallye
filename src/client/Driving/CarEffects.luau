--!strict
--[[
	CarEffects.luau
	Poussière soulevée par les roues sur surface meuble.

	Une traînée de poussière qui s'allonge derrière la voiture est l'un des
	repères de vitesse les plus forts en rallye : elle montre, en arrière-plan,
	tout le chemin parcouru dans la dernière seconde. Elle enfle quand le pneu
	patine ou glisse.

	Un émetteur par roue, posé AU CONTACT avec le sol (pas sous la caisse) et
	déplacé à chaque frame. Les particules ne suivent pas la voiture
	(VelocityInheritance = 0) : elles restent là où elles ont été soulevées.
	Les roues ARRIÈRE en soulèvent bien plus que l'avant : ce sont elles qui
	projettent la terre (motricité, glisse du train arrière).

	NUAGE : en plus, derrière la voiture, un gros nuage de poussière qui monte
	lentement et reste en suspension plusieurs secondes -- la signature d'une
	voiture de rallye sur la terre. Il grossit avec la vitesse et enfle encore
	en glisse.
	La fumée de glisse sur le dur reste gérée par Wheel.luau (émetteur Smoke).
	Effet créé côté client, pour sa voiture (Main.client.luau) comme pour
	celles des autres joueurs (RemoteCars.luau, roues reconstituées).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Surfaces = require(ReplicatedStorage.Shared.Vehicle.Surfaces)

local CarEffects = {}
CarEffects.__index = CarEffects

--[[
	Ce dont la poussière a besoin d'une roue. Les roues physiques (Wheel.luau)
	le fournissent ; celles des voitures des autres joueurs aussi, reconstituées
	par RemoteCars.luau à partir de rayons locaux et de la télémétrie.
]]
export type WheelLike = {
	Attachment: Attachment,
	IsGrounded: boolean,
	Surface: Surfaces.SurfaceProperties,
	ContactPoint: Vector3,
	LongSlipNorm: number,
	LatSlipNorm: number,
}

type DustEmitter = {
	Wheel: WheelLike,
	Attachment: Attachment,
	Emitter: ParticleEmitter,
	Color: Color3?,
	IsRear: boolean,
}

export type CarEffects = typeof(setmetatable({}, CarEffects)) & {
	Chassis: BasePart,
	Emitters: { DustEmitter },
	Cloud: ParticleEmitter,
	CloudAttachment: Attachment,
	CloudColor: Color3?,
	Active: boolean,
}

-- Particules/s par roue, en roulant à FULL_DUST_SPEED, puis en pleine glisse.
local FRONT_ROLL_RATE, FRONT_SLIDE_RATE = 18, 35
local REAR_ROLL_RATE, REAR_SLIDE_RATE = 45, 90
local FULL_DUST_SPEED = 90 -- studs/s (~km/h)
-- Glissement normalisé (1 = pic) à partir duquel la poussière enfle.
local SLIDE_START, SLIDE_RANGE = 0.9, 1.5

-- Nuage derrière la voiture.
local CLOUD_ROLL_RATE = 22 -- grosses bouffées/s, à pleine vitesse, quatre roues sur la terre
local CLOUD_SLIDE_RATE = 30
local CLOUD_MIN_SPEED = 10 -- studs/s : à l'arrêt, pas de nuage
-- Le nuage démarre déjà à basse vitesse (une voiture à 40 km/h sur la terre
-- en soulève) : sa vitesse de référence est plus basse que celle des roues.
local CLOUD_FULL_SPEED = 60

local function makeCloud(chassis: BasePart): (Attachment, ParticleEmitter)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DustCloud"
	-- Derrière le châssis (l'arrière est en +Z local), près du sol.
	attachment.Position = Vector3.new(0, -chassis.Size.Y / 2, chassis.Size.Z / 2 + 1)
	attachment.Parent = chassis

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(2.5, 4.5)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(40, 25)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.VelocityInheritance = 0
	emitter.Drag = 1.2
	emitter.Acceleration = Vector3.new(0, 1.8, 0) -- monte doucement
	-- Peu sensible à la lumière : un nuage à l'ombre reste un nuage clair.
	emitter.LightInfluence = 0.4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4),
		NumberSequenceKeypoint.new(0.4, 12),
		NumberSequenceKeypoint.new(1, 20),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return attachment, emitter
end

local function makeEmitter(chassis: BasePart, name: string): (Attachment, ParticleEmitter)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = chassis

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 15)
	-- L'arrière du châssis est en +Z local : la poussière part vers l'arrière.
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.VelocityInheritance = 0
	emitter.Drag = 2
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 5.5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return attachment, emitter
end

function CarEffects.new(chassis: BasePart, wheels: { WheelLike }): CarEffects
	local self = (setmetatable({}, CarEffects) :: any) :: CarEffects
	self.Chassis = chassis
	self.Active = false
	self.Emitters = {}
	for i, wheel in ipairs(wheels) do
		local suffix = string.sub(wheel.Attachment.Name, 6) -- "WheelRL" -> "RL"
		local attachment, emitter = makeEmitter(chassis, "Dust" .. suffix)
		local isRear = string.sub(suffix, 1, 1) == "R"
		if isRear then
			-- Projetée plus haut et plus loin, en plus gros paquets.
			emitter.Speed = NumberRange.new(4, 9)
			emitter.Lifetime = NumberRange.new(1.2, 2.4)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.8),
				NumberSequenceKeypoint.new(1, 8),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.LightInfluence = 0.4
		end
		self.Emitters[i] = { Wheel = wheel, Attachment = attachment, Emitter = emitter, Color = nil, IsRear = isRear }
	end
	self.CloudAttachment, self.Cloud = makeCloud(chassis)
	self.CloudColor = nil
	return self
end

function CarEffects:Destroy()
	for _, dust in ipairs(self.Emitters) do
		dust.Attachment:Destroy()
	end
	self.CloudAttachment:Destroy()
end

function CarEffects:SetActive(active: boolean)
	self.Active = active
	if not active then
		for _, dust in ipairs(self.Emitters) do
			dust.Emitter.Enabled = false
		end
		self.Cloud.Enabled = false
	end
end

function CarEffects:Update(_dt: number)
	if not self.Active then
		return
	end
	local speed = self.Chassis.AssemblyLinearVelocity.Magnitude
	local rollFactor = math.clamp(speed / FULL_DUST_SPEED, 0, 1)

	local gravelWheels = 0
	local maxSlide = 0
	local cloudColor: Color3? = nil
	for _, dust in ipairs(self.Emitters) do
		local wheel = dust.Wheel
		local surface = wheel.Surface
		local emitter = dust.Emitter

		if wheel.IsGrounded and surface.Sound == "Gravel" then
			dust.Attachment.WorldPosition = wheel.ContactPoint

			local combined = math.sqrt(wheel.LongSlipNorm ^ 2 + wheel.LatSlipNorm ^ 2)
			local slide = math.clamp((combined - SLIDE_START) / SLIDE_RANGE, 0, 1)
			local rollRate = if dust.IsRear then REAR_ROLL_RATE else FRONT_ROLL_RATE
			local slideRate = if dust.IsRear then REAR_SLIDE_RATE else FRONT_SLIDE_RATE
			local rate = rollRate * rollFactor + slideRate * slide
			emitter.Rate = rate
			emitter.Enabled = rate > 0.5

			if dust.Color ~= surface.DustColor then
				dust.Color = surface.DustColor
				emitter.Color = ColorSequence.new(surface.DustColor)
			end
			gravelWheels += 1
			maxSlide = math.max(maxSlide, slide)
			if dust.IsRear or cloudColor == nil then
				cloudColor = surface.DustColor
			end
		else
			emitter.Enabled = false
		end
	end

	-- Nuage : proportionnel à la part des roues sur la terre et à la vitesse.
	local share = gravelWheels / math.max(1, #self.Emitters)
	local cloudFactor = math.clamp(speed / CLOUD_FULL_SPEED, 0, 1)
	local cloudRate = if speed < CLOUD_MIN_SPEED then 0 else share * (CLOUD_ROLL_RATE * cloudFactor + CLOUD_SLIDE_RATE * maxSlide)
	self.Cloud.Rate = cloudRate
	self.Cloud.Enabled = cloudRate > 0.3
	if cloudColor and cloudColor ~= self.CloudColor then
		self.CloudColor = cloudColor
		-- Un peu plus clair que la terre : la poussière en suspension pâlit.
		self.Cloud.Color = ColorSequence.new((cloudColor :: Color3):Lerp(Color3.fromRGB(215, 205, 185), 0.45))
	end
end

return CarEffects
