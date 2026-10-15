"""Rendus d'un modèle : python shots.py <dossier> <modèle> [début fin]."""
import importlib, json, subprocess, sys
S, MODEL = sys.argv[1], sys.argv[2]
sys.path.insert(0, S)
geo = importlib.import_module(MODEL.lower() + '_geo')
for variant in ('full', 'base', 'hero'):
    json.dump(geo.build(variant), open(f'{S}/{MODEL.lower()}_{variant}.json', 'w'))
LIVERIES = {'Hayate': ([244, 240, 230], [214, 40, 52], [110, 200, 245]),
            'Hoshi': ([40, 70, 200], [250, 200, 40], [235, 235, 240]),
            # une couleur par modèle, pour qu'on les distingue d'un coup d'oeil
            'Tsubasa': ([220, 30, 40], [220, 30, 40], [220, 30, 40]),
            'Requin': ([190, 196, 208], [190, 196, 208], [190, 196, 208]),
            'Lynx': ([40, 90, 220], [40, 90, 220], [40, 90, 220]),
            'Griffe': ([60, 205, 240], [60, 205, 240], [60, 205, 240]),
            'Furia': ([250, 200, 40], [250, 200, 40], [250, 200, 40]),
            'Blitz': ([130, 40, 170], [130, 40, 170], [130, 40, 170]),
            'Fauve': ([245, 245, 248], [245, 245, 248], [245, 245, 248]),
            'Cuneo': ([30, 160, 95], [30, 160, 95], [30, 160, 95])}
liv = LIVERIES.get(MODEL, LIVERIES['Hayate'])
shots = [
    ('avant34', 'hero', liv[0], [-11.5, 2.4, -19], 'sable'),
    ('profil', 'base', liv[1], [-26, 1.2, 0.5], 'terre'),
    ('arriere34', 'full', liv[2], [13, 4.5, 19], 'asphalte'),
]
a, b = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 3)
for name, variant, color, eye, ground in shots[a:b]:
    cfg = dict(mesh=f'{S}/{MODEL.lower()}_{variant}.json', out=f'{S}/out/{MODEL.lower()}_{name}.png', mode='anime', livery=color, eye=eye,
               ground=S + '/tex/' + ground + '.png', rim=[238, 238, 242])
    subprocess.run(['python3', '-I', S + '/render_mesh.py', json.dumps(cfg)], check=True)
