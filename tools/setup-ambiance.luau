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

-- Pas d'effets d'image fixes : ceux des ambiances (client, Ambiance.luau) suffisent,
-- et s'y ajoutaient (bloom compté deux fois). On retire ceux d'avant.
for _, name in ipairs({ "WorldGrade", "WorldBloom" }) do
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Terrain : herbe d'alpage, terre brune, asphalte gris clair.
local terrain = workspace.Terrain
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 134, 74))
terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 124, 68))
terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 100, 76))
terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 78, 60))
terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(104, 104, 108))

print("[setup-ambiance] Ambiance appliquée.")
