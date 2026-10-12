--!strict
--[[
	Cars.luau
	Les voitures du catalogue : une par catégorie (CarClasses.luau). La Rally2
	est de série ; les autres s'achètent en crédits OU en Robux (boutique).

	PRIX EN ROBUX : moins cher que les packs de crédits qu'il faudrait
	acheter pour la payer (Products.luau), pour que l'achat direct reste la
	bonne affaire :
		Rally4    2 500 CR  ->  99 R$   (en packs : Coffre, 129 R$)
		Groupe B 12 000 CR  -> 399 R$   (en packs : 477 R$, ou 649 R$ d'un coup)
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{
		Id = "car_rally2",
		Kind = "Car",
		Name = "Rally2",
		Description = "4 roues motrices, 290 ch",
		Rarity = "Serie",
		Free = true,
		CarClass = "Rally2",
	},
	{
		Id = "car_rally4",
		Kind = "Car",
		Name = "Rally4",
		Description = "Traction, 210 ch, agile",
		Rarity = "Club",
		Credits = 2500,
		Robux = 99,
		CarClass = "Rally4",
	},
	{
		Id = "car_groupb",
		Kind = "Car",
		Name = "Groupe B",
		Description = "4 roues motrices, 500 ch, turbo",
		Rarity = "Legende",
		Credits = 12000,
		Robux = 399,
		CarClass = "GroupB",
	},
}

return items
