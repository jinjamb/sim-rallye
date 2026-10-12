--!strict
--[[
	Widgets.luau
	Petits constructeurs d'interface au style du jeu, partagés par tous les
	écrans (menu, HUD, garage...) : panneaux nuit indigo à contour net et
	ombre portée rose, boutons qui « réagissent » (survol, sélection à la
	manette, appui), étiquettes (Theme.luau pour les couleurs et les polices).
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Widgets = {}

-- Style ---------------------------------------------------------------------------

Widgets.COLOR_PANEL = Theme.PANEL
Widgets.COLOR_BUTTON = Theme.PANEL_2
Widgets.COLOR_TEXT = Theme.TEXT
Widgets.COLOR_DIM = Theme.DIM
Widgets.COLOR_ACCENT = Theme.ACCENT
Widgets.COLOR_GREEN = Theme.GREEN
Widgets.COLOR_RED = Theme.RED
Widgets.COLOR_ORANGE = Theme.ORANGE
Widgets.COLOR_BLUE = Theme.BLUE

local HOVER_SCALE = 1.04
local PRESS_SCALE = 0.96
local REACT_TIME = 0.08

-- Angles vifs (Theme) ; un rond (rayon égal à la taille) reste un rond.
function Widgets.Corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, if radius >= 20 then radius else Theme.CORNER)
	corner.Parent = parent
end

-- Panneau du jeu : nuit indigo, contour net, ombre portée rose.
function Widgets.Panel(parent: Instance, transparency: number?): Frame
	local frame = Instance.new("Frame")
	Theme.Card(frame, transparency or 0.12)
	frame.Parent = parent
	return frame
end

function Widgets.Label(parent: Instance, text: string, textSize: number, font: Enum.Font?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.Font = font or Enum.Font.GothamMedium
	label.TextColor3 = color or Widgets.COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

--[[
	Bouton du jeu : italique, angles vifs. Il réagit comme dans un jeu de
	course : au survol ou à la sélection (manette), contour jaune et léger
	grossissement ; à l'appui, il s'enfonce.
]]
function Widgets.Button(parent: Instance, text: string, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.TextSize = 14
	button.FontFace = Theme.HEADLINE_MEDIUM
	button.TextColor3 = Widgets.COLOR_TEXT
	button.BackgroundColor3 = Widgets.COLOR_BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Selectable = true -- navigation à la manette
	Theme.Corner(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	-- Sélection à la manette ou survol : cadre jaune.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.YELLOW
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = button
	local function scaleTo(value: number)
		TweenService:Create(scale, TweenInfo.new(REACT_TIME, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	local function focus(on: boolean)
		stroke.Enabled = on
		scaleTo(if on then HOVER_SCALE else 1)
	end
	button.SelectionGained:Connect(function()
		focus(true)
	end)
	button.SelectionLost:Connect(function()
		focus(false)
	end)
	button.MouseEnter:Connect(function()
		focus(true)
	end)
	button.MouseLeave:Connect(function()
		focus(false)
	end)
	button.MouseButton1Down:Connect(function()
		scaleTo(PRESS_SCALE)
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(if stroke.Enabled then HOVER_SCALE else 1)
	end)
	button.Activated:Connect(callback)
	button.Parent = parent
	return button
end

-- Action principale (lancer, rejoindre) : rose, texte blanc.
Widgets.Primary = Theme.Primary
Widgets.Danger = Theme.Danger

return Widgets
