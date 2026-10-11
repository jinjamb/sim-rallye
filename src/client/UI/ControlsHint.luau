--!strict
--[[
	ControlsHint.luau
	Les commandes, en bas au centre, pendant qu'on conduit (spéciale, course,
	essais libres) : une touche, ce qu'elle fait. Deux lignes : la conduite,
	puis les actions.

		- Clavier ou manette : suit le dernier appareil utilisé (on peut
		  changer en pleine course, l'aide suit).
		- Les lettres suivent la disposition du clavier du joueur (Z Q S D
		  sur un clavier AZERTY) : GetStringForKeyCode.
		- En course, seulement ce qui y sert (pas de « recommencer » ni de
		  fantôme).
		- F1 la replie en une pastille « F1 · commandes » (et la rouvre).
		- Masquée sur mobile : les commandes tactiles sont déjà légendées.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local ControlsHint = {}
ControlsHint.__index = ControlsHint

export type ControlsHint = typeof(setmetatable({}, ControlsHint)) & {
	Gui: ScreenGui,
	Root: Frame,
	Scale: UIScale,
	Lines: Frame,
	Collapsed: boolean,
	Shown: string, -- ce qui est affiché ("" : rien), pour ne reconstruire qu'au changement
}

type Entry = { Keys: { string }, Text: string }

local SCREEN_MARGIN = 18

-- Libellé d'une touche du clavier, dans la disposition du joueur.
local SPECIAL: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Space] = "ESPACE",
	[Enum.KeyCode.Backspace] = "⌫",
	[Enum.KeyCode.F1] = "F1",
}
local function key(code: Enum.KeyCode): string
	local special = SPECIAL[code]
	if special then
		return special
	end
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(code)
	end)
	return if ok and type(text) == "string" and text ~= "" then string.upper(text) else code.Name
end

local function keyboardEntries(racing: boolean): { { Entry } }
	local K = Enum.KeyCode
	local drive: { Entry } = {
		{ Keys = { key(K.W), key(K.S) }, Text = "Gaz · frein" },
		{ Keys = { key(K.A), key(K.D) }, Text = "Volant" },
		{ Keys = { key(K.Space) }, Text = "Frein à main" },
		{ Keys = { key(K.R), key(K.F) }, Text = "Rapports" },
		{ Keys = { key(K.M) }, Text = "Boîte auto" },
	}
	local actions: { Entry } = {
		{ Keys = { key(K.T) }, Text = if racing then "Remise en piste (à l'arrêt)" else "Remise en piste" },
		{ Keys = { key(K.B) }, Text = "Regarder derrière" },
		{ Keys = { key(K.K) }, Text = "Klaxon" },
		{ Keys = { key(K.C) }, Text = if racing then "Menu · abandon" else "Menu" },
	}
	if not racing then
		table.insert(actions, { Keys = { key(K.Backspace) }, Text = "Recommencer" })
		table.insert(actions, { Keys = { key(K.G) }, Text = "Fantôme" })
		table.insert(actions, { Keys = { key(K.L) }, Text = "Classement" })
		table.insert(actions, { Keys = { key(K.Q) }, Text = "Descendre" })
	end
	table.insert(actions, { Keys = { "F1" }, Text = "Masquer" })
	return { drive, actions }
end

local function gamepadEntries(racing: boolean): { { Entry } }
	local drive: { Entry } = {
		{ Keys = { "RT", "LT" }, Text = "Gaz · frein" },
		{ Keys = { "STICK G" }, Text = "Volant" },
		{ Keys = { "A" }, Text = "Frein à main" },
		{ Keys = { "RB", "LB" }, Text = "Rapports" },
		{ Keys = { "Y" }, Text = "Boîte auto" },
	}
	local actions: { Entry } = {
		{ Keys = { "◀ CROIX" }, Text = if racing then "Remise en piste (à l'arrêt)" else "Remise en piste" },
		{ Keys = { "STICK D ▼" }, Text = "Regarder derrière" },
		{ Keys = { "▶ CROIX" }, Text = if racing then "Menu · abandon" else "Menu" },
	}
	if not racing then
		table.insert(actions, { Keys = { "SELECT" }, Text = "Recommencer" })
		table.insert(actions, { Keys = { "R3" }, Text = "Classement" })
		table.insert(actions, { Keys = { "▼ CROIX" }, Text = "Descendre" })
	end
	return { drive, actions }
end

function ControlsHint.new(playerGui: Instance): ControlsHint
	local self = (setmetatable({}, ControlsHint) :: any) :: ControlsHint
	self.Collapsed = false
	self.Shown = ""

	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlsHint"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 3
	self.Gui = gui

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -SCREEN_MARGIN)
	root.Size = UDim2.fromOffset(0, 0)
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Root = root
	self.Scale = scale

	local lines = Instance.new("Frame")
	lines.BackgroundColor3 = Theme.PANEL
	lines.BackgroundTransparency = 0.25
	lines.BorderSizePixel = 0
	lines.AutomaticSize = Enum.AutomaticSize.XY
	lines.Size = UDim2.fromOffset(0, 0)
	Theme.Corner(lines)
	Theme.Ink(lines, Theme.LINE, 1.5, 0.6)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lines
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = lines
	lines.Parent = root
	self.Lines = lines

	UserInputService.LastInputTypeChanged:Connect(function()
		if self.Gui.Enabled then
			self.Shown = "" -- l'appareil a changé : reconstruit à la prochaine mise à jour
		end
	end)

	gui.Parent = playerGui
	return self
end

-- Une touche : case d'encre, lettre blanche.
local function keyCap(parent: Instance, text: string, order: number)
	local cap = Instance.new("TextLabel")
	cap.LayoutOrder = order
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Size = UDim2.fromOffset(22, 22)
	cap.BackgroundColor3 = Theme.INK
	cap.BorderSizePixel = 0
	cap.FontFace = Theme.HEADLINE
	cap.TextSize = 12
	cap.TextColor3 = Theme.TEXT
	cap.Text = text
	Theme.Corner(cap, 3)
	Theme.Ink(cap, Theme.LINE, 1.5, 0.3)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = cap
	cap.Parent = parent
end

local function line(parent: Instance, entries: { Entry }, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	row.LayoutOrder = order
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local n = 0
	for index, entry in ipairs(entries) do
		for _, keyText in ipairs(entry.Keys) do
			n += 1
			keyCap(row, keyText, n)
		end
		n += 1
		local text = Instance.new("TextLabel")
		text.LayoutOrder = n
		text.BackgroundTransparency = 1
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, 22)
		text.FontFace = Theme.BODY_BOLD
		text.TextSize = 13
		text.TextColor3 = Theme.TEXT
		text.Text = entry.Text
		text.Parent = row
		if index < #entries then
			-- Petit séparateur rose penché entre deux commandes.
			n += 1
			local dash = Instance.new("TextLabel")
			dash.LayoutOrder = n
			dash.BackgroundTransparency = 1
			dash.Size = UDim2.fromOffset(12, 22)
			dash.FontFace = Theme.HEADLINE
			dash.TextSize = 14
			dash.TextColor3 = Theme.ACCENT
			dash.Text = "/"
			dash.Parent = row
		end
	end
	row.Parent = parent
end

function ControlsHint:_build(racing: boolean, gamepad: boolean)
	for _, child in ipairs(self.Lines:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if self.Collapsed then
		line(self.Lines, { { Keys = { "F1" }, Text = "Commandes" } }, 1)
		return
	end
	local groups = if gamepad then gamepadEntries(racing) else keyboardEntries(racing)
	for index, entries in ipairs(groups) do
		line(self.Lines, entries, index)
	end
end

--[[
	À chaque image : `visible` (au volant, pas en ralenti ni en spectateur),
	`racing` (course de rallycross : seulement ce qui y sert).
]]
function ControlsHint:Update(visible: boolean, racing: boolean)
	self.Gui.Enabled = visible
	if not visible then
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)
	local last = UserInputService:GetLastInputType()
	local gamepad = last.Name:sub(1, 7) == "Gamepad"
	local state = string.format("%s|%s|%s", tostring(racing), tostring(gamepad), tostring(self.Collapsed))
	if state ~= self.Shown then
		self.Shown = state
		self:_build(racing, gamepad)
	end
end

-- F1 : replie ou rouvre l'aide.
function ControlsHint:ToggleCollapsed()
	self.Collapsed = not self.Collapsed
	self.Shown = ""
end

return ControlsHint
