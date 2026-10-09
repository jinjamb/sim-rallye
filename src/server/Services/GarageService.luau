--!strict
--[[
	GarageService.luau
	Ce que le joueur règle sur sa voiture : réglages (CarSetup.luau) et livrée
	(Livery.luau). Sauvegardés ensemble, par lots (ProfileStore.Defer).

	Une livrée qui utilise un cosmétique verrouillé (pas encore débloqué, ou
	barème retouché depuis) est ramenée à ce qui est débloqué : au chargement
	du profil et à chaque modification.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local CarSetup = require(ReplicatedStorage.Shared.Vehicle.CarSetup)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local ProgressService = require(script.Parent.ProgressService)

local GarageService = {}

local SAVE_COOLDOWN = 0.5 -- seconde entre deux réglages (ou livrées) reçus

-- Appelée quand la livrée d'un joueur change (ou au chargement du profil) :
-- branchée par Main.server.luau sur CarService, qui repeint la voiture.
GarageService.LiveryChanged = function(_player: Player) end

function GarageService.GetLivery(player: Player): Livery.Livery
	local profile = ProfileStore.Get(player)
	return if profile then profile.Livery else Livery.Default(player.UserId)
end

-- Réglages et livrée : écrits ensemble, à la prochaine sauvegarde regroupée.
local function deferSave(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local setup = profile.Setup
	local livery = profile.Livery
	ProfileStore.Defer(player, "Garage", function(stored)
		stored.Setup = setup
		stored.Livery = livery
	end)
end

function GarageService.Start()
	ProfileStore.OnLoaded(function(player, profile)
		-- Livrée sauvegardée avec un cosmétique qui n'est plus débloqué.
		local default = Livery.Default(player.UserId)
		profile.Livery = Progression.Enforce(profile.Livery, default, default, ProgressService.SnapshotOf(profile))
		GarageService.LiveryChanged(player)
	end)

	local lastSetupAt: { [Player]: number } = {}
	Remotes.SaveSetup.OnServerEvent:Connect(function(player: Player, input: any)
		local profile = ProfileStore.Get(player)
		if not profile then
			return
		end
		local now = os.clock()
		if now - (lastSetupAt[player] or 0) < SAVE_COOLDOWN then
			return
		end
		lastSetupAt[player] = now
		profile.Setup = CarSetup.Sanitize(input)
		deferSave(player)
	end)

	local lastLiveryAt: { [Player]: number } = {}
	Remotes.SaveLivery.OnServerEvent:Connect(function(player: Player, input: any)
		local profile = ProfileStore.Get(player)
		if not profile then
			return
		end
		local now = os.clock()
		if now - (lastLiveryAt[player] or 0) < SAVE_COOLDOWN then
			return
		end
		lastLiveryAt[player] = now
		-- Un cosmétique pas encore débloqué est remplacé par ce qui l'est.
		profile.Livery = Progression.Enforce(
			Livery.Sanitize(input, player.UserId),
			profile.Livery,
			Livery.Default(player.UserId),
			ProgressService.Get(player)
		)
		deferSave(player)
		GarageService.LiveryChanged(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSetupAt[player] = nil
		lastLiveryAt[player] = nil
	end)
end

return GarageService
