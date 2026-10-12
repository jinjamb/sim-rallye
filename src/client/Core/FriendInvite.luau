--!strict
--[[
	FriendInvite.luau
	L'invitation de Roblox (SocialService) : le joueur choisit des amis, qui
	reçoivent une notification pour rejoindre le jeu. Depuis une session
	privée, l'invitation porte son code (LaunchData) : à leur arrivée, le
	serveur les y emmène (SessionService).
]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local FriendInvite = {}

-- Ouvre l'invitation (attend la réponse de Roblox : à appeler hors du fil
-- principal). Renvoie un message si c'est impossible.
function FriendInvite.Prompt(sessionCode: string?): string?
	local player = Players.LocalPlayer
	local okCheck, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not okCheck or not canInvite then
		return "Les invitations ne sont pas disponibles ici (appareil, compte ou Studio)."
	end
	local options = Instance.new("ExperienceInviteOptions")
	if sessionCode then
		options.PromptMessage = "Rejoins ma session privée de Sim Rallye !"
		options.LaunchData = sessionCode
	else
		options.PromptMessage = "Viens rouler avec moi sur Sim Rallye !"
	end
	local okPrompt = pcall(function()
		SocialService:PromptGameInvite(player, options)
	end)
	return if okPrompt then nil else "L'invitation n'a pas pu s'ouvrir."
end

return FriendInvite
