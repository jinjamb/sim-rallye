--!nocheck
--[[
	Griffe.luau (généré : assets/meshes/source/export_luau.py)
	La Griffe faite dans Blender (assets/meshes/griffe) : chaque pièce du
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
		NoseZ = -6.3, TailZ = 5.5, BottomY = -1.42, BeltY = 0.78, HalfWidth = 2.95,
		HoodFrontZ = -5.45, HoodRearZ = -2.25, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.9, Y = 0.96, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.5, BaseY = 0.72, TopY = 2.3, WindshieldFrontZ = -2.27, RoofFrontZ = -0.4, RoofRearZ = 3.95 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5446, -0.4), Size = Vector3.new(6.48, 1.7507, 11.8), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.875), Size = Vector3.new(6.48, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.39, -5.875), Size = Vector3.new(6.48, 2.06, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.925, -0.36, -3.85), Size = Vector3.new(0.63, 2.12, 3.2), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.67, -3.85), Size = Vector3.new(5.8, 0.14, 3.2), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.925, -0.36, -3.85), Size = Vector3.new(0.63, 2.12, 3.2), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.78, -0.2913, -0.375), Size = Vector3.new(0.34, 2.2573, 3.75), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.85, 1.3), Size = Vector3.new(5.8, 0.3, 7.1), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.78, -0.2913, -0.375), Size = Vector3.new(0.34, 2.2573, 3.75), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.925, -0.23, 3.25), Size = Vector3.new(0.63, 2.38, 3.5), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.925, -0.23, 3.25), Size = Vector3.new(0.63, 2.38, 3.5), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.98, 4.925), Size = Vector3.new(5.8, 0.04, 0.15), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.25), Size = Vector3.new(6.48, 1.4284, 0.5), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.21, 5.25), Size = Vector3.new(6.48, 2.42, 0.5), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.19, 1.7089), Size = Vector3.new(4.24, 0.22, 4.7385), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.4, 1.3), Size = Vector3.new(5, 1.36, 7.14), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.3024, 1.4272, 0.3087), Size = Vector3.new(0.2432, 0.8704, 3.1817) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.3024, 1.4272, 2.9135), Size = Vector3.new(0.2432, 0.8704, 1.4651) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.3024, 1.4272, 0.3087), Size = Vector3.new(0.2432, 0.8704, 3.1817) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.3024, 1.4272, 2.9135), Size = Vector3.new(0.2432, 0.8704, 1.4651) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.4, -1.4652), Size = Vector3.new(4.2346, 1.088, 1.2877) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.4, 4.4741), Size = Vector3.new(4.2346, 1.088, 0.6335) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.075, -6.34), Size = Vector3.new(4.7529, 0.85, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.975, -6.34), Size = Vector3.new(3, 0.45, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.7882, 0.19, -6.37), Size = Vector3.new(0.8765, 0.14, 0) },
	{ Name = "Claw_R", Paint = "Head", Center = Vector3.new(2.0465, -0.85, -6.37), Size = Vector3.new(0.55, 0.6, 0), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.73, 0.32, 5.55), Size = Vector3.new(0.9, 0.4, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.7882, 0.19, -6.37), Size = Vector3.new(0.8765, 0.14, 0) },
	{ Name = "Claw_L", Paint = "Head", Center = Vector3.new(-2.0465, -0.85, -6.37), Size = Vector3.new(0.55, 0.6, 0), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.73, 0.32, 5.55), Size = Vector3.new(0.9, 0.4, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.585, 0.872, -1.6), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.585, 0.872, -1.6), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.92), Size = Vector3.new(5, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.45, -1, 5.45), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 5.53), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.2097, -0.5798, -4.05), Size = Vector3.new(0.1206, 1.6805, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.2097, -0.5798, -4.05), Size = Vector3.new(0.1206, 1.6805, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.1973, -0.4446, 3.95), Size = Vector3.new(0.1455, 1.9507, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.1973, -0.4446, 3.95), Size = Vector3.new(0.1455, 1.9507, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.88, -0.0513, 1.45), Size = Vector3.new(0.2, 1.7373, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.88, -0.0513, 1.45), Size = Vector3.new(0.2, 1.7373, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.88, -0.12, -2.2), Size = Vector3.new(0.2, 1.6, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.88, -0.12, -2.2), Size = Vector3.new(0.2, 1.6, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.17, -0.395, -5.4), Size = Vector3.new(0.2, 1.95, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.17, -0.395, -5.4), Size = Vector3.new(0.2, 1.95, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.17, -0.215, 4.95), Size = Vector3.new(0.2, 2.31, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.17, -0.215, 4.95), Size = Vector3.new(0.2, 2.31, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6957, -3.8475), Size = Vector3.new(4.59, 0.0907, 3.095), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.98, -1.26, 0), Size = Vector3.new(0, 0.32, 4.7), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.8165, 0.5435, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.98, -1.26, 0), Size = Vector3.new(0, 0.32, 4.7), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.8165, 0.5435, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.325, 5.52), Size = Vector3.new(5, 0.55, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.89, -4.25), Size = Vector3.new(2, 0.493, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7485, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6723, -4.17), Size = Vector3.new(3.5, 0.0755, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.65, 4.675), Size = Vector3.new(5, 0.46, 1.45), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.65, 4.7), Size = Vector3.new(5.16, 0.86, 1.4), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.88, -6.5), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.88, -6.6), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
