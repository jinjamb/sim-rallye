--!strict
--[[
	RollService.luau
	Les tirages (Rolls.luau) : le joueur en utilise un, le serveur tire
	l'objet (son propre générateur : le client ne choisit rien), le donne --
	ou le convertit en crédits si c'est un doublon -- et répond le résultat,
	que le client met en scène (RollReveal.luau).

	Le tirage consommé, l'objet ou les crédits, et la garantie (compteur
	depuis le dernier Usine+) partent dans la même écriture, aussitôt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)
local Rolls = require(ReplicatedStorage.Shared.Economy.Rolls)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local EconomyService = require(script.Parent.EconomyService)
local AchievementService = require(script.Parent.AchievementService)

local RollService = {}

local ROLL_COOLDOWN = 1 -- seconde entre deux tirages (le temps de l'animation côté client)

local random = Random.new()

local function roll(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	if profile.Rolls <= 0 then
		Remotes.RollResult:FireClient(player, { Error = "Plus de tirage : un nouveau à chaque niveau, et avec les trois défis du jour." })
		return
	end
	local item = Rolls.Draw(random, profile.RollPity)
	if not item then
		Remotes.RollResult:FireClient(player, { Error = "Rien à tirer pour l'instant." })
		return
	end
	local id = item.Id
	ProfileStore.AddCounter(player, "Rolls", -1)
	local duplicate = Catalog.Owns(profile.Owned, id)
	local credits = 0
	if duplicate then
		credits = Rolls.DUPLICATE_CREDITS[item.Rarity] or 0
		ProfileStore.AddCounter(player, "Credits", credits)
	else
		profile.Owned[id] = true
		ProfileStore.Defer(player, "own:" .. id, function(stored)
			stored.Owned[id] = true
		end)
	end
	local pity = Rolls.NextPity(profile.RollPity, item)
	profile.RollPity = pity
	ProfileStore.Defer(player, "RollPity", function(stored)
		stored.RollPity = pity
	end)
	ProfileStore.Flush(player)
	Remotes.RollResult:FireClient(player, { ItemId = id, Duplicate = duplicate, Credits = credits })
	EconomyService.SendWallet(player)
	if item.Rarity == "Legende" then
		-- Après la mise en scène du tirage.
		task.delay(4, AchievementService.Award, player, "legend_roll")
	end
end

function RollService.Start()
	local lastRollAt: { [Player]: number } = {}
	Remotes.RequestRoll.OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastRollAt[player] or 0) < ROLL_COOLDOWN then
			return
		end
		lastRollAt[player] = now
		roll(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRollAt[player] = nil
	end)
end

return RollService
