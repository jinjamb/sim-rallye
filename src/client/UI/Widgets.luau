--!strict
--[[
	Widgets.luau
	Petits constructeurs d'interface au style du jeu, partagés par tous les
	écrans (menu, HUD, garage...) : panneaux noirs à angles vifs et liseré
	jaune, boutons, étiquettes (Theme.luau pour les couleurs et les polices).
]]

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

-- Angles presque vifs (Theme) ; un rond (rayon égal à la taille) reste un rond.
function Widgets.Corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, if radius >= 20 then radius else Theme.CORNER)
	corner.Parent = parent
end

-- Panneau du jeu : noir, angles vifs, léger dégradé, liseré jaune à gauche.
function Widgets.Panel(parent: Instance, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Widgets.COLOR_PANEL
	frame.BackgroundTransparency = transparency or 0.12
	frame.BorderSizePixel = 0
	Theme.Corner(frame)
	Theme.Shade(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.LINE
	stroke.Transparency = 0.9
	stroke.Parent = frame
	Theme.AccentBar(frame)
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

function Widgets.Button(parent: Instance, text: string, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Widgets.COLOR_TEXT
	button.BackgroundColor3 = Widgets.COLOR_BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Selectable = true -- navigation à la manette
	Theme.Corner(button)
	-- Sélection à la manette ou survol : cadre jaune.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.ACCENT
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = button
	button.SelectionGained:Connect(function()
		stroke.Enabled = true
	end)
	button.SelectionLost:Connect(function()
		stroke.Enabled = false
	end)
	button.MouseEnter:Connect(function()
		stroke.Enabled = true
	end)
	button.MouseLeave:Connect(function()
		stroke.Enabled = false
	end)
	button.Activated:Connect(callback)
	button.Parent = parent
	return button
end

-- Action principale (lancer, rejoindre) : jaune, texte noir.
Widgets.Primary = Theme.Primary
Widgets.Danger = Theme.Danger

return Widgets
