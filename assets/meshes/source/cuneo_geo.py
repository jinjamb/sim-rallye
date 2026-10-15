"""
Cuneo (« coin ») : inspirée de la Lancia Stratos. Coin très bas, étroit et
pointu devant, très large derrière, flancs qui rentrent fort, pare-brise
enveloppant très incliné, toit court et bas, petites vitres, montants
couleur carrosserie, capot moteur incliné à persiennes noires, becquet en
arceau, phares escamotables, quatre feux ronds.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.0, 5.45
    B.BUMPER_F, B.BUMPER_R = -5.2, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.1, 4.7
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.1, 1.1
    B.HANDLES = (0.5,)
    B.BODY_HW, B.BODY_HW_REAR = 2.4, 3.05
    B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 3.3, 1.3, 0.8
    B.NOSE_CUT, B.TAIL_CUT = (1.0, 1.25), (0.3, 0.38)
    B.SIDE_TAPER, B.CREASE = 0.4, 0.4
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.45, 4, 0.2
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 4, 2, 5
    B.ROCKER_H = 0.0
    B.PILLAR_PAINT = 'Body'
    B.EXTRA_Z = (5.0,)
    B.top_y = L.make_top_y(B, nose=-0.15, bumper=0.22, hood_rear=0.56, deck=0.9, tail=0.82, brk=5.0)
    B.CABIN = dict(yb=0.58, yr=1.92, hwb=2.25, hwr=1.7, zf_top=-0.15, zr_top=1.1, zr_base=B.DECK_FRONT + 0.02,
                   ch=0.5, round=4, crown=0.06, rear='Body',
                   us=[0.0, 0.07, 0.36, 0.42, 1.0], vs=[0.0, 0.22, 0.85, 1.0], glass={(1, 1): 'Window_F'},
                   body_columns=(3,), body_name='RearQuarter')
    B.TAIL_GARNISH = (-2.35, 2.35, 0.18, 0.66)
    B.LAMP_Y = -0.62

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.6, nz)
        L.front_rect(b, 'Intake', 'Trim', -(w - 0.15), w - 0.15, -0.45, -0.95, fz)
        for s in (1, -1):
            z0, z1 = -4.95, -4.3
            x0, x1 = s * 0.75, s * 1.6
            y0 = B.surf_y(1.2, z0) - 0.02
            b.prism('PopUp_' + L.side(s), 'Trim', [(x0, y0), (x1, y0), (x1, y0 + 0.26), (x0, y0 + 0.26)][:: (1 if s > 0 else -1)], z0, z1)
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', x0 + s * 0.08, x1 - s * 0.08, y0 + 0.04, y0 + 0.22, z0 - 0.02)
            for x in (1.4, 1.95):
                b.disc('TailLight_' + L.side(s), 'Tail', (s * x, 0.42, B.TAIL_Z + 0.05), 0.21, -0.03, 'z', n=10)
        c = B.CABIN
        za, ya, zb, yb = c['zr_top'], c['yr'], c['zr_base'], c['yb']
        for k in range(6):
            t0 = 0.28 + k * 0.1
            t1 = t0 + 0.045
            pa = (za + (zb - za) * t0, ya + (yb - ya) * t0 + 0.03)
            pb = (za + (zb - za) * t1, ya + (yb - ya) * t1 + 0.03)
            b.face('Louver', 'Trim', [(-1.4, pa[1], pa[0]), (1.4, pa[1], pa[0]), (1.4, pb[1], pb[0]), (-1.4, pb[1], pb[0])])
        b.prism('RoofSpoiler', 'Body', [(-1.95, c['yr'] + 0.02), (1.95, c['yr'] + 0.02), (1.95, c['yr'] + 0.16), (-1.95, c['yr'] + 0.16)][::-1], 0.8, 1.5)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=1.3, plate_y=-0.15)

    def rally_wing(b):
        yd = B.top_y(5.15)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 1.3, yd), (sx * 1.5, yd), (sx * 1.5, yd + 0.55), (sx * 1.3, yd + 0.55)][:: (1 if sx > 0 else -1)], 4.9, 5.35)
        b.prism('WingBlade', 'Body', [(-2.9, yd + 0.55), (2.9, yd + 0.55), (2.9, yd + 0.72), (-2.9, yd + 0.72)][::-1], 4.7, 5.65)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
