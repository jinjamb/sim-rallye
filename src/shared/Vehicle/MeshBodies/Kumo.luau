--!nocheck
--[[
	Kumo.luau (généré : assets/meshes/source/export_luau.py)
	La Kumo faite dans Blender (assets/meshes/kumo) : chaque pièce du
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
		NoseZ = -6, TailZ = 5.6, BottomY = -1.42, BeltY = 0.81, HalfWidth = 2.62,
		HoodFrontZ = -5.35, HoodRearZ = -2.6, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5, Y = 1.05, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.68, TopY = 2.4, WindshieldFrontZ = -2.62, RoofFrontZ = -1, RoofRearZ = 3.9 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.52, -0.2), Size = Vector3.new(7.2, 1.8, 11.6), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -0.9602, -5.675), Size = Vector3.new(5.9, 0.9196, 0.65), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.435, -5.675), Size = Vector3.new(5.9, 1.97, 0.65), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.95, -0.37, -3.975), Size = Vector3.new(0, 2.1, 2.75), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.615, -3.975), Size = Vector3.new(5.9, 0.13, 2.75), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.95, -0.37, -3.975), Size = Vector3.new(0, 2.1, 2.75), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.785, -0.2824, -0.8), Size = Vector3.new(0.33, 2.2753, 3.6), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.865, 1.2), Size = Vector3.new(7.2, 0.37, 7.6), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.785, -0.2824, -0.8), Size = Vector3.new(0.33, 2.2753, 3.6), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.11, -0.185, 3.075), Size = Vector3.new(0.98, 2.47, 4.15), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.11, -0.185, 3.075), Size = Vector3.new(0.98, 2.47, 4.15), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.05, 5.075), Size = Vector3.new(7.2, 0, 0.15), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.787, 5.375), Size = Vector3.new(7.2, 1.266, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.185, 5.375), Size = Vector3.new(7.2, 2.47, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.3995, 1.4499), Size = Vector3.new(4.2, 0.001, 4.9016), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.5395, 1.2), Size = Vector3.new(4.8, 1.719, 7.64), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.247, 1.5567, 0.0192), Size = Vector3.new(0.21, 1.2033, 3.3199) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.247, 1.5567, 2.7248), Size = Vector3.new(0.21, 1.2033, 1.3515) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.247, 1.5567, 0.0192), Size = Vector3.new(0.21, 1.2033, 3.3199) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.247, 1.5567, 2.7248), Size = Vector3.new(0.21, 1.2033, 1.3515) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.5395, -1.8105), Size = Vector3.new(4.0764, 1.3752, 1.2952) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.5395, 4.4603), Size = Vector3.new(4.0764, 1.3752, 0.8955) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, 0.05, -6.04), Size = Vector3.new(1.6, 0.3, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.875, -6.04), Size = Vector3.new(4.737, 0.55, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.6492, 0.05, -6.06), Size = Vector3.new(1.3985, 0.4, 0) },
	{ Name = "SideIntake_R", Paint = "Trim", Center = Vector3.new(3.095, -0.25, 2.12), Size = Vector3.new(0.91, 1.7, 0.56), Zone = "Details" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.8, 0.21, 5.65), Size = Vector3.new(1, 0.42, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.6492, 0.05, -6.06), Size = Vector3.new(1.3985, 0.4, 0) },
	{ Name = "SideIntake_L", Paint = "Trim", Center = Vector3.new(-3.095, -0.25, 2.12), Size = Vector3.new(0.91, 1.7, 0.56), Zone = "Details" },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.8, 0.21, 5.65), Size = Vector3.new(1, 0.42, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.521, 0.8592, -1.95), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.521, 0.8592, -1.95), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.5, -1, 5.55), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.56, 5.63), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(2.98, -0.5877, -4.025), Size = Vector3.new(0, 1.6645, 3.15), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-2.98, -0.5877, -4.025), Size = Vector3.new(0, 1.6645, 3.15), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.63, -0.42, 3.95), Size = Vector3.new(0, 2, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.63, -0.42, 3.95), Size = Vector3.new(0, 2, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.65, -0.0424, 0.95), Size = Vector3.new(0, 1.7553, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.65, -0.0424, 0.95), Size = Vector3.new(0, 1.7553, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.98, -0.13, -2.55), Size = Vector3.new(0, 1.58, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.98, -0.13, -2.55), Size = Vector3.new(0, 1.58, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.98, -0.42, -5.3), Size = Vector3.new(0, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.98, -0.42, -5.3), Size = Vector3.new(0, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.63, -0.17, 5.1), Size = Vector3.new(0, 2.4, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.63, -0.17, 5.1), Size = Vector3.new(0, 2.4, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6462, -3.9725), Size = Vector3.new(4.59, 0.1229, 2.645), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.65, -1.22, 0), Size = Vector3.new(0, 0.4, 3.66), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.65, 0.556, 0.4), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.65, -1.22, 0), Size = Vector3.new(0, 0.4, 3.66), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.65, 0.556, 0.4), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.175, 5.62), Size = Vector3.new(4.8, 0.65, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7967, -4.25), Size = Vector3.new(2, 0.5688, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.6173, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6061, -4.17), Size = Vector3.new(3.5, 0.0896, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.73, 4.675), Size = Vector3.new(5, 0.14, 1.15), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.73, 4.75), Size = Vector3.new(5.16, 0.54, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.8, -6.2), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.8, -6.3), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
