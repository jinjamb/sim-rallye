--!strict
--[[
	Banner.luau
	Bandeau d'annonce, en haut au centre de l'écran : une médaille décrochée,
	le fantôme qu'on affronte, un rival battu. Un titre en grand, une ligne en
	dessous, un bloc de couleur, un filet à damier, comme à la télévision ; il
	apparaît, reste, puis s'efface.
	Un seul bandeau à la fois. Un petit bandeau (info) remplace le précédent ;
	un GRAND bandeau (médaille, niveau, déblocage) n'est jamais coupé : ce qui
	arrive pendant qu'il est affiché attend son tour (file d'attente).

	Module unique (pas d'instance) : la spéciale (DrivingSession) comme le
	rallycross (RaceClient) l'appellent directement.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Banner = {}

local COLOR_PANEL = Theme.PANEL
local COLOR_TEXT = Theme.TEXT
-- Hauteur (fraction de l'écran) : sous le bandeau du copilote, au-dessus des
-- messages du rallycross (RaceHud, à 36 %).
local TOP_POSITION = 0.22
local FADE_TIME = 0.25

type Parts = {
	Gui: ScreenGui,
	Panel: CanvasGroup,
	Block: Frame,
	Scale: UIScale,
	Title: TextLabel,
	Subtitle: TextLabel,
}

local parts: Parts? = nil
local token = 0
-- Grand bandeau affiché jusqu'à cette heure (os.clock) : les suivants attendent.
local bigUntil = 0
type Pending = { Title: string, Subtitle: string?, Color: Color3, Duration: number, Big: boolean }
local queue: { Pending } = {}
local MAX_QUEUE = 4
local display: (Pending) -> ()

local BLOCK_WIDTH = 10 -- bloc de couleur à gauche (couleur de l'annonce)
local CHECKER_CELL = 4

--[[
	Bandeau façon télévision : fond noir, bloc de couleur à gauche, titre en
	capitales condensées, ligne en dessous, filet à damier en pied. Un
	CanvasGroup : le fondu de sortie emporte tout d'un coup.
]]
local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "Banner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- au-dessus du chrono et du tableau de bord

	local panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, TOP_POSITION)
	panel.Size = UDim2.fromOffset(0, 82)
	panel.AutomaticSize = Enum.AutomaticSize.X
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	Theme.Corner(panel)
	Theme.Shade(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui

	local block = Instance.new("Frame")
	block.BorderSizePixel = 0
	block.Size = UDim2.new(0, BLOCK_WIDTH, 1, 0)
	block.Parent = panel

	-- Titre et ligne, centrés l'un sous l'autre ; le cadre suit le plus large.
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(BLOCK_WIDTH, 0)
	content.Size = UDim2.new(0, 0, 1, -CHECKER_CELL * 2)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 26)
	padding.PaddingRight = UDim.new(0, 30)
	padding.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local function line(order: number, height: number, size: number, face: Font): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(0, height)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.FontFace = face
		label.TextSize = size
		label.TextColor3 = COLOR_TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ""
		label.LayoutOrder = order
		label.Parent = content
		return label
	end
	local title = line(1, 36, 32, Theme.HEADLINE)
	local subtitle = line(2, 20, 16, Theme.BODY)

	-- Filet à damier, en pied, sur toute la largeur.
	local checker = Theme.Checker(panel, 1600, CHECKER_CELL, 2)
	checker.AnchorPoint = Vector2.new(0, 1)
	checker.Position = UDim2.fromScale(0, 1)
	checker.BackgroundTransparency = 0.3

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		Gui = gui,
		Panel = panel,
		Block = block,
		Scale = scale,
		Title = title,
		Subtitle = subtitle,
	}
end

--[[
	Affiche un bandeau pendant `duration` secondes.
	`big` : le grand format (médaille, niveau, déblocage), jamais coupé.
]]
function Banner.Show(title: string, subtitle: string?, color: Color3, duration: number, big: boolean?)
	local pending: Pending = { Title = title, Subtitle = subtitle, Color = color, Duration = duration, Big = big == true }
	if os.clock() < bigUntil then
		if #queue < MAX_QUEUE then
			table.insert(queue, pending)
		end
		return
	end
	display(pending)
end

-- Le suivant de la file, s'il y en a un.
local function nextInQueue()
	local pending = table.remove(queue, 1)
	if pending then
		display(pending)
	end
end

display = function(pending: Pending)
	local title, subtitle, color, duration, big = pending.Title, pending.Subtitle, pending.Color, pending.Duration, pending.Big
	if big then
		bigUntil = os.clock() + duration
	end
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
	p.Title.Text = string.upper(title)
	p.Title.TextColor3 = color
	p.Title.TextSize = if big then 34 else 24
	p.Title.Size = UDim2.fromOffset(0, if big then 38 else 28)
	p.Subtitle.Text = subtitle or ""
	p.Subtitle.Visible = subtitle ~= nil
	p.Panel.Size = UDim2.fromOffset(0, (if subtitle then (if big then 70 else 58) else 40) + CHECKER_CELL * 2)
	p.Block.BackgroundColor3 = color
	p.Panel.GroupTransparency = 0
	p.Panel.Visible = true

	-- Entrée : un léger rebond pour les grandes annonces, un simple glissé sinon.
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
		if #queue > 0 then
			nextInQueue()
			return
		end
		TweenService:Create(p.Panel, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 }):Play()
		task.delay(FADE_TIME, function()
			if mine == token then
				p.Panel.Visible = false
			end
		end)
	end)
end

return Banner
