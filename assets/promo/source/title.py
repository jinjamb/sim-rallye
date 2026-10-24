"""Titre façon affiche de jeu Roblox, posé sur le rendu."""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
src, out = sys.argv[1], sys.argv[2]
FONT = '/usr/share/fonts/opentype/inter/InterDisplay-BlackItalic.otf'
img = Image.open(src).convert('RGBA')
W, H = img.size
k = W / 1920
RED, BLACK, WHITE = (226, 28, 40), (14, 14, 18), (255, 255, 255)

layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
d = ImageDraw.Draw(layer)

def text_block(x, y, text, size, fill, stroke, stroke_w, shadow=None, skew=0.0):
    f = ImageFont.truetype(FONT, int(size * k))
    box = d.textbbox((0, 0), text, font=f, stroke_width=int(stroke_w * k))
    w, h = box[2] - box[0], box[3] - box[1]
    t = Image.new('RGBA', (w + int(80 * k), h + int(80 * k)), (0, 0, 0, 0))
    td = ImageDraw.Draw(t)
    o = (int(40 * k) - box[0], int(40 * k) - box[1])
    if shadow:
        td.text((o[0] + int(10 * k), o[1] + int(12 * k)), text, font=f, fill=shadow, stroke_width=int(stroke_w * k), stroke_fill=shadow)
    td.text(o, text, font=f, fill=fill, stroke_width=int(stroke_w * k), stroke_fill=stroke)
    layer.alpha_composite(t, (int(x * k) - int(40 * k), int(y * k) - int(40 * k)))
    return w / k, h / k

# Traînées rouges derrière le titre (vitesse)
for i, (y, l, th) in enumerate([(120, 700, 20), (160, 560, 10), (318, 760, 24), (362, 540, 9)]):
    x0 = 1880 - l
    d.polygon([(x0 * k, y * k), ((x0 + l) * k, (y - th * 0.5) * k), ((x0 + l) * k, (y + th * 0.9) * k), ((x0 + 60) * k, (y + th) * k)],
              fill=RED + (235,))
    d.polygon([((x0 - 40) * k, (y + th * 0.3) * k), ((x0 + 120) * k, (y + th * 0.1) * k), ((x0 + 120) * k, (y + th * 0.5) * k)], fill=BLACK + (200,))

text_block(1250, 22, 'SIM', 130, WHITE, BLACK, 14, shadow=RED)
text_block(1100, 148, 'RALLYE!', 175, WHITE, BLACK, 16, shadow=RED)

# Bandeau noir : la promesse
f = ImageFont.truetype(FONT, int(42 * k))
msg = 'DÉRAPE. FONCE. PERSONNALISE.'
bw = d.textlength(msg, font=f) / k + 70
bx, by = 1880 - bw, 385
d.polygon([((bx + 18) * k, by * k), ((bx + bw + 18) * k, by * k), ((bx + bw) * k, (by + 66) * k), (bx * k, (by + 66) * k)], fill=BLACK + (240,), outline=WHITE + (255,), width=int(4 * k))
d.text(((bx + 36) * k, (by + 10) * k), msg, font=f, fill=WHITE)
# Bandeau rouge : le contenu
f2 = ImageFont.truetype(FONT, int(32 * k))
msg2 = '16 VOITURES · SPÉCIALES · RALLYCROSS'
bw2 = d.textlength(msg2, font=f2) / k + 60
bx2, by2 = 1880 - bw2, 462
d.polygon([((bx2 + 14) * k, by2 * k), ((bx2 + bw2 + 14) * k, by2 * k), ((bx2 + bw2) * k, (by2 + 52) * k), (bx2 * k, (by2 + 52) * k)], fill=RED + (245,), outline=BLACK + (255,), width=int(4 * k))
d.text(((bx2 + 30) * k, (by2 + 8) * k), msg2, font=f2, fill=WHITE)

# Ombre douce du bloc titre, pour qu'il ressorte du ciel
shadow = layer.split()[3].filter(ImageFilter.GaussianBlur(14 * k)).point(lambda a: a * 0.45)
dark = Image.new('RGBA', img.size, (10, 10, 20, 0)); dark.putalpha(shadow)
img.alpha_composite(dark)
img.alpha_composite(layer)
img.convert('RGB').save(out, quality=95)
