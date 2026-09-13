--!strict
--[[
	CarService.server.luau
	Attribution du NetworkOwnership des châssis.

	Toute la physique tourne sur le client (Client-Side Prediction) : pour que
	les ApplyImpulse du client soient autoritaires, le serveur doit lui donner
	explicitement la propriété réseau de l'assembly. Sinon Roblox corrige la
	position en permanence et la voiture tremble / revient en arrière.

	Une voiture = une BasePart taguée "RallyCar" (CollectionService).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

local CAR_TAG = "RallyCar"
local MAX_CLAIM_DISTANCE = 25 -- studs : distance max pour prendre le volant
-- Filet de sécurité : le pilote étant soudé au châssis, cet écart doit rester nul.
-- S'il explose, c'est que le weld a sauté (personnage détruit, téléportation) et
-- il faut rendre la voiture au serveur.
local REVOKE_ON_DISTANCE = true
local MAX_KEEP_DISTANCE = 150 -- studs
local REQUEST_COOLDOWN = 0.5 -- anti-spam du RemoteEvent
local CHECK_INTERVAL = 1.0

local driverByChassis: {[BasePart]: Player} = {}
local chassisByPlayer: {[Player]: BasePart} = {}
local lastRequestAt: {[Player]: number} = {}

--[[
	Embarquement du pilote.
	Le personnage est soudé au châssis et rendu invisible : il n'y a pas encore de
	siège ni de modèle de voiture, mais ça évite deux problèmes concrets --
	l'avatar abandonné au milieu de la piste (que la voiture peut percuter), et la
	révocation du contrôle dès que le châssis s'éloigne.

	Massless = true est indispensable : sans ça les parts du personnage rejoignent
	l'assembly et AssemblyMass passe de 60 à ~75, ce qui fausse tout le modèle de
	pneu (Wheel.luau divise AssemblyMass par 4 pour la masse non suspendue).
]]
type DriverState = {
	weld: WeldConstraint,
	transparency: {[BasePart]: number},
	canCollide: {[BasePart]: boolean},
}

local driverStateByPlayer: {[Player]: DriverState} = {}

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

	local savedTransparency: {[BasePart]: number} = {}
	local savedCanCollide: {[BasePart]: boolean} = {}
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

local function grant(player: Player, chassis: BasePart)
	driverByChassis[chassis] = player
	chassisByPlayer[player] = chassis

	-- Attribuer la propriété AVANT de souder : une fois le personnage fusionné dans
	-- l'assembly, SetNetworkOwner peut refuser (assembly contenant un personnage).
	-- Le weld ne change rien ensuite : les deux moitiés appartiennent au même joueur.
	local ok, err = pcall(function()
		chassis:SetNetworkOwner(player)
	end)
	if not ok then
		warn("[CarService] SetNetworkOwner a échoué :", err)
		driverByChassis[chassis] = nil
		chassisByPlayer[player] = nil
		Remotes.CarControlChanged:FireClient(player, chassis, false)
		return
	end

	attachDriver(player, chassis)

	Remotes.CarControlChanged:FireClient(player, chassis, true)
end

local function release(chassis: BasePart)
	local player = driverByChassis[chassis]
	if not player then
		return
	end

	driverByChassis[chassis] = nil
	chassisByPlayer[player] = nil

	detachDriver(player, chassis)

	if chassis:IsDescendantOf(workspace) and not chassis.Anchored then
		chassis:SetNetworkOwner(nil) -- le serveur reprend la simulation
	end

	if player.Parent then
		Remotes.CarControlChanged:FireClient(player, chassis, false)
	end
end

local function registerCar(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if instance.Anchored then
		warn(("[CarService] %s est ancré : impossible de déléguer la physique."):format(instance:GetFullName()))
		return
	end

	-- Sans ça, Roblox réattribue la propriété tout seul selon la proximité des joueurs.
	instance:SetNetworkOwnershipAuto(false)
	instance:SetNetworkOwner(nil)
end

local function isCar(instance: any): BasePart?
	if typeof(instance) ~= "Instance" then
		return nil
	end
	local part = instance :: Instance
	if not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
		return nil
	end
	if not CollectionService:HasTag(part, CAR_TAG) then
		return nil
	end
	return part
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

-- Rig de dev : on tague automatiquement le châssis du gabarit s'il existe.
local existingModel = workspace:FindFirstChild("RallyCar")
local existingChassis = if existingModel
	then existingModel:FindFirstChild("Chassis")
	else workspace:FindFirstChild("Chassis")
if existingChassis and not CollectionService:HasTag(existingChassis, CAR_TAG) then
	CollectionService:AddTag(existingChassis, CAR_TAG)
end

for _, car in ipairs(CollectionService:GetTagged(CAR_TAG)) do
	registerCar(car)
end
CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(registerCar)
CollectionService:GetInstanceRemovedSignal(CAR_TAG):Connect(function(instance: Instance)
	if instance:IsA("BasePart") and driverByChassis[instance] then
		release(instance)
	end
end)

Remotes.RequestCarControl.OnServerEvent:Connect(function(player: Player, target: any)
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < REQUEST_COOLDOWN then
		return
	end
	lastRequestAt[player] = now

	local chassis = isCar(target)
	if not chassis then
		return
	end

	local position = getAlivePosition(player)
	if not position then
		return
	end
	if (position - chassis.Position).Magnitude > MAX_CLAIM_DISTANCE then
		Remotes.CarControlChanged:FireClient(player, chassis, false)
		return
	end

	local currentDriver = driverByChassis[chassis]
	if currentDriver == player then
		Remotes.CarControlChanged:FireClient(player, chassis, true)
		return
	end
	if currentDriver then
		return -- déjà occupée
	end

	local previous = chassisByPlayer[player]
	if previous then
		release(previous)
	end

	grant(player, chassis)
end)

Remotes.ReleaseCarControl.OnServerEvent:Connect(function(player: Player)
	local chassis = chassisByPlayer[player]
	if chassis then
		release(chassis)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local chassis = chassisByPlayer[player]
	if chassis then
		release(chassis)
	end
	lastRequestAt[player] = nil
	driverStateByPlayer[player] = nil
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
		local tooFar = REVOKE_ON_DISTANCE
			and position ~= nil
			and ((position :: Vector3) - chassis.Position).Magnitude > MAX_KEEP_DISTANCE
		if position == nil or tooFar then
			release(chassis)
		end
	end
end)
