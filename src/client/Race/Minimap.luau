--!strict
--[[
	Minimap.luau
	Plan du circuit vu de dessus, nord en haut, avec la position des voitures de
	la course. Le tracé est dessiné en points (un tous les ~12 studs) : simple,
	et assez dense pour se lire comme une ligne à cette taille.
		- boucle en gris clair, joker en orange, ligne de départ en blanc ;
		- sa voiture en jaune, plus grosse ; les autres en blanc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Circuit = require(ReplicatedStorage.Shared.Tracks.Circuit)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local Minimap = {}
Minimap.__index = Minimap

export type CarDot = { Position: Vector3, Me: boolean }

export type Minimap = typeof(setmetatable({}, Minimap)) & {
	Frame: Frame,
	Circuit: Circuit.Circuit,
	Min: Vector2,
	Scale: number,
	Offset: Vector2,
	Dots: { Frame },
}

local SIZE = 190
local PADDING = 12
local TRACK_EVERY = 3 -- un point tous les 3 échantillons (12 studs)
local TRACK_DOT = 3
local CAR_DOT = 9
local MY_DOT = 13

function Minimap.new(parent: Instance, circuit: Circuit.Circuit): Minimap
	local self = (setmetatable({}, Minimap) :: any) :: Minimap
	self.Circuit = circuit
	self.Dots = {}

	local frame = Widgets.Panel(parent, 0.35)
	frame.Name = "Minimap"
	frame.Size = UDim2.fromOffset(SIZE, SIZE)
	frame.ClipsDescendants = true
	self.Frame = frame

	local low, high = circuit:GetBounds()
	local range = high - low
	local usable = SIZE - 2 * PADDING
	local scale = usable / math.max(range.X, range.Y, 1)
	self.Min = low
	self.Scale = scale
	-- Centré dans le cadre.
	self.Offset = Vector2.new(PADDING + (usable - range.X * scale) / 2, PADDING + (usable - range.Y * scale) / 2)

	local function dot(position: Vector3, size: number, color: Color3, z: number): Frame
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(size, size)
		d.BackgroundColor3 = color
		d.BorderSizePixel = 0
		d.ZIndex = z
		d.Position = self:_map(position)
		Widgets.Corner(d, math.ceil(size / 2))
		d.Parent = frame
		return d
	end

	for index, sample in ipairs(circuit.Samples) do
		if index % TRACK_EVERY == 0 then
			dot(sample.Position, TRACK_DOT, Color3.fromRGB(200, 202, 210), 2)
		end
	end
	for index, sample in ipairs(circuit.JokerSamples) do
		if index % TRACK_EVERY == 0 then
			dot(sample.Position, TRACK_DOT, Widgets.COLOR_ORANGE, 2)
		end
	end
	-- Ligne de départ / arrivée.
	local start = circuit.Samples[1]
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.fromOffset(10, 3)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.ZIndex = 3
	line.Position = self:_map(start.Position)
	-- Perpendiculaire au sens de course (vu de dessus : X vers la droite, Z vers le bas).
	line.Rotation = math.deg(math.atan2(start.ForwardFlat.Z, start.ForwardFlat.X)) + 90
	line.Parent = frame

	return self
end

function Minimap:_map(position: Vector3): UDim2
	local u = (position.X - self.Min.X) * self.Scale + self.Offset.X
	local v = (position.Z - self.Min.Y) * self.Scale + self.Offset.Y
	return UDim2.fromOffset(u, v)
end

function Minimap:Update(cars: { CarDot })
	for index, car in ipairs(cars) do
		local d = self.Dots[index]
		if not d then
			d = Instance.new("Frame")
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.BorderSizePixel = 0
			Widgets.Corner(d, 8)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Thickness = 1.5
			stroke.Parent = d
			d.Parent = self.Frame
			self.Dots[index] = d
		end
		local size = if car.Me then MY_DOT else CAR_DOT
		d.Size = UDim2.fromOffset(size, size)
		d.BackgroundColor3 = if car.Me then Widgets.COLOR_ACCENT else Color3.new(1, 1, 1)
		d.ZIndex = if car.Me then 6 else 5
		d.Position = self:_map(car.Position)
		d.Visible = true
	end
	for index = #cars + 1, #self.Dots do
		self.Dots[index].Visible = false
	end
end

function Minimap:Destroy()
	self.Frame:Destroy()
end

return Minimap
