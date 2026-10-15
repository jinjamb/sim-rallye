--!nocheck
--[[
	Fauve.luau (généré : assets/meshes/source/export_luau.py)
	La Fauve faite dans Blender (assets/meshes/fauve) : chaque pièce du
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
		NoseZ = -6.05, TailZ = 5.35, BottomY = -1.42, BeltY = 0.82, HalfWidth = 2.72, NoseHalfWidth = 2.47,
		HoodFrontZ = -5.4, HoodRearZ = -2.4, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.75, Y = 1.07, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.72, TopY = 2.31, WindshieldFrontZ = -2.42, RoofFrontZ = -0.75, RoofRearZ = 4.45 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.52, -0.35), Size = Vector3.new(6.64, 1.8, 11.4), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.0346, -5.725), Size = Vector3.new(6.64, 0.7708, 0.65), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.41, -5.725), Size = Vector3.new(6.64, 2.02, 0.65), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.91, -0.36, -3.9), Size = Vector3.new(0.82, 2.12, 3), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.65, -3.9), Size = Vector3.new(6.2, 0.1, 3), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.91, -0.36, -3.9), Size = Vector3.new(0.82, 2.12, 3), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.61, -0.265, -0.575), Size = Vector3.new(0.22, 2.31, 3.65), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.89, 1.25), Size = Vector3.new(6.2, 0.38, 7.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.61, -0.265, -0.575), Size = Vector3.new(0.22, 2.31, 3.65), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.91, -0.17, 3.1), Size = Vector3.new(0.82, 2.5, 3.7), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.91, -0.17, 3.1), Size = Vector3.new(0.82, 2.5, 3.7), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.08, 4.925), Size = Vector3.new(6.2, 0, 0.05), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.224, 5.15), Size = Vector3.new(6.64, 0.5528, 0.4), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, 0.2898, 5.15), Size = Vector3.new(6.64, 1.5804, 0.4), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.49, 1.8107), Size = Vector3.new(4.24, 0.12, 5.3403), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.575, 1.25), Size = Vector3.new(4.8, 1.71, 7.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2572, 1.5921, 0.1881), Size = Vector3.new(0.196, 1.197, 3.3129) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2572, 1.5921, 2.8841), Size = Vector3.new(0.196, 1.197, 1.6848) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2572, 1.5921, 0.1881), Size = Vector3.new(0.196, 1.197, 3.3129) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2572, 1.5921, 2.8841), Size = Vector3.new(0.196, 1.197, 1.6848) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.575, -1.6398), Size = Vector3.new(4.0798, 1.368, 1.2484) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.575, 4.7004), Size = Vector3.new(4.0798, 1.368, 0.3513) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, 0.12, -6.09), Size = Vector3.new(1.9, 0.24, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.835, -6.09), Size = Vector3.new(4.9, 0.83, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.6, 0.11, -6.11), Size = Vector3.new(1.1, 0.38, 0) },
	{ Name = "SideIntake_R", Paint = "Trim", Center = Vector3.new(2.7319, 0, 1.85), Size = Vector3.new(0, 1.1, 1.1), Zone = "Details" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.625, 0.375, 5.38), Size = Vector3.new(1.05, 0.45, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.6, 0.11, -6.11), Size = Vector3.new(1.1, 0.38, 0) },
	{ Name = "SideIntake_L", Paint = "Trim", Center = Vector3.new(-2.7319, 0, 1.85), Size = Vector3.new(0, 1.1, 1.1), Zone = "Details" },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.625, 0.375, 5.38), Size = Vector3.new(1.05, 0.45, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.435, 0.8812, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.435, 0.8812, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.4, -1, 5.3), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.16, 5.38), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.2, -0.5758, -4.05), Size = Vector3.new(0.3, 1.6883, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.2, -0.5758, -4.05), Size = Vector3.new(0.3, 1.6883, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.2, -0.42, 3.95), Size = Vector3.new(0.3, 2, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.2, -0.42, 3.95), Size = Vector3.new(0.3, 2, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.69, -0.025, 1.2), Size = Vector3.new(0.12, 1.79, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.69, -0.025, 1.2), Size = Vector3.new(0.12, 1.79, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.69, -0.12, -2.35), Size = Vector3.new(0.12, 1.6, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.69, -0.12, -2.35), Size = Vector3.new(0.12, 1.6, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.29, -0.395, -5.35), Size = Vector3.new(0.12, 1.95, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.29, -0.395, -5.35), Size = Vector3.new(0.12, 1.95, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.29, -0.155, 4.9), Size = Vector3.new(0.12, 2.43, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.29, -0.155, 4.9), Size = Vector3.new(0.12, 2.43, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6808, -3.8975), Size = Vector3.new(4.59, 0.095, 2.895), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.75, -1.01, 0), Size = Vector3.new(0, 0.82, 4.8), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.6546, 0.5888, 0.65), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.75, -1.01, 0), Size = Vector3.new(0, 0.82, 4.8), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.6546, 0.5888, 0.65), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.725, 5.37), Size = Vector3.new(4.7, 0.75, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8431, -4.25), Size = Vector3.new(2, 0.5139, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.6911, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6427, -4.17), Size = Vector3.new(3.5, 0.072, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.65, 4.525), Size = Vector3.new(4.5, 0.14, 1.05), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.675, 4.6), Size = Vector3.new(4.66, 0.49, 1.1), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.25), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.85, -6.35), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
