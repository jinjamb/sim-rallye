--!nocheck
--[[
	Furia.luau (généré : assets/meshes/source/export_luau.py)
	La Furia faite dans Blender (assets/meshes/furia) : chaque pièce du
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
		NoseZ = -6.3, TailZ = 5.65, BottomY = -1.42, BeltY = 0.87, HalfWidth = 2.72, NoseHalfWidth = 2.62,
		HoodFrontZ = -5.6, HoodRearZ = -2.55, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.05, Y = 1.02, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.5, BaseY = 0.8, TopY = 2.48, WindshieldFrontZ = -2.57, RoofFrontZ = -1.4, RoofRearZ = 4.98 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.52, -0.325), Size = Vector3.new(6.64, 1.8, 11.95), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.95), Size = Vector3.new(6.24, 0, 0.7), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.37, -5.95), Size = Vector3.new(6.24, 2.1, 0.7), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.22, -0.31, -4.075), Size = Vector3.new(0.2, 2.22, 3.05), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.74, -4.075), Size = Vector3.new(6.64, 0.12, 3.05), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.22, -0.31, -4.075), Size = Vector3.new(0.2, 2.22, 3.05), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.97, -0.2695, -1.125), Size = Vector3.new(0.5, 2.3009, 2.85), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.91, 1.325), Size = Vector3.new(6.64, 0.22, 7.75), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.97, -0.2695, -1.125), Size = Vector3.new(0.5, 2.3009, 2.85), Zone = "Doors" },
	{ Name = "Door_RR", Paint = "Body", Center = Vector3.new(2.92, -0.2383, 1.4), Size = Vector3.new(0.4, 2.3634, 2.2), Zone = "Doors" },
	{ Name = "Door_RL", Paint = "Body", Center = Vector3.new(-2.92, -0.2383, 1.4), Size = Vector3.new(0.4, 2.3634, 2.2), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.22, -0.2, 3.875), Size = Vector3.new(0.2, 2.44, 2.75), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.22, -0.2, 3.875), Size = Vector3.new(0.2, 2.44, 2.75), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.02, 5.225), Size = Vector3.new(6.64, 0, 0.05), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.8594, 5.45), Size = Vector3.new(6.64, 1.1211, 0.4), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.2, 5.45), Size = Vector3.new(6.64, 2.44, 0.4), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.7195, 1.7898), Size = Vector3.new(4.8, 0.001, 6.3807), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.7595, 1.325), Size = Vector3.new(5, 1.919, 7.79), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.4505, 1.7499, -0.3407), Size = Vector3.new(0.087, 1.6695, 3.5478) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.4505, 1.7499, 2.7399), Size = Vector3.new(0.087, 1.6695, 3.0822) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.4505, 1.7499, -0.3407), Size = Vector3.new(0.087, 1.6695, 3.5478) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.4505, 1.7499, 2.7399), Size = Vector3.new(0.087, 1.6695, 3.0822) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.7595, -1.9853), Size = Vector3.new(4.2828, 1.5352, 0.9355) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.7595, 5.1001), Size = Vector3.new(4.2828, 1.5352, 0.1919) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.03, -6.34), Size = Vector3.new(4.9, 0.74, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.6, -0.03, -6.36), Size = Vector3.new(1.26, 0.54, 0) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.55, -0.9, -6.36), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.95, 0.4, 5.68), Size = Vector3.new(1, 0.52, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.6, -0.03, -6.36), Size = Vector3.new(1.26, 0.54, 0) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.55, -0.9, -6.36), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.95, 0.4, 5.68), Size = Vector3.new(1, 0.52, 0) },
	{ Name = "GrilleBar", Paint = "Body", Center = Vector3.new(0, -0.015, -6.36), Size = Vector3.new(1.1, 0.55, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.9, -6.34), Size = Vector3.new(2.2, 0.5, 0), Zone = "Bumpers" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.555, 0.967, -1.9), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.555, 0.967, -1.9), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.45, -1, 5.6), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.39, 5.68), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofSpoilerBlade", Paint = "Body", Center = Vector3.new(0, 2.81, 4.8), Size = Vector3.new(4.6, 0.14, 0.7), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.35, -0.5272, -4.05), Size = Vector3.new(0, 1.7856, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.35, -0.5272, -4.05), Size = Vector3.new(0, 1.7856, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.35, -0.42, 3.965), Size = Vector3.new(0, 2, 3.03), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.35, -0.42, 3.965), Size = Vector3.new(0, 2, 3.03), Zone = "Skirts" },
	{ Name = "Ink_DoorF_R", Paint = "Trim", Center = Vector3.new(2.75, -0.0296, 0.3), Size = Vector3.new(0, 1.7809, 0.09), Detail = true },
	{ Name = "Ink_DoorF_L", Paint = "Trim", Center = Vector3.new(-2.75, -0.0296, 0.3), Size = Vector3.new(0, 1.7809, 0.09), Detail = true },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(3.05, 0.0017, 2.45), Size = Vector3.new(0, 1.8434, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-3.05, 0.0017, 2.45), Size = Vector3.new(0, 1.8434, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(3.15, -0.07, -2.5), Size = Vector3.new(0, 1.7, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-3.15, -0.07, -2.5), Size = Vector3.new(0, 1.7, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.25, -0.355, -5.55), Size = Vector3.new(0, 2.03, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.25, -0.355, -5.55), Size = Vector3.new(0, 2.03, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.35, -0.185, 5.2), Size = Vector3.new(0, 2.37, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.35, -0.185, 5.2), Size = Vector3.new(0, 2.37, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.771, -4.0725), Size = Vector3.new(4.59, 0.1141, 2.945), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.75, -1.27, 0), Size = Vector3.new(0, 0.3, 4.6), Zone = "Skirts" },
	{ Name = "Handle_FR", Paint = "Trim", Center = Vector3.new(2.75, 0.5754, -0.95), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.75, 0.6436, 1.45), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.75, -1.27, 0), Size = Vector3.new(0, 0.3, 4.6), Zone = "Skirts" },
	{ Name = "Handle_FL", Paint = "Trim", Center = Vector3.new(-2.75, 0.5754, -0.95), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.75, 0.6436, 1.45), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.125, 5.67), Size = Vector3.new(5, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.9531, -4.25), Size = Vector3.new(2, 0.4984, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.8089, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.7373, -4.17), Size = Vector3.new(3.5, 0.0796, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 3.02, 5.025), Size = Vector3.new(4.8, 0.14, 1.15), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 3.03, 5.1), Size = Vector3.new(4.96, 0.52, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.5), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.85, -6.6), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.85, -0.5), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.845, -1.16), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.955, 3.36), Size = Vector3.new(0.1, 0.49, 3.14), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.5), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.5), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.82, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.5), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-2.97, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.5), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 5.665), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.49), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	},
}
