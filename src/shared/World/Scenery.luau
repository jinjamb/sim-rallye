--!strict
--[[
	Scenery.luau
	Le décor posé autour des pistes et du paddock, en pièces simples façon
	low-poly : arbres (feuillus, pins, cerisiers en fleur, buissons), tribunes
	et leur public, tentes d'équipe, camions d'assistance, drapeaux, piles de
	pneus, mâts d'éclairage ; et les COLLINES qui entourent les pistes.

	Partagé par :
		- PaddockService (serveur) : le paddock d'accueil ;
		- tools/build-circuit.luau et tools/build-stage.luau : le décor des
		  circuits et de la spéciale (les outils en chargent une copie).

	Tout est ancré, sans contact. Seuls les troncs, les tribunes et les camions
	sont solides : le reste ne gêne ni les piétons ni les voitures, et reste
	invisible pour les rayons de suspension (CanQuery = false).

	REPÈRE d'un objet orienté (tribune, tente, camion) : un CFrame posé AU SOL,
	au centre de l'objet ; sa face avant regarde vers LookVector (la piste,
	l'allée du paddock).
]]

local Scenery = {}

export type TreeKind = "Leafy" | "Pine" | "Sakura" | "Bush"

-- Palette : verts de prairie, rose sakura, et les couleurs vives de l'interface.
Scenery.SAKURA = Color3.fromRGB(255, 176, 204)
Scenery.TEAM_COLORS = {
	Color3.fromRGB(255, 70, 140), -- sakura vif
	Color3.fromRGB(70, 90, 220), -- indigo
	Color3.fromRGB(255, 205, 50), -- jaune
	Color3.fromRGB(40, 200, 230), -- cyan
	Color3.fromRGB(235, 70, 55), -- rouge
	Color3.fromRGB(60, 190, 110), -- vert
	Color3.fromRGB(245, 245, 250), -- blanc
}

local DARK = Color3.fromRGB(32, 33, 40)
local STEEL = Color3.fromRGB(120, 124, 134)
local CANVAS = Color3.fromRGB(236, 236, 240)

local function piece(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	solid: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid -- Roblox impose CanQuery = true sur une part solide
	part.CanTouch = false
	part.CastShadow = solid or size.Magnitude > 6
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean?): Part
	return piece(parent, name, Enum.PartType.Block, size, cframe, color, Enum.Material.SmoothPlastic, solid == true)
end

-- Un cylindre Roblox a son axe sur X : on le redresse.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function column(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, material: Enum.Material, solid: boolean): Part
	return piece(parent, name, Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT, color, material, solid)
end

local function ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, material: Enum.Material): Part
	return piece(parent, name, Enum.PartType.Ball, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, material, false)
end

-- Un texte sur une face d'une part (bandeaux, enseignes).
local function sign(part: Part, text: string, background: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(math.max(200, part.Size.X * 40), math.max(40, part.Size.Y * 40))
	gui.LightInfluence = 0.3
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.BorderSizePixel = 0
	label.TextColor3 = if background.R + background.G + background.B > 2 then DARK else Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

--------------------------------------------------------------------------------
-- Assets du Creator Store
--------------------------------------------------------------------------------

--[[
	BIBLIOTHÈQUE : ServerStorage.SceneryAssets, rangée dans le place (pas dans
	Rojo). Un dossier par sorte (Pine, Leafy, Bush, Rock, Logs, Fence,
	Mushroom), des modèles déjà nettoyés : ancrés, sans collision ni script,
	pivot au sol au centre, attribut Size (taille d'origine, longueur sur X).
	Réglés pour les performances (des milliers de copies) : CollisionFidelity
	Box (aucune géométrie de collision détaillée à calculer), ombres seulement
	pour les arbres (pas pour buissons, rochers, rondins, barrières,
	champignons). Ces réglages ne se font que dans Studio : les copies les
	héritent.
	Sans bibliothèque (côté client, ou place sans assets), chaque fonction
	retombe sur les formes simples plus bas.
]]
local libraryCache: Folder | false | nil = nil

local function library(): Folder?
	if libraryCache == nil then
		local ok, found = pcall(function()
			return game:GetService("ServerStorage"):FindFirstChild("SceneryAssets")
		end)
		libraryCache = if ok and found and found:IsA("Folder") then found else false
	end
	return if libraryCache then libraryCache else nil
end

function Scenery.HasAssets(): boolean
	return library() ~= nil
end

local function templateOf(kind: string, rng: Random): Model?
	local lib = library()
	local folder = lib and lib:FindFirstChild(kind)
	if not folder then
		return nil
	end
	local variants = folder:GetChildren()
	if #variants == 0 then
		return nil
	end
	local chosen = variants[rng:NextInteger(1, #variants)]
	return if chosen:IsA("Model") then chosen else nil
end

--[[
	Un asset de la sorte `kind` posé en `at` (un point au sol : tourné au
	hasard ; ou un CFrame : orientation imposée). `height` : hauteur visée ;
	sinon `scale` (1 par défaut). Rend le modèle, ou nil sans bibliothèque.
]]
function Scenery.Asset(parent: Instance, kind: string, at: Vector3 | CFrame, rng: Random, height: number?, scale: number?): Model?
	local template = templateOf(kind, rng)
	if not template then
		return nil
	end
	local model = template:Clone()
	local size = template:GetAttribute("Size")
	local factor = scale or 1
	if height and typeof(size) == "Vector3" and size.Y > 0 then
		factor = height / size.Y
	end
	if math.abs(factor - 1) > 0.01 then
		model:ScaleTo(factor)
	end
	local frame = if typeof(at) == "CFrame" then at else CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	model:PivotTo(frame)
	model.Parent = parent
	return model
end

-- Tronc invisible et solide sous un arbre en mesh (son feuillage ne l'est pas).
local function trunkCollider(parent: Instance, ground: Vector3, diameter: number)
	local collider = piece(parent, "TrunkCollider", Enum.PartType.Cylinder, Vector3.new(10, diameter, diameter), CFrame.new(ground + Vector3.new(0, 5, 0)) * UPRIGHT, DARK, Enum.Material.SmoothPlastic, true)
	collider.Transparency = 1
	collider.CastShadow = false
end

-- Les arbres en assets : pins hauts et sombres, feuillus plus ronds, buissons.
local function assetTree(parent: Instance, ground: Vector3, rng: Random, kind: TreeKind, s: number): boolean
	if kind == "Pine" then
		local model = Scenery.Asset(parent, "Pine", ground - Vector3.new(0, 0.5, 0), rng, rng:NextNumber(26, 44) * s)
		if model then
			trunkCollider(model, ground, 1.8 * s)
			return true
		end
	elseif kind == "Leafy" then
		local model = Scenery.Asset(parent, "Leafy", ground - Vector3.new(0, 0.5, 0), rng, rng:NextNumber(24, 34) * s)
		if model then
			trunkCollider(model, ground, 2.2 * s)
			return true
		end
	elseif kind == "Bush" then
		return Scenery.Asset(parent, "Bush", ground - Vector3.new(0, 0.3, 0), rng, rng:NextNumber(3.5, 6) * s) ~= nil
	end
	return false
end

-- Un rocher, à moitié enfoncé. `height` : sa hauteur hors sol.
function Scenery.Rock(parent: Instance, ground: Vector3, rng: Random, height: number)
	if Scenery.Asset(parent, "Rock", ground - Vector3.new(0, height * 0.35, 0), rng, height * 1.35) then
		return
	end
	local grey = rng:NextInteger(105, 135)
	piece(parent, "Rock", Enum.PartType.Ball, Vector3.new(height * 1.6, height * 1.6, height * 1.6), CFrame.new(ground + Vector3.new(0, height * 0.3, 0)), Color3.fromRGB(grey, grey - 4, grey - 10), Enum.Material.Slate, false)
end

-- Une pile de rondins (la coupe du bois en bord de spéciale).
function Scenery.Logs(parent: Instance, ground: Vector3, rng: Random)
	if Scenery.Asset(parent, "Logs", ground, rng, nil, rng:NextNumber(1, 1.4)) then
		return
	end
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	for row = 0, 2 do
		for i = 0, 2 - row do
			local offset = Vector3.new(0, 0.9 + row * 1.5, (i - (2 - row) / 2) * 1.8)
			piece(parent, "Log", Enum.PartType.Cylinder, Vector3.new(10, 1.8, 1.8), CFrame.new(ground) * yaw * CFrame.new(offset), Color3.fromRGB(140, 96, 62), Enum.Material.Wood, false)
		end
	end
end

-- Quelques champignons rouges au pied d'un arbre.
function Scenery.Mushrooms(parent: Instance, ground: Vector3, rng: Random)
	Scenery.Asset(parent, "Mushroom", ground - Vector3.new(0, 0.2, 0), rng, nil, rng:NextNumber(0.4, 0.8))
end

--[[
	Une barrière en bois de `from` à `to` (points au sol), en segments
	posés bout à bout. `groundAt(x, z)` : hauteur du sol (sinon celle de `from`).
]]
function Scenery.FenceLine(parent: Instance, from: Vector3, to: Vector3, rng: Random, groundAt: ((number, number) -> number?)?)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 1 then
		return
	end
	local direction = flat.Unit
	local template = templateOf("Fence", rng)
	local size = template and template:GetAttribute("Size")
	local segment = if typeof(size) == "Vector3" and size.X > 4 then size.X else 8
	local count = math.max(1, math.floor(length / segment + 0.5))
	local step = length / count
	for i = 0, count - 1 do
		local mid = from + direction * (step * (i + 0.5))
		local y = (groundAt and groundAt(mid.X, mid.Z)) or from.Y
		local base = Vector3.new(mid.X, y, mid.Z)
		-- Le segment a sa longueur sur X : on aligne X sur la direction.
		local frame = CFrame.lookAt(base, base + direction) * CFrame.Angles(0, math.pi / 2, 0)
		if template then
			local model = template:Clone()
			if math.abs(step / segment - 1) > 0.02 then
				model:ScaleTo(step / segment)
			end
			model:PivotTo(frame)
			model.Parent = parent
		else
			block(parent, "FencePost", Vector3.new(0.5, 3.5, 0.5), frame * CFrame.new(-step / 2, 1.75, 0), Color3.fromRGB(110, 78, 52), false)
			for _, h in ipairs({ 1.2, 2.6 }) do
				block(parent, "FenceRail", Vector3.new(step, 0.4, 0.25), frame * CFrame.new(0, h, 0), Color3.fromRGB(130, 92, 60), false)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Arbres
--------------------------------------------------------------------------------

local function green(rng: Random): Color3
	return Color3.fromRGB(rng:NextInteger(50, 78), rng:NextInteger(110, 145), rng:NextInteger(45, 70))
end

local function trunkColor(rng: Random): Color3
	return Color3.fromRGB(rng:NextInteger(88, 108), rng:NextInteger(62, 76), rng:NextInteger(46, 56))
end

-- Une sorte d'arbre au hasard ; `sakura` : part des cerisiers (0 à 1).
function Scenery.PickKind(rng: Random, sakura: number?): TreeKind
	local roll = rng:NextNumber()
	local share = sakura or 0.08
	-- Comme une forêt de montagne : surtout des pins, quelques feuillus et buissons.
	if roll < share then
		return "Sakura"
	elseif roll < share + 0.55 then
		return "Pine"
	elseif roll < share + 0.7 then
		return "Bush"
	end
	return "Leafy"
end

--[[
	Un arbre posé au sol en `ground`. `scale` agrandit ou réduit (1 par défaut).
	Le tronc est solide (une grosse sortie de route doit coûter) ; le feuillage
	ne l'est pas.
]]
function Scenery.Tree(parent: Instance, ground: Vector3, rng: Random, kind: TreeKind?, scale: number?)
	local k = kind or Scenery.PickKind(rng)
	local s = (scale or 1) * rng:NextNumber(0.85, 1.2)
	if assetTree(parent, ground, rng, k, s) then
		return
	end
	if k == "Bush" then
		local color = green(rng)
		local size = rng:NextNumber(4, 6.5) * s
		ball(parent, "Bush", size, ground + Vector3.new(0, size * 0.3, 0), color, Enum.Material.Grass)
		local second = size * rng:NextNumber(0.6, 0.8)
		ball(parent, "Bush", second, ground + Vector3.new(rng:NextNumber(-2, 2), second * 0.3, rng:NextNumber(-2, 2)), color, Enum.Material.Grass)
		return
	end
	if k == "Pine" then
		-- Pin : tronc court, étages de disques de plus en plus petits.
		local trunkHeight = 5 * s
		column(parent, "Trunk", trunkHeight + 1, 1.4 * s, ground - Vector3.new(0, 1, 0), trunkColor(rng), Enum.Material.Wood, true)
		local color = Color3.fromRGB(rng:NextInteger(30, 50), rng:NextInteger(88, 112), rng:NextInteger(55, 72))
		local y = trunkHeight - 1 * s
		local tiers = rng:NextInteger(3, 4)
		for tier = 1, tiers do
			local width = (11 - tier * 2.2) * s
			local height = 4.2 * s
			column(parent, "Leaves", height, width, ground + Vector3.new(0, y, 0), color, Enum.Material.Grass, false)
			y += height * 0.72
		end
		ball(parent, "Leaves", 2.4 * s, ground + Vector3.new(0, y + 0.6 * s, 0), color, Enum.Material.Grass)
		return
	end
	local isSakura = k == "Sakura"
	local trunkHeight = rng:NextNumber(9, 15) * s * (if isSakura then 0.75 else 1)
	local trunkWidth = rng:NextNumber(1.2, 2) * s
	column(parent, "Trunk", trunkHeight + 0.5, trunkWidth, ground - Vector3.new(0, 0.5, 0), if isSakura then Color3.fromRGB(78, 52, 48) else trunkColor(rng), Enum.Material.Wood, true)
	local top = ground + Vector3.new(0, trunkHeight, 0)
	local crown = rng:NextNumber(8, 11.5) * s * (if isSakura then 1.15 else 1)
	local color = if isSakura
		then Scenery.SAKURA:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25))
		else green(rng)
	local material = if isSakura then Enum.Material.SmoothPlastic else Enum.Material.Grass
	ball(parent, "Leaves", crown, top, color, material)
	-- Deux boules décalées : plus naturel qu'une sphère parfaite.
	for _ = 1, 2 do
		local second = crown * rng:NextNumber(0.55, 0.75)
		local shift = Vector3.new(rng:NextNumber(-0.35, 0.35) * crown, rng:NextNumber(0.05, 0.35) * crown, rng:NextNumber(-0.35, 0.35) * crown)
		ball(parent, "Leaves", second, top + shift, if isSakura then color:Lerp(Scenery.SAKURA, 0.5) else color, material)
	end
	if isSakura then
		-- Pétales tombés au pied de l'arbre.
		local carpet = crown * 1.1
		piece(parent, "Petals", Enum.PartType.Cylinder, Vector3.new(0.1, carpet, carpet), CFrame.new(ground + Vector3.new(0, 0.08, 0)) * UPRIGHT, Scenery.SAKURA, Enum.Material.SmoothPlastic, false)
	end
end

--------------------------------------------------------------------------------
-- Paddock et bord de piste
--------------------------------------------------------------------------------

--[[
	Tribune : gradins (rows rangées) le long de `length`, public coloré, toit
	sur poteaux, bandeau sur le devant du toit. `crowd` : part des places
	occupées (0 à 1). Solide : on ne traverse pas une tribune.
]]
function Scenery.Grandstand(parent: Instance, frame: CFrame, length: number, rows: number, rng: Random, banner: string?, crowd: number?)
	local model = Instance.new("Model")
	model.Name = "Grandstand"
	local rowDepth, rowRise = 3, 1.6
	local depth = rows * rowDepth
	-- Les gradins montent vers l'arrière (opposé à LookVector).
	for row = 1, rows do
		local height = row * rowRise
		local z = -depth / 2 + (row - 0.5) * rowDepth -- rangée 1 devant (-Z local)
		block(model, "Step", Vector3.new(length, height, rowDepth), frame * CFrame.new(0, height / 2, z), if row % 2 == 0 then Color3.fromRGB(200, 202, 210) else Color3.fromRGB(180, 182, 192), true)
		-- Sièges : un liseré coloré au bord de chaque rangée.
		block(model, "Seats", Vector3.new(length, 0.5, 0.8), frame * CFrame.new(0, height + 0.25, z - rowDepth / 2 + 0.6), Scenery.TEAM_COLORS[(row % 3) + 1], false)
		-- Le public : des silhouettes simples, de toutes les couleurs.
		local share = crowd or 0.6
		local x = -length / 2 + 1.2
		while x < length / 2 - 1 do
			if rng:NextNumber() < share then
				local tone = Scenery.TEAM_COLORS[rng:NextInteger(1, #Scenery.TEAM_COLORS)]
				local fan = frame * CFrame.new(x + rng:NextNumber(-0.3, 0.3), height + 1.3, z - 0.2)
				block(model, "Fan", Vector3.new(1.1, 1.6, 0.8), fan, tone, false)
				ball(model, "Head", 0.9, (fan * CFrame.new(0, 1.2, 0)).Position, Color3.fromRGB(rng:NextInteger(170, 240), rng:NextInteger(130, 200), rng:NextInteger(100, 170)), Enum.Material.SmoothPlastic)
			end
			x += 1.8
		end
	end
	-- Dos et côtés.
	local top = rows * rowRise
	block(model, "Back", Vector3.new(length, top + 4, 0.6), frame * CFrame.new(0, (top + 4) / 2, depth / 2 + 0.3), DARK, true)
	for _, side in ipairs({ -1, 1 }) do
		block(model, "Side", Vector3.new(0.6, top + 4, depth), frame * CFrame.new(side * (length / 2 + 0.3), (top + 4) / 2, 0), DARK, true)
	end
	-- Toit en pente, sur des poteaux à l'avant.
	local roofY = top + 7
	for x = -length / 2 + 1, length / 2 - 1, math.max(8, length / 6) do
		block(model, "Post", Vector3.new(0.6, roofY, 0.6), frame * CFrame.new(x, roofY / 2, -depth / 2 - 0.5), STEEL, false)
	end
	block(model, "Post", Vector3.new(0.6, roofY, 0.6), frame * CFrame.new(length / 2 - 1, roofY / 2, -depth / 2 - 0.5), STEEL, false)
	block(model, "Roof", Vector3.new(length + 2, 0.5, depth + 3), frame * CFrame.new(0, roofY, -0.5) * CFrame.Angles(math.rad(-6), 0, 0), CANVAS, false)
	local front = block(model, "Banner", Vector3.new(length + 2, 2.4, 0.4), frame * CFrame.new(0, roofY - 0.4, -depth / 2 - 2), Scenery.TEAM_COLORS[1], false)
	if banner then
		sign(front, banner, Scenery.TEAM_COLORS[1], Enum.NormalId.Front)
	end
	-- Barrière devant.
	block(model, "Fence", Vector3.new(length, 1.2, 0.3), frame * CFrame.new(0, 0.6, -depth / 2 - 1.2), STEEL, false)
	model.Parent = parent
end

--[[
	Tente d'équipe : toit à deux pans de la couleur de l'équipe, mâts, fond
	fermé avec le nom, un comptoir et des pneus de rechange devant.
]]
function Scenery.Tent(parent: Instance, frame: CFrame, width: number, depth: number, color: Color3, name: string?)
	local model = Instance.new("Model")
	model.Name = "Tent"
	local height = 8
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			block(model, "Pole", Vector3.new(0.4, height, 0.4), frame * CFrame.new(x * (width / 2 - 0.2), height / 2, z * (depth / 2 - 0.2)), STEEL, false)
		end
	end
	-- Deux pans (coins) qui se rejoignent au faîte.
	local rise = 2.2
	for _, side in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Size = Vector3.new(depth + 0.6, rise, width / 2 + 0.3)
		-- Une WedgePart est haute vers +Z local : tournée pour monter vers le faîte.
		wedge.CFrame = frame * CFrame.new(side * (width / 4 + 0.15), height + rise / 2, 0) * CFrame.Angles(0, -side * math.pi / 2, 0)
		wedge.Color = if side < 0 then color else color:Lerp(Color3.new(1, 1, 1), 0.25)
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Parent = model
	end
	local back = block(model, "Back", Vector3.new(width, height, 0.3), frame * CFrame.new(0, height / 2, depth / 2), color, false)
	if name then
		local plate = block(model, "Plate", Vector3.new(width * 0.7, 1.8, 0.2), frame * CFrame.new(0, height - 3.2, depth / 2 - 0.3), DARK, false)
		sign(plate, name, DARK, Enum.NormalId.Front)
	end
	block(model, "Valance", Vector3.new(width + 0.4, 1, 0.2), frame * CFrame.new(0, height - 0.5, -depth / 2), color, false)
	block(model, "Counter", Vector3.new(width * 0.5, 2.6, 1.6), frame * CFrame.new(-width * 0.18, 1.3, depth / 2 - 2), CANVAS, false)
	-- Pneus de rechange.
	for i = 0, 2 do
		piece(model, "Tire", Enum.PartType.Cylinder, Vector3.new(1, 2.6, 2.6), CFrame.new((frame * CFrame.new(width / 2 - 1.8, 0.5 + i * 1, depth / 2 - 2.2)).Position) * UPRIGHT, DARK, Enum.Material.SmoothPlastic, false)
	end
	model.Parent = parent
	return back
end

-- Camion d'assistance : remorque peinte, cabine, roues.
function Scenery.Truck(parent: Instance, frame: CFrame, color: Color3, name: string?)
	local model = Instance.new("Model")
	model.Name = "Truck"
	local trailer = block(model, "Trailer", Vector3.new(7, 8, 22), frame * CFrame.new(0, 5.5, 2), color, true)
	trailer.Material = Enum.Material.SmoothPlastic
	block(model, "Stripe", Vector3.new(7.05, 1, 22.05), frame * CFrame.new(0, 3, 2), DARK, false)
	if name then
		sign(trailer, name, color, Enum.NormalId.Left)
		sign(trailer, name, color, Enum.NormalId.Right)
	end
	block(model, "Cab", Vector3.new(7, 6.5, 6), frame * CFrame.new(0, 4.75, -12.2), CANVAS, true)
	block(model, "Windshield", Vector3.new(6.2, 2.4, 0.2), frame * CFrame.new(0, 6.3, -15.25), Color3.fromRGB(60, 80, 110), false)
	for _, z in ipairs({ -12, 6, 10 }) do
		for _, x in ipairs({ -1, 1 }) do
			piece(model, "Wheel", Enum.PartType.Cylinder, Vector3.new(1.2, 3, 3), frame * CFrame.new(x * 3.3, 1.5, z), DARK, Enum.Material.SmoothPlastic, false)
		end
	end
	model.Parent = parent
end

-- Drapeau de plage (oriflamme) : mât et voile verticale colorée.
function Scenery.Flag(parent: Instance, ground: Vector3, color: Color3, facing: Vector3?)
	local look = facing or Vector3.new(0, 0, -1)
	column(parent, "FlagPole", 12, 0.3, ground, STEEL, Enum.Material.Metal, false)
	local center = ground + Vector3.new(0, 8.2, 0)
	local sideways = Vector3.new(look.Z, 0, -look.X)
	block(parent, "Flag", Vector3.new(1.8, 7, 0.1), CFrame.lookAt(center + sideways * 1, center + sideways * 1 + look), color, false)
end

-- Pile de pneus, avec un pneu de couleur.
function Scenery.TireStack(parent: Instance, ground: Vector3, rng: Random, count: number?)
	local n = count or rng:NextInteger(2, 4)
	for i = 0, n - 1 do
		local tone = if i == n - 1 and rng:NextNumber() < 0.5 then Scenery.TEAM_COLORS[rng:NextInteger(1, 5)] else DARK
		piece(parent, "Tire", Enum.PartType.Cylinder, Vector3.new(1.1, 3.4, 3.4), CFrame.new(ground + Vector3.new(0, 0.55 + i * 1.1, 0)) * UPRIGHT, tone, Enum.Material.SmoothPlastic, false)
	end
end

-- Mât d'éclairage : un poteau et une rampe de projecteurs (allumés la nuit).
function Scenery.LightTower(parent: Instance, ground: Vector3, facing: Vector3)
	local height = 26
	column(parent, "LightPole", height, 0.8, ground, STEEL, Enum.Material.Metal, false)
	local head = ground + Vector3.new(0, height, 0)
	local lamp = block(parent, "LightHead", Vector3.new(5, 2.4, 0.8), CFrame.lookAt(head, head + facing), DARK, false)
	local face = block(parent, "LightFace", Vector3.new(4.6, 2, 0.1), lamp.CFrame * CFrame.new(0, 0, -0.45), Color3.fromRGB(255, 248, 225), false)
	face.Material = Enum.Material.Neon
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = 60
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Parent = face
end

--[[
	Bâtiment des stands : un long bloc, une porte de garage par équipe (cadre à
	sa couleur), une baie vitrée à l'étage, une enseigne sur le toit. Solide.
]]
function Scenery.PitBuilding(parent: Instance, frame: CFrame, length: number, banner: string?)
	local model = Instance.new("Model")
	model.Name = "PitBuilding"
	local height, depth = 13, 14
	block(model, "Body", Vector3.new(length, height, depth), frame * CFrame.new(0, height / 2, 0), Color3.fromRGB(214, 216, 224), true)
	-- Façade : -Z local (vers LookVector).
	local front = -depth / 2 - 0.1
	local doorWidth, doorHeight, pitch = 10, 8, 14
	local doors = math.max(1, math.floor(length / pitch))
	local first = -(doors - 1) * pitch / 2
	for i = 0, doors - 1 do
		local x = first + i * pitch
		local color = Scenery.TEAM_COLORS[(i % #Scenery.TEAM_COLORS) + 1]
		block(model, "Door", Vector3.new(doorWidth, doorHeight, 0.2), frame * CFrame.new(x, doorHeight / 2, front), Color3.fromRGB(46, 48, 58), false)
		block(model, "DoorFrame", Vector3.new(doorWidth + 1, 0.8, 0.3), frame * CFrame.new(x, doorHeight + 0.4, front - 0.05), color, false)
		for _, side in ipairs({ -1, 1 }) do
			block(model, "DoorFrame", Vector3.new(0.5, doorHeight, 0.3), frame * CFrame.new(x + side * (doorWidth / 2 + 0.25), doorHeight / 2, front - 0.05), color, false)
		end
	end
	local glass = block(model, "Windows", Vector3.new(length - 2, 2.2, 0.2), frame * CFrame.new(0, height - 2.6, front), Color3.fromRGB(70, 110, 160), false)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.2
	local roofSign = block(model, "RoofSign", Vector3.new(math.min(length * 0.6, 60), 4, 0.5), frame * CFrame.new(0, height + 2.5, front + 2), DARK, false)
	if banner then
		sign(roofSign, banner, DARK, Enum.NormalId.Front)
	end
	for _, side in ipairs({ -1, 1 }) do
		block(model, "SignPost", Vector3.new(0.5, 3, 0.5), frame * CFrame.new(side * roofSign.Size.X * 0.4, height + 0.5, front + 2.4), STEEL, false)
	end
	model.Parent = parent
end

-- Portique torii : deux piliers rouges, la traverse noire au sommet.
function Scenery.Torii(parent: Instance, frame: CFrame, span: number, height: number)
	local model = Instance.new("Model")
	model.Name = "Torii"
	local red = Color3.fromRGB(214, 40, 40)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Pillar", Enum.PartType.Cylinder, Vector3.new(height, 1.8, 1.8), frame * CFrame.new(side * span / 2, height / 2, 0) * UPRIGHT, red, Enum.Material.SmoothPlastic, true)
		block(model, "Foot", Vector3.new(2.4, 1.2, 2.4), frame * CFrame.new(side * span / 2, 0.6, 0), DARK, true)
	end
	block(model, "Nuki", Vector3.new(span + 3, 1.2, 1), frame * CFrame.new(0, height - 3.2, 0), red, false)
	block(model, "Kasagi", Vector3.new(span + 7, 1.4, 2.2), frame * CFrame.new(0, height + 0.7, 0), red, false)
	block(model, "KasagiTop", Vector3.new(span + 8, 0.6, 2.6), frame * CFrame.new(0, height + 1.7, 0), DARK, false)
	local plaque = block(model, "Plaque", Vector3.new(3, 2.4, 0.4), frame * CFrame.new(0, height - 1.3, 0), DARK, false)
	sign(plaque, "ラリー", DARK, Enum.NormalId.Front)
	sign(plaque, "ラリー", DARK, Enum.NormalId.Back)
	model.Parent = parent
end

-- Lanterne japonaise (tōrō) : socle, lumière, toit.
function Scenery.Lantern(parent: Instance, ground: Vector3)
	column(parent, "LanternBase", 3, 0.9, ground, Color3.fromRGB(150, 150, 156), Enum.Material.Slate, false)
	local box = block(parent, "LanternLight", Vector3.new(1.8, 1.6, 1.8), CFrame.new(ground + Vector3.new(0, 3.8, 0)), Color3.fromRGB(255, 214, 140), false)
	box.Material = Enum.Material.Neon
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 1.2
	glow.Color = Color3.fromRGB(255, 200, 130)
	glow.Parent = box
	block(parent, "LanternRoof", Vector3.new(3, 0.6, 3), CFrame.new(ground + Vector3.new(0, 4.9, 0)) * CFrame.Angles(0, math.rad(45), 0), DARK, false)
end

--------------------------------------------------------------------------------
-- Collines
--------------------------------------------------------------------------------

export type HillParams = {
	Heights: { number }, -- hauteurs des colonnes (modifiées sur place)
	Reserved: { [number]: boolean }, -- colonnes à laisser telles quelles (piste, zones plates)
	NX: number,
	NZ: number,
	MinX: number,
	MinZ: number,
	Voxel: number,
	FloorY: number,
	Amplitude: number, -- hauteur maximale des collines au-dessus du sol
	Fade: number, -- distance (studs) sur laquelle elles montent depuis les colonnes réservées
	Scale: number?, -- taille d'une colline (studs), 260 par défaut
	Seed: number?,
}

--[[
	Collines autour des pistes : du relief au lieu d'une plaine plate.
	La distance de chaque colonne à la plus proche colonne réservée est
	calculée en deux passes (distance de chanfrein), avec la HAUTEUR de cette
	colonne : le sol part de là (bas du talus, même haut perché) et rejoint en
	douceur les collines (bruit de Perlin à deux octaves). Ni marche ni fossé
	au bord des talus ; la piste et les zones plates ne changent pas.
	Rend la hauteur la plus haute atteinte.
]]
function Scenery.Hills(params: HillParams): number
	local nx, nz = params.NX, params.NZ
	local heights, reserved = params.Heights, params.Reserved
	local count = nx * nz
	local far = 1e9
	local distance = table.create(count, far)
	local source = table.create(count, params.FloorY) -- hauteur de la colonne réservée la plus proche
	for index in pairs(reserved) do
		distance[index] = 0
		source[index] = heights[index]
	end
	local diagonal = math.sqrt(2)
	local function relax(index: number, other: number, cost: number)
		local candidate = distance[other] + cost
		if candidate < distance[index] then
			distance[index] = candidate
			source[index] = source[other]
		end
	end
	-- Passe aller.
	for ix = 1, nx do
		local rowBase = (ix - 1) * nz
		for iz = 1, nz do
			local index = rowBase + iz
			if iz > 1 then
				relax(index, index - 1, 1)
			end
			if ix > 1 then
				relax(index, index - nz, 1)
				if iz > 1 then
					relax(index, index - nz - 1, diagonal)
				end
				if iz < nz then
					relax(index, index - nz + 1, diagonal)
				end
			end
		end
		if ix % 64 == 0 then
			task.wait()
		end
	end
	-- Passe retour.
	for ix = nx, 1, -1 do
		local rowBase = (ix - 1) * nz
		for iz = nz, 1, -1 do
			local index = rowBase + iz
			if iz < nz then
				relax(index, index + 1, 1)
			end
			if ix < nx then
				relax(index, index + nz, 1)
				if iz < nz then
					relax(index, index + nz + 1, diagonal)
				end
				if iz > 1 then
					relax(index, index + nz - 1, diagonal)
				end
			end
		end
		if ix % 64 == 0 then
			task.wait()
		end
	end
	-- Les collines.
	local scale = params.Scale or 260
	local seed = (params.Seed or 0) * 0.37 + 0.123
	local highest = params.FloorY
	for ix = 1, nx do
		local x = params.MinX + (ix - 0.5) * params.Voxel
		local rowBase = (ix - 1) * nz
		for iz = 1, nz do
			local index = rowBase + iz
			local d = distance[index] * params.Voxel
			if d > 0 then
				local z = params.MinZ + (iz - 0.5) * params.Voxel
				local n = math.noise(x / scale, z / scale, seed) + 0.45 * math.noise(x / (scale * 0.4), z / (scale * 0.4), seed + 5.1)
				local shape = math.clamp(n * 1.1 + 0.55, 0, 1)
				local t = math.clamp(d / params.Fade, 0, 1)
				local rise = t * t * (3 - 2 * t)
				local from = if distance[index] < far then source[index] else params.FloorY
				local target = params.FloorY + params.Amplitude * shape * shape
				heights[index] = from + (target - from) * rise
			end
			if heights[index] > highest then
				highest = heights[index]
			end
		end
		if ix % 64 == 0 then
			task.wait()
		end
	end
	return highest
end

return Scenery
