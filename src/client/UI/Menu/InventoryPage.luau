--!strict
--[[
	InventoryPage.luau
	L'onglet INVENTAIRE : tout ce qu'on a débloqué en jouant, et l'équiper.

		TA VOITURE   l'aperçu 3D de sa voiture telle qu'elle est (modèle,
		             pièces, livrée), puis le choix du modèle et de chaque
		             pièce en pastilles. Ce qui est verrouillé porte un cadenas ;
		             un clic dessus dit comment le débloquer (niveau, médaille,
		             tirage...). Un clic sur une pastille libre l'équipe aussitôt
		             (sauvegardé comme la livrée : Livery.luau).
		LIVRÉE       couleurs, bandes, plaques et motif, en pastilles, de
		             même ; puis la PEINTURE PAR PIÈCE : on choisit une zone
		             de la carrosserie (capot, toit, portières...), puis sa
		             couleur (ou « d'origine »).
		ÉQUIPEMENT   ses voitures, sons moteur, retours de flamme, phares, fumées,
		             klaxons, célébrations :
		             seulement ce qu'on possède, en cartes avec PORTER.

	DÉBLOQUER EN ROBUX : sous le « comment le débloquer » d'une pastille
	verrouillée, un bouton l'achète tout de suite (au palier de son prix,
	MonetizationService) ; une pièce de tirage s'achète comme objet.

	La boutique, elle, montre tout le catalogue (ShopPage.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarBodies = require(ReplicatedStorage.Shared.Vehicle.CarBodies)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Products = require(ReplicatedStorage.Shared.Economy.Products)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local ShopPage = require(script.Parent.ShopPage)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local ItemArt = require(script.Parent.Parent.ItemArt)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local InventoryPage = {}

local PREVIEW_HEIGHT = 190
local CHIP_HEIGHT = 30
local CHIP_GAP = 6
local CHIPS_PER_ROW = 3

-- Équipement montré, dans l'ordre (les pièces sont choisies sur la voiture).
local GEAR_KINDS: { Catalog.Kind } = { "Car", "Engine", "Backfire", "Headlight", "Smoke", "Horn", "Celebration" }

-- La pastille verrouillée sur laquelle on a cliqué : sa condition, son achat.
type Locked = { Kind: string, Index: number, Text: string }

--[[
	Une rangée de pastilles (CHIPS_PER_ROW par ligne) pour les choix d'une
	sorte de déblocage (`kind` : Progression.Kind). `selected` : l'indice
	choisi ; `pick(i)` au clic d'une pastille libre ; un clic sur une pastille
	verrouillée affiche sa condition (et son achat).
]]
local function chips(ctx: Context, b: Builder, kind: string, names: { string }, selected: number, pick: (number) -> ())
	local progress = ctx.Data.Progress
	local owned = MenuKit.OwnedSet(ctx)
	local width = (MenuKit.CONTENT_WIDTH - CHIP_GAP * (CHIPS_PER_ROW - 1)) / CHIPS_PER_ROW
	local row: Frame? = nil
	for index, name in ipairs(names) do
		local column = (index - 1) % CHIPS_PER_ROW
		if column == 0 then
			row = b:Row(CHIP_HEIGHT + 4)
		end
		local free = Progression.IsUnlocked(kind :: any, index, progress, owned)
		local chosen = index == selected
		local chip = ctx.Button(row :: Frame, (if free then "" else "🔒 ") .. name, column * (width + CHIP_GAP), width, function()
			if chosen then
				return
			end
			if free then
				ctx.View.InventoryLocked = nil
				pick(index)
			else
				local item = Progression.ItemFor(kind :: any, index)
				ctx.View.InventoryLocked = {
					Kind = kind,
					Index = index,
					Text = Livery.ItemName(kind, index) .. " : " .. (if item then Progression.Describe(item.Requirement) else "?"),
				} :: Locked
				ctx.Rebuild()
			end
		end)
		chip.Size = UDim2.new(0, width, 0, CHIP_HEIGHT)
		chip.TextSize = 12
		chip.TextScaled = (utf8.len(chip.Text) or #chip.Text) > 16
		chip.BackgroundColor3 = if chosen then Theme.ACCENT else Theme.PANEL_2
		chip.TextColor3 = if chosen then Theme.ON_ACCENT elseif free then Widgets.COLOR_TEXT else Widgets.COLOR_DIM
	end
end

-- Équipe une nouvelle livrée (modèle, pièce, couleur...) : sauvegardée par le serveur.
local function equip(ctx: Context, livery: Livery.Livery, field: string, value: number)
	local changed: any = table.clone(livery)
	changed[field] = value
	ctx.Action("Livery", changed)
end

-- La condition de la pastille verrouillée choisie, et le bouton pour l'acheter.
local function lockedPanel(ctx: Context, b: Builder)
	local locked: Locked? = ctx.View.InventoryLocked
	if not locked then
		return
	end
	b:Text("🔒 " .. locked.Text, 13, Theme.ORANGE)
	local entry = Progression.ItemFor(locked.Kind :: any, locked.Index)
	if not entry then
		return
	end
	local partId = entry.Requirement.Item
	local product = if partId then Products.ForItem(partId) else Products.ForUnlock(entry.Requirement)
	if not product then
		return
	end
	local row = b:Row(36)
	local label = Widgets.Label(row, "Ou tout de suite :", 13, Enum.Font.GothamBold, Widgets.COLOR_DIM)
	label.Size = UDim2.new(1, -ShopPage.BUTTON_WIDTH - 8, 1, 0)
	ShopPage.RobuxButton(ctx, row, product, nil, nil, function()
		if partId then
			ctx.Action("RobuxItem", partId)
		else
			ctx.Action("RobuxUnlock", { Kind = locked.Kind, Index = locked.Index })
		end
	end)
end

function InventoryPage.Car(ctx: Context, b: Builder)
	local livery = ctx.Data.Livery
	b:Section("Ta voiture")
	if not livery then
		b:Text("Chargement de ta voiture…", 13, Widgets.COLOR_DIM)
		return
	end

	-- Aperçu : la voiture telle qu'elle roulera.
	local previewRow = b:Row(PREVIEW_HEIGHT)
	local preview = ItemArt.Car(previewRow, MenuKit.ChosenClass(ctx), livery, MenuKit.CONTENT_WIDTH, PREVIEW_HEIGHT)
	preview.Position = UDim2.fromOffset(0, 0)

	lockedPanel(ctx, b)

	-- Le modèle.
	local body = CarBodies.Get(livery.Body)
	b:Text("MODÈLE · " .. Format.Upper(body.Name) .. " · " .. body.Description, 13, Theme.YELLOW)
	local names = {}
	for _, model in ipairs(CarBodies.LIST) do
		table.insert(names, model.Name)
	end
	chips(ctx, b, "Body", names, livery.Body, function(i)
		equip(ctx, livery, "Body", i)
	end)

	-- Les pièces que ce modèle prend.
	for _, slot in ipairs(CarBodies.SLOTS) do
		if CarBodies.HasSlot(body, slot.Key) then
			local current = (livery :: any)[slot.Key] or 1
			b:Text(Format.Upper(slot.Name), 13, Theme.YELLOW)
			local optionNames = {}
			for _, option in ipairs(slot.Options) do
				table.insert(optionNames, option.Name)
			end
			chips(ctx, b, slot.Key, optionNames, current, function(i)
				equip(ctx, livery, slot.Key, i)
			end)
		end
	end
	if body.Custom == false then
		b:Text("La carrosserie d'origine ne prend que les jantes : choisis un modèle du jeu pour les autres pièces.", 12, Widgets.COLOR_DIM)
	end
end

-- Couleurs, bandes et plaques : de même (le numéro se règle au garage).
function InventoryPage.Livery(ctx: Context, b: Builder)
	local livery = ctx.Data.Livery
	if not livery then
		return
	end
	b:Section("Livrée")
	local function names(list: { any }): { string }
		local result = {}
		for _, entry in ipairs(list) do
			table.insert(result, entry.Name)
		end
		return result
	end
	b:Text("COULEUR", 13, Theme.YELLOW)
	chips(ctx, b, "Color", names(Livery.COLORS), livery.Color, function(i)
		equip(ctx, livery, "Color", i)
	end)
	b:Text("BANDES", 13, Theme.YELLOW)
	chips(ctx, b, "Stripes", names(Livery.STRIPES), livery.Stripes, function(i)
		equip(ctx, livery, "Stripes", i)
	end)
	b:Text("PLAQUE DU NUMÉRO", 13, Theme.YELLOW)
	chips(ctx, b, "Plate", names(Livery.PLATES), livery.Plate, function(i)
		equip(ctx, livery, "Plate", i)
	end)
	b:Text("MOTIF", 13, Theme.YELLOW)
	chips(ctx, b, "Pattern", names(Livery.PATTERNS), livery.Pattern or 1, function(i)
		equip(ctx, livery, "Pattern", i)
	end)
	local pattern = Livery.PATTERNS[livery.Pattern or 1]
	if pattern and (livery.Pattern or 1) > 1 then
		if pattern.Image == 0 then
			b:Text("Ce motif arrive bientôt : il s'affichera sur ta voiture dès qu'il sera disponible.", 12, Widgets.COLOR_DIM)
		end
		b:Text("COULEUR DU MOTIF", 13, Theme.YELLOW)
		chips(ctx, b, "Color", names(Livery.COLORS), livery.PatternColor or 4, function(i)
			equip(ctx, livery, "PatternColor", i)
		end)
	end
	b:Text("Numéro et couleur des bandes : au GARAGE (zone violette du paddock).", 12, Widgets.COLOR_DIM)
end

--[[
	Peinture par pièce : la zone choisie (ctx.View.PaintZone), puis sa
	couleur. « D'origine » rend à la zone sa peinture de série. Une pièce
	peinte à part reste unie (le motif couvre la couleur principale).
]]
function InventoryPage.Paint(ctx: Context, b: Builder)
	local livery = ctx.Data.Livery
	if not livery then
		return
	end
	b:Section("Peinture par pièce")
	local body = CarBodies.Get(livery.Body)
	if not body.Custom then
		b:Text("La carrosserie d'origine se peint d'un seul bloc : choisis un modèle du jeu pour peindre chaque pièce.", 12, Widgets.COLOR_DIM)
		return
	end
	local zoneIndex = 1
	for index, zone in ipairs(CarBodies.ZONES) do
		if zone.Key == ctx.View.PaintZone then
			zoneIndex = index
		end
	end
	local zone = CarBodies.ZONES[zoneIndex]
	local paints = livery.Paints or {}
	-- Les zones : celles déjà peintes à part sont marquées d'un point.
	local zoneNames = {}
	for _, entry in ipairs(CarBodies.ZONES) do
		table.insert(zoneNames, (if paints[entry.Key] then "● " else "") .. entry.Name)
	end
	b:Text("PIÈCE", 13, Theme.YELLOW)
	chips(ctx, b, "Zone", zoneNames, zoneIndex, function(i)
		ctx.View.PaintZone = CarBodies.ZONES[i].Key
		ctx.Rebuild()
	end)
	-- Sa couleur.
	local chosen = paints[zone.Key]
	b:Text("COULEUR · " .. Format.Upper(zone.Name), 13, Theme.YELLOW)
	local function setZone(color: number?)
		local changed: any = table.clone(livery)
		local newPaints = table.clone(paints)
		newPaints[zone.Key] = color
		changed.Paints = newPaints
		ctx.Action("Livery", changed)
	end
	local row = b:Row(CHIP_HEIGHT + 4)
	local original = ctx.Button(row, "D'ORIGINE", 0, MenuKit.CONTENT_WIDTH, function()
		if chosen ~= nil then
			setZone(nil)
		end
	end)
	original.Size = UDim2.new(0, MenuKit.CONTENT_WIDTH, 0, CHIP_HEIGHT)
	original.TextSize = 12
	original.BackgroundColor3 = if chosen == nil then Theme.ACCENT else Theme.PANEL_2
	original.TextColor3 = if chosen == nil then Theme.ON_ACCENT else Widgets.COLOR_TEXT
	local colorNames = {}
	for _, swatch in ipairs(Livery.COLORS) do
		table.insert(colorNames, swatch.Name)
	end
	chips(ctx, b, "Color", colorNames, chosen or 0, function(i)
		setZone(i)
	end)
	b:Text("Une pièce peinte à part reste unie : le motif couvre seulement la couleur principale.", 12, Widgets.COLOR_DIM)
end

-- Ce qu'on possède, par sorte : les cartes PORTER de la boutique.
function InventoryPage.Gear(ctx: Context, b: Builder)
	for _, kind in ipairs(GEAR_KINDS) do
		b:Section(Catalog.KIND_NAMES[kind])
		ShopPage.ItemRows(ctx, b, kind, true)
	end
	b:Text("Plus d'objets : BOUTIQUE (tirages, crédits, Robux) et RALLYE PASS.", 12, Widgets.COLOR_DIM)
end

return InventoryPage
