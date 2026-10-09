--!strict
--[[
	TireSmoke.luau
	Fumée des pneus qui glissent ou bloquent sur le dur, à la couleur de la
	fumée portée par le pilote (Items/Smokes.luau, attribut EquippedSmoke de
	la voiture, posé par le serveur).

	VUE PAR TOUS : chaque client fabrique la fumée de chaque voiture. La
	sienne suit le crissement de chaque pneu (CarAudio : glissement au-delà
	du pic d'adhérence, sur le dur seulement) ; celle des autres suit le
	niveau de crissement de leur télémétrie (RemoteCars). Sur la terre,
	c'est la poussière (CarEffects) qui prend le relais.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)

local TireSmoke = {}
TireSmoke.__index = TireSmoke

export type TireSmoke = typeof(setmetatable({}, TireSmoke)) & {
	Model: Model,
	Attachments: { Attachment },
	Emitters: { ParticleEmitter },
	ItemId: string?,
	Active: boolean,
	Connection: RBXScriptConnection,
}

local MAX_RATE = 70 -- particules/s par roue, en pleine glisse
local LEVEL_START = 0.08 -- en dessous, pas de fumée (un pneu qui chante à peine)
local DEFAULT_COLOR = Color3.fromRGB(225, 225, 230)

local function makeEmitter(attachment: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TireSmoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.VelocityInheritance = 0
	emitter.Drag = 1.5
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.LightInfluence = 0.5
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 7),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return emitter
end

-- `wheelAttachments` : les attaches des roues (WheelFL, FR, RL, RR) du châssis.
function TireSmoke.new(model: Model, chassis: BasePart, wheelAttachments: { Attachment }): TireSmoke
	local self = (setmetatable({}, TireSmoke) :: any) :: TireSmoke
	self.Model = model
	self.Attachments = {}
	self.Emitters = {}
	self.ItemId = nil
	self.Active = false
	for i, wheel in ipairs(wheelAttachments) do
		-- Au ras du sol, sous la roue.
		local attachment = Instance.new("Attachment")
		attachment.Name = "TireSmoke" .. i
		attachment.Position = wheel.Position - Vector3.new(0, 1.2, 0)
		attachment.Parent = chassis
		self.Attachments[i] = attachment
		self.Emitters[i] = makeEmitter(attachment)
	end
	self:_applyItem()
	self.Connection = model:GetAttributeChangedSignal("EquippedSmoke"):Connect(function()
		self:_applyItem()
	end)
	return self
end

-- Couleur de la fumée portée (bicolore : elle change en se dissipant).
function TireSmoke:_applyItem()
	local id = self.Model:GetAttribute("EquippedSmoke")
	local item = Catalog.Get(if type(id) == "string" then id else nil)
	self.ItemId = if item then item.Id else nil
	local first = if item and item.Color then item.Color else DEFAULT_COLOR
	local second = if item and item.Color2 then item.Color2 else first
	local color = ColorSequence.new(first, second)
	for _, emitter in ipairs(self.Emitters) do
		emitter.Color = color
	end
end

function TireSmoke:SetActive(active: boolean)
	self.Active = active
	if not active then
		for _, emitter in ipairs(self.Emitters) do
			emitter.Enabled = false
		end
	end
end

-- `levels` : crissement de chaque roue (0..1), dans l'ordre des attaches.
function TireSmoke:Update(levels: { number })
	if not self.Active then
		return
	end
	for i, emitter in ipairs(self.Emitters) do
		local level = levels[i] or 0
		local strength = math.clamp((level - LEVEL_START) / (1 - LEVEL_START), 0, 1)
		emitter.Rate = MAX_RATE * strength
		emitter.Enabled = strength > 0
	end
end

function TireSmoke:Destroy()
	self.Connection:Disconnect()
	for _, attachment in ipairs(self.Attachments) do
		attachment:Destroy()
	end
end

return TireSmoke
