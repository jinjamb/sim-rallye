--!strict
--[[
	RollReveal.luau
	La mise en scène d'un tirage : une bande de cartes (des objets au
	hasard, à la couleur de leur rareté) défile sous un repère jaune, ralentit
	et s'arrête sur l'objet tiré par le serveur ; puis son nom, sa rareté, et
	« doublon : +N CR » s'il était déjà possédé.

	Le résultat est connu avant l'animation (le serveur l'a déjà donné) :
	l'animation ne décide rien, elle raconte. Clic ou Échap pour passer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local Rarity = require(ReplicatedStorage.Shared.Economy.Rarity)
local Rolls = require(ReplicatedStorage.Shared.Economy.Rolls)
local Theme = require(script.Parent.Theme)

local RollReveal = {}
RollReveal.__index = RollReveal

export type RollReveal = typeof(setmetatable({}, RollReveal)) & {
	Gui: ScreenGui,
	Strip: Frame,
	Title: TextLabel,
	Subtitle: TextLabel,
	Token: number,
	Tween: Tween?,
}

local CARD_WIDTH = 150
local CARD_GAP = 8
local CARD_COUNT = 34
local RESULT_INDEX = 30 -- la carte de l'objet tiré
local SPIN_TIME = 3.2

local function card(parent: Instance, item: Catalog.Item, index: number): Frame
	local info = Rarity.Get(item.Rarity)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(CARD_WIDTH, 120)
	frame.Position = UDim2.fromOffset((index - 1) * (CARD_WIDTH + CARD_GAP), 0)
	frame.BackgroundColor3 = Theme.PANEL_2
	frame.BorderSizePixel = 0
	Theme.Corner(frame)
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = info.Color
	band.Size = UDim2.new(1, 0, 0, 8)
	band.Parent = frame
	local kind = Instance.new("TextLabel")
	kind.BackgroundTransparency = 1
	kind.Position = UDim2.fromOffset(8, 16)
	kind.Size = UDim2.new(1, -16, 0, 16)
	kind.FontFace = Theme.BODY
	kind.TextSize = 12
	kind.TextColor3 = Theme.DIM
	kind.TextXAlignment = Enum.TextXAlignment.Left
	kind.Text = string.upper(Catalog.KIND_NAMES[item.Kind])
	kind.Parent = frame
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(8, 34)
	name.Size = UDim2.new(1, -16, 0, 56)
	name.FontFace = Theme.HEADLINE
	name.TextSize = 18
	name.TextWrapped = true
	name.TextColor3 = Theme.TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.Text = string.upper(item.Name)
	name.Parent = frame
	local rarity = Instance.new("TextLabel")
	rarity.BackgroundTransparency = 1
	rarity.Position = UDim2.new(0, 8, 1, -24)
	rarity.Size = UDim2.new(1, -16, 0, 18)
	rarity.FontFace = Theme.BODY_BOLD
	rarity.TextSize = 13
	rarity.TextColor3 = info.Color
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.Text = string.upper(info.Name)
	rarity.Parent = frame
	frame.Parent = parent
	return frame
end

function RollReveal.new(playerGui: Instance): RollReveal
	local self = (setmetatable({}, RollReveal) :: any) :: RollReveal
	self.Token = 0
	self.Tween = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "RollReveal"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20 -- au-dessus du menu
	gui.IgnoreGuiInset = true
	self.Gui = gui

	local shade = Instance.new("TextButton")
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Theme.INK
	shade.BackgroundTransparency = 0.25
	shade.BorderSizePixel = 0
	shade.Parent = gui
	shade.Activated:Connect(function()
		self:_skipOrClose()
	end)

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.45)
	window.Size = UDim2.fromOffset(CARD_WIDTH * 5 + CARD_GAP * 4, 120)
	window.BackgroundTransparency = 1
	window.ClipsDescendants = true
	window.Parent = gui
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(CARD_COUNT * (CARD_WIDTH + CARD_GAP), 120)
	strip.Parent = window
	self.Strip = strip

	-- Repère central : le trait jaune sous lequel la bande s'arrête.
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.45)
	marker.Size = UDim2.fromOffset(4, 150)
	marker.BackgroundColor3 = Theme.ACCENT
	marker.BorderSizePixel = 0
	marker.ZIndex = 5
	marker.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.45, 90)
	title.Size = UDim2.fromOffset(700, 44)
	title.BackgroundTransparency = 1
	title.FontFace = Theme.HEADLINE
	title.TextSize = 36
	title.TextColor3 = Theme.TEXT
	title.Text = ""
	title.Parent = gui
	self.Title = title
	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.45, 136)
	subtitle.Size = UDim2.fromOffset(700, 24)
	subtitle.BackgroundTransparency = 1
	subtitle.FontFace = Theme.BODY_BOLD
	subtitle.TextSize = 18
	subtitle.TextColor3 = Theme.DIM
	subtitle.Text = ""
	subtitle.Parent = gui
	self.Subtitle = subtitle

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			self:_skipOrClose()
		end
	end)

	gui.Parent = playerGui
	return self
end

-- Pendant le défilement : aller au résultat ; après : fermer.
function RollReveal:_skipOrClose()
	local tween = self.Tween
	if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
		tween:Cancel()
		self:_finish()
	else
		self.Gui.Enabled = false
	end
end

function RollReveal:_finish()
	self.Strip.Position = self.Strip:GetAttribute("Target") :: UDim2
	local item = Catalog.Get(self.Strip:GetAttribute("ItemId") :: string?)
	if not item then
		return
	end
	local info = Rarity.Get(item.Rarity)
	self.Title.Text = string.upper(item.Name)
	self.Title.TextColor3 = info.Color
	local duplicate = self.Strip:GetAttribute("Credits") :: number?
	self.Subtitle.Text = string.upper(info.Name) .. " · " .. Catalog.KIND_NAMES[item.Kind]
		.. (if duplicate and duplicate > 0 then "  ·  déjà possédé : +" .. Credits.Format(duplicate) else "  ·  NOUVEAU")
end

-- Montre le tirage : `result` = { ItemId, Duplicate, Credits } (RollService).
function RollReveal:Show(result: any)
	local item = Catalog.Get(if type(result) == "table" then result.ItemId else nil)
	if not item then
		return
	end
	self.Token += 1
	for _, child in ipairs(self.Strip:GetChildren()) do
		child:Destroy()
	end
	-- Des cartes au hasard parmi ce qui peut sortir, pondérées comme le vrai tirage.
	local odds = Rolls.Odds(false)
	local filler = Random.new()
	for index = 1, CARD_COUNT do
		local shown: Catalog.Item = item
		if index ~= RESULT_INDEX and #odds > 0 then
			local roll = filler:NextNumber()
			local chosen = odds[#odds]
			for _, entry in ipairs(odds) do
				roll -= entry.Chance
				if roll < 0 then
					chosen = entry
					break
				end
			end
			shown = chosen.Items[filler:NextInteger(1, #chosen.Items)]
		end
		card(self.Strip, shown, index)
	end
	self.Title.Text = ""
	self.Subtitle.Text = ""
	-- La carte tirée s'arrête sous le repère, un peu décalée (moins mécanique).
	local windowWidth = CARD_WIDTH * 5 + CARD_GAP * 4
	local cardCenter = (RESULT_INDEX - 1) * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH / 2
	local jitter = filler:NextNumber(-CARD_WIDTH * 0.3, CARD_WIDTH * 0.3)
	local target = UDim2.fromOffset(windowWidth / 2 - cardCenter + jitter, 0)
	local strip = self.Strip :: Frame
	strip.Position = UDim2.fromOffset(0, 0)
	strip:SetAttribute("Target", target)
	strip:SetAttribute("ItemId", item.Id)
	strip:SetAttribute("Credits", if result.Duplicate then tonumber(result.Credits) or 0 else 0)
	self.Gui.Enabled = true
	local tween = TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = target })
	self.Tween = tween
	local token = self.Token
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and token == self.Token then
			self:_finish()
		end
	end)
	tween:Play()
end

return RollReveal
