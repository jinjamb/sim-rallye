"""
Fauve (« fauve ») : petite bombe Groupe B à moteur central, inspirée de la
205 T16. Compacte trois portes presque carrée (coins à peine adoucis),
ailes élargies, grande prise d'air noire derrière chaque porte, phares
rectangulaires larges, bouclier noir, feux arrière rectangulaires.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.15, 5.45
    B.BUMPER_F, B.BUMPER_R = -5.45, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.35, 4.95
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.3, 1.3
    B.HANDLES = (0.7,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.74, 3.38, 1.55, 0.15
    B.NOSE_CUT, B.TAIL_CUT = (0.3, 0.38), (0.25, 0.3)
    B.SHOULDER, B.SHOULDER_SEGS = 0.12, 2
    B.NOSE_SEGS = 2
    B.EXTRA_Z = (5.15,)
    B.top_y = L.make_top_y(B, nose=0.32, bumper=0.56, hood_rear=0.66, deck=1.0, tail=0.92, brk=5.15)
    B.CABIN = dict(yb=0.66, yr=2.38, hwb=2.4, hwr=2.05, zf_top=-0.55, zr_top=4.25, zr_base=B.DECK_FRONT + 0.02, ch=0.15, round=2,
                   us=[0.0, 0.1, 0.52, 0.6, 0.84, 0.9, 1.0])
    B.TAIL_GARNISH = (-2.3, 2.3, -0.25, 0.12)
    B.LAMP_Y = -0.85

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Phares rectangulaires larges, fente de calandre noire, bouclier noir
        L.front_rect(b, 'Grille', 'Trim', -0.95, 0.95, -0.02, 0.26, fz)
        L.front_rect(b, 'Intake', 'Trim', -2.25, 2.25, -0.55, -1.2, fz)
        for s in (1, -1):
            L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * 1.05, s * 2.15, -0.06, 0.3, fz - 0.02)
            # grande prise d'air noire derrière la porte (moteur central)
            x = s * (B.BODY_HW + 0.03)
            b.face('SideIntake_' + L.side(s), 'Trim', [(x, -0.25, 1.38), (x, -0.25, 2.4), (x, 0.52, 2.4), (x, 0.52, 1.6)])
            # feux arrière rectangulaires
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.15, s * 2.15, 0.2, 0.58, tz)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.3)
        L.rear_common(b, B, exhaust_x=-1.45, plate_y=-0.35)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.0, 5.1, 2.42, 2.3, blades=1, plates=True, post=0.15)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
