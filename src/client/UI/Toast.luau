--!strict
--[[
	Toast.luau
	Petites notifications, en haut à droite : ce qu'on gagne en passant
	(« +25 CR · Spéciale terminée », un palier du Rallye Pass...). Discrètes
	et empilées, contrairement aux bandeaux (Banner.luau), réservés aux
	grandes nouvelles. Elles s'effacent seules ; au-delà de MAX_VISIBLE, la
	plus ancienne part tout de suite.

	Module unique (pas d'instance), comme Banner.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toast = {}

local WIDTH = 260
local HEIGHT = 34
local GAP = 6
local MAX_VISIBLE = 4
local DURATION = 3.5 -- secondes affichée
local FADE_TIME = 0.3
local TOP = 120 -- sous les boutons de Roblox et le classement

local stack: Frame? = nil
local shown: { CanvasGroup } = {}

local function container(): Frame
	local existing = stack
	if existing and existing.Parent then
		return existing
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Toasts"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 9
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -16, 0, TOP)
	frame.Size = UDim2.fromOffset(WIDTH, (HEIGHT + GAP) * MAX_VISIBLE)
	frame.BackgroundTransparency = 1
	frame.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = frame
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	stack = frame
	return frame
end

local function dismiss(toast: CanvasGroup)
	local index = table.find(shown, toast)
	if index then
		table.remove(shown, index)
	end
	local tween = TweenService:Create(toast, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		toast:Destroy()
	end)
	tween:Play()
end

local order = 0

-- `text` : texte enrichi permis ; `color` : le bloc de gauche (jaune par défaut).
function Toast.Show(text: string, color: Color3?)
	local parent = container()
	while #shown >= MAX_VISIBLE do
		local oldest = table.remove(shown, 1) :: CanvasGroup
		oldest:Destroy()
	end
	order += 1
	local toast = Instance.new("CanvasGroup")
	toast.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	toast.BackgroundColor3 = Theme.PANEL
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0
	toast.GroupTransparency = 1
	toast.LayoutOrder = order
	Theme.Corner(toast)
	local block = Instance.new("Frame")
	block.BorderSizePixel = 0
	block.BackgroundColor3 = color or Theme.ACCENT
	block.Size = UDim2.new(0, 6, 1, 0)
	block.Parent = toast
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, 0)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.FontFace = Theme.BODY_BOLD
	label.TextSize = 15
	label.TextColor3 = Theme.TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.RichText = true
	label.Text = text
	label.Parent = toast
	toast.Parent = parent
	table.insert(shown, toast)
	TweenService:Create(toast, TweenInfo.new(FADE_TIME), { GroupTransparency = 0 }):Play()
	task.delay(DURATION, function()
		if toast.Parent then
			dismiss(toast)
		end
	end)
end

return Toast
