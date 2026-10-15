# Carrosseries faites dans Blender

Le style dessin animé du jeu, en maillages : grands plans plats, arêtes
franches, proportions exagérées, noirs façon manga (bloc vitré, lèvres des
passages de roue, traits des jointures, bas de caisse).

| Modèle | Dossier | Look |
|---|---|---|
| Hayate | `hayate/` | berline façon Evo : nez plongeant, ailes en caissons à marche franche |
| Hoshi | `hoshi/` | berline façon Impreza : gros phares ronds, ailes en bosses à pans coupés, lunette inclinée |
| Tsubasa | `tsubasa/` | compacte de WRC moderne (inspiration Yaris WRC) : ailes à ouïes, grand aileron multi-lames d'origine |
| Requin | `requin/` | compacte (inspiration DS3 WRC) : toit noir flottant, montant en aileron de requin, bandeaux de lumière verticaux |
| Lynx | `lynx/` | petite compacte (inspiration 206 WRC) : phares en amande, grande bouche, formes plus douces |
| Griffe | `griffe/` | compacte moderne (inspiration 208) : feux de jour en trois griffes, bandeau noir arrière griffé de rouge |
| Furia | `furia/` | cinq portes carrée (inspiration Delta Integrale) : quatre phares carrés, ailes boulonnées, becquet de toit |
| Blitz | `blitz/` | coupé Groupe B (inspiration Quattro S1) : long nez, phares carrés doublés, aileron géant d'origine |

Les modèles inspirés de voitures réelles n'en reprennent que l'esprit (silhouette,
signature lumineuse) : noms inventés, aucun logo ni marque.

Dans chaque dossier :

- `<Modèle>.glb` : à importer dans Studio (Importer 3D), puis `tools/import-car.luau` (régler `BODY`).
- `<Modèle>.fbx` : même modèle, autre format.
- `<Modèle>.blend` : la scène Blender, pour retoucher à la main.
- `apercu.png` : rendus (la dernière case : l'ancienne carrosserie en pièces).

Repère : celui du châssis du jeu (X à droite, Y en haut, l'avant en -Z, en
studs). Chaque objet est une pièce séparée (les bosses déplacent chaque pièce) ;
les objets `Opt_...` sont les options (écope, aileron, rampe de phares).

## Régénérer

Les modèles sont construits par script (`source/`), avec Blender en module
Python (`pip install bpy numpy pillow`). `hayate_geo.py` porte la construction
commune (berlines et compactes à hayon) ; chaque autre modèle (`hoshi_geo.py`,
`tsubasa_geo.py`...) en change les mesures et les détails, avec les outils de
`lib_cars.py`. `shots.py` fait les rendus d'aperçu (`render_mesh.py`).

```bash
cd source
python build_blend.py . Hoshi                 # .blend, .glb, .fbx dans ./export
python export_luau.py ../../../src/shared/Vehicle/MeshBodies/Hoshi.luau Hoshi
```

Si tu retouches un modèle à la main dans Blender, garde les noms des objets :
l'outil d'import retrouve chaque pièce par son nom. Une pièce renommée ou
ajoutée doit aussi l'être dans `MeshBodies/<Modèle>.luau`.
