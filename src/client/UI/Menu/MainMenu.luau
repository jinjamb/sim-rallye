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
		INVENTAIRE InventoryPage (sa voiture : modèle et pièces ; son équipement),
		JOUER      PlayPage (spéciale et ralenti, rallycross, essais libres),
		           SchoolPage (école de pilotage, en tête pour un débutant)
		           et un rappel des défis ;
		DÉFIS      ChallengesPage (défi de la semaine, défis du jour, roi du drift) ;
		PASS       PassPage (Rallye Pass : paliers, récompenses, premium) ;
		ÉCURIE     TeamPage (son écurie, invitations, classement des écuries) ;
		BOUTIQUE   ShopPage (solde, crédits, objets) ;
		CARRIÈRE   CareerPage (sa voiture, records du tour, carrière).
	Pendant une course, RacePage remplace tout (sans onglets).

	À pied, la barre de boutons à gauche (HubBar.luau) ouvre chaque onglet
	d'un clic, et le menu s'ouvre à côté d'elle : le personnage reste visible
	et continue de marcher.

	Le contenu est reconstruit à chaque changement d'état (il change rarement) ;
	seuls les comptes à rebours sont rafraîchis à chaque frame.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local MenuKit = require(script.Parent.MenuKit)
local PlayPage = require(script.Parent.PlayPage)
local SessionPage = require(script.Parent.SessionPage)
local ChampionshipPage = require(script.Parent.ChampionshipPage)
local ChallengesPage = require(script.Parent.ChallengesPage)
local ShopPage = require(script.Parent.ShopPage)
local PassPage = require(script.Parent.PassPage)
local TeamPage = require(script.Parent.TeamPage)
local SchoolPage = require(script.Parent.SchoolPage)
local CareerPage = require(script.Parent.CareerPage)
local RacePage = require(script.Parent.RacePage)
local HubBar = require(script.Parent.HubBar)
local InventoryPage = require(script.Parent.InventoryPage)
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
	Footer: TextLabel,
	Hub: HubBar.HubBar, -- barre de boutons à gauche, à pied (HubBar.luau)
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
	View: { [string]: any }, -- état d'affichage des rubriques (MenuKit.Context)
}

local PANEL_WIDTH = MenuKit.PANEL_WIDTH
local HEADER_HEIGHT = 70 -- en-tête du jeu : titre, étiquette, filet rose
local TAB_HEIGHT = 56 -- icône au-dessus du nom : on trouve l'onglet d'un coup d'œil
local FOOTER_HEIGHT = 24 -- rappel des touches

type Tab = { Id: string, Name: string, Icon: string }
local TABS: { Tab } = {
	{ Id = "Play", Name = "JOUER", Icon = "🏁" },
	{ Id = "Inventory", Name = "INVENTAIRE", Icon = "🎒" },
	{ Id = "Challenges", Name = "DÉFIS", Icon = "🎯" },
	{ Id = "Pass", Name = "PASS", Icon = "🎫" },
	{ Id = "Team", Name = "ÉCURIE", Icon = "🤝" },
	{ Id = "Shop", Name = "BOUTIQUE", Icon = "🛒" },
	{ Id = "Career", Name = "CARRIÈRE", Icon = "🏆" },
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
	self.View = {}

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

	-- En-tête du jeu : le titre en capitales italiques, une étiquette jaune
	-- penchée, des bandes de vitesse, le filigrane « ラリー » (rallye), un
	-- filet rose dessous.
	local kana = Theme.Kana(panel, "ラリー", 64, 0.9)
	kana.Position = UDim2.fromOffset(-120, -6)
	kana.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	local title = Widgets.Label(panel, "SIM RALLYE", 32, Enum.Font.GothamBlack)
	title.FontFace = Theme.HEADLINE
	title.Position = UDim2.fromOffset(18, 6)
	title.Size = UDim2.fromOffset(0, 40)
	title.AutomaticSize = Enum.AutomaticSize.X
	Theme.TextInk(title, 2, Theme.ACCENT)
	local tag = Theme.Tag(panel, "SPÉCIALE · RALLYCROSS", Theme.YELLOW, Theme.ON_YELLOW, 12)
	tag.Position = UDim2.fromOffset(20, 44)
	local stripes = Theme.Stripes(panel, Theme.ACCENT, 4)
	stripes.Position = UDim2.fromOffset(214, 46)
	stripes.Size = UDim2.fromOffset(70, 17)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = Theme.ACCENT
	rule.Position = UDim2.fromOffset(0, HEADER_HEIGHT - 3)
	rule.Size = UDim2.new(1, 0, 0, 3)
	rule.Parent = panel
	local close = Widgets.Button(panel, "X", function()
		self:SetOpen(false)
	end)
	close.Position = UDim2.new(1, -46, 0, 12)
	close.Size = UDim2.fromOffset(34, 32)
	close.TextSize = 16
	-- Solde de crédits, toujours en vue.
	local balance = Theme.Tag(panel, "… " .. Credits.SHORT, Theme.INK, Theme.YELLOW, 16)
	balance.AnchorPoint = Vector2.new(1, 0)
	balance.Position = UDim2.new(1, -56, 0, 15)
	self.Balance = balance

	-- Onglets : une icône, le nom dessous ; l'onglet choisi en rose plein.
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(16, HEADER_HEIGHT + 6)
	tabBar.Size = UDim2.new(1, -32, 0, TAB_HEIGHT - 6)
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar
	local tabWidth = (PANEL_WIDTH - 32 - 4 * (#TABS - 1)) / #TABS
	for index, tab in ipairs(TABS) do
		local button = Widgets.Button(tabBar, "", function()
			self:SetTab(tab.Id)
		end)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(tabWidth, TAB_HEIGHT - 12)
		local icon = Widgets.Label(button, tab.Icon, 20)
		icon.Name = "Icon"
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.Position = UDim2.fromOffset(0, 3)
		icon.Size = UDim2.new(1, 0, 0, 22)
		local name = Widgets.Label(button, tab.Name, 12)
		name.Name = "TabName"
		name.FontFace = Theme.HEADLINE
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position = UDim2.fromOffset(2, 25)
		name.Size = UDim2.new(1, -4, 0, 16)
		-- Sept onglets : un nom long (INVENTAIRE) rétrécit pour tenir.
		name.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 12
		nameLimit.Parent = name
		self.TabButtons[tab.Id] = button
	end
	self.TabBar = tabBar

	-- Rappel des touches, en pied : on sait toujours comment sortir.
	local footer = Widgets.Label(panel, "C  ·  fermer le menu", 12, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 18, 1, -4)
	footer.Size = UDim2.new(1, -36, 0, FOOTER_HEIGHT - 6)
	footer.TextXAlignment = Enum.TextXAlignment.Right
	self.Footer = footer

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_HEIGHT + FOOTER_HEIGHT))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Theme.ACCENT
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
	-- Barre de boutons à pied : un clic ouvre (ou referme) l'onglet.
	self.Hub = HubBar.new(playerGui, TABS, function(tab: string)
		self:OpenTab(tab)
	end)
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
		View = self.View,
	}
end

-- Hors course : le contenu de l'onglet choisi.
local function buildTab(ctx: MenuKit.Context, b: MenuKit.Builder, tab: string)
	if tab == "Inventory" then
		InventoryPage.Car(ctx, b)
		InventoryPage.Livery(ctx, b)
		InventoryPage.Paint(ctx, b)
		InventoryPage.Gear(ctx, b)
	elseif tab == "Challenges" then
		ChallengesPage.Weekly(ctx, b)
		ChallengesPage.Daily(ctx, b)
		ChallengesPage.DriftKing(ctx, b)
	elseif tab == "Pass" then
		PassPage.Pass(ctx, b)
	elseif tab == "Team" then
		TeamPage.Team(ctx, b)
	elseif tab == "Shop" then
		ShopPage.Balance(ctx, b)
		ShopPage.Offers(ctx, b)
		ShopPage.Rolls(ctx, b)
		ShopPage.Catalog(ctx, b)
		ShopPage.CreditPacks(ctx, b)
	elseif tab == "Career" then
		CareerPage.Car(ctx, b)
		CareerPage.Records(ctx, b)
		CareerPage.Career(ctx, b)
		CareerPage.Trophies(ctx, b)
	else
		local progress = ctx.Data.Progress
		local beginner = progress ~= nil and progress.Level <= BEGINNER_LEVEL
		PlayPage.XpEvent(ctx, b)
		if beginner then
			SchoolPage.School(ctx, b)
		end
		ChallengesPage.Summary(ctx, b)
		ChampionshipPage.Rallies(ctx, b)
		PlayPage.Stage(ctx, b)
		PlayPage.Rallycross(ctx, b)
		SessionPage.Friends(ctx, b)
		if not beginner then
			SchoolPage.School(ctx, b)
		end
		PlayPage.More(ctx, b)
	end
end

-- Onglets visibles hors course ; l'onglet choisi en rose plein.
function MainMenu:_refreshTabs()
	local inRace = self.Data.Race ~= nil
	self.TabBar.Visible = not inRace
	local top = if inRace then HEADER_HEIGHT + 8 else HEADER_HEIGHT + TAB_HEIGHT
	self.Body.Position = UDim2.fromOffset(0, top)
	self.Body.Size = UDim2.new(1, 0, 1, -(top + FOOTER_HEIGHT))
	for id, button in pairs(self.TabButtons) do
		local selected = id == self.Tab
		button.BackgroundColor3 = if selected then Theme.ACCENT else Theme.PANEL_2
		button.BackgroundTransparency = if selected then 0 else 0.35
		local name = button:FindFirstChild("TabName")
		if name and name:IsA("TextLabel") then
			name.TextColor3 = if selected then Theme.ON_ACCENT else Widgets.COLOR_DIM
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
	if self.Gui.Enabled and self:_usingGamepad() then
		GuiService.SelectedObject = self.FirstButton
	end
end

-- Joue-t-on à la manette ? Seulement alors le menu prend la sélection (à la
-- souris, le cadre de sélection gênerait, et le clic suffit).
function MainMenu:_usingGamepad(): boolean
	if self.TouchLayout then
		return false
	end
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

-- La barre de boutons suit le menu : onglet ouvert, solde, niveau.
function MainMenu:_refreshHub()
	local wallet = self.Data.Wallet
	local open = self.Gui.Enabled and self.Data.Race == nil
	self.Hub:Refresh(if open then self.Tab else nil, if wallet then wallet.Credits else nil, self.Data.Progress)
end

--[[
	Place du menu : à côté de la barre de boutons quand elle est là (le
	personnage reste visible au milieu de l'écran), au centre sinon.
]]
function MainMenu:_place()
	if self.Hub:IsVisible() then
		local left = (HubBar.MARGIN + HubBar.WIDTH) * self.Hub.Scale.Scale + 16
		self.Panel.AnchorPoint = Vector2.new(0, 0.5)
		self.Panel.Position = UDim2.new(0, left, 0.5, 0)
	else
		self.Panel.AnchorPoint = Vector2.new(0.5, 0.5)
		self.Panel.Position = UDim2.fromScale(0.5, 0.5)
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
	self:_refreshHub()
	-- Menu fermé : inutile de tout reconstruire à chaque point de style.
	if not self.Gui.Enabled then
		self.Dirty = true
		return
	end
	self:_rebuild()
end

-- Bouton de la barre : ouvre l'onglet, ou referme le menu s'il y est déjà.
function MainMenu:OpenTab(tab: string)
	if self.Gui.Enabled and self.Tab == tab then
		self:SetOpen(false)
		return
	end
	self:SetTab(tab)
	self:SetOpen(true)
end

-- Barre de boutons visible (à pied, hors course) ; jamais sur mobile.
function MainMenu:SetHubVisible(visible: boolean)
	local shown = visible and not self.TouchLayout
	if self.Hub:IsVisible() == shown then
		return
	end
	self.Hub:SetVisible(shown)
	self:_refreshHub()
	self:_place()
end

function MainMenu:SetTab(tab: string)
	if self.Tab == tab then
		return
	end
	self.Tab = tab
	self.Status = ""
	self.Body.CanvasPosition = Vector2.zero
	self:_rebuild()
	self:_refreshHub()
end

function MainMenu:SetStatus(text: string, color: Color3?)
	self.Status = text
	self.StatusColor = color or Widgets.COLOR_DIM
	self:_rebuild()
end

function MainMenu:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
	self.Footer.Text = if enabled then "MENU  ·  fermer" else "C  ·  fermer le menu"
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
		-- Entrée « pop » : le menu jaillit puis se pose.
		Theme.Pop(self.Panel, scale, 0.9)
		local available = (viewport.Y - SCREEN_PADDING) / scale
		self.Panel.Size = UDim2.fromOffset(PANEL_WIDTH, math.min(760, available))
		self:_place()
		if self:_usingGamepad() then
			GuiService.SelectedObject = self.FirstButton
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
		GuiService.SelectedObject = nil
	end
	self:_refreshHub()
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
