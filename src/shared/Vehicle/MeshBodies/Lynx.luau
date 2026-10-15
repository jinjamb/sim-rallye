--!nocheck
--[[
	Lynx.luau (généré : assets/meshes/source/export_luau.py)
	La Lynx faite dans Blender (assets/meshes/lynx) : chaque pièce du
	modèle, telle que l'outil d'import (tools/import-car.luau) doit la
	trouver et la ranger. Repère du châssis (X à droite, Y en haut, l'avant
	en -Z), en studs.
		Center, Size : la boîte de la pièce ;
		Paint        : sa peinture (comme CarBodies : Body, Trim, Glass...) ;
		Zone         : sa zone de peinture au choix du joueur (CarBodies.ZONES) ;
		Slot, Options: pièce d'option, posée seulement pour ces choix de
		               l'emplacement (Hood, Wing, Bumper) ;
		Detail       : petite pièce (hors des rayons, sans ombre).
	Mounts et Cabin : les repères du modèle, à la place de ceux de la
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -6.2, TailZ = 5.45, BottomY = -1.42, BeltY = 0.72, HalfWidth = 2.72,
		HoodFrontZ = -5.4, HoodRearZ = -2.3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.85, Y = 0.94, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.38, BaseY = 0.6, TopY = 2.3, WindshieldFrontZ = -2.32, RoofFrontZ = -0.6, RoofRearZ = 4.1 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5579, -0.375), Size = Vector3.new(6.56, 1.7242, 11.65), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.0346, -5.8), Size = Vector3.new(6.56, 0.7708, 0.8), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.485, -5.8), Size = Vector3.new(6.56, 1.87, 0.8), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.9917, -0.4, -3.85), Size = Vector3.new(0.5767, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.535, -3.85), Size = Vector3.new(6.06, 0.17, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.9917, -0.4, -3.85), Size = Vector3.new(0.5767, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.7117, -0.3172, -0.45), Size = Vector3.new(0.4833, 2.2056, 3.7), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.78, 1.275), Size = Vector3.new(6.06, 0.32, 7.15), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.7117, -0.3172, -0.45), Size = Vector3.new(0.4833, 2.2056, 3.7), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.875, -0.24, 3.175), Size = Vector3.new(0.81, 2.36, 3.55), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.875, -0.24, 3.175), Size = Vector3.new(0.81, 2.36, 3.55), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.94, 4.9), Size = Vector3.new(6.06, 0, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.6838, 5.2), Size = Vector3.new(6.56, 1.4724, 0.5), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.24, 5.2), Size = Vector3.new(6.56, 2.36, 0.5), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.15, 1.6662), Size = Vector3.new(3.96, 0.3, 5.1394), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.3, 1.275), Size = Vector3.new(4.76, 1.4, 7.19), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.176, 1.314, 0.3878), Size = Vector3.new(0.28, 0.98, 3.3155) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.176, 1.314, 2.9844), Size = Vector3.new(0.28, 0.98, 1.3724) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.176, 1.314, 0.3878), Size = Vector3.new(0.28, 0.98, 3.3155) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.176, 1.314, 2.9844), Size = Vector3.new(0.28, 0.98, 1.3724) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.3, -1.6118), Size = Vector3.new(4.0248, 1.12, 1.1332) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.3, 4.5529), Size = Vector3.new(4.0248, 1.12, 0.5073) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.7, -6.24), Size = Vector3.new(3.2, 0.9, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.26, -0.07, -6.26), Size = Vector3.new(1.32, 0.46, 0) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.2, -0.7, -6.26), Size = Vector3.new(0.3141, 0.3141, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.7, 0.225, 5.48), Size = Vector3.new(0.5, 0.75, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.26, -0.07, -6.26), Size = Vector3.new(1.32, 0.46, 0) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.2, -0.7, -6.26), Size = Vector3.new(0.3141, 0.3141, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.7, 0.225, 5.48), Size = Vector3.new(0.5, 0.75, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.495, 0.7969, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.495, 0.7969, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.82), Size = Vector3.new(4.6, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.3, -1, 5.4), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.14, 5.48), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.31, -0.6288, -4.05), Size = Vector3.new(0, 1.5824, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.31, -0.6288, -4.05), Size = Vector3.new(0, 1.5824, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.31, -0.4579, 4.05), Size = Vector3.new(0, 1.9242, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.31, -0.4579, 4.05), Size = Vector3.new(0, 1.9242, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.75, -0.0772, 1.35), Size = Vector3.new(0, 1.6856, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.75, -0.0772, 1.35), Size = Vector3.new(0, 1.6856, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.9367, -0.16, -2.25), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.9367, -0.16, -2.25), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.31, -0.47, -5.35), Size = Vector3.new(0, 1.8, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.31, -0.47, -5.35), Size = Vector3.new(0, 1.8, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.31, -0.225, 4.9), Size = Vector3.new(0, 2.29, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.31, -0.225, 4.9), Size = Vector3.new(0, 2.29, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5664, -3.8475), Size = Vector3.new(4.59, 0.1618, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.75, -1.195, 0), Size = Vector3.new(0, 0.45, 4.1), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.75, 0.4887, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.75, -1.195, 0), Size = Vector3.new(0, 0.45, 4.1), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.75, 0.4887, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.425, 5.47), Size = Vector3.new(2.4, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7214, -4.25), Size = Vector3.new(2, 0.5604, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.5463, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.517, -4.17), Size = Vector3.new(3.5, 0.0991, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.49, 4.6), Size = Vector3.new(4.7, 0.14, 1.3), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.465, 4.675), Size = Vector3.new(4.86, 0.59, 1.35), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.75, -6.4), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.75, -6.5), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
