--!nocheck
--[[
	Kaze.luau (généré : assets/meshes/source/export_luau.py)
	La Kaze faite dans Blender (assets/meshes/kaze) : chaque pièce du
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
		NoseZ = -6.4, TailZ = 5.5, BottomY = -1.42, BeltY = 0.77, HalfWidth = 2.75, NoseHalfWidth = 1.89,
		HoodFrontZ = -5.5, HoodRearZ = -2.4, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.9, Y = 0.98, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.2, BaseY = 0.66, TopY = 2.1, WindshieldFrontZ = -2.42, RoofFrontZ = -0.55, RoofRearZ = 4.15 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.5386, -0.45), Size = Vector3.new(6.6, 1.7627, 11.9), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.95), Size = Vector3.new(6.43, 0, 0.9), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.5, -5.95), Size = Vector3.new(6.43, 1.84, 0.9), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.0021, -0.38, -3.95), Size = Vector3.new(0.5957, 2.08, 3.1), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.54, -3.95), Size = Vector3.new(5.88, 0.24, 3.1), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.0021, -0.38, -3.95), Size = Vector3.new(0.5957, 2.08, 3.1), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.7271, -0.2956, -0.475), Size = Vector3.new(0.6743, 2.2488, 3.85), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.82, 1.25), Size = Vector3.new(5.88, 0.32, 7.3), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.7271, -0.2956, -0.475), Size = Vector3.new(0.6743, 2.2488, 3.85), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.845, -0.22, 3.225), Size = Vector3.new(0.91, 2.4, 3.55), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.845, -0.22, 3.225), Size = Vector3.new(0.91, 2.4, 3.55), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.98, 4.95), Size = Vector3.new(5.88, 0, 0.1), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.7058, 5.25), Size = Vector3.new(6.6, 1.4284, 0.5), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.22, 5.25), Size = Vector3.new(6.6, 2.4, 0.5), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.3395, 1.7997), Size = Vector3.new(3.7, 0.001, 4.7016), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.4995, 1.25), Size = Vector3.new(4.4, 1.679, 7.34), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.018, 1.5331, 0.2135), Size = Vector3.new(0.238, 1.1417, 3.2212) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.018, 1.5331, 2.8249), Size = Vector3.new(0.238, 1.1417, 1.579) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.018, 1.5331, 0.2135), Size = Vector3.new(0.238, 1.1417, 3.2212) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.018, 1.5331, 2.8249), Size = Vector3.new(0.238, 1.1417, 1.579) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.4995, -1.4856), Size = Vector3.new(3.7238, 1.3432, 1.4951) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.4995, 4.5352), Size = Vector3.new(3.7238, 1.3432, 0.6156) },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.0628, -0.15, -6.46), Size = Vector3.new(1.4255, 0.34, 0) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.875, -6.44), Size = Vector3.new(3.491, 0.85, 0), Zone = "Bumpers" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.8019, 0.42, 5.53), Size = Vector3.new(1.8037, 0.4, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.0628, -0.15, -6.46), Size = Vector3.new(1.4255, 0.34, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.8019, 0.42, 5.53), Size = Vector3.new(1.8037, 0.4, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.305, 0.8363, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.305, 0.8363, -1.75), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.02), Size = Vector3.new(4.6, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.3, -1, 5.45), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.09, 5.53), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofSpoiler", Paint = "Trim", Center = Vector3.new(0, 2.43, 4.4), Size = Vector3.new(3.7, 0.14, 0.8), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.2374, -0.6168, -3.95), Size = Vector3.new(0.1851, 1.6064, 3), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.2374, -0.6168, -3.95), Size = Vector3.new(0.1851, 1.6064, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.1769, -0.4386, 3.95), Size = Vector3.new(0.3062, 1.9627, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.1769, -0.4386, 3.95), Size = Vector3.new(0.3062, 1.9627, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.64, -0.0556, 1.4), Size = Vector3.new(0.28, 1.7288, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.64, -0.0556, 1.4), Size = Vector3.new(0.28, 1.7288, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.8757, -0.14, -2.35), Size = Vector3.new(0.28, 1.56, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.8757, -0.14, -2.35), Size = Vector3.new(0.28, 1.56, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.1475, -0.485, -5.45), Size = Vector3.new(0.28, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.1475, -0.485, -5.45), Size = Vector3.new(0.28, 1.77, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.19, -0.205, 4.95), Size = Vector3.new(0.28, 2.33, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.19, -0.205, 4.95), Size = Vector3.new(0.28, 2.33, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5719, -3.9475), Size = Vector3.new(4.59, 0.2284, 2.995), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.78, -1.23, 0), Size = Vector3.new(0, 0.38, 4.4), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.5497, 0.5303, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.78, -1.23, 0), Size = Vector3.new(0, 0.38, 4.4), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.5497, 0.5303, 0.8), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.325, 5.52), Size = Vector3.new(3.2, 0.35, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.7368, -4.25), Size = Vector3.new(2, 0.5936, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.545, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.5202, -4.17), Size = Vector3.new(3.5, 0.1275, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "WingBlade", Paint = "Body", Center = Vector3.new(0, 2.69, 4.7), Size = Vector3.new(4.9, 0.14, 1.2), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "Wing", Paint = "Trim", Center = Vector3.new(0, 2.64, 4.775), Size = Vector3.new(5.06, 0.64, 1.25), Zone = "Wing", Slot = "Wing", Options = { 2, 3, 4, 5 } },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.7, -6.6), Size = Vector3.new(3.5582, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.7, -6.7), Size = Vector3.new(3.3992, 0.7305, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.47, 0.35), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.465, -0.31), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.575, 2.95), Size = Vector3.new(0.1, 0.49, 2.3), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.85, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.3), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(3, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.3), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.85, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.3), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-3, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.3), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 5.515), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.34), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	},
}
