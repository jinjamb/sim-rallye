--!strict
--[[
	GhostChallenge.luau
	Le défi du fantôme : CONTRE QUI on roule sur la spéciale.

		Perso  : son propre meilleur passage (par défaut) ;
		Rival  : le pilote classé JUSTE DEVANT soi -- l'adversaire à sa portée,
		         bien plus motivant que le n°1 mondial ;
		Record : le meilleur temps de la spéciale ;
		Player : un pilote choisi dans le classement (clic sur sa ligne) ;
		Off    : pas de fantôme.
	G (ou le bouton FANTÔME sur mobile) passe de l'un à l'autre ; un clic sur
	une ligne du classement (L) défie ce pilote.

	Le fantôme d'un autre est demandé au serveur (RecordService), qui choisit
	le pilote et lit sa trajectoire. Si celui-ci n'en a pas (ou s'il n'y a
	personne devant), le mode reste choisi mais on roule contre son propre
	fantôme, et le bandeau dit pourquoi.

	RIVAL BATTU : en mode Rival, un temps officiel meilleur que celui du rival
	fait demander le suivant -- on remonte le classement, un pilote à la fois.

	Le choix dure toute la partie (la voiture, elle, est recréée à chaque
	passage au paddock) : Main.client.luau le transmet à chaque session.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Ghost = require(script.Parent.Ghost)
local Banner = require(script.Parent.Parent.UI.Banner)
local Theme = require(script.Parent.Parent.UI.Theme)

local GhostChallenge = {}
GhostChallenge.__index = GhostChallenge

export type Mode = "Perso" | "Rival" | "Record" | "Player" | "Off"

export type GhostChallenge = typeof(setmetatable({}, GhostChallenge)) & {
	Mode: Mode,
	Opponent: Ghost.Opponent?,
	-- Pilote visé en mode Player.
	TargetUserId: number?,
	-- Dernière demande envoyée : les réponses à une demande dépassée sont ignorées.
	RequestToken: number,
	LastRequestAt: number,
	-- Rival battu : le bandeau du prochain rival le rappelle.
	BeatenName: string?,
	OnChanged: (GhostChallenge) -> (),
}

local CYCLE: { Mode } = { "Perso", "Rival", "Record", "Off" }
local REQUEST_COOLDOWN = 2.1 -- le serveur refuse les demandes à moins de 2 s d'intervalle
local BEATEN_DELAY = 5.5 -- laisse d'abord passer l'annonce du record perso ou de la médaille (5 s)

local COLOR_INFO = Theme.TEXT
local COLOR_OPPONENT = Theme.ORANGE
local COLOR_ERROR = Theme.RED
local COLOR_BEATEN = Theme.GREEN

local MODE_TITLES: { [string]: string } = {
	Perso = "FANTÔME : TON RECORD",
	Rival = "FANTÔME : TON RIVAL",
	Record = "FANTÔME : LE RECORD",
	Player = "FANTÔME : DÉFI",
	Off = "FANTÔME MASQUÉ",
}

function GhostChallenge.new(onChanged: (GhostChallenge) -> ()): GhostChallenge
	local self = (setmetatable({}, GhostChallenge) :: any) :: GhostChallenge
	self.Mode = "Perso"
	self.Opponent = nil
	self.TargetUserId = nil
	self.RequestToken = 0
	self.LastRequestAt = -math.huge
	self.BeatenName = nil
	self.OnChanged = onChanged

	Remotes.GhostOpponent.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" then
			self:_onOpponent(payload)
		end
	end)
	return self
end

-- Le fantôme est-il masqué ?
function GhostChallenge:IsHidden(): boolean
	return self.Mode == "Off"
end

-- Résumé pour le classement : "Fantôme : Pseudo (rival)".
function GhostChallenge:Describe(): string
	local opponent: Ghost.Opponent? = self.Opponent
	if self.Mode == "Off" then
		return "Fantôme masqué"
	elseif opponent then
		local role = if self.Mode == "Rival" then " (rival)" elseif self.Mode == "Record" then " (record)" else ""
		return "Fantôme : " .. opponent.Name .. role
	end
	return "Fantôme : ton record"
end

-- G : mode suivant.
function GhostChallenge:Cycle()
	local index = table.find(CYCLE, self.Mode) or 0
	self:SetMode(CYCLE[index % #CYCLE + 1])
end

-- Clic sur une ligne du classement : défier ce pilote (soi-même = son record).
function GhostChallenge:Challenge(userId: number, localUserId: number)
	if userId == localUserId then
		self:SetMode("Perso")
		return
	end
	self.TargetUserId = userId
	self:SetMode("Player")
end

function GhostChallenge:SetMode(mode: Mode)
	self.Mode = mode
	self.BeatenName = nil
	self.RequestToken += 1
	if mode == "Perso" or mode == "Off" then
		self.Opponent = nil
		Banner.Show(MODE_TITLES[mode], if mode == "Off" then "G : changer de fantôme" else "Ton meilleur passage  ·  G : changer", COLOR_INFO, 2.5)
		self.OnChanged(self)
		return
	end
	-- En attendant la réponse, on garde le fantôme actuel.
	Banner.Show(MODE_TITLES[mode], "Recherche du fantôme…", COLOR_INFO, 3)
	self:_request()
end

-- Envoie la demande du mode actuel, en respectant l'intervalle du serveur :
-- des appuis rapprochés sur G n'envoient que la dernière.
function GhostChallenge:_request()
	local token = self.RequestToken
	local wait = math.max(0, self.LastRequestAt + REQUEST_COOLDOWN - os.clock())
	task.delay(wait, function()
		if token ~= self.RequestToken then
			return
		end
		self.LastRequestAt = os.clock()
		Remotes.RequestGhost:FireServer(self.Mode, if self.Mode == "Player" then self.TargetUserId else nil)
	end)
end

function GhostChallenge:_onOpponent(payload: any)
	if payload.Mode ~= self.Mode then
		return -- réponse à une demande dépassée
	end
	local beaten = self.BeatenName
	self.BeatenName = nil
	local ghost = payload.Ghost
	local valid = type(payload.Name) == "string"
		and type(payload.Ms) == "number"
		and type(payload.UserId) == "number"
		and type(ghost) == "table"
		and type(ghost.Rate) == "number"
		and type(ghost.Frames) == "table"
	if self.Mode == "Player" and valid and payload.UserId ~= self.TargetUserId then
		return -- un autre pilote a été choisi entre-temps
	end

	if not valid then
		-- Pas de fantôme à affronter : on roule contre le sien.
		self.Opponent = nil
		local reason = if type(payload.Error) == "string" then payload.Error else "Fantôme indisponible."
		if beaten then
			Banner.Show("RIVAL BATTU : " .. string.upper(beaten), reason, COLOR_BEATEN, 4, true)
		else
			Banner.Show(MODE_TITLES[self.Mode], reason .. "  ·  Ton record à la place", COLOR_ERROR, 3.5)
		end
		self.OnChanged(self)
		return
	end

	self.Opponent = {
		UserId = payload.UserId,
		Name = payload.Name,
		Ms = payload.Ms,
		Data = { Rate = ghost.Rate, Frames = ghost.Frames },
	}
	local line = string.format("%s — %s", payload.Name, Format.Ms(payload.Ms))
	if beaten then
		Banner.Show("RIVAL BATTU : " .. string.upper(beaten), "Prochain rival : " .. line, COLOR_BEATEN, 4, true)
	else
		Banner.Show(MODE_TITLES[self.Mode], line, COLOR_OPPONENT, 3)
	end
	self.OnChanged(self)
end

-- Temps officiel validé : un rival battu fait monter d'un cran.
function GhostChallenge:OnRunValidated(result: any)
	local opponent = self.Opponent
	-- Le défi de la semaine se court sans fantôme, sous une contrainte : il ne compte pas ici.
	if type(result) ~= "table" or not result.Valid or type(result.Ms) ~= "number" or not opponent or result.Weekly then
		return
	end
	if result.Ms >= opponent.Ms then
		return
	end
	if self.Mode == "Rival" then
		local token = self.RequestToken
		task.delay(BEATEN_DELAY, function()
			if token ~= self.RequestToken or self.Mode ~= "Rival" then
				return
			end
			self.RequestToken += 1
			self.BeatenName = opponent.Name
			self:_request()
		end)
	else
		task.delay(BEATEN_DELAY, function()
			if self.Opponent == opponent then
				Banner.Show("FANTÔME BATTU : " .. string.upper(opponent.Name), Format.Ms(result.Ms) .. " contre " .. Format.Ms(opponent.Ms), COLOR_BEATEN, 4, true)
			end
		end)
	end
end

return GhostChallenge
