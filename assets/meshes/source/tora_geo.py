"""
Tora (« tigre ») : citadine compacte, haute et très courte. Porte-à-faux
minuscules, toit haut et plat, pare-brise droit, gros yeux ronds, petite
calandre souriante, feux arrière verticaux, épaules un peu arrondies.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -5.6, 5.0
    B.BUMPER_F, B.BUMPER_R = -5.15, 4.7
    B.HOOD_REAR, B.DECK_FRONT = -2.55, 4.6
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.3, 1.3
    B.HANDLES = (0.7,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.7, 3.2, 1.4, 0.4
    B.NOSE_CUT, B.TAIL_CUT = (0.45, 0.4), (0.3, 0.3)
    B.SIDE_TAPER, B.CREASE = 0.12, 0.55
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.3, 3, 0.06
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 3, 2, 5
    B.ROCKER_H = 0.35
    B.top_y = L.make_top_y(B, nose=0.45, bumper=0.72, hood_rear=0.86, deck=1.1, tail=1.1, brk=4.8)
    B.CABIN = dict(yb=0.86, yr=2.72, hwb=2.35, hwr=2.05, zf_top=-1.3, zr_top=4.35, zr_base=B.DECK_FRONT + 0.02, ch=0.35, round=3,
                   us=[0.0, 0.08, 0.5, 0.57, 0.86, 0.92, 1.0], vs=[0.0, 0.1, 0.88, 1.0])
    B.TAIL_GARNISH = (-1.2, 1.2, -0.35, -0.05)
    B.LAMP_Y = -0.65

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        for s in (1, -1):
            b.disc('Headlight_' + L.side(s), 'Head', (s * 1.45, 0.2, fz - 0.03), 0.42, 0.06, 'z', n=12)
            tz = B.TAIL_Z + 0.03
            wr = B.side_x(0.4, B.TAIL_Z)
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * (wr - 0.45), s * (wr - 0.1), -0.1, 0.95, tz)
        smile = [(-0.75, -0.3), (0.75, -0.3), (0.55, -0.65), (-0.55, -0.65)]
        b.face('Grille', 'Trim', [(x, y, fz) for x, y in smile])
        L.front_rect(b, 'Intake', 'Trim', -1.6, 1.6, -0.9, -1.2, fz)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.2, plate_y=0.4)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.0, 5.05, 2.78, 2.3, blades=1, plates=True, post=0.2)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
