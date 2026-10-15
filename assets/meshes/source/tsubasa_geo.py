"""
Tsubasa (« aile ») : compacte trois portes de WRC moderne, inspirée de la
Yaris WRC. Aéro démesurée : ailes très larges avec ouïes derrière les roues
avant, grand aileron multi-lames sur le hayon, grande bouche noire, lame
avant et ailettes.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.35, 5.55
    B.BUMPER_F, B.BUMPER_R = -5.5, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.3, 5.0
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.6, 1.6
    B.HANDLES = (0.9,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.42, 1.55, 0.0
    B.NOSE_CUT, B.TAIL_CUT = (0.45, 0.5), (0.3, 0.35)
    B.EXTRA_Z = (5.2,)
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.2, 2, 0.04
    B.NOSE_SEGS, B.ARCH_SEG = 2, 4
    B.top_y = L.make_top_y(B, nose=0.08, bumper=0.42, hood_rear=0.56, deck=0.92, tail=0.7, brk=5.2)
    B.CABIN = dict(yb=0.56, yr=2.36, hwb=2.4, hwr=2.0, zf_top=-0.55, zr_top=4.35, zr_base=B.DECK_FRONT + 0.02, ch=0.25, round=2,
                   us=[0.0, 0.1, 0.5, 0.56, 0.8, 0.86, 1.0])
    B.TAIL_GARNISH = (-2.0, 2.0, -0.45, -0.05)
    B.LAMP_Y = -0.62

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Grande bouche noire en trapèze, phares effilés en biais
        b.face('Grille', 'Trim', [(-1.25, 0.0, fz), (1.25, 0.0, fz), (1.95, -1.2, fz), (-1.95, -1.2, fz)])
        for s in (1, -1):
            hl = [(s * 1.3, 0.04, fz - 0.02), (s * 2.25, -0.06, fz - 0.02), (s * 2.25, -0.3, fz - 0.02), (s * 1.42, -0.22, fz - 0.02)]
            b.face('Headlight_' + L.side(s), 'Head', hl)
            # ailettes (canards) aux coins du bouclier
            b.prism('Canard_' + L.side(s), 'Trim', [(s * 2.05, -0.8), (s * 2.55, -0.72), (s * 2.55, -0.64), (s * 2.05, -0.72)][:: (1 if s > 0 else -1)], nz - 0.05, nz + 0.6)
            # ouïes derrière les roues avant (sur l'aile)
            for k in range(3):
                z = -4.05 + 0.85 + k * 0.22
                x = s * (B.FLARE_HW + 0.03)
                b.face('FlareVent_' + L.side(s), 'Trim', [(x, -0.75, z), (x, -0.75, z + 0.12), (x, 0.15, z + 0.12), (x, 0.15, z)])
            # feux arrière effilés en haut des coins
            tz = B.TAIL_Z + 0.03
            b.face('TailLight_' + L.side(s), 'Tail', [(s * 1.1, 0.62, tz), (s * 2.15, 0.55, tz), (s * 2.15, 0.3, tz), (s * 1.3, 0.38, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.5)
        L.rear_common(b, B, exhaust_x=1.5, plate_y=0.25)
        # Grand aileron multi-lames sur le hayon (d'origine)
        L.roof_wing(b, B, 'RoofWing', 'Body', 4.15, 5.35, 2.42, 2.55, blades=2, plates=True, post=0.0)

    B.details = details
    B.rally_wing = lambda b: None  # son aileron est d'origine


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
