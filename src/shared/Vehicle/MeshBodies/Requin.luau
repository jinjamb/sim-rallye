--!nocheck
--[[
	Requin.luau (généré : assets/meshes/source/export_luau.py)
	La Requin faite dans Blender (assets/meshes/requin) : chaque pièce du
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
		NoseZ = -6.3, TailZ = 5.6, BottomY = -1.42, BeltY = 0.73, HalfWidth = 2.75,
		HoodFrontZ = -5.45, HoodRearZ = -2.35, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5, Y = 0.96, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.62, TopY = 2.34, WindshieldFrontZ = -2.37, RoofFrontZ = -0.45, RoofRearZ = 4.3 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.551, -0.35), Size = Vector3.new(6.6, 1.7381, 11.9), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.875), Size = Vector3.new(6.5977, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.4, -5.875), Size = Vector3.new(6.5977, 2.04, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.9329, -0.4, -3.9), Size = Vector3.new(0.7343, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.62, -3.9), Size = Vector3.new(5.76, 0.24, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.9329, -0.4, -3.9), Size = Vector3.new(0.7343, 2.04, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.6579, -0.3103, -0.425), Size = Vector3.new(0.6557, 2.2193, 3.85), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.85, 1.3), Size = Vector3.new(5.76, 0.46, 7.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.6579, -0.3103, -0.425), Size = Vector3.new(0.6557, 2.2193, 3.85), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.815, -0.23, 3.275), Size = Vector3.new(0.97, 2.38, 3.55), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.815, -0.23, 3.275), Size = Vector3.new(0.97, 2.38, 3.55), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.02, 5), Size = Vector3.new(5.76, 0.12, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7301, 5.325), Size = Vector3.new(6.6, 1.3798, 0.55), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.17, 5.325), Size = Vector3.new(6.6, 2.5, 0.55), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Trim", Center = Vector3.new(0, 2.13, 1.7506), Size = Vector3.new(4.04, 0.54, 5.4728), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.24, 1.3), Size = Vector3.new(4.8, 1.24, 7.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2062, 1.2524, 0.1215), Size = Vector3.new(0.266, 0.868, 3.1319) },
	{ Name = "SharkFin", Paint = "Body", Center = Vector3.new(0, 1.24, 1.9084), Size = Vector3.new(4.8, 1.24, 1.2168), Zone = "Pillars" },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2062, 1.2524, 3.0972), Size = Vector3.new(0.266, 0.868, 1.4787) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2062, 1.2524, 0.1215), Size = Vector3.new(0.266, 0.868, 3.1319) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2062, 1.2524, 3.0972), Size = Vector3.new(0.266, 0.868, 1.4787) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.24, -1.6779), Size = Vector3.new(4.0626, 0.992, 1.1074) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.24, 4.7285), Size = Vector3.new(4.0626, 0.992, 0.3864) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.35, -6.34), Size = Vector3.new(2.7, 1.1, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.7, 0.115, -6.36), Size = Vector3.new(1.1, 0.33, 0) },
	{ Name = "LedStrip_R", Paint = "Head", Center = Vector3.new(1.62, -0.675, -6.36), Size = Vector3.new(0.16, 0.75, 0), Detail = true },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.675, -6.34), Size = Vector3.new(4.5, 0.75, 0), Zone = "Bumpers" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.715, 0.305, 5.63), Size = Vector3.new(0.93, 0.71, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.7, 0.115, -6.36), Size = Vector3.new(1.1, 0.33, 0) },
	{ Name = "LedStrip_L", Paint = "Head", Center = Vector3.new(-1.62, -0.675, -6.36), Size = Vector3.new(0.16, 0.75, 0), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.715, 0.305, 5.63), Size = Vector3.new(0.93, 0.71, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.525, 0.7979, -1.7), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.525, 0.7979, -1.7), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.92), Size = Vector3.new(4.9, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.5, -1, 5.55), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.14, 5.63), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofSpoiler", Paint = "Trim", Center = Vector3.new(0, 2.43, 4.5), Size = Vector3.new(4, 0.14, 0.8), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.33, -0.617, -4.05), Size = Vector3.new(0, 1.606, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.33, -0.617, -4.05), Size = Vector3.new(0, 1.606, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.33, -0.451, 4.05), Size = Vector3.new(0, 1.9381, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.33, -0.451, 4.05), Size = Vector3.new(0, 1.9381, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.78, -0.0703, 1.45), Size = Vector3.new(0, 1.6993, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.78, -0.0703, 1.45), Size = Vector3.new(0, 1.6993, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.9371, -0.16, -2.3), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.9371, -0.16, -2.3), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.33, -0.445, -5.4), Size = Vector3.new(0, 1.85, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.33, -0.445, -5.4), Size = Vector3.new(0, 1.85, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.33, -0.215, 5), Size = Vector3.new(0, 2.31, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.33, -0.215, 5), Size = Vector3.new(0, 2.31, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.63, -3.8975), Size = Vector3.new(4.59, 0.1, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.78, -1.195, 0), Size = Vector3.new(0, 0.45, 4.4), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.78, 0.499, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.78, -1.195, 0), Size = Vector3.new(0, 0.45, 4.4), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.78, 0.499, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.375, 5.62), Size = Vector3.new(3.2, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.878, -4.25), Size = Vector3.new(2, 0.5137, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7262, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6425, -4.17), Size = Vector3.new(3.5, 0.097, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.69, 4.85), Size = Vector3.new(5, 0.14, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.64, 4.925), Size = Vector3.new(5.16, 0.64, 1.25), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.7, -6.5), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.7, -6.6), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
