"""
Tsubasa (« aile ») : inspirée de la Yaris WRC. Caisse étroite et haute
(ceinture haute, vitres basses), ailes en caissons énormes qui débordent
de partout, ligne de caisse nette, nez en bec, grande bouche noire et
prises d'air verticales, grand aileron multi-lames d'origine.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.35, 5.45
    B.BUMPER_F, B.BUMPER_R = -5.5, 4.95
    B.HOOD_REAR, B.DECK_FRONT = -2.3, 4.95
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.6, 1.6
    B.HANDLES = (0.9,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.55, 3.5, 1.62, 0.0
    B.NOSE_CUT, B.TAIL_CUT = (0.5, 0.55), (0.3, 0.35)
    B.SIDE_TAPER, B.CREASE = 0.2, 0.58
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.15, 2, 0.04
    B.NOSE_SEGS, B.ARCH_SEG = 2, 4
    B.ROCKER_H = 0.5
    B.EXTRA_Z = (5.15,)
    B.top_y = L.make_top_y(B, nose=0.05, bumper=0.48, hood_rear=0.76, deck=1.05, tail=0.85, brk=5.15)
    B.CABIN = dict(yb=0.78, yr=2.42, hwb=2.15, hwr=1.85, zf_top=-0.3, zr_top=4.3, zr_base=B.DECK_FRONT + 0.02, ch=0.2, round=2,
                   us=[0.0, 0.1, 0.5, 0.56, 0.8, 0.86, 1.0], vs=[0.0, 0.26, 0.86, 1.0])
    B.TAIL_GARNISH = (-1.9, 1.9, -0.45, -0.05)
    B.LAMP_Y = -0.62

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(0.0, nz)
        b.face('Grille', 'Trim', [(-0.9, 0.02, fz), (0.9, 0.02, fz), (1.45, -1.2, fz), (-1.45, -1.2, fz)])
        for s in (1, -1):
            b.face('Headlight_' + L.side(s), 'Head', [(s * 0.95, 0.06, fz - 0.02), (s * (w - 0.05), 0.0, fz - 0.02), (s * (w - 0.05), -0.18, fz - 0.02), (s * 1.1, -0.14, fz - 0.02)])
            L.front_rect(b, 'Intake', 'Trim', s * 1.6, s * (w - 0.08), -0.4, -1.2, fz)
            b.prism('Canard_' + L.side(s), 'Trim', [(s * 1.9, -0.85), (s * 2.6, -0.75), (s * 2.6, -0.66), (s * 1.9, -0.76)][:: (1 if s > 0 else -1)], nz - 0.05, nz + 0.7)
            for k in range(3):
                z = -4.05 + 0.85 + k * 0.22
                x = s * (B.FLARE_HW + 0.03)
                b.face('FlareVent_' + L.side(s), 'Trim', [(x, -0.85, z), (x, -0.85, z + 0.12), (x, 0.2, z + 0.12), (x, 0.2, z)])
            tz = B.TAIL_Z + 0.03
            wt = B.side_x(0.5, B.TAIL_Z)
            b.face('TailLight_' + L.side(s), 'Tail', [(s * 1.0, 0.7, tz), (s * (wt - 0.08), 0.6, tz), (s * (wt - 0.08), 0.32, tz), (s * 1.2, 0.42, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.5)
        L.rear_common(b, B, exhaust_x=1.4, plate_y=0.2)
        L.roof_wing(b, B, 'RoofWing', 'Body', 4.15, 5.3, 2.5, 2.6, blades=2, plates=True, post=0.0)

    B.details = details
    B.rally_wing = lambda b: None


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
