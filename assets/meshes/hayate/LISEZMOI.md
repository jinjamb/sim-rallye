# Hayate (Blender)

La carrosserie Hayate faite dans Blender, en style dessin animé : grands plans
plats, ailes en caisson, noirs façon manga (lèvres de passages de roue, traits
des jointures, bloc vitré).

- `Hayate.glb` : à importer dans Studio (Importer 3D), puis `tools/import-car.luau`.
- `Hayate.fbx` : même modèle, autre format.
- `Hayate.blend` : la scène Blender, pour retoucher à la main.
- `apercu.png` : rendus (la dernière case : l'ancienne carrosserie en pièces).

Repère : celui du châssis du jeu (X à droite, Y en haut, l'avant en -Z, en
studs). Chaque objet est une pièce séparée (les bosses déplacent chaque pièce) ;
les objets `Opt_...` sont les options (écope, aileron, rampe de phares).

## Régénérer

Le modèle est construit par script (`source/`), avec Blender en module Python
(`pip install bpy`) :

```bash
cd source
python hayate_geo.py                       # compte les pièces
python build_blend.py .                    # .blend, .glb, .fbx dans ./export
python export_luau.py ../../../../src/shared/Vehicle/MeshBodies/Hayate.luau
```

Si tu retouches le modèle à la main dans Blender, garde les noms des objets :
l'outil d'import retrouve chaque pièce par son nom. Une pièce renommée ou
ajoutée doit aussi l'être dans `MeshBodies/Hayate.luau`.
