--!strict
--[[
	CarSetup.luau
	Les réglages de la voiture modifiables en jeu : bornes, pas, valeurs par
	défaut et préréglages. Partagé :
		- le client construit le menu à partir de ce schéma et applique les
		  valeurs à la voiture (Car:ApplySetup) ;
		- le serveur s'en sert pour REBORNER ce qu'il reçoit avant de le
		  sauvegarder (un client ne doit pas pouvoir enregistrer n'importe quoi).

	Les valeurs par défaut sont celles avec lesquelles la voiture a été mise au
	point (Car.luau, Aerodynamics.luau, Gearbox.luau) : "Défaut" ne change rien.
]]

local CarSetup = {}

export type Setup = { [string]: number }

export type Field = {
	Key: string,
	Label: string,
	Group: string,
	Min: number,
	Max: number,
	Step: number,
	Default: number,
	Format: string, -- format d'affichage (string.format)
	Scale: number, -- multiplicateur d'affichage (0.65 -> 65 %)
	Hint: string,
}

CarSetup.FIELDS = {
	{
		Key = "BrakeBias", Label = "Répartition AV", Group = "Freins",
		Min = 0.50, Max = 0.80, Step = 0.01, Default = 0.65, Format = "%.0f %%", Scale = 100,
		Hint = "Moins à l'avant : l'arrière décroche au freinage, la voiture pivote.",
	},
	{
		Key = "BrakeForce", Label = "Puissance", Group = "Freins",
		Min = 0.60, Max = 1.10, Step = 0.05, Default = 0.85, Format = "%.2f", Scale = 1,
		Hint = "Force totale des freins, en fraction du poids.",
	},
	{
		Key = "FrontPowerLock", Label = "Avant, accélération", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.35, Format = "%.0f %%", Scale = 100,
		Hint = "Plus bloqué : plus de motricité, mais l'avant refuse de tourner au gaz.",
	},
	{
		Key = "FrontCoastLock", Label = "Avant, frein moteur", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.15, Format = "%.0f %%", Scale = 100,
		Hint = "Stabilité au lever de pied.",
	},
	{
		Key = "RearPowerLock", Label = "Arrière, accélération", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.50, Format = "%.0f %%", Scale = 100,
		Hint = "Plus bloqué : l'arrière pousse et fait pivoter la voiture au gaz.",
	},
	{
		Key = "RearCoastLock", Label = "Arrière, frein moteur", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.30, Format = "%.0f %%", Scale = 100,
		Hint = "Plus bloqué : plus stable au lever de pied, moins de rotation.",
	},
	{
		Key = "CenterSplit", Label = "Central, part arrière", Group = "Différentiels",
		Min = 0.40, Max = 0.75, Step = 0.05, Default = 0.60, Format = "%.0f %%", Scale = 100,
		Hint = "Plus à l'arrière : caractère survireur, propulsion.",
	},
	{
		Key = "CenterLock", Label = "Central, blocage", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.40, Format = "%.0f %%", Scale = 100,
		Hint = "1 = arbre rigide, comme une vraie Rally2 : motricité maxi, sous-vire en épingle.",
	},
	{
		Key = "AntiRollFront", Label = "Barre avant", Group = "Châssis",
		Min = 0, Max = 1, Step = 0.05, Default = 0.60, Format = "%.2f", Scale = 1,
		Hint = "Plus raide : moins de roulis, plus de sous-virage.",
	},
	{
		Key = "AntiRollRear", Label = "Barre arrière", Group = "Châssis",
		Min = 0, Max = 1, Step = 0.05, Default = 0.42, Format = "%.2f", Scale = 1,
		Hint = "Plus raide : moins de roulis, plus de survirage.",
	},
	{
		Key = "Downforce", Label = "Appui aéro", Group = "Châssis",
		Min = 0, Max = 0.30, Step = 0.02, Default = 0.25, Format = "%.2f", Scale = 1,
		Hint = "Appui à 100 km/h, en fraction du poids. Une vraie Rally2 : ~0.05-0.10.",
	},
	{
		Key = "FinalDrive", Label = "Rapport de pont", Group = "Boîte",
		Min = 3.0, Max = 4.5, Step = 0.1, Default = 3.5, Format = "%.1f", Scale = 1,
		Hint = "Plus haut : rapports plus courts, plus de reprise, moins de vitesse de pointe.",
	},
} :: { Field }

CarSetup.PRESETS = {
	{
		Name = "Défaut",
		Values = {},
	},
	{
		-- Terre : plus de rotation (freins reculés, avant moins bloqué), barres
		-- souples pour absorber, rapports courts.
		Name = "Terre",
		Values = {
			BrakeBias = 0.60, FrontPowerLock = 0.25, RearPowerLock = 0.55,
			AntiRollFront = 0.45, AntiRollRear = 0.35, FinalDrive = 3.8, Downforce = 0.12,
		},
	},
	{
		-- Asphalte : stabilité et précision, barres raides, rapports longs.
		Name = "Asphalte",
		Values = {
			BrakeBias = 0.68, BrakeForce = 1.0, FrontPowerLock = 0.30, RearPowerLock = 0.40,
			CenterSplit = 0.55, AntiRollFront = 0.75, AntiRollRear = 0.60, FinalDrive = 3.3, Downforce = 0.20,
		},
	},
} :: { { Name: string, Values: Setup } }

local BY_KEY: { [string]: Field } = {}
for _, field in ipairs(CarSetup.FIELDS) do
	BY_KEY[field.Key] = field
end

function CarSetup.GetField(key: string): Field?
	return BY_KEY[key]
end

function CarSetup.Default(): Setup
	local setup: Setup = {}
	for _, field in ipairs(CarSetup.FIELDS) do
		setup[field.Key] = field.Default
	end
	return setup
end

-- Valeur ramenée dans ses bornes et sur son pas (évite 0.6500000001).
local function snap(field: Field, value: number): number
	local clamped = math.clamp(value, field.Min, field.Max)
	local steps = math.floor((clamped - field.Min) / field.Step + 0.5)
	return math.clamp(field.Min + steps * field.Step, field.Min, field.Max)
end

--[[
	Réglages fiables à partir de n'importe quoi (données client, ancienne
	sauvegarde) : clés inconnues ignorées, valeurs absentes ou invalides
	remplacées par le défaut, le reste reborné.
]]
function CarSetup.Sanitize(input: any): Setup
	local setup = CarSetup.Default()
	if type(input) ~= "table" then
		return setup
	end
	for _, field in ipairs(CarSetup.FIELDS) do
		local value = input[field.Key]
		if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
			setup[field.Key] = snap(field, value)
		end
	end
	return setup
end

function CarSetup.Step(setup: Setup, key: string, direction: number): Setup
	local field = BY_KEY[key]
	if not field then
		return setup
	end
	local copy = table.clone(setup)
	copy[key] = snap(field, (setup[key] or field.Default) + direction * field.Step)
	return copy
end

function CarSetup.WithPreset(name: string): Setup
	local setup = CarSetup.Default()
	for _, preset in ipairs(CarSetup.PRESETS) do
		if preset.Name == name then
			for key, value in pairs(preset.Values) do
				setup[key] = value
			end
		end
	end
	return CarSetup.Sanitize(setup)
end

return CarSetup
