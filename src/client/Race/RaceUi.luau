--!strict
--[[
	RaceUi.luau
	Ce que partagent les écrans du rallycross (menu, HUD, résultats) : formes des
	données envoyées par RaceService, couleurs, et petits constructeurs
	d'interface au style du jeu (Theme.luau : panneaux noirs à angles vifs et
	liseré jaune, chiffres à chasse fixe).
]]

local Theme = require(script.Parent.Parent.UI.Theme)

local RaceUi = {}

-- Données envoyées par le serveur (RaceService.luau) -------------------------------

export type LobbyRace = {
	Id: string,
	TrackId: string,
	Laps: number,
	Format: string, -- "Sprint" | "Event"
	Contacts: boolean,
	Host: string,
	Count: number,
	Max: number,
	State: string,
}

export type RaceMember = { UserId: number, Name: string }

export type RaceSnapshot = {
	Id: string,
	PadId: string,
	TrackId: string,
	Laps: number,
	Format: string,
	Contacts: boolean,
	HostUserId: number,
	State: string, -- "Lobby" | "Grid" | "Countdown" | "Racing" | "Results"
	Round: number,
	RoundCount: number,
	RoundName: string,
	Members: { RaceMember },
	MinPlayers: number,
	MaxPlayers: number,
	AutoStartAt: number?,
	LightsStart: number?,
	LightCount: number,
	LightInterval: number,
	StartTime: number?,
}

export type LiveRow = {
	U: number, -- UserId
	N: string, -- nom
	P: number, -- position
	L: number, -- tours bouclés
	G: number?, -- écart au leader (s)
	LD: number, -- tours de retard
	J: number, -- jokers pris
	F: boolean, -- arrivé
	D: boolean, -- abandon
	B: number?, -- meilleur tour
	LL: number?, -- dernier tour
	LS: number, -- heure serveur du début du tour en cours
	PEN: number, -- pénalités (s)
	T: number?, -- temps total à l'arrivée
}

export type LivePayload = { Id: string, Rows: { LiveRow }, Time: number }

export type ResultRow = {
	UserId: number,
	Name: string,
	Position: number,
	TotalTime: number?,
	Penalty: number,
	BestLap: number?,
	Dnf: boolean,
	DnfReason: string?,
	Points: number,
}

export type Results = {
	Round: number,
	RoundName: string,
	Final: boolean,
	NextRoundName: string?,
	NextAt: number,
	TrackId: string,
	Rows: { ResultRow },
}

export type BoardEntry = { UserId: number, Name: string, Ms: number }
export type TrackBoard = { Key: string, Entries: { BoardEntry } }
export type Stats = { Races: number, Wins: number, Podiums: number, Points: number }

-- Style ---------------------------------------------------------------------------

RaceUi.COLOR_PANEL = Theme.PANEL
RaceUi.COLOR_BUTTON = Theme.PANEL_2
RaceUi.COLOR_TEXT = Theme.TEXT
RaceUi.COLOR_DIM = Theme.DIM
RaceUi.COLOR_ACCENT = Theme.ACCENT
RaceUi.COLOR_GREEN = Theme.GREEN
RaceUi.COLOR_RED = Theme.RED
RaceUi.COLOR_ORANGE = Theme.ORANGE
RaceUi.COLOR_BLUE = Theme.BLUE

function RaceUi.FormatTime(seconds: number?): string
	if seconds == nil then
		return "--:--.--"
	end
	local s = math.max(0, seconds :: number)
	local minutes = math.floor(s / 60)
	return string.format("%d:%05.2f", minutes, s - minutes * 60)
end

-- Angles presque vifs (Theme) ; un rond (rayon égal à la taille) reste un rond.
function RaceUi.Corner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, if radius >= 20 then radius else Theme.CORNER)
	corner.Parent = parent
end

-- Panneau du jeu : noir, angles vifs, léger dégradé, liseré jaune à gauche.
function RaceUi.Panel(parent: Instance, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = RaceUi.COLOR_PANEL
	frame.BackgroundTransparency = transparency or 0.12
	frame.BorderSizePixel = 0
	Theme.Corner(frame)
	Theme.Shade(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.LINE
	stroke.Transparency = 0.9
	stroke.Parent = frame
	Theme.AccentBar(frame)
	frame.Parent = parent
	return frame
end

function RaceUi.Label(parent: Instance, text: string, textSize: number, font: Enum.Font?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.Font = font or Enum.Font.GothamMedium
	label.TextColor3 = color or RaceUi.COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function RaceUi.Button(parent: Instance, text: string, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = RaceUi.COLOR_TEXT
	button.BackgroundColor3 = RaceUi.COLOR_BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Selectable = true -- navigation à la manette
	Theme.Corner(button)
	-- Sélection à la manette ou survol : cadre jaune.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.ACCENT
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = button
	button.SelectionGained:Connect(function()
		stroke.Enabled = true
	end)
	button.SelectionLost:Connect(function()
		stroke.Enabled = false
	end)
	button.MouseEnter:Connect(function()
		stroke.Enabled = true
	end)
	button.MouseLeave:Connect(function()
		stroke.Enabled = false
	end)
	button.Activated:Connect(callback)
	button.Parent = parent
	return button
end

-- Action principale (lancer, rejoindre) : jaune, texte noir.
RaceUi.Primary = Theme.Primary
RaceUi.Danger = Theme.Danger

return RaceUi
