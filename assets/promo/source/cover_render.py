import sys, numpy as np
from PIL import Image, ImageFilter
import json
cfg = json.loads(sys.argv[1])
out, mode = cfg['out'], cfg['mode']
livery = np.array(cfg.get('livery', [236, 160, 210]), float) / 255
cam_eye = np.array(cfg.get('eye', [-15.0, 4.0, -17.0]), float)
anime = mode in ('anime', 'sketch')
sketch = mode == 'sketch'
rim_color = np.array(cfg.get('rim', [238, 238, 242]), float) / 255
pattern = None
if cfg.get('pattern'):
    pattern = np.array(Image.open(cfg['pattern']).convert('RGBA'), float)[..., 3] / 255
pattern_color = np.array(cfg.get('pattern_color', [40, 30, 60]), float) / 255
tile = cfg.get('tile', 4.0)
SS = cfg.get('ss', 2)
W, H = cfg.get('size', [960, 600])[0] * SS, cfg.get('size', [960, 600])[1] * SS
PAINT = {'Trim': (28, 29, 33), 'Glass': (22, 30, 46), 'Head': (255, 250, 232), 'Tail': (255, 38, 52),
         'Lamp': (255, 232, 150), 'Chrome': (200, 205, 215), 'Accent': (220, 30, 40)}
EMISSIVE = {'Head', 'Tail', 'Lamp'}

tris = []  # (v0,v1,v2, color, kind, center)
BODYPAINT = []
def add_shape(verts, faces, color, kind, body=False):
    c = verts.mean(0)
    for f in faces:
        for i in range(1, len(f) - 1):
            tris.append((verts[f[0]], verts[f[i]], verts[f[i + 1]], color, kind, c))
            BODYPAINT.append(body)

def box_geo(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = np.array([[i, j, k] for i in (-x, x) for j in (-y, y) for k in (-z, z)])
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return v, faces

def wedge_geo(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    # bas complet, face arrière (+Z) complète, pente de (bas, avant) à (haut, arrière)
    v = np.array([[-x, -y, -z], [x, -y, -z], [-x, -y, z], [x, -y, z], [-x, y, z], [x, y, z]])
    faces = [[0, 1, 3, 2], [2, 3, 5, 4], [0, 4, 5, 1], [0, 2, 4], [1, 5, 3]]
    return v, faces

def cyl_geo(sx, sy, sz, n=18):
    r = sy / 2; h = sx / 2
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    ring = np.stack([np.cos(a) * r, np.sin(a) * r], 1)
    v = np.array([[-h, p[0], p[1]] for p in ring] + [[h, p[0], p[1]] for p in ring])
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    return v, faces

def sphere_geo(d, n=16, m=10):
    r = d / 2
    v = [[0, r, 0]]
    for i in range(1, m):
        ph = np.pi * i / m
        for j in range(n):
            th = 2 * np.pi * j / n
            v.append([r * np.sin(ph) * np.cos(th), r * np.cos(ph), r * np.sin(ph) * np.sin(th)])
    v.append([0, -r, 0]); v = np.array(v); b = len(v) - 1
    ring = lambda i, j: 1 + (i - 1) * n + (j % n)
    f = [[0, ring(1, j + 1), ring(1, j)] for j in range(n)]
    f += [[ring(i, j), ring(i, j + 1), ring(i + 1, j + 1), ring(i + 1, j)] for i in range(1, m - 1) for j in range(n)]
    f += [[b, ring(m - 1, j), ring(m - 1, j + 1)] for j in range(n)]
    return v, f

def upright_cyl(height, diameter, base):
    v, f = cyl_geo(height, diameter, diameter, 14)
    v = v[:, [1, 0, 2]]  # axe X -> Y
    return v + np.array(base) + np.array([0, height / 2, 0]), f

DECOR_KINDS = []
def decor_add(v, f, color):
    add_shape(v, f, np.array(color) / 255, 'decor')

for obj in cfg.get('decor', []):
    kind, p = obj['kind'], np.array(obj['at'], float)
    for part in obj['parts']:
        if part[0] == 'ball':
            v, f = sphere_geo(part[1]); decor_add(v + p + np.array(part[2]), f, part[3])
        elif part[0] == 'cone':
            # cône : hauteur, diamètre de base, base, couleur (8 pans, façon low poly)
            h, d, base = part[1], part[2], np.array(part[3]) + p
            n = 8; a = np.linspace(0, 2 * np.pi, n, endpoint=False) + 0.3
            v = np.array([[np.cos(t) * d / 2, 0, np.sin(t) * d / 2] for t in a] + [[0, h, 0]]) + base
            f = [list(range(n))[::-1]] + [[i, (i + 1) % n, n] for i in range(n)]
            decor_add(v, f, part[4])
        else:
            v, f = upright_cyl(part[1], part[2], p + np.array(part[3])); decor_add(v, f, part[4])

PANEL = []
OWN_N = []
for pi, p in enumerate(json.load(open(cfg['mesh']))):
    V = np.array(p['verts'], float)
    paint = p['paint']
    color = livery if paint == 'Body' else np.array(PAINT[paint]) / 255
    if p.get('color'):
        color = np.array(p['color']) / 255
    kind = 'emissive' if paint in EMISSIVE else ('glass' if paint == 'Glass' else ('chrome' if paint == 'Chrome' else 'paint'))
    for f in p['faces']:
        for i in range(1, len(f) - 1):
            a0, a1, a2 = V[f[0]], V[f[i]], V[f[i + 1]]
            tris.append((a0, a1, a2, color, kind, None)); BODYPAINT.append(paint == 'Body'); PANEL.append(pi)
# Roues (du gabarit) : pneu, jante blanche.
for sx in (-1, 1):
    for z in (-4.05, 4.05):
        v, f = cyl_geo(0.95, 2.16, 2.16, 24)
        add_shape(v + np.array([sx * 2.58, -1.02, z]), f, np.array([0.08, 0.08, 0.09]), 'paint'); PANEL.extend([-1] * (len(tris) - len(PANEL)))
        v, f = cyl_geo(0.06, 1.4, 1.4, 24)
        add_shape(v + np.array([sx * (2.58 + 0.47), -1.02, z]), f, rim_color, 'paint'); PANEL.extend([-1] * (len(tris) - len(PANEL)))
        v, f = cyl_geo(0.07, 0.4, 0.4, 12)
        add_shape(v + np.array([sx * (2.58 + 0.5), -1.02, z]), f, np.array([0.3, 0.3, 0.33]), 'paint'); PANEL.extend([-1] * (len(tris) - len(PANEL)))

T = len(tris)
V0 = np.array([t[0] for t in tris]); V1 = np.array([t[1] for t in tris]); V2 = np.array([t[2] for t in tris])
COL = np.array([t[3] for t in tris]); KIND = [t[4] for t in tris]
N = np.cross(V1 - V0, V2 - V0); N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
# Roues (cylindres) : orientées depuis leur axe
for i, t in enumerate(tris):
    if t[5] is not None and np.dot(N[i], (t[0] + t[1] + t[2]) / 3 - t[5]) < 0:
        N[i] *= -1
PANEL = np.array(PANEL)

def raster(P0, P1, P2, w, h, depth_of, near=None):
    # P* : (x, y, depth) écran ; renvoie z-buffer et identifiant de triangle
    zb = np.full((h, w), np.inf); ids = np.full((h, w), -1, int)
    for i in range(len(P0)):
        a, b, c = P0[i], P1[i], P2[i]
        if near is not None and min(a[2], b[2], c[2]) < near:
            continue
        if not (np.isfinite(a).all() and np.isfinite(b).all() and np.isfinite(c).all()):
            continue
        xmin = int(max(0, np.floor(min(a[0], b[0], c[0])))); xmax = int(min(w - 1, np.ceil(max(a[0], b[0], c[0]))))
        ymin = int(max(0, np.floor(min(a[1], b[1], c[1])))); ymax = int(min(h - 1, np.ceil(max(a[1], b[1], c[1]))))
        if xmin > xmax or ymin > ymax:
            continue
        xs, ys = np.meshgrid(np.arange(xmin, xmax + 1) + 0.5, np.arange(ymin, ymax + 1) + 0.5)
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        l0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        l1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        l2 = 1 - l0 - l1
        m = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not m.any():
            continue
        z = depth_of(l0, l1, l2, a, b, c)
        sub = zb[ymin:ymax + 1, xmin:xmax + 1]; sid = ids[ymin:ymax + 1, xmin:xmax + 1]
        upd = m & (z < sub)
        sub[upd] = z[upd]; sid[upd] = i
    return zb, ids

# Caméra
target = np.array(cfg.get('target', [0.0, -0.4, 0.3]), float)
fw = target - cam_eye; fw /= np.linalg.norm(fw)
rt = np.cross(fw, [0, 1, 0]); rt /= np.linalg.norm(rt)
up = np.cross(rt, fw)
fpx = (W / 2) / np.tan(np.radians(cfg.get('fov', 19)))
def to_cam(P):
    d = P - cam_eye
    return np.stack([d @ rt, d @ up, d @ fw], -1)
def project(P):
    c = to_cam(P)
    return np.stack([W / 2 + c[..., 0] / c[..., 2] * fpx, H / 2 - c[..., 1] / c[..., 2] * fpx, c[..., 2]], -1)
persp = lambda l0, l1, l2, a, b, c: 1 / (l0 / a[2] + l1 / b[2] + l2 / c[2])
zb, ids = raster(project(V0), project(V1), project(V2), W, H, persp, near=0.5)

# Rayons de chaque pixel, position monde
xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
dirs = (rt[None, None] * ((xs - W / 2) / fpx)[..., None] + up[None, None] * (-(ys - H / 2) / fpx)[..., None] + fw[None, None])
GROUND = -2.1
car = ids >= 0
t_ground = (GROUND - cam_eye[1]) / dirs[..., 1]
ground = (~car) & (t_ground > 0)
world = np.where(car[..., None], cam_eye + dirs * zb[..., None], cam_eye + dirs * t_ground[..., None])

# Soleil et ombres (carte d'ombre orthographique)
if anime:
    L = np.array([0.55, 0.75, -0.4]); sun = np.array([255, 226, 190]) / 255 * 1.1
    amb = np.array([128, 106, 168]) / 255 * 0.85
else:
    L = np.array([0.25, 1.0, 0.35]); sun = np.array([1.0, 1.0, 0.98]) * 0.75
    amb = np.array([0.5, 0.5, 0.5]) * 0.75
L = L / np.linalg.norm(L)
lr = np.cross(L, [0, 0, 1]); lr /= np.linalg.norm(lr); lu = np.cross(lr, L)
SM = 2400; scale = SM / cfg.get('shadow_extent', 30.0)
def to_light(P):
    return np.stack([SM / 2 + (P @ lr) * scale, SM / 2 - (P @ lu) * scale, -(P @ L)], -1)
lin = lambda l0, l1, l2, a, b, c: l0 * a[2] + l1 * b[2] + l2 * c[2]
smz, _ = raster(to_light(V0), to_light(V1), to_light(V2), SM, SM, lin)
lp = to_light(world)
lx = np.clip(lp[..., 0].astype(int), 0, SM - 1); ly = np.clip(lp[..., 1].astype(int), 0, SM - 1)
lit = lp[..., 2] <= smz[ly, lx] + 0.8

# Ciel
hor = np.clip(dirs[..., 1] / np.linalg.norm(dirs, axis=-1), -0.2, 0.6)
if anime:
    top, low = np.array([150, 110, 200]) / 255, np.array([255, 196, 180]) / 255
else:
    top, low = np.array([150, 185, 225]) / 255, np.array([215, 225, 235]) / 255
tt = np.clip(hor / 0.45, 0, 1)[..., None]
img = low * (1 - tt) + top * tt
if cfg.get('sky'):
    side = np.array(Image.open(cfg['sky'] + '_side.png').convert('RGB'), float) / 255
    upimg = np.array(Image.open(cfg['sky'] + '_up.png').convert('RGB'), float) / 255
    dn = dirs / np.linalg.norm(dirs, axis=-1, keepdims=True)
    az = np.arctan2(dn[..., 0], dn[..., 2])
    fold = (az % (np.pi / 2)); fold = np.where(fold > np.pi / 4, fold - np.pi / 2, fold)
    horiz = np.sqrt(dn[..., 0] ** 2 + dn[..., 2] ** 2)
    u = np.tan(fold); vv = dn[..., 1] / np.maximum(horiz, 1e-6) * np.sqrt(1 + u ** 2)
    Ns = side.shape[0]
    px = np.clip(((u + 1) / 2 * (Ns - 1)).astype(int), 0, Ns - 1); py = np.clip(((1 - vv) / 2 * (Ns - 1)).astype(int), 0, Ns - 1)
    skycol = side[py, px]
    upm = vv > 1
    ux = dn[..., 0] / np.maximum(dn[..., 1], 1e-6); uz = dn[..., 2] / np.maximum(dn[..., 1], 1e-6)
    qx = np.clip(((ux + 1) / 2 * (Ns - 1)).astype(int), 0, Ns - 1); qy = np.clip(((uz + 1) / 2 * (Ns - 1)).astype(int), 0, Ns - 1)
    skycol = np.where(upm[..., None], upimg[qy, qx], skycol)
    img = skycol
    low = side[int(Ns * 0.5), Ns // 2]

# Sol texturé
tex = np.array(Image.open(cfg['ground']).convert('RGB'), float) / 255
TS = 10.0
u = ((world[..., 0] / TS) % 1 * (tex.shape[1] - 1)).astype(int); v = ((world[..., 2] / TS) % 1 * (tex.shape[0] - 1)).astype(int)
gcol = tex[v, u]
if cfg.get('ground2'):
    tex2 = np.array(Image.open(cfg['ground2']).convert('RGB'), float) / 255
    gcol2 = tex2[v, u]
    ra = np.radians(cfg.get('road_angle', 0.0))
    road = np.abs(world[..., 0] * np.cos(ra) - world[..., 2] * np.sin(ra)) < cfg.get('road_half', 9)
    gcol = np.where(road[..., None], gcol, gcol2)
if anime:
    gshade = np.where(lit[..., None], sun * 0.62 + amb * 0.55, amb * 0.95)
    gsh = gcol * gshade
else:
    soft = np.array(Image.fromarray((lit * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14 * SS)), float)[..., None] / 255
    gsh = gcol * (amb + sun * soft * 0.9)
# brume au loin
dist = np.linalg.norm(world - cam_eye, axis=-1)
fog = np.clip((dist - 30) / 90, 0, 1)[..., None]
gsh = gsh * (1 - fog) + low * fog
img = np.where(ground[..., None], gsh, img)

# Voiture
tid = np.where(car, ids, 0)
n = N[tid]; base = COL[tid]
ndl = np.clip(np.einsum('ijk,k->ij', n, L), 0, 1)
kind = np.array([{'paint': 0, 'emissive': 1, 'glass': 2, 'chrome': 3, 'decor': 4}[k] for k in KIND])[tid]
if anime:
    light = amb[None, None] + sun[None, None] * (ndl * lit)[..., None] * 0.95
else:
    sl = (ndl * np.where(lit, 1.0, 0.45))[..., None]
    light = amb[None, None] + sun[None, None] * sl
ccol = base * light
view = -dirs / np.linalg.norm(dirs, axis=-1, keepdims=True)
fres = (1 - np.clip(np.einsum('ijk,ijk->ij', n, view), 0, 1)) ** 3
skyref = top * 0.7 + low * 0.3
spec_amt = 0.55 if anime else 0.2
ccol = np.where((kind == 2)[..., None], base * light * 0.6 + skyref * (0.18 + fres[..., None] * spec_amt), ccol)
ccol = np.where((kind == 3)[..., None], skyref * 0.55 + base * light * 0.5, ccol)
ccol = np.where((kind == 1)[..., None], base * 1.15, ccol)
# Motif de carrosserie (Texture répétée sur chaque face, comme LiveryPainter)
if pattern is not None:
    isbody = np.array(BODYPAINT)[tid] & car & (kind == 0)
    an = np.abs(n)
    ax = np.argmax(an, -1)
    uu = np.where(ax == 0, world[..., 2], world[..., 0])
    vv = np.where(ax == 1, world[..., 2], world[..., 1])
    P = pattern.shape[0]
    pu = ((uu / tile) % 1 * (P - 1)).astype(int); pv = ((vv / tile) % 1 * (P - 1)).astype(int)
    pa = pattern[pv, pu] * 0.9
    pcol = pattern_color * light
    ccol = np.where(isbody[..., None], ccol * (1 - pa[..., None]) + pcol * pa[..., None], ccol)
img = np.where(car[..., None], ccol, img)

if anime:
    # Étalonnage : saturation et contraste (ColorCorrection de l'ambiance)
    lum = (img * np.array([0.299, 0.587, 0.114])).sum(-1, keepdims=True)
    img = lum + (img - lum) * 1.28
    img = (img - 0.5) * 1.14 + 0.5 + 0.02
    # Coques inversées du décor : un trait là où une pièce de décor se
    # détache de ce qui est derrière (saut de profondeur).
    if cfg.get('hulls'):
        isdec = car & (kind == 4)
        zc = np.where(car, zb, 1e4)
        hull = np.zeros((H, W), bool)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            o_z = np.roll(np.roll(zc, dy, 0), dx, 1); o_dec = np.roll(np.roll(isdec, dy, 0), dx, 1)
            o_id = np.roll(np.roll(ids, dy, 0), dx, 1)
            hull |= o_dec & (o_id != ids) & (zc > o_z + 0.35)
        hull = np.array(Image.fromarray((hull * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), float) > 127
        img[hull] = np.array([24, 16, 40]) / 255
    # Contour d'encre (Highlight) : bord de la silhouette
    carmask = car & (kind != 4) if 'decor' in cfg else car
    mask = Image.fromarray((carmask * 255).astype(np.uint8))
    grown = np.array(mask.filter(ImageFilter.MaxFilter(2 * 2 * SS + 1)), float) / 255
    edge = (grown > 0.5) & ~carmask
    img[edge] = np.array([24, 16, 40]) / 255
    # Jointures des panneaux (coque inversée de chaque pièce)
    pid = np.where(car, PANEL[np.where(car, ids, 0)], -2)
    seam = np.zeros((H, W), bool)
    for dy, dx in ((0, 1), (1, 0)):
        o = np.roll(np.roll(pid, dy, 0), dx, 1)
        seam |= (o != pid) & (o >= -1) & (pid >= -1) & car & np.roll(np.roll(car, dy, 0), dx, 1)
    seam = np.array(Image.fromarray((seam * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), float) > 127
    if cfg.get('seams'): img[seam] = img[seam] * 0.35 + np.array([24, 16, 40]) / 255 * 0.65
    # Halo des feux (Bloom)
    glow = np.where((car & (kind == 1))[..., None], np.clip(img, 0, 1), 0)
    g = np.array(Image.fromarray((glow * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10 * SS)), float) / 255
    img = img + g * 0.9

if sketch:
    def noise(sigma, seed, h=H, w=W):
        r = np.random.default_rng(seed).standard_normal((h // 4, w // 4))
        im = Image.fromarray(((r - r.min()) / (r.max() - r.min()) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        im = im.filter(ImageFilter.GaussianBlur(sigma))
        a = np.array(im, float); return (a - a.mean()) / (a.std() + 1e-6)
    # Arêtes : changement de pièce avec saut de profondeur ou de pente, et silhouette.
    idp = np.pad(ids, 1, mode='edge'); zp = np.pad(np.where(car, zb, 1e4), 1, mode='edge')
    npd = np.pad(n * car[..., None], ((1, 1), (1, 1), (0, 0)), mode='edge')
    edge = np.zeros((H, W), bool)
    for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
        o_id = idp[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
        o_z = zp[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
        o_n = npd[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
        zc = np.where(car, zb, 1e4)
        jump = np.abs(o_z - zc) > 0.04 * np.minimum(o_z, zc)
        crease = (o_n * n).sum(-1) < 0.8
        edge |= (o_id != ids) & (jump | crease) & (car | (o_id >= 0))
    dark = np.zeros((H, W))
    yy, xx = np.mgrid[0:H, 0:W]
    for p in range(2):
        jx = (noise(6 * SS, 30 + p) * 1.6 * SS).astype(int); jy = (noise(6 * SS, 40 + p) * 1.6 * SS).astype(int)
        shifted = edge[np.clip(yy + jy, 0, H - 1), np.clip(xx + jx, 0, W - 1)]
        strength = np.clip(0.55 + 0.3 * noise(30 * SS, 50 + p), 0.25, 1.0)
        dark = np.maximum(dark, shifted * strength * (0.85 if p == 0 else 0.5))
    dark = np.array(Image.fromarray((dark * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), float) / 255
    # Hachures dans les ombres (voiture et sol), croisées dans les plus sombres.
    shade = np.where(car, 1 - np.clip(ndl * lit, 0, 1), np.where(ground & ~lit, 1.0, 0.0))
    spacing = 7.0 * SS
    wob = noise(12 * SS, 60) * 0.25
    h1 = (((xx - yy) / spacing + wob) % 1) < 0.16
    h2 = (((xx + yy) / spacing + wob) % 1) < 0.14
    gate = noise(18 * SS, 70) > -0.2
    hatch = (h1 & (shade > np.where(car, 0.75, 0.55)) & gate) * 0.45 + (h2 & (shade > 0.85) & gate & ~car) * 0.3
    dark = np.maximum(dark, hatch)
    graphite = np.array([62, 58, 74]) / 255
    img = img * (1 - dark[..., None]) + graphite * dark[..., None] * img.mean(-1, keepdims=True) * 0.6 + graphite * dark[..., None] * 0.25
    # Grain du papier
    img = img * (1 - 0.035 * np.clip(noise(0.6, 80), -2, 2)[..., None])

img = np.clip(img, 0, 1)
im = Image.fromarray((img * 255).astype(np.uint8)).resize((W // SS, H // SS), Image.LANCZOS)
im.save(out)
print('ok', out)
