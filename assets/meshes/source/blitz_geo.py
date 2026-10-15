"""
Blitz : inspiré de l'Audi Quattro S1. Coupé au très long capot bas et
plongeant, ailes en caissons carrés, vitres courtes et gros montant arrière
couleur carrosserie, bouclier avant à lamelles noires, phares carrés
doublés, aileron géant d'origine sur le coffre.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -7.1, 6.05
    B.BUMPER_F, B.BUMPER_R = -6.0, 5.45
    B.HOOD_REAR, B.DECK_FRONT = -1.8, 4.1
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 2.0, 2.0
    B.HANDLES = (1.3,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.7, 3.45, 1.62, 0.0
    B.NOSE_CUT, B.TAIL_CUT = (0.6, 0.75), (0.2, 0.25)
    B.PILLAR_PAINT = 'Body'
    B.ROCKER_H = 0.42
    B.EXTRA_Z = (5.6,)
    B.top_y = L.make_top_y(B, nose=-0.1, bumper=0.26, hood_rear=0.58, deck=0.82, tail=0.76, brk=5.6)
    B.CABIN = dict(yb=0.6, yr=2.2, hwb=2.4, hwr=2.0, zf_top=-0.3, zr_top=1.9, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.07, 0.6, 0.66, 0.78, 1.0], vs=[0.0, 0.16, 0.86, 1.0],
                   glass={(1, 1): 'Window_F', (3, 1): 'Window_R'})
    B.TAIL_GARNISH = (-2.55, 2.55, 0.0, 0.55)
    B.LAMP_Y = -0.85

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.2, nz)
        L.front_rect(b, 'Grille', 'Trim', -(w - 0.05), w - 0.05, -0.42, -0.02, fz)
        for s in (1, -1):
            for x in (1.0, 1.55):
                L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * x - 0.22, s * x + 0.22, -0.36, -0.08, fz - 0.02)
            tz = B.TAIL_Z + 0.05
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.15, s * 2.35, 0.1, 0.45, tz)
        # bouclier à lamelles noires
        L.front_rect(b, 'Intake', 'Trim', -(w - 0.1), w - 0.1, -0.6, -1.2, fz)
        for k in range(9):
            x = -(w - 0.35) + k * (2 * (w - 0.35) / 8)
            L.front_rect(b, 'GrilleBar', 'Body', x - 0.05, x + 0.05, -1.15, -0.65, fz - 0.03)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.0)
        L.rear_common(b, B, exhaust_x=-1.4, plate_y=-0.2)
        yd = B.top_y(5.4)
        for sx in (1, -1):
            b.prism('DeckWing', 'Trim', [(sx * 1.4, yd), (sx * 1.65, yd), (sx * 1.65, yd + 0.85), (sx * 1.4, yd + 0.85)][:: (1 if sx > 0 else -1)], 5.0, 5.8)
        b.prism('DeckWingBlade', 'Body', [(-3.1, yd + 0.85), (3.1, yd + 0.85), (3.1, yd + 1.05), (-3.1, yd + 1.05)][::-1], 4.7, 6.4)
        for sx in (1, -1):
            b.prism('DeckWing', 'Trim', [(sx * 3.1, yd + 0.45), (sx * 3.2, yd + 0.45), (sx * 3.2, yd + 1.3), (sx * 3.1, yd + 1.3)][:: (1 if sx > 0 else -1)], 4.6, 6.5)

    B.details = details
    B.rally_wing = lambda b: None


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
