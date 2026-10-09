--!strict
--[[
	Boards.luau
	Classements sauvegardés (OrderedDataStore : une valeur par joueur,
	triée par Roblox), complétés par les résultats de la session.

	Les meilleurs temps de la session servent de classement quand le
	DataStore manque, et complètent le classement sauvegardé avec les records
	tout juste battus (le DataStore met un moment à les refléter).
]]

local Players = game:GetService("Players")

local Stores = require(script.Parent.Stores)

local Boards = {}

export type Entry = { UserId: number, Name: string, Ms: number }

local nameCache: { [number]: string } = {}

-- Nom affiché d'un pilote, connecté ou non (peut attendre : à appeler hors
-- du fil principal).
function Boards.NameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else ("Pilote " .. tostring(userId))
	nameCache[userId] = resolved
	return resolved
end

function Boards.RememberName(player: Player)
	nameCache[player.UserId] = player.DisplayName
end

--[[
	Classement trié (plus petit d'abord) et tronqué à `size` : le sauvegardé,
	complété de `session` (UserId -> valeur).
]]
function Boards.Merge(store: OrderedDataStore?, session: { [number]: number }, size: number, context: string): { Entry }
	local entries: { Entry } = {}
	local byUser: { [number]: Entry } = {}
	if Stores.Available() and store then
		local ok, err = pcall(function()
			local pages = store:GetSortedAsync(true, size)
			for _, item in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(item.key)
				if userId then
					local entry = { UserId = userId, Name = Boards.NameOf(userId), Ms = item.value }
					table.insert(entries, entry)
					byUser[userId] = entry
				end
			end
		end)
		if not ok then
			Stores.Failed(context, err)
		end
	end
	for userId, ms in pairs(session) do
		local existing = byUser[userId]
		if existing then
			existing.Ms = math.min(existing.Ms, ms)
		else
			table.insert(entries, { UserId = userId, Name = Boards.NameOf(userId), Ms = ms })
		end
	end
	table.sort(entries, function(a, b)
		return a.Ms < b.Ms
	end)
	while #entries > size do
		table.remove(entries)
	end
	return entries
end

-- Enregistre `value` pour ce joueur si elle bat (plus petite) celle du
-- classement, en tâche de fond.
function Boards.SubmitLowest(store: OrderedDataStore?, userId: number, value: number, context: string)
	if not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(userId), function(old: any)
				if type(old) == "number" and old <= value then
					return nil
				end
				return value
			end)
		end)
		if not ok then
			Stores.Failed(context, err)
		end
	end)
end

-- Remplace la valeur de ce joueur, en tâche de fond.
function Boards.Set(store: OrderedDataStore?, userId: number, value: number, context: string)
	if not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(userId), value)
		end)
		if not ok then
			Stores.Failed(context, err)
		end
	end)
end

-- Regroupe les rafraîchissements demandés en rafale : `refresh` tourne une
-- fois, `delay` secondes après la première demande.
function Boards.Debounced(delay: number, refresh: () -> ()): () -> ()
	local scheduled = false
	return function()
		if scheduled then
			return
		end
		scheduled = true
		task.delay(delay, function()
			scheduled = false
			refresh()
		end)
	end
end

return Boards
