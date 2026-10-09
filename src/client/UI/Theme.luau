--!strict
--[[
	Theme.luau
	L'identité visuelle du jeu : « rallye moderne », comme une retransmission
	de rallye ou de rallycross à la télévision.

		- noir profond, panneaux à angles vifs, un LISERÉ jaune vif à gauche ;
		- titres en capitales condensées (Oswald), texte en Titillium Web,
		  chronos en chiffres à chasse fixe (ils ne « tremblent » pas) ;
		- damier en filet, étiquettes pleines (position, joker, écarts) ;
		- jaune pour l'action principale, vert/rouge pour les écarts,
		  violet pour un meilleur temps absolu (comme les chronos TV).

	HABILLAGE AUTOMATIQUE (Theme.Skin) : chaque écran est construit avec des
	polices génériques (Gotham, RobotoMono) ; Skin les remplace par celles du
	thème, sur tout ce que l'écran contient et tout ce qui s'y ajoute ensuite.
	Changer de police, c'est changer FACES ci-dessous, pas cinquante écrans.
]]

local Theme = {}

-- Couleurs ------------------------------------------------------------------------

Theme.INK = Color3.fromRGB(8, 9, 12) -- le plus sombre : ombres, cases vides
Theme.PANEL = Color3.fromRGB(15, 16, 20)
Theme.PANEL_2 = Color3.fromRGB(30, 32, 40) -- boutons, cases, pistes de barres
Theme.LINE = Color3.fromRGB(255, 255, 255) -- filets (avec transparence)
Theme.TEXT = Color3.fromRGB(244, 245, 248)
Theme.DIM = Color3.fromRGB(140, 145, 158)
Theme.ACCENT = Color3.fromRGB(255, 204, 0) -- jaune course
Theme.ON_ACCENT = Color3.fromRGB(12, 12, 14) -- texte sur fond jaune
Theme.GREEN = Color3.fromRGB(55, 220, 110)
Theme.RED = Color3.fromRGB(255, 62, 62)
Theme.ORANGE = Color3.fromRGB(255, 140, 25)
Theme.BLUE = Color3.fromRGB(60, 150, 255)
Theme.PURPLE = Color3.fromRGB(190, 110, 255)

Theme.CORNER = 3 -- angles presque vifs
Theme.ACCENT_WIDTH = 4 -- liseré jaune

-- Polices ---------------------------------------------------------------------------

local function face(font: Enum.Font, weight: Enum.FontWeight): Font
	local base = Font.fromEnum(font)
	return Font.new(base.Family, weight, Enum.FontStyle.Normal)
end

Theme.HEADLINE = face(Enum.Font.Oswald, Enum.FontWeight.Bold)
Theme.HEADLINE_MEDIUM = face(Enum.Font.Oswald, Enum.FontWeight.Medium)
Theme.BODY = face(Enum.Font.TitilliumWeb, Enum.FontWeight.SemiBold)
Theme.BODY_BOLD = face(Enum.Font.TitilliumWeb, Enum.FontWeight.Bold)
Theme.DIGITS = face(Enum.Font.RobotoMono, Enum.FontWeight.Bold)

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
		if THEMED[current.Family] or (current.Family == Theme.DIGITS.Family and current.Weight == Enum.FontWeight.Bold) then
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

-- Léger dégradé vertical : le haut un peu plus clair, comme un écran TV.
function Theme.Shade(frame: GuiObject)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 172, 180))
	gradient.Parent = frame
end

-- Le liseré jaune, sur le bord gauche d'un panneau.
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

-- Étiquette pleine (« SPÉCIALE », « P1 », « JOKER ✓ ») : largeur ajustée au texte.
function Theme.Tag(parent: Instance, text: string, background: Color3?, color: Color3?, size: number?): TextLabel
	local tag = Instance.new("TextLabel")
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, (size or 13) + 8)
	tag.BackgroundColor3 = background or Theme.ACCENT
	tag.BorderSizePixel = 0
	tag.FontFace = Theme.HEADLINE
	tag.TextSize = size or 13
	tag.TextColor3 = color or Theme.ON_ACCENT
	tag.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = tag
	Theme.Corner(tag, 2)
	tag.Parent = parent
	return tag
end

-- Bouton principal : fond jaune, texte noir.
function Theme.Primary(button: TextButton)
	button.BackgroundColor3 = Theme.ACCENT
	button.TextColor3 = Theme.ON_ACCENT
	button.FontFace = Theme.HEADLINE
end

-- Bouton de danger (abandonner).
function Theme.Danger(button: TextButton)
	button.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
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
