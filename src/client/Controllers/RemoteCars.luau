--!strict
--[[
	RemoteCars.luau
	Les voitures des AUTRES joueurs, vues de ce client.

	Leur physique tourne chez leur pilote ; Roblox ne nous réplique que la
	position du châssis. Tout le reste est reconstitué ici :
		- ROUES : rayons lancés localement sous chaque roue (la suspension
		  suit le sol), rotation déduite de la vitesse, braquage de la télémétrie ;
		- SON : le même CarAudio que pour sa propre voiture, piloté par la
		  télémétrie que le pilote diffuse (régime, charge, glissements) ;
		- POUSSIÈRE : le même CarEffects, sur les surfaces que touchent nos rayons.
	Télémétrie : attributs posés sur le châssis par CarService (Rpm, Load,
	Steer, Screech, GravelSlide, GravelShare, TarmacShare, Driven).
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Surfaces = require(ReplicatedStorage.Shared.Constants.Surfaces)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local CarEffects = require(script.Parent.CarEffects)

local RemoteCars = {}
RemoteCars.__index = RemoteCars

type RemoteWheel = {
	Attachment: Attachment,
	IsGrounded: boolean,
	Surface: Surfaces.SurfaceProperties,
	ContactPoint: Vector3,
	LongSlipNorm: number,
	LatSlipNorm: number,
	Motor: Motor6D?,
	Radius: number,
	IsFront: boolean,
	Spin: number,
}

type View = {
	Model: Model,
	Chassis: BasePart,
	Wheels: { RemoteWheel },
	Audio: CarAudio.CarAudio,
	Effects: CarEffects.CarEffects,
	RayParams: RaycastParams,
}

export type RemoteCars = typeof(setmetatable({}, RemoteCars)) & {
	LocalUserId: number,
	Views: { [BasePart]: View },
}

local CAR_TAG = "RallyCar"
local CAR_COLLISION_GROUP = "Cars"
local SUSPENSION_LENGTH = 1.6 -- doit correspondre à Wheel.luau
local MAX_STEER = math.rad(35) -- doit correspondre à Car.luau (MaxSteerAngle)
local WHEEL_SUFFIXES = { "FL", "FR", "RL", "RR" }

function RemoteCars.new(localUserId: number): RemoteCars
	local self = (setmetatable({}, RemoteCars) :: any) :: RemoteCars
	self.LocalUserId = localUserId
	self.Views = {}

	for _, chassis in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		task.spawn(function()
			self:_add(chassis)
		end)
	end
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(chassis: Instance)
		self:_add(chassis)
	end)
	CollectionService:GetInstanceRemovedSignal(CAR_TAG):Connect(function(chassis: Instance)
		self:_remove(chassis)
	end)
	return self
end

function RemoteCars:_add(instance: Instance)
	if not instance:IsA("BasePart") or self.Views[instance] then
		return
	end
	local chassis = instance
	local model = chassis.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local owner = model:GetAttribute("OwnerUserId")
	if owner == nil or owner == self.LocalUserId then
		return -- sa propre voiture est simulée pour de vrai (Main.client.luau)
	end

	local wheels: { RemoteWheel } = {}
	local attachments: { Attachment } = {}
	for _, suffix in ipairs(WHEEL_SUFFIXES) do
		local attachment = chassis:WaitForChild("Wheel" .. suffix, 10)
		if not attachment or not attachment:IsA("Attachment") then
			return
		end
		local tire = model:FindFirstChild("Tire" .. suffix)
		local motor = chassis:FindFirstChild("Motor" .. suffix)
		table.insert(attachments, attachment)
		table.insert(wheels, {
			Attachment = attachment,
			IsGrounded = false,
			Surface = Surfaces.Default,
			ContactPoint = attachment.WorldPosition,
			LongSlipNorm = 0,
			LatSlipNorm = 0,
			Motor = if motor and motor:IsA("Motor6D") then motor else nil,
			Radius = if tire and tire:IsA("BasePart") then tire.Size.Y / 2 else 1,
			IsFront = string.sub(suffix, 1, 1) == "F",
			Spin = 0,
		})
	end
	if self.Views[chassis] or not chassis:IsDescendantOf(workspace) then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	if PhysicsService:IsCollisionGroupRegistered(CAR_COLLISION_GROUP) then
		params.CollisionGroup = CAR_COLLISION_GROUP
	end

	self.Views[chassis] = {
		Model = model,
		Chassis = chassis,
		Wheels = wheels,
		Audio = CarAudio.new(chassis, attachments, false),
		Effects = CarEffects.new(chassis, wheels :: any),
		RayParams = params,
	}
end

function RemoteCars:_remove(instance: Instance)
	local view = self.Views[instance :: BasePart]
	if not view then
		return
	end
	self.Views[instance :: BasePart] = nil
	view.Audio:Destroy()
	view.Effects:Destroy()
end

local function attributeNumber(part: BasePart, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

function RemoteCars:Update(dt: number)
	for chassis, view in pairs(self.Views) do
		if not chassis:IsDescendantOf(workspace) then
			continue -- hors de portée (streaming) : on attend qu'elle revienne
		end
		local driven = chassis:GetAttribute("Driven") == true
		view.Audio:SetActive(driven)
		view.Effects:SetActive(driven)

		local frame = chassis.CFrame
		local down = -frame.UpVector * SUSPENSION_LENGTH
		local velocity = chassis.AssemblyLinearVelocity
		local forwardSpeed = velocity:Dot(frame.LookVector)
		local steer = attributeNumber(chassis, "Steer", 0) * MAX_STEER
		local slide = attributeNumber(chassis, "GravelSlide", 0)
		-- La poussière (CarEffects) lit un glissement normalisé : on le
		-- reconstitue à partir du niveau de glisse diffusé.
		local slipForDust = if slide > 0 then 0.9 + slide * 1.5 else 0

		for _, wheel in ipairs(view.Wheels) do
			local result = workspace:Raycast(wheel.Attachment.WorldPosition, down, view.RayParams)
			local distance = if result then result.Distance else SUSPENSION_LENGTH
			wheel.IsGrounded = result ~= nil
			if result then
				wheel.ContactPoint = result.Position
				wheel.Surface = Surfaces.Get(result.Material)
			end
			wheel.LongSlipNorm = slipForDust
			wheel.Spin = (wheel.Spin - forwardSpeed / wheel.Radius * dt) % (math.pi * 2)

			local motor = wheel.Motor
			if motor then
				-- Même convention que Wheel:UpdateVisual : la roue pose sur le sol
				-- touché par le rayon ; en l'air, suspension complètement détendue.
				motor.C0 = CFrame.new(wheel.Attachment.Position + Vector3.new(0, wheel.Radius - distance, 0))
					* CFrame.Angles(0, if wheel.IsFront then steer else 0, 0)
					* CFrame.Angles(wheel.Spin, 0, 0)
			end
		end

		if driven then
			local screech = attributeNumber(chassis, "Screech", 0)
			view.Audio:Update(dt, {
				Rpm = attributeNumber(chassis, "Rpm", 1000),
				Load = attributeNumber(chassis, "Load", 0),
				Speed = velocity.Magnitude,
				-- Un seul niveau diffusé : réparti sur les quatre roues.
				Screech = { screech, screech, screech, screech },
				GravelShare = attributeNumber(chassis, "GravelShare", 0),
				GravelSlide = slide,
				TarmacShare = attributeNumber(chassis, "TarmacShare", 0),
			})
			view.Effects:Update(dt)
		end
	end
end

return RemoteCars
