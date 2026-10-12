--!strict
--[[
	SessionPage.luau
	Rubrique « Jouer entre amis » de l'onglet JOUER (SessionService) :
		- inviter ses amis (l'invitation de Roblox) ;
		- créer une session privée (un serveur rien que pour soi et ses amis)
		  ou en rejoindre une avec son code ;
		- dans une session privée : son code à partager, et le retour aux
		  serveurs publics.
	Le code tapé est gardé dans ctx.View (il survit aux reconstructions).
]]

local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)
local Theme = require(script.Parent.Parent.Theme)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local SessionPage = {}

local CODE_LENGTH = 6

function SessionPage.Friends(ctx: Context, b: Builder)
	local state: any = ctx.Data.Session
	local width = MenuKit.CONTENT_WIDTH
	local half = (width - 8) / 2
	b:Section("Jouer entre amis")
	if state and state.Private then
		b:Text(string.format(
			"Session privée · code %s · %d/%d joueurs",
			tostring(state.Code or "…"),
			tonumber(state.Players) or 1,
			tonumber(state.MaxPlayers) or 0
		), 15, Theme.ACCENT)
		b:Text("Donne ce code à tes amis, ou invite-les : l'invitation les amène directement ici.", 12, Widgets.COLOR_DIM)
		local row = b:Row(38)
		local invite = ctx.Button(row, "INVITER DES AMIS", 0, half, function()
			ctx.Action("Session", { Action = "Invite" })
		end)
		Widgets.Primary(invite)
		ctx.Button(row, "QUITTER LA SESSION", half + 8, half, function()
			ctx.Action("Session", { Action = "Leave" })
		end)
		return
	end
	b:Text("Invite tes amis sur ce serveur, ou crée une session privée : un serveur rien que pour vous, qu'on rejoint avec son code.", 12, Widgets.COLOR_DIM)
	local row = b:Row(38)
	local invite = ctx.Button(row, "INVITER DES AMIS", 0, half, function()
		ctx.Action("Session", { Action = "Invite" })
	end)
	Widgets.Primary(invite)
	-- Créer une session : pass Premium (sinon, le bouton ouvre son achat).
	local canCreate = state ~= nil and state.CanCreate == true
	local create = ctx.Button(row, if canCreate then "SESSION PRIVÉE" else "SESSION PRIVÉE · PREMIUM", half + 8, half, function()
		if canCreate then
			ctx.Action("Session", { Action = "Create" })
		else
			ctx.Action("BuyPass", "premium")
		end
	end)
	if not canCreate then
		create.TextColor3 = Theme.ACCENT
		b:Text("Créer une session privée : réservé au Premium Sim Rallye. Rejoindre celle d'un ami avec son code est gratuit.", 12, Widgets.COLOR_DIM)
	end
	MenuKit.TextField(ctx, b, "Code d'un ami", "SessionCode", "ex. K7P2QX", CODE_LENGTH)
	local joinRow = b:Row(36)
	ctx.Button(joinRow, "REJOINDRE SA SESSION", 0, width, function()
		ctx.Action("Session", { Action = "Join", Code = ctx.View.SessionCode or "" })
	end)
	if state and state.Studio then
		b:Text("Dans Studio, les invitations et les sessions privées ne marchent pas : il faut le jeu publié.", 12, Widgets.COLOR_DIM)
	end
end

return SessionPage
