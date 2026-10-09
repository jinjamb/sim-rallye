--!strict
--[[
	Main.server.luau
	Démarrage du serveur. Les services sont des modules (Services/) pour pouvoir
	s'appeler entre eux : RaceService recrée les voitures sur la grille
	(CarService) et enregistre les tours (RecordService) ; PaddockService fait
	entrer les joueurs dans les courses par ses zones.
	Ordre : le paddock d'abord (le point d'apparition doit exister avant que le
	premier personnage n'apparaisse ; PaddockService ramène de toute façon au
	paddock un personnage apparu ailleurs), puis les voitures (gabarit, groupe
	de collision), les profils, les courses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crée les RemoteEvents avant que le premier joueur ne les attende.
require(ReplicatedStorage.Shared.Network.Remotes)

local Services = script.Parent.Services
local CarService = require(Services.CarService)
local RecordService = require(Services.RecordService)
local RaceService = require(Services.RaceService)
local PaddockService = require(Services.PaddockService)

-- Liens entre services (sans dépendance circulaire entre modules).
RecordService.LiveryChanged = CarService.RefreshLivery
RecordService.ProgressChanged = CarService.RefreshProgress
RaceService.PodiumHandler = PaddockService.Podium :: any

PaddockService.Start()
CarService.Start()
RecordService.Start()
RaceService.Start()
