--!strict
--[[
	ShopPage.luau
	L'onglet BOUTIQUE : son solde de crédits, les packs de crédits (Robux),
	et les objets du catalogue qui s'achètent (crédits ou Robux), par sorte.
	Un objet possédé se porte d'ici aussi.

	PRIX EN ROBUX : lus chez Roblox (GetProductInfo), une fois par produit,
	en tâche de fond : le menu se reconstruit quand ils arrivent. Un produit
	pas encore créé sur Roblox (ProductId à 0) s'affiche « BIENTÔT ».
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Rarity = require(ReplicatedStorage.Shared.Economy.Rarity)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local ShopPage = {}

local BUTTON_WIDTH = 150

-- Prix lus chez Roblox : nombre, ou false si la lecture a échoué.
local prices: { [number]: number | false } = {}
local pending: { [number]: boolean } = {}

local function priceText(ctx: Context, product: Products.Product): string?
	if not Products.IsAvailable(product) then
		return nil
	end
	local productId = product.ProductId
	local known = prices[productId]
	if known == nil and not pending[productId] then
		pending[productId] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			prices[productId] = if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then info.PriceInRobux else false
			pending[productId] = nil
			ctx.Rebuild()
		end)
	end
	if type(known) == "number" then
		return Format.Thousands(known) .. " R$"
	end
	return "… R$"
end

-- Bouton d'achat Robux d'un produit (ou « BIENTÔT » s'il n'existe pas encore).
local function robuxButton(ctx: Context, row: Frame, product: Products.Product): TextButton
	local price = priceText(ctx, product)
	local button = ctx.Button(row, if price then price else "BIENTÔT", MenuKit.CONTENT_WIDTH - BUTTON_WIDTH, BUTTON_WIDTH, function()
		if price then
			ctx.Action("BuyRobux", product.Key)
		end
	end)
	if price then
		Widgets.Primary(button)
	else
		button.TextColor3 = Widgets.COLOR_DIM
	end
	return button
end

-- Solde, et comment gagner des crédits.
function ShopPage.Balance(ctx: Context, b: Builder)
	local wallet = ctx.Data.Wallet
	b:Section("Ton solde")
	local row = b:Row(40)
	local amount = Widgets.Label(row, if wallet then Credits.Format(wallet.Credits) else "…", 30, Enum.Font.RobotoMono, Theme.ACCENT)
	amount.Size = UDim2.fromScale(1, 1)
	local rewards = Credits.REWARDS
	b:Text(string.format(
		"Gagne des crédits en jouant : spéciale terminée +%d, course +%d à +%d, défi du jour +%d, niveau +%d, médaille +%d à +%d.",
		rewards.StageRun,
		rewards.RaceFinish,
		rewards.RaceFinish + rewards.RacePodium + rewards.RaceWin,
		rewards.DailyChallenge,
		rewards.LevelUp,
		rewards.Medal[1],
		rewards.Medal[#rewards.Medal]
	), 12, Widgets.COLOR_DIM)
end

-- Packs de crédits, en Robux.
function ShopPage.CreditPacks(ctx: Context, b: Builder)
	b:Section("Crédits")
	for _, product in ipairs(Products.CreditPacks()) do
		local row = b:Row(40)
		local name = Widgets.Label(row, string.upper(product.Name), 16, Enum.Font.GothamBlack)
		name.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 20)
		local amount = Widgets.Label(row, "+" .. Credits.Format(product.Grant.Credits or 0), 13, Enum.Font.GothamBold, Theme.ACCENT)
		amount.Position = UDim2.fromOffset(0, 21)
		amount.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 16)
		robuxButton(ctx, row, product)
	end
	b:Text("Achats accordés par le serveur et sauvegardés aussitôt. Les crédits servent aux voitures et à certains objets.", 12, Widgets.COLOR_DIM)
end

-- Une ligne d'objet : nom (couleur de sa rareté), sorte et source, action.
local function itemRow(ctx: Context, b: Builder, item: Catalog.Item, owned: { [string]: boolean })
	local wallet = ctx.Data.Wallet
	local rarity = Rarity.Get(item.Rarity)
	local row = b:Row(44)
	local name = Widgets.Label(row, item.Name, 15, Enum.Font.GothamBold, rarity.Color)
	name.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 20)
	local details = Widgets.Label(
		row,
		string.format("%s · %s · %s", rarity.Name, item.Description, Catalog.SourceText(item)),
		12,
		Enum.Font.GothamMedium,
		Widgets.COLOR_DIM
	)
	details.Position = UDim2.fromOffset(0, 22)
	details.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 16)
	details.TextTruncate = Enum.TextTruncate.AtEnd

	local isOwned = item.Free == true or owned[item.Id] == true
	local equipped = wallet ~= nil and (wallet.Equipped[item.Kind] == item.Id or (wallet.Equipped[item.Kind] == nil and item.Free == true))
	local x = MenuKit.CONTENT_WIDTH - BUTTON_WIDTH
	if isOwned then
		local button = ctx.Button(row, if equipped then "PORTÉ ✓" else "PORTER", x, BUTTON_WIDTH, function()
			if not equipped then
				ctx.Action("Equip", { Kind = item.Kind, Id = item.Id })
			end
		end)
		if equipped then
			button.TextColor3 = Widgets.COLOR_GREEN
		end
	elseif item.Credits then
		local price = item.Credits :: number
		local affordable = wallet ~= nil and wallet.Credits >= price
		local button = ctx.Button(row, Credits.Format(price), x, BUTTON_WIDTH, function()
			ctx.Action("Buy", item.Id)
		end)
		if affordable then
			Widgets.Primary(button)
		else
			button.TextColor3 = Widgets.COLOR_DIM
		end
	elseif item.Robux then
		local product = Products.ForItem(item.Id)
		if product then
			robuxButton(ctx, row, product)
		end
	else
		local how = Widgets.Label(row, if item.Pass then "RALLYE PASS" else "TIRAGE", 13, Enum.Font.GothamBold, Widgets.COLOR_DIM)
		how.Position = UDim2.fromOffset(x, 0)
		how.Size = UDim2.new(0, BUTTON_WIDTH, 1, 0)
		how.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Les objets d'une sorte : ceux qui s'achètent, et ceux qu'on possède déjà.
function ShopPage.Items(ctx: Context, b: Builder, kind: Catalog.Kind)
	local owned = MenuKit.OwnedSet(ctx)
	local items = {}
	for _, item in ipairs(Catalog.OfKind(kind)) do
		if item.Credits or item.Robux or item.Free or owned[item.Id] then
			table.insert(items, item)
		end
	end
	if #items == 0 then
		return
	end
	b:Section(Catalog.KIND_NAMES[kind])
	for _, item in ipairs(items) do
		itemRow(ctx, b, item, owned)
	end
end

return ShopPage
