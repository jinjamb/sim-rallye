--!strict
--[[
	Cars.luau
	Les voitures du catalogue : une par catégorie (CarClasses.luau), dans
	l'ordre de la carrière. La Rally4 est de série ; les suivantes
	s'achètent en crédits OU en Robux (boutique).

	PRIX EN ROBUX : moins cher que les packs de crédits qu'il faudrait
	acheter pour la payer (Products.luau), pour que l'achat direct reste la
	bonne affaire :
		Rally2    3 000 CR  ->  99 R$   (en packs : Coffre, 129 R$)
		WRC       8 000 CR  -> 199 R$   (en packs : Caisse d'équipe, 299 R$)
		Groupe B 15 000 CR  -> 399 R$   (en packs : 598 R$, ou 649 R$ d'un coup)

	Les pilotes arrivés quand la Rally2 était de série la gardent
	(EconomyService : GarageVersion).
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local items: { ItemTypes.Item } = {
	{
		Id = "car_rally4",
		Kind = "Car",
		Name = "Rally4",
		Description = "Traction, 210 ch, agile",
		Rarity = "Serie",
		Free = true,
		CarClass = "Rally4",
	},
	{
		Id = "car_rally2",
		Kind = "Car",
		Name = "Rally2",
		Description = "4 roues motrices, 290 ch",
		Rarity = "Club",
		Credits = 3000,
		Robux = 99,
		CarClass = "Rally2",
	},
	{
		Id = "car_wrc",
		Kind = "Car",
		Name = "WRC",
		Description = "4 roues motrices, 380 ch, gros appui aéro",
		Rarity = "Usine",
		Credits = 8000,
		Robux = 199,
		CarClass = "WRC",
	},
	{
		Id = "car_groupb",
		Kind = "Car",
		Name = "Groupe B",
		Description = "4 roues motrices, 500 ch, turbo",
		Rarity = "Legende",
		Credits = 15000,
		Robux = 399,
		CarClass = "GroupB",
	},
}

return items
