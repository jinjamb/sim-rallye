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
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -7, TailZ = 6.1, BottomY = -1.42, BeltY = 0.67, HalfWidth = 2.78,
		HoodFrontZ = -5.9, HoodRearZ = -2, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.5, Y = 0.78, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.4, BaseY = 0.62, TopY = 2.22, WindshieldFrontZ = -2.02, RoofFrontZ = -0.3, RoofRearZ = 2.45 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.62, -0.45), Size = Vector3.new(6.84, 1.6, 13.1), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -6.45), Size = Vector3.new(5.56, 0, 1.1), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.53, -6.45), Size = Vector3.new(5.56, 1.78, 1.1), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(3.1, -0.4, -3.95), Size = Vector3.new(0.64, 2.04, 3.9), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.49, -3.95), Size = Vector3.new(6.84, 0.26, 3.9), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-3.1, -0.4, -3.95), Size = Vector3.new(0.64, 2.04, 3.9), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.78, -0.3453, 0.05), Size = Vector3.new(0, 2.1493, 4.1), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.7, 1), Size = Vector3.new(6.84, 0.16, 6), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.78, -0.3453, 0.05), Size = Vector3.new(0, 2.1493, 4.1), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(3.1, -0.32, 3.775), Size = Vector3.new(0.64, 2.2, 3.35), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-3.1, -0.32, 3.775), Size = Vector3.new(0.64, 2.2, 3.35), Zone = "Fenders" },
	{ Name = "Trunk", Paint = "Body", Center = Vector3.new(0, 0.78, 4.725), Size = Vector3.new(6.84, 0, 1.45), Zone = "Hood" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -1.42, 5.775), Size = Vector3.new(6.84, 0, 0.65), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.32, 5.775), Size = Vector3.new(6.84, 2.2, 0.65), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.2195, 1.075), Size = Vector3.new(4.1, 0.001, 2.7521), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.4195, 1), Size = Vector3.new(4.8, 1.599, 6.04), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(2.2215, 1.4355, 0.24), Size = Vector3.new(0.245, 1.1193, 2.8672) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(2.2215, 1.4355, 2.5174), Size = Vector3.new(0.245, 1.1193, 1.6209) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-2.2215, 1.4355, 0.24), Size = Vector3.new(0.245, 1.1193, 2.8672) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-2.2215, 1.4355, 2.5174), Size = Vector3.new(0.245, 1.1193, 1.6209) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.4195, -1.1605), Size = Vector3.new(4.0678, 1.2792, 1.3751) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.4195, 3.2355), Size = Vector3.new(4.0678, 1.2792, 1.2552) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.21, -7.04), Size = Vector3.new(4.2, 0.38, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.375, -0.21, -7.06), Size = Vector3.new(0.99, 0.26, 0) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.875, -7.04), Size = Vector3.new(4, 0.55, 0), Zone = "Bumpers" },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.75, 0.275, 6.15), Size = Vector3.new(1.1, 0.35, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.375, -0.21, -7.06), Size = Vector3.new(0.99, 0.26, 0) },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.75, 0.275, 6.15), Size = Vector3.new(1.1, 0.35, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.555, 0.786, -1.35), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.555, 0.786, -1.35), Size = Vector3.new(0.45, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -6.62), Size = Vector3.new(4.6, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(-1.4, -1, 6.05), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, -0.36, 6.13), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "DeckWing", Paint = "Trim", Center = Vector3.new(0, 1.43, 5.575), Size = Vector3.new(6.4, 1.3, 1.95), Zone = "Wing" },
	{ Name = "DeckWingBlade", Paint = "Body", Center = Vector3.new(0, 1.73, 5.575), Size = Vector3.new(6.2, 0.2, 1.75), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.45, -0.645, -4.05), Size = Vector3.new(0, 1.55, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.45, -0.645, -4.05), Size = Vector3.new(0, 1.55, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.45, -0.52, 4.05), Size = Vector3.new(0, 1.8, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.45, -0.52, 4.05), Size = Vector3.new(0, 1.8, 3.2), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.81, -0.1053, 2.05), Size = Vector3.new(0, 1.6293, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.1053, 2.05), Size = Vector3.new(0, 1.6293, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.81, -0.16, -1.95), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.16, -1.95), Size = Vector3.new(0, 1.52, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(2.81, -0.515, -5.85), Size = Vector3.new(0, 1.71, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-2.81, -0.515, -5.85), Size = Vector3.new(0, 1.71, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.45, -0.305, 5.4), Size = Vector3.new(0, 2.13, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.45, -0.305, 5.4), Size = Vector3.new(0, 2.13, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.5217, -3.9475), Size = Vector3.new(4.59, 0.25, 3.795), Detail = true },
	{ Name = "Ink_Trunk", Paint = "Trim", Center = Vector3.new(0, 0.81, 4.7475), Size = Vector3.new(4.59, 0, 1.295), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.81, 0.4393, 1.35), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.81, -1.195, 0), Size = Vector3.new(0, 0.45, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.81, 0.4393, 1.35), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, 0.275, 6.12), Size = Vector3.new(5, 0.55, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.69, -4.25), Size = Vector3.new(2, 0.5667, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.5117, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.4737, -4.17), Size = Vector3.new(3.5, 0.114, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.8, -7.2), Size = Vector3.new(4, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.8, -7.3), Size = Vector3.new(3.7761, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
