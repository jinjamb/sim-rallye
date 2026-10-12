--!strict
--[[
	Theme.luau
	L'identité visuelle du jeu : « rallye animé ». La mise en page d'une
	retransmission WRC (chronos, écarts, étiquettes pleines, tour de
	classement), dessinée comme un anime de course japonais :

		- nuit indigo, ROSE SAKURA pour l'action et la sélection, jaune pour
		  ce qui doit sauter aux yeux (position, rampe de LED), cyan en
		  second plan ;
		- traits « cel-shading » : contour net, OMBRE PORTÉE pleine et décalée
		  (rose) sous les panneaux, pas de dégradé ;
		- formes penchées : étiquettes en parallélogramme (Slant), titres en
		  capitales italiques (Montserrat), BANDES DE VITESSE en coin (Stripes) ;
		- les grandes annonces en lettrage de manga (Bangers, contour encré),
		  un filigrane en katakana derrière (Kana) ;
		- chronos en chiffres à chasse fixe, penchés (ils ne « tremblent » pas) ;
		- vert/rouge pour les écarts, violet pour un meilleur temps absolu,
		  comme les chronos TV.

	HABILLAGE AUTOMATIQUE (Theme.Skin) : chaque écran est construit avec des
	polices génériques (Gotham, RobotoMono) ; Skin les remplace par celles du
	thème, sur tout ce que l'écran contient et tout ce qui s'y ajoute ensuite.
	Changer de police, c'est changer FACES ci-dessous, pas cinquante écrans.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

-- Couleurs ------------------------------------------------------------------------

Theme.INK = Color3.fromRGB(12, 10, 28) -- l'encre : ombres, contours, cases vides
Theme.PANEL = Color3.fromRGB(24, 20, 52) -- nuit indigo
Theme.PANEL_2 = Color3.fromRGB(46, 40, 94) -- boutons, cases, pistes de barres
Theme.LINE = Color3.fromRGB(255, 255, 255) -- filets (avec transparence)
Theme.TEXT = Color3.fromRGB(255, 251, 246)
Theme.DIM = Color3.fromRGB(170, 164, 212)
Theme.ACCENT = Color3.fromRGB(255, 46, 126) -- rose sakura : action, sélection
Theme.ON_ACCENT = Color3.fromRGB(255, 255, 255) -- texte sur fond rose
Theme.YELLOW = Color3.fromRGB(255, 222, 40) -- position, LED, ce qui saute aux yeux
Theme.ON_YELLOW = Theme.INK
Theme.CYAN = Color3.fromRGB(0, 214, 255)
Theme.GREEN = Color3.fromRGB(60, 232, 130)
Theme.RED = Color3.fromRGB(255, 64, 80)
Theme.ORANGE = Color3.fromRGB(255, 150, 40)
Theme.BLUE = Color3.fromRGB(70, 160, 255)
Theme.PURPLE = Color3.fromRGB(184, 110, 255)

Theme.CORNER = 2 -- angles vifs
Theme.ACCENT_WIDTH = 4 -- liseré
Theme.SHADOW = 5 -- décalage de l'ombre portée (px)
Theme.SLANT = 16 -- inclinaison des parallélogrammes (degrés)

-- Polices ---------------------------------------------------------------------------

local function face(font: Enum.Font, weight: Enum.FontWeight, style: Enum.FontStyle?): Font
	local base = Font.fromEnum(font)
	return Font.new(base.Family, weight, style or Enum.FontStyle.Normal)
end

local ITALIC = Enum.FontStyle.Italic
Theme.HEADLINE = face(Enum.Font.Montserrat, Enum.FontWeight.Heavy, ITALIC)
Theme.HEADLINE_MEDIUM = face(Enum.Font.Montserrat, Enum.FontWeight.Bold, ITALIC)
Theme.BODY = face(Enum.Font.Nunito, Enum.FontWeight.Bold)
Theme.BODY_BOLD = face(Enum.Font.Nunito, Enum.FontWeight.ExtraBold)
Theme.DIGITS = face(Enum.Font.RobotoMono, Enum.FontWeight.Bold, ITALIC)
-- Lettrage de manga : les grandes annonces (record, départ, combinaison).
Theme.SFX = face(Enum.Font.Bangers, Enum.FontWeight.Regular)
-- Filigrane japonais (les katakanas viennent de la police de secours).
Theme.KANA = face(Enum.Font.BuilderSans, Enum.FontWeight.Heavy)

-- Polices génériques -> polices du thème.
local FACES: { [Enum.Font]: Font } = {
	[Enum.Font.GothamBlack] = Theme.HEADLINE,
	[Enum.Font.GothamBold] = Theme.BODY_BOLD,
	[Enum.Font.GothamMedium] = Theme.BODY,
	[Enum.Font.Gotham] = Theme.BODY,
	[Enum.Font.RobotoMono] = Theme.DIGITS,
}
-- Familles du thème : un texte déjà habillé n'est pas retouché.
local THEMED: { [string]: boolean } = {
	[Theme.HEADLINE.Family] = true,
	[Theme.BODY.Family] = true,
	[Theme.SFX.Family] = true,
	[Theme.KANA.Family] = true,
}

function Theme.Face(font: Enum.Font): Font
	return FACES[font] or Theme.BODY
end

local function skinText(item: Instance)
	if not (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) then
		return
	end
	local text = item :: TextLabel
	local function apply()
		local current = text.FontFace
		if THEMED[current.Family] or (current.Family == Theme.DIGITS.Family and current.Style == ITALIC) then
			return
		end
		local mapped = FACES[text.Font]
		if mapped then
			text.FontFace = mapped
		end
	end
	apply()
	-- Un écran qui change la police d'un texte après coup est habillé aussi.
	text:GetPropertyChangedSignal("FontFace"):Connect(apply)
end

--[[
	Habille un écran : ses textes prennent les polices du thème, maintenant et
	à chaque ajout (menus reconstruits, lignes de classement...).
]]
function Theme.Skin(gui: Instance)
	for _, item in ipairs(gui:GetDescendants()) do
		skinText(item)
	end
	gui.DescendantAdded:Connect(skinText)
end

-- Éléments -----------------------------------------------------------------------------

function Theme.Corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.CORNER)
	corner.Parent = parent
end

--[[
	Aplat « cel-shading » : plus de dégradé, le panneau reste d'une couleur
	franche. Gardé pour les écrans qui l'appellent encore.
]]
function Theme.Shade(_frame: GuiObject) end

--[[
	Contour net autour d'un panneau ou d'un bouton : blanc légèrement voilé
	par défaut (lisible sur la nuit indigo comme sur le décor).
]]
function Theme.Ink(parent: GuiObject, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Ink"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.LINE
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0.15
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = parent
	return stroke
end

-- Contour encré d'un texte (lettrage de manga).
function Theme.TextInk(label: TextLabel | TextButton, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextInk"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = color or Theme.INK
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

--[[
	Ombre portée pleine, décalée en bas à droite, comme un dessin animé. Deux
	bandes collées au bord droit et au bord bas (la seule partie visible d'une
	ombre décalée) : rien ne passe sous le panneau, qui peut rester translucide.
	Hors du cadre du parent : sans effet dans un CanvasGroup ou un cadre qui
	découpe ses enfants.
]]
function Theme.CelShadow(parent: GuiObject, color: Color3?, depth: number?): Frame
	local d = depth or Theme.SHADOW
	local holder = Instance.new("Frame")
	holder.Name = "CelShadow"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = parent.ZIndex
	local right = Instance.new("Frame")
	right.BorderSizePixel = 0
	right.BackgroundColor3 = color or Theme.ACCENT
	right.Position = UDim2.new(1, 0, 0, d)
	right.Size = UDim2.new(0, d, 1, 0)
	right.ZIndex = parent.ZIndex
	right.Parent = holder
	local bottom = right:Clone()
	bottom.Position = UDim2.new(0, d, 1, 0)
	bottom.Size = UDim2.new(1, -d, 0, d)
	bottom.Parent = holder
	holder.Parent = parent
	return holder
end

--[[
	Parallélogramme « / / » : le cadre reste un rectangle, deux petits
	triangles de sa couleur lui sont collés DEHORS, en bas à gauche et en
	haut à droite. Chaque triangle est un petit cadre (largeur = hauteur ×
	tan de l'angle) coupé en diagonale par un dégradé penché à bord franc,
	passant par son centre.
	Pourquoi pas un dégradé sur le cadre lui-même : penché, un dégradé ne
	s'étale que sur une bande de quelques hauteurs de large ; sur une longue
	étiquette, il n'atteint pas les bouts.
	Les triangles suivent la couleur et la transparence du cadre (étiquettes
	qui changent de couleur). Pas de contour (UIStroke) sur un cadre penché :
	il resterait rectangulaire.
]]
local function slantCap(frame: GuiObject, degrees: number, right: boolean): Frame
	-- Les marges intérieures (UIPadding) du cadre décalent aussi ses enfants :
	-- on les compense pour coller les triangles au vrai bord.
	local padding = frame:FindFirstChildOfClass("UIPadding")
	local left = if padding then padding.PaddingLeft.Offset else 0
	local rightPad = if padding then padding.PaddingRight.Offset else 0
	local top = if padding then padding.PaddingTop.Offset else 0
	local bottom = if padding then padding.PaddingBottom.Offset else 0
	local cap = Instance.new("Frame")
	cap.Name = if right then "SlantRight" else "SlantLeft"
	cap.BorderSizePixel = 0
	cap.AnchorPoint = Vector2.new(if right then 0 else 1, 0)
	cap.Position = if right then UDim2.new(1, rightPad, 0, -top) else UDim2.new(0, -left, 0, -top)
	cap.Size = UDim2.new(1, 0, 1, top + bottom)
	cap.ZIndex = frame.ZIndex
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = math.tan(math.rad(degrees))
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = cap
	-- Diagonale « / » par le centre : plein à droite (bout gauche), plein à
	-- gauche (bout droit).
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = degrees
	local before = if right then 0 else 1 -- transparence avant la diagonale
	local after = 1 - before
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, before),
		NumberSequenceKeypoint.new(0.5, before),
		NumberSequenceKeypoint.new(0.501, after),
		NumberSequenceKeypoint.new(1, after),
	})
	gradient.Parent = cap
	cap.Parent = frame
	return cap
end

function Theme.Slant(frame: GuiObject, angle: number?)
	local degrees = angle or Theme.SLANT
	local caps = { slantCap(frame, degrees, false), slantCap(frame, degrees, true) }
	local function sync()
		for _, cap in ipairs(caps) do
			cap.BackgroundColor3 = frame.BackgroundColor3
			cap.BackgroundTransparency = frame.BackgroundTransparency
		end
	end
	sync()
	frame:GetPropertyChangedSignal("BackgroundColor3"):Connect(sync)
	frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(sync)
end

--[[
	Bandes de vitesse « //// » : `count` traits penchés (4 au plus : limite
	des dégradés de Roblox), de la couleur donnée, dans un cadre à placer.
]]
function Theme.Stripes(parent: Instance, color: Color3?, count: number?, transparency: number?): Frame
	local n = math.clamp(count or 4, 1, 4)
	local alpha = transparency or 0
	local strip = Instance.new("Frame")
	strip.Name = "Stripes"
	strip.BorderSizePixel = 0
	strip.BackgroundColor3 = color or Theme.ACCENT
	strip.Size = UDim2.fromOffset(120, 30)
	local points = { NumberSequenceKeypoint.new(0, 1) }
	for i = 0, n - 1 do
		local x = 0.04 + i / n * 0.92
		table.insert(points, NumberSequenceKeypoint.new(x, 1))
		table.insert(points, NumberSequenceKeypoint.new(x + 0.001, alpha))
		table.insert(points, NumberSequenceKeypoint.new(x + 0.4 / n, alpha))
		table.insert(points, NumberSequenceKeypoint.new(x + 0.4 / n + 0.001, 1))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, 1))
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(points)
	gradient.Rotation = -25
	gradient.Parent = strip
	strip.Parent = parent
	return strip
end

--[[
	Filigrane japonais : de grands katakanas pâles, derrière le contenu
	(« ラリー », rallye). Décoratif : on peut le lire sans le comprendre.
]]
function Theme.Kana(parent: Instance, text: string, size: number?, transparency: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Kana"
	label.BackgroundTransparency = 1
	label.FontFace = Theme.KANA
	label.Text = text
	label.TextSize = size or 64
	label.TextColor3 = Theme.LINE
	label.TextTransparency = transparency or 0.88
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	return label
end

-- Le liseré rose, sur le bord gauche d'un panneau.
function Theme.AccentBar(parent: GuiObject, color: Color3?): Frame
	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = color or Theme.ACCENT
	bar.Size = UDim2.new(0, Theme.ACCENT_WIDTH, 1, 0)
	bar.ZIndex = (parent.ZIndex or 1) + 1
	bar.Parent = parent
	return bar
end

--[[
	Panneau du jeu, à partir d'un cadre existant : nuit indigo, contour net,
	ombre portée rose. `shadow` = false pour un cadre qui découpe ses enfants.
]]
function Theme.Card(frame: GuiObject, transparency: number?, shadow: Color3 | false | nil)
	frame.BackgroundColor3 = Theme.PANEL
	frame.BackgroundTransparency = transparency or 0.08
	frame.BorderSizePixel = 0
	Theme.Corner(frame)
	Theme.Ink(frame)
	if shadow ~= false then
		Theme.CelShadow(frame, shadow or Theme.ACCENT)
	end
end

--[[
	Filet à damier : `rows` rangées de cases de `cell` pixels, sur toute la
	largeur du parent (assez de cases pour `width` pixels).
]]
function Theme.Checker(parent: GuiObject, width: number, cell: number?, rows: number?): Frame
	local size = cell or 5
	local count = math.ceil(width / size)
	local lines = rows or 2
	local strip = Instance.new("Frame")
	strip.Name = "Checker"
	strip.BackgroundColor3 = Theme.INK
	strip.BorderSizePixel = 0
	strip.ClipsDescendants = true
	strip.Size = UDim2.new(1, 0, 0, size * lines)
	for row = 0, lines - 1 do
		for column = 0, count - 1 do
			if (row + column) % 2 == 0 then
				local square = Instance.new("Frame")
				square.BorderSizePixel = 0
				square.BackgroundColor3 = Theme.TEXT
				square.Position = UDim2.fromOffset(column * size, row * size)
				square.Size = UDim2.fromOffset(size, size)
				square.Parent = strip
			end
		end
	end
	strip.Parent = parent
	return strip
end

-- Étiquette pleine et penchée (« SPÉCIALE », « P1 », « JOKER ✓ ») : largeur ajustée au texte.
function Theme.Tag(parent: Instance, text: string, background: Color3?, color: Color3?, size: number?): TextLabel
	local textSize = size or 13
	local tag = Instance.new("TextLabel")
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, textSize + 9)
	tag.BackgroundColor3 = background or Theme.ACCENT
	tag.BorderSizePixel = 0
	tag.FontFace = Theme.HEADLINE
	tag.TextSize = textSize
	tag.TextColor3 = color or Theme.ON_ACCENT
	tag.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = tag
	Theme.Slant(tag) -- après la marge : les biais la compensent
	tag.Parent = parent
	return tag
end

--[[
	Apparition « pop » d'un élément : il grossit d'un coup puis se pose, comme
	un dessin animé. Utilise (ou crée) son UIScale ; `base` = échelle finale.
]]
function Theme.Pop(item: GuiObject, base: number?, from: number?)
	local scale = item:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = item
	end
	local target = base or 1
	local s = scale :: UIScale
	s.Scale = target * (from or 0.6)
	TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- Bouton principal : rose, texte blanc, ombre d'encre.
function Theme.Primary(button: TextButton)
	button.BackgroundColor3 = Theme.ACCENT
	button.TextColor3 = Theme.ON_ACCENT
	button.FontFace = Theme.HEADLINE
	if not button:FindFirstChild("CelShadow") then
		Theme.CelShadow(button, Theme.INK, 3)
	end
end

-- Bouton de danger (abandonner).
function Theme.Danger(button: TextButton)
	button.BackgroundColor3 = Color3.fromRGB(170, 28, 52)
	button.TextColor3 = Theme.TEXT
end

-- "#RRGGBB" pour le texte enrichi.
function Theme.Hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

return Theme
