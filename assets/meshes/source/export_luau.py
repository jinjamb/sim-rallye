"""Écrit src/shared/Vehicle/MeshBodies/<Modèle>.luau : ce que l'outil d'import
attend de chaque pièce (centre, taille, peinture, zone, option).
Usage : python export_luau.py <fichier.luau> <Modèle>"""
import sys, numpy as np
import importlib
MODEL = sys.argv[2] if len(sys.argv) > 2 else "Hayate"
g = importlib.import_module(MODEL.lower() + "_geo")
B = getattr(g, "base", g)

ZONES = [
    (('Hood', 'Cowl', 'Trunk', 'HoodScoop'), 'Hood'),
    (('BumperFrontLip', 'BumperRearLip', 'GrilleBar', 'Grille', 'Intake', 'Splitter', 'RearPanel', 'TailGarnish', 'LampPod'), 'Bumpers'),
    (('BumperFront',), 'Front'), (('BumperRear',), 'Rear'),
    (('Door_',), 'Doors'), (('Fender_',), 'Fenders'), (('Roof',), 'Roof'), (('Pillars',), 'Pillars'),
    (('WingBlade', 'Wing'), 'Wing'), (('ArchLip_', 'Rocker_'), 'Skirts'), (('Mirror_',), 'Mirrors'),
    (('Handle_', 'HoodVents', 'HoodScoopMouth'), 'Details'),
]
EXACT = {'GrilleBar', 'HoodScoop', 'Wing', 'Roof', 'Pillars', 'Grille', 'Intake', 'Splitter', 'RearPanel', 'TailGarnish', 'LampPod', 'Hood', 'Cowl', 'Trunk',
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
	''' + MODEL + '''.luau (généré : assets/meshes/source/export_luau.py)
	La ''' + MODEL + ''' faite dans Blender (assets/meshes/''' + MODEL.lower() + ''') : chaque pièce du
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
		NoseZ = ''' + f(B.NOSE_Z) + ''', TailZ = ''' + f(B.TAIL_Z) + ''', BottomY = ''' + f(B.BOTTOM) + ''', BeltY = ''' + f(round(B.top_y(0), 2)) + ''', HalfWidth = ''' + f(B.BODY_HW) + ''',
		HoodFrontZ = ''' + f(B.BUMPER_F) + ''', HoodRearZ = ''' + f(B.HOOD_REAR) + ''', HoodHalfWidth = 2.2,
		Wing = { Mount = "Deck", Z = 5.7, Y = ''' + f(round(B.top_y(5.7), 2)) + ''', Width = 5.4 },
	},
	Cabin = { HalfWidth = ''' + f(B.CABIN['hwb']) + ''', BaseY = ''' + f(B.CABIN['yb']) + ''', TopY = ''' + f(B.CABIN['yr']) + ''', WindshieldFrontZ = ''' + f(B.HOOD_REAR - 0.02) + ''', RoofFrontZ = ''' + f(B.CABIN['zf_top']) + ''', RoofRearZ = ''' + f(B.CABIN['zr_top']) + ''' },
	Parts = {
''' + '\n'.join(lines) + '''
	},
}
'''
open(sys.argv[1], 'w').write(out)
print(len(lines), 'pièces')
