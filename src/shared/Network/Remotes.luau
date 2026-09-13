--!strict
--[[
	Remotes.luau
	Crée (serveur) ou attend (client) les RemoteEvents du jeu.
	Le serveur require ce module au démarrage, donc les events existent
	avant même que le premier joueur ne se connecte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Remotes = {
	-- Client -> Serveur : (chassis: BasePart) le joueur demande le contrôle d'une voiture
	RequestCarControl: RemoteEvent,
	-- Client -> Serveur : () le joueur relâche sa voiture
	ReleaseCarControl: RemoteEvent,
	-- Serveur -> Client : (chassis: BasePart, granted: boolean)
	CarControlChanged: RemoteEvent,
}

local REMOTE_NAMES = { "RequestCarControl", "ReleaseCarControl", "CarControlChanged" }

local function buildServer(): Remotes
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end

	local built: { [string]: RemoteEvent } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		local existing = (folder :: Instance):FindFirstChild(name)
		if not existing then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			existing = remote
		end
		built[name] = existing :: RemoteEvent
	end

	return built :: any
end

local function buildClient(): Remotes
	local folder = ReplicatedStorage:WaitForChild("Remotes")

	local built: { [string]: RemoteEvent } = {}
	for _, name in ipairs(REMOTE_NAMES) do
		built[name] = folder:WaitForChild(name) :: RemoteEvent
	end

	return built :: any
end

return (if RunService:IsServer() then buildServer() else buildClient()) :: Remotes
