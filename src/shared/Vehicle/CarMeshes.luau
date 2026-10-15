--!strict
--[[
	CarMeshes.luau
	Les carrosseries faites dans Blender (assets/meshes/<modèle>), à la place
	des carrosseries en pièces Roblox de CarBodies.luau, modèle par modèle.

	Pour un modèle, il faut DEUX choses :
		- sa description, MeshBodies/<Nom>.luau (générée avec le modèle) :
		  chaque pièce, sa boîte, sa peinture, sa zone, son option, et les
		  repères du modèle (Mounts, Cabin) ;
		- ses maillages, importés dans Studio et rangés par l'outil
		  tools/import-car.luau dans ReplicatedStorage.CarMeshes.<Nom> :
		  une MeshPart par pièce, avec sa place sur le châssis (attribut
		  LocalCFrame).
	S'il manque l'un des deux, CarBodies garde la carrosserie en pièces :
	rien ne casse tant que l'import n'est pas fait.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarMeshes = {}

CarMeshes.FOLDER = "CarMeshes" -- dans ReplicatedStorage (hors de Rojo : rangé par l'outil)
CarMeshes.PLACE_ATTRIBUTE = "LocalCFrame" -- place de la pièce dans le repère du châssis

export type PartInfo = {
	Name: string,
	Paint: string,
	Center: Vector3,
	Size: Vector3,
	Zone: string?,
	Slot: string?, -- pièce d'option : posée seulement pour ces choix de l'emplacement
	Options: { number }?,
	Detail: boolean?,
}
export type Data = { Mounts: any, Cabin: any, Parts: { PartInfo } }

local cache: { [string]: Data | false } = {}

-- La description d'un modèle (nil : pas de version Blender).
function CarMeshes.Data(name: string): Data?
	local cached = cache[name]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: Data
	end
	local folder = script.Parent:FindFirstChild("MeshBodies")
	local module = folder and folder:FindFirstChild(name)
	local data: Data? = nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			data = result :: any
		end
	end
	cache[name] = data or false
	return data
end

-- Les maillages importés d'un modèle (nil : pas encore importés).
function CarMeshes.Template(name: string): Model?
	local root = ReplicatedStorage:FindFirstChild(CarMeshes.FOLDER)
	local template = root and root:FindFirstChild(name)
	if template and template:IsA("Model") and template:FindFirstChildWhichIsA("MeshPart") then
		return template
	end
	return nil
end

-- Description et maillages, seulement si les deux sont là.
function CarMeshes.Find(name: string): (Data?, Model?)
	local data = CarMeshes.Data(name)
	if not data then
		return nil, nil
	end
	local template = CarMeshes.Template(name)
	if not template then
		return nil, nil
	end
	return data, template
end

-- Le modèle a-t-il une pièce d'option pour ce choix de l'emplacement ?
function CarMeshes.HasOption(data: Data, slot: string, option: number): boolean
	for _, info in ipairs(data.Parts) do
		if info.Slot == slot and info.Options and table.find(info.Options, option) then
			return true
		end
	end
	return false
end

-- La pièce est-elle posée pour ces choix ? (`option` : choix d'un emplacement)
function CarMeshes.Wanted(info: PartInfo, option: (slot: string) -> number): boolean
	local slot = info.Slot
	if not slot then
		return true
	end
	local options = info.Options
	return options ~= nil and table.find(options, option(slot)) ~= nil
end

return CarMeshes
