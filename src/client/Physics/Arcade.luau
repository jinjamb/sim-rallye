--!strict
--[[
	Arcade.luau
	Une couche « arcade » posée SUR la simulation (Car.luau) : les pneus,
	la suspension, la transmission et les transferts de charge restent ceux
	de la simulation ; ces aides rendent seulement la voiture plus facile et
	plus amusante à tenir. Elles s'appliquent pareil à tout le monde
	(chronos et classements restent comparables).

		GLISSE QUI GARDE LA VITESSE : accélérateur enfoncé en glisse, la
		  vitesse est ramenée peu à peu dans l'axe de la voiture sans perdre
		  sa valeur. On peut tenir une dérive longue et en sortir vite, au
		  lieu de « frotter » et de mourir en sortie de virage.
		GARDE-FOU DE TÊTE-À-QUEUE : au-delà de DRIFT_MAX_ANGLE de dérive, la
		  rotation est retenue (sauf frein à main tiré : l'épingle au frein à
		  main reste entière). Contre-braquer aide encore à rattraper.
		CONTRÔLE EN L'AIR : en saut, la direction fait pivoter la voiture,
		  frein et accélérateur lèvent ou baissent le nez, et la voiture se
		  remet d'aplomb toute seule pour retomber sur ses roues.
		ANTI-TONNEAU : au sol, un roulis trop fort est freiné ; une voiture
		  sur le toit, presque arrêtée, se remet sur ses roues.
		ABS À L'AVANT : une roue avant qui bloque au freinage est relâchée,
		  on garde la direction ; l'arrière peut toujours bloquer (glisse au
		  frein, frein à main).

	STRENGTH règle tout d'un coup : 0 = simulation pure, 1 = réglage prévu.
	Les constantes ci-dessous se règlent à l'essai dans Studio.
]]

local Arcade = {}

Arcade.STRENGTH = 1

-- Glisse
local DRIFT_MIN_SPEED = 18 -- studs/s (~18 km/h) : en dessous, rien
local DRIFT_MIN_ANGLE = math.rad(4) -- dérive en dessous de laquelle on ne touche à rien
local REDIRECT_RATE = 0.55 -- rad/s : vitesse ramenée dans l'axe, accélérateur à fond
local DRIFT_MAX_ANGLE = math.rad(55) -- dérive au-delà de laquelle la rotation est retenue
local SPIN_GUARD_RATE = 5 -- 1/s : force du garde-fou au-delà de DRIFT_MAX_ANGLE
local COUNTERSTEER_DAMPING = 2.2 -- 1/s : lacet amorti quand on contre-braque en glisse

-- En l'air
local AIR_YAW_RATE = 1.6 -- rad/s visés, direction à fond
local AIR_PITCH_RATE = 1.2 -- rad/s visés, frein ou accélérateur à fond
local AIR_RESPONSE = 3 -- 1/s : vitesse à laquelle la rotation suit la commande
local AIR_LEVEL_RATE = 2.2 -- 1/s : remise d'aplomb automatique (roulis surtout)
local AIR_DELAY = 0.15 -- secondes en l'air avant le contrôle (pas sur une simple bosse)

-- Au sol
local ROLL_LIMIT = math.rad(30) -- roulis au-delà duquel on retient
local ROLL_DAMPING = 4 -- 1/s
local FLIP_SPEED = 10 -- studs/s : en dessous, une voiture sur le toit se remet d'aplomb
local FLIP_RATE = 3 -- rad/s visés pour se retourner

-- ABS
local ABS_SLIP = -1.05 -- glissement longitudinal normalisé : au-delà, la roue bloque
local ABS_RELEASE = 0.55 -- part du freinage gardée sur une roue avant qui bloque

local WORLD_UP = Vector3.new(0, 1, 0)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Fait tourner un vecteur horizontal autour de la verticale (angle positif : vers la gauche).
local function rotateFlat(v: Vector3, angle: number): Vector3
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end

--[[
	Freinage d'une roue avant : relâché si elle bloque (glissement mesuré à
	l'image précédente). Appelé par Car.luau avant d'appliquer les forces.
]]
function Arcade.BrakeForce(isFront: boolean, longSlipNorm: number, force: number, handbrake: boolean): number
	if Arcade.STRENGTH <= 0 or not isFront or handbrake or force <= 0 then
		return force
	end
	if longSlipNorm < ABS_SLIP then
		return force * (1 - (1 - ABS_RELEASE) * math.min(1, Arcade.STRENGTH))
	end
	return force
end

export type Inputs = { throttle: number, brake: number, steer: number, handbrake: boolean }

--[[
	Après les forces de la simulation : corrige vitesses et rotation du châssis.
	`grounded` : nombre de roues au sol ; `airTime` : secondes passées en l'air.
]]
function Arcade.Apply(chassis: BasePart, dt: number, inputs: Inputs, grounded: number, airTime: number)
	local strength = Arcade.STRENGTH
	if strength <= 0 then
		return
	end
	local cframe = chassis.CFrame
	local look, right, up = cframe.LookVector, cframe.RightVector, cframe.UpVector
	local velocity = chassis.AssemblyLinearVelocity
	local spin = chassis.AssemblyAngularVelocity

	if grounded == 0 then
		if airTime < AIR_DELAY then
			return
		end
		-- EN L'AIR : chaque rotation (autour des axes de la voiture) suit une
		-- vitesse visée. Lacet et tangage : la commande ; roulis : la remise
		-- d'aplomb ; tangage sans commande : le nez revient à l'horizontale.
		local tilt = up:Cross(WORLD_UP) -- axe qui ramène la voiture d'aplomb
		local pitchInput = inputs.brake - inputs.throttle
		local yawTarget = inputs.steer * AIR_YAW_RATE
		local pitchTarget = if math.abs(pitchInput) > 0.1
			then pitchInput * AIR_PITCH_RATE
			else tilt:Dot(right) * AIR_LEVEL_RATE * 0.6
		local rollTarget = tilt:Dot(look) * AIR_LEVEL_RATE
		local blend = math.min(1, AIR_RESPONSE * dt) * strength
		spin += up * ((yawTarget - spin:Dot(up)) * blend)
		spin += right * ((pitchTarget - spin:Dot(right)) * blend)
		spin += look * ((rollTarget - spin:Dot(look)) * blend)
		chassis.AssemblyAngularVelocity = spin
		return
	end

	-- AU SOL : roulis excessif retenu, voiture sur le toit remise sur ses roues.
	local uprightness = up:Dot(WORLD_UP)
	local speed = velocity.Magnitude
	if uprightness < 0.25 and speed < FLIP_SPEED then
		local axis = up:Cross(WORLD_UP)
		if axis.Magnitude < 1e-3 then
			axis = look -- exactement sur le toit : on bascule sur le côté
		end
		spin = spin:Lerp(axis.Unit * FLIP_RATE, math.min(1, 4 * dt) * strength)
		chassis.AssemblyAngularVelocity = spin
		return
	end
	local roll = math.asin(math.clamp(right:Dot(WORLD_UP), -1, 1))
	if math.abs(roll) > ROLL_LIMIT then
		local rollRate = spin:Dot(look)
		-- Ne freine que la rotation qui aggrave le roulis.
		if rollRate * roll < 0 then
			spin -= look * (rollRate * math.min(1, ROLL_DAMPING * dt) * strength)
		end
	end

	-- GLISSE : seulement en marche avant, à vitesse suffisante, assez de roues au sol.
	local horizontal = flat(velocity)
	local forwardFlat = flat(look)
	local speedFlat = horizontal.Magnitude
	if grounded >= 2 and speedFlat > DRIFT_MIN_SPEED and forwardFlat.Magnitude > 0.5 then
		forwardFlat = forwardFlat.Unit
		local forwardSpeed = horizontal:Dot(forwardFlat)
		if forwardSpeed > 0 then
			-- Dérive : angle de la vitesse par rapport à l'axe, positif si la vitesse part à gauche.
			local side = horizontal:Dot(flat(right).Unit)
			local slip = math.atan2(-side, forwardSpeed)
			local magnitude = math.abs(slip)
			local yawRate = spin:Dot(WORLD_UP)

			-- Garde-fou : au-delà de l'angle limite, le lacet qui creuse la dérive est retenu.
			if magnitude > DRIFT_MAX_ANGLE and not inputs.handbrake then
				local excess = magnitude - DRIFT_MAX_ANGLE
				-- La dérive augmente quand le nez tourne à l'opposé de la vitesse.
				local growing = -yawRate * slip
				if growing > 0 then
					local correction = -yawRate * math.min(1, SPIN_GUARD_RATE * excess * dt * 10) * strength
					spin += WORLD_UP * correction
				end
			end

			-- Contre-braquage en glisse : on amortit le lacet pour rattraper plus facilement.
			if magnitude > math.rad(10) and inputs.steer * slip > 0.05 then
				spin -= WORLD_UP * (yawRate * math.min(1, COUNTERSTEER_DAMPING * dt) * strength * math.abs(inputs.steer))
			end

			-- Glisse qui garde la vitesse : la vitesse revient vers l'axe, sans rien perdre.
			if magnitude > DRIFT_MIN_ANGLE and inputs.throttle > 0.2 and magnitude < math.rad(80) then
				local turn = math.min(magnitude, REDIRECT_RATE * inputs.throttle * dt * strength)
				-- La vitesse est tournée vers l'axe de la voiture (sens opposé à la dérive).
				local redirected = rotateFlat(horizontal, -turn * math.sign(slip))
				chassis.AssemblyLinearVelocity = Vector3.new(redirected.X, velocity.Y, redirected.Z)
			end
		end
	end
	chassis.AssemblyAngularVelocity = spin
end

return Arcade
