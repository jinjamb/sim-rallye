--!strict
--[[
	Dashboard.luau
	Tableau de bord à l'écran, construit entièrement par code (rien à placer dans
	Studio). Visible uniquement pendant la conduite.

		- Rampe de LED du compte-tours : vert jusqu'au pic de puissance, jaune
		  jusqu'au point de montée, rouge au-delà. Toute la rampe clignote au point
		  de montée (shift light) et au rupteur.
		- Rapport engagé + mode de boîte, vitesse en km/h, régime.
		- Les 4 roues vues de dessus, colorées selon l'état du pneu :
			vert   adhère (fonce vers le jaune en approchant de la limite)
			jaune  à la limite, sous le pic d'adhérence
			rouge  patine (au-delà du pic, glissement longitudinal positif)
			bleu   bloque (au-delà du pic, glissement longitudinal négatif)
			orange glisse de côté (au-delà du pic, glissement latéral dominant)
			gris   en l'air
		- Témoins : embrayage qui patine, passage en cours, rupteur, frein à main.
		- F2 : panneau de télémétrie détaillée par roue.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Util.Units)
local CarClass = require(script.Parent.Parent.Physics.Car)
local WheelClass = require(script.Parent.Parent.Physics.Wheel)
local InputManager = require(script.Parent.Parent.Core.InputManager)
local Theme = require(script.Parent.Parent.UI.Theme)

local Dashboard = {}
Dashboard.__index = Dashboard

type Chip = { frame: Frame, label: TextLabel, color: Color3 }

export type Dashboard = typeof(setmetatable({}, Dashboard)) & {
	Car: CarClass.Car,
	Gui: ScreenGui,
	Scale: UIScale,
	RevSegments: { Frame },
	GearLabel: TextLabel,
	ModeLabel: TextLabel,
	SpeedLabel: TextLabel,
	RpmLabel: TextLabel,
	Tires: { [string]: Frame },
	Chips: { [string]: Chip },
	DetailPanel: Frame,
	DetailLabel: TextLabel,
	DetailAccumulator: number,
	Root: Frame,
	Cluster: Frame,
}

local WHEEL_ORDER = { "FL", "FR", "RL", "RR" }
local WHEEL_NAMES = { FL = "AVG", FR = "AVD", RL = "ARG", RR = "ARD" }

local CLUSTER_WIDTH = 380
local CLUSTER_HEIGHT = 170
local DETAIL_HEIGHT = 220
local PANEL_GAP = 8
local SCREEN_MARGIN = 24
local REV_SEGMENTS = 24
local POWER_PEAK_RPM = 5500 -- fin du vert : pic de puissance de la courbe (Powertrain.luau)
local DETAIL_REFRESH = 0.1 -- le texte détaillé n'a pas besoin de 60 Hz
local BLINK_FREQUENCY = 6 -- Hz

local COLOR_PANEL = Theme.PANEL
local COLOR_TEXT = Theme.TEXT
local COLOR_TEXT_DIM = Theme.DIM
local COLOR_GREEN = Theme.GREEN
local COLOR_YELLOW = Theme.ACCENT
local COLOR_RED = Theme.RED
local COLOR_BLUE = Theme.BLUE
local COLOR_ORANGE = Theme.ORANGE
local COLOR_GREY = Color3.fromRGB(70, 72, 80)

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makePanel(name: string, size: Vector2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = COLOR_PANEL
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	corner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.9
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function makeLabel(
	parent: Instance,
	position: UDim2,
	size: UDim2,
	text: string,
	textSize: number,
	font: Enum.Font,
	alignment: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextSize = textSize
	label.Font = font
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = alignment
	label.Parent = parent
	return label
end

function Dashboard.new(car: CarClass.Car, playerGui: Instance): Dashboard
	local self = (setmetatable({}, Dashboard) :: any) :: Dashboard
	self.Car = car
	self.DetailAccumulator = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "RallyDashboard"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	self.Gui = gui

	-- Conteneur ancré en bas à droite : le UIScale grossit/réduit tout autour de ce
	-- coin, les deux panneaux restent collés l'un à l'autre et au bord de l'écran.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN)
	root.Size = UDim2.fromOffset(CLUSTER_WIDTH, CLUSTER_HEIGHT + PANEL_GAP + DETAIL_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = gui

	-- Mise à l'échelle : conçu pour 1080p, réduit sur les petits écrans.
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	local cluster = makePanel("Cluster", Vector2.new(CLUSTER_WIDTH, CLUSTER_HEIGHT), root)
	cluster.Position = UDim2.fromScale(1, 1)
	self.Root = root
	self.Cluster = cluster

	-- Rampe de LED
	local revBar = Instance.new("Frame")
	revBar.Name = "RevBar"
	revBar.BackgroundTransparency = 1
	revBar.Position = UDim2.fromOffset(12, 12)
	revBar.Size = UDim2.new(1, -24, 0, 16)
	revBar.Parent = cluster

	self.RevSegments = {}
	for i = 1, REV_SEGMENTS do
		local segment = Instance.new("Frame")
		segment.BorderSizePixel = 0
		segment.Position = UDim2.new((i - 1) / REV_SEGMENTS, 0, 0, 0)
		segment.Size = UDim2.new(1 / REV_SEGMENTS, -3, 1, 0)
		corner(segment, 3)
		segment.Parent = revBar
		self.RevSegments[i] = segment
	end

	-- Rapport + mode
	self.GearLabel = makeLabel(cluster, UDim2.fromOffset(12, 34), UDim2.fromOffset(80, 80), "1", 84, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	self.ModeLabel = makeLabel(cluster, UDim2.fromOffset(12, 112), UDim2.fromOffset(80, 18), "AUTO", 13, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	self.ModeLabel.TextColor3 = COLOR_TEXT_DIM

	-- Vitesse + régime
	self.SpeedLabel = makeLabel(cluster, UDim2.fromOffset(96, 36), UDim2.fromOffset(170, 62), "0", 64, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	local unit = makeLabel(cluster, UDim2.fromOffset(96, 96), UDim2.fromOffset(170, 16), "km/h", 14, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
	unit.TextColor3 = COLOR_TEXT_DIM
	self.RpmLabel = makeLabel(cluster, UDim2.fromOffset(96, 113), UDim2.fromOffset(170, 18), "1000 tr/min", 14, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
	self.RpmLabel.TextColor3 = COLOR_TEXT_DIM

	-- Les 4 roues vues de dessus (avant en haut)
	local wheels = Instance.new("Frame")
	wheels.Name = "Wheels"
	wheels.BackgroundTransparency = 1
	wheels.Position = UDim2.fromOffset(288, 36)
	wheels.Size = UDim2.fromOffset(80, 94)
	wheels.Parent = cluster

	local body = Instance.new("Frame")
	body.BackgroundColor3 = COLOR_GREY
	body.BackgroundTransparency = 0.5
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(22, 6)
	body.Size = UDim2.fromOffset(36, 82)
	corner(body, 6)
	body.Parent = wheels

	local tirePositions = {
		FL = UDim2.fromOffset(4, 6),
		FR = UDim2.fromOffset(58, 6),
		RL = UDim2.fromOffset(4, 56),
		RR = UDim2.fromOffset(58, 56),
	}
	self.Tires = {}
	for _, suffix in ipairs(WHEEL_ORDER) do
		local tire = Instance.new("Frame")
		tire.Name = suffix
		tire.BorderSizePixel = 0
		tire.Position = tirePositions[suffix]
		tire.Size = UDim2.fromOffset(18, 32)
		corner(tire, 4)
		tire.Parent = wheels
		self.Tires[suffix] = tire
	end

	-- Témoins
	local chipDefs = {
		{ key = "clutch", text = "EMBRAYAGE", color = COLOR_YELLOW },
		{ key = "shift", text = "PASSAGE", color = COLOR_BLUE },
		{ key = "limiter", text = "RUPTEUR", color = COLOR_RED },
		{ key = "handbrake", text = "FREIN À MAIN", color = COLOR_ORANGE },
	}
	self.Chips = {}
	local chipWidth = (CLUSTER_WIDTH - 24 - 3 * 6) / #chipDefs
	for i, def in ipairs(chipDefs) do
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromOffset(12 + (i - 1) * (chipWidth + 6), 138)
		frame.Size = UDim2.fromOffset(chipWidth, 20)
		corner(frame, 4)
		frame.Parent = cluster
		local label = makeLabel(frame, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), def.text, 11, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		self.Chips[def.key] = { frame = frame, label = label, color = def.color }
	end

	-- Télémétrie détaillée (F2)
	local detail = makePanel("Detail", Vector2.new(CLUSTER_WIDTH, DETAIL_HEIGHT), root)
	detail.Position = UDim2.new(1, 0, 1, -(CLUSTER_HEIGHT + PANEL_GAP))
	detail.Visible = false
	self.DetailPanel = detail

	local detailLabel = makeLabel(detail, UDim2.fromOffset(12, 10), UDim2.new(1, -24, 1, -20), "", 12, Enum.Font.Code, Enum.TextXAlignment.Left)
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.DetailLabel = detailLabel

	gui.Parent = playerGui
	return self
end

function Dashboard:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function Dashboard:Destroy()
	self.Gui:Destroy()
end

--[[
	Disposition tactile : les pouces occupent les coins bas (volant, pédales,
	TouchControls.luau), le tableau de bord monte en haut à droite. La
	télémétrie détaillée passe alors SOUS le bloc principal.
]]
function Dashboard:SetTouchLayout(enabled: boolean)
	local root, cluster, detail = self.Root, self.Cluster, self.DetailPanel
	if enabled then
		root.AnchorPoint = Vector2.new(1, 0)
		root.Position = UDim2.new(1, -12, 0, 12)
		cluster.AnchorPoint = Vector2.new(1, 0)
		cluster.Position = UDim2.fromScale(1, 0)
		detail.AnchorPoint = Vector2.new(1, 0)
		detail.Position = UDim2.new(1, 0, 0, CLUSTER_HEIGHT + PANEL_GAP)
	else
		root.AnchorPoint = Vector2.new(1, 1)
		root.Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN)
		cluster.AnchorPoint = Vector2.new(1, 1)
		cluster.Position = UDim2.fromScale(1, 1)
		detail.AnchorPoint = Vector2.new(1, 1)
		detail.Position = UDim2.new(1, 0, 1, -(CLUSTER_HEIGHT + PANEL_GAP))
	end
end

function Dashboard:ToggleDetail(): boolean
	self.DetailPanel.Visible = not self.DetailPanel.Visible
	return self.DetailPanel.Visible
end

--------------------------------------------------------------------------------
-- Mise à jour
--------------------------------------------------------------------------------

local function tireColor(wheel: WheelClass.Wheel): Color3
	if not wheel.IsGrounded then
		return COLOR_GREY
	end
	local long, lat = wheel.LongSlipNorm, wheel.LatSlipNorm
	local combined = math.sqrt(long * long + lat * lat)
	if combined <= 1 then
		-- Sous le pic : du vert au jaune à mesure que le budget d'adhérence s'épuise.
		local t = math.clamp((wheel.FrictionUsage - 0.5) / 0.5, 0, 1)
		return COLOR_GREEN:Lerp(COLOR_YELLOW, t)
	end
	if math.abs(long) >= math.abs(lat) then
		return if long > 0 then COLOR_RED else COLOR_BLUE
	end
	return COLOR_ORANGE
end

local function setChip(chip: Chip, on: boolean)
	chip.frame.BackgroundColor3 = if on then chip.color else COLOR_GREY
	chip.frame.BackgroundTransparency = if on then 0 else 0.6
	chip.label.TextColor3 = if on then COLOR_PANEL else COLOR_TEXT_DIM
end

local function gearText(gear: number): string
	if gear == -1 then
		return "R"
	elseif gear == 0 then
		return "N"
	end
	return tostring(gear)
end

-- Aligne en colonnes. Compte en CARACTÈRES (utf8) : "Béton" fait 5 caractères
-- mais 6 octets, et couper au milieu d'un caractère accentué casserait le texte.
local function pad(text: string, width: number): string
	local length = utf8.len(text) or #text
	if length > width then
		local cut = utf8.offset(text, width + 1)
		return if cut then string.sub(text, 1, cut - 1) else text
	end
	return text .. string.rep(" ", width - length)
end

function Dashboard:_updateDetail()
	local car = self.Car
	local cornerWeight = car.Chassis.AssemblyMass * workspace.Gravity / 4
	local inputs = InputManager:GetInputs()

	local function row(label: string, cell: (WheelClass.Wheel) -> string): string
		local line = pad(label, 8)
		for _, suffix in ipairs(WHEEL_ORDER) do
			-- 8 + 4 x 10 caractères : tient dans les 356 px utiles en police Code 12.
			line ..= pad(cell(car.WheelsByName["Wheel" .. suffix]), 10)
		end
		return line
	end

	local lines = {
		row("", function(w)
			return WHEEL_NAMES[string.sub(w.Attachment.Name, 6)] or "?"
		end),
		row("surface", function(w)
			return if w.IsGrounded then w.Surface.Name else "en l'air"
		end),
		row("mu", function(w)
			return string.format("%.2f", w.Surface.Grip)
		end),
		row("charge", function(w)
			return string.format("%3.0f%%", w.NormalForce / cornerWeight * 100)
		end),
		row("roue", function(w)
			return string.format("%.0f km/h", Units.ToKmh(w.AngularVelocity * w.Radius))
		end),
		row("long", function(w)
			return string.format("%+.2f", w.LongSlipNorm)
		end),
		row("lat", function(w)
			return string.format("%+.2f", w.LatSlipNorm)
		end),
		row("cercle", function(w)
			return string.format("%3.0f%%", w.FrictionUsage * 100)
		end),
		"",
		string.format(
			"diff    AV %s  AR %s  centre %s",
			car.FrontDiff:GetStateLabel(),
			car.RearDiff:GetStateLabel(),
			car.CenterDiff:GetStateLabel()
		),
		string.format(
			"%-7s gaz %3.0f%% frein %3.0f%% volant %+.2f",
			InputManager:GetActiveSource(),
			inputs.throttle * 100,
			inputs.brake * 100,
			inputs.steer
		),
		string.format(
			"freins %3.0f%%   frein à main %3.0f%%",
			car.BrakePressure * 100,
			car.HandbrakePressure * 100
		),
		"long/lat : glissement / pic (>1 = au-delà)",
	}
	self.DetailLabel.Text = table.concat(lines, "\n")
end

function Dashboard:Update(dt: number)
	local car = self.Car
	local powertrain = car.Powertrain
	local gearbox = powertrain.Gearbox

	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)

	-- Rampe de LED
	local rpm = powertrain.EngineRPM
	local blinkOn = (os.clock() * BLINK_FREQUENCY) % 1 < 0.5
	local shiftNow = rpm >= gearbox.UpshiftRPM and gearbox.Gear >= 1 and gearbox.Gear < gearbox:GetTopGear()
	local flash = shiftNow or powertrain.FuelCut
	for i, segment in ipairs(self.RevSegments) do
		local segmentRpm = (i / REV_SEGMENTS) * powertrain.MaxRPM
		local lit = rpm >= segmentRpm - powertrain.MaxRPM / REV_SEGMENTS * 0.5
		local color = if segmentRpm <= POWER_PEAK_RPM
			then COLOR_GREEN
			elseif segmentRpm <= gearbox.UpshiftRPM then COLOR_YELLOW
			else COLOR_RED
		if flash then
			-- Toute la rampe clignote : il faut passer (ou on tape le rupteur).
			segment.BackgroundColor3 = if powertrain.FuelCut then COLOR_RED else COLOR_BLUE
			segment.BackgroundTransparency = if blinkOn then 0 else 0.85
		else
			segment.BackgroundColor3 = color
			segment.BackgroundTransparency = if lit then 0 else 0.85
		end
	end

	self.GearLabel.Text = gearText(gearbox.Gear)
	self.GearLabel.TextColor3 = if gearbox:IsShifting() then COLOR_TEXT_DIM else COLOR_TEXT
	-- Descentes mémorisées en attente d'un régime sûr : "MANUEL ▼2".
	local pending = gearbox.PendingDownshifts
	self.ModeLabel.Text = if gearbox.Automatic
		then "AUTO"
		elseif pending > 0 then string.format("MANUEL ▼%d", pending)
		else "MANUEL"
	self.ModeLabel.TextColor3 = if pending > 0 then COLOR_YELLOW else COLOR_TEXT_DIM

	self.SpeedLabel.Text = string.format("%.0f", Units.ToKmh(car.Chassis.AssemblyLinearVelocity.Magnitude))
	self.RpmLabel.Text = string.format("%.0f tr/min", math.floor(rpm / 50 + 0.5) * 50)

	for _, suffix in ipairs(WHEEL_ORDER) do
		self.Tires[suffix].BackgroundColor3 = tireColor(car.WheelsByName["Wheel" .. suffix])
	end

	setChip(self.Chips.clutch, powertrain.ClutchSlipping)
	setChip(self.Chips.shift, gearbox:IsShifting())
	setChip(self.Chips.limiter, powertrain.FuelCut)
	setChip(self.Chips.handbrake, car.HandbrakePressure > 0)

	if self.DetailPanel.Visible then
		self.DetailAccumulator += dt
		if self.DetailAccumulator >= DETAIL_REFRESH then
			self.DetailAccumulator = 0
			self:_updateDetail()
		end
	end
end

return Dashboard
