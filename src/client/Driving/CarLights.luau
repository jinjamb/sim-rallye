--!strict
--[[
	CarLights.luau
	Les feux d'une voiture, allumés dès qu'elle roule, pour tous les joueurs :
	dans la poussière de la terre ou la neige soulevée, c'est souvent la
	seule chose qu'on voit de la voiture de devant (ou de celle qui arrive).

	ARRIÈRE :
		- deux halos rouges (BillboardGui lumineux, ils percent la poussière),
		  plus vifs et plus grands au FREINAGE (feux stop) ;
		- une lumière rouge derrière la voiture, qui teinte le nuage de
		  poussière et le rend repérable de loin. C'est un projecteur tourné
		  vers l'arrière, posé derrière le pare-chocs : une lumière ronde,
		  sans ombre, éclairerait la voiture elle-même (gros halo rouge).
	AVANT, à la couleur des PHARES portés (Items/Headlights.luau, attribut
	EquippedHeadlight) :
		- deux halos sur les phares ;
		- les optiques du modèle (pièces HeadLight, phares longue portée
		  SpotLamp) prennent la couleur.
	La nuit, les vrais faisceaux de sa voiture prennent aussi cette couleur
	(StageModifier.luau : CarLights.HeadlightColor).

	Piloté par le même état que le son (CarAudio.luau) : Brake vient de la
	physique pour sa voiture, de la télémétrie pour les autres.
	Position : celle des feux des modèles du jeu (attributs TailLightZ,
	TailLightY, HeadLightZ posés par CarBodies), sinon celle du gabarit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)

local CarLights = {}
CarLights.__index = CarLights

export type CarLights = typeof(setmetatable({}, CarLights)) & {
	Model: Model?,
	Rear: { Attachment },
	RearHalos: { BillboardGui },
	Front: { Attachment },
	FrontHalos: { BillboardGui },
	Glow: SpotLight,
	GlowAttachment: Attachment,
	Level: number, -- 0 : feux de position, 1 : feux stop
	Visible: boolean,
	Style: string, -- phares portés, déjà appliqués
	NextLensCheck: number, -- os.clock : les optiques sont recolorées de temps en temps (carrosserie changée)
}

local HALF_WIDTH = 2.2
local DEFAULT_Y = 0.2
local DEFAULT_TAIL_Z = 7.3
local DEFAULT_HEAD_Z = -7.1
local HALO_SIZE = 1.1 -- studs, feux de position
local HALO_BRAKE_SIZE = 1.9 -- studs, au freinage
local FRONT_HALO_SIZE = 1.3
local GLOW_RANGE = 14
local GLOW_BEHIND = 1 -- studs derrière les feux arrière
local GLOW_IDLE = 0.3 -- feux de position
local GLOW_BRAKE = 1.5 -- en plus, au freinage
local RED = Color3.fromRGB(255, 30, 40)
local RESPONSE = 0.06 -- secondes : les feux stop s'allument presque aussitôt
local LENS_CHECK_INTERVAL = 1 -- secondes
local LENS_NAMES = { HeadLight = true, Headlight = true, SpotLamp = true }

-- La couleur des phares d'une voiture (son objet porté, sinon l'halogène de série).
function CarLights.HeadlightColor(model: Instance?): Color3
	local id = if model then model:GetAttribute("EquippedHeadlight") else nil
	local item = Catalog.Get(if type(id) == "string" then id else nil)
	if not item or item.Kind ~= "Headlight" then
		item = Catalog.Default("Headlight")
	end
	return if item and item.Color then item.Color else Color3.fromRGB(255, 240, 210)
end

local function halo(parent: Attachment, color: Color3, size: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LightHalo"
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.MaxDistance = 400
	gui.ResetOnSpawn = false
	gui.Adornee = parent
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = color
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

local function pair(chassis: BasePart, name: string, color: Color3, size: number): ({ Attachment }, { BillboardGui })
	local attachments, halos = {}, {}
	for _ = 1, 2 do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = chassis
		table.insert(attachments, attachment)
		table.insert(halos, halo(attachment, color, size))
	end
	return attachments, halos
end

function CarLights.new(chassis: BasePart, model: Model?): CarLights
	local self = (setmetatable({}, CarLights) :: any) :: CarLights
	self.Model = model
	self.Level = 0
	self.Visible = true
	self.Style = ""
	self.NextLensCheck = 0
	self.Rear, self.RearHalos = pair(chassis, "TailLight", RED, HALO_SIZE)
	self.Front, self.FrontHalos = pair(chassis, "HeadLightHalo", CarLights.HeadlightColor(model), FRONT_HALO_SIZE)
	local glowAttachment = Instance.new("Attachment")
	glowAttachment.Name = "TailGlow"
	glowAttachment.Parent = chassis
	self.GlowAttachment = glowAttachment
	local glow = Instance.new("SpotLight")
	glow.Face = Enum.NormalId.Back -- vers l'arrière (+Z du châssis)
	glow.Angle = 100
	glow.Color = RED
	glow.Range = GLOW_RANGE
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = glowAttachment
	self.Glow = glow
	self:_place()
	self:SetVisible(false)
	return self
end

local function number(model: Model?, name: string, default: number): number
	local value = if model then model:GetAttribute(name) else nil
	return if type(value) == "number" then value else default
end

function CarLights:_place()
	local model = self.Model
	local tailZ = number(model, "TailLightZ", DEFAULT_TAIL_Z)
	local headZ = number(model, "HeadLightZ", DEFAULT_HEAD_Z)
	local y = number(model, "TailLightY", DEFAULT_Y)
	for index, attachment in ipairs(self.Rear) do
		attachment.Position = Vector3.new((if index == 1 then -1 else 1) * HALF_WIDTH, y, tailZ)
	end
	for index, attachment in ipairs(self.Front) do
		attachment.Position = Vector3.new((if index == 1 then -1 else 1) * HALF_WIDTH * 0.92, y, headZ)
	end
	self.GlowAttachment.Position = Vector3.new(0, y, tailZ + GLOW_BEHIND)
end

-- Les phares portés : halos et optiques à leur couleur.
function CarLights:_applyHeadlights(force: boolean)
	local model = self.Model
	local id = if model then model:GetAttribute("EquippedHeadlight") else nil
	local key = if type(id) == "string" then id else ""
	local now = os.clock()
	if key == self.Style and not force and now < self.NextLensCheck then
		return
	end
	self.Style = key
	self.NextLensCheck = now + LENS_CHECK_INTERVAL
	local color = CarLights.HeadlightColor(model)
	for _, gui in ipairs(self.FrontHalos) do
		local dot = gui:FindFirstChild("Dot")
		if dot and dot:IsA("Frame") then
			dot.BackgroundColor3 = color
		end
	end
	if model then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") and LENS_NAMES[item.Name] then
				item.Color = color
			end
		end
	end
end

-- Allumés quand la voiture roule (pilotée), éteints sinon.
function CarLights:SetVisible(visible: boolean)
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	for _, list in ipairs({ self.RearHalos, self.FrontHalos }) do
		for _, gui in ipairs(list) do
			gui.Enabled = visible
		end
	end
	self.Glow.Enabled = visible
end

-- `brake` : 0..1 (pédale de frein).
function CarLights:Update(dt: number, brake: number)
	self:_place()
	self:_applyHeadlights(false)
	local target = if brake > 0.1 then 1 else 0
	self.Level += (target - self.Level) * (1 - math.exp(-dt / RESPONSE))
	local size = HALO_SIZE + (HALO_BRAKE_SIZE - HALO_SIZE) * self.Level
	for _, gui in ipairs(self.RearHalos) do
		gui.Size = UDim2.fromScale(size, size)
		gui.Brightness = 2 + 4 * self.Level
	end
	self.Glow.Brightness = GLOW_IDLE + GLOW_BRAKE * self.Level
end

function CarLights:Destroy()
	for _, list in ipairs({ self.Rear, self.Front }) do
		for _, attachment in ipairs(list) do
			attachment:Destroy()
		end
	end
	self.GlowAttachment:Destroy()
end

return CarLights
