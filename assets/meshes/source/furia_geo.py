"""
Furia : inspirée de la Lancia Delta Integrale. Haute comme une boîte :
flancs droits, arêtes vives, capot plat, pare-brise et hayon presque
verticaux, grande verrière aux montants fins, ailes en bosses boulonnées,
quatre phares carrés dans un bandeau noir, becquet de toit.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.3, 5.65
    B.BUMPER_F, B.BUMPER_R = -5.6, 5.25
    B.HOOD_REAR, B.DECK_FRONT = -2.55, 5.2
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 4, 0.3, 2.5
    B.HANDLES = (-0.95, 1.45)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.32, 1.45, 0.3
    B.NOSE_CUT, B.TAIL_CUT = (0.1, 0.12), (0.1, 0.12)
    B.ROCKER_H = 0.3
    B.EXTRA_Z = (5.35,)
    B.top_y = L.make_top_y(B, nose=0.42, bumper=0.68, hood_rear=0.8, deck=1.02, tail=1.0, brk=5.35)
    B.CABIN = dict(yb=0.8, yr=2.72, hwb=2.5, hwr=2.4, zf_top=-1.4, zr_top=4.98, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.05, 0.45, 0.48, 0.88, 0.9, 1.0], vs=[0.0, 0.06, 0.93, 1.0])
    B.TAIL_GARNISH = (-2.5, 2.5, -0.3, 0.05)
    B.LAMP_Y = -0.85

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        L.front_rect(b, 'Grille', 'Trim', -2.45, 2.45, -0.4, 0.34, fz)
        for s in (1, -1):
            for x in (1.25, 1.95):
                L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * x - 0.28, s * x + 0.28, -0.3, 0.24, fz - 0.02)
            b.disc('FogLight_' + L.side(s), 'Lamp', (s * 1.55, -0.9, fz - 0.05), 0.2, 0.06, 'z', n=8)
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.45, s * 2.45, 0.14, 0.66, tz)
        for k in range(4):
            L.front_rect(b, 'GrilleBar', 'Body', -0.55, 0.55, 0.22 - k * 0.17, 0.26 - k * 0.17, fz - 0.02)
        L.front_rect(b, 'Intake', 'Trim', -1.1, 1.1, -0.65, -1.15, fz)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.45, plate_y=0.55)
        L.roof_wing(b, B, 'RoofSpoiler', 'Body', 4.45, 5.15, 2.74, 2.3, blades=1, plates=False)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.45, 5.6, 2.95, 2.4, blades=1, plates=True, post=0.18)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
