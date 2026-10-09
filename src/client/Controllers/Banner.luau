--!strict
--[[
	Banner.luau
	Bandeau d'annonce, en haut au centre de l'écran : une médaille décrochée,
	le fantôme qu'on affronte, un rival battu. Un titre en grand, une ligne en
	dessous, un liseré de couleur ; il apparaît, reste, puis s'efface.
	Un seul bandeau à la fois : le suivant remplace le précédent.

	Module unique (pas d'instance) : la spéciale (DrivingSession) comme le
	rallycross (RaceClient) l'appellent directement.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Banner = {}

local COLOR_PANEL = Color3.fromRGB(14, 15, 18)
local COLOR_TEXT = Color3.fromRGB(235, 236, 240)
-- Hauteur (fraction de l'écran) : sous le bandeau du copilote, au-dessus des
-- messages du rallycross (RaceHud, à 36 %).
local TOP_POSITION = 0.22
local FADE_TIME = 0.25

type Parts = {
	Gui: ScreenGui,
	Panel: Frame,
	Stroke: UIStroke,
	Scale: UIScale,
	Title: TextLabel,
	Subtitle: TextLabel,
}

local parts: Parts? = nil
local token = 0

local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "Banner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- au-dessus du chrono et du tableau de bord

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, TOP_POSITION)
	panel.Size = UDim2.fromOffset(0, 74)
	panel.AutomaticSize = Enum.AutomaticSize.X
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 28)
	padding.PaddingRight = UDim.new(0, 28)
	padding.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	local function line(y: number, height: number, size: number, font: Enum.Font): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.fromOffset(0, height)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Font = font
		label.TextSize = size
		label.TextColor3 = COLOR_TEXT
		label.Text = ""
		label.Parent = panel
		return label
	end
	local title = line(8, 34, 30, Enum.Font.GothamBlack)
	local subtitle = line(44, 20, 15, Enum.Font.GothamMedium)

	-- Les deux lignes centrées l'une sous l'autre, le cadre suit la plus large.
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	title.LayoutOrder = 1
	subtitle.LayoutOrder = 2

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		Gui = gui,
		Panel = panel,
		Stroke = stroke,
		Scale = scale,
		Title = title,
		Subtitle = subtitle,
	}
end

--[[
	Affiche un bandeau pendant `duration` secondes.
	`big` : le grand format, réservé aux médailles.
]]
function Banner.Show(title: string, subtitle: string?, color: Color3, duration: number, big: boolean?)
	local current = parts
	if not current then
		current = build()
		parts = current
	end
	local p = current :: Parts
	token += 1
	local mine = token

	local viewport = workspace.CurrentCamera.ViewportSize
	local base = math.clamp(viewport.Y / 1080, 0.6, 1.2)
	p.Title.Text = title
	p.Title.TextColor3 = color
	p.Title.TextSize = if big then 30 else 22
	p.Subtitle.Text = subtitle or ""
	p.Subtitle.Visible = subtitle ~= nil
	p.Panel.Size = UDim2.fromOffset(0, if subtitle then (if big then 74 else 62) else 44)
	p.Stroke.Color = color
	p.Stroke.Transparency = 0
	p.Panel.BackgroundTransparency = 0.15
	p.Title.TextTransparency = 0
	p.Subtitle.TextTransparency = 0
	p.Panel.Visible = true

	-- Entrée : un léger rebond pour les médailles, un simple fondu sinon.
	p.Scale.Scale = base * (if big then 0.6 else 0.9)
	TweenService:Create(
		p.Scale,
		TweenInfo.new(if big then 0.35 else 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = base }
	):Play()

	task.delay(duration, function()
		if mine ~= token then
			return -- remplacé entre-temps
		end
		local info = TweenInfo.new(FADE_TIME)
		TweenService:Create(p.Panel, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(p.Stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(p.Title, info, { TextTransparency = 1 }):Play()
		TweenService:Create(p.Subtitle, info, { TextTransparency = 1 }):Play()
		task.delay(FADE_TIME, function()
			if mine == token then
				p.Panel.Visible = false
			end
		end)
	end)
end

return Banner
