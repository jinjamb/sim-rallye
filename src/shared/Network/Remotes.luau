--!strict
--[[
	Remotes.luau
	Crée (serveur) ou attend (client) les RemoteEvents du jeu.
	Le serveur require ce module au démarrage, donc les events existent
	avant même que le premier joueur ne se connecte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Remotes = {
	-- Client -> Serveur : (chassis: BasePart) le joueur demande le contrôle de SA voiture
	RequestCarControl: RemoteEvent,
	-- Client -> Serveur : () le joueur relâche sa voiture
	ReleaseCarControl: RemoteEvent,
	-- Serveur -> Client : (chassis: BasePart, granted: boolean)
	CarControlChanged: RemoteEvent,

	-- Client -> Serveur, ~10 Hz, perte tolérée : état de la voiture pour les
	-- autres joueurs (son, roues, poussière). Voir CarService.
	CarTelemetry: UnreliableRemoteEvent,

	-- Serveur -> Client : (profile) records et fantômes par catégorie, réglages, livrée, statistiques
	ProfileLoaded: RemoteEvent,
	-- Serveur -> Client : (stats, laps) statistiques et records du tour mis à jour
	ProfileUpdated: RemoteEvent,
	-- Serveur -> Client : (result) temps officiel d'une spéciale, mesuré par le serveur
	RunValidated: RemoteEvent,
	-- Client -> Serveur : (ghost) trajectoire du meilleur passage qu'on vient de valider
	SubmitGhost: RemoteEvent,
	-- Client -> Serveur : (mode: "Rival" | "Record" | "Player", userId?, classId) fantôme d'un
	-- autre pilote de la même catégorie à affronter sur la spéciale
	RequestGhost: RemoteEvent,
	-- Serveur -> Client : (opponent) le fantôme demandé (pilote, temps, trajectoire) ou l'erreur
	GhostOpponent: RemoteEvent,
	-- Serveur -> Client : (boards) classements de la spéciale, par catégorie de voiture
	Leaderboard: RemoteEvent,
	-- Serveur -> Client : (board) défi de la semaine : contrainte, fin, classement, son temps
	WeeklyBoard: RemoteEvent,
	-- Client -> Serveur : (classId, setup) réglages d'une catégorie de voiture à sauvegarder
	SaveSetup: RemoteEvent,
	-- Client -> Serveur : (livery) couleur et numéro de course à sauvegarder
	SaveLivery: RemoteEvent,
	-- Serveur -> Client : (snapshot, news?) progression (XP, niveau, licence, médailles) ;
	-- news : niveau gagné, cosmétiques débloqués (Progression.luau)
	Progress: RemoteEvent,
	-- Client -> Serveur : (points, kind, detail?) points de style gagnés (dérapage, saut) ;
	-- detail : multiplicateur d'une combinaison, temps en l'air d'un saut (défis du jour)
	SubmitStyle: RemoteEvent,
	-- Client -> Serveur : () remise en piste pendant la spéciale (défi « sans remise en piste »)
	Recovered: RemoteEvent,
	-- Serveur -> Client : (state, news?) défis du jour : objectifs, progression ; news : réussis
	Daily: RemoteEvent,
	-- Client -> Serveur : (lessonId, tier) médaille obtenue à une leçon de l'école de pilotage
	LessonResult: RemoteEvent,
	-- Client -> Serveur : () retour à pied au paddock (essais libres ; sans effet en course)
	ReturnToPaddock: RemoteEvent,
	-- Client -> Serveur : (mode: "Stage" | "Practice" | "Rallycross", trackId?) choix du
	-- menu principal : lancer une spéciale, des essais libres, une course de rallycross
	PlayMode: RemoteEvent,

	-- RALLYCROSS (RaceService)
	-- Client -> Serveur : (action: string, payload) quitter, abandonner, lancer, réglages de la course
	-- (on rejoint une course en entrant dans sa zone du paddock : PaddockService)
	RaceAction: RemoteEvent,
	-- Serveur -> Clients : (races) les courses ouvertes et en cours, pour le menu
	LobbyState: RemoteEvent,
	-- Serveur -> Client : (race | nil) la course du joueur : membres, état, horaires
	RaceState: RemoteEvent,
	-- Serveur -> Client, ~4 Hz, perte tolérée : classement en direct
	RaceLive: UnreliableRemoteEvent,
	-- Serveur -> Client : (kind, data) tour bouclé, joker, pénalité, arrivée, résultats
	RaceEvent: RemoteEvent,
	-- Serveur -> Clients : (records) meilleurs tours, par catégorie puis par circuit
	TrackRecords: RemoteEvent,

	-- ÉCONOMIE (EconomyService)
	-- Serveur -> Client : (wallet, news?) crédits, objets possédés et portés ;
	-- news : crédits gagnés, objet acheté ou débloqué, erreur
	Wallet: RemoteEvent,
	-- Client -> Serveur : (itemId) acheter un objet en crédits
	BuyItem: RemoteEvent,
	-- Client -> Serveur : (kind, itemId) porter un objet possédé
	EquipItem: RemoteEvent,

	-- COSMÉTIQUES VISIBLES PAR TOUS
	-- Client -> Serveur : () coup de klaxon (au volant)
	Horn: RemoteEvent,
	-- Serveur -> Clients : (userId) ce pilote klaxonne : chacun joue le son sur sa voiture
	HornPlayed: RemoteEvent,
	-- Client -> Serveur : () utiliser un tirage
	RequestRoll: RemoteEvent,
	-- Serveur -> Client : (result) l'objet tiré { ItemId, Duplicate, Credits } ou { Error }
	RollResult: RemoteEvent,
	-- Serveur -> Client : (state, news?) Rallye Pass : saison, XP, premium ; news : palier atteint
	PassState: RemoteEvent,
}

local RELIABLE = {
	"RequestCarControl",
	"ReleaseCarControl",
	"CarControlChanged",
	"ProfileLoaded",
	"ProfileUpdated",
	"RunValidated",
	"SubmitGhost",
	"RequestGhost",
	"GhostOpponent",
	"Leaderboard",
	"WeeklyBoard",
	"SaveSetup",
	"SaveLivery",
	"Progress",
	"SubmitStyle",
	"Recovered",
	"Daily",
	"LessonResult",
	"ReturnToPaddock",
	"PlayMode",
	"RaceAction",
	"LobbyState",
	"RaceState",
	"RaceEvent",
	"TrackRecords",
	"Wallet",
	"BuyItem",
	"EquipItem",
	"Horn",
	"HornPlayed",
	"RequestRoll",
	"RollResult",
	"PassState",
}
local UNRELIABLE = { "CarTelemetry", "RaceLive" }

local function buildServer(): Remotes
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end

	local built: { [string]: Instance } = {}
	local function ensure(name: string, className: string)
		local existing = (folder :: Instance):FindFirstChild(name)
		if not existing then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
			existing = remote
		end
		built[name] = existing :: Instance
	end
	for _, name in ipairs(RELIABLE) do
		ensure(name, "RemoteEvent")
	end
	for _, name in ipairs(UNRELIABLE) do
		ensure(name, "UnreliableRemoteEvent")
	end

	return built :: any
end

local function buildClient(): Remotes
	local folder = ReplicatedStorage:WaitForChild("Remotes")

	local built: { [string]: Instance } = {}
	for _, name in ipairs(RELIABLE) do
		built[name] = folder:WaitForChild(name)
	end
	for _, name in ipairs(UNRELIABLE) do
		built[name] = folder:WaitForChild(name)
	end

	return built :: any
end

return (if RunService:IsServer() then buildServer() else buildClient()) :: Remotes
