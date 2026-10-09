--!strict
--[[
	Main.server.luau
	Démarrage du serveur.

	ORGANISATION :
		Data/      les données sauvegardées : accès aux DataStores (Stores),
		           forme du profil (ProfileSchema), chargement et écritures
		           (ProfileStore), classements (Boards).
		Services/  un service par sujet, qui s'appellent entre eux par
		           require (sans cycle : un service ne dépend que de ceux
		           listés avant lui ci-dessous). Quand un service doit en
		           prévenir un autre qui dépend déjà de lui, il expose un
		           crochet (LiveryChanged...) branché ici.

	ORDRE DE DÉMARRAGE :
		- le paddock d'abord (le point d'apparition doit exister avant que le
		  premier personnage n'apparaisse ; PaddockService ramène de toute
		  façon au paddock un personnage apparu ailleurs), puis les voitures
		  (gabarit, groupe de collision) ;
		- puis les services qui lisent le profil. Ils s'inscrivent au
		  chargement des profils (ProfileStore.OnLoaded) dans l'ordre de leur
		  démarrage : la livrée est remise en règle (Garage) avant l'envoi du
		  profil (Record), et la progression part en dernier ;
		- enfin ProfileStore, qui commence à charger les profils.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crée les RemoteEvents avant que le premier joueur ne les attende.
require(ReplicatedStorage.Shared.Network.Remotes)

local ProfileStore = require(script.Parent.Data.ProfileStore)
local Services = script.Parent.Services
local ProgressService = require(Services.ProgressService)
local GarageService = require(Services.GarageService)
local EconomyService = require(Services.EconomyService)
local RecordService = require(Services.RecordService)
local ChallengeService = require(Services.ChallengeService)
local GhostService = require(Services.GhostService)
local StageService = require(Services.StageService)
local StyleService = require(Services.StyleService)
local SchoolService = require(Services.SchoolService)
local CarService = require(Services.CarService)
local RaceService = require(Services.RaceService)
local HornService = require(Services.HornService)
local PaddockService = require(Services.PaddockService)

-- Crochets entre services (sans dépendance circulaire entre modules).
GarageService.LiveryChanged = CarService.RefreshLivery
EconomyService.EquippedChanged = CarService.RefreshEquipped
ProgressService.Changed = CarService.RefreshProgress
RaceService.PodiumHandler = PaddockService.Podium :: any

PaddockService.Start()
CarService.Start()

GarageService.Start()
EconomyService.Start()
RecordService.Start()
StageService.Start()
ChallengeService.Start()
GhostService.Start()
StyleService.Start()
SchoolService.Start()
ProgressService.Start()
RaceService.Start()
HornService.Start()

ProfileStore.Start()
