--!strict
--[[
	SoundBank.luau
	Tous les identifiants audio du jeu, en un seul endroit. Changer de moteur,
	c'est remplacer une liste ici : CarAudio.luau ne contient aucun ID.

	MOTEUR : une série d'échantillons BOUCLÉS, chacun enregistré à régime
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
SoundBank.Engine = {
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
} :: EngineProfile

-- Crissement de pneu sur surface dure (boucle). Joué une fois PAR ROUE.
SoundBank.TireScreech = id(109487442763183) -- "Tire Squealing Screeching Loop"

-- Roulement sur gravier, continu (sonothèque officielle Roblox).
SoundBank.GravelRoll = id(9126157444) -- "Vehicle Gravel Tires Crunch Constant Over Rocks"

return SoundBank
