--!strict
--[[
	Tutorial.luau
	Le tutoriel express, côté client (règles : TutorialService) : un nouveau
	pilote est mis au volant dès son arrivée, sur la spéciale par défaut, et
	un panneau en haut de l'écran le guide en quatre étapes :

		1. ACCÉLÈRE        (gaz tenus un instant)
		2. TOURNE          (volant d'un côté puis de l'autre)
		3. FREIN À MAIN    (un coup suffit)
		4. CAP SUR L'ARRIVÉE : suivre le copilote jusqu'à la ligne ; le
		   serveur valide l'arrivée et boucle le tutoriel.

	Les commandes affichées suivent l'appareil : clavier (dans la disposition
	du joueur), manette ou écran tactile. Descendu de voiture ou revenu au
	paddock : le panneau propose de reprendre la spéciale. PASSER arrête
	tout (le serveur ne le propose plus).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local InputManager = require(script.Parent.Parent.Core.InputManager)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Banner = require(script.Parent.Parent.UI.Banner)

local Tutorial = {}
Tutorial.__index = Tutorial

export type Options = {
	PlayerGui: Instance,
	IsTouch: boolean,
	-- Au volant de sa voiture (contrôle accordé) ?
	IsDriving: () -> boolean,
	-- Le tutoriel est fini, ou passé : la suite (le menu principal).
	OnFinished: () -> (),
}

export type Tutorial = typeof(setmetatable({}, Tutorial)) & {
	Options: Options,
	Active: boolean,
	StageId: string?,
	Step: number,
	Progress: number, -- avancée de l'étape en cours (0 à 1)
	TurnedLeft: boolean,
	TurnedRight: boolean,
	Gui: ScreenGui,
	Panel: Frame,
	StepTag: TextLabel,
	Title: TextLabel,
	Body: TextLabel,
	Bar: Frame,
	Resume: TextButton,
	Shown: string, -- texte affiché, pour ne le changer qu'au besoin
	LaunchedAt: number, -- os.clock du dernier lancement de la spéciale
}

local STEP_COUNT = 4
local THROTTLE_TIME = 1.2 -- secondes de gaz pour valider l'étape 1
local STEER_TIME = 0.5 -- secondes de chaque côté pour l'étape 2
local WIDTH = 460
local ARRIVAL_TIME = 8 -- secondes laissées à la voiture pour arriver après un lancement

-- Libellé d'une touche du clavier, dans la disposition du joueur (Z sur AZERTY).
local function key(code: Enum.KeyCode): string
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(code)
	end)
	return if ok and type(text) == "string" and text ~= "" then string.upper(text) else code.Name
end

-- "clavier", "manette" ou "tactile" : ce que le joueur a sous la main.
local function device(isTouch: boolean): string
	local source = InputManager:GetActiveSource()
	if source == "manette" or source == "tactile" then
		return source
	end
	return if isTouch then "tactile" else "clavier"
end

-- Titre et consigne de l'étape `step`, pour l'appareil.
local function stepText(step: number, kind: string): (string, string)
	local K = Enum.KeyCode
	if step == 1 then
		return "Accélère",
			if kind == "tactile" then "Pose le pouce sur la pédale de droite (GAZ) et garde-le appuyé."
			elseif kind == "manette" then "Appuie sur la gâchette droite (RT) et garde-la enfoncée."
			else string.format("Garde la touche <b>%s</b> (ou ↑) enfoncée.", key(K.W))
	elseif step == 2 then
		return "Tourne",
			if kind == "tactile" then "Pouce gauche posé n'importe où à gauche de l'écran, puis glisse vers la gauche et vers la droite."
			elseif kind == "manette" then "Braque avec le stick gauche : un coup à gauche, un coup à droite."
			else string.format("Braque avec <b>%s</b> et <b>%s</b> (ou ← →) : un coup de chaque côté.", key(K.A), key(K.D))
	elseif step == 3 then
		return "Frein à main",
			if kind == "tactile" then "Touche le bouton FREIN À MAIN, à côté des pédales : il fait pivoter la voiture dans les épingles."
			elseif kind == "manette" then "Appuie sur <b>A</b> : le frein à main fait pivoter la voiture dans les épingles."
			else "Appuie sur <b>ESPACE</b> : le frein à main fait pivoter la voiture dans les épingles."
	end
	local recover = if kind == "tactile" then "le bouton de remise en piste" elseif kind == "manette" then "◀ de la croix" else "<b>" .. key(K.T) .. "</b>"
	return "Cap sur l'arrivée",
		"Le copilote annonce chaque virage : 1 = très serré, 6 = très rapide. Passe la ligne d'arrivée ! Sorti de la route ? À l'arrêt, "
			.. recover
			.. " te remet en piste."
end

function Tutorial.new(options: Options): Tutorial
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.IgnoreGuiInset = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	-- Sur téléphone, sous la rangée d'actions du haut ; ailleurs, en haut au centre.
	panel.Position = if options.IsTouch then UDim2.new(0.5, 0, 0, 64) else UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.new(0, WIDTH, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.PANEL
	panel.Parent = gui
	Theme.Card(panel, 0.08)
	Theme.AccentBar(panel, Theme.CYAN)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(WIDTH, math.huge)
	sizeLimit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	-- Ligne du haut : l'étape, et PASSER.
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, 24)
	top.LayoutOrder = 1
	top.Parent = panel
	local stepTag = Widgets.Label(top, "", 13, nil, Theme.CYAN)
	stepTag.FontFace = Theme.HEADLINE_MEDIUM
	stepTag.Size = UDim2.new(1, -90, 1, 0)
	local self: Tutorial
	local skip = Widgets.Button(top, "PASSER", function()
		self:_skip()
	end)
	skip.TextSize = 12
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.fromScale(1, 0)
	skip.Size = UDim2.new(0, 80, 1, 0)

	local title = Widgets.Label(panel, "", 24, nil, Theme.TEXT)
	title.FontFace = Theme.HEADLINE
	title.Size = UDim2.new(1, 0, 0, 28)
	title.LayoutOrder = 2

	local body = Widgets.Label(panel, "", 15, nil, Theme.TEXT)
	body.FontFace = Theme.BODY
	body.RichText = true
	body.TextWrapped = true
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 3

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.PANEL_2
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 6)
	track.LayoutOrder = 4
	track.Parent = panel
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Theme.CYAN
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0, 1)
	bar.Parent = track

	-- Hors de la voiture : reprendre la spéciale du tutoriel.
	local resume = Widgets.Button(panel, "REPRENDRE LA SPÉCIALE", function()
		self:_launch()
	end)
	Theme.Primary(resume)
	resume.Size = UDim2.new(1, 0, 0, 40)
	resume.LayoutOrder = 5
	resume.Visible = false

	gui.Parent = options.PlayerGui
	Theme.Skin(gui)

	self = (setmetatable({
		Options = options,
		Active = false,
		StageId = nil,
		Step = 1,
		Progress = 0,
		TurnedLeft = false,
		TurnedRight = false,
		Gui = gui,
		Panel = panel,
		StepTag = stepTag,
		Title = title,
		Body = body,
		Bar = bar,
		Resume = resume,
		Shown = "",
		LaunchedAt = -math.huge,
	}, Tutorial) :: any) :: Tutorial
	return self
end

function Tutorial.IsActive(self: Tutorial): boolean
	return self.Active
end

-- Lance (ou relance) la spéciale du tutoriel, au sec.
function Tutorial._launch(self: Tutorial)
	self.LaunchedAt = os.clock()
	Remotes.PlayMode:FireServer("Stage", self.StageId, "Dry")
end

function Tutorial._finish(self: Tutorial)
	if not self.Active then
		return
	end
	self.Active = false
	self.Gui.Enabled = false
	self.Options.OnFinished()
end

function Tutorial._skip(self: Tutorial)
	Remotes.TutorialAction:FireServer("Skip")
	self:_finish()
end

--[[
	État envoyé par le serveur. `startNow` : à l'arrivée dans le jeu, le
	tutoriel actif part tout de suite (voiture sur la ligne de départ).
	Renvoie vrai si le tutoriel est en cours.
]]
function Tutorial.SetState(self: Tutorial, state: any, news: any, startNow: boolean): boolean
	if type(state) ~= "table" then
		return self.Active
	end
	if type(news) == "table" and news.Completed then
		local rolls = tonumber(news.Rolls) or 0
		Banner.Show(
			"Tutoriel réussi !",
			string.format(
				"+%d CR%s · Choisis maintenant ta suite : autres spéciales, rallycross, championnat...",
				tonumber(news.Credits) or 0,
				if rolls > 0 then string.format(" et %d tirage%s", rolls, if rolls > 1 then "s" else "") else ""
			),
			Theme.GREEN,
			5,
			true
		)
		-- Le temps de savourer l'arrivée, puis le menu.
		self.Gui.Enabled = false
		task.delay(5, function()
			self:_finish()
		end)
		return false
	end
	if state.Active ~= true then
		if self.Active then
			self:_finish()
		end
		return false
	end
	self.StageId = if type(state.StageId) == "string" then state.StageId else nil
	if not self.Active and startNow then
		self.Active = true
		self.Step = 1
		self.Progress = 0
		self.TurnedLeft, self.TurnedRight = false, false
		self.Gui.Enabled = true
		Banner.Show("Bienvenue dans Sim Rallye !", "Ta voiture t'attend sur la ligne de départ : on y va.", Theme.CYAN, 3.5)
		self:_launch()
	end
	return self.Active
end

-- Une fois par image : avance des étapes, et le panneau.
function Tutorial.Update(self: Tutorial, dt: number)
	if not self.Active or not self.Gui.Enabled then
		return
	end
	local driving = self.Options.IsDriving()
	if driving and self.Step < STEP_COUNT then
		local inputs = InputManager:GetInputs()
		if self.Step == 1 then
			if inputs.throttle > 0.3 then
				self.Progress = math.min(1, self.Progress + dt / THROTTLE_TIME)
			end
		elseif self.Step == 2 then
			if inputs.steer > 0.4 then
				self.TurnedLeft = true
			elseif inputs.steer < -0.4 then
				self.TurnedRight = true
			end
			self.Progress = (if self.TurnedLeft then 0.5 else 0) + (if self.TurnedRight then 0.5 else 0)
		elseif self.Step == 3 then
			if inputs.handbrake then
				self.Progress = 1
			end
		end
		if self.Progress >= 1 then
			self.Step += 1
			self.Progress = 0
		end
	end

	local kind = device(self.Options.IsTouch)
	local title, body = stepText(self.Step, kind)
	local arriving = not driving and os.clock() - self.LaunchedAt < ARRIVAL_TIME
	if arriving then
		title, body = "En route", "Ta voiture arrive sur la ligne de départ…"
	elseif not driving then
		title, body = "Ta voiture t'attend", "Reprends la spéciale pour finir le tutoriel et gagner ta récompense."
	end
	local shown = title .. "|" .. body .. "|" .. tostring(driving) .. "|" .. tostring(arriving)
	if shown ~= self.Shown then
		self.Shown = shown
		self.StepTag.Text = string.format("TUTORIEL · ÉTAPE %d/%d", self.Step, STEP_COUNT)
		self.Title.Text = string.upper(title)
		self.Body.Text = body
		self.Resume.Visible = not driving and not arriving
		Theme.Pop(self.Panel)
	end
	local fill = if self.Step >= STEP_COUNT then 1 else self.Progress
	self.Bar.Size = UDim2.fromScale(fill, 1)
end

function Tutorial.Destroy(self: Tutorial)
	self.Gui:Destroy()
end

return Tutorial
