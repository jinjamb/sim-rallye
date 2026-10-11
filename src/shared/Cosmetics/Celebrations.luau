--!strict
--[[
	Celebrations.luau
	Les effets des célébrations de podium (Items/Celebrations.luau), joués
	par le serveur au-dessus de la marche de chaque pilote : vus par tous.

	Uniquement des textures de particules intégrées à Roblox
	(rbxasset://textures/particles/...) : rien à téléverser.

		Confetti    pluie de confettis multicolores (aussi le décor du podium) ;
		Flares      deux colonnes de fumée, à la couleur de la voiture ;
		Fireworks   gerbes d'étincelles qui éclatent en l'air ;
		Champagne   jets de mousse en arc de cercle ;
		Lightning   étincelles bleues et éclairs de lumière ;
		Gold        paillettes d'or qui tombent lentement.
]]

local Celebrations = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function emitterAt(anchor: BasePart, offset: Vector3): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Position = offset
	attachment.Parent = anchor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Parent = attachment
	return emitter
end

-- L'effet joue encore (les boucles d'effets s'arrêtent à la fin de la durée).
local function playing(anchor: BasePart): boolean
	return anchor.Parent ~= nil and anchor:GetAttribute("Playing") == true
end

local function sequence(colors: { Color3 }): ColorSequence
	local points = {}
	for i, color in ipairs(colors) do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
	end
	if #points == 1 then
		return ColorSequence.new(colors[1])
	end
	return ColorSequence.new(points)
end

local BUILDERS: { [string]: (BasePart, Color3?) -> () } = {
	Confetti = function(anchor)
		local emitter = emitterAt(anchor, Vector3.new(0, 10, 0))
		emitter.Texture = SPARKLES
		emitter.Rate = 60
		emitter.Lifetime = NumberRange.new(2.5, 4)
		emitter.Speed = NumberRange.new(4, 10)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Drag = 1.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-200, 200)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Color = sequence({ Color3.fromRGB(245, 200, 55), Color3.fromRGB(235, 65, 55), Color3.fromRGB(70, 150, 255) })
	end,
	Flares = function(anchor, color)
		for _, side in ipairs({ -2.5, 2.5 }) do
			local emitter = emitterAt(anchor, Vector3.new(side, -4, 0))
			emitter.Texture = SMOKE
			emitter.Rate = 25
			emitter.Lifetime = NumberRange.new(3, 5)
			emitter.Speed = NumberRange.new(6, 9)
			emitter.SpreadAngle = Vector2.new(8, 8)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Drag = 0.8
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-25, 25)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 9) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			emitter.Color = ColorSequence.new(color or Color3.fromRGB(235, 50, 45))
			emitter.LightInfluence = 0.3
		end
	end,
	Fireworks = function(anchor)
		local emitter = emitterAt(anchor, Vector3.new(0, 16, 0))
		emitter.Texture = SPARKLES
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(1.2, 1.8)
		emitter.Speed = NumberRange.new(18, 28)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -12, 0)
		emitter.Drag = 2.5
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		local palette = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 170, 255), Color3.fromRGB(120, 255, 140), Color3.fromRGB(230, 110, 255) }
		-- Une gerbe toutes les 0,7 s, d'une couleur au hasard.
		task.spawn(function()
			while playing(anchor) do
				emitter.Color = ColorSequence.new(palette[math.random(#palette)])
				emitter:Emit(70)
				task.wait(0.7)
			end
		end)
	end,
	Champagne = function(anchor)
		for _, side in ipairs({ -1, 1 }) do
			local emitter = emitterAt(anchor, Vector3.new(side * 1.5, 1, 0))
			emitter.Texture = SPARKLES
			emitter.Rate = 120
			emitter.Lifetime = NumberRange.new(1, 1.6)
			emitter.Speed = NumberRange.new(14, 20)
			emitter.SpreadAngle = Vector2.new(12, 12)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Acceleration = Vector3.new(side * 10, -28, 0)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) })
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(255, 225, 140))
			emitter.LightEmission = 0.4
		end
	end,
	Lightning = function(anchor, color)
		local tint = color or Color3.fromRGB(110, 190, 255)
		local emitter = emitterAt(anchor, Vector3.new(0, 6, 0))
		emitter.Texture = SPARKLES
		emitter.Rate = 90
		emitter.Lifetime = NumberRange.new(0.3, 0.7)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		emitter.Color = ColorSequence.new(tint, Color3.new(1, 1, 1))
		-- Éclairs : la lumière claque par à-coups.
		local light = Instance.new("PointLight")
		light.Color = tint
		light.Range = 40
		light.Brightness = 0
		light.Parent = anchor
		task.spawn(function()
			while playing(anchor) do
				light.Brightness = 8
				task.wait(0.06)
				light.Brightness = 0
				task.wait(0.3 + math.random() * 0.9)
			end
		end)
	end,
	Gold = function(anchor, color)
		local emitter = emitterAt(anchor, Vector3.new(0, 14, 0))
		emitter.Texture = SPARKLES
		emitter.Rate = 80
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(90, 90)
		emitter.Acceleration = Vector3.new(0, -2.5, 0)
		emitter.Drag = 0.6
		emitter.LightEmission = 0.8
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
		emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 205, 70), Color3.fromRGB(255, 250, 225))
	end,
}

function Celebrations.Exists(effect: string?): boolean
	return effect ~= nil and BUILDERS[effect] ~= nil
end

--[[
	Joue l'effet `effect` au-dessus de `position` pendant `duration` s (puis
	tout disparaît). `color` : la teinte des effets qui en ont une (fumigènes
	à la couleur de la voiture...).
]]
function Celebrations.Play(parent: Instance, position: Vector3, effect: string, color: Color3?, duration: number)
	local build = BUILDERS[effect]
	if not build then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Celebration"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor:SetAttribute("Playing", true)
	anchor.Parent = parent
	build(anchor, color)
	task.delay(duration, function()
		anchor:SetAttribute("Playing", false)
		-- Les émetteurs s'arrêtent ; les dernières particules finissent leur vie.
		for _, item in ipairs(anchor:GetDescendants()) do
			if item:IsA("ParticleEmitter") then
				item.Enabled = false
			end
		end
		task.delay(6, function()
			anchor:Destroy()
		end)
	end)
end

return Celebrations
