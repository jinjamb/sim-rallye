--!strict
--[[
	RacePage.luau
	Le menu pendant une course de rallycross.
		EN SALLE D'ATTENTE : pilotes, compte à rebours ; l'hôte (premier
		  arrivé) règle tours, format, contacts, voiture (parmi les
		  siennes, prêtée aux autres), et peut lancer sans attendre ;
		  QUITTER (ou sortir de la zone).
		PENDANT LA COURSE : ABANDONNER.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local RaceTypes = require(script.Parent.Parent.Parent.Race.RaceTypes)
local CareerPage = require(script.Parent.CareerPage)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local RacePage = {}

local MIN_LAPS, MAX_LAPS = 2, 8

function RacePage.Race(ctx: Context, b: Builder, race: RaceTypes.RaceSnapshot)
	local isHost = race.HostUserId == ctx.LocalUserId
	local inLobby = race.State == "Lobby"
	b:Section(MenuKit.TrackName(race.TrackId))

	if inLobby and isHost then
		b:Text("Tu es l'hôte : tu règles la course et peux la lancer sans attendre.", 13, Widgets.COLOR_DIM)
		MenuKit.Stepper(ctx, b, "Tours", tostring(race.Laps), function(direction)
			ctx.Action("Settings", { Laps = math.clamp(race.Laps + direction, MIN_LAPS, MAX_LAPS) })
		end)
		MenuKit.Stepper(ctx, b, "Format", MenuKit.RaceFormatName(race.Format), function(_direction)
			ctx.Action("Settings", { Format = if race.Format == "Event" then "Sprint" else "Event" })
		end)
		MenuKit.Stepper(ctx, b, "Contacts entre voitures", if race.Contacts then "Oui" else "Non", function(_direction)
			ctx.Action("Settings", { Contacts = not race.Contacts })
		end)
		-- Catégorie : parmi les voitures de l'hôte (prêtée aux autres pilotes).
		local classes = MenuKit.OwnedClasses(ctx)
		MenuKit.Stepper(ctx, b, "Voiture", CarClasses.Get(race.CarClass).Name, function(direction)
			if #classes > 1 then
				local index = table.find(classes, race.CarClass) or 1
				ctx.Action("Settings", { CarClass = classes[((index - 1 + direction) % #classes) + 1] })
			end
		end)
	else
		b:Text(string.format(
			"%s · %d tours · %s · contacts %s",
			CarClasses.Get(race.CarClass).Name,
			race.Laps,
			MenuKit.RaceFormatName(race.Format),
			if race.Contacts then "activés" else "désactivés"
		), 14)
		if inLobby and not table.find(MenuKit.OwnedClasses(ctx), race.CarClass) then
			b:Text("Tu n'as pas cette voiture : elle t'est prêtée pour la course.", 12, Widgets.COLOR_GREEN)
		end
	end

	local stateText: string
	if inLobby then
		stateText = string.format("Salle d'attente (%d/%d pilotes)", #race.Members, race.MaxPlayers)
	elseif race.State == "Grid" or race.State == "Countdown" then
		stateText = race.RoundName .. " — départ imminent"
	elseif race.State == "Racing" then
		stateText = race.RoundName .. " — en cours"
	else
		stateText = race.RoundName .. " — résultats"
	end
	b:Text(stateText, 14, Widgets.COLOR_ACCENT)
	ctx.SetCountdown(b:Text("", 14, Widgets.COLOR_GREEN))
	if inLobby and #race.Members == 1 then
		b:Text("Seul pour l'instant : la course partira quand même. Une course en solo ne compte pas pour la carrière (points, victoires), mais tes records du tour, oui.", 12, Widgets.COLOR_DIM)
	end

	b:Section("Pilotes")
	for _, member in ipairs(race.Members) do
		local host = if member.UserId == race.HostUserId then "★ " else "   "
		local color = if member.UserId == ctx.LocalUserId then Widgets.COLOR_ACCENT else Widgets.COLOR_TEXT
		b:Text(host .. member.Name, 15, color)
	end

	local row = b:Row(36)
	local width = MenuKit.CONTENT_WIDTH
	if inLobby then
		local half = (width - 8) / 2
		if isHost then
			local canStart = #race.Members >= race.MinPlayers
			local start = ctx.Button(row, "LANCER MAINTENANT", 0, half, function()
				if canStart then
					ctx.Action("Start", nil)
				end
			end)
			if canStart then
				Widgets.Primary(start)
			else
				start.TextColor3 = Widgets.COLOR_DIM
			end
		end
		ctx.Button(row, "QUITTER", if isHost then half + 8 else 0, if isHost then half else width, function()
			ctx.Action("Leave", nil)
		end)
	else
		local abandon = ctx.Button(row, "ABANDONNER", 0, width, function()
			ctx.Action("Abandon", nil)
		end)
		Widgets.Danger(abandon)
	end

	b:Section("Records du tour")
	CareerPage.LapRecords(ctx, b, race.TrackId, race.CarClass)
end

return RacePage
