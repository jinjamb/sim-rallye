"""
Griffe : inspirée de la 208. Large, basse et nette : caisse large aux ailes
à peine marquées, ligne de caisse haute et tendue, masque noir sur toute la
largeur de la face avant, trois griffes lumineuses verticales de chaque
côté, bandeau noir arrière griffé de rouge.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.3, 5.5
    B.BUMPER_F, B.BUMPER_R = -5.45, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.25, 4.85
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.5, 1.5
    B.HANDLES = (0.85,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.95, 3.24, 1.55, 0.15
    B.NOSE_CUT, B.TAIL_CUT = (0.5, 0.6), (0.3, 0.35)
    B.SIDE_TAPER, B.CREASE = 0.2, 0.66
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.14, 2, 0.04
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 2, 2, 4
    B.ROCKER_H = 0.32
    B.EXTRA_Z = (5.15,)
    B.top_y = L.make_top_y(B, nose=0.32, bumper=0.6, hood_rear=0.7, deck=0.96, tail=0.82, brk=5.15)
    B.CABIN = dict(yb=0.72, yr=2.3, hwb=2.5, hwr=2.12, zf_top=-0.4, zr_top=3.95, zr_base=B.DECK_FRONT + 0.02, ch=0.22, round=2,
                   us=[0.0, 0.1, 0.55, 0.62, 0.84, 0.9, 1.0], vs=[0.0, 0.2, 0.84, 1.0])
    B.TAIL_GARNISH = (-2.5, 2.5, 0.05, 0.6)
    B.LAMP_Y = -0.88

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.3, nz)
        # masque noir sur toute la largeur : phares et calandre dedans
        b.face('Grille', 'Trim', [(-(w - 0.05), 0.35, fz), ((w - 0.05), 0.35, fz), ((w - 0.15), -0.5, fz), (-(w - 0.15), -0.5, fz)])
        L.front_rect(b, 'Intake', 'Trim', -1.5, 1.5, -0.75, -1.2, fz)
        for s in (1, -1):
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * 1.35, s * (w - 0.2), 0.12, 0.26, fz - 0.03)
            for k in range(3):
                x = s * (w - 0.25 - k * 0.18)
                b.face('Claw_' + L.side(s), 'Head', [(x - 0.045, -0.55, fz - 0.03), (x + 0.045, -0.55, fz - 0.03), (x + 0.045 + s * 0.1, -1.15, fz - 0.03), (x - 0.045 + s * 0.1, -1.15, fz - 0.03)][:: (1 if s > 0 else -1)])
            tz = B.TAIL_Z + 0.05
            for k in range(3):
                x = s * (1.5 + k * 0.3)
                b.face('TailLight_' + L.side(s), 'Tail', [(x - 0.08, 0.52, tz), (x + 0.08, 0.52, tz), (x + 0.08 - s * 0.14, 0.12, tz), (x - 0.08 - s * 0.14, 0.12, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.4)
        L.rear_common(b, B, exhaust_x=1.45, plate_y=-0.2)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 3.95, 5.3, 2.42, 2.5, blades=2, plates=True, post=0.2)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
