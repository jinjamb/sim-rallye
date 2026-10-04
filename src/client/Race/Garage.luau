--!strict
--[[
	Garage.luau
	Le garage du paddock : entrer dans la zone violette ouvre ce panneau.
		- couleur de carrosserie et numéro de course (sauvegardés, visibles de
		  tous en course : LiveryPainter.luau côté serveur) ;
		- accès aux réglages de la voiture (le menu P).
	Derrière la zone, la voiture tourne sur sa plaque, aux couleurs choisies.
	Cet aperçu est une copie LOCALE du gabarit, comme le fantôme : chacun voit
	sa propre voiture sur la plaque, et elle n'existe que chez lui.

	Une seule voiture pour l'instant (la Rally2 du gabarit) : le choix du
	modèle viendra avec d'autres gabarits.
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Livery = require(ReplicatedStorage.Shared.Constants.Livery)
local PaddockLayout = require(ReplicatedStorage.Shared.Paddock.PaddockLayout)
local RaceUi = require(script.Parent.RaceUi)

local Garage = {}
Garage.__index = Garage

export type Callbacks = {
	GetLivery: () -> Livery.Livery?,
	SetLivery: (Livery.Livery) -> (),
	OpenSetup: () -> (),
}

export type Garage = typeof(setmetatable({}, Garage)) & {
	Callbacks: Callbacks,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	ColorLabel: TextLabel,
	NumberLabel: TextLabel,
	FirstButton: GuiButton?,
	TouchLayout: boolean,
	Inside: boolean,
	Showroom: Model?,
	ShowroomBase: CFrame?,
	NumberTag: TextLabel?,
	Angle: number,
	Shown: string, -- livrée affichée sur l'aperçu ("couleur/numéro")
}

local PANEL_WIDTH = 380
local PANEL_HEIGHT = 300
local SPIN_SPEED = 0.35 -- rad/s
local PAINT_ATTRIBUTE = "LiveryPaint" -- posé sur le gabarit par le serveur

function Garage.new(playerGui: Instance, callbacks: Callbacks): Garage
	local self = (setmetatable({}, Garage) :: any) :: Garage
	self.Callbacks = callbacks
	self.TouchLayout = false
	self.Inside = false
	self.Showroom = nil
	self.ShowroomBase = nil
	self.NumberTag = nil
	self.Angle = 0
	self.Shown = ""
	self.FirstButton = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "Garage"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10
	self.Gui = gui

	local panel = RaceUi.Panel(gui, 0.08)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -24, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Panel = panel
	self.Scale = scale

	local title = RaceUi.Label(panel, "GARAGE", 18, Enum.Font.GothamBlack, PaddockLayout.GARAGE_PAD.Color)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -70, 0, 24)
	local close = RaceUi.Button(panel, "×", function()
		self.Gui.Enabled = false
	end)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Size = UDim2.fromOffset(32, 28)
	close.TextSize = 18

	local car = RaceUi.Label(panel, "Voiture : Rally2, 4 roues motrices\n(une seule voiture pour l'instant)", 13, Enum.Font.GothamMedium, RaceUi.COLOR_DIM)
	car.Position = UDim2.fromOffset(16, 44)
	car.Size = UDim2.new(1, -32, 0, 36)
	car.TextYAlignment = Enum.TextYAlignment.Top

	-- Ligne "libellé [◀] valeur [▶]".
	local function stepper(y: number, text: string, onStep: (number) -> ()): TextLabel
		local label = RaceUi.Label(panel, text, 14)
		label.Position = UDim2.fromOffset(16, y)
		label.Size = UDim2.fromOffset(110, 30)
		local previous = RaceUi.Button(panel, "◀", function()
			onStep(-1)
		end)
		previous.Position = UDim2.fromOffset(PANEL_WIDTH - 246, y)
		previous.Size = UDim2.fromOffset(40, 30)
		if not self.FirstButton then
			self.FirstButton = previous
		end
		local value = RaceUi.Label(panel, "", 14, Enum.Font.GothamBold)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.Position = UDim2.fromOffset(PANEL_WIDTH - 200, y)
		value.Size = UDim2.fromOffset(138, 30)
		RaceUi.Corner(value, 6)
		local nextButton = RaceUi.Button(panel, "▶", function()
			onStep(1)
		end)
		nextButton.Position = UDim2.fromOffset(PANEL_WIDTH - 56, y)
		nextButton.Size = UDim2.fromOffset(40, 30)
		return value
	end

	local function change(edit: (Livery.Livery) -> Livery.Livery)
		local current = callbacks.GetLivery()
		if current then
			callbacks.SetLivery(edit(current))
			self:_refresh()
		end
	end
	self.ColorLabel = stepper(92, "Couleur", function(direction)
		change(function(current)
			return { Color = ((current.Color - 1 + direction) % #Livery.COLORS) + 1, Number = current.Number }
		end)
	end)
	self.NumberLabel = stepper(132, "Numéro", function(direction)
		change(function(current)
			local range = Livery.MAX_NUMBER - Livery.MIN_NUMBER + 1
			return { Color = current.Color, Number = ((current.Number - Livery.MIN_NUMBER + direction) % range) + Livery.MIN_NUMBER }
		end)
	end)

	local setup = RaceUi.Button(panel, "RÉGLAGES DE LA VOITURE (P)", function()
		callbacks.OpenSetup()
	end)
	setup.Position = UDim2.fromOffset(16, 182)
	setup.Size = UDim2.new(1, -32, 0, 36)

	local hint = RaceUi.Label(panel, "Ta couleur et ton numéro se voient sur ta voiture, en course comme aux essais. Aussi dans le menu C.", 12, Enum.Font.GothamMedium, RaceUi.COLOR_DIM)
	hint.Position = UDim2.fromOffset(16, 230)
	hint.Size = UDim2.new(1, -32, 0, 56)
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top

	gui.Parent = playerGui
	self:_refresh()
	return self
end

function Garage:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
	-- Mobile : au centre, au-dessus du joystick et du bouton de saut.
	self.Panel.AnchorPoint = if enabled then Vector2.new(0.5, 0) else Vector2.new(1, 0.5)
	self.Panel.Position = if enabled then UDim2.new(0.5, 0, 0, 50) else UDim2.new(1, -24, 0.5, 0)
end

function Garage:_refresh()
	local livery = self.Callbacks.GetLivery()
	if not livery then
		self.ColorLabel.Text = "…"
		self.NumberLabel.Text = "…"
		return
	end
	local color = Livery.ColorOf(livery)
	self.ColorLabel.Text = Livery.NameOf(livery)
	self.ColorLabel.BackgroundTransparency = 0
	self.ColorLabel.BackgroundColor3 = color
	self.ColorLabel.TextColor3 = Livery.ContrastOf(color)
	self.NumberLabel.Text = "#" .. tostring(livery.Number)
end

function Garage:SetOpen(open: boolean)
	self.Gui.Enabled = open
	if open then
		self:_refresh()
		local viewport = workspace.CurrentCamera.ViewportSize
		self.Scale.Scale = if self.TouchLayout then math.clamp(viewport.Y / 500, 0.6, 1) else math.clamp(viewport.Y / 1080, 0.6, 1.2)
		if not self.TouchLayout then
			GuiService.SelectedObject = self.FirstButton
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
		GuiService.SelectedObject = nil
	end
end

-- Copie inerte du gabarit, posée sur la plaque tournante.
function Garage:_buildShowroom(): Model?
	local template = ReplicatedStorage:FindFirstChild("CarTemplate")
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.Name = "ShowroomCar"
	for _, item in ipairs(model:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(item)) do
			CollectionService:RemoveTag(item, tag)
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif item:IsA("ParticleEmitter") or item:IsA("Sound") or item:IsA("LuaSourceContainer")
			or item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			item:Destroy()
		end
	end
	-- Posée sur la plaque : le bas de la voiture au ras du dessus de la plaque.
	local boxFrame, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomOffset = pivot.Position.Y - (boxFrame.Position.Y - size.Y / 2)
	local top = PaddockLayout.SHOWROOM + Vector3.new(0, 0.6, 0)
	self.ShowroomBase = CFrame.new(top + Vector3.new(0, bottomOffset, 0)) * pivot.Rotation

	-- Numéro de course au-dessus de la voiture.
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(90, 50)
		tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 2, 0)
		tag.MaxDistance = 200
		tag.Adornee = primary
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(0.06, 0.06, 0.08)
		RaceUi.Corner(label, 25)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 4
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = label
		label.Parent = tag
		tag.Parent = model
		self.NumberTag = label
	end
	model.Parent = workspace
	return model
end

-- Couleurs de l'aperçu : celles que le joueur est en train de choisir.
function Garage:_paintShowroom(livery: Livery.Livery)
	local model = self.Showroom
	if not model then
		return
	end
	local color = Livery.ColorOf(livery)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute(PAINT_ATTRIBUTE) == true then
			item.Color = color
		end
	end
	local tag = self.NumberTag
	if tag then
		tag.Text = tostring(livery.Number)
		local ring = tag:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Color = color
		end
	end
end

--[[
	position : celle du personnage (nil s'il n'en a pas). Ouvre le garage en
	entrant dans la zone, le ferme en en sortant.
]]
function Garage:Update(dt: number, position: Vector3?)
	local pad = PaddockLayout.GARAGE_PAD
	local inside = false
	if position then
		local dx, dz = position.X - pad.Position.X, position.Z - pad.Position.Z
		inside = dx * dx + dz * dz <= pad.Radius * pad.Radius and math.abs(position.Y - pad.Position.Y) < 12
	end
	if inside ~= self.Inside then
		self.Inside = inside
		self:SetOpen(inside)
	end

	-- Aperçu : construit dès que le gabarit est là, tourne en permanence.
	if not self.Showroom then
		self.Showroom = self:_buildShowroom()
		self.Shown = ""
	end
	local model = self.Showroom
	local base = self.ShowroomBase
	if model and base then
		self.Angle = (self.Angle + SPIN_SPEED * dt) % (math.pi * 2)
		model:PivotTo(CFrame.new(base.Position) * CFrame.Angles(0, self.Angle, 0) * base.Rotation)
		local livery = self.Callbacks.GetLivery()
		if livery then
			local key = string.format("%d/%d", livery.Color, livery.Number)
			if key ~= self.Shown then
				self.Shown = key
				self:_paintShowroom(livery)
				if self.Gui.Enabled then
					self:_refresh()
				end
			end
		end
	end
end

return Garage
