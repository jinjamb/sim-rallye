"""Scène de couverture : la voiture en dérapage sur une piste de terre en forêt."""
import json, sys, math, subprocess
import numpy as np
S = '/tmp/claude-0/-home-user-sim-rallye/623b93d1-8ecb-5d30-8896-9fae5fbb7e66/scratchpad'
C = S + '/cover'
model, size, ss, out = sys.argv[1], json.loads(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
KEEP_ACC = {'AccMudflaps', 'AccMudflapsBand', 'AccSkirt_R', 'AccSkirt_L', 'AccDiffuser'}
parts = [p for p in json.load(open(f'{S}/blender/{model.lower()}_full.json'))
         if not p['name'].startswith('Acc') or p['name'] in KEEP_ACC]
json.dump(parts, open(C + '/car.json', 'w'))

TH = math.radians(24)  # la piste tourne par rapport à la voiture : dérapage
u = np.array([math.sin(TH), 0, math.cos(TH)])   # sens de la piste (vers l'arrière de la voiture)
n = np.array([math.cos(TH), 0, -math.sin(TH)])  # travers de la piste
G = -2.1
rng = np.random.default_rng(7)
decor = []
def at(s, t, y=G):  # s : le long de la piste, t : en travers
    p = u * s + n * t; return [float(p[0]), y, float(p[2])]

# Forêt low poly des deux côtés
for side in (-1, 1):
    for k in range(60):
        s = rng.uniform(-60, 140)
        t = side * rng.uniform(13, 70)
        if s < 25 and abs(t) < 24:
            continue  # pas d'arbre près de la caméra : la place du titre
        h = rng.uniform(7, 14)
        green = [int(x) for x in rng.choice([[52, 140, 70], [40, 120, 62], [70, 160, 72], [30, 105, 70]])]
        if rng.random() < 0.6:  # sapin
            decor.append({'kind': 'tree', 'at': at(s, t), 'parts': [
                ['cyl', 1.5, 0.7, [0, 0, 0], [110, 72, 48]],
                ['cone', h * 0.55, h * 0.42, [0, 1.2, 0], green],
                ['cone', h * 0.45, h * 0.32, [0, 1.2 + h * 0.32, 0], green],
                ['cone', h * 0.3, h * 0.2, [0, 1.2 + h * 0.62, 0], green]]})
        else:  # feuillu
            decor.append({'kind': 'tree', 'at': at(s, t), 'parts': [
                ['cyl', h * 0.45, 0.8, [0, 0, 0], [120, 84, 56]],
                ['ball', h * 0.55, [0, h * 0.62, 0], green],
                ['ball', h * 0.38, [h * 0.18, h * 0.82, 0.4], [min(255, green[0] + 25), min(255, green[1] + 25), green[2]]]]})

# Poussière : nuage derrière les roues arrière, de plus en plus gros vers l'arrière
DUST = [[226, 196, 140], [238, 212, 160], [208, 172, 118], [244, 224, 182]]
for k in range(70):
    d = rng.uniform(0, 1) ** 0.8
    s = 4.5 + d * 22
    t = -rng.uniform(1.5, 5.5) - d * 7  # vers l'extérieur du virage (côté caméra)
    r = 1.2 + d * 4.5 + rng.uniform(0, 1.2)
    y = G + r * 0.35 + d * rng.uniform(0, 2.5)
    p = at(s, t, y)
    decor.append({'kind': 'dust', 'at': p, 'parts': [['ball', r, [0, 0, 0], [int(c) for c in DUST[k % 4]]]]})
# Gerbe basse, jetée vers l'extérieur du virage (vers la caméra)
for k in range(45):
    d = rng.uniform(0, 1)
    s = 3.0 + d * 9
    t = -3.5 - d * 9 - rng.uniform(0, 2.5)
    r = 0.8 + d * 2.6 + rng.uniform(0, 0.8)
    p = at(s, t, G + r * 0.3 + rng.uniform(0, 0.6))
    decor.append({'kind': 'dust', 'at': p, 'parts': [['ball', r, [0, 0, 0], [int(c) for c in DUST[(k + 1) % 4]]]]})
# Projections : cailloux qui volent
for k in range(40):
    s = rng.uniform(2, 12); t = -rng.uniform(3, 14)
    decor.append({'kind': 'rock', 'at': at(s, t, G + rng.uniform(0.2, 2.6)), 'parts': [['ball', rng.uniform(0.25, 0.6), [0, 0, 0], [92, 70, 56]]]})
# Panneau de virage (chevrons) au bord de la piste
cfg = dict(mesh=C + '/car.json', out=out, mode='anime', livery=json.loads(sys.argv[5]) if len(sys.argv) > 5 else [222, 30, 40],
           eye=json.loads(sys.argv[6]) if len(sys.argv) > 6 else [-10.5, 0.4, -15.5], target=json.loads(sys.argv[8]) if len(sys.argv) > 8 else [-4.5, 0.3, 3.0],
           fov=json.loads(sys.argv[7]) if len(sys.argv) > 7 else 24, size=size, ss=ss,
           ground=S + '/blender/tex/terre.png', ground2=C + '/herbe.png', road_half=10.5, road_angle=math.degrees(TH),
           sky='/home/user/sim-rallye/assets/sky/jour', rim=[255, 255, 255], decor=decor, shadow_extent=40.0)
subprocess.run(['python3', '-I', C + '/cover_render.py', json.dumps(cfg)], check=True)
