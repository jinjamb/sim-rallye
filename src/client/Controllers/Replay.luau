--!strict
--[[
	Replay.luau
	Le ralenti : rejouer un passage de la spéciale (son meilleur, ou celui du
	fantôme qu'on affronte) comme à la télévision, et le mode photo.

	LA VOITURE : une copie pleine du gabarit, à sa livrée (LiveryPainter),
	posée image par image sur la trajectoire que le fantôme a enregistrée
	(Ghost.PoseAt : 10 images par seconde, interpolées). Locale, inerte.

	LECTURE : pause, ±5 s, vitesse ×1, ×½, ×¼, barre de lecture cliquable.
	CAMÉRAS :
		TV         : caméras posées le long de la spéciale (tous les
		             TV_SPACING studs, d'un côté puis de l'autre) ; celle que la
		             voiture approche la suit et zoome, comme à la télévision ;
		Poursuite  : derrière la voiture ;
		Hélico     : en orbite lente, au-dessus ;
		Embarquée  : sur le capot.
	MODE PHOTO : l'image se fige ; la caméra tourne autour de la voiture
	(glisser, molette ou pincement ; clavier : A/D, W/S, Q/E), profondeur de
	champ sur la voiture, filtres de couleur, interface masquable (U) pour
	une capture propre (Impr. écran, ou le menu Roblox).

	Pendant le ralenti, les autres écrans du jeu sont masqués, puis rendus.
	Avec le streaming, le décor est demandé autour de la voiture rejouée.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local StageTrack = require(game:GetService("ReplicatedStorage").Shared.Stage.StageTrack)
local LiveryPainter = require(game:GetService("ReplicatedStorage").Shared.Cosmetics.LiveryPainter)
local Livery = require(game:GetService("ReplicatedStorage").Shared.Constants.Livery)
local Ghost = require(script.Parent.Ghost)
local Theme = require(script.Parent.Parent.UI.Theme)

local Replay = {}
Replay.__index = Replay

type CameraMode = "TV" | "Chase" | "Heli" | "Onboard"
type TvCamera = { Distance: number, Position: Vector3 }
type Filter = { Name: string, Saturation: number, Contrast: number, Brightness: number, Tint: Color3 }

export type Replay = typeof(setmetatable({}, Replay)) & {
	PlayerGui: Instance,
	Camera: Camera,
	Active: boolean,
	Data: Ghost.GhostData?,
	Title: string,
	Duration: number,
	Time: number,
	SpeedIndex: number,
	Paused: boolean,
	Mode: CameraMode,
	Photo: boolean,
	Yaw: number,
	Pitch: number,
	Distance: number,
	FilterIndex: number,
	UiHidden: boolean,
	Dragging: boolean,
	Model: Model?,
	Hint: number,
	TvCameras: { TvCamera },
	SmoothFov: number,
	LastStreamAt: number,
	HiddenGuis: { [ScreenGui]: boolean },
	Effects: { Instance },
	ColorEffect: ColorCorrectionEffect?,
	FocusEffect: DepthOfFieldEffect?,

	Gui: ScreenGui,
	Bar: Frame,
	Scale: UIScale,
	TitleLabel: TextLabel,
	TimeLabel: TextLabel,
	Fill: Frame,
	PlayButton: TextButton,
	SeekButtons: { TextButton },
	SpeedButton: TextButton,
	CameraButton: TextButton,
	PhotoButton: TextButton,
	FilterButton: TextButton,
	HideButton: TextButton,
	HintLabel: TextLabel,
	OnExit: () -> (),
}

local SPEEDS = { 1, 0.5, 0.25 }
local SEEK_STEP = 5
local TV_SPACING = 180 -- studs entre deux caméras TV
local TV_SIDE = StageTrack.ROAD_WIDTH / 2 + 18
local TV_HEIGHT = 7
local TV_SWITCH_BEHIND = 25 -- on garde la caméra encore ce peu après le passage
local STREAM_INTERVAL = 2
local BAR_WIDTH = 680

local CAMERA_ORDER: { CameraMode } = { "TV", "Chase", "Heli", "Onboard" }
local CAMERA_NAMES: { [string]: string } = { TV = "TV", Chase = "POURSUITE", Heli = "HÉLICO", Onboard = "EMBARQUÉE" }

local FILTERS: { Filter } = {
	{ Name = "Naturel", Saturation = 0, Contrast = 0, Brightness = 0, Tint = Color3.new(1, 1, 1) },
	{ Name = "Contrasté", Saturation = 0.25, Contrast = 0.25, Brightness = 0, Tint = Color3.new(1, 1, 1) },
	{ Name = "Noir et blanc", Saturation = -1, Contrast = 0.2, Brightness = 0, Tint = Color3.new(1, 1, 1) },
	{ Name = "Vintage", Saturation = -0.35, Contrast = 0.1, Brightness = 0.02, Tint = Color3.fromRGB(255, 236, 210) },
	{ Name = "Coucher de soleil", Saturation = 0.15, Contrast = 0.1, Brightness = 0.03, Tint = Color3.fromRGB(255, 214, 178) },
}

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%05.2f", minutes, seconds - minutes * 60)
end

-- Caméras TV le long de la spéciale, d'un côté puis de l'autre.
local function buildTvCameras(): { TvCamera }
	local cameras: { TvCamera } = {}
	local side = 1
	local distance = StageTrack.START_DISTANCE + 60
	local finish = StageTrack.GetFinishDistance()
	while distance < finish + 60 do
		local sample = StageTrack.SampleAt(distance)
		table.insert(cameras, {
			Distance = distance,
			Position = sample.Position + sample.Left * side * TV_SIDE + Vector3.new(0, TV_HEIGHT, 0),
		})
		side = -side
		distance += TV_SPACING
	end
	return cameras
end

function Replay.new(playerGui: Instance, camera: Camera, onExit: () -> ()): Replay
	local self = (setmetatable({}, Replay) :: any) :: Replay
	self.PlayerGui = playerGui
	self.Camera = camera
	self.OnExit = onExit
	self.Active = false
	self.Data = nil
	self.Title = ""
	self.Duration = 0
	self.Time = 0
	self.SpeedIndex = 1
	self.Paused = false
	self.Mode = "TV"
	self.Photo = false
	self.Yaw = 0
	self.Pitch = -0.25
	self.Distance = 18
	self.FilterIndex = 1
	self.UiHidden = false
	self.Dragging = false
	self.Model = nil
	self.Hint = 0
	self.TvCameras = {}
	self.SmoothFov = 50
	self.LastStreamAt = 0
	self.HiddenGuis = {}
	self.Effects = {}
	self.ColorEffect = nil
	self.FocusEffect = nil

	-- Barre de commandes, en bas au centre ----------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "Replay"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20
	self.Gui = gui

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.Size = UDim2.fromOffset(BAR_WIDTH, 132)
	bar.BackgroundColor3 = Theme.PANEL
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel = 0
	Theme.Corner(bar)
	Theme.Shade(bar)
	Theme.AccentBar(bar)
	local checker = Theme.Checker(bar, BAR_WIDTH, 3, 2)
	checker.BackgroundTransparency = 0.4
	local scale = Instance.new("UIScale")
	scale.Parent = bar
	bar.Parent = gui
	self.Bar = bar
	self.Scale = scale

	local tag = Theme.Tag(bar, "RALENTI", Theme.ACCENT, Theme.ON_ACCENT, 14)
	tag.Position = UDim2.fromOffset(16, 12)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(100, 10)
	title.Size = UDim2.new(1, -300, 0, 24)
	title.FontFace = Theme.HEADLINE
	title.TextSize = 18
	title.TextColor3 = Theme.TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = bar
	self.TitleLabel = title
	local time = Instance.new("TextLabel")
	time.BackgroundTransparency = 1
	time.AnchorPoint = Vector2.new(1, 0)
	time.Position = UDim2.new(1, -16, 0, 10)
	time.Size = UDim2.fromOffset(190, 24)
	time.FontFace = Theme.DIGITS
	time.TextSize = 18
	time.TextColor3 = Theme.TEXT
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.Parent = bar
	self.TimeLabel = time

	-- Barre de lecture : cliquer pour aller à un instant.
	local scrub = Instance.new("TextButton")
	scrub.Text = ""
	scrub.AutoButtonColor = false
	scrub.BackgroundColor3 = Theme.PANEL_2
	scrub.BorderSizePixel = 0
	scrub.Position = UDim2.fromOffset(16, 42)
	scrub.Size = UDim2.new(1, -32, 0, 8)
	scrub.Parent = bar
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.ACCENT
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = scrub
	self.Fill = fill
	scrub.Activated:Connect(function(input: InputObject)
		local fraction = math.clamp((input.Position.X - scrub.AbsolutePosition.X) / math.max(1, scrub.AbsoluteSize.X), 0, 1)
		self:Seek(fraction * self.Duration)
	end)

	-- Boutons.
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(16, 58)
	row.Size = UDim2.new(1, -32, 0, 34)
	row.Parent = bar
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local order = 0
	local function button(text: string, width: number, callback: () -> ()): TextButton
		order += 1
		local item = Instance.new("TextButton")
		item.Text = text
		item.LayoutOrder = order
		item.Size = UDim2.fromOffset(width, 34)
		item.FontFace = Theme.HEADLINE
		item.TextSize = 15
		item.TextColor3 = Theme.TEXT
		item.BackgroundColor3 = Theme.PANEL_2
		item.BorderSizePixel = 0
		item.AutoButtonColor = true
		Theme.Corner(item)
		item.Activated:Connect(callback)
		item.Parent = row
		return item
	end
	local back = button("−5 S", 54, function()
		self:Seek(self.Time - SEEK_STEP)
	end)
	self.PlayButton = button("❚❚", 54, function()
		self:TogglePause()
	end)
	local forward = button("+5 S", 54, function()
		self:Seek(self.Time + SEEK_STEP)
	end)
	self.SeekButtons = { back, forward }
	self.SpeedButton = button("×1", 54, function()
		self:CycleSpeed()
	end)
	self.CameraButton = button("CAMÉRA : TV", 150, function()
		self:CycleCamera()
	end)
	self.PhotoButton = button("PHOTO", 90, function()
		self:SetPhoto(not self.Photo)
	end)
	local quit = button("QUITTER", 100, function()
		self:Stop()
	end)
	Theme.Danger(quit)
	-- Mode photo : filtre et interface masquée, à la place des commandes de
	-- lecture (masquées : la liste ne garde que les boutons visibles).
	self.FilterButton = button("FILTRE : NATUREL", 190, function()
		self:CycleFilter()
	end)
	self.HideButton = button("MASQUER (U)", 120, function()
		self:SetUiHidden(true)
	end)
	self.FilterButton.LayoutOrder = 1
	self.HideButton.LayoutOrder = 2
	self.FilterButton.Visible = false
	self.HideButton.Visible = false

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(16, 98)
	hint.Size = UDim2.new(1, -32, 0, 26)
	hint.FontFace = Theme.BODY
	hint.TextSize = 13
	hint.TextColor3 = Theme.DIM
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.Parent = bar
	self.HintLabel = hint

	gui.Parent = playerGui

	-- Mode photo : glisser pour tourner autour de la voiture, molette pour la distance.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not self.Active or not self.Photo or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.Touch then
			self.Dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.Touch then
			self.Dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not self.Active or not self.Photo then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			self.Distance = math.clamp(self.Distance - input.Position.Z * 2, 6, 80)
		elseif self.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			self.Yaw -= input.Delta.X * 0.008
			self.Pitch = math.clamp(self.Pitch - input.Delta.Y * 0.006, -1.3, 0.15)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_positions, pinchScale: number, _velocity, state: Enum.UserInputState)
		if self.Active and self.Photo and state == Enum.UserInputState.Change then
			self.Distance = math.clamp(self.Distance / math.max(0.5, pinchScale), 6, 80)
		end
	end)
	return self
end

function Replay:IsActive(): boolean
	return self.Active
end

--[[
	Commence le ralenti d'un passage. `livery` : celle de la voiture rejouée
	(nil : celle du gabarit, pour le fantôme d'un autre pilote).
]]
function Replay:Start(data: Ghost.GhostData, title: string, livery: Livery.Livery?)
	if self.Active then
		self:Stop()
	end
	local model = Ghost.BuildSolidModel()
	if not model then
		return
	end
	self.Active = true
	self.Data = data
	self.Title = title
	self.Duration = Ghost.Duration(data)
	self.Time = 0
	self.SpeedIndex = 1
	self.Paused = false
	self.Mode = "TV"
	self.Photo = false
	self.UiHidden = false
	self.Hint = 0
	if #self.TvCameras == 0 then
		self.TvCameras = buildTvCameras()
	end

	-- La voiture, à la livrée voulue ; ensuite, plus rien ne la touche.
	model:PivotTo(Ghost.PoseAt(data, 0))
	model.Parent = workspace
	if livery then
		LiveryPainter.Prepare(model)
		LiveryPainter.Apply(model, livery)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanQuery = false
			item.CanCollide = false
		end
	end
	self.Model = model

	-- Les autres écrans s'effacent.
	self.HiddenGuis = {}
	for _, child in ipairs(self.PlayerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= self.Gui and child.Enabled then
			self.HiddenGuis[child] = true
			child.Enabled = false
		end
	end

	-- Filtre de couleur et profondeur de champ (mode photo).
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "ReplayFilter"
	color.Parent = Lighting
	local focus = Instance.new("DepthOfFieldEffect")
	focus.Name = "ReplayFocus"
	focus.Enabled = false
	focus.FarIntensity = 0.45
	focus.NearIntensity = 0.3
	focus.InFocusRadius = 12
	focus.Parent = Lighting
	self.ColorEffect = color
	self.FocusEffect = focus
	self.Effects = { color :: Instance, focus }
	self.FilterIndex = 1
	self:_applyFilter()

	self.TitleLabel.Text = title
	self.Gui.Enabled = true
	self:_refreshButtons()
end

function Replay:Stop()
	if not self.Active then
		return
	end
	self.Active = false
	self.Dragging = false
	local model = self.Model
	if model then
		model:Destroy()
		self.Model = nil
	end
	for _, effect in ipairs(self.Effects) do
		effect:Destroy()
	end
	self.Effects = {}
	self.ColorEffect = nil
	self.FocusEffect = nil
	for gui in pairs(self.HiddenGuis) do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	self.HiddenGuis = {}
	self.Gui.Enabled = false
	self.OnExit()
end

function Replay:Seek(time: number)
	self.Time = math.clamp(time, 0, self.Duration)
	self.Hint = 0
end

function Replay:TogglePause()
	-- En mode photo, l'image reste figée.
	if self.Photo then
		return
	end
	self.Paused = not self.Paused
	if not self.Paused and self.Time >= self.Duration then
		self.Time = 0
	end
	self:_refreshButtons()
end

function Replay:CycleSpeed()
	self.SpeedIndex = self.SpeedIndex % #SPEEDS + 1
	self:_refreshButtons()
end

function Replay:CycleCamera()
	local index = table.find(CAMERA_ORDER, self.Mode) or 0
	self.Mode = CAMERA_ORDER[index % #CAMERA_ORDER + 1]
	self:_refreshButtons()
end

function Replay:SetCamera(mode: CameraMode)
	self.Mode = mode
	self:_refreshButtons()
end

function Replay:SetPhoto(enabled: boolean)
	self.Photo = enabled
	local focus = self.FocusEffect
	if focus then
		focus.Enabled = enabled
	end
	if enabled then
		self.Paused = true
		-- On part de la caméra actuelle : derrière la voiture, un peu au-dessus.
		-- Rotation de lacet θ : la caméra est en (sin θ, cos θ) autour de la
		-- voiture ; derrière elle, c'est à l'opposé de son regard.
		local model = self.Model
		if model then
			local look = model:GetPivot().LookVector
			self.Yaw = math.atan2(-look.X, -look.Z)
		end
		self.Pitch = -0.25
		self.Distance = 18
	else
		self:SetUiHidden(false)
	end
	-- Les boutons du mode photo remplacent les commandes de lecture.
	self.FilterButton.Visible = enabled
	self.HideButton.Visible = enabled
	self.PlayButton.Visible = not enabled
	for _, item in ipairs(self.SeekButtons) do
		item.Visible = not enabled
	end
	self.CameraButton.Visible = not enabled
	self.SpeedButton.Visible = not enabled
	self:_refreshButtons()
end

function Replay:CycleFilter()
	self.FilterIndex = self.FilterIndex % #FILTERS + 1
	self:_applyFilter()
	self:_refreshButtons()
end

function Replay:_applyFilter()
	local effect = self.ColorEffect
	if not effect then
		return
	end
	local filter = FILTERS[self.FilterIndex]
	effect.Saturation = filter.Saturation
	effect.Contrast = filter.Contrast
	effect.Brightness = filter.Brightness
	effect.TintColor = filter.Tint
end

-- Interface masquée (photo) : toute touche ou un clic la fait revenir.
function Replay:SetUiHidden(hidden: boolean)
	self.UiHidden = hidden
	self.Bar.Visible = not hidden
end

function Replay:_refreshButtons()
	self.PlayButton.Text = if self.Paused then "▶" else "❚❚"
	self.SpeedButton.Text = string.format("×%s", if SPEEDS[self.SpeedIndex] == 1 then "1" elseif SPEEDS[self.SpeedIndex] == 0.5 then "½" else "¼")
	self.CameraButton.Text = "CAMÉRA : " .. CAMERA_NAMES[self.Mode]
	self.PhotoButton.Text = if self.Photo then "LECTURE" else "PHOTO"
	if self.Photo then
		Theme.Primary(self.PhotoButton)
	else
		self.PhotoButton.BackgroundColor3 = Theme.PANEL_2
		self.PhotoButton.TextColor3 = Theme.TEXT
	end
	self.FilterButton.Text = "FILTRE : " .. string.upper(FILTERS[self.FilterIndex].Name)
	self.HintLabel.Text = if self.Photo
		then "Glisser : tourner autour · molette : distance · A/D, W/S, Q/E au clavier · F : filtre · U : masquer l'interface · capture : Impr. écran"
		else "Espace : pause · ←/→ : 5 s · ↑/↓ : vitesse · 1 à 4 : caméras · P : photo · Retour arrière : quitter"
end

--[[
	Touches du ralenti (Main.client.luau les lui passe tant qu'il est actif).
	Renvoie true si la touche a servi.
]]
function Replay:HandleKey(key: Enum.KeyCode): boolean
	if not self.Active then
		return false
	end
	if self.UiHidden then
		self:SetUiHidden(false)
		return true
	end
	if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
		if self.Photo then
			self:SetPhoto(false)
		else
			self:Stop()
		end
	elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
		self:TogglePause()
	elseif key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
		self:Seek(self.Time - SEEK_STEP)
	elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
		self:Seek(self.Time + SEEK_STEP)
	elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.DPadUp then
		self.SpeedIndex = math.max(1, self.SpeedIndex - 1)
		self:_refreshButtons()
	elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.DPadDown then
		self.SpeedIndex = math.min(#SPEEDS, self.SpeedIndex + 1)
		self:_refreshButtons()
	elseif key == Enum.KeyCode.One then
		self:SetCamera("TV")
	elseif key == Enum.KeyCode.Two then
		self:SetCamera("Chase")
	elseif key == Enum.KeyCode.Three then
		self:SetCamera("Heli")
	elseif key == Enum.KeyCode.Four then
		self:SetCamera("Onboard")
	elseif key == Enum.KeyCode.ButtonY then
		self:CycleCamera()
	elseif key == Enum.KeyCode.P or key == Enum.KeyCode.ButtonX then
		self:SetPhoto(not self.Photo)
	elseif key == Enum.KeyCode.F and self.Photo then
		self:CycleFilter()
	elseif key == Enum.KeyCode.U and self.Photo then
		self:SetUiHidden(true)
	end
	return true
end

-- Avance la lecture et pose la voiture (juste avant la caméra, à chaque image).
function Replay:_advance(dt: number)
	local data = self.Data
	local model = self.Model
	if not self.Active or not data or not model then
		return
	end
	local viewport: Vector2 = self.Camera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.55, 1.2)

	if not self.Paused then
		self.Time += dt * SPEEDS[self.SpeedIndex]
		if self.Time >= self.Duration then
			self.Time = self.Duration
			self.Paused = true
			self:_refreshButtons()
		end
	end
	model:PivotTo(Ghost.PoseAt(data, self.Time))
	self.Fill.Size = UDim2.fromScale(if self.Duration > 0 then self.Time / self.Duration else 0, 1)
	self.TimeLabel.Text = formatTime(self.Time) .. " / " .. formatTime(self.Duration)

	-- Mode photo au clavier.
	if self.Photo then
		local turn = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
		local zoom = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
		local lift = (if UserInputService:IsKeyDown(Enum.KeyCode.E) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.Q) then 1 else 0)
		self.Yaw += turn * dt * 1.2
		self.Distance = math.clamp(self.Distance + zoom * dt * 25, 6, 80)
		self.Pitch = math.clamp(self.Pitch - lift * dt * 0.8, -1.3, 0.15)
	end

	-- Streaming : le décor autour de la voiture rejouée.
	local now = os.clock()
	if workspace.StreamingEnabled and now - self.LastStreamAt > STREAM_INTERVAL then
		self.LastStreamAt = now
		local position = model:GetPivot().Position
		task.spawn(function()
			pcall(function()
				Players.LocalPlayer:RequestStreamAroundAsync(position, 3)
			end)
		end)
	end
end

-- Caméra du ralenti. Renvoie false si le ralenti n'est pas actif.
function Replay:UpdateCamera(dt: number): boolean
	if not self.Active or not self.Model then
		return false
	end
	self:_advance(dt)
	local model = self.Model :: Model
	local camera = self.Camera
	camera.CameraType = Enum.CameraType.Scriptable
	local pose = model:GetPivot()
	local target = pose.Position + Vector3.new(0, 1.5, 0)

	if self.Photo then
		local orbit = CFrame.new(target) * CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, 0)
		local eye = orbit * CFrame.new(0, 0, self.Distance)
		camera.CFrame = CFrame.lookAt(eye.Position, target)
		camera.FieldOfView = 50
		local focus = self.FocusEffect
		if focus then
			focus.FocusDistance = self.Distance
		end
		return true
	end

	local fov = 60
	local eye: Vector3
	local look = target
	if self.Mode == "TV" then
		-- La caméra que la voiture approche (ou vient juste de passer).
		-- (Pas d'expression « if » ici : elle ne garderait que la première valeur.)
		local sample, progress
		if self.Hint > 0 then
			sample, progress = StageTrack.LocateNear(pose.Position, self.Hint, 30)
		else
			sample, progress = StageTrack.Locate(pose.Position)
		end
		self.Hint = sample.Index
		local chosen = self.TvCameras[#self.TvCameras]
		for _, tv in ipairs(self.TvCameras) do
			if tv.Distance >= progress - TV_SWITCH_BEHIND then
				chosen = tv
				break
			end
		end
		eye = chosen.Position
		local distance = (target - eye).Magnitude
		-- Zoom : la voiture garde à peu près la même taille à l'écran.
		fov = math.clamp(math.deg(2 * math.atan(16 / math.max(distance, 1))), 10, 70)
	elseif self.Mode == "Chase" then
		eye = (pose * CFrame.new(0, 5.5, 15)).Position
		look = (pose * CFrame.new(0, 2, -8)).Position
		fov = 70
	elseif self.Mode == "Heli" then
		local angle = self.Time * 0.25
		eye = target + Vector3.new(math.cos(angle) * 55, 38, math.sin(angle) * 55)
		fov = 45
	else
		eye = (pose * CFrame.new(0, 2.8, -2.5)).Position
		look = (pose * CFrame.new(0, 2.4, -40)).Position
		fov = 75
	end
	-- Le zoom glisse (pas de saut de focale à chaque changement de caméra TV).
	self.SmoothFov += (fov - self.SmoothFov) * math.min(1, dt * 6)
	camera.CFrame = CFrame.lookAt(eye, look)
	camera.FieldOfView = self.SmoothFov
	return true
end

return Replay
