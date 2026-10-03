--!strict
--[[
	SetupMenu.luau
	Menu des réglages de la voiture, construit à partir du schéma partagé
	(Shared/Constants/CarSetup.luau) : ajouter un réglage au schéma l'ajoute ici.

	P (ou stick gauche enfoncé) ouvre et ferme. Chaque réglage se change par
	pas avec -/+ ; une ligne explique l'effet du dernier réglage touché.
	Préréglages : Défaut, Terre, Asphalte.
	Les changements s'appliquent à la voiture aussitôt (callback OnChange, voir
	Main.client.luau), voiture en mouvement comprise, et sont sauvegardés.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)

local SetupMenu = {}
SetupMenu.__index = SetupMenu

export type SetupMenu = typeof(setmetatable({}, SetupMenu)) & {
	Setup: CarSetup.Setup,
	OnChange: (CarSetup.Setup) -> (),
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	ValueLabels: { [string]: TextLabel },
	HintLabel: TextLabel,
	FirstButton: GuiButton?,
}

local PANEL_WIDTH = 470
local ROW_HEIGHT = 26
local GROUP_HEIGHT = 24

local COLOR_PANEL = Color3.fromRGB(14, 15, 18)
local COLOR_BUTTON = Color3.fromRGB(45, 47, 55)
local COLOR_TEXT = Color3.fromRGB(235, 236, 240)
local COLOR_DIM = Color3.fromRGB(130, 134, 145)
local COLOR_ACCENT = Color3.fromRGB(245, 200, 55)

local function makeLabel(parent: Instance, position: UDim2, size: UDim2, text: string, textSize: number, font: Enum.Font, color: Color3, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextSize = textSize
	label.Font = font
	label.TextColor3 = color
	label.TextXAlignment = alignment
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, position: UDim2, size: UDim2, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = size
	button.Text = text
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = COLOR_TEXT
	button.BackgroundColor3 = COLOR_BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Selectable = true -- navigation à la manette
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function formatValue(field: CarSetup.Field, value: number): string
	return string.format(field.Format, value * field.Scale)
end

function SetupMenu.new(playerGui: Instance, onChange: (CarSetup.Setup) -> ()): SetupMenu
	local self = (setmetatable({}, SetupMenu) :: any) :: SetupMenu
	self.Setup = CarSetup.Default()
	self.OnChange = onChange
	self.ValueLabels = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "SetupMenu"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10
	self.Gui = gui

	-- Hauteur : titre, préréglages, un intertitre par groupe, une ligne par
	-- réglage, l'explication en bas.
	local groups: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, field in ipairs(CarSetup.FIELDS) do
		if not seen[field.Group] then
			seen[field.Group] = true
			table.insert(groups, field.Group)
		end
	end
	local height = 40 + 40 + #groups * GROUP_HEIGHT + #CarSetup.FIELDS * ROW_HEIGHT + 60

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 24, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, height)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	self.Panel = panel
	self.Scale = scale

	makeLabel(panel, UDim2.fromOffset(14, 10), UDim2.new(1, -60, 0, 22), "RÉGLAGES DE LA VOITURE", 16, Enum.Font.GothamBlack, COLOR_TEXT, Enum.TextXAlignment.Left)
	local close = makeButton(panel, UDim2.new(1, -40, 0, 8), UDim2.fromOffset(28, 26), "×")
	close.Activated:Connect(function()
		self:SetOpen(false)
	end)

	-- Préréglages
	local y = 42
	local presetWidth = (PANEL_WIDTH - 28 - (#CarSetup.PRESETS - 1) * 8) / #CarSetup.PRESETS
	for i, preset in ipairs(CarSetup.PRESETS) do
		local button = makeButton(panel, UDim2.fromOffset(14 + (i - 1) * (presetWidth + 8), y), UDim2.fromOffset(presetWidth, 28), string.upper(preset.Name))
		button.TextSize = 13
		button.Activated:Connect(function()
			self:_set(CarSetup.WithPreset(preset.Name), "Préréglage « " .. preset.Name .. " » appliqué.")
		end)
		if i == 1 then
			self.FirstButton = button
		end
	end
	y += 40

	-- Réglages, par groupe
	for _, group in ipairs(groups) do
		makeLabel(panel, UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, GROUP_HEIGHT), string.upper(group), 12, Enum.Font.GothamBold, COLOR_ACCENT, Enum.TextXAlignment.Left)
		y += GROUP_HEIGHT
		for _, field in ipairs(CarSetup.FIELDS) do
			if field.Group == group then
				makeLabel(panel, UDim2.fromOffset(22, y), UDim2.fromOffset(220, ROW_HEIGHT), field.Label, 14, Enum.Font.GothamMedium, COLOR_TEXT, Enum.TextXAlignment.Left)
				local minus = makeButton(panel, UDim2.fromOffset(PANEL_WIDTH - 190, y + 2), UDim2.fromOffset(32, ROW_HEIGHT - 4), "−")
				local value = makeLabel(panel, UDim2.fromOffset(PANEL_WIDTH - 152, y), UDim2.fromOffset(100, ROW_HEIGHT), "", 14, Enum.Font.RobotoMono, COLOR_TEXT, Enum.TextXAlignment.Center)
				local plus = makeButton(panel, UDim2.fromOffset(PANEL_WIDTH - 46, y + 2), UDim2.fromOffset(32, ROW_HEIGHT - 4), "+")
				self.ValueLabels[field.Key] = value
				minus.Activated:Connect(function()
					self:_set(CarSetup.Step(self.Setup, field.Key, -1), field.Hint)
				end)
				plus.Activated:Connect(function()
					self:_set(CarSetup.Step(self.Setup, field.Key, 1), field.Hint)
				end)
				y += ROW_HEIGHT
			end
		end
	end

	local hint = makeLabel(panel, UDim2.fromOffset(14, y + 8), UDim2.new(1, -28, 0, 44), "", 13, Enum.Font.GothamMedium, COLOR_DIM, Enum.TextXAlignment.Left)
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Text = "Les changements s'appliquent tout de suite et sont sauvegardés."
	self.HintLabel = hint

	gui.Parent = playerGui
	self:_refresh()
	return self
end

function SetupMenu:_refresh()
	for _, field in ipairs(CarSetup.FIELDS) do
		local label = self.ValueLabels[field.Key]
		if label then
			label.Text = formatValue(field, self.Setup[field.Key] or field.Default)
		end
	end
end

function SetupMenu:_set(setup: CarSetup.Setup, hint: string)
	self.Setup = setup
	self.HintLabel.Text = hint
	self:_refresh()
	self.OnChange(setup)
end

-- Réglages venus de la sauvegarde : affichés, sans déclencher OnChange.
function SetupMenu:SetSetup(setup: CarSetup.Setup)
	self.Setup = CarSetup.Sanitize(setup)
	self:_refresh()
end

function SetupMenu:IsOpen(): boolean
	return self.Gui.Enabled
end

function SetupMenu:SetOpen(open: boolean)
	self.Gui.Enabled = open
	if open then
		local viewport = workspace.CurrentCamera.ViewportSize
		self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)
		-- À la manette, la sélection démarre sur le premier bouton.
		GuiService.SelectedObject = self.FirstButton
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
		GuiService.SelectedObject = nil
	end
end

function SetupMenu:Toggle()
	self:SetOpen(not self:IsOpen())
end

return SetupMenu
