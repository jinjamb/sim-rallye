--!strict
--[[
	BodyKits.luau
	Ce qui distingue les catégories au premier coup d'œil, sur le même
	gabarit (CarClasses.luau : Body) :
		Rally2    la carrosserie du gabarit, telle quelle ;
		Rally4    sans le grand aileron : un simple becquet de toit ;
		WRC       grand aileron du gabarit, lame avant et canards, ailes
		          ouvertes, écope de toit ;
		Groupe B  aileron haut à double étage, prises d'air sur les flancs,
		          ailes encore élargies.

	Les pièces ajoutées sont cosmétiques (sans masse, sans collision, ni
	requête de rayon : elles ne gênent ni la physique ni les numéros posés
	par LiveryPainter), soudées au châssis, en carbone sombre : la livrée ne
	les repeint pas. Les pièces du gabarit qu'un kit retire sont seulement
	rendues invisibles.

	Appliqué par le serveur à chaque voiture (CarService : vu par tous), et
	par le client à ses aperçus (garage, ralenti). Un gabarit importé
	(tools/attach-body.luau) sans pièce nommée "Wing" garde sa carrosserie ;
	seuls les ajouts du kit apparaissent.
]]

local BodyKits = {}

local CARBON = Color3.fromRGB(28, 29, 33)
local KIT_FOLDER = "BodyKit"

type PartSpec = { Name: string, Size: Vector3, Offset: CFrame }

-- Positions dans le repère du châssis (6 x 2 x 14 studs, l'avant en -Z).
local KITS: { [string]: { Hide: { string }, Add: { PartSpec } } } = {
	Rally2 = { Hide = {}, Add = {} },
	Rally4 = {
		Hide = { "Wing", "WingPost" },
		Add = {
			{ Name = "RoofSpoiler", Size = Vector3.new(5.2, 0.16, 1.0), Offset = CFrame.new(0, 3.5, 3.2) * CFrame.Angles(math.rad(-8), 0, 0) },
		},
	},
	WRC = {
		Hide = {},
		Add = {
			{ Name = "Splitter", Size = Vector3.new(6.2, 0.14, 1.1), Offset = CFrame.new(0, 0.15, -7.2) },
			{ Name = "Canard", Size = Vector3.new(0.9, 0.1, 0.7), Offset = CFrame.new(-2.9, 0.75, -6.9) * CFrame.Angles(0, 0, math.rad(12)) },
			{ Name = "Canard", Size = Vector3.new(0.9, 0.1, 0.7), Offset = CFrame.new(2.9, 0.75, -6.9) * CFrame.Angles(0, 0, math.rad(-12)) },
			{ Name = "RoofScoop", Size = Vector3.new(1.2, 0.35, 1.0), Offset = CFrame.new(0, 3.45, -0.6) },
			{ Name = "WideFlare", Size = Vector3.new(0.35, 0.8, 3.0), Offset = CFrame.new(-3.3, 0.6, 4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.35, 0.8, 3.0), Offset = CFrame.new(3.3, 0.6, 4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.35, 0.8, 3.0), Offset = CFrame.new(-3.3, 0.6, -4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.35, 0.8, 3.0), Offset = CFrame.new(3.3, 0.6, -4.45) },
		},
	},
	GroupB = {
		Hide = { "Wing", "WingPost" },
		Add = {
			{ Name = "WingUpper", Size = Vector3.new(6.6, 0.2, 1.7), Offset = CFrame.new(0, 4.35, 5.9) },
			{ Name = "WingLower", Size = Vector3.new(6.2, 0.16, 1.2), Offset = CFrame.new(0, 3.55, 6.1) },
			{ Name = "WingPlate", Size = Vector3.new(0.12, 1.2, 1.9), Offset = CFrame.new(-3.3, 3.95, 5.95) },
			{ Name = "WingPlate", Size = Vector3.new(0.12, 1.2, 1.9), Offset = CFrame.new(3.3, 3.95, 5.95) },
			{ Name = "SideIntake", Size = Vector3.new(0.3, 0.9, 1.6), Offset = CFrame.new(-3.1, 1.55, 2.2) },
			{ Name = "SideIntake", Size = Vector3.new(0.3, 0.9, 1.6), Offset = CFrame.new(3.1, 1.55, 2.2) },
			{ Name = "WideFlare", Size = Vector3.new(0.45, 1.0, 3.4), Offset = CFrame.new(-3.4, 0.55, 4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.45, 1.0, 3.4), Offset = CFrame.new(3.4, 0.55, 4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.45, 1.0, 3.4), Offset = CFrame.new(-3.4, 0.55, -4.45) },
			{ Name = "WideFlare", Size = Vector3.new(0.45, 1.0, 3.4), Offset = CFrame.new(3.4, 0.55, -4.45) },
		},
	},
}

-- Applique le kit `kitId` (remplace celui qui était posé).
function BodyKits.Apply(car: Model, kitId: string)
	local chassis = car:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return
	end
	local kit = KITS[kitId] or KITS.Rally2
	local old = car:FindFirstChild(KIT_FOLDER)
	if old then
		old:Destroy()
	end
	-- Retenu pour CarBodies : revenir à la carrosserie d'origine remet le kit.
	car:SetAttribute("KitId", kitId)
	-- Un modèle construit par le jeu (CarBodies) a ses propres pièces : le kit
	-- de la catégorie, taillé pour la carrosserie d'origine, n'y tomberait pas.
	if car:GetAttribute("CustomBody") == true then
		return
	end

	local hidden: { [string]: boolean } = {}
	for _, name in ipairs(kit.Hide) do
		hidden[name] = true
	end
	local body = car:FindFirstChild("Body")
	if body then
		for _, part in ipairs(body:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Transparence d'origine retenue, pour pouvoir changer de kit.
				local original = part:GetAttribute("KitTransparency")
				if original == nil then
					part:SetAttribute("KitTransparency", part.Transparency)
					original = part.Transparency
				end
				part.Transparency = if hidden[part.Name] then 1 else original :: number
			end
		end
	end

	if #kit.Add == 0 then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = KIT_FOLDER
	for _, spec in ipairs(kit.Add) do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Size = spec.Size
		part.CFrame = chassis.CFrame * spec.Offset
		part.Color = CARBON
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = chassis
		weld.Parent = part
		part.Parent = folder
	end
	folder.Parent = car
end

return BodyKits
