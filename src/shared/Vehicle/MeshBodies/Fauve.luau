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
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -6.15, TailZ = 5.45, BottomY = -1.42, BeltY = 0.77, HalfWidth = 2.74,
		HoodFrontZ = -5.45, HoodRearZ = -2.35, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.85, Y = 1, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.66, TopY = 2.38, WindshieldFrontZ = -2.37, RoofFrontZ = -0.55, RoofRearZ = 4.25 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.531, -0.35), Size = Vector3.new(6.76, 1.7781, 11.6), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.8), Size = Vector3.new(6.76, 0, 0.7), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.43, -5.8), Size = Vector3.new(6.76, 1.98, 0.7), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3, -0.38, -3.9), Size = Vector3.new(0.76, 2.08, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.61, -3.9), Size = Vector3.new(6.52, 0.1, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3, -0.38, -3.9), Size = Vector3.new(0.76, 2.08, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.68, -0.295, -0.525), Size = Vector3.new(0.12, 2.25, 3.65), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.83, 1.3), Size = Vector3.new(6.52, 0.34, 7.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.68, -0.295, -0.525), Size = Vector3.new(0.12, 2.25, 3.65), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3, -0.21, 3.15), Size = Vector3.new(0.76, 2.42, 3.7), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3, -0.21, 3.15), Size = Vector3.new(0.76, 2.42, 3.7), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1, 4.975), Size = Vector3.new(6.52, 0, 0.05), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.225), Size = Vector3.new(6.76, 1.4284, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.21, 5.225), Size = Vector3.new(6.76, 2.42, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.305, 1.802), Size = Vector3.new(4.1, 0.15, 5.0215), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.445, 1.3), Size = Vector3.new(4.8, 1.57, 7.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2215, 1.4607, 0.2157), Size = Vector3.new(0.245, 1.099, 3.246) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2215, 1.4607, 2.9135), Size = Vector3.new(0.245, 1.099, 1.6726) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2215, 1.4607, 0.2157), Size = Vector3.new(0.245, 1.099, 3.246) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2215, 1.4607, 2.9135), Size = Vector3.new(0.245, 1.099, 1.6726) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.445, -1.5394), Size = Vector3.new(4.0678, 1.256, 1.329) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.445, 4.6414), Size = Vector3.new(4.0678, 1.256, 0.5258) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, 0.12, -6.19), Size = Vector3.new(1.9, 0.28, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.875, -6.19), Size = Vector3.new(4.5, 0.65, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.6, 0.12, -6.21), Size = Vector3.new(1.1, 0.36, 0) },
	{ Name = "SideIntake_R", Paint = "Trim", Center = Vector3.new(2.77, 0.135, 1.89), Size = Vector3.new(0, 0.77, 1.02), Zone = "Details" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.65, 0.39, 5.48), Size = Vector3.new(1, 0.38, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.6, 0.12, -6.21), Size = Vector3.new(1.1, 0.36, 0) },
	{ Name = "SideIntake_L", Paint = "Trim", Center = Vector3.new(-2.77, 0.135, 1.89), Size = Vector3.new(0, 0.77, 1.02), Zone = "Details" },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.65, 0.39, 5.48), Size = Vector3.new(1, 0.38, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.515, 0.8379, -1.7), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.515, 0.8379, -1.7), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.77), Size = Vector3.new(4.8, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.45, -1, 5.4), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.51, 5.48), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.41, -0.5961, -4.05), Size = Vector3.new(0, 1.6477, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.41, -0.5961, -4.05), Size = Vector3.new(0, 1.6477, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.41, -0.431, 4.05), Size = Vector3.new(0, 1.9781, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.41, -0.431, 4.05), Size = Vector3.new(0, 1.9781, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.77, -0.055, 1.25), Size = Vector3.new(0, 1.73, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.77, -0.055, 1.25), Size = Vector3.new(0, 1.73, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.77, -0.14, -2.3), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.77, -0.14, -2.3), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.41, -0.415, -5.4), Size = Vector3.new(0, 1.91, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.41, -0.415, -5.4), Size = Vector3.new(0, 1.91, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.41, -0.195, 4.95), Size = Vector3.new(0, 2.35, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.41, -0.195, 4.95), Size = Vector3.new(0, 2.35, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6408, -3.8975), Size = Vector3.new(4.59, 0.0952, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.77, -1.195, 0), Size = Vector3.new(0, 0.45, 4.7), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.77, 0.532, 0.7), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.77, -1.195, 0), Size = Vector3.new(0, 0.45, 4.7), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.77, 0.532, 0.7), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.065, 5.47), Size = Vector3.new(4.6, 0.37, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8109, -4.25), Size = Vector3.new(2, 0.4962, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.6679, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6031, -4.17), Size = Vector3.new(3.5, 0.0706, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.49, 4.55), Size = Vector3.new(4.6, 0.14, 1.1), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.515, 4.625), Size = Vector3.new(4.76, 0.49, 1.15), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.35), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.85, -6.45), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
