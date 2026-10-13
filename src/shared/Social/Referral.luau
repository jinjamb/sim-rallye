--!strict
--[[
	Referral.luau
	Le parrainage : inviter un ami qui découvre le jeu rapporte une
	récompense aux deux, dès que le filleul a pris le volant (première
	spéciale terminée, ou première course de rallycross).

	QUI EST LE PARRAIN : Roblox le dit à l'arrivée du filleul quand il vient
	d'une invitation ou d'un lien de partage (GetJoinData().ReferredByPlayerId).
	À défaut, l'invitation du jeu (FriendInvite.luau) porte l'identifiant de
	celui qui invite dans ses données de lancement (LaunchData, ci-dessous) ;
	celles-là peuvent être fabriquées, le serveur ne les croit donc que si
	les deux joueurs sont amis.

	FILLEUL : seulement à sa toute première venue (profil vierge), une seule
	fois. PARRAIN : récompensé pour MAX_REWARDED amis au plus.

	DONNÉES DE LANCEMENT : un petit JSON { r = parrain, s = code de session
	privée } ; un code seul (ancien format) reste compris.
]]

local HttpService = game:GetService("HttpService")

local Referral = {}

Referral.INVITER_CREDITS = 500 -- au parrain, par ami qui prend le volant
Referral.INVITER_ROLLS = 1 -- et un tirage
Referral.NEWCOMER_CREDITS = 300 -- au filleul, en plus de la récompense du tutoriel
Referral.MAX_REWARDED = 20 -- amis récompensés au plus, par parrain

export type LaunchInfo = {
	Referrer: number?, -- UserId de celui qui invite
	SessionCode: string?, -- session privée à rejoindre (SessionService)
}

-- Données de lancement d'une invitation (ExperienceInviteOptions.LaunchData).
function Referral.Encode(referrer: number, sessionCode: string?): string
	return HttpService:JSONEncode({ r = referrer, s = sessionCode })
end

-- Ce que portent les données de lancement (jamais d'erreur : tout peut y arriver).
function Referral.Decode(launchData: any): LaunchInfo
	if type(launchData) ~= "string" or launchData == "" or #launchData > 200 then
		return {}
	end
	if string.sub(launchData, 1, 1) ~= "{" then
		return { SessionCode = launchData } -- ancien format : le code seul
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(launchData)
	end)
	if not ok or type(data) ~= "table" then
		return {}
	end
	local referrer = data.r
	return {
		Referrer = if type(referrer) == "number" and referrer > 0 and referrer == math.floor(referrer) then referrer else nil,
		SessionCode = if type(data.s) == "string" then data.s else nil,
	}
end

return Referral
