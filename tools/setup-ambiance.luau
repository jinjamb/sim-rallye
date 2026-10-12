--[[
	setup-ambiance.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée).
	Rojo le range dans ServerStorage.Tools (jamais exécuté en jeu) : c'est un outil d'édition.

	L'ambiance du monde, façon rallye illustré : lumière de jour douce, ombres
	légères, couleurs un peu adoucies, brume qui estompe le lointain, ciel peint
	(ServerStorage.SceneryAssets.Sky, un asset du Creator Store), herbe et terre
	dans des tons naturels. Relançable : il remplace ce qu'il a posé.

	Les défis de la spéciale (StageModifier.luau) prennent une photo de ces
	réglages et les remettent après coup ; la nuit, la pluie et le brouillard
	retirent le ciel peint le temps du défi.
]]

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

-- Lumière : soleil en fin de matinée, ambiance claire et douce.
Lighting.ClockTime = 14.2
Lighting.GeographicLatitude = 35
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(88, 92, 100)
Lighting.OutdoorAmbient = Color3.fromRGB(138, 142, 150)
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.2
Lighting.ShadowSoftness = 0.6
Lighting.ExposureCompensation = 0.1
Lighting.GlobalShadows = true

-- Ciel peint.
for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Sky") then
		child:Destroy()
	end
end
local library = ServerStorage:FindFirstChild("SceneryAssets")
local sky = library and library:FindFirstChild("Sky")
if sky then
	local copy = sky:Clone()
	copy.Name = "Sky"
	copy.Parent = Lighting
else
	warn("[setup-ambiance] Pas de ServerStorage.SceneryAssets.Sky : ciel par défaut.")
end

-- Brume : le lointain se fond dans le ciel, les collines s'étagent.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(205, 215, 222)
atmosphere.Decay = Color3.fromRGB(120, 140, 150)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.4
atmosphere.Parent = Lighting

-- Étalonnage : un peu moins saturé, un peu plus de contraste, une pointe chaude.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end
local grade = effect("ColorCorrectionEffect", "WorldGrade") :: ColorCorrectionEffect
grade.Saturation = -0.08
grade.Contrast = 0.08
grade.Brightness = 0.02
grade.TintColor = Color3.fromRGB(255, 248, 238)
local bloom = effect("BloomEffect", "WorldBloom") :: BloomEffect
bloom.Intensity = 0.25
bloom.Size = 24
bloom.Threshold = 1.6

-- Terrain : herbe d'alpage, terre brune, asphalte gris clair.
local terrain = workspace.Terrain
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 134, 74))
terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 124, 68))
terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 100, 76))
terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 78, 60))
terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(104, 104, 108))

print("[setup-ambiance] Ambiance appliquée.")
