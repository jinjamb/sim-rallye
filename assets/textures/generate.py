# Génère les textures de sol style anime (World/ToonMaterials.luau) : aplats en
# trois tons, quelques détails dessinés et des traits au crayon à papier.
# Images 512 x 512 qui se raccordent quand elles se répètent.
# Usage : python3 assets/textures/generate.py assets/textures
import sys, numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
N = 512


def blur_noise(sigma, seed):
    # bruit lissé périodique (flou par FFT : les bords se raccordent)
    r = np.random.default_rng(seed).standard_normal((N, N))
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-(fx ** 2 + fy ** 2) * (2 * np.pi * sigma) ** 2 / 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(r) * g))
    return (out - out.mean()) / out.std()


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tones(field, cuts, colors):
    img = np.zeros((N, N, 3))
    img[:] = hexc(colors[0])
    for cut, col in zip(cuts, colors[1:]):
        img[field > cut] = hexc(col)
    return img


def draw_wrapped(img, fn, alpha=False):
    # dessine neuf fois (décalages d'une tuile) : les traits passent d'un bord à l'autre
    mode = 'RGBA' if alpha else 'RGB'
    im = Image.fromarray(img.astype(np.uint8), mode)
    d = ImageDraw.Draw(im, 'RGBA')
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            fn(d, ox, oy)
    return np.array(im).astype(float)


def pencil(img, seed, ink, field, amount=1.0):
    """Traits au crayon à papier : hachures courtes là où le ton est sombre,
    quelques traits de contour isolés ailleurs. Mélange en multiplication."""
    rng = np.random.default_rng(seed)
    layer = np.full((N, N, 3), 255.0)
    strokes = []
    # Hachures : petits paquets de traits parallèles, dans les zones sombres.
    for _ in range(int(55 * amount)):
        x, y = rng.integers(0, N, 2)
        if field[y % N, x % N] > 0.2:
            continue
        angle = np.radians(rng.uniform(35, 55))
        dx, dy = np.cos(angle), -np.sin(angle)
        count = rng.integers(3, 7)
        length = rng.uniform(10, 22)
        for k in range(count):
            ox = x + k * 4 * np.sin(angle) + rng.normal(0, 0.6)
            oy = y + k * 4 * np.cos(angle) + rng.normal(0, 0.6)
            l = length * rng.uniform(0.7, 1.1)
            strokes.append(((ox, oy), (ox + dx * l, oy + dy * l), rng.uniform(70, 130)))
    # Traits isolés, légèrement courbes : le crayon qui esquisse.
    for _ in range(int(30 * amount)):
        x, y = rng.integers(0, N, 2)
        angle = rng.uniform(0, np.pi)
        l = rng.uniform(14, 34)
        strokes.append(((x, y), (x + np.cos(angle) * l, y + np.sin(angle) * l), rng.uniform(50, 90)))

    def fn(d, ox, oy):
        for (a, b, alpha) in strokes:
            d.line([a[0] + ox, a[1] + oy, b[0] + ox, b[1] + oy], fill=ink + (int(alpha),), width=1)
    layer = draw_wrapped(layer, fn)
    return img * layer / 255


rng = np.random.default_rng(7)


def speckles(img, count, sizes, colors):
    pts = rng.integers(0, N, (count, 2))
    sz = rng.integers(sizes[0], sizes[1] + 1, count)

    def fn(d, ox, oy):
        for (x, y), s in zip(pts, sz):
            d.ellipse([x + ox - s, y + oy - s, x + ox + s, y + oy + s], fill=colors[(x + y) % len(colors)])
    return draw_wrapped(img, fn)


def tufts(img, count, ink):
    pts = rng.integers(0, N, (count, 2))

    def fn(d, ox, oy):
        for x, y in pts:
            x += ox; y += oy
            d.line([x - 7, y - 12, x, y], fill=ink, width=3)
            d.line([x + 7, y - 14, x, y], fill=ink, width=3)
            d.line([x, y - 16, x, y], fill=ink, width=3)
    return draw_wrapped(img, fn)


def pebbles(img, count, fill, ink, radius=(4, 9)):
    pts = rng.integers(0, N, (count, 2))
    rs = rng.integers(radius[0], radius[1], count)

    def fn(d, ox, oy):
        for (x, y), r in zip(pts, rs):
            x += ox; y += oy
            d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=fill, outline=ink, width=2)
    return draw_wrapped(img, fn)


def arcs(img, count, ink, size=14):
    pts = rng.integers(0, N, (count, 2))

    def fn(d, ox, oy):
        for x, y in pts:
            x += ox; y += oy
            d.arc([x - size, y - size * 0.43, x + size, y + size * 0.43], 200, 340, fill=ink, width=2)
    return draw_wrapped(img, fn)


def cracks(img, count, ink):
    lines = []
    for _ in range(count):
        x, y = rng.integers(0, N, 2).astype(float)
        pts = [(x, y)]
        angle = rng.uniform(0, 2 * np.pi)
        for _ in range(rng.integers(3, 6)):
            angle += rng.normal(0, 0.6)
            x += np.cos(angle) * rng.uniform(8, 18); y += np.sin(angle) * rng.uniform(8, 18)
            pts.append((x, y))
        lines.append(pts)

    def fn(d, ox, oy):
        for pts in lines:
            d.line([(px + ox, py + oy) for px, py in pts], fill=ink, width=2)
    return draw_wrapped(img, fn)


GRAPHITE = (72, 66, 86)
TEXTURES = {}

f = blur_noise(40, 1) + 0.35 * blur_noise(12, 2)
img = tones(f, [-0.2, 0.9], ['4a4560', '544f6c', '615b7a'])
img = speckles(img, 70, (2, 4), [(120, 114, 146), (40, 36, 54)])
TEXTURES['asphalte'] = pencil(img, 101, (40, 34, 56), f, 0.8)

f = blur_noise(45, 3) + 0.3 * blur_noise(15, 4)
img = tones(f, [-0.3, 0.8], ['3f9a52', '4fb15e', '66c46c'])
img = tufts(img, 90, (34, 110, 60))
TEXTURES['herbe'] = pencil(img, 102, (30, 70, 50), f)

f = blur_noise(38, 5) + 0.4 * blur_noise(10, 6)
img = tones(f, [-0.4, 0.7], ['a8724a', 'bd8656', 'd29d68'])
img = pebbles(img, 40, (226, 190, 140), (92, 56, 40))
TEXTURES['terre'] = pencil(img, 103, (80, 50, 40), f)

f = blur_noise(36, 9) + 0.5 * blur_noise(9, 10)
img = tones(f, [-0.3, 0.6], ['5e4433', '6e5040', '7f5f4a'])
img = arcs(img, 30, (60, 40, 30), 10)
TEXTURES['boue'] = pencil(img, 104, (40, 26, 20), f, 1.2)

f = blur_noise(50, 7) + 0.3 * blur_noise(16, 8)
img = tones(f, [-0.5, 0.6], ['c9d8f5', 'e2ebfb', 'f7f9ff'])
img = arcs(img, 35, (150, 172, 220))
TEXTURES['neige'] = pencil(img, 105, (110, 130, 190), f, 0.6)

f = blur_noise(55, 11) + 0.25 * blur_noise(18, 12)
img = tones(f, [-0.3, 0.7], ['9fc6ee', 'b8d8f6', 'd4e8fb'])
img = cracks(img, 14, (120, 160, 210))
TEXTURES['glace'] = pencil(img, 106, (90, 120, 180), f, 0.5)

f = blur_noise(30, 13) + 0.5 * blur_noise(8, 14)
img = tones(f, [-0.4, 0.5], ['6c6878', '7e7a8c', '948fa2'])
img = cracks(img, 22, (60, 56, 70))
TEXTURES['roche'] = pencil(img, 107, (44, 40, 56), f, 1.1)

f = blur_noise(48, 15) + 0.3 * blur_noise(14, 16)
img = tones(f, [-0.4, 0.7], ['d9b97c', 'e6c98e', 'f0d9a4'])
img = arcs(img, 26, (196, 160, 100), 12)
TEXTURES['sable'] = pencil(img, 108, (150, 110, 70), f, 0.6)

f = blur_noise(60, 17) + 0.2 * blur_noise(20, 18)
img = tones(f, [-0.2, 0.8], ['8c8796', '98939f', 'a5a0ad'])
img = cracks(img, 8, (90, 86, 100))
TEXTURES['beton'] = pencil(img, 109, (60, 56, 72), f, 0.7)

for name, tex in TEXTURES.items():
    Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).save(f'{OUT}/{name}.png', optimize=True)
print('textures :', ', '.join(TEXTURES))
