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
		ÉQUIPEMENT   ses voitures, sons moteur, fumées, klaxons, célébrations :
		             seulement ce qu'on possède, en cartes avec PORTER.

	La boutique, elle, montre tout le catalogue (ShopPage.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarBodies = require(ReplicatedStorage.Shared.Vehicle.CarBodies)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
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
local GEAR_KINDS: { Catalog.Kind } = { "Car", "Engine", "Smoke", "Horn", "Celebration" }

--[[
	Une rangée de pastilles (CHIPS_PER_ROW par ligne). `selected` : l'indice
	choisi ; `unlocked(i)` ; `pick(i)` au clic d'une pastille libre ;
	`why(i)` : le texte affiché au clic d'une pastille verrouillée.
]]
local function chips(
	ctx: Context,
	b: Builder,
	names: { string },
	selected: number,
	unlocked: (number) -> boolean,
	pick: (number) -> (),
	why: (number) -> string
)
	local width = (MenuKit.CONTENT_WIDTH - CHIP_GAP * (CHIPS_PER_ROW - 1)) / CHIPS_PER_ROW
	local row: Frame? = nil
	for index, name in ipairs(names) do
		local column = (index - 1) % CHIPS_PER_ROW
		if column == 0 then
			row = b:Row(CHIP_HEIGHT + 4)
		end
		local free = unlocked(index)
		local chosen = index == selected
		local chip = ctx.Button(row :: Frame, (if free then "" else "🔒 ") .. name, column * (width + CHIP_GAP), width, function()
			if chosen then
				return
			end
			if free then
				pick(index)
			else
				ctx.View.InventoryHint = why(index)
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

-- Équipe une nouvelle livrée (modèle ou pièce changés) : sauvegardée par le serveur.
local function equip(ctx: Context, livery: Livery.Livery, field: string, value: number)
	local changed: any = table.clone(livery)
	changed[field] = value
	ctx.View.InventoryHint = nil
	ctx.Action("Livery", changed)
end

function InventoryPage.Car(ctx: Context, b: Builder)
	local livery = ctx.Data.Livery
	b:Section("Ta voiture")
	if not livery then
		b:Text("Chargement de ta voiture…", 13, Widgets.COLOR_DIM)
		return
	end
	local progress = ctx.Data.Progress
	local owned = MenuKit.OwnedSet(ctx)

	-- Aperçu : la voiture telle qu'elle roulera.
	local previewRow = b:Row(PREVIEW_HEIGHT)
	local preview = ItemArt.Car(previewRow, MenuKit.ChosenClass(ctx), livery, MenuKit.CONTENT_WIDTH, PREVIEW_HEIGHT)
	preview.Position = UDim2.fromOffset(0, 0)

	local hint = ctx.View.InventoryHint
	if hint then
		b:Text("🔒 " .. hint, 13, Theme.ORANGE)
	end

	-- Le modèle.
	local body = CarBodies.Get(livery.Body)
	b:Text("MODÈLE · " .. Format.Upper(body.Name) .. " — " .. body.Description, 13, Theme.YELLOW)
	local names = {}
	for _, model in ipairs(CarBodies.LIST) do
		table.insert(names, model.Name)
	end
	chips(ctx, b, names, livery.Body, function(i)
		return Progression.IsUnlocked("Body", i, progress, owned)
	end, function(i)
		equip(ctx, livery, "Body", i)
	end, function(i)
		local item = Progression.ItemFor("Body", i)
		return Livery.ItemName("Body", i) .. " : " .. (if item then Progression.Describe(item.Requirement) else "?")
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
			chips(ctx, b, optionNames, current, function(i)
				return Progression.IsUnlocked(slot.Key :: any, i, progress, owned)
			end, function(i)
				equip(ctx, livery, slot.Key, i)
			end, function(i)
				local item = Progression.ItemFor(slot.Key :: any, i)
				return Livery.ItemName(slot.Key, i) .. " : " .. (if item then Progression.Describe(item.Requirement) else "?")
			end)
		end
	end
	if body.Custom == false then
		b:Text("La carrosserie d'origine ne prend que les jantes : choisis un modèle du jeu pour les autres pièces.", 12, Widgets.COLOR_DIM)
	end
	b:Text("Couleurs, bandes et numéro : au GARAGE (zone violette du paddock).", 12, Widgets.COLOR_DIM)
end

-- Ce qu'on possède, par sorte : les cartes PORTER de la boutique.
function InventoryPage.Gear(ctx: Context, b: Builder)
	for _, kind in ipairs(GEAR_KINDS) do
		b:Section(Catalog.KIND_NAMES[kind])
		ShopPage.ItemRows(ctx, b, kind, true)
	end
	b:Text("Plus d'objets : BOUTIQUE (tirages, crédits) et RALLYE PASS.", 12, Widgets.COLOR_DIM)
end


return InventoryPage
