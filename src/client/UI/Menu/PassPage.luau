--!strict
--[[
	PassPage.luau
	L'onglet PASS : le Rallye Pass de la saison (Pass.luau). La saison et sa
	fin, son palier et la barre jusqu'au suivant, le bouton de la voie
	premium (Robux), puis les paliers, chacun avec sa récompense gratuite et
	sa récompense premium : en couleur ce qui est déjà reçu. Les paliers
	forment une frise horizontale avec la vignette de chaque récompense.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pass = require(ReplicatedStorage.Shared.Economy.Pass)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Rarity = require(ReplicatedStorage.Shared.Economy.Rarity)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local ShopPage = require(script.Parent.ShopPage)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local ItemArt = require(script.Parent.Parent.ItemArt)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local PassPage = {}

-- "300 CR", "1 tirage", "Fumée néon" (en couleur de rareté).
local function rewardText(reward: Pass.Reward): string
	if reward.Item then
		local item = Catalog.Get(reward.Item)
		if item then
			return string.format('<font color="%s">%s</font>', Theme.Hex(Rarity.Get(item.Rarity).Color), item.Name)
		end
		return reward.Item
	end
	if reward.Rolls then
		return string.format("%d tirage%s", reward.Rolls, if reward.Rolls > 1 then "s" else "")
	end
	return Credits.Format(reward.Credits or 0)
end

function PassPage.Pass(ctx: Context, b: Builder)
	local state: any = ctx.Data.Pass
	local season = Pass.Current()
	local xp = if state then state.Xp else 0
	local premium = state ~= nil and state.Premium == true
	local tier = Pass.TierOf(xp)

	b:Section("Rallye Pass · " .. season.Name)
	b:Text(string.format(
		"%d paliers, gagnés avec toute l'XP de la saison. Fin dans %s.",
		Pass.TIER_COUNT,
		Format.Remaining(season.EndsAt - workspace:GetServerTimeNow())
	), 13, Widgets.COLOR_DIM)

	-- Palier et barre jusqu'au suivant.
	local row = b:Row(30)
	local title = Widgets.Label(row, string.format("PALIER %d / %d", tier, Pass.TIER_COUNT), 22, Enum.Font.GothamBlack, Theme.ACCENT)
	title.Size = UDim2.new(1, -150, 1, 0)
	local progressLabel = Widgets.Label(
		row,
		if tier < Pass.TIER_COUNT then string.format("%s / %s XP", Format.Thousands(xp - tier * Pass.TIER_XP), Format.Thousands(Pass.TIER_XP)) else "TERMINÉ",
		13,
		Enum.Font.GothamBold,
		Widgets.COLOR_DIM
	)
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	local barRow = b:Row(10)
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.PANEL_2
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Parent = barRow
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.ACCENT
	fill.Size = UDim2.fromScale(if tier >= Pass.TIER_COUNT then 1 else math.clamp((xp - tier * Pass.TIER_XP) / Pass.TIER_XP, 0, 1), 1)
	fill.Parent = track

	-- Voie premium.
	local premiumRow = b:Row(40)
	local label = Widgets.Label(
		premiumRow,
		if premium then "PREMIUM ACTIVÉ ✓" else "VOIE PREMIUM",
		16,
		Enum.Font.GothamBlack,
		if premium then Widgets.COLOR_GREEN else Widgets.COLOR_TEXT
	)
	label.Size = UDim2.new(1, -ShopPage.BUTTON_WIDTH - 8, 1, 0)
	if not premium then
		local product = Products.Get("pass_premium")
		if product then
			ShopPage.RobuxButton(ctx, premiumRow, product)
		end
	end
	b:Text(
		if premium
			then "Les récompenses premium de chaque palier te sont données en même temps que les gratuites."
			else "Premium : une seconde récompense à chaque palier (plus de crédits, de tirages, des objets exclusifs), y compris pour les paliers déjà atteints. À racheter à chaque saison.",
		12,
		Widgets.COLOR_DIM
	)

	PassPage.Track(ctx, b, tier, premium)
end

--[[
	La frise des paliers, comme un passe de combat : une colonne par palier,
	défilant de gauche à droite ; en haut la récompense gratuite, en bas la
	premium (cadenas tant qu'on n'a pas la voie premium), la vignette de
	chaque récompense (ItemArt.luau). Les paliers atteints sont cochés, le
	prochain à atteindre est en rose. La frise s'ouvre sur le palier en cours.
]]
local COLUMN_WIDTH = 96
local COLUMN_GAP = 8
local ART_SIZE = 84
local LANE_LABEL = 22 -- libellés GRATUIT / PREMIUM au-dessus des cartes
local TRACK_HEIGHT = 300

local function rewardCard(parent: Frame, y: number, reward: Pass.Reward, reached: boolean, locked: boolean, livery: any)
	local art = ItemArt.New(parent, reward, ART_SIZE, livery)
	art.Position = UDim2.fromOffset((COLUMN_WIDTH - ART_SIZE) / 2, y)
	if locked then
		-- Voie premium pas achetée : la carte s'assombrit, un cadenas dessus.
		local veil = Instance.new("TextLabel")
		veil.BackgroundColor3 = Theme.INK
		veil.BackgroundTransparency = 0.45
		veil.BorderSizePixel = 0
		veil.Size = UDim2.fromScale(1, 1)
		veil.Text = "🔒"
		veil.TextSize = 26
		veil.ZIndex = 4
		veil.Parent = art
	elseif reached then
		-- Reçue : une pastille verte cochée dans le coin.
		local check = Instance.new("TextLabel")
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -4, 0, 4)
		check.Size = UDim2.fromOffset(22, 22)
		check.BackgroundColor3 = Theme.GREEN
		check.BorderSizePixel = 0
		check.FontFace = Theme.HEADLINE
		check.Text = "✓"
		check.TextSize = 14
		check.TextColor3 = Theme.INK
		check.ZIndex = 4
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = check
		check.Parent = art
	end
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(0, y + ART_SIZE + 2)
	caption.Size = UDim2.new(1, 0, 0, 16)
	caption.FontFace = Theme.BODY_BOLD
	caption.TextSize = 11
	caption.TextColor3 = if reached then Theme.TEXT else Theme.DIM
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	caption.RichText = true
	caption.Text = rewardText(reward)
	caption.Parent = parent
end

function PassPage.Track(ctx: Context, b: Builder, tier: number, premium: boolean)
	b:Section("Paliers")
	local count = #Pass.TIERS
	local step = COLUMN_WIDTH + COLUMN_GAP

	-- ◀ ▶ : cinq paliers d'un coup (la molette défile aussi).
	local nav = b:Row(30)
	local hint = Widgets.Label(nav, "Gratuit en haut · premium en bas", 12, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	hint.Size = UDim2.new(1, -110, 1, 0)
	local scroller: ScrollingFrame
	-- La position de défilement est en pixels à l'écran : le menu est mis à
	-- l'échelle (UIScale), on convertit depuis les pixels de référence.
	local function screenScale(): number
		local canvas = scroller.AbsoluteCanvasSize.X
		return if canvas > 0 then canvas / (count * step) else 1
	end
	local function page(direction: number)
		-- Roblox borne lui-même la position au bout de la frise.
		local target = scroller.CanvasPosition.X + direction * step * 5 * screenScale()
		scroller.CanvasPosition = Vector2.new(math.max(0, target), 0)
	end
	ctx.Button(nav, "◀", MenuKit.CONTENT_WIDTH - 100, 46, function()
		page(-1)
	end)
	ctx.Button(nav, "▶", MenuKit.CONTENT_WIDTH - 46, 46, function()
		page(1)
	end)

	local row = b:Row(TRACK_HEIGHT)
	scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = Theme.ACCENT
	scroller.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
	scroller.CanvasSize = UDim2.fromOffset(count * step, 0)
	scroller.Parent = row

	local freeY = 30 + LANE_LABEL
	local premiumY = freeY + ART_SIZE + 22 + LANE_LABEL
	for index, rewards in ipairs(Pass.TIERS) do
		local reached = index <= tier
		local isNext = index == tier + 1
		local column = Instance.new("Frame")
		column.Name = "Tier" .. index
		column.BackgroundColor3 = if isNext then Theme.ACCENT else Theme.PANEL_2
		column.BackgroundTransparency = if isNext then 0.75 else (if reached then 0.6 else 0.85)
		column.BorderSizePixel = 0
		column.Position = UDim2.fromOffset((index - 1) * step, 0)
		column.Size = UDim2.new(0, COLUMN_WIDTH, 1, -10)
		Theme.Corner(column)
		column.Parent = scroller
		-- Numéro du palier, en étiquette penchée.
		local number = Theme.Tag(
			column,
			tostring(index),
			if reached then Theme.GREEN elseif isNext then Theme.ACCENT else Theme.INK,
			if reached then Theme.INK else Theme.TEXT,
			14
		)
		number.AnchorPoint = Vector2.new(0.5, 0)
		number.Position = UDim2.fromOffset(COLUMN_WIDTH / 2, 6)
		local function lane(y: number, text: string, color: Color3)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromOffset(0, y - LANE_LABEL)
			label.Size = UDim2.new(1, 0, 0, LANE_LABEL)
			label.FontFace = Theme.HEADLINE
			label.TextSize = 10
			label.TextColor3 = color
			label.Text = text
			label.Parent = column
		end
		lane(freeY, "GRATUIT", Theme.DIM)
		lane(premiumY, "★ PREMIUM", Theme.YELLOW)
		rewardCard(column, freeY, rewards.Free, reached, false, ctx.Data.Livery)
		rewardCard(column, premiumY, rewards.Premium, reached and premium, not premium, ctx.Data.Livery)
	end
	-- La frise s'ouvre sur le palier en cours (un palier de marge à gauche),
	-- une fois sa taille à l'écran connue (après l'entrée « pop » du menu).
	task.delay(0.35, function()
		if scroller.Parent then
			scroller.CanvasPosition = Vector2.new(math.max(0, (tier - 1) * step * screenScale()), 0)
		end
	end)
end

return PassPage
