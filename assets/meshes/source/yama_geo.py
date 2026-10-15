"""
Yama (« montagne ») : berline trois volumes des années 70. Caisse droite et
carrée, long capot et long coffre, habitacle haut aux montants fins couleur
carrosserie, gros phares ronds dans une calandre noire, pare-chocs chromés,
petites ailes boulonnées.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.7, 6.5
    B.BUMPER_F, B.BUMPER_R = -5.9, 5.9
    B.HOOD_REAR, B.DECK_FRONT = -2.2, 3.1
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 4, 0.4, 2.4
    B.HANDLES = (-0.5, 1.8)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.8, 3.15, 1.4, 0.2
    B.NOSE_CUT, B.TAIL_CUT = (0.15, 0.2), (0.15, 0.2)
    B.PILLAR_PAINT = 'Body'
    B.ROCKER_H = 0.0
    B.EXTRA_Z = (6.1,)
    B.top_y = L.make_top_y(B, nose=0.5, bumper=0.62, hood_rear=0.7, deck=0.74, tail=0.7, brk=6.1)
    B.CABIN = dict(yb=0.7, yr=2.5, hwb=2.55, hwr=2.35, zf_top=-0.8, zr_top=2.15, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.05, 0.47, 0.51, 0.9, 0.95, 1.0], vs=[0.0, 0.08, 0.92, 1.0])
    B.TAIL_GARNISH = (-1.2, 1.2, 0.0, 0.35)
    B.LAMP_Y = -0.55

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        L.front_rect(b, 'Grille', 'Trim', -2.45, 2.45, -0.45, 0.4, fz)
        for s in (1, -1):
            b.disc('Headlight_' + L.side(s), 'Head', (s * 1.85, -0.03, fz - 0.03), 0.36, 0.06, 'z', n=10)
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.5, s * 2.5, 0.0, 0.45, tz)
        for k in range(3):
            L.front_rect(b, 'GrilleBar', 'Chrome', -1.2, 1.2, 0.18 - k * 0.22, 0.24 - k * 0.22, fz - 0.03)
        # pare-chocs chromés
        for z0, z1 in ((nz - 0.25, nz + 0.15), (B.TAIL_Z - 0.15, B.TAIL_Z + 0.25)):
            b.prism('Bumper', 'Chrome', [(-2.75, -0.82), (2.75, -0.82), (2.75, -0.6), (-2.75, -0.6)][::-1], z0, z1)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.5, plate_y=-0.2)

    def rally_wing(b):
        yd = B.top_y(5.9)
        b.prism('WingBlade', 'Body', [(-2.6, yd), (2.6, yd), (2.6, yd + 0.22), (-2.6, yd + 0.22)][::-1], 5.6, 6.45)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 2.6, yd - 0.05), (sx * 2.7, yd - 0.05), (sx * 2.7, yd + 0.35), (sx * 2.6, yd + 0.35)][:: (1 if sx > 0 else -1)], 5.55, 6.5)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
