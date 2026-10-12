--!strict
--[[
	ChampionshipService.luau
	Le mode championnat (Championships.luau) : des rallyes de plusieurs
	spéciales, au temps cumulé.

	DÉROULEMENT :
		- le joueur lance un rallye (menu) : sa voiture apparaît au départ de
		  la première spéciale, avec sa météo, et porte les attributs
		  Championship et ChampLeg ;
		- StageService chronomètre la spéciale comme toute autre ; à
		  l'arrivée d'une voiture de rallye, il prévient ce service
		  (StageFinished) : le temps est gardé, et la spéciale suivante est
		  lancée après la liaison (Championships.LIAISON_TIME) ;
		- un retour au départ ou un passage refusé pendant une spéciale
		  coûte une pénalité (Penalty), comme la reprise d'une spéciale
		  entamée puis quittée ;
		- à la dernière arrivée : temps total, record perso, classement du
		  rallye (par catégorie), crédits, XP et trophée.

	Le rallye en cours est gardé dans le profil : on peut le quitter (une
	spéciale, des essais, une course) et le reprendre plus tard, là où on
	l'avait laissé. Le rallye de la semaine expire avec la semaine.

	La catégorie de voiture est fixée au départ du rallye (celle choisie au
	garage) : le classement et le record sont ceux de cette catégorie.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Championships = require(ReplicatedStorage.Shared.Championship.Championships)
local Stages = require(ReplicatedStorage.Shared.Stage.Stages)
local Weather = require(ReplicatedStorage.Shared.Weather.Weather)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local Stores = require(script.Parent.Parent.Data.Stores)
local Boards = require(script.Parent.Parent.Data.Boards)
local CarService = require(script.Parent.CarService)
local RaceService = require(script.Parent.RaceService)
local EconomyService = require(script.Parent.EconomyService)
local ProgressService = require(script.Parent.ProgressService)
local AchievementService = require(script.Parent.AchievementService)
local AnnounceService = require(script.Parent.AnnounceService)

local ChampionshipService = {}

local BOARD_PREFIX = "RallyChamp_"
local BOARD_SIZE = 5
local BOARD_ROTATE = 40 -- secondes entre deux classements de rallye relus
local BOARD_FIRST_WAIT = 20
local ACTION_COOLDOWN = 2

type Run = ProfileSchema.ChampionshipRun

-- Classements : par rallye (sa clé) et par catégorie.
local sessionTotals: { [string]: { [number]: number } } = {}
local boards: { [string]: { Boards.Entry } } = {}
local lastActionAt: { [Player]: number } = {}

local function boardKey(key: string, classId: string): string
	return key .. "|" .. classId
end

-- Clé du record perso d'un rallye dans une catégorie (profil, ChampBests).
function ChampionshipService.BestKey(key: string, classId: string): string
	return boardKey(key, classId)
end

local function boardStore(key: string, classId: string): OrderedDataStore?
	return Stores.Ordered(BOARD_PREFIX .. key .. "_" .. classId)
end

local function sessionOf(key: string): { [number]: number }
	local entries = sessionTotals[key]
	if not entries then
		entries = {}
		sessionTotals[key] = entries
	end
	return entries
end

local function refreshBoard(key: string, classId: string)
	local id = boardKey(key, classId)
	boards[id] = Boards.Merge(boardStore(key, classId), sessionOf(id), BOARD_SIZE, "rallye")
end

local function totalOf(run: Run): number
	local total = run.Penalty
	for _, ms in ipairs(run.Times) do
		total += ms
	end
	return total
end

-- La catégorie de la voiture choisie au garage.
local function chosenClass(player: Player): string
	local item = EconomyService.Equipped(player, "Car")
	return CarClasses.Get(if item then item.CarClass else nil).Id
end

-- Ce que le menu affiche : le rallye en cours, et chaque rallye avec ses
-- spéciales, son record perso et son classement (dans la catégorie choisie).
local function sendState(player: Player, news: any?)
	local profile = ProfileStore.Get(player)
	if not profile or not player.Parent then
		return
	end
	local classId = chosenClass(player)
	local list = {}
	for _, championship in ipairs(Championships.List()) do
		local legs = {}
		for _, leg in ipairs(championship.Legs) do
			table.insert(legs, { Stage = leg.Stage, Name = Stages.Get(leg.Stage).Name, Weather = leg.Weather })
		end
		table.insert(list, {
			Id = championship.Id,
			Name = championship.Name,
			Description = championship.Description,
			Legs = legs,
			Credits = championship.Credits,
			Xp = championship.Xp,
			Weekly = championship.Weekly,
			Best = profile.ChampBests[ChampionshipService.BestKey(championship.Key, classId)],
			Board = boards[boardKey(championship.Key, classId)] or {},
		})
	end
	local current: any = nil
	local run = profile.Championship
	if run then
		local championship = Championships.Get(run.Id)
		current = {
			Id = run.Id,
			Name = if championship then championship.Name else run.Id,
			Index = run.Index,
			Count = if championship then #championship.Legs else run.Index,
			Times = run.Times,
			Penalty = run.Penalty,
			Total = totalOf(run),
			ClassId = run.ClassId,
			Expired = championship == nil or championship.Key ~= run.Key,
		}
	end
	Remotes.ChampionshipState:FireClient(player, { Current = current, List = list, ClassId = classId }, news)
end

local function saveRun(player: Player, run: Run?)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	profile.Championship = run
	local copy: Run? = if run
		then {
			Id = run.Id,
			Key = run.Key,
			ClassId = run.ClassId,
			Index = run.Index,
			Times = table.clone(run.Times),
			Penalty = run.Penalty,
			LegStarted = run.LegStarted,
		}
		else nil
	ProfileStore.Defer(player, "Championship", function(stored)
		stored.Championship = copy
	end)
end

-- La voiture du joueur roule-t-elle la spéciale en cours de son rallye ?
local function onCurrentLeg(player: Player, run: Run): boolean
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	return car ~= nil and car:GetAttribute("Championship") == run.Id and car:GetAttribute("ChampLeg") == run.Index
end

-- Lance la spéciale en cours du rallye (au départ, avec sa météo).
local function spawnLeg(player: Player, run: Run)
	local championship = Championships.Get(run.Id)
	if not championship or championship.Key ~= run.Key then
		saveRun(player, nil)
		sendState(player, { Message = "Ce rallye est terminé (nouvelle semaine) : lance celui de cette semaine.", Error = true })
		return
	end
	local leg = championship.Legs[run.Index]
	if not leg then
		return
	end
	local ok, reason = RaceService.ReleaseForMode(player)
	if not ok then
		sendState(player, { Message = reason or "Impossible pour l'instant.", Error = true })
		return
	end
	-- Reprendre une spéciale entamée puis quittée : comme un retour au départ.
	if run.LegStarted then
		run.Penalty += Championships.RESTART_PENALTY * 1000
		run.LegStarted = false
		saveRun(player, run)
	end
	local track = Stages.Get(leg.Stage)
	local forecast = Weather.New(leg.Weather, workspace:GetServerTimeNow())
	sendState(player, {
		Leg = { Index = run.Index, Count = #championship.Legs, Name = track.Name, Weather = leg.Weather, Rally = championship.Name },
	})
	CarService.Spawn(player, track.StartFrame(), {
		Attributes = Weather.ToAttributes(forecast, { Stage = track.Id, Championship = run.Id, ChampLeg = run.Index }),
		CarClass = run.ClassId,
	})
end

local function finishRally(player: Player, run: Run, championship: Championships.Championship)
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local total = totalOf(run)
	local key = ChampionshipService.BestKey(championship.Key, run.ClassId)
	local previous = profile.ChampBests[key]
	local isBest = previous == nil or total < previous
	if isBest then
		profile.ChampBests[key] = total
		ProfileStore.Defer(player, "champBest:" .. key, function(stored)
			local old = stored.ChampBests[key]
			if not old or total < old then
				stored.ChampBests[key] = total
			end
		end)
		-- Nouveau meilleur temps du rallye : annoncé à tout le serveur.
		local board = boards[boardKey(championship.Key, run.ClassId)]
		local first = if board then board[1] else nil
		if board and (first == nil or total < first.Ms) then
			AnnounceService.Send("Record", player.DisplayName, string.format(
				"remporte le %s en %s (%s) : nouveau record",
				championship.Name,
				Format.Ms(total),
				CarClasses.Get(run.ClassId).Name
			))
		end
		sessionOf(boardKey(championship.Key, run.ClassId))[player.UserId] = total
		Boards.SubmitLowest(boardStore(championship.Key, run.ClassId), player.UserId, total, "rallye")
		task.delay(2, refreshBoard, championship.Key, run.ClassId)
	end
	saveRun(player, nil)
	ProfileStore.AddCounter(player, "ChampionshipXp", championship.Xp)
	ProfileStore.AddCounter(player, "ChampionshipsDone", 1)
	ProgressService.Push(player, true)
	EconomyService.Earn(player, championship.Credits, championship.Name .. " terminé")
	AchievementService.Award(player, "first_rally")
	sendState(player, {
		Finished = {
			Rally = championship.Name,
			Total = total,
			Penalty = run.Penalty,
			Best = isBest,
			Previous = previous,
		},
	})
end

--[[
	Arrivée d'une spéciale chronométrée (StageService) par une voiture de
	rallye : le temps compte s'il s'agit bien de la spéciale en cours.
]]
function ChampionshipService.StageFinished(player: Player, stageId: string, ms: number)
	local profile = ProfileStore.Get(player)
	local run = if profile then profile.Championship else nil
	if not run or not onCurrentLeg(player, run) then
		return
	end
	local championship = Championships.Get(run.Id)
	local leg = if championship then championship.Legs[run.Index] else nil
	if not championship or not leg or leg.Stage ~= stageId or championship.Key ~= run.Key then
		return
	end
	table.insert(run.Times, ms)
	run.Index += 1
	run.LegStarted = false
	saveRun(player, run)
	if run.Index > #championship.Legs then
		finishRally(player, run, championship)
		return
	end
	local nextLeg = championship.Legs[run.Index]
	sendState(player, {
		LegDone = {
			Index = run.Index - 1,
			Count = #championship.Legs,
			Ms = ms,
			Total = totalOf(run),
			Next = Stages.Get(nextLeg.Stage).Name,
			Liaison = Championships.LIAISON_TIME,
		},
	})
	-- La liaison : la spéciale suivante, sauf si le joueur est parti ailleurs.
	local index = run.Index
	task.delay(Championships.LIAISON_TIME, function()
		local current = ProfileStore.Get(player)
		local live = if current then current.Championship else nil
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		if live and live.Id == run.Id and live.Index == index and car and car:GetAttribute("Championship") == run.Id then
			spawnLeg(player, live)
		end
	end)
end

-- Départ d'une spéciale chronométrée (StageService) : la spéciale est entamée.
function ChampionshipService.LegStarted(player: Player)
	local profile = ProfileStore.Get(player)
	local run = if profile then profile.Championship else nil
	if run and onCurrentLeg(player, run) and not run.LegStarted then
		run.LegStarted = true
		saveRun(player, run)
	end
end

-- Retour au départ ou passage refusé pendant la spéciale en cours : pénalité.
function ChampionshipService.Penalty(player: Player, reason: string)
	local profile = ProfileStore.Get(player)
	local run = if profile then profile.Championship else nil
	if not run or not onCurrentLeg(player, run) then
		return
	end
	run.Penalty += Championships.RESTART_PENALTY * 1000
	run.LegStarted = false
	saveRun(player, run)
	sendState(player, { Penalty = { Seconds = Championships.RESTART_PENALTY, Reason = reason } })
end

local function onAction(player: Player, action: any, payload: any)
	local now = os.clock()
	if now - (lastActionAt[player] or -math.huge) < ACTION_COOLDOWN then
		return
	end
	lastActionAt[player] = now
	local profile = ProfileStore.Get(player)
	if not profile then
		return
	end
	local run = profile.Championship
	if action == "Start" then
		local championship = Championships.Get(if type(payload) == "table" then payload.Id else nil)
		if not championship then
			return
		end
		if run and run.Id == championship.Id and run.Key == championship.Key then
			spawnLeg(player, run) -- déjà en cours : on reprend
			return
		end
		if run then
			sendState(player, { Message = "Un rallye est déjà en cours : reprends-le ou abandonne-le d'abord.", Error = true })
			return
		end
		local fresh: Run = {
			Id = championship.Id,
			Key = championship.Key,
			ClassId = chosenClass(player),
			Index = 1,
			Times = {},
			Penalty = 0,
			LegStarted = false,
		}
		saveRun(player, fresh)
		spawnLeg(player, fresh)
	elseif action == "Continue" then
		if run then
			spawnLeg(player, run)
		end
	elseif action == "Abandon" then
		if run then
			saveRun(player, nil)
			sendState(player, { Message = "Rallye abandonné." })
		end
	elseif action == "State" then
		sendState(player)
	end
end

function ChampionshipService.Start()
	ProfileStore.OnLoaded(function(player)
		sendState(player)
	end)
	Remotes.ChampionshipAction.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
	end)
	-- Classements : un à la fois, à tour de rôle (rallye x catégorie) ; la
	-- liste est refaite à chaque tour (le rallye de la semaine change).
	task.spawn(function()
		local index = 0
		local firstPass = true
		while true do
			local list = {}
			for _, championship in ipairs(Championships.List()) do
				for _, class in ipairs(CarClasses.LIST) do
					table.insert(list, { Key = championship.Key, Class = class.Id })
				end
			end
			index = index % #list + 1
			refreshBoard(list[index].Key, list[index].Class)
			if index == #list then
				firstPass = false
				-- Tous relus : chacun reçoit les classements à jour.
				for _, player in ipairs(Players:GetPlayers()) do
					sendState(player)
				end
			end
			task.wait(if firstPass then BOARD_FIRST_WAIT else BOARD_ROTATE)
		end
	end)
end

return ChampionshipService
