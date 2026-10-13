--!strict
--[[
	ChampionshipPage.luau
	Rubrique « Championnats » de l'onglet JOUER (ChampionshipService) :
		- le rallye en cours : où on en est (spéciale, cumul, pénalités),
		  le reprendre ou l'abandonner ;
		- chaque rallye : ses spéciales et leur météo, ce qu'il rapporte,
		  son record perso et son classement dans la catégorie de la voiture
		  choisie, et le bouton pour le courir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = require(ReplicatedStorage.Shared.Weather.Weather)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Credits = require(ReplicatedStorage.Shared.Economy.Credits)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local ChampionshipPage = {}

local function legsText(legs: { any }): string
	local parts = {}
	for index, leg in ipairs(legs) do
		local weather = Weather.Sanitize(leg.Weather)
		table.insert(parts, string.format("%d. %s%s", index, tostring(leg.Name), if weather == "Dry" then "" else " (" .. string.lower(Weather.MODE_NAMES[weather]) .. ")"))
	end
	return table.concat(parts, " · ")
end

local function currentSection(ctx: Context, b: Builder, current: any)
	local width = MenuKit.CONTENT_WIDTH
	local half = (width - 8) / 2
	b:Text(string.format(
		"Rallye en cours : %s · %s",
		tostring(current.Name),
		CarClasses.Get(current.ClassId).Name
	), 15, Theme.ACCENT)
	if current.Expired then
		b:Text("La semaine est passée : ce rallye ne compte plus. Abandonne-le pour en lancer un autre.", 12, Widgets.COLOR_RED)
	else
		b:Text(string.format(
			"Spéciale %d/%d · cumul %s%s",
			math.min(current.Index, current.Count),
			current.Count,
			Format.Ms(current.Total),
			if current.Penalty > 0 then string.format(" (dont %d s de pénalités)", current.Penalty // 1000) else ""
		), 13, Widgets.COLOR_TEXT)
	end
	local row = b:Row(38)
	if not current.Expired then
		local continue = ctx.Button(row, "REPRENDRE", 0, half, function()
			ctx.Action("Championship", { Action = "Continue" })
		end)
		Widgets.Primary(continue)
	end
	local abandon = ctx.Button(row, "ABANDONNER", if current.Expired then 0 else half + 8, if current.Expired then width else half, function()
		ctx.Action("Championship", { Action = "Abandon" })
	end)
	Widgets.Danger(abandon)
end

function ChampionshipPage.Rallies(ctx: Context, b: Builder)
	local state: any = ctx.Data.Championship
	local width = MenuKit.CONTENT_WIDTH
	b:Section("Championnats")
	if not state then
		b:Text("Chargement…", 13, Widgets.COLOR_DIM)
		return
	end
	b:Text("Des rallyes de plusieurs spéciales enchaînées, au temps cumulé. Un retour au départ coûte 30 s. On peut s'arrêter et reprendre plus tard.", 12, Widgets.COLOR_DIM)
	local current = state.Current
	if current then
		currentSection(ctx, b, current)
	end
	for _, rally in ipairs(state.List or {}) do
		local row = b:Row(44)
		local name = Widgets.Label(row, (if rally.Weekly then "★ " else "🏁 ") .. tostring(rally.Name), 15, Enum.Font.GothamBold, if rally.Weekly then Theme.ACCENT else Widgets.COLOR_TEXT)
		name.Position = UDim2.fromOffset(0, 2)
		name.Size = UDim2.new(1, -176, 0, 18)
		local reward = Widgets.Label(row, string.format("%d spéciales · +%s · +%d XP", #rally.Legs, Credits.Format(rally.Credits), rally.Xp), 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
		reward.Position = UDim2.fromOffset(0, 22)
		reward.Size = UDim2.new(1, -176, 0, 18)
		local running = current ~= nil and current.Id == rally.Id
		local button = ctx.Button(row, if running then "REPRENDRE" else "COURIR", width - 168, 168, function()
			ctx.Action("Championship", { Action = "Start", Id = rally.Id })
		end)
		if running then
			Widgets.Primary(button)
		end
		b:Text(legsText(rally.Legs), 12, Widgets.COLOR_DIM)
		local board = rally.Board or {}
		local lines = {}
		if rally.Best then
			table.insert(lines, "Ton meilleur : " .. Format.Ms(rally.Best))
		end
		if board[1] then
			table.insert(lines, string.format("Record : %s %s", tostring(board[1].Name), Format.Ms(board[1].Ms)))
		end
		if #lines > 0 then
			b:Text(table.concat(lines, " · ") .. " (" .. CarClasses.Get(state.ClassId).Name .. ")", 12, Widgets.COLOR_ACCENT)
		end
	end
end

return ChampionshipPage
