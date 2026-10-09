--!strict
--[[
	StageModifier.luau
	Applique chez le pilote la contrainte du défi de la semaine (Weekly.luau),
	pour la durée d'une voiture (DrivingSession) ; tout est rendu à l'état
	d'origine à la fin (Cleanup).

		Nuit         : il fait nuit (éclairage local), phares sur la voiture.
		Pluie        : adhérence de toutes les surfaces × RAIN_GRIP, ciel gris,
		               pluie autour de la caméra.
		Boîte en 3e  : un seul rapport engagé (Car.GearLock).
		Brouillard   : on y voit à quelques dizaines de mètres.
		Sans frein à main : Car.HandbrakeDisabled.

	L'éclairage n'est modifié QUE chez ce joueur (Lighting est local au client
	pour ce qui est réglé côté client) : les autres joueurs gardent leur ciel.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Surfaces = require(ReplicatedStorage.Shared.Vehicle.Surfaces)
local CarClass = require(script.Parent.Parent.Physics.Car)

local StageModifier = {}

local RAIN_GRIP = 0.8
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
	return function()
		for _, item in ipairs(created) do
			item:Destroy()
		end
	end
end

-- Pluie : des traits qui tombent autour de la caméra.
local function rain(): () -> ()
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
	emitter.Rate = 900
	emitter.Size = NumberSequence.new(0.08)
	-- Étirées en traits (Squash < 0 : allongées dans le sens du mouvement).
	emitter.Squash = NumberSequence.new(-2.5)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	emitter.LightEmission = 0.1
	emitter.Parent = holder
	holder.Parent = workspace
	local connection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
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
	elseif id == "Rain" then
		Surfaces.GripScale = RAIN_GRIP
		table.insert(cleanups, function()
			Surfaces.GripScale = 1
		end)
		Lighting.Brightness = 1.2
		Lighting.OutdoorAmbient = Color3.fromRGB(105, 110, 120)
		Lighting.FogColor = Color3.fromRGB(150, 156, 165)
		Lighting.FogStart = 40
		Lighting.FogEnd = 700
		table.insert(cleanups, rain())
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
	if atmosphere and (id == "Fog" or id == "Rain") then
		atmosphere.Parent = nil
		table.insert(cleanups, function()
			atmosphere.Parent = Lighting
		end)
	end

	return function()
		for i = #cleanups, 1, -1 do
			cleanups[i]()
		end
	end
end

return StageModifier
