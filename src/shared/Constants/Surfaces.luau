--!strict
--[[
	Surfaces.luau
	Table de correspondance Enum.Material -> propriétés d'adhérence.
	Utilisé par Wheel.luau via RaycastResult.Material.
]]

local Surfaces = {}

--[[
	Famille sonore du contact pneu/sol (CarAudio.luau) :
		Tarmac : surface dure, le pneu CRISSE quand il dépasse son pic d'adhérence ;
		Gravel : surface meuble, le pneu ROULE dans un crissement de cailloux
		         permanent, qui enfle quand il patine ou glisse ;
		Ice    : la glace ne crisse pas, elle chuinte -- on laisse le moteur parler.
]]
export type SurfaceSound = "Tarmac" | "Gravel" | "Ice"

--[[
	COMPORTEMENT DU PNEU selon la nature du sol (lu par Wheel.luau).

	Sur le dur, le pneu atteint son adhérence maximale avec peu de glissement
	(10 à 20 %) et la perd nettement au-delà : roue bloquée ou qui patine fort,
	il ne reste qu'environ 77 % de l'adhérence.
	Sur le meuble (terre, gravier, neige), les crampons creusent le sol : le
	maximum arrive bien plus tard (30 à 50 % de glissement, ~14° de dérive) et
	la chute au-delà est faible (~95 % roue bloquée, ~87 % en gros patinage).
	Un peu de patinage DONNE de la motricité, comme en vrai -- c'est ce qui
	rend une relance possible après une épingle au frein à main.

	Courbe de Pacejka normalisée : sin(C * atan(B*x - E*(B*x - atan(B*x)))),
	x = glissement / glissement au pic. B est calculé pour que le pic tombe
	exactement à x = 1 et vaille exactement 1 ; C règle ce qui reste au-delà
	(asymptote sin(C * pi/2)), E la rondeur du sommet.
]]
export type TireProfile = {
	Name: string,
	PeakSlipRatio: number, -- glissement longitudinal au pic
	PeakSlipAngle: number, -- tangente de l'angle de dérive au pic
	B: number,
	C: number,
	E: number,
}

Surfaces.TIRE_TARMAC = {
	Name = "dur",
	PeakSlipRatio = 0.19,
	PeakSlipAngle = 0.16, -- ~9°
	B = 1.886,
	C = 1.65,
	E = 0.6,
} :: TireProfile

Surfaces.TIRE_LOOSE = {
	Name = "meuble",
	PeakSlipRatio = 0.35,
	PeakSlipAngle = 0.25, -- ~14°
	B = 2.786,
	C = 1.35,
	E = 0.3,
} :: TireProfile

export type SurfaceProperties = {
	Name: string,
	Grip: number, -- coefficient de friction (mu) au pic d'adhérence
	RollingResistance: number, -- fraction de la charge normale opposée au roulement
	DustColor: Color3, -- couleur des particules soulevées par la roue
	Sound: SurfaceSound,
	Tire: TireProfile,
}

local HARD = Surfaces.TIRE_TARMAC
local LOOSE = Surfaces.TIRE_LOOSE

local DEFAULT: SurfaceProperties = {
	Name = "Default",
	Grip = 0.85,
	RollingResistance = 0.015,
	DustColor = Color3.fromRGB(200, 200, 200),
	Sound = "Tarmac",
	Tire = HARD,
}

local BY_MATERIAL: { [Enum.Material]: SurfaceProperties } = {
	-- Routes
	[Enum.Material.Asphalt] = { Name = "Asphalte", Grip = 1.05, RollingResistance = 0.012, DustColor = Color3.fromRGB(90, 90, 90), Sound = "Tarmac", Tire = HARD },
	[Enum.Material.Concrete] = { Name = "Béton", Grip = 1.00, RollingResistance = 0.013, DustColor = Color3.fromRGB(150, 150, 150), Sound = "Tarmac", Tire = HARD },
	[Enum.Material.Pavement] = { Name = "Pavé", Grip = 0.95, RollingResistance = 0.015, DustColor = Color3.fromRGB(140, 140, 140), Sound = "Tarmac", Tire = HARD },
	[Enum.Material.Plastic] = { Name = "Plastique", Grip = 0.90, RollingResistance = 0.014, DustColor = Color3.fromRGB(200, 200, 200), Sound = "Tarmac", Tire = HARD },
	[Enum.Material.Metal] = { Name = "Métal", Grip = 0.85, RollingResistance = 0.012, DustColor = Color3.fromRGB(180, 180, 190), Sound = "Tarmac", Tire = HARD },
	[Enum.Material.WoodPlanks] = { Name = "Planches", Grip = 0.80, RollingResistance = 0.018, DustColor = Color3.fromRGB(160, 120, 80), Sound = "Tarmac", Tire = HARD },

	-- Spéciales rallye
	[Enum.Material.Rock] = { Name = "Rocaille", Grip = 0.88, RollingResistance = 0.022, DustColor = Color3.fromRGB(130, 120, 110), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Slate] = { Name = "Ardoise", Grip = 0.86, RollingResistance = 0.020, DustColor = Color3.fromRGB(110, 110, 115), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Pebble] = { Name = "Gravier", Grip = 0.70, RollingResistance = 0.035, DustColor = Color3.fromRGB(170, 160, 140), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Ground] = { Name = "Terre", Grip = 0.72, RollingResistance = 0.032, DustColor = Color3.fromRGB(120, 95, 70), Sound = "Gravel", Tire = LOOSE },
	-- Dans l'herbe, les pneus arrachent la terre en dessous : poussière brune,
	-- pas verte (une poussière verte sur fond vert ne se voit pas).
	[Enum.Material.Grass] = { Name = "Herbe", Grip = 0.62, RollingResistance = 0.045, DustColor = Color3.fromRGB(135, 115, 80), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.LeafyGrass] = { Name = "Herbe haute", Grip = 0.55, RollingResistance = 0.060, DustColor = Color3.fromRGB(125, 108, 75), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Mud] = { Name = "Boue", Grip = 0.50, RollingResistance = 0.075, DustColor = Color3.fromRGB(90, 70, 50), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Sand] = { Name = "Sable", Grip = 0.48, RollingResistance = 0.090, DustColor = Color3.fromRGB(200, 180, 130), Sound = "Gravel", Tire = LOOSE },
	[Enum.Material.Snow] = { Name = "Neige", Grip = 0.35, RollingResistance = 0.055, DustColor = Color3.fromRGB(235, 240, 245), Sound = "Gravel", Tire = LOOSE },
	-- La glace est une surface DURE : faible adhérence, mais vite perdue.
	[Enum.Material.Glacier] = { Name = "Glace", Grip = 0.18, RollingResistance = 0.010, DustColor = Color3.fromRGB(220, 240, 255), Sound = "Ice", Tire = HARD },
	[Enum.Material.Ice] = { Name = "Verglas", Grip = 0.12, RollingResistance = 0.008, DustColor = Color3.fromRGB(220, 240, 255), Sound = "Ice", Tire = HARD },
	[Enum.Material.Water] = { Name = "Eau", Grip = 0.30, RollingResistance = 0.120, DustColor = Color3.fromRGB(160, 200, 230), Sound = "Gravel", Tire = LOOSE },
}

Surfaces.Default = DEFAULT

-- Adhérence de TOUTES les surfaces, multipliée (pluie du défi de la semaine :
-- StageModifier.luau). 1 = sec. Côté client seulement : la physique est là.
Surfaces.GripScale = 1

function Surfaces.Get(material: Enum.Material): SurfaceProperties
	return BY_MATERIAL[material] or DEFAULT
end

return Surfaces
