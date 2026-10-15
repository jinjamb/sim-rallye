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
	carrosserie en pièces (numéros, feux, accessoires). Cabin.TopY est,
	comme pour les carrosseries en pièces, le dessous du toit (0.24 sous le
	dessus) : les accessoires de toit se posent dessus.
]]

return {
	Mounts = {
		NoseZ = -6, TailZ = 5.6, BottomY = -1.42, BeltY = 0.94, HalfWidth = 2.72, NoseHalfWidth = 1.55,
		HoodFrontZ = -5.35, HoodRearZ = -3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5, Y = 0.96, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.15, BaseY = 0.92, TopY = 2.2, WindshieldFrontZ = -3.02, RoofFrontZ = -0.45, RoofRearZ = 3.45 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.532, -0.2), Size = Vector3.new(6.4, 1.7759, 11.6), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -0.9602, -5.675), Size = Vector3.new(6.0187, 0.9196, 0.65), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.35, -5.675), Size = Vector3.new(6.0187, 2.14, 0.65), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.6547, 0.2098, -4.175), Size = Vector3.new(1.0907, 1.4204, 2.35), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.82, -4.175), Size = Vector3.new(4.6, 0.68, 2.35), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.6547, 0.2098, -4.175), Size = Vector3.new(1.0907, 1.4204, 2.35), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.51, -0.2389, -0.825), Size = Vector3.new(1.38, 2.3622, 4.35), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 1.06, 0.925), Size = Vector3.new(4.6, 0.28, 7.85), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.51, -0.2389, -0.825), Size = Vector3.new(1.38, 2.3622, 4.35), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.51, -0.23, 3.25), Size = Vector3.new(1.38, 2.38, 3.8), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.51, -0.23, 3.25), Size = Vector3.new(1.38, 2.38, 3.8), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.08, 5), Size = Vector3.new(4.6, 0.24, 0.3), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.787, 5.375), Size = Vector3.new(6.2998, 1.266, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.11, 5.375), Size = Vector3.new(6.2998, 2.62, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.07, 1.25), Size = Vector3.new(3.24, 0.74, 5.6348), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.31, 0.925), Size = Vector3.new(4.3, 0.78, 7.89), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(1.8956, 1.2944, -0.0777), Size = Vector3.new(0.4028, 0.5928, 3.7546) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(1.8956, 1.2944, 3.043), Size = Vector3.new(0.4028, 0.5928, 1.6539) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-1.8956, 1.2944, -0.0777), Size = Vector3.new(0.4028, 0.5928, 3.7546) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-1.8956, 1.2944, 3.043), Size = Vector3.new(0.4028, 0.5928, 1.6539) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.31, -2.2937), Size = Vector3.new(3.6068, 0.624, 1.1621) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.31, 4.4687), Size = Vector3.new(3.6068, 0.624, 0.6421) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.8782, -6.04), Size = Vector3.new(2.9, 0.5163, 0), Zone = "Bumpers" },
	{ Name = "GrilleSlot", Paint = "Trim", Center = Vector3.new(0, -0.07, -6.04), Size = Vector3.new(1.1, 0.1, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(2.359, 0.1019, -5.125), Size = Vector3.new(1.1519, 0.8038, 1.65) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.05, -0.78, -6.06), Size = Vector3.new(0.2402, 0.2402, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(2.6584, 0.64, 5.305), Size = Vector3.new(0.5097, 0.44, 0.51) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-2.359, 0.1019, -5.125), Size = Vector3.new(1.1519, 0.8038, 1.65) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.05, -0.78, -6.06), Size = Vector3.new(0.2402, 0.2402, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-2.6584, 0.64, 5.305), Size = Vector3.new(0.5097, 0.44, 0.51) },
	{ Name = "DoorStrip_R", Paint = "Trim", Center = Vector3.new(2.781, -0.38, 0), Size = Vector3.new(0.267, 0.08, 4.6), Zone = "Details", Detail = true },
	{ Name = "DoorStrip_L", Paint = "Trim", Center = Vector3.new(-2.781, -0.38, 0), Size = Vector3.new(0.267, 0.08, 4.6), Zone = "Details", Detail = true },
	{ Name = "RoofScoop", Paint = "Body", Center = Vector3.new(0, 2.51, -0.05), Size = Vector3.new(1.14, 0.18, 0.6), Zone = "Roof" },
	{ Name = "RoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.505, -0.36), Size = Vector3.new(1.04, 0.13, 0), Zone = "Details", Detail = true },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.519, 1.0731, -2.35), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.519, 1.0731, -2.35), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.1, -1, 5.55), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.16, 5.63), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.0527, -0.4992, -3.95), Size = Vector3.new(0.3546, 1.8415, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.0527, -0.4992, -3.95), Size = Vector3.new(0.3546, 1.8415, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.074, -0.432, 3.95), Size = Vector3.new(0.312, 1.9759, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.074, -0.432, 3.95), Size = Vector3.new(0.312, 1.9759, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.6, 0.0011, 1.3), Size = Vector3.new(0.3, 1.8422, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.6, 0.0011, 1.3), Size = Vector3.new(0.3, 1.8422, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(3.08, -0.01, -2.95), Size = Vector3.new(0.3, 1.82, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-3.08, -0.01, -2.95), Size = Vector3.new(0.3, 1.82, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.9379, -0.455, -5.3), Size = Vector3.new(0.3, 1.83, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.9379, -0.455, -5.3), Size = Vector3.new(0.3, 1.83, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.0457, -0.215, 5.1), Size = Vector3.new(0.3, 2.31, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.0457, -0.215, 5.1), Size = Vector3.new(0.3, 2.31, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.8368, -4.1725), Size = Vector3.new(4.19, 0.4056, 2.245), Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.45, 0.6691, 0.75), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.45, 0.6691, 0.75), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.46, 5.62), Size = Vector3.new(1.8, 0.28, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 1.1185, -4.25), Size = Vector3.new(2, 0.9231, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7619, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.863, -4.17), Size = Vector3.new(3.5, 0.3156, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Body", Center = Vector3.new(0, 2.26, 4.25), Size = Vector3.new(3.1, 0.62, 1), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.65, 4.65), Size = Vector3.new(4.3, 0.16, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.8, -6.2), Size = Vector3.new(2.9802, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.8, -6.3), Size = Vector3.new(2.847, 0.6118, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.67, 0.75), Size = Vector3.new(1.28, 0.5, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.665, 0.09), Size = Vector3.new(1.14, 0.41, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.675, 2.45), Size = Vector3.new(0.1, 0.49, 1.9), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 3.5), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 3.5), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 3.5), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 3.5), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 5.615), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.44), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	{ Name = "AccAntenna", Paint = "Trim", Center = Vector3.new(0.612, 3.0875, 3.0525), Size = Vector3.new(0.2, 1.483, 0.545), Zone = "Details", Slot = "Roof", Options = { 4 }, Detail = true },
	{ Name = "AccMudflaps", Paint = "Trim", Center = Vector3.new(0, -1.475, 1.3), Size = Vector3.new(6.12, 0.95, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.04, 0.16, 8.19), Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsLong", Paint = "Trim", Center = Vector3.new(0, -1.325, 1.3), Size = Vector3.new(6.32, 1.25, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 3 }, Detail = true },
	{ Name = "AccMudflapsLongBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.24, 0.16, 8.19), Slot = "Mudflaps", Options = { 3 }, Detail = true },
	},
}
