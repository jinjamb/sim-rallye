--!strict
--[[
	CarClasses.luau
	Les catégories de voitures : une fiche technique chacune, lue par la
	physique (Car, Powertrain, Gearbox), le son, la carrosserie (BodyKits),
	les médailles et les classements.

	Toutes partagent le même gabarit physique (masse, suspension, géométrie :
	Car.luau se recale sur la masse). Ce qui les distingue : la puissance
	ramenée au poids, la forme de la courbe de couple, le turbo, la boîte, la
	transmission (traction ou 4 roues motrices) et les pneus.

		Rally4    traction, ~210 ch : agile, facile, mais il faut la placer
		          avant le virage (pas de motricité arrière pour pivoter).
		Rally2    la référence : 4 roues motrices, ~290 ch.
		Groupe B  la légende des années 80 : 4 roues motrices, ~500 ch, un
		          turbo qui met du temps à souffler, des pneus moins
		          accrocheurs. Brutale.

	CLASSEMENTS ÉQUITABLES : records, fantômes, médailles et classements sont
	propres à chaque catégorie (RecordKey). La Rally2 garde les clés d'avant
	les catégories (suffixe vide) : les temps déjà enregistrés restent les
	siens.

	PUISSANCE : voir Powertrain.luau (la courbe en N·m est recalée pour que
	sa puissance maximale, ramenée à la masse, vaille PowerToWeight).
	MÉDAILLES : les vitesses moyennes de Medals.luau sont celles de la
	Rally2 ; MedalScale les adapte (à calibrer en roulant : la sortie de
	Studio affiche la vitesse moyenne de chaque temps validé).
]]

local CarClasses = {}

export type Drive = "AWD" | "FWD"
export type TorquePoint = { rpm: number, torque: number }

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
	TireGrip: number, -- adhérence des pneus (1 = Rally2)
	MedalScale: number, -- vitesses des médailles, relatives à la Rally2
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
		TurboLag = 0,
		TurboShare = 0,
		TireGrip = 0.97,
		MedalScale = 0.9,
		Setup = { FinalDrive = 3.4, Downforce = 0.14, BrakeBias = 0.62, SteerAngle = 47 },
		Engine = "Rally4",
		Body = "Rally4",
		RecordSuffix = "_r4",
	},
	{
		Id = "Rally2",
		Name = "Rally2",
		Description = "4 roues motrices, 290 ch. La référence, équilibrée.",
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
		TurboLag = 0,
		TurboShare = 0,
		TireGrip = 1,
		MedalScale = 1,
		Setup = {},
		Engine = "Rally2",
		Body = "Rally2",
		RecordSuffix = "",
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
		TireGrip = 0.95,
		MedalScale = 1.12,
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

function CarClasses.Exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

-- Clé d'un record de cette catégorie (spéciale, circuit, classement).
function CarClasses.RecordKey(base: string, id: string): string
	return base .. CarClasses.Get(id).RecordSuffix
end

return CarClasses
