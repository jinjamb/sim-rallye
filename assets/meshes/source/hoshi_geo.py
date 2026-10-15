"""
Géométrie de la Hoshi (« étoile ») : berline de rallye à phares ronds, façon
Impreza, dans le même style dessin animé que la Hayate (hayate_geo.py, dont
elle reprend la construction) : grands plans plats, noirs façon manga.
Ce qui la distingue : ailes en bosses à pans coupés, nez plus droit, coffre
court et lunette très inclinée, habitacle plus haut, gros phares ronds dans
un bandeau noir, calandre hexagonale, feux arrière ronds doublés.
"""
import math
import lib_cars as L


def configure(B):
    B.NOSE_Z, B.TAIL_Z = -6.55, 6.35
    B.BUMPER_F, B.BUMPER_R = -5.7, 5.7
    B.HOOD_REAR = -2.4
    B.DECK_FRONT = 3.45
    B.DOOR_SPLIT, B.DOOR_REAR = 0.0, 2.3
    B.BODY_HW, B.FLARE_HW = 2.82, 3.3
    B.FLARE_LEN, B.FLARE_RAMP = 1.45, 0.5
    B.CABIN = dict(yb=0.6, yr=2.42, hwb=2.45, hwr=2.02, zf_top=-0.5, zr_top=1.95, zr_base=B.DECK_FRONT + 0.02)
    B.LAMP_Y = -0.84
    B.TAIL_GARNISH = (-2.25, 2.25, -0.02, 0.48)


    def top_y(z):
        """Capot presque plat, nez court et droit, coffre court et haut."""
        if z <= B.HOOD_REAR:
            if z < B.BUMPER_F:
                return 0.5 - 0.22 * (B.BUMPER_F - z) / (B.BUMPER_F - B.NOSE_Z)
            return 0.66 - 0.16 * (B.HOOD_REAR - z) / (B.HOOD_REAR - B.BUMPER_F)
        if z >= B.DECK_FRONT:
            if z > 5.95:
                return 0.84 - 0.22 * (z - 5.95) / (B.TAIL_Z - 5.95)
            return 0.84
        return 0.66 + 0.18 * (z - B.HOOD_REAR) / (B.DECK_FRONT - B.HOOD_REAR)


    B.top_y = top_y


    def octagon(b, name, paint, cx, cy, z, r, depth=0.06):
        b.disc(name, paint, (cx, cy, z), r, depth, 'z', n=8)


    def details(b):
        nz = B.NOSE_Z
        fz = nz - 0.04
        # Bandeau noir des phares, gros phares ronds, calandre hexagonale
        b.face('Grille', 'Trim', [(-2.3, 0.3, fz), (2.3, 0.3, fz), (2.3, -0.42, fz), (-2.3, -0.42, fz)])
        for s in (1, -1):
            octagon(b, 'Headlight_' + ('R' if s > 0 else 'L'), 'Head', s * 1.7, -0.06, fz - 0.03, 0.34)
        # barre de calandre couleur carrosserie, en travers du bandeau
        b.prism('GrilleBar', 'Body', [(-0.75, -0.12), (0.75, -0.12), (0.75, 0.0), (-0.75, 0.0)][::-1], fz - 0.08, fz)
        # Bouche basse et gros antibrouillards dans des écrins noirs
        b.face('Intake', 'Trim', [(-1.3, -0.62, fz), (1.3, -0.62, fz), (1.15, -1.08, fz), (-1.15, -1.08, fz)])
        for s in (1, -1):
            b.face('Intake', 'Trim', [(s * 1.6, -0.6, fz), (s * 2.35, -0.6, fz), (s * 2.35, -1.1, fz), (s * 1.6, -1.1, fz)][:: (1 if s > 0 else -1)])
            octagon(b, 'FogLight_' + ('R' if s > 0 else 'L'), 'Lamp', s * 1.97, -0.85, fz - 0.03, 0.2)
            # feux arrière : deux ronds par côté dans le bandeau noir
            for k, x in enumerate((1.35, 1.95)):
                b.disc('TailLight_' + ('R' if s > 0 else 'L'), 'Tail', (s * x, 0.23, B.TAIL_Z + 0.05), 0.19, -0.03, 'z', n=8)
            b.prism('Mirror_' + ('R' if s > 0 else 'L'), 'Body',
                    [(s * 2.32, 0.66), (s * B.BODY_HW, 0.7), (s * B.BODY_HW, 0.98), (s * 2.34, 0.96)][:: (1 if s > 0 else -1)], -1.9, -1.6)
        b.disc('Exhaust', 'Trim', (-1.45, -0.98, B.TAIL_Z - 0.25), 0.22, 0.4, 'z', n=8)
        b.face('RearPanel', 'Trim', [(-0.8, -0.2, B.TAIL_Z + 0.03), (0.8, -0.2, B.TAIL_Z + 0.03), (0.8, -0.55, B.TAIL_Z + 0.03), (-0.8, -0.55, B.TAIL_Z + 0.03)])
        b.prism('Splitter', 'Trim', [(-2.4, -1.16), (2.4, -1.16), (2.5, -1.08), (-2.5, -1.08)][::-1], nz - 0.14, nz + 0.9)


    def hood_scoop(b):
        """Variante de capot : grande écope plate, bouche noire vers l'avant (façon Impreza)."""
        z0, z1 = -4.7, -3.2
        w = 1.15
        y0, y1 = top_y(z0) + 0.02, top_y(z1) + 0.02
        h = 0.34
        # dessus, flancs, bouche
        b.face('HoodScoop', 'Body', [(-w, y0 + h, z0), (w, y0 + h, z0), (w, y1 + 0.06, z1), (-w, y1 + 0.06, z1)])
        for s in (1, -1):
            b.face('HoodScoop', 'Body', [(s * w, y0, z0), (s * w, y0 + h, z0), (s * w, y1 + 0.06, z1), (s * w, y1, z1)])
        b.face('HoodScoopMouth', 'Trim', [(-w, y0, z0 - 0.01), (w, y0, z0 - 0.01), (w, y0 + h, z0 - 0.01), (-w, y0 + h, z0 - 0.01)])
        for s in (1, -1):
            for k in range(3):
                zc = -2.95 - k * 0.3
                yv = top_y(zc) + 0.02
                b.face('HoodVents', 'Trim', [(s * 1.4, yv, zc), (s * 2.0, yv, zc), (s * 2.0, yv, zc - 0.16), (s * 1.4, yv, zc - 0.16)])


    def rally_wing(b):
        """Variante d'aileron : double lame sur hauts montants (façon STi)."""
        yd = top_y(5.6)
        yw = yd + 1.0
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 1.1, yd), (sx * 1.32, yd), (sx * 1.32, yw + 0.45), (sx * 1.1, yw + 0.45)][:: (1 if sx > 0 else -1)], 5.25, 5.95)
        b.prism('WingBlade', 'Body', [(-2.7, yw), (2.7, yw), (2.7, yw + 0.16), (-2.7, yw + 0.16)][::-1], 4.95, 6.2)
        b.prism('WingBlade', 'Body', [(-2.7, yw + 0.42), (2.7, yw + 0.42), (2.7, yw + 0.56), (-2.7, yw + 0.56)][::-1], 5.25, 6.35)
        for sx in (1, -1):
            b.prism('Wing', 'Trim', [(sx * 2.7, yw - 0.3), (sx * 2.82, yw - 0.3), (sx * 2.82, yw + 0.75), (sx * 2.7, yw + 0.75)][:: (1 if sx > 0 else -1)], 4.85, 6.45)


    B.details = details
    B.hood_scoop = hood_scoop
    B.rally_wing = rally_wing


def build(variant='full'):
    return L.build_with(configure, variant)


if __name__ == '__main__':
    panels = build('full')
    tris = sum(sum(len(f) - 2 for f in p['faces']) for p in panels)
    print(len(panels), 'pièces,', tris, 'triangles')
