--!strict
--[[
	StageTimer.luau
	Chronométrage de la spéciale et remise en piste.

	Aucun capteur physique : la position de la voiture est projetée sur le tracé
	(StageTrack.Locate), ce qui donne son abscisse curviligne -- "où elle en
	est" le long de la spéciale. Tout en découle :
		- départ   : l'abscisse franchit la ligne de départ, voiture sur la route ;
		- inters   : l'abscisse franchit 33 % puis 66 % du parcours chronométré ;
		- arrivée  : l'abscisse franchit la ligne d'arrivée ;
		- raccourci: l'abscisse fait un bond impossible d'une frame à l'autre
		  (couper l'intérieur de l'épingle saute ~400 studs de tracé d'un coup)
		  -> temps annulé.

	Meilleur temps et meilleurs inters : gardés pour la session seulement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarClass = require(script.Parent.Parent.Physics.Car)

local StageTimer = {}
StageTimer.__index = StageTimer

type RunState = "Idle" | "Running" | "Finished" | "Invalid"

export type StageTimer = typeof(setmetatable({}, StageTimer)) & {
	Car: CarClass.Car,
	Gui: ScreenGui,
	Scale: UIScale,
	StatusLabel: TextLabel,
	TimeLabel: TextLabel,
	SplitLabels: { TextLabel },
	BestLabel: TextLabel,

	State: RunState,
	StartClock: number,
	FinalTime: number,
	LastProgress: number,
	Grace: boolean,
	SplitDistances: { number },
	SplitTimes: { number },
	BestTime: number?,
	BestSplits: { number },
	InvalidReason: string,
	-- Verdict du serveur sur le dernier passage (temps officiel), affiché à l'arrivée.
	OfficialText: string?,
	OfficialColor: Color3,

	-- Abonnés (fantôme) : départ, arrivée (temps local), passage annulé.
	OnRunStarted: (() -> ())?,
	OnRunFinished: ((number) -> ())?,
	OnRunCancelled: (() -> ())?,
}

-- Bond d'abscisse au-delà duquel on considère que le tracé a été coupé. À
-- 180 km/h la voiture parcourt 3 studs par frame : 60 laisse une marge énorme
-- pour un saut ou un à-coup de framerate, et reste très loin des ~400 studs
-- que fait gagner la coupe d'une épingle.
local MAX_PROGRESS_JUMP = 60
-- Le départ ne se déclenche que si la voiture franchit la ligne sur la route
-- (pas en passant à côté du portique).
local START_LATERAL_TOLERANCE = StageTrack.ROAD_WIDTH / 2 + 6
-- Remise en piste : un peu au-dessus de la chaussée, la suspension se pose.
local DROP_HEIGHT = 4
local RESTART_BEFORE_LINE = 10 -- studs avant la ligne : départ quasi arrêté

-- Gabarit identique au bloc principal du tableau de bord (Dashboard.luau).
local PANEL_WIDTH = 380
local PANEL_HEIGHT = 170
local SCREEN_MARGIN = 24

local COLOR_PANEL = Color3.fromRGB(14, 15, 18)
local COLOR_TEXT = Color3.fromRGB(235, 236, 240)
local COLOR_DIM = Color3.fromRGB(130, 134, 145)
local COLOR_FASTER = Color3.fromRGB(70, 200, 95)
local COLOR_SLOWER = Color3.fromRGB(235, 65, 55)
local COLOR_INVALID = Color3.fromRGB(235, 65, 55)

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%05.2f", minutes, seconds - minutes * 60)
end

local function makeLabel(parent: Instance, y: number, height: number, textSize: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.TextSize = textSize
	label.Font = font
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

function StageTimer.new(car: CarClass.Car, playerGui: Instance): StageTimer
	local self = (setmetatable({}, StageTimer) :: any) :: StageTimer
	self.Car = car
	self.State = "Idle"
	self.StartClock = 0
	self.FinalTime = 0
	self.LastProgress = -math.huge
	self.Grace = true
	self.SplitTimes = {}
	self.BestTime = nil
	self.BestSplits = {}
	self.InvalidReason = ""
	self.OfficialText = nil
	self.OfficialColor = COLOR_DIM
	self.OnRunStarted = nil
	self.OnRunFinished = nil
	self.OnRunCancelled = nil

	local start = StageTrack.START_DISTANCE
	local timedLength = StageTrack.GetFinishDistance() - start
	self.SplitDistances = {}
	for i, fraction in ipairs(StageTrack.SPLITS) do
		self.SplitDistances[i] = start + timedLength * fraction
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "StageTimer"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui

	-- En bas à gauche, même gabarit et même style que le tableau de bord (en
	-- bas à droite) : les deux encadrent l'écran sans masquer la route.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, SCREEN_MARGIN, 1, -SCREEN_MARGIN)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.9
	stroke.Parent = panel
	panel.Parent = gui

	-- Même mise à l'échelle que le tableau de bord, autour du coin bas-gauche.
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Scale = scale

	-- Chiffres en police à chasse fixe : sinon le chrono "tremble" à chaque
	-- centième, les chiffres n'ayant pas tous la même largeur.
	self.StatusLabel = makeLabel(panel, 12, 16, 13, Enum.Font.GothamBold)
	self.StatusLabel.TextColor3 = COLOR_DIM
	self.TimeLabel = makeLabel(panel, 30, 58, 56, Enum.Font.RobotoMono)
	self.SplitLabels = {}
	for i = 1, #StageTrack.SPLITS do
		self.SplitLabels[i] = makeLabel(panel, 94 + (i - 1) * 20, 18, 16, Enum.Font.RobotoMono)
	end
	self.BestLabel = makeLabel(panel, 94 + #StageTrack.SPLITS * 20 + 4, 16, 14, Enum.Font.RobotoMono)
	self.BestLabel.TextColor3 = COLOR_DIM

	gui.Parent = playerGui
	self:_refresh(0)
	return self
end

function StageTimer:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

local function dropFrame(sample: StageTrack.Sample): CFrame
	local position = sample.Position + Vector3.new(0, DROP_HEIGHT, 0)
	return CFrame.lookAt(position, position + sample.Forward)
end

-- Retour au départ, chrono remis à zéro.
function StageTimer:Restart()
	local sample = StageTrack.SampleAt(StageTrack.START_DISTANCE - RESTART_BEFORE_LINE)
	self.Car:Teleport(dropFrame(sample))
	self.State = "Idle"
	self.SplitTimes = {}
	self.Grace = true
	self.OfficialText = nil
	if self.OnRunCancelled then
		self.OnRunCancelled()
	end
end

-- Meilleur temps sauvegardé (profil chargé par le serveur), en millisecondes.
function StageTimer:SetPersonalBest(ms: number?)
	self.BestTime = if ms then ms / 1000 else nil
end

--[[
	Verdict du serveur sur le passage qui vient de finir : c'est LUI qui fait foi
	(RecordService le chronomètre de son côté). Il peut différer du chrono local
	de quelques centièmes ; s'il est meilleur que le record, c'est lui qui le
	remplace.
]]
function StageTimer:SetOfficialResult(result: any)
	if type(result) ~= "table" then
		return
	end
	if result.Valid and type(result.Ms) == "number" then
		local text = "OFFICIEL " .. formatTime(result.Ms / 1000)
		if result.PersonalBest then
			text ..= " — RECORD PERSO !"
			self.BestTime = result.Ms / 1000
		end
		self.OfficialText = text
		self.OfficialColor = if result.PersonalBest then COLOR_FASTER else COLOR_DIM
	else
		self.OfficialText = "TEMPS REFUSÉ : " .. string.upper(tostring(result.Reason or "invalide"))
		self.OfficialColor = COLOR_INVALID
	end
end

--[[
	Remise sur la route à l'endroit le plus proche du tracé (sortie de route,
	voiture sur le toit). Le chrono continue : le temps perdu est la pénalité.
]]
function StageTimer:Recover()
	local sample = StageTrack.Locate(self.Car.Chassis.Position)
	self.Car:Teleport(dropFrame(sample))
	self.Grace = true
end

function StageTimer:_start(now: number)
	self.State = "Running"
	self.StartClock = now
	self.SplitTimes = {}
	self.OfficialText = nil
	if self.OnRunStarted then
		self.OnRunStarted()
	end
end

function StageTimer:_finish(now: number)
	self.State = "Finished"
	self.FinalTime = now - self.StartClock
	local best = self.BestTime
	if best == nil or self.FinalTime < best then
		self.BestTime = self.FinalTime
		self.BestSplits = table.clone(self.SplitTimes)
	end
	if self.OnRunFinished then
		self.OnRunFinished(self.FinalTime)
	end
end

function StageTimer:Update(_dt: number)
	local now = os.clock()
	local _, progress, lateral = StageTrack.Locate(self.Car.Chassis.Position)

	-- Juste après une téléportation, l'abscisse saute légitimement : on la
	-- reprend comme nouvelle référence sans rien conclure.
	if self.Grace then
		self.Grace = false
		self.LastProgress = progress
	end

	local crossedStart = self.LastProgress < StageTrack.START_DISTANCE and progress >= StageTrack.START_DISTANCE
	if self.State ~= "Running" then
		if crossedStart and math.abs(lateral) <= START_LATERAL_TOLERANCE then
			self:_start(now)
		end
	else
		if progress - self.LastProgress > MAX_PROGRESS_JUMP then
			self.State = "Invalid"
			self.FinalTime = now - self.StartClock
			self.InvalidReason = "raccourci"
			if self.OnRunCancelled then
				self.OnRunCancelled()
			end
		else
			local nextSplit = #self.SplitTimes + 1
			if nextSplit <= #self.SplitDistances and progress >= self.SplitDistances[nextSplit] then
				self.SplitTimes[nextSplit] = now - self.StartClock
			end
			if progress >= StageTrack.GetFinishDistance() then
				self:_finish(now)
			end
		end
	end

	self.LastProgress = progress
	self:_refresh(now)
end

function StageTimer:_refresh(now: number)
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)

	local state = self.State
	self.StatusLabel.TextColor3 = COLOR_DIM
	if state == "Running" then
		self.StatusLabel.Text = "EN COURSE"
		self.TimeLabel.Text = formatTime(now - self.StartClock)
		self.TimeLabel.TextColor3 = COLOR_TEXT
	elseif state == "Finished" then
		local isBest = self.BestTime == self.FinalTime
		local official = self.OfficialText
		if official then
			self.StatusLabel.Text = official
			self.StatusLabel.TextColor3 = self.OfficialColor
		else
			self.StatusLabel.Text = "ARRIVÉE — VALIDATION…"
			self.StatusLabel.TextColor3 = COLOR_DIM
		end
		self.TimeLabel.Text = formatTime(self.FinalTime)
		self.TimeLabel.TextColor3 = if isBest then COLOR_FASTER else COLOR_TEXT
	elseif state == "Invalid" then
		self.StatusLabel.Text = "TEMPS ANNULÉ : " .. string.upper(self.InvalidReason)
		self.TimeLabel.Text = formatTime(self.FinalTime)
		self.TimeLabel.TextColor3 = COLOR_INVALID
	else
		self.StatusLabel.Text = "SPÉCIALE — FRANCHIS LE DÉPART"
		self.TimeLabel.Text = formatTime(0)
		self.TimeLabel.TextColor3 = COLOR_DIM
	end

	for i, label in ipairs(self.SplitLabels) do
		local splitTime = self.SplitTimes[i]
		if splitTime then
			local best = self.BestSplits[i]
			if best and not (state == "Finished" and self.BestTime == self.FinalTime) then
				local delta = splitTime - best
				label.Text = string.format("INTER %d   %s   %+.2f", i, formatTime(splitTime), delta)
				label.TextColor3 = if delta <= 0 then COLOR_FASTER else COLOR_SLOWER
			else
				label.Text = string.format("INTER %d   %s", i, formatTime(splitTime))
				label.TextColor3 = COLOR_TEXT
			end
		else
			label.Text = string.format("INTER %d   --:--.--", i)
			label.TextColor3 = COLOR_DIM
		end
	end

	local best = self.BestTime
	self.BestLabel.Text = if best then "Meilleur  " .. formatTime(best) else "Pas encore de temps"
end

return StageTimer
