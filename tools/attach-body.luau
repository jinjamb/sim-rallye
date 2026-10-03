--[[
	attach-body.luau
	À COLLER DANS LA BARRE DE COMMANDES DE ROBLOX STUDIO (Ctrl+9, puis Ctrl+Entrée),
	en mode ÉDITION (pas en Play). Ce fichier n'est PAS synchronisé par Rojo.

	Transforme un modèle importé (Creator Store, Importer 3D) en CARROSSERIE de la
	voiture construite par build-rig.luau :

		0. insère le modèle et sélectionne-le dans l'Explorateur (un Model, ou
		   une MeshPart seule) ;
		1. lance ce script.

	Il fait, dans l'ordre :
		- supprime TOUS les scripts du modèle (les modèles gratuits en cachent
		  parfois de malveillants), ainsi que sièges, Humanoid, sons, prompts et
		  jointures d'origine ;
		- met de côté les roues du modèle (repérées par leur nom) ;
		- oriente le modèle sur le châssis (avant vers -Z), le met à l'échelle
		  (longueur visée) et le centre ;
		- MESURE les roues du modèle et y place celles du gabarit : position des
		  essieux, voie, rayon, largeur. La carrosserie est posée pour que ses
		  roues touchent le sol, et décalée pour centrer les essieux sur le
		  châssis (sinon la répartition des masses serait faussée). La physique
		  suit seule : empattement, voie et rayon sont relus sur le gabarit ;
		- supprime les roues du modèle : ce sont celles du gabarit qui tournent,
		  braquent et suivent la suspension ;
		- rend chaque pièce purement décorative (sans masse, sans collision,
		  invisible pour la suspension), la soude au châssis, la range dans
		  RallyCar ("ImportedBody"), retire la carrosserie procédurale ("Body")
		  et rend le châssis invisible (ses coins dépasseraient).

	Annulable d'un Ctrl+Z. Pour RECOMMENCER avec d'autres réglages, il faut
	repartir du modèle d'origine (ses roues ont été supprimées au premier
	passage) : supprime RallyCar.ImportedBody, réinsère le modèle, relance.
	Note : relancer build-rig.luau remet le gabarit d'origine ; pour garder
	l'ajustement des roues, reporte dans build-rig les valeurs affichées.

	ORIENTATION : chaque créateur choisit ses axes. Le script redresse,
	aligne et remet sur ses roues le modèle tout seul (AUTO_ORIENT), et devine
	l'avant d'après le nom des pièces (phares, capot, feux, coffre...). Si ça
	ne suffit pas : ROTATION_DEGREES.Y = 180 (capot vers l'arrière) ou
	ROTATION_DEGREES.Z = 180 (sur le toit).
]]

--------------------------------------------------------------------------------
-- Réglages
--------------------------------------------------------------------------------

--[[
	Orientation AUTOMATIQUE : une voiture a sa hauteur comme plus petite
	dimension et sa longueur comme plus grande. Le script redresse donc un
	modèle couché et tourne un modèle de travers tout seul.
	Ce qu'il ne peut pas deviner : l'avant de l'arrière. Si la voiture roule
	"à reculons" (capot vers l'arrière), mets ROTATION_DEGREES.Y = 180.
]]
local AUTO_ORIENT = true
-- Rotation ajoutée APRÈS l'orientation automatique (ou seule, si AUTO_ORIENT = false).
local ROTATION_DEGREES = Vector3.new(0, 0, 0)
-- Longueur visée (studs) : celle du gabarit (14 studs = 3.9 m). nil = taille d'origine.
local TARGET_LENGTH: number? = 14
-- Garde au sol, utilisée seulement si les roues du modèle ne sont pas trouvées.
local GROUND_CLEARANCE = 0.45
-- Décalages fins (studs, repère du châssis : X droite, Y haut, Z arrière).
local NUDGE = Vector3.new(0, 0, 0)
-- Placer les roues du gabarit dans les passages de roue du modèle ?
local FIT_WHEELS = true
-- Retirer la carrosserie procédurale de build-rig ?
local REMOVE_PROCEDURAL_BODY = true
-- Rendre le châssis invisible ? C'est un pavé à angles vifs : sous une
-- carrosserie arrondie, ses coins dépassent. Il garde sa masse et ses collisions.
local HIDE_CHASSIS = true

-- Mots qui désignent une roue dans un nom de pièce (minuscules), comme mots
-- entiers. WHEEL_EXCLUDE : le volant n'est pas une roue.
local WHEEL_PATTERNS = { "wheel", "tire", "tyre", "rim", "roue", "pneu", "jante" }
local WHEEL_EXCLUDE = { "steer", "volant" }
-- Indices de l'avant et de l'arrière, lus dans les noms des pièces (et de leurs
-- groupes) pour deviner le sens du modèle. Mots entiers, comme pour les roues.
local FRONT_WORDS = { "front", "head", "headlight", "hood", "bonnet", "grille", "grill", "windshield", "avant", "phare", "capot", "calandre" }
local REAR_WORDS = { "rear", "back", "tail", "taillight", "trunk", "boot", "spoiler", "exhaust", "arriere", "arrière", "coffre", "aileron", "echappement", "pot" }
-- Socle, plateau tournant ou présentoir des modèles d'exposition : ce n'est pas
-- la voiture, il est SUPPRIMÉ avant toute mesure (il fausserait l'échelle, le
-- centrage et la mesure des roues). Recherche en sous-chaîne : "wheel platform".
local DISPLAY_PATTERNS = { "platform", "plateforme", "turntable", "showroom", "display", "socle", "podium" }

-- Géométrie du gabarit (doit correspondre à tools/build-rig.luau et Wheel.luau) :
-- au repos, le sol est 1.12 stud sous les points d'attache des roues, eux-mêmes
-- sous le châssis (y = -1) : le bas des pneus est donc à y = -2.12.
local REST_DROP = 1.12
local WHEEL_RADIUS_RANGE = { 0.7, 1.6 } -- au-delà, la mesure est sans doute fausse
local WHEEL_WIDTH_RANGE = { 0.6, 1.6 }

--------------------------------------------------------------------------------

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local car = workspace:FindFirstChild("RallyCar")
local chassis = car and car:FindFirstChild("Chassis")
assert(car and chassis and chassis:IsA("BasePart"), "[attach-body] RallyCar.Chassis introuvable : lance d'abord tools/build-rig.luau")
local attachmentY = -chassis.Size.Y / 2
local groundY = attachmentY - REST_DROP

local selected = Selection:Get()[1]
assert(selected, "[attach-body] Sélectionne le modèle à attacher dans l'Explorateur")
assert(selected ~= car and not chassis:IsDescendantOf(selected), "[attach-body] Sélectionne le modèle importé, pas la voiture entière")

-- Une MeshPart seule : on l'emballe dans un Model (ScaleTo et PivotTo en ont besoin).
local model: Model
if selected:IsA("Model") then
	model = selected
elseif selected:IsA("BasePart") then
	model = Instance.new("Model")
	model.Name = selected.Name
	model.Parent = selected.Parent
	selected.Parent = model
else
	error("[attach-body] La sélection doit être un Model ou une pièce (MeshPart)")
end

-- Enregistrement pour Ctrl+Z (API récente si disponible, sinon points d'annulation).
local recording: string? = nil
local ok, result = pcall(function()
	return ChangeHistoryService:TryBeginRecording("attach-body")
end)
if ok then
	recording = result
else
	ChangeHistoryService:SetWaypoint("Avant attach-body")
end

local function matchesAny(name: string, patterns: { string }): boolean
	local lower = string.lower(name)
	for _, pattern in ipairs(patterns) do
		if string.find(lower, pattern, 1, true) then
			return true
		end
	end
	return false
end

--[[
	Le mot doit être un mot ENTIER du nom : en tête, après un séparateur
	("front_wheel", "Wheel FL") ou en début de majuscule ("FrontWheel").
	Sinon "rim" attraperait "Trim" (une baguette de carrosserie).
]]
local function matchesWord(name: string, patterns: { string }): boolean
	local lower = string.lower(name)
	for _, pattern in ipairs(patterns) do
		local start = 1
		while true do
			local index = string.find(lower, pattern, start, true)
			if not index then
				break
			end
			local before = if index > 1 then string.sub(name, index - 1, index - 1) else ""
			local first = string.sub(name, index, index)
			local wordStart = index == 1
				or not string.match(before, "%a")
				or (string.match(first, "%u") ~= nil and string.match(before, "%l") ~= nil)
			if wordStart then
				return true
			end
			start = index + 1
		end
	end
	return false
end

local function weld(part0: BasePart, part1: BasePart, parent: Instance)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = parent
end

--------------------------------------------------------------------------------
-- 1. Nettoyage, et tri entre carrosserie et roues
--------------------------------------------------------------------------------

local removedScripts, removedOther = 0, 0
for _, item in ipairs(model:GetDescendants()) do
	if item.Parent == nil then
		continue -- déjà supprimé avec un parent
	end
	if item:IsA("LuaSourceContainer") then
		item:Destroy()
		removedScripts += 1
	elseif item:IsA("Seat") or item:IsA("VehicleSeat") or item:IsA("Humanoid")
		or item:IsA("Sound") or item:IsA("ProximityPrompt") or item:IsA("ClickDetector")
		or item:IsA("JointInstance") or item:IsA("Constraint")
		or item:IsA("WeldConstraint") or item:IsA("NoCollisionConstraint") then
		-- Les jointures et soudures d'origine sont retirées : tout est re-soudé
		-- au châssis plus bas.
		item:Destroy()
		removedOther += 1
	end
end

local removedDisplay: { string } = {}
for _, item in ipairs(model:GetDescendants()) do
	if item.Parent ~= nil
		and (item:IsA("BasePart") or item:IsA("Model") or item:IsA("Folder"))
		and matchesAny(item.Name, DISPLAY_PATTERNS) then
		table.insert(removedDisplay, item.Name)
		item:Destroy()
	end
end

-- Roues du modèle : mises de côté (mesurées après mise en place, puis supprimées).
local wheelItems: { Instance } = {}
local wheelNames: { string } = {}
local function isInsideWheel(item: Instance): boolean
	for _, wheelItem in ipairs(wheelItems) do
		if item == wheelItem or item:IsDescendantOf(wheelItem) then
			return true
		end
	end
	return false
end
for _, item in ipairs(model:GetDescendants()) do
	if (item:IsA("BasePart") or item:IsA("Model") or item:IsA("Folder"))
		and not isInsideWheel(item)
		and matchesWord(item.Name, WHEEL_PATTERNS)
		and not matchesAny(item.Name, WHEEL_EXCLUDE) then
		table.insert(wheelItems, item)
		table.insert(wheelNames, item.Name)
	end
end

local bodyParts: { BasePart } = {}
local wheelParts: { BasePart } = {}
for _, item in ipairs(model:GetDescendants()) do
	if item:IsA("BasePart") then
		table.insert(if isInsideWheel(item) then wheelParts else bodyParts, item)
	end
end
assert(#bodyParts > 0, "[attach-body] Le modèle ne contient aucune pièce de carrosserie")

-- Ancrées pendant la mise en place : rien ne doit tomber avant d'être soudé.
for _, part in ipairs(bodyParts) do
	part.Anchored = true
end
for _, part in ipairs(wheelParts) do
	part.Anchored = true
end

--------------------------------------------------------------------------------
-- 2. Orientation, échelle, centrage (dans le repère du châssis)
--------------------------------------------------------------------------------

-- Boîte englobante de pièces, exprimée dans le repère du châssis.
local function boundsInChassisSpace(parts: { BasePart }): (Vector3, Vector3)
	local minCorner = Vector3.new(math.huge, math.huge, math.huge)
	local maxCorner = -minCorner
	for _, part in ipairs(parts) do
		local half = part.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local world = part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					local localPoint = chassis.CFrame:PointToObjectSpace(world)
					minCorner = minCorner:Min(localPoint)
					maxCorner = maxCorner:Max(localPoint)
				end
			end
		end
	end
	return minCorner, maxCorner
end

local function shiftModel(localShift: Vector3)
	model:PivotTo(model:GetPivot() + chassis.CFrame:VectorToWorldSpace(localShift))
end

-- Tourne le modèle autour de son pivot, avec une rotation exprimée dans le
-- repère du châssis (le pivot reste au centre du châssis).
local function rotateInChassisFrame(rotation: CFrame)
	model:PivotTo(chassis.CFrame * rotation * chassis.CFrame:ToObjectSpace(model:GetPivot()))
end

local function extents(): Vector3
	local low, high = boundsInChassisSpace(bodyParts)
	return high - low
end

-- Point de départ : axes du modèle alignés sur ceux du châssis.
model:PivotTo(chassis.CFrame)

local orientationNotes: { string } = {}
if AUTO_ORIENT then
	-- 1. La plus petite dimension doit être la hauteur (Y).
	local size = extents()
	if size.X < size.Y and size.X <= size.Z then
		rotateInChassisFrame(CFrame.Angles(0, 0, math.pi / 2))
		table.insert(orientationNotes, "redressé (couché sur le côté)")
	elseif size.Z < size.Y and size.Z < size.X then
		rotateInChassisFrame(CFrame.Angles(math.pi / 2, 0, 0))
		table.insert(orientationNotes, "redressé (couché sur l'avant ou l'arrière)")
	end
	-- 2. La plus grande dimension horizontale doit être la longueur (Z).
	size = extents()
	if size.X > size.Z then
		rotateInChassisFrame(CFrame.Angles(0, math.pi / 2, 0))
		table.insert(orientationNotes, "tourné de 90°")
	end

	-- 3. Sur le toit ? Les roues d'une voiture sont en bas de sa carrosserie.
	if #wheelParts > 0 then
		local wheelLow, wheelHigh = boundsInChassisSpace(wheelParts)
		local bodyLow, bodyHigh = boundsInChassisSpace(bodyParts)
		if (wheelLow.Y + wheelHigh.Y) / 2 > (bodyLow.Y + bodyHigh.Y) / 2 then
			rotateInChassisFrame(CFrame.Angles(0, 0, math.pi))
			table.insert(orientationNotes, "retourné (il était sur le toit)")
		end
	end

	--[[
		4. Capot vers l'arrière ? Indices tirés des noms : les pièces "avant"
		(phares, capot, calandre...) doivent être côté -Z, les pièces "arrière"
		(feux, coffre, aileron, échappement...) côté +Z. Le nom d'une pièce ET
		ceux de ses groupes comptent ("Headlights" > "Part").
	]]
	local function nameChain(part: BasePart): { string }
		local names = {}
		local item: Instance? = part
		while item and item ~= model do
			table.insert(names, item.Name)
			item = item.Parent
		end
		return names
	end
	local function hasWord(names: { string }, words: { string }): boolean
		for _, name in ipairs(names) do
			if matchesWord(name, words) then
				return true
			end
		end
		return false
	end
	-- Mesuré depuis le centre de la carrosserie : elle n'est pas encore centrée
	-- sur le châssis à ce stade.
	local bodyLow, bodyHigh = boundsInChassisSpace(bodyParts)
	local bodyCenterZ = (bodyLow.Z + bodyHigh.Z) / 2
	local evidence, clues = 0, 0
	for _, part in ipairs(bodyParts) do
		local names = nameChain(part)
		local z = chassis.CFrame:PointToObjectSpace(part.Position).Z - bodyCenterZ
		local isFront = hasWord(names, FRONT_WORDS)
		local isRear = hasWord(names, REAR_WORDS)
		if isFront and not isRear then
			evidence -= z -- un avant bien placé a z < 0 : preuve positive
			clues += 1
		elseif isRear and not isFront then
			evidence += z
			clues += 1
		end
	end
	if clues > 0 and evidence < 0 then
		rotateInChassisFrame(CFrame.Angles(0, math.pi, 0))
		table.insert(orientationNotes, string.format("demi-tour (avant/arrière d'après %d pièce(s) nommée(s))", clues))
	elseif clues == 0 then
		table.insert(orientationNotes, "sens avant/arrière non vérifiable (aucune pièce nommée avant/arrière)")
	end
end
if ROTATION_DEGREES.Magnitude > 0 then
	rotateInChassisFrame(CFrame.Angles(math.rad(ROTATION_DEGREES.X), math.rad(ROTATION_DEGREES.Y), math.rad(ROTATION_DEGREES.Z)))
	table.insert(orientationNotes, string.format("rotation manuelle (%g, %g, %g)", ROTATION_DEGREES.X, ROTATION_DEGREES.Y, ROTATION_DEGREES.Z))
end

local minCorner, maxCorner = boundsInChassisSpace(bodyParts)
local scaleFactor = 1
if TARGET_LENGTH then
	local length = maxCorner.Z - minCorner.Z
	if length > 1e-3 then
		scaleFactor = TARGET_LENGTH / length
		model:ScaleTo(model:GetScale() * scaleFactor)
	end
	minCorner, maxCorner = boundsInChassisSpace(bodyParts)
end

-- Centrée en X et Z sur le châssis, posée à la garde au sol par défaut.
local center = (minCorner + maxCorner) / 2
shiftModel(Vector3.new(-center.X, (groundY + GROUND_CLEARANCE) - minCorner.Y, -center.Z))

--------------------------------------------------------------------------------
-- 3. Mesure des roues du modèle, ajustement de celles du gabarit
--------------------------------------------------------------------------------

type Quadrant = { Min: Vector3, Max: Vector3, Count: number }

-- Une roue tient dans environ un quart de la longueur : au-delà, la pièce n'en
-- est pas une (socle, garde-boue complet...) et fausserait la mesure.
local MAX_WHEEL_PART_SIZE = (TARGET_LENGTH or 14) * 0.3

local function measureWheels(): { [string]: Quadrant }
	local quadrants: { [string]: Quadrant } = {}
	for _, part in ipairs(wheelParts) do
		local horizontal = math.max(part.Size.X, part.Size.Z, part.Size.Y)
		if horizontal <= MAX_WHEEL_PART_SIZE then
			local partMin, partMax = boundsInChassisSpace({ part })
			local partCenter = (partMin + partMax) / 2
			-- Gauche = -X ; avant = -Z (repère du châssis).
			local key = (if partCenter.Z < 0 then "F" else "R") .. (if partCenter.X < 0 then "L" else "R")
			local quadrant = quadrants[key]
			if quadrant then
				quadrant.Min = quadrant.Min:Min(partMin)
				quadrant.Max = quadrant.Max:Max(partMax)
				quadrant.Count += 1
			else
				quadrants[key] = { Min = partMin, Max = partMax, Count = 1 }
			end
		end
	end
	return quadrants
end

local fitReport: string? = nil
local fitWarning: string? = nil

if FIT_WHEELS and #wheelParts > 0 then
	local quadrants = measureWheels()
	local complete = quadrants.FL and quadrants.FR and quadrants.RL and quadrants.RR
	if not complete then
		local found = {}
		for key, quadrant in pairs(quadrants) do
			table.insert(found, string.format("%s (%d pièces)", key, quadrant.Count))
		end
		fitWarning = string.format(
			"roues du modèle incomplètes, il faut les quatre coins (FL, FR, RL, RR) ; trouvées : %s. Roues du gabarit laissées en place",
			if #found > 0 then table.concat(found, ", ") else "aucune de taille plausible"
		)
	else
		-- Moyennes symétriques : un essieu reste perpendiculaire et centré.
		local radiusSum, widthSum, halfTrackSum = 0, 0, 0
		local frontZ, rearZ, centerYSum = 0, 0, 0
		for key, quadrant in pairs(quadrants) do
			local size = quadrant.Max - quadrant.Min
			local mid = (quadrant.Min + quadrant.Max) / 2
			radiusSum += math.max(size.Y, size.Z) / 2
			widthSum += size.X
			halfTrackSum += math.abs(mid.X)
			centerYSum += mid.Y
			if string.sub(key, 1, 1) == "F" then
				frontZ += mid.Z / 2
			else
				rearZ += mid.Z / 2
			end
		end
		local radius = radiusSum / 4
		local width = math.clamp(widthSum / 4, WHEEL_WIDTH_RANGE[1], WHEEL_WIDTH_RANGE[2])
		local halfTrack = halfTrackSum / 4
		local wheelCenterY = centerYSum / 4

		if radius < WHEEL_RADIUS_RANGE[1] or radius > WHEEL_RADIUS_RANGE[2] then
			fitWarning = string.format(
				"rayon de roue mesuré improbable (%.2f stud) : roues du gabarit laissées en place",
				radius
			)
		else
			--[[
				Essieux recentrés sur le châssis (la carrosserie se décale d'autant
				en Z) : le centre de masse reste à mi-empattement, comme le suppose
				la suspension (même raideur aux quatre coins). Hauteur : les roues
				du modèle doivent toucher le sol au repos.
			]]
			local axleMid = (frontZ + rearZ) / 2
			local halfBase = (rearZ - frontZ) / 2
			local verticalShift = (groundY + radius) - wheelCenterY
			shiftModel(Vector3.new(0, verticalShift, -axleMid))

			local layout = {
				FL = Vector3.new(-halfTrack, attachmentY, -halfBase),
				FR = Vector3.new(halfTrack, attachmentY, -halfBase),
				RL = Vector3.new(-halfTrack, attachmentY, halfBase),
				RR = Vector3.new(halfTrack, attachmentY, halfBase),
			}
			for suffix, position in pairs(layout) do
				local attachment = chassis:FindFirstChild("Wheel" .. suffix)
				local motor = chassis:FindFirstChild("Motor" .. suffix)
				local tire = car:FindFirstChild("Tire" .. suffix)
				if attachment and attachment:IsA("Attachment") then
					attachment.Position = position
				end
				local restOffset = CFrame.new(position + Vector3.new(0, radius - REST_DROP, 0))
				if motor and motor:IsA("Motor6D") then
					motor.C0 = restOffset
				end
				if tire and tire:IsA("BasePart") then
					-- Jante et branches soudées au pneu : dessoudées, mises à
					-- l'échelle du nouveau rayon, replacées, ressoudées.
					local oldRadius = tire.Size.Y / 2
					local oldWidth = tire.Size.X
					local factor = radius / oldRadius
					local decor = {}
					for _, child in ipairs(tire:GetChildren()) do
						if child:IsA("WeldConstraint") then
							child:Destroy()
						elseif child:IsA("BasePart") then
							table.insert(decor, { Part = child, Rotation = tire.CFrame:ToObjectSpace(child.CFrame).Rotation })
						end
					end
					local tireCFrame = chassis.CFrame * restOffset
					tire.Size = Vector3.new(width, radius * 2, radius * 2)
					tire.CFrame = tireCFrame
					for _, entry in ipairs(decor) do
						local part = entry.Part :: BasePart
						local size = part.Size
						part.Size = Vector3.new(size.X - oldWidth + width, size.Y * factor, size.Z * factor)
						part.CFrame = tireCFrame * entry.Rotation
						weld(tire, part, tire)
					end
				end
			end

			fitReport = string.format(
				"roues ajustées : empattement %.2f, voie %.2f, rayon %.2f, largeur %.2f studs. "
					.. "Pour les garder après un build-rig : HALF_BASE = %.2f, HALF_TRACK = %.2f, "
					.. "WHEEL_RADIUS = %.2f, WHEEL_WIDTH = %.2f",
				halfBase * 2,
				halfTrack * 2,
				radius,
				width,
				halfBase,
				halfTrack,
				radius,
				width
			)
		end
	end
elseif FIT_WHEELS then
	fitWarning = "aucune roue repérée par son nom dans le modèle : roues du gabarit laissées en place"
end

if NUDGE.Magnitude > 0 then
	shiftModel(NUDGE)
end

for _, wheelItem in ipairs(wheelItems) do
	if wheelItem.Parent then
		wheelItem:Destroy()
	end
end

--------------------------------------------------------------------------------
-- 4. Pièces décoratives, soudées au châssis
--------------------------------------------------------------------------------

local previous = car:FindFirstChild("ImportedBody")
if previous and previous ~= model then
	previous:Destroy()
end

for _, part in ipairs(bodyParts) do
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false -- invisible pour les raycasts de suspension
	part.CanTouch = false
	part.Anchored = false
	-- Soudure rangée DANS la pièce : elle disparaît avec elle si on la remplace.
	weld(chassis, part, part)
end

model.Name = "ImportedBody"
model.Parent = car

local procedural = car:FindFirstChild("Body")
if REMOVE_PROCEDURAL_BODY and procedural then
	procedural:Destroy()
end

if HIDE_CHASSIS then
	chassis.Transparency = 1
	for _, item in ipairs(chassis:GetChildren()) do
		if item:IsA("Decal") or item:IsA("Texture") or item:IsA("SurfaceGui") then
			item:Destroy()
		end
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
else
	ChangeHistoryService:SetWaypoint("Après attach-body")
end

--------------------------------------------------------------------------------
-- Bilan
--------------------------------------------------------------------------------

minCorner, maxCorner = boundsInChassisSpace(bodyParts)
local size = maxCorner - minCorner
print(string.format(
	"[attach-body] %d pièces attachées | échelle x%.3f | longueur %.1f, largeur %.1f, hauteur %.1f studs (%.2f x %.2f x %.2f m)",
	#bodyParts,
	scaleFactor,
	size.Z,
	size.X,
	size.Y,
	size.Z * 0.28,
	size.X * 0.28,
	size.Y * 0.28
))
print(string.format("[attach-body] supprimés : %d script(s), %d objet(s) interactif(s)/jointure(s)", removedScripts, removedOther))
print("[attach-body] orientation : " .. (if #orientationNotes > 0 then table.concat(orientationNotes, ", ") else "inchangée"))
if #removedDisplay > 0 then
	print("[attach-body] socle / présentoir supprimé : " .. table.concat(removedDisplay, ", "))
end
if #wheelNames > 0 then
	print("[attach-body] roues du modèle (mesurées puis retirées) : " .. table.concat(wheelNames, ", "))
end
if fitReport then
	print("[attach-body] " .. fitReport)
end
if fitWarning then
	warn("[attach-body] " .. fitWarning)
end
if size.X > size.Z then
	warn("[attach-body] Plus large que long après orientation : vérifie ROTATION_DEGREES (ou passe AUTO_ORIENT à false).")
end
if size.Y > size.Z * 0.6 then
	warn("[attach-body] Très haut pour une voiture après orientation : vérifie ROTATION_DEGREES (ou passe AUTO_ORIENT à false).")
end
print("[attach-body] Encore à l'envers ? Recommence avec ROTATION_DEGREES = Vector3.new(0, 180, 0) si le capot est vers l'arrière, Vector3.new(0, 0, 180) si elle est sur le toit.")
