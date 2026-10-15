"""
Cuneo (« coin », en italien) : coupé à moteur central en forme de coin
arrondi, inspiré de la Lancia Stratos. Très court et large, nez bas en
pointe arrondie, pare-brise enveloppant très incliné, toit court et bas
avec becquet en arceau, capot moteur incliné à persiennes noires, phares
escamotables sur le capot, quatre feux ronds à l'arrière.
"""
import math
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.1, 5.5
    B.BUMPER_F, B.BUMPER_R = -5.3, 5.05
    B.HOOD_REAR, B.DECK_FRONT = -2.2, 4.75
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.2, 1.2
    B.HANDLES = (0.55,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.78, 3.36, 1.4, 0.6
    B.NOSE_CUT, B.TAIL_CUT = (0.95, 1.05), (0.3, 0.38)
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.38, 3, 0.14
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 4, 2, 5
    B.EXTRA_Z = (5.0,)
    B.top_y = L.make_top_y(B, nose=-0.08, bumper=0.28, hood_rear=0.62, deck=0.96, tail=0.86, brk=5.0)
    B.CABIN = dict(yb=0.62, yr=2.06, hwb=2.45, hwr=2.0, zf_top=-0.1, zr_top=1.35, zr_base=B.DECK_FRONT + 0.02,
                   ch=0.42, round=3, crown=0.05, rear='Body',
                   us=[0.0, 0.07, 0.4, 0.46, 1.0], glass={(1, 1): 'Window_F'},
                   body_columns=(3,), body_name='RearQuarter')
    B.TAIL_GARNISH = (-2.2, 2.2, 0.18, 0.66)
    B.LAMP_Y = -0.62

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Fente noire basse dans le nez en coin
        L.front_rect(b, 'Intake', 'Trim', -1.35, 1.35, -0.4, -0.95, fz)
        for s in (1, -1):
            # phares escamotables : blocs noirs posés sur le capot, phare devant
            z0, z1 = -5.0, -4.35
            x0, x1 = s * 0.95, s * 1.85
            y0 = B.surf_y(1.4, z0) - 0.02
            b.prism('PopUp_' + L.side(s), 'Trim', [(x0, y0), (x1, y0), (x1, y0 + 0.24), (x0, y0 + 0.24)][:: (1 if s > 0 else -1)], z0, z1)
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', x0 + s * 0.08, x1 - s * 0.08, y0 + 0.04, y0 + 0.21, z0 - 0.02)
            # quatre feux ronds à l'arrière, dans le bandeau noir
            for x in (1.35, 1.9):
                b.disc('TailLight_' + L.side(s), 'Tail', (s * x, 0.42, B.TAIL_Z + 0.05), 0.2, -0.03, 'z', n=10)
        # Persiennes noires sur le capot moteur incliné
        c = B.CABIN
        za, ya = c['zr_top'], c['yr']
        zb, yb = c['zr_base'], c['yb']
        for k in range(6):
            t0 = 0.3 + k * 0.1
            t1 = t0 + 0.045
            pa = (za + (zb - za) * t0, ya + (yb - ya) * t0 + 0.03)
            pb = (za + (zb - za) * t1, ya + (yb - ya) * t1 + 0.03)
            b.face('Louver', 'Trim', [(-1.5, pa[1], pa[0]), (1.5, pa[1], pa[0]), (1.5, pb[1], pb[0]), (-1.5, pb[1], pb[0])])
        # Becquet en arceau sur l'arrière du toit
        b.prism('RoofSpoiler', 'Body', [(-2.05, c['yr'] + 0.02), (2.05, c['yr'] + 0.02), (2.05, c['yr'] + 0.16), (-2.05, c['yr'] + 0.16)][::-1], 1.0, 1.75)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=1.3, plate_y=-0.15)

    def rally_wing(b):
        yd = B.top_y(5.2)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 1.3, yd), (sx * 1.5, yd), (sx * 1.5, yd + 0.55), (sx * 1.3, yd + 0.55)][:: (1 if sx > 0 else -1)], 4.95, 5.4)
        b.prism('WingBlade', 'Body', [(-2.7, yd + 0.55), (2.7, yd + 0.55), (2.7, yd + 0.72), (-2.7, yd + 0.72)][::-1], 4.75, 5.7)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
