"""Rendus d'un modèle : python shots.py <dossier> <modèle> [début fin]."""
import importlib, json, subprocess, sys
S, MODEL = sys.argv[1], sys.argv[2]
sys.path.insert(0, S)
geo = importlib.import_module(MODEL.lower() + '_geo')
for variant in ('full', 'base', 'hero'):
    json.dump(geo.build(variant), open(f'{S}/{MODEL.lower()}_{variant}.json', 'w'))
LIVERIES = {'Hayate': ([244, 240, 230], [214, 40, 52], [110, 200, 245]),
            'Hoshi': ([40, 70, 200], [250, 200, 40], [235, 235, 240]),
            'Tsubasa': ([235, 235, 240], [220, 30, 40], [30, 32, 40]),
            'Requin': ([240, 236, 226], [40, 120, 220], [220, 30, 40]),
            'Lynx': ([235, 235, 240], [250, 190, 30], [40, 70, 200]),
            'Griffe': ([60, 200, 240], [235, 235, 240], [250, 120, 30]),
            'Furia': ([220, 30, 40], [240, 236, 226], [40, 60, 160]),
            'Blitz': ([240, 236, 226], [30, 32, 40], [220, 30, 40])}
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
