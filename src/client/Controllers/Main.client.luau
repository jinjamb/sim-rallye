--!strict
--[[
	Main.client.luau
	Point d'entrée du client.

	Ce qui dure toute la partie vit ici : voitures des autres joueurs, menus
	(réglages, rallycross), classement de la spéciale, commandes tactiles,
	profil chargé. Ce qui dépend d'UNE voiture vit dans une session de conduite
	(DrivingSession.luau) : le serveur recrée la voiture à chaque changement de
	lieu (paddock -> grille de départ -> paddock), et une session neuve est
	créée pour chaque nouvelle voiture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Units = require(ReplicatedStorage.Shared.Constants.Units)
local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)
local InputManager = require(script.Parent.InputManager)
local RemoteCars = require(script.Parent.RemoteCars)
local Leaderboard = require(script.Parent.Leaderboard)
local SetupMenu = require(script.Parent.SetupMenu)
local TouchControls = require(script.Parent.TouchControls)
local DrivingSession = require(script.Parent.DrivingSession)
local GhostChallenge = require(script.Parent.GhostChallenge)
local RaceClient = require(script.Parent.Parent.Race.RaceClient)
local Garage = require(script.Parent.Parent.Race.Garage)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- Identité visuelle (Theme.luau) : tous les écrans du joueur, et les panneaux
-- du paddock, prennent les polices du thème.
Theme.Skin(playerGui)
task.spawn(function()
	local paddock = workspace:WaitForChild("Paddock", 30)
	if paddock then
		Theme.Skin(paddock)
	end
end)

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

local isTouch = TouchControls.IsTouchDevice()

--------------------------------------------------------------------------------
-- Ce qui dure toute la partie
--------------------------------------------------------------------------------

-- Les voitures des autres joueurs vivent dès maintenant, même à pied.
local remoteCars = RemoteCars.new(player.UserId)

local session: DrivingSession.DrivingSession? = nil
local sessionToken = 0
local debugEnabled = false

-- Profil (chargé par le serveur), gardé d'une voiture à l'autre.
local currentSetup: CarSetup.Setup = CarSetup.Default()
local stageBestMs: number? = nil
local stageGhost: any = nil

-- Défi du fantôme : contre qui on roule sur la spéciale. Le choix dure toute
-- la partie et suit le joueur d'une voiture à l'autre.
local leaderboard: Leaderboard.Leaderboard
local ghostChallenge = GhostChallenge.new(function(challenge)
	local current = session
	if current then
		current:SetGhostChoice(challenge.Opponent, challenge:IsHidden())
	end
	leaderboard:SetGhostInfo(challenge:Describe())
end)
leaderboard = Leaderboard.new(playerGui, player.UserId, function(userId: number)
	ghostChallenge:Challenge(userId, player.UserId)
end)

local function hasControl(): boolean
	local current = session
	return current ~= nil and current.HasControl
end

local function isRacing(): boolean
	local current = session
	return current ~= nil and current:IsRacing()
end

--------------------------------------------------------------------------------
-- Réglages de la voiture (menu P), sauvegardés côté serveur
--------------------------------------------------------------------------------

local SETUP_SAVE_DELAY = 1.5 -- regroupe une rafale de clics en une seule sauvegarde
local setupSaveToken = 0

local setupMenu = SetupMenu.new(playerGui, function(setup: CarSetup.Setup)
	currentSetup = setup
	local current = session
	if current then
		current.Car:ApplySetup(setup)
	end
	setupSaveToken += 1
	local token = setupSaveToken
	task.delay(SETUP_SAVE_DELAY, function()
		if token == setupSaveToken then
			Remotes.SaveSetup:FireServer(setup)
		end
	end)
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
		if hasControl() then
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
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

--------------------------------------------------------------------------------
-- Rallycross : menu, affichage de course, spectateur
--------------------------------------------------------------------------------

local raceClient = RaceClient.new({
	PlayerGui = playerGui,
	Camera = camera,
	LocalUserId = player.UserId,
	GetOtherCars = function()
		return remoteCars:GetVisibleCars()
	end,
	OnSpectateStopped = function()
		local current = session
		if current and current.HasControl then
			current.ChaseCamera:Enter()
		else
			exitDrivingCamera()
		end
	end,
})

-- Garage du paddock (zone violette) : livrée et réglages, voiture en aperçu.
local garage = Garage.new(playerGui, {
	GetLivery = function()
		return raceClient:GetLivery()
	end,
	SetLivery = function(livery)
		raceClient:SaveLivery(livery)
	end,
	GetProgress = function()
		return raceClient:GetProgress()
	end,
	OpenSetup = function()
		setupMenu:SetOpen(true)
	end,
})

RunService:BindToRenderStep("RallyCamera", Enum.RenderPriority.Camera.Value, function(dt: number)
	if raceClient:UpdateCamera(dt) then
		return
	end
	local current = session
	if current and current.HasControl then
		current.ChaseCamera:Update(dt)
	end
end)

--------------------------------------------------------------------------------
-- Actions, communes au clavier, à la manette et à l'écran tactile
--------------------------------------------------------------------------------

local function drivingSession(): DrivingSession.DrivingSession?
	local current = session
	if current and current.HasControl and not current.Parked then
		return current
	end
	return nil
end

local actions: TouchControls.Actions = {
	ShiftUp = function()
		local current = drivingSession()
		if current then
			current.Car:ShiftUp()
		end
	end,
	ShiftDown = function()
		local current = drivingSession()
		if current then
			current.Car:ShiftDown()
		end
	end,
	ToggleMode = function()
		local current = drivingSession()
		if current then
			local automatic = current.Car:ToggleAutomatic()
			print("[Car] Boîte", if automatic then "automatique" else "manuelle")
		end
	end,
	Recover = function()
		local current = drivingSession()
		if current then
			current:Recover()
		end
	end,
	Restart = function()
		local current = drivingSession()
		if current then
			current:Restart()
		end
	end,
	ToggleSetup = function()
		setupMenu:Toggle()
	end,
	ToggleLeaderboard = function()
		leaderboard:Toggle()
	end,
	-- Fantôme suivant (le sien, le rival, le record, aucun) : spéciale seulement.
	CycleGhost = function()
		if not isRacing() then
			ghostChallenge:Cycle()
		end
	end,
	ToggleRaceMenu = function()
		raceClient:ToggleMenu()
	end,
	-- Essais libres, spéciale, ou à pied loin : retour à pied au paddock.
	-- En course, le serveur l'ignore (on abandonne depuis le menu).
	ReturnToPaddock = function()
		if isRacing() then
			raceClient:ToggleMenu()
			return
		end
		Remotes.ReturnToPaddock:FireServer()
	end,
	EnterCar = function()
		local current = session
		if current then
			Remotes.RequestCarControl:FireServer(current.Chassis)
		else
			print("[Paddock] Pas de voiture : C (menu) pour lancer une spéciale, une course de rallycross ou des essais libres")
		end
	end,
	ExitCar = function()
		-- En course, on ne descend pas de voiture : on abandonne depuis le menu.
		if isRacing() then
			raceClient:ToggleMenu()
			return
		end
		Remotes.ReleaseCarControl:FireServer()
	end,
}

-- Téléphone ou tablette : commandes à l'écran, et l'interface se range autour.
local touchControls: TouchControls.TouchControls? = nil
if isTouch then
	local created = TouchControls.new(playerGui, actions)
	created:SetDriving(false)
	touchControls = created
	leaderboard:SetTouchLayout(true)
	setupMenu:SetTouchLayout(true)
	raceClient:SetTouchLayout(true)
	garage:SetTouchLayout(true)
end

--------------------------------------------------------------------------------
-- Prise / perte de contrôle, sessions de conduite
--------------------------------------------------------------------------------

-- L'interface suit l'état : au volant ou à pied, au paddock ou en course.
local function applyDrivingUi()
	local current = session
	local driving = hasControl()
	local racing = isRacing()
	leaderboard:SetVisible(driving and not racing)
	local touch = touchControls
	if touch then
		touch:SetDriving(driving)
		touch:SetRaceMode(racing)
		touch:SetCarAvailable(current ~= nil)
	end
	remoteCars:SetLocalRaceId(if current then current.RaceId else nil)
	raceClient:SetMyChassis(if current then current.Chassis else nil)
end

local function setControl(granted: boolean)
	local current = session
	if not current or current.HasControl == granted then
		return
	end
	current:SetControl(granted)
	if granted then
		setCharacterControlsEnabled(false)
		if current:IsRacing() then
			print("[Car] En course — R/F rapports, M boîte, T remise en piste, C menu (abandon), V spectateur après l'arrivée")
		else
			print("[Car] Au volant — R/F rapports, M boîte auto/manuelle, T remise en piste, Retour arrière recommencer, P réglages, L classement, G fantôme (le tien, ton rival, le record), C menu, H retour au paddock, Q descendre, F2 télémétrie, F3 journal")
		end
	else
		if not raceClient:IsSpectating() then
			exitDrivingCamera()
		end
		setCharacterControlsEnabled(true)
		print("[Car] Hors de la voiture — E pour reprendre le volant, C pour le menu")
	end
	applyDrivingUi()
end

Remotes.CarControlChanged.OnClientEvent:Connect(function(targetChassis: BasePart?, granted: boolean)
	-- Une voiture pas encore reçue (recréée à l'instant) arrive en nil : la
	-- session la réclamera elle-même dès qu'elle sera prête.
	local current = session
	if current and targetChassis == current.Chassis then
		setControl(granted)
	end
end)

local function endSession()
	local current = session
	if not current then
		return
	end
	session = nil
	-- Le meilleur temps et le fantôme ont pu changer pendant cette session.
	local timer, ghost = current.StageTimer, current.Ghost
	if timer and timer.BestTime then
		stageBestMs = math.floor((timer.BestTime :: number) * 1000 + 0.5)
	end
	if ghost and ghost.Best then
		stageGhost = ghost.Best
	end
	raceClient:StopSpectating()
	local hadControl = current.HasControl
	current:Destroy()
	if hadControl then
		exitDrivingCamera()
		setCharacterControlsEnabled(true)
	end
	applyDrivingUi()
end

local function startSession(model: Model)
	endSession()
	sessionToken += 1
	local token = sessionToken
	local ok, result = pcall(DrivingSession.new, model, {
		PlayerGui = playerGui,
		Camera = camera,
		TouchLayout = isTouch,
		Setup = currentSetup,
		StageBestMs = stageBestMs,
		StageGhost = stageGhost,
		GhostOpponent = ghostChallenge.Opponent,
		GhostHidden = ghostChallenge:IsHidden(),
	})
	if not ok then
		warn("[Car] Session de conduite impossible :", result)
		return
	end
	local created = result :: DrivingSession.DrivingSession
	-- Une voiture plus récente est arrivée, ou celle-ci a déjà disparu.
	if token ~= sessionToken or model.Parent ~= workspace then
		created:Destroy()
		return
	end
	session = created
	applyDrivingUi()
	-- Le serveur donne le volant dès l'apparition, mais son message a pu
	-- arriver avant la voiture : on le redemande (sans effet si déjà accordé).
	Remotes.RequestCarControl:FireServer(created.Chassis)
	task.delay(1.5, function()
		if session == created and not created.HasControl then
			Remotes.RequestCarControl:FireServer(created.Chassis)
		end
	end)
end

local function isOwnCar(instance: Instance): boolean
	return instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId
end

workspace.ChildAdded:Connect(function(child: Instance)
	if isOwnCar(child) then
		task.spawn(startSession, child :: Model)
	end
end)
workspace.ChildRemoved:Connect(function(child: Instance)
	local current = session
	if current and child == current.Model then
		endSession()
	end
end)
for _, child in ipairs(workspace:GetChildren()) do
	if isOwnCar(child) then
		task.spawn(startSession, child :: Model)
		break
	end
end

-- Personnage qui réapparaît : nouveau Humanoid pour la caméra, et la voiture
-- vient le rechercher.
player.CharacterAdded:Connect(function()
	task.defer(function()
		local current = session
		if current then
			current:RefreshIgnoreList()
		end
		if not hasControl() and not raceClient:IsSpectating() then
			exitDrivingCamera()
		end
	end)
	task.delay(1, function()
		local current = session
		if current then
			Remotes.RequestCarControl:FireServer(current.Chassis)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Profil, temps officiels, classements
--------------------------------------------------------------------------------

Remotes.ProfileLoaded.OnClientEvent:Connect(function(profile: any)
	if type(profile) ~= "table" then
		return
	end
	stageBestMs = if type(profile.BestMs) == "number" then profile.BestMs else nil
	stageGhost = if type(profile.Ghost) == "table" then profile.Ghost else nil
	currentSetup = CarSetup.Sanitize(profile.Setup)
	setupMenu:SetSetup(currentSetup)
	local current = session
	if current then
		current.Car:ApplySetup(currentSetup)
		current:SetStageProfile(stageBestMs, stageGhost)
	end
	raceClient:SetProfile(profile.Stats, profile.Laps)
	raceClient:SetLivery(profile.Livery)
end)

print("[Paddock] Bienvenue ! C : menu (spéciale, rallycross, essais libres, records). Au paddock : une zone par circuit, zone jaune = ta voiture, zone violette = garage (couleur, numéro, réglages). H : retour au paddock")

-- Arrivée dans le jeu : le menu principal, pour choisir tout de suite à quoi jouer.
task.delay(2, function()
	if not hasControl() and not isRacing() then
		raceClient:OpenMenu()
	end
end)

Remotes.ProfileUpdated.OnClientEvent:Connect(function(stats: any, laps: any)
	raceClient:SetProfile(stats, laps)
end)

-- Progression (XP, niveau, licence) : menu, garage, et les bandeaux d'un niveau
-- gagné ou d'un cosmétique débloqué.
Remotes.Progress.OnClientEvent:Connect(function(snapshot: any, news: any)
	raceClient:SetProgress(snapshot, news)
	garage:Refresh()
end)

Remotes.RunValidated.OnClientEvent:Connect(function(result: any)
	local current = session
	if current then
		current:OnRunValidated(result)
	end
	ghostChallenge:OnRunValidated(result)
end)

Remotes.Leaderboard.OnClientEvent:Connect(function(entries: any)
	if type(entries) == "table" then
		leaderboard:SetEntries(entries)
	end
end)

--------------------------------------------------------------------------------
-- Clavier et manette
--------------------------------------------------------------------------------

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
		local current = session
		if current then
			current.Dashboard:ToggleDetail()
		end
	elseif key == Enum.KeyCode.F3 then
		-- Le journal reste utile pour garder une trace écrite d'un essai.
		debugEnabled = not debugEnabled
		print("[Car] Journal console", if debugEnabled then "activé" else "désactivé")
	elseif key == Enum.KeyCode.P or key == Enum.KeyCode.ButtonL3 then
		actions.ToggleSetup()
	elseif key == Enum.KeyCode.L or key == Enum.KeyCode.ButtonR3 then
		actions.ToggleLeaderboard()
	elseif key == Enum.KeyCode.C or key == Enum.KeyCode.DPadRight then
		actions.ToggleRaceMenu()
	elseif key == Enum.KeyCode.V then
		raceClient:SpectateNext(1)
	elseif key == Enum.KeyCode.H then
		actions.ReturnToPaddock()
	elseif key == Enum.KeyCode.G then
		actions.CycleGhost()
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

--------------------------------------------------------------------------------
-- Affichage, son, effets, télémétrie
--------------------------------------------------------------------------------

local TELEMETRY_INTERVAL = 0.1 -- 10 Hz : assez pour le son et les roues des autres
local telemetryAccumulator = 0

RunService.RenderStepped:Connect(function(dt: number)
	remoteCars:Update(dt)

	local current = session
	if current then
		current.Parked = raceClient:IsSpectating()
		local audioState = current:RenderUpdate(dt)
		-- Ce que les autres joueurs entendent et voient de cette voiture (CarService).
		if audioState then
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
					-- Braquage rapporté à 60° (RemoteCars) : l'angle maximal est réglable.
					InputManager:GetInputs().steer * current.Car.MaxSteerAngle / 60,
					screech,
					audioState.GravelSlide,
					audioState.GravelShare,
					audioState.TarmacShare
				)
			end
		end
	end

	leaderboard:Update()
	raceClient:Update(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	garage:Update(dt, if root and root:IsA("BasePart") then root.Position else nil)
	local touch = touchControls
	if touch then
		touch:Update()
	end
end)

--------------------------------------------------------------------------------
-- Journal console (F3)
--------------------------------------------------------------------------------

local debugAccumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
	local current = session
	if not debugEnabled or not current then
		return
	end
	debugAccumulator += dt
	if debugAccumulator < 0.5 then
		return
	end
	debugAccumulator = 0

	local car = current.Car
	local chassis = current.Chassis
	local inputs = InputManager:GetInputs()
	local grounded = 0
	local totalLoad = 0
	local maxSlip = 0
	local maxUsage = 0
	for _, wheel in ipairs(car.Wheels) do
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
		local wheel = car.WheelsByName["Wheel" .. suffix]
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

	local powertrain = car.Powertrain
	local gearbox = powertrain.Gearbox
	local gearLabel = if gearbox.Gear == -1 then "R" elseif gearbox.Gear == 0 then "N" else tostring(gearbox.Gear)
	local flags = (if gearbox:IsShifting() then " passage" else "")
		.. (if powertrain.ClutchSlipping then " embrayage-patine" else "")
		.. (if powertrain.FuelCut then " RUPTEUR" else "")
		.. (if car.Held then " RETENUE" else "")

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
	local current = session
	if current then
		current:PhysicsStep(math.min(dt, MAX_PHYSICS_STEP))
	end
end)
