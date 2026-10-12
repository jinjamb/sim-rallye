--!strict
--[[
	HubBar.luau
	La barre de boutons à gauche de l'écran, à pied : comme dans les jeux
	Roblox, tout est là pendant qu'on se promène au paddock, et un clic
	ouvre la rubrique.

		en haut   le solde de crédits et le niveau (avec la barre d'XP) ;
		dessous   un bouton par onglet du menu (icône, nom) : JOUER, DÉFIS,
		          PASS, ÉCURIE, BOUTIQUE, CARRIÈRE. Le bouton de l'onglet
		          ouvert est rose ; un second clic referme le menu.

	Le menu s'ouvre à côté de la barre (MainMenu.luau), pas au milieu : le
	personnage reste visible et continue de marcher (ZQSD) menu ouvert.
	Masquée au volant, en course, pendant un ralenti, et sur mobile (le
	bouton MENU des commandes tactiles fait ce travail).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

local HubBar = {}
HubBar.__index = HubBar

export type Tab = { Id: string, Name: string, Icon: string }

export type HubBar = typeof(setmetatable({}, HubBar)) & {
	Gui: ScreenGui,
	Root: Frame,
	Scale: UIScale,
	Buttons: { [string]: TextButton },
	CreditsLabel: TextLabel,
	LevelLabel: TextLabel,
	XpFill: Frame,
}

HubBar.WIDTH = 84 -- largeur de la barre (le menu s'ouvre juste à droite)
HubBar.MARGIN = 16
local BUTTON_HEIGHT = 60
local GAP = 8
local WALLET_HEIGHT = 64

-- `onTab(id)` : clic sur le bouton d'un onglet.
function HubBar.new(playerGui: Instance, tabs: { Tab }, onTab: (string) -> ()): HubBar
	local self = (setmetatable({}, HubBar) :: any) :: HubBar
	self.Buttons = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubBar"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	self.Gui = gui

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0, HubBar.MARGIN, 0.5, 0)
	root.Size = UDim2.fromOffset(HubBar.WIDTH, WALLET_HEIGHT + GAP + #tabs * (BUTTON_HEIGHT + GAP))
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Root = root
	self.Scale = scale

	-- Solde et niveau : toujours sous les yeux.
	local wallet = Instance.new("Frame")
	wallet.Size = UDim2.fromOffset(HubBar.WIDTH, WALLET_HEIGHT)
	Theme.Card(wallet, 0.1, Theme.YELLOW)
	wallet.Parent = root
	local credits = Widgets.Label(wallet, "…", 15, Enum.Font.GothamBlack, Theme.YELLOW)
	credits.TextXAlignment = Enum.TextXAlignment.Center
	credits.Position = UDim2.fromOffset(0, 6)
	credits.Size = UDim2.new(1, 0, 0, 20)
	credits.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 15
	limit.Parent = credits
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = credits
	self.CreditsLabel = credits
	local level = Widgets.Label(wallet, "NIV. –", 12, Enum.Font.GothamBlack, Theme.TEXT)
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.Position = UDim2.fromOffset(0, 28)
	level.Size = UDim2.new(1, 0, 0, 16)
	self.LevelLabel = level
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.INK
	track.Position = UDim2.fromOffset(10, 48)
	track.Size = UDim2.new(1, -20, 0, 6)
	track.Parent = wallet
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.ACCENT
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	self.XpFill = fill

	-- Un bouton par onglet.
	for index, tab in ipairs(tabs) do
		local button = Widgets.Button(root, "", function()
			onTab(tab.Id)
		end)
		button.Name = tab.Id
		button.Position = UDim2.fromOffset(0, WALLET_HEIGHT + GAP + (index - 1) * (BUTTON_HEIGHT + GAP))
		button.Size = UDim2.fromOffset(HubBar.WIDTH, BUTTON_HEIGHT)
		button.BackgroundColor3 = Theme.PANEL
		button.BackgroundTransparency = 0.12
		Theme.Ink(button)
		local icon = Widgets.Label(button, tab.Icon, 24)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.Position = UDim2.fromOffset(0, 6)
		icon.Size = UDim2.new(1, 0, 0, 28)
		local name = Widgets.Label(button, tab.Name, 10, Enum.Font.GothamBlack, Theme.TEXT)
		name.Name = "TabName"
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position = UDim2.fromOffset(0, 36)
		name.Size = UDim2.new(1, 0, 0, 16)
		self.Buttons[tab.Id] = button
	end

	gui.Parent = playerGui
	return self
end

function HubBar:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function HubBar:IsVisible(): boolean
	return self.Gui.Enabled
end

--[[
	État affiché : l'onglet ouvert (nil : menu fermé), le solde, la
	progression. Appelé par le menu à chaque changement.
]]
function HubBar:Refresh(openTab: string?, credits: number?, progress: Progression.Snapshot?)
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.7, 1.2)
	for id, button in pairs(self.Buttons) do
		local active = id == openTab
		button.BackgroundColor3 = if active then Theme.ACCENT else Theme.PANEL
		button.BackgroundTransparency = if active then 0 else 0.12
	end
	self.CreditsLabel.Text = if credits then Credits.Format(credits) else "… " .. Credits.SHORT
	if progress then
		self.LevelLabel.Text = "NIV. " .. tostring(progress.Level)
		local nextXp = progress.NextXp
		local fraction = if nextXp and nextXp > progress.LevelXp
			then (progress.Xp - progress.LevelXp) / (nextXp - progress.LevelXp)
			else 1
		self.XpFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

return HubBar
