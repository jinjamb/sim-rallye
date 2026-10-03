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

	Le fantôme est une copie du gabarit de la voiture (ReplicatedStorage.
	CarTemplate), ancrée, transparente, sans collision ni effet sur les rayons de
	suspension. Il n'existe que chez ce joueur.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ghost = {}
Ghost.__index = Ghost

export type GhostData = { Rate: number, Frames: { number } }

export type Ghost = typeof(setmetatable({}, Ghost)) & {
	Chassis: BasePart,
	Best: GhostData?,
	Model: Model?,

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

function Ghost.new(chassis: BasePart): Ghost
	local self = (setmetatable({}, Ghost) :: any) :: Ghost
	self.Chassis = chassis
	self.Best = nil
	self.Model = nil
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

-- Fantôme à rejouer (meilleur temps). nil = aucun.
function Ghost:SetBest(data: GhostData?)
	self.Best = data
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

	-- Lecture du meilleur passage.
	local best = self.Best
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
