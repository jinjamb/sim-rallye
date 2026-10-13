--!strict
--[[
	Slipstream.luau
	L'ASPIRATION : derrière une autre voiture, dans son sillage, l'air est
	déjà en mouvement : la traînée baisse, on va plus vite qu'elle et on
	peut la doubler en sortant du sillage au dernier moment.

	LE SILLAGE d'une voiture qui roule à plus de MIN_SPEED : un cône
	derrière elle, jusqu'à RANGE studs, large de sa voiture au départ et qui
	s'élargit avec la distance. Plus on est près et dans l'axe, plus
	l'aspiration est forte (0..1). Elle réduit la traînée de sa voiture
	jusqu'à MAX_DRAG_CUT (Aerodynamics : DragScale), et s'installe ou se
	perd en quelques dixièmes de seconde (SMOOTH_TIME).

	CE QU'ON VOIT :
		- derrière chaque voiture lancée, une traînée d'air (RemoteCars.luau) ;
		  celle de la voiture qu'on aspire s'allume en cyan ;
		- à l'écran, « ASPIRATION » et une jauge, tant qu'elle agit.

	Calculé chez chaque pilote pour sa propre voiture, à partir des voitures
	des autres qu'il voit (même course, ou le paddock) : ni fantômes ni
	voitures d'une autre course.
]]

local Theme = require(script.Parent.Parent.UI.Theme)

local Slipstream = {}
Slipstream.__index = Slipstream

export type Slipstream = typeof(setmetatable({}, Slipstream)) & {
	Gui: ScreenGui,
	Label: TextLabel,
	Fill: Frame,
	Strength: number,
	Leader: number?, -- UserId de la voiture aspirée
}

local RANGE = 55 -- studs derrière la voiture de tête
local MIN_GAP = 4 -- studs : plus près, on est dans son pare-chocs, pas dans le sillage
local HALF_WIDTH = 3.2 -- demi-largeur du sillage au pare-chocs
local WIDENING = 0.06 -- élargissement par stud de distance
local MIN_SPEED = 40 -- studs/s (~40 km/h) : en dessous, pas de sillage
local MAX_DRAG_CUT = 0.7 -- traînée en moins, aspiration complète
local SMOOTH_TIME = 0.25 -- secondes
local SHOW_THRESHOLD = 0.08 -- jauge affichée au-delà

function Slipstream.new(playerGui: Instance): Slipstream
	local self = (setmetatable({}, Slipstream) :: any) :: Slipstream
	self.Strength = 0
	self.Leader = nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "Slipstream"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.64)
	frame.Size = UDim2.fromOffset(180, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.FontFace = Theme.HEADLINE
	label.TextSize = 18
	label.TextColor3 = Theme.CYAN
	label.Text = "»» ASPIRATION ««"
	label.Parent = frame
	Theme.TextInk(label, 2)
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(20, 26)
	track.Size = UDim2.new(1, -40, 0, 5)
	track.BackgroundColor3 = Theme.INK
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.CYAN
	fill.BorderSizePixel = 0
	fill.Parent = track
	gui.Parent = playerGui
	Theme.Skin(gui)
	self.Gui = gui
	self.Label = label
	self.Fill = fill
	return self
end

-- L'aspiration de `chassis` dans le sillage de `other` (0..1).
local function draftOf(chassis: BasePart, other: BasePart): number
	local frame = other.CFrame
	local forward = frame.LookVector
	if other.AssemblyLinearVelocity:Dot(forward) < MIN_SPEED then
		return 0
	end
	-- Sa propre voiture doit aller dans le même sens.
	if chassis.CFrame.LookVector:Dot(forward) < 0.7 then
		return 0
	end
	local offset = chassis.Position - frame.Position
	local behind = -offset:Dot(forward)
	if behind < MIN_GAP or behind > RANGE then
		return 0
	end
	local lateral = (offset + forward * behind).Magnitude
	local width = HALF_WIDTH + behind * WIDENING
	if lateral > width then
		return 0
	end
	local distanceFactor = 1 - (behind - MIN_GAP) / (RANGE - MIN_GAP)
	local axisFactor = 1 - (lateral / width) ^ 2
	return distanceFactor * axisFactor
end

--[[
	Une fois par image. `car` : sa voiture (nil : à pied, pas d'aspiration) ;
	`others` : les voitures visibles des autres (UserId -> châssis).
	Renvoie le UserId de la voiture aspirée (nil : aucune).
]]
function Slipstream:Update(dt: number, car: any, others: { [number]: BasePart }): number?
	local best = 0
	local leader: number? = nil
	if car then
		local chassis: BasePart = car.Chassis
		for userId, other in pairs(others) do
			local strength = draftOf(chassis, other)
			if strength > best then
				best, leader = strength, userId
			end
		end
	end
	self.Strength += (best - self.Strength) * (1 - math.exp(-dt / SMOOTH_TIME))
	if self.Strength < 0.01 then
		leader = nil
	end
	self.Leader = leader or (if self.Strength > SHOW_THRESHOLD then self.Leader else nil)
	if car then
		car.Aerodynamics.DragScale = 1 - MAX_DRAG_CUT * self.Strength
	end
	self.Gui.Enabled = self.Strength > SHOW_THRESHOLD
	self.Fill.Size = UDim2.fromScale(math.clamp(self.Strength, 0, 1), 1)
	return self.Leader
end

return Slipstream
