--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Units = require(ReplicatedStorage.Shared.Constants.Units)
local CarClass = require(script.Parent.Parent.Physics.Car)
local InputManager = require(script.Parent.InputManager)
local Dashboard = require(script.Parent.Dashboard)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local StageTimer = require(script.Parent.StageTimer)
local ChaseCamera = require(script.Parent.ChaseCamera)
local CarEffects = require(script.Parent.CarEffects)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Toute la calibration (suspension, freins, aéro) est déduite du poids au moment
-- de Car.new : une gravité qui ne correspond pas à l'échelle fausse tout en silence.
-- Elle est réglée dans default.project.json ; si Rojo n'a pas synchronisé le place,
-- on le dit plutôt que de rouler sur une physique 5.6 fois trop adhérente.
if math.abs(workspace.Gravity - Units.REAL_GRAVITY) > 0.5 then
	warn(string.format(
		"[Car] workspace.Gravity = %.1f, attendu %.1f (gravité réelle à %.2f m/stud). Synchronise le place avec Rojo.",
		workspace.Gravity,
		Units.REAL_GRAVITY,
		Units.METERS_PER_STUD
	))
end

local carModel = workspace:WaitForChild("RallyCar") :: Model
local chassis = carModel:WaitForChild("Chassis") :: BasePart
local myRallyCar = CarClass.new(chassis)
local dashboard = Dashboard.new(myRallyCar, player:WaitForChild("PlayerGui"))
local carAudio = CarAudio.new(myRallyCar)
local stageTimer = StageTimer.new(myRallyCar, player:WaitForChild("PlayerGui"))

local chaseCamera = ChaseCamera.new(myRallyCar, camera)
local carEffects = CarEffects.new(myRallyCar)

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
	chaseCamera:Enter()
end

local function exitDrivingCamera()
	chaseCamera:Exit()
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
	if hasControl then
		chaseCamera:Update(dt)
	end
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
		dashboard:SetVisible(true)
		carAudio:SetActive(true)
		carEffects:SetActive(true)
		stageTimer:SetVisible(true)
		print("[Car] Contrôle accordé — Q / croix bas pour descendre, R/F ou B/X ou RB/LB rapports, M / Y boîte auto/manuelle, T / croix gauche remise en piste, Retour arrière / bouton Vue recommencer la spéciale, F2 télémétrie, F3 journal console")
	else
		exitDrivingCamera()
		setCharacterControlsEnabled(true)
		dashboard:SetVisible(false)
		carAudio:SetActive(false)
		carEffects:SetActive(false)
		stageTimer:SetVisible(false)
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
	local key = input.KeyCode
	if key == Enum.KeyCode.E or key == Enum.KeyCode.DPadUp then
		Remotes.RequestCarControl:FireServer(chassis)
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.DPadDown then
		Remotes.ReleaseCarControl:FireServer()
	elseif key == Enum.KeyCode.F2 then
		dashboard:ToggleDetail()
	elseif key == Enum.KeyCode.F3 then
		-- Le journal reste utile pour garder une trace écrite d'un essai.
		debugEnabled = not debugEnabled
		print("[Car] Journal console", if debugEnabled then "activé" else "désactivé")
	elseif not hasControl then
		return
	-- Manette : B / RB montent, X / LB descendent (deux jeux de palettes, au choix).
	elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.ButtonR1 then
		myRallyCar:ShiftUp()
	elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonX or key == Enum.KeyCode.ButtonL1 then
		myRallyCar:ShiftDown()
	elseif key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonY then
		local automatic = myRallyCar:ToggleAutomatic()
		print("[Car] Boîte", if automatic then "automatique" else "manuelle")
	elseif key == Enum.KeyCode.T or key == Enum.KeyCode.DPadLeft then
		stageTimer:Recover()
	elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonSelect then
		stageTimer:Restart()
	end
end)

-- Demande initiale (le serveur refusera si le personnage est trop loin : appuyer sur E).
Remotes.RequestCarControl:FireServer(chassis)

--------------------------------------------------------------------------------
-- Tableau de bord (F2 : télémétrie détaillée)
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt: number)
	if hasControl then
		dashboard:Update(dt)
		carAudio:Update(dt)
		carEffects:Update(dt)
		stageTimer:Update(dt)
	end
end)

--------------------------------------------------------------------------------
-- Journal console (F3)
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
	local maxSlip = 0
	local maxUsage = 0
	for _, wheel in ipairs(myRallyCar.Wheels) do
		if wheel.IsGrounded then
			grounded += 1
			totalLoad += wheel.NormalForce
		end
		maxSlip = math.max(maxSlip, math.abs(wheel.SlipRatio))
		maxUsage = math.max(maxUsage, wheel.FrictionUsage)
	end

	-- Surface sous chaque roue : un seul nom si les quatre sont d'accord, sinon le
	-- détail (utile en travers d'une limite de surface, ou sur une bande split-mu).
	local surfaceNames: { string } = {}
	local sameSurface = true
	for i, suffix in ipairs({ "FL", "FR", "RL", "RR" }) do
		local wheel = myRallyCar.WheelsByName["Wheel" .. suffix]
		local name = if wheel.IsGrounded
			then string.format("%s %.2f", wheel.Surface.Name, wheel.Surface.Grip)
			else "en l'air"
		surfaceNames[i] = name
		if name ~= surfaceNames[1] then
			sameSurface = false
		end
	end
	local surfaceLabel = if sameSurface
		then surfaceNames[1]
		else string.format("AVG %s / AVD %s / ARG %s / ARD %s", table.unpack(surfaceNames))

	local powertrain = myRallyCar.Powertrain
	local gearbox = powertrain.Gearbox
	local gearLabel = if gearbox.Gear == -1 then "R" elseif gearbox.Gear == 0 then "N" else tostring(gearbox.Gear)
	local flags = (if gearbox:IsShifting() then " passage" else "")
		.. (if powertrain.ClutchSlipping then " embrayage-patine" else "")
		.. (if powertrain.FuelCut then " RUPTEUR" else "")

	print(string.format(
		"[Car] %s throttle=%.2f brake=%.2f steer=%+.2f%s | sol=%d/4 charge=%.0f (poids=%.0f) | surface=%s | %.0f km/h | %s %s %.0f tr/min%s | glissement=%.2f | cercle=%.0f%%",
		InputManager:GetActiveSource(),
		inputs.throttle,
		inputs.brake,
		inputs.steer,
		if inputs.handbrake then " FREIN-À-MAIN" else "",
		grounded,
		totalLoad,
		chassis.AssemblyMass * workspace.Gravity,
		surfaceLabel,
		Units.ToKmh(chassis.AssemblyLinearVelocity.Magnitude),
		if gearbox.Automatic then "A" else "M",
		gearLabel,
		powertrain.EngineRPM,
		flags,
		maxSlip,
		maxUsage * 100
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
	-- Les rampes du clavier avancent ici, une seule fois par pas physique.
	local inputs = InputManager:Update(step, myRallyCar:GetForwardSpeed())
	myRallyCar:Update(step, inputs)
end)
