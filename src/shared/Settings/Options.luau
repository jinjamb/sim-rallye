--!strict
--[[
	Options.luau
	Les réglages du joueur (onglet OPTIONS du menu) : leur liste, leurs
	valeurs possibles et leur remise en forme. Partagé par le serveur (le
	profil les sauvegarde : ProfileSchema, Remotes.SaveOptions) et le
	client (client/Core/Settings.luau les applique).

	Chaque option est un choix dans une liste (Choices) : le profil retient
	l'INDICE du choix. Ajouter une option : l'ajouter ici (à la fin de sa
	section), puis l'appliquer dans Settings.luau. Ajouter des choix : à la
	fin de la liste seulement (les indices sauvegardés ne changent pas).
]]

local Options = {}

export type Choice = { Label: string, Value: any }
export type Option = {
	Id: string,
	Section: string,
	Name: string,
	Hint: string?, -- précision affichée sous la ligne
	Choices: { Choice },
	Default: number, -- indice du choix par défaut
}

-- Un volume de 0 à 100 %, par pas de 10.
local function volumes(): { Choice }
	local list = {}
	for step = 0, 10 do
		table.insert(list, { Label = tostring(step * 10) .. " %", Value = step / 10 })
	end
	return list
end

local OFF_ON = { { Label = "Non", Value = false }, { Label = "Oui", Value = true } }

Options.SECTIONS = { "Son", "Conduite", "Caméra", "Affichage" }

Options.LIST = {
	-- Son
	{ Id = "MasterVolume", Section = "Son", Name = "Volume général", Choices = volumes(), Default = 11 },
	{ Id = "EngineVolume", Section = "Son", Name = "Moteurs et pneus", Choices = volumes(), Default = 11 },
	{ Id = "EffectsVolume", Section = "Son", Name = "Effets", Hint = "retours de flamme, klaxons, chocs, feux de départ, pluie", Choices = volumes(), Default = 11 },
	{ Id = "VoiceVolume", Section = "Son", Name = "Voix du copilote", Choices = volumes(), Default = 11 },
	{
		Id = "CopilotVoice",
		Section = "Son",
		Name = "Copilote",
		Choices = { { Label = "Homme", Value = "Male" }, { Label = "Femme", Value = "Female" }, { Label = "Coupé", Value = "Off" } },
		Default = 1,
	},
	-- Conduite
	{
		Id = "Gearbox",
		Section = "Conduite",
		Name = "Boîte de vitesses",
		Hint = "au départ ; M change en roulant",
		Choices = { { Label = "Automatique", Value = true }, { Label = "Manuelle", Value = false } },
		Default = 1,
	},
	{
		Id = "SpeedUnit",
		Section = "Conduite",
		Name = "Vitesse",
		Choices = { { Label = "km/h", Value = "kmh" }, { Label = "mph", Value = "mph" } },
		Default = 1,
	},
	-- Caméra
	{
		Id = "FieldOfView",
		Section = "Caméra",
		Name = "Champ de vision",
		Choices = {
			{ Label = "60°", Value = 60 },
			{ Label = "65°", Value = 65 },
			{ Label = "70°", Value = 70 },
			{ Label = "75°", Value = 75 },
			{ Label = "80°", Value = 80 },
			{ Label = "85°", Value = 85 },
			{ Label = "90°", Value = 90 },
		},
		Default = 3,
	},
	{
		Id = "CameraShake",
		Section = "Caméra",
		Name = "Secousses",
		Choices = {
			{ Label = "Aucune", Value = 0 },
			{ Label = "Légères", Value = 0.5 },
			{ Label = "Normales", Value = 1 },
			{ Label = "Fortes", Value = 1.5 },
		},
		Default = 3,
	},
	-- Affichage
	{ Id = "ControlsHint", Section = "Affichage", Name = "Aide des commandes", Hint = "F1 la replie aussi", Choices = OFF_ON, Default = 2 },
	{ Id = "Minimap", Section = "Affichage", Name = "Mini-carte en course", Choices = OFF_ON, Default = 2 },
	{ Id = "Dents", Section = "Affichage", Name = "Bosses", Hint = "carrosserie cabossée après un contact ; les étincelles restent", Choices = OFF_ON, Default = 2 },
} :: { Option }

local byId: { [string]: Option } = {}
for _, option in ipairs(Options.LIST) do
	byId[option.Id] = option
end

function Options.Get(id: string): Option?
	return byId[id]
end

-- Les choix par défaut (indice par option).
function Options.Defaults(): { [string]: number }
	local values = {}
	for _, option in ipairs(Options.LIST) do
		values[option.Id] = option.Default
	end
	return values
end

-- Remise en forme : options connues, indices entiers dans la liste.
function Options.Sanitize(input: any): { [string]: number }
	local values = Options.Defaults()
	if type(input) ~= "table" then
		return values
	end
	for _, option in ipairs(Options.LIST) do
		local index = input[option.Id]
		if type(index) == "number" and index == math.floor(index) and index >= 1 and index <= #option.Choices then
			values[option.Id] = index
		end
	end
	return values
end

-- La valeur choisie (Value du choix) d'une option.
function Options.Value(values: { [string]: number }, id: string): any
	local option = byId[id]
	if not option then
		return nil
	end
	local choice = option.Choices[values[id] or option.Default] or option.Choices[option.Default]
	return choice.Value
end

return Options
