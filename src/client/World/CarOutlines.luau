--!strict
--[[
	CarOutlines.luau
	Le trait d'encre autour des voitures, comme sur un dessin animé : un
	Highlight sans remplissage, dont seul le contour est tracé (couleur Ink
	de l'ambiance en cours, Ambiances.luau).

	Roblox n'affiche que 31 Highlight à la fois : on n'en allume que pour les
	MAX_OUTLINED voitures les plus proches de la caméra (revu deux fois par
	seconde). Les voitures en jeu sont trouvées par leur étiquette (RallyCar,
	posée sur le châssis) ; l'aperçu du garage s'ajoute à la main (Track).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Ambiance = require(script.Parent.Ambiance)

local CarOutlines = {}

local CAR_TAG = "RallyCar"
local MAX_OUTLINED = 24 -- sous la limite de 31, pour laisser de la place à d'autres Highlight
local REFRESH = 0.5 -- secondes entre deux choix des voitures encrées
local OUTLINE_NAME = "InkOutline"

local tracked: { [Model]: Highlight } = {}
local started = false

-- Encre ce modèle (jusqu'à sa destruction).
function CarOutlines.Track(model: Model)
	if tracked[model] then
		return
	end
	local outline = Instance.new("Highlight")
	outline.Name = OUTLINE_NAME
	outline.Adornee = model
	outline.FillTransparency = 1
	outline.OutlineTransparency = 0
	outline.OutlineColor = Ambiance.Current().Ink
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Enabled = false
	outline.Parent = model
	tracked[model] = outline
	model.Destroying:Connect(function()
		tracked[model] = nil
	end)
end

local function onTagged(chassis: Instance)
	-- Seulement les voitures posées dans le monde (pas un modèle rangé dans
	-- ReplicatedStorage, qui porterait aussi l'étiquette).
	local model = chassis.Parent
	if model and model:IsA("Model") and model:IsDescendantOf(workspace) then
		CarOutlines.Track(model)
	end
end

local function refresh()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local ink = Ambiance.Current().Ink
	local ranked: { { Model: Model, Distance: number } } = {}
	for model, outline in pairs(tracked) do
		if model.Parent == nil then
			outline.Enabled = false
		else
			table.insert(ranked, { Model = model, Distance = (model:GetPivot().Position - eye).Magnitude })
		end
	end
	table.sort(ranked, function(a, b)
		return a.Distance < b.Distance
	end)
	for i, entry in ipairs(ranked) do
		local outline = tracked[entry.Model]
		outline.Enabled = i <= MAX_OUTLINED
		outline.OutlineColor = ink
	end
end

function CarOutlines.Start()
	if started then
		return
	end
	started = true
	for _, chassis in ipairs(CollectionService:GetTagged(CAR_TAG)) do
		onTagged(chassis)
	end
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(function(chassis: Instance)
		-- L'étiquette peut arriver avant que le châssis soit rangé dans sa voiture.
		task.defer(onTagged, chassis)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			refresh()
		end
	end)
end

return CarOutlines
