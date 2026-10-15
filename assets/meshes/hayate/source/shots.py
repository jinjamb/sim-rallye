import json, subprocess, sys
S = sys.argv[1]
shots = [
    ('avant34', 'hayate_full.json', [244, 240, 230], [-11.5, 2.4, -19], 'sable'),
    ('profil', 'hayate_base.json', [214, 40, 52], [-26, 1.2, 0.5], 'terre'),
    ('arriere34', 'hayate_full.json', [110, 200, 245], [13, 4.5, 19], 'asphalte'),
]
for name, mesh, liv, eye, ground in shots[int(sys.argv[2]):int(sys.argv[3])]:
    cfg = dict(mesh=S + '/' + mesh, out=S + '/out/hayate_' + name + '.png', mode='anime', livery=liv, eye=eye,
               ground=S + '/tex/' + ground + '.png', rim=[238, 238, 242])
    subprocess.run(['python3', '-I', S + '/render_mesh.py', json.dumps(cfg)], check=True)
