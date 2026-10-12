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

local StageModifier = {}


-- Faisceaux longue portée des phares (voir headlights) : distance devant la
-- voiture (studs, à l'arrêt) et puissance, qui baisse au loin.
local LONG_BEAMS = {
	{ Distance = 45, Brightness = 3 },
	{ Distance = 85, Brightness = 2.4 },
	{ Distance = 125, Brightness = 1.8 },
	{ Distance = 165, Brightness = 1.3 },
}
local BEAM_HEIGHT = 22 -- au-dessus de la route
local BEAM_STRETCH = 0.6 -- jusqu'à +60 % de distance...
local BEAM_STRETCH_SPEED = 150 -- ... à 150 studs/s (~150 km/h)
local LOCKED_GEAR = 3

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

-- Phares : deux projecteurs à l'avant du châssis (l'avant est en -Z).
local function headlights(chassis: BasePart): () -> ()
	local created: { Instance } = {}
	local half = chassis.Size
	for _, side in ipairs({ -1, 1 }) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Headlight"
		attachment.Position = Vector3.new(side * half.X * 0.32, 0.2, -half.Z / 2)
		attachment.Orientation = Vector3.new(-6, 0, 0)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 60
		light.Angle = 70
		light.Brightness = 6
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Parent = attachment
		attachment.Parent = chassis
		table.insert(created, attachment)
	end
	-- Un halo autour de la voiture, pour voir les bas-côtés.
	local glow = Instance.new("PointLight")
	glow.Range = 18
	glow.Brightness = 0.6
	glow.Color = Color3.fromRGB(255, 240, 210)
	glow.Parent = chassis
	table.insert(created, glow)

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
		light.Color = Color3.fromRGB(255, 244, 220)
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
	end
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
