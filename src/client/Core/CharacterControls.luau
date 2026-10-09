--!strict
--[[
	CharacterControls.luau
	L'avatar à pied : ses commandes et sa caméra.

	PlayerModule est le contrôleur par défaut de Roblox (clavier, mobile,
	manette). On le coupe entièrement pendant la conduite, sinon ZQSD pilote
	aussi l'avatar. Il se charge un peu après le jeu : l'état demandé entre-
	temps lui est appliqué dès qu'il est là.
]]

local Players = game:GetService("Players")

local CharacterControls = {}

local player = Players.LocalPlayer
local controls: any = nil
local enabled = true

local function apply()
	if not controls then
		return
	end
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

task.spawn(function()
	local ok, result = pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule")) :: any
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
		if not enabled then
			apply()
		end
	else
		warn("[Car] PlayerModule introuvable, les contrôles de l'avatar restent actifs")
	end
end)

function CharacterControls.SetEnabled(on: boolean)
	enabled = on
	apply()
end

-- Caméra de l'avatar à pied (en sortant de la voiture, d'un ralenti...).
function CharacterControls.ResetCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

return CharacterControls
