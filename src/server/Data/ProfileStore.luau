--!strict
--[[
	ProfileStore.luau
	Le profil sauvegardé de chaque joueur (forme : ProfileSchema.luau) :
	chargement à l'arrivée, copie en mémoire pendant la partie, écritures.

	DEUX FAÇONS D'ÉCRIRE :
		- Update : tout de suite, de façon atomique (UpdateAsync) -- un autre
		  serveur a pu écrire entre-temps. Pour ce qui compte (un record, une
		  fin de course) : la fonction reçoit le profil SAUVEGARDÉ et le modifie.
		- AddCounter / Defer : regroupé, écrit toutes les FLUSH_INTERVAL s et au
		  départ du joueur, en UNE écriture. AddCounter ajoute à une somme
		  (spéciales terminées, points de style...) ; Defer remplace une valeur
		  (réglages, livrée) -- la dernière demande l'emporte.
	La copie en mémoire (Get) est tenue à jour par les services eux-mêmes :
	l'écriture ne fait que la reporter dans le DataStore.

	CHARGEMENT : les services s'inscrivent avec OnLoaded, et sont appelés dans
	l'ordre d'inscription (Main.server.luau fixe cet ordre) une fois le profil
	chargé. Sans DataStore (Studio sans accès aux API), un profil vierge.
]]

local Players = game:GetService("Players")

local ProfileSchema = require(script.Parent.ProfileSchema)
local Stores = require(script.Parent.Stores)

type Profile = ProfileSchema.Profile

local ProfileStore = {}

local PROFILE_STORE_NAME = "RallyProfiles_v1"
local FLUSH_INTERVAL = 30 -- secondes entre deux écritures regroupées
local FLUSH_ATTEMPTS = 3 -- essais d'une écriture regroupée (DataStore surchargé)

type Pending = {
	Counters: { [string]: number },
	Writes: { [string]: (Profile) -> () },
}

local profiles: { [Player]: Profile } = {}
local pending: { [Player]: Pending } = {}
local loadedListeners: { (Player, Profile) -> () } = {}

local function profileKey(userId: number): string
	return "u_" .. tostring(userId)
end

local function store(): DataStore?
	return Stores.Get(PROFILE_STORE_NAME)
end

-- Profil en mémoire d'un joueur connecté (nil tant qu'il n'est pas chargé).
function ProfileStore.Get(player: Player): Profile?
	return profiles[player]
end

-- `listener(player, profile)` à chaque profil chargé.
function ProfileStore.OnLoaded(listener: (Player, Profile) -> ())
	table.insert(loadedListeners, listener)
end

--[[
	Modifie le profil SAUVEGARDÉ de façon atomique, en tâche de fond.
	`change` renvoie false pour ne rien écrire. Elle peut être rappelée (un
	autre serveur a écrit entre-temps) : elle ne doit dépendre que de ce
	qu'elle reçoit.
]]
function ProfileStore.Update(userId: number, context: string, change: (Profile) -> boolean)
	local dataStore = store()
	if not dataStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			dataStore:UpdateAsync(profileKey(userId), function(old: any)
				local profile = ProfileSchema.Sanitize(old, userId)
				if not change(profile) then
					return nil -- rien à écrire
				end
				return profile
			end)
		end)
		if not ok then
			Stores.Failed(context, err)
		end
	end)
end

--[[
	Comme Update, mais attend la fin de l'écriture : true si elle a réussi
	(ou s'il n'y avait rien à écrire). Pour ce qui doit être sauvegardé
	avant de répondre (un achat Robux). false sans DataStore.
]]
function ProfileStore.UpdateNow(userId: number, context: string, change: (Profile) -> boolean): boolean
	local dataStore = store()
	if not dataStore then
		return false
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(profileKey(userId), function(old: any)
			local profile = ProfileSchema.Sanitize(old, userId)
			if not change(profile) then
				return nil
			end
			return profile
		end)
	end)
	if not ok then
		Stores.Failed(context, err)
	end
	return ok
end

-- Profil sauvegardé d'un joueur, connecté ou non (attend le DataStore).
-- nil si les DataStores manquent ou si la lecture échoue.
function ProfileStore.Read(userId: number, context: string): Profile?
	local dataStore = store()
	if not dataStore then
		return nil
	end
	local ok, result = pcall(function()
		return dataStore:GetAsync(profileKey(userId))
	end)
	if not ok then
		Stores.Failed(context, result)
		return nil
	end
	return ProfileSchema.Sanitize(result, userId)
end

local function pendingOf(player: Player): Pending
	local entry = pending[player]
	if not entry then
		entry = { Counters = {}, Writes = {} }
		pending[player] = entry
	end
	return entry
end

-- Ajoute `amount` à un compteur du profil (en mémoire tout de suite, dans le
-- DataStore à la prochaine écriture regroupée).
function ProfileStore.AddCounter(player: Player, counter: ProfileSchema.Counter, amount: number)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	local fields = profile :: any
	fields[counter] += amount
	local counters = pendingOf(player).Counters
	counters[counter] = (counters[counter] or 0) + amount
end

-- Écriture regroupée : `write(profilSauvegardé)` à la prochaine sauvegarde.
-- Une nouvelle demande sous la même clé remplace la précédente.
function ProfileStore.Defer(player: Player, key: string, write: (Profile) -> ())
	if profiles[player] then
		pendingOf(player).Writes[key] = write
	end
end

-- Écrit maintenant ce qui attendait (compteurs et écritures regroupées).
-- En cas d'échec passager du DataStore, on réessaie un peu plus tard ; si le
-- joueur est encore là, ce qui n'a pas pu partir rejoint le prochain lot.
function ProfileStore.Flush(player: Player)
	local entry = pending[player]
	if not entry then
		return
	end
	pending[player] = nil
	local counters, writes = entry.Counters, entry.Writes
	local userId = player.UserId
	task.spawn(function()
		for attempt = 1, FLUSH_ATTEMPTS do
			local saved = ProfileStore.UpdateNow(userId, "sauvegarde", function(stored)
				local fields = stored :: any
				for counter, amount in pairs(counters) do
					fields[counter] += amount
				end
				for _, write in pairs(writes) do
					write(stored)
				end
				return true
			end)
			if saved or not Stores.Available() then
				return
			end
			if attempt < FLUSH_ATTEMPTS then
				task.wait(2 ^ attempt)
			end
		end
		if profiles[player] then
			local again = pendingOf(player)
			for counter, amount in pairs(counters) do
				again.Counters[counter] = (again.Counters[counter] or 0) + amount
			end
			for key, write in pairs(writes) do
				if again.Writes[key] == nil then -- une demande plus récente l'emporte
					again.Writes[key] = write
				end
			end
		end
	end)
end

local function onPlayerAdded(player: Player)
	local data: any = nil
	local dataStore = store()
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(profileKey(player.UserId))
		end)
		if ok then
			data = result
		else
			Stores.Failed("chargement du profil", result)
		end
	end
	if not player.Parent then
		return -- parti pendant le chargement
	end
	local profile = ProfileSchema.Sanitize(data, player.UserId)
	profiles[player] = profile
	for _, listener in ipairs(loadedListeners) do
		local ok, err = pcall(function()
			listener(player, profile)
		end)
		if not ok then
			warn("[ProfileStore] Chargement du profil :", err)
		end
	end
end

-- À appeler une fois tous les services inscrits (OnLoaded).
function ProfileStore.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		ProfileStore.Flush(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for player in pairs(pending) do
				ProfileStore.Flush(player)
			end
		end
	end)

	game:BindToClose(function()
		for player in pairs(pending) do
			ProfileStore.Flush(player)
		end
		task.wait(2) -- laisse partir les écritures lancées en tâche de fond
	end)
end

return ProfileStore
