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
		NoseZ = -6.25, TailZ = 5.5, BottomY = -1.42, BeltY = 0.76, HalfWidth = 2.76,
		HoodFrontZ = -5.45, HoodRearZ = -2.3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.9, Y = 0.98, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.42, BaseY = 0.66, TopY = 2.34, WindshieldFrontZ = -2.32, RoofFrontZ = -0.5, RoofRearZ = 4.2 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5389, -0.375), Size = Vector3.new(6.64, 1.7622, 11.75), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.85), Size = Vector3.new(6.64, 0, 0.8), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.41, -5.85), Size = Vector3.new(6.64, 2.02, 0.8), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.92, -0.38, -3.875), Size = Vector3.new(0.8, 2.08, 3.15), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.63, -3.875), Size = Vector3.new(6.16, 0.16, 3.15), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.92, -0.38, -3.875), Size = Vector3.new(0.8, 2.08, 3.15), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.64, -0.2956, -0.4), Size = Vector3.new(0.24, 2.2489, 3.8), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.845, 1.3), Size = Vector3.new(6.16, 0.37, 7.2), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.64, -0.2956, -0.4), Size = Vector3.new(0.24, 2.2489, 3.8), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.92, -0.22, 3.25), Size = Vector3.new(0.8, 2.4, 3.5), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.92, -0.22, 3.25), Size = Vector3.new(0.8, 2.4, 3.5), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.005, 4.95), Size = Vector3.new(6.16, 0.05, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.25), Size = Vector3.new(6.64, 1.4284, 0.5), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.195, 5.25), Size = Vector3.new(6.64, 2.45, 0.5), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.19, 1.7518), Size = Vector3.new(4.04, 0.3, 5.1536), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.35, 1.3), Size = Vector3.new(4.84, 1.38, 7.24), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.216, 1.3638, 0.2853), Size = Vector3.new(0.28, 0.966, 3.351) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.216, 1.3638, 2.9607), Size = Vector3.new(0.28, 0.966, 1.5194) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.216, 1.3638, 0.2853), Size = Vector3.new(0.28, 0.966, 3.351) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.216, 1.3638, 2.9607), Size = Vector3.new(0.28, 0.966, 1.5194) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.35, -1.5725), Size = Vector3.new(4.0936, 1.104, 1.196) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.35, 4.6243), Size = Vector3.new(4.0936, 1.104, 0.4731) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.55, -6.29), Size = Vector3.new(3.4, 1.2, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.75, 0.185, -6.31), Size = Vector3.new(1, 0.27, 0) },
	{ Name = "Claw_R", Paint = "Head", Center = Vector3.new(1.97, -0.425, -6.31), Size = Vector3.new(0.52, 0.65, 0), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.67, 0.335, 5.55), Size = Vector3.new(0.82, 0.43, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.75, 0.185, -6.31), Size = Vector3.new(1, 0.27, 0) },
	{ Name = "Claw_L", Paint = "Head", Center = Vector3.new(-1.97, -0.425, -6.31), Size = Vector3.new(0.52, 0.65, 0), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.67, 0.335, 5.55), Size = Vector3.new(0.82, 0.43, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.535, 0.8367, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.535, 0.8367, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.87), Size = Vector3.new(5, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.45, -1, 5.45), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 5.53), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.35, -0.6012, -4.05), Size = Vector3.new(0, 1.6376, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.35, -0.6012, -4.05), Size = Vector3.new(0, 1.6376, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.35, -0.4389, 4.05), Size = Vector3.new(0, 1.9622, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.35, -0.4389, 4.05), Size = Vector3.new(0, 1.9622, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.79, -0.0556, 1.45), Size = Vector3.new(0, 1.7289, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.79, -0.0556, 1.45), Size = Vector3.new(0, 1.7289, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.79, -0.14, -2.25), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.79, -0.14, -2.25), Size = Vector3.new(0, 1.56, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.35, -0.42, -5.4), Size = Vector3.new(0, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.35, -0.42, -5.4), Size = Vector3.new(0, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.35, -0.205, 4.95), Size = Vector3.new(0, 2.33, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.35, -0.205, 4.95), Size = Vector3.new(0, 2.33, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6532, -3.8725), Size = Vector3.new(4.59, 0.0956, 3.045), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.79, -1.195, 0), Size = Vector3.new(0, 0.45, 4.6), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.79, 0.53, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.79, -1.195, 0), Size = Vector3.new(0, 0.45, 4.6), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.79, 0.53, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.335, 5.52), Size = Vector3.new(4.7, 0.57, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8525, -4.25), Size = Vector3.new(2, 0.5062, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7044, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6348, -4.17), Size = Vector3.new(3.5, 0.081, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.73, 4.75), Size = Vector3.new(4.9, 0.46, 1.4), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.73, 4.775), Size = Vector3.new(5.06, 0.86, 1.35), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.85, -6.45), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.85, -6.55), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
