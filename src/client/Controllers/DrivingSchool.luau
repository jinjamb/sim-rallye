--!strict
--[[
	DrivingSchool.luau
	Une leçon de l'école de pilotage (Lessons.luau), pour la durée d'une
	voiture (DrivingSession, attribut Lesson posé par le serveur).

	REPÈRES SUR LA ROUTE (locaux, chez ce joueur seulement) : portiques jaunes
	au départ et à l'arrivée ; pour le freinage, la zone jaune et la ligne
	blanche de la cible.

	DÉROULEMENT :
		Prête    : la voiture attend derrière le portique de départ.
		En cours : mesures (vitesse, chrono, décollage...).
		Finie    : médaille (ou raté, avec la raison) ; Retour arrière pour
		           recommencer, C pour le menu.
	Freinage : prendre de l'élan (MinSpeed), s'arrêter : noté sur l'écart à
	la cible. Chrono : du portique de départ au portique d'arrivée.
	Saut : vitesse au bout du tremplin, réception sur les roues, sur la route.

	La meilleure médaille est envoyée au serveur (LessonResult) ; une
	nouvelle médaille est annoncée en grand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Lessons = require(ReplicatedStorage.Shared.Constants.Lessons)
local Medals = require(ReplicatedStorage.Shared.Constants.Medals)
local Units = require(ReplicatedStorage.Shared.Constants.Units)
local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)
local CarClass = require(script.Parent.Parent.Physics.Car)
local Theme = require(script.Parent.Parent.UI.Theme)
local Banner = require(script.Parent.Banner)

local DrivingSchool = {}
DrivingSchool.__index = DrivingSchool

type State = "Ready" | "Running" | "Done" | "Failed"

export type DrivingSchool = typeof(setmetatable({}, DrivingSchool)) & {
	Car: CarClass.Car,
	Lesson: Lessons.Lesson,
	Best: number, -- meilleure médaille déjà obtenue (0 à 4)
	StartDistance: number,
	EndDistance: number,
	GateDistance: number, -- portique de départ (chrono, saut)
	CrestDistance: number?, -- bout du tremplin (saut)

	State: State,
	Hint: number, -- dernier échantillon du tracé (recherche locale)
	Progress: number,
	StartClock: number,
	MaxKmh: number,
	TakeoffKmh: number?,
	TakeoffClock: number,
	AirTime: number,
	ResultText: string,
	ResultColor: Color3,

	Markers: Folder,
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	Title: TextLabel,
	Live: TextLabel,
	Result: TextLabel,
}

local GATE_AHEAD = 15 -- studs entre la voiture posée et le portique de départ
local STOPPED_SPEED = 0.8 -- studs/s : la voiture est arrêtée
local OVERSHOOT = 25 -- studs au-delà de la ligne droite : freinage raté
local TAKEOFF_TIMEOUT = 2.5 -- s après le tremplin sans décoller : raté
local MIN_TAKEOFF_KMH = 60
local LOCATE_WINDOW = 30
local PANEL_WIDTH = 420

-- Virgule décimale, à la française.
local function comma(text: string): string
	return (string.gsub(text, "%.", ","))
end

local function studsToMeters(studs: number): string
	return comma(string.format("%.1f m", studs * Units.METERS_PER_STUD))
end

-- Repère : une pièce locale, ancrée, sans collision.
local function marker(parent: Instance, size: Vector3, frame: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = frame
	part.Parent = parent
	return part
end

-- Ligne en travers de la route à l'abscisse `distance`, et deux poteaux.
local function gate(parent: Instance, distance: number, color: Color3, posts: boolean)
	local sample = StageTrack.SampleAt(distance)
	local base = CFrame.lookAt(sample.Position, sample.Position + sample.ForwardFlat)
	marker(parent, Vector3.new(StageTrack.ROAD_WIDTH, 0.15, 1), base * CFrame.new(0, 0.1, 0), color, 0.1)
	if posts then
		for _, side in ipairs({ -1, 1 }) do
			marker(parent, Vector3.new(0.6, 9, 0.6), base * CFrame.new(side * (StageTrack.ROAD_WIDTH / 2 + 1), 4.5, 0), color, 0)
		end
	end
end

function DrivingSchool.new(car: CarClass.Car, playerGui: Instance, lesson: Lessons.Lesson, best: number): DrivingSchool
	local self = (setmetatable({}, DrivingSchool) :: any) :: DrivingSchool
	self.Car = car
	self.Lesson = lesson
	self.Best = best
	local startDistance, endDistance = Lessons.Distances(lesson)
	self.StartDistance = startDistance
	self.EndDistance = endDistance
	self.GateDistance = startDistance + GATE_AHEAD
	self.CrestDistance = if lesson.RampSegment then StageTrack.GetSegments()[lesson.RampSegment].EndDistance else nil
	car.HandbrakeDisabled = lesson.NoHandbrake == true

	-- Repères sur la route.
	local markers = Instance.new("Folder")
	markers.Name = "DrivingSchool"
	self.Markers = markers
	if lesson.Kind == "Brake" then
		local segment = StageTrack.GetSegments()[lesson.StartSegment]
		local zoneStart = segment.StartDistance + (lesson.ZoneOffset or 0)
		local zoneEnd = segment.EndDistance
		local middle = StageTrack.SampleAt((zoneStart + zoneEnd) / 2)
		marker(
			markers,
			Vector3.new(StageTrack.ROAD_WIDTH, 0.1, zoneEnd - zoneStart),
			CFrame.lookAt(middle.Position, middle.Position + middle.ForwardFlat) * CFrame.new(0, 0.06, 0),
			Theme.ACCENT,
			0.7
		)
		gate(markers, segment.StartDistance + (lesson.TargetOffset or 0), Color3.new(1, 1, 1), true)
	else
		gate(markers, self.GateDistance, Theme.ACCENT, true)
		gate(markers, endDistance, Theme.ACCENT, true)
	end
	markers.Parent = workspace

	-- Panneau : la leçon, la mesure en direct, le résultat.
	local gui = Instance.new("ScreenGui")
	gui.Name = "DrivingSchool"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui
	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(24, 70)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 196)
	panel.BackgroundColor3 = Theme.PANEL
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	Theme.Corner(panel)
	Theme.Shade(panel)
	Theme.AccentBar(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	self.Panel = panel
	self.Scale = scale

	local function text(y: number, height: number, size: number, face: Font, color: Color3, content: string): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(16, y)
		label.Size = UDim2.new(1, -28, 0, height)
		label.FontFace = face
		label.TextSize = size
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.RichText = true
		label.Text = content
		label.Parent = panel
		return label
	end
	local tag = Theme.Tag(panel, "ÉCOLE DE PILOTAGE · " .. string.upper(lesson.Name), Theme.ACCENT, Theme.ON_ACCENT, 14)
	tag.Position = UDim2.fromOffset(16, 12)
	self.Title = text(40, 34, 15, Theme.BODY_BOLD, Theme.TEXT, lesson.Goal)
	text(76, 34, 13, Theme.BODY, Theme.DIM, lesson.Tips)
	self.Live = text(114, 30, 26, Theme.DIGITS, Theme.TEXT, "")
	self.Result = text(146, 44, 14, Theme.BODY_BOLD, Theme.DIM, "")

	gui.Parent = playerGui
	self:_reset()
	return self
end

function DrivingSchool:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function DrivingSchool:SetTouchLayout(enabled: boolean)
	self.Panel.Position = if enabled then UDim2.fromOffset(12, 12) else UDim2.fromOffset(24, 70)
end

function DrivingSchool:Destroy()
	self.Gui:Destroy()
	self.Markers:Destroy()
	self.Car.HandbrakeDisabled = false
end

-- Les seuils des médailles, en clair : « BRONZE 2,8 m · ARGENT ... ».
function DrivingSchool:_limitsText(): string
	local lesson = self.Lesson
	local parts = {}
	for tier, limit in ipairs(lesson.Limits) do
		local value
		if lesson.Kind == "Brake" then
			value = studsToMeters(limit)
		elseif lesson.Kind == "Timed" then
			value = comma(string.format("%.1f s", limit))
		else
			value = string.format("±%g km/h", limit)
		end
		table.insert(parts, Medals.Rich(tier) .. " " .. value)
	end
	return table.concat(parts, "  ·  ")
end

function DrivingSchool:_reset()
	self.State = "Ready"
	self.Hint = 0
	self.Progress = self.StartDistance
	self.StartClock = 0
	self.MaxKmh = 0
	self.TakeoffKmh = nil
	self.TakeoffClock = 0
	self.AirTime = 0
	self.ResultText = self:_limitsText()
	self.ResultColor = Theme.DIM
end

-- Retour au départ de la leçon (Retour arrière).
function DrivingSchool:Restart()
	self.Car:Teleport(Lessons.StartFrame(self.Lesson))
	self:_reset()
end

--[[
	Remise en piste (T) : au chrono, le temps perdu est la pénalité ; au
	freinage et au saut, l'essai est raté.
]]
function DrivingSchool:Recover()
	local sample = StageTrack.Locate(self.Car.Chassis.Position)
	local position = sample.Position + Vector3.new(0, StageTrack.DROP_HEIGHT, 0)
	self.Car:Teleport(CFrame.lookAt(position, position + sample.Forward))
	self.Hint = 0
	if self.State == "Running" and self.Lesson.Kind ~= "Timed" then
		self:_fail("Remis en piste : recommence (Retour arrière).")
	end
end

function DrivingSchool:_fail(reason: string)
	self.State = "Failed"
	self.ResultText = "RATÉ — " .. reason
	self.ResultColor = Theme.RED
end

-- Fin d'un essai réussi : `score` (plus petit = meilleur) et sa description.
function DrivingSchool:_finish(score: number, description: string)
	self.State = "Done"
	local lesson = self.Lesson
	local tier = Lessons.TierOf(lesson, score)
	if RunService:IsStudio() then
		print(string.format("[École] %s : %s (score %.2f, médaille %d)", lesson.Name, description, score, tier))
	end
	local info = Medals.Get(tier)
	if info then
		self.ResultText = string.format("%s — %s", description, Medals.Rich(tier, info.Title))
		self.ResultColor = Theme.TEXT
		if tier > self.Best then
			self.Best = tier
			Remotes.LessonResult:FireServer(lesson.Id, tier)
			Banner.Show(info.Title, "École de pilotage · " .. lesson.Name .. " · " .. description, info.Color, 4, true)
		end
	else
		self.ResultText = description .. " — pas encore de médaille. " .. self:_limitsText()
		self.ResultColor = Theme.ORANGE
	end
end

function DrivingSchool:Update(dt: number)
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)

	local car = self.Car
	local chassis = car.Chassis
	local now = os.clock()
	local sample, progress, lateral
	if self.Hint > 0 then
		sample, progress, lateral = StageTrack.LocateNear(chassis.Position, self.Hint, LOCATE_WINDOW)
	else
		sample, progress, lateral = StageTrack.Locate(chassis.Position)
	end
	self.Hint = sample.Index
	self.Progress = progress
	local speed = car:GetForwardSpeed()
	local kmh = Units.ToKmh(math.abs(speed))
	local lesson = self.Lesson

	if self.State == "Ready" then
		local started = if lesson.Kind == "Brake" then progress > self.StartDistance + 2 else progress >= self.GateDistance
		if started then
			self.State = "Running"
			self.StartClock = now
		end
	end

	if self.State == "Running" then
		self.MaxKmh = math.max(self.MaxKmh, kmh)
		if lesson.Kind == "Brake" then
			local segment = StageTrack.GetSegments()[lesson.StartSegment]
			local target = segment.StartDistance + (lesson.TargetOffset or 0)
			local zoneStart = segment.StartDistance + (lesson.ZoneOffset or 0)
			if progress > segment.EndDistance + OVERSHOOT then
				self:_fail("trop loin, la zone est passée. Freine plus tôt.")
			elseif math.abs(speed) < STOPPED_SPEED and progress > self.StartDistance + 20 then
				if self.MaxKmh < (lesson.MinSpeed or 0) then
					self:_fail(string.format("trop lent : %d km/h au plus, il en faut %d.", math.floor(self.MaxKmh), lesson.MinSpeed or 0))
				elseif progress < zoneStart then
					self:_fail("arrêté avant la zone jaune.")
				else
					local gap = math.abs(progress - target)
					self:_finish(gap, "Arrêt à " .. studsToMeters(gap) .. " de la cible")
				end
			end
			self.Live.Text = string.format("%d km/h · cible à %s", math.floor(kmh), studsToMeters(math.max(0, target - progress)))
		elseif lesson.Kind == "Timed" then
			local elapsed = now - self.StartClock
			if progress >= self.EndDistance then
				self:_finish(elapsed, comma(string.format("%.2f s", elapsed)))
			end
			self.Live.Text = comma(string.format("%.2f s", elapsed))
		else
			local crest = self.CrestDistance or self.EndDistance
			local grounded = 0
			for _, wheel in ipairs(car.Wheels) do
				if wheel.IsGrounded then
					grounded += 1
				end
			end
			local takeoff = self.TakeoffKmh
			if takeoff == nil then
				if progress >= crest then
					self.TakeoffKmh = kmh
					self.TakeoffClock = now
				end
				self.Live.Text = string.format("%d km/h · idéal %d", math.floor(kmh), lesson.IdealSpeed or 0)
			else
				if grounded == 0 then
					self.AirTime += dt
				elseif self.AirTime > 0.15 then
					-- Réception : sur les roues, sur la route ?
					local upright = chassis.CFrame.UpVector.Y > 0.7
					if takeoff < MIN_TAKEOFF_KMH then
						self:_fail(string.format("trop lent au tremplin (%d km/h) : tu retombes à plat.", math.floor(takeoff)))
					elseif not upright then
						self:_fail("réception ratée : la voiture n'est pas retombée sur ses roues.")
					elseif math.abs(lateral) > StageTrack.ROAD_WIDTH / 2 + 3 then
						self:_fail("réception hors de la route.")
					else
						local ideal = lesson.IdealSpeed or 0
						self:_finish(
							math.abs(takeoff - ideal),
							string.format("Décollage à %d km/h, %s en l'air", math.floor(takeoff), comma(string.format("%.1f s", self.AirTime)))
						)
					end
				elseif now - self.TakeoffClock > TAKEOFF_TIMEOUT then
					self:_fail("la voiture n'a pas décollé : prends plus de vitesse.")
				end
				self.Live.Text = string.format("Décollage %d km/h · idéal %d", math.floor(takeoff), lesson.IdealSpeed or 0)
			end
		end
	elseif self.State == "Ready" then
		self.Live.Text = if lesson.Kind == "Brake" then "En avant !" else "Passe le portique jaune"
	end

	-- Raté ou fini : la mesure reste affichée, avec le résultat.
	if self.State == "Done" or self.State == "Failed" then
		self.Result.Text = self.ResultText .. '\n<font color="#8C909A">Retour arrière : recommencer · C : menu</font>'
	else
		self.Result.Text = self.ResultText
	end
	self.Result.TextColor3 = self.ResultColor
end

return DrivingSchool
