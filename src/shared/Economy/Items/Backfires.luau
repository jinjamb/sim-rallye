--!strict
--[[
	Backfires.luau
	Retours de flamme : la couleur, la taille et la détonation des flammes
	qui sortent de l'échappement (Driving/Exhaust.luau, attribut
	EquippedBackfire de la voiture), vus et entendus par tous.
		Color   les flammes ; Color2 : leur cœur (souvent plus clair) ;
		Scale   taille de la gerbe (1 = normale) ;
		Sound   détonation propre (identifiant audio) ; sinon celles de
		        SoundBank.Backfire, communes à tous.
]]

local ItemTypes = require(script.Parent.Parent.ItemTypes)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local items: { ItemTypes.Item } = {
	{ Id = "backfire_classic", Kind = "Backfire", Name = "Flammes classiques", Description = "orange, cœur jaune", Rarity = "Serie", Free = true, Color = rgb(255, 110, 25), Color2 = rgb(255, 215, 110) },
	{ Id = "backfire_blue", Kind = "Backfire", Name = "Bleu course", Description = "l'essence de course qui brûle bleu", Rarity = "Club", Credits = 1500, Roll = true, Color = rgb(40, 120, 255), Color2 = rgb(190, 225, 255) },
	{ Id = "backfire_purple", Kind = "Backfire", Name = "Violet", Description = "violet électrique", Rarity = "Pro", Credits = 3000, Roll = true, Color = rgb(150, 60, 255), Color2 = rgb(235, 190, 255) },
	{ Id = "backfire_green", Kind = "Backfire", Name = "Vert bore", Description = "la flamme verte des chimistes", Rarity = "Pro", Roll = true, Color = rgb(40, 220, 90), Color2 = rgb(210, 255, 180) },
	{ Id = "backfire_sakura", Kind = "Backfire", Name = "Sakura", Description = "rose, cœur blanc", Rarity = "Usine", Roll = true, Color = rgb(255, 60, 140), Color2 = rgb(255, 225, 240) },
	{ Id = "backfire_plasma", Kind = "Backfire", Name = "Plasma", Description = "blanc aveuglant, bordé de bleu", Rarity = "Usine", Credits = 6000, Color = rgb(120, 200, 255), Color2 = rgb(255, 255, 255), Scale = 1.15 },
	{ Id = "backfire_neon", Kind = "Backfire", Name = "Néon", Description = "cyan qui vire au rose", Rarity = "Prototype", Roll = true, Color = rgb(255, 50, 200), Color2 = rgb(0, 230, 255), Scale = 1.15 },
	{ Id = "backfire_dragon", Kind = "Backfire", Name = "Souffle du dragon", Description = "une gerbe énorme, rouge sang", Rarity = "Prototype", Credits = 12000, Color = rgb(230, 25, 15), Color2 = rgb(255, 160, 40), Scale = 1.6 },
	{ Id = "backfire_gold", Kind = "Backfire", Name = "Or", Description = "des flammes dorées, scintillantes", Rarity = "Legende", Roll = true, Color = rgb(255, 185, 20), Color2 = rgb(255, 250, 200), Scale = 1.3 },
}

return items
