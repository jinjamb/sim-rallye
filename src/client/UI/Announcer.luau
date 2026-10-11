--!strict
--[[
	Announcer.luau
	Le bandeau du serveur, en haut au centre (dans la barre de Roblox) :
		- les annonces faites à tous les joueurs (record battu, platine,
		  nouveau roi du drift, grand trophée : AnnounceService), l'une après
		  l'autre ;
		- entre deux annonces, l'événement en cours (double XP), s'il y en a un.

	Module unique (pas d'instance), comme Banner et Toast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Theme = require(script.Parent.Theme)

local Announcer = {}

local SHOW_TIME = 6 -- secondes par annonce
local MAX_QUEUE = 5 -- au-delà, les plus anciennes sautent
local FADE_TIME = 0.25
local MAX_WIDTH = 520

export type Message = { Tag: string, Text: string, Color: Color3 }

local queue: { Message } = {}
local event: Message? = nil
local playing = false

type Strip = { Group: CanvasGroup, Tag: TextLabel, Text: TextLabel }
local strip: Strip? = nil

local function build(): Strip
	local existing = strip
	if existing and existing.Group.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Announcer"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- dans la barre du haut de Roblox, entre ses boutons
	gui.DisplayOrder = 8
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.new(0.5, 0, 0, 10)
	group.Size = UDim2.new(0.5, 0, 0, 32)
	group.BackgroundColor3 = Theme.PANEL
	group.BackgroundTransparency = 0.1
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Visible = false
	Theme.Corner(group)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(MAX_WIDTH, 32)
	limit.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = group
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = group
	local tag = Theme.Tag(group, "", Theme.ACCENT, Theme.ON_ACCENT, 13)
	tag.LayoutOrder = 1
	local text = Instance.new("TextLabel")
	text.LayoutOrder = 2
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -140, 1, 0) -- la place laissée par l'étiquette
	text.FontFace = Theme.BODY_BOLD
	text.TextSize = 14
	text.TextColor3 = Theme.TEXT
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.RichText = true
	text.Parent = group
	group.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local built = { Group = group, Tag = tag, Text = text }
	strip = built
	return built
end

-- Affiche `message` (nil : le bandeau s'efface).
local function display(message: Message?)
	local ui = build()
	if not message then
		local tween = TweenService:Create(ui.Group, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 })
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and ui.Group.GroupTransparency >= 1 then
				ui.Group.Visible = false
			end
		end)
		tween:Play()
		return
	end
	ui.Tag.Text = message.Tag
	ui.Tag.BackgroundColor3 = message.Color
	ui.Tag.TextColor3 = Livery.ContrastOf(message.Color)
	ui.Text.Text = message.Text
	ui.Group.Visible = true
	TweenService:Create(ui.Group, TweenInfo.new(FADE_TIME), { GroupTransparency = 0 }):Play()
end

-- Les annonces en attente, l'une après l'autre ; puis l'événement en cours.
local function play()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			display(table.remove(queue, 1))
			task.wait(SHOW_TIME)
		end
		playing = false
		display(event)
	end)
end

-- Une annonce à tout le serveur. `text` : texte enrichi permis.
function Announcer.Push(tag: string, text: string, color: Color3)
	while #queue >= MAX_QUEUE do
		table.remove(queue, 1)
	end
	table.insert(queue, { Tag = tag, Text = text, Color = color })
	play()
end

-- L'événement affiché entre deux annonces (nil : aucun).
function Announcer.SetEvent(message: Message?)
	event = message
	if not playing then
		display(message)
	end
end

-- Texte sans balises (texte enrichi).
local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- Étiquette et couleur de chaque sorte d'annonce du serveur (AnnounceService.Kind).
local KINDS: { [string]: { Tag: string, Color: Color3 } } = {
	Record = { Tag = "RECORD", Color = Theme.ACCENT },
	Platinum = { Tag = "PLATINE", Color = Medals.TIERS[#Medals.TIERS].Color },
	DriftKing = { Tag = "ROI DU DRIFT", Color = Theme.ORANGE },
	Trophy = { Tag = "TROPHÉE", Color = Theme.PURPLE },
}

-- Une annonce reçue du serveur (Remotes.Announce) : { Kind, Name, Text }.
function Announcer.FromServer(announce: any)
	if type(announce) ~= "table" or type(announce.Name) ~= "string" or type(announce.Text) ~= "string" then
		return
	end
	local kind = KINDS[announce.Kind]
	if kind then
		Announcer.Push(kind.Tag, "<b>" .. escape(announce.Name) .. "</b> " .. escape(announce.Text), kind.Color)
	end
end

return Announcer
