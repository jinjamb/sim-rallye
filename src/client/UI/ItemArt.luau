--!strict
--[[
	ItemArt.luau
	La vignette d'un objet (boutique, Rallye Pass, carrière) : on voit ce
	qu'on achète avant de l'acheter.

		Voiture      la vraie voiture, en 3D (ViewportFrame) : le gabarit du
		             jeu, la carrosserie de sa catégorie (BodyKits) et la
		             livrée du joueur (LiveryPainter), vue de trois quarts ;
		Fumée        un nuage dessiné, de sa couleur (et de sa seconde
		             couleur pour une fumée bicolore) ;
		Klaxon, son moteur, célébration
		             une grande icône et une onomatopée de manga (« TUUT ! »,
		             « VROOM ! ») ;
		Crédits, tirages (récompenses du Pass)
		             une pièce « CR », un cadeau.

	Le fond prend la couleur de la rareté (bandes de vitesse, contour), comme
	une carte à collectionner.

	VOITURES : préparer une voiture (peindre sa livrée) demande des rayons
	contre la carrosserie, donc un modèle posé dans le monde. C'est fait une
	fois par catégorie et par livrée, loin au-dessus de la carte ; chaque
	vignette en reçoit ensuite une simple copie (le menu se reconstruit
	souvent).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Rarity = require(ReplicatedStorage.Shared.Economy.Rarity)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local BodyKits = require(ReplicatedStorage.Shared.Vehicle.BodyKits)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local LiveryPainter = require(ReplicatedStorage.Shared.Cosmetics.LiveryPainter)
local CarBodies = require(ReplicatedStorage.Shared.Vehicle.CarBodies)
local Theme = require(script.Parent.Theme)

local ItemArt = {}

-- Ce qu'une vignette montre : un objet du catalogue, ou une récompense du
-- Pass (crédits, tirages).
export type Subject = { Item: string?, Credits: number?, Rolls: number? }

local PREPARE_AT = CFrame.new(0, 4000, 0) -- loin de tout : rien ne gêne les rayons
local CAMERA_ANGLE = math.rad(35) -- trois quarts avant
local CAMERA_PITCH = 18 -- degrés au-dessus de l'horizon

-- Icône et onomatopée par sorte (et par effet, pour les célébrations).
local KIND_ICONS: { [string]: { Icon: string, Sfx: string? } } = {
	Horn = { Icon = "📯", Sfx = "TUUT !" },
	Engine = { Icon = "⚙️", Sfx = "VROOM !" },
	Celebration = { Icon = "🎉" },
}
local EFFECT_ICONS: { [string]: string } = {
	Confetti = "🎉",
	Flares = "🔥",
	Fireworks = "🎆",
	Champagne = "🍾",
	Lightning = "⚡",
	Gold = "✨",
}

--------------------------------------------------------------------------------
-- Voitures en 3D
--------------------------------------------------------------------------------

local prepared: { [string]: Model } = {}

-- Copie inerte du gabarit : pas de scripts, de sons, de liaisons ni de tags.
local function inertCopy(template: Model): Model
	local model = template:Clone()
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
	return model
end

-- La voiture d'une catégorie, peinte de la livrée, prête à copier (nil : pas de gabarit).
local function preparedCar(classId: string, livery: Livery.Livery?): Model?
	local key = classId .. "|" .. (if livery then Livery.Key(livery) else "")
	local cached = prepared[key]
	if cached then
		return cached
	end
	local template = ReplicatedStorage:FindFirstChild("CarTemplate")
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = inertCopy(template)
	model:PivotTo(PREPARE_AT)
	model.Parent = workspace
	BodyKits.Apply(model, CarClasses.Get(classId).Body)
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
	if livery then
		LiveryPainter.Prepare(model)
		LiveryPainter.Apply(model, livery)
	end
	model.Parent = nil
	prepared[key] = model
	return model
end

local partArt: (Frame, Catalog.Item, number) -> ()

local function carViewport(parent: Frame, classId: string, livery: Livery.Livery?)
	local model = preparedCar(classId, livery)
	if not model then
		return false
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Car"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(150, 150, 165)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -1.4, -0.6)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local copy = model:Clone()
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	-- Cadrage : la voiture entière, de trois quarts avant, un peu en hauteur.
	local box, size = copy:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 0.92
	-- L'avant du châssis est en -Z : la caméra se place devant, de biais, un
	-- peu au-dessus.
	local front = CFrame.Angles(0, CAMERA_ANGLE, 0).LookVector
	local pitch = math.rad(CAMERA_PITCH)
	local eye = box.Position + (front * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)) * distance
	camera.CFrame = CFrame.lookAt(eye, box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return true
end

--------------------------------------------------------------------------------
-- Dessins
--------------------------------------------------------------------------------

local function label(parent: Instance, text: string, size: number, face: Font, color: Color3): TextLabel
	local text_ = Instance.new("TextLabel")
	text_.BackgroundTransparency = 1
	text_.Size = UDim2.fromScale(1, 1)
	text_.Text = text
	text_.TextSize = size
	text_.FontFace = face
	text_.TextColor3 = color
	text_.Parent = parent
	return text_
end

-- Grosse icône au centre ; onomatopée penchée en haut à droite.
local function iconArt(parent: Frame, icon: string, sfx: string?, sfxColor: Color3, size: number)
	local glyph = label(parent, icon, math.floor(size * 0.5), Theme.BODY_BOLD, Theme.TEXT)
	glyph.Position = UDim2.fromScale(0, 0.04)
	if sfx then
		local word = label(parent, sfx, math.floor(size * 0.2), Theme.SFX, sfxColor)
		word.AnchorPoint = Vector2.new(1, 0)
		word.Position = UDim2.new(1, -4, 0, 2)
		word.Size = UDim2.fromScale(0.9, 0.3)
		word.TextXAlignment = Enum.TextXAlignment.Right
		word.Rotation = -8
		Theme.TextInk(word, 2)
	end
end

-- Nuage de fumée : des bulles qui grossissent et passent d'une couleur à l'autre.
local PUFFS = {
	{ 0.22, 0.62, 0.30 },
	{ 0.40, 0.48, 0.38 },
	{ 0.60, 0.40, 0.44 },
	{ 0.78, 0.30, 0.36 },
	{ 0.50, 0.66, 0.30 },
}
local function smokeArt(parent: Frame, color: Color3, color2: Color3?)
	local second = color2 or color
	for index, puff in ipairs(PUFFS) do
		local bubble = Instance.new("Frame")
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.fromScale(puff[1], puff[2])
		bubble.Size = UDim2.fromScale(puff[3], puff[3])
		bubble.BorderSizePixel = 0
		bubble.BackgroundColor3 = color:Lerp(second, (index - 1) / (#PUFFS - 1))
		bubble.BackgroundTransparency = 0.05
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = bubble
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bubble
		-- Contour encré : la fumée blanche reste lisible sur fond clair.
		Theme.Ink(bubble, Theme.INK, 2, 0.2)
		bubble.Parent = parent
	end
	-- Le pneu, en bas à gauche, d'où sort la fumée.
	local tire = Instance.new("Frame")
	tire.AnchorPoint = Vector2.new(0.5, 0.5)
	tire.Position = UDim2.fromScale(0.16, 0.8)
	tire.Size = UDim2.fromScale(0.26, 0.26)
	tire.BorderSizePixel = 0
	tire.BackgroundColor3 = Theme.INK
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = tire
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = tire
	Theme.Ink(tire, Theme.DIM, 3, 0)
	tire.Parent = parent
end

-- Pièce « CR » (crédits) avec le montant dessous.
local function coinArt(parent: Frame, amount: number, size: number)
	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromScale(0.5, 0.42)
	coin.Size = UDim2.fromScale(0.5, 0.5)
	coin.BorderSizePixel = 0
	coin.BackgroundColor3 = Theme.YELLOW
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = coin
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = coin
	Theme.Ink(coin, Theme.INK, 3, 0)
	label(coin, "CR", math.floor(size * 0.18), Theme.HEADLINE, Theme.INK)
	coin.Parent = parent
	local value = label(parent, "+" .. Credits.Format(amount), math.floor(size * 0.15), Theme.HEADLINE, Theme.TEXT)
	value.AnchorPoint = Vector2.new(0, 1)
	value.Position = UDim2.fromScale(0, 1)
	value.Size = UDim2.fromScale(1, 0.26)
	Theme.TextInk(value, 2)
end

-- Modèle du jeu qui représente chaque catégorie (CarBodies.LIST) sur les vignettes.
local CLASS_BODIES: { [string]: number } = {
	Rally4 = 6, -- Hoshi
	Rally2 = 5, -- Hayate, berline de rallye
	WRC = 2, -- Kaze, citadine WRC
	GroupB = 4, -- Raijin, coupé des années 80
}

-- Icône d'une pièce de carrosserie, selon son emplacement.
local PART_ICONS: { [string]: string } = {
	Wing = "✈️",
	Bumper = "🛡️",
	Hood = "💡",
	Flares = "📐",
}

-- Une pièce : les jantes en couleur (un cercle et ses branches), une icône sinon.
function partArt(parent: Frame, item: Catalog.Item, size: number)
	if item.Slot == "Rims" then
		local colors = CarBodies.RimColors(item.Option or 1)
		local rim = Instance.new("Frame")
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.fromScale(0.5, 0.5)
		rim.Size = UDim2.fromScale(0.62, 0.62)
		rim.BackgroundColor3 = colors.Spoke
		rim.BorderSizePixel = 0
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = rim
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = rim
		local ring = Instance.new("UIStroke")
		ring.Color = colors.Rim
		ring.Thickness = math.max(4, size * 0.08)
		ring.Parent = rim
		rim.Parent = parent
		for angle = 0, 288, 72 do
			local spoke = Instance.new("Frame")
			spoke.AnchorPoint = Vector2.new(0.5, 0.5)
			spoke.Position = UDim2.fromScale(0.5, 0.5)
			spoke.Size = UDim2.fromScale(0.16, 1)
			spoke.BackgroundColor3 = colors.Rim
			spoke.BorderSizePixel = 0
			spoke.Rotation = angle
			spoke.Parent = rim
		end
		return
	end
	iconArt(parent, PART_ICONS[item.Slot or ""] or "🔧", "NEW !", Theme.YELLOW, size)
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- Couleur de la carte : rareté de l'objet ; jaune pour les crédits, rose pour un tirage.
function ItemArt.Color(subject: Subject): Color3
	if subject.Item then
		local item = Catalog.Get(subject.Item)
		return if item then Rarity.Get(item.Rarity).Color else Theme.DIM
	end
	return if subject.Rolls then Theme.ACCENT else Theme.YELLOW
end

--[[
	Vignette de `width` x `height` pixels (de référence ; carrée sans
	`height`), dans `parent`. `livery` : celle du joueur, pour peindre les
	voitures.
]]
function ItemArt.New(parent: Instance, subject: Subject, width: number, livery: Livery.Livery?, height: number?): Frame
	local tone = ItemArt.Color(subject)
	local size = math.min(width, height or width) -- échelle des icônes et des textes
	local card = Instance.new("Frame")
	card.Name = "ItemArt"
	card.Size = UDim2.fromOffset(width, height or width)
	card.BackgroundColor3 = Theme.PANEL_2
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	Theme.Corner(card)
	Theme.Ink(card, tone, 2, 0)
	-- Fond de carte à collectionner : bandes de vitesse de la couleur de la rareté.
	local stripes = Theme.Stripes(card, tone, 4, 0.75)
	stripes.Size = UDim2.fromScale(1.3, 1)
	stripes.Position = UDim2.fromScale(-0.15, 0)

	local item = if subject.Item then Catalog.Get(subject.Item) else nil
	if item then
		if item.Kind == "Car" then
			-- Une voiture du catalogue est une CATÉGORIE : on la montre avec un
			-- modèle du jeu qui lui est propre (CLASS_BODIES), aux couleurs du
			-- joueur -- jamais avec la carrosserie importée du gabarit.
			local classId = item.CarClass or CarClasses.DEFAULT
			local shown = table.clone(livery or Livery.Default(0))
			shown.Body = CLASS_BODIES[classId] or 2
			if not carViewport(card, classId, shown) then
				iconArt(card, "🏎️", nil, tone, size)
			end
		elseif item.Kind == "Part" then
			partArt(card, item, size)
		elseif item.Kind == "Smoke" then
			smokeArt(card, item.Color or Theme.TEXT, item.Color2)
		elseif item.Kind == "Celebration" then
			iconArt(card, EFFECT_ICONS[item.Effect or ""] or KIND_ICONS.Celebration.Icon, nil, tone, size)
		else
			local icons = KIND_ICONS[item.Kind]
			iconArt(card, if icons then icons.Icon else "❔", if icons then icons.Sfx else nil, tone, size)
		end
	elseif subject.Rolls then
		iconArt(card, "🎁", if subject.Rolls > 1 then "×" .. subject.Rolls else nil, tone, size)
	else
		coinArt(card, subject.Credits or 0, size)
	end
	card.Parent = parent
	return card
end

--[[
	Sa voiture telle qu'elle roulera (modèle, pièces, livrée), en grand :
	l'aperçu de l'inventaire.
]]
function ItemArt.Car(parent: Instance, classId: string, livery: Livery.Livery, width: number, height: number): Frame
	local card = Instance.new("Frame")
	card.Name = "CarPreview"
	card.Size = UDim2.fromOffset(width, height)
	card.BackgroundColor3 = Theme.PANEL_2
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	Theme.Corner(card)
	Theme.Ink(card, Theme.ACCENT, 2, 0)
	local stripes = Theme.Stripes(card, Theme.ACCENT, 4, 0.8)
	stripes.Size = UDim2.fromScale(1.2, 1)
	stripes.Position = UDim2.fromScale(-0.1, 0)
	local kana = Theme.Kana(card, "マイカー", math.floor(height * 0.35), 0.88)
	kana.Position = UDim2.fromOffset(-12, 0)
	if not carViewport(card, classId, livery) then
		iconArt(card, "🏎️", nil, Theme.ACCENT, math.min(width, height))
	end
	card.Parent = parent
	return card
end

return ItemArt
