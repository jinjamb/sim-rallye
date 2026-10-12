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

	Tous les sons ci-dessous sont publiés dans le Creator Store (relevés le
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
	Pour l'instant, toutes partent du même enregistrement de V8 : ce sont
	des variations, pas de vrais moteurs. Un vrai enregistrement s'ajoute
	dans RECORDINGS, et une tonalité le cite (Recording).
]]
export type EngineTone = {
	Recording: string,
	PitchScale: number,
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

SoundBank.RECORDINGS = {
	LS3 = LS3,
} :: { [string]: EngineProfile }

local function tone(pitch: number, low: number, mid: number, high: number, distortion: number, volume: number?): EngineTone
	return { Recording = "LS3", PitchScale = pitch, Low = low, Mid = mid, High = high, Distortion = distortion, Volume = volume or 1 }
end

SoundBank.TONES = {
	-- Catégories de voitures (son de série).
	Rally2 = tone(1.18, -3, 0, 2, 0.08),
	Rally4 = tone(1.32, -5, 1, 3, 0.05, 0.9),
	GroupB = tone(1.08, 2, 0, 1, 0.25, 1.1),
	-- Sons moteur à débloquer (Items/Engines.luau).
	V8 = tone(1, 0, 0, 0, 0),
	Open = tone(1.12, 3, -1, 2, 0.35, 1.1),
	Sport = tone(1.25, -2, 1, 4, 0.1),
	Turbo = tone(1.2, -4, 2, 5, 0.15),
	Screamer = tone(1.45, -6, 0, 6, 0.05),
	Vintage = tone(0.95, 4, 2, -4, 0.45, 1.1),
	Legend = tone(1.1, 3, 1, 3, 0.3, 1.15),
} :: { [string]: EngineTone }

SoundBank.DEFAULT_TONE = "Rally2"

function SoundBank.Tone(toneId: string?): EngineTone
	return SoundBank.TONES[toneId or SoundBank.DEFAULT_TONE] or SoundBank.TONES[SoundBank.DEFAULT_TONE]
end

-- Crissement de pneu sur surface dure (boucle). Joué une fois PAR ROUE.
SoundBank.TireScreech = id(109487442763183) -- "Tire Squealing Screeching Loop"

-- Roulement sur gravier, continu (sonothèque officielle Roblox).
SoundBank.GravelRoll = id(9126157444) -- "Vehicle Gravel Tires Crunch Constant Over Rocks"

-- Roulement des pneus sur le dur, continu (sonothèque officielle Roblox).
SoundBank.TarmacRoll = id(9112886486) -- "Tire Constant 2"

-- Vent : il monte avec le carré de la vitesse, comme la pression aérodynamique.
-- PAS ENCORE ÉCOUTÉ : à remplacer s'il sonne mal ou ne boucle pas proprement.
SoundBank.Wind = id(5813077875) -- "wind"

return SoundBank
