--!strict
--[[
	RaceTypes.luau
	Formes des données de rallycross envoyées par le serveur (RaceService.luau) :
	salle d'attente, état de la course, classement en direct, résultats,
	records du tour. Le menu, le HUD et la minicarte les lisent.
]]

local RaceTypes = {}

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

return RaceTypes
