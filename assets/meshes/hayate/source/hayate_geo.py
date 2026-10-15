"""
Géométrie de la Hayate, dans le repère du châssis du jeu (studs) :
X à droite, Y en haut, l'avant en -Z. Sol à Y = -2.1, roues à
X = ±2.58, Z = ±4.05, centre Y = -1.02, rayon 1.08.

Sortie : une liste de panneaux {name, paint, verts, faces}. Chaque panneau
est une pièce séparée (les bosses déplacent chaque pièce, le contour à
l'encre souligne chaque jointure).
"""
import math
import numpy as np

WHEEL_Z = (-4.05, 4.05)
WHEEL_Y = -1.02
ARCH_R = 1.4
GROUND = -2.1

NOSE_Z, TAIL_Z = -6.75, 6.55
BOTTOM = -1.42
HOOD_REAR = -2.45   # pied du pare-brise
DECK_FRONT = 3.85   # bas de la lunette
BUMPER_F = -5.85    # jointure bouclier / ailes / capot
BUMPER_R = 5.85
DOOR_SPLIT = 0.05   # porte avant / porte arrière
DOOR_REAR = 2.55    # fin de la porte arrière


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def half_width(z):
    """Demi-largeur (vue de dessus) : un seul pan coupé aux quatre coins, et
    des ailes en marche franche sur les roues (pas de courbe douce)."""
    hw = 2.78
    for wz in WHEEL_Z:
        if abs(z - wz) <= 1.62:
            hw = 3.32
    if z < NOSE_Z + 0.45:
        hw -= 0.42 * (1 - (z - NOSE_Z) / 0.45)
    if z > TAIL_Z - 0.4:
        hw -= 0.34 * (1 - (TAIL_Z - z) / 0.4)
    return hw


def top_y(z):
    """Dessus de la caisse : capot plat et droit, un seul pan pour le nez."""
    if z <= HOOD_REAR:
        if z < BUMPER_F:
            return 0.42 - 0.34 * (BUMPER_F - z) / (BUMPER_F - NOSE_Z)
        return 0.62 - 0.2 * (HOOD_REAR - z) / (HOOD_REAR - BUMPER_F)
    if z >= DECK_FRONT:
        if z > 6.0:
            return 0.72 - 0.24 * (z - 6.0) / (TAIL_Z - 6.0)
        return 0.72
    return 0.62 + 0.1 * (z - HOOD_REAR) / (DECK_FRONT - HOOD_REAR)


ARCH_SEG = 3  # demi-arc en 3 pans : un passage de roue anguleux


def bottom_y(z):
    """Bas de caisse ; passage de roue polygonal au-dessus de chaque roue."""
    y = BOTTOM
    for wz in WHEEL_Z:
        d = z - wz
        if abs(d) < ARCH_R:
            arch = WHEEL_Y + math.sqrt(max(0.0, ARCH_R ** 2 - d * d))
            y = max(y, min(arch, top_y(z) - 0.6))
    return y


def stations():
    zs = [NOSE_Z, NOSE_Z + 0.45, BUMPER_F, HOOD_REAR, DOOR_SPLIT, DOOR_REAR, DECK_FRONT, BUMPER_R, 6.0, TAIL_Z - 0.4, TAIL_Z]
    for wz in WHEEL_Z:
        for k in range(-ARCH_SEG, ARCH_SEG + 1):
            zs.append(wz + ARCH_R * math.sin(math.pi / 2 * k / ARCH_SEG) * 0.999)
        zs += [wz - 1.62, wz + 1.62, wz - 1.6201, wz + 1.6201]
    zs = sorted(set(round(z, 4) for z in zs if NOSE_Z <= z <= TAIL_Z))
    return zs


# Indices des points d'une section (côté droit, du bas vers le dessus).
# 0 milieu du plancher, 1 bord du plancher, 2 bas du flanc, 3 haut du flanc,
# 4 épaule, 5 dessus, 6 milieu du dessus (plat : pas de bombé).
def section(z):
    hw = half_width(z)
    yb = bottom_y(z)
    yt = top_y(z)
    arch = yb > BOTTOM + 0.05
    pts = [
        (0.0, yb),
        (hw, yb),
        (hw, yb),
        (hw, yt),
        (hw, yt),
        (hw * 0.5, yt),
        (0.0, yt),
    ]
    return pts


SEG_NAMES = ['floor', 'sill', 'side', 'shoulder', 'top', 'topmid']


def panel_for(seg, zc, side):
    """Panneau d'une face de la caisse, d'après son segment et sa place."""
    s = 'R' if side > 0 else 'L'
    if seg == 'floor':
        return 'Underbody', 'Trim'
    if zc < BUMPER_F:
        return ('BumperFrontLip', 'Trim') if seg == 'sill' else ('BumperFront', 'Body')
    if zc > BUMPER_R:
        return ('BumperRearLip', 'Trim') if seg == 'sill' else ('BumperRear', 'Body')
    if seg in ('top', 'topmid'):
        if zc < HOOD_REAR:
            return 'Hood', 'Body'
        if zc > DECK_FRONT:
            return 'Trunk', 'Body'
        return 'Cowl', 'Body'  # sous l'habitacle, invisible
    if zc < HOOD_REAR:
        return 'Fender_F' + s, 'Body'
    if zc < DOOR_SPLIT:
        return 'Door_F' + s, 'Body'
    if zc < DOOR_REAR:
        return 'Door_R' + s, 'Body'
    return 'Fender_R' + s, 'Body'


class Builder:
    def __init__(self):
        self.panels = {}

    def panel(self, name, paint):
        key = name
        if key not in self.panels:
            self.panels[key] = {'name': name, 'paint': paint, 'verts': [], 'faces': [], 'index': {}}
        return self.panels[key]

    def face(self, name, paint, pts, ref=None):
        # Oriente la face vers l'extérieur : à l'opposé de `ref` (centre de la
        # pièce pour un solide, axe de la voiture pour la coque).
        P = np.array(pts, float)
        c = P.mean(0)
        nrm = np.zeros(3)
        for i in range(len(P)):
            a, d = P[i], P[(i + 1) % len(P)]
            nrm += np.array([(a[1] - d[1]) * (a[2] + d[2]), (a[2] - d[2]) * (a[0] + d[0]), (a[0] - d[0]) * (a[1] + d[1])])
        if ref is None:
            ref = (0.0, 0.15, min(5.0, max(-5.2, c[2])))
        if np.dot(nrm, c - np.array(ref)) < 0:
            pts = list(pts)[::-1]
        p = self.panel(name, paint)
        idx = []
        for v in pts:
            k = (round(v[0], 5), round(v[1], 5), round(v[2], 5))
            if k not in p['index']:
                p['index'][k] = len(p['verts'])
                p['verts'].append(k)
            idx.append(p['index'][k])
        # retire les points répétés (faces dégénérées)
        clean = []
        for i in idx:
            if not clean or clean[-1] != i:
                clean.append(i)
        if len(clean) > 1 and clean[0] == clean[-1]:
            clean.pop()
        if len(clean) >= 3:
            p['faces'].append(clean)

    def box(self, name, paint, center, size, rot=None):
        cx, cy, cz = center
        sx, sy, sz = (s / 2 for s in size)
        corners = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        if rot is not None:
            corners = [tuple(np.array(rot) @ np.array(c)) for c in corners]
        v = [(cx + c[0], cy + c[1], cz + c[2]) for c in corners]
        for f in ([0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]):
            self.face(name, paint, [v[i] for i in f], ref=center)

    def prism(self, name, paint, outline, z0, z1):
        """Prisme : contour (x, y) extrudé de z0 à z1 (contour dans le sens trigo vu de -Z)."""
        a = [(x, y, z0) for x, y in outline]
        b = [(x, y, z1) for x, y in outline]
        n = len(outline)
        ref = (sum(x for x, _ in outline) / n, sum(y for _, y in outline) / n, (z0 + z1) / 2)
        self.face(name, paint, a[::-1], ref)
        self.face(name, paint, b, ref)
        for i in range(n):
            j = (i + 1) % n
            self.face(name, paint, [a[i], a[j], b[j], b[i]], ref)

    def disc(self, name, paint, center, radius, depth, axis, n=12, ring=None):
        """Cylindre court (phare rond) ; axis : 'z' (vers l'avant/arrière) ou 'x'."""
        cx, cy, cz = center
        pts = []
        for k in range(n):
            a = 2 * math.pi * k / n + math.pi / n
            pts.append((math.cos(a) * radius, math.sin(a) * radius))
        if axis == 'z':
            front = [(cx + u, cy + v, cz) for u, v in pts]
            back = [(cx + u, cy + v, cz + depth) for u, v in pts]
        else:
            front = [(cx, cy + v, cz + u) for u, v in pts]
            back = [(cx + depth, cy + v, cz + u) for u, v in pts]
        ref = (cx + (depth / 2 if axis == 'x' else 0), cy, cz + (depth / 2 if axis == 'z' else 0))
        self.face(name, paint, front, ref)
        self.face(name, paint, back, ref)
        for i in range(n):
            j = (i + 1) % n
            self.face(name, paint, [front[i], front[j], back[j], back[i]], ref)


def lower_body(b):
    zs = stations()
    secs = [section(z) for z in zs]
    for i in range(len(zs) - 1):
        z0, z1 = zs[i], zs[i + 1]
        zc = (z0 + z1) / 2
        A, B = secs[i], secs[i + 1]
        for side in (1, -1):
            for k in range(6):
                seg = SEG_NAMES[k]
                name, paint = panel_for(seg, zc, side)
                p0 = (side * A[k][0], A[k][1], z0)
                p1 = (side * A[k + 1][0], A[k + 1][1], z0)
                p2 = (side * B[k + 1][0], B[k + 1][1], z1)
                p3 = (side * B[k][0], B[k][1], z1)
                quad = [p0, p3, p2, p1] if side > 0 else [p0, p1, p2, p3]
                b.face(name, paint, quad)
    # Faces avant et arrière : polygones de section, coupés en bouclier
    for z, sec, front in ((zs[0], secs[0], True), (zs[-1], secs[-1], False)):
        ring = [(x, y) for x, y in sec] + [(-x, y) for x, y in reversed(sec[:-1])][:-1]
        ring = ring[:-1] if ring[-1] == ring[0] else ring
        pts = [(x, y, z) for x, y in ring]
        name = 'BumperFront' if front else 'BumperRear'
        b.face(name, 'Body', pts[::-1] if front else pts)
    # Intérieur des passages de roue : flasques sombres
    for wz in WHEEL_Z:
        for side in (1, -1):
            x = side * 2.25
            pts = []
            for k in range(11):
                a = math.pi * k / 10
                pts.append((x, WHEEL_Y + math.sin(a) * (ARCH_R - 0.02), wz + math.cos(a) * (ARCH_R - 0.02)))
            pts.append((x, WHEEL_Y - 0.4, wz - ARCH_R))
            pts.append((x, WHEEL_Y - 0.4, wz + ARCH_R))
            b.face('WheelWell', 'Trim', pts if side < 0 else pts[::-1])


def cabin(b):
    """Habitacle : pare-brise, toit, montants, vitres, lunette."""
    yb, yr = 0.56, 2.28
    hwb, hwr = 2.45, 2.1
    zf_base, zf_top = HOOD_REAR - 0.02, -0.75
    zr_top, zr_base = 2.6, DECK_FRONT + 0.02

    def ring(zbase, ztop):
        # côté droit : base, haut du flanc, bord du toit, milieu du toit
        prof = [(hwb, yb), (hwr, yr - 0.001), (hwr - 0.001, yr), (0.0, yr)]
        out = []
        for x, y in prof:
            t = (y - yb) / (yr - yb)
            out.append((x, y, zbase + (ztop - zbase) * t))
        return out
    F = ring(zf_base, zf_top)
    R = ring(zr_base, zr_top)

    def mir(p):
        return (-p[0], p[1], p[2])

    def lerp(a, c, t):
        return tuple(a[i] + (c[i] - a[i]) * t for i in range(3))

    def bil(q, u, v):  # q : coin bas-avant, bas-arrière, haut-arrière, haut-avant
        return lerp(lerp(q[0], q[1], u), lerp(q[3], q[2], u), v)

    # Toit (bord et dessus)
    for side in (1, -1):
        m = (lambda p: p) if side > 0 else mir
        for k in (1, 2):
            a, c = m(F[k]), m(F[k + 1])
            d, e = m(R[k]), m(R[k + 1])
            quad = [a, d, e, c] if side > 0 else [a, c, e, d]
            b.face('Roof', 'Body', quad)
    # Flancs : montants, vitres (deux vitres et une custode)
    us = [0.0, 0.1, 0.43, 0.49, 0.83, 0.88, 1.0]
    vs = [0.0, 0.16, 0.86, 1.0]
    glass_cells = {(1, 1): 'Window_F', (3, 1): 'Window_R', (5, 1): None}
    for side in (1, -1):
        m = (lambda p: p) if side > 0 else mir
        q = [m(F[0]), m(R[0]), m(R[1]), m(F[1])]
        s = 'R' if side > 0 else 'L'
        for i in range(len(us) - 1):
            for j in range(len(vs) - 1):
                cell = [bil(q, us[i], vs[j]), bil(q, us[i + 1], vs[j]), bil(q, us[i + 1], vs[j + 1]), bil(q, us[i], vs[j + 1])]
                if side < 0:
                    cell = cell[::-1]
                g = glass_cells.get((i, j), 'pillar')
                if g == 'pillar' or g is None:
                    b.face('Pillars', 'Trim', cell)
                else:
                    b.face(g + s, 'Glass', cell)
    # Pare-brise et lunette, avec cadre
    for ringpts, name, front in ((F, 'Windshield', True), (R, 'RearWindow', False)):
        bl, br = mir(ringpts[0]), ringpts[0]
        tl, tr = mir(ringpts[1]), ringpts[1]
        q = [bl, br, tr, tl]
        us2, vs2 = [0, 0.07, 0.93, 1], [0, 0.1, 0.9, 1]
        for i in range(3):
            for j in range(3):
                cell = [bil(q, us2[i], vs2[j]), bil(q, us2[i + 1], vs2[j]), bil(q, us2[i + 1], vs2[j + 1]), bil(q, us2[i], vs2[j + 1])]
                if not front:
                    cell = cell[::-1]
                if i == 1 and j == 1:
                    b.face(name, 'Glass', cell)
                else:
                    b.face('Pillars', 'Trim', cell)
        # bande du haut (bord de toit) jusqu'au milieu
        for side in (1, -1):
            m = (lambda p: p) if side > 0 else mir
            pts = [m(ringpts[1]), m(ringpts[2]), (0.0, ringpts[3][1], ringpts[3][2])]
            tri = pts if (side > 0) == front else pts[::-1]
            b.face('Roof', 'Body', tri[::-1])
        b.face('Roof', 'Body', [tl, tr, (0.0, ringpts[3][1], ringpts[3][2])])
    # Fond de l'habitacle (fermé, sous le capot : invisible)


def details(b):
    nz = NOSE_Z
    # Calandre et grande bouche d'air (marque de la Hayate)
    fz = nz - 0.04
    # Visage en aplats francs : bandeau noir des phares, grande bouche noire.
    b.face('Grille', 'Trim', [(-2.2, 0.0, fz), (2.2, 0.0, fz), (2.2, -0.4, fz), (-2.2, -0.4, fz)])
    b.face('Intake', 'Trim', [(-2.05, -0.6, fz), (2.05, -0.6, fz), (2.05, -1.2, fz), (-2.05, -1.2, fz)])
    for s in (1, -1):
        hl = [(s * 1.05, -0.04, fz - 0.02), (s * 2.1, -0.04, fz - 0.02), (s * 2.1, -0.36, fz - 0.02), (s * 1.05, -0.36, fz - 0.02)]
        b.face('Headlight_' + ('R' if s > 0 else 'L'), 'Head', hl)
        b.disc('FogLight_' + ('R' if s > 0 else 'L'), 'Lamp', (s * 1.6, -0.9, fz - 0.04), 0.18, 0.06, 'z', n=8)
        # feux arrière en bandeau
        tz = TAIL_Z
        tl = [(s * 0.95, 0.34, tz + 0.03), (s * 2.25, 0.3, tz + 0.03), (s * 2.25, -0.05, tz + 0.03), (s * 0.95, -0.02, tz + 0.03)]
        b.face('TailLight_' + ('R' if s > 0 else 'L'), 'Tail', tl if s > 0 else tl[::-1])
        # rétroviseurs
        b.prism('Mirror_' + ('R' if s > 0 else 'L'), 'Body',
                [(s * 2.3, 0.62), (s * 2.78, 0.66), (s * 2.78, 0.92), (s * 2.32, 0.9)][:: (1 if s > 0 else -1)], -1.95, -1.65)
        # bas de caisse noirs (jupes)
        if False: b.prism('Skirt_' + ('R' if s > 0 else 'L'), 'Trim',
                [(s * 2.78, -1.46), (s * 2.98, -1.46), (s * 2.98, -1.1), (s * 2.9, -1.1)][:: (1 if s > 0 else -1)], -2.62, 2.62)
        # échappement
    b.disc('Exhaust', 'Trim', (1.5, -0.98, TAIL_Z - 0.25), 0.19, 0.4, 'z', n=10)
    b.face('RearPanel', 'Trim', [(-0.8, -0.18, TAIL_Z + 0.03), (0.8, -0.18, TAIL_Z + 0.03), (0.8, -0.5, TAIL_Z + 0.03), (-0.8, -0.5, TAIL_Z + 0.03)])
    # sabot avant
    b.prism('Splitter', 'Trim', [(-2.3, -1.16), (2.3, -1.16), (2.4, -1.08), (-2.4, -1.08)][::-1], NOSE_Z - 0.12, NOSE_Z + 0.9)


def ink(b):
    """Le noir façon manga, dans le modèle : lèvres des passages de roue,
    traits des jointures, bas de caisse, bandeau arrière, poignées."""
    T = 0.03  # décollement de la surface
    # Lèvres noires autour des passages de roue
    for wz in WHEEL_Z:
        for sd in (1, -1):
            x = sd * (3.32 + T)
            inner, outer = [], []
            for k in range(-ARCH_SEG, ARCH_SEG + 1):
                th = math.pi / 2 * k / ARCH_SEG
                z = wz + ARCH_R * math.sin(th)
                yi = max(BOTTOM, min(WHEEL_Y + ARCH_R * math.cos(th), top_y(z) - 0.6))
                zo = wz + (ARCH_R + 0.2) * math.sin(th)
                yo = max(BOTTOM, min(WHEEL_Y + (ARCH_R + 0.2) * math.cos(th), top_y(z) - 0.4))
                inner.append((x, yi, z)); outer.append((x, yo, zo))
            # les deux bouts descendent jusqu'au bas de caisse
            inner = [(x, BOTTOM, inner[0][2])] + inner + [(x, BOTTOM, inner[-1][2])]
            outer = [(x, BOTTOM, outer[0][2])] + outer + [(x, BOTTOM, outer[-1][2])]
            for k in range(len(inner) - 1):
                b.face('ArchLip_' + ('F' if wz < 0 else 'R') + ('R' if sd > 0 else 'L'), 'Trim', [inner[k], inner[k + 1], outer[k + 1], outer[k]])
    # Traits verticaux des jointures (flancs)
    def vline(name, z, y0, y1, w=0.09):
        for sd in (1, -1):
            x = sd * (half_width(z) + T)
            b.face(name + ('R' if sd > 0 else 'L'), 'Trim', [(x, y0, z - w / 2), (x, y0, z + w / 2), (x, y1, z + w / 2), (x, y1, z - w / 2)])
    vline('Ink_DoorF_', DOOR_SPLIT, BOTTOM + 0.5, top_y(DOOR_SPLIT) - 0.02)
    vline('Ink_DoorR_', DOOR_REAR - 0.05, BOTTOM + 0.5, top_y(DOOR_REAR) - 0.02)
    vline('Ink_DoorA_', HOOD_REAR + 0.05, BOTTOM + 0.5, top_y(HOOD_REAR) - 0.02)
    vline('Ink_BumpF_', BUMPER_F + 0.05, BOTTOM + 0.05, top_y(BUMPER_F) - 0.02)
    vline('Ink_BumpR_', BUMPER_R - 0.05, BOTTOM + 0.05, top_y(BUMPER_R) - 0.02)
    # Contour du capot et du coffre (dessus)
    def topline(name, za, zb, xa, xb, w=0.09):
        ya, yb2 = top_y(za) + T, top_y(zb) + T
        if abs(xa - xb) < 1e-6:
            pts = [(xa - w / 2, ya, za), (xa + w / 2, ya, za), (xb + w / 2, yb2, zb), (xb - w / 2, yb2, zb)]
        else:
            pts = [(xa, ya - 0.0, za - w / 2), (xb, ya, za - w / 2), (xb, ya, za + w / 2), (xa, ya, za + w / 2)]
        b.face(name, 'Trim', pts)
    for sd in (1, -1):
        topline('Ink_Hood', BUMPER_F + 0.1, HOOD_REAR - 0.05, sd * 2.25, sd * 2.25)
        topline('Ink_Trunk', DECK_FRONT + 0.1, BUMPER_R - 0.1, sd * 2.25, sd * 2.25)
    topline('Ink_Hood', BUMPER_F + 0.1, BUMPER_F + 0.1, -2.25, 2.25)
    topline('Ink_Trunk', BUMPER_R - 0.1, BUMPER_R - 0.1, -2.25, 2.25)
    # Bas de caisse noir entre les roues, poignées
    for sd in (1, -1):
        x = sd * (2.78 + T)
        b.face('Rocker_' + ('R' if sd > 0 else 'L'), 'Trim', [(x, BOTTOM, -2.43), (x, BOTTOM, 2.43), (x, BOTTOM + 0.45, 2.43), (x, BOTTOM + 0.45, -2.43)])
        for zc in (-0.6, 1.9):
            yh = top_y(zc) - 0.32
            b.face('Handle_' + ('F' if zc < 0 else 'R') + ('R' if sd > 0 else 'L'), 'Trim', [(x, yh, zc - 0.28), (x, yh, zc + 0.28), (x, yh + 0.1, zc + 0.28), (x, yh + 0.1, zc - 0.28)])
    # Bandeau arrière noir entre les feux
    tz = TAIL_Z + 0.02
    b.face('TailGarnish', 'Trim', [(-1.0, -0.05, tz), (1.0, -0.05, tz), (1.0, 0.38, tz), (-1.0, 0.38, tz)])


def hood_scoop(b):
    """Variante de capot : écope centrale et ouïes (façon Evo)."""
    z0, z1 = -5.5, -3.0
    def y(z): return top_y(z) + 0.02
    w = 1.0
    b.face('HoodScoop', 'Body', [(-w, y(z0), z0), (w, y(z0), z0), (w - 0.05, y(z1) + 0.4, z1), (-w + 0.05, y(z1) + 0.4, z1)][::-1])
    b.face('HoodScoopMouth', 'Trim', [(-w + 0.08, y(z0) + 0.01, z0 - 0.01), (w - 0.08, y(z0) + 0.01, z0 - 0.01), (w - 0.1, y(z0) + 0.2, z0 + 0.1), (-w + 0.1, y(z0) + 0.2, z0 + 0.1)][::-1])
    for s in (1, -1):
        side = [(s * w, y(z0), z0), (s * (w - 0.05), y(z1) + 0.4, z1), (s * (w - 0.05), y(z1), z1)]
        b.face('HoodScoop', 'Body', side if s > 0 else side[::-1])
    b.face('HoodScoop', 'Body', [(-w + 0.05, y(z1) + 0.4, z1), (w - 0.05, y(z1) + 0.4, z1), (w - 0.05, y(z1), z1), (-w + 0.05, y(z1), z1)][::-1])
    for s in (1, -1):
        for k in range(4):
            zc = -4.9 + k * 0.42
            yv = top_y(zc) + 0.02
            b.face('HoodVents', 'Trim', [(s * 1.05, yv, zc), (s * 1.75, yv - 0.03, zc), (s * 1.75, yv - 0.03, zc + 0.2), (s * 1.05, yv, zc + 0.2)][:: (1 if s < 0 else -1)])


def rally_wing(b):
    """Variante d'aileron : très grand aileron sur hauts montants noirs."""
    yd = top_y(5.7)
    yw = yd + 1.15
    for sx in (1, -1):
        b.prism('Wing', 'Trim', [(sx * 1.35, yd), (sx * 1.6, yd), (sx * 1.6, yw), (sx * 1.35, yw)][:: (1 if sx > 0 else -1)], 5.3, 6.1)
    b.prism('WingBlade', 'Body', [(-3.0, yw), (3.0, yw), (3.0, yw + 0.2), (-3.0, yw + 0.2)][::-1], 4.85, 6.55)
    for sx in (1, -1):
        b.prism('Wing', 'Trim', [(sx * 3.0, yw - 0.45), (sx * 3.12, yw - 0.45), (sx * 3.12, yw + 0.5), (sx * 3.0, yw + 0.5)][:: (1 if sx > 0 else -1)], 4.75, 6.65)


def rally_lamps(b):
    """Variante de bouclier : rampe de quatre phares longue portée."""
    nz = NOSE_Z
    b.prism('LampPod', 'Trim', [(-2.0, -0.82), (2.0, -0.82), (2.0, -0.22), (-2.0, -0.22)][::-1], nz - 0.32, nz - 0.08)
    for k, x in enumerate((-1.5, -0.5, 0.5, 1.5)):
        b.disc('RallyLamp', 'Lamp', (x, -0.52, nz - 0.36), 0.42, 0.12, 'z', n=8)


def build(variant='full'):
    b = Builder()
    lower_body(b)
    cabin(b)
    details(b)
    ink(b)
    if variant in ('full', 'parts'):
        hood_scoop(b)
        rally_wing(b)
        rally_lamps(b)
    out = []
    for p in b.panels.values():
        out.append({'name': p['name'], 'paint': p['paint'], 'verts': p['verts'], 'faces': p['faces']})
    return out


if __name__ == '__main__':
    import json, sys
    panels = build(sys.argv[1] if len(sys.argv) > 1 else 'full')
    tris = sum(sum(len(f) - 2 for f in p['faces']) for p in panels)
    print(len(panels), 'panneaux,', tris, 'triangles')
    for p in panels:
        print(' ', p['name'], p['paint'], len(p['faces']))
