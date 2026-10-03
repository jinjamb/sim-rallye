--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Units = require(ReplicatedStorage.Shared.Constants.Units)
local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)
local CarClass = require(script.Parent.Parent.Physics.Car)
local InputManager = require(script.Parent.InputManager)
local Dashboard = require(script.Parent.Dashboard)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local StageTimer = require(script.Parent.StageTimer)
local ChaseCamera = require(script.Parent.ChaseCamera)
local CarEffects = require(script.Parent.CarEffects)
local Copilot = require(script.Parent.Copilot)
local RemoteCars = require(script.Parent.RemoteCars)
local Ghost = require(script.Parent.Ghost)
local Leaderboard = require(script.Parent.Leaderboard)
local SetupMenu = require(script.Parent.SetupMenu)
local TouchControls = require(script.Parent.TouchControls)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

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

-- Les voitures des autres joueurs vivent dès maintenant, même à pied.
local remoteCars = RemoteCars.new(player.UserId)
RunService.RenderStepped:Connect(function(dt: number)
	remoteCars:Update(dt)
end)

--------------------------------------------------------------------------------
-- Sa propre voiture : créée par le serveur (CarService) à l'arrivée du joueur
--------------------------------------------------------------------------------

local function waitForOwnCar(): Model
	while true do
		for _, child in ipairs(workspace:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("OwnerUserId") == player.UserId then
				return child
			end
		end
		workspace.ChildAdded:Wait()
	end
end

local carModel = waitForOwnCar()
local chassis = carModel:WaitForChild("Chassis") :: BasePart
local myRallyCar = CarClass.new(chassis)

local wheelAttachments: { Attachment } = {}
for i, wheel in ipairs(myRallyCar.Wheels) do
	wheelAttachments[i] = wheel.Attachment
end

local dashboard = Dashboard.new(myRallyCar, playerGui)
local carAudio = CarAudio.new(chassis, wheelAttachments, true)
local stageTimer = StageTimer.new(myRallyCar, playerGui)
local copilot = Copilot.new(myRallyCar, playerGui)
local chaseCamera = ChaseCamera.new(myRallyCar, camera)
local carEffects = CarEffects.new(chassis, myRallyCar.Wheels :: any)
local ghost = Ghost.new(chassis)
local leaderboard = Leaderboard.new(playerGui, player.UserId)

-- Le client ne simule que s'il possède le NetworkOwnership du châssis :
-- sinon les impulsions sont écrasées par la réplication et la voiture "élastique".
local hasControl = false
local debugEnabled = false

--------------------------------------------------------------------------------
-- Réglages de la voiture (menu P), sauvegardés côté serveur
--------------------------------------------------------------------------------

local SETUP_SAVE_DELAY = 1.5 -- regroupe une rafale de clics en une seule sauvegarde
local setupSaveToken = 0

local setupMenu = SetupMenu.new(playerGui, function(setup: CarSetup.Setup)
	myRallyCar:ApplySetup(setup)
	setupSaveToken += 1
	local token = setupSaveToken
	task.delay(SETUP_SAVE_DELAY, function()
		if token == setupSaveToken then
			Remotes.SaveSetup:FireServer(setup)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Temps officiels, record perso, fantôme, classement (RecordService)
--------------------------------------------------------------------------------

-- Le verdict du serveur peut arriver juste AVANT que le chrono local ne voie la
-- ligne : l'envoi du fantôme attend alors la fin de l'enregistrement.
local ghostUploadPending = false

local function uploadGhost()
	local recording = ghost.LastRecording
	if recording then
		Remotes.SubmitGhost:FireServer(recording)
		ghost:SetBest(recording)
	end
end

stageTimer.OnRunStarted = function()
	ghostUploadPending = false
	ghost:StartRun()
end
stageTimer.OnRunFinished = function(_seconds: number)
	ghost:FinishRun()
	if ghostUploadPending then
		ghostUploadPending = false
		uploadGhost()
	end
end
stageTimer.OnRunCancelled = function()
	ghostUploadPending = false
	ghost:CancelRun()
end

Remotes.ProfileLoaded.OnClientEvent:Connect(function(profile: any)
	if type(profile) ~= "table" then
		return
	end
	stageTimer:SetPersonalBest(if type(profile.BestMs) == "number" then profile.BestMs else nil)
	if type(profile.Ghost) == "table" then
		ghost:SetBest(profile.Ghost)
	end
	local setup = CarSetup.Sanitize(profile.Setup)
	myRallyCar:ApplySetup(setup)
	setupMenu:SetSetup(setup)
end)

Remotes.RunValidated.OnClientEvent:Connect(function(result: any)
	stageTimer:SetOfficialResult(result)
	if type(result) == "table" and result.Valid and result.PersonalBest then
		if ghost.LastRecording then
			uploadGhost()
		else
			ghostUploadPending = true
		end
	end
end)

Remotes.Leaderboard.OnClientEvent:Connect(function(entries: any)
	if type(entries) == "table" then
		leaderboard:SetEntries(entries)
	end
end)

--------------------------------------------------------------------------------
-- Filtre des raycasts de suspension
--------------------------------------------------------------------------------

-- Roues visuelles, carrosserie, pilote soudé : tout ce qui est solidaire de la
-- voiture doit être exclu, sinon les rayons de suspension tapent dedans au lieu
-- de toucher le sol (un raycast ignore CanCollide). Les autres voitures sont
-- traversées grâce au groupe de collision (voir Wheel.luau).
local function refreshIgnoreList()
	local ignore: { Instance } = { carModel }
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	myRallyCar:SetIgnoreList(ignore)
end

refreshIgnoreList()

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
-- Actions, communes au clavier, à la manette et à l'écran tactile
--------------------------------------------------------------------------------

local actions: TouchControls.Actions = {
	ShiftUp = function()
		if hasControl then
			myRallyCar:ShiftUp()
		end
	end,
	ShiftDown = function()
		if hasControl then
			myRallyCar:ShiftDown()
		end
	end,
	ToggleMode = function()
		if hasControl then
			local automatic = myRallyCar:ToggleAutomatic()
			print("[Car] Boîte", if automatic then "automatique" else "manuelle")
		end
	end,
	Recover = function()
		if hasControl then
			stageTimer:Recover()
		end
	end,
	Restart = function()
		if hasControl then
			stageTimer:Restart()
		end
	end,
	ToggleSetup = function()
		setupMenu:Toggle()
	end,
	ToggleLeaderboard = function()
		leaderboard:Toggle()
	end,
	EnterCar = function()
		Remotes.RequestCarControl:FireServer(chassis)
	end,
	ExitCar = function()
		Remotes.ReleaseCarControl:FireServer()
	end,
}

-- Téléphone ou tablette : commandes à l'écran, et l'interface se range autour.
local touchControls: TouchControls.TouchControls? = nil
if TouchControls.IsTouchDevice() then
	local created = TouchControls.new(playerGui, actions)
	created:SetDriving(false)
	touchControls = created
	dashboard:SetTouchLayout(true)
	stageTimer:SetTouchLayout(true)
	copilot:SetTouchLayout(true)
	leaderboard:SetTouchLayout(true)
	setupMenu:SetTouchLayout(true)
	RunService.RenderStepped:Connect(function()
		created:Update()
	end)
end

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
	if touchControls then
		touchControls:SetDriving(granted)
	end

	if granted then
		-- La caméra part de sa position actuelle et glisse vers la voiture.
		refreshIgnoreList()
		chaseCamera:Enter()
		setCharacterControlsEnabled(false)
		dashboard:SetVisible(true)
		carAudio:SetActive(true)
		carEffects:SetActive(true)
		stageTimer:SetVisible(true)
		copilot:SetVisible(true)
		leaderboard:SetVisible(true)
		ghost:SetVisible(true)
		print("[Car] Au volant — R/F rapports, M boîte auto/manuelle, T remise en piste, Retour arrière recommencer, P réglages, L classement, Q descendre de voiture, F2 télémétrie, F3 journal")
	else
		exitDrivingCamera()
		setCharacterControlsEnabled(true)
		dashboard:SetVisible(false)
		carAudio:SetActive(false)
		carEffects:SetActive(false)
		stageTimer:SetVisible(false)
		copilot:SetVisible(false)
		leaderboard:SetVisible(false)
		ghost:SetVisible(false)
		print("[Car] Hors de la voiture — E pour reprendre le volant")
	end
end)

-- Personnage qui réapparaît : nouveau Humanoid pour la caméra, et la voiture
-- vient le rechercher.
player.CharacterAdded:Connect(function()
	task.defer(refreshIgnoreList)
	if not hasControl then
		task.defer(exitDrivingCamera)
	end
	task.delay(1, function()
		Remotes.RequestCarControl:FireServer(chassis)
	end)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.E or key == Enum.KeyCode.DPadUp then
		actions.EnterCar()
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.DPadDown then
		actions.ExitCar()
	elseif key == Enum.KeyCode.F2 then
		dashboard:ToggleDetail()
	elseif key == Enum.KeyCode.F3 then
		-- Le journal reste utile pour garder une trace écrite d'un essai.
		debugEnabled = not debugEnabled
		print("[Car] Journal console", if debugEnabled then "activé" else "désactivé")
	elseif key == Enum.KeyCode.P or key == Enum.KeyCode.ButtonL3 then
		actions.ToggleSetup()
	elseif key == Enum.KeyCode.L or key == Enum.KeyCode.ButtonR3 then
		actions.ToggleLeaderboard()
	-- Manette : B / RB montent, X / LB descendent (deux jeux de palettes, au choix).
	elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.ButtonR1 then
		actions.ShiftUp()
	elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonX or key == Enum.KeyCode.ButtonL1 then
		actions.ShiftDown()
	elseif key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonY then
		actions.ToggleMode()
	elseif key == Enum.KeyCode.T or key == Enum.KeyCode.DPadLeft then
		actions.Recover()
	elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonSelect then
		actions.Restart()
	end
end)

-- Demande initiale : le serveur ne laisse prendre que SA voiture, où qu'on soit.
Remotes.RequestCarControl:FireServer(chassis)

--------------------------------------------------------------------------------
-- Affichage, son, effets, fantôme, télémétrie
--------------------------------------------------------------------------------

local TELEMETRY_INTERVAL = 0.1 -- 10 Hz : assez pour le son et les roues des autres
local telemetryAccumulator = 0

RunService.RenderStepped:Connect(function(dt: number)
	if not hasControl then
		return
	end
	local audioState = CarAudio.StateFromCar(myRallyCar)
	dashboard:Update(dt)
	carAudio:Update(dt, audioState)
	carEffects:Update(dt)
	stageTimer:Update(dt)
	ghost:Update(dt)
	-- Le copilote réutilise l'avancement que le chrono vient de calculer.
	copilot:Update(dt, stageTimer.LastProgress)
	leaderboard:Update()

	-- Ce que les autres joueurs entendent et voient de cette voiture (CarService).
	telemetryAccumulator += dt
	if telemetryAccumulator >= TELEMETRY_INTERVAL then
		telemetryAccumulator = 0
		local screech = 0
		for _, level in ipairs(audioState.Screech) do
			screech = math.max(screech, level)
		end
		Remotes.CarTelemetry:FireServer(
			audioState.Rpm,
			audioState.Load,
			InputManager:GetInputs().steer,
			screech,
			audioState.GravelSlide,
			audioState.GravelShare,
			audioState.TarmacShare
		)
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
