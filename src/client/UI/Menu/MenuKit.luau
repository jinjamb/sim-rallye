--!strict
--[[
	MenuKit.luau
	Ce que partagent les rubriques du menu principal (MainMenu.luau) :
		- Context : ce qu'une rubrique sait du menu (données reçues du
		  serveur, actions, reconstruction) ;
		- Builder : empile des lignes dans le corps du menu (titres de
		  section, textes, lignes libres) ;
		- quelques lignes toutes faites (sélecteur ◀ valeur ▶).
	Une rubrique est une fonction (ctx, b) qui ajoute ses lignes : elle ne
	connaît ni le cadre du menu ni les autres rubriques.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local RaceTypes = require(script.Parent.Parent.Parent.Race.RaceTypes)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local MenuKit = {}

MenuKit.PANEL_WIDTH = 540
MenuKit.CONTENT_WIDTH = MenuKit.PANEL_WIDTH - 32 -- marges intérieures du corps
MenuKit.ROW_HEIGHT = 30

-- Ce que le menu affiche : envoyé par le serveur, relayé par RaceClient.
export type Data = {
	Lobby: { RaceTypes.LobbyRace },
	Race: RaceTypes.RaceSnapshot?,
	Records: RaceTypes.ClassBoards, -- records du tour, par catégorie puis par circuit
	Stats: RaceTypes.Stats?,
	Progress: Progression.Snapshot?,
	Weekly: any, -- { Key, Modifier, EndsAt, Entries, Mine } (ChallengeService)
	Daily: any, -- { EndsAt, Challenges = { Id, Text, Goal, Progress, Done }, Bonus, Xp, BonusXp }
	ReplayOpponent: string?, -- fantôme affronté : son ralenti est proposé
	Laps: { [string]: number },
	Livery: Livery.Livery?,
	Wallet: Wallet?,
	Pass: any, -- Rallye Pass { Key, Name, EndsAt, Xp, Premium } (PassService)
	Drift: any, -- Roi du drift { Key, EndsAt, Entries = { UserId, Name, Score }, Mine } (ChallengeService)
	Team: any, -- écurie { Team, UseColors, Invite, Board, Rank, Season } (TeamService)
	Achievements: { [string]: number }?, -- trophées obtenus : id -> date (AchievementService)
}

-- Solde et objets (EconomyService).
export type Wallet = {
	Credits: number,
	Owned: { string },
	Equipped: { [string]: string },
	Rolls: number?, -- tirages disponibles
	Pity: number?, -- tirages depuis le dernier objet Usine ou plus
}

export type Context = {
	Data: Data,
	LocalUserId: number,
	-- Action demandée au jeu (RaceClient) : "Play", "Replay", "Livery"...
	Action: (string, any) -> (),
	-- Tout reconstruire (après un changement local, comme la livrée).
	Rebuild: () -> (),
	-- Bouton dans une ligne ; le premier créé reçoit la sélection à la manette.
	Button: (parent: Instance, text: string, x: number, width: number, callback: () -> ()) -> TextButton,
	-- Étiquette rafraîchie à chaque image (compte à rebours de la salle d'attente).
	SetCountdown: (TextLabel?) -> (),
	-- Aller à un autre onglet du menu ("Play", "Challenges", "Shop", "Career").
	SetTab: (string) -> (),
	-- État d'affichage propre aux rubriques (catégorie montrée...), gardé
	-- d'une reconstruction à l'autre.
	View: { [string]: any },
}

export type Builder = {
	Order: number,
	Row: (Builder, number?) -> Frame,
	Section: (Builder, string) -> (),
	Text: (Builder, string, number?, Color3?) -> TextLabel,
}

function MenuKit.Builder(body: Instance): Builder
	local builder = { Order = 0 } :: any
	function builder.Row(b: Builder, height: number?): Frame
		b.Order += 1
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, height or MenuKit.ROW_HEIGHT)
		row.LayoutOrder = b.Order
		row.Parent = body
		return row
	end
	-- Titre de section : un pavé rose penché, des capitales italiques, un
	-- filet qui file vers la droite (comme une ligne de vitesse).
	function builder.Section(b: Builder, text: string)
		local row = b:Row(38)
		local mark = Instance.new("Frame")
		mark.BorderSizePixel = 0
		mark.BackgroundColor3 = Theme.ACCENT
		mark.Position = UDim2.fromOffset(0, 13)
		mark.Size = UDim2.fromOffset(14, 20)
		mark.Parent = row
		Theme.Slant(mark, 20)
		local label = Widgets.Label(row, Format.Upper(text), 19, Enum.Font.GothamBlack, Widgets.COLOR_TEXT)
		label.Position = UDim2.fromOffset(20, 12)
		label.Size = UDim2.fromOffset(0, 22)
		label.AutomaticSize = Enum.AutomaticSize.X
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Theme.LINE
		line.AnchorPoint = Vector2.new(1, 0)
		line.Position = UDim2.new(1, 0, 0, 24)
		line.Size = UDim2.new(1, -40, 0, 1)
		line.BackgroundTransparency = 0.7
		line.Parent = row
		-- Le filet commence après le titre (rapport de tailles à l'écran : la
		-- mise à l'échelle du menu s'annule).
		local function fit()
			local width = row.AbsoluteSize.X
			local taken = if width > 0 then label.AbsoluteSize.X / width else 0.5
			line.Size = UDim2.new(math.max(0, 1 - taken), -32, 0, 1)
		end
		row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end
	function builder.Text(b: Builder, text: string, textSize: number?, color: Color3?): TextLabel
		local row = b:Row(20)
		local label = Widgets.Label(row, text, textSize or 14, Enum.Font.GothamMedium, color or Widgets.COLOR_TEXT)
		label.Size = UDim2.new(1, 0, 0, 20)
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		row.AutomaticSize = Enum.AutomaticSize.Y
		return label
	end
	return builder :: Builder
end

-- Catégorie de la voiture choisie au garage (Rally2 par défaut).
function MenuKit.ChosenClass(ctx: Context): string
	local wallet = ctx.Data.Wallet
	local item = Catalog.Get(if wallet then wallet.Equipped.Car else nil)
	return CarClasses.Get(if item then item.CarClass else nil).Id
end

-- Catégories dont le joueur possède la voiture, dans l'ordre du catalogue.
function MenuKit.OwnedClasses(ctx: Context): { string }
	local owned = MenuKit.OwnedSet(ctx)
	local list = {}
	for _, class in ipairs(CarClasses.LIST) do
		local item = Catalog.CarItem(class.Id)
		if item and (item.Free or owned[item.Id]) then
			table.insert(list, class.Id)
		end
	end
	return list
end

-- Objets possédés (dont les objets de série), d'après le portefeuille.
function MenuKit.OwnedSet(ctx: Context): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local wallet = ctx.Data.Wallet
	if wallet then
		for _, id in ipairs(wallet.Owned) do
			set[id] = true
		end
	end
	return set
end

function MenuKit.TrackName(id: string): string
	local circuit = Tracks.Get(id)
	return if circuit then circuit.Name else id
end

-- Format d'une course de rallycross ("Sprint" ou "Event"), en clair.
function MenuKit.RaceFormatName(format: string): string
	return if format == "Event" then "Qualif + finale" else "Course simple"
end

-- Ligne "libellé  [◀] valeur [▶]". Renvoie l'étiquette de la valeur.
function MenuKit.Stepper(ctx: Context, b: Builder, label: string, value: string, onStep: (number) -> ()): TextLabel
	local row = b:Row()
	local text = Widgets.Label(row, label, 14)
	text.Size = UDim2.new(0, 200, 1, 0)
	local width = MenuKit.CONTENT_WIDTH
	ctx.Button(row, "◀", width - 240, 40, function()
		onStep(-1)
	end)
	local valueLabel = Widgets.Label(row, value, 14, Enum.Font.GothamBold)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Position = UDim2.fromOffset(width - 196, 0)
	valueLabel.Size = UDim2.new(0, 152, 1, 0)
	ctx.Button(row, "▶", width - 40, 40, function()
		onStep(1)
	end)
	return valueLabel
end

return MenuKit
