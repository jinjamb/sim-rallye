--!strict
--[[
	RaceMenu.luau
	Le menu principal : C (ou croix directionnelle droite, ou bouton MENU sur
	mobile) ouvre et ferme ; il s'ouvre aussi à l'arrivée dans le jeu, et au
	retour d'une course.

	HORS COURSE :
		- DÉFI DE LA SEMAINE : la contrainte, le temps qu'il reste, le podium
		  de la semaine, son temps, et RELEVER LE DÉFI ;
		- DÉFIS DU JOUR : les trois objectifs, leur progression, l'XP ;
		- ÉCOLE DE PILOTAGE : les leçons et leur médaille (en tête du menu
		  pour un débutant) ;
		- JOUER : lancer une spéciale ; une course de rallycross (un bouton par
		  circuit : on ouvre la salle d'attente, ou on rejoint celle qui attend) ;
		  des essais libres ; retour au paddock ;
		- sa livrée : couleur de carrosserie et numéro ;
		- records du tour de chaque circuit, ses médailles (Medals.luau) et
		  sa carrière.
	EN SALLE D'ATTENTE :
		- pilotes, compte à rebours ;
		- l'hôte (premier arrivé) règle tours, format, contacts, et peut lancer
		  sans attendre ;
		- QUITTER (ou sortir de la zone).
	PENDANT LA COURSE : ABANDONNER.

	Le contenu est reconstruit à chaque changement d'état (il change rarement) ;
	seuls les comptes à rebours sont rafraîchis à chaque frame.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Livery = require(ReplicatedStorage.Shared.Constants.Livery)
local Medals = require(ReplicatedStorage.Shared.Constants.Medals)
local Progression = require(ReplicatedStorage.Shared.Constants.Progression)
local Weekly = require(ReplicatedStorage.Shared.Constants.Weekly)
local Lessons = require(ReplicatedStorage.Shared.Constants.Lessons)
local RaceUi = require(script.Parent.RaceUi)
local Theme = require(script.Parent.Parent.UI.Theme)

local RaceMenu = {}
RaceMenu.__index = RaceMenu

export type Data = {
	Lobby: { RaceUi.LobbyRace },
	Race: RaceUi.RaceSnapshot?,
	Records: { [string]: RaceUi.TrackBoard },
	Stats: RaceUi.Stats?,
	Progress: Progression.Snapshot?,
	Weekly: any, -- { Key, Modifier, EndsAt, Entries, Mine } (RecordService)
	Daily: any, -- { EndsAt, Challenges = { Id, Text, Goal, Progress, Done }, Bonus, Xp, BonusXp }
	Laps: { [string]: number },
	Livery: Livery.Livery?,
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
	CountdownLabel: TextLabel?,
	FirstButton: GuiButton?,
	-- Données changées menu fermé : reconstruit à la prochaine ouverture.
	Dirty: boolean,
}

local PANEL_WIDTH = 540
local HEADER_HEIGHT = 70 -- en-tête du jeu : titre, sous-titre, damier
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
	self.Data = { Lobby = {}, Race = nil, Records = {}, Stats = nil, Progress = nil, Weekly = nil, Daily = nil, Laps = {}, Livery = nil }
	self.Status = ""
	self.StatusColor = RaceUi.COLOR_DIM
	self.CountdownLabel = nil
	self.FirstButton = nil
	self.Dirty = false

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

	-- En-tête du jeu : le titre en capitales condensées, une étiquette jaune,
	-- un filet à damier dessous.
	local title = RaceUi.Label(panel, "SIM RALLYE", 30, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(18, 8)
	title.Size = UDim2.fromOffset(170, 38)
	local tag = Theme.Tag(panel, "SPÉCIALE · RALLYCROSS", Theme.ACCENT, Theme.ON_ACCENT, 13)
	tag.Position = UDim2.fromOffset(176, 17)
	local checker = Theme.Checker(panel, PANEL_WIDTH, 5, 2)
	checker.Position = UDim2.fromOffset(0, HEADER_HEIGHT - 14)
	checker.BackgroundTransparency = 0.2
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
	-- Titre de section façon télévision : un pavé jaune, des capitales condensées.
	function builder.Section(b: Builder, text: string)
		local row = b:Row(34)
		local mark = Instance.new("Frame")
		mark.BorderSizePixel = 0
		mark.BackgroundColor3 = Theme.ACCENT
		mark.Position = UDim2.fromOffset(0, 12)
		mark.Size = UDim2.fromOffset(6, 18)
		mark.Parent = row
		local label = RaceUi.Label(row, string.upper(text), 19, Enum.Font.GothamBlack, RaceUi.COLOR_TEXT)
		label.Position = UDim2.fromOffset(14, 10)
		label.Size = UDim2.new(1, -14, 0, 22)
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

-- Ligne "libellé  [◀] valeur [▶]". Renvoie l'étiquette de la valeur.
function RaceMenu:_stepper(b: Builder, label: string, value: string, onStep: (number) -> ()): TextLabel
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
	return valueLabel
end

function RaceMenu:_records(b: Builder, trackId: string)
	local circuit = Tracks.Get(trackId)
	if not circuit then
		return
	end
	local board = self.Data.Records[trackId]
	local mine = self.Data.Laps[circuit.Key]
	-- Son record, sa médaille, et la prochaine à décrocher.
	local limits = Medals.ForCircuit(trackId, circuit.Length)
	local tier = Medals.TierOf(mine, limits)
	local nextTier, nextMs = Medals.Next(mine, limits)
	local text = string.format("%s — ton record : %s", circuit.Name, if mine then RaceUi.FormatTime(mine / 1000) else "aucun")
	if tier > 0 then
		text ..= "  " .. Medals.Rich(tier)
	end
	if nextTier and nextMs then
		text ..= "  → " .. Medals.Rich(nextTier) .. " " .. Medals.FormatLimit(nextMs)
	end
	b:Text(text, 14, RaceUi.COLOR_TEXT).RichText = true
	b:Text("   " .. Medals.RichLine(limits), 12, RaceUi.COLOR_DIM).RichText = true
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

-- Niveau, licence, barre d'XP, et d'où vient l'XP.
function RaceMenu:_progress(b: Builder)
	local progress = self.Data.Progress
	if not progress then
		return
	end
	local licence = Progression.LICENCES[progress.Licence] or Progression.LICENCES[1]
	local title = b:Text(string.format(
		'Niveau %d · <font color="%s">Licence %s</font> · %s XP',
		progress.Level,
		Medals.Hex(licence.Color),
		licence.Name,
		Progression.Thousands(progress.Xp)
	), 15)
	title.RichText = true
	title.Font = Enum.Font.GothamBold

	-- Barre jusqu'au niveau suivant.
	local nextXp: number? = progress.NextXp
	local row = b:Row(12)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.fromOffset(0, 2)
	track.BackgroundColor3 = RaceUi.COLOR_BUTTON
	track.BorderSizePixel = 0
	RaceUi.Corner(track, 4)
	track.Parent = row
	local fill = Instance.new("Frame")
	local fraction = 1
	if nextXp then
		fraction = math.clamp((progress.Xp - progress.LevelXp) / math.max(1, nextXp - progress.LevelXp), 0, 1)
	end
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = licence.Color
	fill.BorderSizePixel = 0
	RaceUi.Corner(fill, 4)
	fill.Parent = track
	if nextXp then
		b:Text(string.format("Niveau %d à %s XP", progress.Level + 1, Progression.Thousands(nextXp)), 12, RaceUi.COLOR_DIM)
	end
	b:Text(string.format(
		"Spéciales terminées %d · Points de style %s",
		progress.StageRuns,
		Progression.Thousands(progress.Style)
	), 13)
	b:Text(string.format(
		"XP : médailles, courses, victoires, podiums, points, spéciales terminées, et le style en compétition — dérapages, sauts, dépassements (%d points de style = 1 XP).",
		Progression.XP.STYLE_PER_XP
	), 12, RaceUi.COLOR_DIM)
end

-- Couleur et numéro de sa voiture.
function RaceMenu:_livery(b: Builder)
	local livery = self.Data.Livery
	if not livery then
		b:Text("Chargement…", 13, RaceUi.COLOR_DIM)
		return
	end
	local current: Livery.Livery = livery
	local function send(changed: Livery.Livery)
		self.Data.Livery = changed
		self.Action("Livery", changed)
		self:_rebuild()
	end
	local colorValue = self:_stepper(b, "Couleur", Livery.NameOf(current), function(direction)
		-- Couleur suivante parmi celles débloquées (Progression.luau).
		local count = #Livery.COLORS
		local color = current.Color
		for _ = 1, count do
			color = ((color - 1 + direction) % count) + 1
			if Progression.IsUnlocked("Color", color, self.Data.Progress) then
				break
			end
		end
		local changed = table.clone(current)
		changed.Color = color
		send(changed)
	end)
	-- Pastille de la couleur, derrière le nom.
	local swatch = Livery.ColorOf(current)
	colorValue.BackgroundTransparency = 0
	colorValue.BackgroundColor3 = swatch
	colorValue.TextColor3 = Livery.ContrastOf(swatch)
	RaceUi.Corner(colorValue, 6)
	self:_stepper(b, "Numéro", "#" .. tostring(current.Number), function(direction)
		local range = Livery.MAX_NUMBER - Livery.MIN_NUMBER + 1
		local changed = table.clone(current)
		changed.Number = ((current.Number - Livery.MIN_NUMBER + direction) % range) + Livery.MIN_NUMBER
		send(changed)
	end)
	b:Text("Visible de tous : carrosserie, numéros sur les flancs et le toit. Bandes, style du numéro, couleurs à débloquer et aperçu : au GARAGE (zone violette du paddock).", 12, RaceUi.COLOR_DIM)
end

-- Un circuit du menu : nom, ce qui s'y passe, et le bouton pour y courir.
function RaceMenu:_circuitRow(b: Builder, id: string)
	local circuit = Tracks.Get(id)
	if not circuit then
		return
	end
	-- Salle qui attend des pilotes (on la rejoint) et pilotes déjà en piste.
	local waiting: RaceUi.LobbyRace? = nil
	local racing = 0
	for _, race in ipairs(self.Data.Lobby) do
		if race.TrackId == id then
			if race.State == "Lobby" and race.Count < race.Max then
				waiting = waiting or race
			elseif race.State ~= "Lobby" then
				racing += race.Count
			end
		end
	end
	local details = string.match(circuit.Description, "^[^%.]+") or ""
	local status = {}
	if waiting then
		table.insert(status, string.format("%d en attente · %d tours · %s", waiting.Count, waiting.Laps, formatName(waiting.Format)))
	end
	if racing > 0 then
		table.insert(status, string.format("%d en course", racing))
	end

	local width = PANEL_WIDTH - 32
	local row = b:Row(40)
	local name = RaceUi.Label(row, circuit.Name, 15, Enum.Font.GothamBold)
	name.Position = UDim2.fromOffset(0, 2)
	name.Size = UDim2.new(1, -176, 0, 18)
	local info = RaceUi.Label(row, if #status > 0 then table.concat(status, " · ") else details, 12, Enum.Font.GothamMedium, if waiting then RaceUi.COLOR_GREEN else RaceUi.COLOR_DIM)
	info.Position = UDim2.fromOffset(0, 21)
	info.Size = UDim2.new(1, -176, 0, 16)
	info.TextTruncate = Enum.TextTruncate.AtEnd
	local text = if waiting then string.format("REJOINDRE (%d/%d)", waiting.Count, waiting.Max) else "COURIR"
	local button = self:_button(row, text, width - 168, 168, function()
		self.Action("Play", { Mode = "Rallycross", TrackId = id })
	end)
	if waiting then
		RaceUi.Primary(button)
	end
end

-- Défi de la semaine : la contrainte, la fin, le podium, son temps, le bouton.
function RaceMenu:_weekly(b: Builder)
	local board: any = self.Data.Weekly
	local modifier = if board then Weekly.ModifierById(board.Modifier) else nil
	if not board or not modifier then
		return
	end
	local width = PANEL_WIDTH - 32
	b:Section("Défi de la semaine")
	local row = b:Row(28)
	local tag = Theme.Tag(row, string.upper(modifier.Name), Theme.ACCENT, Theme.ON_ACCENT, 16)
	tag.Position = UDim2.fromOffset(0, 2)
	local remaining = RaceUi.Label(
		row,
		"fin dans " .. Weekly.FormatRemaining(board.EndsAt - workspace:GetServerTimeNow()),
		13,
		Enum.Font.GothamBold,
		RaceUi.COLOR_DIM
	)
	remaining.Size = UDim2.fromScale(1, 1)
	remaining.TextXAlignment = Enum.TextXAlignment.Right
	b:Text(modifier.Description .. " La spéciale, ce seul changement, et un classement remis à zéro chaque lundi.", 13, RaceUi.COLOR_DIM)

	local entries = board.Entries or {}
	if #entries == 0 then
		b:Text("Personne n'a encore relevé le défi cette semaine : à toi !", 13, RaceUi.COLOR_GREEN)
	end
	for index = 1, math.min(3, #entries) do
		local entry = entries[index]
		local color = if entry.UserId == self.LocalUserId then RaceUi.COLOR_ACCENT else RaceUi.COLOR_TEXT
		local label = b:Text(string.format("   %d. %s  %s", index, entry.Name, RaceUi.FormatTime(entry.Ms / 1000)), 14, color)
		label.Font = Enum.Font.RobotoMono
	end
	local mine: number? = board.Mine
	b:Text(
		if mine
			then "Ton meilleur temps cette semaine : " .. RaceUi.FormatTime(mine / 1000)
			else string.format("Pas encore de temps cette semaine · +%d XP à ta première arrivée", Progression.XP.WEEKLY),
		13,
		if mine then RaceUi.COLOR_TEXT else RaceUi.COLOR_ACCENT
	)
	local buttonRow = b:Row(40)
	local go = self:_button(buttonRow, "RELEVER LE DÉFI", 0, width, function()
		self.Action("Play", { Mode = "Weekly" })
	end)
	RaceUi.Primary(go)
	go.TextSize = 16
end

-- Défis du jour : chaque objectif, sa barre, l'XP ; et quand ils changent.
function RaceMenu:_daily(b: Builder)
	local state: any = self.Data.Daily
	if not state then
		return
	end
	b:Section("Défis du jour")
	for _, challenge in ipairs(state.Challenges) do
		local row = b:Row(38)
		local done = challenge.Done == true
		-- Case cochée ou vide.
		local box = Instance.new("TextLabel")
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(0, 4)
		box.Size = UDim2.fromOffset(22, 22)
		box.BackgroundColor3 = if done then Theme.GREEN else Theme.PANEL_2
		box.Text = if done then "✓" else ""
		box.TextColor3 = Theme.ON_ACCENT
		box.FontFace = Theme.HEADLINE
		box.TextSize = 16
		Theme.Corner(box, 2)
		box.Parent = row
		local text = RaceUi.Label(row, challenge.Text, 14, Enum.Font.GothamBold, if done then RaceUi.COLOR_DIM else RaceUi.COLOR_TEXT)
		text.Position = UDim2.fromOffset(32, 2)
		text.Size = UDim2.new(1, -120, 0, 20)
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local amount = RaceUi.Label(
			row,
			if done then "+" .. tostring(state.Xp) .. " XP ✓" else string.format("%s / %s", Progression.Thousands(challenge.Progress), Progression.Thousands(challenge.Goal)),
			13,
			Enum.Font.GothamBold,
			if done then RaceUi.COLOR_GREEN else RaceUi.COLOR_DIM
		)
		amount.Position = UDim2.new(1, -110, 0, 2)
		amount.Size = UDim2.fromOffset(110, 20)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		-- Barre de progression.
		local track = Instance.new("Frame")
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Theme.PANEL_2
		track.Position = UDim2.fromOffset(32, 26)
		track.Size = UDim2.new(1, -32, 0, 5)
		track.Parent = row
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = if done then Theme.GREEN else Theme.ACCENT
		fill.Size = UDim2.fromScale(math.clamp(challenge.Progress / math.max(1, challenge.Goal), 0, 1), 1)
		fill.Parent = track
	end
	b:Text(string.format(
		"%s · +%d XP par défi, +%d pour les trois · nouveaux défis dans %s",
		if state.Bonus then "Les trois sont faits, bravo !" else "Spéciale, défi ou course",
		state.Xp,
		state.BonusXp,
		Weekly.FormatRemaining(state.EndsAt - workspace:GetServerTimeNow())
	), 12, RaceUi.COLOR_DIM)
end

-- École de pilotage : une ligne par leçon, sa médaille, le bouton.
function RaceMenu:_school(b: Builder)
	local width = PANEL_WIDTH - 32
	local progress = self.Data.Progress
	local bests: { [string]: number } = if progress and progress.Lessons then progress.Lessons else {}
	b:Section("École de pilotage")
	b:Text("Quatre leçons courtes sur la spéciale, notées de bronze à platine. Le meilleur moyen de progresser (et de l'XP).", 13, RaceUi.COLOR_DIM)
	for _, lesson in ipairs(Lessons.LIST) do
		local row = b:Row(40)
		local name = RaceUi.Label(row, string.upper(lesson.Name), 16, Enum.Font.GothamBlack)
		name.Position = UDim2.fromOffset(0, 0)
		name.Size = UDim2.new(1, -150, 0, 20)
		local goal = RaceUi.Label(row, lesson.Goal, 12, Enum.Font.GothamMedium, RaceUi.COLOR_DIM)
		goal.Position = UDim2.fromOffset(0, 21)
		goal.Size = UDim2.new(1, -150, 0, 16)
		goal.TextTruncate = Enum.TextTruncate.AtEnd
		local tier = bests[lesson.Id] or 0
		local medal = Medals.Get(tier)
		if medal then
			local tag = Theme.Tag(row, medal.Short, medal.Color, Theme.ON_ACCENT, 12)
			tag.AnchorPoint = Vector2.new(1, 0)
			tag.Position = UDim2.new(1, -112, 0, 9)
		end
		local button = self:_button(row, if tier > 0 then "REFAIRE" else "LEÇON", width - 104, 104, function()
			self.Action("Play", { Mode = "Lesson", TrackId = lesson.Id })
		end)
		if tier == 0 then
			RaceUi.Primary(button)
		end
	end
end

function RaceMenu:_buildOutside(b: Builder)
	local width = PANEL_WIDTH - 32
	-- Débutant : l'école d'abord.
	local progress = self.Data.Progress
	local beginner = progress ~= nil and progress.Level <= 3
	if beginner then
		self:_school(b)
	end
	self:_weekly(b)
	self:_daily(b)

	b:Section("Spéciale")
	b:Text("1,6 km chronométrés, terre et asphalte, un saut et deux épingles. Bats ton record et grimpe au classement (L).", 13, RaceUi.COLOR_DIM)
	local stageRow = b:Row(40)
	local stage = self:_button(stageRow, "LANCER UNE SPÉCIALE", 0, width, function()
		self.Action("Play", { Mode = "Stage" })
	end)
	RaceUi.Primary(stage)
	stage.TextSize = 16

	b:Section("Rallycross")
	b:Text("Seul ou jusqu'à 6 pilotes. Le départ est donné 20 s après le premier inscrit : les autres peuvent rejoindre d'ici là, et l'hôte peut lancer sans attendre. Joker obligatoire une fois par course.", 13, RaceUi.COLOR_DIM)
	for _, id in ipairs(Tracks.List()) do
		self:_circuitRow(b, id)
	end

	if not beginner then
		self:_school(b)
	end

	b:Section("Et aussi")
	local practiceRow = b:Row(36)
	self:_button(practiceRow, "ESSAIS LIBRES (piste d'essai)", 0, width, function()
		self.Action("Play", { Mode = "Practice" })
	end)
	local homeRow = b:Row(36)
	self:_button(homeRow, "RETOUR AU PADDOCK (H)", 0, width, function()
		self.Action("Paddock", nil)
	end)
	b:Text("Au paddock, entrer à pied dans la zone d'un circuit fait aussi rejoindre sa salle d'attente (en sortir, c'est la quitter).", 12, RaceUi.COLOR_DIM)

	b:Section("Ta voiture")
	self:_livery(b)

	b:Section("Records du tour")
	for _, id in ipairs(Tracks.List()) do
		self:_records(b, id)
	end

	b:Section("Ta carrière")
	self:_progress(b)
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
	local inLobby = race.State == "Lobby"
	b:Section(trackName(race.TrackId))

	if inLobby and isHost then
		b:Text("Tu es l'hôte : tu règles la course et peux la lancer sans attendre.", 13, RaceUi.COLOR_DIM)
		self:_stepper(b, "Tours", tostring(race.Laps), function(direction)
			self.Action("Settings", { Laps = math.clamp(race.Laps + direction, MIN_LAPS, MAX_LAPS) })
		end)
		self:_stepper(b, "Format", formatName(race.Format), function(_direction)
			self.Action("Settings", { Format = if race.Format == "Event" then "Sprint" else "Event" })
		end)
		self:_stepper(b, "Contacts entre voitures", if race.Contacts then "Oui" else "Non", function(_direction)
			self.Action("Settings", { Contacts = not race.Contacts })
		end)
	else
		b:Text(string.format(
			"%d tours · %s · contacts %s",
			race.Laps,
			formatName(race.Format),
			if race.Contacts then "activés" else "désactivés"
		), 14)
	end

	local stateText: string
	if inLobby then
		stateText = string.format("Salle d'attente (%d/%d pilotes)", #race.Members, race.MaxPlayers)
	elseif race.State == "Grid" or race.State == "Countdown" then
		stateText = race.RoundName .. " — départ imminent"
	elseif race.State == "Racing" then
		stateText = race.RoundName .. " — en cours"
	else
		stateText = race.RoundName .. " — résultats"
	end
	b:Text(stateText, 14, RaceUi.COLOR_ACCENT)
	self.CountdownLabel = b:Text("", 14, RaceUi.COLOR_GREEN)
	if inLobby and #race.Members == 1 then
		b:Text("Seul pour l'instant : la course partira quand même. Une course en solo ne compte pas pour la carrière (points, victoires), mais tes records du tour, oui.", 12, RaceUi.COLOR_DIM)
	end

	b:Section("Pilotes")
	for _, member in ipairs(race.Members) do
		local host = if member.UserId == race.HostUserId then "★ " else "   "
		local color = if member.UserId == self.LocalUserId then RaceUi.COLOR_ACCENT else RaceUi.COLOR_TEXT
		b:Text(host .. member.Name, 15, color)
	end

	local row = b:Row(36)
	local width = PANEL_WIDTH - 32
	if inLobby then
		local half = (width - 8) / 2
		if isHost then
			local canStart = #race.Members >= race.MinPlayers
			local start = self:_button(row, "LANCER MAINTENANT", 0, half, function()
				if canStart then
					self.Action("Start", nil)
				end
			end)
			if canStart then
				RaceUi.Primary(start)
			else
				start.TextColor3 = RaceUi.COLOR_DIM
			end
		end
		self:_button(row, "QUITTER", if isHost then half + 8 else 0, if isHost then half else width, function()
			self.Action("Leave", nil)
		end)
	else
		local abandon = self:_button(row, "ABANDONNER", 0, width, function()
			self.Action("Abandon", nil)
		end)
		RaceUi.Danger(abandon)
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
		self:_buildOutside(b)
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
	-- Menu fermé : inutile de tout reconstruire à chaque point de style.
	if not self.Gui.Enabled then
		self.Dirty = true
		return
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
	if open and self.Dirty then
		self.Dirty = false
		self:_rebuild()
	end
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

-- Compte à rebours de la salle d'attente.
function RaceMenu:Update()
	local label = self.CountdownLabel
	local race = self.Data.Race
	if not label or not race then
		return
	end
	if race.State == "Lobby" and race.AutoStartAt then
		label.Text = string.format("Départ dans %d s", math.max(0, math.ceil((race.AutoStartAt :: number) - serverNow())))
	elseif race.State == "Lobby" and #race.Members < race.MinPlayers then
		label.Text = string.format("En attente d'un %de pilote…", race.MinPlayers)
	else
		label.Text = ""
	end
end

return RaceMenu
