--!strict
--[[
	CarDamage.luau
	Les bosses d'une voiture après un contact avec une autre voiture : huit
	zones autour de la caisse, chacune enfoncée de 0 (intacte) à 1 (froissée).

	Qui fait quoi :
		- le client du pilote voit le choc sur SA voiture (CarContact.luau),
		  en déduit la zone touchée et la gravité, et le signale au serveur
		  (Remotes.CarDamage) ;
		- le serveur vérifie (sa voiture, contacts activés, valeurs bornées,
		  cadence), puis ajoute la bosse aux attributs de la voiture (Dent1 à
		  Dent8), qui se répliquent chez tout le monde ;
		- chaque client déforme la carrosserie de chaque voiture d'après ces
		  attributs (client/Driving/Dents.luau), avec étincelles et éclats.

	ZONES, dans le sens des aiguilles d'une montre vu de dessus, l'avant en
	premier : 1 avant, 2 avant droit, 3 flanc droit, 4 arrière droit,
	5 arrière, 6 arrière gauche, 7 flanc gauche, 8 avant gauche.
	REPÈRE : celui du châssis (X à droite, l'avant en -Z).

	Seulement visuel pour l'instant : les bosses ne changent pas la conduite.
]]

local CarDamage = {}

CarDamage.ZONE_COUNT = 8
CarDamage.ZONE_NAMES = { "avant", "avant droit", "flanc droit", "arrière droit", "arrière", "arrière gauche", "flanc gauche", "avant gauche" }

-- Gravité d'un choc : la vitesse de rapprochement des deux voitures (studs/s).
CarDamage.THRESHOLD = 9 -- en dessous : une touchette, pas de bosse
CarDamage.FULL_SPEED = 75 -- au-dessus du seuil : de quoi froisser une zone d'un coup
CarDamage.MAX_HIT = 0.6 -- bosse ajoutée au plus par un seul choc
CarDamage.SPREAD = 0.3 -- part de la bosse reportée sur les deux zones voisines
CarDamage.COOLDOWN = 0.35 -- secondes entre deux chocs signalés avec la même voiture

local STEP = math.pi / 4

function CarDamage.Attribute(zone: number): string
	return "Dent" .. tostring(zone)
end

-- La bosse ajoutée par un choc à cette vitesse de rapprochement (0 : aucune).
function CarDamage.AmountFor(speed: number): number
	if speed <= CarDamage.THRESHOLD then
		return 0
	end
	return math.min(CarDamage.MAX_HIT, (speed - CarDamage.THRESHOLD) / CarDamage.FULL_SPEED)
end

-- Angle d'une direction du châssis vue de dessus : 0 à l'avant, positif vers la droite.
function CarDamage.AngleOf(localDirection: Vector3): number
	return math.atan2(localDirection.X, -localDirection.Z)
end

-- La zone touchée, d'après la direction (repère du châssis) du centre vers le choc.
function CarDamage.ZoneOf(localDirection: Vector3): number
	local index = math.floor(CarDamage.AngleOf(localDirection) / STEP + 0.5)
	return index % CarDamage.ZONE_COUNT + 1
end

-- Direction (repère du châssis, à plat) du milieu d'une zone.
function CarDamage.DirectionOf(zone: number): Vector3
	local angle = (zone - 1) * STEP
	return Vector3.new(math.sin(angle), 0, -math.cos(angle))
end

-- Les bosses d'une voiture (huit valeurs de 0 à 1).
function CarDamage.Read(model: Instance): { number }
	local dents = table.create(CarDamage.ZONE_COUNT, 0)
	for zone = 1, CarDamage.ZONE_COUNT do
		local value = model:GetAttribute(CarDamage.Attribute(zone))
		dents[zone] = if type(value) == "number" then math.clamp(value, 0, 1) else 0
	end
	return dents
end

-- La bosse sous un angle donné : mélange des deux zones qui l'encadrent.
function CarDamage.At(dents: { number }, angle: number): number
	local position = (angle % (2 * math.pi)) / STEP
	local first = math.floor(position)
	local t = position - first
	local a = dents[first % CarDamage.ZONE_COUNT + 1]
	local b = dents[(first + 1) % CarDamage.ZONE_COUNT + 1]
	return a + (b - a) * t
end

-- Serveur : ajoute une bosse (zone touchée, et un peu sur ses voisines).
function CarDamage.Add(model: Instance, zone: number, amount: number)
	local function bump(z: number, value: number)
		local index = (z - 1) % CarDamage.ZONE_COUNT + 1
		local name = CarDamage.Attribute(index)
		local old = model:GetAttribute(name)
		local current = if type(old) == "number" then old else 0
		model:SetAttribute(name, math.min(1, current + value))
	end
	bump(zone, amount)
	bump(zone - 1, amount * CarDamage.SPREAD)
	bump(zone + 1, amount * CarDamage.SPREAD)
end

return CarDamage
