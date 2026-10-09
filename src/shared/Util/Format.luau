--!strict
--[[
	Format.luau
	Mise en forme des nombres pour l'affichage, partagée par le serveur
	(panneaux du paddock) et le client (menus, chronos, bandeaux) : un seul
	endroit pour qu'un temps s'écrive partout de la même façon.
]]

local Format = {}

local DAY = 86400

-- Chrono "m:ss.cc" ; rien de connu : "--:--.--".
function Format.Time(seconds: number?): string
	if seconds == nil then
		return "--:--.--"
	end
	local s = math.max(0, seconds :: number)
	local minutes = math.floor(s / 60)
	return string.format("%d:%05.2f", minutes, s - minutes * 60)
end

-- Même chose, à partir de millisecondes (ce que le serveur envoie).
function Format.Ms(ms: number?): string
	return Format.Time(if ms then ms / 1000 else nil)
end

-- 12500 -> "12 500" (espace des milliers, à la française).
function Format.Thousands(value: number): string
	local negative = value < 0
	local text = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1 ")))
	formatted = (string.gsub(formatted, "^ ", ""))
	return if negative then "-" .. formatted else formatted
end

-- Temps restant, à la louche : "3 j 4 h", "5 h 07 min", "12 min".
function Format.Remaining(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days = s // DAY
	local hours = (s % DAY) // 3600
	local minutes = (s % 3600) // 60
	if days > 0 then
		return string.format("%d j %d h", days, hours)
	elseif hours > 0 then
		return string.format("%d h %02d min", hours, minutes)
	end
	return string.format("%d min", math.max(1, minutes))
end

-- Virgule décimale à la française : "2.5 m" -> "2,5 m".
function Format.Decimal(text: string): string
	return (string.gsub(text, "%.", ","))
end

return Format
