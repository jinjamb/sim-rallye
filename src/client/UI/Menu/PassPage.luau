--!strict
--[[
	PassPage.luau
	L'onglet PASS : le Rallye Pass de la saison (Pass.luau). La saison et sa
	fin, son palier et la barre jusqu'au suivant, le bouton de la voie
	premium (Robux), puis les paliers, chacun avec sa récompense gratuite et
	sa récompense premium : en couleur ce qui est déjà reçu.
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

	-- Les paliers.
	b:Section("Paliers")
	for index, rewards in ipairs(Pass.TIERS) do
		local reached = index <= tier
		local line = b:Text(string.format(
			'%s<b>%2d</b>   Gratuit : %s   ·   <font color="%s">Premium</font> : %s',
			if reached then "✓ " else "   ",
			index,
			rewardText(rewards.Free),
			Theme.Hex(Theme.ACCENT),
			rewardText(rewards.Premium)
		), 13, if reached then Widgets.COLOR_TEXT else Widgets.COLOR_DIM)
		line.RichText = true
	end
end

return PassPage
