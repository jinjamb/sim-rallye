--!strict
--[[
	Cars.luau
	Les voitures du catalogue, construites à partir de leurs fiches
	(Vehicle/CarModels.luau) : huit par catégorie, trois gratuites (prêtes
	dès le niveau de la catégorie : Level) et cinq à acheter en crédits OU en
	Robux (boutique).

	PRIX EN ROBUX : moins cher que les packs de crédits qu'il faudrait
	acheter pour la payer (Products.luau), pour que l'achat direct reste la
	bonne affaire.

	Les pilotes arrivés quand la Rally2 était de série la gardent
	(EconomyService : GarageVersion).
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)
local CarModels = require(script.Parent.Parent.Parent.Vehicle.CarModels)

local items: { ItemTypes.Item } = {}
for _, model in ipairs(CarModels.LIST) do
	table.insert(items, {
		Id = model.Id,
		Kind = "Car",
		Name = model.Name,
		Description = model.Description,
		Rarity = model.Rarity :: any,
		Free = model.Free,
		Credits = model.Credits,
		Robux = model.Robux,
		CarClass = model.Class,
		Level = CarModels.LevelOf(model),
	})
end

return items
