--!strict
--[[
	Cars.luau
	Les voitures du catalogue : une par catégorie (CarClasses.luau). La Rally2
	est de série ; les autres s'achètent en crédits.
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
		CarClass = "Rally4",
	},
	{
		Id = "car_groupb",
		Kind = "Car",
		Name = "Groupe B",
		Description = "4 roues motrices, 500 ch, turbo",
		Rarity = "Legende",
		Credits = 12000,
		CarClass = "GroupB",
	},
}

return items
