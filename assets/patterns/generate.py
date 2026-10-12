# Génère les motifs de carrosserie (Livery.PATTERNS) : images blanches sur fond
# transparent, 512 x 512, qui se raccordent quand elles se répètent.
# Usage : python3 assets/patterns/generate.py assets/patterns
import sys, numpy as np
from PIL import Image
OUT = sys.argv[1]
N = 1024  # suréchantillonné, réduit à 512
y, x = np.mgrid[0:N, 0:N] / N  # 0..1, périodique

def save(name, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.zeros((N, N, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").resize((512, 512), Image.LANCZOS).save(f"{OUT}/{name}.png", optimize=True)

def smooth(d, w=1.5 / N):
    return np.clip(0.5 - d / w, 0, 1)

def pnoise(seed, terms=24, maxf=5):
    rng = np.random.default_rng(seed)
    v = np.zeros_like(x)
    for _ in range(terms):
        fx, fy = rng.integers(-maxf, maxf + 1, 2)
        if fx == 0 and fy == 0:
            continue
        amp = 1 / np.hypot(fx, fy)
        v += amp * np.sin(2 * np.pi * (fx * x + fy * y) + rng.uniform(0, 2 * np.pi))
    return v / np.abs(v).max()

def wrapd(a, b):
    d = np.abs(a - b)
    return np.minimum(d, 1 - d)

# Damier : 2 x 2 cases.
save("damier", ((np.floor(x * 2) + np.floor(y * 2)) % 2 == 0).astype(float))

# Pois : quinconce.
d = np.minimum(np.hypot(wrapd(x, .25), wrapd(y, .25)), np.hypot(wrapd(x, .75), wrapd(y, .75)))
save("pois", smooth(d - 0.14))

# Hexagones (nid d'abeille, contours) : réseau périodique dans le carré.
def hexdist(px, py):
    # distance au bord de l'hexagone le plus proche, sur un réseau 2 x 2 (centres en quinconce)
    best = np.full(px.shape, 9.0)
    second = np.full(px.shape, 9.0)
    centers = [(i / 2 + (j % 2) / 4, j / 2) for i in range(-1, 4) for j in range(-1, 4)]
    for cx, cy in centers:
        dd = np.hypot(px - cx, (py - cy) * 0.866)
        second = np.where(dd < best, best, np.minimum(second, dd))
        best = np.minimum(best, dd)
    return second - best
save("hexagones", smooth(hexdist(x, y) - 0.025, 3 / N))

# Carbone : sergé 2/2, chaque brin en dégradé.
cells = 8
cx, cy = (x * cells) % 1, (y * cells) % 1
ix, iy = np.floor(x * cells), np.floor(y * cells)
horizontal = ((ix + iy) // 2) % 2 == 0
shade = np.where(horizontal, np.sin(np.pi * cy), np.sin(np.pi * cx))
save("carbone", 0.35 + 0.55 * shade)

# Camouflage : deux nappes de taches.
n1, n2 = pnoise(3), pnoise(11)
big = np.clip((n1 - 0.15) * 60, 0, 1)
save("camouflage", np.maximum(big, 0.55 * np.clip((n2 - 0.1) * 60, 0, 1) * (1 - big)))

# Zébrures : bandes déformées par un bruit.
warp = pnoise(7, maxf=3)
save("zebrures", np.clip((np.sin(2 * np.pi * (3 * x + 0.35 * warp)) - 0.15) * 6, 0, 1))

# Flammes : des langues qui montent depuis le bas de la tuile.
h = 0.45 + 0.18 * np.sin(2 * np.pi * 4 * x) + 0.12 * np.sin(2 * np.pi * 7 * x + 1.3) + 0.06 * np.sin(2 * np.pi * 13 * x + 0.4)
up = 1 - y
flame = smooth(up - h, 3 / N)
inner = smooth(up - (h - 0.12), 3 / N)
line = smooth(np.abs(up - (h - 0.1)) - 0.008, 3 / N)
save("flammes", flame * (1 - 0.7 * line))

# Sakura : fleurs à cinq pétales semées au hasard (raccord aux bords).
rng = np.random.default_rng(5)
alpha = np.zeros_like(x)
for _ in range(9):
    fx, fy, r, rot = rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0.05, 0.085), rng.uniform(0, 2 * np.pi)
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            dx, dy = x - fx - ox, y - fy - oy
            rr = np.hypot(dx, dy)
            th = np.arctan2(dy, dx) + rot
            petal = r * (0.55 + 0.45 * np.abs(np.cos(2.5 * th)))
            alpha = np.maximum(alpha, smooth(rr - petal, 3 / N) * (1 - 0.6 * smooth(rr - r * 0.18, 3 / N)))
save("sakura", alpha)
print("ok")
