--!strict
--[[
	Copilot.luau
	Le copilote : annonce les notes (Pacenotes.luau) avant d'y arriver.

	ANTICIPATION : comme un vrai copilote, il lit à l'avance d'un temps à peu
	près constant, pas d'une distance constante -- à 150 km/h il faut entendre
	le virage bien plus tôt qu'à 50. Une note est annoncée quand on en est à
	moins de LEAD_TIME secondes (bornée entre MIN_LEAD et MAX_LEAD studs), et
	disparaît quand on l'atteint.

	AFFICHAGE : bandeau en haut au centre, la note immédiate en grand, les
	suivantes déjà annoncées en dessous, plus petites. Texte seul pour l'instant :
	pas de voix (il faudrait une série d'enregistrements de mots en français).

	L'avancement le long du tracé est fourni par StageTimer (même calcul) ; un
	bond d'avancement (retour au départ, remise en piste) resynchronise les notes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pacenotes = require(ReplicatedStorage.Shared.Stage.Pacenotes)
local CarClass = require(script.Parent.Parent.Physics.Car)
local Theme = require(script.Parent.Parent.UI.Theme)

local Copilot = {}
Copilot.__index = Copilot

export type Copilot = typeof(setmetatable({}, Copilot)) & {
	Car: CarClass.Car,
	Notes: { Pacenotes.Note },
	NextIndex: number, -- première note pas encore annoncée
	Called: { number }, -- notes annoncées et pas encore atteintes (indices)
	LastProgress: number?,
	Gui: ScreenGui,
	Scale: UIScale,
	Panel: Frame,
	Lines: { TextLabel },
}

local LEAD_TIME = 3.5 -- secondes d'anticipation
local MIN_LEAD, MAX_LEAD = 90, 450 -- studs
local RESYNC_JUMP = 80 -- studs : au-delà, c'est une téléportation, pas un déplacement
local MAX_LINES = 3

local PANEL_WIDTH = 560
local LINE_HEIGHTS = { 50, 34, 28 }
local MAIN_SIZES = { 40, 26, 21 }
local DETAIL_SIZES = { 22, 17, 15 }
local LINE_TRANSPARENCY = { 0, 0.35, 0.55 }

local COLOR_PANEL = Theme.PANEL

function Copilot.new(car: CarClass.Car, playerGui: Instance): Copilot
	local self = (setmetatable({}, Copilot) :: any) :: Copilot
	self.Car = car
	self.Notes = Pacenotes.Generate()
	self.NextIndex = 1
	self.Called = {}
	self.LastProgress = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "Copilot"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	self.Gui = gui

	local totalHeight = 16
	for _, height in ipairs(LINE_HEIGHTS) do
		totalHeight += height
	end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 16)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, totalHeight)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	panel.Parent = gui
	self.Panel = panel
	self.Scale = scale

	self.Lines = {}
	local y = 8
	for i = 1, MAX_LINES do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, y)
		label.Size = UDim2.new(1, -24, 0, LINE_HEIGHTS[i])
		label.RichText = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextTransparency = LINE_TRANSPARENCY[i]
		label.TextSize = MAIN_SIZES[i]
		label.Text = ""
		label.Parent = panel
		self.Lines[i] = label
		y += LINE_HEIGHTS[i]
	end

	gui.Parent = playerGui
	return self
end

function Copilot:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function Copilot:Destroy()
	self.Gui:Destroy()
end

-- Disposition tactile : la rangée d'actions occupe le haut de l'écran, le
-- bandeau du copilote descend juste en dessous.
function Copilot:SetTouchLayout(enabled: boolean)
	self.Panel.Position = UDim2.new(0.5, 0, 0, if enabled then 50 else 16)
end

-- Repart de la position actuelle : plus rien d'annoncé, prochaine note = la
-- première devant la voiture.
function Copilot:_resync(progress: number)
	self.Called = {}
	self.NextIndex = #self.Notes + 1
	for i, note in ipairs(self.Notes) do
		if note.Distance > progress then
			self.NextIndex = i
			break
		end
	end
end

local function lineText(note: Pacenotes.Note, line: number): string
	local main = string.format('<font size="%d">%s</font>', MAIN_SIZES[line], note.Main)
	if note.Detail == "" then
		return main
	end
	return string.format(
		'%s  <font size="%d" color="#B4B8C2">%s</font>',
		main,
		DETAIL_SIZES[line],
		note.Detail
	)
end

function Copilot:Update(_dt: number, progress: number)
	local last = self.LastProgress
	if last == nil or math.abs(progress - last) > RESYNC_JUMP then
		self:_resync(progress)
	end
	self.LastProgress = progress

	-- Notes atteintes : retirées.
	local still = {}
	for _, index in ipairs(self.Called) do
		if self.Notes[index].Distance > progress then
			table.insert(still, index)
		end
	end
	self.Called = still

	-- Nouvelles annonces, selon la vitesse.
	local speed = self.Car.Chassis.AssemblyLinearVelocity.Magnitude
	local lead = math.clamp(speed * LEAD_TIME, MIN_LEAD, MAX_LEAD)
	while self.NextIndex <= #self.Notes and self.Notes[self.NextIndex].Distance - progress <= lead do
		table.insert(self.Called, self.NextIndex)
		self.NextIndex += 1
	end

	local viewport = workspace.CurrentCamera.ViewportSize
	self.Scale.Scale = math.clamp(viewport.Y / 1080, 0.6, 1.2)

	self.Panel.Visible = #self.Called > 0
	for line, label in ipairs(self.Lines) do
		local index = self.Called[line]
		label.Text = if index then lineText(self.Notes[index], line) else ""
	end
end

return Copilot
