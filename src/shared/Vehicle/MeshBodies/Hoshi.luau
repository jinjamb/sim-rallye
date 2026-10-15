--!nocheck
--[[
	Hoshi.luau (généré : assets/meshes/source/export_luau.py)
	La Hoshi faite dans Blender (assets/meshes/hoshi) : chaque pièce du
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
		NoseZ = -6.55, TailZ = 6.35, BottomY = -1.42, BeltY = 0.73, HalfWidth = 2.82, NoseHalfWidth = 2.4,
		HoodFrontZ = -5.7, HoodRearZ = -2.4, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = 0.84, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.45, BaseY = 0.6, TopY = 2.18, WindshieldFrontZ = -2.42, RoofFrontZ = -0.5, RoofRearZ = 1.95 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.59, -0.1), Size = Vector3.new(6.6, 1.66, 12.9), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.125), Size = Vector3.new(6.216, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.46, -6.125), Size = Vector3.new(6.216, 1.92, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.204, -0.38, -4.05), Size = Vector3.new(0.192, 2.08, 3.3), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.58, -4.05), Size = Vector3.new(6.6, 0.16, 3.3), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.204, -0.38, -4.05), Size = Vector3.new(0.192, 2.08, 3.3), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.964, -0.3431, -1.2), Size = Vector3.new(0.288, 2.1538, 2.4), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.75, 0.525), Size = Vector3.new(6.6, 0.18, 5.85), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.964, -0.3431, -1.2), Size = Vector3.new(0.288, 2.1538, 2.4), Zone = "Doors" },
	{ Name = "Door_RR", Paint = "Body", Center = Vector3.new(2.916, -0.3077, 1.15), Size = Vector3.new(0.192, 2.2246, 2.3), Zone = "Doors" },
	{ Name = "Door_RL", Paint = "Body", Center = Vector3.new(-2.916, -0.3077, 1.15), Size = Vector3.new(0.192, 2.2246, 2.3), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.156, -0.29, 4), Size = Vector3.new(0.288, 2.26, 3.4), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.156, -0.29, 4), Size = Vector3.new(0.288, 2.26, 3.4), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.84, 4.575), Size = Vector3.new(6.6, 0, 2.25), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 6.025), Size = Vector3.new(6.216, 0, 0.65), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.29, 6.025), Size = Vector3.new(6.216, 2.26, 0.65), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.4195, 0.7249), Size = Vector3.new(4.04, 0.001, 2.4519), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.5095, 0.525), Size = Vector3.new(4.9, 1.819, 5.89), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2307, 1.5277, -0.5437), Size = Vector3.new(0.301, 1.2733, 2.0706) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2307, 1.5277, 1.4114), Size = Vector3.new(0.301, 1.2733, 1.8156) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2307, 1.5277, -0.5437), Size = Vector3.new(0.301, 1.2733, 2.0706) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2307, 1.5277, 1.4114), Size = Vector3.new(0.301, 1.2733, 1.8156) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.5095, -1.4605), Size = Vector3.new(4.14, 1.4552, 1.5352) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.5095, 2.7104), Size = Vector3.new(4.14, 1.4552, 1.2153) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.06, -6.59), Size = Vector3.new(4.6, 0.72, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.7, -0.06, -6.59), Size = Vector3.new(0.6282, 0.6282, 0.06) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.7, -0.06, -6.59), Size = Vector3.new(0.6282, 0.6282, 0.06) },
	{ Name = "GrilleBar", Paint = "Body", Center = Vector3.new(0, -0.06, -6.63), Size = Vector3.new(1.5, 0.12, 0.08), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.59), Size = Vector3.new(4.7, 0.5, 0), Zone = "Bumpers" },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.97, -0.85, -6.59), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.65, 0.23, 6.385), Size = Vector3.new(0.9511, 0.3511, 0.03) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.57, 0.82, -1.75), Size = Vector3.new(0.5, 0.32, 0.3), Zone = "Mirrors" },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.97, -0.85, -6.59), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.65, 0.23, 6.385), Size = Vector3.new(0.9511, 0.3511, 0.03) },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.57, 0.82, -1.75), Size = Vector3.new(0.5, 0.32, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.45, -0.98, 6.3), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.375, 6.38), Size = Vector3.new(1.6, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.17), Size = Vector3.new(5, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.33, -0.603, -4.05), Size = Vector3.new(0, 1.6339, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.33, -0.603, -4.05), Size = Vector3.new(0, 1.6339, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.33, -0.49, 4.05), Size = Vector3.new(0, 1.86, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.33, -0.49, 4.05), Size = Vector3.new(0, 1.86, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorF_R", Paint = "Trim", Center = Vector3.new(2.85, -0.1031, 0), Size = Vector3.new(0, 1.6339, 0.09), Detail = true },
	{ Name = "Ink_DoorF_L", Paint = "Trim", Center = Vector3.new(-2.85, -0.1031, 0), Size = Vector3.new(0, 1.6339, 0.09), Detail = true },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.994, -0.0677, 2.25), Size = Vector3.new(0, 1.7046, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.994, -0.0677, 2.25), Size = Vector3.new(0, 1.7046, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(3.09, -0.14, -2.35), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-3.09, -0.14, -2.35), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.186, -0.445, -5.65), Size = Vector3.new(0, 1.85, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.186, -0.445, -5.65), Size = Vector3.new(0, 1.85, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.186, -0.275, 5.65), Size = Vector3.new(0, 2.19, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.186, -0.275, 5.65), Size = Vector3.new(0, 2.19, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6112, -4.0475), Size = Vector3.new(4.59, 0.1527, 3.195), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.87, 4.5975), Size = Vector3.new(4.59, 0, 2.095), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.85, -1.195, 0), Size = Vector3.new(0, 0.45, 4.2), Zone = "Skirts" },
	{ Name = "Handle_FR", Paint = "Trim", Center = Vector3.new(2.85, 0.4454, -0.6), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.85, 0.5223, 1.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.85, -1.195, 0), Size = Vector3.new(0, 0.45, 4.2), Zone = "Skirts" },
	{ Name = "Handle_FL", Paint = "Trim", Center = Vector3.new(-2.85, 0.4454, -0.6), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.85, 0.5223, 1.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.23, 6.37), Size = Vector3.new(4.5, 0.5, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7385, -3.95), Size = Vector3.new(2.3, 0.34, 1.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7385, -4.71), Size = Vector3.new(2.3, 0.34, 0), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6388, -3.33), Size = Vector3.new(4, 0.0291, 0.76), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.715, 5.65), Size = Vector3.new(5.64, 1.75, 1.6), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.12, 5.65), Size = Vector3.new(5.4, 0.56, 1.4), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.84, -6.75), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.84, -6.85), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.55, 0.4), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.545, -0.26), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.655, 1.3125), Size = Vector3.new(0.1, 0.49, 1.175), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.92, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(3.07, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.92, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-3.07, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 6.365), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 6.19), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	},
}
