"""
Furia (« furie ») : cinq portes très carrée, inspirée de la Lancia Delta
Integrale. Pare-brise et hayon presque droits, capot plat, quatre phares
carrés dans un bandeau noir, ailes en bosses boulonnées, becquet de toit.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.3, 5.7
    B.BUMPER_F, B.BUMPER_R = -5.6, 5.25
    B.HOOD_REAR, B.DECK_FRONT = -2.5, 5.15
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 4, 0.3, 2.5
    B.HANDLES = (-0.95, 1.45)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.8, 3.3, 1.5, 0.25
    B.NOSE_CUT, B.TAIL_CUT = (0.15, 0.2), (0.15, 0.2)
    B.EXTRA_Z = (5.3,)
    B.top_y = L.make_top_y(B, nose=0.36, bumper=0.62, hood_rear=0.72, deck=0.98, tail=0.92, brk=5.3)
    B.CABIN = dict(yb=0.72, yr=2.46, hwb=2.48, hwr=2.18, zf_top=-1.05, zr_top=4.75, zr_base=B.DECK_FRONT + 0.02)
    B.TAIL_GARNISH = (-2.45, 2.45, -0.3, 0.05)
    B.LAMP_Y = -0.82

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Bandeau noir, quatre phares carrés, fine calandre
        L.front_rect(b, 'Grille', 'Trim', -2.4, 2.4, -0.38, 0.3, fz)
        for s in (1, -1):
            for x in (1.25, 1.95):
                L.front_rect(b, 'Headlight_' + L.side(s), 'Head', s * x - 0.28, s * x + 0.28, -0.3, 0.22, fz - 0.02)
            b.disc('FogLight_' + L.side(s), 'Lamp', (s * 1.5, -0.85, fz - 0.05), 0.2, 0.06, 'z', n=8)
            # feux arrière carrés sur les coins
            tz = B.TAIL_Z + 0.03
            L.front_rect(b, 'TailLight_' + L.side(s), 'Tail', s * 1.85 - 0.45, s * 1.85 + 0.45, 0.12, 0.62, tz)
        L.front_rect(b, 'Intake', 'Trim', -1.1, 1.1, -0.6, -1.1, fz)
        L.mirrors(b, B)
        L.splitter(b, B, half=2.45)
        L.rear_common(b, B, exhaust_x=-1.45, plate_y=0.55)
        # Becquet de toit d'origine (au-dessus du hayon)
        L.roof_wing(b, B, 'RoofSpoiler', 'Body', 4.35, 5.05, 2.48, 2.1, blades=1, plates=False)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.4, 5.55, 2.72, 2.3, blades=1, plates=True, post=0.2)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
