"""
Fauve : inspirée de la 205 T16. Courte et haute, presque carrée, avec une
grande ceinture noire tout autour du bas (boucliers et bas de caisse),
grandes prises d'air noires derrière les portes, ailes élargies carrées,
phares rectangulaires larges, fine calandre noire.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.05, 5.35
    B.BUMPER_F, B.BUMPER_R = -5.4, 4.95
    B.HOOD_REAR, B.DECK_FRONT = -2.4, 4.9
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.25, 1.25
    B.HANDLES = (0.65,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.32, 1.55, 0.1
    B.NOSE_CUT, B.TAIL_CUT = (0.25, 0.3), (0.2, 0.25)
    B.SIDE_TAPER, B.CREASE = 0.12, 0.62
    B.SHOULDER, B.SHOULDER_SEGS = 0.1, 2
    B.ROCKER_H = 0.82
    B.EXTRA_Z = (5.1,)
    B.top_y = L.make_top_y(B, nose=0.38, bumper=0.6, hood_rear=0.7, deck=1.08, tail=1.02, brk=5.1)
    B.CABIN = dict(yb=0.72, yr=2.55, hwb=2.4, hwr=2.12, zf_top=-0.75, zr_top=4.45, zr_base=B.DECK_FRONT + 0.02, ch=0.12, round=2,
                   us=[0.0, 0.1, 0.52, 0.6, 0.84, 0.9, 1.0])
    B.TAIL_GARNISH = (-2.35, 2.35, -1.1, -0.35)
    B.LAMP_Y = -0.85

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.6, nz)
        L.front_rect(b, 'Grille', 'Trim', -0.95, 0.95, 0.0, 0.24, fz)
        # ceinture noire : tout le bas du bouclier avant
        L.front_rect(b, 'Intake', 'Trim', -(w - 0.02), w - 0.02, -0.42, -1.25, fz)
        for s in (1, -1):
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * 1.05, s * 2.15, -0.08, 0.3, fz - 0.02)
            x = s * (B.side_x(0.1, 1.9) + 0.03)
            b.face('SideIntake_' + L.side(s), 'Trim', [(x, -0.55, 1.3), (x, -0.55, 2.4), (x, 0.55, 2.4), (x, 0.55, 1.55)])
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.1, s * 2.15, 0.15, 0.6, tz)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.4, plate_y=-0.0)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.0, 5.05, 2.58, 2.25, blades=1, plates=True, post=0.15)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
