--!strict
--[[
	PaddockLayout.luau
	Plan du paddock, sur la Baseplate (512 x 512, dessus à Y = 0) : où l'on
	apparaît, les zones de course, la zone voiture, le podium. Partagé par le
	serveur (construction, détection des zones, retour au paddock) et le client
	(caméra du podium).

	TOUT EST À PORTÉE DU SPAWN : on apparaît face aux zones de course (une par
	circuit), en deux rangées de cinq à 40 et 80 studs (quelques secondes de
	marche), la seconde décalée pour que ses panneaux se voient entre ceux de
	la première ; la zone voiture à droite, le podium à gauche. Panneaux
	tournés vers le spawn. On rejoint aussi une course depuis le menu (C).

	La Baseplate est déjà occupée ailleurs : piste d'essai à droite (X de 24 à
	250), places des voitures en Z = -180, départ de la spéciale en Z = -256
	(cap -Z). Le paddock prend le quart gauche, côté +Z.
]]

local PaddockLayout = {}

export type Pad = {
	Id: string, -- identifiant du circuit (Tracks.luau), ou "car"
	Position: Vector3, -- centre, au sol
	Radius: number,
	Color: Color3,
}

PaddockLayout.SPAWN = Vector3.new(-130, 0, 175)
PaddockLayout.SPAWN_SPREAD = 10 -- retour de course : dispersé autour du spawn

-- Dalle du paddock (décor, posée sur la Baseplate)
PaddockLayout.PLAZA_CENTER = Vector3.new(-130, 0, 140)
PaddockLayout.PLAZA_SIZE = Vector2.new(230, 190)

PaddockLayout.PAD_RADIUS = 12
PaddockLayout.CAR_PAD_ID = "car"

-- Devant le spawn (cap -Z), de gauche à droite vus du spawn : rangée avant,
-- puis rangée arrière décalée d'une demi-place.
PaddockLayout.RACE_PADS = {
	{ Id = "greves", Position = Vector3.new(-190, 0, 138), Radius = 11, Color = Color3.fromRGB(70, 150, 255) },
	{ Id = "ajoncs", Position = Vector3.new(-160, 0, 138), Radius = 11, Color = Color3.fromRGB(70, 200, 95) },
	{ Id = "valdefaye", Position = Vector3.new(-130, 0, 138), Radius = 11, Color = Color3.fromRGB(255, 140, 40) },
	{ Id = "falaises", Position = Vector3.new(-100, 0, 138), Radius = 11, Color = Color3.fromRGB(40, 200, 200) },
	{ Id = "anneau", Position = Vector3.new(-70, 0, 138), Radius = 11, Color = Color3.fromRGB(240, 70, 70) },
	{ Id = "lacs", Position = Vector3.new(-175, 0, 98), Radius = 11, Color = Color3.fromRGB(170, 215, 255) },
	{ Id = "carriere", Position = Vector3.new(-145, 0, 98), Radius = 11, Color = Color3.fromRGB(200, 160, 100) },
	{ Id = "port", Position = Vector3.new(-115, 0, 98), Radius = 11, Color = Color3.fromRGB(120, 130, 255) },
	{ Id = "brumes", Position = Vector3.new(-85, 0, 98), Radius = 11, Color = Color3.fromRGB(160, 170, 180) },
	{ Id = "tourbieres", Position = Vector3.new(-55, 0, 98), Radius = 11, Color = Color3.fromRGB(190, 110, 255) },
} :: { Pad }

-- À droite du spawn.
PaddockLayout.CAR_PAD = {
	Id = "car",
	Position = Vector3.new(-82, 0, 180),
	Radius = 10,
	Color = Color3.fromRGB(245, 200, 55),
} :: Pad

--[[
	GARAGE, devant à gauche : entrer dans la zone ouvre le garage (livrée,
	réglages) ; la voiture tourne sur sa plaque juste derrière, aux couleurs que
	l'on choisit (aperçu local, Garage.luau). Détecté par le client seul : rien
	ne change pour les autres tant qu'on n'a pas choisi.
]]
PaddockLayout.GARAGE_PAD = {
	Id = "garage",
	Position = Vector3.new(-222, 0, 138),
	Radius = 10,
	Color = Color3.fromRGB(170, 90, 230),
} :: Pad
PaddockLayout.SHOWROOM = Vector3.new(-222, 0, 112) -- centre de la plaque tournante
PaddockLayout.SHOWROOM_RADIUS = 10

-- Podium, à gauche du spawn, face aux spectateurs (+Z). Marches : 1er au
-- centre, 2e à sa droite (à gauche vu du public), 3e de l'autre côté.
PaddockLayout.PODIUM_CENTER = Vector3.new(-205, 0, 170)
PaddockLayout.PODIUM_STEPS = {
	{ Offset = Vector3.new(0, 0, 0), Height = 4.5 },
	{ Offset = Vector3.new(-9, 0, 0), Height = 3 },
	{ Offset = Vector3.new(9, 0, 0), Height = 2 },
}
PaddockLayout.PODIUM_STEP_SIZE = Vector2.new(8, 8)
-- Caméra de la cérémonie : devant et un peu au-dessus.
PaddockLayout.PODIUM_CAMERA_EYE = Vector3.new(-205, 9, 205)
PaddockLayout.PODIUM_CAMERA_FOCUS = Vector3.new(-205, 5, 170)

-- Le pad (course ou voiture) sous une position, ou nil.
function PaddockLayout.PadAt(position: Vector3): Pad?
	local function inside(pad: Pad): boolean
		local dx, dz = position.X - pad.Position.X, position.Z - pad.Position.Z
		return dx * dx + dz * dz <= pad.Radius * pad.Radius and math.abs(position.Y - pad.Position.Y) < 12
	end
	for _, pad in ipairs(PaddockLayout.RACE_PADS) do
		if inside(pad) then
			return pad
		end
	end
	if inside(PaddockLayout.CAR_PAD) then
		return PaddockLayout.CAR_PAD
	end
	return nil
end

return PaddockLayout
