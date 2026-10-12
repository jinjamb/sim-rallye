--!strict
--[[
	Stores.luau
	Accès aux DataStores, avec repli en mémoire.

	Dans Studio, les DataStores exigent "Activer l'accès Studio aux services
	d'API" (Paramètres du jeu > Sécurité) ; une place jamais publiée n'en a pas
	du tout. Sans eux, tout le jeu fonctionne quand même, en mémoire, pour la
	session : chaque module de données demande ses stores ici, et reçoit nil
	quand ils manquent.

	Limites de Roblox : ~60 + 10 x joueurs écritures par minute et par
	serveur. Les écritures sont rares par construction (ProfileStore les
	regroupe) : on en reste loin.
]]

local DataStoreService = game:GetService("DataStoreService")

local Stores = {}

local available = true
local warned = false
local stores: { [string]: DataStore } = {}
local ordered: { [string]: OrderedDataStore } = {}

-- Une opération a échoué : prévenir une fois, et renoncer aux stores si
-- l'accès est refusé (Studio) plutôt que d'échouer à chaque appel.
function Stores.Failed(context: string, err: any)
	local message = tostring(err)
	if string.find(message, "Studio", 1, true) or string.find(message, "403", 1, true) then
		available = false
	end
	if not warned then
		warned = true
		warn(string.format(
			"[Données] DataStore indisponible (%s : %s). Données gardées en mémoire pour la session. "
				.. "Dans Studio : Paramètres du jeu > Sécurité > Activer l'accès Studio aux services d'API.",
			context,
			message
		))
	end
end

function Stores.Available(): boolean
	return available
end

function Stores.Get(name: string): DataStore?
	if not available then
		return nil
	end
	local existing = stores[name]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		-- Typiquement : place jamais publiée sur Roblox. Inutile d'insister.
		available = false
		Stores.Failed(name, result)
		return nil
	end
	stores[name] = result
	return result
end

function Stores.Ordered(name: string): OrderedDataStore?
	if not available then
		return nil
	end
	local existing = ordered[name]
	if existing then
		return existing
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if not ok then
		-- Typiquement : place jamais publiée sur Roblox. Inutile d'insister.
		available = false
		Stores.Failed(name, result)
		return nil
	end
	ordered[name] = result
	return result
end

return Stores
