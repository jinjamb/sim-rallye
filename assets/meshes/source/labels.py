"""Planches légendées : nom du modèle et voiture d'inspiration sur chaque image."""
import sys
from PIL import Image, ImageDraw, ImageFont
B = sys.argv[1]
INFO = {
    'kaze': ('Kaze', 'voiture de départ · Rally4, Rally2, WRC'),
    'yama': ('Yama', 'berline des années 70 · Rally2, Groupe B'),
    'raijin': ('Raijin', 'coupé en coin des années 80 · Groupe B'),
    'hayate': ('Hayate', 'berline façon Evo · Rally2, WRC, Groupe B'),
    'hoshi': ('Hoshi', 'berline façon Impreza · Rally2, WRC'),
    'tora': ('Tora', 'citadine compacte · Rally4, Rally2, WRC, Groupe B'),
    'kumo': ('Kumo', 'bombe à moteur central · Groupe B'),
    'ryu': ('Ryu', 'long coupé des années 80 · Groupe B'),
    'tsubasa': ('Tsubasa', 'inspiration : Toyota Yaris WRC'),
    'requin': ('Requin', 'inspiration : Citroën DS3 WRC'),
    'lynx': ('Lynx', 'inspiration : Peugeot 206 WRC'),
    'griffe': ('Griffe', 'inspiration : Peugeot 208'),
    'furia': ('Furia', 'inspiration : Lancia Delta Integrale'),
    'blitz': ('Blitz', 'inspiration : Audi Quattro S1'),
    'fauve': ('Fauve', 'inspiration : Peugeot 205 T16'),
    'cuneo': ('Cuneo', 'inspiration : Lancia Stratos'),
}
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
REG = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def label(im, title, sub, scale=1.0):
    im = im.copy()
    d = ImageDraw.Draw(im, 'RGBA')
    ft = ImageFont.truetype(BOLD, int(46 * scale)); fs = ImageFont.truetype(REG, int(24 * scale))
    pad = int(18 * scale)
    w1 = d.textlength(title, font=ft); w2 = d.textlength(sub, font=fs)
    bw = int(max(w1, w2) + pad * 2); bh = int(46 * scale + 24 * scale + pad * 2.2)
    d.rectangle([0, 0, bw, bh], fill=(24, 16, 40, 225))
    d.text((pad, pad * 0.6), title, font=ft, fill=(255, 255, 255))
    d.text((pad, pad * 0.6 + 52 * scale), sub, font=fs, fill=(255, 205, 150))
    return im


def sheet(m):
    title, sub = INFO[m]
    ims = [Image.open(f'{B}/out/{m}_{n}.png') for n in ('avant34', 'profil', 'arriere34')]
    w, h = ims[0].size
    s = Image.new('RGB', (w * 3, h))
    for i, im in enumerate(ims):
        s.paste(im, (w * i, 0))
    s = label(s, title, sub, 1.3)
    return s.resize((w * 3 * 2 // 3, h * 2 // 3))


def grid(models, out, cols, title=None):
    heros = [label(Image.open(f'{B}/out/{m}_avant34.png'), *INFO[m]) for m in models]
    w, h = heros[0].size
    rows = (len(heros) + cols - 1) // cols
    top = 110 if title else 0
    g = Image.new('RGB', (w * cols, h * rows + top), (24, 16, 40))
    for i, im in enumerate(heros):
        g.paste(im, ((i % cols) * w, top + (i // cols) * h))
    if title:
        d = ImageDraw.Draw(g)
        d.text((30, 22), title, font=ImageFont.truetype(BOLD, 64), fill=(255, 255, 255))
    g.resize((w * cols // 2, (h * rows + top) // 2)).save(out)


if __name__ == '__main__' and sys.argv[2] == 'toutes':
    jeu = ['kaze', 'yama', 'raijin', 'hayate', 'hoshi', 'tora', 'kumo', 'ryu']
    legendes = ['tsubasa', 'requin', 'lynx', 'griffe', 'furia', 'blitz', 'fauve', 'cuneo']
    for m in jeu:
        sheet(m).save(f'{B}/out/{m}_planche.png')
    grid(jeu, f'{B}/out/toutes_jeu.png', 4, 'Les carrosseries des 32 voitures du jeu')
    grid(legendes, f'{B}/out/toutes_legendes.png', 4, 'Les modèles inspirés des légendes (garage)')
    a, c = Image.open(f'{B}/out/toutes_jeu.png'), Image.open(f'{B}/out/toutes_legendes.png')
    t = Image.new('RGB', (a.width, a.height + c.height), (24, 16, 40))
    t.paste(a, (0, 0)); t.paste(c, (0, a.height)); t.save(f'{B}/out/toutes.png')
elif __name__ == '__main__':
    models = sys.argv[2].split(',')
    for m in models:
        sheet(m).save(f'{B}/out/{m}_planche.png')
    heros = [label(Image.open(f'{B}/out/{m}_avant34.png'), *INFO[m]) for m in models]
    w, h = heros[0].size
    cols = 4 if len(heros) > 6 else 3
    rows = (len(heros) + cols - 1) // cols
    g = Image.new('RGB', (w * cols, h * rows), (24, 16, 40))
    for i, im in enumerate(heros):
        g.paste(im, ((i % cols) * w, (i // cols) * h))
    g.resize((w * cols // 2, h * rows // 2)).save(f'{B}/out/legendes.png')
