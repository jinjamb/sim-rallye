"""
Blitz (« éclair ») : coupé Groupe B au long nez, inspiré de l'Audi Quattro
S1. Nez allongé et plongeant, ailes en caissons très carrées, phares carrés
doublés dans un bandeau noir, bouclier à grandes ouïes, aileron géant sur
le coffre, bandeau noir sur tout l'arrière.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -7.0, 6.1
    B.BUMPER_F, B.BUMPER_R = -5.9, 5.45
    B.HOOD_REAR, B.DECK_FRONT = -2.0, 4.0
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 2.1, 2.1
    B.HANDLES = (1.35,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.78, 3.42, 1.62, 0.0
    B.NOSE_CUT, B.TAIL_CUT = (0.5, 0.6), (0.2, 0.25)
    B.EXTRA_Z = (5.6,)
    B.top_y = L.make_top_y(B, nose=0.0, bumper=0.36, hood_rear=0.62, deck=0.78, tail=0.72, brk=5.6)
    B.CABIN = dict(yb=0.62, yr=2.22, hwb=2.4, hwr=2.05, zf_top=-0.3, zr_top=2.45, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.1, 0.62, 0.7, 0.92, 0.96, 1.0])
    B.TAIL_GARNISH = (-2.5, 2.5, 0.0, 0.55)
    B.LAMP_Y = -0.8

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Bandeau noir, phares carrés doublés
        L.front_rect(b, 'Grille', 'Trim', -2.1, 2.1, -0.4, -0.02, fz)
        for s in (1, -1):
            for x in (1.1, 1.65):
                L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * x - 0.22, s * x + 0.22, -0.34, -0.08, fz - 0.02)
            # grandes ouïes du bouclier
            L.front_rect(b, 'Intake', 'Trim', s * 0.35, s * 2.0, -0.6, -1.15, fz)
            # feux arrière dans le bandeau
            tz = B.TAIL_Z + 0.05
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.2, s * 2.3, 0.1, 0.45, tz)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.2)
        L.rear_common(b, B, exhaust_x=-1.4, plate_y=-0.2)
        # Aileron géant sur le coffre, d'origine
        yd = B.top_y(5.4)
        for sx in (1, -1):
            b.prism('DeckWing', 'Trim', [(sx * 1.4, yd), (sx * 1.65, yd), (sx * 1.65, yd + 0.85), (sx * 1.4, yd + 0.85)][:: (1 if sx > 0 else -1)], 5.0, 5.8)
        b.prism('DeckWingBlade', 'Body', [(-3.1, yd + 0.85), (3.1, yd + 0.85), (3.1, yd + 1.05), (-3.1, yd + 1.05)][::-1], 4.7, 6.45)
        for sx in (1, -1):
            b.prism('DeckWing', 'Trim', [(sx * 3.1, yd + 0.45), (sx * 3.2, yd + 0.45), (sx * 3.2, yd + 1.3), (sx * 3.1, yd + 1.3)][:: (1 if sx > 0 else -1)], 4.6, 6.55)

    B.details = details
    B.rally_wing = lambda b: None  # son aileron est d'origine


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
