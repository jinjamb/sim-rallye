--!strict
--[[
	DrivingSession.luau
	Tout ce qui vit avec UNE voiture du joueur : physique, tableau de bord, son,
	poussière, caméra de poursuite, et selon le contexte :
		- au paddock (pas d'attribut RaceId) : chrono de la spéciale, copilote,
		  fantôme ;
		- en course de rallycross : contact avec les autres voitures de la course
		  (si la course l'active), remise en piste sur le circuit.

	Le serveur recrée la voiture à chaque changement de lieu (paddock -> grille ->
	paddock) : Main.client.luau détruit alors la session et en crée une neuve.
	Rien ne traîne d'une voiture à l'autre (régime, pédales, chrono en cours).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local CarSetup = require(ReplicatedStorage.Shared.Constants.CarSetup)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local CarClass = require(script.Parent.Parent.Physics.Car)
local InputManager = require(script.Parent.InputManager)
local Dashboard = require(script.Parent.Dashboard)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local StageTimer = require(script.Parent.StageTimer)
local ChaseCamera = require(script.Parent.ChaseCamera)
local CarEffects = require(script.Parent.CarEffects)
local Copilot = require(script.Parent.Copilot)
local Ghost = require(script.Parent.Ghost)
local CarContact = require(script.Parent.Parent.Race.CarContact)

local DrivingSession = {}
DrivingSession.__index = DrivingSession

export type Context = {
	PlayerGui: Instance,
	Camera: Camera,
	TouchLayout: boolean,
	Setup: CarSetup.Setup,
	StageBestMs: number?,
	StageGhost: Ghost.GhostData?,
}

export type DrivingSession = typeof(setmetatable({}, DrivingSession)) & {
	Model: Model,
	Chassis: BasePart,
	Car: CarClass.Car,
	RaceId: string?,
	Dashboard: Dashboard.Dashboard,
	Audio: CarAudio.CarAudio,
	Effects: CarEffects.CarEffects,
	ChaseCamera: ChaseCamera.ChaseCamera,
	StageTimer: StageTimer.StageTimer?,
	Copilot: Copilot.Copilot?,
	Ghost: Ghost.Ghost?,
	Contact: CarContact.CarContact?,
	HasControl: boolean,
	GhostUploadPending: boolean,
	LastRecoverAt: number,
	-- Garée pendant que le joueur regarde la course (spectateur) : freins
	-- serrés, comme retenue sur la grille, les commandes n'agissent plus.
	Parked: boolean,
}

local CAR_TAG = "RallyCar"
local RACE_RECOVER_COOLDOWN = 3 -- secondes entre deux remises en piste en course

function DrivingSession.new(model: Model, context: Context): DrivingSession
	local self = (setmetatable({}, DrivingSession) :: any) :: DrivingSession
	self.Model = model
	self.Chassis = model:WaitForChild("Chassis") :: BasePart
	self.HasControl = false
	self.GhostUploadPending = false
	self.LastRecoverAt = -math.huge
	self.Parked = false
	local raceId = model:GetAttribute("RaceId")
	self.RaceId = if type(raceId) == "string" then raceId else nil

	local car = CarClass.new(self.Chassis)
	car:ApplySetup(context.Setup)
	self.Car = car

	local wheelAttachments: { Attachment } = {}
	for i, wheel in ipairs(car.Wheels) do
		wheelAttachments[i] = wheel.Attachment
	end

	self.Dashboard = Dashboard.new(car, context.PlayerGui)
	self.Audio = CarAudio.new(self.Chassis, wheelAttachments, true)
	self.Effects = CarEffects.new(self.Chassis, car.Wheels :: any)
	self.ChaseCamera = ChaseCamera.new(car, context.Camera)
	if context.TouchLayout then
		self.Dashboard:SetTouchLayout(true)
	end

	if self.RaceId == nil then
		-- Au paddock : la spéciale, son chrono, son copilote, son fantôme.
		local timer = StageTimer.new(car, context.PlayerGui)
		local copilot = Copilot.new(car, context.PlayerGui)
		local ghost = Ghost.new(self.Chassis)
		if context.TouchLayout then
			timer:SetTouchLayout(true)
			copilot:SetTouchLayout(true)
		end
		timer:SetPersonalBest(context.StageBestMs)
		ghost:SetBest(context.StageGhost)

		-- Le verdict du serveur peut arriver juste AVANT que le chrono local ne
		-- voie la ligne : l'envoi du fantôme attend alors la fin de l'enregistrement.
		timer.OnRunStarted = function()
			self.GhostUploadPending = false
			ghost:StartRun()
		end
		timer.OnRunFinished = function(_seconds: number)
			ghost:FinishRun()
			if self.GhostUploadPending then
				self.GhostUploadPending = false
				self:_uploadGhost()
			end
		end
		timer.OnRunCancelled = function()
			self.GhostUploadPending = false
			ghost:CancelRun()
		end
		self.StageTimer = timer
		self.Copilot = copilot
		self.Ghost = ghost
	elseif model:GetAttribute("Contacts") == true then
		self.Contact = CarContact.new(car, self.RaceId :: string)
	end

	self:RefreshIgnoreList()
	return self
end

--[[
	Rayons de suspension : tout ce qui est solidaire de la voiture doit être
	exclu (roues visuelles, carrosserie, pilote soudé), sinon ils tapent dedans
	au lieu de toucher le sol. Les autres voitures sont traversées grâce au
	groupe de collision (voir Wheel.luau).
]]
function DrivingSession:RefreshIgnoreList()
	local ignore: { Instance } = { self.Model }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	self.Car:SetIgnoreList(ignore)
end

function DrivingSession:IsRacing(): boolean
	return self.RaceId ~= nil
end

function DrivingSession:SetControl(granted: boolean)
	if granted == self.HasControl then
		return
	end
	self.HasControl = granted
	if granted then
		self:RefreshIgnoreList()
		-- La caméra part de sa position actuelle et glisse vers la voiture.
		self.ChaseCamera:Enter()
	else
		self.ChaseCamera:Exit()
	end
	self.Dashboard:SetVisible(granted)
	self.Audio:SetActive(granted)
	self.Effects:SetActive(granted)
	local timer, copilot, ghost = self.StageTimer, self.Copilot, self.Ghost
	if timer then
		timer:SetVisible(granted)
	end
	if copilot then
		copilot:SetVisible(granted)
	end
	if ghost then
		ghost:SetVisible(granted)
	end
end

-- Profil chargé après la création de la session (meilleur temps, fantôme).
function DrivingSession:SetStageProfile(bestMs: number?, ghostData: Ghost.GhostData?)
	local timer, ghost = self.StageTimer, self.Ghost
	if timer then
		timer:SetPersonalBest(bestMs)
	end
	if ghost and ghostData then
		ghost:SetBest(ghostData)
	end
end

function DrivingSession:_uploadGhost()
	local ghost = self.Ghost
	local recording = ghost and ghost.LastRecording
	if ghost and recording then
		Remotes.SubmitGhost:FireServer(recording)
		ghost:SetBest(recording)
	end
end

-- Verdict du serveur sur un passage de la spéciale.
function DrivingSession:OnRunValidated(result: any)
	local timer, ghost = self.StageTimer, self.Ghost
	if not timer or not ghost then
		return
	end
	timer:SetOfficialResult(result)
	if type(result) == "table" and result.Valid and result.PersonalBest then
		if ghost.LastRecording then
			self:_uploadGhost()
		else
			self.GhostUploadPending = true
		end
	end
end

-- Positions des autres voitures de la même course (remise en piste sans chevauchement).
function DrivingSession:_otherCarPositions(): { Vector3 }
	local positions = {}
	for _, chassis in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		if chassis ~= self.Chassis and chassis:IsA("BasePart") then
			local model = chassis.Parent
			if model and model:GetAttribute("RaceId") == self.RaceId then
				table.insert(positions, chassis.Position)
			end
		end
	end
	return positions
end

-- Remise en piste : sur la spéciale au paddock, sur le circuit en course.
function DrivingSession:Recover()
	if not self.HasControl or self.Car.Held then
		return
	end
	local timer = self.StageTimer
	if timer then
		timer:Recover()
		return
	end
	local now = os.clock()
	if now - self.LastRecoverAt < RACE_RECOVER_COOLDOWN then
		return
	end
	local circuit = Tracks.FindAt(self.Chassis.Position)
	if circuit then
		self.LastRecoverAt = now
		self.Car:Teleport(circuit:RecoverFrame(self.Chassis.Position, self:_otherCarPositions()))
	end
end

-- Retour au départ de la spéciale (au paddock seulement).
function DrivingSession:Restart()
	local timer = self.StageTimer
	if timer and self.HasControl then
		timer:Restart()
	end
end

function DrivingSession:ShowStageUi(visible: boolean)
	local timer, copilot = self.StageTimer, self.Copilot
	if timer then
		timer:SetVisible(visible and self.HasControl)
	end
	if copilot then
		copilot:SetVisible(visible and self.HasControl)
	end
end

-- Affichage, son, effets : à chaque frame. Renvoie l'état sonore (télémétrie).
function DrivingSession:RenderUpdate(dt: number): CarAudio.AudioState?
	if not self.HasControl then
		return nil
	end
	local audioState = CarAudio.StateFromCar(self.Car)
	self.Dashboard:Update(dt)
	self.Audio:Update(dt, audioState)
	self.Effects:Update(dt)
	local timer = self.StageTimer
	if timer then
		timer:Update(dt)
		local ghost = self.Ghost
		if ghost then
			ghost:Update(dt)
		end
		local copilot = self.Copilot
		if copilot then
			-- Le copilote réutilise l'avancement que le chrono vient de calculer.
			copilot:Update(dt, timer.LastProgress)
		end
	end
	return audioState
end

-- Pas physique (PreSimulation).
function DrivingSession:PhysicsStep(step: number)
	if not self.HasControl then
		return
	end
	self.Car.Held = self.Parked or self.Chassis:GetAttribute("Held") == true
	-- Les rampes du clavier avancent ici, une seule fois par pas physique.
	local inputs = InputManager:Update(step, self.Car:GetForwardSpeed())
	self.Car:Update(step, inputs)
	local contact = self.Contact
	if contact then
		contact:Step(step)
	end
end

function DrivingSession:Destroy()
	if self.HasControl then
		self.ChaseCamera:Exit()
	end
	self.HasControl = false
	self.Dashboard:Destroy()
	self.Audio:Destroy()
	self.Effects:Destroy()
	local timer, copilot, ghost = self.StageTimer, self.Copilot, self.Ghost
	if timer then
		timer:Destroy()
	end
	if copilot then
		copilot:Destroy()
	end
	if ghost then
		ghost:Destroy()
	end
end

return DrivingSession
