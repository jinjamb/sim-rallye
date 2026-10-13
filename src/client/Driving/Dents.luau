--!strict
--[[
	Dents.luau
	La carrosserie cabossée, chez chaque joueur et pour chaque voiture,
	d'après ses bosses (attributs Dent1 à Dent8 posés par le serveur :
	CarDamage.luau).

	DÉFORMATION : chaque pièce de carrosserie soudée au châssis (dossiers
	CustomBody, ImportedBody, Body, BodyKit) est déplacée depuis sa position
	d'origine, selon la bosse à son angle (mélange des deux zones voisines)
	et sa place sur la caisse : rien au centre, de plus en plus vers les
	bords. Elle rentre vers l'intérieur de la caisse, s'affaisse un peu et
	se tord (angle propre à chaque pièce, toujours le même : la voiture ne
	« tremble » pas d'une mise à jour à l'autre).
	Pour déplacer une pièce soudée : soudure coupée, pièce replacée, soudure
	remise (une WeldConstraint retient la position qu'elle trouve en se
	réactivant). Tout est local : le serveur ne connaît que les bosses.

	EFFETS d'une nouvelle bosse : gerbe d'étincelles et éclats de
	carrosserie au point de choc, son de choc (SoundBank.Crash, s'il est
	renseigné). OnLocalHit : prévenu quand c'est la voiture du joueur.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarDamage = require(ReplicatedStorage.Shared.Vehicle.CarDamage)
local SoundBank = require(script.Parent.Parent.Audio.SoundBank)
local SoundGroups = require(script.Parent.Parent.Audio.SoundGroups)

local Dents = {}

local CAR_TAG = "RallyCar"
local BODY_FOLDERS = { CustomBody = true, ImportedBody = true, Body = true, BodyKit = true }
local DEPTH = 0.85 -- studs : enfoncement d'une zone complètement froissée, au bord
local SAG = 0.18 -- studs : affaissement au même endroit
local TWIST = 0.24 -- radians : torsion maximale d'une pièce
local INNER = 0.35 -- en deçà (part du demi-gabarit), la caisse ne bouge pas

type CarState = {
	Model: Model,
	Chassis: BasePart,
	Rest: { [BasePart]: CFrame }, -- position d'origine (repère du châssis)
	HalfWidth: number,
	HalfLength: number,
	Dents: { number },
	Dirty: boolean,
}

local cars: { [Model]: CarState } = {}
local started = false
local enabled = true -- onglet OPTIONS : « Bosses » (les étincelles restent)
local INTACT = table.create(CarDamage.ZONE_COUNT, 0)

-- Prévenu à chaque nouvelle bosse de la voiture du joueur (secousse, son...).
Dents.OnLocalHit = nil :: ((zone: number, amount: number) -> ())?
Dents.LocalModel = nil :: Model?

-- Un nombre stable tiré du nom et de la place d'une pièce (-1 à 1).
local function hash(part: BasePart, salt: number, rest: CFrame): number
	local p = rest.Position
	local seed = math.floor(p.X * 73.1 + p.Y * 37.7 + p.Z * 19.3 + #part.Name * 11 + salt * 101)
	local value = math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453
	return (value - math.floor(value)) * 2 - 1
end

-- La soudure qui tient la pièce au châssis (WeldConstraint), s'il y en a une.
local function weldOf(part: BasePart, chassis: BasePart): WeldConstraint?
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") and (child.Part0 == chassis or child.Part1 == chassis) then
			return child
		end
	end
	return nil
end

local function inBody(part: BasePart, model: Model): boolean
	local node = part.Parent
	while node and node ~= model do
		if BODY_FOLDERS[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Retient la position d'origine des pièces de carrosserie (une fois).
local function collect(state: CarState)
	local chassis = state.Chassis
	local maxX, maxZ = 0.5, 0.5
	for _, item in ipairs(state.Model:GetDescendants()) do
		if item:IsA("BasePart") and item ~= chassis and inBody(item, state.Model) and weldOf(item, chassis) then
			if not state.Rest[item] then
				state.Rest[item] = chassis.CFrame:ToObjectSpace(item.CFrame)
			end
		end
	end
	for part, rest in pairs(state.Rest) do
		if part.Parent == nil then
			state.Rest[part] = nil
		elseif part.Transparency < 1 then
			maxX = math.max(maxX, math.abs(rest.Position.X) + part.Size.X / 2)
			maxZ = math.max(maxZ, math.abs(rest.Position.Z) + part.Size.Z / 2)
		end
	end
	state.HalfWidth, state.HalfLength = maxX, maxZ
end

-- Replace chaque pièce d'après les bosses actuelles (ou intacte : dents).
local function apply(state: CarState, dents: { number }?)
	collect(state)
	local shown = dents or state.Dents
	local chassis = state.Chassis
	local hw, hl = state.HalfWidth, state.HalfLength
	for part, rest in pairs(state.Rest) do
		local p = rest.Position
		local edge = math.max(math.abs(p.X) / hw, math.abs(p.Z) / hl)
		local reach = math.clamp((edge - INNER) / (1 - INNER), 0, 1) ^ 1.5
		local angle = CarDamage.AngleOf(Vector3.new(p.X, 0, p.Z))
		local amount = CarDamage.At(shown, angle) * reach
		local target = rest
		if amount > 0.005 then
			-- Vers l'intérieur, perpendiculairement au contour (ellipse du gabarit).
			local normal = Vector3.new(p.X / (hw * hw), 0, p.Z / (hl * hl))
			normal = if normal.Magnitude > 1e-6 then normal.Unit else Vector3.zero
			local offset = -normal * (amount * DEPTH) - Vector3.new(0, amount * SAG, 0)
			local twist = CFrame.Angles(hash(part, 1, rest) * amount * TWIST, hash(part, 2, rest) * amount * TWIST, hash(part, 3, rest) * amount * TWIST)
			target = CFrame.new(offset) * rest * twist
		end
		local weld = weldOf(part, chassis)
		if weld then
			local wanted = chassis.CFrame * target
			if (part.CFrame.Position - wanted.Position).Magnitude > 0.01 or amount > 0.005 then
				weld.Enabled = false
				part.CFrame = wanted
				weld.Enabled = true
			end
		end
	end
end

-- Étincelles et éclats au point de choc.
local function burst(state: CarState, zone: number, amount: number)
	local chassis = state.Chassis
	local direction = CarDamage.DirectionOf(zone)
	local localPoint = Vector3.new(direction.X * state.HalfWidth, 0.2, direction.Z * state.HalfLength)
	local attachment = Instance.new("Attachment")
	attachment.Position = localPoint
	attachment.Parent = chassis
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 120, 40))
	sparks.Size = NumberSequence.new(0.18, 0)
	sparks.Lifetime = NumberRange.new(0.25, 0.6)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -60, 0)
	sparks.Drag = 2
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = attachment
	sparks:Emit(math.floor(12 + amount * 50))
	Debris:AddItem(attachment, 1.5)

	-- Éclats de carrosserie : avec les bosses seulement (onglet OPTIONS).
	if enabled then
		-- Éclats : petits morceaux de la couleur de la carrosserie la plus proche.
		local nearest: BasePart? = nil
		local best = math.huge
		for part, rest in pairs(state.Rest) do
			local d = (rest.Position - localPoint).Magnitude
			if d < best and part.Transparency < 1 then
				best, nearest = d, part
			end
		end
		local color = if nearest then nearest.Color else Color3.new(0.8, 0.8, 0.8)
		local origin = chassis.CFrame:PointToWorldSpace(localPoint)
		local outward = chassis.CFrame:VectorToWorldSpace(direction)
		for i = 1, math.floor(2 + amount * 6) do
			local shard = Instance.new("Part")
			shard.Name = "Shard"
			shard.Size = Vector3.new(0.4, 0.06, 0.3) * (0.6 + (i % 3) * 0.3)
			shard.Color = if i % 3 == 0 then Color3.fromRGB(30, 30, 34) else color
			shard.Material = Enum.Material.SmoothPlastic
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.CFrame = CFrame.new(origin) * CFrame.Angles(i, i * 1.7, i * 0.6)
			shard.AssemblyLinearVelocity = chassis.AssemblyLinearVelocity * 0.6 + outward * (10 + i * 2) + Vector3.new(0, 12 + i, 0)
			shard.AssemblyAngularVelocity = Vector3.new(i * 3, i * 5, i * 2)
			shard.Parent = workspace
			Debris:AddItem(shard, 3)
		end
	end

	-- Son de choc (une liste vide : pas de son).
	local sounds = SoundBank.Crash
	if #sounds > 0 then
		local sound = Instance.new("Sound")
		sound.SoundId = sounds[math.random(1, #sounds)]
		sound.Volume = 0.4 + amount
		sound.PlaybackSpeed = 0.9 + math.random() * 0.25
		sound.RollOffMaxDistance = 300
		sound.SoundGroup = SoundGroups.Get("Effets")
		sound.Parent = attachment
		sound:Play()
	end
end

local function refresh(state: CarState)
	local fresh = CarDamage.Read(state.Model)
	for zone = 1, CarDamage.ZONE_COUNT do
		local gained = fresh[zone] - state.Dents[zone]
		-- Une bosse franche (pas le simple report sur les zones voisines).
		if gained > 0.05 and fresh[zone] >= math.max(fresh[(zone - 2) % 8 + 1], fresh[zone % 8 + 1]) then
			burst(state, zone, gained)
			if state.Model == Dents.LocalModel and Dents.OnLocalHit then
				(Dents.OnLocalHit :: any)(zone, gained)
			end
		end
	end
	state.Dents = fresh
	state.Dirty = true
end

local function track(chassis: Instance)
	local model = chassis.Parent
	if not chassis:IsA("BasePart") or not model or not model:IsA("Model") or cars[model] then
		return
	end
	if not model:IsDescendantOf(workspace) then
		return
	end
	local state: CarState = {
		Model = model,
		Chassis = chassis,
		Rest = setmetatable({}, { __mode = "k" }) :: any,
		HalfWidth = 3,
		HalfLength = 6.5,
		Dents = table.create(CarDamage.ZONE_COUNT, 0),
		Dirty = false,
	}
	cars[model] = state
	model.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 4) == "Dent" then
			refresh(state)
		end
	end)
	-- Carrosserie reconstruite (livrée changée) : les nouvelles pièces se cabossent aussi.
	model.DescendantAdded:Connect(function(item: Instance)
		if item:IsA("BasePart") then
			state.Dirty = true
		end
	end)
	model.Destroying:Connect(function()
		cars[model] = nil
	end)
	refresh(state)
end

-- Bosses (et éclats) affichées ou non ; les étincelles restent toujours.
function Dents.SetEnabled(on: boolean)
	if enabled == on then
		return
	end
	enabled = on
	for _, state in pairs(cars) do
		state.Dirty = true
	end
end

function Dents.Start()
	if started then
		return
	end
	started = true
	for _, chassis in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		track(chassis)
	end
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(chassis: Instance)
		task.defer(track, chassis)
	end)
	-- Une mise à jour par image au plus, et seulement pour les voitures qui ont changé.
	RunService.Heartbeat:Connect(function()
		for model, state in pairs(cars) do
			if model.Parent == nil then
				cars[model] = nil
			elseif state.Dirty then
				state.Dirty = false
				local any = false
				for _, value in ipairs(state.Dents) do
					if value > 0 then
						any = true
						break
					end
				end
				if any then
					apply(state, if enabled then nil else INTACT)
				end
			end
		end
	end)
end

return Dents
