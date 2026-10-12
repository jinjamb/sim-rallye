--!strict
--[[
	EventNotice.luau
	Suit, sur l'heure du serveur, les deux calendriers d'événements :
		- DOUBLE XP (XpEvents.luau : week-ends, dates précises) ;
		- ÉVÉNEMENTS ÉCLAIR (FlashEvents.luau : un par quart d'heure).
	L'événement en cours reste affiché dans le bandeau du serveur
	(Announcer ; l'éclair passe devant le double XP tant qu'il dure), et son
	début s'annonce en grand (Banner). Un événement éclair est annoncé une
	minute avant (Toast).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local XpEvents = require(ReplicatedStorage.Shared.Progression.XpEvents)
local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Announcer = require(script.Parent.Announcer)
local Banner = require(script.Parent.Banner)
local Toast = require(script.Parent.Toast)
local Theme = require(script.Parent.Theme)

local EventNotice = {}

local CHECK_INTERVAL = 1 -- seconde : le compte à rebours de l'éclair

-- Nom d'un événement éclair, avec sa voiture rare.
function EventNotice.FlashName(event: FlashEvents.Event): string
	if event.CarClass then
		return event.Kind.Name .. " : " .. CarClasses.Get(event.CarClass).Name
	end
	return event.Kind.Name
end

function EventNotice.Start()
	task.spawn(function()
		local shownXp: string? = nil -- double XP annoncé (nom et début)
		local shownFlash: number? = nil -- événement éclair annoncé (Slot)
		local warnedFlash: number? = nil -- événement éclair prévenu
		local banner = "" -- texte du bandeau du serveur, changé seulement s'il change
		local function setEvent(message: any)
			local key = if message then message.Tag .. "|" .. message.Text else ""
			if key ~= banner then
				banner = key
				Announcer.SetEvent(message)
			end
		end
		while true do
			local now = workspace:GetServerTimeNow()
			local flash = FlashEvents.Active(now)
			local nextFlash = FlashEvents.Next(now)
			local xp = XpEvents.Active(now)

			-- Une minute avant : on prévient.
			local untilNext = nextFlash.StartsAt - now
			if untilNext <= FlashEvents.WARNING and warnedFlash ~= nextFlash.Slot then
				warnedFlash = nextFlash.Slot
				Toast.Show(string.format("<b>Dans 1 min</b> · %s %s", nextFlash.Kind.Icon, EventNotice.FlashName(nextFlash)), Theme.CYAN)
			end

			if flash then
				local text = string.format("%s · %s · encore %s", EventNotice.FlashName(flash), flash.Kind.Description, Format.Remaining(flash.EndsAt - now))
				setEvent({ Tag = flash.Kind.Icon .. " ÉCLAIR", Text = text, Color = Theme.CYAN })
				if shownFlash ~= flash.Slot then
					shownFlash = flash.Slot
					Banner.Show("Événement éclair · " .. EventNotice.FlashName(flash), flash.Kind.Description .. " Pendant 5 minutes !", Theme.CYAN, 5, true)
				end
			elseif xp then
				setEvent({ Tag = "XP ×" .. xp.Multiplier, Text = xp.Name .. " · encore " .. Format.Remaining(xp.EndsAt - now), Color = Theme.YELLOW })
			else
				setEvent(nil)
			end

			local xpId = if xp then xp.Name .. "@" .. xp.StartsAt else nil
			if xp and xpId ~= shownXp then
				Banner.Show("XP ×" .. xp.Multiplier, xp.Name .. " · encore " .. Format.Remaining(xp.EndsAt - now) .. " · Rallye Pass et écurie compris", Theme.YELLOW, 5, true)
			end
			shownXp = xpId
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return EventNotice
