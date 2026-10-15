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
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -6.3, TailZ = 5.7, BottomY = -1.42, BeltY = 0.8, HalfWidth = 2.8,
		HoodFrontZ = -5.6, HoodRearZ = -2.5, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.1, Y = 0.98, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.48, BaseY = 0.72, TopY = 2.46, WindshieldFrontZ = -2.52, RoofFrontZ = -1.05, RoofRearZ = 4.75 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5387, -0.3), Size = Vector3.new(6.6, 1.7626, 12), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.95), Size = Vector3.new(6.4, 0, 0.7), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.4, -5.95), Size = Vector3.new(6.4, 2.04, 0.7), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.25, -0.35, -4.05), Size = Vector3.new(0.1, 2.14, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.67, -4.05), Size = Vector3.new(6.6, 0.1, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.25, -0.35, -4.05), Size = Vector3.new(0.1, 2.14, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(3, -0.3024, -1.1), Size = Vector3.new(0.4, 2.2352, 2.8), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.85, 1.325), Size = Vector3.new(6.6, 0.26, 7.65), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-3, -0.3024, -1.1), Size = Vector3.new(0.4, 2.2352, 2.8), Zone = "Doors" },
	{ Name = "Door_RR", Paint = "Body", Center = Vector3.new(3, -0.265, 1.4), Size = Vector3.new(0.4, 2.3099, 2.2), Zone = "Doors" },
	{ Name = "Door_RL", Paint = "Body", Center = Vector3.new(-3, -0.265, 1.4), Size = Vector3.new(0.4, 2.3099, 2.2), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.25, -0.22, 3.875), Size = Vector3.new(0.1, 2.4, 2.75), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.25, -0.22, 3.875), Size = Vector3.new(0.1, 2.4, 2.75), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.98, 5.2), Size = Vector3.new(6.6, 0, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.8594, 5.475), Size = Vector3.new(6.6, 1.1211, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.22, 5.475), Size = Vector3.new(6.6, 2.4, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.4595, 1.8497), Size = Vector3.new(4.36, 0.001, 5.8011), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.5895, 1.325), Size = Vector3.new(4.96, 1.739, 7.69), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.327, 1.6069, -0.0973), Size = Vector3.new(0.21, 1.2173, 2.8978) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.327, 1.6069, 2.591), Size = Vector3.new(0.21, 1.2173, 2.5118) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.327, 1.6069, -0.0973), Size = Vector3.new(0.21, 1.2173, 2.8978) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.327, 1.6069, 2.591), Size = Vector3.new(0.21, 1.2173, 2.5118) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.5895, -1.7854), Size = Vector3.new(4.214, 1.3912, 1.1753) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.5895, 4.9601), Size = Vector3.new(4.214, 1.3912, 0.3358) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.04, -6.34), Size = Vector3.new(4.8, 0.68, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.6, -0.04, -6.36), Size = Vector3.new(1.26, 0.52, 0) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.5, -0.85, -6.36), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.85, 0.37, 5.73), Size = Vector3.new(0.9, 0.5, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.6, -0.04, -6.36), Size = Vector3.new(1.26, 0.52, 0) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.5, -0.85, -6.36), Size = Vector3.new(0.3696, 0.3696, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.85, 0.37, 5.73), Size = Vector3.new(0.9, 0.5, 0) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.34), Size = Vector3.new(2.2, 0.5, 0), Zone = "Bumpers" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.575, 0.8904, -1.85), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.575, 0.8904, -1.85), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.92), Size = Vector3.new(5.1, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.45, -1, 5.65), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.39, 5.73), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofSpoilerBlade", Paint = "Body", Center = Vector3.new(0, 2.55, 4.7), Size = Vector3.new(4.2, 0.14, 0.7), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.33, -0.5637, -4.05), Size = Vector3.new(0, 1.7126, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.33, -0.5637, -4.05), Size = Vector3.new(0, 1.7126, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.33, -0.4387, 4.05), Size = Vector3.new(0, 1.9626, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.33, -0.4387, 4.05), Size = Vector3.new(0, 1.9626, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorF_R", Paint = "Trim", Center = Vector3.new(2.83, -0.0624, 0.3), Size = Vector3.new(0, 1.7152, 0.09), Detail = true },
	{ Name = "Ink_DoorF_L", Paint = "Trim", Center = Vector3.new(-2.83, -0.0624, 0.3), Size = Vector3.new(0, 1.7152, 0.09), Detail = true },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(3.13, -0.025, 2.45), Size = Vector3.new(0, 1.7899, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-3.13, -0.025, 2.45), Size = Vector3.new(0, 1.7899, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(3.13, -0.11, -2.45), Size = Vector3.new(0, 1.62, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-3.13, -0.11, -2.45), Size = Vector3.new(0, 1.62, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.33, -0.385, -5.55), Size = Vector3.new(0, 1.97, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.33, -0.385, -5.55), Size = Vector3.new(0, 1.97, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.33, -0.205, 5.2), Size = Vector3.new(0, 2.33, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.33, -0.205, 5.2), Size = Vector3.new(0, 2.33, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.7008, -4.0475), Size = Vector3.new(4.59, 0.0952, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.83, -1.195, 0), Size = Vector3.new(0, 0.45, 4.6), Zone = "Skirts" },
	{ Name = "Handle_FR", Paint = "Trim", Center = Vector3.new(2.83, 0.5027, -0.95), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.83, 0.5842, 1.45), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.83, -1.195, 0), Size = Vector3.new(0, 0.45, 4.6), Zone = "Skirts" },
	{ Name = "Handle_FL", Paint = "Trim", Center = Vector3.new(-2.83, 0.5027, -0.95), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.83, 0.5842, 1.45), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.125, 5.72), Size = Vector3.new(4.9, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8835, -4.25), Size = Vector3.new(2, 0.4806, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7482, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6679, -4.17), Size = Vector3.new(3.5, 0.0706, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.79, 4.975), Size = Vector3.new(4.6, 0.14, 1.15), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.79, 5.05), Size = Vector3.new(4.76, 0.54, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.82, -6.5), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.82, -6.6), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
