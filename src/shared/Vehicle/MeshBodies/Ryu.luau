--!nocheck
--[[
	Ryu.luau (généré : assets/meshes/source/export_luau.py)
	La Ryu faite dans Blender (assets/meshes/ryu) : chaque pièce du
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
		NoseZ = -7.1, TailZ = 6.35, BottomY = -1.42, BeltY = 0.58, HalfWidth = 2.72, NoseHalfWidth = 2.27,
		HoodFrontZ = -6.1, HoodRearZ = -1.3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = 0.72, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.25, BaseY = 0.55, TopY = 1.78, WindshieldFrontZ = -1.32, RoofFrontZ = 0.4, RoofRearZ = 1.9 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.6592, -0.375), Size = Vector3.new(6.4, 1.5216, 13.45), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.6), Size = Vector3.new(5.44, 0, 1), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.49, -6.6), Size = Vector3.new(5.44, 1.86, 1), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.785, -0.435, -3.7), Size = Vector3.new(0.83, 1.97, 4.8), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.495, -3.7), Size = Vector3.new(5.7, 0.23, 4.8), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.785, -0.435, -3.7), Size = Vector3.new(0.83, 1.97, 4.8), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.545, -0.3938, 0.3), Size = Vector3.new(0.35, 2.0524, 3.2), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.665, 2), Size = Vector3.new(5.7, 0.23, 6.6), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.545, -0.3938, 0.3), Size = Vector3.new(0.35, 2.0524, 3.2), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.785, -0.3021, 3.95), Size = Vector3.new(0.83, 2.2358, 4.1), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.785, -0.3021, 3.95), Size = Vector3.new(0.83, 2.2358, 4.1), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.7979, 5.65), Size = Vector3.new(5.7, 0.1558, 0.7), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 6.175), Size = Vector3.new(5.44, 0, 0.35), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.205, 6.175), Size = Vector3.new(5.44, 2.43, 0.35), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 1.92, 1.2656), Size = Vector3.new(3.8, 0.2, 2.1993), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Body", Center = Vector3.new(0, 1.185, 2), Size = Vector3.new(4.5, 1.27, 6.64), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.0715, 1.1977, 1.0524), Size = Vector3.new(0.245, 0.889, 3.0833) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.0715, 1.1977, 2.797), Size = Vector3.new(0.245, 0.889, 1.7287) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.0715, 1.1977, 1.0524), Size = Vector3.new(0.245, 0.889, 3.0833) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.0715, 1.1977, 2.797), Size = Vector3.new(0.245, 0.889, 1.7287) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.185, -0.577), Size = Vector3.new(3.8098, 1.016, 1.1888) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.185, 3.8427), Size = Vector3.new(3.8098, 1.016, 2.3638) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.2, -7.14), Size = Vector3.new(4.1997, 0.5, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.275, -0.2, -7.14), Size = Vector3.new(1.0304, 0.4, 0.06) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.575, 0.41, 6.385), Size = Vector3.new(0.8734, 0.34, 0.03) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.275, -0.2, -7.14), Size = Vector3.new(1.0304, 0.4, 0.06) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.575, 0.41, 6.385), Size = Vector3.new(0.8734, 0.34, 0.03) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.925, -7.14), Size = Vector3.new(2.8, 0.35, 0), Zone = "Bumpers" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.405, 0.7155, -0.65), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.405, 0.7155, -0.65), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.72), Size = Vector3.new(4.4, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.4, -1, 6.3), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 6.38), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.158, -0.6662, -4.05), Size = Vector3.new(0.144, 1.5077, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.158, -0.6662, -4.05), Size = Vector3.new(0.144, 1.5077, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.158, -0.5592, 4.05), Size = Vector3.new(0.144, 1.7216, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.158, -0.5592, 4.05), Size = Vector3.new(0.144, 1.7216, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.675, -0.1538, 1.85), Size = Vector3.new(0.15, 1.5324, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.675, -0.1538, 1.85), Size = Vector3.new(0.15, 1.5324, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.675, -0.195, -1.25), Size = Vector3.new(0.15, 1.45, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.675, -0.195, -1.25), Size = Vector3.new(0.15, 1.45, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.675, -0.505, -6.05), Size = Vector3.new(0.15, 1.73, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.675, -0.505, -6.05), Size = Vector3.new(0.15, 1.73, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(2.723, -0.2871, 5.95), Size = Vector3.new(0.15, 2.1658, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-2.723, -0.2871, 5.95), Size = Vector3.new(0.15, 2.1658, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5114, -3.6975), Size = Vector3.new(4.33, 0.1647, 4.695), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.8208, 5.6725), Size = Vector3.new(4.59, 0.0934, 0.545), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.75, -1.27, 0), Size = Vector3.new(0, 0.3, 4.2), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.6127, 0.347, 1.3), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.75, -1.27, 0), Size = Vector3.new(0, 0.3, 4.2), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.6127, 0.347, 1.3), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.41, 6.37), Size = Vector3.new(4.4, 0.42, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7255, -4.25), Size = Vector3.new(2, 0.4885, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.5863, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.495, -4.17), Size = Vector3.new(3.5, 0.0846, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.0408, 5.925), Size = Vector3.new(3.4, 0.45, 0.45), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 1.3508, 5.95), Size = Vector3.new(5.4, 0.17, 0.9), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.75, -7.3), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.75, -7.4), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.15, 1.175), Size = Vector3.new(1.1, 0.3, 1.05), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.145, 0.64), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.255, 1.5), Size = Vector3.new(0.1, 0.49, 0.7), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.1), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 6.365), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 6.19), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	{ Name = "AccAntenna", Paint = "Trim", Center = Vector3.new(0.8, 2.7515, 1.5025), Size = Vector3.new(0.2, 1.483, 0.545), Zone = "Details", Slot = "Roof", Options = { 4 }, Detail = true },
	{ Name = "AccMudflaps", Paint = "Trim", Center = Vector3.new(0, -1.475, 1.3), Size = Vector3.new(6.12, 0.95, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.04, 0.16, 8.19), Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsLong", Paint = "Trim", Center = Vector3.new(0, -1.325, 1.3), Size = Vector3.new(6.32, 1.25, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 3 }, Detail = true },
	{ Name = "AccMudflapsLongBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.24, 0.16, 8.19), Slot = "Mudflaps", Options = { 3 }, Detail = true },
	},
}
