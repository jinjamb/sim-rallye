--!nocheck
--[[
	Tsubasa.luau (généré : assets/meshes/source/export_luau.py)
	La Tsubasa faite dans Blender (assets/meshes/tsubasa) : chaque pièce du
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
		NoseZ = -6.35, TailZ = 5.55, BottomY = -1.42, BeltY = 0.67, HalfWidth = 2.72,
		HoodFrontZ = -5.5, HoodRearZ = -2.3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.95, Y = 0.92, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.56, TopY = 2.36, WindshieldFrontZ = -2.32, RoofFrontZ = -0.55, RoofRearZ = 4.35 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5734, -0.4), Size = Vector3.new(6.84, 1.6931, 11.9), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.925), Size = Vector3.new(6.84, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.5, -5.925), Size = Vector3.new(6.84, 1.84, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.07, -0.43, -3.9), Size = Vector3.new(0.7, 1.98, 3.2), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.49, -3.9), Size = Vector3.new(6.84, 0.14, 3.2), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.07, -0.43, -3.9), Size = Vector3.new(0.7, 1.98, 3.2), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.72, -0.3338, -0.35), Size = Vector3.new(0, 2.1723, 3.9), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.74, 1.35), Size = Vector3.new(6.84, 0.36, 7.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.72, -0.3338, -0.35), Size = Vector3.new(0, 2.1723, 3.9), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.07, -0.25, 3.3), Size = Vector3.new(0.7, 2.34, 3.4), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.07, -0.25, 3.3), Size = Vector3.new(0.7, 2.34, 3.4), Zone = "Fenders" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.275), Size = Vector3.new(6.84, 1.4284, 0.55), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.25, 5.275), Size = Vector3.new(6.84, 2.34, 0.55), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.3595, 1.8997), Size = Vector3.new(4, 0.001, 4.9013), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.4595, 1.35), Size = Vector3.new(4.8, 1.799, 7.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.196, 1.4775, 0.2404), Size = Vector3.new(0.28, 1.2593, 3.1647) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.196, 1.4775, 2.6889), Size = Vector3.new(0.28, 1.2593, 1.668) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.196, 1.4775, 0.2404), Size = Vector3.new(0.28, 1.2593, 3.1647) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.196, 1.4775, 2.6889), Size = Vector3.new(0.28, 1.2593, 1.668) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.4595, -1.4355), Size = Vector3.new(4.0592, 1.4392, 1.4152) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.4595, 4.6852), Size = Vector3.new(4.0592, 1.4392, 0.5357) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.6, -6.39), Size = Vector3.new(3.9, 1.2, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.775, -0.13, -6.41), Size = Vector3.new(0.95, 0.34, 0) },
	{ Name = "Canard_R", Paint = "Trim", Center = Vector3.new(2.3, -0.72, -6.075), Size = Vector3.new(0.5, 0.16, 0.65), Zone = "Details", Detail = true },
	{ Name = "FlareVent_R", Paint = "Trim", Center = Vector3.new(3.45, -0.3, -2.92), Size = Vector3.new(0, 0.9, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.625, 0.46, 5.58), Size = Vector3.new(1.05, 0.32, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.775, -0.13, -6.41), Size = Vector3.new(0.95, 0.34, 0) },
	{ Name = "Canard_L", Paint = "Trim", Center = Vector3.new(-2.3, -0.72, -6.075), Size = Vector3.new(0.5, 0.16, 0.65), Zone = "Details", Detail = true },
	{ Name = "FlareVent_L", Paint = "Trim", Center = Vector3.new(-3.45, -0.3, -2.92), Size = Vector3.new(0, 0.9, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.625, 0.46, 5.58), Size = Vector3.new(1.05, 0.32, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.495, 0.7396, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.495, 0.7396, -1.65), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.97), Size = Vector3.new(5.2, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.5, -1, 5.5), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.09, 5.58), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofWingBlade", Paint = "Body", Center = Vector3.new(0, 2.65, 4.8), Size = Vector3.new(5.1, 0.46, 1.3), Zone = "Wing" },
	{ Name = "RoofWing", Paint = "Trim", Center = Vector3.new(0, 2.7, 4.825), Size = Vector3.new(5.26, 0.76, 1.25), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.45, -0.653, -4.05), Size = Vector3.new(0, 1.5341, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.45, -0.653, -4.05), Size = Vector3.new(0, 1.5341, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.45, -0.4734, 4.05), Size = Vector3.new(0, 1.8931, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.45, -0.4734, 4.05), Size = Vector3.new(0, 1.8931, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.75, -0.0938, 1.55), Size = Vector3.new(0, 1.6523, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.75, -0.0938, 1.55), Size = Vector3.new(0, 1.6523, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.75, -0.19, -2.25), Size = Vector3.new(0, 1.46, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.75, -0.19, -2.25), Size = Vector3.new(0, 1.46, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.45, -0.485, -5.45), Size = Vector3.new(0, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.45, -0.485, -5.45), Size = Vector3.new(0, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.45, -0.235, 4.95), Size = Vector3.new(0, 2.27, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.45, -0.235, 4.95), Size = Vector3.new(0, 2.27, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5211, -3.8975), Size = Vector3.new(4.59, 0.1334, 3.095), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.75, -1.195, 0), Size = Vector3.new(0, 0.45, 5), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.75, 0.4478, 0.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.75, -1.195, 0), Size = Vector3.new(0, 0.45, 5), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.75, 0.4478, 0.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.25, 5.57), Size = Vector3.new(4, 0.4, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.6947, -4.25), Size = Vector3.new(2, 0.5094, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.545, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.4788, -4.17), Size = Vector3.new(3.5, 0.0851, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.62, -6.55), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.62, -6.65), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
