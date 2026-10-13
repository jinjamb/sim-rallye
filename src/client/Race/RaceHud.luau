--!strict
--[[
	RaceHud.luau
	Affichage pendant une course de rallycross.

		EN HAUT AU CENTRE : position (P2/6), tour (2/4), chrono du tour en cours,
		meilleur et dernier tour, état du joker, pénalités.
		À GAUCHE : classement en direct, écarts au leader (masqué sur mobile) ;
		au bout de chaque ligne, le badge du joker (vert « J ✓ » fait,
		orange « J » à faire), légende en pied.
		JOKER : tant que le sien est à faire, son témoin clignote, la branche
		joker est orange vif sur la mini-carte, et à l'approche de l'entrée
		une grande alerte dit de quel côté il part.
		MINI-CARTE : en bas à gauche (en haut à gauche sur mobile : le volant
		tactile occupe le bas).
		FEUX DE DÉPART : cinq feux rouges qui s'allument un à un ; leur
		extinction est le départ. Les feux du portique, sur le circuit, sont
		synchronisés (tools/build-circuit.luau les crée).
		MESSAGES : tour bouclé, joker, pénalité, dernier tour, drapeau à damier.
		RÉSULTATS : classement de la manche, temps, meilleurs tours, points ;
		après la dernière manche, le bouton REVANCHE et le compte des votes.
		SPECTATEUR : une fois arrivé, on peut suivre les pilotes encore en course.

	Le chrono du tour est calculé avec l'heure du SERVEUR (début du tour envoyé
	par RaceService) : il est identique pour tous et colle au temps officiel.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Circuit = require(ReplicatedStorage.Shared.Tracks.Circuit)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local RaceTypes = require(script.Parent.RaceTypes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Minimap = require(script.Parent.Minimap)
local SoundBank = require(script.Parent.Parent.Audio.SoundBank)
local SoundGroups = require(script.Parent.Parent.Audio.SoundGroups)

local RaceHud = {}

-- Mini-carte en course (onglet OPTIONS : « Mini-carte en course »).
RaceHud.ShowMinimap = true
RaceHud.__index = RaceHud

export type Callbacks = {
	Rematch: () -> (),
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
	JokerBadges: { TextLabel }, -- au bout de chaque ligne : joker fait (vert) ou à faire (orange)
	JokerPrompt: TextLabel, -- « JOKER → » à l'approche de l'entrée du joker, s'il reste à faire
	JokerSide: { [string]: number }, -- côté de la branche joker par circuit (+1 gauche, -1 droite)
	JokerHint: Circuit.Location?, -- dernière position sur le tracé (recherche locale)

	MinimapHolder: Frame,
	Minimap: Minimap.Minimap?,
	MinimapTrack: string?,

	Lights: Frame,
	LightDots: { Frame },
	GantryLights: { BasePart },
	GantryTrack: string?,
	LightsLit: number, -- feux rouges déjà annoncés par un bip
	LightsGreen: boolean, -- départ déjà annoncé
	LightSounds: { [string]: Sound },

	Message: TextLabel,
	MessageUntil: number,

	Results: Frame,
	ResultsTitle: TextLabel,
	ResultsRows: Frame,
	ResultsFooter: TextLabel,
	ResultsData: RaceTypes.Results?,
	RematchButton: TextButton,
	RematchVoted: boolean,

	SpectateBar: Frame,
	SpectateLabel: TextLabel,
	SpectateButtons: Frame,
	WatchButton: TextButton,

	LobbyBanner: Frame,
	LobbyLabel: TextLabel,
	PodiumUntil: number,

	Race: RaceTypes.RaceSnapshot?,
	Live: RaceTypes.LivePayload?,
}

local INFO_WIDTH, INFO_HEIGHT = 470, 108
local STANDINGS_WIDTH = 290
local ROW_HEIGHT = 22
local MAX_ROWS = 6
local LIGHT_SIZE = 46
local MESSAGE_TIME = 2.5
local JOKER_PROMPT_DISTANCE = 260 -- studs avant l'entrée du joker où l'alerte s'affiche
local JOKER_LEGEND_HEIGHT = 20
local COLOR_JOKER_DUE = Theme.ORANGE
local COLOR_JOKER_DONE = Theme.GREEN

local COLOR_LIGHT_OFF = Color3.fromRGB(44, 24, 56)
local COLOR_LIGHT_RED = Color3.fromRGB(240, 30, 30)
local COLOR_LIGHT_GREEN = Color3.fromRGB(40, 230, 80)

-- « P2/6 » dans la case jaune : le nombre de pilotes plus petit, plus pâle.
local function positionText(position: number, count: number): string
	return string.format('P%d<font size="24" color="#7A6420">/%d</font>', position, count)
end

function RaceHud.new(playerGui: Instance, localUserId: number, callbacks: Callbacks): RaceHud
	local self = (setmetatable({}, RaceHud) :: any) :: RaceHud
	self.LocalUserId = localUserId
	self.TouchLayout = false
	self.MessageUntil = 0
	self.PodiumUntil = 0
	self.GantryLights = {}
	self.LightsLit = 0
	self.LightsGreen = false
	self.LightSounds = {}
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
	local info = Widgets.Panel(root)
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.new(0.5, 0, 0, 12)
	info.Size = UDim2.fromOffset(INFO_WIDTH, INFO_HEIGHT)
	self.Info = info

	self.RoundLabel = Widgets.Label(info, "", 12, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	self.RoundLabel.Position = UDim2.fromOffset(14, 6)
	self.RoundLabel.Size = UDim2.new(1, -28, 0, 16)

	-- Position : la case jaune des retransmissions.
	self.PositionLabel = Widgets.Label(info, "", 46, Enum.Font.GothamBlack, Theme.ON_YELLOW)
	self.PositionLabel.RichText = true
	self.PositionLabel.BackgroundTransparency = 0
	self.PositionLabel.BackgroundColor3 = Theme.YELLOW
	self.PositionLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.PositionLabel.Position = UDim2.fromOffset(14, 24)
	self.PositionLabel.Size = UDim2.fromOffset(126, 56)
	Theme.Slant(self.PositionLabel, 12) -- case penchée

	self.LapLabel = Widgets.Label(info, "", 15, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	self.LapLabel.Position = UDim2.fromOffset(164, 24)
	self.LapLabel.Size = UDim2.fromOffset(170, 18)

	self.LapTimeLabel = Widgets.Label(info, "", 34, Enum.Font.RobotoMono)
	self.LapTimeLabel.Position = UDim2.fromOffset(164, 42)
	self.LapTimeLabel.Size = UDim2.fromOffset(170, 36)

	local function chip(y: number, height: number): TextLabel
		local label = Widgets.Label(info, "", 12, Enum.Font.GothamBold, Widgets.COLOR_PANEL)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.BackgroundTransparency = 0
		label.Position = UDim2.fromOffset(INFO_WIDTH - 140, y)
		label.Size = UDim2.fromOffset(126, height)
		Theme.Slant(label)
		return label
	end
	self.JokerChip = chip(26, 24)
	self.PenaltyChip = chip(56, 20)
	self.PenaltyChip.BackgroundColor3 = Widgets.COLOR_RED
	self.PenaltyChip.TextColor3 = Theme.TEXT

	self.BottomLabel = Widgets.Label(info, "", 14, Enum.Font.RobotoMono, Widgets.COLOR_DIM)
	self.BottomLabel.Position = UDim2.fromOffset(14, 84)
	self.BottomLabel.Size = UDim2.new(1, -28, 0, 18)

	-- Classement ------------------------------------------------------------------
	local standings = Widgets.Panel(root, 0.3)
	standings.Position = UDim2.fromOffset(16, 64)
	standings.Size = UDim2.fromOffset(STANDINGS_WIDTH, 34 + MAX_ROWS * ROW_HEIGHT + 8 + JOKER_LEGEND_HEIGHT)
	self.Standings = standings
	local header = Widgets.Label(standings, "CLASSEMENT", 16, Enum.Font.GothamBlack)
	header.Position = UDim2.fromOffset(12, 4)
	header.Size = UDim2.new(1, -24, 0, 20)
	local headerStripes = Theme.Stripes(standings, Theme.ACCENT, 4)
	headerStripes.AnchorPoint = Vector2.new(1, 0)
	headerStripes.Position = UDim2.new(1, -10, 0, 7)
	headerStripes.Size = UDim2.fromOffset(56, 16)
	local headerRule = Instance.new("Frame")
	headerRule.BorderSizePixel = 0
	headerRule.BackgroundColor3 = Theme.ACCENT
	headerRule.Position = UDim2.fromOffset(0, 27)
	headerRule.Size = UDim2.new(1, 0, 0, 2)
	headerRule.Parent = standings
	self.StandingRows = {}
	self.JokerBadges = {}
	for i = 1, MAX_ROWS do
		local row = Widgets.Label(standings, "", 15, Enum.Font.RobotoMono)
		row.Position = UDim2.fromOffset(8, 32 + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -16, 0, ROW_HEIGHT)
		row.RichText = true
		-- Sa propre ligne : surlignée en rose (voir Update).
		row.BackgroundColor3 = Theme.ACCENT
		row.BackgroundTransparency = 1
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 4)
		padding.Parent = row
		self.StandingRows[i] = row
		-- Badge du joker, au bout de la ligne : on voit d'un coup d'œil qui
		-- l'a déjà fait et qui devra encore faire le détour.
		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -14, 0, 32 + (i - 1) * ROW_HEIGHT + ROW_HEIGHT / 2)
		badge.Size = UDim2.fromOffset(38, ROW_HEIGHT - 6)
		badge.BorderSizePixel = 0
		badge.FontFace = Theme.HEADLINE
		badge.TextSize = 11
		badge.TextColor3 = Theme.INK
		badge.Visible = false
		badge.Parent = standings
		Theme.Slant(badge)
		self.JokerBadges[i] = badge
	end
	-- Légende des badges, en pied du classement.
	local legend = Widgets.Label(standings, "", 11, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	legend.RichText = true
	legend.Text = string.format(
		'<font color="%s"><b>J ✓</b></font> joker fait   <font color="%s"><b>J</b></font> joker à faire',
		Theme.Hex(COLOR_JOKER_DONE),
		Theme.Hex(COLOR_JOKER_DUE)
	)
	legend.AnchorPoint = Vector2.new(0, 1)
	legend.Position = UDim2.new(0, 12, 1, -4)
	legend.Size = UDim2.new(1, -24, 0, JOKER_LEGEND_HEIGHT - 4)

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
	local lights = Widgets.Panel(root, 0.15)
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
		Widgets.Corner(dot, LIGHT_SIZE)
		dot.Parent = lights
		self.LightDots[i] = dot
	end

	-- Alerte du joker : à l'approche de l'entrée, tant qu'il reste à faire.
	local prompt = Widgets.Label(root, "", 40, Enum.Font.GothamBlack, Theme.TEXT)
	prompt.FontFace = Theme.SFX
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.fromScale(0.5, 0.28)
	prompt.Size = UDim2.fromOffset(0, 54)
	prompt.AutomaticSize = Enum.AutomaticSize.X
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.BackgroundColor3 = COLOR_JOKER_DUE
	prompt.BackgroundTransparency = 0
	prompt.Rotation = -2
	prompt.Visible = false
	local promptPadding = Instance.new("UIPadding")
	promptPadding.PaddingLeft = UDim.new(0, 18)
	promptPadding.PaddingRight = UDim.new(0, 18)
	promptPadding.Parent = prompt
	Theme.TextInk(prompt, 3)
	Theme.Slant(prompt)
	self.JokerPrompt = prompt
	self.JokerSide = {}

	-- Message ---------------------------------------------------------------------
	-- Lettrage de manga encré : « DERNIER TOUR ! », « DRAPEAU À DAMIER ».
	local message = Widgets.Label(root, "", 52, Enum.Font.GothamBlack)
	message.FontFace = Theme.SFX
	message.Rotation = -2
	Theme.TextInk(message, 3)
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.36)
	message.Size = UDim2.fromOffset(900, 64)
	message.TextXAlignment = Enum.TextXAlignment.Center
	-- Messages longs (arrivée, podium) : réduits pour tenir sur une ligne.
	message.TextScaled = true
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 52
	sizeLimit.Parent = message
	message.Visible = false
	self.Message = message

	-- Résultats --------------------------------------------------------------------
	local results = Widgets.Panel(root, 0.08)
	results.AnchorPoint = Vector2.new(0.5, 0.5)
	results.Position = UDim2.fromScale(0.5, 0.52)
	results.Size = UDim2.fromOffset(560, 80 + MAX_ROWS * 30)
	results.Visible = false
	self.Results = results
	-- Tableau des résultats : damier en tête, titre en capitales condensées.
	local resultsChecker = Theme.Checker(results, 600, 5, 2)
	resultsChecker.BackgroundTransparency = 0.2
	self.ResultsTitle = Widgets.Label(results, "", 24, Enum.Font.GothamBlack)
	self.ResultsTitle.Position = UDim2.fromOffset(16, 12)
	self.ResultsTitle.Size = UDim2.new(1, -32, 0, 28)
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(16, 42)
	rows.Size = UDim2.new(1, -32, 0, MAX_ROWS * 30)
	rows.Parent = results
	self.ResultsRows = rows
	self.ResultsFooter = Widgets.Label(results, "", 13, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
	self.ResultsFooter.Position = UDim2.new(0, 16, 1, -34)
	self.ResultsFooter.Size = UDim2.new(1, -220, 0, 28)
	self.ResultsFooter.TextWrapped = true
	self.ResultsData = nil
	-- Revanche : la salle reste ouverte pour ceux qui votent (RaceService).
	local rematch = Widgets.Button(results, "REVANCHE", function()
		callbacks.Rematch()
	end)
	rematch.AnchorPoint = Vector2.new(1, 1)
	rematch.Position = UDim2.new(1, -16, 1, -10)
	rematch.Size = UDim2.fromOffset(190, 34)
	rematch.TextSize = 16
	Widgets.Primary(rematch)
	rematch.Visible = false
	self.RematchButton = rematch
	self.RematchVoted = false

	-- Salle d'attente (on est dans la zone d'un circuit, au paddock) -------------------
	local banner = Widgets.Panel(root, 0.15)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Size = UDim2.fromOffset(560, 62)
	banner.Visible = false
	self.LobbyBanner = banner
	local lobbyLabel = Widgets.Label(banner, "", 18, Enum.Font.GothamBold)
	lobbyLabel.RichText = true
	lobbyLabel.TextXAlignment = Enum.TextXAlignment.Center
	lobbyLabel.Position = UDim2.fromOffset(12, 0)
	lobbyLabel.Size = UDim2.new(1, -24, 1, 0)
	self.LobbyLabel = lobbyLabel

	-- Spectateur ------------------------------------------------------------------
	local bar = Widgets.Panel(root, 0.2)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.Size = UDim2.fromOffset(470, 48)
	bar.Visible = false
	self.SpectateBar = bar
	self.SpectateLabel = Widgets.Label(bar, "", 15, Enum.Font.GothamBold)
	self.SpectateLabel.Position = UDim2.fromOffset(14, 0)
	self.SpectateLabel.Size = UDim2.new(1, -200, 1, 0)
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -8, 0.5, 0)
	buttons.Size = UDim2.fromOffset(180, 34)
	buttons.Parent = bar
	self.SpectateButtons = buttons
	local previous = Widgets.Button(buttons, "◀", function()
		callbacks.SpectateNext(-1)
	end)
	previous.Size = UDim2.fromOffset(40, 34)
	local nextButton = Widgets.Button(buttons, "▶", function()
		callbacks.SpectateNext(1)
	end)
	nextButton.Position = UDim2.fromOffset(46, 0)
	nextButton.Size = UDim2.fromOffset(40, 34)
	local stop = Widgets.Button(buttons, "RETOUR", function()
		callbacks.StopSpectate()
	end)
	stop.Position = UDim2.fromOffset(92, 0)
	stop.Size = UDim2.fromOffset(88, 34)
	stop.TextSize = 12
	local watch = Widgets.Button(bar, "REGARDER LA COURSE (V)", function()
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

-- Applique le réglage de la mini-carte tout de suite (sinon à la prochaine course).
function RaceHud:RefreshMinimap()
	local race = self.Race
	self.MinimapHolder.Visible = race ~= nil and race.State ~= "Lobby" and RaceHud.ShowMinimap
end

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
	-- Avec le streaming, le portique peut ne pas être encore chargé (ou avoir été
	-- déchargé) : on ne garde la liste que si les cinq feux sont bien là.
	local cached = self.GantryLights
	if self.GantryTrack == trackId and #cached == 5 and cached[1].Parent ~= nil then
		return cached
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
function RaceHud:SetRace(race: RaceTypes.RaceSnapshot?)
	self.Race = race
	self.Gui.Enabled = race ~= nil or os.clock() < self.PodiumUntil
	self.JokerPrompt.Visible = false
	self.JokerHint = nil
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
	self.MinimapHolder.Visible = not inLobby and RaceHud.ShowMinimap
	if inLobby then
		self.Live = nil
		self:HideResults()
	end
	if race.State == "Grid" then
		self:HideResults()
		self:ShowMessage("MISE EN GRILLE…", Widgets.COLOR_TEXT, 3)
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

function RaceHud:SetLive(payload: RaceTypes.LivePayload)
	local race = self.Race
	if race and payload.Id == race.Id then
		self.Live = payload
	end
end

function RaceHud:ShowMessage(text: string, color: Color3?, duration: number?)
	self.Message.TextColor3 = color or Widgets.COLOR_TEXT
	if not self.Message.Visible or self.Message.Text ~= text then
		Theme.Pop(self.Message, 1, 0.5) -- le message jaillit
	end
	self.Message.Text = text
	self.Message.Visible = true
	self.MessageUntil = os.clock() + (duration or MESSAGE_TIME)
end

function RaceHud:ShowResults(results: RaceTypes.Results)
	self.ResultsData = results
	local trackName = ""
	local circuit = Tracks.Get(results.TrackId)
	if circuit then
		trackName = " · " .. Format.Upper(circuit.Name)
	end
	self.ResultsTitle.Text = (if results.Final then "RÉSULTATS · " else "") .. results.RoundName .. trackName
	for _, child in ipairs(self.ResultsRows:GetChildren()) do
		child:Destroy()
	end
	for index, row in ipairs(results.Rows) do
		if index > MAX_ROWS then
			break
		end
		local label = Widgets.Label(self.ResultsRows, "", 16, Enum.Font.RobotoMono)
		label.Position = UDim2.fromOffset(0, (index - 1) * 30)
		label.Size = UDim2.new(1, 0, 0, 28)
		label.RichText = true
		-- Lignes alternées, la sienne surlignée en rose.
		local mine = row.UserId == self.LocalUserId
		label.BackgroundColor3 = if mine then Theme.ACCENT else Theme.PANEL_2
		label.BackgroundTransparency = if mine then 0.45 elseif index % 2 == 1 then 0.55 else 1
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.Parent = label
		local name = row.Name
		if (utf8.len(name) or #name) > 14 then
			local cut = utf8.offset(name, 14)
			name = (if cut then string.sub(name, 1, cut - 1) else name) .. "…"
		end
		local padding = string.rep(" ", math.max(0, 15 - (utf8.len(name) or #name)))
		local timeText = if row.Dnf then Format.Upper(row.DnfReason or "abandon") else Format.Time(row.TotalTime)
		local penalty = if row.Penalty > 0 and not row.Dnf then string.format(" (+%gs)", row.Penalty) else ""
		local best = if row.BestLap then "  t. " .. Format.Time(row.BestLap) else ""
		local points = if results.Final and row.Points > 0 then string.format("  +%d pts", row.Points) else ""
		label.Text = string.format("%d. %s%s%s%s%s%s", row.Position, name, padding, timeText, penalty, best, points)
		label.TextColor3 = Widgets.COLOR_TEXT
	end
	self.Results.Size = UDim2.fromOffset(560, 96 + math.min(#results.Rows, MAX_ROWS) * 30)
	self.Results.Visible = true
	-- Dernière manche : on peut voter pour la revanche.
	self.RematchVoted = false
	self.RematchButton.Visible = results.Final
	self.RematchButton.Text = "REVANCHE"
	if results.Final and UserInputService.GamepadEnabled and not self.TouchLayout then
		GuiService.SelectedObject = self.RematchButton
	end
end

-- Votes pour la revanche : `voted` = son propre vote.
function RaceHud:SetRematch(votes: number, members: number, voted: boolean)
	self.RematchVoted = voted
	self.RematchButton.Text = string.format("%s (%d/%d)", if voted then "REVANCHE ✓" else "REVANCHE", votes, members)
end

-- Cérémonie du podium (après le retour au paddock, hors course).
function RaceHud:ShowPodium(names: { string }, duration: number)
	self.PodiumUntil = os.clock() + duration
	self.Gui.Enabled = true
	local parts = {}
	for index, name in ipairs(names) do
		table.insert(parts, string.format("%d. %s", index, name))
	end
	self:ShowMessage("PODIUM · " .. table.concat(parts, "   "), Widgets.COLOR_ACCENT, duration)
end

function RaceHud:HideResults()
	self.ResultsData = nil
	self.Results.Visible = false
	self.RematchButton.Visible = false
	if GuiService.SelectedObject == self.RematchButton then
		GuiService.SelectedObject = nil
	end
end

function RaceHud:SetSpectate(state: SpectateState)
	self.SpectateBar.Visible = self.Gui.Enabled and (state.Available or state.Active)
	self.SpectateButtons.Visible = state.Active
	self.WatchButton.Visible = state.Available and not state.Active
	self.SpectateLabel.Text = if state.Active then "SPECTATEUR · " .. state.Name else "COURSE TERMINÉE POUR TOI"
end

--------------------------------------------------------------------------------
-- Mise à jour
--------------------------------------------------------------------------------

function RaceHud:_myRow(): RaceTypes.LiveRow?
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

-- Bip des feux de départ (SoundBank.StartLights) : sans spatialisation, chacun
-- n'entend que ceux de sa course.
function RaceHud:_lightSound(kind: string)
	local spec = SoundBank.StartLights[kind]
	if not spec or spec.Id == "" then
		return
	end
	local sound = self.LightSounds[kind]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "StartLight" .. kind
		sound.SoundId = spec.Id
		sound.Volume = spec.Volume
		sound.PlaybackSpeed = spec.Pitch
		sound.SoundGroup = SoundGroups.Get("Effets")
		sound.Parent = SoundService
		self.LightSounds[kind] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

function RaceHud:_updateLights(race: RaceTypes.RaceSnapshot, serverNow: number)
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
	-- Un bip par feu rouge qui s'allume, le signal du départ au vert. Hors du
	-- décompte et du vert, tout est réarmé pour la course suivante.
	if green then
		if not self.LightsGreen then
			self.LightsGreen = true
			self:_lightSound("Green")
		end
	elseif visible then
		if lit > self.LightsLit then
			self:_lightSound("Red")
		end
		self.LightsLit = lit
		self.LightsGreen = false
	else
		self.LightsLit = 0
		self.LightsGreen = false
	end
	for i, dot in ipairs(self.LightDots) do
		dot.BackgroundColor3 = if green then COLOR_LIGHT_GREEN elseif i <= lit then COLOR_LIGHT_RED else COLOR_LIGHT_OFF
	end
	-- Feux du portique (modifiés localement : chacun voit ceux de sa course).
	for i, light in ipairs(self:_gantryLights(race.TrackId)) do
		light.Color = if green then COLOR_LIGHT_GREEN elseif visible and i <= lit then COLOR_LIGHT_RED else COLOR_LIGHT_OFF
	end
end

-- Son joker : vert une fois fait ; tant qu'il reste à faire, orange et clignotant.
function RaceHud:_setJokerChip(done: boolean)
	local chip = self.JokerChip
	if done then
		chip.Text = "JOKER ✓"
		chip.BackgroundColor3 = COLOR_JOKER_DONE
		chip.BackgroundTransparency = 0
	else
		chip.Text = "⚠ JOKER À FAIRE"
		chip.BackgroundColor3 = COLOR_JOKER_DUE
		chip.BackgroundTransparency = if (os.clock() * 2) % 1 < 0.5 then 0 else 0.45
	end
end

-- Côté de la branche joker par rapport à la boucle, à son entrée (+1 gauche, -1 droite).
function RaceHud:_jokerSide(trackId: string, circuit: Circuit.Circuit): number
	local known = self.JokerSide[trackId]
	if known then
		return known
	end
	local main = circuit:SampleAt(circuit.JokerStartProgress)
	local joker = circuit.JokerSamples[math.min(#circuit.JokerSamples, 12)]
	local side = if joker and (joker.Position - main.Position):Dot(main.Left) < 0 then -1 else 1
	self.JokerSide[trackId] = side
	return side
end

--[[
	Alerte du joker : tant qu'on ne l'a pas fait, à l'approche de son entrée
	(JOKER_PROMPT_DISTANCE studs avant), une grande étiquette orange dit de
	quel côté il part ; sur la branche, « JOKER EN COURS ».
]]
function RaceHud:_updateJokerPrompt(race: RaceTypes.RaceSnapshot, cars: { Minimap.CarDot }, me: RaceTypes.LiveRow?)
	local prompt = self.JokerPrompt
	local position: Vector3? = nil
	for _, car in ipairs(cars) do
		if car.Me then
			position = car.Position
		end
	end
	local circuit = Tracks.Get(race.TrackId)
	if race.State ~= "Racing" or not me or me.J > 0 or me.F or me.D or not position or not circuit then
		prompt.Visible = false
		return
	end
	local location = circuit:Locate(position :: Vector3, self.JokerHint)
	self.JokerHint = location
	local text: string? = nil
	if location.OnJoker then
		text = "JOKER EN COURS"
	else
		local ahead = (circuit.JokerStartProgress - location.Progress) % circuit.Length
		if ahead <= JOKER_PROMPT_DISTANCE then
			local lastLap = me.L + 1 >= race.Laps
			local side = if self:_jokerSide(race.TrackId, circuit) > 0 then "← JOKER À GAUCHE" else "JOKER À DROITE →"
			text = (if lastLap then "DERNIÈRE CHANCE · " else "") .. side
		end
	end
	prompt.Visible = text ~= nil
	if text then
		prompt.Text = text
		-- Clignote entre l'orange et le jaune : impossible à rater.
		prompt.BackgroundColor3 = if (os.clock() * 3) % 1 < 0.5 then COLOR_JOKER_DUE else Theme.YELLOW
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
		local name = if circuit then Format.Upper(circuit.Name) else race.TrackId
		local countdown = if race.AutoStartAt
			then string.format("départ dans <b>%d s</b>", math.max(0, math.ceil((race.AutoStartAt :: number) - serverNow)))
			else string.format("en attente d'un %de pilote", race.MinPlayers)
		self.LobbyLabel.Text = string.format(
			'%s · %d/%d pilotes · %s\n<font size="13" color="#8288A0">%d tours · %s · C : menu (réglages, quitter)</font>',
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
	local roundText = race.RoundName .. (if circuit then " · " .. Format.Upper(circuit.Name) else "")
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
			self.LapTimeLabel.Text = Format.Time(me.T)
		elseif race.State == "Racing" then
			self.LapTimeLabel.Text = Format.Time(serverNow - me.LS)
		else
			self.LapTimeLabel.Text = Format.Time(0)
		end
		self:_setJokerChip(me.J > 0 or me.F)
		self.PenaltyChip.Visible = me.PEN > 0
		self.PenaltyChip.Text = string.format("PÉNALITÉ +%g s", me.PEN)
		self.BottomLabel.Text = string.format("MEILLEUR %s   DERNIER %s", Format.Time(me.B), Format.Time(me.LL))
	else
		self.PositionLabel.Text = positionText(0, count)
		self.LapLabel.Text = string.format("TOUR 1/%d", race.Laps)
		self.LapTimeLabel.Text = Format.Time(0)
		self:_setJokerChip(false)
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
				gap = "-"
			end
			label.Text = string.format("%d %s%s%s", row.P, name, padding, gap)
			local mine = row.U == self.LocalUserId
			label.TextColor3 = Widgets.COLOR_TEXT
			label.BackgroundTransparency = if mine then 0.45 else 1
			-- Joker : fait (vert), à faire (orange) ; rien après un abandon.
			local badge = self.JokerBadges[i]
			badge.Visible = not row.D
			badge.Text = if row.J > 0 then "J ✓" else "J"
			badge.BackgroundColor3 = if row.J > 0 then COLOR_JOKER_DONE else COLOR_JOKER_DUE
		else
			label.Text = ""
			label.BackgroundTransparency = 1
			self.JokerBadges[i].Visible = false
		end
	end

	self:_updateJokerPrompt(race, cars, me)
	local map = self.Minimap
	if map then
		map:SetJokerDone(me ~= nil and me.J > 0)
	end

	local results = self.ResultsData
	if results and self.Results.Visible then
		local remaining = math.max(0, math.ceil(results.NextAt - serverNow))
		self.ResultsFooter.Text = if results.Final
			then string.format("Retour au paddock dans %d s. REVANCHE : la salle reste ouverte pour ceux qui votent.", remaining)
			else string.format("%s dans %d s · grille dans l'ordre de ce classement", results.NextRoundName or "Manche suivante", remaining)
	end
end

return RaceHud
