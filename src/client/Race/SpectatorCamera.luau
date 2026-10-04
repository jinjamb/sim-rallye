--!strict
--[[
	SpectatorCamera.luau
	Caméra de poursuite sur la voiture d'un autre pilote, une fois sa propre
	course finie. Plus simple que ChaseCamera : la voiture suivie n'est connue
	que par sa position répliquée (pas de suspension ni de pédales), on se
	contente de la suivre de derrière, dans le sens de son déplacement, avec un
	lissage qui gomme les à-coups de réplication.
]]

local SpectatorCamera = {}
SpectatorCamera.__index = SpectatorCamera

export type SpectatorCamera = typeof(setmetatable({}, SpectatorCamera)) & {
	Camera: Camera,
	Target: BasePart?,
	TargetName: string,
	TargetUserId: number?,
	Active: boolean,
	Base: CFrame,
	Direction: Vector3,
}

local DISTANCE = 18
local HEIGHT = 7
local LOOK_HEIGHT = 2.5
local SMOOTHING = 6
local DIRECTION_SMOOTHING = 4
local FOV = 75

function SpectatorCamera.new(camera: Camera): SpectatorCamera
	local self = (setmetatable({}, SpectatorCamera) :: any) :: SpectatorCamera
	self.Camera = camera
	self.Target = nil
	self.TargetName = ""
	self.TargetUserId = nil
	self.Active = false
	self.Base = camera.CFrame
	self.Direction = Vector3.new(0, 0, -1)
	return self
end

function SpectatorCamera:SetTarget(target: BasePart, name: string, userId: number)
	self.Target = target
	self.TargetName = name
	self.TargetUserId = userId
	if not self.Active then
		self.Active = true
		self.Camera.CameraType = Enum.CameraType.Scriptable
		self.Base = self.Camera.CFrame
	end
	local look = target.CFrame.LookVector
	self.Direction = Vector3.new(look.X, 0, look.Z).Unit
end

function SpectatorCamera:Stop()
	self.Active = false
	self.Target = nil
	self.TargetUserId = nil
end

function SpectatorCamera:Update(dt: number)
	local target = self.Target
	if not self.Active or not target or not target:IsDescendantOf(workspace) then
		return
	end
	-- Sens du déplacement à bonne vitesse, sinon l'avant de la voiture.
	local velocity = target.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local wanted = if flatVelocity.Magnitude > 10
		then flatVelocity.Unit
		else Vector3.new(target.CFrame.LookVector.X, 0, target.CFrame.LookVector.Z)
	if wanted.Magnitude > 1e-3 then
		local blended = self.Direction:Lerp(wanted.Unit, 1 - math.exp(-DIRECTION_SMOOTHING * dt))
		if blended.Magnitude > 1e-3 then
			self.Direction = blended.Unit
		end
	end
	local position = target.Position
	local eye = position - self.Direction * DISTANCE + Vector3.yAxis * HEIGHT
	local focus = position + Vector3.yAxis * LOOK_HEIGHT + self.Direction * 6
	self.Base = self.Base:Lerp(CFrame.lookAt(eye, focus), 1 - math.exp(-SMOOTHING * dt))
	self.Camera.CFrame = self.Base
	self.Camera.FieldOfView = FOV
end

return SpectatorCamera
