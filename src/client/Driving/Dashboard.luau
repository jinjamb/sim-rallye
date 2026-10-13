--!strict
--[[
	Dashboard.luau
	Tableau de bord à l'écran, construit entièrement par code (rien à placer dans
	Studio). Visible uniquement pendant la conduite. Style « rallye illustré » :

		- COMPTE-TOURS ROND, en bas à droite, sur une plaque d'encre penchée :
		  graduations blanches (milliers de tours), zone rouge violette à partir
		  du point de montée, aiguille vert acide. La zone rouge clignote au point
		  de montée (shift light), l'aiguille vire au rouge au rupteur.
		- Rapport engagé en gros à droite du moyeu, mode de boîte dessous ;
		  vitesse en km/h en gros sous le moyeu.
		- Les 4 roues vues de dessus, dans le coin de la plaque, colorées selon
		  l'état du pneu :
			vert   adhère (fonce vers le jaune en approchant de la limite)
			jaune  à la limite, sous le pic d'adhérence
			rouge  patine (au-delà du pic, glissement longitudinal positif)
			bleu   bloque (au-delà du pic, glissement longitudinal négatif)
			orange glisse de côté (au-delà du pic, glissement latéral dominant)
			gris   en l'air
		- Témoin au-dessus de la plaque, seulement quand il y a lieu : rupteur,
		  embrayage qui patine, frein à main, passage en cours.
		- CADRE de l'écran : coins de viseur et trame de points dans les quatre
		  coins (une texture du Creator Store), comme une caméra embarquée.
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

export type Dashboard = typeof(setmetatable({}, Dashboard)) & {
	Car: CarClass.Car,
	Gui: ScreenGui,
	Scale: UIScale,
	Needle: Frame,
	NeedleBar: Frame,
	RedSegments: { Frame },
	GearLabel: TextLabel,
	ModeLabel: TextLabel,
	SpeedLabel: TextLabel,
	UnitLabel: TextLabel, -- KM/H ou MPH (Units.SpeedUnit)
	WarningLabel: TextLabel,
	Tires: { [string]: Frame },
	DetailPanel: Frame,
	DetailLabel: TextLabel,
	DetailAccumulator: number,
	NeedleAngle: number,
	Root: Frame,
	Cluster: Frame,
}

local WHEEL_ORDER = { "FL", "FR", "RL", "RR" }
local WHEEL_NAMES = { FL = "AVG", FR = "AVD", RL = "ARG", RR = "ARD" }

local CLUSTER_WIDTH = 300
local CLUSTER_HEIGHT = 250
local DETAIL_WIDTH = 380
local DETAIL_HEIGHT = 220
local PANEL_GAP = 8
local SCREEN_MARGIN = 24
local DETAIL_REFRESH = 0.1 -- le texte détaillé n'a pas besoin de 60 Hz
local BLINK_FREQUENCY = 6 -- Hz

-- Le cadran : centre et rayon dans la plaque, balayage de l'aiguille (degrés,
-- 0 = midi, sens horaire) de 0 tr/min à la zone rouge maximale.
local DIAL_CENTER = Vector2.new(158, 124)
local DIAL_RADIUS = 104
local DIAL_START = -135
local DIAL_SWEEP = 245
local NEEDLE_SMOOTHING = 22 -- l'aiguille suit le régime sans trembler

-- Cadre de l'écran : trame de points (coin dense en bas à gauche de l'image).
local HALFTONE_IMAGE = "rbxassetid://89854195038597"
local HALFTONE_TRANSPARENCY = 0.82
local BRACKET_LENGTH = 64
local BRACKET_INSET = 22

local COLOR_TEXT = Theme.TEXT
local COLOR_TEXT_DIM = Theme.DIM
local COLOR_GREEN = Theme.GREEN
local COLOR_YELLOW = Theme.YELLOW
local COLOR_RED = Theme.RED
local COLOR_BLUE = Theme.BLUE
local COLOR_ORANGE = Theme.ORANGE
local COLOR_GREY = Color3.fromRGB(78, 72, 120)
local COLOR_NEEDLE = Color3.fromRGB(176, 236, 60) -- vert acide
local COLOR_REDLINE = Color3.fromRGB(110, 70, 255) -- zone rouge violette

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function makeLabel(parent: Instance, position: UDim2, size: UDim2, text: string, textSize: number, face: Font, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextSize = textSize
	label.FontFace = face
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = alignment
	label.Parent = parent
	return label
end

-- Un repère tourné autour du centre du cadran : une frame carrée de la taille
-- du cadran, pivotée ; son contenu (posé en haut) tourne avec elle.
local function spoke(parent: Instance, angle: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(DIAL_CENTER.X, DIAL_CENTER.Y)
	holder.Size = UDim2.fromOffset(DIAL_RADIUS * 2, DIAL_RADIUS * 2)
	holder.Rotation = angle
	holder.Parent = parent
	return holder
end

local function angleOf(rpm: number, maxRpm: number): number
	return DIAL_START + math.clamp(rpm / maxRpm, 0, 1.04) * DIAL_SWEEP
end

-- Coins de viseur et trame de points : le cadre « caméra embarquée ».
local function buildFrameOverlay(gui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = "ScreenFrame"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 0
	overlay.Parent = gui

	-- Trame : la même image tournée pour chaque coin (dense dans le coin).
	local corners = {
		{ Anchor = Vector2.new(0, 1), Rotation = 0 },
		{ Anchor = Vector2.new(0, 0), Rotation = 90 },
		{ Anchor = Vector2.new(1, 0), Rotation = 180 },
		{ Anchor = Vector2.new(1, 1), Rotation = 270 },
	}
	for _, c in ipairs(corners) do
		local dots = Instance.new("ImageLabel")
		dots.Name = "Halftone"
		dots.BackgroundTransparency = 1
		dots.Image = HALFTONE_IMAGE
		dots.ImageColor3 = Theme.INK
		dots.ImageTransparency = HALFTONE_TRANSPARENCY
		dots.AnchorPoint = c.Anchor
		dots.Position = UDim2.fromScale(c.Anchor.X, c.Anchor.Y)
		dots.Size = UDim2.fromScale(0.36, 0.36)
		dots.SizeConstraint = Enum.SizeConstraint.RelativeYY
		dots.Rotation = c.Rotation
		dots.ZIndex = 0
		dots.Parent = overlay
	end

	-- Coins de viseur : deux traits fins par coin.
	for _, sx in ipairs({ 0, 1 }) do
		for _, sy in ipairs({ 0, 1 }) do
			local inset = Vector2.new(if sx == 0 then BRACKET_INSET else -BRACKET_INSET, if sy == 0 then BRACKET_INSET else -BRACKET_INSET)
			for _, horizontal in ipairs({ true, false }) do
				local bar = Instance.new("Frame")
				bar.Name = "Bracket"
				bar.BorderSizePixel = 0
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				bar.BackgroundTransparency = 0.45
				bar.AnchorPoint = Vector2.new(sx, sy)
				bar.Position = UDim2.new(sx, inset.X, sy, inset.Y)
				bar.Size = if horizontal then UDim2.fromOffset(BRACKET_LENGTH, 3) else UDim2.fromOffset(3, BRACKET_LENGTH)
				bar.ZIndex = 0
				bar.Parent = overlay
			end
		end
	end
end

function Dashboard.new(car: CarClass.Car, playerGui: Instance): Dashboard
	local self = (setmetatable({}, Dashboard) :: any) :: Dashboard
	self.Car = car
	self.DetailAccumulator = 0
	self.NeedleAngle = DIAL_START

	local gui = Instance.new("ScreenGui")
	gui.Name = "RallyDashboard"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	self.Gui = gui

	buildFrameOverlay(gui)

	-- Conteneur ancré en bas à droite : le UIScale grossit/réduit tout autour de ce
	-- coin, les deux panneaux restent collés l'un à l'autre et au bord de l'écran.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN)
	root.Size = UDim2.fromOffset(DETAIL_WIDTH, CLUSTER_HEIGHT + PANEL_GAP + DETAIL_HEIGHT)
	root.BackgroundTransparency = 1
	root.ZIndex = 2
	root.Parent = gui
	self.Root = root

	-- Mise à l'échelle : conçu pour 1080p, réduit sur les petits écrans.
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	local cluster = Instance.new("Frame")
	cluster.Name = "Cluster"
	cluster.AnchorPoint = Vector2.new(1, 1)
	cluster.Position = UDim2.fromScale(1, 1)
	cluster.Size = UDim2.fromOffset(CLUSTER_WIDTH, CLUSTER_HEIGHT)
	cluster.BackgroundTransparency = 1
	cluster.Parent = root
	self.Cluster = cluster

	-- Plaque d'encre, légèrement penchée, avec son ombre sakura décalée.
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromOffset(CLUSTER_WIDTH / 2, CLUSTER_HEIGHT / 2)
	plate.Size = UDim2.fromOffset(CLUSTER_WIDTH - 6, CLUSTER_HEIGHT - 12)
	plate.Rotation = -4
	plate.BackgroundColor3 = Theme.INK
	plate.BackgroundTransparency = 0 -- opaque : la trame de l'écran ne transparaît pas
	plate.BorderSizePixel = 0
	Theme.Corner(plate)
	Theme.CelShadow(plate, Theme.ACCENT, 6)
	plate.Parent = cluster

	-- Graduations : un trait par millier de tours, un petit au demi-millier.
	local powertrain = car.Powertrain
	local maxRpm = powertrain.MaxRPM
	for rpm = 0, maxRpm, 500 do
		local major = rpm % 1000 == 0
		local holder = spoke(cluster, angleOf(rpm, maxRpm))
		local tick = Instance.new("Frame")
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = COLOR_TEXT
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.Position = UDim2.new(0.5, 0, 0, 2)
		tick.Size = if major then UDim2.fromOffset(4, 17) else UDim2.fromOffset(2, 9)
		tick.Parent = holder
		if major then
			local a = math.rad(angleOf(rpm, maxRpm))
			local r = DIAL_RADIUS - 27
			local number = makeLabel(cluster, UDim2.fromOffset(DIAL_CENTER.X + math.sin(a) * r, DIAL_CENTER.Y - math.cos(a) * r), UDim2.fromOffset(24, 20), tostring(rpm // 1000), 17, Theme.HEADLINE, Enum.TextXAlignment.Center)
			number.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	end

	-- Zone rouge : du point de montée au régime maximal.
	self.RedSegments = {}
	local upshift = powertrain.Gearbox.UpshiftRPM
	for rpm = upshift, maxRpm, 125 do
		local holder = spoke(cluster, angleOf(rpm, maxRpm))
		local segment = Instance.new("Frame")
		segment.BorderSizePixel = 0
		segment.BackgroundColor3 = COLOR_REDLINE
		segment.AnchorPoint = Vector2.new(0.5, 0)
		-- Au bord extérieur, sous les chiffres : ils restent lisibles.
		segment.Position = UDim2.new(0.5, 0, 0, -2)
		segment.Size = UDim2.fromOffset(8, 11)
		segment.Parent = holder
		table.insert(self.RedSegments, segment)
	end

	-- Rapport en gros à droite du moyeu, mode de boîte dessous.
	self.GearLabel = makeLabel(cluster, UDim2.fromOffset(DIAL_CENTER.X + 12, DIAL_CENTER.Y - 42), UDim2.fromOffset(48, 52), "1", 52, Theme.HEADLINE, Enum.TextXAlignment.Center)
	Theme.TextInk(self.GearLabel, 3)
	self.ModeLabel = makeLabel(cluster, UDim2.fromOffset(DIAL_CENTER.X + 6, DIAL_CENTER.Y + 10), UDim2.fromOffset(60, 14), "AUTO", 12, Theme.BODY_BOLD, Enum.TextXAlignment.Center)
	self.ModeLabel.TextColor3 = COLOR_TEXT_DIM

	-- Vitesse sous le moyeu, dans l'ouverture du cadran.
	self.SpeedLabel = makeLabel(cluster, UDim2.fromOffset(DIAL_CENTER.X - 38, DIAL_CENTER.Y + 40), UDim2.fromOffset(96, 46), "0", 46, Theme.DIGITS, Enum.TextXAlignment.Center)
	Theme.TextInk(self.SpeedLabel, 2)
	local unit = makeLabel(cluster, UDim2.fromOffset(DIAL_CENTER.X - 38, DIAL_CENTER.Y + 84), UDim2.fromOffset(96, 14), "KM/H", 13, Theme.HEADLINE, Enum.TextXAlignment.Center)
	unit.TextColor3 = COLOR_TEXT_DIM
	self.UnitLabel = unit

	-- Témoin : étiquette penchée au-dessus de la plaque, seulement quand il y a lieu.
	self.WarningLabel = makeLabel(cluster, UDim2.fromOffset(CLUSTER_WIDTH - 20, -14), UDim2.fromOffset(0, 22), "", 14, Theme.HEADLINE, Enum.TextXAlignment.Center)
	self.WarningLabel.AnchorPoint = Vector2.new(1, 0)
	self.WarningLabel.AutomaticSize = Enum.AutomaticSize.X
	self.WarningLabel.TextColor3 = Theme.INK
	local warningPadding = Instance.new("UIPadding")
	warningPadding.PaddingLeft = UDim.new(0, 8)
	warningPadding.PaddingRight = UDim.new(0, 8)
	warningPadding.Parent = self.WarningLabel
	Theme.Slant(self.WarningLabel)
	self.WarningLabel.Visible = false

	-- Aiguille, puis le moyeu par-dessus.
	local needle = spoke(cluster, DIAL_START)
	needle.Name = "Needle"
	needle.ZIndex = 3
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = COLOR_NEEDLE
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 0.5, 8)
	bar.Size = UDim2.fromOffset(5, DIAL_RADIUS - 6)
	bar.ZIndex = 3
	Theme.Ink(bar, Theme.INK, 1.5)
	bar.Parent = needle
	self.Needle = needle
	self.NeedleBar = bar
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromOffset(DIAL_CENTER.X, DIAL_CENTER.Y)
	hub.Size = UDim2.fromOffset(18, 18)
	hub.BackgroundColor3 = Theme.INK
	hub.ZIndex = 4
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = hub
	local hubRing = Instance.new("UIStroke")
	hubRing.Color = COLOR_NEEDLE
	hubRing.Thickness = 2
	hubRing.LineJoinMode = Enum.LineJoinMode.Round
	hubRing.Parent = hub
	hub.Parent = cluster

	-- Les 4 roues vues de dessus (avant en haut), dans le coin bas-gauche.
	local wheels = Instance.new("Frame")
	wheels.Name = "Wheels"
	wheels.BackgroundTransparency = 1
	wheels.Position = UDim2.fromOffset(22, CLUSTER_HEIGHT - 66)
	wheels.Size = UDim2.fromOffset(40, 50)
	wheels.Parent = cluster
	local body = Instance.new("Frame")
	body.BackgroundColor3 = COLOR_GREY
	body.BackgroundTransparency = 0.4
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(11, 2)
	body.Size = UDim2.fromOffset(18, 46)
	Theme.Corner(body)
	body.Parent = wheels
	local tirePositions = {
		FL = UDim2.fromOffset(1, 3),
		FR = UDim2.fromOffset(30, 3),
		RL = UDim2.fromOffset(1, 30),
		RR = UDim2.fromOffset(30, 30),
	}
	self.Tires = {}
	for _, suffix in ipairs(WHEEL_ORDER) do
		local tire = Instance.new("Frame")
		tire.Name = suffix
		tire.BorderSizePixel = 0
		tire.Position = tirePositions[suffix]
		tire.Size = UDim2.fromOffset(9, 17)
		Theme.Corner(tire)
		tire.Parent = wheels
		self.Tires[suffix] = tire
	end

	-- Télémétrie détaillée (F2), au-dessus du compte-tours.
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(1, 1)
	detail.Size = UDim2.fromOffset(DETAIL_WIDTH, DETAIL_HEIGHT)
	detail.Position = UDim2.new(1, 0, 1, -(CLUSTER_HEIGHT + PANEL_GAP))
	Theme.Card(detail, 0.15)
	detail.Visible = false
	detail.Parent = root
	self.DetailPanel = detail
	local detailLabel = makeLabel(detail, UDim2.fromOffset(12, 10), UDim2.new(1, -24, 1, -20), "", 12, Theme.Face(Enum.Font.Code), Enum.TextXAlignment.Left)
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
	TouchControls.luau), le compte-tours monte en haut à droite. La télémétrie
	détaillée passe alors SOUS lui.
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
			return string.format("%.0f %s", Units.Speed(w.AngularVelocity * w.Radius), Units.SpeedLabel())
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

	-- Aiguille : lissée, pour ne pas trembler au rupteur.
	local rpm = powertrain.EngineRPM
	local target = angleOf(rpm, powertrain.MaxRPM)
	self.NeedleAngle += (target - self.NeedleAngle) * math.min(1, dt * NEEDLE_SMOOTHING)
	self.Needle.Rotation = self.NeedleAngle

	-- Shift light : la zone rouge clignote au point de montée ; l'aiguille vire
	-- au rouge au rupteur.
	local blinkOn = (os.clock() * BLINK_FREQUENCY) % 1 < 0.5
	local shiftNow = rpm >= gearbox.UpshiftRPM and gearbox.Gear >= 1 and gearbox.Gear < gearbox:GetTopGear()
	for _, segment in ipairs(self.RedSegments) do
		if powertrain.FuelCut then
			segment.BackgroundColor3 = COLOR_RED
			segment.BackgroundTransparency = if blinkOn then 0 else 0.6
		elseif shiftNow then
			segment.BackgroundColor3 = COLOR_BLUE
			segment.BackgroundTransparency = if blinkOn then 0 else 0.6
		else
			segment.BackgroundColor3 = COLOR_REDLINE
			segment.BackgroundTransparency = 0
		end
	end
	self.NeedleBar.BackgroundColor3 = if powertrain.FuelCut then COLOR_RED else COLOR_NEEDLE

	self.GearLabel.Text = gearText(gearbox.Gear)
	self.GearLabel.TextColor3 = if gearbox:IsShifting() then COLOR_TEXT_DIM else COLOR_TEXT
	-- Descentes mémorisées en attente d'un régime sûr : "MANUEL ▼2".
	local pending = gearbox.PendingDownshifts
	self.ModeLabel.Text = if gearbox.Automatic
		then "AUTO"
		elseif pending > 0 then string.format("MANUEL ▼%d", pending)
		else "MANUEL"
	self.ModeLabel.TextColor3 = if pending > 0 then COLOR_YELLOW else COLOR_TEXT_DIM

	self.SpeedLabel.Text = string.format("%.0f", Units.Speed(car.Chassis.AssemblyLinearVelocity.Magnitude))
	self.UnitLabel.Text = string.upper(Units.SpeedLabel())

	for _, suffix in ipairs(WHEEL_ORDER) do
		self.Tires[suffix].BackgroundColor3 = tireColor(car.WheelsByName["Wheel" .. suffix])
	end

	-- Témoin : le plus important seulement (étiquette de sa couleur).
	local warning, tone = "", COLOR_TEXT
	if powertrain.FuelCut then
		warning, tone = "RUPTEUR", COLOR_RED
	elseif powertrain.ClutchSlipping then
		warning, tone = "EMBRAYAGE", COLOR_YELLOW
	elseif car.HandbrakePressure > 0 then
		warning, tone = "FREIN À MAIN", COLOR_ORANGE
	elseif gearbox:IsShifting() then
		warning, tone = "PASSAGE", COLOR_BLUE
	end
	self.WarningLabel.Text = warning
	self.WarningLabel.BackgroundColor3 = tone
	self.WarningLabel.BackgroundTransparency = 0
	self.WarningLabel.Visible = warning ~= ""

	if self.DetailPanel.Visible then
		self.DetailAccumulator += dt
		if self.DetailAccumulator >= DETAIL_REFRESH then
			self.DetailAccumulator = 0
			self:_updateDetail()
		end
	end
end

return Dashboard
