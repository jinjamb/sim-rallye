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
	carrosserie en pièces (numéros, feux, accessoires). Cabin.TopY est,
	comme pour les carrosseries en pièces, le dessous du toit (0.24 sous le
	dessus) : les accessoires de toit se posent dessus.
]]

return {
	Mounts = {
		NoseZ = -6.3, TailZ = 5.55, BottomY = -1.42, BeltY = 0.78, HalfWidth = 2.75, NoseHalfWidth = 1.84,
		HoodFrontZ = -5.45, HoodRearZ = -2.35, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.95, Y = 1, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.05, BaseY = 0.68, TopY = 2.3, WindshieldFrontZ = -2.37, RoofFrontZ = -0.45, RoofRearZ = 4.25 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5288, -0.375), Size = Vector3.new(6.3, 1.7825, 11.85), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.875), Size = Vector3.new(6.2977, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.365, -5.875), Size = Vector3.new(6.2977, 2.11, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.6493, -0.37, -3.9), Size = Vector3.new(1.0014, 2.1, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.685, -3.9), Size = Vector3.new(4.64, 0.27, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.6493, -0.37, -3.9), Size = Vector3.new(1.0014, 2.1, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.4493, -0.285, -0.425), Size = Vector3.new(1.0586, 2.2699, 3.85), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.91, 1.275), Size = Vector3.new(4.64, 0.46, 7.25), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.4493, -0.285, -0.425), Size = Vector3.new(1.0586, 2.2699, 3.85), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.535, -0.21, 3.25), Size = Vector3.new(1.23, 2.42, 3.5), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.535, -0.21, 3.25), Size = Vector3.new(1.23, 2.42, 3.5), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1.07, 4.95), Size = Vector3.new(4.64, 0.14, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.275), Size = Vector3.new(6.3, 1.4284, 0.55), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.14, 5.275), Size = Vector3.new(6.3, 2.56, 0.55), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Trim", Center = Vector3.new(0, 2.285, 1.7438), Size = Vector3.new(3.44, 0.51, 5.3475), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.355, 1.275), Size = Vector3.new(4.1, 1.35, 7.29), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(1.885, 1.355, 0.098), Size = Vector3.new(0.2508, 1.026, 3.179) },
	{ Name = "SharkFin", Paint = "Body", Center = Vector3.new(0, 1.355, 1.8837), Size = Vector3.new(4.1, 1.35, 1.2174), Zone = "Pillars" },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(1.885, 1.355, 3.0602), Size = Vector3.new(0.2508, 1.026, 1.4819) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-1.885, 1.355, 0.098), Size = Vector3.new(0.2508, 1.026, 3.179) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-1.885, 1.355, 3.0602), Size = Vector3.new(0.2508, 1.026, 1.4819) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.355, -1.65), Size = Vector3.new(3.4692, 1.08, 1.152) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.355, 4.6687), Size = Vector3.new(3.4692, 1.08, 0.402) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.7, -6.34), Size = Vector3.new(2.5, 0.7, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.13, 0.12, -6.36), Size = Vector3.new(0.86, 0.4, 0) },
	{ Name = "LedStrip_R", Paint = "Head", Center = Vector3.new(1.4372, -0.65, -6.36), Size = Vector3.new(0.14, 0.7, 0), Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.6612, 0.285, 5.58), Size = Vector3.new(1.1224, 0.67, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.13, 0.12, -6.36), Size = Vector3.new(0.86, 0.4, 0) },
	{ Name = "LedStrip_L", Paint = "Head", Center = Vector3.new(-1.4372, -0.65, -6.36), Size = Vector3.new(0.14, 0.7, 0), Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.6612, 0.285, 5.58), Size = Vector3.new(1.1224, 0.67, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.205, 0.8565, -1.7), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.205, 0.8565, -1.7), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.3, -1, 5.5), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.09, 5.58), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofSpoiler", Paint = "Trim", Center = Vector3.new(0, 2.57, 4.45), Size = Vector3.new(3.4, 0.14, 0.8), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(2.99, -0.5884, -3.95), Size = Vector3.new(0.38, 1.6632, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-2.99, -0.5884, -3.95), Size = Vector3.new(0.38, 1.6632, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(2.99, -0.4288, 3.95), Size = Vector3.new(0.38, 1.9825, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-2.99, -0.4288, 3.95), Size = Vector3.new(0.38, 1.9825, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.59, -0.045, 1.45), Size = Vector3.new(0.38, 1.7499, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.59, -0.045, 1.45), Size = Vector3.new(0.38, 1.7499, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.79, -0.13, -2.3), Size = Vector3.new(0.38, 1.58, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.79, -0.13, -2.3), Size = Vector3.new(0.38, 1.58, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.99, -0.42, -5.4), Size = Vector3.new(0.38, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.99, -0.42, -5.4), Size = Vector3.new(0.38, 1.9, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(2.99, -0.195, 4.95), Size = Vector3.new(0.38, 2.35, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-2.99, -0.195, 4.95), Size = Vector3.new(0.38, 2.35, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.7068, -3.8975), Size = Vector3.new(4.23, 0.1277, 2.995), Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.4, 0.5512, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.4, 0.5512, 0.85), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.4, 5.57), Size = Vector3.new(2.8, 0.3, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.9511, -4.25), Size = Vector3.new(2, 0.5233, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.7944, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.7071, -4.17), Size = Vector3.new(3.5, 0.1108, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.79, 4.775), Size = Vector3.new(4.8, 0.14, 1.15), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.74, 4.85), Size = Vector3.new(4.96, 0.64, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.62, -6.5), Size = Vector3.new(3.3934, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.62, -6.6), Size = Vector3.new(3.2418, 0.6967, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.67, 0.45), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.665, -0.21), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.775, 3.05), Size = Vector3.new(0.1, 0.49, 2.3), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.85, -1.22, 0), Size = Vector3.new(0.2, 0.48, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(3, -1.3, 0), Size = Vector3.new(0.5, 0.36, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.85, -1.22, 0), Size = Vector3.new(0.2, 0.48, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-3, -1.3, 0), Size = Vector3.new(0.5, 0.36, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 5.565), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.39), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	},
}
