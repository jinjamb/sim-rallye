--!strict
--[[
	CarService.luau
	Une voiture par joueur, et l'attribution du NetworkOwnership.

	GABARIT : la voiture construite dans Studio par tools/build-rig.luau
	(workspace.RallyCar) sert de modèle. Au démarrage, le serveur la range dans
	ReplicatedStorage sous le nom "CarTemplate" -- hors du monde, donc sans
	physique -- et en fait une copie par joueur. Le client s'en sert aussi pour
	afficher le fantôme (Ghost.luau).

	PHYSIQUE CÔTÉ CLIENT : toute la simulation tourne chez le pilote. Pour que ses
	ApplyImpulse soient autoritaires, le serveur lui donne la propriété réseau
	de l'assembly de SA voiture, et de celle-là seulement.

	ENTRE JOUEURS : les voitures ne se percutent pas nativement (groupe de
	collision "Cars", qui ne collisionne pas avec lui-même). En rallycross, le
	contact est recalculé par chaque client sur sa propre voiture (CarContact.luau) :
	les collisions natives entre deux voitures simulées par deux clients
	différents, chacun voyant l'autre avec du retard, sont violentes et
	asymétriques. Les rayons de suspension utilisent le même groupe et
	traversent donc les autres voitures.

	APPARITION (Spawn) : au paddock à l'arrivée, sur la grille au départ d'une
	course, de retour au paddock ensuite. Chaque apparition recrée la voiture :
	le client démarre une nouvelle session de conduite à chaque fois
	(DrivingSession.luau), sans rien garder de l'ancienne (régime, pédales...).
	La voiture porte l'attribut RaceId (course en cours, absent au paddock) et
	Contacts (contact entre voitures activé) ; le châssis porte Held (voiture
	retenue sur la grille, jusqu'à l'extinction des feux).

	TÉLÉMÉTRIE : la physique fine (régime, glissements, braquage) n'existe que
	chez le pilote. Il en envoie un résumé ~10 fois par seconde ; le serveur le
	recopie en attributs sur le châssis, que Roblox réplique à tous : les autres
	joueurs entendent le moteur, voient les roues tourner et braquer, la
	poussière se lever (RemoteCars.luau).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

local CarService = {}

local CAR_TAG = "RallyCar"
local CAR_COLLISION_GROUP = "Cars"
local REQUEST_COOLDOWN = 0.5 -- anti-spam du RemoteEvent
local CHECK_INTERVAL = 1.0
-- Filet de sécurité : le pilote étant soudé au châssis, cet écart doit rester nul.
-- S'il explose, le weld a sauté (personnage détruit, téléportation).
local MAX_KEEP_DISTANCE = 150 -- studs
local STREAM_TIMEOUT = 8 -- secondes d'attente maximale du chargement d'une zone

-- Places au paddock, sur la Baseplate, avant le départ de la spéciale (cap -Z).
-- À gauche du spawn : la piste d'essai occupe la droite (x > 24).
local SPAWN_Z = -180
local SPAWN_HEIGHT = 6
local SPAWN_FIRST_X = -12
local SPAWN_SPACING = 11
local SPAWN_SLOTS = 12

-- Télémétrie : bornes de sanité et cadence maximale acceptée par joueur.
local TELEMETRY_MIN_INTERVAL = 0.05
local MAX_RPM = 9000

export type SpawnOptions = {
	RaceId: string?,
	Contacts: boolean?,
	Held: boolean?,
}

--------------------------------------------------------------------------------
-- Gabarit
--------------------------------------------------------------------------------

local template: Model? = nil

local function prepareTemplate()
	local rig = workspace:FindFirstChild("RallyCar")
	local stored = ReplicatedStorage:FindFirstChild("CarTemplate")
	if rig and rig:IsA("Model") then
		if stored then
			stored:Destroy()
		end
		rig.Name = "CarTemplate"
		rig.Parent = ReplicatedStorage
		template = rig
	elseif stored and stored:IsA("Model") then
		template = stored
	end
	local found = template
	if found then
		-- Le gabarit n'est pas une voiture en jeu : pas de tag (sinon on
		-- tenterait de lui attribuer un propriétaire réseau hors du monde).
		local chassis = found:FindFirstChild("Chassis")
		if chassis then
			CollectionService:RemoveTag(chassis, CAR_TAG)
		end
	else
		warn("[CarService] Pas de voiture modèle : lance tools/build-rig.luau dans Studio (workspace.RallyCar)")
	end
end

--------------------------------------------------------------------------------
-- État
--------------------------------------------------------------------------------

local carByPlayer: { [Player]: Model } = {}
local slotByPlayer: { [Player]: number } = {}
local driverByChassis: { [BasePart]: Player } = {}
local lastRequestAt: { [Player]: number } = {}
local lastTelemetryAt: { [Player]: number } = {}
-- En course, on ne descend pas de voiture (Q) : on abandonne depuis le menu.
local lockedInCar: { [Player]: boolean } = {}
local spawnGeneration: { [Player]: number } = {}

--[[
	Embarquement du pilote.
	Le personnage est soudé au châssis et rendu invisible : pas de siège, mais
	pas d'avatar abandonné sur la piste, ni de révocation dès que la voiture
	s'éloigne.
	Massless = true est indispensable : sans ça les parts du personnage rejoignent
	l'assembly et faussent la masse, donc tout le modèle de pneu.
]]
type DriverState = {
	weld: WeldConstraint,
	transparency: { [BasePart]: number },
	canCollide: { [BasePart]: boolean },
}

local driverStateByPlayer: { [Player]: DriverState } = {}

local function attachDriver(player: Player, chassis: BasePart)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true -- coupe la marche, les animations et la station debout
		humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- coupe la machine à états
	end

	local savedTransparency: { [BasePart]: number } = {}
	local savedCanCollide: { [BasePart]: boolean } = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			savedTransparency[descendant] = descendant.Transparency
			savedCanCollide[descendant] = descendant.CanCollide
			descendant.Transparency = 1
			descendant.Massless = true
			-- Sinon les jambes du pilote traînent par terre et portent la voiture.
			descendant.CanCollide = false
		end
	end

	-- Le weld fusionne les quantités de mouvement : un pilote en pleine chute
	-- transmettrait sa vitesse au châssis et le ferait basculer.
	root.CFrame = chassis.CFrame
	root.AssemblyLinearVelocity = chassis.AssemblyLinearVelocity
	root.AssemblyAngularVelocity = chassis.AssemblyAngularVelocity

	local weld = Instance.new("WeldConstraint")
	weld.Name = "DriverWeld"
	weld.Part0 = chassis
	weld.Part1 = root
	weld.Parent = chassis

	driverStateByPlayer[player] = {
		weld = weld,
		transparency = savedTransparency,
		canCollide = savedCanCollide,
	}
end

local function detachDriver(player: Player, chassis: BasePart)
	local state = driverStateByPlayer[player]
	if not state then
		return
	end
	driverStateByPlayer[player] = nil

	if state.weld.Parent then
		state.weld:Destroy()
	end

	for part, transparency in pairs(state.transparency) do
		if part.Parent then
			part.Transparency = transparency
			part.Massless = false
			part.CanCollide = state.canCollide[part]
		end
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and chassis:IsDescendantOf(workspace) then
			-- On repose le pilote à côté de la voiture, pas dedans.
			root.CFrame = chassis.CFrame * CFrame.new(-6, 3, 0)
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function chassisOf(car: Model?): BasePart?
	if not car then
		return nil
	end
	local chassis = car:FindFirstChild("Chassis")
	return if chassis and chassis:IsA("BasePart") then chassis else nil
end

local function getAlivePosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

--------------------------------------------------------------------------------
-- Contrôle
--------------------------------------------------------------------------------

local function grant(player: Player, chassis: BasePart)
	driverByChassis[chassis] = player

	-- Attribuer la propriété AVANT de souder : une fois le personnage fusionné dans
	-- l'assembly, SetNetworkOwner peut refuser (assembly contenant un personnage).
	local ok, err = pcall(function()
		chassis:SetNetworkOwner(player)
	end)
	if not ok then
		warn("[CarService] SetNetworkOwner a échoué :", err)
		driverByChassis[chassis] = nil
		Remotes.CarControlChanged:FireClient(player, chassis, false)
		return
	end

	attachDriver(player, chassis)
	chassis:SetAttribute("Driven", true)
	Remotes.CarControlChanged:FireClient(player, chassis, true)
end

-- notify = false : la voiture va être détruite (remplacée), sa disparition suffit
-- à terminer la session de conduite du client ; inutile de le faire passer à pied.
local function release(chassis: BasePart, notify: boolean?)
	local player = driverByChassis[chassis]
	if not player then
		return
	end
	driverByChassis[chassis] = nil
	chassis:SetAttribute("Driven", false)

	detachDriver(player, chassis)

	if chassis:IsDescendantOf(workspace) and not chassis.Anchored then
		chassis:SetNetworkOwner(nil) -- le serveur reprend la simulation
	end

	if player.Parent and notify ~= false then
		Remotes.CarControlChanged:FireClient(player, chassis, false)
	end
end

--------------------------------------------------------------------------------
-- Voitures des joueurs
--------------------------------------------------------------------------------

local function freeSlot(): number
	local used: { [number]: boolean } = {}
	for _, slot in pairs(slotByPlayer) do
		used[slot] = true
	end
	for slot = 0, SPAWN_SLOTS - 1 do
		if not used[slot] then
			return slot
		end
	end
	return 0 -- serveur plein : on empile (les voitures ne se percutent pas)
end

local function paddockFrame(player: Player): CFrame
	local slot = slotByPlayer[player]
	if slot == nil then
		slot = freeSlot()
		slotByPlayer[player] = slot
	end
	return CFrame.new(SPAWN_FIRST_X - slot * SPAWN_SPACING, SPAWN_HEIGHT, SPAWN_Z)
end

local function removeCar(player: Player)
	local car = carByPlayer[player]
	carByPlayer[player] = nil
	local chassis = chassisOf(car)
	if chassis and driverByChassis[chassis] then
		release(chassis, false)
	end
	if car then
		car:Destroy()
	end
end

-- Fait charger la zone chez le joueur avant d'y poser sa voiture : avec le
-- streaming, un circuit lointain n'existe pas encore chez lui, et les rayons de
-- suspension ne toucheraient rien.
local function streamAround(player: Player, position: Vector3)
	if not workspace.StreamingEnabled then
		return
	end
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(position, STREAM_TIMEOUT)
	end)
	if not ok then
		warn("[CarService] Chargement de la zone impossible :", err)
	end
end

--[[
	(Re)crée la voiture du joueur. frame nil = au paddock. Le joueur en reprend
	aussitôt le volant s'il est en vie (son personnage est soudé au châssis, il
	voyage avec). Peut attendre quelques secondes (chargement de la zone).
]]
function CarService.Spawn(player: Player, frame: CFrame?, options: SpawnOptions?): Model?
	local source = template
	if not source then
		return nil
	end
	local opts: SpawnOptions = options or {}
	local target = frame or paddockFrame(player)

	-- Deux apparitions peuvent se chevaucher (retour au paddock demandé pendant
	-- la mise en grille) : seule la plus récente aboutit.
	local generation = (spawnGeneration[player] or 0) + 1
	spawnGeneration[player] = generation

	removeCar(player)
	streamAround(player, target.Position)
	if not player.Parent or spawnGeneration[player] ~= generation then
		return nil -- parti pendant le chargement, ou une apparition plus récente a pris le relais
	end
	removeCar(player)

	local car = source:Clone()
	car.Name = "Car_" .. player.UserId
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("OwnerName", player.DisplayName)
	car:SetAttribute("RaceId", opts.RaceId)
	car:SetAttribute("Contacts", opts.Contacts == true)
	car:PivotTo(target)

	local chassis = chassisOf(car)
	if not chassis then
		car:Destroy()
		warn("[CarService] La voiture modèle n'a pas de Chassis")
		return nil
	end
	chassis.CollisionGroup = CAR_COLLISION_GROUP
	chassis:SetAttribute("Driven", false)
	chassis:SetAttribute("Held", opts.Held == true)

	-- Sa propre voiture est toujours chargée chez son pilote, où qu'elle soit ;
	-- chez les autres, elle apparaît d'un bloc (pas de roue sans châssis).
	pcall(function()
		car.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
		car:AddPersistentPlayer(player)
	end)

	car.Parent = workspace
	-- Sans ça, Roblox réattribue la propriété tout seul selon la proximité des joueurs.
	chassis:SetNetworkOwnershipAuto(false)
	chassis:SetNetworkOwner(nil)
	CollectionService:AddTag(chassis, CAR_TAG)

	carByPlayer[player] = car
	if getAlivePosition(player) ~= nil then
		grant(player, chassis)
	end
	return car
end

function CarService.ReturnToPaddock(player: Player)
	lockedInCar[player] = nil
	CarService.Spawn(player, nil, nil)
end

function CarService.GetCar(player: Player): Model?
	return carByPlayer[player]
end

function CarService.GetChassis(player: Player): BasePart?
	return chassisOf(carByPlayer[player])
end

-- Le joueur est-il au volant de sa voiture ?
function CarService.IsDriving(player: Player): boolean
	local chassis = chassisOf(carByPlayer[player])
	return chassis ~= nil and driverByChassis[chassis] == player
end

-- Voiture retenue sur la grille (freins serrés, embrayage ouvert : voir Car.luau).
function CarService.SetHeld(player: Player, held: boolean)
	local chassis = chassisOf(carByPlayer[player])
	if chassis then
		chassis:SetAttribute("Held", held)
	end
end

function CarService.SetLocked(player: Player, locked: boolean)
	lockedInCar[player] = if locked then true else nil
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- La voiture attend le premier personnage : le pilote y est soudé.
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	if player.Parent and not carByPlayer[player] then
		CarService.Spawn(player, nil, nil)
	end
end

--[[
	Télémétrie : uniquement de la voiture qu'on pilote, à cadence bornée, valeurs
	bornées. Ce n'est que de l'affichage pour les autres -- aucune décision de
	jeu ne s'appuie dessus -- mais un client ne doit pas pouvoir y injecter
	n'importe quoi.
]]
local function finiteIn(value: any, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(value, low, high)
end

function CarService.Start()
	prepareTemplate()

	if not PhysicsService:IsCollisionGroupRegistered(CAR_COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(CAR_COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(CAR_COLLISION_GROUP, CAR_COLLISION_GROUP, false)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		removeCar(player)
		slotByPlayer[player] = nil
		lastRequestAt[player] = nil
		lastTelemetryAt[player] = nil
		driverStateByPlayer[player] = nil
		lockedInCar[player] = nil
		spawnGeneration[player] = nil
	end)

	-- Seul le propriétaire peut prendre le volant, où qu'il soit : sa voiture
	-- vient le chercher (le pilote est soudé au châssis à l'embarquement).
	Remotes.RequestCarControl.OnServerEvent:Connect(function(player: Player, target: any)
		local now = os.clock()
		if now - (lastRequestAt[player] or 0) < REQUEST_COOLDOWN then
			return
		end
		lastRequestAt[player] = now

		local chassis = chassisOf(carByPlayer[player])
		if not chassis or target ~= chassis then
			return
		end
		if getAlivePosition(player) == nil then
			return
		end
		if driverByChassis[chassis] == player then
			Remotes.CarControlChanged:FireClient(player, chassis, true)
			return
		end
		grant(player, chassis)
	end)

	Remotes.ReleaseCarControl.OnServerEvent:Connect(function(player: Player)
		if lockedInCar[player] then
			return
		end
		local chassis = chassisOf(carByPlayer[player])
		if chassis and driverByChassis[chassis] == player then
			release(chassis)
		end
	end)

	Remotes.CarTelemetry.OnServerEvent:Connect(function(player: Player, rpm: any, load: any, steer: any, screech: any, gravelSlide: any, gravelShare: any, tarmacShare: any)
		local now = os.clock()
		if now - (lastTelemetryAt[player] or 0) < TELEMETRY_MIN_INTERVAL then
			return
		end
		lastTelemetryAt[player] = now

		local chassis = chassisOf(carByPlayer[player])
		if not chassis or driverByChassis[chassis] ~= player then
			return
		end
		chassis:SetAttribute("Rpm", math.floor(finiteIn(rpm, 0, MAX_RPM)))
		chassis:SetAttribute("Load", finiteIn(load, 0, 1))
		chassis:SetAttribute("Steer", finiteIn(steer, -1, 1))
		chassis:SetAttribute("Screech", finiteIn(screech, 0, 1))
		chassis:SetAttribute("GravelSlide", finiteIn(gravelSlide, 0, 1))
		chassis:SetAttribute("GravelShare", finiteIn(gravelShare, 0, 1))
		chassis:SetAttribute("TarmacShare", finiteIn(tarmacShare, 0, 1))
	end)

	-- Filet de sécurité : mort, respawn, joueur téléporté loin de sa voiture.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0

		for chassis, player in pairs(driverByChassis) do
			local position = getAlivePosition(player)
			local tooFar = position ~= nil and ((position :: Vector3) - chassis.Position).Magnitude > MAX_KEEP_DISTANCE
			if position == nil or tooFar then
				release(chassis)
			end
		end
	end)
end

return CarService
