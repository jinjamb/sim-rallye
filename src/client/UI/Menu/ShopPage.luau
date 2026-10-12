--!strict
--[[
	ShopPage.luau
	L'onglet BOUTIQUE : son solde de crédits, ses tirages (avec les
	probabilités, affichées en entier), les packs de crédits (Robux), et les
	objets du catalogue qui s'achètent (crédits ou Robux), par sorte. Un
	objet possédé se porte d'ici aussi.

	LES OBJETS sont des CARTES, trois par rangée : la vignette de l'objet
	(ItemArt.luau : la voiture en 3D, la fumée de sa couleur...), son nom à
	la couleur de sa rareté, et le bouton d'action. Une rangée de pastilles
	choisit la sorte montrée (voitures, moteurs, fumées...).

	PRIX EN ROBUX : lus chez Roblox (GetProductInfo), une fois par produit,
	en tâche de fond : le menu se reconstruit quand ils arrivent. Un produit
	pas encore créé sur Roblox (ProductId à 0) s'affiche « BIENTÔT ».

	TOUT S'ACHÈTE EN ROBUX : chaque objet non possédé a son bouton Robux (au
	palier de sa rareté, Products.ForItem), à côté de son prix en crédits
	s'il en a un. OFFRES : pack de démarrage, pass de jeu (Crédits ×2, VIP),
	boost d'XP, Roblox Premium ; tirages en Robux dans la rubrique Tirages
	(masqués là où les objets aléatoires payants sont interdits).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Rarity = require(ReplicatedStorage.Shared.Economy.Rarity)
local Rolls = require(ReplicatedStorage.Shared.Economy.Rolls)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local ItemArt = require(script.Parent.Parent.ItemArt)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local ShopPage = {}

local BUTTON_WIDTH = 150
local CARD_GAP = 14
local CARD_COLUMNS = 3
local CARD_WIDTH = math.floor((MenuKit.CONTENT_WIDTH - CARD_GAP * (CARD_COLUMNS - 1)) / CARD_COLUMNS)
local ART_HEIGHT = 108
local CARD_HEIGHT = ART_HEIGHT + 86
local CARD_BUTTON_HEIGHT = 32

-- Pastilles des sortes : icône et nom court.
local KIND_CHIPS: { [string]: string } = {
	Car = "🏎️ VOITURES",
	Engine = "⚙️ MOTEURS",
	Backfire = "🔥 FLAMMES",
	Smoke = "💨 FUMÉES",
	Horn = "📯 KLAXONS",
	Celebration = "🎉 FÊTES",
	Part = "🔧 PIÈCES",
}

-- Prix lus chez Roblox, par « produit:id » ou « pass:id » : nombre, ou
-- false si la lecture a échoué.
local prices: { [string]: number | false } = {}
local pending: { [string]: boolean } = {}

local function fetchedPrice(ctx: Context, id: number, infoType: Enum.InfoType): string
	local key = (if infoType == Enum.InfoType.GamePass then "pass:" else "product:") .. tostring(id)
	local known = prices[key]
	if known == nil and not pending[key] then
		pending[key] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			prices[key] = if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then info.PriceInRobux else false
			pending[key] = nil
			ctx.Rebuild()
		end)
	end
	if type(known) == "number" then
		return Format.Thousands(known) .. " R$"
	end
	return "… R$"
end

local function priceText(ctx: Context, product: Products.Product): string?
	if not Products.IsAvailable(product) then
		return nil
	end
	return fetchedPrice(ctx, product.ProductId, Enum.InfoType.Product)
end

--[[
	Bouton d'achat Robux d'un produit (ou « BIENTÔT » s'il n'existe pas encore).
	Par défaut au bout de la ligne ; `x`, `width` pour le placer ailleurs
	(carte). `onBuy` : à la place de l'achat du produit lui-même (un palier
	qui achète un objet précis).
]]
local function robuxButton(ctx: Context, row: Frame, product: Products.Product, x: number?, width: number?, onBuy: (() -> ())?): TextButton
	local price = priceText(ctx, product)
	local w = width or BUTTON_WIDTH
	local button = ctx.Button(row, if price then price else "BIENTÔT", x or (MenuKit.CONTENT_WIDTH - w), w, function()
		if price then
			if onBuy then
				onBuy()
			else
				ctx.Action("BuyRobux", product.Key)
			end
		end
	end)
	if price then
		Widgets.Primary(button)
	else
		button.TextColor3 = Widgets.COLOR_DIM
	end
	return button
end

ShopPage.RobuxButton = robuxButton
ShopPage.BUTTON_WIDTH = BUTTON_WIDTH

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

-- Tirages : combien, la garantie, le bouton, et les probabilités (sur demande).
function ShopPage.Rolls(ctx: Context, b: Builder)
	local wallet = ctx.Data.Wallet
	local count = if wallet and wallet.Rolls then wallet.Rolls else 0
	local pity = if wallet and wallet.Pity then wallet.Pity else 0
	b:Section("Tirages")
	local row = b:Row(40)
	local label = Widgets.Label(row, string.format("%d tirage%s disponible%s", count, if count > 1 then "s" else "", if count > 1 then "s" else ""), 18, Enum.Font.GothamBlack, if count > 0 then Theme.ACCENT else Widgets.COLOR_DIM)
	label.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 1, 0)
	local button = ctx.Button(row, "TIRER", MenuKit.CONTENT_WIDTH - BUTTON_WIDTH, BUTTON_WIDTH, function()
		if count > 0 then
			ctx.Action("Roll", nil)
		end
	end)
	if count > 0 then
		Widgets.Primary(button)
	else
		button.TextColor3 = Widgets.COLOR_DIM
	end
	-- Tirages en Robux (pas là où les objets aléatoires payants sont interdits).
	local perks = if wallet and type(wallet.Perks) == "table" then wallet.Perks else {}
	if perks.RandomRestricted ~= true then
		local packs = Products.RollPacks()
		local packRow = b:Row(36)
		local gap = 6
		local width = (MenuKit.CONTENT_WIDTH - gap * (#packs - 1)) / #packs
		for index, product in ipairs(packs) do
			local button = robuxButton(ctx, packRow, product, (index - 1) * (width + gap), width)
			local price = priceText(ctx, product)
			button.Text = Format.Upper(product.Name) .. " · " .. (price or "BIENTÔT")
			button.TextSize = 12
		end
	end
	local left = math.max(1, Rolls.PITY_LIMIT - pity)
	b:Text(string.format(
		"Un tirage par niveau gagné, et un pour les trois défis du jour. Garantie : un objet Usine ou plus %s. Doublon : converti en crédits.",
		if left <= 1 then "au prochain tirage" else string.format("d'ici %d tirages", left)
	), 12, Widgets.COLOR_DIM)
	local details = b:Row(30)
	ctx.Button(details, if ctx.View.ShowOdds then "MASQUER LES PROBABILITÉS" else "VOIR LES PROBABILITÉS", 0, MenuKit.CONTENT_WIDTH, function()
		ctx.View.ShowOdds = not ctx.View.ShowOdds
		ctx.Rebuild()
	end)
	if ctx.View.ShowOdds then
		for _, entry in ipairs(Rolls.Odds(false)) do
			local info = Rarity.Get(entry.Rarity)
			local names = {}
			for _, item in ipairs(entry.Items) do
				table.insert(names, item.Name)
			end
			local text = b:Text(string.format(
				'<font color="%s"><b>%s %s</b></font> · %s par objet · %s',
				Theme.Hex(info.Color),
				Format.Upper(info.Name),
				Rolls.FormatChance(entry.Chance),
				Rolls.FormatChance(entry.Chance / #entry.Items),
				table.concat(names, ", ")
			), 12, Widgets.COLOR_TEXT)
			text.RichText = true
		end
	end
end

-- Une ligne d'offre : nom, ce qu'elle donne, et à droite son bouton
-- (construit par `button`).
local function offerRow(b: Builder, title: string, details: string, color: Color3, button: (Frame) -> ())
	local row = b:Row(48)
	local name = Widgets.Label(row, title, 15, Enum.Font.GothamBlack, color)
	name.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 20)
	local text = Widgets.Label(row, details, 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
	text.Position = UDim2.fromOffset(0, 21)
	text.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 26)
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top
	button(row)
end

--[[
	Les offres : pack de démarrage (tant qu'il n'est pas pris), pass de jeu,
	boost d'XP, Roblox Premium.
]]
function ShopPage.Offers(ctx: Context, b: Builder)
	local wallet = ctx.Data.Wallet
	local perks = if wallet and type(wallet.Perks) == "table" then wallet.Perks else {}
	local passes = if type(perks.Passes) == "table" then perks.Passes else {}
	local owned = MenuKit.OwnedSet(ctx)
	b:Section("Offres")

	local starter = Products.Get("starter")
	if starter and not owned[Products.STARTER_KEY] then
		offerRow(b, "🎁 " .. Format.Upper(starter.Name), starter.Description or "", Theme.YELLOW, function(row)
			robuxButton(ctx, row, starter)
		end)
	end

	for _, pass in ipairs(Products.PASSES) do
		-- Le Premium contient les autres pass : avec lui, ils sont « inclus ».
		local included = pass.Key ~= "premium" and passes.premium == true
		local active = passes[pass.Key] == true or included
		local icon = if pass.Key == "premium" then "⭐ " elseif pass.Key == "vip" then "👑 " else "💰 "
		offerRow(b, icon .. "PASS " .. Format.Upper(pass.Name), pass.Description, if active then Widgets.COLOR_GREEN else Theme.ACCENT, function(row)
			if active then
				local state = Widgets.Label(row, if included and passes[pass.Key] ~= true then "INCLUS ✓" else "ACTIF ✓", 14, Enum.Font.GothamBlack, Widgets.COLOR_GREEN)
				state.Position = UDim2.fromOffset(MenuKit.CONTENT_WIDTH - BUTTON_WIDTH, 0)
				state.Size = UDim2.fromOffset(BUTTON_WIDTH, 40)
				state.TextXAlignment = Enum.TextXAlignment.Center
				return
			end
			local available = Products.IsPassAvailable(pass)
			local price = if available then fetchedPrice(ctx, pass.GamePassId, Enum.InfoType.GamePass) else "BIENTÔT"
			local button = ctx.Button(row, price, MenuKit.CONTENT_WIDTH - BUTTON_WIDTH, BUTTON_WIDTH, function()
				if available then
					ctx.Action("BuyPass", pass.Key)
				end
			end)
			if available then
				Widgets.Primary(button)
			else
				button.TextColor3 = Widgets.COLOR_DIM
			end
		end)
	end

	local boost = Products.Get("xp_boost")
	if boost then
		local remaining = (if type(perks.XpBoostUntil) == "number" then perks.XpBoostUntil else 0) - workspace:GetServerTimeNow()
		local details = (boost.Description or "") .. (if remaining > 0 then " Actif encore " .. Format.Remaining(remaining) .. "." else "")
		offerRow(b, "⚡ " .. Format.Upper(boost.Name), details, if remaining > 0 then Widgets.COLOR_GREEN else Theme.CYAN, function(row)
			robuxButton(ctx, row, boost)
		end)
	end

	-- Roblox Premium : bonus de crédits ; sinon, proposer l'abonnement.
	if perks.Premium == true then
		b:Text("★ Membre Roblox Premium : +10 % sur tous les crédits gagnés en jouant.", 12, Widgets.COLOR_GREEN)
	else
		offerRow(b, "★ ROBLOX PREMIUM", "Les abonnés Premium gagnent 10 % de crédits en plus en jouant.", Widgets.COLOR_TEXT, function(row)
			ctx.Button(row, "S'ABONNER", MenuKit.CONTENT_WIDTH - BUTTON_WIDTH, BUTTON_WIDTH, function()
				ctx.Action("Premium", nil)
			end)
		end)
	end
end

-- Packs de crédits, en Robux.
function ShopPage.CreditPacks(ctx: Context, b: Builder)
	b:Section("Crédits")
	for _, product in ipairs(Products.CreditPacks()) do
		local row = b:Row(40)
		local name = Widgets.Label(row, Format.Upper(product.Name), 16, Enum.Font.GothamBlack)
		name.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 20)
		local amount = Widgets.Label(row, "+" .. Credits.Format(product.Grant.Credits or 0), 13, Enum.Font.GothamBold, Theme.ACCENT)
		amount.Position = UDim2.fromOffset(0, 21)
		amount.Size = UDim2.new(1, -BUTTON_WIDTH - 8, 0, 16)
		robuxButton(ctx, row, product)
	end
	b:Text("Achats accordés par le serveur et sauvegardés aussitôt. Les crédits servent aux voitures et à certains objets.", 12, Widgets.COLOR_DIM)
end

-- Le bouton d'une carte : porter, acheter (crédits ou Robux), ou d'où il vient.
local function cardAction(ctx: Context, holder: Frame, item: Catalog.Item, owned: { [string]: boolean })
	local wallet = ctx.Data.Wallet
	local isOwned = item.Free == true or owned[item.Id] == true
	local equipped = wallet ~= nil and (wallet.Equipped[item.Kind] == item.Id or (wallet.Equipped[item.Kind] == nil and item.Free == true))
	if item.Kind == "Part" and isOwned then
		-- Une pièce ne se porte pas : elle se choisit sur sa voiture (INVENTAIRE, garage).
		local state = Widgets.Label(holder, "OBTENUE ✓ · INVENTAIRE", 11, Enum.Font.GothamBlack, Widgets.COLOR_GREEN)
		state.Size = UDim2.fromScale(1, 1)
		state.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	if isOwned then
		local button = ctx.Button(holder, if equipped then "PORTÉ ✓" else "PORTER", 0, CARD_WIDTH, function()
			if not equipped then
				ctx.Action("Equip", { Kind = item.Kind, Id = item.Id })
			end
		end)
		if equipped then
			button.TextColor3 = Widgets.COLOR_GREEN
		end
	else
		local tier = Products.ForItem(item.Id)
		local buyRobux = function()
			ctx.Action("RobuxItem", item.Id)
		end
		if item.Credits then
			-- Crédits à gauche, Robux à droite.
			local half = (CARD_WIDTH - 6) / 2
			local price = item.Credits :: number
			local affordable = wallet ~= nil and wallet.Credits >= price
			local button = ctx.Button(holder, Credits.Format(price), 0, if tier then half else CARD_WIDTH, function()
				ctx.Action("Buy", item.Id)
			end)
			if affordable then
				Widgets.Primary(button)
			else
				button.TextColor3 = Widgets.COLOR_DIM
			end
			if tier then
				robuxButton(ctx, holder, tier, half + 6, half, buyRobux)
			end
		elseif tier then
			robuxButton(ctx, holder, tier, 0, CARD_WIDTH, buyRobux)
		else
			local how = Widgets.Label(holder, if item.Starter then "🎁 PACK DE DÉMARRAGE" elseif item.Pass then "🎫 RALLYE PASS" else "🎁 TIRAGE", 12, Enum.Font.GothamBlack, Widgets.COLOR_DIM)
			how.Size = UDim2.fromScale(1, 1)
			how.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

--[[
	Une carte d'objet : sa vignette (ce qu'on achète), son nom à la couleur
	de sa rareté, sa rareté et sa description, le bouton d'action.
]]
local function itemCard(ctx: Context, row: Frame, column: number, item: Catalog.Item, owned: { [string]: boolean })
	local rarity = Rarity.Get(item.Rarity)
	local card = Instance.new("Frame")
	card.Name = item.Id
	card.BackgroundColor3 = Theme.PANEL_2
	card.BackgroundTransparency = 0.55
	card.BorderSizePixel = 0
	card.Position = UDim2.fromOffset((column - 1) * (CARD_WIDTH + CARD_GAP), 0)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	Theme.Corner(card)
	card.Parent = row
	ItemArt.New(card, { Item = item.Id }, CARD_WIDTH, ctx.Data.Livery, ART_HEIGHT)
	-- Rareté en étiquette penchée, sur la vignette.
	local tag = Theme.Tag(card, Format.Upper(rarity.Name), rarity.Color, Theme.INK, 10)
	tag.Position = UDim2.fromOffset(10, 6)
	tag.ZIndex = 3
	local name = Widgets.Label(card, item.Name, 14, Enum.Font.GothamBlack, rarity.Color)
	name.Position = UDim2.fromOffset(6, ART_HEIGHT + 4)
	name.Size = UDim2.new(1, -12, 0, 20)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local details = Widgets.Label(card, item.Description, 11, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
	details.Position = UDim2.fromOffset(6, ART_HEIGHT + 24)
	details.Size = UDim2.new(1, -12, 0, 26)
	details.TextWrapped = true
	details.TextTruncate = Enum.TextTruncate.AtEnd
	details.TextYAlignment = Enum.TextYAlignment.Top
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.fromScale(0, 1)
	holder.Size = UDim2.new(1, 0, 0, CARD_BUTTON_HEIGHT)
	holder.Parent = card
	cardAction(ctx, holder, item, owned)
end

--[[
	Les objets d'une sorte montrés ici : TOUT le catalogue disponible (ce qui
	ne s'achète pas dit d'où il vient : tirage, Rallye Pass), pour savoir ce
	qui existe ; `ownedOnly` : seulement ce qu'on possède (INVENTAIRE).
]]
local function shownItems(ctx: Context, kind: Catalog.Kind, ownedOnly: boolean?): ({ Catalog.Item }, { [string]: boolean })
	local owned = MenuKit.OwnedSet(ctx)
	local items = {}
	for _, item in ipairs(Catalog.OfKind(kind)) do
		local mine = item.Free == true or owned[item.Id] == true
		if Catalog.IsAvailable(item) and (mine or not ownedOnly) then
			table.insert(items, item)
		end
	end
	return items, owned
end

-- Les cartes des objets d'une sorte, trois par rangée, sans titre.
-- `ownedOnly` : seulement ce qu'on possède (INVENTAIRE).
function ShopPage.ItemRows(ctx: Context, b: Builder, kind: Catalog.Kind, ownedOnly: boolean?)
	local items, owned = shownItems(ctx, kind, ownedOnly)
	local row: Frame? = nil
	for index, item in ipairs(items) do
		local column = (index - 1) % CARD_COLUMNS + 1
		if column == 1 then
			row = b:Row(CARD_HEIGHT + CARD_GAP)
		end
		itemCard(ctx, row :: Frame, column, item, owned)
	end
end

-- Les objets d'une sorte, sous leur titre.
function ShopPage.Items(ctx: Context, b: Builder, kind: Catalog.Kind)
	local items = shownItems(ctx, kind)
	if #items == 0 then
		return
	end
	b:Section(Catalog.KIND_NAMES[kind])
	ShopPage.ItemRows(ctx, b, kind)
end

--[[
	Le catalogue : une rangée de pastilles (une par sorte qui a des objets à
	montrer), puis les cartes de la sorte choisie (gardée d'une ouverture à
	l'autre : ctx.View.ShopKind).
]]
function ShopPage.Catalog(ctx: Context, b: Builder)
	local kinds = {}
	for _, kind in ipairs(Catalog.KINDS) do
		if #(shownItems(ctx, kind :: Catalog.Kind)) > 0 then
			table.insert(kinds, kind)
		end
	end
	if #kinds == 0 then
		return
	end
	local chosen = ctx.View.ShopKind
	if not table.find(kinds, chosen) then
		chosen = kinds[1]
	end
	b:Section("Objets")
	local chips = b:Row(34)
	local gap = 6
	local width = (MenuKit.CONTENT_WIDTH - gap * (#kinds - 1)) / #kinds
	for index, kind in ipairs(kinds) do
		local selected = kind == chosen
		local chip = ctx.Button(chips, KIND_CHIPS[kind] or Format.Upper(Catalog.KIND_NAMES[kind]), (index - 1) * (width + gap), width, function()
			ctx.View.ShopKind = kind
			ctx.Rebuild()
		end)
		chip.TextSize = 11
		chip.BackgroundColor3 = if selected then Theme.ACCENT else Theme.PANEL_2
		chip.TextColor3 = if selected then Theme.ON_ACCENT else Widgets.COLOR_DIM
	end
	b:Row(4)
	ShopPage.ItemRows(ctx, b, chosen :: Catalog.Kind)
end

return ShopPage
