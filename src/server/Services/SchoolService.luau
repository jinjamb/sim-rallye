--!strict
--[[
	SchoolService.luau
	École de pilotage (Lessons.luau) : la leçon se déroule chez le pilote,
	qui envoie sa médaille (LessonResult) ; le profil garde la meilleure de
	chaque leçon, et elle rapporte de l'XP (Progression.luau). Ce n'est qu'un
	apprentissage : rien n'entre dans les classements.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Lessons = require(ReplicatedStorage.Shared.School.Lessons)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local ProgressService = require(script.Parent.ProgressService)

local SchoolService = {}

local RESULT_COOLDOWN = 1 -- seconde entre deux résultats

function SchoolService.Start()
	local lastResultAt: { [Player]: number } = {}
	Remotes.LessonResult.OnServerEvent:Connect(function(player: Player, id: any, tier: any)
		local profile = ProfileStore.Get(player)
		if not profile or type(id) ~= "string" or not Lessons.Get(id) or type(tier) ~= "number" or tier ~= tier then
			return
		end
		local now = os.clock()
		if now - (lastResultAt[player] or 0) < RESULT_COOLDOWN then
			return
		end
		lastResultAt[player] = now
		local medal = math.clamp(math.floor(tier), 0, 4)
		if medal <= (profile.Lessons[id] or 0) then
			return
		end
		profile.Lessons[id] = medal
		ProfileStore.Update(player.UserId, "école de pilotage", function(stored)
			if (stored.Lessons[id] or 0) >= medal then
				return false
			end
			stored.Lessons[id] = medal
			return true
		end)
		ProgressService.Push(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastResultAt[player] = nil
	end)
end

return SchoolService
