"""
Kaze (« vent ») : la voiture de départ. Compacte de rallye moderne au style
« origami » : arêtes tranchantes, flancs rentrants au-dessus d'une ligne de
caisse marquée, nez plongeant en pointe, phares en triangle, prises d'air
noires en X, becquet de toit noir.
"""
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.4, 5.5
    B.BUMPER_F, B.BUMPER_R = -5.5, 5.0
    B.HOOD_REAR, B.DECK_FRONT = -2.4, 4.9
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.45, 1.45
    B.HANDLES = (0.8,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.75, 3.3, 1.5, 0.35
    B.NOSE_CUT, B.TAIL_CUT = (0.85, 1.0), (0.35, 0.4)
    B.SIDE_TAPER, B.CREASE = 0.28, 0.5
    B.SHOULDER = 0.08
    B.ROCKER_H = 0.38
    B.EXTRA_Z = (5.15,)
    B.top_y = L.make_top_y(B, nose=0.0, bumper=0.42, hood_rear=0.66, deck=0.98, tail=0.8, brk=5.15)
    B.CABIN = dict(yb=0.66, yr=2.34, hwb=2.2, hwr=1.85, zf_top=-0.55, zr_top=4.15, zr_base=B.DECK_FRONT + 0.02,
                   us=[0.0, 0.1, 0.52, 0.6, 0.83, 0.9, 1.0], vs=[0.0, 0.18, 0.86, 1.0])
    B.TAIL_GARNISH = (-1.6, 1.6, -0.5, -0.15)
    B.LAMP_Y = -0.7

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        w = B.side_x(-0.5, nz)
        for s in (1, -1):
            # phares en triangle sur les coins hauts
            b.face('Headlight_' + L.side(s), 'Head', [(s * 0.35, -0.05, fz - 0.02), (s * (w - 0.02), 0.02, fz - 0.02), (s * (w - 0.1), -0.32, fz - 0.02)])
            # prises d'air en X : deux triangles noirs par côté
            b.face('Intake', 'Trim', [(s * 0.1, -0.45, fz), (s * (w - 0.05), -0.5, fz), (s * 0.1, -0.85, fz)][:: (1 if s > 0 else -1)])
            b.face('Intake', 'Trim', [(s * 0.1, -0.95, fz), (s * (w - 0.05), -1.3, fz), (s * (w - 0.05), -0.62, fz)][:: (1 if s > 0 else -1)])
            tz = B.TAIL_Z + 0.03
            wr = B.side_x(0.4, B.TAIL_Z)
            b.face('TailLight_' + L.side(s), 'Tail', [(s * 0.9, 0.62, tz), (s * (wr - 0.05), 0.62, tz), (s * (wr - 0.05), 0.22, tz)][:: (1 if s > 0 else -1)])
        L.mirrors(b, B)
        L.splitter(b, B, half=2.2)
        L.rear_common(b, B, exhaust_x=1.3, plate_y=0.25)
        L.roof_wing(b, B, 'RoofSpoiler', 'Trim', 4.0, 4.8, 2.36, 1.85, blades=1, plates=False)

    def rally_wing(b):
        L.roof_wing(b, B, 'Wing', 'Body', 4.1, 5.3, 2.62, 2.45, blades=1, plates=True, post=0.3)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
