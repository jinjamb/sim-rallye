--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local CarClass = require(script.Parent.Parent.Physics.Car)
local InputManager = require(script.Parent.InputManager)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local carModel = workspace:WaitForChild("RallyCar") :: Model
local chassis = carModel:WaitForChild("Chassis") :: BasePart
local myRallyCar = CarClass.new(chassis)

-- Réglages caméra
local CAMERA_DISTANCE = 20
local CAMERA_HEIGHT = 7
local CAMERA_LOOK_HEIGHT = 2.5
local CAMERA_SMOOTHING = 9 -- plus haut = caméra plus rigide
local DRIFT_BLEND_SPEED = 15 -- studs/s à partir desquels la caméra suit la trajectoire

-- Le client ne simule que s'il possède le NetworkOwnership du châssis :
-- sinon les impulsions sont écrasées par la réplication et la voiture "élastique".
local hasControl = false
local debugEnabled = false

--------------------------------------------------------------------------------
-- Filtre des raycasts de suspension
--------------------------------------------------------------------------------

-- Roues visuelles, carrosserie, pilote soudé : tout ce qui est solidaire de la
-- voiture doit être exclu, sinon les rayons de suspension tapent dedans au lieu
-- de toucher le sol (un raycast ignore CanCollide).
local function refreshIgnoreList()
	local ignore: {Instance} = {carModel}
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	myRallyCar:SetIgnoreList(ignore)
end

refreshIgnoreList()
player.CharacterAdded:Connect(function()
	task.defer(refreshIgnoreList)
end)

--------------------------------------------------------------------------------
-- Contrôles du personnage
--------------------------------------------------------------------------------

-- PlayerModule est le contrôleur par défaut de Roblox (clavier, mobile, manette).
-- On le coupe entièrement pendant la conduite, sinon ZQSD pilote aussi l'avatar.
local controls: any = nil
task.spawn(function()
	local ok, result = pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule")) :: any
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
		if hasControl then
			controls:Disable()
		end
	else
		warn("[Car] PlayerModule introuvable, les contrôles de l'avatar restent actifs")
	end
end)

local function setCharacterControlsEnabled(enabled: boolean)
	if not controls then
		return
	end
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

--------------------------------------------------------------------------------
-- Caméra
--------------------------------------------------------------------------------

local function enterDrivingCamera()
	camera.CameraType = Enum.CameraType.Scriptable
end

local function exitDrivingCamera()
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

RunService:BindToRenderStep("RallyCamera", Enum.RenderPriority.Camera.Value, function(dt: number)
	if not hasControl then
		return
	end

	local chassisCFrame = chassis.CFrame
	local velocity = chassis.AssemblyLinearVelocity

	-- En dessous du seuil on suit le nez de la voiture ; au-dessus on mélange avec
	-- la direction réelle du déplacement, ce qui garde la trajectoire dans le champ
	-- quand la voiture part en travers (et évite un fouetté de caméra en drift).
	local lookDirection = chassisCFrame.LookVector
	if velocity.Magnitude > DRIFT_BLEND_SPEED then
		local blended = lookDirection:Lerp(velocity.Unit, 0.5)
		if blended.Magnitude > 0.01 then
			lookDirection = blended.Unit
		end
	end

	local targetPosition = chassisCFrame.Position
		- lookDirection * CAMERA_DISTANCE
		+ Vector3.yAxis * CAMERA_HEIGHT
	local target = CFrame.lookAt(targetPosition, chassisCFrame.Position + Vector3.yAxis * CAMERA_LOOK_HEIGHT)

	-- Lissage indépendant du framerate.
	local alpha = 1 - math.exp(-CAMERA_SMOOTHING * dt)
	camera.CFrame = camera.CFrame:Lerp(target, alpha)
end)

--------------------------------------------------------------------------------
-- Prise / perte de contrôle
--------------------------------------------------------------------------------

Remotes.CarControlChanged.OnClientEvent:Connect(function(targetChassis: BasePart, granted: boolean)
	if targetChassis ~= chassis then
		return
	end
	if granted == hasControl then
		return
	end

	hasControl = granted

	if granted then
		-- La caméra part de sa position actuelle et glisse vers la voiture.
		refreshIgnoreList()
		enterDrivingCamera()
		setCharacterControlsEnabled(false)
		print("[Car] Contrôle accordé — Q pour descendre, F2 pour le diagnostic")
	else
		exitDrivingCamera()
		setCharacterControlsEnabled(true)
		print("[Car] Contrôle perdu")
	end
end)

-- Le personnage qui réapparaît reçoit un nouveau Humanoid : on réaligne la caméra.
player.CharacterAdded:Connect(function()
	if not hasControl then
		task.defer(exitDrivingCamera)
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.RequestCarControl:FireServer(chassis)
	elseif input.KeyCode == Enum.KeyCode.Q then
		Remotes.ReleaseCarControl:FireServer()
	elseif input.KeyCode == Enum.KeyCode.F2 then
		debugEnabled = not debugEnabled
		print("[Car] Diagnostic", if debugEnabled then "activé" else "désactivé")
	end
end)

-- Demande initiale (le serveur refusera si le personnage est trop loin : appuyer sur E).
Remotes.RequestCarControl:FireServer(chassis)

--------------------------------------------------------------------------------
-- Diagnostic (F2)
--------------------------------------------------------------------------------

local debugAccumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
	if not debugEnabled then
		return
	end
	debugAccumulator += dt
	if debugAccumulator < 0.5 then
		return
	end
	debugAccumulator = 0

	local inputs = InputManager:GetInputs()
	local grounded = 0
	local totalLoad = 0
	for _, wheel in ipairs(myRallyCar.Wheels) do
		if wheel.IsGrounded then
			grounded += 1
			totalLoad += wheel.NormalForce
		end
	end

	print(string.format(
		"[Car] contrôle=%s | throttle=%.0f brake=%.0f steer=%.0f | roues au sol=%d/4 charge=%.0f (poids=%.0f) | vitesse=%.1f",
		tostring(hasControl),
		inputs.throttle,
		inputs.brake,
		inputs.steer,
		grounded,
		totalLoad,
		chassis.AssemblyMass * workspace.Gravity,
		chassis.AssemblyLinearVelocity.Magnitude
	))
end)

--------------------------------------------------------------------------------
-- Boucle physique
--------------------------------------------------------------------------------

-- PreSimulation (ex-Stepped) : les impulsions sont appliquées AVANT le pas de
-- simulation, contrairement à Heartbeat qui tourne après (une frame de retard).
-- Un à-coup de frame (chargement, alt-tab, hitch Studio) produit un dt énorme qui
-- fait diverger l'intégration explicite de la suspension -> la voiture part en
-- tonneau. On plafonne le pas : la physique ralentit au lieu d'exploser.
local MAX_PHYSICS_STEP = 1 / 30

RunService.PreSimulation:Connect(function(dt: number)
	if not hasControl then
		return
	end
	local step = math.min(dt, MAX_PHYSICS_STEP)
	local inputs = InputManager:GetInputs()
	myRallyCar:Update(step, inputs)
end)
