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

	PAR CATÉGORIE (CarClasses.luau) : chaque catégorie a ses réglages (le
	profil en garde un jeu par catégorie) et peut changer les valeurs par
	défaut (Setup de sa fiche). Une traction n'a ni différentiel central ni
	arrière moteur, une propulsion ni avant ni central : ces réglages (Axle)
	ne s'affichent pas pour elles (la transmission est celle de la voiture,
	CarModels.luau).
	L'APPUI AÉRO a la plage de la voiture (CarClasses : DownforceRange) : les
	bornes de Downforce ci-dessous ne sont qu'un repli.
	PRÉRÉGLAGES : une valeur d'appui y est une part de cette plage (Relative),
	pour que « Terre » et « Asphalte » aient un sens sur chaque voiture.
]]

local CarClasses = require(script.Parent.CarClasses)

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
	-- Différentiel concerné : sans effet (et caché) si la transmission ne
	-- l'entraîne pas (traction : ni arrière ni central ; propulsion : ni avant ni central).
	Axle: ("Front" | "Rear" | "Center")?,
}

CarSetup.FIELDS = {
	{
		Key = "SteerAngle", Label = "Angle de braquage", Group = "Direction",
		Min = 30, Max = 60, Step = 1, Default = 45, Format = "%.0f°", Scale = 1,
		Hint = "Braquage maximal des roues avant. Plus grand : épingles plus serrées, contre-braquage plus ample.",
	},
	{
		Key = "HighSpeedSteer", Label = "Braquage à haute vitesse", Group = "Direction",
		Min = 0.30, Max = 1, Step = 0.05, Default = 0.8, Format = "%.0f %%", Scale = 100,
		Hint = "Clavier et tactile : part du braquage gardée à 120 km/h (la manette n'est jamais limitée).",
	},
	{
		Key = "SteerAssist", Label = "Aide au braquage", Group = "Direction",
		Min = 0, Max = 1, Step = 0.25, Default = 1, Format = "%.0f %%", Scale = 100,
		Hint = "Quand on braque plus que les pneus ne peuvent tenir (clavier surtout), garde les roues avant près de leur meilleure adhérence : moins de sous-virage, surtout sur l'asphalte. Le contre-braquage reste libre. 0 % : braquage brut.",
	},
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
		Axle = "Front",
	},
	{
		Key = "FrontCoastLock", Label = "Avant, frein moteur", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.15, Format = "%.0f %%", Scale = 100,
		Hint = "Stabilité au lever de pied.",
		Axle = "Front",
	},
	{
		Key = "RearPowerLock", Label = "Arrière, accélération", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.50, Format = "%.0f %%", Scale = 100,
		Hint = "Plus bloqué : l'arrière pousse et fait pivoter la voiture au gaz.",
		Axle = "Rear",
	},
	{
		Key = "RearCoastLock", Label = "Arrière, frein moteur", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.30, Format = "%.0f %%", Scale = 100,
		Hint = "Plus bloqué : plus stable au lever de pied, moins de rotation.",
		Axle = "Rear",
	},
	{
		Key = "CenterSplit", Label = "Central, part arrière", Group = "Différentiels",
		Min = 0.40, Max = 0.75, Step = 0.05, Default = 0.60, Format = "%.0f %%", Scale = 100,
		Hint = "Plus à l'arrière : caractère survireur, propulsion.",
		Axle = "Center",
	},
	{
		Key = "CenterLock", Label = "Central, blocage", Group = "Différentiels",
		Min = 0, Max = 1, Step = 0.05, Default = 0.40, Format = "%.0f %%", Scale = 100,
		Hint = "1 = arbre rigide, comme une vraie Rally2 : motricité maxi, sous-vire en épingle.",
		Axle = "Center",
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
		Hint = "Appui à 100 km/h, en fraction du poids : plus de grip en courbe rapide, mais plus de traînée en ligne droite.",
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
			AntiRollFront = 0.45, AntiRollRear = 0.35, FinalDrive = 3.8,
		},
		Relative = { Downforce = 0.4 },
	},
	{
		-- Asphalte : stabilité et précision, barres raides, rapports longs.
		Name = "Asphalte",
		Values = {
			BrakeBias = 0.68, BrakeForce = 1.0, FrontPowerLock = 0.30, RearPowerLock = 0.40,
			CenterSplit = 0.55, AntiRollFront = 0.75, AntiRollRear = 0.60, FinalDrive = 3.3,
		},
		Relative = { Downforce = 0.85 },
	},
} :: { { Name: string, Values: Setup, Relative: Setup? } }

local BY_KEY: { [string]: Field } = {}
for _, field in ipairs(CarSetup.FIELDS) do
	BY_KEY[field.Key] = field
end

function CarSetup.GetField(key: string): Field?
	return BY_KEY[key]
end

-- Valeurs par défaut d'une catégorie (la Rally2 sans argument).
function CarSetup.Default(classId: string?): Setup
	local setup: Setup = {}
	for _, field in ipairs(CarSetup.FIELDS) do
		setup[field.Key] = field.Default
	end
	for key, value in pairs(CarClasses.Get(classId).Setup) do
		if BY_KEY[key] then
			setup[key] = value
		end
	end
	return setup
end

-- Un réglage tel qu'il est pour cette catégorie (l'appui aéro a sa plage).
local function fieldFor(field: Field, classId: string?): Field
	if field.Key ~= "Downforce" then
		return field
	end
	local range = CarClasses.Get(classId).DownforceRange
	local adjusted = table.clone(field)
	adjusted.Min = range.Min
	adjusted.Max = range.Max
	adjusted.Hint = string.format("%s Plage de cette voiture : %.2f à %.2f.", field.Hint, range.Min, range.Max)
	return adjusted
end

-- Le différentiel `axle` est-il entraîné par cette transmission ?
local function driven(axle: string?, drive: string): boolean
	if axle == nil or drive == "AWD" then
		return true
	end
	return (axle == "Front" and drive == "FWD") or (axle == "Rear" and drive == "RWD")
end

-- Les réglages qui ont un effet sur cette voiture, dans l'ordre du menu.
-- `carId` : la voiture (CarModels.luau), dont la transmission peut différer de la catégorie.
function CarSetup.FieldsFor(classId: string?, carId: string?): { Field }
	local drive = CarClasses.ForCar(classId, carId).Drive
	local fields = {}
	for _, field in ipairs(CarSetup.FIELDS) do
		if driven(field.Axle, drive) then
			table.insert(fields, fieldFor(field, classId))
		end
	end
	return fields
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
function CarSetup.Sanitize(input: any, classId: string?): Setup
	local setup = CarSetup.Default(classId)
	if type(input) ~= "table" then
		return setup
	end
	for _, base in ipairs(CarSetup.FIELDS) do
		local field = fieldFor(base, classId)
		local value = input[field.Key]
		if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
			setup[field.Key] = snap(field, value)
		end
	end
	return setup
end

function CarSetup.Step(setup: Setup, key: string, direction: number, classId: string?): Setup
	local base = BY_KEY[key]
	if not base then
		return setup
	end
	local field = fieldFor(base, classId)
	local copy = table.clone(setup)
	copy[key] = snap(field, (setup[key] or field.Default) + direction * field.Step)
	return copy
end

function CarSetup.WithPreset(name: string, classId: string?): Setup
	local setup = CarSetup.Default(classId)
	for _, preset in ipairs(CarSetup.PRESETS) do
		if preset.Name == name then
			for key, value in pairs(preset.Values) do
				setup[key] = value
			end
			-- Une part de la plage de cette voiture (l'appui aéro).
			for key, share in pairs(preset.Relative or {}) do
				local field = BY_KEY[key]
				if field then
					local adjusted = fieldFor(field, classId)
					setup[key] = adjusted.Min + share * (adjusted.Max - adjusted.Min)
				end
			end
		end
	end
	return CarSetup.Sanitize(setup, classId)
end

return CarSetup
