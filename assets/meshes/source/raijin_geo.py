"""
Raijin (« dieu du tonnerre ») : coupé en coin des années 80. Nez très bas
en lame, capot qui monte vers le pare-brise, ailes en caissons larges,
bandeau noir sur toute la face avec phares fins, gros becquet avant,
lunette couverte de persiennes couleur carrosserie.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.8, 6.2
    B.BUMPER_F, B.BUMPER_R = -5.9, 5.6
    B.HOOD_REAR, B.DECK_FRONT = -1.9, 4.6
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.9, 1.9
    B.HANDLES = (1.2,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.75, 3.45, 1.6, 0.0
    B.NOSE_CUT, B.TAIL_CUT = (0.4, 0.5), (0.2, 0.25)
    B.ROCKER_H = 0.45
    B.EXTRA_Z = (5.8,)
    B.top_y = L.make_top_y(B, nose=-0.2, bumper=0.15, hood_rear=0.58, deck=0.82, tail=0.86, brk=5.8)
    B.CABIN = dict(yb=0.58, yr=2.12, hwb=2.4, hwr=2.0, zf_top=-0.2, zr_top=2.0, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.08, 0.62, 0.68, 0.9, 0.95, 1.0], vs=[0.0, 0.14, 0.86, 1.0])
    B.TAIL_GARNISH = (-2.6, 2.6, 0.15, 0.7)
    B.LAMP_Y = -0.75

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.4, nz)
        L.front_rect(b, 'Grille', 'Trim', -(w - 0.04), w - 0.04, -0.6, -0.25, fz)
        for s in (1, -1):
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * 0.9, s * (w - 0.15), -0.5, -0.36, fz - 0.02)
            tz = B.TAIL_Z + 0.05
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 0.4, s * 2.5, 0.3, 0.52, tz)
        # gros becquet avant
        b.prism('Splitter', 'Trim', [(-w, -1.3), (w, -1.3), (w + 0.15, -1.05), (-w - 0.15, -1.05)][::-1], nz - 0.3, nz + 0.8)
        # persiennes couleur carrosserie sur la lunette
        c = B.CABIN
        za, ya, zb, yb = c['zr_top'], c['yr'], c['zr_base'], c['yb']
        for k in range(7):
            t0 = 0.12 + k * 0.11
            t1 = t0 + 0.06
            pa = (za + (zb - za) * t0, ya + (yb - ya) * t0 + 0.04)
            pb = (za + (zb - za) * t1, ya + (yb - ya) * t1 + 0.04)
            hw = c['hwr'] + (c['hwb'] - c['hwr']) * t0 - 0.15
            b.face('Louver', 'Body', [(-hw, pa[1], pa[0]), (hw, pa[1], pa[0]), (hw, pb[1], pb[0]), (-hw, pb[1], pb[0])])
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.5, plate_y=-0.15)

    def rally_wing(b):
        yd = B.top_y(5.8)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 1.5, yd), (sx * 1.7, yd), (sx * 1.7, yd + 0.5), (sx * 1.5, yd + 0.5)][:: (1 if sx > 0 else -1)], 5.5, 6.0)
        b.prism('WingBlade', 'Body', [(-2.9, yd + 0.5), (2.9, yd + 0.5), (2.9, yd + 0.68), (-2.9, yd + 0.68)][::-1], 5.3, 6.3)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
