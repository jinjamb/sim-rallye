# Architecture

Jeu Roblox de rallye (spéciale chronométrée) et de rallycross, écrit en Luau strict et synchronisé avec Rojo.

## Les trois arbres

| Dossier       | Dans Roblox                                 | Qui l'exécute                        |
|---------------|---------------------------------------------|--------------------------------------|
| `src/shared`  | `ReplicatedStorage.Shared`                  | Serveur et client (règles communes)  |
| `src/server`  | `ServerScriptService.Server`                | Serveur seul (autorité, sauvegardes) |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client` | Client seul (physique, affichage)    |

**Règle d'or :** le serveur décide de tout ce qui compte (temps officiels, classements, XP, monnaie, achats). Le client propose et affiche. La physique de la voiture tourne chez le client (il en est propriétaire), donc le serveur vérifie tout ce qu'il reçoit : bornes, débit, plausibilité.

## `src/shared` : les règles du jeu

Ces modules sont purs. Ils ne contiennent ni état ni RemoteEvent, et leurs données et calculs sont les mêmes des deux côtés.

| Dossier        | Contenu                                                                                  |
|----------------|------------------------------------------------------------------------------------------|
| `Network/`     | `Remotes` : la liste de tous les RemoteEvents (créés par le serveur, attendus par le client). |
| `Util/`        | `Format` (temps, milliers, compte à rebours) et `Units` (échelle stud/mètre, gravité).    |
| `Vehicle/`     | Ce qui définit une voiture : `CarClasses` (fiches techniques Rally4, Rally2, WRC, Groupe B, aérodynamique comprise), `CarSetup` (réglages et bornes, par catégorie), `BodyKits` (carrosserie de chaque catégorie), `CarBodies` (modèles Kaze, Hayate, Hoshi… et pièces à personnaliser, sans effet sur la conduite) et `Surfaces` (adhérence). |
| `Stage/`       | Les spéciales : `Stages` (la liste des spéciales et leurs tracés), `StageTrack` (construction d'un tracé, abscisse) et `Pacenotes` (notes du copilote). |
| `World/`       | `Scenery` : le décor (arbres, tribunes, public, collines), partagé par le paddock et les outils de construction des cartes. |
| `Tracks/`      | Les circuits de rallycross.                                                              |
| `Paddock/`     | La disposition du paddock (zones, panneaux).                                             |
| `Progression/` | `Progression` (XP, niveaux, licences, déblocages), `Medals` (seuils bronze → platine), `Achievements` (trophées et badges Roblox) et `XpEvents` (calendrier du double XP). |
| `Challenges/`  | `Weekly` (défi de la semaine) et `Daily` (défis du jour).                                |
| `School/`      | `Lessons` : les leçons de l'école de pilotage.                                           |
| `Cosmetics/`   | `Livery` (livrée), `LiveryPainter` (peinture de la voiture, côté serveur et aperçu client) et `Celebrations` (effets de podium). |
| `Economy/`     | `Credits` (monnaie et barème des gains), `Rarity` (raretés), `Catalog` (tous les objets, leurs sources), `Items/` (les objets de chaque sorte), `Products` (achats en Robux), `Rolls` (règles et probabilités des tirages), `Pass` (saisons et paliers du Rallye Pass). `Items/Parts` : les pièces de carrosserie. |
| `Weather/`     | `Weather` : la météo (sec, pluie, variable), ses averses et l'eau sur la route, calculées de la même façon par le serveur et chaque client. |
| `Championship/` | `Championships` : les rallyes du mode championnat (spéciales enchaînées, météo de chaque spéciale, rallye de la semaine). |
| `Teams/`       | `Teams` : les écuries (taille, nom et sigle valides, couleurs communes).                  |
| `Social/`      | `Referral` : le parrainage (montants, plafond) et les données portées par une invitation (parrain, code de session). |

## `src/server` : l'autorité

### `Data/` : ce qui est sauvegardé

| Module          | Rôle                                                                                                       |
|-----------------|------------------------------------------------------------------------------------------------------------|
| `Stores`        | Accès aux DataStores, avec repli en mémoire (Studio sans accès aux API).                                    |
| `ProfileSchema` | La forme du profil et sa remise en forme (`Sanitize`).                                                      |
| `ProfileStore`  | Chargement, copie en mémoire et écritures. `Update` écrit tout de suite (atomique), `AddCounter` et `Defer` écrivent par lots. |
| `Boards`        | Classements (OrderedDataStore et résultats de la session), noms des pilotes.                                |

Pour ajouter un champ au profil, on l'ajoute au type `Profile`, à `Empty` et à `Sanitize` de `ProfileSchema`, et nulle part ailleurs.

### `World/` : le décor construit par le serveur

| Module           | Rôle                                                                 |
|------------------|----------------------------------------------------------------------|
| `PaddockScenery` | Décor du paddock d'accueil, qui ferme la vue vers les pistes.        |

### `Services/` : un service par sujet

| Service            | Sujet                                                                                 |
|--------------------|---------------------------------------------------------------------------------------|
| `ProgressService`  | XP, niveau et déblocages, déduits du profil et envoyés au joueur.                     |
| `EconomyService`   | Crédits, objets possédés et portés, achats en crédits et en Robux (ProcessReceipt).   |
| `MonetizationService` | Achats en Robux au-delà des packs : paliers par prix, offres, pass, boost d'XP.   |
| `Perks`            | Avantages d'un joueur (pass, Premium, boost d'XP, pays) : lu par l'économie et la progression, sans dépendance vers les services. |
| `GarageService`    | Réglages et livrée.                                                                   |
| `RecordService`    | Record de la spéciale et son classement, records du tour, statistiques de carrière.   |
| `GhostService`     | Fantômes : le sien, et le défi du fantôme contre un autre pilote.                     |
| `StageService`     | Chrono officiel de la spéciale, mesuré par le serveur.                                |
| `ChallengeService` | Défis du jour et de la semaine.                                                       |
| `StyleService`     | Points de style (dérapages, sauts, dépassements), à débit plausible.                  |
| `SchoolService`    | Médailles de l'école de pilotage.                                                     |
| `HornService`      | Klaxon : relaie le coup de klaxon d'un pilote à tous les joueurs.                     |
| `RollService`      | Tirages : tire l'objet côté serveur, le donne ou le convertit en crédits.             |
| `PassService`      | Rallye Pass : XP de la saison, paliers, récompenses gratuites et premium.             |
| `TeamService`      | Écuries : fondation, invitations, couleurs communes, classement de la saison.         |
| `AchievementService` | Trophées : les décerne et donne leur badge Roblox (BadgeService).                 |
| `AnnounceService`  | Annonces à tout le serveur : records battus, platine, roi du drift, grands trophées. |
| `SessionService`   | Jouer entre amis : sessions privées (serveur réservé, code à 6 caractères), arrivée par invitation, retour aux serveurs publics. |
| `ReferralService`  | Parrainage : note le parrain d'un nouveau joueur, récompense les deux quand le filleul prend le volant (parrain absent : récompense mise de côté dans son profil, remise par `MessagingService` ou à sa venue). |
| `TutorialService`  | Tutoriel express : proposé aux nouveaux pilotes, bouclé par la première spéciale terminée (récompense de bienvenue). |
| `ChampionshipService` | Mode championnat : enchaîne les spéciales d'un rallye, temps cumulé et pénalités, classements, récompenses. Prévenu par `StageService` via des crochets. |
| `CarService`       | Voitures des joueurs : apparition, volant, livrée, télémétrie.                        |
| `RaceService`      | Courses de rallycross : salle d'attente, départ, tours, résultats, revanche.          |
| `PaddockService`   | Le paddock : zones, panneaux, podium, choix du mode de jeu.                           |

**Dépendances :** un service appelle les autres par `require`, sans cycle. L'ordre est celui de `Main.server.luau`. Quand un service doit prévenir un service qui dépend déjà de lui, il expose un crochet (par exemple `GarageService.LiveryChanged`), et `Main.server.luau` le branche.

**Chargement d'un profil :** chaque service s'inscrit avec `ProfileStore.OnLoaded`. Les services sont appelés dans l'ordre de leur démarrage.

## `src/client` : physique et affichage

| Dossier    | Contenu                                                                                                       |
|------------|---------------------------------------------------------------------------------------------------------------|
| `Main.client.luau` | Point d'entrée. Il crée ce qui dure toute la partie et relie les modules entre eux.                   |
| `Core/`    | Commandes (`InputManager`, `TouchControls`), avatar à pied (`CharacterControls`), journal console (`DebugLog`), invitation d'amis (`FriendInvite`). |
| `Physics/` | La voiture : roues, moteur, boîte, différentiels, aérodynamique.                                              |
| `Audio/`   | Son des voitures (`CarAudio`), identifiants audio (`SoundBank`) et voix du copilote (`CopilotVoice` : mots enregistrés, sinon synthèse vocale). |
| `Camera/`  | Caméra de poursuite et caméra de spectateur.                                                                  |
| `Driving/` | Une session de conduite (`DrivingSession` : une voiture, de son apparition à sa disparition), tableau de bord, effets (poussière, fumée colorée `TireSmoke`, klaxon `Horn`), voitures des autres joueurs, points de style. |
| `Stage/`   | Ce qui sert sur la spéciale : chrono, copilote, fantômes, contrainte du défi (`StageModifier` : nuit, pluie, brouillard…). |
| `School/`  | Déroulement d'une leçon.                                                                                      |
| `Tutorial/` | `Tutorial` : le tutoriel express (un nouveau pilote au volant dès son arrivée, guidé en quatre étapes selon son appareil). |
| `Weather/` | `WeatherClient` : la météo chez le pilote (adhérence mouillée, pluie, ciel, routes assombries).                |
| `Replay/`  | Ralenti et mode photo.                                                                                        |
| `Race/`    | Rallycross : `RaceClient` (relie serveur, menu et affichage), HUD, minicarte, `RaceTypes`.                    |
| `UI/`      | `Theme` et `Widgets` (identité visuelle), bandeaux (`Banner`), notifications (`Toast`), bandeau du serveur (`Announcer` : annonces et double XP), vignettes des objets (`ItemArt`), aide des commandes (`ControlsHint`), classement, réglages, garage, et le menu principal (`UI/Menu`, avec la barre de boutons `HubBar` et l'onglet `InventoryPage`). |

Le menu principal (`UI/Menu/MainMenu`) n'est qu'un cadre, avec des onglets. Chaque rubrique est un module (`PlayPage`, `ChampionshipPage`, `SessionPage`, `ChallengesPage`, `PassPage`, `TeamPage`, `ShopPage`…) qui reçoit un `MenuKit.Context` et ajoute ses lignes.

## Économie

- **Ajouter un objet** (voiture, fumée, klaxon…) : une entrée dans le module de sa sorte (`shared/Economy/Items/`), avec sa rareté et ses sources (`Free`, `Credits`, `Robux`, `Pass`, `Roll`). La boutique, le garage, les tirages et le Rallye Pass le trouvent d'eux-mêmes.
- **Achats en Robux** : chaque produit se crée dans le Creator Dashboard. Son identifiant va dans `Products.luau` (packs de crédits) ou dans le champ `Robux.ProductId` de l'objet. Tant qu'il vaut 0, le produit s'affiche « bientôt ».
- Le serveur n'accorde un achat qu'une fois sauvegardé, et garde l'identifiant de l'achat pour ne jamais l'accorder deux fois.

## Trophées et badges

Un trophée est une entrée de `shared/Progression/Achievements.luau`. Il est déduit du profil (`Check`), ou décerné par un service (`AchievementService.Award`). Pour en faire un badge Roblox, on crée le badge dans le Creator Dashboard et on met son identifiant dans `BadgeId`. Les pilotes qui ont déjà le trophée reçoivent le badge à leur prochaine connexion.

## Catégories de voitures

Une catégorie est une fiche dans `shared/Vehicle/CarClasses.luau`. Elle définit le moteur, la boîte, la transmission, les pneus, l'aérodynamique (traînée, répartition de l'appui, appui de série) et le kit de carrosserie. Elle donne aussi un suffixe aux clés des records : la Rally2 garde les clés d'avant les catégories. La physique (`Car`, `Powertrain`, `Gearbox`) lit la fiche de la voiture conduite.

Records, fantômes, médailles et classements sont propres à chaque catégorie. Chaque catégorie compte huit voitures (`shared/Vehicle/CarModels.luau`) : trois gratuites, ouvertes au niveau de la catégorie (Rally4 tout de suite, Rally2 au niveau 5, WRC au 12, Groupe B au 20), et cinq à acheter en crédits ou en Robux. Une voiture retouche la fiche de sa catégorie (`CarClasses.ForCar` : puissance, couple, rapports, transmission avec la propulsion pour certaines Groupe B, turbo, pneus, aéro, son) et a sa carrosserie (`Design`, posée quand la livrée garde `Body = 0`). Records et médailles restent ceux de la catégorie. Le catalogue (`Economy/Items/Cars.luau`) est construit à partir de ces fiches ; la voiture qui roule est posée sur le modèle (attribut `CarModel`) par `CarService`, qui prête la voiture de référence à qui n'a pas de voiture de la catégorie imposée (course, défi). Les profils d'avant gardent leur Rally2 (`GarageVersion`).

## Spéciales et cartes

Une spéciale est une entrée de `shared/Stage/Stages.luau` : son tracé (segments), son thème de décor (`Forest`, `Snow`, `Mountain`, `Garrigue`, `Countryside` : réglages dans `THEMES` de `tools/build-stage.luau`), son emplacement et ses vitesses de médailles. Sa nature (asphalte, neige, terre, mixte) se déduit de ses surfaces. Chaque spéciale a sa propre médaille dans la progression (`Stages.MedalKey`). Le chrono, le copilote, les records et les fantômes la lisent d'eux-mêmes.

Le terrain et le décor se construisent dans Studio avec les outils de `tools/` (rangés par Rojo dans `ServerStorage.Tools`, jamais exécutés en jeu), à coller dans la barre de commandes avec `rojo serve` actif :

- `build-stage.luau` : le terrain et le décor des spéciales (`STAGE = nil` pour toutes, ou l'identifiant d'une seule) ;
- `build-circuit.luau` : les circuits de rallycross ;
- `setup-ambiance.luau` : le ciel et l'éclairage ;
- `build-rig.luau`, `attach-body.luau`, `build-test-track.luau` : le gabarit de la voiture et la piste d'essai.

Modifier le tracé d'une spéciale change sa longueur, donc la clé de ses records : ses temps repartent de zéro.

## Météo

Une prévision (`Weather.luau`) tient en trois valeurs : le mode (sec, pluie, variable), une graine et l'heure du serveur de son début. Le serveur la tire au lancement d'une spéciale (mode choisi au menu) ou au départ d'une course (mode réglé par l'hôte) et la pose sur la voiture (attributs `Weather`, `WeatherSeed`, `WeatherStart`). Chaque client en déduit les mêmes averses au même moment, et l'eau sur la route qui monte sous la pluie puis sèche (`WET_TIME`, `DRY_TIME`). L'adhérence suit l'eau (`Surfaces.EffectiveGrip`) : l'asphalte perd le plus, la neige presque rien.

## Arrivée d'un nouveau joueur

Le profil vierge déclenche le tutoriel express (`TutorialService`) : le client lance aussitôt la spéciale par défaut, au sec, sans passer par le menu, et `Tutorial.luau` guide le pilote (accélérer, tourner, frein à main, suivre le copilote jusqu'à l'arrivée). La première spéciale terminée boucle le tutoriel et rapporte des crédits et un tirage ; le menu s'ouvre ensuite. Un joueur arrivé par l'invitation d'un ami est noté comme filleul (`ReferralService`) : quand il termine sa première spéciale ou sa première course, lui et son parrain sont récompensés.

## Peinture et motifs

La livrée (`Livery.luau`) porte, en plus de la couleur principale, une couleur par zone de carrosserie (`Paints` : capot, toit, portières, boucliers…, zones définies dans `CarBodies.ZONES` et posées sur chaque pièce par l'attribut `PaintZone`) et un motif (`Pattern`, `PatternColor`). `LiveryPainter` repeint chaque zone, puis pose le motif (une `Texture` répétée par face visible) sur les pièces restées dans la couleur principale. Les images des motifs sont dans `assets/patterns/` (générées par `generate.py`) : chacune s'importe sur Roblox, et son identifiant va dans `Livery.PATTERNS` (`Image`). Tant qu'il vaut 0, le motif se choisit mais ne s'affiche pas.

Sponsors : un autocollant de marque imaginaire par emplacement (capot, portières, toit : `Livery.SPONSORS`, `SPONSOR_SLOTS`), dessiné en texte par `LiveryPainter` (aucune image à importer) ; « Écurie » affiche le sigle de son écurie. Déblocages par niveau, victoire, médaille ou tirage (`Progression.ITEMS`, sorte « Sponsor »).

## Réglages et médailles par voiture

- Appui aéro : chaque catégorie a sa plage (`CarClasses.DownforceRange`), appliquée par `CarSetup` (menu, sauvegarde) ; les préréglages en donnent une part (`Relative`).
- Médailles : les vitesses des tracés sont celles de la Rally2 ; `CarClasses.MedalScale` les adapte par surface (asphalte, terre, neige, mixte) et pour les circuits. Dans Studio, `_G.MedalReport()` (`MedalCalibration`) donne, d'après les passages de la session, les vitesses suggérées de chaque tracé et les `MedalScale` mesurés.

## Événements éclair

`Shared/Events/FlashEvents.luau` : au début de chaque quart d'heure, un événement de 5 minutes, le même sur tous les serveurs (déduit de l'heure), annoncé une minute avant : tirages boostés (raretés Usine et plus ×3), tirage offert (première spéciale ou course terminée), pluie de crédits (×2), XP éclair (×2, sans cumul avec le double XP du week-end), voiture rare (WRC ou Groupe B prêtée sur les spéciales, -30 % en crédits). Les effets sont lus là où ils s'appliquent (`RollService`, `Perks`, `ProgressService`, `EconomyService`, `PaddockService`, `FlashEventService`) ; l'affichage est dans `UI/EventNotice.luau` et le menu JOUER.

## Sons moteur

Chaque moteur est un enregistrement du Creator Store (`Audio/SoundBank.luau`, `RECORDINGS`) : des boucles à régime stabilisé, à charge et pied levé, que `CarAudio` fond l'une dans l'autre selon le régime. Les types de moteur (3, 4 et 5 cylindres turbo, 4 cylindres anti-lag, boxer, V6, 6 à plat, rotatif) ont chacun leur série à remplir (`STORE`) ; une série vide est remplacée par le V8. Une tonalité (`TONES`) choisit l'enregistrement et le traite (égaliseur, distorsion) : une par catégorie de voiture, une par son moteur à débloquer (`Items/Engines.luau`).

Anti-lag et retours de flamme : `Driving/Exhaust.luau`, piloté par le même état que le son (régime, charge) pour toutes les voitures. Un lever de pied franc à haut régime fait un retour de flamme ; pied levé, l'anti-lag (`CarClasses.AntiLag`) fait crépiter l'échappement et garde la pression du turbo (`Powertrain`).

## Retours de flamme, feux et aspiration

- **Retours de flamme** (`Driving/Exhaust.luau`) : une explosion (gerbe, boule de feu, étincelles, fumée, éclair) au lever de pied franc à haut régime, aux passages de rapport et au rupteur ; crépitements pied levé avec l'anti-lag. Couleurs, taille et détonation viennent de l'objet porté (`Items/Backfires.luau`, sorte « Backfire », attribut `EquippedBackfire`), à débloquer comme les fumées.
- **Feux** (`Driving/CarLights.luau`) : allumés sur toute voiture qui roule, halos lumineux qui percent la poussière et la neige ; feux stop au freinage (`Brake`, ajouté à la télémétrie) ; phares à la couleur de l'objet porté (`Items/Headlights.luau`, sorte « Headlight », attribut `EquippedHeadlight`) : halos, optiques, et faisceaux de nuit.
- **Aspiration** (`Driving/Slipstream.luau`) : dans le sillage d'une autre voiture (cône derrière elle), la traînée baisse jusqu'à 70 % (`Aerodynamics.DragScale`). Chaque voiture lancée laisse une traînée d'air (`RemoteCars`), cyan quand on l'aspire, et « ASPIRATION » s'affiche avec une jauge.

## Conventions

- `--!strict` partout. Les types exportés sont nommés comme le module (`Car.Car`, `MainMenu.MainMenu`).
- Commentaires et textes en français. Chaque module commence par un bloc qui explique son rôle et ses choix.
- Jamais de tiret cadratin (le tiret long, U+2014), ni dans les textes du jeu, ni dans le code, ni dans la documentation : un séparateur « · », deux-points, ou une virgule à la place.
- Les constantes réglables sont en tête de module, en MAJUSCULES, avec leur unité.
- Aucun identifiant d'asset en dur dans le code : ils sont rassemblés dans des catalogues (`SoundBank`, etc.).
- Tout ce qui vient du client est vérifié par le serveur : type, bornes, débit (cooldown).

## Vérifier avant de pousser

- `rojo build default.project.json -o test.rbxlx` : le projet se construit.
- `luau-lsp analyze` avec la sourcemap de Rojo (`rojo sourcemap`) : aucun avertissement nouveau.
- Les seuils (médailles, école, style, XP) se calibrent dans Studio : la sortie affiche `[Médailles]` et `[École]` à chaque essai.
