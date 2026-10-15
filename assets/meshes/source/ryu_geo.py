"""
Ryu (« dragon ») : long coupé bas des années 80. Très long capot, habitacle
reculé et bas, lunette fastback qui file jusqu'au coffre, arrière en queue
de canard, quatre phares ronds dans un bandeau noir, montants couleur
carrosserie.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -7.1, 6.35
    B.BUMPER_F, B.BUMPER_R = -6.1, 6.0
    B.HOOD_REAR, B.DECK_FRONT = -1.3, 5.3
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.9, 1.9
    B.HANDLES = (1.3,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.2, 1.45, 0.5
    B.NOSE_CUT, B.TAIL_CUT = (0.45, 0.6), (0.3, 0.35)
    B.SIDE_TAPER, B.CREASE = 0.15, 0.55
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.2, 2, 0.06
    B.NOSE_SEGS, B.ARCH_SEG = 2, 4
    B.PILLAR_PAINT = 'Body'
    B.ROCKER_H = 0.3
    B.EXTRA_Z = (5.75,)
    B.top_y = L.make_top_y(B, nose=0.12, bumper=0.38, hood_rear=0.55, deck=0.72, tail=0.95, brk=5.75)
    B.CABIN = dict(yb=0.55, yr=2.02, hwb=2.25, hwr=1.9, zf_top=0.4, zr_top=1.9, zr_base=B.DECK_FRONT + 0.02, ch=0.2, round=2,
                   us=[0.0, 0.1, 0.62, 0.7, 0.8, 1.0], vs=[0.0, 0.16, 0.86, 1.0],
                   glass={(1, 1): 'Window_F', (3, 1): 'Window_R'})
    B.TAIL_GARNISH = (-2.2, 2.2, 0.2, 0.62)
    B.LAMP_Y = -0.75

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.2, nz)
        L.front_rect(b, 'Grille', 'Trim', -(w - 0.05), w - 0.05, -0.45, 0.05, fz)
        for s in (1, -1):
            for x in (0.95, 1.6):
                b.disc('Headlight_' + L.side(s), 'Head', (s * x, -0.2, fz - 0.03), 0.2, 0.06, 'z', n=10)
            for x in (1.3, 1.85):
                b.disc('TailLight_' + L.side(s), 'Tail', (s * x, 0.41, B.TAIL_Z + 0.05), 0.17, -0.03, 'z', n=10)
        L.front_rect(b, 'Intake', 'Trim', -1.4, 1.4, -0.75, -1.1, fz)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.1)
        L.rear_common(b, B, exhaust_x=-1.4, plate_y=-0.2)

    def rally_wing(b):
        yd = B.top_y(6.0)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 1.5, yd), (sx * 1.7, yd), (sx * 1.7, yd + 0.45), (sx * 1.5, yd + 0.45)][:: (1 if sx > 0 else -1)], 5.7, 6.15)
        b.prism('WingBlade', 'Body', [(-2.7, yd + 0.45), (2.7, yd + 0.45), (2.7, yd + 0.62), (-2.7, yd + 0.62)][::-1], 5.5, 6.4)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
