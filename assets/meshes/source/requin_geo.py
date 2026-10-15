"""
Requin : inspirée de la DS3 WRC. Carrosserie gonflée (flancs qui rentrent
fort au-dessus d'une ligne basse, épaules rondes, capot bombé), toit noir
flottant, montant central couleur carrosserie en aileron de requin, grand
sourire noir bas, bandeaux de lumière verticaux, phares étirés sur les
coins, pas de bas de caisse noir.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.3, 5.55
    B.BUMPER_F, B.BUMPER_R = -5.45, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.35, 4.9
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.5, 1.5
    B.HANDLES = (0.85,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.75, 3.15, 1.4, 0.7
    B.NOSE_CUT, B.TAIL_CUT = (0.75, 0.9), (0.45, 0.55)
    B.SIDE_TAPER, B.CREASE = 0.38, 0.32
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.45, 4, 0.14
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 4, 3, 5
    B.ROCKER_H = 0.0
    B.ROOF_PAINT = 'Trim'
    B.EXTRA_Z = (5.2,)
    B.top_y = L.make_top_y(B, nose=0.2, bumper=0.55, hood_rear=0.68, deck=1.0, tail=0.78, brk=5.2)
    B.CABIN = dict(yb=0.68, yr=2.48, hwb=2.05, hwr=1.72, zf_top=-0.45, zr_top=4.25, zr_base=B.DECK_FRONT + 0.02, ch=0.45, round=4, crown=0.06,
                   us=[0.0, 0.1, 0.5, 0.64, 0.85, 0.9, 1.0], vs=[0.0, 0.12, 0.88, 1.0],
                   glass={(1, 1): 'Window_F', (3, 1): 'Window_R', (5, 1): None}, body_columns=(2,))
    B.TAIL_GARNISH = (-1.4, 1.4, -0.55, -0.25)
    B.LAMP_Y = -0.62

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.6, nz)
        # grand sourire noir bas
        b.face('Grille', 'Trim', [(-1.25, -0.35, fz), (1.25, -0.35, fz), (1.05, -1.05, fz), (-1.05, -1.05, fz)])
        for s in (1, -1):
            wt = B.side_x(0.25, nz)
            b.face('Headlight_' + L.side(s), 'Head', [(s * 0.7, 0.1, fz - 0.02), (s * (wt - 0.06), 0.32, fz - 0.02), (s * (wt - 0.06), 0.1, fz - 0.02), (s * 0.85, -0.08, fz - 0.02)])
            L.front_rect(b, 'LedStrip_' + L.side(s), 'Head', s * (w - 0.42), s * (w - 0.28), -1.0, -0.3, fz - 0.02)
            tz = B.TAIL_Z + 0.03
            wr = B.side_x(0.3, B.TAIL_Z)
            b.face('TailLight_' + L.side(s), 'Tail', [(s * 1.1, 0.62, tz), (s * (wr - 0.05), 0.55, tz), (s * (wr - 0.05), -0.05, tz), (s * (wr - 0.32), -0.05, tz), (s * (wr - 0.32), 0.36, tz), (s * 1.1, 0.4, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=1.3, plate_y=0.25)
        L.roof_wing(b, B, 'RoofSpoiler', 'Trim', 4.05, 4.85, 2.5, 1.7, blades=1, plates=False)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.2, 5.35, 2.72, 2.4, blades=1, plates=True, post=0.3)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    print(len(panels), 'pièces,', sum(sum(len(f) - 2 for f in p['faces']) for p in panels), 'triangles')
