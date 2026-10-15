--!nocheck
--[[
	Tora.luau (généré : assets/meshes/source/export_luau.py)
	La Tora faite dans Blender (assets/meshes/tora) : chaque pièce du
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
	carrosserie en pièces (numéros, feux, accessoires). Cabin.TopY est,
	comme pour les carrosseries en pièces, le dessous du toit (0.24 sous le
	dessus) : les accessoires de toit se posent dessus.
]]

return {
	Mounts = {
		NoseZ = -5.6, TailZ = 5, BottomY = -1.42, BeltY = 0.95, HalfWidth = 2.7, NoseHalfWidth = 2.56,
		HoodFrontZ = -5.15, HoodRearZ = -2.55, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.4, Y = 1.09, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.35, BaseY = 0.86, TopY = 2.48, WindshieldFrontZ = -2.57, RoofFrontZ = -1.3, RoofRearZ = 4.35 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.52, -0.3), Size = Vector3.new(6.4, 1.8, 10.6), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -0.787, -5.375), Size = Vector3.new(6.4, 1.266, 0.45), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.32, -5.375), Size = Vector3.new(6.4, 2.2, 0.45), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.9275, -0.28, -3.85), Size = Vector3.new(0.545, 2.28, 2.6), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.82, -3.85), Size = Vector3.new(5.56, 0.2, 2.6), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.9275, -0.28, -3.85), Size = Vector3.new(0.545, 2.28, 2.6), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.6775, -0.2154, -0.625), Size = Vector3.new(0.795, 2.4092, 3.85), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 1.01, 1.025), Size = Vector3.new(5.56, 0.3, 7.15), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.6775, -0.2154, -0.625), Size = Vector3.new(0.795, 2.4092, 3.85), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.74, -0.16, 3), Size = Vector3.new(0.92, 2.52, 3.4), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.74, -0.16, 3), Size = Vector3.new(0.92, 2.52, 3.4), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.13, 4.65), Size = Vector3.new(5.56, 0.06, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, 0.1142, 4.85), Size = Vector3.new(6.4, 0.2116, 0.3), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, 0.5842, 4.85), Size = Vector3.new(6.4, 1.1516, 0.3), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.545, 1.4309), Size = Vector3.new(4.1, 0.35, 5.9398), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.615, 1.025), Size = Vector3.new(4.7, 1.51, 7.19), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.203, 1.5999, -0.2597), Size = Vector3.new(0.234, 1.1778, 3.2839) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.203, 1.5999, 2.5846), Size = Vector3.new(0.234, 1.1778, 2.0488) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.203, 1.5999, -0.2597), Size = Vector3.new(0.234, 1.1778, 3.2839) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.203, 1.5999, 2.5846), Size = Vector3.new(0.234, 1.1778, 2.0488) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.615, -2.0545), Size = Vector3.new(3.9904, 1.208, 0.8248) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.615, 4.5104), Size = Vector3.new(3.9904, 1.208, 0.1754) },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.45, 0.2, -5.64), Size = Vector3.new(0.8114, 0.8114, 0.06) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(2.553, 0.425, 5.03), Size = Vector3.new(0.35, 1.05, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.45, 0.2, -5.64), Size = Vector3.new(0.8114, 0.8114, 0.06) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-2.553, 0.425, 5.03), Size = Vector3.new(0.35, 1.05, 0) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.475, -5.64), Size = Vector3.new(1.5, 0.35, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -1.05, -5.64), Size = Vector3.new(3.2, 0.3, 0), Zone = "Bumpers" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.415, 1.0301, -1.9), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.415, 1.0301, -1.9), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.2, -1, 4.95), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.24, 5.03), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.105, -0.5087, -3.95), Size = Vector3.new(0.25, 1.8225, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.105, -0.5087, -3.95), Size = Vector3.new(0.25, 1.8225, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.0799, -0.42, 3.95), Size = Vector3.new(0.3002, 2, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.0799, -0.42, 3.95), Size = Vector3.new(0.3002, 2, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.67, 0.0246, 1.25), Size = Vector3.new(0.12, 1.8892, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.67, 0.0246, 1.25), Size = Vector3.new(0.12, 1.8892, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.9825, -0.04, -2.5), Size = Vector3.new(0.12, 1.76, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.9825, -0.04, -2.5), Size = Vector3.new(0.12, 1.76, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.17, -0.335, -5.1), Size = Vector3.new(0.12, 2.07, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.17, -0.335, -5.1), Size = Vector3.new(0.12, 2.07, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.17, -0.145, 4.65), Size = Vector3.new(0.12, 2.45, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.17, -0.145, 4.65), Size = Vector3.new(0.12, 2.45, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.843, -3.8475), Size = Vector3.new(4.59, 0.1303, 2.495), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.73, -1.245, 0), Size = Vector3.new(0, 0.35, 4.5), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.61, 0.6991, 0.7), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.73, -1.245, 0), Size = Vector3.new(0, 0.35, 4.5), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.61, 0.6991, 0.7), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.2, 5.02), Size = Vector3.new(2.4, 0.3, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.9529, -4.25), Size = Vector3.new(2, 0.7258, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.695, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.8174, -4.17), Size = Vector3.new(3.5, 0.1082, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.85, 4.525), Size = Vector3.new(4.6, 0.14, 1.05), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.85, 4.6), Size = Vector3.new(4.76, 0.54, 1.1), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.65, -5.8), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.65, -5.9), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
