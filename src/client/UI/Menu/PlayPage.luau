--!strict
--[[
	PlayPage.luau
	Rubriques du menu pour JOUER : la spéciale (et son ralenti), le
	rallycross (un bouton par circuit : on ouvre la salle d'attente, ou on
	rejoint celle qui attend), les essais libres, le retour au paddock ; et
	l'événement double XP en cours ou à venir (XpEvents.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local XpEvents = require(ReplicatedStorage.Shared.Progression.XpEvents)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local RaceTypes = require(script.Parent.Parent.Parent.Race.RaceTypes)
local MenuKit = require(script.Parent.MenuKit)
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
		table.insert(status, string.format("%d en attente · %s · %d tours · %s", waiting.Count, CarClasses.Get(waiting.CarClass).Name, waiting.Laps, MenuKit.RaceFormatName(waiting.Format)))
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

-- Spéciale : la lancer, et le ralenti de son meilleur passage.
function PlayPage.Stage(ctx: Context, b: Builder)
	local width = MenuKit.CONTENT_WIDTH
	b:Section("Spéciale")
	b:Text("1,6 km chronométrés, terre et asphalte, un saut et deux épingles. Bats ton record et grimpe au classement (L).", 13, Widgets.COLOR_DIM)
	local stageRow = b:Row(40)
	local stage = ctx.Button(stageRow, "LANCER UNE SPÉCIALE", 0, width, function()
		ctx.Action("Play", { Mode = "Stage" })
	end)
	Widgets.Primary(stage)
	stage.TextSize = 16
	-- Ralenti façon télévision, et mode photo.
	local replayRow = b:Row(36)
	local opponent = ctx.Data.ReplayOpponent
	local half = (width - 8) / 2
	ctx.Button(replayRow, "RALENTI : TON MEILLEUR", 0, if opponent then half else width, function()
		ctx.Action("Replay", { Which = "Own" } :: any)
	end)
	if opponent then
		local other = ctx.Button(replayRow, "RALENTI : " .. string.upper(opponent), half + 8, half, function()
			ctx.Action("Replay", { Which = "Opponent" } :: any)
		end)
		other.TextTruncate = Enum.TextTruncate.AtEnd
	end
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
