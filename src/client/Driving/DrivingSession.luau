--!strict
--[[
	DrivingSession.luau
	Tout ce qui vit avec UNE voiture du joueur : physique, tableau de bord, son,
	poussière, caméra de poursuite, points de style (dérapages, sauts), et
	selon le contexte :
		- au paddock (pas d'attribut RaceId) : chrono de la spéciale, copilote,
		  fantôme ; pour le défi de la semaine (attribut Weekly), la contrainte
		  (StageModifier), sans fantôme ;
		- à l'école de pilotage (attribut Lesson) : la leçon (DrivingSchool),
		  sans chrono de spéciale ni fantôme ;
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
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local CarClass = require(script.Parent.Parent.Physics.Car)
local InputManager = require(script.Parent.Parent.Core.InputManager)
local Dashboard = require(script.Parent.Dashboard)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local StageTimer = require(script.Parent.Parent.Stage.StageTimer)
local ChaseCamera = require(script.Parent.Parent.Camera.ChaseCamera)
local CarEffects = require(script.Parent.CarEffects)
local Copilot = require(script.Parent.Parent.Stage.Copilot)
local Ghost = require(script.Parent.Parent.Stage.Ghost)
local StylePoints = require(script.Parent.StylePoints)
local StageModifier = require(script.Parent.Parent.Stage.StageModifier)
local DrivingSchool = require(script.Parent.Parent.School.DrivingSchool)
local Lessons = require(ReplicatedStorage.Shared.School.Lessons)
local Weekly = require(ReplicatedStorage.Shared.Challenges.Weekly)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local CarContact = require(script.Parent.CarContact)

local DrivingSession = {}
DrivingSession.__index = DrivingSession

-- Record de la spéciale dans une catégorie : temps officiel et fantôme.
export type StageBest = { Ms: number?, Ghost: Ghost.GhostData? }

export type Context = {
	PlayerGui: Instance,
	Camera: Camera,
	TouchLayout: boolean,
	-- Réglages et records, par catégorie de voiture (CarClasses.luau).
	Setups: { [string]: CarSetup.Setup },
	StageBests: { [string]: StageBest },
	-- Défi du fantôme (GhostChallenge.luau) : adversaire choisi, ou fantôme masqué.
	GhostOpponent: Ghost.Opponent?,
	GhostHidden: boolean,
	-- Défi de la semaine : son meilleur temps de la semaine.
	WeeklyBestMs: number?,
	-- École de pilotage : meilleure médaille (0 à 4) par leçon.
	LessonBests: { [string]: number },
}

export type DrivingSession = typeof(setmetatable({}, DrivingSession)) & {
	Model: Model,
	Chassis: BasePart,
	Car: CarClass.Car,
	ClassId: string, -- catégorie de la voiture (attribut CarClass)
	RaceId: string?,
	Dashboard: Dashboard.Dashboard,
	Audio: CarAudio.CarAudio,
	Effects: CarEffects.CarEffects,
	ChaseCamera: ChaseCamera.ChaseCamera,
	Style: StylePoints.StylePoints,
	StageTimer: StageTimer.StageTimer?,
	Copilot: Copilot.Copilot?,
	Ghost: Ghost.Ghost?,
	Contact: CarContact.CarContact?,
	-- Défi de la semaine (clé de semaine) et de quoi défaire sa contrainte.
	Weekly: string?,
	UndoModifier: (() -> ())?,
	-- Leçon de l'école de pilotage en cours.
	School: DrivingSchool.DrivingSchool?,
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
	local weekly = model:GetAttribute("Weekly")
	self.Weekly = if type(weekly) == "string" and self.RaceId == nil then weekly else nil
	self.UndoModifier = nil
	self.School = nil
	local lessonId = model:GetAttribute("Lesson")
	local lesson = if self.RaceId == nil and type(lessonId) == "string" then Lessons.Get(lessonId) else nil

	self.ClassId = CarClasses.Get(model:GetAttribute("CarClass")).Id
	local car = CarClass.new(self.Chassis, self.ClassId)
	car:ApplySetup(context.Setups[self.ClassId] or CarSetup.Default(self.ClassId))
	self.Car = car

	local wheelAttachments: { Attachment } = {}
	for i, wheel in ipairs(car.Wheels) do
		wheelAttachments[i] = wheel.Attachment
	end

	self.Dashboard = Dashboard.new(car, context.PlayerGui)
	self.Audio = CarAudio.new(self.Chassis, wheelAttachments, true)
	self.Effects = CarEffects.new(self.Chassis, car.Wheels :: any)
	self.ChaseCamera = ChaseCamera.new(car, context.Camera)
	self.Style = StylePoints.new(car, context.PlayerGui)
	-- Les points de style comptent en compétition : course, ou spéciale chronométrée.
	self.Style.Counting = function()
		if self.RaceId ~= nil then
			return true
		end
		local timer = self.StageTimer
		return timer ~= nil and timer.State == "Running"
	end
	if context.TouchLayout then
		self.Dashboard:SetTouchLayout(true)
	end

	if lesson then
		-- École de pilotage : la leçon seulement (pas de chrono de spéciale).
		local school = DrivingSchool.new(car, context.PlayerGui, lesson, context.LessonBests[lesson.Id] or 0)
		if context.TouchLayout then
			school:SetTouchLayout(true)
		end
		self.School = school
	elseif self.RaceId == nil then
		-- Au paddock : la spéciale, son chrono, son copilote, son fantôme.
		local timer = StageTimer.new(car, context.PlayerGui)
		local copilot = Copilot.new(car, context.PlayerGui)
		local ghost = Ghost.new(self.Chassis)
		if context.TouchLayout then
			timer:SetTouchLayout(true)
			copilot:SetTouchLayout(true)
		end
		local best: StageBest = context.StageBests[self.ClassId] or { Ms = nil, Ghost = nil }
		timer:SetClass(self.ClassId)
		timer:SetPersonalBest(best.Ms)
		ghost:SetBest(best.Ghost)
		ghost:SetOpponent(context.GhostOpponent)
		ghost:SetHidden(context.GhostHidden)
		timer:SetGhost(ghost)
		-- Défi de la semaine : la contrainte, sans fantôme (il a roulé sans elle).
		if self.Weekly then
			local modifierId = model:GetAttribute("Modifier")
			local modifier = Weekly.ModifierById(if type(modifierId) == "string" then modifierId else nil)
			if modifier then
				self.UndoModifier = StageModifier.Apply(car, modifier.Id)
				timer:SetWeekly(modifier.Name, context.WeeklyBestMs)
			end
			ghost:SetHidden(true)
		end

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

-- Passage chronométré de la spéciale, ou leçon de l'école, en cours.
function DrivingSession:IsRunInProgress(): boolean
	local timer = self.StageTimer
	local school = self.School
	return (timer ~= nil and timer.State == "Running") or (school ~= nil and school.State == "Running")
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
	self.Style:SetVisible(granted)
	self.Audio:SetActive(granted)
	self.Effects:SetActive(granted)
	local timer, copilot, ghost = self.StageTimer, self.Copilot, self.Ghost
	local school = self.School
	if school then
		school:SetVisible(granted)
	end
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
-- Records chargés après la voiture : ceux de sa catégorie.
function DrivingSession:SetStageProfile(bests: { [string]: StageBest })
	local best = bests[self.ClassId]
	if not best then
		return
	end
	local timer, ghost = self.StageTimer, self.Ghost
	if timer then
		timer:SetPersonalBest(best.Ms)
	end
	if ghost and best.Ghost then
		ghost:SetBest(best.Ghost)
	end
end

-- Défi du fantôme : contre qui on roule (nil = son propre record), ou rien.
function DrivingSession:SetGhostChoice(opponent: Ghost.Opponent?, hidden: boolean)
	local ghost = self.Ghost
	if ghost then
		ghost:SetOpponent(opponent)
		-- Au défi de la semaine, le fantôme reste masqué quoi qu'on choisisse.
		ghost:SetHidden(hidden or self.Weekly ~= nil)
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
	local school = self.School
	if school then
		self.Style:Reset()
		school:Recover()
		return
	end
	local timer = self.StageTimer
	if timer then
		self.Style:Reset()
		timer:Recover()
		-- Le serveur note que ce passage n'est plus « sans remise en piste ».
		Remotes.Recovered:FireServer()
		return
	end
	local now = os.clock()
	if now - self.LastRecoverAt < RACE_RECOVER_COOLDOWN then
		return
	end
	local circuit = Tracks.FindAt(self.Chassis.Position)
	if circuit then
		self.LastRecoverAt = now
		self.Style:Reset()
		self.Car:Teleport(circuit:RecoverFrame(self.Chassis.Position, self:_otherCarPositions()))
	end
end

-- Retour au départ de la spéciale (au paddock seulement).
function DrivingSession:Restart()
	local school = self.School
	if school and self.HasControl then
		self.Style:Reset(false)
		school:Restart()
		return
	end
	local timer = self.StageTimer
	if timer and self.HasControl then
		self.Style:Reset(false)
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
	if not self.Parked then
		self.Style:Update(dt)
	end
	self.Audio:Update(dt, audioState)
	self.Effects:Update(dt)
	local school = self.School
	if school then
		school:Update(dt)
	end
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
	local undo: (() -> ())? = self.UndoModifier
	self.UndoModifier = nil
	if undo then
		undo()
	end
	self.HasControl = false
	self.Dashboard:Destroy()
	self.Style:Destroy()
	self.Audio:Destroy()
	self.Effects:Destroy()
	local school: DrivingSchool.DrivingSchool? = self.School
	self.School = nil
	if school then
		school:Destroy()
	end
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
