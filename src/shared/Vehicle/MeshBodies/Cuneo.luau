--!nocheck
--[[
	Cuneo.luau (généré : assets/meshes/source/export_luau.py)
	La Cuneo faite dans Blender (assets/meshes/cuneo) : chaque pièce du
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
		NoseZ = -6, TailZ = 5.45, BottomY = -1.42, BeltY = 0.67, HalfWidth = 2.4, NoseHalfWidth = 1.27,
		HoodFrontZ = -5.2, HoodRearZ = -2.1, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.85, Y = 0.9, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.25, BaseY = 0.58, TopY = 1.74, WindshieldFrontZ = -2.12, RoofFrontZ = -0.15, RoofRearZ = 1.1 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5654, -0.275), Size = Vector3.new(6.6, 1.7091, 11.45), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -0.9, -5.6), Size = Vector3.new(6.4659, 1.04, 0.8), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.5, -5.6), Size = Vector3.new(6.4659, 1.84, 0.8), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.5357, -0.43, -3.65), Size = Vector3.new(1.5286, 1.98, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.49, -3.65), Size = Vector3.new(4.9, 0.54, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.5357, -0.43, -3.65), Size = Vector3.new(1.5286, 1.98, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.2872, -0.35, -0.5), Size = Vector3.new(1.0317, 2.14, 3.2), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.83, 1.3), Size = Vector3.new(4.9, 0.54, 6.8), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.2872, -0.35, -0.5), Size = Vector3.new(1.0317, 2.14, 3.2), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.6265, -0.26, 3.05), Size = Vector3.new(1.3469, 2.32, 3.9), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.6265, -0.26, 3.05), Size = Vector3.new(1.3469, 2.32, 3.9), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 1, 4.85), Size = Vector3.new(4.9, 0.2, 0.3), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.225), Size = Vector3.new(6.6, 1.4284, 0.45), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.16, 5.225), Size = Vector3.new(6.6, 2.52, 0.45), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 1.7, 0.7828), Size = Vector3.new(3.4, 0.56, 3.3358), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Body", Center = Vector3.new(0, 1, -0.6836), Size = Vector3.new(4.5, 0.84, 2.8728), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(1.9558, 1.0294, -0.5435), Size = Vector3.new(0.3465, 0.5292, 1.76) },
	{ Name = "RearQuarter", Paint = "Body", Center = Vector3.new(0, 1, 2.618), Size = Vector3.new(4.5, 0.84, 4.204), Zone = "Fenders" },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-1.9558, 1.0294, -0.5435), Size = Vector3.new(0.3465, 0.5292, 1.76) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1, -1.5025), Size = Vector3.new(3.7754, 0.672, 0.9879) },
	{ Name = "EngineCover", Paint = "Body", Center = Vector3.new(0, 1, 3.5854), Size = Vector3.new(4.5, 0.84, 2.2692), Zone = "Rear" },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.7, -6.04), Size = Vector3.new(2.0375, 0.5, 0), Zone = "Bumpers" },
	{ Name = "PopUp_R", Paint = "Trim", Center = Vector3.new(1.175, 0.5209, -4.625), Size = Vector3.new(0.85, 0.26, 0.65), Zone = "Details" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.175, 0.5209, -4.97), Size = Vector3.new(0.69, 0.18, 0) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.675, 0.42, 5.485), Size = Vector3.new(0.9494, 0.42, 0.03) },
	{ Name = "PopUp_L", Paint = "Trim", Center = Vector3.new(-1.175, 0.5209, -4.625), Size = Vector3.new(0.85, 0.26, 0.65), Zone = "Details" },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.175, 0.5209, -4.97), Size = Vector3.new(0.69, 0.18, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.675, 0.42, 5.485), Size = Vector3.new(0.9494, 0.42, 0.03) },
	{ Name = "Louver", Paint = "Trim", Center = Vector3.new(0, 1.2096, 3.1), Size = Vector3.new(2.8, 0.7303, 1.9729), Zone = "Details", Detail = true },
	{ Name = "RoofSpoiler", Paint = "Body", Center = Vector3.new(0, 2.01, 1.15), Size = Vector3.new(3.9, 0.14, 0.7), Zone = "Wing" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.0933, 0.74, -1.45), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.0933, 0.74, -1.45), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.3, -1, 5.4), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.31, 5.48), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.1262, -0.6918, -3.95), Size = Vector3.new(0.4076, 1.4564, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.1262, -0.6918, -3.95), Size = Vector3.new(0.4076, 1.4564, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.1238, -0.4654, 3.95), Size = Vector3.new(0.4125, 1.9091, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.1238, -0.4654, 3.95), Size = Vector3.new(0.4125, 1.9091, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.6302, -0.11, 1.05), Size = Vector3.new(0.4, 1.62, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.6302, -0.11, 1.05), Size = Vector3.new(0.4, 1.62, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.4542, -0.19, -2.05), Size = Vector3.new(0.4, 1.46, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.4542, -0.19, -2.05), Size = Vector3.new(0.4, 1.46, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.0774, -0.585, -5.15), Size = Vector3.new(0.4, 1.57, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.0774, -0.585, -5.15), Size = Vector3.new(0.4, 1.57, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.13, -0.245, 4.95), Size = Vector3.new(0.4, 2.25, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.13, -0.245, 4.95), Size = Vector3.new(0.4, 2.25, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5206, -3.6475), Size = Vector3.new(4.41, 0.354, 2.995), Detail = true },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.399, 0.42, 0.5), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.399, 0.42, 0.5), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.42, 5.47), Size = Vector3.new(4.7, 0.48, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.6913, -4.25), Size = Vector3.new(2, 0.78, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.4062, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.4796, -4.17), Size = Vector3.new(3.5, 0.1994, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 1.1483, 5.125), Size = Vector3.new(3, 0.55, 0.45), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 1.5083, 5.175), Size = Vector3.new(5.8, 0.17, 0.95), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.62, -6.2), Size = Vector3.new(2.17, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.62, -6.3), Size = Vector3.new(2.073, 0.4455, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.11, 0.5), Size = Vector3.new(1.1, 0.3, 0.8), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.105, 0.09), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.215, 0.7625), Size = Vector3.new(0.1, 0.49, 0.575), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.8406, -1.22, 0), Size = Vector3.new(0.4157, 0.48, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(2.9906, -1.3, 0), Size = Vector3.new(0.7157, 0.36, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.8406, -1.22, 0), Size = Vector3.new(0.4157, 0.48, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-2.9906, -1.3, 0), Size = Vector3.new(0.7157, 0.36, 3.8), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 5.465), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.29), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	{ Name = "AccAntenna", Paint = "Trim", Center = Vector3.new(0.72, 2.6755, 0.7025), Size = Vector3.new(0.2, 1.483, 0.545), Zone = "Details", Slot = "Roof", Options = { 4 }, Detail = true },
	{ Name = "AccMudflaps", Paint = "Trim", Center = Vector3.new(0, -1.475, 1.3), Size = Vector3.new(6.12, 0.95, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.04, 0.16, 8.19), Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsLong", Paint = "Trim", Center = Vector3.new(0, -1.325, 1.3), Size = Vector3.new(6.32, 1.25, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 3 }, Detail = true },
	{ Name = "AccMudflapsLongBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.24, 0.16, 8.19), Slot = "Mudflaps", Options = { 3 }, Detail = true },
	},
}
