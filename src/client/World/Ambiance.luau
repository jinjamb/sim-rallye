--!strict
--[[
	Ambiance.luau
	Applique une ambiance (Ambiances.luau) à l'éclairage, chez ce joueur
	seulement : Lighting, Atmosphere, nuages, étalonnage, halo, rayons.

	Le paddock pose la sienne au démarrage ; une voiture (DrivingSession) pose
	celle de sa spéciale ou de son circuit AVANT la météo et les contraintes
	du défi (WeatherClient, StageModifier), qui partent de cet éclairage et y
	reviennent ; puis, voiture rendue, le paddock reprend la main.

	Les effets du ralenti (Replay.luau : filtres, profondeur de champ) se
	posent par-dessus : ils restent relatifs à l'ambiance.
]]

local Lighting = game:GetService("Lighting")

local Ambiances = require(script.Parent.Ambiances)

local Ambiance = {}

local current: Ambiances.Ambiance = Ambiances.Paddock()

-- L'effet nommé, créé au besoin (il peut avoir été supprimé dans Studio).
local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return (existing :: any) :: T
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return (created :: any) :: T
end

function Ambiance.Current(): Ambiances.Ambiance
	return current
end

function Ambiance.Set(ambiance: Ambiances.Ambiance)
	current = ambiance

	-- Moteur d'éclairage (Technology, non modifiable par script, est réglé
	-- dans default.project.json).
	local engine = Ambiances.ENGINE
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = engine.ShadowSoftness
	Lighting.EnvironmentSpecularScale = engine.EnvironmentSpecularScale
	Lighting.EnvironmentDiffuseScale = engine.EnvironmentDiffuseScale

	Lighting.ClockTime = ambiance.ClockTime
	Lighting.GeographicLatitude = ambiance.Latitude
	Lighting.Brightness = ambiance.Brightness
	Lighting.ExposureCompensation = ambiance.Exposure
	Lighting.OutdoorAmbient = ambiance.Shadow
	Lighting.Ambient = ambiance.Ambient
	Lighting.ColorShift_Top = ambiance.ShiftTop
	Lighting.ColorShift_Bottom = ambiance.ShiftBottom

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		local created = Instance.new("Atmosphere")
		created.Parent = Lighting
		atmosphere = created
	end
	local spec = ambiance.Atmosphere
	local air = atmosphere :: Atmosphere
	air.Density = spec.Density
	air.Offset = spec.Offset
	air.Haze = spec.Haze
	air.Glare = spec.Glare
	air.Color = spec.Color
	air.Decay = spec.Decay

	local grade = effect("ColorCorrectionEffect", "AmbianceGrade") :: ColorCorrectionEffect
	grade.Saturation = ambiance.Grade.Saturation
	grade.Contrast = ambiance.Grade.Contrast
	grade.Brightness = ambiance.Grade.Brightness
	grade.TintColor = ambiance.Grade.Tint

	local bloom = effect("BloomEffect", "AmbianceBloom") :: BloomEffect
	bloom.Intensity = ambiance.Bloom.Intensity
	bloom.Size = ambiance.Bloom.Size
	bloom.Threshold = ambiance.Bloom.Threshold

	local rays = effect("SunRaysEffect", "AmbianceRays") :: SunRaysEffect
	rays.Intensity = ambiance.SunRays.Intensity
	rays.Spread = ambiance.SunRays.Spread

	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		local created = Instance.new("Clouds")
		created.Parent = terrain
		clouds = created
	end
	local sky = clouds :: Clouds
	sky.Cover = ambiance.Clouds.Cover
	sky.Density = ambiance.Clouds.Density
	sky.Color = ambiance.Clouds.Color
end

-- Retour à l'ambiance du paddock (voiture rendue).
function Ambiance.Reset()
	Ambiance.Set(Ambiances.Paddock())
end

return Ambiance
