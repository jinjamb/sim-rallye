--!strict
--[[
	RaceHud.luau
	Affichage pendant une course de rallycross.

		EN HAUT AU CENTRE : position (P2/6), tour (2/4), chrono du tour en cours,
		meilleur et dernier tour, état du joker, pénalités.
		À GAUCHE : classement en direct, écarts au leader (masqué sur mobile).
		MINI-CARTE : en bas à gauche (en haut à gauche sur mobile : le volant
		tactile occupe le bas).
		FEUX DE DÉPART : cinq feux rouges qui s'allument un à un ; leur
		extinction est le départ. Les feux du portique, sur le circuit, sont
		synchronisés (tools/build-circuit.luau les crée).
		MESSAGES : tour bouclé, joker, pénalité, dernier tour, drapeau à damier.
		RÉSULTATS : classement de la manche, temps, meilleurs tours, points.
		SPECTATEUR : une fois arrivé, on peut suivre les pilotes encore en course.

	Le chrono du tour est calculé avec l'heure du SERVEUR (début du tour envoyé
	par RaceService) : il est identique pour tous et colle au temps officiel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Circuit = require(ReplicatedStorage.Shared.Tracks.Circuit)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local RaceUi = require(script.Parent.RaceUi)
local Theme = require(script.Parent.Parent.UI.Theme)
local Minimap = require(script.Parent.Minimap)

local RaceHud = {}
RaceHud.__index = RaceHud

export type Callbacks = {
	Spectate: () -> (),
	SpectateNext: (number) -> (),
	StopSpectate: () -> (),
}

export type SpectateState = { Available: boolean, Active: boolean, Name: string }

export type RaceHud = typeof(setmetatable({}, RaceHud)) & {
	Gui: ScreenGui,
	Root: Frame,
	Scale: UIScale,
	TouchLayout: boolean,
	LocalUserId: number,

	Info: Frame,
	RoundLabel: TextLabel,
	PositionLabel: TextLabel,
	LapLabel: TextLabel,
	LapTimeLabel: TextLabel,
	JokerChip: TextLabel,
	PenaltyChip: TextLabel,
	BottomLabel: TextLabel,

	Standings: Frame,
	StandingRows: { TextLabel },

	MinimapHolder: Frame,
	Minimap: Minimap.Minimap?,
	MinimapTrack: string?,

	Lights: Frame,
	LightDots: { Frame },
	GantryLights: { BasePart },
	GantryTrack: string?,

	Message: TextLabel,
	MessageUntil: number,

	Results: Frame,
	ResultsTitle: TextLabel,
	ResultsRows: Frame,
	ResultsFooter: TextLabel,
	ResultsData: RaceUi.Results?,

	SpectateBar: Frame,
	SpectateLabel: TextLabel,
	SpectateButtons: Frame,
	WatchButton: TextButton,

	LobbyBanner: Frame,
	LobbyLabel: TextLabel,
	PodiumUntil: number,

	Race: RaceUi.RaceSnapshot?,
	Live: RaceUi.LivePayload?,
}

local INFO_WIDTH, INFO_HEIGHT = 470, 108
local STANDINGS_WIDTH = 270
local ROW_HEIGHT = 22
local MAX_ROWS = 6
local LIGHT_SIZE = 46
local MESSAGE_TIME = 2.5

local COLOR_LIGHT_OFF = Color3.fromRGB(45, 20, 20)
local COLOR_LIGHT_RED = Color3.fromRGB(240, 30, 30)
local COLOR_LIGHT_GREEN = Color3.fromRGB(40, 230, 80)

-- « P2/6 » dans la case jaune : le nombre de pilotes plus petit, en gris foncé.
local function positionText(position: number, count: number): string
	return string.format('P%d<font size="24" color="#4A4A52">/%d</font>', position, count)
end

function RaceHud.new(playerGui: Instance, localUserId: number, callbacks: Callbacks): RaceHud
	local self = (setmetatable({}, RaceHud) :: any) :: RaceHud
	self.LocalUserId = localUserId
	self.TouchLayout = false
	self.MessageUntil = 0
	self.PodiumUntil = 0
	self.GantryLights = {}
	self.Race = nil
	self.Live = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	self.Gui = gui

	-- Racine à l'échelle : ses enfants sont placés en "pixels de référence" (1080p).
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Root = root
	self.Scale = scale

	-- Panneau principal ----------------------------------------------------------
	local info = RaceUi.Panel(root)
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.new(0.5, 0, 0, 12)
	info.Size = UDim2.fromOffset(INFO_WIDTH, INFO_HEIGHT)
	self.Info = info

	self.RoundLabel = RaceUi.Label(info, "", 12, Enum.Font.GothamBold, RaceUi.COLOR_DIM)
	self.RoundLabel.Position = UDim2.fromOffset(14, 6)
	self.RoundLabel.Size = UDim2.new(1, -28, 0, 16)

	-- Position : la case jaune des retransmissions.
	self.PositionLabel = RaceUi.Label(info, "", 50, Enum.Font.GothamBlack, Theme.ON_ACCENT)
	self.PositionLabel.RichText = true
	self.PositionLabel.BackgroundTransparency = 0
	self.PositionLabel.BackgroundColor3 = Theme.ACCENT
	self.PositionLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.PositionLabel.Position = UDim2.fromOffset(14, 24)
	self.PositionLabel.Size = UDim2.fromOffset(126, 56)
	Theme.Corner(self.PositionLabel, 2)

	self.LapLabel = RaceUi.Label(info, "", 15, Enum.Font.GothamBold, RaceUi.COLOR_DIM)
	self.LapLabel.Position = UDim2.fromOffset(150, 24)
	self.LapLabel.Size = UDim2.fromOffset(170, 18)

	self.LapTimeLabel = RaceUi.Label(info, "", 34, Enum.Font.RobotoMono)
	self.LapTimeLabel.Position = UDim2.fromOffset(150, 42)
	self.LapTimeLabel.Size = UDim2.fromOffset(170, 36)

	local function chip(y: number, height: number): TextLabel
		local label = RaceUi.Label(info, "", 12, Enum.Font.GothamBold, RaceUi.COLOR_PANEL)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.BackgroundTransparency = 0
		label.Position = UDim2.fromOffset(INFO_WIDTH - 140, y)
		label.Size = UDim2.fromOffset(126, height)
		RaceUi.Corner(label, 4)
		return label
	end
	self.JokerChip = chip(26, 24)
	self.PenaltyChip = chip(56, 20)
	self.PenaltyChip.BackgroundColor3 = RaceUi.COLOR_RED

	self.BottomLabel = RaceUi.Label(info, "", 14, Enum.Font.RobotoMono, RaceUi.COLOR_DIM)
	self.BottomLabel.Position = UDim2.fromOffset(14, 84)
	self.BottomLabel.Size = UDim2.new(1, -28, 0, 18)

	-- Classement ------------------------------------------------------------------
	local standings = RaceUi.Panel(root, 0.3)
	standings.Position = UDim2.fromOffset(16, 64)
	standings.Size = UDim2.fromOffset(STANDINGS_WIDTH, 34 + MAX_ROWS * ROW_HEIGHT + 8)
	self.Standings = standings
	local header = RaceUi.Label(standings, "CLASSEMENT", 16, Enum.Font.GothamBlack)
	header.Position = UDim2.fromOffset(12, 4)
	header.Size = UDim2.new(1, -24, 0, 20)
	local headerChecker = Theme.Checker(standings, STANDINGS_WIDTH, 3, 2)
	headerChecker.Position = UDim2.fromOffset(0, 24)
	headerChecker.BackgroundTransparency = 0.4
	self.StandingRows = {}
	for i = 1, MAX_ROWS do
		local row = RaceUi.Label(standings, "", 15, Enum.Font.RobotoMono)
		row.Position = UDim2.fromOffset(8, 32 + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -16, 0, ROW_HEIGHT)
		row.RichText = true
		-- Sa propre ligne : surlignée en jaune (voir Update).
		row.BackgroundColor3 = Theme.ACCENT
		row.BackgroundTransparency = 1
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 4)
		padding.Parent = row
		self.StandingRows[i] = row
	end

	-- Mini-carte (construite à la première course) ------------------------------------
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -16)
	holder.Size = UDim2.fromOffset(190, 190)
	holder.Parent = root
	self.MinimapHolder = holder
	self.Minimap = nil
	self.MinimapTrack = nil

	-- Feux de départ ---------------------------------------------------------------
	local lights = RaceUi.Panel(root, 0.15)
	lights.AnchorPoint = Vector2.new(0.5, 0)
	lights.Position = UDim2.new(0.5, 0, 0, 136)
	lights.Size = UDim2.fromOffset(5 * (LIGHT_SIZE + 12) + 12, LIGHT_SIZE + 24)
	lights.Visible = false
	self.Lights = lights
	self.LightDots = {}
	for i = 1, 5 do
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromOffset(12 + (i - 1) * (LIGHT_SIZE + 12), 12)
		dot.Size = UDim2.fromOffset(LIGHT_SIZE, LIGHT_SIZE)
		dot.BackgroundColor3 = COLOR_LIGHT_OFF
		dot.BorderSizePixel = 0
		RaceUi.Corner(dot, LIGHT_SIZE)
		dot.Parent = lights
		self.LightDots[i] = dot
	end

	-- Message ---------------------------------------------------------------------
	local message = RaceUi.Label(root, "", 36, Enum.Font.GothamBlack)
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.36)
	message.Size = UDim2.fromOffset(900, 50)
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.TextStrokeTransparency = 0.3
	-- Messages longs (arrivée, podium) : réduits pour tenir sur une ligne.
	message.TextScaled = true
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 36
	sizeLimit.Parent = message
	message.Visible = false
	self.Message = message

	-- Résultats --------------------------------------------------------------------
	local results = RaceUi.Panel(root, 0.08)
	results.AnchorPoint = Vector2.new(0.5, 0.5)
	results.Position = UDim2.fromScale(0.5, 0.52)
	results.Size = UDim2.fromOffset(560, 80 + MAX_ROWS * 30)
	results.Visible = false
	self.Results = results
	-- Tableau des résultats : damier en tête, titre en capitales condensées.
	local resultsChecker = Theme.Checker(results, 600, 5, 2)
	resultsChecker.BackgroundTransparency = 0.2
	self.ResultsTitle = RaceUi.Label(results, "", 24, Enum.Font.GothamBlack)
	self.ResultsTitle.Position = UDim2.fromOffset(16, 12)
	self.ResultsTitle.Size = UDim2.new(1, -32, 0, 28)
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(16, 42)
	rows.Size = UDim2.new(1, -32, 0, MAX_ROWS * 30)
	rows.Parent = results
	self.ResultsRows = rows
	self.ResultsFooter = RaceUi.Label(results, "", 13, Enum.Font.GothamMedium, RaceUi.COLOR_DIM)
	self.ResultsFooter.Position = UDim2.new(0, 16, 1, -28)
	self.ResultsFooter.Size = UDim2.new(1, -32, 0, 18)
	self.ResultsData = nil

	-- Salle d'attente (on est dans la zone d'un circuit, au paddock) -------------------
	local banner = RaceUi.Panel(root, 0.15)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Size = UDim2.fromOffset(560, 62)
	banner.Visible = false
	self.LobbyBanner = banner
	local lobbyLabel = RaceUi.Label(banner, "", 18, Enum.Font.GothamBold)
	lobbyLabel.RichText = true
	lobbyLabel.TextXAlignment = Enum.TextXAlignment.Center
	lobbyLabel.Position = UDim2.fromOffset(12, 0)
	lobbyLabel.Size = UDim2.new(1, -24, 1, 0)
	self.LobbyLabel = lobbyLabel

	-- Spectateur ------------------------------------------------------------------
	local bar = RaceUi.Panel(root, 0.2)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.Size = UDim2.fromOffset(470, 48)
	bar.Visible = false
	self.SpectateBar = bar
	self.SpectateLabel = RaceUi.Label(bar, "", 15, Enum.Font.GothamBold)
	self.SpectateLabel.Position = UDim2.fromOffset(14, 0)
	self.SpectateLabel.Size = UDim2.new(1, -200, 1, 0)
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -8, 0.5, 0)
	buttons.Size = UDim2.fromOffset(180, 34)
	buttons.Parent = bar
	self.SpectateButtons = buttons
	local previous = RaceUi.Button(buttons, "◀", function()
		callbacks.SpectateNext(-1)
	end)
	previous.Size = UDim2.fromOffset(40, 34)
	local nextButton = RaceUi.Button(buttons, "▶", function()
		callbacks.SpectateNext(1)
	end)
	nextButton.Position = UDim2.fromOffset(46, 0)
	nextButton.Size = UDim2.fromOffset(40, 34)
	local stop = RaceUi.Button(buttons, "RETOUR", function()
		callbacks.StopSpectate()
	end)
	stop.Position = UDim2.fromOffset(92, 0)
	stop.Size = UDim2.fromOffset(88, 34)
	stop.TextSize = 12
	local watch = RaceUi.Button(bar, "REGARDER LA COURSE (V)", function()
		callbacks.Spectate()
	end)
	watch.AnchorPoint = Vector2.new(1, 0.5)
	watch.Position = UDim2.new(1, -8, 0.5, 0)
	watch.Size = UDim2.fromOffset(220, 34)
	watch.TextSize = 13
	self.WatchButton = watch

	gui.Parent = playerGui
	return self
end

--------------------------------------------------------------------------------
-- Disposition
--------------------------------------------------------------------------------

function RaceHud:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
	-- Mobile : la rangée de boutons tactiles occupe le haut, le volant le bas gauche.
	self.Info.Position = UDim2.new(0.5, 0, 0, if enabled then 52 else 12)
	self.LobbyBanner.Position = UDim2.new(0.5, 0, 0, if enabled then 52 else 12)
	self.Standings.Visible = not enabled
	if enabled then
		self.MinimapHolder.AnchorPoint = Vector2.new(0, 0)
		self.MinimapHolder.Position = UDim2.fromOffset(12, 12)
	else
		self.MinimapHolder.AnchorPoint = Vector2.new(0, 1)
		self.MinimapHolder.Position = UDim2.new(0, 16, 1, -16)
	end
	self.Lights.Position = UDim2.new(0.5, 0, 0, if enabled then 170 else 136)
end

--------------------------------------------------------------------------------
-- Données
--------------------------------------------------------------------------------

function RaceHud:_gantryLights(trackId: string): { BasePart }
	if self.GantryTrack == trackId then
		return self.GantryLights
	end
	self.GantryTrack = trackId
	self.GantryLights = {}
	local folder = workspace:FindFirstChild("Circuits")
	local circuit = folder and folder:FindFirstChild(trackId)
	local gantry = circuit and circuit:FindFirstChild("Gantry")
	if gantry then
		for i = 1, 5 do
			local light = gantry:FindFirstChild("Light" .. i)
			if light and light:IsA("BasePart") then
				self.GantryLights[i] = light
			end
		end
	end
	return self.GantryLights
end

-- La course du joueur (nil : pas de course, HUD masqué).
function RaceHud:SetRace(race: RaceUi.RaceSnapshot?)
	self.Race = race
	self.Gui.Enabled = race ~= nil or os.clock() < self.PodiumUntil
	if not race then
		self.Live = nil
		self:HideResults()
		self.LobbyBanner.Visible = false
		self.Info.Visible = false
		self.Standings.Visible = false
		self.MinimapHolder.Visible = false
		self.Lights.Visible = false
		return
	end
	-- En salle d'attente : seulement le bandeau ; en course : tout le reste.
	local inLobby = race.State == "Lobby"
	self.LobbyBanner.Visible = inLobby
	self.Info.Visible = not inLobby
	self.Standings.Visible = not inLobby and not self.TouchLayout
	self.MinimapHolder.Visible = not inLobby
	if inLobby then
		self.Live = nil
		self:HideResults()
	end
	if race.State == "Grid" then
		self:HideResults()
		self:ShowMessage("MISE EN GRILLE…", RaceUi.COLOR_TEXT, 3)
	end
	if self.MinimapTrack ~= race.TrackId then
		local existing = self.Minimap
		if existing then
			existing:Destroy()
		end
		local circuit: Circuit.Circuit? = Tracks.Get(race.TrackId)
		self.Minimap = if circuit then Minimap.new(self.MinimapHolder, circuit) else nil
		self.MinimapTrack = race.TrackId
	end
end

function RaceHud:SetLive(payload: RaceUi.LivePayload)
	local race = self.Race
	if race and payload.Id == race.Id then
		self.Live = payload
	end
end

function RaceHud:ShowMessage(text: string, color: Color3?, duration: number?)
	self.Message.Text = text
	self.Message.TextColor3 = color or RaceUi.COLOR_TEXT
	self.Message.Visible = true
	self.MessageUntil = os.clock() + (duration or MESSAGE_TIME)
end

function RaceHud:ShowResults(results: RaceUi.Results)
	self.ResultsData = results
	local trackName = ""
	local circuit = Tracks.Get(results.TrackId)
	if circuit then
		trackName = " · " .. string.upper(circuit.Name)
	end
	self.ResultsTitle.Text = (if results.Final then "RÉSULTATS — " else "") .. results.RoundName .. trackName
	for _, child in ipairs(self.ResultsRows:GetChildren()) do
		child:Destroy()
	end
	for index, row in ipairs(results.Rows) do
		if index > MAX_ROWS then
			break
		end
		local label = RaceUi.Label(self.ResultsRows, "", 16, Enum.Font.RobotoMono)
		label.Position = UDim2.fromOffset(0, (index - 1) * 30)
		label.Size = UDim2.new(1, 0, 0, 28)
		label.RichText = true
		-- Lignes alternées, la sienne surlignée en jaune.
		local mine = row.UserId == self.LocalUserId
		label.BackgroundColor3 = if mine then Theme.ACCENT else Theme.PANEL_2
		label.BackgroundTransparency = if mine then 0.75 elseif index % 2 == 1 then 0.55 else 1
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.Parent = label
		local name = row.Name
		if (utf8.len(name) or #name) > 14 then
			local cut = utf8.offset(name, 14)
			name = (if cut then string.sub(name, 1, cut - 1) else name) .. "…"
		end
		local padding = string.rep(" ", math.max(0, 15 - (utf8.len(name) or #name)))
		local timeText = if row.Dnf then string.upper(row.DnfReason or "abandon") else RaceUi.FormatTime(row.TotalTime)
		local penalty = if row.Penalty > 0 and not row.Dnf then string.format(" (+%gs)", row.Penalty) else ""
		local best = if row.BestLap then "  t. " .. RaceUi.FormatTime(row.BestLap) else ""
		local points = if results.Final and row.Points > 0 then string.format("  +%d pts", row.Points) else ""
		label.Text = string.format("%d. %s%s%s%s%s%s", row.Position, name, padding, timeText, penalty, best, points)
		label.TextColor3 = if row.UserId == self.LocalUserId then RaceUi.COLOR_ACCENT else RaceUi.COLOR_TEXT
	end
	self.Results.Size = UDim2.fromOffset(560, 80 + math.min(#results.Rows, MAX_ROWS) * 30)
	self.Results.Visible = true
end

-- Cérémonie du podium (après le retour au paddock, hors course).
function RaceHud:ShowPodium(names: { string }, duration: number)
	self.PodiumUntil = os.clock() + duration
	self.Gui.Enabled = true
	local parts = {}
	for index, name in ipairs(names) do
		table.insert(parts, string.format("%d. %s", index, name))
	end
	self:ShowMessage("PODIUM — " .. table.concat(parts, "   "), RaceUi.COLOR_ACCENT, duration)
end

function RaceHud:HideResults()
	self.ResultsData = nil
	self.Results.Visible = false
end

function RaceHud:SetSpectate(state: SpectateState)
	self.SpectateBar.Visible = self.Gui.Enabled and (state.Available or state.Active)
	self.SpectateButtons.Visible = state.Active
	self.WatchButton.Visible = state.Available and not state.Active
	self.SpectateLabel.Text = if state.Active then "SPECTATEUR — " .. state.Name else "COURSE TERMINÉE POUR TOI"
end

--------------------------------------------------------------------------------
-- Mise à jour
--------------------------------------------------------------------------------

function RaceHud:_myRow(): RaceUi.LiveRow?
	local live = self.Live
	if not live then
		return nil
	end
	for _, row in ipairs(live.Rows) do
		if row.U == self.LocalUserId then
			return row
		end
	end
	return nil
end

function RaceHud:_updateLights(race: RaceUi.RaceSnapshot, serverNow: number)
	local lit = 0
	local green = false
	local visible = false
	if race.State == "Countdown" and race.LightsStart then
		visible = true
		lit = math.clamp(math.floor((serverNow - (race.LightsStart :: number)) / race.LightInterval) + 1, 0, race.LightCount)
	elseif race.State == "Racing" and race.StartTime and serverNow - (race.StartTime :: number) < 1.2 then
		visible = true
		green = true
	end
	self.Lights.Visible = visible
	for i, dot in ipairs(self.LightDots) do
		dot.BackgroundColor3 = if green then COLOR_LIGHT_GREEN elseif i <= lit then COLOR_LIGHT_RED else COLOR_LIGHT_OFF
	end
	-- Feux du portique (modifiés localement : chacun voit ceux de sa course).
	for i, light in ipairs(self:_gantryLights(race.TrackId)) do
		light.Color = if green then COLOR_LIGHT_GREEN elseif visible and i <= lit then COLOR_LIGHT_RED else COLOR_LIGHT_OFF
	end
end

function RaceHud:Update(_dt: number, cars: { Minimap.CarDot }, serverNow: number)
	local viewport = workspace.CurrentCamera.ViewportSize
	local scale = if self.TouchLayout
		then math.clamp(viewport.Y / 620, 0.55, 1)
		else math.clamp(viewport.Y / 1080, 0.6, 1.2)
	self.Scale.Scale = scale
	self.Root.Size = UDim2.fromScale(1 / scale, 1 / scale)

	if self.Message.Visible and os.clock() > self.MessageUntil then
		self.Message.Visible = false
	end
	-- Hors course, le HUD ne reste affiché que pendant la cérémonie du podium.
	if self.Race == nil then
		self.Gui.Enabled = os.clock() < self.PodiumUntil
	end

	local race = self.Race
	if not race or not self.Gui.Enabled then
		return
	end
	if race.State == "Lobby" then
		local circuit = Tracks.Get(race.TrackId)
		local name = if circuit then string.upper(circuit.Name) else race.TrackId
		local countdown = if race.AutoStartAt
			then string.format("départ dans <b>%d s</b>", math.max(0, math.ceil((race.AutoStartAt :: number) - serverNow)))
			else string.format("en attente d'un %de pilote", race.MinPlayers)
		self.LobbyLabel.Text = string.format(
			'%s · %d/%d pilotes · %s\n<font size="13" color="#8288A0">%d tours · %s · C : options · sors de la zone pour quitter</font>',
			name,
			#race.Members,
			race.MaxPlayers,
			countdown,
			race.Laps,
			if race.Format == "Event" then "qualif + finale" else "course simple"
		)
		return
	end
	self:_updateLights(race, serverNow)

	local minimap = self.Minimap
	if minimap then
		minimap:Update(cars)
	end

	local circuit = Tracks.Get(race.TrackId)
	local roundText = race.RoundName .. (if circuit then " · " .. string.upper(circuit.Name) else "")
	if race.RoundCount > 1 then
		roundText ..= string.format(" · MANCHE %d/%d", race.Round, race.RoundCount)
	end
	self.RoundLabel.Text = roundText

	local live = self.Live
	local me = self:_myRow()
	local count = if live then #live.Rows else #race.Members
	if me then
		self.PositionLabel.Text = positionText(me.P, count)
		local currentLap = math.min(me.L + 1, race.Laps)
		self.LapLabel.Text = if me.F then "ARRIVÉE" else string.format("TOUR %d/%d", currentLap, race.Laps)
		if me.F then
			self.LapTimeLabel.Text = RaceUi.FormatTime(me.T)
		elseif race.State == "Racing" then
			self.LapTimeLabel.Text = RaceUi.FormatTime(serverNow - me.LS)
		else
			self.LapTimeLabel.Text = RaceUi.FormatTime(0)
		end
		self.JokerChip.Text = if me.J > 0 then "JOKER ✓" else "JOKER À FAIRE"
		self.JokerChip.BackgroundColor3 = if me.J > 0 then RaceUi.COLOR_GREEN else RaceUi.COLOR_ORANGE
		self.PenaltyChip.Visible = me.PEN > 0
		self.PenaltyChip.Text = string.format("PÉNALITÉ +%g s", me.PEN)
		self.BottomLabel.Text = string.format("MEILLEUR %s   DERNIER %s", RaceUi.FormatTime(me.B), RaceUi.FormatTime(me.LL))
	else
		self.PositionLabel.Text = positionText(0, count)
		self.LapLabel.Text = string.format("TOUR 1/%d", race.Laps)
		self.LapTimeLabel.Text = RaceUi.FormatTime(0)
		self.JokerChip.Text = "JOKER À FAIRE"
		self.JokerChip.BackgroundColor3 = RaceUi.COLOR_ORANGE
		self.PenaltyChip.Visible = false
		self.BottomLabel.Text = ""
	end

	-- Classement en direct.
	for i, label in ipairs(self.StandingRows) do
		local row = if live then live.Rows[i] else nil
		if row then
			local name = row.N
			if (utf8.len(name) or #name) > 11 then
				local cut = utf8.offset(name, 11)
				name = (if cut then string.sub(name, 1, cut - 1) else name) .. "…"
			end
			local padding = string.rep(" ", math.max(0, 12 - (utf8.len(name) or #name)))
			local gap: string
			if row.D then
				gap = "ABANDON"
			elseif row.F and i == 1 then
				gap = "ARRIVÉ"
			elseif i == 1 then
				gap = string.format("T%d", math.min(row.L + 1, race.Laps))
			elseif row.LD > 0 then
				gap = string.format("+%d T", row.LD)
			elseif row.G then
				gap = string.format("+%.1f", row.G)
			else
				gap = "—"
			end
			local joker = if row.J > 0 then "" else ' <font color="#FF8C28">J</font>'
			label.Text = string.format("%d %s%s%s%s", row.P, name, padding, gap, joker)
			local mine = row.U == self.LocalUserId
			label.TextColor3 = if mine then RaceUi.COLOR_ACCENT else RaceUi.COLOR_TEXT
			label.BackgroundTransparency = if mine then 0.82 else 1
		else
			label.Text = ""
			label.BackgroundTransparency = 1
		end
	end

	local results = self.ResultsData
	if results and self.Results.Visible then
		local remaining = math.max(0, math.ceil(results.NextAt - serverNow))
		self.ResultsFooter.Text = if results.Final
			then string.format("Retour au paddock dans %d s", remaining)
			else string.format("%s dans %d s — grille dans l'ordre de ce classement", results.NextRoundName or "Manche suivante", remaining)
	end
end

return RaceHud
