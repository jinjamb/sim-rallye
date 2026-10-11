--!strict
--[[
	StylePoints.luau
	Points de style : récompenser la conduite spectaculaire, pas seulement le
	chrono. Ils comptent pour la progression (Progression.luau : 10 points =
	1 XP), donc pour les cosmétiques ; jamais pour le temps ni le classement.

	DÉRAPAGE : la voiture avance de travers -- l'angle entre sa direction et sa
	trajectoire dépasse MIN_ANGLE, à plus de MIN_SPEED, au moins deux roues au
	sol. Les points coulent tant que ça dure, plus vite quand l'angle et la
	vitesse augmentent.
	COMBINAISON : les dérapages qui s'enchaînent (moins de COMBO_GRACE secondes
	entre deux) forment une combinaison. Chaque changement de côté -- le coup
	de balancier gauche-droite des pilotes de rallye -- augmente le
	multiplicateur (jusqu'à ×5). La combinaison est encaissée quand elle
	s'arrête ; elle est PERDUE sur un choc, un tonneau ou une remise en piste.
	SAUT : au moins MIN_AIR secondes en l'air, et retombé sur ses roues.

	EN COMPÉTITION SEULEMENT : les points comptent en spéciale chronométrée et
	en course (`Counting`, fourni par DrivingSession). Aux essais libres, ils
	s'affichent quand même, marqués « essais », mais ne sont pas envoyés.

	Le calcul se fait ici (la physique tourne chez le pilote) ; le serveur
	n'accepte qu'un débit plausible, en compétition (RecordService). Les
	dépassements, eux, sont décidés par le serveur (RaceService) et annoncés
	par RaceClient.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local CarClass = require(script.Parent.Parent.Physics.Car)
local Theme = require(script.Parent.Parent.UI.Theme)

local StylePoints = {}
StylePoints.__index = StylePoints

export type StylePoints = typeof(setmetatable({}, StylePoints)) & {
	Car: CarClass.Car,
	Gui: ScreenGui,
	Root: Frame,
	Scale: UIScale,
	ComboLabel: TextLabel,
	BankLabel: TextLabel,
	TotalLabel: TextLabel,

	-- Combinaison en cours
	Active: boolean,
	Points: number, -- avant multiplicateur
	Multiplier: number,
	Side: number, -- côté du dérapage en cours (-1, 0, 1)
	SideTime: number, -- depuis combien de temps de ce côté
	DriftTime: number,
	LastDriftAt: number,
	-- Saut en cours
	AirTime: number,
	-- Après une remise en piste : rien n'est compté (la voiture retombe).
	IgnoreUntil: number,
	LastSpeed: number,
	Session: number, -- points encaissés depuis la création de la voiture
	BankToken: number,
	-- En compétition ? (spéciale chronométrée, course) ; sinon rien n'est envoyé.
	Counting: () -> boolean,
	CountingUntil: number,
}

local MIN_SPEED = 30 -- studs/s (~30 km/h)
local MIN_ANGLE = 12 -- degrés
local MAX_ANGLE = 100 -- au-delà, la voiture recule ou tourne sur elle-même
local BASE_RATE = 60 -- points par seconde, à 25° et 50 km/h
local MAX_MULTIPLIER = 5
local FLICK_MIN_TIME = 0.25 -- s d'un côté avant qu'un changement compte
local COMBO_GRACE = 1.0 -- s sans déraper avant d'encaisser
local MIN_DRIFT_TIME = 0.6 -- s : en dessous, ce n'était qu'un écart
local MIN_BANK = 20
local CRASH_DECELERATION = 220 -- studs/s² : au-delà, c'est un choc (combinaison perdue)
local MIN_AIR = 0.45 -- s en l'air pour un saut
local JUMP_RATE = 120 -- points par seconde en l'air
local RECOVER_GRACE = 1.2 -- s ignorées après une remise en piste
local COUNTING_GRACE = 4 -- s après l'arrivée où une combinaison finie compte encore

local COLOR_TEXT = Theme.TEXT
local COLOR_DIM = Theme.DIM
local COLOR_LOST = Theme.RED
local MULTIPLIER_COLORS = {
	Color3.fromRGB(235, 236, 240),
	Color3.fromRGB(120, 210, 255),
	Color3.fromRGB(110, 230, 120),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 110, 60),
}

local function label(parent: Instance, y: number, height: number, size: number, font: Enum.Font, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, y)
	text.Size = UDim2.new(1, 0, 0, height)
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.5
	text.Text = ""
	text.Parent = parent
	return text
end

function StylePoints.new(car: CarClass.Car, playerGui: Instance): StylePoints
	local self = (setmetatable({}, StylePoints) :: any) :: StylePoints
	self.Car = car
	self.Active = false
	self.Points = 0
	self.Multiplier = 1
	self.Side = 0
	self.SideTime = 0
	self.DriftTime = 0
	self.LastDriftAt = 0
	self.AirTime = 0
	self.IgnoreUntil = os.clock() + RECOVER_GRACE -- la voiture vient d'être posée
	self.LastSpeed = 0
	self.Session = 0
	self.BankToken = 0
	self.Counting = function()
		return true
	end
	self.CountingUntil = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "StylePoints"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui
	-- Au centre, sous la voiture (la caméra de poursuite la place au centre).
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, 0.64)
	root.Size = UDim2.fromOffset(420, 90)
	root.Parent = gui
	self.Root = root
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale
	self.ComboLabel = label(root, 0, 34, 28, Enum.Font.GothamBlack, COLOR_TEXT)
	self.BankLabel = label(root, 36, 28, 22, Enum.Font.GothamBlack, COLOR_TEXT)
	self.TotalLabel = label(root, 66, 18, 13, Enum.Font.GothamBold, COLOR_DIM)
	gui.Parent = playerGui
	return self
end

function StylePoints:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function StylePoints:Destroy()
	self.Gui:Destroy()
end

-- Message bref sous la combinaison ("+1 240", "SAUT 1.2 s +140", "COMBO PERDU").
function StylePoints:_flash(text: string, color: Color3)
	self.BankToken += 1
	local token = self.BankToken
	local bank = self.BankLabel
	bank.Text = text
	bank.TextColor3 = color
	bank.TextTransparency = 0
	bank.TextStrokeTransparency = 0.5
	task.delay(1.6, function()
		if token == self.BankToken then
			local info = TweenInfo.new(0.4)
			TweenService:Create(bank, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Envoie des points encaissés ; false s'ils ne comptent pas (essais libres).
-- `detail` : multiplicateur d'une combinaison, temps en l'air d'un saut (défis du jour).
function StylePoints:_submit(points: number, kind: string, detail: any): boolean
	if os.clock() >= self.CountingUntil then
		return false
	end
	self.Session += points
	self.TotalLabel.Text = "STYLE  " .. Format.Thousands(self.Session)
	Remotes.SubmitStyle:FireServer(points, kind, detail)
	return true
end

function StylePoints:_endCombo()
	self.Active = false
	self.Points = 0
	self.Multiplier = 1
	self.Side = 0
	self.SideTime = 0
	self.DriftTime = 0
	self.ComboLabel.Text = ""
end

-- Fin normale d'une combinaison : encaissée.
function StylePoints:_bank()
	local total = math.floor(self.Points * self.Multiplier)
	if self.DriftTime >= MIN_DRIFT_TIME and total >= MIN_BANK then
		local counted = self:_submit(total, "Drift", { Multiplier = self.Multiplier })
		local text = "+" .. Format.Thousands(total)
		if self.Multiplier > 1 then
			text ..= string.format("  (×%d)", self.Multiplier)
		end
		if not counted then
			text ..= "  · essais, non compté"
		end
		self:_flash(text, if counted then MULTIPLIER_COLORS[self.Multiplier] else COLOR_DIM)
	end
	self:_endCombo()
end

-- Choc, tonneau, remise en piste : la combinaison est perdue.
function StylePoints:Reset(lost: boolean?)
	if self.Active and lost ~= false and self.DriftTime >= MIN_DRIFT_TIME then
		self:_flash("COMBO PERDU", COLOR_LOST)
	end
	self:_endCombo()
	self.AirTime = 0
	self.IgnoreUntil = os.clock() + RECOVER_GRACE
end

function StylePoints:Update(dt: number)
	if dt <= 0 then
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)

	local now = os.clock()
	if self.Counting() then
		self.CountingUntil = now + COUNTING_GRACE
	end
	local car = self.Car
	local chassis = car.Chassis
	local frame = chassis.CFrame
	local velocity = chassis.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	local deceleration = (self.LastSpeed - speed) / dt
	self.LastSpeed = speed

	if now < self.IgnoreUntil or car.Held then
		self.AirTime = 0
		return
	end

	local grounded = 0
	for _, wheel in ipairs(car.Wheels) do
		if wheel.IsGrounded then
			grounded += 1
		end
	end
	local upright = frame.UpVector.Y > 0.5

	-- Choc ou tonneau : tout est perdu.
	if not upright or deceleration > CRASH_DECELERATION then
		if self.Active or self.AirTime > 0 then
			self:Reset(true)
		end
		return
	end

	-- Saut : compté à la réception, sur ses roues.
	if grounded == 0 then
		self.AirTime += dt
	elseif self.AirTime > 0 then
		local air = self.AirTime
		self.AirTime = 0
		if air >= MIN_AIR and grounded >= 2 then
			local points = math.floor(JUMP_RATE * air)
			local counted = self:_submit(points, "Jump", { Air = air })
			self:_flash(
				string.format("SAUT %.1f s  +%s%s", air, Format.Thousands(points), if counted then "" else "  · essais"),
				if counted then COLOR_TEXT else COLOR_DIM
			)
		end
	end

	-- Dérapage : angle entre l'axe de la voiture et sa trajectoire.
	local look = frame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local drifting = false
	local side = 0
	local angle = 0
	if speed >= MIN_SPEED and grounded >= 2 and forward.Magnitude > 0.1 then
		local cosine = math.clamp(flat.Unit:Dot(forward.Unit), -1, 1)
		angle = math.deg(math.acos(cosine))
		drifting = angle >= MIN_ANGLE and angle <= MAX_ANGLE
		side = if forward:Cross(flat).Y > 0 then 1 else -1
	end

	if drifting then
		if not self.Active then
			self.Active = true
			self.Side = side
			self.SideTime = 0
		end
		-- Coup de balancier : changement de côté après un vrai dérapage.
		if side ~= self.Side then
			if self.SideTime >= FLICK_MIN_TIME then
				self.Multiplier = math.min(MAX_MULTIPLIER, self.Multiplier + 1)
			end
			self.Side = side
			self.SideTime = 0
		end
		self.SideTime += dt
		self.DriftTime += dt
		self.LastDriftAt = now
		local angleFactor = math.clamp(angle / 25, 0.6, 2.4)
		local speedFactor = math.clamp(speed / 50, 0.6, 2)
		self.Points += BASE_RATE * angleFactor * speedFactor * dt
	elseif self.Active and now - self.LastDriftAt > COMBO_GRACE then
		self:_bank()
	end

	if self.Active and self.DriftTime >= MIN_DRIFT_TIME then
		local text = "DÉRAPAGE  " .. Format.Thousands(math.floor(self.Points))
		if self.Multiplier > 1 then
			text ..= string.format("  ×%d", self.Multiplier)
		end
		self.ComboLabel.Text = text
		self.ComboLabel.TextColor3 = MULTIPLIER_COLORS[self.Multiplier]
	else
		self.ComboLabel.Text = ""
	end
end

return StylePoints
