"""
Lynx : inspirée de la 206 WRC. Petite, ronde et basse : coins arrondis,
épaules et toit très ronds, capot bombé et plongeant, ailes en bosses
douces, montants couleur carrosserie, grande bouche ovale, phares en amande
qui remontent vers le capot, feux arrière hauts et verticaux.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.15, 5.35
    B.BUMPER_F, B.BUMPER_R = -5.4, 4.9
    B.HOOD_REAR, B.DECK_FRONT = -2.4, 4.75
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.4, 1.4
    B.HANDLES = (0.8,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.6, 3.22, 1.3, 0.85
    B.NOSE_CUT, B.TAIL_CUT = (1.0, 1.2), (0.65, 0.75)
    B.SIDE_TAPER, B.CREASE = 0.3, 0.35
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.55, 4, 0.2
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 4, 3, 5
    B.ROCKER_H = 0.0
    B.PILLAR_PAINT = 'Body'
    B.EXTRA_Z = (5.0,)
    B.top_y = L.make_top_y(B, nose=0.12, bumper=0.42, hood_rear=0.62, deck=0.9, tail=0.66, brk=5.0)
    B.CABIN = dict(yb=0.62, yr=2.22, hwb=2.05, hwr=1.6, zf_top=-0.75, zr_top=3.75, zr_base=B.DECK_FRONT + 0.02, ch=0.6, round=4, crown=0.12,
                   us=[0.0, 0.14, 0.58, 0.66, 0.86, 0.92, 1.0], vs=[0.0, 0.14, 0.84, 1.0])
    B.TAIL_GARNISH = (-1.0, 1.0, -0.6, -0.3)
    B.LAMP_Y = -0.75

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        mouth = [(-0.85, -0.3), (0.85, -0.3), (1.25, -0.55), (1.25, -0.9), (0.85, -1.15), (-0.85, -1.15), (-1.25, -0.9), (-1.25, -0.55)]
        b.face('Grille', 'Trim', [(x, y, fz) for x, y in mouth])
        for s in (1, -1):
            wt = B.side_x(0.1, nz)
            b.face('Headlight_' + L.side(s), 'Head', [(s * 0.45, -0.1, fz - 0.02), (s * 1.0, 0.05, fz - 0.02), (s * (wt - 0.02), 0.26, fz - 0.02), (s * (wt - 0.15), -0.06, fz - 0.02), (s * 0.8, -0.24, fz - 0.02)])
            b.disc('FogLight_' + L.side(s), 'Lamp', (s * 1.0, -0.72, fz - 0.05), 0.15, 0.06, 'z', n=8)
            tz = B.TAIL_Z + 0.03
            wr = B.side_x(0.2, B.TAIL_Z)
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * (wr - 0.5), s * (wr - 0.08), -0.2, 0.55, tz)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.1, plate_y=0.3)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 3.85, 5.05, 2.34, 2.2, blades=1, plates=True, post=0.25)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
