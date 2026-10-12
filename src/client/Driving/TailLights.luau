--!strict
--[[
	TailLights.luau
	Feux arrière, allumés dès que la voiture roule, pour tous les joueurs :
	dans la poussière de la terre ou la neige soulevée, c'est souvent la
	seule chose qu'on voit de la voiture de devant.

		- deux halos rouges (BillboardGui lumineux, ils percent la poussière),
		  plus vifs et plus grands au FREINAGE (feux stop) ;
		- une lumière rouge derrière la voiture, qui teinte le nuage de
		  poussière et le rend repérable de loin.

	Piloté par le même état que le son (CarAudio.luau) : Brake vient de la
	physique pour sa voiture, de la télémétrie pour les autres.
	Position : celle des feux des modèles du jeu (attributs TailLightZ et
	TailLightY posés par CarBodies), sinon celle du gabarit.
]]

local TailLights = {}
TailLights.__index = TailLights

export type TailLights = typeof(setmetatable({}, TailLights)) & {
	Model: Model?,
	Attachments: { Attachment },
	Halos: { BillboardGui },
	Glow: PointLight,
	Level: number, -- 0 : feux de position, 1 : feux stop
	Visible: boolean,
}

local HALF_WIDTH = 2.2
local DEFAULT_Y = 0.2
local DEFAULT_Z = 7.3
local HALO_SIZE = 1.1 -- studs, feux de position
local HALO_BRAKE_SIZE = 1.9 -- studs, au freinage
local GLOW_RANGE = 14
local RED = Color3.fromRGB(255, 30, 40)
local RESPONSE = 0.06 -- secondes : les feux stop s'allument presque aussitôt

local function halo(parent: Attachment): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "TailHalo"
	gui.Size = UDim2.fromScale(HALO_SIZE, HALO_SIZE)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.MaxDistance = 400
	gui.ResetOnSpawn = false
	gui.Adornee = parent
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = RED
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	-- Bord adouci : un cœur plein, une couronne qui s'estompe.
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	gradient.Parent = dot
	dot.Parent = gui
	gui.Parent = parent
	return gui
end

function TailLights.new(chassis: BasePart, model: Model?): TailLights
	local self = (setmetatable({}, TailLights) :: any) :: TailLights
	self.Model = model
	self.Attachments = {}
	self.Halos = {}
	self.Level = 0
	self.Visible = true
	for _, side in ipairs({ -1, 1 }) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "TailLight"
		attachment.Parent = chassis
		table.insert(self.Attachments, attachment)
		table.insert(self.Halos, halo(attachment))
	end
	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Range = GLOW_RANGE
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = self.Attachments[1]
	self.Glow = glow
	self:_place()
	self:SetVisible(false)
	return self
end

function TailLights:_place()
	local model = self.Model
	local z = if model then model:GetAttribute("TailLightZ") else nil
	local y = if model then model:GetAttribute("TailLightY") else nil
	local zValue = if type(z) == "number" then z else DEFAULT_Z
	local yValue = if type(y) == "number" then y else DEFAULT_Y
	for index, attachment in ipairs(self.Attachments) do
		local side = if index == 1 then -1 else 1
		attachment.Position = Vector3.new(side * HALF_WIDTH, yValue, zValue)
	end
end

-- Allumés quand la voiture roule (pilotée), éteints sinon.
function TailLights:SetVisible(visible: boolean)
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	for _, gui in ipairs(self.Halos) do
		gui.Enabled = visible
	end
	self.Glow.Enabled = visible
end

-- `brake` : 0..1 (pédale de frein).
function TailLights:Update(dt: number, brake: number)
	self:_place()
	local target = if brake > 0.1 then 1 else 0
	self.Level += (target - self.Level) * (1 - math.exp(-dt / RESPONSE))
	local size = HALO_SIZE + (HALO_BRAKE_SIZE - HALO_SIZE) * self.Level
	for _, gui in ipairs(self.Halos) do
		gui.Size = UDim2.fromScale(size, size)
		gui.Brightness = 2 + 4 * self.Level
	end
	self.Glow.Brightness = 0.6 + 2.4 * self.Level
end

function TailLights:Destroy()
	for _, attachment in ipairs(self.Attachments) do
		attachment:Destroy()
	end
end

return TailLights
