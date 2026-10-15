--!nocheck
--[[
	Yama.luau (généré : assets/meshes/source/export_luau.py)
	La Yama faite dans Blender (assets/meshes/yama) : chaque pièce du
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
		NoseZ = -6.7, TailZ = 6.5, BottomY = -1.42, BeltY = 0.72, HalfWidth = 2.8, NoseHalfWidth = 2.65,
		HoodFrontZ = -5.9, HoodRearZ = -2.2, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = 0.74, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.55, BaseY = 0.7, TopY = 2.26, WindshieldFrontZ = -2.22, RoofFrontZ = -0.8, RoofRearZ = 2.15 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.64, -0.1), Size = Vector3.new(6.3, 1.56, 13.2), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.3), Size = Vector3.new(5.6, 0, 0.8), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.4, -6.3), Size = Vector3.new(5.6, 2.04, 0.8), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.975, -0.36, -4.05), Size = Vector3.new(0.35, 2.12, 3.7), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.66, -4.05), Size = Vector3.new(6.3, 0.08, 3.7), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.975, -0.36, -4.05), Size = Vector3.new(0.35, 2.12, 3.7), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.8, -0.3502, -0.9), Size = Vector3.new(0, 2.1396, 2.6), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.72, 0.45), Size = Vector3.new(6.3, 0.04, 5.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.8, -0.3502, -0.9), Size = Vector3.new(0, 2.1396, 2.6), Zone = "Doors" },
	{ Name = "Door_RR", Paint = "Body", Center = Vector3.new(2.8, -0.3426, 1.4), Size = Vector3.new(0, 2.1547, 2), Zone = "Doors" },
	{ Name = "Door_RL", Paint = "Body", Center = Vector3.new(-2.8, -0.3426, 1.4), Size = Vector3.new(0, 2.1547, 2), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.975, -0.34, 4.15), Size = Vector3.new(0.35, 2.16, 3.5), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.975, -0.34, 4.15), Size = Vector3.new(0.35, 2.16, 3.5), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.74, 4.5), Size = Vector3.new(6.3, 0, 2.8), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 6.2), Size = Vector3.new(5.6, 0, 0.6), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.34, 6.2), Size = Vector3.new(5.6, 2.16, 0.6), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.4995, 0.6749), Size = Vector3.new(4.7, 0.001, 2.9513), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Body", Center = Vector3.new(0, 1.5995, 0.45), Size = Vector3.new(5.1, 1.799, 5.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.45, 1.5995, -0.6432), Size = Vector3.new(0.168, 1.5112, 2.4116) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.45, 1.5995, 1.5235), Size = Vector3.new(0.168, 1.5112, 2.0081) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.45, 1.5995, -0.6432), Size = Vector3.new(0.168, 1.5112, 2.4116) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.45, 1.5995, 1.5235), Size = Vector3.new(0.168, 1.5112, 2.0081) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.5995, -1.5104), Size = Vector3.new(4.3516, 1.4392, 1.1354) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.5995, 2.6353), Size = Vector3.new(4.3516, 1.4392, 0.7756) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.025, -6.74), Size = Vector3.new(4.9, 0.85, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.85, -0.03, -6.74), Size = Vector3.new(0.6848, 0.72, 0.06) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(2, 0.225, 6.53), Size = Vector3.new(1, 0.45, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.85, -0.03, -6.74), Size = Vector3.new(0.6848, 0.72, 0.06) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-2, 0.225, 6.53), Size = Vector3.new(1, 0.45, 0) },
	{ Name = "GrilleBar", Paint = "Chrome", Center = Vector3.new(0, -0.01, -6.77), Size = Vector3.new(2.4, 0.5, 0) },
	{ Name = "Bumper", Paint = "Chrome", Center = Vector3.new(0, -0.71, -0.1), Size = Vector3.new(5.5, 0.22, 13.7) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.635, 0.8545, -1.55), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.635, 0.8545, -1.55), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.5, -1, 6.45), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 6.53), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.18, -0.5724, -4.05), Size = Vector3.new(0, 1.6951, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.18, -0.5724, -4.05), Size = Vector3.new(0, 1.6951, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.18, -0.54, 4.05), Size = Vector3.new(0, 1.76, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.18, -0.54, 4.05), Size = Vector3.new(0, 1.76, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorF_R", Paint = "Trim", Center = Vector3.new(2.83, -0.1102, 0.4), Size = Vector3.new(0, 1.6196, 0.09), Detail = true },
	{ Name = "Ink_DoorF_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.1102, 0.4), Size = Vector3.new(0, 1.6196, 0.09), Detail = true },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.83, -0.1026, 2.35), Size = Vector3.new(0, 1.6347, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.1026, 2.35), Size = Vector3.new(0, 1.6347, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.83, -0.12, -2.15), Size = Vector3.new(0, 1.6, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.12, -2.15), Size = Vector3.new(0, 1.6, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.83, -0.385, -5.85), Size = Vector3.new(0, 1.97, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.385, -5.85), Size = Vector3.new(0, 1.97, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(2.83, -0.325, 5.85), Size = Vector3.new(0, 2.09, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.325, 5.85), Size = Vector3.new(0, 2.09, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6905, -4.0475), Size = Vector3.new(4.59, 0.0768, 3.595), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.77, 4.5225), Size = Vector3.new(4.59, 0, 2.645), Detail = true },
	{ Name = "Handle_FR", Paint = "Trim", Center = Vector3.new(2.83, 0.4428, -0.5), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.83, 0.4602, 1.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_FL", Paint = "Trim", Center = Vector3.new(-2.83, 0.4428, -0.5), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.83, 0.4602, 1.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.175, 6.52), Size = Vector3.new(2.4, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8757, -4.25), Size = Vector3.new(2, 0.4541, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7536, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6602, -4.17), Size = Vector3.new(3.5, 0.0572, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 0.85, 6.025), Size = Vector3.new(5.2, 0.22, 0.85), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 0.89, 6.025), Size = Vector3.new(5.4, 0.4, 0.95), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.55, -6.9), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.55, -7), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.63, 0.1), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.625, -0.56), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.735, 1.3875), Size = Vector3.new(0.1, 0.49, 1.425), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.9, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(3.05, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.9, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-3.05, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 6.515), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 6.34), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	{ Name = "AccAntenna", Paint = "Trim", Center = Vector3.new(0.8, 3.2315, 1.7525), Size = Vector3.new(0.2, 1.483, 0.545), Zone = "Details", Slot = "Roof", Options = { 4 }, Detail = true },
	{ Name = "AccMudflaps", Paint = "Trim", Center = Vector3.new(0, -1.475, 1.3), Size = Vector3.new(6.12, 0.95, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.04, 0.16, 8.19), Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsLong", Paint = "Trim", Center = Vector3.new(0, -1.325, 1.3), Size = Vector3.new(6.32, 1.25, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 3 }, Detail = true },
	{ Name = "AccMudflapsLongBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.24, 0.16, 8.19), Slot = "Mudflaps", Options = { 3 }, Detail = true },
	},
}
