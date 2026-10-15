--!nocheck
--[[
	Raijin.luau (généré : assets/meshes/source/export_luau.py)
	La Raijin faite dans Blender (assets/meshes/raijin) : chaque pièce du
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
		NoseZ = -6.8, TailZ = 6.2, BottomY = -1.42, BeltY = 0.65, HalfWidth = 2.75,
		HoodFrontZ = -5.9, HoodRearZ = -1.9, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.6, Y = 0.82, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.58, TopY = 2.12, WindshieldFrontZ = -1.92, RoofFrontZ = -0.2, RoofRearZ = 2 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.6, -0.3), Size = Vector3.new(6.9, 1.64, 13), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.35), Size = Vector3.new(5.5, 0, 0.9), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.635, -6.35), Size = Vector3.new(5.5, 1.57, 0.9), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.1, -0.42, -3.9), Size = Vector3.new(0.7, 2, 4), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.365, -3.9), Size = Vector3.new(6.9, 0.43, 4), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.1, -0.42, -3.9), Size = Vector3.new(0.7, 2, 4), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.75, -0.3498, 0), Size = Vector3.new(0, 2.1403, 3.8), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.7, 1.35), Size = Vector3.new(6.9, 0.24, 6.5), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.75, -0.3498, 0), Size = Vector3.new(0, 2.1403, 3.8), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.1, -0.3, 3.75), Size = Vector3.new(0.7, 2.24, 3.7), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.1, -0.3, 3.75), Size = Vector3.new(0.7, 2.24, 3.7), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.82, 5.1), Size = Vector3.new(6.9, 0, 1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 5.9), Size = Vector3.new(6.9, 0, 0.6), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.28, 5.9), Size = Vector3.new(6.9, 2.28, 0.6), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.1195, 0.9003), Size = Vector3.new(4, 0.001, 2.2028), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.3495, 1.35), Size = Vector3.new(4.8, 1.539, 6.54), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2, 1.3495, 0.3971), Size = Vector3.new(0.288, 1.1081, 3.2037) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2, 1.3495, 2.5646), Size = Vector3.new(0.288, 1.1081, 2.1911) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2, 1.3495, 0.3971), Size = Vector3.new(0.288, 1.1081, 3.2037) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2, 1.3495, 2.5646), Size = Vector3.new(0.288, 1.1081, 2.1911) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.3495, -1.0606), Size = Vector3.new(4.0592, 1.2312, 1.3751) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.3495, 3.3109), Size = Vector3.new(4.0592, 1.2312, 2.0946) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.425, -6.84), Size = Vector3.new(4.62, 0.35, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.55, -0.43, -6.86), Size = Vector3.new(1.3, 0.14, 0) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.45, 0.41, 6.25), Size = Vector3.new(2.1, 0.22, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.55, -0.43, -6.86), Size = Vector3.new(1.3, 0.14, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.45, 0.41, 6.25), Size = Vector3.new(2.1, 0.22, 0) },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.175, -6.55), Size = Vector3.new(5, 0.25, 1.1), Zone = "Bumpers" },
	{ Name = "Louver", Paint = "Body", Center = Vector3.new(0, 1.4208, 3.2576), Size = Vector3.new(4.324, 1.1088, 1.8864), Zone = "Details", Detail = true },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.585, 0.7521, -1.25), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.585, 0.7521, -1.25), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.5, -1, 6.15), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.31, 6.23), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.48, -0.6979, -4.05), Size = Vector3.new(0, 1.4441, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.48, -0.6979, -4.05), Size = Vector3.new(0, 1.4441, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.48, -0.5102, 4.05), Size = Vector3.new(0, 1.8197, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.48, -0.5102, 4.05), Size = Vector3.new(0, 1.8197, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.78, -0.1098, 1.85), Size = Vector3.new(0, 1.6203, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.78, -0.1098, 1.85), Size = Vector3.new(0, 1.6203, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.78, -0.18, -1.85), Size = Vector3.new(0, 1.48, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.78, -0.18, -1.85), Size = Vector3.new(0, 1.48, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.78, -0.62, -5.85), Size = Vector3.new(0, 1.5, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.78, -0.62, -5.85), Size = Vector3.new(0, 1.5, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.48, -0.285, 5.55), Size = Vector3.new(0, 2.17, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.48, -0.285, 5.55), Size = Vector3.new(0, 2.17, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.3977, -3.8975), Size = Vector3.new(4.59, 0.4139, 3.895), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.85, 5.1225), Size = Vector3.new(4.59, 0, 0.845), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.78, -1.195, 0), Size = Vector3.new(0, 0.45, 4.9), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.78, 0.4245, 1.2), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.78, -1.195, 0), Size = Vector3.new(0, 0.45, 4.9), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.78, 0.4245, 1.2), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.425, 6.22), Size = Vector3.new(5.2, 0.55, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.5474, -4.25), Size = Vector3.new(2, 0.6688, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.318, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.3302, -4.17), Size = Vector3.new(3.5, 0.1654, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.07, 5.75), Size = Vector3.new(3.4, 0.5, 0.5), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 1.41, 5.8), Size = Vector3.new(5.8, 0.18, 1), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.75, -7), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.75, -7.1), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
