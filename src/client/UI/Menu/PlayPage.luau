--!strict
--[[
	PlayPage.luau
	Rubriques du menu pour JOUER : les spéciales (une ligne chacune, et le
	ralenti de son meilleur passage), le
	rallycross (un bouton par circuit : on ouvre la salle d'attente, ou on
	rejoint celle qui attend), les essais libres, le retour au paddock ; et
	l'événement double XP en cours ou à venir (XpEvents.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local XpEvents = require(ReplicatedStorage.Shared.Progression.XpEvents)
local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)
local Weather = require(ReplicatedStorage.Shared.Weather.Weather)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local RaceTypes = require(script.Parent.Parent.Parent.Race.RaceTypes)
local MenuKit = require(script.Parent.MenuKit)
local Theme = require(script.Parent.Parent.Theme)
local CopilotVoice = require(script.Parent.Parent.Parent.Audio.CopilotVoice)
local Settings = require(script.Parent.Parent.Parent.Core.Settings)
local Widgets = require(script.Parent.Parent.Widgets)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local PlayPage = {}

-- Un circuit du menu : nom, ce qui s'y passe, et le bouton pour y courir.
local function circuitRow(ctx: Context, b: Builder, id: string)
	local circuit = Tracks.Get(id)
	if not circuit then
		return
	end
	-- Salle qui attend des pilotes (on la rejoint) et pilotes déjà en piste.
	local waiting: RaceTypes.LobbyRace? = nil
	local racing = 0
	for _, race in ipairs(ctx.Data.Lobby) do
		if race.TrackId == id then
			if race.State == "Lobby" and race.Count < race.Max then
				waiting = waiting or race
			elseif race.State ~= "Lobby" then
				racing += race.Count
			end
		end
	end
	local details = string.match(circuit.Description, "^[^%.]+") or ""
	local status = {}
	if waiting then
		local weather = Weather.Sanitize(waiting.Weather)
		table.insert(status, string.format("%d en attente · %s · %d tours · %s%s", waiting.Count, CarClasses.Get(waiting.CarClass).Name, waiting.Laps, MenuKit.RaceFormatName(waiting.Format), if weather == "Dry" then "" else " · " .. string.lower(Weather.MODE_NAMES[weather])))
	end
	if racing > 0 then
		table.insert(status, string.format("%d en course", racing))
	end

	local width = MenuKit.CONTENT_WIDTH
	local row = b:Row(40)
	local name = Widgets.Label(row, circuit.Name, 15, Enum.Font.GothamBold)
	name.Position = UDim2.fromOffset(0, 2)
	name.Size = UDim2.new(1, -176, 0, 18)
	local info = Widgets.Label(row, if #status > 0 then table.concat(status, " · ") else details, 12, Enum.Font.GothamMedium, if waiting then Widgets.COLOR_GREEN else Widgets.COLOR_DIM)
	info.Position = UDim2.fromOffset(0, 21)
	info.Size = UDim2.new(1, -176, 0, 16)
	info.TextTruncate = Enum.TextTruncate.AtEnd
	local text = if waiting then string.format("REJOINDRE (%d/%d)", waiting.Count, waiting.Max) else "COURIR"
	local button = ctx.Button(row, text, width - 168, 168, function()
		ctx.Action("Play", { Mode = "Rallycross", TrackId = id })
	end)
	if waiting then
		Widgets.Primary(button)
	end
end

-- Double XP : l'événement en cours, sinon le prochain.
function PlayPage.XpEvent(_ctx: Context, b: Builder)
	local now = workspace:GetServerTimeNow()
	local active = XpEvents.Active(now)
	if active then
		b:Text(string.format(
			"★ XP ×%d · %s : toute l'XP compte %d fois (Rallye Pass et écurie compris) · encore %s",
			active.Multiplier,
			active.Name,
			active.Multiplier,
			Format.Remaining(active.EndsAt - now)
		), 14, Widgets.COLOR_ACCENT)
		return
	end
	local upcoming = XpEvents.Next(now)
	if upcoming then
		b:Text(string.format("Prochain XP ×%d : %s, dans %s.", upcoming.Multiplier, upcoming.Name, Format.Remaining(upcoming.StartsAt - now)), 12, Widgets.COLOR_DIM)
	end
end

--[[
	Événement éclair (FlashEvents.luau) : celui en cours, son effet et le
	temps qui reste ; pendant « Voiture rare », de quoi la prendre tout de
	suite sur une spéciale. Sinon, le prochain et dans combien de temps.
]]
function PlayPage.FlashEvent(ctx: Context, b: Builder)
	local now = workspace:GetServerTimeNow()
	local active = FlashEvents.Active(now)
	if active then
		local car = if active.CarClass then CarClasses.Get(active.CarClass) else nil
		b:Text(string.format(
			"%s ÉVÉNEMENT ÉCLAIR · %s%s · %s Encore %s.",
			active.Kind.Icon,
			Format.Upper(active.Kind.Name),
			if car then " : " .. Format.Upper(car.Name) else "",
			active.Kind.Description,
			Format.Remaining(active.EndsAt - now)
		), 14, Theme.CYAN)
		if car then
			local row = b:Row(38)
			local weather = Weather.Sanitize(ctx.View.StageWeather)
			local button = ctx.Button(row, "PILOTER LA " .. Format.Upper(car.Name) .. " (PRÊTÉE)", 0, MenuKit.CONTENT_WIDTH, function()
				ctx.Action("Play", { Mode = "EventCar", TrackId = Stages.DEFAULT, Weather = weather })
			end)
			Widgets.Primary(button)
		end
		return
	end
	local upcoming = FlashEvents.Next(now)
	b:Text(string.format(
		"Prochain événement éclair dans %s : %s %s.",
		Format.Remaining(upcoming.StartsAt - now),
		upcoming.Kind.Icon,
		upcoming.Kind.Name
	), 12, Widgets.COLOR_DIM)
end

local SURFACE_ICONS = { Tarmac = "🛣 ", Snow = "❄ ", Gravel = "🌲 ", Mixed = "🔀 " }
local SURFACE_NAMES = { Tarmac = "Asphalte", Snow = "Neige", Gravel = "Terre", Mixed = "Mixte" }

-- Les spéciales : une ligne chacune (nom, ce qui l'attend, LANCER), puis le
-- ralenti de son meilleur passage.
function PlayPage.Stage(ctx: Context, b: Builder)
	local width = MenuKit.CONTENT_WIDTH
	b:Section("Spéciales")
	b:Text("Bats ton record sur chaque spéciale et grimpe au classement (L) : chacune a ses médailles et ses fantômes.", 13, Widgets.COLOR_DIM)
	-- Météo de la prochaine spéciale (gardée dans le menu tant que la partie dure).
	local weather = Weather.Sanitize(ctx.View.StageWeather)
	MenuKit.Stepper(ctx, b, "Météo", Weather.MODE_NAMES[weather], function(direction)
		local index = table.find(Weather.MODES, weather) or 1
		ctx.View.StageWeather = Weather.MODES[((index - 1 + direction) % #Weather.MODES) + 1]
		ctx.Rebuild()
	end)
	b:Text(Weather.MODE_DESCRIPTIONS[weather], 12, Widgets.COLOR_DIM)
	for index, id in ipairs(Stages.List()) do
		local track = Stages.Get(id)
		local row = b:Row(44)
		local name = Widgets.Label(row, SURFACE_ICONS[track.Surface] .. track.Name, 15, Enum.Font.GothamBold)
		name.Position = UDim2.fromOffset(0, 2)
		name.Size = UDim2.new(1, -176, 0, 18)
		local info = Widgets.Label(row, SURFACE_NAMES[track.Surface] .. " · " .. track.Description, 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
		info.Position = UDim2.fromOffset(0, 21)
		info.Size = UDim2.new(1, -176, 0, 22)
		info.TextWrapped = true
		info.TextTruncate = Enum.TextTruncate.AtEnd
		local launch = ctx.Button(row, "LANCER", width - 168, 168, function()
			ctx.Action("Play", { Mode = "Stage", TrackId = id, Weather = weather })
		end)
		if index == 1 then
			Widgets.Primary(launch)
		end
	end
	-- Ralenti façon télévision, et mode photo.
	local replayRow = b:Row(36)
	local opponent = ctx.Data.ReplayOpponent
	local half = (width - 8) / 2
	ctx.Button(replayRow, "RALENTI : TON MEILLEUR", 0, if opponent then half else width, function()
		ctx.Action("Replay", { Which = "Own" } :: any)
	end)
	if opponent then
		local other = ctx.Button(replayRow, "RALENTI : " .. Format.Upper(opponent), half + 8, half, function()
			ctx.Action("Replay", { Which = "Opponent" } :: any)
		end)
		other.TextTruncate = Enum.TextTruncate.AtEnd
	end
	-- Voix du copilote (aussi : touche N).
	MenuKit.Stepper(ctx, b, "Voix du copilote (N)", CopilotVoice.MODE_NAMES[CopilotVoice.GetMode()], function(direction)
		CopilotVoice.Cycle(direction)
		Settings.SyncCopilot() -- le choix de l'onglet OPTIONS suit
		ctx.Rebuild()
	end)
end

-- Rallycross : un bouton par circuit.
function PlayPage.Rallycross(ctx: Context, b: Builder)
	b:Section("Rallycross")
	b:Text("Seul ou jusqu'à 6 pilotes. Le départ est donné 20 s après le premier inscrit : les autres peuvent rejoindre d'ici là, et l'hôte peut lancer sans attendre. Joker obligatoire une fois par course.", 13, Widgets.COLOR_DIM)
	for _, id in ipairs(Tracks.List()) do
		circuitRow(ctx, b, id)
	end
end

-- Essais libres, retour au paddock.
function PlayPage.More(ctx: Context, b: Builder)
	local width = MenuKit.CONTENT_WIDTH
	b:Section("Et aussi")
	local practiceRow = b:Row(36)
	ctx.Button(practiceRow, "ESSAIS LIBRES (piste d'essai)", 0, width, function()
		ctx.Action("Play", { Mode = "Practice" })
	end)
	local homeRow = b:Row(36)
	ctx.Button(homeRow, "RETOUR AU PADDOCK (H)", 0, width, function()
		ctx.Action("Paddock", nil)
	end)
	b:Text("Au paddock, entrer à pied dans la zone d'un circuit fait aussi rejoindre sa salle d'attente (en sortir, c'est la quitter).", 12, Widgets.COLOR_DIM)
end

return PlayPage
