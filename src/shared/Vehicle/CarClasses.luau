--!strict
--[[
	CarClasses.luau
	Les catégories de voitures : une fiche technique chacune, lue par la
	physique (Car, Powertrain, Gearbox), le son, la carrosserie (BodyKits),
	les médailles et les classements.

	Toutes partagent le même gabarit physique (masse, suspension, géométrie :
	Car.luau se recale sur la masse). Ce qui les distingue : la puissance
	ramenée au poids, la forme de la courbe de couple, le turbo, la boîte, la
	transmission (traction ou 4 roues motrices), les pneus et l'aérodynamique.

	LA GAMME, dans l'ordre de la carrière (Items/Cars.luau) :
		Rally4    la voiture de série : traction, ~210 ch, petit turbo sans
		          anti-lag. Agile, facile,
		          mais il faut la placer avant le virage (pas de motricité
		          arrière pour pivoter).
		Rally2    la référence : 4 roues motrices, ~290 ch, anti-lag.
		WRC       la voiture d'usine : 4 roues motrices, ~380 ch, anti-lag
		          complet (le turbo ne retombe jamais), boîte courte, gros
		          appui aéro. Très
		          rapide partout, exigeante à haute vitesse.
		Groupe B  la légende des années 80 : 4 roues motrices, ~500 ch, un
		          turbo qui met du temps à souffler, des pneus moins
		          accrocheurs, peu d'appui. Brutale.

	AÉRODYNAMIQUE (Aerodynamics.luau) : chaque catégorie a sa traînée
	(DragRatio) et sa répartition d'appui (AeroBalance) ; la quantité d'appui
	est un réglage (Downforce, CarSetup.luau) dont la valeur de série est
	dans Setup et la plage dans DownforceRange : un simple becquet de
	Rally4 ne donne pas l'appui des grands ailerons d'une WRC. L'appui ajoute de la charge sur les pneus, donc de
	l'adhérence, d'autant plus qu'on va vite.

	VOITURES (CarModels.luau) : huit par catégorie, chacune une retouche de
	cette fiche (ForCar) ; la catégorie garde les records et les médailles.

	CLASSEMENTS ÉQUITABLES : records, fantômes, médailles et classements sont
	propres à chaque catégorie (RecordKey). La Rally2 garde les clés d'avant
	les catégories (suffixe vide) : les temps déjà enregistrés restent les
	siens.

	PUISSANCE : voir Powertrain.luau (la courbe en N·m est recalée pour que
	sa puissance maximale, ramenée à la masse, vaille PowerToWeight).
	MÉDAILLES : les vitesses moyennes de Medals.luau sont celles de la
	Rally2 ; MedalScale les adapte, PAR SURFACE (une traction souffre sur
	la neige, l'appui d'une WRC paie sur l'asphalte rapide, la puissance
	d'un Groupe B sur la terre) et pour les circuits. Valeurs estimées
	d'après la fiche (puissance au poids, pneus, appui, turbo), à recaler
	en roulant : dans Studio, _G.MedalReport() (MedalCalibration.luau)
	donne les valeurs mesurées.
]]

local CarModels = require(script.Parent.CarModels)

local CarClasses = {}

export type Drive = "AWD" | "FWD" | "RWD" -- RWD : propulsion (certaines Groupe B)
export type TorquePoint = { rpm: number, torque: number }
-- Par surface de spéciale (StageTrack : Surface), et pour les circuits.
export type MedalScale = { Tarmac: number, Gravel: number, Snow: number, Mixed: number, Circuit: number }

export type Class = {
	Id: string,
	Name: string,
	Description: string,
	Drive: Drive,
	PowerToWeight: number, -- W/kg (Powertrain.luau)
	TorqueCurve: { TorquePoint }, -- N·m, forme seulement
	IdleRPM: number,
	MaxRPM: number,
	LimiterRPM: number,
	LaunchRPM: number, -- plancher d'embrayage à fond, au départ arrêté
	GearRatios: { number },
	ReverseRatio: number,
	UpshiftRPM: number, -- boîte auto et LED de passage
	DownshiftRPM: number,
	-- Turbo : la part TurboShare du couple attend que la pression monte, en
	-- TurboLag secondes (0 : réponse immédiate, anti-lag moderne).
	TurboLag: number,
	TurboShare: number,
	-- Anti-lag (0..1) : pression du turbo gardée pied levé (au-dessus de
	-- 3 000 tr/min). 0 : le turbo retombe, il faut attendre qu'il reparte.
	-- L'échappement crépite et crache des flammes (Driving/Exhaust.luau).
	AntiLag: number,
	TireGrip: number, -- adhérence des pneus (1 = Rally2)
	DragRatio: number, -- traînée à 100 km/h, en fraction du poids (Aerodynamics.luau)
	AeroBalance: number, -- part de l'appui sur l'arrière (0.5 : neutre ; plus : stable)
	-- Plage du réglage d'appui (CarSetup : Downforce), propre à la voiture : ce
	-- que ses ailerons peuvent donner, du plus plat au plus braqué.
	DownforceRange: { Min: number, Max: number },
	MedalScale: MedalScale, -- vitesses des médailles, relatives à la Rally2
	Setup: { [string]: number }, -- réglages par défaut propres (CarSetup.luau)
	Engine: string, -- son moteur de série (SoundBank.luau)
	Body: string, -- kit de carrosserie (BodyKits.luau)
	RecordSuffix: string, -- ajouté aux clés des records ("" : Rally2)
}

CarClasses.DEFAULT = "Rally2"

local LIST: { Class } = {
	{
		Id = "Rally4",
		Name = "Rally4",
		Description = "Traction, 210 ch. Agile et facile : place-la avant le virage.",
		Drive = "FWD",
		PowerToWeight = 120,
		-- 1.2 turbo 3 cylindres : du couple tôt, à plat, qui s'essouffle en haut.
		TorqueCurve = {
			{ rpm = 0, torque = 0 },
			{ rpm = 1000, torque = 130 },
			{ rpm = 2500, torque = 290 },
			{ rpm = 4500, torque = 300 },
			{ rpm = 6000, torque = 240 },
			{ rpm = 7000, torque = 0 },
		},
		IdleRPM = 1000,
		MaxRPM = 7000,
		LimiterRPM = 6800,
		LaunchRPM = 4000,
		-- 5 rapports. Au rupteur (pont 3.4, roue de 1 stud) : 58 | 82 | 107 | 140 | 182.
		GearRatios = { 3.6, 2.55, 1.95, 1.5, 1.15 },
		ReverseRatio = 3.5,
		UpshiftRPM = 6300,
		DownshiftRPM = 3000,
		TurboLag = 0.3, -- petit turbo : un léger temps de réponse
		TurboShare = 0.3,
		AntiLag = 0, -- pas d'anti-lag en Rally4
		TireGrip = 0.97,
		DragRatio = 0.028, -- petite voiture, simple becquet
		AeroBalance = 0.55,
		DownforceRange = { Min = 0, Max = 0.18 },
		-- Moins de puissance, traction : la neige la ralentit le plus.
		MedalScale = { Tarmac = 0.89, Gravel = 0.88, Snow = 0.85, Mixed = 0.88, Circuit = 0.9 },
		Setup = { FinalDrive = 3.4, Downforce = 0.14, BrakeBias = 0.62, SteerAngle = 47 },
		Engine = "Rally4",
		Body = "Rally4",
		RecordSuffix = "_r4",
	},
	{
		Id = "Rally2",
		Name = "Rally2",
		Description = "4 roues motrices, 290 ch, anti-lag. La référence, équilibrée.",
		Drive = "AWD",
		PowerToWeight = 150,
		TorqueCurve = {
			{ rpm = 0, torque = 0 },
			{ rpm = 1000, torque = 150 },
			{ rpm = 3500, torque = 600 },
			{ rpm = 5500, torque = 650 },
			{ rpm = 7500, torque = 400 },
			{ rpm = 8000, torque = 0 },
		},
		IdleRPM = 1000,
		MaxRPM = 8000,
		LimiterRPM = 7800,
		LaunchRPM = 4500,
		-- Au rupteur (pont 3.5, roue de 1 stud) : 54 | 75 | 98 | 123 | 152 | 184.
		GearRatios = { 4.40, 3.20, 2.45, 1.95, 1.58, 1.30 },
		ReverseRatio = 3.80,
		UpshiftRPM = 6800,
		DownshiftRPM = 3500,
		TurboLag = 0.35,
		TurboShare = 0.3,
		AntiLag = 0.85,
		TireGrip = 1,
		DragRatio = 0.03,
		AeroBalance = 0.6,
		DownforceRange = { Min = 0.04, Max = 0.3 },
		MedalScale = { Tarmac = 1, Gravel = 1, Snow = 1, Mixed = 1, Circuit = 1 },
		Setup = {},
		Engine = "Rally2",
		Body = "Rally2",
		RecordSuffix = "",
	},
	{
		Id = "WRC",
		Name = "WRC",
		Description = "4 roues motrices, 380 ch, gros appui aéro. La voiture d'usine.",
		Drive = "AWD",
		PowerToWeight = 200,
		-- 1.6 turbo bridé, anti-lag : un plateau de couple énorme, de 3000 à 6000.
		TorqueCurve = {
			{ rpm = 0, torque = 0 },
			{ rpm = 1000, torque = 220 },
			{ rpm = 3000, torque = 640 },
			{ rpm = 6000, torque = 660 },
			{ rpm = 7600, torque = 470 },
			{ rpm = 8200, torque = 0 },
		},
		IdleRPM = 1000,
		MaxRPM = 8200,
		LimiterRPM = 8000,
		LaunchRPM = 5000,
		-- 6 rapports courts. Au rupteur (pont 3.6, roue de 1 stud) : 57 | 78 | 99 | 122 | 146 | 174.
		GearRatios = { 4.20, 3.05, 2.40, 1.95, 1.62, 1.36 },
		ReverseRatio = 3.80,
		UpshiftRPM = 7300,
		DownshiftRPM = 4000,
		TurboLag = 0.35,
		TurboShare = 0.35,
		AntiLag = 1, -- anti-lag complet : le turbo ne retombe jamais
		TireGrip = 1.03,
		DragRatio = 0.036, -- grands ailerons, lame avant, ailes ouvertes : l'appui se paie
		AeroBalance = 0.55, -- lame et canards à l'avant : l'avant mord à haute vitesse
		DownforceRange = { Min = 0.12, Max = 0.42 }, -- même au plus plat, ses ailerons appuient
		-- L'appui et l'anti-lag paient surtout sur l'asphalte rapide.
		MedalScale = { Tarmac = 1.11, Gravel = 1.08, Snow = 1.05, Mixed = 1.09, Circuit = 1.08 },
		Setup = { FinalDrive = 3.6, Downforce = 0.32, BrakeForce = 0.95, CenterLock = 0.5 },
		Engine = "WRC",
		Body = "WRC",
		RecordSuffix = "_wrc",
	},
	{
		Id = "GroupB",
		Name = "Groupe B",
		Description = "4 roues motrices, 500 ch, turbo à retardement. Brutale.",
		Drive = "AWD",
		PowerToWeight = 240,
		-- Turbo des années 80 : presque rien en bas, une avalanche au-dessus de 4500.
		TorqueCurve = {
			{ rpm = 0, torque = 0 },
			{ rpm = 1000, torque = 120 },
			{ rpm = 3000, torque = 230 },
			{ rpm = 4500, torque = 500 },
			{ rpm = 6500, torque = 540 },
			{ rpm = 7800, torque = 380 },
			{ rpm = 8200, torque = 0 },
		},
		IdleRPM = 1100,
		MaxRPM = 8200,
		LimiterRPM = 8000,
		LaunchRPM = 5000,
		-- 5 rapports longs. Au rupteur (pont 3.2, roue de 1 stud) : 75 | 105 | 134 | 169 | 206.
		GearRatios = { 3.5, 2.5, 1.95, 1.55, 1.27 },
		ReverseRatio = 3.6,
		UpshiftRPM = 7400,
		DownshiftRPM = 4300,
		TurboLag = 0.6,
		TurboShare = 0.45,
		AntiLag = 0.5, -- un anti-lag des débuts : il aide, sans effacer le retard
		TireGrip = 0.95,
		DragRatio = 0.033, -- aileron double étage, mais carrosserie des années 80
		AeroBalance = 0.65, -- appui surtout à l'arrière : l'avant se déleste à haute vitesse
		DownforceRange = { Min = 0, Max = 0.16 },
		-- La puissance paie sur la terre ; peu d'appui et pneus moins bons sur l'asphalte.
		MedalScale = { Tarmac = 1.07, Gravel = 1.11, Snow = 1.04, Mixed = 1.09, Circuit = 1.1 },
		Setup = { FinalDrive = 3.2, Downforce = 0.08, CenterSplit = 0.65, BrakeForce = 0.8 },
		Engine = "GroupB",
		Body = "GroupB",
		RecordSuffix = "_gb",
	},
}

CarClasses.LIST = LIST

local byId: { [string]: Class } = {}
for _, class in ipairs(LIST) do
	byId[class.Id] = class
end

-- La catégorie demandée, ou la Rally2 si l'identifiant est inconnu.
function CarClasses.Get(id: any): Class
	return byId[if type(id) == "string" then id else CarClasses.DEFAULT] or byId[CarClasses.DEFAULT]
end

--[[
	La fiche d'une VOITURE (CarModels.luau) : celle de sa catégorie, retouchée
	(puissance, couple, rapports, transmission, turbo, pneus, aéro, son). Sans
	voiture connue, ou d'une autre catégorie : la fiche de la catégorie.
]]
local carCache: { [string]: Class } = {}
function CarClasses.ForCar(classId: any, carId: any): Class
	local class = CarClasses.Get(classId)
	local model = CarModels.Get(carId)
	if not model or model.Class ~= class.Id then
		return class
	end
	local cached = carCache[model.Id]
	if cached then
		return cached
	end
	local merged = table.clone(class) :: any
	for key, value in pairs(model.Tune) do
		merged[key] = value
	end
	carCache[model.Id] = merged
	return merged
end

function CarClasses.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

-- Clé d'un record de cette catégorie (spéciale, circuit, classement).
function CarClasses.RecordKey(base: string, id: string): string
	return base .. CarClasses.Get(id).RecordSuffix
end

return CarClasses
