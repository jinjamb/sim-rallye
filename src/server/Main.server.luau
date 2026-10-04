--!strict
--[[
	Main.server.luau
	Démarrage du serveur. Les services sont des modules (Services/) pour pouvoir
	s'appeler entre eux : RaceService recrée les voitures sur la grille
	(CarService) et enregistre les tours (RecordService).
	Ordre : les voitures d'abord (gabarit, groupe de collision), puis les
	profils, puis les courses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crée les RemoteEvents avant que le premier joueur ne les attende.
require(ReplicatedStorage.Shared.Network.Remotes)

local Services = script.Parent.Services
local CarService = require(Services.CarService)
local RecordService = require(Services.RecordService)
local RaceService = require(Services.RaceService)

CarService.Start()
RecordService.Start()
RaceService.Start()
