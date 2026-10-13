# Génère les coques inversées du trait d'encre (client/World/InkHulls.luau) :
# un cube, une sphère, un cylindre (axe X, comme ceux de Roblox) et un coin
# (WedgePart), de taille 1 x 1 x 1, faces RETOURNÉES (normales vers
# l'intérieur). Roblox n'affiche que les faces tournées vers la caméra : d'une
# coque retournée, on ne voit donc que le fond, qui dépasse autour de la
# pièce comme un trait.
# Usage : python3 assets/meshes/generate.py assets/meshes
import sys, math

OUT = sys.argv[1]


def write(name, verts, faces):
    """faces : listes d'indices dans le sens direct (normales vers
    l'extérieur) ; elles sont écrites à l'envers, normales vers l'intérieur."""
    # D'abord dans le sens direct (forme convexe : normale à l'opposé du centre).
    mid = [sum(v[i] for v in verts) / len(verts) for i in range(3)]
    oriented = []
    for f in faces:
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        u = [b[i] - a[i] for i in range(3)]
        w = [c[i] - a[i] for i in range(3)]
        n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
        center = [sum(verts[k][i] for k in f) / len(f) - mid[i] for i in range(3)]
        oriented.append(f if sum(n[i] * center[i] for i in range(3)) > 0 else list(reversed(f)))
    faces = oriented
    lines = [f"# Coque inversée : {name} (1 x 1 x 1)", f"o {name}"]
    for v in verts:
        lines.append("v %.6f %.6f %.6f" % v)
    normals = []
    for f in faces:
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        u = [b[i] - a[i] for i in range(3)]
        w = [c[i] - a[i] for i in range(3)]
        n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
        length = math.sqrt(sum(x * x for x in n)) or 1
        normals.append([-x / length for x in n])  # vers l'intérieur
    for n in normals:
        lines.append("vn %.6f %.6f %.6f" % tuple(n))
    for i, f in enumerate(faces):
        rev = list(reversed(f))
        lines.append("f " + " ".join(f"{k + 1}//{i + 1}" for k in rev))
    open(f"{OUT}/{name}.obj", "w").write("\n".join(lines) + "\n")


h = 0.5

# Cube
verts = [(x, y, z) for x in (-h, h) for y in (-h, h) for z in (-h, h)]
faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
write("InkBox", verts, faces)

# Coin (WedgePart) : dessous complet, face arrière (+Z) complète, pente qui
# monte de l'avant (-Z, en bas) vers l'arrière (+Z, en haut).
verts = [(-h, -h, -h), (h, -h, -h), (-h, -h, h), (h, -h, h), (-h, h, h), (h, h, h)]
faces = [[0, 1, 3, 2], [2, 3, 5, 4], [0, 4, 5, 1], [0, 2, 4], [1, 5, 3]]
write("InkWedge", verts, faces)

# Sphère (UV, 24 x 14)
seg, rings = 24, 14
verts = [(0, h, 0)]
for r in range(1, rings):
    phi = math.pi * r / rings
    for s in range(seg):
        th = 2 * math.pi * s / seg
        verts.append((h * math.sin(phi) * math.cos(th), h * math.cos(phi), h * math.sin(phi) * math.sin(th)))
verts.append((0, -h, 0))
bottom = len(verts) - 1
faces = []
ring = lambda r, s: 1 + (r - 1) * seg + (s % seg)
for s in range(seg):
    faces.append([0, ring(1, s + 1), ring(1, s)])
for r in range(1, rings - 1):
    for s in range(seg):
        faces.append([ring(r, s), ring(r, s + 1), ring(r + 1, s + 1), ring(r + 1, s)])
for s in range(seg):
    faces.append([bottom, ring(rings - 1, s), ring(rings - 1, s + 1)])
write("InkBall", verts, faces)

# Cylindre, axe X (comme Enum.PartType.Cylinder)
seg = 24
verts = []
for x in (-h, h):
    for s in range(seg):
        th = 2 * math.pi * s / seg
        verts.append((x, h * math.cos(th), h * math.sin(th)))
faces = [list(range(seg - 1, -1, -1)), list(range(seg, 2 * seg))]
for s in range(seg):
    faces.append([s, (s + 1) % seg, seg + (s + 1) % seg, seg + s])
write("InkCylinder", verts, faces)

print("ok")
