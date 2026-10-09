--!strict
--[[
	MainMenu.luau
	Le menu principal : C (ou croix directionnelle droite, ou bouton MENU sur
	mobile) ouvre et ferme ; il s'ouvre aussi à l'arrivée dans le jeu, et au
	retour d'une course.

	Ce module n'est que le cadre : en-tête (avec le solde de crédits),
	onglets, corps défilant, ouverture, sélection à la manette. Le contenu
	vient des rubriques, une par module (MenuKit.luau décrit ce qu'elles
	reçoivent), réparties en onglets :
		JOUER      PlayPage (spéciale et ralenti, rallycross, essais libres),
		           SchoolPage (école de pilotage, en tête pour un débutant)
		           et un rappel des défis ;
		DÉFIS      ChallengesPage (défi de la semaine, défis du jour) ;
		BOUTIQUE   ShopPage (solde, crédits, objets) ;
		CARRIÈRE   CareerPage (sa voiture, records du tour, carrière).
	Pendant une course, RacePage remplace tout (sans onglets).

	Le contenu est reconstruit à chaque changement d'état (il change rarement) ;
	seuls les comptes à rebours sont rafraîchis à chaque frame.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local MenuKit = require(script.Parent.MenuKit)
local PlayPage = require(script.Parent.PlayPage)
local ChallengesPage = require(script.Parent.ChallengesPage)
local ShopPage = require(script.Parent.ShopPage)
local SchoolPage = require(script.Parent.SchoolPage)
local CareerPage = require(script.Parent.CareerPage)
local RacePage = require(script.Parent.RacePage)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

local MainMenu = {}
MainMenu.__index = MainMenu

export type Data = MenuKit.Data

export type MainMenu = typeof(setmetatable({}, MainMenu)) & {
	Action: (string, any) -> (),
	LocalUserId: number,
	Gui: ScreenGui,
	Panel: Frame,
	Body: ScrollingFrame,
	TabBar: Frame,
	TabButtons: { [string]: TextButton },
	Tab: string,
	Balance: TextLabel,
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

local PANEL_WIDTH = MenuKit.PANEL_WIDTH
local HEADER_HEIGHT = 70 -- en-tête du jeu : titre, sous-titre, damier
local TAB_HEIGHT = 34

type Tab = { Id: string, Name: string }
local TABS: { Tab } = {
	{ Id = "Play", Name = "JOUER" },
	{ Id = "Challenges", Name = "DÉFIS" },
	{ Id = "Shop", Name = "BOUTIQUE" },
	{ Id = "Career", Name = "CARRIÈRE" },
}
local SCREEN_PADDING = 24
local TOUCH_SCALE = 1.1
local BEGINNER_LEVEL = 3 -- jusqu'à ce niveau, l'école passe en tête du menu

function MainMenu.new(playerGui: Instance, localUserId: number, action: (string, any) -> ()): MainMenu
	local self = (setmetatable({}, MainMenu) :: any) :: MainMenu
	self.Action = action
	self.LocalUserId = localUserId
	self.TouchLayout = false
	self.Data = { Lobby = {}, Race = nil, Records = {}, Stats = nil, Progress = nil, Weekly = nil, Daily = nil, Laps = {}, Livery = nil }
	self.Status = ""
	self.StatusColor = Widgets.COLOR_DIM
	self.CountdownLabel = nil
	self.FirstButton = nil
	self.Dirty = false
	self.Tab = "Play"
	self.TabButtons = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceMenu"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 11
	self.Gui = gui

	local panel = Widgets.Panel(gui, 0.08)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 600)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Panel = panel
	self.Scale = scale

	-- En-tête du jeu : le titre en capitales condensées, une étiquette jaune,
	-- un filet à damier dessous.
	local title = Widgets.Label(panel, "SIM RALLYE", 30, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(18, 8)
	title.Size = UDim2.fromOffset(170, 38)
	local tag = Theme.Tag(panel, "SPÉCIALE · RALLYCROSS", Theme.ACCENT, Theme.ON_ACCENT, 13)
	tag.Position = UDim2.fromOffset(176, 17)
	local checker = Theme.Checker(panel, PANEL_WIDTH, 5, 2)
	checker.Position = UDim2.fromOffset(0, HEADER_HEIGHT - 14)
	checker.BackgroundTransparency = 0.2
	local close = Widgets.Button(panel, "×", function()
		self:SetOpen(false)
	end)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Size = UDim2.fromOffset(32, 28)
	close.TextSize = 18
	-- Solde de crédits, toujours en vue.
	local balance = Theme.Tag(panel, "… " .. Credits.SHORT, Theme.PANEL_2, Theme.ACCENT, 15)
	balance.AnchorPoint = Vector2.new(1, 0)
	balance.Position = UDim2.new(1, -54, 0, 12)
	self.Balance = balance

	-- Onglets.
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(16, HEADER_HEIGHT)
	tabBar.Size = UDim2.new(1, -32, 0, TAB_HEIGHT)
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar
	local tabWidth = (PANEL_WIDTH - 32 - 4 * (#TABS - 1)) / #TABS
	for index, tab in ipairs(TABS) do
		local button = Widgets.Button(tabBar, tab.Name, function()
			self:SetTab(tab.Id)
		end)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(tabWidth, TAB_HEIGHT - 6)
		button.FontFace = Theme.HEADLINE
		button.TextSize = 15
		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.BorderSizePixel = 0
		underline.BackgroundColor3 = Theme.ACCENT
		underline.AnchorPoint = Vector2.new(0, 1)
		underline.Position = UDim2.fromScale(0, 1)
		underline.Size = UDim2.new(1, 0, 0, 3)
		underline.Parent = button
		self.TabButtons[tab.Id] = button
	end
	self.TabBar = tabBar

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_HEIGHT))
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

-- Ce que reçoivent les rubriques (MenuKit.Context).
function MainMenu:_context(): MenuKit.Context
	return {
		Data = self.Data,
		LocalUserId = self.LocalUserId,
		Action = self.Action,
		Rebuild = function()
			self:_rebuild()
		end,
		Button = function(parent: Instance, text: string, x: number, width: number, callback: () -> ()): TextButton
			local button = Widgets.Button(parent, text, callback)
			button.Position = UDim2.fromOffset(x, 0)
			button.Size = UDim2.new(0, width, 1, 0)
			if not self.FirstButton then
				self.FirstButton = button
			end
			return button
		end,
		SetCountdown = function(label: TextLabel?)
			self.CountdownLabel = label
		end,
		SetTab = function(tab: string)
			self:SetTab(tab)
		end,
	}
end

-- Hors course : le contenu de l'onglet choisi.
local function buildTab(ctx: MenuKit.Context, b: MenuKit.Builder, tab: string)
	if tab == "Challenges" then
		ChallengesPage.Weekly(ctx, b)
		ChallengesPage.Daily(ctx, b)
	elseif tab == "Shop" then
		ShopPage.Balance(ctx, b)
		for _, kind in ipairs(Catalog.KINDS) do
			ShopPage.Items(ctx, b, kind :: Catalog.Kind)
		end
		ShopPage.CreditPacks(ctx, b)
	elseif tab == "Career" then
		CareerPage.Car(ctx, b)
		CareerPage.Records(ctx, b)
		CareerPage.Career(ctx, b)
	else
		local progress = ctx.Data.Progress
		local beginner = progress ~= nil and progress.Level <= BEGINNER_LEVEL
		if beginner then
			SchoolPage.School(ctx, b)
		end
		ChallengesPage.Summary(ctx, b)
		PlayPage.Stage(ctx, b)
		PlayPage.Rallycross(ctx, b)
		if not beginner then
			SchoolPage.School(ctx, b)
		end
		PlayPage.More(ctx, b)
	end
end

-- Onglets visibles hors course ; l'onglet choisi en jaune, souligné.
function MainMenu:_refreshTabs()
	local inRace = self.Data.Race ~= nil
	self.TabBar.Visible = not inRace
	local top = if inRace then HEADER_HEIGHT else HEADER_HEIGHT + TAB_HEIGHT
	self.Body.Position = UDim2.fromOffset(0, top)
	self.Body.Size = UDim2.new(1, 0, 1, -top)
	for id, button in pairs(self.TabButtons) do
		local selected = id == self.Tab
		button.TextColor3 = if selected then Theme.ACCENT else Widgets.COLOR_DIM
		local underline = button:FindFirstChild("Underline")
		if underline and underline:IsA("Frame") then
			underline.Visible = selected
		end
	end
	local wallet = self.Data.Wallet
	self.Balance.Text = if wallet then Credits.Format(wallet.Credits) else "… " .. Credits.SHORT
end

function MainMenu:_rebuild()
	for _, child in ipairs(self.Body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.CountdownLabel = nil
	self.FirstButton = nil
	local ctx = self:_context()
	local b = MenuKit.Builder(self.Body)
	if self.Status ~= "" then
		b:Text(self.Status, 13, self.StatusColor)
	end
	self:_refreshTabs()
	local race = self.Data.Race
	if race then
		RacePage.Race(ctx, b, race)
	else
		buildTab(ctx, b, self.Tab)
	end
	if self.Gui.Enabled and not self.TouchLayout then
		GuiService.SelectedObject = self.FirstButton
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function MainMenu:SetData(data: Data)
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

function MainMenu:SetTab(tab: string)
	if self.Tab == tab then
		return
	end
	self.Tab = tab
	self.Status = ""
	self.Body.CanvasPosition = Vector2.zero
	self:_rebuild()
end

function MainMenu:SetStatus(text: string, color: Color3?)
	self.Status = text
	self.StatusColor = color or Widgets.COLOR_DIM
	self:_rebuild()
end

function MainMenu:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
end

function MainMenu:IsOpen(): boolean
	return self.Gui.Enabled
end

function MainMenu:SetOpen(open: boolean)
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
		self.Panel.Size = UDim2.fromOffset(PANEL_WIDTH, math.min(760, available))
		if not self.TouchLayout then
			GuiService.SelectedObject = self.FirstButton
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
		GuiService.SelectedObject = nil
	end
end

function MainMenu:Toggle()
	self:SetOpen(not self:IsOpen())
end

-- Compte à rebours de la salle d'attente.
function MainMenu:Update()
	local label = self.CountdownLabel
	local race = self.Data.Race
	if not label or not race then
		return
	end
	if race.State == "Lobby" and race.AutoStartAt then
		label.Text = string.format("Départ dans %d s", math.max(0, math.ceil((race.AutoStartAt :: number) - workspace:GetServerTimeNow())))
	elseif race.State == "Lobby" and #race.Members < race.MinPlayers then
		label.Text = string.format("En attente d'un %de pilote…", race.MinPlayers)
	else
		label.Text = ""
	end
end

return MainMenu
