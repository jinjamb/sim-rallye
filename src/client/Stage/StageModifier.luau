--!strict
--[[
	StageModifier.luau
	Applique chez le pilote la contrainte du défi de la semaine (Weekly.luau),
	pour la durée d'une voiture (DrivingSession) ; tout est rendu à l'état
	d'origine à la fin (Cleanup).

		Nuit         : il fait nuit (éclairage local), phares sur la voiture.
		Pluie        : la météo « pluie » (Weather.luau), posée par le serveur
		               sur la voiture et appliquée par WeatherClient : rien à
		               faire ici.
		Boîte en 3e  : un seul rapport engagé (Car.GearLock).
		Brouillard   : on y voit à quelques dizaines de mètres.
		Sans frein à main : Car.HandbrakeDisabled.

	L'éclairage n'est modifié QUE chez ce joueur (Lighting est local au client
	pour ce qui est réglé côté client) : les autres joueurs gardent leur ciel.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarClass = require(script.Parent.Parent.Physics.Car)
local CarLights = require(script.Parent.Parent.Driving.CarLights)

local StageModifier = {}


-- Faisceaux longue portée des phares (voir headlights) : distance devant la
-- voiture (studs, à l'arrêt) et puissance, qui baisse au loin.
local LONG_BEAMS = {
	{ Distance = 40, Brightness = 4 },
	{ Distance = 75, Brightness = 3.4 },
	{ Distance = 110, Brightness = 2.8 },
	{ Distance = 145, Brightness = 2.2 },
	{ Distance = 180, Brightness = 1.6 },
}
local BEAM_HEIGHT = 22 -- au-dessus de la route
local BEAM_STRETCH = 0.6 -- jusqu'à +60 % de distance...
local BEAM_STRETCH_SPEED = 150 -- ... à 150 studs/s (~150 km/h)
local LOCKED_GEAR = 3
local HEADLIGHT_AHEAD = 1.5 -- studs devant le nez de la carrosserie (lame avant comprise)

-- Valeurs d'éclairage modifiées, pour les rendre ensuite.
local function snapshot(instance: Instance, properties: { string }): () -> ()
	local saved: { [string]: any } = {}
	for _, name in ipairs(properties) do
		saved[name] = (instance :: any)[name]
	end
	return function()
		for name, value in pairs(saved) do
			(instance :: any)[name] = value
		end
	end
end

local LIGHTING_PROPERTIES = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogStart", "FogEnd", "FogColor", "ExposureCompensation" }

--[[
	Phares : deux projecteurs à l'avant du châssis (l'avant est en -Z), à la
	couleur des phares portés (Items/Headlights.luau). Allumés la nuit (défi)
	et dès le crépuscule (DrivingSession, voir StageModifier.NeedsHeadlights).
	Une seule paire par voiture : un second appel ne fait rien.
	Sans ombres : la carrosserie, posée autour du châssis, masquerait le
	faisceau de ses propres phares. Les projecteurs sont donc posés DEVANT le
	nez de la carrosserie (attribut HeadLightZ, CarBodies) : sans ombres, un
	projecteur placé dedans éclairerait la voiture elle-même (lame avant,
	capot), d'où un gros halo sur les WRC et leur lame avant.
]]
local function headlights(chassis: BasePart): () -> ()
	if chassis:GetAttribute("HeadlightsOn") then
		return function() end
	end
	chassis:SetAttribute("HeadlightsOn", true)
	local created: { Instance } = {}
	local beamColor = CarLights.HeadlightColor(chassis.Parent)
	local half = chassis.Size
	local model = chassis.Parent
	local headZ = if model then model:GetAttribute("HeadLightZ") else nil
	local noseZ = math.min(-half.Z / 2, if type(headZ) == "number" then headZ else -half.Z / 2)
	for _, side in ipairs({ -1, 1 }) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Headlight"
		attachment.Position = Vector3.new(side * half.X * 0.32, 0.2, noseZ - HEADLIGHT_AHEAD)
		attachment.Orientation = Vector3.new(-6, 0, 0)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 60
		light.Angle = 80
		light.Brightness = 6
		light.Color = beamColor
		light.Shadows = false
		light.Parent = attachment
		attachment.Parent = chassis
		table.insert(created, attachment)
	end

	--[[
		PORTÉE : Roblox plafonne un projecteur à 60 studs (~17 m), qu'on
		dépasse en une demi-seconde à haute vitesse. Des faisceaux « longue
		portée » prolongent l'éclairage : des sources invisibles posées sur la
		route DEVANT la voiture, éclairant vers le bas, recalées à chaque
		image (elles suivent la voiture quelle que soit sa vitesse) et
		poussées plus loin quand elle accélère.
	]]
	local beams: { { Part: Part, Light: SpotLight, Distance: number } } = {}
	for index, spec in ipairs(LONG_BEAMS) do
		local holder = Instance.new("Part")
		holder.Name = "LongBeam" .. index
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = BEAM_HEIGHT + 20
		light.Angle = 120
		light.Brightness = spec.Brightness
		light.Color = beamColor
		light.Shadows = false
		light.Parent = holder
		holder.Parent = workspace
		table.insert(created, holder)
		table.insert(beams, { Part = holder, Light = light, Distance = spec.Distance })
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local connection = RunService.RenderStepped:Connect(function()
		if not chassis.Parent then
			return
		end
		local look = chassis.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude < 1e-3 then
			return
		end
		forward = forward.Unit
		local speed = math.max(0, chassis.AssemblyLinearVelocity:Dot(forward))
		local stretch = 1 + math.clamp(speed / BEAM_STRETCH_SPEED, 0, 1) * BEAM_STRETCH
		rayParams.FilterDescendantsInstances = { chassis.Parent :: Instance, Players.LocalPlayer.Character :: Instance }
		for _, beam in ipairs(beams) do
			local ahead = chassis.Position + forward * beam.Distance * stretch
			local hit = workspace:Raycast(ahead + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), rayParams)
			local ground = if hit then hit.Position.Y else chassis.Position.Y - 2
			beam.Part.CFrame = CFrame.new(ahead.X, ground + BEAM_HEIGHT, ahead.Z)
		end
	end)
	return function()
		connection:Disconnect()
		for _, item in ipairs(created) do
			item:Destroy()
		end
		chassis:SetAttribute("HeadlightsOn", nil)
	end
end

-- Heures où l'on allume les phares (Lighting.ClockTime) : du crépuscule à l'aube.
local DUSK = 16.5
local DAWN = 7.5

function StageModifier.NeedsHeadlights(): boolean
	local clock = Lighting.ClockTime
	return clock >= DUSK or clock <= DAWN
end

-- Les phares seuls (crépuscule, aube) ; renvoie de quoi les éteindre.
function StageModifier.Headlights(chassis: BasePart): () -> ()
	return headlights(chassis)
end

--[[
	Applique la contrainte `id` à la voiture. Renvoie de quoi tout défaire.
]]
function StageModifier.Apply(car: CarClass.Car, id: string): () -> ()
	local cleanups: { () -> () } = {}
	local restoreLighting = snapshot(Lighting, LIGHTING_PROPERTIES)
	table.insert(cleanups, restoreLighting)

	if id == "Night" then
		Lighting.ClockTime = 0.5
		Lighting.Brightness = 0.4
		Lighting.Ambient = Color3.fromRGB(20, 24, 36)
		Lighting.OutdoorAmbient = Color3.fromRGB(28, 32, 48)
		Lighting.ExposureCompensation = 0.3
		table.insert(cleanups, headlights(car.Chassis))
	elseif id == "Fog" then
		Lighting.FogColor = Color3.fromRGB(196, 200, 206)
		Lighting.FogStart = 8
		Lighting.FogEnd = 150
		Lighting.Brightness = 1.5
	elseif id == "Gear3" then
		car.GearLock = LOCKED_GEAR
		table.insert(cleanups, function()
			car.GearLock = nil
		end)
	elseif id == "NoHandbrake" then
		car.HandbrakeDisabled = true
		table.insert(cleanups, function()
			car.HandbrakeDisabled = false
		end)
	end

	-- Le brouillard du moteur ne se voit pas si une Atmosphere le remplace :
	-- on la met de côté le temps du défi.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and id == "Fog" then
		atmosphere.Parent = nil
		table.insert(cleanups, function()
			atmosphere.Parent = Lighting
		end)
	end
	-- Le ciel peint (nuages en plein soleil) resterait lumineux la nuit et sous
	-- la pluie : sans lui, Roblox affiche son ciel dynamique (étoiles, gris).
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky and (id == "Night" or id == "Fog") then
		sky.Parent = nil
		table.insert(cleanups, function()
			sky.Parent = Lighting
		end)
	end

	return function()
		for i = #cleanups, 1, -1 do
			cleanups[i]()
		end
	end
end

return StageModifier
