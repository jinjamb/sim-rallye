--!strict
--[[
	Horn.luau
	Le klaxon : joué sur la voiture qui klaxonne, chez chaque joueur (le
	serveur relaie à tous : HornService), avec le son du klaxon porté par
	son pilote (attribut EquippedHorn de la voiture, Items/Horns.luau).
	Un son positionné : on l'entend de près, pas à l'autre bout de la carte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Economy.Catalog)

local Horn = {}

local VOLUME = 1.2
local ROLLOFF_MIN, ROLLOFF_MAX = 30, 450
local warned = false

-- Joue le klaxon de la voiture `car` (son modèle, dans le monde).
function Horn.Play(car: Model)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return
	end
	local id = car:GetAttribute("EquippedHorn")
	local item = Catalog.Get(if type(id) == "string" then id else nil)
	if not item or not item.Sound or item.Sound == "" then
		-- Klaxon sans son choisi (Items/Horns.luau) : rien à jouer.
		if RunService:IsStudio() and not warned then
			warned = true
			warn("[Klaxon] Pas de son pour " .. tostring(id) .. " : identifiant audio à renseigner dans Shared/Economy/Items/Horns.luau")
		end
		return
	end
	local existing = chassis:FindFirstChild("Horn")
	if existing and existing:IsA("Sound") then
		existing:Destroy() -- un nouveau coup de klaxon coupe le précédent
	end
	local sound = Instance.new("Sound")
	sound.Name = "Horn"
	sound.SoundId = item.Sound :: string
	sound.PlaybackSpeed = item.Pitch or 1
	sound.Volume = VOLUME
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	sound.Parent = chassis
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy() -- son trop long ou qui ne se charge pas
		end
	end)
end

return Horn
