--!strict
--[[
	WeatherClient.luau
	La météo chez le pilote, pour la durée d'une voiture (DrivingSession) :
	la prévision (Weather.luau) est lue à chaque image, sur l'heure du
	serveur, et appliquée :
		- à la conduite : Surfaces.Wetness (l'adhérence suit l'eau sur la
		  route) ;
		- à l'image : pluie autour de la caméra, ciel gris et brume qui
		  suivent l'averse, routes et talus assombris tant qu'ils sont
		  mouillés ;
		- au son : pluie (SoundBank.Rain, si elle est renseignée) ;
		- aux annonces : une averse qui arrive, une pluie qui cesse.

	Tout est local (éclairage, couleurs du terrain : réglés côté client, ils
	ne changent que chez ce joueur) et rendu à l'état d'origine à l'arrêt.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Weather = require(ReplicatedStorage.Shared.Weather.Weather)
local Surfaces = require(ReplicatedStorage.Shared.Vehicle.Surfaces)
local SoundBank = require(script.Parent.Parent.Audio.SoundBank)
local SoundGroups = require(script.Parent.Parent.Audio.SoundGroups)
local Toast = require(script.Parent.Parent.UI.Toast)
local Theme = require(script.Parent.Parent.UI.Theme)

local WeatherClient = {}

local RAIN_RATE = 900 -- gouttes par seconde au plus fort
local WET_DARKEN = 0.32 -- une route trempée est assombrie de 32 %
local SHOWER_START, SHOWER_END = 0.15, 0.02 -- seuils des annonces (hystérésis)
local SKY_HIDE, SKY_SHOW = 0.45, 0.25 -- le ciel peint s'efface sous l'averse
local RAIN_VOLUME = 0.6

-- Ce que l'averse assombrit (le reste du terrain : neige, glace, roche, garde sa couleur).
local WET_MATERIALS = {
	Enum.Material.Asphalt,
	Enum.Material.Ground,
	Enum.Material.Mud,
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Sand,
	Enum.Material.Slate,
}

-- Ambiance sous la pluie (au plus fort), mélangée à celle d'origine.
local WET_LIGHTING = {
	Brightness = 1.2,
	OutdoorAmbient = Color3.fromRGB(105, 110, 120),
	FogColor = Color3.fromRGB(150, 156, 165),
	FogStart = 40,
	FogEnd = 700,
}
local WET_ATMOSPHERE = { Density = 0.42, Haze = 2.4, Color = Color3.fromRGB(170, 176, 186) }

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Pluie : des traits qui tombent autour de la caméra.
local function makeRain(): (Part, ParticleEmitter)
	local holder = Instance.new("Part")
	holder.Name = "Rain"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(160, 1, 160)
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Speed = NumberRange.new(90, 110)
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new(0.08)
	-- Étirées en traits (Squash < 0 : allongées dans le sens du mouvement).
	emitter.Squash = NumberSequence.new(-2.5)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	emitter.LightEmission = 0.1
	emitter.Parent = holder
	holder.Parent = workspace
	return holder, emitter
end

--[[
	Applique la prévision jusqu'à l'appel de la fonction rendue (qui rend
	tout à l'état d'origine). Une prévision « sec » ne change rien.
]]
function WeatherClient.Start(forecast: Weather.Forecast): () -> ()
	if forecast.Mode == "Dry" then
		return function() end
	end
	local tracker = Weather.Tracker(forecast)
	local terrain = workspace.Terrain

	-- État d'origine, pour mélanger puis rendre.
	local base = {
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local baseAtmosphere = if atmosphere
		then { Density = atmosphere.Density, Haze = atmosphere.Haze, Color = atmosphere.Color }
		else nil
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local skyHidden = false
	local baseColors: { [Enum.Material]: Color3 } = {}
	for _, material in ipairs(WET_MATERIALS) do
		baseColors[material] = terrain:GetMaterialColor(material)
	end

	local holder, emitter = makeRain()
	local sound: Sound? = nil
	if SoundBank.Rain ~= "" then
		local created = Instance.new("Sound")
		created.Name = "Rain"
		created.SoundId = SoundBank.Rain
		created.Looped = true
		created.Volume = 0
		created.SoundGroup = SoundGroups.Get("Effets")
		created.Parent = SoundService
		created:Play()
		sound = created
	end

	local showering = false
	local lastWetness = -1
	local connection = RunService.RenderStepped:Connect(function()
		local rain, wetness = tracker:Update(workspace:GetServerTimeNow())
		Surfaces.Wetness = wetness

		-- La pluie autour de la caméra.
		local camera = workspace.CurrentCamera
		holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
		emitter.Rate = RAIN_RATE * rain
		if sound then
			sound.Volume = RAIN_VOLUME * rain
		end

		-- Le ciel et la brume suivent l'averse.
		Lighting.Brightness = lerp(base.Brightness, WET_LIGHTING.Brightness, rain)
		Lighting.OutdoorAmbient = base.OutdoorAmbient:Lerp(WET_LIGHTING.OutdoorAmbient, rain)
		Lighting.FogColor = base.FogColor:Lerp(WET_LIGHTING.FogColor, rain)
		Lighting.FogStart = lerp(base.FogStart, WET_LIGHTING.FogStart, rain)
		Lighting.FogEnd = lerp(base.FogEnd, WET_LIGHTING.FogEnd, rain)
		if atmosphere and baseAtmosphere then
			atmosphere.Density = lerp(baseAtmosphere.Density, WET_ATMOSPHERE.Density, rain)
			atmosphere.Haze = lerp(baseAtmosphere.Haze, WET_ATMOSPHERE.Haze, rain)
			atmosphere.Color = baseAtmosphere.Color:Lerp(WET_ATMOSPHERE.Color, rain)
		end
		-- Le ciel peint (plein soleil) jure sous l'averse : sans lui, Roblox
		-- affiche son ciel gris.
		if sky then
			if not skyHidden and rain > SKY_HIDE then
				sky.Parent = nil
				skyHidden = true
			elseif skyHidden and rain < SKY_SHOW then
				sky.Parent = Lighting
				skyHidden = false
			end
		end

		-- Routes et talus assombris tant qu'ils sont mouillés (pas à chaque image).
		if math.abs(wetness - lastWetness) > 0.02 then
			lastWetness = wetness
			for material, color in pairs(baseColors) do
				terrain:SetMaterialColor(material, color:Lerp(Color3.new(0, 0, 0), WET_DARKEN * wetness))
			end
		end

		-- Annonces : une averse arrive, la pluie cesse (pas en mode pluie continue).
		if forecast.Mode == "Dynamic" then
			if not showering and rain > SHOWER_START then
				showering = true
				Toast.Show("<b>Averse</b> · la route devient glissante", Theme.BLUE)
			elseif showering and rain < SHOWER_END then
				showering = false
				Toast.Show("<b>La pluie cesse</b> · la route va sécher peu à peu", Theme.BLUE)
			end
		end
	end)

	if forecast.Mode == "Rain" then
		Toast.Show("<b>Pluie</b> · route mouillée, freine plus tôt", Theme.BLUE)
	end

	return function()
		connection:Disconnect()
		holder:Destroy()
		if sound then
			sound:Destroy()
		end
		Surfaces.Wetness = 0
		for key, value in pairs(base) do
			(Lighting :: any)[key] = value
		end
		if atmosphere and baseAtmosphere then
			atmosphere.Density = baseAtmosphere.Density
			atmosphere.Haze = baseAtmosphere.Haze
			atmosphere.Color = baseAtmosphere.Color
		end
		if sky and skyHidden then
			sky.Parent = Lighting
		end
		for material, color in pairs(baseColors) do
			terrain:SetMaterialColor(material, color)
		end
	end
end

return WeatherClient
