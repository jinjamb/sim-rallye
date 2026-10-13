--!strict
--[[
	StageTimer.luau
	Chronométrage de la spéciale et remise en piste.

	Aucun capteur physique : la position de la voiture est projetée sur le tracé
	(track.Locate, la spéciale courue : Stages.luau), ce qui donne son abscisse curviligne -- "où elle en
	est" le long de la spéciale. Tout en découle :
		- départ   : l'abscisse franchit la ligne de départ, voiture sur la route ;
		- inters   : l'abscisse franchit 33 % puis 66 % du parcours chronométré ;
		- arrivée  : l'abscisse franchit la ligne d'arrivée ;
		- raccourci: l'abscisse fait un bond impossible d'une frame à l'autre
		  (couper l'intérieur de l'épingle saute ~400 studs de tracé d'un coup)
		  -> temps annulé.

	RÉFÉRENCE : le fantôme rejoué (le sien ou celui d'un adversaire, Ghost.luau).
	Il donne l'écart EN DIRECT (en vert : devant lui ; en rouge : derrière) et
	l'écart à chaque inter et à l'arrivée. Sans fantôme (masqué, ou pas encore
	de temps), les inters se comparent aux meilleurs inters de la session.

	MÉDAILLES (Medals.luau) : la ligne du bas donne le meilleur temps officiel,
	sa médaille, et la prochaine à décrocher. Une médaille gagnée est annoncée
	en grand (Banner.luau) dès que le serveur valide le temps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local CarClass = require(script.Parent.Parent.Physics.Car)
local Ghost = require(script.Parent.Ghost)
local Banner = require(script.Parent.Parent.UI.Banner)
local Theme = require(script.Parent.Parent.UI.Theme)

local StageTimer = {}
StageTimer.__index = StageTimer

type RunState = "Idle" | "Running" | "Finished" | "Invalid"

export type StageTimer = typeof(setmetatable({}, StageTimer)) & {
	Car: CarClass.Car,
	Track: StageTrack.Track,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	StatusLabel: TextLabel,
	ProgressLabel: TextLabel,
	TimeLabel: TextLabel,
	SplitLabels: { TextLabel },
	BestLabel: TextLabel,
	DeltaLabel: TextLabel,
	VersusLabel: TextLabel,

	State: RunState,
	StartClock: number,
	FinalTime: number,
	LastProgress: number,
	Grace: boolean,
	SplitDistances: { number },
	SplitTimes: { number },
	BestTime: number?,
	BestSplits: { number },
	-- Écart au fantôme (s) à chaque inter, figé au passage ; puis à l'arrivée.
	SplitDeltas: { [number]: number },
	FinalDelta: number?,
	LiveDelta: number?,
	NextDeltaAt: number,
	-- Meilleur temps OFFICIEL (ms) : celui qui donne la médaille.
	OfficialBestMs: number?,
	-- Catégorie de la voiture (CarClasses.luau) : ses médailles.
	ClassId: string?,
	-- Défi de la semaine : nom de la contrainte (nil : spéciale habituelle), et
	-- meilleur temps de la semaine (pas de médailles ici).
	Weekly: string?,
	WeeklyBestMs: number?,
	Ghost: Ghost.Ghost?,
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
-- (pas en passant à côté du portique) : à moins de ça du bord de la route.
local START_LATERAL_MARGIN = 6

-- En haut à gauche, sans cadre, façon rallye illustré : la progression en très
-- gros, le temps dans un bandeau d'encre penché, le reste en petit dessous.
-- Les textes sont cernés d'encre pour rester lisibles sur le décor.
local PANEL_WIDTH = 470
local PANEL_HEIGHT = 270
local SCREEN_MARGIN = 28
local TOP_MARGIN = 62 -- sous la barre de Roblox

local COLOR_TEXT = Theme.TEXT
local COLOR_DIM = Theme.DIM
local COLOR_FASTER = Theme.GREEN
local COLOR_SLOWER = Theme.RED
local COLOR_INVALID = Theme.RED
local DELTA_INTERVAL = 0.1 -- l'écart en direct change 10 fois par seconde : lisible

local function makeLabel(parent: Instance, y: number, height: number, textSize: number, face: Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(4, y)
	label.Size = UDim2.new(1, -8, 0, height)
	label.TextSize = textSize
	label.FontFace = face
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

-- Une étiquette pleine à largeur automatique (statut, écart).
local function pill(label: TextLabel, padding: number)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 0
	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = UDim.new(0, padding)
	inner.PaddingRight = UDim.new(0, padding)
	inner.Parent = label
	Theme.Slant(label)
end

-- `track` : la spéciale courue (Stages.luau).
function StageTimer.new(car: CarClass.Car, playerGui: Instance, track: StageTrack.Track): StageTimer
	local self = (setmetatable({}, StageTimer) :: any) :: StageTimer
	self.Car = car
	self.Track = track
	self.State = "Idle"
	self.StartClock = 0
	self.FinalTime = 0
	self.LastProgress = -math.huge
	self.Grace = true
	self.SplitTimes = {}
	self.BestTime = nil
	self.BestSplits = {}
	self.SplitDeltas = {}
	self.FinalDelta = nil
	self.LiveDelta = nil
	self.NextDeltaAt = 0
	self.OfficialBestMs = nil
	self.ClassId = nil
	self.Weekly = nil
	self.WeeklyBestMs = nil
	self.Ghost = nil
	self.InvalidReason = ""
	self.OfficialText = nil
	self.OfficialColor = COLOR_DIM
	self.OnRunStarted = nil
	self.OnRunFinished = nil
	self.OnRunCancelled = nil

	local start = track.START_DISTANCE
	local timedLength = track.GetFinishDistance() - start
	self.SplitDistances = {}
	for i, fraction in ipairs(track.SPLITS) do
		self.SplitDistances[i] = start + timedLength * fraction
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "StageTimer"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.Position = UDim2.fromOffset(SCREEN_MARGIN, TOP_MARGIN)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.Parent = gui
	self.Panel = panel

	-- Même mise à l'échelle que le tableau de bord, autour du coin haut-gauche.
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Scale = scale

	-- Progression : « 80% » en très gros, « PROGRESSION » dessous.
	self.ProgressLabel = makeLabel(panel, 0, 76, 76, Theme.HEADLINE)
	Theme.TextInk(self.ProgressLabel, 3)
	local caption = makeLabel(panel, 70, 28, 26, Theme.HEADLINE)
	caption.Text = "PROGRESSION"
	Theme.TextInk(caption, 2)

	-- Bandeau du temps : « TEMPS » puis le chrono, à chasse fixe (sinon les
	-- chiffres « tremblent » à chaque centième).
	local band = Instance.new("Frame")
	band.Name = "TimeBand"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Theme.INK
	band.BackgroundTransparency = 0.15
	band.Position = UDim2.fromOffset(4, 104)
	band.Size = UDim2.fromOffset(268, 38)
	Theme.Slant(band)
	band.Parent = panel
	local timeCaption = Instance.new("TextLabel")
	timeCaption.BackgroundTransparency = 1
	timeCaption.Position = UDim2.fromOffset(10, 0)
	timeCaption.Size = UDim2.fromOffset(80, 38)
	timeCaption.FontFace = Theme.HEADLINE
	timeCaption.TextSize = 20
	timeCaption.TextColor3 = COLOR_TEXT
	timeCaption.TextXAlignment = Enum.TextXAlignment.Left
	timeCaption.Text = "TEMPS"
	timeCaption.Parent = band
	self.TimeLabel = Instance.new("TextLabel")
	self.TimeLabel.BackgroundTransparency = 1
	self.TimeLabel.Position = UDim2.fromOffset(92, 0)
	self.TimeLabel.Size = UDim2.fromOffset(170, 38)
	self.TimeLabel.FontFace = Theme.DIGITS
	self.TimeLabel.TextSize = 28
	self.TimeLabel.TextColor3 = COLOR_TEXT
	self.TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.TimeLabel.Parent = band

	-- Écart au fantôme : pastille pleine à droite du temps (verte devant,
	-- rouge derrière), contre qui dessous.
	self.DeltaLabel = makeLabel(panel, 107, 32, 24, Theme.DIGITS)
	self.DeltaLabel.Position = UDim2.fromOffset(286, 107)
	self.DeltaLabel.Size = UDim2.fromOffset(0, 32)
	self.DeltaLabel.TextXAlignment = Enum.TextXAlignment.Center
	pill(self.DeltaLabel, 8)
	self.VersusLabel = makeLabel(panel, 144, 16, 12, Theme.HEADLINE_MEDIUM)
	self.VersusLabel.Position = UDim2.fromOffset(286, 144)
	self.VersusLabel.Size = UDim2.fromOffset(180, 16)
	self.VersusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.TextInk(self.VersusLabel, 1.5)

	-- Statut (étiquette penchée), inters, meilleur temps et médailles.
	self.StatusLabel = makeLabel(panel, 150, 20, 13, Theme.HEADLINE)
	self.StatusLabel.Size = UDim2.fromOffset(0, 20)
	pill(self.StatusLabel, 7)
	self.SplitLabels = {}
	for i = 1, #track.SPLITS do
		self.SplitLabels[i] = makeLabel(panel, 176 + (i - 1) * 20, 18, 16, Theme.DIGITS)
		Theme.TextInk(self.SplitLabels[i], 1.5)
	end
	self.BestLabel = makeLabel(panel, 176 + #track.SPLITS * 20 + 4, 16, 14, Theme.DIGITS)
	self.BestLabel.RichText = true
	Theme.TextInk(self.BestLabel, 1.5)

	gui.Parent = playerGui
	self:_refresh(0)
	return self
end

function StageTimer:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function StageTimer:Destroy()
	self.Gui:Destroy()
end

-- Disposition tactile : déjà en haut à gauche ; un peu plus près du bord.
function StageTimer:SetTouchLayout(enabled: boolean)
	self.Panel.Position = if enabled then UDim2.fromOffset(12, TOP_MARGIN - 8) else UDim2.fromOffset(SCREEN_MARGIN, TOP_MARGIN)
end

local function dropFrame(track: StageTrack.Track, sample: StageTrack.Sample): CFrame
	local position = sample.Position + Vector3.new(0, track.DROP_HEIGHT, 0)
	return CFrame.lookAt(position, position + sample.Forward)
end

-- Retour au départ, chrono remis à zéro.
function StageTimer:Restart()
	self.Car:Teleport(self.Track.StartFrame())
	self.State = "Idle"
	self.SplitTimes = {}
	self.Grace = true
	self.OfficialText = nil
	if self.OnRunCancelled then
		self.OnRunCancelled()
	end
end

-- Meilleur temps sauvegardé (profil chargé par le serveur), en millisecondes.
-- Catégorie de la voiture : ses médailles (avant SetPersonalBest).
function StageTimer:SetClass(classId: string)
	self.ClassId = classId
end

function StageTimer:SetPersonalBest(ms: number?)
	self.BestTime = if ms then ms / 1000 else nil
	self.OfficialBestMs = ms
end

-- Défi de la semaine : la contrainte (affichée), son meilleur temps de la semaine.
function StageTimer:SetWeekly(modifierName: string, bestMs: number?)
	self.Weekly = modifierName
	self.WeeklyBestMs = bestMs
	self.BestTime = if bestMs then bestMs / 1000 else nil
end

-- Le fantôme qui sert de référence (écarts).
function StageTimer:SetGhost(ghost: Ghost.Ghost?)
	self.Ghost = ghost
end

-- Un fantôme est-il rejoué (pas masqué, et il y a un passage à rejouer) ?
function StageTimer:_hasGhost(): boolean
	local ghost = self.Ghost
	return ghost ~= nil and ghost:Played() ~= nil
end

-- Instant où le fantôme rejoué est passé au point `distance` du tracé.
function StageTimer:_referenceAt(distance: number): number?
	local ghost = self.Ghost
	return if ghost and self:_hasGhost() then ghost:TimeAt(distance) else nil
end

-- "+0.42" / "-0.15", signe toujours affiché.
local function formatDelta(delta: number): string
	return string.format("%+.2f", delta)
end

-- Nouvelle médaille : annonce en grand. Sinon, un record perso rappelle la
-- prochaine à décrocher.
local function announceRecord(ms: number, previousMs: number?, classId: string?, stageId: string)
	local limits = Medals.ForStage(classId, stageId)
	local before = Medals.TierOf(previousMs, limits)
	local after = Medals.TierOf(ms, limits)
	local nextTier, nextMs = Medals.Next(ms, limits)
	local nextText = if nextTier and nextMs
		then string.format("Prochaine : %s en %s", (Medals.TIERS[nextTier] :: Medals.Tier).Name, Medals.FormatLimit(nextMs))
		else "Toutes les médailles de la spéciale !"
	if after > before then
		local tier = Medals.TIERS[after] :: Medals.Tier
		Banner.Show(tier.Title, "Spéciale en " .. Format.Time(ms / 1000) .. "  ·  " .. nextText, tier.Color, 5, true)
	else
		Banner.Show("RECORD PERSO", Format.Time(ms / 1000) .. "  ·  " .. nextText, COLOR_FASTER, 3.5)
	end
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
	if result.Valid and type(result.Ms) == "number" and result.Weekly then
		-- Défi de la semaine : son classement à lui, pas de médaille.
		local text = "OFFICIEL " .. Format.Time(result.Ms / 1000)
		if result.WeeklyBest then
			text ..= " · MEILLEUR DE TA SEMAINE !"
			self.WeeklyBestMs = result.Ms
			self.BestTime = result.Ms / 1000
			Banner.Show(
				"DÉFI DE LA SEMAINE",
				Format.Time(result.Ms / 1000) .. "  ·  nouveau meilleur temps de ta semaine (classement : L)",
				COLOR_FASTER,
				4,
				true
			)
		end
		self.OfficialText = text
		self.OfficialColor = if result.WeeklyBest then COLOR_FASTER else COLOR_DIM
	elseif result.Valid and type(result.Ms) == "number" then
		local text = "OFFICIEL " .. Format.Time(result.Ms / 1000)
		if result.PersonalBest then
			text ..= " · RECORD PERSO !"
			self.BestTime = result.Ms / 1000
			self.OfficialBestMs = result.Ms
			announceRecord(result.Ms, if type(result.PreviousMs) == "number" then result.PreviousMs else nil, self.ClassId, self.Track.Id)
		end
		self.OfficialText = text
		self.OfficialColor = if result.PersonalBest then COLOR_FASTER else COLOR_DIM
	else
		self.OfficialText = "TEMPS REFUSÉ : " .. Format.Upper(tostring(result.Reason or "invalide"))
		self.OfficialColor = COLOR_INVALID
	end
end

--[[
	Remise sur la route à l'endroit le plus proche du tracé (sortie de route,
	voiture sur le toit). Le chrono continue : le temps perdu est la pénalité.
]]
function StageTimer:Recover()
	local sample = self.Track.Locate(self.Car.Chassis.Position)
	self.Car:Teleport(dropFrame(self.Track, sample))
	self.Grace = true
end

function StageTimer:_start(now: number)
	self.State = "Running"
	self.StartClock = now
	self.SplitTimes = {}
	self.SplitDeltas = {}
	self.FinalDelta = nil
	self.LiveDelta = nil
	self.NextDeltaAt = 0
	self.OfficialText = nil
	if self.OnRunStarted then
		self.OnRunStarted()
	end
end

function StageTimer:_finish(now: number)
	self.State = "Finished"
	self.FinalTime = now - self.StartClock
	local reference = self:_referenceAt(self.Track.GetFinishDistance())
	self.FinalDelta = if reference then self.FinalTime - reference else nil
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
	local track = self.Track
	local _, progress, lateral = track.Locate(self.Car.Chassis.Position)

	-- Juste après une téléportation, l'abscisse saute légitimement : on la
	-- reprend comme nouvelle référence sans rien conclure.
	if self.Grace then
		self.Grace = false
		self.LastProgress = progress
	end

	local crossedStart = self.LastProgress < track.START_DISTANCE and progress >= track.START_DISTANCE
	if self.State ~= "Running" then
		if crossedStart and math.abs(lateral) <= track.ROAD_WIDTH / 2 + START_LATERAL_MARGIN then
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
				local splitTime = now - self.StartClock
				self.SplitTimes[nextSplit] = splitTime
				-- Sans fantôme : le meilleur inter de la session.
				local reference = if self:_hasGhost()
					then self:_referenceAt(self.SplitDistances[nextSplit])
					else self.BestSplits[nextSplit]
				if reference then
					self.SplitDeltas[nextSplit] = splitTime - reference
				end
			end
			-- Écart en direct : où en était la référence quand elle était ICI ?
			if now >= self.NextDeltaAt then
				self.NextDeltaAt = now + DELTA_INTERVAL
				local reference = self:_referenceAt(progress)
				self.LiveDelta = if reference then (now - self.StartClock) - reference else nil
			end
			if progress >= track.GetFinishDistance() then
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
	-- Progression : part du parcours chronométré déjà couverte.
	local start = self.Track.START_DISTANCE
	local timedLength = self.Track.GetFinishDistance() - start
	local done = if state == "Finished" then 1
		elseif state == "Running" or state == "Invalid" then math.clamp((self.LastProgress - start) / timedLength, 0, 1)
		else 0
	self.ProgressLabel.Text = string.format("%d%%", math.floor(done * 100))
	-- Couleur de l'étiquette de statut : jaune par défaut.
	local tone = Theme.ACCENT
	local weekly = self.Weekly
	local title = if weekly then "DÉFI · " .. Format.Upper(weekly) else Format.Upper(self.Track.Name)
	if state == "Running" then
		self.StatusLabel.Text = title .. " · EN COURSE"
		self.TimeLabel.Text = Format.Time(now - self.StartClock)
		self.TimeLabel.TextColor3 = COLOR_TEXT
	elseif state == "Finished" then
		local isBest = self.BestTime == self.FinalTime
		local official = self.OfficialText
		if official then
			self.StatusLabel.Text = official
			if self.OfficialColor ~= COLOR_DIM then
				tone = self.OfficialColor
			end
		else
			self.StatusLabel.Text = "ARRIVÉE · VALIDATION…"
		end
		self.TimeLabel.Text = Format.Time(self.FinalTime)
		self.TimeLabel.TextColor3 = if isBest then COLOR_FASTER else COLOR_TEXT
	elseif state == "Invalid" then
		self.StatusLabel.Text = "TEMPS ANNULÉ : " .. Format.Upper(self.InvalidReason)
		tone = COLOR_INVALID
		self.TimeLabel.Text = Format.Time(self.FinalTime)
		self.TimeLabel.TextColor3 = COLOR_INVALID
	else
		self.StatusLabel.Text = title .. " · FRANCHIS LE DÉPART"
		self.TimeLabel.Text = Format.Time(0)
		self.TimeLabel.TextColor3 = COLOR_DIM
	end
	self.StatusLabel.BackgroundColor3 = tone
	-- Texte blanc sur rose ou rouge, encre sur les couleurs claires (vert, or).
	self.StatusLabel.TextColor3 = if tone == Theme.ACCENT or tone == COLOR_INVALID then Theme.TEXT else Theme.INK

	for i, label in ipairs(self.SplitLabels) do
		local splitTime = self.SplitTimes[i]
		if splitTime then
			local delta = self.SplitDeltas[i]
			if delta then
				label.Text = string.format("INTER %d   %s   %s", i, Format.Time(splitTime), formatDelta(delta))
				label.TextColor3 = if delta <= 0 then COLOR_FASTER else COLOR_SLOWER
			else
				label.Text = string.format("INTER %d   %s", i, Format.Time(splitTime))
				label.TextColor3 = COLOR_TEXT
			end
		else
			label.Text = string.format("INTER %d   --:--.--", i)
			label.TextColor3 = COLOR_DIM
		end
	end

	-- Écart au fantôme : en direct pendant le passage, figé à l'arrivée.
	local delta = if state == "Running" then self.LiveDelta elseif state == "Finished" then self.FinalDelta else nil
	local ghost = self.Ghost
	if delta then
		self.DeltaLabel.Text = formatDelta(delta)
		self.DeltaLabel.BackgroundTransparency = 0
		self.DeltaLabel.BackgroundColor3 = if delta <= 0 then COLOR_FASTER else COLOR_SLOWER
		self.DeltaLabel.TextColor3 = if delta <= 0 then Theme.INK else Theme.TEXT
		self.VersusLabel.Text = if ghost and self:_hasGhost() then "VS " .. ghost:Describe() else "VS MEILLEURS INTERS"
	else
		self.DeltaLabel.Text = ""
		self.DeltaLabel.BackgroundTransparency = 1
		self.VersusLabel.Text = if state ~= "Running" and ghost and self:_hasGhost() then "VS " .. ghost:Describe() else ""
	end

	-- Défi de la semaine : son meilleur temps de la semaine, pas de médailles.
	if weekly then
		local weeklyBest = self.WeeklyBestMs
		self.BestLabel.Text = if weeklyBest then "Ta semaine " .. Format.Time(weeklyBest / 1000) else "Pas encore de temps cette semaine"
		return
	end

	-- Meilleur temps officiel, sa médaille, la prochaine à décrocher.
	local limits = Medals.ForStage(self.ClassId, self.Track.Id)
	local bestMs = self.OfficialBestMs
	local tier = Medals.TierOf(bestMs, limits)
	local nextTier, nextMs = Medals.Next(bestMs, limits)
	local text = if bestMs then "Meilleur " .. Format.Time(bestMs / 1000) else "Pas de temps"
	if tier > 0 then
		text ..= " " .. Medals.Rich(tier)
	end
	if nextTier and nextMs then
		text ..= "  → " .. Medals.Rich(nextTier) .. " " .. Medals.FormatLimit(nextMs)
	end
	self.BestLabel.Text = text
end

return StageTimer
