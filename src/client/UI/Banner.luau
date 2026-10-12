--!strict
--[[
	Banner.luau
	Bandeau d'annonce, façon « cut-in » d'anime : une médaille décrochée, le
	fantôme qu'on affronte, un rival battu. Une bande de couleur traverse
	l'écran d'un coup (de gauche à droite), cernée d'encre ; le titre en
	lettrage de manga jaillit au milieu, une ligne en dessous, un filigrane
	en katakana derrière ; puis la bande repart vers la droite.
	Un seul bandeau à la fois. Un petit bandeau (info) remplace le précédent ;
	un GRAND bandeau (médaille, niveau, déblocage) n'est jamais coupé : ce qui
	arrive pendant qu'il est affiché attend son tour (file d'attente).

	Module unique (pas d'instance) : la spéciale (DrivingSession) comme le
	rallycross (RaceClient) l'appellent directement.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Banner = {}

-- Hauteur (fraction de l'écran) : sous le bandeau du copilote, au-dessus des
-- messages du rallycross (RaceHud, à 36 %).
local TOP_POSITION = 0.22
local SLIDE_TIME = 0.28
local FADE_TIME = 0.25
local INK_EDGE = 6 -- filet d'encre au-dessus et au-dessous de la bande

-- Hauteurs et tailles de texte en pixels de référence (1080p).
local BIG = { Height = 112, Title = 64, Subtitle = 19, Kana = 96 }
local SMALL = { Height = 70, Title = 38, Subtitle = 15, Kana = 60 }
-- Le filigrane : « すごい！ » (génial !) pour les grandes nouvelles, « ラリー » sinon.
local KANA_BIG = "すごい！"
local KANA_SMALL = "ラリー"

type Parts = {
	Gui: ScreenGui,
	Group: CanvasGroup,
	Slide: Frame,
	Band: Frame,
	Stripes: Frame,
	Kana: TextLabel,
	Content: Frame,
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

local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "Banner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- au-dessus du chrono et du tableau de bord

	-- Le groupe porte le fondu ; la bande glisse dedans.
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Position = UDim2.fromScale(0, TOP_POSITION)
	group.Size = UDim2.new(1, 0, 0, BIG.Height)
	group.Visible = false
	group.Parent = gui

	local slide = Instance.new("Frame")
	slide.BackgroundColor3 = Theme.INK
	slide.BorderSizePixel = 0
	slide.Size = UDim2.fromScale(1, 1)
	slide.Parent = group

	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.Position = UDim2.fromOffset(0, INK_EDGE)
	band.Size = UDim2.new(1, 0, 1, -INK_EDGE * 2)
	band.Parent = slide

	-- Bandes de vitesse en encre, côté gauche ; filigrane côté droit.
	local stripes = Theme.Stripes(band, Theme.INK, 4, 0.55)
	stripes.AnchorPoint = Vector2.new(0, 0.5)
	stripes.Position = UDim2.new(0.06, 0, 0.5, 0)
	stripes.Size = UDim2.new(0.12, 0, 0.7, 0)
	local kana = Theme.Kana(band, KANA_SMALL, SMALL.Kana, 0.78)
	kana.Position = UDim2.new(-0.04, 0, 0, 0)

	-- Titre et ligne, centrés l'un sous l'autre.
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = band
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, -4)
	layout.Parent = content

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AutomaticSize = Enum.AutomaticSize.X
	title.FontFace = Theme.SFX
	title.TextColor3 = Theme.TEXT
	title.Rotation = -2 -- penché, comme une onomatopée
	title.LayoutOrder = 1
	title.Parent = content
	Theme.TextInk(title, 4)

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.AutomaticSize = Enum.AutomaticSize.X
	subtitle.FontFace = Theme.BODY_BOLD
	subtitle.TextColor3 = Theme.TEXT
	subtitle.LayoutOrder = 2
	subtitle.Parent = content
	Theme.TextInk(subtitle, 2)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		Gui = gui,
		Group = group,
		Slide = slide,
		Band = band,
		Stripes = stripes,
		Kana = kana,
		Content = content,
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
	local size = if big then BIG else SMALL
	local height = math.floor(size.Height * base)
	p.Group.Size = UDim2.new(1, 0, 0, height)
	p.Band.BackgroundColor3 = color
	p.Title.Text = Format.Upper(title)
	p.Title.TextSize = math.floor(size.Title * base)
	p.Title.Size = UDim2.fromOffset(0, math.floor(size.Title * base * 1.05))
	p.Subtitle.Text = subtitle or ""
	p.Subtitle.Visible = subtitle ~= nil
	p.Subtitle.TextSize = math.max(14, math.floor(size.Subtitle * base)) -- lisible même sur petit écran
	p.Subtitle.Size = UDim2.fromOffset(0, math.floor(p.Subtitle.TextSize * 1.3))
	p.Kana.Text = if big then KANA_BIG else KANA_SMALL
	p.Kana.TextSize = math.floor(size.Kana * base)
	p.Group.GroupTransparency = 0
	p.Group.Visible = true

	-- Entrée : la bande traverse l'écran depuis la gauche, le titre jaillit.
	p.Slide.Position = UDim2.fromScale(-1, 0)
	TweenService:Create(p.Slide, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0),
	}):Play()
	Theme.Pop(p.Title, 1, if big then 0.4 else 0.75)

	task.delay(duration, function()
		if mine ~= token then
			return -- remplacé entre-temps
		end
		if #queue > 0 then
			nextInQueue()
			return
		end
		-- Sortie : la bande file vers la droite en s'effaçant.
		local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(p.Slide, info, { Position = UDim2.fromScale(0.6, 0) }):Play()
		TweenService:Create(p.Group, info, { GroupTransparency = 1 }):Play()
		task.delay(FADE_TIME, function()
			if mine == token then
				p.Group.Visible = false
			end
		end)
	end)
end

return Banner
