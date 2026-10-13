--!strict
--[[
	RemoteCars.luau
	Les voitures des AUTRES joueurs, vues de ce client.

	Leur physique tourne chez leur pilote ; Roblox ne nous réplique que la
	position du châssis. Tout le reste est reconstitué ici :
		- ROUES : rayons lancés localement sous chaque roue (la suspension
		  suit le sol), rotation déduite de la vitesse, braquage de la télémétrie ;
		- SON : le même CarAudio que pour sa propre voiture, piloté par la
		  télémétrie que le pilote diffuse (régime, charge, glissements) ;
		- POUSSIÈRE : le même CarEffects, sur les surfaces que touchent nos rayons.
	Télémétrie : attributs posés sur le châssis par CarService (Rpm, Load,
	Steer, Screech, GravelSlide, GravelShare, TarmacShare, Brake, Driven).

	INSTANCES DE COURSE : on ne voit que les voitures du même "monde" que la
	sienne -- même course (attribut RaceId de la voiture), ou toutes celles du
	paddock. Plusieurs courses peuvent tourner sur le même circuit : sans ça, on y
	verrait rouler les voitures des autres courses, au travers de la sienne.
	Masquage purement local (LocalTransparencyModifier) : rien n'est modifié pour
	les autres joueurs.
	Le nom du pilote flotte au-dessus de chaque voiture visible.
	SILLAGE : derrière chaque voiture lancée, une traînée d'air ; celle de
	la voiture qu'on aspire (Slipstream.luau) s'allume en cyan.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Surfaces = require(ReplicatedStorage.Shared.Vehicle.Surfaces)
local Medals = require(ReplicatedStorage.Shared.Progression.Medals)
local Progression = require(ReplicatedStorage.Shared.Progression.Progression)
local CarClasses = require(ReplicatedStorage.Shared.Vehicle.CarClasses)
local Livery = require(ReplicatedStorage.Shared.Cosmetics.Livery)
local CarAudio = require(script.Parent.Parent.Audio.CarAudio)
local CarEffects = require(script.Parent.CarEffects)
local TireSmoke = require(script.Parent.TireSmoke)
local Theme = require(script.Parent.Parent.UI.Theme)

local RemoteCars = {}
RemoteCars.__index = RemoteCars

type RemoteWheel = {
	Attachment: Attachment,
	IsGrounded: boolean,
	Surface: Surfaces.SurfaceProperties,
	ContactPoint: Vector3,
	LongSlipNorm: number,
	LatSlipNorm: number,
	Motor: Motor6D?,
	Radius: number,
	IsFront: boolean,
	Spin: number,
}

type View = {
	Model: Model,
	Chassis: BasePart,
	Wheels: { RemoteWheel },
	Audio: CarAudio.CarAudio,
	Effects: CarEffects.CarEffects,
	Smoke: TireSmoke.TireSmoke, -- fumée de glisse, à la couleur portée par son pilote
	RayParams: RaycastParams,
	NameTag: BillboardGui,
	NameLabel: TextLabel,
	Visible: boolean,
	-- Sillage : une traînée de chaque côté de l'arrière, et leurs points d'attache.
	Wake: { Trail },
	WakePoints: { Attachment },
}

local WAKE_SPEED = 40 -- studs/s : en dessous, pas de sillage (Slipstream : MIN_SPEED)
local WAKE_DEFAULT_Z = 7.3
local WAKE_HALF_WIDTH = 2.6
local WAKE_HEIGHT = 1.6
local WAKE_COLOR = Color3.fromRGB(235, 240, 255)
local WAKE_DRAFT_COLOR = Color3.fromRGB(0, 214, 255)
local WAKE_TRANSPARENCY = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) })
local WAKE_DRAFT_TRANSPARENCY = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })

-- Le sillage d'une voiture : deux traînées verticales aux coins arrière.
local function makeWake(chassis: BasePart): ({ Trail }, { Attachment })
	local trails, points = {}, {}
	for _, side in ipairs({ -1, 1 }) do
		local low = Instance.new("Attachment")
		low.Name = "WakeLow"
		low.Position = Vector3.new(side * WAKE_HALF_WIDTH, 0, WAKE_DEFAULT_Z)
		low.Parent = chassis
		local high = Instance.new("Attachment")
		high.Name = "WakeHigh"
		high.Position = Vector3.new(side * WAKE_HALF_WIDTH, WAKE_HEIGHT, WAKE_DEFAULT_Z)
		high.Parent = chassis
		local trail = Instance.new("Trail")
		trail.Name = "Wake"
		trail.Attachment0 = low
		trail.Attachment1 = high
		trail.FaceCamera = true
		trail.Lifetime = 0.5
		trail.MinLength = 0.3
		trail.LightEmission = 0.4
		trail.LightInfluence = 0.3
		trail.WidthScale = NumberSequence.new(1, 0.25)
		trail.Color = ColorSequence.new(WAKE_COLOR)
		trail.Transparency = WAKE_TRANSPARENCY
		trail.Enabled = false
		trail.Parent = chassis
		table.insert(trails, trail)
		table.insert(points, low)
		table.insert(points, high)
	end
	return trails, points
end

-- UserId du roi du drift de la semaine (ChallengeService), affiché sur sa voiture.
local driftKing: number? = nil

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- "#7 Pilote · NATIONALE 12 · Rally4" : numéro de course (livrée), nom,
-- licence et niveau dans la couleur de la licence (posés par le serveur,
-- Progression.luau), catégorie de la voiture.
local function nameText(model: Model): string
	local name = escape(tostring(model:GetAttribute("OwnerName") or ""))
	-- Sigle de son écurie, dans sa couleur (Teams.luau).
	local tag = model:GetAttribute("TeamTag")
	local teamColor = Livery.COLORS[tonumber(model:GetAttribute("TeamColor")) or 0]
	if type(tag) == "string" and teamColor then
		name = string.format('<font color="%s">[%s]</font> %s', Medals.Hex(teamColor.Color), escape(tag), name)
	end
	-- Pass VIP (MonetizationService : attribut Vip du joueur) : badge doré.
	local ownerId = model:GetAttribute("OwnerUserId")
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	if owner and owner:GetAttribute("Vip") == true then
		name = '<font color="#ffcc00"><b>VIP</b></font> ' .. name
	end
	local number = model:GetAttribute("RaceNumber")
	local text = if type(number) == "number" then string.format("#%d %s", number, name) else name
	local level = model:GetAttribute("Level")
	local licence = Progression.LICENCES[tonumber(model:GetAttribute("Licence")) or 0]
	if licence and type(level) == "number" then
		text ..= string.format(' <font color="%s">· %s %d</font>', Medals.Hex(licence.Color), licence.Short, level)
	end
	-- Roi du drift de la semaine : son titre.
	if model:GetAttribute("OwnerUserId") == driftKing then
		text ..= ' <font color="#ffcc00">· ★ ROI DU DRIFT</font>'
	end
	-- Sa catégorie de voiture (CarClasses.luau), en discret.
	local class = model:GetAttribute("CarClass")
	if CarClasses.Exists(class) then
		text ..= ' <font color="#a0a4b0">· ' .. escape(CarClasses.Get(class).Name) .. "</font>"
	end
	return text
end

export type RemoteCars = typeof(setmetatable({}, RemoteCars)) & {
	LocalUserId: number,
	LocalRaceId: string?,
	DraftLeader: number?, -- UserId de la voiture qu'on aspire
	Views: { [BasePart]: View },
}

local CAR_TAG = "RallyCar"
local CAR_COLLISION_GROUP = "Cars"
local SUSPENSION_LENGTH = 1.6 -- doit correspondre à Wheel.luau
-- La télémétrie envoie le braquage rapporté à 60° (Main.client.luau) : l'angle
-- maximal de chaque voiture est un réglage du joueur.
local MAX_STEER = math.rad(60)
local WHEEL_SUFFIXES = { "FL", "FR", "RL", "RR" }

function RemoteCars.new(localUserId: number): RemoteCars
	local self = (setmetatable({}, RemoteCars) :: any) :: RemoteCars
	self.LocalUserId = localUserId
	self.LocalRaceId = nil
	self.DraftLeader = nil
	self.Views = {}

	for _, chassis in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		task.spawn(function()
			self:_add(chassis)
		end)
	end
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(chassis: Instance)
		self:_add(chassis)
	end)
	CollectionService:GetInstanceRemovedSignal(CAR_TAG):Connect(function(chassis: Instance)
		self:_remove(chassis)
	end)
	return self
end

function RemoteCars:_add(instance: Instance)
	if not instance:IsA("BasePart") or self.Views[instance] then
		return
	end
	local chassis = instance
	local model = chassis.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local owner = model:GetAttribute("OwnerUserId")
	if owner == nil or owner == self.LocalUserId then
		return -- sa propre voiture est simulée pour de vrai (Main.client.luau)
	end

	local wheels: { RemoteWheel } = {}
	local attachments: { Attachment } = {}
	for _, suffix in ipairs(WHEEL_SUFFIXES) do
		local attachment = chassis:WaitForChild("Wheel" .. suffix, 10)
		if not attachment or not attachment:IsA("Attachment") then
			return
		end
		local tire = model:FindFirstChild("Tire" .. suffix)
		local motor = chassis:FindFirstChild("Motor" .. suffix)
		table.insert(attachments, attachment)
		table.insert(wheels, {
			Attachment = attachment,
			IsGrounded = false,
			Surface = Surfaces.Default,
			ContactPoint = attachment.WorldPosition,
			LongSlipNorm = 0,
			LatSlipNorm = 0,
			Motor = if motor and motor:IsA("Motor6D") then motor else nil,
			Radius = if tire and tire:IsA("BasePart") then tire.Size.Y / 2 else 1,
			IsFront = string.sub(suffix, 1, 1) == "F",
			Spin = 0,
		})
	end
	if self.Views[chassis] or not chassis:IsDescendantOf(workspace) then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	if PhysicsService:IsCollisionGroupRegistered(CAR_COLLISION_GROUP) then
		params.CollisionGroup = CAR_COLLISION_GROUP
	end

	-- Nom du pilote, au-dessus de la voiture.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(300, 28) -- nom et licence
	tag.StudsOffset = Vector3.new(0, 6.5, 0)
	tag.MaxDistance = 350
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.BODY_BOLD
	label.TextSize = 17
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.RichText = true
	label.Text = nameText(model)
	label.Parent = tag
	tag.Adornee = chassis
	tag.Parent = chassis

	local wake, wakePoints = makeWake(chassis)
	local view: View = {
		Model = model,
		Chassis = chassis,
		Wheels = wheels,
		Audio = CarAudio.new(chassis, attachments, false, model),
		Effects = CarEffects.new(chassis, wheels :: any),
		Smoke = TireSmoke.new(model, chassis, attachments),
		RayParams = params,
		NameTag = tag,
		NameLabel = label,
		Visible = true,
		Wake = wake,
		WakePoints = wakePoints,
	}
	self.Views[chassis] = view
	self:_applyVisibility(view)
	-- Numéros reposés après coup (livrée modifiée) : masqués eux aussi si besoin.
	model.DescendantAdded:Connect(function(item: Instance)
		if view.Visible then
			return
		end
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = 1
		elseif item:IsA("SurfaceGui") then
			item.Enabled = false
		end
	end)
end

function RemoteCars:_remove(instance: Instance)
	local view = self.Views[instance :: BasePart]
	if not view then
		return
	end
	self.Views[instance :: BasePart] = nil
	view.Audio:Destroy()
	view.Effects:Destroy()
	view.Smoke:Destroy()
	view.NameTag:Destroy()
	for _, item in ipairs(view.Wake) do
		item:Destroy()
	end
	for _, point in ipairs(view.WakePoints) do
		point:Destroy()
	end
end

-- La voiture qu'on aspire (Slipstream.luau) : son sillage s'allume.
function RemoteCars:SetDraftLeader(userId: number?)
	self.DraftLeader = userId
end

-- Sillage d'une voiture : visible à pleine vitesse, en cyan si on l'aspire.
local function updateWake(model: Model, points: { Attachment }, trails: { Trail }, driven: boolean, speed: number, drafted: boolean)
	local z = model:GetAttribute("TailLightZ")
	local rearZ = if type(z) == "number" then z else WAKE_DEFAULT_Z
	for index, point in ipairs(points) do
		local side = if index <= 2 then -1 else 1
		local height = if index % 2 == 0 then WAKE_HEIGHT else 0
		point.Position = Vector3.new(side * WAKE_HALF_WIDTH, height, rearZ)
	end
	local enabled = driven and speed >= WAKE_SPEED
	for _, trail in ipairs(trails) do
		trail.Enabled = enabled
		trail.Color = ColorSequence.new(if drafted then WAKE_DRAFT_COLOR else WAKE_COLOR)
		trail.Transparency = if drafted then WAKE_DRAFT_TRANSPARENCY else WAKE_TRANSPARENCY
		trail.Lifetime = if drafted then 0.8 else 0.5
	end
end

-- Même monde que soi : même course, ou tous les deux au paddock.
function RemoteCars:_shouldShow(view: View): boolean
	local raceId = view.Model:GetAttribute("RaceId")
	return raceId == self.LocalRaceId
end

function RemoteCars:_applyVisibility(view: View)
	local visible = self:_shouldShow(view)
	view.Visible = visible
	local modifier = if visible then 0 else 1
	for _, item in ipairs(view.Model:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = modifier
		elseif item:IsA("SurfaceGui") then
			-- Numéros de course : un SurfaceGui ignore la transparence de sa pièce.
			item.Enabled = visible
		end
	end
	view.NameTag.Enabled = visible
	if not visible then
		view.Audio:SetActive(false)
		view.Effects:SetActive(false)
		view.Smoke:SetActive(false)
	end
end

-- Course de sa propre voiture (nil = paddock) : seules les voitures du même
-- monde restent visibles.
function RemoteCars:SetDriftKing(userId: number?)
	driftKing = userId
end

function RemoteCars:SetLocalRaceId(raceId: string?)
	if raceId == self.LocalRaceId then
		return
	end
	self.LocalRaceId = raceId
	for _, view in pairs(self.Views) do
		self:_applyVisibility(view)
	end
end

-- Voitures visibles (autres que la sienne), pour la mini-carte et le mode spectateur.
function RemoteCars:GetVisibleCars(): { [number]: BasePart }
	local cars = {}
	for chassis, view in pairs(self.Views) do
		if view.Visible and chassis:IsDescendantOf(workspace) then
			local owner = view.Model:GetAttribute("OwnerUserId")
			if type(owner) == "number" then
				cars[owner] = chassis
			end
		end
	end
	return cars
end

local function attributeNumber(part: BasePart, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

function RemoteCars:Update(dt: number)
	for chassis, view in pairs(self.Views) do
		if not chassis:IsDescendantOf(workspace) then
			continue -- hors de portée (streaming) : on attend qu'elle revienne
		end
		-- Une voiture peut changer de course sans être recréée (rare) : on revérifie.
		if self:_shouldShow(view) ~= view.Visible then
			self:_applyVisibility(view)
		end
		if not view.Visible then
			continue
		end
		-- La livrée peut changer en cours de route (menu) : numéro à jour.
		local text = nameText(view.Model)
		if view.NameLabel.Text ~= text then
			view.NameLabel.Text = text
		end
		local driven = chassis:GetAttribute("Driven") == true
		view.Audio:SetActive(driven)
		view.Effects:SetActive(driven)
		view.Smoke:SetActive(driven)

		local frame = chassis.CFrame
		local down = -frame.UpVector * SUSPENSION_LENGTH
		local velocity = chassis.AssemblyLinearVelocity
		local forwardSpeed = velocity:Dot(frame.LookVector)
		local steer = attributeNumber(chassis, "Steer", 0) * MAX_STEER
		local slide = attributeNumber(chassis, "GravelSlide", 0)
		-- La poussière (CarEffects) lit un glissement normalisé : on le
		-- reconstitue à partir du niveau de glisse diffusé.
		local slipForDust = if slide > 0 then 0.9 + slide * 1.5 else 0

		for _, wheel in ipairs(view.Wheels) do
			local result = workspace:Raycast(wheel.Attachment.WorldPosition, down, view.RayParams)
			local distance = if result then result.Distance else SUSPENSION_LENGTH
			wheel.IsGrounded = result ~= nil
			if result then
				wheel.ContactPoint = result.Position
				wheel.Surface = Surfaces.Get(result.Material)
			end
			wheel.LongSlipNorm = slipForDust
			wheel.Spin = (wheel.Spin - forwardSpeed / wheel.Radius * dt) % (math.pi * 2)

			local motor = wheel.Motor
			if motor then
				-- Même convention que Wheel:UpdateVisual : la roue pose sur le sol
				-- touché par le rayon ; en l'air, suspension complètement détendue.
				motor.C0 = CFrame.new(wheel.Attachment.Position + Vector3.new(0, wheel.Radius - distance, 0))
					* CFrame.Angles(0, if wheel.IsFront then steer else 0, 0)
					* CFrame.Angles(wheel.Spin, 0, 0)
			end
		end

		local owner = view.Model:GetAttribute("OwnerUserId")
		updateWake(view.Model, view.WakePoints, view.Wake, driven, velocity.Magnitude, owner ~= nil and owner == self.DraftLeader)
		if driven then
			local screech = attributeNumber(chassis, "Screech", 0)
			-- Un seul niveau diffusé : la fumée sort des quatre roues à la fois.
			view.Smoke:Update({ screech, screech, screech, screech })
			view.Audio:Update(dt, {
				Rpm = attributeNumber(chassis, "Rpm", 1000),
				Load = attributeNumber(chassis, "Load", 0),
				Speed = velocity.Magnitude,
				Brake = attributeNumber(chassis, "Brake", 0),
				-- Un seul niveau diffusé : réparti sur les quatre roues.
				Screech = { screech, screech, screech, screech },
				GravelShare = attributeNumber(chassis, "GravelShare", 0),
				GravelSlide = slide,
				TarmacShare = attributeNumber(chassis, "TarmacShare", 0),
			})
			view.Effects:Update(dt)
		end
	end
end

return RemoteCars
