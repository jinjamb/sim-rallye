--!strict
--[[
	AnnounceService.luau
	Les annonces à tout le serveur : un record battu, une médaille de platine,
	un nouveau roi du drift, un grand trophée. Chaque joueur les voit passer
	dans le bandeau du serveur (Announcer.luau, côté client), l'une après
	l'autre.

	Ne dépend de rien d'autre que des remotes : tous les services peuvent
	l'appeler.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

local AnnounceService = {}

-- La sorte d'annonce choisit l'étiquette et la couleur affichées (Announcer.luau).
export type Kind = "Record" | "Platinum" | "DriftKing" | "Trophy"

-- `name` : le pilote ; `text` : ce qu'il a fait (« bat le record de... »).
function AnnounceService.Send(kind: Kind, name: string, text: string)
	Remotes.Announce:FireAllClients({ Kind = kind, Name = name, Text = text })
end

return AnnounceService
