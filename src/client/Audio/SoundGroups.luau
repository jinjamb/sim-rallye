--!strict
--[[
	SoundGroups.luau
	Les familles de sons du jeu, chacune avec son volume réglable (onglet
	OPTIONS : client/Core/Settings.luau) :
		Voitures  moteurs, pneus, vent (CarAudio.luau) ;
		Effets    retours de flamme, klaxons, chocs, feux de départ, pluie ;
		Voix      le copilote (mots enregistrés ; la synthèse vocale lit
		          Level("Voix") au moment de parler).
	Un son rejoint sa famille par sa propriété SoundGroup. Le volume d'une
	famille : son volume de base (BASE) x son réglage x le volume général.
]]

local SoundService = game:GetService("SoundService")

local SoundBank = require(script.Parent.SoundBank)

local SoundGroups = {}

export type Family = "Voitures" | "Effets" | "Voix"

local BASE: { [string]: number } = {
	Voitures = SoundBank.MasterVolume,
	Effets = 1,
	Voix = 1,
}

local groups: { [string]: SoundGroup } = {}
local levels: { [string]: number } = { Voitures = 1, Effets = 1, Voix = 1 }
local master = 1

local function refresh(name: string)
	local group = groups[name]
	if group then
		group.Volume = (BASE[name] or 1) * (levels[name] or 1) * master
	end
end

function SoundGroups.Get(name: Family): SoundGroup
	local group = groups[name]
	if group then
		return group
	end
	local existing = SoundService:FindFirstChild(name)
	local created: SoundGroup
	if existing and existing:IsA("SoundGroup") then
		created = existing
	else
		created = Instance.new("SoundGroup")
		created.Name = name
		created.Parent = SoundService
	end
	groups[name] = created
	refresh(name)
	return created
end

-- Réglage d'une famille (0 à 1).
function SoundGroups.SetLevel(name: Family, level: number)
	levels[name] = math.clamp(level, 0, 1)
	refresh(name)
end

-- Volume général (0 à 1), appliqué à toutes les familles.
function SoundGroups.SetMaster(level: number)
	master = math.clamp(level, 0, 1)
	for name in pairs(BASE) do
		refresh(name)
	end
end

-- Volume effectif d'une famille hors base (réglage x général) : pour les
-- sons qui ne passent pas par un SoundGroup (synthèse vocale).
function SoundGroups.Level(name: Family): number
	return (levels[name] or 1) * master
end

return SoundGroups
