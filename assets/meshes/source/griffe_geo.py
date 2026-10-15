"""
Griffe (« griffe ») : compacte trois portes moderne, inspirée de la 208.
Feux de jour en trois griffes verticales sous chaque phare, grande calandre
noire, bandeau noir sur tout l'arrière avec trois griffes rouges par côté.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.25, 5.5
    B.BUMPER_F, B.BUMPER_R = -5.45, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.3, 4.9
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.5, 1.5
    B.HANDLES = (0.85,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.76, 3.32, 1.55, 0.2
    B.NOSE_CUT, B.TAIL_CUT = (0.55, 0.65), (0.32, 0.4)
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.24, 2, 0.05
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 3, 2, 4
    B.EXTRA_Z = (5.15,)
    B.top_y = L.make_top_y(B, nose=0.22, bumper=0.55, hood_rear=0.66, deck=0.98, tail=0.78, brk=5.15)
    B.CABIN = dict(yb=0.66, yr=2.34, hwb=2.42, hwr=2.02, zf_top=-0.5, zr_top=4.2, zr_base=B.DECK_FRONT + 0.02, ch=0.3, round=2,
                   us=[0.0, 0.1, 0.55, 0.62, 0.84, 0.9, 1.0])
    B.TAIL_GARNISH = (-2.35, 2.35, 0.05, 0.62)
    B.LAMP_Y = -0.85

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Grande calandre noire
        b.face('Grille', 'Trim', [(-1.3, 0.05, fz), (1.3, 0.05, fz), (1.7, -1.15, fz), (-1.7, -1.15, fz)])
        for s in (1, -1):
            b.face('Headlight_' + L.side(s), 'Head', [(s * 1.25, 0.32, fz - 0.02), (s * 2.25, 0.25, fz - 0.02), (s * 2.25, 0.05, fz - 0.02), (s * 1.4, 0.1, fz - 0.02)])
            # trois griffes lumineuses sous le phare
            for k in range(3):
                x = s * (1.85 + k * 0.17)
                b.face('Claw_' + L.side(s), 'Head', [(x - 0.04, -0.1 - k * 0.05, fz - 0.02), (x + 0.04, -0.1 - k * 0.05, fz - 0.02), (x + 0.04 - s * 0.1, -0.75, fz - 0.02), (x - 0.04 - s * 0.1, -0.75, fz - 0.02)][:: (1 if s > 0 else -1)])
            # trois griffes rouges par côté dans le bandeau arrière
            tz = B.TAIL_Z + 0.05
            for k in range(3):
                x = s * (1.45 + k * 0.28)
                b.face('TailLight_' + L.side(s), 'Tail', [(x - 0.07, 0.55, tz), (x + 0.07, 0.55, tz), (x + 0.07 - s * 0.12, 0.12, tz), (x - 0.07 - s * 0.12, 0.12, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.4)
        L.rear_common(b, B, exhaust_x=1.45, plate_y=-0.2)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.05, 5.35, 2.5, 2.45, blades=2, plates=True, post=0.2)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
