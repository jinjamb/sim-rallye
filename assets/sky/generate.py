# Génère les ciels dessinés (client/World/Ambiances.luau : SKIES), style anime :
# dégradé lisse, nuages en aplats (corps clair, dessous ombré, liseré),
# une bande de nuages lointains. Trois images par ciel : un côté (le même sur les
# quatre faces Bk, Ft, Lf, Rt), le dessus (Up) et le dessous (Dn).
# Le dessin ne dépend que de la hauteur et d'un angle replié tous les 90°
# (symétrique) : les faces se raccordent quel que soit leur sens dans Roblox.
# Usage : python3 assets/sky/generate.py assets/sky
import sys, numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
N = 1024
SS = 2  # suréchantillonnage (bords nets mais lissés)
M = N * SS

SKIES = {
    'couchant': dict(
        stops=[(-0.1, (120, 84, 150)), (0.0, (255, 200, 170)), (0.12, (250, 160, 185)), (0.35, (186, 120, 200)), (0.75, (96, 76, 168)), (1.0, (70, 58, 140))],
        cloud=(255, 214, 220), shade=(206, 140, 196), rim=(255, 240, 220), ink=(120, 70, 140),
        ground=(92, 70, 120)),
    'jour': dict(
        stops=[(-0.1, (150, 170, 210)), (0.0, (214, 234, 252)), (0.15, (160, 206, 248)), (0.45, (96, 160, 238)), (1.0, (56, 116, 214))],
        cloud=(255, 255, 255), shade=(186, 196, 236), rim=(255, 255, 255), ink=(110, 130, 190),
        ground=(120, 140, 170)),
}


def face_dirs(face):
    u, v = np.meshgrid(np.linspace(-1, 1, M), np.linspace(1, -1, M))
    if face == 'side':
        return u, v, np.ones_like(u)
    if face == 'up':
        return u, np.ones_like(u), v
    return u, -np.ones_like(u), v


def gradient(elev, stops):
    t = np.clip(elev / (np.pi / 2), -0.1, 1.0)
    out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        a = ((t - t0) / (t1 - t0))[m][:, None]
        out[m] = np.array(c0) * (1 - a) + np.array(c1) * a
    return out


def clouds(az, elev):
    """Masque des nuages : une rangée de cumulus (bosses rondes) posée sur
    une base plate, et l'ombre de leur dessous. az : angle replié 0..45°."""
    e = np.degrees(elev)
    a = np.degrees(az)
    # Bosses : cercles le long de l'horizon (angle replié : symétrique).
    bumps = [(3, 8.0, 6.0), (12, 13.0, 8.5), (21, 9.0, 6.0), (30, 16.0, 10.0), (41, 10.5, 7.0)]
    top = np.full(e.shape, -90.0)
    for ca, ce, r in bumps:
        dx = a - ca
        inside = r ** 2 - dx ** 2
        top = np.maximum(top, np.where(inside > 0, ce + np.sqrt(np.clip(inside, 0, None)) * 0.55, -90))
    base = 3.0
    body = (e > base) & (e < top)
    shade = body & (e < base + (top - base) * 0.38)
    # Second rang, plus haut et plus fin (nuages lointains en bande).
    band = (e > 22) & (e < 24.5 + 1.8 * np.sin(np.radians(a) * 8) ** 2)
    return body, shade, band


def render(name, cfg):
    out = {}
    for face in ('side', 'up', 'down'):
        x, y, z = face_dirs(face)
        horiz = np.sqrt(x ** 2 + z ** 2)
        elev = np.arctan2(y, horiz)
        az = np.arctan2(x, z) % (np.pi / 2)
        az = np.abs(az - np.pi / 4)  # replié : 0 (milieu d'une face) .. 45°
        az = np.pi / 4 - az
        img = gradient(elev, cfg['stops'])
        body, shade, band = clouds(az, elev)
        img[band] = img[band] * 0.35 + np.array(cfg['cloud']) * 0.65
        img[body] = cfg['cloud']
        img[shade] = cfg['shade']
        # Liseré d'encre autour des nuages (trait fin, adouci).
        mask = Image.fromarray((body * 255).astype(np.uint8))
        grown = np.array(mask.filter(ImageFilter.MaxFilter(5)), float) > 127
        edge = grown & ~body
        img[edge] = np.array(cfg['ink'])
        if face == 'down':
            img[:] = cfg['ground']
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)
        im.save(f'{OUT}/{name}_{face}.png', optimize=True)
        out[face] = im
    return out


for name, cfg in SKIES.items():
    render(name, cfg)
print('ciels :', ', '.join(SKIES))
