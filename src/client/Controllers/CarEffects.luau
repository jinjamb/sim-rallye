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
	La fumée de glisse sur le dur reste gérée par Wheel.luau (émetteur Smoke).
	Effet local : créé côté client, seul le pilote le voit.
]]

local CarClass = require(script.Parent.Parent.Physics.Car)
local WheelClass = require(script.Parent.Parent.Physics.Wheel)

local CarEffects = {}
CarEffects.__index = CarEffects

type DustEmitter = {
	Wheel: WheelClass.Wheel,
	Attachment: Attachment,
	Emitter: ParticleEmitter,
	Color: Color3?,
}

export type CarEffects = typeof(setmetatable({}, CarEffects)) & {
	Car: CarClass.Car,
	Emitters: { DustEmitter },
	Active: boolean,
}

local ROLL_RATE = 28 -- particules/s par roue, en roulant à FULL_DUST_SPEED
local SLIDE_RATE = 45 -- particules/s supplémentaires, pneu en pleine glisse
local FULL_DUST_SPEED = 90 -- studs/s (~km/h)
-- Glissement normalisé (1 = pic) à partir duquel la poussière enfle.
local SLIDE_START, SLIDE_RANGE = 0.9, 1.5

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

function CarEffects.new(car: CarClass.Car): CarEffects
	local self = (setmetatable({}, CarEffects) :: any) :: CarEffects
	self.Car = car
	self.Active = false
	self.Emitters = {}
	for i, wheel in ipairs(car.Wheels) do
		local attachment, emitter = makeEmitter(car.Chassis, "Dust" .. string.sub(wheel.Attachment.Name, 6))
		self.Emitters[i] = { Wheel = wheel, Attachment = attachment, Emitter = emitter, Color = nil }
	end
	return self
end

function CarEffects:SetActive(active: boolean)
	self.Active = active
	if not active then
		for _, dust in ipairs(self.Emitters) do
			dust.Emitter.Enabled = false
		end
	end
end

function CarEffects:Update(_dt: number)
	if not self.Active then
		return
	end
	local speed = self.Car.Chassis.AssemblyLinearVelocity.Magnitude
	local rollFactor = math.clamp(speed / FULL_DUST_SPEED, 0, 1)

	for _, dust in ipairs(self.Emitters) do
		local wheel = dust.Wheel
		local surface = wheel.Surface
		local emitter = dust.Emitter

		if wheel.IsGrounded and surface.Sound == "Gravel" then
			dust.Attachment.WorldPosition = wheel.ContactPoint

			local combined = math.sqrt(wheel.LongSlipNorm ^ 2 + wheel.LatSlipNorm ^ 2)
			local slide = math.clamp((combined - SLIDE_START) / SLIDE_RANGE, 0, 1)
			local rate = ROLL_RATE * rollFactor + SLIDE_RATE * slide
			emitter.Rate = rate
			emitter.Enabled = rate > 0.5

			if dust.Color ~= surface.DustColor then
				dust.Color = surface.DustColor
				emitter.Color = ColorSequence.new(surface.DustColor)
			end
		else
			emitter.Enabled = false
		end
	end
end

return CarEffects
