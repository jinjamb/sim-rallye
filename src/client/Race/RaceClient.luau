--!strict
--[[
	RaceClient.luau
	Le rallycross côté client : reçoit ce qu'envoie RaceService (courses
	ouvertes, état de sa course, classement en direct, événements, records) et
	le répartit entre le menu (RaceMenu), l'affichage de course (RaceHud) et la
	caméra spectateur (SpectatorCamera).

	Les décisions (tours, positions, arrivée) sont toutes prises par le serveur :
	ce module ne fait qu'afficher et transmettre les demandes du joueur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Medals = require(ReplicatedStorage.Shared.Constants.Medals)
local Progression = require(ReplicatedStorage.Shared.Constants.Progression)
local Livery = require(ReplicatedStorage.Shared.Constants.Livery)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Banner = require(script.Parent.Parent.Controllers.Banner)
local RaceUi = require(script.Parent.RaceUi)
local RaceMenu = require(script.Parent.RaceMenu)
local RaceHud = require(script.Parent.RaceHud)
local Minimap = require(script.Parent.Minimap)
local SpectatorCamera = require(script.Parent.SpectatorCamera)

local RaceClient = {}
RaceClient.__index = RaceClient

export type Options = {
	PlayerGui: Instance,
	Camera: Camera,
	LocalUserId: number,
	-- Voitures des autres joueurs visibles (même course), par UserId.
	GetOtherCars: () -> { [number]: BasePart },
	-- Le joueur quitte la vue spectateur : la caméra de poursuite reprend la main.
	OnSpectateStopped: () -> (),
}

export type RaceClient = typeof(setmetatable({}, RaceClient)) & {
	Options: Options,
	Menu: RaceMenu.RaceMenu,
	Hud: RaceHud.RaceHud,
	Spectator: SpectatorCamera.SpectatorCamera,
	Lobby: { RaceUi.LobbyRace },
	Race: RaceUi.RaceSnapshot?,
	Live: RaceUi.LivePayload?,
	Records: { [string]: RaceUi.TrackBoard },
	Stats: RaceUi.Stats?,
	Progress: Progression.Snapshot?,
	LapBests: { [string]: number },
	MyChassis: BasePart?,
	Livery: any,
	LiverySaveToken: number,
	-- Cérémonie du podium : caméra fixe sur le podium jusqu'à PodiumUntil.
	PodiumUntil: number,
	-- Course finie : le menu se rouvre (après le podium) pour enchaîner.
	ReopenMenuAt: number?,
	PodiumEye: Vector3,
	PodiumFocus: Vector3,
}

local LIVERY_SAVE_DELAY = 1 -- regroupe une rafale de clics en une seule sauvegarde
local REOPEN_MENU_DELAY = 3 -- après la fin d'une course, le temps de revenir au paddock

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function RaceClient.new(options: Options): RaceClient
	local self = (setmetatable({}, RaceClient) :: any) :: RaceClient
	self.Options = options
	self.Lobby = {}
	self.Race = nil
	self.Live = nil
	self.Records = {}
	self.Stats = nil
	self.Progress = nil
	self.LapBests = {}
	self.MyChassis = nil
	self.Livery = nil
	self.LiverySaveToken = 0
	self.PodiumUntil = 0
	self.ReopenMenuAt = nil
	self.PodiumEye = Vector3.zero
	self.PodiumFocus = Vector3.zero

	self.Menu = RaceMenu.new(options.PlayerGui, options.LocalUserId, function(action: string, payload: any)
		if action == "Livery" then
			self:SaveLivery(payload)
		elseif action == "Paddock" then
			Remotes.ReturnToPaddock:FireServer()
			self.Menu:SetOpen(false)
		elseif action == "Play" then
			-- Spéciale, essais libres, ou salle d'attente d'un circuit (PaddockService).
			if type(payload) == "table" then
				Remotes.PlayMode:FireServer(payload.Mode, payload.TrackId)
			end
			-- La salle d'attente s'affiche dans le menu : on le laisse ouvert.
			if type(payload) ~= "table" or payload.Mode ~= "Rallycross" then
				self.Menu:SetOpen(false)
			end
		else
			Remotes.RaceAction:FireServer(action, payload)
		end
	end)
	self.Hud = RaceHud.new(options.PlayerGui, options.LocalUserId, {
		Spectate = function()
			self:StartSpectating()
		end,
		SpectateNext = function(direction: number)
			self:SpectateNext(direction)
		end,
		StopSpectate = function()
			-- Fin de la vue choisie par le joueur : direction le paddock.
			self:StopSpectating()
			Remotes.ReturnToPaddock:FireServer()
		end,
	})
	self.Spectator = SpectatorCamera.new(options.Camera)

	Remotes.LobbyState.OnClientEvent:Connect(function(list: any)
		if type(list) == "table" then
			self.Lobby = list
			self:_refreshMenu()
		end
	end)
	Remotes.RaceState.OnClientEvent:Connect(function(snapshot: any)
		self:_setRace(if type(snapshot) == "table" then snapshot else nil)
	end)
	Remotes.RaceLive.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.Rows) == "table" then
			self.Live = payload
			self.Hud:SetLive(payload)
		end
	end)
	Remotes.RaceEvent.OnClientEvent:Connect(function(kind: any, data: any)
		self:_onEvent(kind, if type(data) == "table" then data else {})
	end)
	Remotes.TrackRecords.OnClientEvent:Connect(function(boards: any)
		if type(boards) == "table" then
			self.Records = boards
			self:_refreshMenu()
		end
	end)
	return self
end

function RaceClient:_refreshMenu()
	self.Menu:SetData({
		Lobby = self.Lobby,
		Race = self.Race,
		Records = self.Records,
		Stats = self.Stats,
		Progress = self.Progress,
		Laps = self.LapBests,
		Livery = self.Livery,
	})
end

-- Livrée choisie dans le menu : sauvegardée (et repeinte par le serveur) après
-- une courte pause, pour ne pas repeindre à chaque clic.
function RaceClient:SaveLivery(livery: any)
	local changed = self.Livery ~= livery
	self.Livery = livery
	if changed then
		self:_refreshMenu() -- le garage a pu la changer : le menu suit
	end
	self.LiverySaveToken += 1
	local token = self.LiverySaveToken
	task.delay(LIVERY_SAVE_DELAY, function()
		if token == self.LiverySaveToken then
			Remotes.SaveLivery:FireServer(livery)
		end
	end)
end

function RaceClient:GetLivery(): any
	return self.Livery
end

-- Livrée chargée avec le profil.
function RaceClient:SetLivery(livery: any)
	if type(livery) == "table" then
		self.Livery = livery
		self:_refreshMenu()
	end
end

function RaceClient:_setRace(snapshot: RaceUi.RaceSnapshot?)
	local previous = self.Race
	self.Race = snapshot
	-- Fin d'une course (pas d'une simple salle d'attente quittée) : le menu
	-- revient pour enchaîner.
	if snapshot == nil and previous ~= nil and previous.State ~= "Lobby" then
		self.ReopenMenuAt = os.clock() + REOPEN_MENU_DELAY
	end
	if not snapshot or snapshot.State == "Lobby" then
		self.Live = nil
		self:StopSpectating()
	end
	if snapshot and snapshot.State ~= "Racing" and self.Spectator.Active then
		self:StopSpectating()
	end
	-- La mise en grille ferme le menu : place à la course.
	if snapshot and snapshot.State == "Grid" and (previous == nil or previous.State ~= "Grid") then
		self.Menu:SetOpen(false)
	end
	self.Hud:SetRace(snapshot)
	self:_refreshMenu()
end

function RaceClient:_onEvent(kind: string, data: any)
	local hud = self.Hud
	local race = self.Race
	if kind == "Error" then
		local message = tostring(data.Message or "Action impossible.")
		self.Menu:SetStatus(message, RaceUi.COLOR_RED)
		hud:ShowMessage(message, RaceUi.COLOR_RED)
	elseif kind == "Go" then
		hud:ShowMessage("GO !", RaceUi.COLOR_GREEN, 1.2)
	elseif kind == "Lap" then
		local lap = tonumber(data.Lap) or 0
		local text = string.format("TOUR %d — %s", lap, RaceUi.FormatTime(tonumber(data.Time)))
		local color = RaceUi.COLOR_TEXT
		if data.Record then
			text ..= " — RECORD PERSO DU CIRCUIT !"
			color = RaceUi.COLOR_ACCENT
		elseif data.Best and lap > 1 then
			text ..= " — MEILLEUR TOUR"
			color = RaceUi.COLOR_GREEN
		end
		if race and lap == race.Laps - 1 then
			local myRow = self:_myRow()
			local jokerDue = myRow ~= nil and myRow.J == 0
			text = "DERNIER TOUR" .. (if jokerDue then " — JOKER À FAIRE !" else "") .. "  ·  " .. RaceUi.FormatTime(tonumber(data.Time))
			color = if jokerDue then RaceUi.COLOR_ORANGE else RaceUi.COLOR_TEXT
		end
		hud:ShowMessage(text, color, 3)
		-- Nouvelle médaille sur ce circuit (meilleur tour, Medals.luau).
		local tier = Medals.Get(tonumber(data.Medal) or 0)
		if tier then
			local circuit = if race then Tracks.Get(race.TrackId) else nil
			Banner.Show(
				tier.Title,
				string.format("%s — tour en %s", if circuit then circuit.Name else "Circuit", RaceUi.FormatTime(tonumber(data.Time))),
				tier.Color,
				4,
				true
			)
		end
	elseif kind == "Overtake" then
		local points = tonumber(data.Points) or 0
		hud:ShowMessage(
			"DÉPASSEMENT — " .. tostring(data.Name) .. (if points > 0 then "  +" .. Progression.Thousands(points) else ""),
			RaceUi.COLOR_GREEN,
			2
		)
	elseif kind == "Overtaken" then
		hud:ShowMessage("DÉPASSÉ PAR " .. tostring(data.Name), RaceUi.COLOR_ORANGE, 2)
	elseif kind == "Joker" then
		local count = tonumber(data.Count) or 1
		if count == 1 then
			hud:ShowMessage("JOKER ✓", RaceUi.COLOR_GREEN)
		else
			hud:ShowMessage("JOKER EN TROP : un seul suffit", RaceUi.COLOR_ORANGE)
		end
	elseif kind == "Penalty" then
		hud:ShowMessage(string.format("PÉNALITÉ +%s s — %s", tostring(data.Seconds), string.upper(tostring(data.Reason))), RaceUi.COLOR_RED, 3.5)
	elseif kind == "Chequered" then
		hud:ShowMessage("DRAPEAU À DAMIER — " .. tostring(data.Winner) .. " gagne", RaceUi.COLOR_TEXT, 3)
	elseif kind == "Finished" then
		local returnIn = tonumber(data.ReturnIn) or 6
		hud:ShowMessage(
			string.format("ARRIVÉE — P%d · retour au paddock dans %d s (V : regarder la course)", tonumber(data.Position) or 0, returnIn),
			RaceUi.COLOR_ACCENT,
			returnIn
		)
	elseif kind == "Results" then
		self:StopSpectating()
		hud:ShowResults(data :: any)
	elseif kind == "Podium" then
		local duration = tonumber(data.Duration) or 8
		if typeof(data.Eye) == "Vector3" and typeof(data.Focus) == "Vector3" then
			self.PodiumEye = data.Eye
			self.PodiumFocus = data.Focus
			self.PodiumUntil = os.clock() + duration
		end
		hud:ShowPodium(if type(data.Names) == "table" then data.Names else {}, duration)
		-- Place à la cérémonie ; le menu reviendra après.
		self.Menu:SetOpen(false)
		if self.ReopenMenuAt then
			self.ReopenMenuAt = os.clock()
		end
	end
end

function RaceClient:_myRow(): RaceUi.LiveRow?
	local live = self.Live
	if not live then
		return nil
	end
	for _, row in ipairs(live.Rows) do
		if row.U == self.Options.LocalUserId then
			return row
		end
	end
	return nil
end

-- Profil : statistiques de carrière et meilleurs tours (par Circuit.Key).
function RaceClient:SetProfile(stats: any, laps: any)
	if type(stats) == "table" then
		self.Stats = stats
	end
	if type(laps) == "table" then
		self.LapBests = laps
	end
	self:_refreshMenu()
end

--[[
	Progression (RecordService) : gardée pour le menu et le garage ; un niveau
	gagné ou un cosmétique débloqué est annoncé en grand.
]]
function RaceClient:SetProgress(snapshot: any, news: any)
	if type(snapshot) ~= "table" or type(snapshot.Level) ~= "number" then
		return
	end
	local previous = self.Progress
	self.Progress = snapshot
	self:_refreshMenu()
	if type(news) ~= "table" then
		return
	end
	if news.LevelUp then
		local licence = Progression.LICENCES[snapshot.Licence] or Progression.LICENCES[1]
		local newLicence = previous ~= nil and snapshot.Licence > previous.Licence
		local nextXp = snapshot.NextXp
		if newLicence then
			Banner.Show("LICENCE " .. licence.Short, "Niveau " .. snapshot.Level .. "  ·  bravo, pilote !", licence.Color, 5, true)
		else
			Banner.Show(
				"NIVEAU " .. snapshot.Level,
				"Licence " .. licence.Name .. (if nextXp then "  ·  prochain niveau à " .. Progression.Thousands(nextXp) .. " XP" else ""),
				licence.Color,
				4,
				true
			)
		end
	end
	if type(news.Unlocks) == "table" then
		for _, item in ipairs(news.Unlocks) do
			if type(item) == "table" then
				Banner.Show("DÉBLOQUÉ", Livery.ItemName(tostring(item.Kind), tonumber(item.Index) or 0) .. "  ·  au garage", RaceUi.COLOR_ACCENT, 3.5, true)
			end
		end
	end
end

function RaceClient:GetProgress(): Progression.Snapshot?
	return self.Progress
end

function RaceClient:SetTouchLayout(enabled: boolean)
	self.Menu:SetTouchLayout(enabled)
	self.Hud:SetTouchLayout(enabled)
end

function RaceClient:ToggleMenu()
	self.Menu:Toggle()
end

-- Menu principal ouvert (arrivée dans le jeu).
function RaceClient:OpenMenu()
	self.Menu:SetOpen(true)
end

-- Châssis de sa propre voiture (pour la mini-carte), nil sans voiture.
function RaceClient:SetMyChassis(chassis: BasePart?)
	self.MyChassis = chassis
end

--------------------------------------------------------------------------------
-- Spectateur
--------------------------------------------------------------------------------

-- Possible une fois arrivé, tant que d'autres roulent encore et qu'on est
-- encore sur le circuit (pas encore ramené au paddock).
function RaceClient:CanSpectate(): boolean
	local race = self.Race
	local me = self:_myRow()
	local mine = self.MyChassis
	return race ~= nil and race.State == "Racing" and me ~= nil and me.F
		and mine ~= nil and mine:IsDescendantOf(workspace)
end

function RaceClient:IsSpectating(): boolean
	return self.Spectator.Active
end

-- Pilotes à suivre : ceux encore en course d'abord, dans l'ordre du classement.
function RaceClient:_targets(): { { UserId: number, Name: string, Chassis: BasePart } }
	local cars = self.Options.GetOtherCars()
	local running, finished = {}, {}
	local live = self.Live
	if live then
		for _, row in ipairs(live.Rows) do
			local chassis = cars[row.U]
			if row.U ~= self.Options.LocalUserId and chassis and not row.D then
				table.insert(if row.F then finished else running, { UserId = row.U, Name = row.N, Chassis = chassis })
			end
		end
	end
	for _, entry in ipairs(finished) do
		table.insert(running, entry)
	end
	return running
end

function RaceClient:StartSpectating()
	if not self:CanSpectate() then
		return
	end
	local targets = self:_targets()
	local first = targets[1]
	if first then
		-- Le serveur ne nous ramène pas au paddock tant qu'on regarde.
		Remotes.RaceAction:FireServer("Watch", nil)
		self.Spectator:SetTarget(first.Chassis, first.Name, first.UserId)
	end
end

function RaceClient:SpectateNext(direction: number)
	if not self.Spectator.Active then
		self:StartSpectating()
		return
	end
	local targets = self:_targets()
	if #targets == 0 then
		return
	end
	local index = 1
	for i, entry in ipairs(targets) do
		if entry.UserId == self.Spectator.TargetUserId then
			index = ((i - 1 + direction) % #targets) + 1
		end
	end
	local target = targets[index]
	self.Spectator:SetTarget(target.Chassis, target.Name, target.UserId)
end

function RaceClient:StopSpectating()
	if self.Spectator.Active then
		self.Spectator:Stop()
		self.Options.OnSpectateStopped()
	end
end

-- Caméra : renvoie true si la vue spectateur l'a prise en charge.
function RaceClient:UpdateCamera(dt: number): boolean
	-- Cérémonie du podium : plan fixe, puis la caméra revient au joueur.
	if self.PodiumUntil > 0 then
		local camera = self.Options.Camera
		if os.clock() < self.PodiumUntil then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 60
			camera.CFrame = CFrame.lookAt(self.PodiumEye, self.PodiumFocus)
			return true
		end
		self.PodiumUntil = 0
		self.Options.OnSpectateStopped()
	end
	local spectator = self.Spectator
	if not spectator.Active then
		return false
	end
	local target = spectator.Target
	if not target or not target:IsDescendantOf(workspace) then
		-- Voiture disparue (pilote parti) : au suivant, ou fin de la vue.
		local targets = self:_targets()
		if targets[1] then
			spectator:SetTarget(targets[1].Chassis, targets[1].Name, targets[1].UserId)
		else
			self:StopSpectating()
			return false
		end
	end
	spectator:Update(dt)
	return true
end

--------------------------------------------------------------------------------
-- Mise à jour
--------------------------------------------------------------------------------

function RaceClient:Update(dt: number)
	self.Menu:Update()
	-- Retour d'une course : le menu revient, une fois le podium passé, si le
	-- joueur est à pied (il a pu repartir en spéciale entre-temps).
	local reopenAt = self.ReopenMenuAt
	if reopenAt and os.clock() >= reopenAt and self.PodiumUntil == 0 and self.Race == nil then
		self.ReopenMenuAt = nil
		if self.MyChassis == nil then
			self.Menu:SetOpen(true)
		end
	end
	local race = self.Race
	local cars: { Minimap.CarDot } = {}
	if race and race.State ~= "Lobby" then
		local mine = self.MyChassis
		if mine and mine:IsDescendantOf(workspace) then
			table.insert(cars, { Position = mine.Position, Me = true })
		end
		-- Seulement les pilotes de la course (revenu à pied au paddock après son
		-- arrivée, on voit aussi les voitures du paddock, qui n'ont rien à faire ici).
		local members: { [number]: boolean } = {}
		for _, member in ipairs(race.Members) do
			members[member.UserId] = true
		end
		for userId, chassis in pairs(self.Options.GetOtherCars()) do
			if members[userId] then
				table.insert(cars, { Position = chassis.Position, Me = false })
			end
		end
	end
	self.Hud:Update(dt, cars, serverNow())
	self.Hud:SetSpectate({
		Available = self:CanSpectate(),
		Active = self.Spectator.Active,
		Name = self.Spectator.TargetName,
	})
end

return RaceClient
