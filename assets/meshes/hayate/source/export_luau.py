"""Écrit src/shared/Vehicle/MeshBodies/Hayate.luau : ce que l'outil d'import
attend de chaque pièce (centre, taille, peinture, zone, option)."""
import sys, numpy as np
import hayate_geo as g

ZONES = [
    (('Hood', 'Cowl', 'Trunk', 'HoodScoop'), 'Hood'),
    (('BumperFrontLip', 'BumperRearLip', 'Grille', 'Intake', 'Splitter', 'RearPanel', 'TailGarnish', 'LampPod'), 'Bumpers'),
    (('BumperFront',), 'Front'), (('BumperRear',), 'Rear'),
    (('Door_',), 'Doors'), (('Fender_',), 'Fenders'), (('Roof',), 'Roof'), (('Pillars',), 'Pillars'),
    (('WingBlade', 'Wing'), 'Wing'), (('ArchLip_', 'Rocker_'), 'Skirts'), (('Mirror_',), 'Mirrors'),
    (('Handle_', 'HoodVents', 'HoodScoopMouth'), 'Details'),
]
EXACT = {'HoodScoop', 'Wing', 'Roof', 'Pillars', 'Grille', 'Intake', 'Splitter', 'RearPanel', 'TailGarnish', 'LampPod', 'Hood', 'Cowl', 'Trunk',
         'BumperFront', 'BumperRear', 'BumperFrontLip', 'BumperRearLip', 'WingBlade', 'HoodVents', 'HoodScoopMouth'}
OPTIONS = {'HoodScoop': ('Hood', '2, 3'), 'HoodScoopMouth': ('Hood', '2, 3'), 'HoodVents': ('Hood', '2, 3'),
           'Wing': ('Wing', '2, 3, 4, 5'), 'WingBlade': ('Wing', '2, 3, 4, 5'),
           'LampPod': ('Bumper', '2'), 'RallyLamp': ('Bumper', '2')}
DETAIL = ('Ink_', 'Handle_', 'HoodVents', 'TailGarnish', 'RearPanel', 'FogLight', 'Exhaust', 'WheelWell', 'Underbody')

def zone_of(name, paint):
    if paint not in ('Body', 'Trim') or name.startswith('Ink_'):
        return None
    for prefixes, zone in ZONES:
        for p in prefixes:
            if (name == p) if p in EXACT else name.startswith(p):
                return zone
    return None

def f(x):
    return f"{x:.4f}".rstrip('0').rstrip('.') if abs(x) > 1e-9 else '0'

lines = []
for p in g.build('full'):
    V = np.array(p['verts'], float)
    lo, hi = V.min(0), V.max(0)
    c, s = (lo + hi) / 2, hi - lo
    name, paint = p['name'], p['paint']
    z = zone_of(name, paint)
    o = OPTIONS.get(name)
    extra = ''
    if z: extra += f', Zone = "{z}"'
    if o: extra += f', Slot = "{o[0]}", Options = {{ {o[1]} }}'
    if name.startswith(DETAIL): extra += ', Detail = true'
    lines.append(f'\t{{ Name = "{name}", Paint = "{paint}", Center = Vector3.new({f(c[0])}, {f(c[1])}, {f(c[2])}), Size = Vector3.new({f(s[0])}, {f(s[1])}, {f(s[2])}){extra} }},')

out = '''--!nocheck
--[[
	Hayate.luau (généré : assets/meshes/hayate/source/export_luau.py)
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
	carrosserie en pièces (numéros, feux, accessoires).
]]

return {
	Mounts = {
		NoseZ = -6.75, TailZ = 6.55, BottomY = -1.42, BeltY = 0.66, HalfWidth = 2.78,
		HoodFrontZ = -5.85, HoodRearZ = -2.45, HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = 0.72, Width = 5.4 },
	},
	Cabin = { HalfWidth = 2.45, BaseY = 0.56, TopY = 2.28, WindshieldFrontZ = -2.47, RoofFrontZ = -0.75, RoofRearZ = 2.6 },
	Parts = {
''' + '\n'.join(lines) + '''
	},
}
'''
open(sys.argv[1], 'w').write(out)
print(len(lines), 'pièces')
