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
	carrosserie en pièces (numéros, feux, accessoires). Cabin.TopY est,
	comme pour les carrosseries en pièces, le dessous du toit (0.24 sous le
	dessus) : les accessoires de toit se posent dessus.
]]

return {
	Mounts = {
		NoseZ = -6.35, TailZ = 5.45, BottomY = -1.42, BeltY = 0.85, HalfWidth = 2.55, NoseHalfWidth = 2.05,
		HoodFrontZ = -5.5, HoodRearZ = -2.3, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 4.85, Y = 1.05, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.15, BaseY = 0.78, TopY = 2.18, WindshieldFrontZ = -2.32, RoofFrontZ = -0.3, RoofRearZ = 4.3 },
	Parts = {
	{ Name = "Underbody", Paint = "Trim", Center = Vector3.new(0, -0.52, -0.45), Size = Vector3.new(7, 1.8, 11.8), Detail = true },
	{ Name = "BumperFrontLip", Paint = "Trim", Center = Vector3.new(0, -1.42, -5.925), Size = Vector3.new(7, 0, 0.85), Zone = "Bumpers" },
	{ Name = "BumperFront", Paint = "Body", Center = Vector3.new(0, -0.45, -5.925), Size = Vector3.new(7, 1.94, 0.85), Zone = "Front" },
	{ Name = "Fender_FR", Paint = "Body", Center = Vector3.new(2.85, -0.33, -3.9), Size = Vector3.new(1.3, 2.18, 3.2), Zone = "Fenders" },
	{ Name = "Hood", Paint = "Body", Center = Vector3.new(0, 0.64, -3.9), Size = Vector3.new(6.3, 0.32, 3.2), Zone = "Hood" },
	{ Name = "Fender_FL", Paint = "Body", Center = Vector3.new(-2.85, -0.33, -3.9), Size = Vector3.new(1.3, 2.18, 3.2), Zone = "Fenders" },
	{ Name = "Door_FR", Paint = "Body", Center = Vector3.new(2.375, -0.252, -0.35), Size = Vector3.new(0.35, 2.336, 3.9), Zone = "Doors" },
	{ Name = "Cowl", Paint = "Body", Center = Vector3.new(0, 0.925, 1.325), Size = Vector3.new(6.3, 0.33, 7.25), Zone = "Hood" },
	{ Name = "Door_FL", Paint = "Body", Center = Vector3.new(-2.375, -0.252, -0.35), Size = Vector3.new(0.35, 2.336, 3.9), Zone = "Doors" },
	{ Name = "Fender_RR", Paint = "Body", Center = Vector3.new(2.85, -0.185, 3.275), Size = Vector3.new(1.3, 2.47, 3.35), Zone = "Fenders" },
	{ Name = "Fender_RL", Paint = "Body", Center = Vector3.new(-2.85, -0.185, 3.275), Size = Vector3.new(1.3, 2.47, 3.35), Zone = "Fenders" },
	{ Name = "BumperRearLip", Paint = "Trim", Center = Vector3.new(0, -0.6838, 5.2), Size = Vector3.new(7, 1.4724, 0.5), Zone = "Bumpers" },
	{ Name = "BumperRear", Paint = "Body", Center = Vector3.new(0, -0.165, 5.2), Size = Vector3.new(7, 2.51, 0.5), Zone = "Rear" },
	{ Name = "WheelWell", Paint = "Trim", Center = Vector3.new(0, -0.53, 0), Size = Vector3.new(4.5, 1.78, 10.9), Detail = true },
	{ Name = "Roof", Paint = "Body", Center = Vector3.new(0, 2.32, 1.9177), Size = Vector3.new(3.7, 0.2, 4.928), Zone = "Roof" },
	{ Name = "Pillars", Paint = "Trim", Center = Vector3.new(0, 1.5, 1.325), Size = Vector3.new(4.3, 1.44, 7.29), Zone = "Pillars" },
	{ Name = "Window_FR", Paint = "Glass", Center = Vector3.new(1.982, 1.5864, 0.3217), Size = Vector3.new(0.18, 0.864, 3.026) },
	{ Name = "Window_RR", Paint = "Glass", Center = Vector3.new(1.982, 1.5864, 2.6808), Size = Vector3.new(0.18, 0.864, 1.6022) },
	{ Name = "Window_FL", Paint = "Glass", Center = Vector3.new(-1.982, 1.5864, 0.3217), Size = Vector3.new(0.18, 0.864, 3.026) },
	{ Name = "Window_RL", Paint = "Glass", Center = Vector3.new(-1.982, 1.5864, 2.6808), Size = Vector3.new(0.18, 0.864, 1.6022) },
	{ Name = "Windshield", Paint = "Glass", Center = Vector3.new(0, 1.5, -1.4332), Size = Vector3.new(3.6464, 1.152, 1.4189) },
	{ Name = "RearWindow", Paint = "Glass", Center = Vector3.new(0, 1.5, 4.6759), Size = Vector3.new(3.6464, 1.152, 0.4706) },
	{ Name = "Grille", Paint = "Trim", Center = Vector3.new(0, -0.59, -6.39), Size = Vector3.new(2.9, 1.22, 0), Zone = "Bumpers" },
	{ Name = "Headlight_R", Paint = "Head", Center = Vector3.new(1.375, -0.06, -6.41), Size = Vector3.new(0.85, 0.24, 0) },
	{ Name = "Intake", Paint = "Trim", Center = Vector3.new(0, -0.8, -6.39), Size = Vector3.new(3.54, 0.8, 0), Zone = "Bumpers" },
	{ Name = "Canard_R", Paint = "Trim", Center = Vector3.new(2.25, -0.755, -6.025), Size = Vector3.new(0.7, 0.19, 0.75), Zone = "Details", Detail = true },
	{ Name = "FlareVent_R", Paint = "Trim", Center = Vector3.new(3.53, -0.325, -2.92), Size = Vector3.new(0, 1.05, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailLight_R", Paint = "Tail", Center = Vector3.new(1.9825, 0.51, 5.48), Size = Vector3.new(1.9649, 0.38, 0) },
	{ Name = "Headlight_L", Paint = "Head", Center = Vector3.new(-1.375, -0.06, -6.41), Size = Vector3.new(0.85, 0.24, 0) },
	{ Name = "Canard_L", Paint = "Trim", Center = Vector3.new(-2.25, -0.755, -6.025), Size = Vector3.new(0.7, 0.19, 0.75), Zone = "Details", Detail = true },
	{ Name = "FlareVent_L", Paint = "Trim", Center = Vector3.new(-3.53, -0.325, -2.92), Size = Vector3.new(0, 1.05, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailLight_L", Paint = "Tail", Center = Vector3.new(-1.9825, 0.51, 5.48), Size = Vector3.new(1.9649, 0.38, 0) },
	{ Name = "Mirror_R", Paint = "Body", Center = Vector3.new(2.185, 0.934, -1.65), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Mirror_L", Paint = "Body", Center = Vector3.new(-2.185, 0.934, -1.65), Size = Vector3.new(0.57, 0.3, 0.3), Zone = "Mirrors" },
	{ Name = "Splitter", Paint = "Trim", Center = Vector3.new(0, -1.12, -5.97), Size = Vector3.new(5.2, 0.08, 1.04), Zone = "Bumpers" },
	{ Name = "Exhaust", Paint = "Trim", Center = Vector3.new(1.4, -1, 5.4), Size = Vector3.new(0.4065, 0.4065, 0.4), Detail = true },
	{ Name = "RearPanel", Paint = "Trim", Center = Vector3.new(0, 0.04, 5.48), Size = Vector3.new(1.6, 0.32, 0), Zone = "Bumpers", Detail = true },
	{ Name = "RoofWingBlade", Paint = "Body", Center = Vector3.new(0, 2.73, 4.775), Size = Vector3.new(5.2, 0.46, 1.25), Zone = "Wing" },
	{ Name = "RoofWing", Paint = "Trim", Center = Vector3.new(0, 2.78, 4.8), Size = Vector3.new(5.36, 0.76, 1.2), Zone = "Wing" },
	{ Name = "ArchLip_FR", Paint = "Trim", Center = Vector3.new(3.4617, -0.5831, -4.05), Size = Vector3.new(0.1367, 1.6737, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_FL", Paint = "Trim", Center = Vector3.new(-3.4617, -0.5831, -4.05), Size = Vector3.new(0.1367, 1.6737, 3.2), Zone = "Skirts" },
	{ Name = "ArchLip_RR", Paint = "Trim", Center = Vector3.new(3.38, -0.42, 3.95), Size = Vector3.new(0.3, 2, 3), Zone = "Skirts" },
	{ Name = "ArchLip_RL", Paint = "Trim", Center = Vector3.new(-3.38, -0.42, 3.95), Size = Vector3.new(0.3, 2, 3), Zone = "Skirts" },
	{ Name = "Ink_DoorR_R", Paint = "Trim", Center = Vector3.new(2.48, -0.012, 1.55), Size = Vector3.new(0.2, 1.816, 0.09), Detail = true },
	{ Name = "Ink_DoorR_L", Paint = "Trim", Center = Vector3.new(-2.48, -0.012, 1.55), Size = Vector3.new(0.2, 1.816, 0.09), Detail = true },
	{ Name = "Ink_DoorA_R", Paint = "Trim", Center = Vector3.new(2.48, -0.09, -2.25), Size = Vector3.new(0.2, 1.66, 0.09), Detail = true },
	{ Name = "Ink_DoorA_L", Paint = "Trim", Center = Vector3.new(-2.48, -0.09, -2.25), Size = Vector3.new(0.2, 1.66, 0.09), Detail = true },
	{ Name = "Ink_BumpF_R", Paint = "Trim", Center = Vector3.new(3.43, -0.455, -5.45), Size = Vector3.new(0.2, 1.83, 0.09), Detail = true },
	{ Name = "Ink_BumpF_L", Paint = "Trim", Center = Vector3.new(-3.43, -0.455, -5.45), Size = Vector3.new(0.2, 1.83, 0.09), Detail = true },
	{ Name = "Ink_BumpR_R", Paint = "Trim", Center = Vector3.new(3.43, -0.17, 4.9), Size = Vector3.new(0.2, 2.4, 0.09), Detail = true },
	{ Name = "Ink_BumpR_L", Paint = "Trim", Center = Vector3.new(-3.43, -0.17, 4.9), Size = Vector3.new(0.2, 2.4, 0.09), Detail = true },
	{ Name = "Ink_Hood", Paint = "Trim", Center = Vector3.new(0, 0.6685, -3.8975), Size = Vector3.new(4.59, 0.2583, 3.095), Detail = true },
	{ Name = "Rocker_R", Paint = "Trim", Center = Vector3.new(2.58, -1.17, 0), Size = Vector3.new(0, 0.5, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RR", Paint = "Trim", Center = Vector3.new(2.4065, 0.618, 0.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "Rocker_L", Paint = "Trim", Center = Vector3.new(-2.58, -1.17, 0), Size = Vector3.new(0, 0.5, 4.86), Zone = "Skirts" },
	{ Name = "Handle_RL", Paint = "Trim", Center = Vector3.new(-2.4065, 0.618, 0.9), Size = Vector3.new(0, 0.1, 0.56), Zone = "Details", Detail = true },
	{ Name = "TailGarnish", Paint = "Trim", Center = Vector3.new(0, -0.25, 5.47), Size = Vector3.new(3.8, 0.4, 0), Zone = "Bumpers", Detail = true },
	{ Name = "HoodScoop", Paint = "Body", Center = Vector3.new(0, 0.8494, -4.25), Size = Vector3.new(2, 0.6187, 2.5), Zone = "Hood", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodScoopMouth", Paint = "Trim", Center = Vector3.new(0, 0.645, -5.455), Size = Vector3.new(1.84, 0.19, 0.11), Zone = "Details", Slot = "Hood", Options = { 2, 3 } },
	{ Name = "HoodVents", Paint = "Trim", Center = Vector3.new(0, 0.6246, -4.17), Size = Vector3.new(3.5, 0.1442, 1.46), Zone = "Details", Slot = "Hood", Options = { 2, 3 }, Detail = true },
	{ Name = "LampPod", Paint = "Trim", Center = Vector3.new(0, -0.62, -6.55), Size = Vector3.new(3.8752, 0.6, 0.24), Zone = "Bumpers", Slot = "Bumper", Options = { 2 } },
	{ Name = "RallyLamp", Paint = "Lamp", Center = Vector3.new(0, -0.62, -6.65), Size = Vector3.new(3.6824, 0.7761, 0.12), Slot = "Bumper", Options = { 2 } },
	},
}
