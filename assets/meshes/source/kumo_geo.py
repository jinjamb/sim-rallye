"""
Kumo (« nuage ») : petite bombe à moteur central des années 80. Avant
étroit et court, habitacle avancé, hanches arrière énormes (ailes arrière
bien plus larges que l'avant) avec de grandes prises d'air noires devant
les roues arrière, phares carrés, arrière carré et haut.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.0, 5.6
    B.BUMPER_F, B.BUMPER_R = -5.35, 5.15
    B.HOOD_REAR, B.DECK_FRONT = -2.6, 5.0
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.0, 1.0
    B.HANDLES = (0.4,)
    B.BODY_HW = 2.62
    B.FLARE_HW, B.FLARE_HW_REAR, B.FLARE_LEN, B.FLARE_RAMP = 2.95, 3.6, 1.62, 0.6
    B.NOSE_CUT, B.TAIL_CUT = (0.3, 0.35), (0.2, 0.25)
    B.ROCKER_H = 0.4
    B.EXTRA_Z = (5.3,)
    B.top_y = L.make_top_y(B, nose=0.3, bumper=0.55, hood_rear=0.68, deck=1.05, tail=1.0, brk=5.3)
    B.CABIN = dict(yb=0.68, yr=2.4, hwb=2.4, hwr=2.1, zf_top=-1.0, zr_top=3.9, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.1, 0.55, 0.62, 0.8, 0.86, 1.0])
    B.TAIL_GARNISH = (-2.4, 2.4, -0.15, 0.5)
    B.LAMP_Y = -0.8

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(0.0, nz)
        L.front_rect(b, 'Grille', 'Trim', -0.8, 0.8, -0.1, 0.2, fz)
        L.front_rect(b, 'Intake', 'Trim', -(w - 0.1), w - 0.1, -0.6, -1.15, fz)
        for s in (1, -1):
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * 0.95, s * (w - 0.12), -0.15, 0.25, fz - 0.02)
            # grande prise d'air noire sur la face avant des hanches arrière
            z = 4.05 - 1.62 - 0.6 + 0.02
            x0, x1 = s * (B.BODY_HW + 0.02), s * (3.6 - 0.05)
            b.face('SideIntake_' + L.side(s), 'Trim', [(x0, -1.1, z - 0.01), (x1, -0.9, z + 0.55), (x1, 0.55, z + 0.55), (x0, 0.6, z - 0.01)])
            tz = B.TAIL_Z + 0.05
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.3, s * 2.3, 0.0, 0.42, tz)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=1.5, plate_y=-0.4)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.1, 5.25, 2.66, 2.5, blades=1, plates=True, post=0.2)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
