--!strict
--[[
	XpEventNotice.luau
	Suit le calendrier des événements double XP (XpEvents.luau), sur l'heure
	du serveur : l'événement en cours reste affiché dans le bandeau du
	serveur (Announcer), et son début s'annonce en grand (Banner), à
	l'arrivée dans le jeu comme pendant la partie.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local XpEvents = require(ReplicatedStorage.Shared.Progression.XpEvents)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Announcer = require(script.Parent.Announcer)
local Banner = require(script.Parent.Banner)
local Theme = require(script.Parent.Theme)

local XpEventNotice = {}

local CHECK_INTERVAL = 20 -- secondes

function XpEventNotice.Start()
	task.spawn(function()
		local shown: string? = nil -- l'événement affiché (nom et début)
		while true do
			local now = workspace:GetServerTimeNow()
			local event = XpEvents.Active(now)
			local id = if event then event.Name .. "@" .. event.StartsAt else nil
			if event then
				local tag = "XP ×" .. event.Multiplier
				local text = event.Name .. " · encore " .. Format.Remaining(event.EndsAt - now)
				Announcer.SetEvent({ Tag = tag, Text = text, Color = Theme.ACCENT })
				if id ~= shown then
					Banner.Show(tag, text .. " · Rallye Pass et écurie compris", Theme.ACCENT, 5, true)
				end
			elseif shown then
				Announcer.SetEvent(nil)
			end
			shown = id
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return XpEventNotice
