--!strict
--[[
	Garage.luau
	Le garage du paddock : entrer dans la zone violette ouvre ce panneau.
		- sa progression : niveau, licence, barre d'XP (Progression.luau) ;
		- la livrée : couleur, numéro, bandes de course et leur couleur, style
		  du numéro, motif et sa couleur (sauvegardée, visible de tous en
		  course) ; la peinture pièce par pièce se fait dans le menu
		  (INVENTAIRE), l'aperçu d'ici la montre ;
		- accès aux réglages de la voiture (le menu P).
	Derrière la zone, la voiture tourne sur sa plaque, aux couleurs choisies,
	peinte exactement comme en jeu (LiveryPainter.luau). Cet aperçu est une
	copie LOCALE du gabarit, comme le fantôme : chacun voit sa propre voiture
	sur la plaque, et elle n'existe que chez lui.

	COSMÉTIQUES VERROUILLÉS : on peut les essayer sur l'aperçu, la condition
	pour les débloquer s'affiche ; la livrée n'est sauvegardée que si tout ce
	qu'elle utilise est débloqué (le serveur le vérifie aussi). En sortant du
	garage, l'aperçu revient à la livrée sauvegardée.

]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local PaddockLayout = require(ReplicatedStorage.Shared.Paddock.PaddockLayout)
local LiveryPainter = require(ReplicatedStorage.Shared.Cosmetics.LiveryPainter)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local CarBodies = require(ReplicatedStorage.Shared.Vehicle.CarBodies)
local BodyKits = require(ReplicatedStorage.Shared.Vehicle.BodyKits)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)

local Garage = {}
Garage.__index = Garage

export type Callbacks = {
	GetLivery: () -> Livery.Livery?,
	SetLivery: (Livery.Livery) -> (),
	GetProgress: () -> Progression.Snapshot?,
	OpenSetup: () -> (),
	-- Catégorie de la voiture choisie : sa carrosserie sur l'aperçu.
	GetCarClass: () -> string,
	-- La voiture choisie (CarModels.luau) : sa carrosserie si la livrée la garde (Body = 0).
	GetCarModel: () -> string?,
	-- Objets possédés (pièces gagnées aux tirages).
	GetOwned: () -> { [string]: boolean },
}

export type Garage = typeof(setmetatable({}, Garage)) & {
	Callbacks: Callbacks,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	LevelLabel: TextLabel,
	XpFill: Frame,
	ColorLabel: TextLabel,
	NumberLabel: TextLabel,
	StripesLabel: TextLabel,
	StripeColorLabel: TextLabel,
	PlateLabel: TextLabel,
	PatternLabel: TextLabel,
	PatternColorLabel: TextLabel,
	FinishLabel: TextLabel,
	-- Carrosserie (CarBodies.luau) : le modèle, puis une ligne par emplacement de pièce.
	BodyLabel: TextLabel,
	SlotLabels: { [string]: TextLabel },
	Hint: TextLabel,
	FirstButton: GuiButton?,
	TouchLayout: boolean,
	Inside: boolean,
	-- Livrée essayée (peut contenir un cosmétique verrouillé) ; nil = la sauvegardée.
	Draft: Livery.Livery?,
	Showroom: Model?,
	ShowroomBase: CFrame?,
	Angle: number,
	Shown: string, -- livrée affichée sur l'aperçu (Livery.Key)
	ShownClass: string, -- catégorie et voiture affichées sur l'aperçu (kit, carrosserie)
}

local PANEL_WIDTH = 380
local PANEL_HEIGHT = 804
local BODY_ROW = 34 -- lignes de la carrosserie, un peu plus serrées
local SPIN_SPEED = 0.35 -- rad/s
local COLOR_LOCKED = Theme.ORANGE
local HINT_TEXT = "Ta livrée se voit sur ta voiture, en course comme aux essais. Les cosmétiques verrouillés se gagnent en jouant : niveaux, médailles, victoires, points de style."

function Garage.new(playerGui: Instance, callbacks: Callbacks): Garage
	local self = (setmetatable({}, Garage) :: any) :: Garage
	self.Callbacks = callbacks
	self.TouchLayout = false
	self.Inside = false
	self.Draft = nil
	self.Showroom = nil
	self.ShowroomBase = nil
	self.Angle = 0
	self.Shown = ""
	self.ShownClass = ""
	self.FirstButton = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "Garage"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10
	self.Gui = gui

	local panel = Widgets.Panel(gui, 0.08)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -24, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.Panel = panel
	self.Scale = scale

	-- Filigrane « ガレージ » (garage) derrière l'en-tête.
	local kana = Theme.Kana(panel, "ガレージ", 40, 0.9)
	kana.Position = UDim2.fromOffset(-60, -4)
	kana.Size = UDim2.new(1, 0, 0, 48)
	local title = Widgets.Label(panel, "GARAGE", 22, Enum.Font.GothamBlack, PaddockLayout.GARAGE_PAD.Color)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -70, 0, 24)
	local close = Widgets.Button(panel, "X", function()
		self:SetOpen(false)
	end)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Size = UDim2.fromOffset(32, 28)
	close.TextSize = 16

	-- Progression : niveau, licence, barre jusqu'au niveau suivant.
	local level = Widgets.Label(panel, "", 14, Enum.Font.GothamBold)
	level.Position = UDim2.fromOffset(16, 44)
	level.Size = UDim2.new(1, -32, 0, 20)
	level.RichText = true
	self.LevelLabel = level
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(16, 68)
	track.Size = UDim2.new(1, -32, 0, 6)
	track.BackgroundColor3 = Widgets.COLOR_BUTTON
	track.BorderSizePixel = 0
	Widgets.Corner(track, 3)
	track.Parent = panel
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	Widgets.Corner(fill, 3)
	fill.Parent = track
	self.XpFill = fill

	local car = Widgets.Label(panel, "Peinture par pièce et accessoires : menu C › INVENTAIRE", 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
	car.Position = UDim2.fromOffset(16, 82)
	car.Size = UDim2.new(1, -32, 0, 18)

	-- Ligne "libellé [◀] valeur [▶]".
	local function stepper(y: number, text: string, onStep: (number) -> ()): TextLabel
		local label = Widgets.Label(panel, text, 14)
		label.Position = UDim2.fromOffset(16, y)
		label.Size = UDim2.fromOffset(110, 30)
		local previous = Widgets.Button(panel, "◀", function()
			onStep(-1)
		end)
		previous.Position = UDim2.fromOffset(PANEL_WIDTH - 246, y)
		previous.Size = UDim2.fromOffset(40, 30)
		if not self.FirstButton then
			self.FirstButton = previous
		end
		local value = Widgets.Label(panel, "", 13, Enum.Font.GothamBold)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.Position = UDim2.fromOffset(PANEL_WIDTH - 200, y)
		value.Size = UDim2.fromOffset(138, 30)
		Widgets.Corner(value, 6)
		local nextButton = Widgets.Button(panel, "▶", function()
			onStep(1)
		end)
		nextButton.Position = UDim2.fromOffset(PANEL_WIDTH - 56, y)
		nextButton.Size = UDim2.fromOffset(40, 30)
		return value
	end

	-- Un élément de la livrée change : essayé sur l'aperçu, sauvegardé s'il
	-- est entièrement débloqué.
	local function change(field: string, count: number, direction: number, first: number?)
		local base = self:_shown()
		if not base then
			return
		end
		local draft: any = table.clone(base)
		local low = first or 1
		draft[field] = (((draft[field] or low) - low + direction) % count) + low
		-- Une couleur de la palette remplace la couleur sur mesure de ce champ.
		if base.Custom and base.Custom[field] then
			draft.Custom = table.clone(base.Custom)
			draft.Custom[field] = nil
		end
		self.Draft = draft
		if self:_lockedText(draft) == nil then
			callbacks.SetLivery(draft)
		end
		self:_refresh()
	end
	local y = 110
	self.ColorLabel = stepper(y, "Couleur", function(direction)
		change("Color", #Livery.COLORS, direction)
	end)
	self.NumberLabel = stepper(y + 38, "Numéro", function(direction)
		change("Number", Livery.MAX_NUMBER - Livery.MIN_NUMBER + 1, direction, Livery.MIN_NUMBER)
	end)
	self.StripesLabel = stepper(y + 76, "Bandes", function(direction)
		change("Stripes", #Livery.STRIPES, direction)
	end)
	self.StripeColorLabel = stepper(y + 114, "Couleur bandes", function(direction)
		change("StripeColor", #Livery.COLORS, direction)
	end)
	self.PlateLabel = stepper(y + 152, "Style numéro", function(direction)
		change("Plate", #Livery.PLATES, direction)
	end)
	self.PatternLabel = stepper(y + 190, "Motif", function(direction)
		change("Pattern", #Livery.PATTERNS, direction)
	end)
	self.PatternColorLabel = stepper(y + 228, "Couleur motif", function(direction)
		change("PatternColor", #Livery.COLORS, direction)
	end)
	self.FinishLabel = stepper(y + 266, "Finition", function(direction)
		change("Finish", #Livery.FINISHES, direction)
	end)

	-- Carrosserie : le modèle et ses pièces. Une pièce que le modèle ne prend
	-- pas (la carrosserie d'origine n'a que les jantes) s'affiche « - ».
	local bodyTitle = Widgets.Label(panel, "CARROSSERIE", 14, Enum.Font.GothamBlack, Theme.ACCENT)
	bodyTitle.Position = UDim2.fromOffset(16, y + 304)
	bodyTitle.Size = UDim2.new(1, -32, 0, 18)
	local bodyY = y + 326
	self.BodyLabel = stepper(bodyY, "Modèle", function(direction)
		-- 0 : la carrosserie de la voiture, puis chaque modèle.
		change("Body", #CarBodies.LIST + 1, direction, 0)
	end)
	-- Les pièces principales ; les accessoires se choisissent dans le menu (INVENTAIRE).
	self.SlotLabels = {}
	local rows = 0
	for _, slot in ipairs(CarBodies.SLOTS) do
		if not slot.Accessory then
			rows += 1
			self.SlotLabels[slot.Key] = stepper(bodyY + rows * BODY_ROW, slot.Name, function(direction)
				change(slot.Key, #slot.Options, direction)
			end)
		end
	end
	local setupY = bodyY + (rows + 1) * BODY_ROW + 10

	local setup = Widgets.Button(panel, "RÉGLAGES DE LA VOITURE (P)", function()
		callbacks.OpenSetup()
	end)
	setup.Position = UDim2.fromOffset(16, setupY)
	setup.Size = UDim2.new(1, -32, 0, 36)

	local hint = Widgets.Label(panel, HINT_TEXT, 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
	hint.Position = UDim2.fromOffset(16, setupY + 44)
	hint.Size = UDim2.new(1, -32, 0, 90)
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top
	self.Hint = hint

	gui.Parent = playerGui
	self:_refresh()
	return self
end

function Garage:SetTouchLayout(enabled: boolean)
	self.TouchLayout = enabled
	-- Mobile : au centre, au-dessus du joystick et du bouton de saut.
	self.Panel.AnchorPoint = if enabled then Vector2.new(0.5, 0) else Vector2.new(1, 0.5)
	self.Panel.Position = if enabled then UDim2.new(0.5, 0, 0, 50) else UDim2.new(1, -24, 0.5, 0)
end

-- La livrée montrée : celle qu'on essaie, sinon la sauvegardée.
function Garage:_shown(): Livery.Livery?
	return self.Draft or self.Callbacks.GetLivery()
end

-- Ce qui est verrouillé dans cette livrée, et comment le débloquer (nil : rien).
function Garage:_lockedText(livery: Livery.Livery): string?
	local progress = self.Callbacks.GetProgress()
	local owned = self.Callbacks.GetOwned()
	local lines = {}
	local checks: { { Kind: Progression.Kind, Index: number } } = {
		{ Kind = "Color", Index = livery.Color },
		{ Kind = "Stripes", Index = livery.Stripes },
		{ Kind = "Color", Index = livery.StripeColor },
		{ Kind = "Plate", Index = livery.Plate },
		{ Kind = "Pattern", Index = livery.Pattern or 1 },
		{ Kind = "Finish", Index = livery.Finish or 1 },
		{ Kind = "TrimFinish", Index = livery.TrimFinish or 1 },
		{ Kind = "Sponsor", Index = livery.SponsorHood or 1 },
		{ Kind = "Sponsor", Index = livery.SponsorDoors or 1 },
		{ Kind = "Sponsor", Index = livery.SponsorRoof or 1 },
		{ Kind = "Color", Index = livery.PatternColor or 4 },
		{ Kind = "Body", Index = livery.Body },
	}
	for _, color in pairs(livery.Paints or {}) do
		table.insert(checks, { Kind = "Color", Index = color })
	end
	if livery.Custom and next(livery.Custom) ~= nil then
		table.insert(checks, { Kind = "Custom", Index = 1 })
	end
	local body = CarBodies.Get(livery.Body)
	for _, slot in ipairs(CarBodies.SLOTS) do
		-- Carrosserie de la voiture (Body = 0) : ses pièces sont à elle ; jantes et accessoires restent au joueur.
		if CarBodies.HasSlot(body, slot.Key) and (livery.Body ~= 0 or slot.Key == "Rims" or slot.Accessory) then
			table.insert(checks, { Kind = slot.Key :: any, Index = (livery :: any)[slot.Key] })
		end
	end
	local seen: { [string]: boolean } = {}
	for _, check in ipairs(checks) do
		local item = Progression.ItemFor(check.Kind, check.Index)
		local key = check.Kind .. check.Index
		if item and not seen[key] and not Progression.Meets(item.Requirement, progress, owned) then
			seen[key] = true
			table.insert(lines, Livery.ItemName(check.Kind, check.Index) .. " : " .. Progression.Describe(item.Requirement))
		end
	end
	return if #lines > 0 then "Verrouillé : " .. table.concat(lines, " · ") .. ". Essai seulement : non sauvegardé." else nil
end

local function valueText(name: string, unlocked: boolean): string
	return if unlocked then name else "🔒 " .. name
end

function Garage:_refresh()
	-- Progression.
	local progress = self.Callbacks.GetProgress()
	if progress then
		local licence = Progression.LICENCES[progress.Licence] or Progression.LICENCES[1]
		local nextXp = progress.NextXp
		self.LevelLabel.Text = string.format(
			'Niveau %d · <font color="%s">Licence %s</font>  <font color="#8C909A">%s%s XP</font>',
			progress.Level,
			Medals.Hex(licence.Color),
			licence.Name,
			Format.Thousands(progress.Xp),
			if nextXp then " / " .. Format.Thousands(nextXp) else ""
		)
		self.XpFill.BackgroundColor3 = licence.Color
		self.XpFill.Size = UDim2.fromScale(
			if nextXp then math.clamp((progress.Xp - progress.LevelXp) / math.max(1, nextXp - progress.LevelXp), 0, 1) else 1,
			1
		)
	else
		self.LevelLabel.Text = "Progression : chargement…"
	end

	local livery = self:_shown()
	if not livery then
		for _, label in ipairs({ self.ColorLabel, self.NumberLabel, self.StripesLabel, self.StripeColorLabel, self.PlateLabel, self.PatternLabel, self.PatternColorLabel, self.FinishLabel, self.BodyLabel }) do
			label.Text = "…"
		end
		for _, label in pairs(self.SlotLabels) do
			label.Text = "…"
		end
		return
	end
	local function swatch(label: TextLabel, color: Color3)
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = color
		label.TextColor3 = Livery.ContrastOf(color)
	end
	local function plain(label: TextLabel, unlocked: boolean)
		label.BackgroundTransparency = 1
		label.TextColor3 = if unlocked then Widgets.COLOR_TEXT else COLOR_LOCKED
	end

	-- Objets possédés : pièces de tirage et déblocages achetés en Robux.
	local owned = self.Callbacks.GetOwned()
	self.ColorLabel.Text = valueText(Livery.NameOf(livery), Progression.IsUnlocked("Color", livery.Color, progress, owned))
	swatch(self.ColorLabel, Livery.ColorOf(livery))
	self.NumberLabel.Text = "#" .. tostring(livery.Number)
	plain(self.NumberLabel, true)
	local stripes = Livery.STRIPES[livery.Stripes] or Livery.STRIPES[1]
	local stripesUnlocked = Progression.IsUnlocked("Stripes", livery.Stripes, progress, owned)
	self.StripesLabel.Text = valueText(stripes.Name, stripesUnlocked)
	plain(self.StripesLabel, stripesUnlocked)
	local stripeColor = Livery.COLORS[livery.StripeColor] or Livery.COLORS[3]
	self.StripeColorLabel.Text = valueText(if livery.Custom and livery.Custom.StripeColor then livery.Custom.StripeColor else stripeColor.Name, Progression.IsUnlocked("Color", livery.StripeColor, progress, owned))
	swatch(self.StripeColorLabel, Livery.StripeColorOf(livery))
	local plate = Livery.PLATES[livery.Plate] or Livery.PLATES[1]
	local plateUnlocked = Progression.IsUnlocked("Plate", livery.Plate, progress, owned)
	self.PlateLabel.Text = valueText(plate.Name, plateUnlocked)
	plain(self.PlateLabel, plateUnlocked)
	local patternIndex = livery.Pattern or 1
	local pattern = Livery.PATTERNS[patternIndex] or Livery.PATTERNS[1]
	local patternUnlocked = Progression.IsUnlocked("Pattern", patternIndex, progress, owned)
	self.PatternLabel.Text = valueText(pattern.Name, patternUnlocked)
	plain(self.PatternLabel, patternUnlocked)
	local patternColor = Livery.COLORS[livery.PatternColor or 4] or Livery.COLORS[4]
	self.PatternColorLabel.Text = valueText(if livery.Custom and livery.Custom.PatternColor then livery.Custom.PatternColor else patternColor.Name, Progression.IsUnlocked("Color", livery.PatternColor or 4, progress, owned))
	swatch(self.PatternColorLabel, Livery.PatternColorOf(livery))
	local finishIndex = livery.Finish or 1
	local finish = Livery.FINISHES[finishIndex] or Livery.FINISHES[1]
	local finishUnlocked = Progression.IsUnlocked("Finish", finishIndex, progress, owned)
	self.FinishLabel.Text = valueText(finish.Name, finishUnlocked)
	plain(self.FinishLabel, finishUnlocked)

	-- Carrosserie : le modèle, et chaque pièce (« - » si le modèle ne la prend pas).
	local ownBody = livery.Body == 0
	local body = CarBodies.Get(livery.Body)
	local bodyUnlocked = Progression.IsUnlocked("Body", livery.Body, progress, owned)
	self.BodyLabel.Text = if ownBody then "De la voiture" else valueText(body.Name, bodyUnlocked)
	plain(self.BodyLabel, bodyUnlocked)
	for _, slot in ipairs(CarBodies.SLOTS) do
		local label = self.SlotLabels[slot.Key]
		if not label then
			continue -- accessoire : choisi dans le menu
		elseif ownBody and slot.Key ~= "Rims" then
			label.Text = "De la voiture"
			plain(label, true)
		elseif CarBodies.HasSlot(body, slot.Key) then
			local index = (livery :: any)[slot.Key] or 1
			local option = slot.Options[index] or slot.Options[1]
			local unlocked = Progression.IsUnlocked(slot.Key :: any, index, progress, owned)
			label.Text = valueText(option.Name, unlocked)
			plain(label, unlocked)
		else
			label.Text = "-"
			label.BackgroundTransparency = 1
			label.TextColor3 = Widgets.COLOR_DIM
		end
	end

	local locked = self:_lockedText(livery)
	self.Hint.Text = locked or HINT_TEXT
	self.Hint.TextColor3 = if locked then COLOR_LOCKED else Widgets.COLOR_DIM
end

function Garage:SetOpen(open: boolean)
	self.Gui.Enabled = open
	if open then
		self:_refresh()
		local viewport = workspace.CurrentCamera.ViewportSize
		self.Scale.Scale = if self.TouchLayout then math.clamp(viewport.Y / 560, 0.6, 1) else math.clamp(viewport.Y / 1080, 0.6, 1.2)
		-- Sélection seulement à la manette : à la souris, le cadre gênerait.
		local last = UserInputService:GetLastInputType()
		if not self.TouchLayout and last.Name:sub(1, 7) == "Gamepad" then
			GuiService.SelectedObject = self.FirstButton
		end
	else
		-- Les essais non sauvegardés s'arrêtent là : l'aperçu reprend la livrée.
		self.Draft = nil
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Gui) then
			GuiService.SelectedObject = nil
		end
	end
end

-- Progression mise à jour (niveau gagné pendant qu'on est au garage).
function Garage:Refresh()
	if self.Gui.Enabled then
		self:_refresh()
	end
end

-- Copie inerte du gabarit, posée sur la plaque tournante.
function Garage:_buildShowroom(): Model?
	local template = ReplicatedStorage:FindFirstChild("CarTemplate")
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.Name = "ShowroomCar"
	for _, item in ipairs(model:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(item)) do
			CollectionService:RemoveTag(item, tag)
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
		elseif item:IsA("ParticleEmitter") or item:IsA("Sound") or item:IsA("LuaSourceContainer")
			or item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			item:Destroy()
		end
	end
	-- Posée sur la plaque : le bas de la voiture au ras du dessus de la plaque.
	local boxFrame, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomOffset = pivot.Position.Y - (boxFrame.Position.Y - size.Y / 2)
	local top = PaddockLayout.SHOWROOM + Vector3.new(0, 0.6, 0)
	self.ShowroomBase = CFrame.new(top + Vector3.new(0, bottomOffset, 0)) * pivot.Rotation
	model:PivotTo(self.ShowroomBase :: CFrame)
	model.Parent = workspace

	-- Emplacements des numéros et tracés des bandes, tant que les rayons
	-- touchent encore la carrosserie ; puis l'aperçu devient inerte.
	LiveryPainter.Prepare(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanQuery = false
		end
	end
	return model
end

--[[
	position : celle du personnage (nil s'il n'en a pas). Ouvre le garage en
	entrant dans la zone, le ferme en en sortant.
]]
function Garage:Update(dt: number, position: Vector3?)
	local pad = PaddockLayout.GARAGE_PAD
	local inside = false
	if position then
		local dx, dz = position.X - pad.Position.X, position.Z - pad.Position.Z
		inside = dx * dx + dz * dz <= pad.Radius * pad.Radius and math.abs(position.Y - pad.Position.Y) < 12
	end
	if inside ~= self.Inside then
		self.Inside = inside
		self:SetOpen(inside)
	end

	-- Aperçu : construit dès que le gabarit est là, tourne en permanence.
	if not self.Showroom then
		self.Showroom = self:_buildShowroom()
		self.Shown = ""
		self.ShownClass = ""
	end
	local model: Model? = self.Showroom
	local base = self.ShowroomBase
	if model and base then
		self.Angle = (self.Angle + SPIN_SPEED * dt) % (math.pi * 2)
		model:PivotTo(CFrame.new(base.Position) * CFrame.Angles(0, self.Angle, 0) * base.Rotation)
		-- La voiture choisie : son kit (BodyKits.luau) et sa carrosserie, inertes comme le reste.
		local classId = self.Callbacks.GetCarClass()
		local carId = self.Callbacks.GetCarModel()
		local shownCar = classId .. "|" .. tostring(carId)
		if shownCar ~= self.ShownClass then
			self.ShownClass = shownCar
			self.Shown = "" -- même livrée, autre voiture : on repeint
			model:SetAttribute("CarClass", classId)
			model:SetAttribute("CarModel", carId)
			BodyKits.Apply(model, CarClasses.ForCar(classId, carId).Body)
			local kit = model:FindFirstChild("BodyKit")
			if kit then
				for _, item in ipairs(kit:GetDescendants()) do
					if item:IsA("WeldConstraint") then
						item:Destroy()
					elseif item:IsA("BasePart") then
						item.Anchored = true
					end
				end
			end
		end
		local livery = self:_shown()
		if livery then
			local key = Livery.Key(livery)
			if key ~= self.Shown then
				self.Shown = key
				LiveryPainter.Apply(model, livery)
				for _, item in ipairs(model:GetDescendants()) do
					if item:IsA("BasePart") then
						item.CanQuery = false
					end
				end
				if self.Gui.Enabled then
					self:_refresh()
				end
			end
		end
	end
end

return Garage
