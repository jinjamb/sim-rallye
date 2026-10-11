--!strict
--[[
	ChallengesPage.luau
	Rubriques des défis : le défi de la semaine (contrainte, fin, podium,
	son temps) et les défis du jour (objectifs, progression, XP).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weekly = require(ReplicatedStorage.Shared.Challenges.Weekly)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local ChallengesPage = {}

-- Défi de la semaine : la contrainte, la fin, le podium, son temps, le bouton.
function ChallengesPage.Weekly(ctx: Context, b: Builder)
	local board: any = ctx.Data.Weekly
	local modifier = if board then Weekly.ModifierById(board.Modifier) else nil
	if not board or not modifier then
		return
	end
	local width = MenuKit.CONTENT_WIDTH
	b:Section("Défi de la semaine")
	local row = b:Row(28)
	local tag = Theme.Tag(row, string.upper(modifier.Name), Theme.ACCENT, Theme.ON_ACCENT, 16)
	tag.Position = UDim2.fromOffset(0, 2)
	local remaining = Widgets.Label(
		row,
		"fin dans " .. Format.Remaining(board.EndsAt - workspace:GetServerTimeNow()),
		13,
		Enum.Font.GothamBold,
		Widgets.COLOR_DIM
	)
	remaining.Size = UDim2.fromScale(1, 1)
	remaining.TextXAlignment = Enum.TextXAlignment.Right
	b:Text(modifier.Description .. " La spéciale, ce seul changement, et un classement remis à zéro chaque lundi.", 13, Widgets.COLOR_DIM)
	-- La voiture de la semaine, la même pour tous (prêtée si on ne l'a pas).
	local class = CarClasses.Get(board.CarClass)
	local loaned = not table.find(MenuKit.OwnedClasses(ctx), class.Id)
	b:Text("Voiture imposée : " .. class.Name .. (if loaned then " (prêtée pour le défi)" else ""), 13, Theme.ACCENT)

	local entries = board.Entries or {}
	if #entries == 0 then
		b:Text("Personne n'a encore relevé le défi cette semaine : à toi !", 13, Widgets.COLOR_GREEN)
	end
	for index = 1, math.min(3, #entries) do
		local entry = entries[index]
		local color = if entry.UserId == ctx.LocalUserId then Widgets.COLOR_ACCENT else Widgets.COLOR_TEXT
		local label = b:Text(string.format("   %d. %s  %s", index, entry.Name, Format.Time(entry.Ms / 1000)), 14, color)
		label.Font = Enum.Font.RobotoMono
	end
	local mine: number? = board.Mine
	b:Text(
		if mine
			then "Ton meilleur temps cette semaine : " .. Format.Time(mine / 1000)
			else string.format("Pas encore de temps cette semaine · +%d XP à ta première arrivée", Progression.XP.WEEKLY),
		13,
		if mine then Widgets.COLOR_TEXT else Widgets.COLOR_ACCENT
	)
	local buttonRow = b:Row(40)
	local go = ctx.Button(buttonRow, "RELEVER LE DÉFI", 0, width, function()
		ctx.Action("Play", { Mode = "Weekly" })
	end)
	Widgets.Primary(go)
	go.TextSize = 16
end

-- Défis du jour : chaque objectif, sa barre, l'XP ; et quand ils changent.
function ChallengesPage.Daily(ctx: Context, b: Builder)
	local state: any = ctx.Data.Daily
	if not state then
		return
	end
	b:Section("Défis du jour")
	for _, challenge in ipairs(state.Challenges) do
		local row = b:Row(38)
		local done = challenge.Done == true
		-- Case cochée ou vide.
		local box = Instance.new("TextLabel")
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(0, 4)
		box.Size = UDim2.fromOffset(22, 22)
		box.BackgroundColor3 = if done then Theme.GREEN else Theme.PANEL_2
		box.Text = if done then "✓" else ""
		box.TextColor3 = Theme.ON_ACCENT
		box.FontFace = Theme.HEADLINE
		box.TextSize = 16
		Theme.Corner(box, 2)
		box.Parent = row
		local text = Widgets.Label(row, challenge.Text, 14, Enum.Font.GothamBold, if done then Widgets.COLOR_DIM else Widgets.COLOR_TEXT)
		text.Position = UDim2.fromOffset(32, 2)
		text.Size = UDim2.new(1, -120, 0, 20)
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local amount = Widgets.Label(
			row,
			if done then "+" .. tostring(state.Xp) .. " XP ✓" else string.format("%s / %s", Format.Thousands(challenge.Progress), Format.Thousands(challenge.Goal)),
			13,
			Enum.Font.GothamBold,
			if done then Widgets.COLOR_GREEN else Widgets.COLOR_DIM
		)
		amount.Position = UDim2.new(1, -110, 0, 2)
		amount.Size = UDim2.fromOffset(110, 20)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		-- Barre de progression.
		local track = Instance.new("Frame")
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Theme.PANEL_2
		track.Position = UDim2.fromOffset(32, 26)
		track.Size = UDim2.new(1, -32, 0, 5)
		track.Parent = row
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = if done then Theme.GREEN else Theme.ACCENT
		fill.Size = UDim2.fromScale(math.clamp(challenge.Progress / math.max(1, challenge.Goal), 0, 1), 1)
		fill.Parent = track
	end
	b:Text(string.format(
		"%s · +%d XP par défi, +%d pour les trois · nouveaux défis dans %s",
		if state.Bonus then "Les trois sont faits, bravo !" else "Spéciale, défi ou course",
		state.Xp,
		state.BonusXp,
		Format.Remaining(state.EndsAt - workspace:GetServerTimeNow())
	), 12, Widgets.COLOR_DIM)
end

-- Roi du drift : les meilleures combinaisons de la semaine, et la sienne.
function ChallengesPage.DriftKing(ctx: Context, b: Builder)
	local board: any = ctx.Data.Drift
	if not board then
		return
	end
	b:Section("Roi du drift")
	b:Text("La plus grosse combinaison de dérapages de la semaine, en spéciale chronométrée ou en course. Le n°1 porte le titre au-dessus de sa voiture. Remis à zéro le lundi.", 13, Widgets.COLOR_DIM)
	local entries = board.Entries or {}
	if #entries == 0 then
		b:Text("Personne n'a encore le titre cette semaine : à toi !", 13, Widgets.COLOR_GREEN)
	end
	for index = 1, math.min(5, #entries) do
		local entry = entries[index]
		local color = if entry.UserId == ctx.LocalUserId then Widgets.COLOR_ACCENT elseif index == 1 then Theme.ACCENT else Widgets.COLOR_TEXT
		local label = b:Text(string.format("   %s%d. %s  %s pts", if index == 1 then "★ " else "", index, entry.Name, Format.Thousands(entry.Score)), 14, color)
		label.Font = Enum.Font.RobotoMono
	end
	local mine: number? = board.Mine
	b:Text(
		if mine then "Ta meilleure combinaison cette semaine : " .. Format.Thousands(mine) .. " pts" else "Pas encore de combinaison cette semaine.",
		13,
		if mine then Widgets.COLOR_TEXT else Widgets.COLOR_DIM
	)
end

-- Rappel dans l'onglet JOUER : où en sont les défis, et un bouton pour y aller.
function ChallengesPage.Summary(ctx: Context, b: Builder)
	local parts = {}
	local daily: any = ctx.Data.Daily
	if daily then
		local done = 0
		for _, challenge in ipairs(daily.Challenges) do
			if challenge.Done then
				done += 1
			end
		end
		table.insert(parts, string.format("Défis du jour %d/%d", done, #daily.Challenges))
	end
	local board: any = ctx.Data.Weekly
	local modifier = if board then Weekly.ModifierById(board.Modifier) else nil
	if modifier then
		table.insert(parts, "Semaine : " .. modifier.Name .. (if board.Mine then " ✓" else ""))
	end
	if #parts == 0 then
		return
	end
	local row = b:Row(36)
	local text = Widgets.Label(row, table.concat(parts, "  ·  "), 14, Enum.Font.GothamBold, Theme.ACCENT)
	text.Size = UDim2.new(1, -128, 1, 0)
	text.TextTruncate = Enum.TextTruncate.AtEnd
	ctx.Button(row, "DÉFIS ▶", MenuKit.CONTENT_WIDTH - 120, 120, function()
		ctx.SetTab("Challenges")
	end)
end

return ChallengesPage
