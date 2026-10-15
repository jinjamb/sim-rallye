--!nocheck
--[[
	Cuneo.luau (généré : assets/meshes/source/export_luau.py)
	La Cuneo faite dans Blender (assets/meshes/cuneo) : chaque pièce du
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
		NoseZ = -6.1, TailZ = 5.5, BottomY = -1.42, BeltY = 0.73, HalfWidth = 2.78,
		HoodFrontZ = -5.3, HoodRearZ = -2.2, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.9, Y = 0.96, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.45, BaseY = 0.62, TopY = 2.06, WindshieldFrontZ = -2.22, RoofFrontZ = -0.1, RoofRearZ = 1.35 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5471, -0.3), Size = Vector3.new(6.72, 1.7458, 11.6), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -0.9048, -5.7), Size = Vector3.new(6.6654, 1.0305, 0.8), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.5, -5.7), Size = Vector3.new(6.6654, 1.84, 0.8), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.9525, -0.4, -3.75), Size = Vector3.new(0.815, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.52, -3.75), Size = Vector3.new(5.96, 0.48, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.9525, -0.4, -3.75), Size = Vector3.new(0.815, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.6625, -0.3168, -0.5), Size = Vector3.new(0.525, 2.2063, 3.4), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.86, 1.275), Size = Vector3.new(5.96, 0.48, 6.95), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.6625, -0.3168, -0.5), Size = Vector3.new(0.525, 2.2063, 3.4), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.88, -0.23, 3.125), Size = Vector3.new(0.96, 2.38, 3.85), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.88, -0.23, 3.125), Size = Vector3.new(0.96, 2.38, 3.85), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.025, 4.9), Size = Vector3.new(5.96, 0.15, 0.3), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7301, 5.275), Size = Vector3.new(6.72, 1.3798, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.165, 5.275), Size = Vector3.new(6.72, 2.51, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 1.875, 0.8146), Size = Vector3.new(4, 0.47, 3.0658), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.13, -0.6123), Size = Vector3.new(4.9, 1.02, 3.2154), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2205, 1.1402, -0.4846), Size = Vector3.new(0.315, 0.714, 2.0995) },
	{ Name = "RearQuarter", Paint = "Body", Center = Vector3.new(0, 1.13, 2.731), Size = Vector3.new(4.9, 1.02, 4.078), Zone = "Fenders" },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2205, 1.1402, -0.4846), Size = Vector3.new(0.315, 0.714, 2.0995) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.13, -1.4692), Size = Vector3.new(4.1366, 0.816, 1.2013) },
	{ Name = "EngineCover", Paint = "Body", Center = Vector3.new(0, 1.13, 3.5587), Size = Vector3.new(4.9, 1.02, 2.4225), Zone = "Rear" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.675, -6.14), Size = Vector3.new(2.7, 0.55, 0), Zone = "Bumpers" },
	{ Name = "PopUp_R", Paint = "Trim", Center = Vector3.new(1.4, 0.5237, -4.675), Size = Vector3.new(0.9, 0.24, 0.65), Zone = "Details" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.4, 0.5287, -5.02), Size = Vector3.new(0.74, 0.17, 0) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.625, 0.42, 5.535), Size = Vector3.new(0.9304, 0.4, 0.03) },
	{ Name = "PopUp_L", Paint = "Trim", Center = Vector3.new(-1.4, 0.5237, -4.675), Size = Vector3.new(0.9, 0.24, 0.65), Zone = "Details" },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.4, 0.5287, -5.02), Size = Vector3.new(0.74, 0.17, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.625, 0.42, 5.535), Size = Vector3.new(0.9304, 0.4, 0.03) },
	{ Name = "Louver", Paint = "Trim", Center = Vector3.new(0, 1.2656, 3.3079), Size = Vector3.new(3, 0.7848, 1.8639), Zone = "Details", Detail = true },
	{ Name = "RoofSpoiler", Paint = "Body", Center = Vector3.new(0, 2.15, 1.375), Size = Vector3.new(4.1, 0.14, 0.75), Zone = "Wing" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.555, 0.7994, -1.55), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.555, 0.7994, -1.55), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.3, -1, 5.45), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.31, 5.53), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.39, -0.6563, -4.05), Size = Vector3.new(0, 1.5273, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.39, -0.6563, -4.05), Size = Vector3.new(0, 1.5273, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.39, -0.4471, 4.05), Size = Vector3.new(0, 1.9458, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.39, -0.4471, 4.05), Size = Vector3.new(0, 1.9458, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.81, -0.0768, 1.15), Size = Vector3.new(0, 1.6863, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.0768, 1.15), Size = Vector3.new(0, 1.6863, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.9067, -0.16, -2.15), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.9067, -0.16, -2.15), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.3726, -0.555, -5.25), Size = Vector3.new(0, 1.63, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.3726, -0.555, -5.25), Size = Vector3.new(0, 1.63, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.39, -0.22, 5), Size = Vector3.new(0, 2.3, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.39, -0.22, 5), Size = Vector3.new(0, 2.3, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5282, -3.7475), Size = Vector3.new(4.59, 0.2977, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.1), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.81, 0.4845, 0.55), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.1), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.81, 0.4845, 0.55), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.42, 5.52), Size = Vector3.new(4.4, 0.48, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7211, -4.25), Size = Vector3.new(2, 0.7423, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.455, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.5067, -4.17), Size = Vector3.new(3.5, 0.187, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.195, 5.175), Size = Vector3.new(3, 0.55, 0.45), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 1.555, 5.225), Size = Vector3.new(5.4, 0.17, 0.95), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.62, -6.3), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.62, -6.4), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
