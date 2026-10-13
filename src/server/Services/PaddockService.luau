--!strict
--[[
	PaddockService.luau
	Le paddock : le lieu où l'on arrive, à pied, et d'où partent les courses.

	CONSTRUIT AU DÉMARRAGE DU SERVEUR (workspace.Paddock, recréé à chaque
	lancement) d'après PaddockLayout.luau :
		- point d'apparition ;
		- une ZONE par circuit, anneau lumineux au sol, et au-dessus un panneau :
		  nom et longueur du circuit, record du tour, temps des médailles
		  (Medals.luau), pilotes en attente, compte à rebours, pilotes en course ;
		- la zone VOITURE : sa voiture pour les essais libres et la spéciale ;
		- le podium, et ses confettis.

	ZONES : toutes les 0,25 s, on regarde où se trouve chaque joueur.
		- Entrer dans la zone d'un circuit = rejoindre sa salle d'attente
		  (RaceService.JoinPad). On peut y venir à pied ou en voiture.
		- Sortir de la zone = quitter la salle (tant que la course n'est pas partie).
		- Entrer à pied dans la zone VOITURE = recevoir sa voiture.
	MENU (C, ou bouton MENU sur mobile ; ouvert à l'arrivée) : le raccourci de
	tout ça, d'où qu'on soit :
		- Lancer une spéciale : la voiture est posée sur la ligne de départ ;
		- Défi de la semaine : pareil, avec la contrainte de la semaine
		  (Weekly.luau ; attributs Weekly et Modifier sur la voiture) ;
		- École de pilotage : la voiture au départ de la leçon (Lessons.luau ;
		  attribut Lesson) ;
		- Rallycross : rejoindre (ou ouvrir) la salle d'attente d'un circuit ;
		  on y reste sans avoir à se tenir dans la zone ;
		- Essais libres : la voiture à sa place au paddock.
	RETOUR : depuis les essais libres ou la spéciale, H (ou le menu C, ou le
	bouton PADDOCK sur mobile) ramène à pied au paddock, sans la voiture.
	L'entrée est détectée au FRANCHISSEMENT : quelqu'un qui quitte la salle par
	le menu sans bouger n'y est pas renvoyé aussitôt ; il ressort et revient.

	STYLE : dessin animé, comme le reste du décor (ToonDecor.luau) : panneaux
	crème cerclés d'encre, titres arrondis (FredokaOne) au trait, couleurs
	franches, trait d'encre autour des pièces (étiquette Ink).

	PODIUM : après la dernière manche, les trois premiers y sont posés, les
	confettis partent, et tous les pilotes de la course voient la cérémonie
	(caméra du podium, RaceClient.luau).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local PaddockLayout = require(ReplicatedStorage.Shared.Paddock.PaddockLayout)
local Tracks = require(ReplicatedStorage.Shared.Tracks.Tracks)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local Weather = require(ReplicatedStorage.Shared.Weather.Weather)
local FlashEvents = require(ReplicatedStorage.Shared.Events.FlashEvents)
local Weekly = require(ReplicatedStorage.Shared.Challenges.Weekly)
local Lessons = require(ReplicatedStorage.Shared.School.Lessons)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local Celebrations = require(ReplicatedStorage.Shared.Cosmetics.Celebrations)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local CarService = require(script.Parent.CarService)
local RaceService = require(script.Parent.RaceService)
local RecordService = require(script.Parent.RecordService)
local EconomyService = require(script.Parent.EconomyService)
local GarageService = require(script.Parent.GarageService)
local PaddockScenery = require(script.Parent.Parent.World.PaddockScenery)
local ToonDecor = require(ReplicatedStorage.Shared.World.ToonDecor)
local ToonMaterials = require(ReplicatedStorage.Shared.World.ToonMaterials)

-- Palette du paddock (style dessin animé).
local INK = Color3.fromRGB(32, 22, 48)
local CREAM = Color3.fromRGB(250, 244, 234)
local TEXT_DIM = Color3.fromRGB(86, 76, 110)
local TEXT_SOFT = Color3.fromRGB(130, 118, 150)
local GOLD = Color3.fromRGB(214, 150, 20)
local POST = Color3.fromRGB(70, 60, 90)

local PaddockService = {}

local POLL_INTERVAL = 0.25
local SIGN_INTERVAL = 0.5
local CAR_PAD_COOLDOWN = 3
local RETURN_COOLDOWN = 2
local PODIUM_DURATION = 9
local PLAY_COOLDOWN = 1.5 -- entre deux choix du menu (chaque choix recrée la voiture)

type Sign = {
	Status: TextLabel,
	Record: TextLabel,
}

local signs: { [string]: Sign } = {}
local confetti: { ParticleEmitter } = {}
local currentPad: { [Player]: string? } = {}
local lastCarAt: { [Player]: number } = {}

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute(ToonDecor.DONE_ATTRIBUTE, true)
	ToonDecor.Tag(p)
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, y: number, height: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 30, 0, y)
	l.Size = UDim2.new(1, -60, 0, height)
	-- Titres (FredokaOne) : lettres arrondies cernées d'encre, comme un titre d'anime.
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	if font == Enum.Font.FredokaOne then
		l.TextStrokeColor3 = INK
		l.TextStrokeTransparency = 0
	end
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- Panneau tourné vers +Z (vers le point d'apparition).
local function board(parent: Instance, position: Vector3, size: Vector2, color: Color3): (Part, Frame)
	local center = position + Vector3.new(0, size.Y / 2, 0)
	local panel = part(parent, "Board", Vector3.new(size.X, size.Y, 0.6), CFrame.lookAt(center, center + Vector3.new(0, 0, 1)), INK, true)
	-- Montants du sol jusqu'en haut du panneau.
	local groundY = PaddockLayout.SPAWN.Y
	local topY = position.Y + size.Y
	for _, side in ipairs({ -1, 1 }) do
		local postPosition = Vector3.new(position.X + side * (size.X / 2 - 0.5), (groundY + topY) / 2, position.Z - 0.6)
		part(parent, "Post", Vector3.new(0.8, topY - groundY, 0.8), CFrame.new(postPosition), POST, true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 50, size.Y * 50)
	gui.LightInfluence = 0
	gui.Parent = panel
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = CREAM
	frame.BorderSizePixel = 0
	frame.Parent = gui
	-- Cadre d'encre épais, bandeau de couleur penché en haut.
	local border = Instance.new("UIStroke")
	border.Color = INK
	border.Thickness = 14
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(1.1, 0, 0, 22)
	stripe.Position = UDim2.new(-0.05, 0, 0, 0)
	stripe.Rotation = -1
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	stripe.Parent = frame
	return panel, frame
end

-- Anneau lumineux au sol : la zone se voit de loin.
local function padRing(parent: Instance, pad: PaddockLayout.Pad)
	local base = pad.Position
	-- Disque au-dessus de l'anneau, l'anneau au-dessus de la dalle (dessus à 0.2) :
	-- trois hauteurs distinctes, sinon les surfaces scintillent.
	local disc = part(parent, "PadDisc", Vector3.new(0.2, pad.Radius * 2, pad.Radius * 2), CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), pad.Color:Lerp(CREAM, 0.72), false)
	disc.Shape = Enum.PartType.Cylinder
	local ring = part(parent, "PadRing", Vector3.new(0.2, pad.Radius * 2 + 1.5, pad.Radius * 2 + 1.5), CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), pad.Color, false)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	-- Halo vertical discret, visible de loin.
	local light = Instance.new("PointLight")
	light.Color = pad.Color
	light.Range = pad.Radius * 1.6
	light.Brightness = 1.2
	light.Parent = disc
end

local function buildPaddock()
	local existing = workspace:FindFirstChild("Paddock")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Paddock"

	-- Dalle (fine : aucune marche à franchir, à pied comme en voiture).
	local plaza = PaddockLayout.PLAZA_CENTER
	local size = PaddockLayout.PLAZA_SIZE
	local slab = part(folder, "Plaza", Vector3.new(size.X, 0.2, size.Y), CFrame.new(plaza + Vector3.new(0, 0.1, 0)), ToonMaterials.PartColor(Enum.Material.Asphalt, Color3.fromRGB(92, 86, 110)), true)
	slab.Material = Enum.Material.Asphalt -- texture toon d'asphalte (ToonMaterials), sinon celle de Roblox
	game:GetService("CollectionService"):RemoveTag(slab, ToonDecor.INK_TAG)

	-- Point d'apparition.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PaddockSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(14, 0.4, 14)
	spawnLocation.CFrame = CFrame.lookAt(PaddockLayout.SPAWN + Vector3.new(0, 0.3, 0), PaddockLayout.SPAWN + Vector3.new(0, 0.3, -1))
	spawnLocation.Color = Color3.fromRGB(255, 196, 220)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Parent = folder

	-- Arche d'accueil.
	local archPosition = PaddockLayout.SPAWN + Vector3.new(0, 0, -22)
	local _, archFrame = board(folder, archPosition + Vector3.new(0, 12, 0), Vector2.new(34, 5), Color3.fromRGB(255, 120, 170))
	label(archFrame, "PADDOCK RALLYCROSS", 34, 150, Enum.Font.FredokaOne, Color3.fromRGB(255, 205, 50))
	-- Piliers et linteau rouges, façon torii.
	local red = Color3.fromRGB(214, 40, 40)
	for _, side in ipairs({ -1, 1 }) do
		part(folder, "ArchPillar", Vector3.new(1.8, 18, 1.8), CFrame.new(archPosition + Vector3.new(side * 16.5, 9, -0.6)), red, true)
	end
	part(folder, "ArchBeam", Vector3.new(40, 1.4, 2.4), CFrame.new(archPosition + Vector3.new(0, 18.4, -0.6)), red, false)
	part(folder, "ArchBeamTop", Vector3.new(42, 0.6, 2.8), CFrame.new(archPosition + Vector3.new(0, 19.4, -0.6)), INK, false)

	-- Zones des circuits.
	for _, pad in ipairs(PaddockLayout.RACE_PADS) do
		padRing(folder, pad)
		local circuit = Tracks.Get(pad.Id)
		-- Rangée arrière : panneau plus haut, visible au-dessus de la rangée avant.
		local back = pad.Position.Z < PaddockLayout.SPAWN.Z - 60
		local _, frame = board(folder, pad.Position + Vector3.new(0, if back then 12 else 4, -pad.Radius - 4), Vector2.new(20, 11), pad.Color)
		label(frame, if circuit then string.upper(circuit.Name) else pad.Id, 34, 90, Enum.Font.FredokaOne, pad.Color)
		label(frame, if circuit then circuit.Description else "", 130, 50, Enum.Font.GothamMedium, TEXT_DIM)
		local record = label(frame, "Record du tour : -", 190, 52, Enum.Font.GothamBold, GOLD)
		if circuit then
			local medals = label(frame, "Médailles   " .. Medals.RichLine(Medals.ForCircuit(pad.Id, circuit.Length)), 246, 36, Enum.Font.GothamBold, TEXT_DIM)
			medals.RichText = true
		end
		local status = label(frame, "Entre dans la zone pour courir", 292, 140, Enum.Font.GothamBlack, INK)
		label(frame, "1 à 6 pilotes · départ 20 s après le 1er · C : menu", 450, 50, Enum.Font.GothamMedium, TEXT_SOFT)
		signs[pad.Id] = { Status = status, Record = record }
	end

	-- Zone voiture.
	local carPad = PaddockLayout.CAR_PAD
	padRing(folder, carPad)
	local _, carFrame = board(folder, carPad.Position + Vector3.new(0, 4, -carPad.Radius - 4), Vector2.new(16, 7), carPad.Color)
	label(carFrame, "TA VOITURE", 34, 90, Enum.Font.FredokaOne, carPad.Color)
	label(carFrame, "Essais libres sur la piste d'essai · spéciale : menu C", 140, 60, Enum.Font.GothamMedium, TEXT_DIM)
	label(carFrame, "Entre à pied dans la zone · E : monter · Q : descendre", 230, 60, Enum.Font.GothamMedium, TEXT_SOFT)

	-- Garage : zone, plaque tournante (la voiture y est posée par chaque client,
	-- à ses propres couleurs : Garage.luau) et panneau.
	local garagePad = PaddockLayout.GARAGE_PAD
	padRing(folder, garagePad)
	local showroom = PaddockLayout.SHOWROOM
	local turntable = part(folder, "Turntable", Vector3.new(0.6, PaddockLayout.SHOWROOM_RADIUS * 2, PaddockLayout.SHOWROOM_RADIUS * 2), CFrame.new(showroom + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(64, 54, 86), true)
	turntable.Shape = Enum.PartType.Cylinder
	local _, garageFrame = board(folder, showroom + Vector3.new(0, 4, -PaddockLayout.SHOWROOM_RADIUS - 4), Vector2.new(18, 8), garagePad.Color)
	label(garageFrame, "GARAGE", 34, 100, Enum.Font.FredokaOne, garagePad.Color)
	label(garageFrame, "Couleur, numéro de course, réglages de la voiture", 150, 60, Enum.Font.GothamMedium, TEXT_DIM)
	label(garageFrame, "Entre dans la zone violette", 250, 60, Enum.Font.GothamMedium, TEXT_SOFT)

	-- Podium.
	local podium = Instance.new("Folder")
	podium.Name = "Podium"
	podium.Parent = folder
	local stepColors = { Color3.fromRGB(255, 205, 50), Color3.fromRGB(200, 205, 230), Color3.fromRGB(230, 140, 80) }
	local stepSize = PaddockLayout.PODIUM_STEP_SIZE
	for index, step in ipairs(PaddockLayout.PODIUM_STEPS) do
		local position = PaddockLayout.PODIUM_CENTER + step.Offset + Vector3.new(0, step.Height / 2, 0)
		local block = part(podium, "Step" .. index, Vector3.new(stepSize.X, step.Height, stepSize.Y), CFrame.new(position), stepColors[index], true)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- face +Z, vers le public
		gui.CanvasSize = Vector2.new(200, 200 * step.Height / stepSize.X)
		gui.Parent = block
		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.Size = UDim2.fromScale(1, 1)
		number.Font = Enum.Font.FredokaOne
		number.TextScaled = true
		number.TextColor3 = INK
		number.Text = tostring(index)
		number.Parent = gui
	end
	local _, podiumFrame = board(podium, PaddockLayout.PODIUM_CENTER + Vector3.new(0, 0, -stepSize.Y / 2 - 2), Vector2.new(30, 9), Color3.fromRGB(255, 205, 50))
	label(podiumFrame, "PODIUM", 60, 200, Enum.Font.FredokaOne, Color3.fromRGB(255, 205, 50))

	-- Confettis, au-dessus des marches.
	for index, step in ipairs(PaddockLayout.PODIUM_STEPS) do
		local anchor = part(podium, "Confetti" .. index, Vector3.new(1, 1, 1), CFrame.new(PaddockLayout.PODIUM_CENTER + step.Offset + Vector3.new(0, 18, 0)), Color3.new(1, 1, 1), false)
		anchor.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Rate = 60
		emitter.Lifetime = NumberRange.new(2.5, 4)
		emitter.Speed = NumberRange.new(4, 10)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Drag = 1.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-200, 200)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 200, 55)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 65, 55)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 150, 255)),
		})
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Parent = anchor
		table.insert(confetti, emitter)
	end

	-- Décor : stands, tribunes, arbres, tentes... et la vue fermée sur l'accueil.
	PaddockScenery.Build(folder)

	folder.Parent = workspace
end

--------------------------------------------------------------------------------
-- Panneaux
--------------------------------------------------------------------------------

local recordText: { [string]: string } = {}

local function updateSigns()
	local now = workspace:GetServerTimeNow()
	for padId, sign in pairs(signs) do
		local status = RaceService.GetPadStatus(padId)
		local lines = {}
		if status.Waiting > 0 then
			local text = string.format("%d/%d pilotes", status.Waiting, status.Max)
			local startAt = status.AutoStartAt
			if startAt then
				text ..= string.format(" · départ dans %d s", math.max(0, math.ceil(startAt - now)))
			else
				text ..= " · en attente d'un 2e pilote"
			end
			table.insert(lines, text)
		else
			table.insert(lines, "Entre dans la zone pour courir")
		end
		if status.Racing > 0 then
			table.insert(lines, string.format("%d en course", status.Racing))
		end
		sign.Status.Text = table.concat(lines, "\n")
		sign.Record.Text = recordText[padId] or "Record du tour : -"
	end
end

-- Records du tour (RecordService les diffuse aussi aux clients), par
-- catégorie puis par circuit : le panneau montre ceux de la Rally2, la
-- catégorie de référence.
local function onTrackRecords(boards: any)
	local byTrack = if type(boards) == "table" then boards[CarClasses.DEFAULT] else nil
	if type(byTrack) ~= "table" then
		return
	end
	for padId, boardData in pairs(byTrack) do
		local entries = type(boardData) == "table" and boardData.Entries
		local best = type(entries) == "table" and entries[1]
		recordText[padId] = if best then string.format("Record du tour (Rally2) : %s · %s", Format.Ms(best.Ms), best.Name) else "Record du tour : -"
	end
end

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function pollZones()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		local pad = if root then PaddockLayout.PadAt(root.Position) else nil
		local padId = if pad then pad.Id else nil
		local previous = currentPad[player]
		currentPad[player] = padId

		if padId and padId ~= previous then
			if padId == PaddockLayout.CAR_PAD_ID then
				-- À pied seulement : y entrer en voiture ne la recrée pas.
				if not CarService.IsDriving(player) and not RaceService.IsRacing(player)
					and now - (lastCarAt[player] or -math.huge) > CAR_PAD_COOLDOWN then
					lastCarAt[player] = now
					task.spawn(CarService.GiveFreeCar, player)
				end
			else
				RaceService.JoinPad(player, padId)
			end
		end

		-- Sorti de la zone de sa salle d'attente : il la quitte.
		local lobbyPad = RaceService.GetLobbyPad(player)
		if lobbyPad and lobbyPad ~= padId then
			RaceService.LeavePad(player)
		end
	end
end

--------------------------------------------------------------------------------
-- Menu principal : lancer une spéciale, une course de rallycross, des essais
--------------------------------------------------------------------------------

local lastPlayAt: { [Player]: number } = {}

local function refuse(player: Player, message: string)
	Remotes.RaceEvent:FireClient(player, "Error", { Message = message })
end

-- `weather` : la météo choisie pour une spéciale (Weather.luau), sec sinon.
local function onPlayMode(player: Player, mode: any, trackId: any, weather: any)
	local now = os.clock()
	if now - (lastPlayAt[player] or -math.huge) < PLAY_COOLDOWN then
		return
	end
	if mode == "Rallycross" then
		if type(trackId) ~= "string" or not Tracks.Get(trackId) then
			return
		end
		if RaceService.GetLobbyTrack(player) == trackId then
			return -- déjà dans cette salle d'attente
		end
	elseif mode == "Lesson" then
		if type(trackId) ~= "string" or not Lessons.Get(trackId) then
			return
		end
	elseif mode == "Stage" or mode == "EventCar" then
		-- trackId : la spéciale choisie (Stages.luau) ; la spéciale par défaut sinon.
		if trackId ~= nil and not Stages.Exists(trackId) then
			return
		end
		-- La voiture rare de l'événement éclair : seulement pendant l'événement.
		if mode == "EventCar" and not FlashEvents.RareCar(os.time()) then
			refuse(player, "L'événement « Voiture rare » est terminé : rendez-vous au prochain !")
			return
		end
	elseif mode ~= "Practice" and mode ~= "Weekly" then
		return
	end
	local ok, reason = RaceService.ReleaseForMode(player)
	if not ok then
		refuse(player, reason or "Impossible pour l'instant.")
		return
	end
	lastPlayAt[player] = now

	if mode == "Stage" or mode == "EventCar" then
		local track = Stages.Get(if type(trackId) == "string" then trackId else nil)
		local forecast = Weather.New(weather, workspace:GetServerTimeNow())
		CarService.Spawn(player, track.StartFrame(), {
			Attributes = Weather.ToAttributes(forecast, { Stage = track.Id }),
			-- Événement éclair : la voiture rare, prêtée (CarService : Loaned).
			CarClass = if mode == "EventCar" then FlashEvents.RareCar(os.time()) else nil,
		})
	elseif mode == "Lesson" then
		local lesson = Lessons.Get(trackId) :: Lessons.Lesson
		-- Les leçons sont réglées pour la Rally2 : c'est elle qu'on prend.
		CarService.Spawn(player, Lessons.StartFrame(lesson), { Attributes = { Lesson = lesson.Id }, CarClass = "Rally2" })
	elseif mode == "Weekly" then
		local week = Weekly.Current()
		local track = Stages.Get(Stages.DEFAULT)
		-- Défi « pluie » : la météo pluie, pour tous les concurrents de la semaine.
		local forecast = Weather.New(if week.Modifier.Id == "Rain" then "Rain" else "Dry", workspace:GetServerTimeNow())
		CarService.Spawn(player, track.StartFrame(), {
			Attributes = Weather.ToAttributes(forecast, { Weekly = week.Key, Modifier = week.Modifier.Id, Stage = track.Id }),
			CarClass = week.CarClass, -- la voiture de la semaine, prêtée au besoin
		})
	elseif mode == "Practice" then
		CarService.GiveFreeCar(player)
	elseif RaceService.IsInRace(player) then
		-- Arrivé et revenu au paddock, mais sa course n'est pas finie pour les autres.
		refuse(player, "Ta course n'est pas encore terminée : patiente jusqu'aux résultats.")
	else
		-- La voiture actuelle (essais, spéciale) reste jusqu'à la mise en grille.
		RaceService.JoinPad(player, trackId, true)
	end
end

--------------------------------------------------------------------------------
-- Podium
--------------------------------------------------------------------------------

type PodiumRow = { UserId: number, Name: string, Position: number }

local podiumToken = 0

--[[
	La célébration portée par le pilote (Items/Celebrations.luau) au-dessus
	de sa marche ; les confettis (célébration de série) sont ceux du décor.
	Les fumigènes prennent la couleur de sa voiture.
]]
local function celebrate(player: Player, index: number, top: Vector3)
	local item = EconomyService.Equipped(player, "Celebration")
	local effect = if item and Celebrations.Exists(item.Effect) then item.Effect :: string else "Confetti"
	if effect == "Confetti" then
		local emitter = confetti[index]
		if emitter then
			emitter.Enabled = true
		end
		return
	end
	local color = if item and item.Color then item.Color else Livery.ColorOf(GarageService.GetLivery(player))
	Celebrations.Play(workspace, top, effect, color, PODIUM_DURATION)
end

function PaddockService.Podium(players: { Player }, rows: { PodiumRow })
	podiumToken += 1
	local token = podiumToken
	local names = {}
	for index, row in ipairs(rows) do
		local step = PaddockLayout.PODIUM_STEPS[index]
		local player = Players:GetPlayerByUserId(row.UserId)
		if step and player then
			local top = PaddockLayout.PODIUM_CENTER + step.Offset + Vector3.new(0, step.Height + 3, 0)
			CarService.PlaceCharacter(player, CFrame.lookAt(top, top + Vector3.new(0, 0, 1)))
			celebrate(player, index, top)
		end
		table.insert(names, row.Name)
	end
	for _, player in ipairs(players) do
		-- Avec le streaming, le paddock n'est pas chargé chez un pilote resté sur
		-- le circuit : on le fait charger avant de montrer la cérémonie.
		task.spawn(function()
			if workspace.StreamingEnabled then
				pcall(function()
					player:RequestStreamAroundAsync(PaddockLayout.PODIUM_CENTER, 4)
				end)
			end
			if player.Parent then
				Remotes.RaceEvent:FireClient(player, "Podium", {
					Names = names,
					Duration = PODIUM_DURATION,
					Eye = PaddockLayout.PODIUM_CAMERA_EYE,
					Focus = PaddockLayout.PODIUM_CAMERA_FOCUS,
				})
			end
		end)
	end
	task.delay(PODIUM_DURATION, function()
		if podiumToken == token then
			for _, emitter in ipairs(confetti) do
				emitter.Enabled = false
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Démarrage
--------------------------------------------------------------------------------

--[[
	Tout personnage qui apparaît loin du paddock y est ramené. Indispensable au
	premier joueur dans Studio : son personnage peut apparaître AVANT que le
	point d'apparition n'existe, et Roblox le pose alors au centre de la
	Baseplate. Sert aussi après un reset. Un pilote en course n'est pas déplacé :
	sa voiture vient le rechercher (CarService).
]]
local SPAWN_TOLERANCE = 40

local function bringToPaddock(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or RaceService.IsRacing(player) then
		return
	end
	task.wait() -- laisse Roblox finir de poser le personnage
	if (root.Position - PaddockLayout.SPAWN).Magnitude > SPAWN_TOLERANCE then
		local spread = PaddockLayout.SPAWN_SPREAD
		local position = PaddockLayout.SPAWN + Vector3.new((math.random() * 2 - 1) * spread, 4, (math.random() * 2 - 1) * spread)
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		bringToPaddock(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(bringToPaddock, player, character)
	end
end

function PaddockService.Start()
	buildPaddock()
	RecordService.TrackRecordsChanged = onTrackRecords

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- Retour au paddock demandé (touche H, menu, bouton tactile) : depuis les
	-- essais libres ou la spéciale. En course, on passe par "Abandonner".
	local lastReturnAt: { [Player]: number } = {}
	Remotes.ReturnToPaddock.OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastReturnAt[player] or -math.huge) < RETURN_COOLDOWN then
			return
		end
		local status = RaceService.PaddockRequest(player)
		if status == "blocked" then
			return
		end
		lastReturnAt[player] = now
		if status == "free" then
			CarService.ReturnToPaddock(player)
		end
	end)

	Remotes.PlayMode.OnServerEvent:Connect(onPlayMode)

	Players.PlayerRemoving:Connect(function(player: Player)
		currentPad[player] = nil
		lastCarAt[player] = nil
		lastReturnAt[player] = nil
		lastPlayAt[player] = nil
	end)

	local pollAccumulator, signAccumulator = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		pollAccumulator += dt
		signAccumulator += dt
		if pollAccumulator >= POLL_INTERVAL then
			pollAccumulator = 0
			pollZones()
		end
		if signAccumulator >= SIGN_INTERVAL then
			signAccumulator = 0
			updateSigns()
		end
	end)
end

return PaddockService
