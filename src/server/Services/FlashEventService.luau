--!strict
--[[
	FlashEventService.luau
	Les événements éclair (FlashEvents.luau) qui demandent au serveur
	d'agir sur le moment :
		- TIRAGE OFFERT : la première spéciale ou course terminée pendant
		  l'événement rapporte un tirage, une fois par événement (retenu dans
		  le profil : FlashRollSlot, même en changeant de serveur).
	Les autres effets sont lus là où ils s'appliquent : tirages
	(RollService), crédits (Perks), XP (ProgressService), prix de la voiture
	rare (EconomyService), voiture prêtée (PaddockService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local EconomyService = require(script.Parent.EconomyService)

local FlashEventService = {}

-- Une spéciale ou une course terminée (StageService, RaceService).
function FlashEventService.Finished(player: Player)
	local event = FlashEvents.Active(os.time())
	if not event or event.Kind.Id ~= "FreeRoll" then
		return
	end
	local profile = ProfileStore.Get(player)
	if not profile or profile.FlashRollSlot == event.Slot then
		return
	end
	local slot = event.Slot
	profile.FlashRollSlot = slot
	ProfileStore.Defer(player, "FlashRollSlot", function(stored)
		stored.FlashRollSlot = slot
	end)
	EconomyService.AddRolls(player, 1, "Événement éclair : tirage offert")
end

return FlashEventService
