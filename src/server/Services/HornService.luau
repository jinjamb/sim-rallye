--!strict
--[[
	HornService.luau
	Le klaxon : un pilote au volant klaxonne (Horn), le serveur relaie à
	tous les joueurs (HornPlayed), et chacun joue le son du klaxon porté par
	ce pilote sur sa voiture (Horn.luau, côté client). Un coup au plus toutes
	les HORN_COOLDOWN s : de quoi saluer, pas de quoi assourdir le paddock.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local CarService = require(script.Parent.CarService)

local HornService = {}

local HORN_COOLDOWN = 0.8 -- secondes

function HornService.Start()
	local lastHornAt: { [Player]: number } = {}
	Remotes.Horn.OnServerEvent:Connect(function(player: Player)
		if not CarService.IsDriving(player) then
			return
		end
		local now = os.clock()
		if now - (lastHornAt[player] or 0) < HORN_COOLDOWN then
			return
		end
		lastHornAt[player] = now
		Remotes.HornPlayed:FireAllClients(player.UserId)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastHornAt[player] = nil
	end)
end

return HornService
