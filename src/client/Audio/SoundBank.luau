--!strict
--[[
	SoundBank.luau
	Tous les identifiants audio du jeu, en un seul endroit. Changer de moteur,
	c'est remplacer une liste ici : CarAudio.luau ne contient aucun ID.

	MOTEUR : des enregistrements (RECORDINGS) et des tonalités qui les
	traitent (TONES, voir plus bas). Un enregistrement est une série
	d'échantillons BOUCLÉS, chacun enregistré à régime
	stabilisé, en deux familles :
		OnLoad  : moteur qui pousse (accélérateur enfoncé) -- son plein, rauque ;
		OffLoad : moteur entraîné (pied levé, frein moteur) -- son creux, qui pétille.
	CarAudio joue les deux échantillons qui encadrent le régime actuel, fondus
	l'un dans l'autre et accélérés/ralentis pour coller au régime exact, puis
	mélange les deux familles selon la charge. Plus les échantillons sont
	serrés, moins on entend la transposition (au-delà de ~1.3x, le son
	devient "dessin animé").
	Rpm DOIT être le régime auquel l'échantillon a été enregistré : sur les séries
	du Creator Store, c'est en général le nombre à la fin du nom.

	Tous les sons viennent du Creator Store (le V8 LS3 : relevé le
	2026-10-03). Pour en tester d'autres : create.roblox.com/store/audio,
	chercher "engacc", "engdec", "eng on", "eng off", ou un nom de moteur.
]]

local SoundBank = {}

-- Volume général de la voiture (moteur + pneus), appliqué par un SoundGroup :
-- c'est LE réglage à toucher si l'ensemble est trop fort ou trop faible.
-- Les volumes individuels ci-dessous et dans CarAudio.luau règlent l'équilibre.
SoundBank.MasterVolume = 0.5

export type EngineSample = {
	Id: string,
	Rpm: number,
}

export type EngineProfile = {
	Name: string,
	OnLoad: { EngineSample },
	OffLoad: { EngineSample },
	Volume: number,
}

--[[
	TONALITÉS : un enregistrement (EngineProfile) passé par un traitement --
	transposition (PitchScale : plus aigu = un moteur plus petit qui tourne
	plus vite), égaliseur (dB : graves, médiums, aigus) et distorsion
	(0..1 : la rocaille d'un échappement libre). Chaque catégorie de voiture
	a la sienne (CarClasses.luau : Engine), et les sons moteur à débloquer
	(Items/Engines.luau) en sont d'autres.
	Chaque tonalité cite son enregistrement (Recording). Un enregistrement
	pas encore branché (série vide, voir STORE) est remplacé par le V8
	(LS3), transposé de FallbackPitch.
]]
export type EngineTone = {
	Recording: string,
	PitchScale: number,
	FallbackPitch: number, -- transposition du V8 tant que l'enregistrement manque
	Low: number,
	Mid: number,
	High: number,
	Distortion: number,
	Volume: number, -- multiplie le volume de l'enregistrement
}

local function id(assetId: number): string
	return "rbxassetid://" .. tostring(assetId)
end

--[[
	PROVISOIRE : Chevrolet LS3, un V8 -- sonorité de muscle car, pas de
	4 cylindres turbo de rallye. Retenu parce que c'est la série la plus
	complète trouvée (8 régimes à charge, 9 hors charge), ce qui permet de
	valider toute la mécanique de mixage. À remplacer par une série de
	4 cylindres dès qu'on en trouve une aussi complète.
]]
local LS3: EngineProfile = {
	Name = "LS3 (V8, provisoire)",
	Volume = 0.4,
	OnLoad = {
		{ Id = id(72216435285754), Rpm = 1272 },
		{ Id = id(94008428404294), Rpm = 1822 },
		{ Id = id(71409334425969), Rpm = 2611 },
		{ Id = id(78094824557081), Rpm = 3402 },
		{ Id = id(100659229161899), Rpm = 4201 },
		{ Id = id(71537655941923), Rpm = 5008 },
		{ Id = id(134186940990232), Rpm = 5800 },
		{ Id = id(115519256988247), Rpm = 6575 },
	},
	OffLoad = {
		{ Id = id(114429516081468), Rpm = 750 },
		{ Id = id(111780808549049), Rpm = 1220 },
		{ Id = id(80826058525589), Rpm = 2012 },
		{ Id = id(82569864411746), Rpm = 2809 },
		{ Id = id(97985325574914), Rpm = 3408 },
		{ Id = id(91503589306067), Rpm = 4201 },
		{ Id = id(75921633907206), Rpm = 5008 },
		{ Id = id(102002975670312), Rpm = 5806 },
		{ Id = id(113687997502918), Rpm = 6260 },
	},
}

--[[
	MOTEURS À BRANCHER (Creator Store) : une série par type de moteur, à
	remplir comme LS3 ci-dessus : pour chaque échantillon, son identifiant
	et le régime auquel il a été enregistré (le nombre à la fin du nom, en
	général). Au moins deux échantillons par famille ; plus ils sont serrés,
	plus le son est naturel. Une série vide est remplacée par le V8,
	transposé (FallbackPitch de la tonalité).
	Où chercher : create.roblox.com/store/audio, « engacc » / « engdec »,
	« eng on » / « eng off », ou le nom d'un moteur (« 4 cylinder »,
	« boxer », « rotary », « inline 5 »...).
]]
local function series(name: string, volume: number, onLoad: { EngineSample }, offLoad: { EngineSample }): EngineProfile
	return { Name = name, Volume = volume, OnLoad = onLoad, OffLoad = offLoad }
end

local STORE: { [string]: EngineProfile } = {
	I3 = series("3 cylindres turbo (Rally4)", 0.4, {}, {}),
	I4 = series("4 cylindres turbo (Rally2)", 0.4, {}, {}),
	I4R = series("4 cylindres anti-lag (WRC)", 0.4, {}, {}),
	I5 = series("5 cylindres turbo (Groupe B)", 0.4, {}, {}),
	Boxer4 = series("4 cylindres à plat (boxer)", 0.4, {}, {}),
	V6 = series("V6", 0.4, {}, {}),
	Flat6 = series("6 cylindres à plat", 0.4, {}, {}),
	Rotary = series("Rotatif", 0.4, {}, {}),
}

SoundBank.RECORDINGS = {
	LS3 = LS3,
} :: { [string]: EngineProfile }
for key, profile in pairs(STORE) do
	if #profile.OnLoad >= 2 and #profile.OffLoad >= 2 then
		SoundBank.RECORDINGS[key] = profile
	end
end

local function tone(recording: string, fallbackPitch: number, low: number, mid: number, high: number, distortion: number, volume: number?): EngineTone
	return {
		Recording = recording,
		PitchScale = 1,
		FallbackPitch = fallbackPitch,
		Low = low,
		Mid = mid,
		High = high,
		Distortion = distortion,
		Volume = volume or 1,
	}
end

SoundBank.TONES = {
	-- Catégories de voitures (son de série).
	Rally4 = tone("I3", 1.32, 0, 0, 1, 0, 0.9),
	Rally2 = tone("I4", 1.18, 0, 0, 0, 0),
	WRC = tone("I4R", 1.26, 0, 1, 2, 0.05, 1.05),
	GroupB = tone("I5", 1.08, 1, 0, 0, 0.1, 1.1),
	-- Sons moteur à débloquer (Items/Engines.luau).
	V8 = tone("LS3", 1, 0, 0, 0, 0),
	Open = tone("I4", 1.12, 3, -1, 2, 0.35, 1.1),
	Sport = tone("V6", 1.25, -1, 1, 2, 0),
	Turbo = tone("I4R", 1.2, -3, 2, 5, 0.1),
	Screamer = tone("Flat6", 1.45, -2, 0, 3, 0),
	Vintage = tone("V6", 0.95, 4, 2, -4, 0.4, 1.1),
	Legend = tone("I5", 1.1, 3, 1, 2, 0.3, 1.15),
	Boxer = tone("Boxer4", 1.0, 2, 0, 0, 0.05),
	Rotary = tone("Rotary", 1.5, -2, 1, 3, 0.1),
} :: { [string]: EngineTone }

SoundBank.DEFAULT_TONE = "Rally2"

function SoundBank.Tone(toneId: string?): EngineTone
	return SoundBank.TONES[toneId or SoundBank.DEFAULT_TONE] or SoundBank.TONES[SoundBank.DEFAULT_TONE]
end

--[[
	ÉCHAPPEMENT (Driving/Exhaust.luau), sons courts joués une fois :
		Backfire     retour de flamme (lever de pied franc, passage de
		             rapport, rupteur) : une explosion. Un retour de flamme
		             porté (Items/Backfires.luau) peut avoir la sienne (Sound) ;
		AntiLagPops  crépitements de l'anti-lag, pied levé.
	Plusieurs identifiants par liste : l'un d'eux au hasard, transposé un peu
	(moins répétitif). Listes vides : les flammes sans le son. À chercher dans
	le Creator Store : « backfire », « explosion », « exhaust pop », « anti
	lag », « crackle ».
]]
SoundBank.Backfire = {} :: { string }

-- Choc entre voitures (Driving/Dents.luau), joué au point de choc, plus fort
-- quand la bosse est grosse. Vide : les étincelles sans le son. À chercher
-- dans le Creator Store : « car crash », « metal impact », « car hit ».
SoundBank.Crash = {} :: { string }
SoundBank.AntiLagPops = {} :: { string }

-- Crissement de pneu sur surface dure (boucle). Joué une fois PAR ROUE.
SoundBank.TireScreech = id(109487442763183) -- "Tire Squealing Screeching Loop"

-- Roulement sur gravier, continu (sonothèque officielle Roblox).
SoundBank.GravelRoll = id(9126157444) -- "Vehicle Gravel Tires Crunch Constant Over Rocks"

-- Roulement des pneus sur le dur, continu (sonothèque officielle Roblox).
SoundBank.TarmacRoll = id(9112886486) -- "Tire Constant 2"

-- Vent : il monte avec le carré de la vitesse, comme la pression aérodynamique.
-- PAS ENCORE ÉCOUTÉ : à remplacer s'il sonne mal ou ne boucle pas proprement.
SoundBank.Wind = id(5813077875) -- "wind"

-- Pluie sur la carrosserie, en boucle (WeatherClient.luau), plus forte avec
-- l'averse. "" : pas encore choisie (la pluie reste muette) ; à prendre dans
-- la sonothèque Roblox (Creator Store > Audio, « rain loop »).
SoundBank.Rain = ""

--[[
	FEUX DE DÉPART du rallycross (Race/RaceHud.luau) : un bip à chaque feu
	rouge qui s'allume, puis le signal du départ quand ils passent au vert.
	Par défaut, le « ping » électronique livré avec Roblox (rbxasset://, rien à
	télécharger) : grave pour les rouges, aigu et plus long pour le vert
	(Pitch). Pour un vrai son de feux, Creator Store > Audio : « start beep »,
	« race countdown », « start lights », « countdown beep ».
]]
SoundBank.StartLights = {
	Red = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 0.8, Volume = 0.7 },
	Green = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.6, Volume = 0.9 },
}

return SoundBank
