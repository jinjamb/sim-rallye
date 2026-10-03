--!strict
--[[
	InputManager.luau
	Clavier + manette, fusionnés en une seule commande de conduite.

	MANETTE (analogique) :
		Gâchette droite = accélérateur, gâchette gauche = frein,
		stick gauche = direction, A = frein à main.
		(Les palettes et le mode de boîte sont des événements : Main.client.luau.)

	CLAVIER (tout ou rien, donc lissé) :
		W accélérateur, S frein, A/D direction, Espace frein à main.
		Un clavier ne sait pas doser : on fait monter les commandes en rampe pour
		imiter un pied et un volant, et on réduit le braquage maximal avec la
		vitesse -- sans ça, A à 100 km/h donne 35° de braquage en une frame,
		ce qu'aucun pilote ne fait, et la voiture part en toupie.
		La manette, elle, n'est NI lissée NI limitée : le joueur dose lui-même.

	FUSION : pédales = max des deux sources ; direction = manette dès que le
	stick sort de sa zone morte, clavier sinon. On peut changer de source à
	tout moment sans rien configurer.

	Update(dt, vitesse) avance les rampes une fois par pas physique ;
	GetInputs() relit le dernier résultat sans rien faire avancer (pour le
	tableau de bord et le journal console).
]]

local UserInputService = game:GetService("UserInputService")

local InputManager = {}

export type CarInputs = {
	throttle: number, -- 0..1
	brake: number, -- 0..1
	steer: number, -- -1..1, positif = à gauche
	handbrake: boolean,
}

local GAMEPAD = Enum.UserInputType.Gamepad1

-- Zones mortes : un stick au repos ne revient jamais exactement à 0, une
-- gâchette usée non plus.
local STICK_DEADZONE = 0.12
local TRIGGER_DEADZONE = 0.05
-- Courbe du stick : > 1 = plus de précision autour du centre, où se joue la
-- conduite en ligne, sans perdre la butée.
local STEER_EXPONENT = 1.4
--[[
	Courbes des gâchettes ("linéarité" des jeux de simulation). Le moteur pousse
	jusqu'à 1.46 g en 1re pour ~0.7 g d'adhérence sur terre : toute la plage
	utile de l'accélérateur tient dans le premier tiers de la course. Avec
	l'exposant, mi-gâchette ne donne plus que ~30 % : le dosage se fait sur la
	moitié de la course au lieu d'un tiers. Le frein, moins brutal, a une
	courbe plus douce, pour trouver le point de blocage sans le dépasser.
]]
local THROTTLE_EXPONENT = 1.7
local BRAKE_EXPONENT = 1.3

-- Rampes clavier, en secondes de 0 à 1.
local KEYBOARD_STEER_TIME = 0.22 -- vers la butée
local KEYBOARD_CENTER_TIME = 0.12 -- retour au centre, plus rapide (le volant revient seul)
local KEYBOARD_THROTTLE_TIME = 0.15
local KEYBOARD_THROTTLE_RELEASE_TIME = 0.08

-- Braquage clavier selon la vitesse (studs/s ~ km/h) : complet jusqu'à
-- FULL, réduit linéairement jusqu'à MIN atteint à FADE. Le plancher reste
-- assez haut pour contre-braquer une glissade.
local KEYBOARD_STEER_FULL_SPEED = 20
local KEYBOARD_STEER_FADE_SPEED = 120
local KEYBOARD_STEER_MIN = 0.35

--------------------------------------------------------------------------------
-- État de la manette, tenu à jour par événements (évite de relire tout
-- GetGamepadState à chaque frame).
--------------------------------------------------------------------------------

local padStickX = 0
local padThrottle = 0
local padBrake = 0

local function onGamepadInput(input: InputObject)
	if input.UserInputType ~= GAMEPAD then
		return
	end
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		padStickX = input.Position.X
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		padThrottle = input.Position.Z
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		padBrake = input.Position.Z
	end
end

UserInputService.InputBegan:Connect(onGamepadInput)
UserInputService.InputChanged:Connect(onGamepadInput)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType ~= GAMEPAD then
		return
	end
	-- La dernière valeur reçue n'est pas toujours exactement 0 au relâchement.
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		padStickX = 0
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		padThrottle = 0
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		padBrake = 0
	end
end)
UserInputService.GamepadDisconnected:Connect(function(gamepad: Enum.UserInputType)
	if gamepad == GAMEPAD then
		padStickX, padThrottle, padBrake = 0, 0, 0
	end
end)

--------------------------------------------------------------------------------
-- Mise en forme
--------------------------------------------------------------------------------

-- Zone morte AXIALE, remise à l'échelle : la sortie repart de 0 au bord de la
-- zone morte au lieu de sauter directement à 0.12.
local function applyDeadzone(value: number, deadzone: number): number
	local magnitude = math.abs(value)
	if magnitude <= deadzone then
		return 0
	end
	return math.sign(value) * math.min(1, (magnitude - deadzone) / (1 - deadzone))
end

local function approach(current: number, target: number, dt: number, riseTime: number, fallTime: number): number
	if target > current then
		return math.min(target, current + dt / riseTime)
	end
	return math.max(target, current - dt / fallTime)
end

-- Rampe de volant : lente en s'éloignant du centre, rapide en y revenant
-- (y compris quand on passe directement d'une butée à l'autre).
local function approachSteer(current: number, target: number, dt: number): number
	local movingOutward = math.abs(target) > math.abs(current) and (current == 0 or math.sign(target) == math.sign(current))
	local time = if movingOutward then KEYBOARD_STEER_TIME else KEYBOARD_CENTER_TIME
	local step = dt / time
	return current + math.clamp(target - current, -step, step)
end

--------------------------------------------------------------------------------
-- État lissé du clavier + dernier résultat
--------------------------------------------------------------------------------

local keyboardThrottle = 0
local keyboardBrake = 0
local keyboardSteer = 0

--[[
	Commandes tactiles (TouchControls.luau) : pédales et volant à l'écran, déjà
	analogiques -- le doigt se pose plus ou moins haut sur la pédale, glisse
	plus ou moins loin sur le volant. Le volant tactile reçoit la même
	réduction de braquage avec la vitesse que le clavier : un doigt sur une
	vitre est bien moins précis qu'un stick.
]]
local touchThrottle = 0
local touchBrake = 0
local touchSteer = 0
local touchHandbrake = false

function InputManager:SetTouch(throttle: number, brake: number, steer: number, handbrake: boolean)
	touchThrottle = math.clamp(throttle, 0, 1)
	touchBrake = math.clamp(brake, 0, 1)
	touchSteer = math.clamp(steer, -1, 1)
	touchHandbrake = handbrake
end

local last: CarInputs = { throttle = 0, brake = 0, steer = 0, handbrake = false }
local lastSource = "clavier"

function InputManager:Update(dt: number, forwardSpeed: number): CarInputs
	-- Clavier
	local wantThrottle = if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0
	local wantBrake = if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0
	local wantSteer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		wantSteer += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		wantSteer -= 1
	end

	local speedFactor = math.clamp(
		(math.abs(forwardSpeed) - KEYBOARD_STEER_FULL_SPEED) / (KEYBOARD_STEER_FADE_SPEED - KEYBOARD_STEER_FULL_SPEED),
		0,
		1
	)
	local steerLimit = 1 - (1 - KEYBOARD_STEER_MIN) * speedFactor

	keyboardThrottle = approach(keyboardThrottle, wantThrottle, dt, KEYBOARD_THROTTLE_TIME, KEYBOARD_THROTTLE_RELEASE_TIME)
	-- Le frein garde son entrée franche : Car.luau lui applique déjà la montée
	-- en pression hydraulique, commune aux deux sources.
	keyboardBrake = wantBrake
	keyboardSteer = approachSteer(keyboardSteer, wantSteer * steerLimit, dt)

	-- Manette
	local stick = applyDeadzone(padStickX, STICK_DEADZONE)
	-- Stick à droite = X positif, mais steer positif = à gauche.
	local padSteer = -math.sign(stick) * math.abs(stick) ^ STEER_EXPONENT
	local padThrottleValue = applyDeadzone(padThrottle, TRIGGER_DEADZONE) ^ THROTTLE_EXPONENT
	local padBrakeValue = applyDeadzone(padBrake, TRIGGER_DEADZONE) ^ BRAKE_EXPONENT

	-- Tactile : même courbe que le stick, même limite à haute vitesse que le clavier.
	local touchSteerValue = math.sign(touchSteer) * math.abs(touchSteer) ^ STEER_EXPONENT * steerLimit

	-- Fusion
	local padActive = padSteer ~= 0 or padThrottleValue > 0 or padBrakeValue > 0
	local keyboardActive = wantThrottle > 0 or wantBrake > 0 or wantSteer ~= 0
	local touchActive = touchSteer ~= 0 or touchThrottle > 0 or touchBrake > 0 or touchHandbrake
	if padActive then
		lastSource = "manette"
	elseif touchActive then
		lastSource = "tactile"
	elseif keyboardActive then
		lastSource = "clavier"
	end

	local steer = keyboardSteer
	if padSteer ~= 0 then
		steer = padSteer
	elseif touchSteerValue ~= 0 then
		steer = touchSteerValue
	end

	last = {
		throttle = math.max(keyboardThrottle, padThrottleValue, touchThrottle),
		brake = math.max(keyboardBrake, padBrakeValue, touchBrake),
		steer = steer,
		handbrake = UserInputService:IsKeyDown(Enum.KeyCode.Space)
			or UserInputService:IsGamepadButtonDown(GAMEPAD, Enum.KeyCode.ButtonA)
			or touchHandbrake,
	}
	return last
end

-- Dernier résultat calculé par Update, sans rien faire avancer.
function InputManager:GetInputs(): CarInputs
	return last
end

-- "clavier", "manette" ou "tactile" : la dernière source réellement utilisée.
function InputManager:GetActiveSource(): string
	return lastSource
end

return InputManager
