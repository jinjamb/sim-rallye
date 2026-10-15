"""
Requin (« requin ») : compacte trois portes au toit flottant, inspirée de la
DS3 WRC. Toit noir qui semble posé, montant central couleur carrosserie en
aileron de requin, bandeaux de lumière verticaux dans le bouclier, grands
phares étirés vers l'arrière, feux arrière en boomerang.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.3, 5.6
    B.BUMPER_F, B.BUMPER_R = -5.45, 5.05
    B.HOOD_REAR, B.DECK_FRONT = -2.35, 4.95
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.5, 1.5
    B.HANDLES = (0.85,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.75, 3.3, 1.5, 0.35
    B.NOSE_CUT, B.TAIL_CUT = (0.75, 0.9), (0.45, 0.55)
    B.EXTRA_Z = (5.25,)
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.42, 4, 0.12
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 4, 3, 5
    B.top_y = L.make_top_y(B, nose=0.18, bumper=0.5, hood_rear=0.62, deck=0.96, tail=0.74, brk=5.25)
    B.ROOF_PAINT = 'Trim'
    B.CABIN = dict(yb=0.62, yr=2.34, hwb=2.4, hwr=2.02, zf_top=-0.45, zr_top=4.3, zr_base=B.DECK_FRONT + 0.02, ch=0.48, round=4, crown=0.06,
                   us=[0.0, 0.1, 0.5, 0.64, 0.85, 0.9, 1.0],
                   glass={(1, 1): 'Window_F', (3, 1): 'Window_R', (5, 1): None},
                   body_columns=(2,))
    B.TAIL_GARNISH = (-1.6, 1.6, -0.55, -0.2)
    B.LAMP_Y = -0.7

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # Calandre noire en trapèze, grands phares étirés
        b.face('Grille', 'Trim', [(-1.0, 0.2, fz), (1.0, 0.2, fz), (1.35, -0.9, fz), (-1.35, -0.9, fz)])
        for s in (1, -1):
            b.face('Headlight_' + L.side(s), 'Head', [(s * 1.15, 0.28, fz - 0.02), (s * 2.2, 0.2, fz - 0.02), (s * 2.25, -0.05, fz - 0.02), (s * 1.25, 0.02, fz - 0.02)])
            # bandeaux de lumière verticaux
            L.front_rect(b, 'LedStrip_' + L.side(s), 'Head', s * 1.62 - 0.08, s * 1.62 + 0.08, -1.05, -0.3, fz - 0.02)
            b.face('Intake', 'Trim', [(s * 1.82, -0.3, fz), (s * 2.25, -0.3, fz), (s * 2.25, -1.05, fz), (s * 1.82, -1.05, fz)][:: (1 if s > 0 else -1)])
            # feux arrière en boomerang
            tz = B.TAIL_Z + 0.03
            b.face('TailLight_' + L.side(s), 'Tail', [(s * 1.25, 0.66, tz), (s * 2.18, 0.6, tz), (s * 2.18, -0.05, tz), (s * 1.9, -0.05, tz), (s * 1.9, 0.38, tz), (s * 1.25, 0.42, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.35)
        L.rear_common(b, B, exhaust_x=1.5, plate_y=0.3)
        # Becquet de toit noir d'origine
        L.roof_wing(b, B, 'RoofSpoiler', 'Trim', 4.1, 4.9, 2.36, 2.0, blades=1, plates=False)

    def rally_wing(b):
        # Option : grand aileron sur le hayon, montants noirs
        L.roof_wing(b, B, 'Wing', 'Body', 4.25, 5.45, 2.62, 2.5, blades=1, plates=True, post=0.3)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
