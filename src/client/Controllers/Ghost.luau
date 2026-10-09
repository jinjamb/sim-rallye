--!strict
--[[
	Ghost.luau
	Le fantôme : la trajectoire de son meilleur passage, rejouée en voiture
	transparente pendant qu'on roule, partie au même instant que soi.

	Il montre exactement OÙ on perd du temps -- point de freinage, trajectoire,
	sortie de virage -- là où les inters ne disent que COMBIEN.

	ENREGISTREMENT : la position et l'orientation du châssis, 10 fois par
	seconde, du départ à l'arrivée (6 nombres par image : x, y, z et les trois
	angles). Une spéciale de 2 min tient en ~7000 nombres.
	LECTURE : interpolation entre deux images, à chaque frame : le fantôme est
	fluide malgré la faible cadence d'enregistrement.
	SAUVEGARDE : quand le serveur valide un nouveau record perso (RunValidated),
	l'enregistrement lui est envoyé et rangé avec le temps (RecordService).

	ADVERSAIRE : au lieu de son propre meilleur passage, on peut affronter celui
	d'un autre pilote (GhostChallenge.luau) ; une étiquette au-dessus du
	fantôme dit qui c'est. Le fantôme peut aussi être masqué.
	RÉFÉRENCE DU CHRONO : chaque image du fantôme joué est située sur le tracé
	(son avancement). On sait donc À QUEL INSTANT il est passé en tout point :
	écart en direct et temps intermédiaires de référence (StageTimer.luau)
	s'en déduisent, sans rien sauvegarder de plus.

	Le fantôme est une copie du gabarit de la voiture (ReplicatedStorage.
	CarTemplate), ancrée, transparente, sans collision ni effet sur les rayons de
	suspension. Il n'existe que chez ce joueur.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageTrack = require(ReplicatedStorage.Shared.Stage.StageTrack)

local Ghost = {}
Ghost.__index = Ghost

export type GhostData = { Rate: number, Frames: { number } }
-- Le passage d'un autre pilote, envoyé par le serveur (RecordService).
export type Opponent = { UserId: number, Name: string, Ms: number, Data: GhostData }

export type Ghost = typeof(setmetatable({}, Ghost)) & {
	Chassis: BasePart,
	Best: GhostData?,
	Opponent: Opponent?,
	Hidden: boolean,
	Model: Model?,
	Tag: TextLabel?,
	-- Avancement le long du tracé à chaque image du fantôme joué (croissant).
	TraceData: GhostData?,
	Trace: { number },

	Recording: { number }?,
	LastRecording: GhostData?,
	NextSample: number,
	RunClock: number?,
	Visible: boolean,
}

local RATE = 10 -- images par seconde
local VALUES_PER_FRAME = 6
local MAX_FRAMES = 3000 -- 5 minutes : au-delà, on arrête d'enregistrer
local GHOST_TRANSPARENCY = 0.65
local TRACE_WINDOW = 25 -- échantillons du tracé (4 studs) examinés autour du précédent
local TAG_OWN = Color3.fromRGB(235, 236, 240)
local TAG_OPPONENT = Color3.fromRGB(255, 140, 40)

function Ghost.new(chassis: BasePart): Ghost
	local self = (setmetatable({}, Ghost) :: any) :: Ghost
	self.Chassis = chassis
	self.Best = nil
	self.Opponent = nil
	self.Hidden = false
	self.Model = nil
	self.Tag = nil
	self.TraceData = nil
	self.Trace = {}
	self.Recording = nil
	self.LastRecording = nil
	self.NextSample = 0
	self.RunClock = nil
	self.Visible = true
	return self
end

-- Copie inerte du gabarit : rien qui tombe, collisionne, émet ou joue un son.
local function buildModel(): Model?
	local template = ReplicatedStorage:FindFirstChild("CarTemplate")
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.Name = "Ghost"
	for _, item in ipairs(model:GetDescendants()) do
		for _, tag in ipairs(CollectionService:GetTags(item)) do
			CollectionService:RemoveTag(item, tag)
		end
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
			item.Transparency = math.max(item.Transparency, GHOST_TRANSPARENCY)
		elseif item:IsA("ParticleEmitter") or item:IsA("Sound") or item:IsA("LuaSourceContainer")
			or item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			item:Destroy()
		end
	end
	return model
end

-- Son propre meilleur passage. nil = aucun.
function Ghost:SetBest(data: GhostData?)
	self.Best = data
	self:_refreshTag()
end

-- Passage d'un autre pilote à affronter à la place du sien. nil = le sien.
function Ghost:SetOpponent(opponent: Opponent?)
	self.Opponent = opponent
	self:_refreshTag()
end

-- Fantôme masqué : plus de voiture transparente, plus de référence au chrono.
function Ghost:SetHidden(hidden: boolean)
	self.Hidden = hidden
	if hidden then
		self:_hide()
	end
end

-- Le passage rejoué : celui de l'adversaire s'il y en a un, sinon le sien.
function Ghost:Played(): GhostData?
	if self.Hidden then
		return nil
	end
	local opponent = self.Opponent
	return if opponent then opponent.Data else self.Best
end

-- Qui est le fantôme, pour l'affichage : "TON RECORD" ou le nom de l'adversaire.
function Ghost:Describe(): string
	local opponent = self.Opponent
	return if opponent then string.upper(opponent.Name) else "TON RECORD"
end

function Ghost:_refreshTag()
	local tag = self.Tag
	if tag then
		tag.Text = self:Describe()
		tag.TextColor3 = if self.Opponent then TAG_OPPONENT else TAG_OWN
	end
end

--[[
	Avancement de chaque image du passage rejoué, calculé à la première
	demande. Chaque image est cherchée près de la précédente (StageTrack.
	LocateNear) ; recherche complète pour la première, et après un bond
	(remise en piste). L'avancement est rendu croissant : un passage validé ne
	recule pas, et la recherche par dichotomie (TimeAt) en a besoin.
]]
function Ghost:_trace(): ({ number }, GhostData?)
	local played = self:Played()
	if played == nil then
		return {}, nil
	end
	local data: GhostData = played
	if self.TraceData == data then
		return self.Trace, data
	end
	local frames = data.Frames
	local count = #frames // VALUES_PER_FRAME
	local sampleCount = #StageTrack.GetSamples()
	local trace = table.create(count)
	local hint: number? = nil
	local highest = -math.huge
	for i = 1, count do
		local base = (i - 1) * VALUES_PER_FRAME
		local position = Vector3.new(frames[base + 1], frames[base + 2], frames[base + 3])
		local sample, progress
		if hint then
			sample, progress = StageTrack.LocateNear(position, hint, TRACE_WINDOW)
			local first = math.max(1, hint - TRACE_WINDOW)
			local last = math.min(sampleCount, hint + TRACE_WINDOW)
			if (sample.Index == first and first > 1) or (sample.Index == last and last < sampleCount) then
				sample, progress = StageTrack.Locate(position) -- bond : hors de la fenêtre
			end
		else
			sample, progress = StageTrack.Locate(position)
		end
		hint = sample.Index
		highest = math.max(highest, progress)
		trace[i] = highest
	end
	self.TraceData = data
	self.Trace = trace
	return trace, data
end

--[[
	Instant (secondes depuis le départ) où le fantôme rejoué est passé à
	l'abscisse `progress`, interpolé entre deux images. nil sans fantôme, ou
	au-delà de son arrivée.
]]
function Ghost:TimeAt(progress: number): number?
	local trace, data = self:_trace()
	local count = #trace
	if data == nil or count < 2 or progress > trace[count] then
		return nil
	end
	if progress <= trace[1] then
		return 0
	end
	-- Première image dont l'avancement atteint `progress`.
	local low, high = 2, count
	while low < high do
		local middle = (low + high) // 2
		if trace[middle] >= progress then
			high = middle
		else
			low = middle + 1
		end
	end
	local before, after = trace[low - 1], trace[low]
	local alpha = if after > before then (progress - before) / (after - before) else 1
	return (low - 2 + alpha) / data.Rate
end

function Ghost:SetVisible(visible: boolean)
	self.Visible = visible
	local model = self.Model
	if model and not visible then
		model.Parent = nil
	end
end

local function frameCount(data: GhostData): number
	return #data.Frames // VALUES_PER_FRAME
end

local function frameAt(data: GhostData, index: number): CFrame
	local base = (index - 1) * VALUES_PER_FRAME
	local f = data.Frames
	return CFrame.new(f[base + 1], f[base + 2], f[base + 3]) * CFrame.fromOrientation(f[base + 4], f[base + 5], f[base + 6])
end

-- Départ : on enregistre, et le fantôme part au même instant.
function Ghost:StartRun()
	self.RunClock = os.clock()
	self.Recording = {}
	self.NextSample = 0
	self.LastRecording = nil
	self:_sample(0)
end

function Ghost:_sample(elapsed: number)
	local recording = self.Recording
	if not recording or #recording >= MAX_FRAMES * VALUES_PER_FRAME then
		return
	end
	local frame = self.Chassis.CFrame
	local rx, ry, rz = frame:ToOrientation()
	local p = frame.Position
	table.insert(recording, p.X)
	table.insert(recording, p.Y)
	table.insert(recording, p.Z)
	table.insert(recording, rx)
	table.insert(recording, ry)
	table.insert(recording, rz)
	self.NextSample = elapsed + 1 / RATE
end

-- Arrivée : l'enregistrement est gardé (LastRecording) en attendant le verdict du serveur.
function Ghost:FinishRun()
	if self.Recording and self.RunClock then
		self:_sample(os.clock() - self.RunClock) -- dernière image : pile sur la ligne
		self.LastRecording = { Rate = RATE, Frames = self.Recording :: { number } }
	end
	self.Recording = nil
	self.RunClock = nil
	self:_hide()
end

-- Retour au départ, temps annulé : on oublie ce passage.
function Ghost:CancelRun()
	self.Recording = nil
	self.RunClock = nil
	self:_hide()
end

function Ghost:Destroy()
	local model = self.Model
	if model then
		model:Destroy()
		self.Model = nil
		self.Tag = nil
	end
	self.Recording = nil
	self.RunClock = nil
end

-- Étiquette au-dessus du fantôme : qui c'est.
function Ghost:_attachTag()
	local model = self.Model
	if not model then
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChild("Chassis")
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GhostTag"
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(220, 26)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 400
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 16
	label.TextStrokeTransparency = 0.4
	label.TextTransparency = 0.15
	label.Parent = billboard
	billboard.Parent = anchor -- détruite avec le fantôme
	self.Tag = label
	self:_refreshTag()
end

function Ghost:_hide()
	local model = self.Model
	if model then
		model.Parent = nil
	end
end

function Ghost:Update(_dt: number)
	local start = self.RunClock
	if not start then
		return
	end
	local elapsed = os.clock() - start

	-- Enregistrement : une image tous les 1/RATE s (à la frame qui suit l'échéance).
	if self.Recording and elapsed >= self.NextSample then
		self:_sample(elapsed)
	end

	-- Lecture du passage choisi (le sien, ou celui de l'adversaire).
	local best = self:Played()
	if not best or not self.Visible then
		return
	end
	local count = frameCount(best)
	local position = elapsed * best.Rate + 1
	if count < 2 or position >= count then
		self:_hide() -- le fantôme a franchi la ligne
		return
	end
	if not self.Model then
		self.Model = buildModel()
		self:_attachTag()
	end
	local model = self.Model
	if not model then
		return
	end
	local index = math.floor(position)
	local alpha = position - index
	model:PivotTo(frameAt(best, index):Lerp(frameAt(best, index + 1), alpha))
	if model.Parent ~= workspace then
		model.Parent = workspace
	end
end

return Ghost
