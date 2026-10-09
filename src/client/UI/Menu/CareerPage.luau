--!strict
--[[
	CareerPage.luau
	Rubriques de la carrière : sa voiture (couleur, numéro), les records du
	tour de chaque circuit avec ses médailles (Medals.luau), son niveau, sa
	licence et ses statistiques de course.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local CareerPage = {}

function CareerPage.LapRecords(ctx: Context, b: Builder, trackId: string)
	local circuit = Tracks.Get(trackId)
	if not circuit then
		return
	end
	local board = ctx.Data.Records[trackId]
	local mine = ctx.Data.Laps[circuit.Key]
	-- Son record, sa médaille, et la prochaine à décrocher.
	local limits = Medals.ForCircuit(trackId, circuit.Length)
	local tier = Medals.TierOf(mine, limits)
	local nextTier, nextMs = Medals.Next(mine, limits)
	local text = string.format("%s — ton record : %s", circuit.Name, if mine then Format.Time(mine / 1000) else "aucun")
	if tier > 0 then
		text ..= "  " .. Medals.Rich(tier)
	end
	if nextTier and nextMs then
		text ..= "  → " .. Medals.Rich(nextTier) .. " " .. Medals.FormatLimit(nextMs)
	end
	b:Text(text, 14, Widgets.COLOR_TEXT).RichText = true
	b:Text("   " .. Medals.RichLine(limits), 12, Widgets.COLOR_DIM).RichText = true
	if board and #board.Entries > 0 then
		for index, entry in ipairs(board.Entries) do
			local color = if entry.UserId == ctx.LocalUserId then Widgets.COLOR_ACCENT else Widgets.COLOR_DIM
			local label = b:Text(string.format("   %d. %s  %s", index, entry.Name, Format.Time(entry.Ms / 1000)), 13, color)
			label.Font = Enum.Font.RobotoMono
		end
	else
		b:Text("   Pas encore de record.", 13, Widgets.COLOR_DIM)
	end
end

-- Niveau, licence, barre d'XP, et d'où vient l'XP.
local function progressLines(ctx: Context, b: Builder)
	local progress = ctx.Data.Progress
	if not progress then
		return
	end
	local licence = Progression.LICENCES[progress.Licence] or Progression.LICENCES[1]
	local title = b:Text(string.format(
		'Niveau %d · <font color="%s">Licence %s</font> · %s XP',
		progress.Level,
		Medals.Hex(licence.Color),
		licence.Name,
		Format.Thousands(progress.Xp)
	), 15)
	title.RichText = true
	title.Font = Enum.Font.GothamBold

	-- Barre jusqu'au niveau suivant.
	local nextXp: number? = progress.NextXp
	local row = b:Row(12)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.fromOffset(0, 2)
	track.BackgroundColor3 = Widgets.COLOR_BUTTON
	track.BorderSizePixel = 0
	Widgets.Corner(track, 4)
	track.Parent = row
	local fill = Instance.new("Frame")
	local fraction = 1
	if nextXp then
		fraction = math.clamp((progress.Xp - progress.LevelXp) / math.max(1, nextXp - progress.LevelXp), 0, 1)
	end
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = licence.Color
	fill.BorderSizePixel = 0
	Widgets.Corner(fill, 4)
	fill.Parent = track
	if nextXp then
		b:Text(string.format("Niveau %d à %s XP", progress.Level + 1, Format.Thousands(nextXp)), 12, Widgets.COLOR_DIM)
	end
	b:Text(string.format(
		"Spéciales terminées %d · Points de style %s",
		progress.StageRuns,
		Format.Thousands(progress.Style)
	), 13)
	b:Text(string.format(
		"XP : médailles, courses, victoires, podiums, points, spéciales terminées, et le style en compétition — dérapages, sauts, dépassements (%d points de style = 1 XP).",
		Progression.XP.STYLE_PER_XP
	), 12, Widgets.COLOR_DIM)
end

-- Couleur et numéro de sa voiture.
function CareerPage.Livery(ctx: Context, b: Builder)
	local livery = ctx.Data.Livery
	if not livery then
		b:Text("Chargement…", 13, Widgets.COLOR_DIM)
		return
	end
	local current: Livery.Livery = livery
	local function send(changed: Livery.Livery)
		ctx.Data.Livery = changed
		ctx.Action("Livery", changed)
		ctx.Rebuild()
	end
	local colorValue = MenuKit.Stepper(ctx, b, "Couleur", Livery.NameOf(current), function(direction)
		-- Couleur suivante parmi celles débloquées (Progression.luau).
		local count = #Livery.COLORS
		local color = current.Color
		for _ = 1, count do
			color = ((color - 1 + direction) % count) + 1
			if Progression.IsUnlocked("Color", color, ctx.Data.Progress) then
				break
			end
		end
		local changed = table.clone(current)
		changed.Color = color
		send(changed)
	end)
	-- Pastille de la couleur, derrière le nom.
	local swatch = Livery.ColorOf(current)
	colorValue.BackgroundTransparency = 0
	colorValue.BackgroundColor3 = swatch
	colorValue.TextColor3 = Livery.ContrastOf(swatch)
	Widgets.Corner(colorValue, 6)
	MenuKit.Stepper(ctx, b, "Numéro", "#" .. tostring(current.Number), function(direction)
		local range = Livery.MAX_NUMBER - Livery.MIN_NUMBER + 1
		local changed = table.clone(current)
		changed.Number = ((current.Number - Livery.MIN_NUMBER + direction) % range) + Livery.MIN_NUMBER
		send(changed)
	end)
	b:Text("Visible de tous : carrosserie, numéros sur les flancs et le toit. Bandes, style du numéro, couleurs à débloquer et aperçu : au GARAGE (zone violette du paddock).", 12, Widgets.COLOR_DIM)
end

-- Ta voiture : couleur et numéro.
function CareerPage.Car(ctx: Context, b: Builder)
	b:Section("Ta voiture")
	CareerPage.Livery(ctx, b)
end

-- Records du tour de chaque circuit.
function CareerPage.Records(ctx: Context, b: Builder)
	b:Section("Records du tour")
	for _, id in ipairs(Tracks.List()) do
		CareerPage.LapRecords(ctx, b, id)
	end
end

-- Niveau, licence, XP et statistiques de course.
function CareerPage.Career(ctx: Context, b: Builder)
	b:Section("Ta carrière")
	progressLines(ctx, b)
	local stats = ctx.Data.Stats
	if stats then
		b:Text(string.format(
			"Courses %d · Victoires %d · Podiums %d · Points %d",
			stats.Races,
			stats.Wins,
			stats.Podiums,
			stats.Points
		), 14)
	else
		b:Text("Chargement…", 13, Widgets.COLOR_DIM)
	end
	b:Text("Points : 10, 8, 6, 4, 2, 1 du 1er au 6e (finale, ou course simple).", 12, Widgets.COLOR_DIM)
end

return CareerPage
