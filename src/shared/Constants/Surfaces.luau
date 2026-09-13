--!strict
--[[
	Surfaces.luau
	Table de correspondance Enum.Material -> propriétés d'adhérence.
	Utilisé par Wheel.luau via RaycastResult.Material.
]]

local Surfaces = {}

export type SurfaceProperties = {
	Name: string,
	Grip: number, -- coefficient de friction (mu) utilisé par Coulomb et Pacejka
	RollingResistance: number, -- fraction de la charge normale opposée au roulement
	DustColor: Color3, -- couleur des particules soulevées par la roue
}

local DEFAULT: SurfaceProperties = {
	Name = "Default",
	Grip = 0.85,
	RollingResistance = 0.015,
	DustColor = Color3.fromRGB(200, 200, 200),
}

local BY_MATERIAL: { [Enum.Material]: SurfaceProperties } = {
	-- Routes
	[Enum.Material.Asphalt] = { Name = "Asphalte", Grip = 1.05, RollingResistance = 0.012, DustColor = Color3.fromRGB(90, 90, 90) },
	[Enum.Material.Concrete] = { Name = "Béton", Grip = 1.00, RollingResistance = 0.013, DustColor = Color3.fromRGB(150, 150, 150) },
	[Enum.Material.Pavement] = { Name = "Pavé", Grip = 0.95, RollingResistance = 0.015, DustColor = Color3.fromRGB(140, 140, 140) },
	[Enum.Material.Plastic] = { Name = "Plastique", Grip = 0.90, RollingResistance = 0.014, DustColor = Color3.fromRGB(200, 200, 200) },
	[Enum.Material.Metal] = { Name = "Métal", Grip = 0.85, RollingResistance = 0.012, DustColor = Color3.fromRGB(180, 180, 190) },
	[Enum.Material.WoodPlanks] = { Name = "Planches", Grip = 0.80, RollingResistance = 0.018, DustColor = Color3.fromRGB(160, 120, 80) },

	-- Spéciales rallye
	[Enum.Material.Rock] = { Name = "Rocaille", Grip = 0.88, RollingResistance = 0.022, DustColor = Color3.fromRGB(130, 120, 110) },
	[Enum.Material.Slate] = { Name = "Ardoise", Grip = 0.86, RollingResistance = 0.020, DustColor = Color3.fromRGB(110, 110, 115) },
	[Enum.Material.Pebble] = { Name = "Gravier", Grip = 0.70, RollingResistance = 0.035, DustColor = Color3.fromRGB(170, 160, 140) },
	[Enum.Material.Ground] = { Name = "Terre", Grip = 0.72, RollingResistance = 0.032, DustColor = Color3.fromRGB(120, 95, 70) },
	[Enum.Material.Grass] = { Name = "Herbe", Grip = 0.62, RollingResistance = 0.045, DustColor = Color3.fromRGB(95, 130, 70) },
	[Enum.Material.LeafyGrass] = { Name = "Herbe haute", Grip = 0.55, RollingResistance = 0.060, DustColor = Color3.fromRGB(80, 115, 60) },
	[Enum.Material.Mud] = { Name = "Boue", Grip = 0.50, RollingResistance = 0.075, DustColor = Color3.fromRGB(90, 70, 50) },
	[Enum.Material.Sand] = { Name = "Sable", Grip = 0.48, RollingResistance = 0.090, DustColor = Color3.fromRGB(200, 180, 130) },
	[Enum.Material.Snow] = { Name = "Neige", Grip = 0.35, RollingResistance = 0.055, DustColor = Color3.fromRGB(235, 240, 245) },
	[Enum.Material.Glacier] = { Name = "Glace", Grip = 0.18, RollingResistance = 0.010, DustColor = Color3.fromRGB(220, 240, 255) },
	[Enum.Material.Ice] = { Name = "Verglas", Grip = 0.12, RollingResistance = 0.008, DustColor = Color3.fromRGB(220, 240, 255) },
	[Enum.Material.Water] = { Name = "Eau", Grip = 0.30, RollingResistance = 0.120, DustColor = Color3.fromRGB(160, 200, 230) },
}

Surfaces.Default = DEFAULT

function Surfaces.Get(material: Enum.Material): SurfaceProperties
	return BY_MATERIAL[material] or DEFAULT
end

return Surfaces
