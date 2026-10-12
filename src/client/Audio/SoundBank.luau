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

	PLANCHES : un moteur peut tenir dans UN seul fichier audio, qui enchaîne
	ses boucles ; chaque échantillon y est alors une région (Start, Length,
	en secondes), lue et bouclée par Sound.PlaybackRegion / LoopRegion. Les
	moteurs synthétisés (assets/engines/, generate.py) sont faits ainsi :
	un import par moteur au lieu de dix-sept.

	Le V8 (LS3) vient du Creator Store (relevé le 2026-10-03). Pour en tester
	d'autres : create.roblox.com/store/audio, chercher "engacc", "engdec",
	"eng on", "eng off", ou un nom de moteur.
]]

local SoundBank = {}

-- Volume général de la voiture (moteur + pneus), appliqué par un SoundGroup :
-- c'est LE réglage à toucher si l'ensemble est trop fort ou trop faible.
-- Les volumes individuels ci-dessous et dans CarAudio.luau règlent l'équilibre.
SoundBank.MasterVolume = 0.5

export type EngineSample = {
	Id: string,
	Rpm: number,
	-- Planche : la boucle est la région [Start, Start + Length] du fichier (s).
	Start: number?,
	Length: number?,
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
	dont la planche n'est pas encore importée (identifiant 0) est remplacé
	par le V8 (LS3), transposé de FallbackPitch.
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
	MOTEURS SYNTHÉTISÉS (assets/engines/generate.py) : un fichier par moteur,
	tous sur la même planche (REGIONS : mêmes régimes, mêmes positions).
	Chaque fichier .ogg s'importe dans Studio (Asset Manager) ; son
	identifiant va dans SHEETS. Tant qu'il vaut 0, le moteur est remplacé
	par le V8 (voir FallbackPitch).
]]
local REGIONS = {
	OnLoad = {
		{ Rpm = 1000, Start = 0.050000, Length = 1.200000 },
		{ Rpm = 1800, Start = 1.350000, Length = 1.200000 },
		{ Rpm = 2600, Start = 2.650000, Length = 1.199773 },
		{ Rpm = 3401, Start = 3.949773, Length = 1.199637 },
		{ Rpm = 4200, Start = 5.249410, Length = 1.200000 },
		{ Rpm = 5002, Start = 6.549410, Length = 1.199546 },
		{ Rpm = 5803, Start = 7.848957, Length = 1.199456 },
		{ Rpm = 6599, Start = 9.148413, Length = 1.200272 },
		{ Rpm = 7401, Start = 10.448685, Length = 1.199773 },
		{ Rpm = 8205, Start = 11.748458, Length = 1.199320 },
	},
	OffLoad = {
		{ Rpm = 900, Start = 13.047778, Length = 1.200000 },
		{ Rpm = 2000, Start = 14.347778, Length = 1.200000 },
		{ Rpm = 3200, Start = 15.647778, Length = 1.200181 },
		{ Rpm = 4399, Start = 16.947959, Length = 1.200272 },
		{ Rpm = 5600, Start = 18.248231, Length = 1.200000 },
		{ Rpm = 6802, Start = 19.548231, Length = 1.199637 },
		{ Rpm = 7994, Start = 20.847868, Length = 1.200907 },
	},
}

local SHEETS: { [string]: { Name: string, Id: number, Volume: number } } = {
	I3 = { Name = "3 cylindres turbo", Id = 0, Volume = 0.5 }, -- assets/engines/I3.ogg
	I4 = { Name = "4 cylindres turbo", Id = 0, Volume = 0.5 }, -- I4.ogg
	I4R = { Name = "4 cylindres anti-lag", Id = 0, Volume = 0.5 }, -- I4R.ogg
	I5 = { Name = "5 cylindres turbo", Id = 0, Volume = 0.5 }, -- I5.ogg
	Boxer4 = { Name = "4 cylindres à plat", Id = 0, Volume = 0.5 }, -- Boxer4.ogg
	V6 = { Name = "V6", Id = 0, Volume = 0.5 }, -- V6.ogg
	Flat6 = { Name = "6 cylindres à plat", Id = 0, Volume = 0.5 }, -- Flat6.ogg
	Rotary = { Name = "Rotatif", Id = 0, Volume = 0.45 }, -- Rotary.ogg
}

local function sheet(spec: { Name: string, Id: number, Volume: number }): EngineProfile
	local function samples(list: { { Rpm: number, Start: number, Length: number } }): { EngineSample }
		local result = {}
		for _, region in ipairs(list) do
			table.insert(result, { Id = id(spec.Id), Rpm = region.Rpm, Start = region.Start, Length = region.Length })
		end
		return result
	end
	return { Name = spec.Name, Volume = spec.Volume, OnLoad = samples(REGIONS.OnLoad), OffLoad = samples(REGIONS.OffLoad) }
end

SoundBank.RECORDINGS = {
	LS3 = LS3,
} :: { [string]: EngineProfile }
for key, spec in pairs(SHEETS) do
	if spec.Id ~= 0 then
		SoundBank.RECORDINGS[key] = sheet(spec)
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

return SoundBank
