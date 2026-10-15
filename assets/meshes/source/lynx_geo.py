"""
Lynx (« lynx ») : petite compacte aux yeux de félin, inspirée de la 206 WRC.
Formes plus douces (épaules et toit chanfreinés, coins coupés larges),
phares en amande remontant vers le capot, grande bouche, ailes en bosses,
feux arrière hauts et verticaux.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.2, 5.45
    B.BUMPER_F, B.BUMPER_R = -5.4, 4.95
    B.HOOD_REAR, B.DECK_FRONT = -2.3, 4.85
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.4, 1.4
    B.HANDLES = (0.8,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.28, 1.4, 0.6
    B.NOSE_CUT, B.TAIL_CUT = (0.75, 0.8), (0.5, 0.5)
    B.SHOULDER = 0.25
    B.EXTRA_Z = (5.1,)
    B.top_y = L.make_top_y(B, nose=0.22, bumper=0.45, hood_rear=0.62, deck=0.94, tail=0.7, brk=5.1)
    B.CABIN = dict(yb=0.6, yr=2.3, hwb=2.38, hwr=1.98, zf_top=-0.6, zr_top=4.1, zr_base=B.DECK_FRONT + 0.02, ch=0.3,
                   us=[0.0, 0.12, 0.58, 0.64, 0.84, 0.9, 1.0])
    B.TAIL_GARNISH = (-1.2, 1.2, -0.6, -0.25)
    B.LAMP_Y = -0.75

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Grande bouche noire (octogone large)
        mouth = [(-1.2, -0.25), (1.2, -0.25), (1.6, -0.5), (1.6, -0.95), (1.2, -1.15), (-1.2, -1.15), (-1.6, -0.95), (-1.6, -0.5)]
        b.face('Grille', 'Trim', [(x, y, fz) for x, y in mouth])
        for s in (1, -1):
            # phares en amande, qui remontent vers le capot
            b.face('Headlight_' + L.side(s), 'Head', [(s * 0.6, -0.12, fz - 0.02), (s * 1.3, 0.04, fz - 0.02), (s * 1.92, 0.16, fz - 0.02), (s * 1.75, -0.12, fz - 0.02), (s * 1.0, -0.3, fz - 0.02)])
            b.disc('FogLight_' + L.side(s), 'Lamp', (s * 1.2, -0.7, fz - 0.05), 0.17, 0.06, 'z', n=8)
            # feux arrière hauts et verticaux
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.7 - 0.25, s * 1.7 + 0.25, -0.15, 0.6, tz)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.2)
        L.rear_common(b, B, exhaust_x=-1.3, plate_y=0.3)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 3.95, 5.25, 2.42, 2.35, blades=1, plates=True, post=0.25)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
