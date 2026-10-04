--!strict
--[[
	ChaseCamera.luau
	Caméra de poursuite, réglée pour donner la sensation de vitesse.

	La vitesse se lit surtout en vision périphérique et dans les réactions de la
	caméra ; une caméra figée à hauteur constante l'écrase complètement. Ici :

		- PLUS BASSE et plus proche : le sol défile plus près de l'œil.
		- CHAMP DE VISION qui s'élargit avec la vitesse (70° -> 90°) : les bords
		  de l'image défilent plus vite, comme en vision périphérique.
		- RETARD À L'ACCÉLÉRATION : la caméra se laisse distancer quand la voiture
		  accélère et se rapproche au freinage -- on sent les g.
		- REGARD PLUS LOIN avec la vitesse : on voit venir le virage.
		- SECOUSSES : un léger frémissement qui croît avec la vitesse, et des
		  à-coups tirés de la suspension elle-même (bosses, réceptions de saut).
		  Les secousses s'ajoutent APRÈS le lissage, sinon il les effacerait.
		- En glisse, la caméra suit la trajectoire réelle plutôt que le nez de la
		  voiture : la trajectoire reste dans le champ, sans fouetté.
]]

local CarClass = require(script.Parent.Parent.Physics.Car)

local ChaseCamera = {}
ChaseCamera.__index = ChaseCamera

export type ChaseCamera = typeof(setmetatable({}, ChaseCamera)) & {
	Car: CarClass.Car,
	Camera: Camera,
	Base: CFrame, -- position lissée, sans secousses
	Fov: number,
	DistanceOffset: number,
	PreviousForwardSpeed: number,
	PreviousCompression: { number },
	BumpEnergy: number,
	Time: number,
	Active: boolean,
}

local BASE_DISTANCE = 15
local SPEED_DISTANCE = 2 -- recul supplémentaire à pleine vitesse
-- Juste au-dessus de l'aileron (toit à ~3.5, aileron à ~4 au-dessus du centre
-- du châssis, voir tools/build-rig.luau) : plus bas, la carrosserie masque la route.
local HEIGHT = 6.2
local LOOK_HEIGHT = 3.0
local LOOK_AHEAD_BASE = 4
local LOOK_AHEAD_PER_SPEED = 0.06 -- studs de regard en avant par stud/s
local SMOOTHING = 9 -- plus haut = caméra plus rigide
local TELEPORT_DISTANCE = 200 -- au-delà, la caméra rejoint la voiture sans glisser
local DRIFT_BLEND_SPEED = 15 -- studs/s à partir desquels la caméra suit la trajectoire

local BASE_FOV = 70
local FOV_BOOST = 20
local FULL_EFFECT_SPEED = 160 -- studs/s (~km/h) : effets de vitesse au maximum
local FOV_SMOOTH_TIME = 0.4

-- Retard à l'accélération : recul proportionnel à l'accélération longitudinale.
local LAG_PER_ACCELERATION = 0.04 -- studs de recul par stud/s²
local LAG_MIN, LAG_MAX = -1.5, 2.5 -- au freinage on se rapproche, à l'accélération on recule
local LAG_SMOOTH_TIME = 0.3

-- Frémissement de vitesse (route, vent).
local SPEED_SHAKE_POSITION = 0.05 -- studs à pleine vitesse
local SPEED_SHAKE_ANGLE = math.rad(0.25)
local SPEED_SHAKE_FREQUENCY = 9 -- Hz
-- À-coups de suspension : énergie alimentée par la vitesse de compression des
-- ressorts, qui retombe en quelques dixièmes de seconde.
local BUMP_GAIN = 0.012 -- par stud/s de vitesse de compression cumulée
local BUMP_MAX = 0.8
local BUMP_DECAY_TIME = 0.25
local BUMP_SHAKE_POSITION = 0.6 -- studs à énergie maximale
local BUMP_SHAKE_ANGLE = math.rad(1.6)
local BUMP_SHAKE_FREQUENCY = 14

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function approach(current: number, target: number, dt: number, time: number): number
	return current + (target - current) * (1 - math.exp(-dt / time))
end

function ChaseCamera.new(car: CarClass.Car, camera: Camera): ChaseCamera
	local self = (setmetatable({}, ChaseCamera) :: any) :: ChaseCamera
	self.Car = car
	self.Camera = camera
	self.Base = camera.CFrame
	self.Fov = BASE_FOV
	self.DistanceOffset = 0
	self.PreviousForwardSpeed = 0
	self.PreviousCompression = {}
	self.BumpEnergy = 0
	self.Time = 0
	self.Active = false
	return self
end

-- La caméra part de sa position actuelle et glisse vers la voiture.
function ChaseCamera:Enter()
	self.Active = true
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Base = self.Camera.CFrame
	-- Voiture loin de la caméra (apparition sur un circuit, retour au paddock) :
	-- on se place directement derrière elle au lieu de traverser la carte.
	local carFrame = self.Car.Chassis.CFrame
	if (self.Base.Position - carFrame.Position).Magnitude > TELEPORT_DISTANCE then
		local eye = carFrame.Position - carFrame.LookVector * BASE_DISTANCE + Vector3.yAxis * HEIGHT
		self.Base = CFrame.lookAt(eye, carFrame.Position + Vector3.yAxis * LOOK_HEIGHT)
	end
	self.Fov = self.Camera.FieldOfView
	self.DistanceOffset = 0
	self.PreviousForwardSpeed = self.Car:GetForwardSpeed()
	self.BumpEnergy = 0
	for i, wheel in ipairs(self.Car.Wheels) do
		self.PreviousCompression[i] = wheel.Compression
	end
end

function ChaseCamera:Exit()
	self.Active = false
	self.Camera.FieldOfView = BASE_FOV
end

function ChaseCamera:Update(dt: number)
	if not self.Active or dt <= 0 then
		return
	end
	local car = self.Car
	local chassisCFrame = car.Chassis.CFrame
	local velocity = car.Chassis.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local speedFactor = smoothstep(speed / FULL_EFFECT_SPEED)
	self.Time += dt

	-- Direction suivie : le nez à basse vitesse, la trajectoire en glisse.
	local lookDirection = chassisCFrame.LookVector
	if speed > DRIFT_BLEND_SPEED then
		local blended = lookDirection:Lerp(velocity.Unit, 0.5)
		if blended.Magnitude > 0.01 then
			lookDirection = blended.Unit
		end
	end

	-- Retard à l'accélération, mesuré sur la vitesse vers l'avant.
	local forwardSpeed = car:GetForwardSpeed()
	local acceleration = (forwardSpeed - self.PreviousForwardSpeed) / dt
	self.PreviousForwardSpeed = forwardSpeed
	local lagTarget = math.clamp(acceleration * LAG_PER_ACCELERATION, LAG_MIN, LAG_MAX)
	self.DistanceOffset = approach(self.DistanceOffset, lagTarget, dt, LAG_SMOOTH_TIME)

	local distance = BASE_DISTANCE + SPEED_DISTANCE * speedFactor + self.DistanceOffset
	local carPosition = chassisCFrame.Position
	local eye = carPosition - lookDirection * distance + Vector3.yAxis * HEIGHT
	local focus = carPosition + Vector3.yAxis * LOOK_HEIGHT + lookDirection * (LOOK_AHEAD_BASE + LOOK_AHEAD_PER_SPEED * speed)
	local target = CFrame.lookAt(eye, focus)

	-- Lissage indépendant du framerate.
	local alpha = 1 - math.exp(-SMOOTHING * dt)
	self.Base = self.Base:Lerp(target, alpha)

	self.Fov = approach(self.Fov, BASE_FOV + FOV_BOOST * speedFactor, dt, FOV_SMOOTH_TIME)
	self.Camera.FieldOfView = self.Fov

	-- À-coups de suspension : vitesse de compression cumulée des quatre ressorts.
	local compressionRate = 0
	for i, wheel in ipairs(car.Wheels) do
		local previous = self.PreviousCompression[i] or wheel.Compression
		compressionRate += math.abs(wheel.Compression - previous) / dt
		self.PreviousCompression[i] = wheel.Compression
	end
	self.BumpEnergy = math.max(
		self.BumpEnergy * math.exp(-dt / BUMP_DECAY_TIME),
		math.min(BUMP_MAX, compressionRate * BUMP_GAIN)
	)

	-- Secousses : bruit de Perlin (fluide, sans saccade). Deux couches
	-- indépendantes : frémissement de vitesse et à-coups de suspension.
	local t = self.Time
	local bump = self.BumpEnergy / BUMP_MAX
	local function shake(seed: number, speedAmplitude: number, bumpAmplitude: number): number
		return math.noise(t * SPEED_SHAKE_FREQUENCY, seed) * speedFactor * speedAmplitude
			+ math.noise(t * BUMP_SHAKE_FREQUENCY, seed + 50) * bump * bumpAmplitude
	end
	local offset = Vector3.new(
		shake(1, SPEED_SHAKE_POSITION * 0.5, BUMP_SHAKE_POSITION * 0.5),
		shake(2, SPEED_SHAKE_POSITION, BUMP_SHAKE_POSITION),
		0
	)
	local pitch = shake(3, SPEED_SHAKE_ANGLE, BUMP_SHAKE_ANGLE)
	local roll = shake(4, SPEED_SHAKE_ANGLE, BUMP_SHAKE_ANGLE)

	self.Camera.CFrame = self.Base * CFrame.new(offset) * CFrame.Angles(pitch, 0, roll)
end

return ChaseCamera
