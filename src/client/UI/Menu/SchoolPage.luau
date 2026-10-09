--!strict
--[[
	SchoolPage.luau
	Rubrique de l'école de pilotage : une ligne par leçon, sa médaille, le
	bouton (en tête du menu pour un débutant : MainMenu.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lessons = require(ReplicatedStorage.Shared.School.Lessons)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Theme = require(script.Parent.Parent.Theme)
local MenuKit = require(script.Parent.MenuKit)
local Widgets = require(script.Parent.Parent.Widgets)

type Context = MenuKit.Context
type Builder = MenuKit.Builder

local SchoolPage = {}

-- École de pilotage : une ligne par leçon, sa médaille, le bouton.
function SchoolPage.School(ctx: Context, b: Builder)
	local width = MenuKit.CONTENT_WIDTH
	local progress = ctx.Data.Progress
	local bests: { [string]: number } = if progress and progress.Lessons then progress.Lessons else {}
	b:Section("École de pilotage")
	b:Text("Quatre leçons courtes sur la spéciale, notées de bronze à platine. Le meilleur moyen de progresser (et de l'XP).", 13, Widgets.COLOR_DIM)
	for _, lesson in ipairs(Lessons.LIST) do
		local row = b:Row(40)
		local name = Widgets.Label(row, string.upper(lesson.Name), 16, Enum.Font.GothamBlack)
		name.Position = UDim2.fromOffset(0, 0)
		name.Size = UDim2.new(1, -150, 0, 20)
		local goal = Widgets.Label(row, lesson.Goal, 12, Enum.Font.GothamMedium, Widgets.COLOR_DIM)
		goal.Position = UDim2.fromOffset(0, 21)
		goal.Size = UDim2.new(1, -150, 0, 16)
		goal.TextTruncate = Enum.TextTruncate.AtEnd
		local tier = bests[lesson.Id] or 0
		local medal = Medals.Get(tier)
		if medal then
			local tag = Theme.Tag(row, medal.Short, medal.Color, Theme.ON_ACCENT, 12)
			tag.AnchorPoint = Vector2.new(1, 0)
			tag.Position = UDim2.new(1, -112, 0, 9)
		end
		local button = ctx.Button(row, if tier > 0 then "REFAIRE" else "LEÇON", width - 104, 104, function()
			ctx.Action("Play", { Mode = "Lesson", TrackId = lesson.Id })
		end)
		if tier == 0 then
			Widgets.Primary(button)
		end
	end
end

return SchoolPage
