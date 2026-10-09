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
local Units = require(ReplicatedStorage.Shared.Util.Units)
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)
local InputManager = require(script.Parent.Core.InputManager)
local CharacterControls = require(script.Parent.Core.CharacterControls)
local DebugLog = require(script.Parent.Core.DebugLog)
local RemoteCars = require(script.Parent.Driving.RemoteCars)
local Leaderboard = require(script.Parent.UI.Leaderboard)
local SetupMenu = require(script.Parent.UI.SetupMenu)
local TouchControls = require(script.Parent.Core.TouchControls)
local DrivingSession = require(script.Parent.Driving.DrivingSession)
local Horn = require(script.Parent.Driving.Horn)
local RollReveal = require(script.Parent.UI.RollReveal)
local Toast = require(script.Parent.UI.Toast)
local GhostChallenge = require(script.Parent.Stage.GhostChallenge)
local Replay = require(script.Parent.Replay.Replay)
local Banner = require(script.Parent.UI.Banner)
local Weekly = require(ReplicatedStorage.Shared.Challenges.Weekly)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local RaceClient = require(script.Parent.Race.RaceClient)
local Garage = require(script.Parent.UI.Garage)
local Theme = require(script.Parent.UI.Theme)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)

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

-- Profil (chargé par le serveur), gardé d'une voiture à l'autre : réglages
-- et records de la spéciale, par catégorie de voiture (CarClasses.luau).
local setups: { [string]: CarSetup.Setup } = {}
local stageBests: { [string]: DrivingSession.StageBest } = {}

-- Classements : la spéciale habituelle (par catégorie), et le défi de la semaine.
local stageBoards: { [string]: { any } } = {}
local weeklyBoard: any = nil

-- Défi du fantôme : contre qui on roule sur la spéciale. Le choix dure toute
-- la partie et suit le joueur d'une voiture à l'autre.
local leaderboard: Leaderboard.Leaderboard
local raceClient: RaceClient.RaceClient -- créé plus bas (menus, rallycross)
local ghostChallenge = GhostChallenge.new(function(challenge)
	local current = session
	if current then
		current:SetGhostChoice(challenge.Opponent, challenge:IsHidden())
	end
	leaderboard:SetGhostInfo(challenge:Describe())
	-- Le menu propose aussi le ralenti du fantôme affronté.
	local opponent = challenge.Opponent
	raceClient:SetReplayOpponent(if opponent then opponent.Name else nil)
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

-- Catégorie de la voiture conduite ; à pied, celle choisie au garage.
local function drivenClass(): string
	local current = session
	if current then
		return current.ClassId
	end
	local wallet = raceClient:GetWallet()
	local item = Catalog.Get(if wallet then wallet.Equipped.Car else nil)
	return CarClasses.Get(if item then item.CarClass else nil).Id
end

local function setupFor(classId: string): CarSetup.Setup
	return setups[classId] or CarSetup.Default(classId)
end

--------------------------------------------------------------------------------
-- Réglages de la voiture (menu P), sauvegardés côté serveur
--------------------------------------------------------------------------------

local SETUP_SAVE_DELAY = 1.5 -- regroupe une rafale de clics en une seule sauvegarde
local setupSaveTokens: { [string]: number } = {}

-- Les réglages d'une catégorie : appliqués à la voiture si c'est la sienne,
-- et sauvegardés (une fois la rafale de clics finie).
local setupMenu = SetupMenu.new(playerGui, function(setup: CarSetup.Setup, classId: string)
	setups[classId] = setup
	local current = session
	if current and current.ClassId == classId then
		current.Car:ApplySetup(setup)
	end
	local token = (setupSaveTokens[classId] or 0) + 1
	setupSaveTokens[classId] = token
	task.delay(SETUP_SAVE_DELAY, function()
		if setupSaveTokens[classId] == token then
			Remotes.SaveSetup:FireServer(classId, setup)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Rallycross : menu, affichage de course, spectateur
--------------------------------------------------------------------------------

-- Ralenti du meilleur passage, et mode photo (Replay.luau).
local startReplay: (string) -> ()
local replay = Replay.new(playerGui, camera, function()
	-- Fin du ralenti : la caméra revient au joueur.
	local current = session
	if current and current.HasControl then
		current.ChaseCamera:Enter()
	else
		CharacterControls.ResetCamera()
		CharacterControls.SetEnabled(true)
	end
end)

raceClient = RaceClient.new({
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
			CharacterControls.ResetCamera()
		end
	end,
	OnReplay = function(which: string)
		startReplay(which)
	end,
})

-- Ralenti : "Own" = son meilleur passage, "Opponent" = le fantôme affronté.
--[[
	Le ralenti est local : personne d'autre ne le voit, et le jeu ne ralentit
	pour personne. Mais pendant ce temps, sa voiture attend sur place, freins
	serrés, et la caméra est prise : on le refuse quand ça ferait perdre
	quelque chose (une course qui part, un chrono qui tourne).
]]
startReplay = function(which: string)
	if raceClient:IsInRace() then
		Banner.Show("RALENTI", "Pas pendant une course, ni en salle d'attente : après la course.", Theme.ORANGE, 2.5)
		return
	end
	local running = session
	if running and running:IsRunInProgress() then
		Banner.Show("RALENTI", "Pas pendant un passage chronométré : à l'arrivée, ou recommence (Retour arrière).", Theme.ORANGE, 3)
		return
	end
	local data: any = nil
	local title = ""
	local livery: any = nil
	-- Le passage de la catégorie de sa voiture (ou de celle de l'adversaire).
	local classId = drivenClass()
	if which == "Opponent" then
		local opponent = ghostChallenge.Opponent
		if opponent then
			data = opponent.Data
			title = opponent.Name .. " · " .. Format.Ms(opponent.Ms)
			classId = ghostChallenge.ClassId
		end
	else
		-- Le fantôme de la voiture actuelle a pu être battu depuis le profil.
		local current = session
		local ghost = if current and current.ClassId == classId then current.Ghost else nil
		local best = stageBests[classId]
		data = (if ghost then ghost.Best else nil) or (if best then best.Ghost else nil)
		title = "Ton meilleur passage" .. (if best and best.Ms then " · " .. Format.Ms(best.Ms) else "")
		livery = raceClient:GetLivery()
	end
	if not data then
		Banner.Show("RALENTI", "Pas encore de passage enregistré dans cette catégorie : termine la spéciale d'abord.", Theme.ORANGE, 3)
		return
	end
	CharacterControls.SetEnabled(false)
	replay:Start(data, string.upper(title .. " · " .. CarClasses.Get(classId).Name), livery, classId)
end

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
	GetCarClass = function()
		return drivenClass()
	end,
})

RunService:BindToRenderStep("RallyCamera", Enum.RenderPriority.Camera.Value, function(dt: number)
	if replay:UpdateCamera(dt) then
		return
	end
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
	ToggleMenu = function()
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
	-- Klaxon : le serveur le relaie à tous (HornService), soi compris.
	Horn = function()
		if drivingSession() then
			Remotes.Horn:FireServer()
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
-- Le classement affiché (L) : celui du défi pendant le défi, sinon la spéciale.
local function refreshLeaderboard()
	local current = session
	if current and current.Weekly and weeklyBoard then
		local modifier = Weekly.ModifierById(weeklyBoard.Modifier)
		leaderboard:SetTitle("DÉFI · " .. string.upper(if modifier then modifier.Name else "SEMAINE"))
		leaderboard:SetEntries(weeklyBoard.Entries or {}, false)
	else
		local classId = drivenClass()
		leaderboard:SetTitle("CLASSEMENT · " .. string.upper(CarClasses.Get(classId).Name))
		leaderboard:SetEntries(stageBoards[classId] or {}, true, classId)
	end
end

local function applyDrivingUi()
	local current = session
	local driving = hasControl()
	local racing = isRacing()
	leaderboard:SetVisible(driving and not racing)
	refreshLeaderboard()
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
		CharacterControls.SetEnabled(false)
		if current:IsRacing() then
			print("[Car] En course — R/F rapports, M boîte, T remise en piste, C menu (abandon), V spectateur après l'arrivée")
		else
			print("[Car] Au volant — R/F rapports, M boîte auto/manuelle, T remise en piste, Retour arrière recommencer, P réglages, L classement, G fantôme (le tien, ton rival, le record), K klaxon, C menu, H retour au paddock, Q descendre, F2 télémétrie, F3 journal")
		end
	else
		if not raceClient:IsSpectating() then
			CharacterControls.ResetCamera()
		end
		CharacterControls.SetEnabled(true)
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
	-- Le meilleur temps et le fantôme de sa catégorie ont pu changer pendant
	-- cette session (pas au défi de la semaine : il a son propre classement).
	local timer, ghost = current.StageTimer, current.Ghost
	if not current.Weekly then
		local best: DrivingSession.StageBest = stageBests[current.ClassId] or { Ms = nil, Ghost = nil }
		if timer and timer.BestTime then
			best.Ms = math.floor((timer.BestTime :: number) * 1000 + 0.5)
		end
		if ghost and ghost.Best then
			best.Ghost = ghost.Best
		end
		stageBests[current.ClassId] = best
	end
	raceClient:StopSpectating()
	local hadControl = current.HasControl
	current:Destroy()
	if hadControl then
		CharacterControls.ResetCamera()
		CharacterControls.SetEnabled(true)
	end
	applyDrivingUi()
end

-- Médailles d'école déjà obtenues (progression envoyée par le serveur).
local function lessonBests(): { [string]: number }
	local progress = raceClient:GetProgress()
	return if progress and progress.Lessons then progress.Lessons else {}
end

local function startSession(model: Model)
	endSession()
	sessionToken += 1
	local token = sessionToken
	local ok, result = pcall(DrivingSession.new, model, {
		PlayerGui = playerGui,
		Camera = camera,
		TouchLayout = isTouch,
		Setups = setups,
		StageBests = stageBests,
		WeeklyBestMs = if weeklyBoard then weeklyBoard.Mine else nil,
		LessonBests = lessonBests(),
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
	-- Réglages et adversaire fantôme de la catégorie de cette voiture.
	setupMenu:SetClass(created.ClassId, setupFor(created.ClassId))
	ghostChallenge:SetClass(created.ClassId)
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
			CharacterControls.ResetCamera()
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
	stageBests = {}
	if type(profile.Stage) == "table" then
		for classId, record in pairs(profile.Stage) do
			if CarClasses.Exists(classId) and type(record) == "table" then
				stageBests[classId] = {
					Ms = if type(record.Ms) == "number" then record.Ms else nil,
					Ghost = if type(record.Ghost) == "table" then record.Ghost else nil,
				}
			end
		end
	end
	setups = {}
	if type(profile.Setups) == "table" then
		for classId, setup in pairs(profile.Setups) do
			if CarClasses.Exists(classId) then
				setups[classId] = CarSetup.Sanitize(setup, classId)
			end
		end
	end
	setupMenu:SetSetup(setupFor(setupMenu:GetClass()))
	local current = session
	if current then
		current.Car:ApplySetup(setupFor(current.ClassId))
		current:SetStageProfile(stageBests)
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

-- Classements de la spéciale, par catégorie : on affiche celui de sa voiture.
Remotes.Leaderboard.OnClientEvent:Connect(function(boards: any)
	if type(boards) == "table" then
		stageBoards = boards
		refreshLeaderboard()
	end
end)

-- Rallye Pass : saison, XP, paliers atteints.
Remotes.PassState.OnClientEvent:Connect(function(state: any, news: any)
	raceClient:SetPass(state, news)
end)

-- Tirage : la mise en scène de l'objet tiré par le serveur.
local rollReveal = RollReveal.new(playerGui)
Remotes.RollResult.OnClientEvent:Connect(function(result: any)
	if type(result) ~= "table" then
		return
	end
	if type(result.Error) == "string" then
		Toast.Show(result.Error, Theme.RED)
		return
	end
	rollReveal:Show(result)
end)

-- Un pilote klaxonne (soi compris) : son klaxon, sur sa voiture.
Remotes.HornPlayed.OnClientEvent:Connect(function(userId: any)
	local car = workspace:FindFirstChild("Car_" .. tostring(userId))
	if car and car:IsA("Model") then
		Horn.Play(car)
	end
end)

-- Crédits et objets : solde, boutique, et ce qu'on vient de gagner ou d'acheter.
Remotes.Wallet.OnClientEvent:Connect(function(wallet: any, news: any)
	raceClient:SetWallet(wallet, news)
	-- Une autre voiture choisie, à pied : ses réglages, son classement, ses fantômes.
	if not session then
		local classId = drivenClass()
		setupMenu:SetClass(classId, setupFor(classId))
		ghostChallenge:SetClass(classId)
	end
	refreshLeaderboard()
end)

-- Défis du jour : objectifs et progression (menu), réussites annoncées.
Remotes.Daily.OnClientEvent:Connect(function(state: any, news: any)
	raceClient:SetDaily(state, news)
end)

-- Défi de la semaine : contrainte, fin, classement, son temps (menu et L).
Remotes.WeeklyBoard.OnClientEvent:Connect(function(board: any)
	if type(board) == "table" and type(board.Entries) == "table" then
		weeklyBoard = board
		raceClient:SetWeekly(board)
		refreshLeaderboard()
	end
end)

--------------------------------------------------------------------------------
-- Clavier et manette
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	-- Pendant le ralenti, ses touches à lui (pause, caméras, photo...).
	if replay:IsActive() then
		replay:HandleKey(input.KeyCode)
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
		actions.ToggleMenu()
	elseif key == Enum.KeyCode.V then
		raceClient:SpectateNext(1)
	elseif key == Enum.KeyCode.H then
		actions.ReturnToPaddock()
	elseif key == Enum.KeyCode.G then
		actions.CycleGhost()
	elseif key == Enum.KeyCode.K then
		actions.Horn()
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

	-- Une course qui part (revanche, salle rejointe) reprend la main sur le ralenti.
	if replay:IsActive() and raceClient:IsRaceUnderway() then
		replay:Stop()
		Banner.Show("RALENTI", "La course part : ralenti interrompu.", Theme.ORANGE, 2.5)
	end

	local current = session
	if current then
		-- Spectateur ou ralenti : la voiture attend, freins serrés.
		current.Parked = raceClient:IsSpectating() or replay:IsActive()
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

local DEBUG_INTERVAL = 0.5
local debugAccumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
	local current = session
	if not debugEnabled or not current then
		return
	end
	debugAccumulator += dt
	if debugAccumulator >= DEBUG_INTERVAL then
		debugAccumulator = 0
		DebugLog.Print(current.Car, current.Chassis)
	end
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
