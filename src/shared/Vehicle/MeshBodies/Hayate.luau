--!nocheck
--[[
	Hayate.luau (généré : assets/meshes/source/export_luau.py)
	La Hayate faite dans Blender (assets/meshes/hayate) : chaque pièce du
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
		NoseZ = -6.75, TailZ = 6.55, BottomY = -1.42, BeltY = 0.66, HalfWidth = 2.78, NoseHalfWidth = 2.36,
		HoodFrontZ = -5.85, HoodRearZ = -2.45, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = 0.72, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.45, BaseY = 0.56, TopY = 2.04, WindshieldFrontZ = -2.47, RoofFrontZ = -0.75, RoofRearZ = 2.6 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.65, -0.1), Size = Vector3.new(6.64, 1.54, 13.3), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.3), Size = Vector3.new(5.56, 0, 0.9), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.5, -6.3), Size = Vector3.new(5.56, 1.84, 0.9), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.05, -0.4, -4.15), Size = Vector3.new(0.54, 2.04, 3.4), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.52, -4.15), Size = Vector3.new(6.64, 0.2, 3.4), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.05, -0.4, -4.15), Size = Vector3.new(0.54, 2.04, 3.4), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(3.05, -0.3802, -1.2), Size = Vector3.new(0.54, 2.0797, 2.5), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.67, 0.7), Size = Vector3.new(6.64, 0.1, 6.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-3.05, -0.3802, -1.2), Size = Vector3.new(0.54, 2.0797, 2.5), Zone = "Doors" },
	{ Name = "Door_RR", Paint = "Body", Center = Vector3.new(3.05, -0.3603, 1.3), Size = Vector3.new(0.54, 2.1194, 2.5), Zone = "Doors" },
	{ Name = "Door_RL", Paint = "Body", Center = Vector3.new(-3.05, -0.3603, 1.3), Size = Vector3.new(0.54, 2.1194, 2.5), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.05, -0.35, 4.2), Size = Vector3.new(0.54, 2.14, 3.3), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.05, -0.35, 4.2), Size = Vector3.new(0.54, 2.14, 3.3), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.72, 4.85), Size = Vector3.new(6.64, 0, 2), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 6.2), Size = Vector3.new(5.56, 0, 0.7), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.35, 6.2), Size = Vector3.new(5.56, 2.14, 0.7), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.2795, 0.9249), Size = Vector3.new(4.2, 0.001, 3.3517), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.4195, 0.7), Size = Vector3.new(4.9, 1.719, 6.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2715, 1.4367, -0.4896), Size = Vector3.new(0.245, 1.2033, 2.2382) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2715, 1.4367, 1.6739), Size = Vector3.new(0.245, 1.2033, 1.993) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2715, 1.4367, -0.4896), Size = Vector3.new(0.245, 1.2033, 2.2382) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2715, 1.4367, 1.6739), Size = Vector3.new(0.245, 1.2033, 1.993) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.4195, -1.6105), Size = Vector3.new(4.1538, 1.3752, 1.3752) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.4195, 3.2354), Size = Vector3.new(4.1538, 1.3752, 1.0154) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.2, -6.79), Size = Vector3.new(4.4, 0.4, 0), Zone = "Bumpers" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.9, -6.79), Size = Vector3.new(4.1, 0.6, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.575, -0.2, -6.81), Size = Vector3.new(1.05, 0.32, 0) },
	{ Name = "FogLight_R", Paint = "Lamp", Center = Vector3.new(1.6, -0.9, -6.8), Size = Vector3.new(0.3326, 0.3326, 0.06), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.6, 0.145, 6.58), Size = Vector3.new(1.3, 0.39, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.54, 0.77, -1.8), Size = Vector3.new(0.48, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.575, -0.2, -6.81), Size = Vector3.new(1.05, 0.32, 0) },
	{ Name = "FogLight_L", Paint = "Lamp", Center = Vector3.new(-1.6, -0.9, -6.8), Size = Vector3.new(0.3326, 0.3326, 0.06), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.6, 0.145, 6.58), Size = Vector3.new(1.3, 0.39, 0) },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.54, 0.77, -1.8), Size = Vector3.new(0.48, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.5, -0.98, 6.5), Size = Vector3.new(0.3614, 0.38, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.34, 6.58), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.36), Size = Vector3.new(4.8, 0.08, 1.02), Zone = "Bumpers" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.35, -0.6265, -4.05), Size = Vector3.new(0, 1.5871, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.35, -0.6265, -4.05), Size = Vector3.new(0, 1.5871, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.35, -0.55, 4.05), Size = Vector3.new(0, 1.74, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.35, -0.55, 4.05), Size = Vector3.new(0, 1.74, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorF_R", Paint = "Trim", Center = Vector3.new(2.81, -0.1402, 0.05), Size = Vector3.new(0, 1.5597, 0.09), Detail = true },
	{ Name = "Ink_DoorF_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.1402, 0.05), Size = Vector3.new(0, 1.5597, 0.09), Detail = true },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(3.35, -0.1203, 2.5), Size = Vector3.new(0, 1.5994, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-3.35, -0.1203, 2.5), Size = Vector3.new(0, 1.5994, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.81, -0.16, -2.4), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.16, -2.4), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.81, -0.485, -5.8), Size = Vector3.new(0, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.485, -5.8), Size = Vector3.new(0, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(2.81, -0.335, 5.8), Size = Vector3.new(0, 2.07, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.335, 5.8), Size = Vector3.new(0, 2.07, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5515, -4.1475), Size = Vector3.new(4.59, 0.1912, 3.295), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.75, 4.8725), Size = Vector3.new(4.59, 0, 1.845), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.86), Zone = "Skirts" },
	{ Name = "Handle_FR", Paint = "Trim", Center = Vector3.new(2.81, 0.3794, -0.6), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.81, 0.4191, 1.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.86), Zone = "Skirts" },
	{ Name = "Handle_FL", Paint = "Trim", Center = Vector3.new(-2.81, 0.3794, -0.6), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.81, 0.4191, 1.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.165, 6.57), Size = Vector3.new(2, 0.43, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7341, -4.25), Size = Vector3.new(2, 0.5471, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.5656, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.5179, -4.17), Size = Vector3.new(3.5, 0.1041, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.545, 5.7), Size = Vector3.new(6.24, 1.65, 1.9), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 1.97, 5.7), Size = Vector3.new(6, 0.2, 1.7), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.52, -6.95), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.52, -7.05), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
