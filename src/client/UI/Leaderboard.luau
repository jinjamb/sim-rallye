--!strict
--[[
	Leaderboard.luau
	Classement de la spéciale, envoyé par le serveur (RecordService) : les dix
	meilleurs temps officiels, tous joueurs confondus, sauvegardés d'une partie à
	l'autre. Sa propre ligne est surlignée.
	En haut à droite ; L (ou stick droit enfoncé) l'affiche ou le masque.

	Chaque temps porte la pastille de sa médaille (Medals.luau). Cliquer sur
	une ligne défie le fantôme de ce pilote (GhostChallenge.luau) ; la ligne
	du bas dit contre quel fantôme on roule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Theme)

local Leaderboard = {}
Leaderboard.__index = Leaderboard

export type Entry = { UserId: number, Name: string, Ms: number }

export type Leaderboard = typeof(setmetatable({}, Leaderboard)) & {
	LocalUserId: number,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	Title: TextLabel,
	Rows: { TextButton },
	Dots: { Frame },
	RowUserIds: { [number]: number },
	Empty: TextLabel,
	Footer: TextLabel,
	GhostText: string,
	Touch: boolean,
	Shown: boolean,
}

local ROWS = 10
local PANEL_WIDTH = 300
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 38 -- titre et filet à damier
local FOOTER_HEIGHT = 34
local DOT_SIZE = 10
local SCREEN_MARGIN = 24
local TOP_OFFSET = 64 -- sous la barre de Roblox

local COLOR_PANEL = Theme.PANEL
local COLOR_TEXT = Theme.TEXT
local COLOR_DIM = Theme.DIM
local COLOR_SELF = Theme.ACCENT

-- `onChallenge(userId)` : clic sur une ligne, défier le fantôme de ce pilote.
function Leaderboard.new(playerGui: Instance, localUserId: number, onChallenge: (number) -> ()): Leaderboard
	local self = (setmetatable({}, Leaderboard) :: any) :: Leaderboard
	self.LocalUserId = localUserId
	self.Shown = true
	self.RowUserIds = {}
	self.GhostText = ""
	self.Touch = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "Leaderboard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -SCREEN_MARGIN, 0, TOP_OFFSET)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT + ROWS * ROW_HEIGHT + FOOTER_HEIGHT + 6)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	Theme.Corner(panel)
	Theme.Shade(panel)
	Theme.AccentBar(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	self.Panel = panel
	self.Scale = scale

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 17
	title.TextColor3 = COLOR_TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "CLASSEMENT · SPÉCIALE"
	title.Parent = panel
	self.Title = title
	-- Filet à damier sous le titre, comme un tableau de chronométrage TV.
	local checker = Theme.Checker(panel, PANEL_WIDTH, 3, 2)
	checker.Position = UDim2.fromOffset(0, HEADER_HEIGHT - 9)
	checker.BackgroundTransparency = 0.4

	self.Rows = {}
	self.Dots = {}
	for i = 1, ROWS do
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(12, HEADER_HEIGHT + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
		row.Font = Enum.Font.RobotoMono
		row.TextSize = 15
		row.TextColor3 = COLOR_TEXT
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = panel
		row.Activated:Connect(function()
			local userId = self.RowUserIds[i]
			if userId then
				onChallenge(userId)
			end
		end)
		self.Rows[i] = row
		-- Pastille de la médaille, au bout de la ligne.
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(1, 0, 0.5, 0)
		dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		dot.BorderSizePixel = 0
		dot.Visible = false
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		dot.Parent = row
		self.Dots[i] = dot
	end

	local empty = Instance.new("TextLabel")
	empty.BackgroundTransparency = 1
	empty.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	empty.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
	empty.Font = Enum.Font.GothamMedium
	empty.TextSize = 14
	empty.TextColor3 = COLOR_DIM
	empty.TextXAlignment = Enum.TextXAlignment.Left
	empty.Text = "Aucun temps pour l'instant."
	empty.Parent = panel
	self.Empty = empty

	-- Contre quel fantôme on roule, et comment en changer.
	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromOffset(12, HEADER_HEIGHT + ROWS * ROW_HEIGHT + 4)
	footer.Size = UDim2.new(1, -24, 0, FOOTER_HEIGHT)
	footer.Font = Enum.Font.GothamMedium
	footer.TextSize = 12
	footer.TextColor3 = COLOR_DIM
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextYAlignment = Enum.TextYAlignment.Top
	footer.TextWrapped = true
	footer.Text = ""
	footer.Parent = panel
	self.Footer = footer
	self:SetGhostInfo("Fantôme : ton record")

	gui.Parent = playerGui
	return self
end

-- Titre du panneau (le défi de la semaine a son propre classement).
function Leaderboard:SetTitle(text: string)
	self.Title.Text = text
end

-- `medals` : pastilles de médaille (la spéciale habituelle ; pas le défi).
function Leaderboard:SetEntries(entries: { Entry }, medals: boolean?)
	self.Empty.Visible = #entries == 0
	local limits = Medals.ForStage()
	for i, row in ipairs(self.Rows) do
		local entry = entries[i]
		local dot = self.Dots[i]
		self.RowUserIds[i] = if entry then entry.UserId else nil
		local tier = if entry and medals ~= false then Medals.Get(Medals.TierOf(entry.Ms, limits)) else nil
		dot.Visible = tier ~= nil
		if tier then
			dot.BackgroundColor3 = tier.Color
		end
		if entry then
			-- Nom tronqué : la colonne des temps reste alignée (police à chasse fixe).
			local name = entry.Name
			if utf8.len(name) and (utf8.len(name) :: number) > 16 then
				local cut = utf8.offset(name, 16)
				name = (if cut then string.sub(name, 1, cut - 1) else name) .. "…"
			end
			local padding = math.max(0, 17 - (utf8.len(name) or #name))
			row.Text = string.format("%2d. %s%s%s", i, name, string.rep(" ", padding), Format.Ms(entry.Ms))
			row.TextColor3 = if entry.UserId == self.LocalUserId then COLOR_SELF else COLOR_TEXT
		else
			row.Text = ""
		end
	end
end

-- Ligne du bas : le fantôme affronté (GhostChallenge:Describe()).
function Leaderboard:SetGhostInfo(text: string)
	self.GhostText = text
	self.Footer.Text = text
		.. (if self.Touch then "\nFANTÔME : changer · touche un pilote : le défier" else "\nG : changer · clic sur un pilote : le défier")
end

-- Visible quand on pilote (Main) ET pas masqué par le joueur (L).
function Leaderboard:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

-- Disposition tactile : le tableau de bord occupe le haut à droite ; le
-- classement s'ouvre au centre, à la demande (bouton TEMPS), masqué par défaut.
function Leaderboard:SetTouchLayout(enabled: boolean)
	self.Touch = enabled
	self:SetGhostInfo(self.GhostText)
	if enabled then
		self.Panel.AnchorPoint = Vector2.new(0.5, 0.5)
		self.Panel.Position = UDim2.fromScale(0.5, 0.5)
		self.Shown = false
	else
		self.Panel.AnchorPoint = Vector2.new(1, 0)
		self.Panel.Position = UDim2.new(1, -SCREEN_MARGIN, 0, TOP_OFFSET)
		self.Shown = true
	end
	self.Panel.Visible = self.Shown
end

function Leaderboard:Toggle()
	self.Shown = not self.Shown
	self.Panel.Visible = self.Shown
end

function Leaderboard:Update()
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)
end

return Leaderboard
