--!strict
local UserInputService = game:GetService("UserInputService")
local InputManager = {}

export type CarInputs = {
	throttle: number,
	brake: number,
	steer: number,
	handbrake: boolean
}

function InputManager:GetInputs(): CarInputs
	local throttle = 0
	local brake = 0
	local steer = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then throttle = 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then brake = 1 end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then steer += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then steer -= 1 end

	local handbrake = UserInputService:IsKeyDown(Enum.KeyCode.Space)

	return { throttle = throttle, brake = brake, steer = steer, handbrake = handbrake }
end

return InputManager
