# Carrosseries faites dans Blender

Le style dessin animé du jeu, en maillages : grands plans plats, arêtes
franches, proportions exagérées, noirs façon manga (bloc vitré, lèvres des
passages de roue, traits des jointures, bas de caisse).

| Modèle | Dossier | Look |
|---|---|---|
| Hayate | `hayate/` | berline façon Evo : nez plongeant, ailes en caissons à marche franche |
| Hoshi | `hoshi/` | berline façon Impreza : gros phares ronds, ailes en bosses à pans coupés, lunette inclinée |
| Kaze | `kaze/` | la voiture de départ : compacte « origami » aux arêtes tranchantes, phares en triangle, prises d'air en X |
| Yama | `yama/` | berline des années 70 : caisse carrée, montants fins couleur carrosserie, gros phares ronds, pare-chocs chromés |
| Raijin | `raijin/` | coupé en coin des années 80 : nez en lame, bandeau noir à phares fins, gros becquet, lunette à persiennes |
| Tora | `tora/` | citadine haute et très courte : gros yeux ronds, calandre souriante, feux verticaux |
| Kumo | `kumo/` | bombe à moteur central : avant étroit, hanches arrière énormes avec prises d'air noires |
| Ryu | `ryu/` | long coupé bas : capot très long, lunette fastback, queue de canard, quatre phares ronds |
| Tsubasa | `tsubasa/` | inspiration Yaris WRC : caisse étroite et haute, vitres basses, ailes en caissons énormes à ouïes, grand aileron multi-lames d'origine |
| Requin | `requin/` | inspiration DS3 WRC : carrosserie gonflée aux flancs rentrants, toit noir flottant, montant en aileron de requin, sourire noir et bandeaux de lumière verticaux |
| Lynx | `lynx/` | inspiration 206 WRC : compacte lisse et ronde, capot court qui file dans un pare-brise très incliné, grands phares en amande qui enveloppent les coins, bouche ovale en sourire, jonc noir, écopes de toit, aileron en arceau |
| Griffe | `griffe/` | inspiration 208 : large et basse, ligne de caisse haute, masque noir sur toute la face, trois griffes lumineuses par côté |
| Furia | `furia/` | inspiration Delta Integrale : haute comme une boîte, flancs droits, grande verrière quasi verticale, quatre phares carrés |
| Blitz | `blitz/` | inspiration Quattro S1 : coupé au très long capot, gros montant arrière couleur carrosserie, bouclier à lamelles, aileron géant |
| Fauve | `fauve/` | inspiration 205 T16 : courte et haute, grande ceinture noire tout autour du bas, prises d'air derrière les portes |
| Cuneo | `cuneo/` | inspiration Stratos : coin très bas, étroit devant et très large derrière, petites vitres, persiennes, phares escamotables, feux ronds |

Les modèles inspirés de voitures réelles n'en reprennent que l'esprit (silhouette,
signature lumineuse) : noms inventés, aucun logo ni marque.

`pieces_1.png` et `pieces_2.png` montrent chaque carrosserie du jeu de série puis
avec toutes les pièces débloquées (rendu fait avec le vrai code de `CarBodies`).
`comparatif.png` compare, pour les huit carrosseries du jeu, l'ancienne version
en pièces Roblox et la version Blender. `toutes.png` montre toutes les carrosseries (en haut, celles des 32 voitures du
jeu ; en bas, les modèles inspirés du garage). `legendes.png` montre les modèles inspirés, chacun légendé de son nom et de sa
voiture d'inspiration. Les modèles dont les originales sont rondes (Lynx,
Requin, Cuneo) ont des épaules, un toit et un nez arrondis et des flancs qui
rentrent ; les carrés (Furia, Blitz, Fauve, Hayate, Hoshi) gardent des arêtes
franches. Chaque modèle a ses proportions (hauteur de toit, inclinaison du
pare-brise, taille des vitres, largeur avant et arrière) et sa couleur
d'aperçu, pour qu'on les distingue d'un coup d'oeil.

Les modèles inspirés de voitures réelles n'en reprennent que l'esprit (silhouette,
signature lumineuse) : noms inventés, aucun logo ni marque.

Dans chaque dossier :

- `<Modèle>.glb` : à importer dans Studio (Importer 3D), puis `tools/import-car.luau` (régler `BODY`).
- `<Modèle>.fbx` : même modèle, autre format.
- `<Modèle>.blend` : la scène Blender, pour retoucher à la main.
- `apercu.png` : rendus (la dernière case : l'ancienne carrosserie en pièces).

Repère : celui du châssis du jeu (X à droite, Y en haut, l'avant en -Z, en
studs). Chaque objet est une pièce séparée (les bosses déplacent chaque pièce) ;
les objets `Opt_...` sont les options du garage, posées par le jeu selon le
choix du joueur :
- capot : écope (`Opt_Hood_Scoop_`) ;
- aileron (`Opt_Wing_Rally_`) ; pare-chocs : rampe de phares (`Opt_Bumper_Lamps_`) ;
- toit : écope (`Opt_Roof_Scoop_`), aileron de requin (`Opt_Roof_Fin_`) ou antenne (`Opt_Roof_Antenna_`) ;
- bas de caisse : jupes (`Opt_Skirts_Side_`) ou lames (`Opt_Skirts_Blade_`) ;
- diffuseur route (`Opt_Diffuser_Road_`) ou course (`Opt_Diffuser_Race_`) ;
- bavettes rallye (`Opt_Mudflaps_Rally_`) ou longues (`Opt_Mudflaps_Long_`).
Les autres accessoires (filet, sangles, ailettes...) restent en pièces Roblox,
posées sur le maillage. `accessoires_1.png` à `accessoires_4.png` : le rendu sur les 16 modèles.

## Régénérer

Les modèles sont construits par script (`source/`), avec Blender en module
Python (`pip install bpy numpy pillow`). `hayate_geo.py` porte la construction
commune (berlines et compactes à hayon) ; chaque autre modèle (`hoshi_geo.py`,
`tsubasa_geo.py`...) en change les mesures et les détails, avec les outils de
`lib_cars.py`. `shots.py` fait les rendus d'aperçu (`render_mesh.py`),
`labels.py` les planches légendées.

```bash
cd source
python build_blend.py . Hoshi                 # .blend, .glb, .fbx dans ./export
python export_luau.py ../../../src/shared/Vehicle/MeshBodies/Hoshi.luau Hoshi
```

Si tu retouches un modèle à la main dans Blender, garde les noms des objets :
l'outil d'import retrouve chaque pièce par son nom. Une pièce renommée ou
ajoutée doit aussi l'être dans `MeshBodies/<Modèle>.luau`.
