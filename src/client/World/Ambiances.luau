--!strict
--[[
	Ambiances.luau
	Les ambiances lumineuses du jeu (appliquées par Ambiance.luau), dans un
	style « anime années 90 » : ombres nettes et colorées (violet, bleu nuit)
	plutôt que noires, couleurs saturées, contours encrés sur les voitures
	(CarOutlines.luau), lumières qui bavent un peu (Bloom).

	Une ambiance par surface de spéciale (Tarmac, Gravel, Snow, Mixed), une
	pour le rallycross (Circuit), une pour le paddock et les menus
	(Paddock). OVERRIDES retouche une spéciale ou un circuit précis : seuls
	les champs donnés remplacent ceux de son ambiance de base.

	Les champs :
		ClockTime, Latitude      heure et latitude : position du soleil, donc
		                         longueur et direction des ombres ;
		Brightness, Exposure     force du soleil, exposition générale ;
		Shadow                   couleur des zones à l'ombre (OutdoorAmbient) :
		                         c'est elle qui donne les ombres « dessinées » ;
		Ambient                  lumière des intérieurs (sous les ponts, tunnels) ;
		ShiftTop, ShiftBottom    teinte des faces au soleil, et à contre-jour ;
		Atmosphere               brume (Color), horizon (Decay), densité ;
		Grade                    étalonnage (ColorCorrection) ;
		Bloom, SunRays           halo des lumières, rayons du soleil ;
		Clouds                   nuages dynamiques du terrain ;
		Ink                      couleur du contour des voitures.

	À régler à l'œil dans Studio : modifier une valeur ici, relancer.
]]

local Ambiances = {}

export type AtmosphereSpec = {
	Density: number,
	Offset: number,
	Haze: number,
	Glare: number,
	Color: Color3,
	Decay: Color3,
}

export type Ambiance = {
	Name: string,
	ClockTime: number,
	Latitude: number,
	Brightness: number,
	Exposure: number,
	Shadow: Color3,
	Ambient: Color3,
	ShiftTop: Color3,
	ShiftBottom: Color3,
	Atmosphere: AtmosphereSpec,
	Grade: { Saturation: number, Contrast: number, Brightness: number, Tint: Color3 },
	Bloom: { Intensity: number, Size: number, Threshold: number },
	SunRays: { Intensity: number, Spread: number },
	Clouds: { Cover: number, Density: number, Color: Color3 },
	Ink: Color3,
}

local rgb = Color3.fromRGB

--[[
	Réglages communs à toutes les ambiances (moteur d'éclairage) :
		Future            ombres nettes, reflets, phares et feux qui éclairent ;
		ShadowSoftness 0  bord d'ombre franc, comme tracé au pinceau ;
		EnvironmentSpecularScale  reflets du ciel (chromé, métallisé, nacré) ;
		EnvironmentDiffuseScale   lumière diffuse du ciel : basse, pour garder
		                          des aplats (la couleur d'ombre fait le reste).
	Technology n'est pas modifiable par script : il est dans
	default.project.json, avec les mêmes valeurs (aperçu dans Studio).
]]
Ambiances.ENGINE = {
	ShadowSoftness = 0,
	EnvironmentSpecularScale = 1,
	EnvironmentDiffuseScale = 0.25,
}

Ambiances.BASE = {
	-- Paddock et menus : fin d'après-midi, ombres lilas, ciel orangé.
	Paddock = {
		Name = "Paddock",
		ClockTime = 16.8,
		Latitude = 38,
		Brightness = 2.6,
		Exposure = 0.1,
		Shadow = rgb(128, 106, 168),
		Ambient = rgb(52, 40, 76),
		ShiftTop = rgb(255, 226, 190),
		ShiftBottom = rgb(120, 90, 170),
		Atmosphere = { Density = 0.28, Offset = 0.2, Haze = 1.4, Glare = 0.4, Color = rgb(236, 196, 210), Decay = rgb(150, 110, 190) },
		Grade = { Saturation = 0.28, Contrast = 0.14, Brightness = 0.02, Tint = rgb(255, 246, 250) },
		Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.4 },
		SunRays = { Intensity = 0.06, Spread = 0.6 },
		Clouds = { Cover = 0.55, Density = 0.6, Color = rgb(255, 222, 230) },
		Ink = rgb(24, 16, 40),
	},
	-- Asphalte : plein jour, ciel bleu franc, ombres bleu-violet.
	Tarmac = {
		Name = "Asphalte",
		ClockTime = 13.4,
		Latitude = 41,
		Brightness = 3,
		Exposure = 0,
		Shadow = rgb(112, 112, 168),
		Ambient = rgb(40, 40, 70),
		ShiftTop = rgb(255, 246, 228),
		ShiftBottom = rgb(96, 110, 180),
		Atmosphere = { Density = 0.22, Offset = 0.15, Haze = 0.8, Glare = 0.2, Color = rgb(200, 220, 245), Decay = rgb(110, 150, 220) },
		Grade = { Saturation = 0.25, Contrast = 0.16, Brightness = 0, Tint = rgb(250, 252, 255) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.5 },
		SunRays = { Intensity = 0.04, Spread = 0.5 },
		Clouds = { Cover = 0.45, Density = 0.55, Color = rgb(255, 255, 255) },
		Ink = rgb(20, 20, 40),
	},
	-- Terre : soleil doré, poussière chaude dans l'air.
	Gravel = {
		Name = "Terre",
		ClockTime = 17.3,
		Latitude = 36,
		Brightness = 2.7,
		Exposure = 0.05,
		Shadow = rgb(140, 104, 140),
		Ambient = rgb(60, 40, 56),
		ShiftTop = rgb(255, 214, 160),
		ShiftBottom = rgb(130, 90, 150),
		Atmosphere = { Density = 0.34, Offset = 0.25, Haze = 1.8, Glare = 0.6, Color = rgb(240, 200, 160), Decay = rgb(190, 120, 120) },
		Grade = { Saturation = 0.3, Contrast = 0.15, Brightness = 0.02, Tint = rgb(255, 244, 232) },
		Bloom = { Intensity = 0.6, Size = 30, Threshold = 1.35 },
		SunRays = { Intensity = 0.1, Spread = 0.7 },
		Clouds = { Cover = 0.4, Density = 0.5, Color = rgb(255, 220, 200) },
		Ink = rgb(36, 18, 30),
	},
	-- Neige : matin froid, soleil bas, ombres bleues sur la neige.
	Snow = {
		Name = "Neige",
		ClockTime = 9.6,
		Latitude = 55,
		Brightness = 2.4,
		Exposure = -0.1,
		Shadow = rgb(100, 128, 196),
		Ambient = rgb(40, 54, 90),
		ShiftTop = rgb(255, 236, 220),
		ShiftBottom = rgb(90, 130, 210),
		Atmosphere = { Density = 0.3, Offset = 0.2, Haze = 1.2, Glare = 0.5, Color = rgb(214, 228, 250), Decay = rgb(140, 170, 230) },
		Grade = { Saturation = 0.18, Contrast = 0.18, Brightness = 0, Tint = rgb(240, 248, 255) },
		Bloom = { Intensity = 0.45, Size = 26, Threshold = 1.6 },
		SunRays = { Intensity = 0.08, Spread = 0.6 },
		Clouds = { Cover = 0.5, Density = 0.6, Color = rgb(240, 245, 255) },
		Ink = rgb(16, 24, 48),
	},
	-- Mixte : début d'après-midi, lumière chaude et douce.
	Mixed = {
		Name = "Mixte",
		ClockTime = 15.2,
		Latitude = 44,
		Brightness = 2.8,
		Exposure = 0.05,
		Shadow = rgb(124, 110, 164),
		Ambient = rgb(48, 40, 70),
		ShiftTop = rgb(255, 232, 200),
		ShiftBottom = rgb(110, 100, 176),
		Atmosphere = { Density = 0.28, Offset = 0.2, Haze = 1.2, Glare = 0.35, Color = rgb(226, 214, 230), Decay = rgb(130, 130, 200) },
		Grade = { Saturation = 0.27, Contrast = 0.15, Brightness = 0.01, Tint = rgb(255, 250, 248) },
		Bloom = { Intensity = 0.55, Size = 26, Threshold = 1.45 },
		SunRays = { Intensity = 0.06, Spread = 0.6 },
		Clouds = { Cover = 0.5, Density = 0.55, Color = rgb(255, 240, 240) },
		Ink = rgb(26, 20, 44),
	},
	-- Rallycross : soleil couchant, ciel rose et violet, néons qui bavent.
	Circuit = {
		Name = "Rallycross",
		ClockTime = 17.9,
		Latitude = 40,
		Brightness = 2.3,
		Exposure = 0.2,
		Shadow = rgb(120, 92, 170),
		Ambient = rgb(56, 36, 86),
		ShiftTop = rgb(255, 196, 170),
		ShiftBottom = rgb(130, 80, 190),
		Atmosphere = { Density = 0.3, Offset = 0.22, Haze = 1.6, Glare = 0.8, Color = rgb(250, 180, 200), Decay = rgb(140, 90, 200) },
		Grade = { Saturation = 0.32, Contrast = 0.16, Brightness = 0.02, Tint = rgb(255, 240, 250) },
		Bloom = { Intensity = 0.75, Size = 32, Threshold = 1.3 },
		SunRays = { Intensity = 0.12, Spread = 0.8 },
		Clouds = { Cover = 0.5, Density = 0.6, Color = rgb(255, 190, 210) },
		Ink = rgb(30, 14, 46),
	},
} :: { [string]: Ambiance }

-- Retouches par spéciale (Stages.luau) ou circuit (Tracks.luau), par identifiant.
local OVERRIDES: { [string]: { [string]: any } } = {
	-- Spéciales
	laponie = { ClockTime = 11.5, Latitude = 68 }, -- soleil arctique, rasant à midi
	corniche = { ClockTime = 11, Shadow = rgb(100, 120, 176), Atmosphere = { Density = 0.18, Offset = 0.1, Haze = 0.5, Glare = 0.3, Color = rgb(200, 230, 250), Decay = rgb(80, 150, 230) } },
	-- Circuits
	lacs = { ClockTime = 9.2, Latitude = 60, Shadow = rgb(100, 124, 196), ShiftBottom = rgb(90, 120, 210) },
	brumes = { Atmosphere = { Density = 0.48, Offset = 0.05, Haze = 2.6, Glare = 0.4, Color = rgb(226, 196, 220), Decay = rgb(150, 120, 190) } },
	tourbieres = { ClockTime = 16.5, Clouds = { Cover = 0.8, Density = 0.8, Color = rgb(220, 200, 230) } },
	port = { ClockTime = 18.3, Brightness = 2, Exposure = 0.35 }, -- crépuscule plus avancé
	falaises = { ClockTime = 14.5, Shadow = rgb(104, 118, 180) }, -- plein jour au bord de la mer
}

local function merge(base: Ambiance, id: string?): Ambiance
	local override = if id then OVERRIDES[id] else nil
	if not override then
		return base
	end
	local merged = table.clone(base) :: any
	for key, value in pairs(override) do
		merged[key] = value
	end
	return merged :: Ambiance
end

function Ambiances.Paddock(): Ambiance
	return Ambiances.BASE.Paddock
end

-- L'ambiance d'une spéciale, selon sa surface (StageTrack.Surface).
function Ambiances.ForStage(stageId: string, surface: string): Ambiance
	return merge(Ambiances.BASE[surface] or Ambiances.BASE.Mixed, stageId)
end

-- L'ambiance d'un circuit de rallycross.
function Ambiances.ForCircuit(circuitId: string): Ambiance
	return merge(Ambiances.BASE.Circuit, circuitId)
end

return Ambiances
