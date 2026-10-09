--!strict
--[[
	TeamPage.luau
	L'onglet ÉCURIE (Teams.luau, TeamService) :
		- une invitation reçue : l'accepter ou la refuser ;
		- sans écurie : en fonder une (nom, sigle, deux couleurs) ;
		- avec : ses pilotes (le fondateur peut exclure), inviter les joueurs
		  du serveur (les amis d'abord), porter les couleurs de l'écurie,
		  les changer (fondateur), la quitter ;
		- le classement des écuries de la saison.
	Le brouillon de création (nom, sigle, couleurs) est gardé dans
	ctx.View : il survit aux reconstructions du menu.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Teams = require(ReplicatedStorage.Shared.Teams.Teams)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local TeamPage = {}

-- Amis du joueur parmi les présents (IsFriendsWith interroge Roblox : une
-- fois par joueur, en tâche de fond).
local friends: { [number]: boolean } = {}
local asked: { [number]: boolean } = {}

local function isFriend(ctx: Context, userId: number): boolean
	if not asked[userId] then
		asked[userId] = true
		task.spawn(function()
			local ok, result = pcall(function()
				return Players.LocalPlayer:IsFriendsWith(userId)
			end)
			friends[userId] = ok and result == true
			if friends[userId] then
				ctx.Rebuild()
			end
		end)
	end
	return friends[userId] == true
end

local function colorName(index: number): string
	local swatch = Livery.COLORS[index]
	return if swatch then swatch.Name else "?"
end

-- Ligne « libellé ◀ couleur ▶ », la valeur sur fond de la couleur.
local function colorStepper(ctx: Context, b: Builder, label: string, value: number, onChange: (number) -> ())
	local valueLabel = MenuKit.Stepper(ctx, b, label, colorName(value), function(direction)
		onChange(((value - 1 + direction) % Teams.COLOR_COUNT) + 1)
	end)
	local color = Livery.COLORS[value].Color
	valueLabel.BackgroundTransparency = 0
	valueLabel.BackgroundColor3 = color
	valueLabel.TextColor3 = Livery.ContrastOf(color)
end

-- Champ de saisie sur une ligne ; le texte va dans ctx.View[key].
local function textField(ctx: Context, b: Builder, label: string, key: string, placeholder: string, maxLength: number)
	local row = b:Row(34)
	local text = Widgets.Label(row, label, 14)
	text.Size = UDim2.new(0, 120, 1, 0)
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(130, 2)
	box.Size = UDim2.new(1, -130, 1, -4)
	box.BackgroundColor3 = Theme.PANEL_2
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.FontFace = Theme.BODY_BOLD
	box.TextSize = 16
	box.TextColor3 = Theme.TEXT
	box.PlaceholderColor3 = Theme.DIM
	box.PlaceholderText = placeholder
	box.Text = ctx.View[key] or ""
	Theme.Corner(box)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if utf8.len(box.Text) and (utf8.len(box.Text) :: number) > maxLength then
			box.Text = string.sub(box.Text, 1, (utf8.offset(box.Text, maxLength + 1) :: number) - 1)
		end
		ctx.View[key] = box.Text
	end)
	box.Parent = row
end

local function inviteSection(ctx: Context, b: Builder, state: any)
	local invite = state.Invite
	if not invite then
		return
	end
	b:Section("Invitation")
	b:Text(string.format("%s t'invite dans l'écurie %s.", invite.FromName, invite.TeamName), 14, Theme.ACCENT)
	local row = b:Row(36)
	local half = (MenuKit.CONTENT_WIDTH - 8) / 2
	local yes = ctx.Button(row, "ACCEPTER", 0, half, function()
		ctx.Action("Team", { Action = "Accept" })
	end)
	Widgets.Primary(yes)
	ctx.Button(row, "REFUSER", half + 8, half, function()
		ctx.Action("Team", { Action = "Decline" })
	end)
end

local function createSection(ctx: Context, b: Builder)
	b:Section("Fonder une écurie")
	b:Text(string.format("Jusqu'à %d pilotes sous les mêmes couleurs, un sigle devant vos noms, et un classement des écuries à chaque saison.", Teams.MAX_MEMBERS), 13, Widgets.COLOR_DIM)
	textField(ctx, b, "Nom", "TeamName", "Les Fous du Volant", Teams.NAME_MAX)
	textField(ctx, b, "Sigle", "TeamTag", "FDV", Teams.TAG_MAX)
	local color = ctx.View.TeamColor or 1
	local stripe = ctx.View.TeamStripe or 3
	colorStepper(ctx, b, "Carrosserie", color, function(value)
		ctx.View.TeamColor = value
		ctx.Rebuild()
	end)
	colorStepper(ctx, b, "Bandes", stripe, function(value)
		ctx.View.TeamStripe = value
		ctx.Rebuild()
	end)
	local row = b:Row(40)
	local go = ctx.Button(row, "FONDER L'ÉCURIE", 0, MenuKit.CONTENT_WIDTH, function()
		ctx.Action("Team", {
			Action = "Create",
			Name = ctx.View.TeamName or "",
			Tag = ctx.View.TeamTag or "",
			Color = color,
			Stripe = stripe,
		})
	end)
	Widgets.Primary(go)
	b:Text("Nom et sigle passent par le filtre de Roblox. Ensuite, invite tes amis présents sur le serveur.", 12, Widgets.COLOR_DIM)
end

local function teamSection(ctx: Context, b: Builder, state: any)
	local team = state.Team
	local isOwner = team.OwnerId == ctx.LocalUserId
	local width = MenuKit.CONTENT_WIDTH
	b:Section("[" .. team.Tag .. "] " .. team.Name)
	b:Text(string.format(
		"%d/%d pilotes · couleurs %s et %s%s",
		#team.Members,
		Teams.MAX_MEMBERS,
		colorName(team.Color),
		colorName(team.Stripe),
		if state.Rank then string.format(" · %de au classement de la saison", state.Rank) else ""
	), 13, Widgets.COLOR_DIM)
	MenuKit.Stepper(ctx, b, "Porter ses couleurs", if state.UseColors then "OUI" else "NON", function(_direction)
		ctx.Action("Team", { Action = "UseColors", On = not state.UseColors })
	end)
	if isOwner then
		colorStepper(ctx, b, "Carrosserie", team.Color, function(value)
			ctx.Action("Team", { Action = "SetColors", Color = value, Stripe = team.Stripe })
		end)
		colorStepper(ctx, b, "Bandes", team.Stripe, function(value)
			ctx.Action("Team", { Action = "SetColors", Color = team.Color, Stripe = value })
		end)
	end

	b:Section("Pilotes")
	for _, member in ipairs(team.Members) do
		local row = b:Row(30)
		local name = Widgets.Label(
			row,
			(if member.Owner then "★ " else "   ") .. tostring(member.Name) .. (if member.Online then "" else "  · absent"),
			14,
			Enum.Font.GothamBold,
			if member.UserId == ctx.LocalUserId then Theme.ACCENT elseif member.Online then Widgets.COLOR_TEXT else Widgets.COLOR_DIM
		)
		name.Size = UDim2.new(1, -110, 1, 0)
		if isOwner and member.UserId ~= ctx.LocalUserId then
			local kick = ctx.Button(row, "EXCLURE", width - 100, 100, function()
				ctx.Action("Team", { Action = "Kick", UserId = member.UserId })
			end)
			Widgets.Danger(kick)
		end
	end

	-- Inviter : les joueurs du serveur qui ne sont pas dans l'écurie, les amis d'abord.
	local inTeam: { [number]: boolean } = {}
	for _, member in ipairs(team.Members) do
		inTeam[member.UserId] = true
	end
	local candidates = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if not inTeam[other.UserId] then
			table.insert(candidates, other)
		end
	end
	table.sort(candidates, function(a, c)
		local fa, fc = isFriend(ctx, a.UserId), isFriend(ctx, c.UserId)
		if fa ~= fc then
			return fa
		end
		return a.DisplayName < c.DisplayName
	end)
	if #candidates > 0 and #team.Members < Teams.MAX_MEMBERS then
		b:Section("Inviter")
		for _, other in ipairs(candidates) do
			local row = b:Row(30)
			local friend = isFriend(ctx, other.UserId)
			local name = Widgets.Label(row, other.DisplayName .. (if friend then "  · ami" else ""), 14, Enum.Font.GothamBold, if friend then Widgets.COLOR_GREEN else Widgets.COLOR_TEXT)
			name.Size = UDim2.new(1, -110, 1, 0)
			ctx.Button(row, "INVITER", width - 100, 100, function()
				ctx.Action("Team", { Action = "Invite", UserId = other.UserId })
			end)
		end
	end

	local leaveRow = b:Row(34)
	local leave = ctx.Button(leaveRow, "QUITTER L'ÉCURIE", 0, width, function()
		ctx.Action("Team", { Action = "Leave" })
	end)
	Widgets.Danger(leave)
end

local function boardSection(ctx: Context, b: Builder, state: any)
	b:Section("Classement des écuries · " .. tostring(state.Season or ""))
	b:Text("Toute l'XP gagnée par ses pilotes pendant la saison du Rallye Pass.", 12, Widgets.COLOR_DIM)
	local entries = state.Board or {}
	if #entries == 0 then
		b:Text("   Pas encore d'écurie classée cette saison.", 13, Widgets.COLOR_DIM)
	end
	local mine = if state.Team then state.Team.Id else nil
	for index, entry in ipairs(entries) do
		local swatch = Livery.COLORS[entry.Color]
		local label = b:Text(string.format(
			'   %d. <font color="%s">[%s]</font> %s  %s XP',
			index,
			Theme.Hex(if swatch then swatch.Color else Theme.TEXT),
			entry.Tag,
			entry.Name,
			Format.Thousands(entry.Score)
		), 13, if entry.TeamId == mine then Theme.ACCENT else Widgets.COLOR_TEXT)
		label.RichText = true
	end
end

function TeamPage.Team(ctx: Context, b: Builder)
	local state: any = ctx.Data.Team
	if not state then
		b:Text("Chargement…", 13, Widgets.COLOR_DIM)
		return
	end
	inviteSection(ctx, b, state)
	if state.Team then
		teamSection(ctx, b, state)
	else
		createSection(ctx, b)
	end
	boardSection(ctx, b, state)
end

return TeamPage
