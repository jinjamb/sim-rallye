--!strict
--[[
	LiveryPainter.luau
	Applique une livrée (Livery.luau : couleur, numéro, bandes, style du
	numéro) à une voiture. Partagé : le serveur peint les voitures en jeu
	(CarService), le client l'aperçu du garage (Garage.luau), à l'identique.

	PEINTURE : la carrosserie n'est pas décrite pièce par pièce (elle vient de
	build-rig ou d'un modèle importé, de structure inconnue). On repère donc,
	une fois, sur le gabarit, la COULEUR DOMINANTE de la carrosserie -- celle qui
	couvre la plus grande surface, hors roues, vitres, phares, intérieur -- et
	toutes les pièces de cette couleur sont repeintes à la couleur du joueur.
	Limite : une MeshPart texturée (TextureID, SurfaceAppearance) garde sa
	texture, la couleur n'y change rien. Le numéro, lui, apparaît toujours.

	NUMÉROS : un rond blanc cerclé de la couleur du joueur, sur chaque flanc
	(pas sur le toit). Leurs emplacements sont trouvés par des rayons lancés
	vers la carrosserie, à mi-hauteur des flancs, sur la première voiture
	posée dans le monde, puis réutilisés. Panneaux sans masse ni collision,
	soudés au châssis : la physique n'en voit rien. Le style du numéro
	(Livery.PLATES) change le fond, le chiffre et le cercle.

	BANDES DE COURSE : posées de la même façon. Pour chaque bande, des rayons
	tombent sur la carrosserie tous les STRIPE_STEP studs, de l'avant à
	l'arrière ; deux points voisins à peu près à la même hauteur sont reliés
	par une fine plaque (capot, toit, coffre). Pare-brise et lunette, exclus
	des rayons, coupent la bande comme sur une vraie voiture. Les tracés sont
	calculés une fois par bande, comme les numéros, puis réutilisés.

	MODÈLES (CarBodies.luau) : Apply pose d'abord le modèle et les pièces
	choisis dans la livrée. Numéros et bandes dépendent de la forme : leurs
	emplacements sont gardés PAR FORME (CarBodies.ShapeKey).

	PEINTURE PAR PIÈCE : une pièce d'un modèle du jeu porte sa zone (attribut
	PaintZone) ; si la livrée donne une couleur à cette zone (Livery.Paints),
	la pièce la prend, sinon elle garde sa peinture d'origine (la couleur de
	la livrée, ou BaseColor pour les garnitures).

	SPONSORS (Livery.SPONSORS) : un autocollant dessiné en texte (pas
	d'image) sur le capot, sur chaque portière devant le numéro, et sur le
	toit. Emplacements trouvés par des rayons, comme les numéros, et gardés
	par forme. Le texte du capot et du toit se lit depuis la caméra de
	poursuite (le haut du texte vers l'avant de la voiture).

	MOTIF : une image répétée (Texture) sur les faces visibles (pas le
	dessous) de chaque pièce peinte dans la couleur principale, teintée dans
	la couleur du motif. Rien tant que l'image du motif n'est pas importée
	(Livery.PATTERNS : Image = 0).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local CarBodies = require(ReplicatedStorage.Shared.Vehicle.CarBodies)
local CarModels = require(ReplicatedStorage.Shared.Vehicle.CarModels)

local LiveryPainter = {}

local PAINT_ATTRIBUTE = "LiveryPaint"
local PANEL_NAME = "LiveryNumber"
local STRIPE_NAME = "LiveryStripe"
local SPONSOR_NAME = "LiverySponsor"
-- Sponsors : taille (largeur, hauteur en studs) et position par emplacement.
local SPONSOR_SIZES: { [string]: Vector2 } = {
	SponsorHood = Vector2.new(2.6, 0.8),
	SponsorDoors = Vector2.new(1.5, 0.55),
	SponsorRoof = Vector2.new(3.2, 1.0),
}
local DOOR_SPONSOR_Z = -1.85 -- devant le numéro de portière
local ROOF_SPONSOR_Z = 1.0
local DEFAULT_HOOD_Z = -4.6
local SPONSOR_LIFT = 0.07 -- au-dessus de la peinture et des bandes
local PATTERN_NAME = "LiveryPattern"
local ZONE_ATTRIBUTE = "PaintZone"
local BASE_COLOR_ATTRIBUTE = "BaseColor"
-- Faces qui reçoivent le motif : tout sauf le dessous, qu'on ne voit pas.
local PATTERN_FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local SIDE_PANEL = 3.2
local STRIPE_STEP = 0.8 -- studs entre deux points d'une bande
local STRIPE_LIFT = 0.035 -- au-dessus de la peinture (sous les numéros, à 0.06)
local STRIPE_THICKNESS = 0.03
local STRIPE_MAX_STEP = 0.9 -- écart de hauteur au-delà duquel la bande s'interrompt
local STRIPE_TOP_BAND = 2.6 -- sous le point le plus haut, on n'est plus sur le dessus
local STRIPE_MIN_UP = 0.35 -- surface tournée vers le haut (pas les flancs)

-- Mots qui désignent ce qui n'est pas de la carrosserie peinte. Comparaison mot
-- à mot ("Trim" n'est pas "rim").
local EXCLUDED_WORDS = {
	"tire", "tyre", "wheel", "rim", "spoke", "hub", "glass", "window", "windscreen",
	"windshield", "light", "lamp", "headlight", "taillight", "brake", "disc", "caliper",
	"seat", "interior", "exhaust", "driver", "number", "plate", "grille", "grill",
}

type Anchor = { Offset: CFrame, Size: number }
-- Un emplacement de sponsor : où, et dans quel sens (le haut du texte).
type SponsorAnchor = { Offset: CFrame, Size: Vector2 }
-- Un point d'une bande, dans le repère du châssis (Hit false : rien touché).
type StripePoint = { Hit: boolean, Point: Vector3, Normal: Vector3 }
local MISS: StripePoint = { Hit = false, Point = Vector3.zero, Normal = Vector3.yAxis }

-- Par forme de carrosserie (CarBodies.ShapeKey, attribut « DesignKey » de la voiture).
local anchorsByShape: { [string]: { Anchor } } = {}
local sponsorsByShape: { [string]: { [string]: { SponsorAnchor } } } = {} -- puis par emplacement
local stripesByShape: { [string]: { [number]: { StripePoint } } } = {} -- puis par décalage latéral

local function shapeOf(car: Model): string
	local key = car:GetAttribute("DesignKey")
	return if type(key) == "string" then key else "origine"
end

local function nameWords(name: string): { [string]: boolean }
	local spaced = string.gsub(name, "(%l)(%u)", "%1 %2")
	local words = {}
	for word in string.gmatch(string.lower(spaced), "%a+") do
		words[word] = true
		-- Pluriels simples : "Wheels" -> "wheel".
		if string.sub(word, -1) == "s" then
			words[string.sub(word, 1, -2)] = true
		end
	end
	return words
end

-- Le nom de la pièce et ceux de ses parents jusqu'à la voiture (un modèle
-- "WheelFL" contient des "Part" anonymes).
local function isExcluded(part: BasePart, root: Instance): boolean
	if part.Material == Enum.Material.Glass or part.Material == Enum.Material.Neon or part.Transparency >= 0.5 then
		return true
	end
	local current: Instance? = part
	while current and current ~= root do
		local words = nameWords(current.Name)
		for _, excluded in ipairs(EXCLUDED_WORDS) do
			if words[excluded] then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function colorKey(color: Color3): string
	return string.format("%d,%d,%d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function area(size: Vector3): number
	return 2 * (size.X * size.Y + size.Y * size.Z + size.X * size.Z)
end

-- Repère, sur le gabarit, les pièces de la couleur dominante de la carrosserie.
function LiveryPainter.PrepareTemplate(template: Model)
	local weights: { [string]: number } = {}
	local parts: { [string]: { BasePart } } = {}
	for _, item in ipairs(template:GetDescendants()) do
		if item:IsA("BasePart") and not isExcluded(item, template) then
			local key = colorKey(item.Color)
			weights[key] = (weights[key] or 0) + area(item.Size)
			local list = parts[key]
			if not list then
				list = {}
				parts[key] = list
			end
			table.insert(list, item)
		end
	end
	local bestKey, bestWeight = nil, 0
	for key, weight in pairs(weights) do
		if weight > bestWeight then
			bestKey, bestWeight = key, weight
		end
	end
	if not bestKey then
		warn("[Livrée] Aucune pièce de carrosserie trouvée : seuls les numéros seront posés.")
		return
	end
	local textured = 0
	for _, part in ipairs(parts[bestKey]) do
		part:SetAttribute(PAINT_ATTRIBUTE, true)
		if part:IsA("MeshPart") and part.TextureID ~= "" then
			textured += 1
		end
		if part:FindFirstChildOfClass("SurfaceAppearance") then
			textured += 1
		end
	end
	print(string.format(
		"[Livrée] %d pièces de carrosserie repeintes (couleur d'origine %s)%s",
		#parts[bestKey],
		bestKey,
		if textured > 0 then string.format(", dont %d texturées : la couleur n'y change rien", textured) else ""
	))
end

-- Rayons qui ne touchent que la carrosserie (ni roues, ni vitres, ni décors posés).
local function bodyRayParams(car: Model): RaycastParams?
	local include: { Instance } = {}
	for _, item in ipairs(car:GetDescendants()) do
		if item:IsA("BasePart") and item.CanQuery and item.Name ~= PANEL_NAME and item.Name ~= STRIPE_NAME and item.Name ~= SPONSOR_NAME
			and not isExcluded(item, car) then
			table.insert(include, item)
		end
	end
	if #include == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return params
end

-- Emplacements des numéros, relatifs au châssis, trouvés sur une voiture posée dans le monde.
local function computeAnchors(car: Model, chassis: BasePart): { Anchor }
	local found: { Anchor } = {}
	local params = bodyRayParams(car)
	if not params then
		return found
	end

	local boxFrame, size = car:GetBoundingBox()
	local frame = CFrame.new(boxFrame.Position) * chassis.CFrame.Rotation
	local reach = math.max(size.X, size.Y, size.Z) / 2 + 6

	local function cast(origin: Vector3, direction: Vector3, panelSize: number)
		local hit = workspace:Raycast(origin, direction, params)
		if hit then
			local position = hit.Position + hit.Normal * 0.06
			local world = CFrame.lookAt(position, position + hit.Normal)
			table.insert(found, { Offset = chassis.CFrame:ToObjectSpace(world), Size = panelSize })
		end
	end
	-- Modèle construit par le jeu (CarBodies) : le numéro se pose sur la
	-- porte, à la hauteur et à la taille qu'il indique ; sinon à mi-hauteur.
	local flankY = car:GetAttribute("FlankY")
	local flankSize = car:GetAttribute("FlankPanel")
	local flankCenter = if type(flankY) == "number"
		then chassis.CFrame:PointToWorldSpace(Vector3.new(0, flankY, 0))
		else frame.Position
	local sideSize = if type(flankSize) == "number" then flankSize else SIDE_PANEL
	for _, side in ipairs({ -1, 1 }) do
		local outward = frame.RightVector * side
		cast(flankCenter + outward * reach, -outward * reach, sideSize)
	end
	return found
end

-- Tracé d'une bande (axe à `x` studs du centre) : un point tous les STRIPE_STEP.
local function computeStripe(car: Model, chassis: BasePart, x: number): { StripePoint }
	local points: { StripePoint } = {}
	local params = bodyRayParams(car)
	if not params then
		return points
	end
	local boxFrame, size = car:GetBoundingBox()
	local frame = CFrame.new(boxFrame.Position) * chassis.CFrame.Rotation
	local drop = size.Y + 6
	local half = size.Z / 2 - 0.3
	local highest = -math.huge
	local z = -half
	while z <= half do
		local origin = frame:PointToWorldSpace(Vector3.new(x, size.Y / 2 + 3, z))
		local hit = workspace:Raycast(origin, -frame.UpVector * drop, params)
		local point = MISS
		if hit then
			local normal = chassis.CFrame:VectorToObjectSpace(hit.Normal)
			if normal.Y >= STRIPE_MIN_UP then
				point = { Hit = true, Point = chassis.CFrame:PointToObjectSpace(hit.Position), Normal = normal }
				highest = math.max(highest, point.Point.Y)
			end
		end
		table.insert(points, point)
		z += STRIPE_STEP
	end
	-- Plancher entrevu sous le pare-brise : trop bas pour être le dessus.
	for i, point in ipairs(points) do
		if point.Hit and point.Point.Y < highest - STRIPE_TOP_BAND then
			points[i] = MISS
		end
	end
	return points
end

local function stripeOf(car: Model, chassis: BasePart, x: number): { StripePoint }?
	local shape = shapeOf(car)
	local stripePaths = stripesByShape[shape]
	if not stripePaths then
		stripePaths = {}
		stripesByShape[shape] = stripePaths
	end
	local cached = stripePaths[x]
	if cached then
		return cached
	end
	if not car:IsDescendantOf(workspace) then
		return nil
	end
	local computed = computeStripe(car, chassis, x)
	if #computed > 0 then
		stripePaths[x] = computed
	end
	return computed
end

-- Une bande : des plaques fines reliant les points voisins à la même hauteur.
local function makeStripe(car: Model, chassis: BasePart, path: { StripePoint }, width: number, color: Color3)
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		if a.Hit and b.Hit and math.abs(a.Point.Y - b.Point.Y) <= STRIPE_MAX_STEP then
			local up = (a.Normal + b.Normal).Unit
			local from = a.Point + a.Normal * STRIPE_LIFT
			local to = b.Point + b.Normal * STRIPE_LIFT
			local length = (to - from).Magnitude
			if length > 1e-3 then
				local part = Instance.new("Part")
				part.Name = STRIPE_NAME
				part.Size = Vector3.new(width, STRIPE_THICKNESS, length + 0.1) -- léger recouvrement
				part.Color = color
				part.Material = Enum.Material.SmoothPlastic
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Massless = true
				part.Anchored = chassis.Anchored
				part.CFrame = chassis.CFrame * CFrame.lookAt((from + to) / 2, to, up)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = chassis
				weld.Part1 = part
				weld.Parent = part
				part.Parent = car
			end
		end
	end
end

local function makePanel(car: Model, chassis: BasePart, anchor: Anchor, number: number, color: Color3, plate: Livery.PlateStyle)
	local part = Instance.new("Part")
	part.Name = PANEL_NAME
	part.Size = Vector3.new(anchor.Size, anchor.Size, 0.05)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = chassis.Anchored
	part.CFrame = chassis.CFrame * anchor.Offset

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0.6
	gui.Parent = part
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.86, 0.86)
	disc.BackgroundColor3 = plate.Disc
	disc.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = if plate.GoldRing then Color3.fromRGB(190, 145, 30) else color
	ring.Thickness = 14
	ring.Parent = disc
	disc.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.52)
	label.Size = UDim2.fromScale(0.8, 0.7)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = plate.Text
	label.Text = tostring(number)
	label.Parent = disc

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = car
end

-- Emplacements des sponsors, relatifs au châssis : capot, portières, toit.
local function computeSponsorAnchors(car: Model, chassis: BasePart): { [string]: { SponsorAnchor } }
	local found: { [string]: { SponsorAnchor } } = { SponsorHood = {}, SponsorDoors = {}, SponsorRoof = {} }
	local params = bodyRayParams(car)
	if not params then
		return found
	end
	local _, size = car:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) / 2 + 6
	local base = chassis.CFrame
	-- Un rayon dans le repère du châssis ; `up` : le haut du texte (repère du châssis).
	local function cast(slot: string, origin: Vector3, direction: Vector3, up: Vector3)
		local hit = workspace:Raycast(base:PointToWorldSpace(origin), base:VectorToWorldSpace(direction), params)
		if not hit then
			return
		end
		local position = base:PointToObjectSpace(hit.Position)
		local normal = base:VectorToObjectSpace(hit.Normal)
		local lifted = position + normal * SPONSOR_LIFT
		table.insert(found[slot], { Offset = CFrame.lookAt(lifted, lifted + normal, up), Size = SPONSOR_SIZES[slot] })
	end
	local forward = Vector3.new(0, 0, -1) -- l'avant du châssis
	local hoodZ = car:GetAttribute("HoodZ")
	cast("SponsorHood", Vector3.new(0, reach, if type(hoodZ) == "number" then hoodZ else DEFAULT_HOOD_Z), Vector3.new(0, -2 * reach, 0), forward)
	cast("SponsorRoof", Vector3.new(0, reach, ROOF_SPONSOR_Z), Vector3.new(0, -2 * reach, 0), forward)
	local flankY = car:GetAttribute("FlankY")
	local y = if type(flankY) == "number" then flankY else 0
	for _, side in ipairs({ -1, 1 }) do
		cast("SponsorDoors", Vector3.new(side * reach, y, DOOR_SPONSOR_Z), Vector3.new(-side * 2 * reach, 0, 0), Vector3.yAxis)
	end
	-- Le toit doit être le dessus de la voiture (pas un capot plongeant sous un aileron).
	local roof = found.SponsorRoof[1]
	local hood = found.SponsorHood[1]
	if roof and hood and roof.Offset.Position.Y < hood.Offset.Position.Y + 0.5 then
		found.SponsorRoof = {}
	end
	return found
end

-- Un autocollant de sponsor (texte et fond), posé sur la carrosserie.
local function makeSponsor(car: Model, chassis: BasePart, anchor: SponsorAnchor, sponsor: Livery.SponsorStyle, text: string, background: Color3?)
	local part = Instance.new("Part")
	part.Name = SPONSOR_NAME
	part.Size = Vector3.new(anchor.Size.X, anchor.Size.Y, 0.05)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = chassis.Anchored
	part.CFrame = chassis.CFrame * anchor.Offset

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(anchor.Size.X, anchor.Size.Y) * 100
	gui.LightInfluence = 0.6
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = background or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = if background then 0 else 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = frame
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.78)
	label.Font = sponsor.Font
	label.TextScaled = true
	label.TextColor3 = sponsor.Ink
	label.Text = text
	if not background then
		-- Sans fond : le texte cerné, lisible sur n'importe quelle couleur.
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(16, 16, 20)
		stroke.Thickness = 3
		stroke.Parent = label
	end
	label.Parent = frame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = car
end

--[[
	Calcule d'avance les emplacements des numéros et le tracé de toutes les
	bandes, sur une voiture posée dans le monde et dont les pièces répondent
	encore aux rayons (CanQuery). Pour l'aperçu du garage, dont les pièces sont
	ensuite rendues inertes. En jeu, Apply le fait de lui-même.
]]
function LiveryPainter.Prepare(car: Model)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") or not car:IsDescendantOf(workspace) then
		return
	end
	local shape = shapeOf(car)
	if anchorsByShape[shape] == nil then
		local computed = computeAnchors(car, chassis)
		if #computed > 0 then
			anchorsByShape[shape] = computed
		end
	end
	for _, style in ipairs(Livery.STRIPES) do
		for _, lane in ipairs(style.Lanes) do
			stripeOf(car, chassis, lane.X)
		end
	end
	if sponsorsByShape[shape] == nil then
		sponsorsByShape[shape] = computeSponsorAnchors(car, chassis)
	end
end

-- Le motif sur une pièce : une image répétée par face visible.
local function addPattern(part: BasePart, style: Livery.PatternStyle, color: Color3)
	for _, face in ipairs(PATTERN_FACES) do
		local texture = Instance.new("Texture")
		texture.Name = PATTERN_NAME
		texture.Texture = "rbxassetid://" .. tostring(style.Image)
		texture.Face = face
		texture.StudsPerTileU = style.Tile
		texture.StudsPerTileV = style.Tile
		texture.Color3 = color
		texture.Transparency = style.Transparency
		texture.Parent = part
	end
end

-- La carrosserie de la voiture (attributs CarModel, sinon CarClass : sa voiture de référence).
local function designOf(car: Model): CarModels.Design?
	local model = CarModels.Get(car:GetAttribute("CarModel"))
	if not model then
		local classId = car:GetAttribute("CarClass")
		model = if type(classId) == "string" then CarModels.Reference(classId) else nil
	end
	return if model then model.Design else nil
end

-- Peinture, bandes et numéros. La voiture doit être dans le monde (rayons).
function LiveryPainter.Apply(car: Model, wanted: Livery.Livery)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return
	end
	-- « La carrosserie de la voiture » (Body = 0) : celle de sa fiche.
	local livery = Livery.WithDesign(wanted, designOf(car))
	local color = Livery.ColorOf(livery)
	-- Le modèle et ses pièces d'abord : la peinture et les numéros se posent dessus.
	CarBodies.Apply(car, livery, color)
	-- Aucun motif, ou image pas encore importée : rien à poser.
	local style = Livery.PATTERNS[livery.Pattern or 1]
	local pattern: Livery.PatternStyle? = if style and style.Image ~= 0 then style else nil
	local patternColor = Livery.PatternColorOf(livery)
	for _, item in ipairs(car:GetDescendants()) do
		if item.Name == PANEL_NAME or item.Name == STRIPE_NAME or item.Name == PATTERN_NAME or item.Name == SPONSOR_NAME then
			item:Destroy()
		elseif item:IsA("BasePart") then
			-- Une zone peinte à part prend sa couleur (et reste unie) ; sinon, la peinture d'origine.
			local zone = item:GetAttribute(ZONE_ATTRIBUTE)
			local zoneColor = if type(zone) == "string" then Livery.ZoneColorOf(livery, zone) else nil
			local painted = item:GetAttribute(PAINT_ATTRIBUTE) == true
			if zoneColor then
				item.Color = zoneColor
			elseif painted then
				item.Color = color
			else
				local base = item:GetAttribute(BASE_COLOR_ATTRIBUTE)
				if typeof(base) == "Color3" then
					item.Color = base
				end
			end
			if pattern and painted and not zoneColor and item.Transparency < 1 then
				addPattern(item, pattern, patternColor)
			end
		end
	end
	car:SetAttribute("RaceNumber", livery.Number)
	car:SetAttribute("LiveryColor", color)

	local shape = shapeOf(car)
	if anchorsByShape[shape] == nil and car:IsDescendantOf(workspace) then
		local computed = computeAnchors(car, chassis)
		if #computed > 0 then
			anchorsByShape[shape] = computed
		end
	end
	-- Bandes, puis numéros par-dessus (les rayons des uns ignorent les autres).
	local style = Livery.STRIPES[livery.Stripes]
	if style then
		local stripeColor = Livery.StripeColorOf(livery)
		for _, lane in ipairs(style.Lanes) do
			local path = stripeOf(car, chassis, lane.X)
			if path then
				makeStripe(car, chassis, path, lane.Width, stripeColor)
			end
		end
	end
	local plate = Livery.PLATES[livery.Plate] or Livery.PLATES[1]
	for _, anchor in ipairs(anchorsByShape[shape] or {}) do
		makePanel(car, chassis, anchor, livery.Number, color, plate)
	end

	-- Sponsors : capot, portières, toit.
	if sponsorsByShape[shape] == nil and car:IsDescendantOf(workspace) then
		sponsorsByShape[shape] = computeSponsorAnchors(car, chassis)
	end
	local sponsorAnchors = sponsorsByShape[shape] or {}
	for _, slot in ipairs(Livery.SPONSOR_SLOTS) do
		local sponsor = Livery.SPONSORS[(livery :: any)[slot.Field] or 1]
		if sponsor and (livery :: any)[slot.Field] ~= 1 then
			local text = sponsor.Text
			local background = sponsor.Background
			if text == nil then
				-- Écurie : son sigle, à sa couleur.
				local tag = car:GetAttribute("TeamTag")
				local teamColor = car:GetAttribute("TeamColor")
				text = if type(tag) == "string" then tag else nil
				local swatch = if type(teamColor) == "number" then Livery.COLORS[teamColor] else nil
				background = if swatch then swatch.Color else background
			end
			if text and text ~= "" then
				for _, anchor in ipairs(sponsorAnchors[slot.Field] or {}) do
					makeSponsor(car, chassis, anchor, sponsor, text, background)
				end
			end
		end
	end
end

return LiveryPainter
