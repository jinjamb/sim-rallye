--!strict
--[[
	OptionsPage.luau
	L'onglet OPTIONS du menu principal : les réglages du joueur, par section
	(Shared/Settings/Options.luau), chacun en sélecteur ◀ valeur ▶. Un
	changement s'applique tout de suite et se sauvegarde dans le profil
	(client/Core/Settings.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Options = require(ReplicatedStorage.Shared.Settings.Options)
local MenuKit = require(script.Parent.MenuKit)
local Settings = require(script.Parent.Parent.Parent.Core.Settings)
local Widgets = require(script.Parent.Parent.Widgets)

local OptionsPage = {}

function OptionsPage.Options(ctx: MenuKit.Context, b: MenuKit.Builder)
	for _, section in ipairs(Options.SECTIONS) do
		b:Section(section)
		for _, option in ipairs(Options.LIST) do
			if option.Section == section then
				local choice = option.Choices[Settings.Index(option.Id)]
				MenuKit.Stepper(ctx, b, option.Name, if choice then choice.Label else "?", function(direction: number)
					Settings.Step(option.Id, direction)
					ctx.Rebuild()
				end)
				if option.Hint then
					b:Text(option.Hint, 12, Widgets.COLOR_DIM)
				end
			end
		end
	end

	b:Section("Par défaut")
	local row = b:Row(34)
	ctx.Button(row, "Rétablir les réglages par défaut", 0, MenuKit.CONTENT_WIDTH, function()
		Settings.Reset()
		ctx.Rebuild()
	end)
	b:Text("Les réglages sont gardés dans ton profil, d'une partie à l'autre.", 12, Widgets.COLOR_DIM)
end

return OptionsPage
