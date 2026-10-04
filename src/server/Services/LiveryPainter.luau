--!strict
--[[
	LiveryPainter.luau
	Applique une livrée (couleur + numéro, Livery.luau) à une voiture en jeu.

	PEINTURE : la carrosserie n'est pas décrite pièce par pièce (elle vient de
	build-rig ou d'un modèle importé, de structure inconnue). On repère donc,
	une fois, sur le gabarit, la COULEUR DOMINANTE de la carrosserie -- celle qui
	couvre la plus grande surface, hors roues, vitres, phares, intérieur -- et
	toutes les pièces de cette couleur sont repeintes à la couleur du joueur.
	Limite : une MeshPart texturée (TextureID, SurfaceAppearance) garde sa
	texture, la couleur n'y change rien. Le numéro, lui, apparaît toujours.

	NUMÉROS : un rond blanc cerclé de la couleur du joueur, sur chaque flanc et
	sur le toit. Leurs emplacements sont trouvés par des rayons lancés vers la
	carrosserie (flancs à mi-hauteur, toit par-dessus) sur la première voiture
	posée dans le monde, puis réutilisés. Panneaux sans masse ni collision,
	soudés au châssis : la physique n'en voit rien.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Livery = require(ReplicatedStorage.Shared.Constants.Livery)

local LiveryPainter = {}

local PAINT_ATTRIBUTE = "LiveryPaint"
local PANEL_NAME = "LiveryNumber"
local SIDE_PANEL = 3.2
local ROOF_PANEL = 4.2

-- Mots qui désignent ce qui n'est pas de la carrosserie peinte. Comparaison mot
-- à mot ("Trim" n'est pas "rim").
local EXCLUDED_WORDS = {
	"tire", "tyre", "wheel", "rim", "spoke", "hub", "glass", "window", "windscreen",
	"windshield", "light", "lamp", "headlight", "taillight", "brake", "disc", "caliper",
	"seat", "interior", "exhaust", "driver", "number", "plate", "grille", "grill",
}

type Anchor = { Offset: CFrame, Size: number }

local anchors: { Anchor }? = nil

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

-- Emplacements des numéros, relatifs au châssis, trouvés sur une voiture posée dans le monde.
local function computeAnchors(car: Model, chassis: BasePart): { Anchor }
	local found: { Anchor } = {}
	local include: { Instance } = {}
	for _, item in ipairs(car:GetDescendants()) do
		if item:IsA("BasePart") and item.CanQuery and item.Name ~= PANEL_NAME and not isExcluded(item, car) then
			table.insert(include, item)
		end
	end
	if #include == 0 then
		return found
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include

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
	for _, side in ipairs({ -1, 1 }) do
		local outward = frame.RightVector * side
		cast(frame.Position + outward * reach, -outward * reach, SIDE_PANEL)
	end
	cast(frame.Position + frame.UpVector * reach, -frame.UpVector * reach, ROOF_PANEL)
	return found
end

local function makePanel(car: Model, chassis: BasePart, anchor: Anchor, number: number, color: Color3)
	local part = Instance.new("Part")
	part.Name = PANEL_NAME
	part.Size = Vector3.new(anchor.Size, anchor.Size, 0.05)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
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
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = color
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
	label.TextColor3 = Color3.new(0.06, 0.06, 0.08)
	label.Text = tostring(number)
	label.Parent = disc

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = car
end

-- Peinture et numéros. La voiture doit être dans le monde (rayons).
function LiveryPainter.Apply(car: Model, livery: Livery.Livery)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return
	end
	local color = Livery.ColorOf(livery)
	for _, item in ipairs(car:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute(PAINT_ATTRIBUTE) == true then
			item.Color = color
		elseif item.Name == PANEL_NAME then
			item:Destroy()
		end
	end
	car:SetAttribute("RaceNumber", livery.Number)
	car:SetAttribute("LiveryColor", color)

	if anchors == nil and car:IsDescendantOf(workspace) then
		local computed = computeAnchors(car, chassis)
		if #computed > 0 then
			anchors = computed
		end
	end
	for _, anchor in ipairs(anchors or {}) do
		makePanel(car, chassis, anchor, livery.Number, color)
	end
end

return LiveryPainter
