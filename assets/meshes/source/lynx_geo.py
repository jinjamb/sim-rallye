"""
Lynx : inspirée de la 206 WRC. Petite compacte lisse et ronde : capot court
et plongeant qui file dans un pare-brise très incliné, toit qui culmine au
milieu, hayon arrondi, passages de roue intégrés et ronds, grands phares en
amande qui enveloppent les coins du nez et remontent sur les ailes, bouche
ovale en sourire, jonc noir sur les portes, écopes de toit, aileron en arceau.
"""
import math
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.0, 5.6
    B.BUMPER_F, B.BUMPER_R = -5.35, 5.15
    B.HOOD_REAR, B.DECK_FRONT = -3.0, 4.85
    B.DOORS, B.DOOR_SPLIT, B.DOOR_REAR = 2, 1.35, 1.35
    B.HANDLES = (0.75,)
    B.BODY_HW, B.FLARE_HW, B.FLARE_LEN, B.FLARE_RAMP = 2.72, 3.2, 1.25, 1.0
    B.NOSE_CUT, B.TAIL_CUT = (1.15, 1.35), (0.6, 0.75)
    B.SIDE_TAPER, B.CREASE = 0.3, 0.42
    B.SHOULDER, B.SHOULDER_SEGS, B.CROWN = 0.6, 6, 0.24
    B.NOSE_SEGS, B.TAIL_SEGS, B.ARCH_SEG = 6, 4, 7
    B.ROCKER_H = 0.0
    B.EXTRA_Z = (-4.6, 5.25)
    B.SCOOP = (0.64, 0.5, 0.3)  # toit très bombé : écope plus haute pour qu'elle se voie
    B.top_y = L.make_top_y(B, nose=0.12, bumper=0.48, hood_rear=0.92, deck=0.96, tail=0.66, brk=5.25)
    B.CABIN = dict(yb=0.92, yr=2.3, hwb=2.15, hwr=1.62, zf_top=-0.45, zr_top=3.45, zr_base=B.DECK_FRONT + 0.02,
                   ch=0.6, round=6, crown=0.14,
                   us=[0.0, 0.12, 0.6, 0.67, 0.88, 0.93, 1.0], vs=[0.0, 0.1, 0.86, 1.0])
    B.TAIL_GARNISH = (-0.9, 0.9, -0.6, -0.32)
    B.LAMP_Y = -0.8

    def details(b):
        nz, fz = B.NOSE_Z, B.NOSE_Z - 0.04
        # bouche ovale en sourire
        mouth = [(math.cos(a) * 1.35, -0.78 + math.sin(a) * 0.36) for a in [math.pi * (1 + k / 11) for k in range(12)]]
        mouth = [(-1.45, -0.62), (1.45, -0.62)] + [(x, y) for x, y in reversed(mouth)][1:-1]
        b.face('Grille', 'Trim', [(x, y, fz) for x, y in mouth])
        L.front_rect(b, 'GrilleSlot', 'Trim', -0.55, 0.55, -0.12, -0.02, fz)
        for s in (1, -1):
            # grand phare en amande : sur le coin du nez, il remonte sur l'aile
            L.wrap_patch(b, B, 'Headlight_' + L.side(s), 'Head', s, nz + 0.05, nz + 1.7,
                         lambda t: -0.3 + 0.62 * t ** 1.2,
                         lambda t: -0.3 + 0.62 * t ** 1.2 + 0.1 + 0.42 * math.sin(math.pi * min(1.0, t * 1.1)),
                         steps=12)
            b.disc('FogLight_' + L.side(s), 'Lamp', (s * 1.05, -0.78, fz - 0.05), 0.13, 0.06, 'z', n=8)
            tz = B.TAIL_Z + 0.03
            L.wrap_patch(b, B, 'TailLight_' + L.side(s), 'Tail', s, B.TAIL_Z - 0.55, B.TAIL_Z - 0.04,
                         lambda t: 0.42 + 0.05 * t, lambda t: 0.86 - 0.06 * t, steps=6)
        # jonc noir sur les portes
        L.side_line(b, B, 'DoorStrip', -0.42, -2.3, 2.3)
        # écopes de toit
        yr = B.CABIN['yr'] + B.CABIN['crown']
        for x in (-0.35, 0.35):
            b.prism('RoofScoop', 'Body', [(x - 0.22, yr - 0.02), (x + 0.22, yr - 0.02), (x + 0.2, yr + 0.16), (x - 0.2, yr + 0.16)][::-1], -0.35, 0.25)
            L.front_rect(b, 'RoofScoopMouth', 'Trim', x - 0.17, x + 0.17, yr, yr + 0.13, -0.36)
        L.mirrors(b, B)
        L.rear_common(b, B, exhaust_x=-1.1, plate_y=0.32)

    def rally_wing(b):
        # aileron en arceau : montants qui partent du haut du hayon
        c = B.CABIN
        y0 = c['yr'] - 0.15
        for sx in (1, -1):
            b.prism('Wing', 'Body', [(sx * 1.35, y0 - 0.2), (sx * 1.55, y0 - 0.2), (sx * 1.55, y0 + 0.42), (sx * 1.35, y0 + 0.42)][:: (1 if sx > 0 else -1)], 3.75, 4.75)
        b.prism('WingBlade', 'Body', [(-2.15, y0 + 0.42), (2.15, y0 + 0.42), (2.15, y0 + 0.58), (-2.15, y0 + 0.58)][::-1], 4.05, 5.25)

    B.details = details
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)
