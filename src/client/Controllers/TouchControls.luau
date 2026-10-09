--!strict
--[[
	TouchControls.luau
	Commandes à l'écran pour téléphones et tablettes.

		À GAUCHE, un VOLANT FLOTTANT : là où le pouce se pose devient le centre ;
		glisser vers la gauche ou la droite braque, d'autant plus qu'on glisse
		loin. Pas besoin de viser un bouton précis, et le centre suit le pouce
		d'un virage à l'autre.
		À DROITE, les PÉDALES, ANALOGIQUES : plus on appuie haut sur la pédale,
		plus on accélère (ou freine). Un appui en bas donne déjà 35 % : le dosage
		se fait en glissant le pouce. À côté : frein à main, rapports.
		EN HAUT, une rangée d'actions : remise en piste, retour au départ, boîte
		auto/manuelle, réglages, classement, courses de rallycross, descendre de
		voiture. En course, "départ" et "sortir" disparaissent (SetRaceMode).
		Hors de la voiture : "Prendre le volant" et "Courses".

	MULTITOUCH : chaque contrôle retient LE doigt qui l'a touché (l'InputObject
	d'un toucher reste le même du début à la fin) et ne suit que lui. On peut
	donc braquer, accélérer et tirer le frein à main en même temps, et un pouce
	qui déborde de sa pédale continue de la commander.

	Les valeurs sont poussées dans InputManager (SetTouch), qui les fusionne
	avec le clavier et la manette.
]]

local UserInputService = game:GetService("UserInputService")

local InputManager = require(script.Parent.InputManager)

local TouchControls = {}
TouchControls.__index = TouchControls

export type Actions = {
	ShiftUp: () -> (),
	ShiftDown: () -> (),
	ToggleMode: () -> (),
	Recover: () -> (),
	Restart: () -> (),
	ToggleSetup: () -> (),
	ToggleLeaderboard: () -> (),
	CycleGhost: () -> (),
	ToggleRaceMenu: () -> (),
	ReturnToPaddock: () -> (),
	EnterCar: () -> (),
	ExitCar: () -> (),
}

type Hold = {
	Frame: GuiObject,
	Touch: InputObject?,
	Value: number,
	Update: (Hold, Vector3) -> (),
}

export type TouchControls = typeof(setmetatable({}, TouchControls)) & {
	Gui: ScreenGui,
	Driving: Frame,
	Walking: Frame,
	Root: Frame,
	Scale: UIScale,
	Steer: Hold,
	Throttle: Hold,
	Brake: Hold,
	Handbrake: Hold,
	SteerKnob: Frame,
	SteerOrigin: number?,
	Holds: { Hold },
	ActionRow: Frame,
	ActionButtons: { [string]: TextButton },
	EnterButton: TextButton,
}

-- Dimensions de référence pour un écran de 400 points de haut (téléphone en
-- paysage) ; un UIScale adapte aux autres écrans.
local REFERENCE_HEIGHT = 400
local MARGIN = 16
local STEER_SIZE = Vector2.new(240, 140)
local STEER_RANGE = 90 -- glissement (points) pour braquer à fond
local PEDAL_WIDTH = 84
local GAP = 8
local PEDAL_MIN = 0.35 -- un appui tout en bas de la pédale

local COLOR_FILL = Color3.fromRGB(20, 21, 26)
local COLOR_EDGE = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT = Color3.fromRGB(235, 236, 240)
local COLOR_THROTTLE = Color3.fromRGB(70, 200, 95)
local COLOR_BRAKE = Color3.fromRGB(235, 65, 55)
local COLOR_HANDBRAKE = Color3.fromRGB(255, 140, 40)

local function styled(frame: GuiObject, radius: number)
	frame.BackgroundColor3 = COLOR_FILL
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_EDGE
	stroke.Transparency = 0.75
	stroke.Thickness = 1.5
	stroke.Parent = frame
end

local function caption(parent: Instance, text: string, textSize: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = COLOR_TEXT
	label.TextWrapped = true
	label.Parent = parent
end

-- Zone tenue par un doigt : on la place depuis le coin bas-droit (ou bas-gauche).
local function holdFrame(parent: Instance, anchor: Vector2, position: UDim2, size: Vector2, text: string): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Active = true -- capte le toucher (pas de clic "à travers")
	styled(frame, 12)
	caption(frame, text, 13)
	frame.Parent = parent
	return frame
end

local function actionButton(parent: Instance, text: string, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(54, 34)
	button.Text = text
	button.TextSize = 11
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = COLOR_TEXT
	button.AutoButtonColor = true
	styled(button, 8)
	button.Activated:Connect(callback)
	button.Parent = parent
	return button
end

function TouchControls.new(playerGui: Instance, actions: Actions): TouchControls
	local self = (setmetatable({}, TouchControls) :: any) :: TouchControls
	self.SteerOrigin = nil
	self.Holds = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	self.Gui = gui

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Root = root
	self.Scale = scale

	-- Au volant -------------------------------------------------------------
	local driving = Instance.new("Frame")
	driving.Name = "Driving"
	driving.BackgroundTransparency = 1
	driving.Size = UDim2.fromScale(1, 1)
	driving.Visible = false
	driving.Parent = root
	self.Driving = driving

	-- Volant flottant
	local steerFrame = holdFrame(driving, Vector2.new(0, 1), UDim2.new(0, MARGIN, 1, -MARGIN), STEER_SIZE, "")
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.new(1, -40, 0, 6)
	track.BackgroundColor3 = COLOR_EDGE
	track.BackgroundTransparency = 0.7
	track.BorderSizePixel = 0
	track.Parent = steerFrame
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(46, 46)
	knob.BackgroundColor3 = COLOR_EDGE
	knob.BackgroundTransparency = 0.35
	knob.BorderSizePixel = 0
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	knob.Parent = steerFrame
	self.SteerKnob = knob
	local steerHint = Instance.new("TextLabel")
	steerHint.BackgroundTransparency = 1
	steerHint.Position = UDim2.new(0, 0, 1, -22)
	steerHint.Size = UDim2.new(1, 0, 0, 18)
	steerHint.Text = "◀  DIRECTION  ▶"
	steerHint.TextSize = 11
	steerHint.Font = Enum.Font.GothamBold
	steerHint.TextColor3 = COLOR_TEXT
	steerHint.TextTransparency = 0.3
	steerHint.Parent = steerFrame

	-- Pédales et frein à main, du bord droit vers le centre
	local throttleFrame = holdFrame(driving, Vector2.new(1, 1), UDim2.new(1, -MARGIN, 1, -MARGIN), Vector2.new(PEDAL_WIDTH, 140), "GAZ")
	local brakeX = -(MARGIN + PEDAL_WIDTH + GAP)
	local brakeFrame = holdFrame(driving, Vector2.new(1, 1), UDim2.new(1, brakeX, 1, -MARGIN), Vector2.new(PEDAL_WIDTH, 100), "FREIN")
	local handbrakeFrame = holdFrame(driving, Vector2.new(1, 1), UDim2.new(1, brakeX, 1, -(MARGIN + 100 + GAP)), Vector2.new(PEDAL_WIDTH, 48), "FREIN À MAIN")

	-- Rapports, troisième colonne
	local shiftX = brakeX - PEDAL_WIDTH - GAP
	local function shiftButton(text: string, bottom: number, callback: () -> ())
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, shiftX, 1, bottom)
		button.Size = UDim2.fromOffset(64, 52)
		button.Text = text
		button.TextSize = 22
		button.Font = Enum.Font.GothamBlack
		button.TextColor3 = COLOR_TEXT
		button.AutoButtonColor = true
		styled(button, 10)
		button.Activated:Connect(callback)
		button.Parent = driving
	end
	shiftButton("−", -MARGIN, actions.ShiftDown)
	shiftButton("+", -(MARGIN + 52 + GAP), actions.ShiftUp)

	-- Rangée d'actions, en haut au centre (largeur ajustée par le UIListLayout)
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 6)
	row.Size = UDim2.fromOffset(0, 34)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.Parent = driving
	self.ActionRow = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local actionList = {
		{ "PISTE", actions.Recover },
		{ "DÉPART", actions.Restart },
		{ "BOÎTE", actions.ToggleMode },
		{ "RÉGLAGES", actions.ToggleSetup },
		{ "TEMPS", actions.ToggleLeaderboard },
		{ "FANTÔME", actions.CycleGhost },
		{ "COURSES", actions.ToggleRaceMenu },
		{ "PADDOCK", actions.ReturnToPaddock },
		{ "SORTIR", actions.ExitCar },
	}
	self.ActionButtons = {}
	for index, entry in ipairs(actionList) do
		local name = entry[1] :: string
		local button = actionButton(row, name, entry[2] :: () -> ())
		button.LayoutOrder = index
		self.ActionButtons[name] = button
	end

	-- À pied ------------------------------------------------------------------
	local walking = Instance.new("Frame")
	walking.Name = "Walking"
	walking.BackgroundTransparency = 1
	walking.Size = UDim2.fromScale(1, 1)
	walking.Visible = false
	walking.Parent = root
	self.Walking = walking
	local enter = Instance.new("TextButton")
	enter.AnchorPoint = Vector2.new(0.5, 1)
	enter.Position = UDim2.new(0.5, 0, 1, -MARGIN)
	enter.Size = UDim2.fromOffset(200, 52)
	enter.Text = "PRENDRE LE VOLANT"
	enter.TextSize = 15
	enter.Font = Enum.Font.GothamBlack
	enter.TextColor3 = COLOR_TEXT
	styled(enter, 12)
	enter.Activated:Connect(actions.EnterCar)
	enter.Visible = false -- sans voiture (arrivée au paddock), rien à prendre
	enter.Parent = walking
	self.EnterButton = enter
	local races = Instance.new("TextButton")
	races.AnchorPoint = Vector2.new(0.5, 1)
	races.Position = UDim2.new(0.5, 0, 1, -(MARGIN + 52 + GAP))
	races.Size = UDim2.fromOffset(200, 40)
	races.Text = "COURSES"
	races.TextSize = 14
	races.Font = Enum.Font.GothamBlack
	races.TextColor3 = COLOR_TEXT
	styled(races, 12)
	races.Activated:Connect(actions.ToggleRaceMenu)
	races.Parent = walking
	-- À pied loin du paddock (descendu de voiture sur la spéciale) : retour direct.
	-- Colonne centrale (le coin bas-droit est au bouton de saut de Roblox).
	local home = Instance.new("TextButton")
	home.AnchorPoint = Vector2.new(0.5, 1)
	home.Position = UDim2.new(0.5, 0, 1, -(MARGIN + 52 + GAP + 40 + GAP))
	home.Size = UDim2.fromOffset(200, 40)
	home.Text = "PADDOCK"
	home.TextSize = 13
	home.Font = Enum.Font.GothamBlack
	home.TextColor3 = COLOR_TEXT
	styled(home, 12)
	home.Activated:Connect(actions.ReturnToPaddock)
	home.Parent = walking

	-- Zones tenues ------------------------------------------------------------
	local function pedalUpdate(color: Color3)
		return function(hold: Hold, position: Vector3)
			local frame = hold.Frame
			local top = frame.AbsolutePosition.Y
			local height = math.max(1, frame.AbsoluteSize.Y)
			-- Hauteur du doigt sur la pédale (0 en bas, 1 en haut).
			local fraction = math.clamp((top + height - position.Y) / height, 0, 1)
			hold.Value = PEDAL_MIN + (1 - PEDAL_MIN) * fraction
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = 0.75 - 0.45 * hold.Value
		end
	end

	self.Throttle = { Frame = throttleFrame, Touch = nil, Value = 0, Update = pedalUpdate(COLOR_THROTTLE) }
	self.Brake = { Frame = brakeFrame, Touch = nil, Value = 0, Update = pedalUpdate(COLOR_BRAKE) }
	self.Handbrake = {
		Frame = handbrakeFrame,
		Touch = nil,
		Value = 0,
		Update = function(hold: Hold, _position: Vector3)
			hold.Value = 1
			hold.Frame.BackgroundColor3 = COLOR_HANDBRAKE
			hold.Frame.BackgroundTransparency = 0.2
		end,
	}
	self.Steer = {
		Frame = steerFrame,
		Touch = nil,
		Value = 0,
		Update = function(hold: Hold, position: Vector3)
			local origin = self.SteerOrigin
			if origin == nil then
				origin = position.X
				self.SteerOrigin = origin
			end
			-- Écart en points d'écran ramené à l'échelle de référence.
			local offset = (position.X - (origin :: number)) / math.max(0.1, self.Scale.Scale)
			-- Glisser à droite braque à droite ; steer positif = à gauche.
			hold.Value = -math.clamp(offset / STEER_RANGE, -1, 1)
			self.SteerKnob.Position = UDim2.new(0.5, -hold.Value * (STEER_SIZE.X / 2 - 30), 0.5, 0)
		end,
	}
	self.Holds = { self.Steer, self.Throttle, self.Brake, self.Handbrake }

	for _, hold in ipairs(self.Holds) do
		hold.Frame.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch and hold.Touch == nil then
				hold.Touch = input
				hold.Update(hold, input.Position)
				self:_push()
			end
		end)
	end
	-- Mouvements et relâchements suivis globalement : un doigt qui sort de sa
	-- zone continue de la commander jusqu'à ce qu'il quitte l'écran.
	UserInputService.TouchMoved:Connect(function(input: InputObject)
		for _, hold in ipairs(self.Holds) do
			if hold.Touch == input then
				hold.Update(hold, input.Position)
				self:_push()
			end
		end
	end)
	UserInputService.TouchEnded:Connect(function(input: InputObject)
		for _, hold in ipairs(self.Holds) do
			if hold.Touch == input then
				self:_release(hold)
			end
		end
		self:_push()
	end)

	gui.Parent = playerGui
	return self
end

function TouchControls:_release(hold: Hold)
	hold.Touch = nil
	hold.Value = 0
	hold.Frame.BackgroundColor3 = COLOR_FILL
	hold.Frame.BackgroundTransparency = 0.45
	if hold == self.Steer then
		self.SteerOrigin = nil
		self.SteerKnob.Position = UDim2.fromScale(0.5, 0.5)
	end
end

function TouchControls:_push()
	InputManager:SetTouch(self.Throttle.Value, self.Brake.Value, self.Steer.Value, self.Handbrake.Value > 0)
end

-- Au volant : volant, pédales et actions. À pied : "Prendre le volant".
function TouchControls:SetDriving(driving: boolean)
	self.Driving.Visible = driving
	self.Walking.Visible = not driving
	if not driving then
		for _, hold in ipairs(self.Holds) do
			self:_release(hold)
		end
		self:_push()
	end
end

-- À pied : "Prendre le volant" seulement si on a une voiture (zone VOITURE du paddock).
function TouchControls:SetCarAvailable(available: boolean)
	self.EnterButton.Visible = available
end

-- En course : pas de retour au départ de la spéciale ni au paddock, pas de
-- fantôme, et on ne descend pas de voiture (on abandonne depuis le menu COURSES).
function TouchControls:SetRaceMode(racing: boolean)
	for _, name in ipairs({ "DÉPART", "FANTÔME", "SORTIR", "PADDOCK" }) do
		local button = self.ActionButtons[name]
		if button then
			button.Visible = not racing
		end
	end
end

function TouchControls:Update()
	local viewport = workspace.CurrentCamera.ViewportSize
	local scale = math.clamp(viewport.Y / REFERENCE_HEIGHT, 0.75, 1.6)
	self.Scale.Scale = scale
	-- UIScale agrandit aussi le cadre racine : on le réduit d'autant pour qu'il
	-- couvre exactement l'écran, sinon les pédales (ancrées en bas à droite)
	-- sortiraient de l'écran dès que l'échelle dépasse 1.
	self.Root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

-- Un écran tactile SANS clavier : téléphone, tablette (un PC portable tactile
-- garde son clavier, inutile d'encombrer l'écran).
function TouchControls.IsTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return TouchControls
