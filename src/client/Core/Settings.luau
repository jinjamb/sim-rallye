--!strict
--[[
	Settings.luau
	Les réglages du joueur chez lui (onglet OPTIONS du menu) : la liste et
	les choix sont dans Shared/Settings/Options.luau. Ce module garde les
	choix courants, les applique au jeu et les fait sauvegarder par le
	serveur (Remotes.SaveOptions, une seconde après le dernier changement :
	on peut cliquer plusieurs fois de suite sans tout envoyer).

	Appliqué ici : volumes (SoundGroups), voix du copilote, unité de vitesse.
	Le reste est relayé par OnChanged (Main.client.luau : caméra, bosses,
	mini-carte, aide des commandes, boîte de la voiture en cours) : ce
	module reste léger, sans dépendre de ces modules-là.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Options = require(ReplicatedStorage.Shared.Settings.Options)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Units = require(ReplicatedStorage.Shared.Util.Units)
local SoundGroups = require(script.Parent.Parent.Audio.SoundGroups)
local CopilotVoice = require(script.Parent.Parent.Audio.CopilotVoice)

local Settings = {}

local SAVE_DELAY = 1 -- secondes après le dernier changement

local values: { [string]: number } = Options.Defaults()
local listeners: { (id: string, value: any) -> () } = {}
local saveToken = 0

-- La valeur choisie d'une option (Value du choix).
function Settings.Value(id: string): any
	return Options.Value(values, id)
end

-- L'indice du choix d'une option.
function Settings.Index(id: string): number
	local option = Options.Get(id)
	return values[id] or (if option then option.Default else 1)
end

-- Prévenu à chaque changement (et une fois par option au chargement du profil).
function Settings.OnChanged(callback: (id: string, value: any) -> ())
	table.insert(listeners, callback)
end

local function apply(id: string)
	local value = Settings.Value(id)
	if id == "MasterVolume" then
		SoundGroups.SetMaster(value)
	elseif id == "EngineVolume" then
		SoundGroups.SetLevel("Voitures", value)
	elseif id == "EffectsVolume" then
		SoundGroups.SetLevel("Effets", value)
	elseif id == "VoiceVolume" then
		SoundGroups.SetLevel("Voix", value)
	elseif id == "CopilotVoice" then
		CopilotVoice.SetMode(value)
	elseif id == "SpeedUnit" then
		Units.SpeedUnit = value
	end
	for _, callback in ipairs(listeners) do
		task.spawn(callback, id, value)
	end
end

local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token == saveToken then
			Remotes.SaveOptions:FireServer(values)
		end
	end)
end

-- Choix reçus avec le profil : tout est appliqué.
function Settings.Load(input: any)
	values = Options.Sanitize(input)
	for _, option in ipairs(Options.LIST) do
		apply(option.Id)
	end
end

-- Choisit l'indice `index` d'une option, l'applique et le fait sauvegarder.
function Settings.Set(id: string, index: number)
	local option = Options.Get(id)
	if not option or index < 1 or index > #option.Choices or values[id] == index then
		return
	end
	values[id] = index
	apply(id)
	scheduleSave()
end

-- Choix suivant ou précédent (les volumes s'arrêtent aux bornes, les autres bouclent).
function Settings.Step(id: string, direction: number)
	local option = Options.Get(id)
	if not option then
		return
	end
	local count = #option.Choices
	local index = Settings.Index(id) + direction
	if string.find(id, "Volume") then
		index = math.clamp(index, 1, count)
	else
		index = (index - 1) % count + 1
	end
	Settings.Set(id, index)
end

-- Retour aux choix par défaut.
function Settings.Reset()
	for _, option in ipairs(Options.LIST) do
		values[option.Id] = option.Default
		apply(option.Id)
	end
	scheduleSave()
end

-- La voix changée hors du menu (touche N) : le choix suit.
function Settings.SyncCopilot()
	local mode = CopilotVoice.GetMode()
	local option = Options.Get("CopilotVoice")
	if not option then
		return
	end
	for index, choice in ipairs(option.Choices) do
		if choice.Value == mode and values.CopilotVoice ~= index then
			values.CopilotVoice = index
			scheduleSave()
		end
	end
end

return Settings
