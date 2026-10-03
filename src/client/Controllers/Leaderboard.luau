--!strict
--[[
	Leaderboard.luau
	Classement de la spéciale, envoyé par le serveur (RecordService) : les dix
	meilleurs temps officiels, tous joueurs confondus, sauvegardés d'une partie à
	l'autre. Sa propre ligne est surlignée.
	En haut à droite ; L (ou stick droit enfoncé) l'affiche ou le masque.
]]

local Leaderboard = {}
Leaderboard.__index = Leaderboard

export type Entry = { UserId: number, Name: string, Ms: number }

export type Leaderboard = typeof(setmetatable({}, Leaderboard)) & {
	LocalUserId: number,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	Rows: { TextLabel },
	Empty: TextLabel,
	Shown: boolean,
}

local ROWS = 10
local PANEL_WIDTH = 300
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 30
local SCREEN_MARGIN = 24
local TOP_OFFSET = 64 -- sous la barre de Roblox

local COLOR_PANEL = Color3.fromRGB(14, 15, 18)
local COLOR_TEXT = Color3.fromRGB(235, 236, 240)
local COLOR_DIM = Color3.fromRGB(130, 134, 145)
local COLOR_SELF = Color3.fromRGB(245, 200, 55)

local function formatTime(ms: number): string
	local seconds = ms / 1000
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%05.2f", minutes, seconds - minutes * 60)
end

function Leaderboard.new(playerGui: Instance, localUserId: number): Leaderboard
	local self = (setmetatable({}, Leaderboard) :: any) :: Leaderboard
	self.LocalUserId = localUserId
	self.Shown = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "Leaderboard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -SCREEN_MARGIN, 0, TOP_OFFSET)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT + ROWS * ROW_HEIGHT + 10)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	self.Panel = panel
	self.Scale = scale

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = COLOR_DIM
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "CLASSEMENT DE LA SPÉCIALE"
	title.Parent = panel

	self.Rows = {}
	for i = 1, ROWS do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(12, HEADER_HEIGHT + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
		row.Font = Enum.Font.RobotoMono
		row.TextSize = 15
		row.TextColor3 = COLOR_TEXT
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = ""
		row.Parent = panel
		self.Rows[i] = row
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

	gui.Parent = playerGui
	return self
end

function Leaderboard:SetEntries(entries: { Entry })
	self.Empty.Visible = #entries == 0
	for i, row in ipairs(self.Rows) do
		local entry = entries[i]
		if entry then
			-- Nom tronqué : la colonne des temps reste alignée (police à chasse fixe).
			local name = entry.Name
			if utf8.len(name) and (utf8.len(name) :: number) > 16 then
				local cut = utf8.offset(name, 16)
				name = (if cut then string.sub(name, 1, cut - 1) else name) .. "…"
			end
			local padding = math.max(0, 17 - (utf8.len(name) or #name))
			row.Text = string.format("%2d. %s%s%s", i, name, string.rep(" ", padding), formatTime(entry.Ms))
			row.TextColor3 = if entry.UserId == self.LocalUserId then COLOR_SELF else COLOR_TEXT
		else
			row.Text = ""
		end
	end
end

-- Visible quand on pilote (Main) ET pas masqué par le joueur (L).
function Leaderboard:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
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
