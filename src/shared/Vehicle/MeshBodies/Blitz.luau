--!nocheck
--[[
	Blitz.luau (généré : assets/meshes/source/export_luau.py)
	La Blitz faite dans Blender (assets/meshes/blitz) : chaque pièce du
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
		NoseZ = -7.1, TailZ = 6.05, BottomY = -1.42, BeltY = 0.65, HalfWidth = 2.7, NoseHalfWidth = 2.1,
		HoodFrontZ = -6, HoodRearZ = -1.8, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.45, Y = 0.82, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.6, TopY = 1.96, WindshieldFrontZ = -1.82, RoofFrontZ = -0.3, RoofRearZ = 1.9 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.6, -0.525), Size = Vector3.new(6.9, 1.64, 13.15), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.55), Size = Vector3.new(5.4, 0, 1.1), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.58, -6.55), Size = Vector3.new(5.4, 1.68, 1.1), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.075, -0.42, -3.9), Size = Vector3.new(0.75, 2, 4.2), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.42, -3.9), Size = Vector3.new(6.9, 0.32, 4.2), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.075, -0.42, -3.9), Size = Vector3.new(0.75, 2, 4.2), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.7, -0.3427, 0.1), Size = Vector3.new(0, 2.1546, 3.8), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.7, 1.15), Size = Vector3.new(6.9, 0.24, 5.9), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.7, -0.3427, 0.1), Size = Vector3.new(0, 2.1546, 3.8), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.075, -0.3, 3.725), Size = Vector3.new(0.75, 2.24, 3.45), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.075, -0.3, 3.725), Size = Vector3.new(0.75, 2.24, 3.45), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.82, 4.775), Size = Vector3.new(6.9, 0, 1.35), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 5.75), Size = Vector3.new(6.9, 0, 0.6), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.3, 5.75), Size = Vector3.new(6.9, 2.24, 0.6), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.1995, 0.8002), Size = Vector3.new(4, 0.001, 2.2023), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Body", Center = Vector3.new(0, 1.3995, 1.15), Size = Vector3.new(4.8, 1.599, 5.94), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.196, 1.4155, 0.2126), Size = Vector3.new(0.28, 1.1193, 2.8312) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.196, 1.4155, 1.9375), Size = Vector3.new(0.28, 1.1193, 1.3045) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.196, 1.4155, 0.2126), Size = Vector3.new(0.28, 1.1193, 2.8312) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.196, 1.4155, 1.9375), Size = Vector3.new(0.28, 1.1193, 1.3045) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.3995, -1.0605), Size = Vector3.new(4.0592, 1.2792, 1.2152) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.3995, 3.0107), Size = Vector3.new(4.0592, 1.2792, 1.7749) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.22, -7.14), Size = Vector3.new(4.1, 0.4, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.275, -0.22, -7.16), Size = Vector3.new(0.99, 0.28, 0) },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.75, 0.275, 6.1), Size = Vector3.new(1.2, 0.35, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.275, -0.22, -7.16), Size = Vector3.new(0.99, 0.28, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.75, 0.275, 6.1), Size = Vector3.new(1.2, 0.35, 0) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.9, -7.14), Size = Vector3.new(4, 0.6, 0), Zone = "Bumpers" },
	{ Name = "GrilleBar", Paint = "Body", Center = Vector3.new(0, -0.9, -7.17), Size = Vector3.new(3.6, 0.5, 0), Zone = "Bumpers" },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.535, 0.7544, -1.15), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.535, 0.7544, -1.15), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.72), Size = Vector3.new(4.2, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.4, -1, 6), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 6.08), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "DeckWing", Paint = "Trim", Center = Vector3.new(0, 1.47, 5.55), Size = Vector3.new(6.4, 1.3, 1.9), Zone = "Wing" },
	{ Name = "DeckWingBlade", Paint = "Body", Center = Vector3.new(0, 1.77, 5.55), Size = Vector3.new(6.2, 0.2, 1.7), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.48, -0.679, -4.05), Size = Vector3.new(0, 1.4819, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.48, -0.679, -4.05), Size = Vector3.new(0, 1.4819, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.48, -0.501, 4.05), Size = Vector3.new(0, 1.838, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.48, -0.501, 4.05), Size = Vector3.new(0, 1.838, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.73, -0.1027, 1.95), Size = Vector3.new(0, 1.6346, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.73, -0.1027, 1.95), Size = Vector3.new(0, 1.6346, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.73, -0.18, -1.75), Size = Vector3.new(0, 1.48, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.73, -0.18, -1.75), Size = Vector3.new(0, 1.48, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.73, -0.565, -5.95), Size = Vector3.new(0, 1.61, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.73, -0.565, -5.95), Size = Vector3.new(0, 1.61, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.48, -0.285, 5.4), Size = Vector3.new(0, 2.17, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.48, -0.285, 5.4), Size = Vector3.new(0, 2.17, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.4519, -3.8975), Size = Vector3.new(4.59, 0.3086, 4.095), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.85, 4.7975), Size = Vector3.new(4.59, 0, 1.195), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.73, -1.21, 0), Size = Vector3.new(0, 0.42, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.73, 0.4361, 1.3), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.73, -1.21, 0), Size = Vector3.new(0, 0.42, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.73, 0.4361, 1.3), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.275, 6.07), Size = Vector3.new(5.1, 0.55, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.6133, -4.25), Size = Vector3.new(2, 0.5905, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.4231, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.3968, -4.17), Size = Vector3.new(3.5, 0.126, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.85, -7.3), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.85, -7.4), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	{ Name = "AccRoofScoop", Paint = "Body", Center = Vector3.new(0, 2.33, 0.6), Size = Vector3.new(1.1, 0.3, 1.3), Zone = "Roof", Slot = "Roof", Options = { 2 } },
	{ Name = "AccRoofScoopMouth", Paint = "Trim", Center = Vector3.new(0, 2.325, -0.06), Size = Vector3.new(0.96, 0.21, 0), Zone = "Details", Slot = "Roof", Options = { 2 }, Detail = true },
	{ Name = "AccSharkFin", Paint = "Body", Center = Vector3.new(0, 2.435, 1.325), Size = Vector3.new(0.1, 0.49, 1.05), Zone = "Roof", Slot = "Roof", Options = { 3 } },
	{ Name = "AccSkirt_R", Paint = "Body", Center = Vector3.new(2.8, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.76), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_R", Paint = "Trim", Center = Vector3.new(2.95, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.76), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccSkirt_L", Paint = "Body", Center = Vector3.new(-2.8, -1.22, 0), Size = Vector3.new(0.2, 0.48, 4.76), Zone = "Skirts", Slot = "Skirts", Options = { 2 } },
	{ Name = "AccSideBlade_L", Paint = "Trim", Center = Vector3.new(-2.95, -1.3, 0), Size = Vector3.new(0.5, 0.36, 4.76), Zone = "Skirts", Slot = "Skirts", Options = { 3 } },
	{ Name = "AccDiffuser", Paint = "Trim", Center = Vector3.new(0, -1.28, 6.065), Size = Vector3.new(4.8, 0.32, 0.55), Zone = "Bumpers", Slot = "Diffuser", Options = { 2 } },
	{ Name = "AccDiffuserRace", Paint = "Trim", Center = Vector3.new(0, -1.19, 5.89), Size = Vector3.new(4.8, 0.5, 0.9), Zone = "Bumpers", Slot = "Diffuser", Options = { 3 } },
	{ Name = "AccAntenna", Paint = "Trim", Center = Vector3.new(0.8, 2.9315, 1.5025), Size = Vector3.new(0.2, 1.483, 0.545), Zone = "Details", Slot = "Roof", Options = { 4 }, Detail = true },
	{ Name = "AccMudflaps", Paint = "Trim", Center = Vector3.new(0, -1.475, 1.3), Size = Vector3.new(6.12, 0.95, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.04, 0.16, 8.19), Slot = "Mudflaps", Options = { 2 }, Detail = true },
	{ Name = "AccMudflapsLong", Paint = "Trim", Center = Vector3.new(0, -1.325, 1.3), Size = Vector3.new(6.32, 1.25, 8.16), Zone = "Details", Slot = "Mudflaps", Options = { 3 }, Detail = true },
	{ Name = "AccMudflapsLongBand", Paint = "Body", Center = Vector3.new(0, -1.67, 1.3), Size = Vector3.new(6.24, 0.16, 8.19), Slot = "Mudflaps", Options = { 3 }, Detail = true },
	},
}
