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
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -6.15, TailZ = 5.35, BottomY = -1.42, BeltY = 0.71, HalfWidth = 2.6,
		HoodFrontZ = -5.4, HoodRearZ = -2.4, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.75, Y = 0.9, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.05, BaseY = 0.62, TopY = 2.22, WindshieldFrontZ = -2.42, RoofFrontZ = -0.75, RoofRearZ = 3.75 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5652, -0.4), Size = Vector3.new(6.44, 1.7095, 11.5), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.0346, -5.775), Size = Vector3.new(6.2211, 0.7708, 0.75), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.4, -5.775), Size = Vector3.new(6.2211, 2.04, 0.75), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.6674, -0.4, -3.9), Size = Vector3.new(1.1053, 2.04, 3), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.62, -3.9), Size = Vector3.new(4.74, 0.4, 3), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.6674, -0.4, -3.9), Size = Vector3.new(1.1053, 2.04, 3), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.3574, -0.3256, -0.5), Size = Vector3.new(1.2147, 2.1888, 3.8), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.86, 1.175), Size = Vector3.new(4.74, 0.48, 7.15), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.3574, -0.3256, -0.5), Size = Vector3.new(1.2147, 2.1888, 3.8), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.485, -0.26, 3.15), Size = Vector3.new(1.47, 2.32, 3.5), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.485, -0.26, 3.15), Size = Vector3.new(1.47, 2.32, 3.5), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1, 4.825), Size = Vector3.new(4.7137, 0.2, 0.15), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.204, 5.125), Size = Vector3.new(6.3315, 0.5928, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, 0.2998, 5.125), Size = Vector3.new(6.3315, 1.6004, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 1.98, 1.3781), Size = Vector3.new(3.2, 0.72, 5.5088), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Body", Center = Vector3.new(0, 1.12, 1.175), Size = Vector3.new(4.1, 1, 7.19), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(1.8295, 1.11, 0.2538), Size = Vector3.new(0.315, 0.7, 3.1081) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(1.8295, 1.11, 2.9886), Size = Vector3.new(0.315, 0.7, 1.437) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-1.8295, 1.11, 0.2538), Size = Vector3.new(0.315, 0.7, 3.1081) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-1.8295, 1.11, 2.9886), Size = Vector3.new(0.315, 0.7, 1.437) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.12, -1.8981), Size = Vector3.new(3.4486, 0.8, 0.835) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.12, 4.4512), Size = Vector3.new(3.4486, 0.8, 0.51) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.725, -6.19), Size = Vector3.new(2.5, 0.85, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(0.8832, 0.01, -6.21), Size = Vector3.new(0.8665, 0.5, 0) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1, -0.72, -6.21), Size = Vector3.new(0.2772, 0.2772, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.98, 0.175, 5.38), Size = Vector3.new(0.42, 0.75, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-0.8832, 0.01, -6.21), Size = Vector3.new(0.8665, 0.5, 0) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1, -0.72, -6.21), Size = Vector3.new(0.2772, 0.2772, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.98, 0.175, 5.38), Size = Vector3.new(0.42, 0.75, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.135, 0.7935, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.135, 0.7935, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.1, -1, 5.3), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.14, 5.38), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.1, -0.6276, -3.95), Size = Vector3.new(0.3, 1.5849, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.1, -0.6276, -3.95), Size = Vector3.new(0.3, 1.5849, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(2.8669, -0.4652, 3.95), Size = Vector3.new(0.7662, 1.9095, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-2.8669, -0.4652, 3.95), Size = Vector3.new(0.7662, 1.9095, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.48, -0.0856, 1.35), Size = Vector3.new(0.3, 1.6688, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.48, -0.0856, 1.35), Size = Vector3.new(0.3, 1.6688, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.8082, -0.16, -2.35), Size = Vector3.new(0.3, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.8082, -0.16, -2.35), Size = Vector3.new(0.3, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.0428, -0.485, -5.35), Size = Vector3.new(0.3, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.0428, -0.485, -5.35), Size = Vector3.new(0.3, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.0628, -0.245, 4.85), Size = Vector3.new(0.3, 2.25, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.0628, -0.245, 4.85), Size = Vector3.new(0.3, 2.25, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6348, -3.8975), Size = Vector3.new(4.243, 0.1973, 2.895), Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.33, 0.4753, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.33, 0.4753, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.45, 5.37), Size = Vector3.new(2, 0.3, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.9, -4.25), Size = Vector3.new(2, 0.6, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.705, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6491, -4.17), Size = Vector3.new(3.5, 0.1512, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.41, 4.45), Size = Vector3.new(4.4, 0.14, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.385, 4.525), Size = Vector3.new(4.56, 0.59, 1.25), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.75, -6.35), Size = Vector3.new(2.7713, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.75, -6.45), Size = Vector3.new(2.6475, 0.569, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
