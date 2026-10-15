"""Outils communs aux modèles construits sur hayate_geo.py."""
import importlib
import math
import hayate_geo


def fresh():
    """Une construction remise à neuf (chaque modèle change les mesures)."""
    return importlib.reload(hayate_geo)


def make_top_y(B, nose, bumper, hood_rear, deck, tail, brk):
    """Ligne du dessus en segments : nez, capot, pied de lunette, coffre ou hayon."""
    def top_y(z):
        if z <= B.BUMPER_F:
            return nose + (bumper - nose) * (z - B.NOSE_Z) / (B.BUMPER_F - B.NOSE_Z)
        if z <= B.HOOD_REAR:
            return bumper + (hood_rear - bumper) * (z - B.BUMPER_F) / (B.HOOD_REAR - B.BUMPER_F)
        if z <= B.DECK_FRONT:
            return hood_rear + (deck - hood_rear) * (z - B.HOOD_REAR) / (B.DECK_FRONT - B.HOOD_REAR)
        if z <= brk:
            return deck
        return deck + (tail - deck) * (z - brk) / (B.TAIL_Z - brk)
    return top_y


def side(s):
    return 'R' if s > 0 else 'L'


def quad(b, name, paint, pts):
    b.face(name, paint, pts)


def front_rect(b, name, paint, x0, x1, y0, y1, z):
    b.face(name, paint, [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)])


def mirrors(b, B, y=None):
    y = B.top_y(B.HOOD_REAR + 0.6) if y is None else y
    for s in (1, -1):
        b.prism('Mirror_' + side(s), 'Body', [(s * (B.BODY_HW - 0.45), y), (s * B.BODY_HW, y + 0.04), (s * B.BODY_HW, y + 0.3), (s * (B.BODY_HW - 0.43), y + 0.28)][:: (1 if s > 0 else -1)],
                B.HOOD_REAR + 0.5, B.HOOD_REAR + 0.8)


def rear_common(b, B, exhaust_x=-1.4, plate_y=-0.35):
    tz = B.TAIL_Z + 0.03
    b.disc('Exhaust', 'Trim', (exhaust_x, -1.0, B.TAIL_Z - 0.25), 0.22, 0.4, 'z', n=8)
    front_rect(b, 'RearPanel', 'Trim', -0.8, 0.8, plate_y - 0.32, plate_y, tz)


def splitter(b, B, half=2.4):
    nz = B.NOSE_Z
    b.prism('Splitter', 'Trim', [(-half, -1.16), (half, -1.16), (half + 0.1, -1.08), (-half - 0.1, -1.08)][::-1], nz - 0.14, nz + 0.9)


def roof_wing(b, B, name, paint, z0, z1, y, half, blades=1, plates=True, post=0.0):
    """Aileron de toit (hayon) : lames sur le bord arrière du toit."""
    for k in range(blades):
        yy = y + k * 0.32
        b.prism(name + 'Blade' if paint == 'Body' else name, paint, [(-half, yy), (half, yy), (half, yy + 0.14), (-half, yy + 0.14)][::-1], z0 + k * 0.25, z1 + k * 0.1)
    if post > 0:
        for sx in (1, -1):
            b.prism(name, 'Trim', [(sx * (half - 0.9), y - post), (sx * (half - 0.7), y - post), (sx * (half - 0.7), y), (sx * (half - 0.9), y)][:: (1 if sx > 0 else -1)], z0 + 0.3, z1 - 0.2)
    if plates:
        for sx in (1, -1):
            b.prism(name, 'Trim', [(sx * half, y - 0.1), (sx * (half + 0.08), y - 0.1), (sx * (half + 0.08), y + 0.32 * blades + 0.02), (sx * half, y + 0.32 * blades + 0.02)][:: (1 if sx > 0 else -1)], z0 + 0.05, z1 + 0.1)


def build_with(configure, variant):
    B = fresh()
    configure(B)
    return B.build(variant)
