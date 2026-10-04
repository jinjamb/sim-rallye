--!strict
--[[
	CarContact.luau
	Contact entre voitures d'une même course, calculé par chaque client sur SA
	voiture seulement.

	POURQUOI PAS LES COLLISIONS DE ROBLOX : chaque voiture est simulée par le
	client de son pilote. Chacun voit l'autre voiture avec 100 à 200 ms de
	retard, sous forme d'un objet qu'il ne peut pas pousser. Les collisions
	natives donnent alors des chocs violents et asymétriques : l'autre voiture
	se comporte comme un mur qui se téléporte. Les voitures sont donc dans le
	groupe "Cars" (aucune collision native entre elles) et le contact est
	reconstitué ici, en douceur.

	MÉTHODE : les deux voitures sont des rectangles vus de dessus (empreinte du
	gabarit). Test des axes séparateurs : s'ils se chevauchent, on connaît la
	direction du choc et la profondeur d'interpénétration. On applique alors à SA
	voiture la moitié de la réponse d'un choc entre masses égales -- l'autre
	client applique l'autre moitié à la sienne -- plus une poussée de séparation
	proportionnelle à l'interpénétration, et un léger frottement. Une voiture
	que personne ne pilote ne réagit pas : on prend alors toute la réponse.

	La position de l'autre voiture est légèrement extrapolée (vitesse x
	EXTRAPOLATION) pour compenser une partie du retard de réplication.
	L'impulsion est appliquée au point de contact, à hauteur du centre : un choc
	sur l'arrière fait pivoter, sans faire rouler ni cabrer.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarClass = require(script.Parent.Parent.Physics.Car)

local CarContact = {}
CarContact.__index = CarContact

export type CarContact = typeof(setmetatable({}, CarContact)) & {
	Car: CarClass.Car,
	RaceId: string,
	HalfWidth: number,
	HalfLength: number,
}

local CAR_TAG = "RallyCar"
local EXTRAPOLATION = 0.06 -- secondes
local BROAD_RANGE = 30 -- studs : au-delà, pas de test précis
local MAX_HEIGHT_GAP = 4 -- une voiture en l'air au-dessus d'une autre ne la touche pas
local RESTITUTION = 0.25
local PUSH_GAIN = 6 -- studs/s de séparation par stud d'interpénétration
local MAX_PUSH = 12
local FRICTION = 0.08 -- part de la vitesse de glissement relative absorbée par frame de contact
local FOOTPRINT_MARGIN = 0.94 -- la carrosserie est arrondie : empreinte un peu réduite

local function flat(v: Vector3): Vector2
	local p = Vector2.new(v.X, v.Z)
	return if p.Magnitude > 1e-6 then p.Unit else Vector2.new(1, 0)
end

function CarContact.new(car: CarClass.Car, raceId: string): CarContact
	local self = (setmetatable({}, CarContact) :: any) :: CarContact
	self.Car = car
	self.RaceId = raceId

	-- Empreinte : celle du gabarit (carrosserie importée comprise), sinon du châssis.
	local size = car.Chassis.Size
	local template = ReplicatedStorage:FindFirstChild("CarTemplate")
	if template and template:IsA("Model") then
		local ok, extents = pcall(function()
			return template:GetExtentsSize()
		end)
		if ok then
			size = extents
		end
	end
	self.HalfWidth = size.X / 2 * FOOTPRINT_MARGIN
	self.HalfLength = size.Z / 2 * FOOTPRINT_MARGIN
	return self
end

-- Demi-largeur de l'empreinte projetée sur un axe.
local function radiusAlong(axis: Vector2, right: Vector2, look: Vector2, halfWidth: number, halfLength: number): number
	return halfWidth * math.abs(right:Dot(axis)) + halfLength * math.abs(look:Dot(axis))
end

function CarContact:Step(_dt: number)
	local chassis = self.Car.Chassis
	local myFrame = chassis.CFrame
	local p1 = chassis.Position
	local v1 = chassis.AssemblyLinearVelocity
	local mass = chassis.AssemblyMass
	local myRight, myLook = flat(myFrame.RightVector), flat(myFrame.LookVector)
	local hw, hl = self.HalfWidth, self.HalfLength

	for _, other in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		if other == chassis or not other:IsA("BasePart") then
			continue
		end
		local model = other.Parent
		if not model or model:GetAttribute("RaceId") ~= self.RaceId then
			continue
		end
		local v2 = other.AssemblyLinearVelocity
		local p2 = other.Position + v2 * EXTRAPOLATION
		if math.abs(p1.Y - p2.Y) > MAX_HEIGHT_GAP then
			continue
		end
		local d = Vector2.new(p1.X - p2.X, p1.Z - p2.Z)
		if d.Magnitude > BROAD_RANGE then
			continue
		end

		-- Axes séparateurs : les côtés des deux rectangles.
		local otherFrame = other.CFrame
		local otherRight, otherLook = flat(otherFrame.RightVector), flat(otherFrame.LookVector)
		local depth = math.huge
		local normal = Vector2.new(1, 0)
		local separated = false
		for _, axis in ipairs({ myRight, myLook, otherRight, otherLook }) do
			local overlap = radiusAlong(axis, myRight, myLook, hw, hl)
				+ radiusAlong(axis, otherRight, otherLook, hw, hl)
				- math.abs(d:Dot(axis))
			if overlap <= 0 then
				separated = true
				break
			end
			if overlap < depth then
				depth = overlap
				-- Orientée de l'autre voiture vers la sienne.
				normal = if d:Dot(axis) >= 0 then axis else -axis
			end
		end
		if separated then
			continue
		end

		local n = Vector3.new(normal.X, 0, normal.Y)
		local relative = v1 - v2
		local approach = relative:Dot(n) -- négatif : les voitures se rapprochent
		local share = if other:GetAttribute("Driven") == true then 0.5 else 1

		local target = math.min(depth * PUSH_GAIN, MAX_PUSH)
		if approach < 0 then
			target = math.max(target, -approach * RESTITUTION)
		end
		local impulse = Vector3.zero
		if approach < target then
			impulse += n * ((target - approach) * share * mass)
		end
		-- Frottement : les carrosseries qui se frottent freinent le glissement relatif.
		local tangent = Vector3.new(-n.Z, 0, n.X)
		local slide = relative:Dot(tangent)
		impulse -= tangent * (slide * FRICTION * share * mass)

		if impulse.Magnitude > 0 then
			local midpoint = (p1 + p2) / 2
			chassis:ApplyImpulseAtPosition(impulse, Vector3.new(midpoint.X, p1.Y, midpoint.Z))
		end
	end
end

return CarContact
