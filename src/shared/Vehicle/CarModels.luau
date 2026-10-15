--!strict
--[[
	CarModels.luau
	Les VOITURES : huit par catégorie (CarClasses.luau), chacune avec son
	caractère et sa ligne. Noms imaginaires, aucune vraie marque ; leurs
	fiches s'inspirent de ce qui roule (ou a roulé) dans chaque catégorie.

	UNE VOITURE = SA CATÉGORIE + DES RETOUCHES (Tune) : puissance au poids,
	courbe de couple, régimes, rapports, transmission (traction, propulsion,
	4 roues motrices), turbo et anti-lag, pneus, aérodynamique, son moteur
	(SoundBank.TONES), kit de carrosserie. Tout le reste vient de la
	catégorie. Records, classements et médailles restent ceux de la
	catégorie : dans une même catégorie, les voitures ont un caractère
	différent, pas des chronos très différents (quelques pour cent au plus).

	SA LIGNE (Design) : le modèle de carrosserie et ses pièces
	(CarBodies.luau), posés quand le joueur garde « la carrosserie de la
	voiture » (Livery : Body = 0).

	ACCÈS (Items/Cars.luau construit le catalogue à partir d'ici) :
		- trois voitures gratuites par catégorie, prêtes dès le niveau de la
		  catégorie (CLASS_LEVELS) : Rally4 tout de suite, Rally2 au niveau 5,
		  WRC au 12, Groupe B au 20 ;
		- cinq à acheter en crédits (gagnés en jouant) ou en Robux, à tout
		  niveau.
	AJOUTER UNE VOITURE : une entrée ici, à la fin de sa catégorie (l'Id ne
	doit jamais changer : il est sauvegardé dans les profils).
]]

local CarModels = {}

export type Drive = "AWD" | "FWD" | "RWD"
export type Design = { Body: number, Wing: number, Bumper: number, Hood: number, Flares: number }

-- Retouches de la fiche de la catégorie (mêmes noms que CarClasses.Class).
export type Tune = {
	PowerToWeight: number?,
	TorqueCurve: { { rpm: number, torque: number } }?,
	MaxRPM: number?,
	LimiterRPM: number?,
	UpshiftRPM: number?,
	DownshiftRPM: number?,
	LaunchRPM: number?,
	GearRatios: { number }?,
	Drive: Drive?,
	TurboLag: number?,
	TurboShare: number?,
	AntiLag: number?,
	TireGrip: number?,
	DragRatio: number?,
	AeroBalance: number?,
	Engine: string?, -- tonalité du son moteur (SoundBank.TONES)
	Body: string?, -- kit de carrosserie (BodyKits.luau), pour la carrosserie d'origine
}

export type Model = {
	Id: string, -- objet du catalogue
	Class: string, -- catégorie (CarClasses.luau)
	Name: string,
	Description: string, -- court : la boutique
	Story: string, -- ce qui la distingue au volant
	Rarity: string, -- Rarity.luau
	Free: boolean?, -- gratuite (dès le niveau de la catégorie)
	Credits: number?,
	Robux: number?,
	Tune: Tune,
	Design: Design,
}

-- Niveau de pilote qui ouvre les voitures gratuites de chaque catégorie.
CarModels.CLASS_LEVELS = { Rally4 = 1, Rally2 = 5, WRC = 12, GroupB = 20 } :: { [string]: number }

local function design(body: number, wing: number, bumper: number, hood: number, flares: number): Design
	return { Body = body, Wing = wing, Bumper = bumper, Hood = hood, Flares = flares }
end

-- Carrosseries (CarBodies.LIST) : 2 Kaze, 3 Yama, 4 Raijin, 5 Hayate, 6 Hoshi, 7 Tora, 8 Kumo, 9 Ryu,
-- 10 Tsubasa, 11 Requin, 12 Lynx, 13 Griffe, 14 Furia, 15 Blitz.
-- Ailerons : 1 aucun, 2 becquet, 3 rallye, 4 grand, 5 double étage. Boucliers : 1 route, 2 rallye, 3 course.
-- Capots : 1 lisse, 2 prises d'air, 3 écope, 4 rampe de phares. Ailes : 1 d'origine, 2 élargies.

-- Courbes de couple (N·m, forme seulement : Powertrain recale la puissance).
local CURVE_R4_16T = { -- 1.6 turbo 4 cylindres : beaucoup de couple en bas
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 160 }, { rpm = 2200, torque = 320 },
	{ rpm = 4500, torque = 320 }, { rpm = 6200, torque = 230 }, { rpm = 7000, torque = 0 },
}
local CURVE_KITCAR = { -- 2.0 atmosphérique pointu : tout en haut
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 110 }, { rpm = 4000, torque = 190 },
	{ rpm = 6800, torque = 230 }, { rpm = 8200, torque = 200 }, { rpm = 8800, torque = 0 },
}
local CURVE_BOXER = { -- 4 cylindres à plat turbo : coffre au milieu
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 140 }, { rpm = 3000, torque = 620 },
	{ rpm = 5000, torque = 640 }, { rpm = 7000, torque = 380 }, { rpm = 7600, torque = 0 },
}
local CURVE_HYBRID = { -- WRC hybride : le moteur électrique bouche les creux
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 420 }, { rpm = 2500, torque = 700 },
	{ rpm = 6000, torque = 690 }, { rpm = 7600, torque = 500 }, { rpm = 8200, torque = 0 },
}
local CURVE_WRC97 = { -- 2.0 turbo des années 90 : creux en bas, poussée au milieu
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 140 }, { rpm = 3200, torque = 520 },
	{ rpm = 5000, torque = 640 }, { rpm = 6800, torque = 420 }, { rpm = 7400, torque = 0 },
}
local CURVE_SUPERCHARGED = { -- compresseur volumétrique : du couple tout de suite, régulier
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 260 }, { rpm = 2500, torque = 380 },
	{ rpm = 5500, torque = 400 }, { rpm = 7500, torque = 320 }, { rpm = 8000, torque = 0 },
}
local CURVE_V6_ATMO = { -- V6 atmosphérique de course : linéaire, haut perché
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 180 }, { rpm = 3500, torque = 330 },
	{ rpm = 6500, torque = 380 }, { rpm = 8800, torque = 300 }, { rpm = 9300, torque = 0 },
}
local CURVE_FLAT6 = { -- 6 à plat atmosphérique : rond et rageur à la fois
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 200 }, { rpm = 3500, torque = 300 },
	{ rpm = 6000, torque = 330 }, { rpm = 7800, torque = 270 }, { rpm = 8400, torque = 0 },
}
local CURVE_ATMO_4 = { -- gros 4 cylindres atmosphérique : franc en bas, court en haut
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 230 }, { rpm = 3000, torque = 300 },
	{ rpm = 5200, torque = 310 }, { rpm = 6800, torque = 240 }, { rpm = 7300, torque = 0 },
}
local CURVE_MID_TURBO = { -- 1.8 turbo de Groupe B à moteur central : violent passé 4000
	{ rpm = 0, torque = 0 }, { rpm = 1000, torque = 110 }, { rpm = 3200, torque = 220 },
	{ rpm = 4300, torque = 520 }, { rpm = 6800, torque = 520 }, { rpm = 7600, torque = 0 },
}

CarModels.LIST = {
	----------------------------------------------------------------------------
	-- RALLY4 : tractions de 200 ch environ, citadines
	----------------------------------------------------------------------------
	{
		Id = "car_rally4", Class = "Rally4", Name = "Kaze R4", Rarity = "Serie", Free = true,
		Description = "1.2 turbo 3 cylindres, traction, polyvalente",
		Story = "La référence de la catégorie : saine, facile, rien ne la prend en défaut.",
		Tune = {},
		Design = design(2, 2, 1, 1, 1),
	},
	{
		Id = "car_r4_tora", Class = "Rally4", Name = "Tora R4", Rarity = "Serie", Free = true,
		Description = "1.2 turbo, rapports courts, très vive",
		Story = "Petite et nerveuse : relances canon, mais elle plafonne plus tôt en vitesse.",
		Tune = { PowerToWeight = 118, GearRatios = { 3.85, 2.75, 2.1, 1.62, 1.25 }, TireGrip = 0.98 },
		Design = design(7, 2, 2, 1, 1),
	},
	{
		Id = "car_r4_kaze16", Class = "Rally4", Name = "Kaze R4 1.6", Rarity = "Serie", Free = true,
		Description = "1.6 turbo 4 cylindres, du couple en bas",
		Story = "Plus de couple dès les bas régimes, un turbo un peu plus long à souffler.",
		Tune = { PowerToWeight = 119, TorqueCurve = CURVE_R4_16T, TurboLag = 0.38, Engine = "Rally2" },
		Design = design(2, 3, 2, 2, 1),
	},
	{
		Id = "car_r4_sport", Class = "Rally4", Name = "Tora R4 Sport", Rarity = "Club", Credits = 1500, Robux = 49,
		Description = "turbo réactif, aileron rallye",
		Story = "Un turbo plus petit qui répond tout de suite : idéale dans le sinueux.",
		Tune = { PowerToWeight = 121, TurboLag = 0.2, TireGrip = 0.98 },
		Design = design(7, 3, 2, 2, 1),
	},
	{
		Id = "car_r4_evo", Class = "Rally4", Name = "Kaze R4 Evo", Rarity = "Pro", Credits = 2500, Robux = 99,
		Description = "évolution : voies larges, pneus plus tendres",
		Story = "Ailes élargies et gommes tendres : elle tient mieux en courbe rapide.",
		Tune = { PowerToWeight = 121, TireGrip = 0.99, DragRatio = 0.03 },
		Design = design(2, 3, 3, 1, 2),
	},
	{
		Id = "car_r4_turbo", Class = "Rally4", Name = "Tora R4 Gros Turbo", Rarity = "Pro", Credits = 3000, Robux = 99,
		Description = "gros turbo : creux en bas, coup de pied en haut",
		Story = "Il faut l'attendre, puis ça pousse fort : à garder haut dans les tours.",
		Tune = { PowerToWeight = 125, TurboLag = 0.5, TurboShare = 0.45, Engine = "Turbo" },
		Design = design(7, 4, 3, 3, 2),
	},
	{
		Id = "car_r4_light", Class = "Rally4", Name = "Kaze R4 Allégée", Rarity = "Usine", Credits = 4000, Robux = 199,
		Description = "allégée, rapports courts, peu de traînée",
		Story = "Chaque kilo en moins se sent : vive en relance, joueuse au freinage.",
		Tune = { PowerToWeight = 123, GearRatios = { 3.75, 2.65, 2.02, 1.56, 1.2 }, DragRatio = 0.026, TireGrip = 0.98 },
		Design = design(2, 2, 2, 2, 1),
	},
	{
		Id = "car_r4_kitcar", Class = "Rally4", Name = "Tora Kit Car", Rarity = "Prototype", Credits = 6000, Robux = 199,
		Description = "2.0 atmosphérique à 8 500 tr/min, sans turbo",
		Story = "L'esprit des Kit Cars : pas de turbo, un moteur qui hurle et une réponse instantanée.",
		Tune = {
			PowerToWeight = 124, TorqueCurve = CURVE_KITCAR, MaxRPM = 8800, LimiterRPM = 8600, UpshiftRPM = 8200, DownshiftRPM = 5200,
			LaunchRPM = 5500, GearRatios = { 3.3, 2.4, 1.86, 1.47, 1.17 }, TurboLag = 0, TurboShare = 0, Engine = "Screamer",
		},
		Design = design(7, 4, 3, 2, 2),
	},

	----------------------------------------------------------------------------
	-- RALLY2 : 4 roues motrices, 1.6 turbo, 290 ch environ
	----------------------------------------------------------------------------
	{
		Id = "car_rally2", Class = "Rally2", Name = "Hayate R2", Rarity = "Serie", Free = true,
		Description = "4 roues motrices, 1.6 turbo, anti-lag",
		Story = "La berline de référence : équilibrée, efficace partout.",
		Tune = {},
		Design = design(5, 3, 2, 1, 1),
	},
	{
		Id = "car_r2_kaze", Class = "Rally2", Name = "Kaze R2", Rarity = "Serie", Free = true,
		Description = "citadine 4 roues motrices, empattement court",
		Story = "Courte et vive : elle pivote facilement dans les épingles, un peu moins stable à fond.",
		Tune = { GearRatios = { 4.55, 3.3, 2.52, 2.0, 1.62, 1.33 }, AeroBalance = 0.56 },
		Design = design(2, 3, 2, 1, 2),
	},
	{
		Id = "car_r2_hoshi", Class = "Rally2", Name = "Hoshi R2", Rarity = "Serie", Free = true,
		Description = "berline à phares ronds, très stable",
		Story = "Lourde de l'avant et rassurante : elle pardonne beaucoup, pivote moins.",
		Tune = { AeroBalance = 0.64, TireGrip = 1.0, TurboLag = 0.4 },
		Design = design(6, 4, 2, 1, 1),
	},
	{
		Id = "car_r2_tora", Class = "Rally2", Name = "Tora R2", Rarity = "Club", Credits = 3000, Robux = 99,
		Description = "la plus compacte, pneus tendres",
		Story = "Toute petite pour une 4 roues motrices : grip en courbe, nerveuse.",
		Tune = { TireGrip = 1.01, PowerToWeight = 149, GearRatios = { 4.5, 3.25, 2.48, 1.98, 1.6, 1.32 } },
		Design = design(7, 3, 2, 2, 2),
	},
	{
		Id = "car_r2_heritage", Class = "Rally2", Name = "Yama R2 Héritage", Rarity = "Pro", Credits = 4000, Robux = 99,
		Description = "ligne des années 70, mécanique moderne",
		Story = "Une berline d'autrefois sur une base de Rally2 : un peu moins fine en aéro, très efficace.",
		Tune = { PowerToWeight = 152, DragRatio = 0.033, TurboLag = 0.3 },
		Design = design(3, 3, 2, 2, 2),
	},
	{
		Id = "car_r2_boxer", Class = "Rally2", Name = "Hoshi R2 Boxer", Rarity = "Usine", Credits = 6000, Robux = 199,
		Description = "4 cylindres à plat, gros couple au milieu",
		Story = "Le grondement du boxer et un couple énorme au milieu des tours : idéale sur la terre.",
		Tune = { PowerToWeight = 151, TorqueCurve = CURVE_BOXER, TurboLag = 0.45, Engine = "Boxer" },
		Design = design(6, 4, 2, 3, 2),
	},
	{
		Id = "car_r2_evo", Class = "Rally2", Name = "Hayate R2 Evo", Rarity = "Usine", Credits = 7000, Robux = 199,
		Description = "évolution aéro : plus d'appui, plus de traînée",
		Story = "Lame et aileron revus : collée au sol en courbe rapide, un peu moins vite en ligne droite.",
		Tune = { PowerToWeight = 153, AeroBalance = 0.58, DragRatio = 0.034, TireGrip = 1.01 },
		Design = design(5, 4, 3, 2, 2),
	},
	{
		Id = "car_r2_maxi", Class = "Rally2", Name = "Kaze R2 Maxi", Rarity = "Prototype", Credits = 9000, Robux = 199,
		Description = "la plus poussée : moteur et châssis affûtés",
		Story = "Tout est réglé à la limite : la plus rapide de la catégorie, et la plus exigeante.",
		Tune = { PowerToWeight = 155, TireGrip = 1.01, TurboLag = 0.3, Engine = "Turbo" },
		Design = design(2, 5, 3, 3, 2),
	},

	----------------------------------------------------------------------------
	-- WRC : les voitures d'usine, 380 ch et plus, gros appui
	----------------------------------------------------------------------------
	{
		Id = "car_wrc", Class = "WRC", Name = "Kaze WRC", Rarity = "Usine", Free = true,
		Description = "4 roues motrices, 380 ch, gros appui aéro",
		Story = "La voiture d'usine de référence : appui maximal, anti-lag complet.",
		Tune = {},
		Design = design(2, 4, 3, 2, 2),
	},
	{
		Id = "car_wrc_hayate", Class = "WRC", Name = "Hayate WRC", Rarity = "Usine", Free = true,
		Description = "berline WRC, empattement long, très stable",
		Story = "Plus longue : imperturbable à haute vitesse, moins agile dans le serré.",
		Tune = { AeroBalance = 0.6, TireGrip = 1.04, PowerToWeight = 198 },
		Design = design(5, 4, 3, 2, 2),
	},
	{
		Id = "car_wrc_boxer", Class = "WRC", Name = "Hoshi WRC", Rarity = "Usine", Free = true,
		Description = "boxer 2.0 turbo, gros couple",
		Story = "Le son du boxer et du couple partout : la plus facile à exploiter sur la terre.",
		Tune = { TorqueCurve = CURVE_BOXER, Engine = "Boxer", PowerToWeight = 199 },
		Design = design(6, 4, 2, 3, 2),
	},
	{
		Id = "car_wrc_tora", Class = "WRC", Name = "Tora WRC", Rarity = "Prototype", Credits = 6000, Robux = 199,
		Description = "la plus courte, rapports serrés",
		Story = "Une citadine avec un moteur de WRC : explosive en relance, vive à placer.",
		Tune = { GearRatios = { 4.4, 3.2, 2.52, 2.05, 1.7, 1.42 }, AeroBalance = 0.53 },
		Design = design(7, 4, 3, 2, 2),
	},
	{
		Id = "car_wrc_97", Class = "WRC", Name = "Hoshi WRC 97", Rarity = "Prototype", Credits = 7000, Robux = 199,
		Description = "WRC des années 90 : 2.0 turbo, moins d'appui",
		Story = "Un turbo qu'on sent arriver et moins d'aéro : spectaculaire, plus physique à piloter.",
		Tune = { TorqueCurve = CURVE_WRC97, TurboLag = 0.5, TurboShare = 0.4, AntiLag = 0.9, DragRatio = 0.032, PowerToWeight = 196, Engine = "Boxer" },
		Design = design(6, 4, 2, 4, 1),
	},
	{
		Id = "car_wrc_tarmac", Class = "WRC", Name = "Hayate WRC Asphalte", Rarity = "Prototype", Credits = 8000, Robux = 399,
		Description = "spécial asphalte : appui renforcé, pneus tendres",
		Story = "Taillée pour le bitume : un grip phénoménal en courbe, un peu de traînée en plus.",
		Tune = { TireGrip = 1.05, DragRatio = 0.039, AeroBalance = 0.56 },
		Design = design(5, 5, 3, 1, 2),
	},
	{
		Id = "car_wrc_hybrid", Class = "WRC", Name = "Kaze WRC Hybride", Rarity = "Legende", Credits = 11000, Robux = 399,
		Description = "turbo et moteur électrique : 500 ch en sortie de virage",
		Story = "Le coup de pouce électrique efface tout temps de réponse : brutale à la réaccélération.",
		Tune = { TorqueCurve = CURVE_HYBRID, PowerToWeight = 206, TurboLag = 0, TireGrip = 1.02, Engine = "WRC" },
		Design = design(2, 5, 3, 3, 2),
	},
	{
		Id = "car_wrc_plus", Class = "WRC", Name = "Tora WRC Plus", Rarity = "Legende", Credits = 13000, Robux = 399,
		Description = "évolution ultime : tout au maximum",
		Story = "La plus aboutie des WRC : rapide partout, réservée aux pilotes précis.",
		Tune = { PowerToWeight = 205, TireGrip = 1.04, TurboLag = 0.3 },
		Design = design(7, 5, 3, 3, 2),
	},

	----------------------------------------------------------------------------
	-- GROUPE B : les monstres des années 80
	----------------------------------------------------------------------------
	{
		Id = "car_groupb", Class = "GroupB", Name = "Raijin B", Rarity = "Legende", Free = true,
		Description = "5 cylindres turbo, 4 roues motrices, lourde de l'avant",
		Story = "Le monstre à 5 cylindres : une poussée énorme, un nez lourd qui sous-vire.",
		Tune = { Engine = "Legend", AeroBalance = 0.68 },
		Design = design(4, 5, 2, 2, 1),
	},
	{
		Id = "car_gb_kumo", Class = "GroupB", Name = "Kumo B", Rarity = "Legende", Free = true,
		Description = "moteur central, 4 roues motrices, courte",
		Story = "Moteur derrière les sièges : elle pivote sur place, et le turbo arrive d'un coup.",
		Tune = { TorqueCurve = CURVE_MID_TURBO, PowerToWeight = 236, TurboLag = 0.55, AeroBalance = 0.62, Engine = "GroupB" },
		Design = design(8, 4, 2, 1, 1),
	},
	{
		Id = "car_gb_ryu", Class = "GroupB", Name = "Ryu B", Rarity = "Legende", Free = true,
		Description = "propulsion, compresseur : aucun temps de réponse",
		Story = "Deux roues motrices seulement, mais un compresseur qui pousse tout de suite : de la glisse à volonté.",
		Tune = {
			Drive = "RWD", TorqueCurve = CURVE_SUPERCHARGED, PowerToWeight = 210, TurboLag = 0, TurboShare = 0,
			AntiLag = 0, TireGrip = 0.97, Engine = "Turbo",
		},
		Design = design(9, 4, 2, 2, 1),
	},
	{
		Id = "car_gb_yama", Class = "GroupB", Name = "Yama B 400", Rarity = "Prototype", Credits = 6000, Robux = 199,
		Description = "propulsion, gros 4 cylindres atmosphérique",
		Story = "La propulsion à l'ancienne : un moteur franc, de la glisse, et du doigté.",
		Tune = {
			Drive = "RWD", TorqueCurve = CURVE_ATMO_4, PowerToWeight = 200, MaxRPM = 7300, LimiterRPM = 7100, UpshiftRPM = 6700,
			DownshiftRPM = 4000, TurboLag = 0, TurboShare = 0, AntiLag = 0, TireGrip = 0.97, Engine = "Vintage",
		},
		Design = design(3, 2, 2, 4, 2),
	},
	{
		Id = "car_gb_v6", Class = "GroupB", Name = "Tora B V6", Rarity = "Prototype", Credits = 9000, Robux = 199,
		Description = "V6 atmosphérique central, 4 roues motrices",
		Story = "Pas de turbo : une réponse parfaite et un V6 qui chante jusqu'à 9 000 tr/min.",
		Tune = {
			TorqueCurve = CURVE_V6_ATMO, PowerToWeight = 228, MaxRPM = 9300, LimiterRPM = 9100, UpshiftRPM = 8700, DownshiftRPM = 5500,
			TurboLag = 0, TurboShare = 0, AntiLag = 0, AeroBalance = 0.6, Engine = "Sport",
		},
		Design = design(7, 5, 3, 3, 2),
	},
	{
		Id = "car_gb_flat6", Class = "GroupB", Name = "Ryu B Flat-6", Rarity = "Prototype", Credits = 10000, Robux = 399,
		Description = "propulsion, 6 cylindres à plat, moteur en porte-à-faux",
		Story = "Tout le poids sur l'arrière : une motricité étonnante, et un arrière qui ne demande qu'à passer.",
		Tune = {
			Drive = "RWD", TorqueCurve = CURVE_FLAT6, PowerToWeight = 205, MaxRPM = 8400, LimiterRPM = 8200, UpshiftRPM = 7800,
			DownshiftRPM = 4800, TurboLag = 0, TurboShare = 0, AntiLag = 0, AeroBalance = 0.72, TireGrip = 0.98, Engine = "Screamer",
		},
		Design = design(9, 3, 2, 4, 1),
	},
	{
		Id = "car_gb_twin", Class = "GroupB", Name = "Hayate B Twincharge", Rarity = "Legende", Credits = 13000, Robux = 399,
		Description = "turbo et compresseur, 4 roues motrices",
		Story = "Le compresseur en bas, le turbo en haut : la poussée ne s'arrête jamais.",
		Tune = { TurboLag = 0.25, TurboShare = 0.3, PowerToWeight = 244, TireGrip = 0.96 },
		Design = design(5, 5, 2, 3, 2),
	},
	{
		Id = "car_gb_evo2", Class = "GroupB", Name = "Kumo B Evo 2", Rarity = "Legende", Credits = 15000, Robux = 399,
		Description = "moteur central, évolution ultime, énorme aileron",
		Story = "La plus folle : un turbo à retardement monstrueux et un aileron double pour la tenir.",
		Tune = { TorqueCurve = CURVE_MID_TURBO, PowerToWeight = 250, TurboLag = 0.65, TurboShare = 0.5, AeroBalance = 0.6, DragRatio = 0.036, Engine = "Legend" },
		Design = design(8, 5, 3, 3, 1),
	},
} :: { Model }

local byId: { [string]: Model } = {}
for _, model in ipairs(CarModels.LIST) do
	assert(byId[model.Id] == nil, "voiture en double : " .. model.Id)
	byId[model.Id] = model
end

function CarModels.Get(id: any): Model?
	return if type(id) == "string" then byId[id] else nil
end

-- Les voitures d'une catégorie, dans l'ordre.
function CarModels.OfClass(classId: string): { Model }
	local list = {}
	for _, model in ipairs(CarModels.LIST) do
		if model.Class == classId then
			table.insert(list, model)
		end
	end
	return list
end

-- La voiture de référence d'une catégorie (la première, gratuite) : celle
-- qu'on prête à qui n'a aucune voiture de la catégorie.
function CarModels.Reference(classId: string): Model?
	return CarModels.OfClass(classId)[1]
end

-- Niveau qui ouvre une voiture gratuite (nil : achetée, sans condition de niveau).
function CarModels.LevelOf(model: Model): number?
	return if model.Free then CarModels.CLASS_LEVELS[model.Class] or 1 else nil
end

return CarModels
