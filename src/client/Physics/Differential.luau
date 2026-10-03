--!strict
--[[
	Differential.luau
	Différentiel autobloquant à rampes (type Salisbury), le standard des voitures
	de rallye.

	OUVERT : le couple d'entrée est partagé dans une proportion FIXE (Split) entre
	les deux sorties, quelles que soient leurs vitesses. Une sortie qui perd
	l'adhérence (roue délestée, en l'air, sur la glace) s'emballe, le moteur
	monte dans les tours avec elle, et l'autre sortie ne reçoit pas plus.

	AUTOBLOQUANT : un embrayage interne freine l'écart de vitesse entre les deux
	sorties, ce qui renvoie du couple vers la sortie la plus lente, celle qui
	adhère. Sa capacité :

		C = Preload + Lock * |couple d'entrée| / 2

	Preload : tarage des rondelles, agit même pédale levée.
	Lock    : effet des rampes, proportionnel au couple qui traverse le
	          différentiel. Différent en traction (Power) et en frein moteur
	          (Coast) : c'est ce qu'on appelle un différentiel "1.5 voie".
	          Lock = 1 suffit à renvoyer TOUT le couple d'un seul côté ; le
	          rapport de couple maximal entre les sorties vaut (1+Lock)/(1-Lock),
	          le "TBR" des fiches techniques (Lock 0.5 -> TBR 3).

	RÉSOLUTION : comme le pneu (voir Wheel.luau), par impulsion implicite.
	On calcule l'impulsion qui égaliserait EXACTEMENT les deux vitesses compte
	tenu des deux inerties, puis on l'écrête à C * dt. Non écrêtée, elle verrouille
	sans osciller ; écrêtée, elle ne peut pas inverser l'écart. Stable quelle que
	soit la petitesse de l'inertie des roues.
]]

local Differential = {}
Differential.__index = Differential

export type DifferentialConfig = {
	Split: number, -- part du couple d'entrée vers la sortie 2 (0.5 = symétrique)
	Preload: number, -- couple de tarage (unités de couple Roblox)
	PowerLock: number, -- 0..1, en traction
	CoastLock: number, -- 0..1, en frein moteur
}

export type Differential = typeof(setmetatable({}, Differential)) & DifferentialConfig & {
	-- Diagnostic de la dernière frame
	LockingTorque: number, -- couple de blocage réellement transmis
	Capacity: number, -- couple de blocage disponible
	Engaged: boolean, -- false : non résolu cette frame (arrière désaccouplé)
}

function Differential.new(config: DifferentialConfig): Differential
	local self = (setmetatable({}, Differential) :: any) :: Differential
	self.Split = config.Split
	self.Preload = config.Preload
	self.PowerLock = config.PowerLock
	self.CoastLock = config.CoastLock
	self.LockingTorque = 0
	self.Capacity = 0
	self.Engaged = false
	return self
end

--[[
	État lisible pour la télémétrie :
		"bloqué"     : l'embrayage a suffi, les deux sorties tournent ensemble ;
		"glisse"     : capacité atteinte, les sorties tournent à des vitesses
		               différentes (normal en virage, ou une roue qui patine) ;
		"libre"      : non résolu cette frame.
]]
function Differential:GetStateLabel(): string
	if not self.Engaged then
		return "libre"
	end
	if self.Capacity <= 0 or math.abs(self.LockingTorque) >= self.Capacity * 0.99 then
		return "glisse"
	end
	return "bloqué"
end

-- isPower : le moteur entraîne les roues (et non l'inverse, en frein moteur).
function Differential:GetCapacity(inputTorque: number, isPower: boolean): number
	local lock = if isPower then self.PowerLock else self.CoastLock
	return self.Preload + lock * math.abs(inputTorque) * 0.5
end

--[[
	Impulsion angulaire à retirer à la sortie 1 et à ajouter à la sortie 2 pour
	freiner leur écart de vitesse, dans la limite de la capacité.
	Positive quand la sortie 1 tourne plus vite.
]]
function Differential:Solve(
	omega1: number,
	inertia1: number,
	omega2: number,
	inertia2: number,
	capacity: number,
	dt: number
): number
	local equalizing = (omega1 - omega2) / (1 / inertia1 + 1 / inertia2)
	local maxImpulse = capacity * dt
	local impulse = math.clamp(equalizing, -maxImpulse, maxImpulse)
	self.LockingTorque = impulse / dt
	self.Capacity = capacity
	self.Engaged = true
	return impulse
end

-- À appeler à la place de Solve quand le différentiel n'est pas en prise.
function Differential:Disengage()
	self.LockingTorque = 0
	self.Capacity = 0
	self.Engaged = false
end

return Differential
