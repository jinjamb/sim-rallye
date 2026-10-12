--!strict
--[[
	CopilotVoice.luau
	La voix du copilote : elle dit les notes (Pacenotes.luau) que Copilot.luau
	affiche, au moment où il les affiche.

	DEUX SOURCES, la meilleure disponible pour chaque note :
		1. ENREGISTREMENTS (CLIPS) : un son par mot ("gauche", "3", "longue",
		   "150"...), enchaînés. Les enregistrer, les importer (Creator Hub >
		   Audio), puis mettre leurs identifiants dans CLIPS. Une note n'est
		   dite ainsi que si tous ses mots ont un son.
		2. SYNTHÈSE VOCALE de Roblox (AudioTextToSpeech, voix française) :
		   une phrase par note, générée une fois puis gardée pour la partie.
		   Roblox limite les générations (1 + 6 x joueurs par minute, pour toute
		   l'expérience) : chaque joueur en demande au plus
		   GENERATIONS_PER_MINUTE, les notes devant lui d'abord, dès son
		   arrivée dans le jeu. Une note pas encore générée est seulement
		   affichée.
	Sans enregistrement ni synthèse (indisponible, refusée), le copilote
	reste muet : le texte suffit.

	ACTUALITÉ : une note atteinte avant d'avoir été dite est sautée (le
	copilote ne parle jamais d'un virage déjà passé), et au plus MAX_QUEUE
	notes attendent leur tour.

	RÉGLAGE : voix d'homme, de femme, ou coupée (menu JOUER, touche N).
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Pacenotes = require(ReplicatedStorage.Shared.Stage.Pacenotes)

local CopilotVoice = {}

export type Mode = "Male" | "Female" | "Off"

CopilotVoice.MODES = { "Male", "Female", "Off" } :: { Mode }
CopilotVoice.MODE_NAMES = { Male = "HOMME", Female = "FEMME", Off = "COUPÉE" } :: { [string]: string }

-- Voix françaises de la synthèse vocale de Roblox.
local VOICE_IDS: { [Mode]: string } = { Male = "401", Female = "402" }

local GENERATIONS_PER_MINUTE = 5 -- la part d'un joueur (Roblox : 6 par joueur et par minute)
local MAX_FAILURES = 3 -- échecs d'affilée : la synthèse est indisponible, on arrête
local SPEECH_SPEED = 1.2 -- un copilote parle vite
local SPEECH_VOLUME = 1.6
local CLIP_SPEED = 1.1
local CLIP_OVERLAP = 0.06 -- secondes : le mot suivant démarre juste avant la fin
local MAX_QUEUE = 2

--[[
	Enregistrements, un par mot (identifiant de l'asset audio ; 0 : pas
	encore enregistré). Tout le vocabulaire des notes est listé.
]]
CopilotVoice.CLIPS = {
	-- Directions et sévérité
	["gauche"] = 0, ["droite"] = 0, ["épingle"] = 0, ["légère"] = 0,
	["1"] = 0, ["2"] = 0, ["3"] = 0, ["4"] = 0, ["5"] = 0, ["6"] = 0,
	["longue"] = 0, ["courte"] = 0,
	-- Liens
	["dans"] = 0, ["et"] = 0,
	-- Dangers et infos
	["saut"] = 0, ["bosse"] = 0, ["montée"] = 0, ["descente"] = 0, ["arrivée"] = 0,
	["asphalte"] = 0, ["terre"] = 0, ["boue"] = 0, ["sable"] = 0, ["neige"] = 0,
	["herbe"] = 0, ["verglas"] = 0, ["glace"] = 0,
	-- Distances (mètres)
	["30"] = 0, ["40"] = 0, ["50"] = 0, ["60"] = 0, ["70"] = 0, ["80"] = 0, ["90"] = 0,
	["100"] = 0, ["150"] = 0, ["200"] = 0, ["250"] = 0, ["300"] = 0, ["350"] = 0,
	["400"] = 0, ["450"] = 0, ["500"] = 0, ["600"] = 0, ["700"] = 0, ["800"] = 0,
} :: { [string]: number }

type Speech = { Generator: any, Ready: boolean, Failed: boolean }
type Queued = { Note: Pacenotes.Note, Relevant: () -> boolean }

local mode: Mode = "Male"
local output: any = nil -- AudioDeviceOutput
local speeches: { [string]: Speech } = {} -- par voix et phrase
local pending: { string } = {} -- phrases à générer, la plus urgente d'abord
local generating = false
local failures = 0
local synthesisDown = false
local prepared: { notes: { Pacenotes.Note }, from: number }? = nil

local clipSounds: { [string]: Sound } = {}
local clipsPreloaded = false

local queue: { Queued } = {}
local speaking = false
local current: any = nil -- ce qui se joue (Sound ou AudioTextToSpeech)
local epoch = 0 -- change à chaque Stop : ce qui était en cours n'est plus dit

-- La phrase d'une note : ses mots, la distance détachée par une virgule.
local function phraseOf(note: Pacenotes.Note): string
	local words = note.Words
	local last = words[#words]
	if #words > 1 and last and string.match(last, "^%d+$") and tonumber(last) and (tonumber(last) :: number) >= 30 then
		return table.concat(words, " ", 1, #words - 1) .. ", " .. last
	end
	return table.concat(words, " ")
end

local function speechKey(text: string): string
	return VOICE_IDS[mode] .. "|" .. text
end

local function audioOutput(): any
	if not output then
		local device = Instance.new("AudioDeviceOutput" :: any) :: any
		device.Name = "CopilotVoice"
		device.Parent = SoundService
		output = device
	end
	return output
end

-- Génère les phrases en attente, au rythme permis.
local function generate()
	if generating then
		return
	end
	generating = true
	task.spawn(function()
		while #pending > 0 and not synthesisDown and mode ~= "Off" do
			local text = table.remove(pending, 1) :: string
			local key = speechKey(text)
			if not speeches[key] then
				local ok, generator = pcall(function()
					local tts = Instance.new("AudioTextToSpeech" :: any) :: any
					tts.Text = text
					tts.VoiceId = VOICE_IDS[mode]
					tts.AutoLocalize = false -- le jeu est en français : la voix aussi
					tts.Speed = SPEECH_SPEED
					tts.Volume = SPEECH_VOLUME
					local wire = Instance.new("Wire" :: any) :: any
					wire.SourceInstance = tts
					wire.TargetInstance = audioOutput()
					wire.Parent = tts
					tts.Parent = SoundService
					return tts
				end)
				local speech: Speech = { Generator = if ok then generator else nil, Ready = false, Failed = not ok }
				speeches[key] = speech
				if ok then
					local loaded, status = pcall(function()
						return generator:LoadAsync()
					end)
					speech.Ready = loaded and status == Enum.AssetFetchStatus.Success
					speech.Failed = not speech.Ready
				end
				failures = if speech.Failed then failures + 1 else 0
				if failures >= MAX_FAILURES then
					synthesisDown = true
					warn("[Copilote] Synthèse vocale indisponible : notes affichées seulement.")
				end
				task.wait(60 / GENERATIONS_PER_MINUTE)
			end
		end
		generating = false
	end)
end

-- Les sons de mots renseignés dans CLIPS, créés et préchargés une fois.
local function clipFor(word: string): Sound?
	local id = CopilotVoice.CLIPS[word]
	if not id or id == 0 then
		return nil
	end
	local sound = clipSounds[word]
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "Copilot_" .. word
		created.SoundId = "rbxassetid://" .. tostring(id)
		created.PlaybackSpeed = CLIP_SPEED
		created.Volume = 1
		created.Parent = SoundService
		clipSounds[word] = created
		sound = created
	end
	return sound
end

local function preloadClips()
	if clipsPreloaded then
		return
	end
	clipsPreloaded = true
	local sounds = {}
	for word in pairs(CopilotVoice.CLIPS) do
		local sound = clipFor(word)
		if sound then
			table.insert(sounds, sound)
		end
	end
	if #sounds > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(sounds)
			end)
		end)
	end
end

-- Tous les mots de la note enregistrés ? Leurs sons, dans l'ordre.
local function clipsOf(note: Pacenotes.Note): { Sound }?
	local sounds = {}
	for _, word in ipairs(note.Words) do
		local sound = clipFor(word)
		if not sound then
			return nil
		end
		table.insert(sounds, sound)
	end
	return sounds
end

-- Arrête `instance` : un Sound s'arrête, un AudioTextToSpeech se met en pause.
local function halt(instance: any)
	pcall(function()
		if instance:IsA("Sound") then
			instance:Stop()
		else
			instance:Pause()
		end
	end)
end

-- Joue `instance` (Sound ou AudioTextToSpeech) jusqu'à sa fin, ou presque.
local function playToEnd(instance: any, length: number, overlap: number, relevant: () -> boolean)
	current = instance
	instance.TimePosition = 0
	instance:Play()
	local deadline = os.clock() + math.max(0.2, length - overlap)
	while os.clock() < deadline and current == instance do
		if not relevant() then
			halt(instance)
			break
		end
		task.wait()
	end
	if current == instance then
		current = nil
	end
end

local function sayNow(item: Queued)
	local sounds = clipsOf(item.Note)
	if sounds then
		for _, sound in ipairs(sounds) do
			if not item.Relevant() or mode == "Off" then
				return
			end
			playToEnd(sound, if sound.TimeLength > 0 then sound.TimeLength / CLIP_SPEED else 0.4, CLIP_OVERLAP, item.Relevant)
		end
		return
	end
	local speech = speeches[speechKey(phraseOf(item.Note))]
	if speech and speech.Ready then
		local generator = speech.Generator
		local length = tonumber(generator.TimeLength) or 1
		playToEnd(generator, length, 0, item.Relevant)
	end
end

local function speak()
	if speaking then
		return
	end
	speaking = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1) :: Queued
			if mode ~= "Off" and item.Relevant() then
				sayNow(item)
			end
		end
		speaking = false
	end)
end

-- Fait générer les phrases des notes, à partir de la note `from` (celles
-- devant la voiture d'abord, puis le reste du parcours).
function CopilotVoice.Prepare(notes: { Pacenotes.Note }, from: number)
	prepared = { notes = notes, from = from }
	preloadClips()
	if mode == "Off" or synthesisDown then
		return
	end
	local order = {}
	local seen: { [string]: boolean } = {}
	local function add(note: Pacenotes.Note)
		if clipsOf(note) then
			return -- dite avec les enregistrements
		end
		local text = phraseOf(note)
		if not seen[text] and not speeches[speechKey(text)] then
			seen[text] = true
			table.insert(order, text)
		end
	end
	for index = math.max(1, from), #notes do
		add(notes[index])
	end
	for index = 1, math.min(from - 1, #notes) do
		add(notes[index])
	end
	pending = order
	generate()
end

-- Annonce une note. `relevant` : encore utile de la dire (pas encore atteinte) ?
function CopilotVoice.Say(note: Pacenotes.Note, relevant: () -> boolean)
	if mode == "Off" then
		return
	end
	while #queue >= MAX_QUEUE do
		table.remove(queue, 1)
	end
	local saidAt = epoch
	table.insert(queue, {
		Note = note,
		Relevant = function()
			return saidAt == epoch and relevant()
		end,
	})
	speak()
end

-- Se tait tout de suite (remise en piste, fin de la session).
function CopilotVoice.Stop()
	epoch += 1
	table.clear(queue)
	local playing = current
	current = nil
	if playing then
		halt(playing)
	end
end

function CopilotVoice.GetMode(): Mode
	return mode
end

-- Change de voix (`direction` : +1 ou -1 dans MODES) ; renvoie la nouvelle.
function CopilotVoice.Cycle(direction: number): Mode
	local index = table.find(CopilotVoice.MODES, mode) or 1
	mode = CopilotVoice.MODES[(index - 1 + direction) % #CopilotVoice.MODES + 1]
	CopilotVoice.Stop()
	local last = prepared
	if last then
		CopilotVoice.Prepare(last.notes, last.from)
	end
	return mode
end

return CopilotVoice
