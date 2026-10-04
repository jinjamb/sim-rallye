--!strict
--[[
	RaceMenu.luau
	Le lobby du rallycross : C (ou croix directionnelle droite, ou bouton
	COURSES sur mobile) ouvre et ferme.

	HORS COURSE :
		- créer une course : circuit, nombre de tours, format (course simple, ou
		  manche qualificative + finale), contacts entre voitures ;
		- rejoindre une course ouverte (2 à 6 pilotes) ;
		- records du tour de chaque circuit, et sa carrière (courses, victoires,
		  podiums, points).
	DANS UNE COURSE :
		- salle d'attente : pilotes, prêts ou non, hôte ; PRÊT, LANCER (hôte),
		  QUITTER. Départ automatique quand tout le monde est prêt ;
		- pendant la course : ABANDONNER.

	Le contenu est reconstruit à chaque changement d'état (il change rarement) ;
	seuls les comptes à rebours sont rafraîchis à chaque frame.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local RaceUi = require(script.Parent.RaceUi)

local RaceMenu = {}
RaceMenu.__index = RaceMenu

export type Data = {
	Lobby: { RaceUi.LobbyRace },
	Race: RaceUi.RaceSnapshot?,
	Records: { [string]: RaceUi.TrackBoard },
	Stats: RaceUi.Stats?,
	Laps: { [string]: number },
}

export type RaceMenu = typeof(setmetatable({}, RaceMenu)) & {
	Action: (string, any) -> (),
	LocalUserId: number,
	Gui: ScreenGui,
	Panel: Frame,
	Body: ScrollingFrame,
	Scale: UIScale,
	TouchLayout: boolean,
	Data: Data,
	Status: string,
	StatusColor: Color3,

	-- Formulaire de création
	TrackIndex: number,
	Laps: number,
	Format: string,
	Contacts: boolean,

	CountdownLabel: TextLabel?,
	FirstButton: GuiButton?,
}

local PANEL_WIDTH = 540
local HEADER_HEIGHT = 44
local ROW_HEIGHT = 30
local SCREEN_PADDING = 24
local TOUCH_SCALE = 1.1
local MIN_LAPS, MAX_LAPS = 2, 8

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function trackName(id: string): string
	local circuit = Tracks.Get(id)
	return if circuit then circuit.Name else id
end

local function formatName(format: string): string
	return if format == "Event" then "Qualif + finale" else "Course simple"
end

function RaceMenu.new(playerGui: Instance, localUserId: number, action: (string, any) -> ()): RaceMenu
	local self = (setmetatable({}, RaceMenu) :: any) :: RaceMenu
	self.Action = action
	self.LocalUserId = localUserId
	self.TouchLayout = false
	self.Data = { Lobby = {}, Race = nil, Records = {}, Stats = nil, Laps = {} }
	self.Status = ""
	self.StatusColor = RaceUi.COLOR_DIM
	self.TrackIndex = 1
	local first = Tracks.Get(Tracks.List()[1])
	self.Laps = if first then first.DefaultLaps else 4
	self.Format = "Sprint"
	self.Contacts = true
	self.CountdownLabel = nil
	self.FirstButton = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceMenu"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 11
	self.Gui = gui

	local panel = RaceUi.Panel(gui, 0.08)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 600)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Panel = panel
	self.Scale = scale

	local title = RaceUi.Label(panel, "RALLYCROSS", 18, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -70, 0, 24)
	local close = RaceUi.Button(panel, "×", function()
		self:SetOpen(false)
	end)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Size = UDim2.fromOffset(32, 28)
	close.TextSize = 18

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = body
	self.Body = body

	gui.Parent = playerGui
	self:_rebuild()
	return self
end

--------------------------------------------------------------------------------
-- Construction du contenu
--------------------------------------------------------------------------------

type Builder = {
	Order: number,
	Row: (Builder, number?) -> Frame,
	Section: (Builder, string) -> (),
	Text: (Builder, string, number?, Color3?) -> TextLabel,
}

function RaceMenu:_builder(): Builder
	local body = self.Body
	local builder = { Order = 0 } :: any
	function builder.Row(b: Builder, height: number?): Frame
		b.Order += 1
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, height or ROW_HEIGHT)
		row.LayoutOrder = b.Order
		row.Parent = body
		return row
	end
	function builder.Section(b: Builder, text: string)
		local row = b:Row(26)
		local label = RaceUi.Label(row, string.upper(text), 12, Enum.Font.GothamBold, RaceUi.COLOR_ACCENT)
		label.Position = UDim2.fromOffset(0, 8)
		label.Size = UDim2.new(1, 0, 0, 18)
	end
	function builder.Text(b: Builder, text: string, textSize: number?, color: Color3?): TextLabel
		local row = b:Row(20)
		local label = RaceUi.Label(row, text, textSize or 14, Enum.Font.GothamMedium, color or RaceUi.COLOR_TEXT)
		label.Size = UDim2.new(1, 0, 0, 20)
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		row.AutomaticSize = Enum.AutomaticSize.Y
		return label
	end
	return builder :: Builder
end

function RaceMenu:_button(parent: Instance, text: string, x: number, width: number, callback: () -> ()): TextButton
	local button = RaceUi.Button(parent, text, callback)
	button.Position = UDim2.fromOffset(x, 0)
	button.Size = UDim2.new(0, width, 1, 0)
	if not self.FirstButton then
		self.FirstButton = button
	end
	return button
end

-- Ligne "libellé  [−] valeur [+]".
function RaceMenu:_stepper(b: Builder, label: string, value: string, onStep: (number) -> ())
	local row = b:Row()
	local text = RaceUi.Label(row, label, 14)
	text.Size = UDim2.new(0, 200, 1, 0)
	local width = PANEL_WIDTH - 32
	self:_button(row, "◀", width - 240, 40, function()
		onStep(-1)
	end)
	local valueLabel = RaceUi.Label(row, value, 14, Enum.Font.GothamBold)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Position = UDim2.fromOffset(width - 196, 0)
	valueLabel.Size = UDim2.new(0, 152, 1, 0)
	self:_button(row, "▶", width - 40, 40, function()
		onStep(1)
	end)
end

function RaceMenu:_records(b: Builder, trackId: string)
	local circuit = Tracks.Get(trackId)
	if not circuit then
		return
	end
	local board = self.Data.Records[trackId]
	local mine = self.Data.Laps[circuit.Key]
	b:Text(string.format("%s — ton record : %s", circuit.Name, if mine then RaceUi.FormatTime(mine / 1000) else "aucun"), 14, RaceUi.COLOR_TEXT)
	if board and #board.Entries > 0 then
		for index, entry in ipairs(board.Entries) do
			local color = if entry.UserId == self.LocalUserId then RaceUi.COLOR_ACCENT else RaceUi.COLOR_DIM
			local label = b:Text(string.format("   %d. %s  %s", index, entry.Name, RaceUi.FormatTime(entry.Ms / 1000)), 13, color)
			label.Font = Enum.Font.RobotoMono
		end
	else
		b:Text("   Pas encore de record.", 13, RaceUi.COLOR_DIM)
	end
end

function RaceMenu:_buildLobby(b: Builder)
	local ids = Tracks.List()
	self.TrackIndex = math.clamp(self.TrackIndex, 1, #ids)
	local trackId = ids[self.TrackIndex]
	local circuit = Tracks.Get(trackId)

	b:Section("Créer une course")
	self:_stepper(b, "Circuit", if circuit then circuit.Name else trackId, function(direction)
		self.TrackIndex = ((self.TrackIndex - 1 + direction) % #ids) + 1
		local selected = Tracks.Get(ids[self.TrackIndex])
		if selected then
			self.Laps = selected.DefaultLaps
		end
		self:_rebuild()
	end)
	if circuit then
		b:Text(circuit.Description, 13, RaceUi.COLOR_DIM)
	end
	self:_stepper(b, "Tours", tostring(self.Laps), function(direction)
		self.Laps = math.clamp(self.Laps + direction, MIN_LAPS, MAX_LAPS)
		self:_rebuild()
	end)
	self:_stepper(b, "Format", formatName(self.Format), function(_direction)
		self.Format = if self.Format == "Sprint" then "Event" else "Sprint"
		self:_rebuild()
	end)
	self:_stepper(b, "Contacts entre voitures", if self.Contacts then "Oui" else "Non", function(_direction)
		self.Contacts = not self.Contacts
		self:_rebuild()
	end)
	local createRow = b:Row(36)
	local create = self:_button(createRow, "CRÉER LA COURSE", 0, PANEL_WIDTH - 32, function()
		self.Action("Create", { TrackId = trackId, Laps = self.Laps, Format = self.Format, Contacts = self.Contacts })
	end)
	create.BackgroundColor3 = Color3.fromRGB(40, 120, 60)

	b:Section("Courses")
	local lobby = self.Data.Lobby
	if #lobby == 0 then
		b:Text("Aucune course pour l'instant : crée la première !", 13, RaceUi.COLOR_DIM)
	end
	for _, race in ipairs(lobby) do
		local row = b:Row(34)
		local open = race.State == "Lobby" and race.Count < race.Max
		local stateText = if race.State == "Lobby" then "en attente" else "en course"
		local text = RaceUi.Label(row, string.format(
			"%s · %d tours · %s%s\n%d/%d pilotes · hôte %s · %s",
			trackName(race.TrackId),
			race.Laps,
			formatName(race.Format),
			if race.Contacts then " · contacts" else "",
			race.Count,
			race.Max,
			race.Host,
			stateText
		), 13)
		text.Size = UDim2.new(1, -130, 1, 0)
		local join = self:_button(row, if open then "REJOINDRE" else "—", PANEL_WIDTH - 32 - 120, 120, function()
			if open then
				self.Action("Join", { RaceId = race.Id })
			end
		end)
		join.AutoButtonColor = open
		join.TextColor3 = if open then RaceUi.COLOR_TEXT else RaceUi.COLOR_DIM
	end

	b:Section("Records du tour")
	for _, id in ipairs(ids) do
		self:_records(b, id)
	end

	b:Section("Ta carrière")
	local stats = self.Data.Stats
	if stats then
		b:Text(string.format(
			"Courses %d · Victoires %d · Podiums %d · Points %d",
			stats.Races,
			stats.Wins,
			stats.Podiums,
			stats.Points
		), 14)
	else
		b:Text("Chargement…", 13, RaceUi.COLOR_DIM)
	end
	b:Text("Points : 10, 8, 6, 4, 2, 1 du 1er au 6e (finale, ou course simple).", 12, RaceUi.COLOR_DIM)
end

function RaceMenu:_buildRace(b: Builder, race: RaceUi.RaceSnapshot)
	local isHost = race.HostUserId == self.LocalUserId
	b:Section(trackName(race.TrackId))
	b:Text(string.format(
		"%d tours · %s · contacts %s",
		race.Laps,
		formatName(race.Format),
		if race.Contacts then "activés" else "désactivés"
	), 14)

	local stateText: string
	if race.State == "Lobby" then
		stateText = string.format("En attente des pilotes (%d/%d)", #race.Members, race.MaxPlayers)
	elseif race.State == "Grid" or race.State == "Countdown" then
		stateText = race.RoundName .. " — départ imminent"
	elseif race.State == "Racing" then
		stateText = race.RoundName .. " — en cours"
	else
		stateText = race.RoundName .. " — résultats"
	end
	b:Text(stateText, 14, RaceUi.COLOR_ACCENT)
	self.CountdownLabel = b:Text("", 14, RaceUi.COLOR_GREEN)

	b:Section("Pilotes")
	for _, member in ipairs(race.Members) do
		local ready = if race.State == "Lobby" then (if member.Ready then "  ✓ prêt" else "  pas prêt") else ""
		local host = if member.UserId == race.HostUserId then "★ " else "   "
		local color = if member.UserId == self.LocalUserId then RaceUi.COLOR_ACCENT else RaceUi.COLOR_TEXT
		b:Text(host .. member.Name .. ready, 15, color)
	end

	local row = b:Row(36)
	local width = PANEL_WIDTH - 32
	if race.State == "Lobby" then
		local me: RaceUi.RaceMember? = nil
		for _, member in ipairs(race.Members) do
			if member.UserId == self.LocalUserId then
				me = member
			end
		end
		local ready = me ~= nil and me.Ready
		local third = (width - 16) / 3
		local readyButton = self:_button(row, if ready then "PAS PRÊT" else "PRÊT", 0, third, function()
			self.Action("Ready", { Ready = not ready })
		end)
		readyButton.BackgroundColor3 = if ready then RaceUi.COLOR_BUTTON else Color3.fromRGB(40, 120, 60)
		if isHost then
			local canStart = #race.Members >= race.MinPlayers
			local start = self:_button(row, "LANCER", third + 8, third, function()
				if canStart then
					self.Action("Start", nil)
				end
			end)
			start.TextColor3 = if canStart then RaceUi.COLOR_TEXT else RaceUi.COLOR_DIM
		end
		self:_button(row, "QUITTER", 2 * (third + 8), third, function()
			self.Action("Leave", nil)
		end)
		b:Text(
			if isHost
				then "Tu es l'hôte : LANCER part sans attendre que tout le monde soit prêt."
				else "Le départ est donné quand tout le monde est prêt, ou par l'hôte.",
			12,
			RaceUi.COLOR_DIM
		)
	else
		local abandon = self:_button(row, "ABANDONNER", 0, width, function()
			self.Action("Abandon", nil)
		end)
		abandon.BackgroundColor3 = Color3.fromRGB(130, 40, 35)
	end

	b:Section("Records du tour")
	self:_records(b, race.TrackId)
end

function RaceMenu:_rebuild()
	for _, child in ipairs(self.Body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.CountdownLabel = nil
	self.FirstButton = nil
	local b = self:_builder()
	if self.Status ~= "" then
		b:Text(self.Status, 13, self.StatusColor)
	end
	local race = self.Data.Race
	if race then
		self:_buildRace(b, race)
	else
		self:_buildLobby(b)
	end
	if self.Gui.Enabled and not self.TouchLayout then
		GuiService.SelectedObject = self.FirstButton
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function RaceMenu:SetData(data: Data)
	local previousRace = self.Data.Race
	self.Data = data
	-- Entrée dans une course, ou sortie : le message d'erreur n'a plus lieu d'être.
	if (previousRace == nil) ~= (data.Race == nil) then
		self.Status = ""
	end
	self:_rebuild()
end

function RaceMenu:SetStatus(text: string, color: Color3?)
	self.Status = text
	self.StatusColor = color or RaceUi.COLOR_DIM
	self:_rebuild()
end

function RaceMenu:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
end

function RaceMenu:IsOpen(): boolean
	return self.Gui.Enabled
end

function RaceMenu:SetOpen(open: boolean)
	self.Gui.Enabled = open
	if open then
		local viewport = workspace.CurrentCamera.ViewportSize
		local scale = if self.TouchLayout then TOUCH_SCALE * math.clamp(viewport.Y / 500, 0.6, 1) else math.clamp(viewport.Y / 1080, 0.6, 1.2)
		self.Scale.Scale = scale
		local available = (viewport.Y - SCREEN_PADDING) / scale
		self.Panel.Size = UDim2.fromOffset(PANEL_WIDTH, math.min(720, available))
		if not self.TouchLayout then
			GuiService.SelectedObject = self.FirstButton
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
		GuiService.SelectedObject = nil
	end
end

function RaceMenu:Toggle()
	self:SetOpen(not self:IsOpen())
end

-- Comptes à rebours (départ automatique).
function RaceMenu:Update()
	local label = self.CountdownLabel
	local race = self.Data.Race
	if not label or not race then
		return
	end
	if race.State == "Lobby" and race.AutoStartAt then
		label.Text = string.format("Tout le monde est prêt : départ dans %d s", math.max(0, math.ceil((race.AutoStartAt :: number) - serverNow())))
	elseif race.State == "Lobby" and #race.Members < race.MinPlayers then
		label.Text = string.format("Il faut au moins %d pilotes.", race.MinPlayers)
	else
		label.Text = ""
	end
end

return RaceMenu
