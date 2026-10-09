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
| `Vehicle/`     | Ce qui définit une voiture : `CarClasses` (fiches techniques Rally4, Rally2, Groupe B), `CarSetup` (réglages et bornes, par catégorie), `BodyKits` (carrosserie de chaque catégorie) et `Surfaces` (adhérence). |
| `Stage/`       | La spéciale : `StageTrack` (tracé, abscisse) et `Pacenotes` (notes du copilote).         |
| `Tracks/`      | Les circuits de rallycross.                                                              |
| `Paddock/`     | La disposition du paddock (zones, panneaux).                                             |
| `Progression/` | `Progression` (XP, niveaux, licences, déblocages) et `Medals` (seuils bronze → platine).  |
| `Challenges/`  | `Weekly` (défi de la semaine) et `Daily` (défis du jour).                                |
| `School/`      | `Lessons` : les leçons de l'école de pilotage.                                           |
| `Cosmetics/`   | `Livery` (livrée), `LiveryPainter` (peinture de la voiture, côté serveur et aperçu client) et `Celebrations` (effets de podium). |
| `Economy/`     | `Credits` (monnaie et barème des gains), `Rarity` (raretés), `Catalog` (tous les objets, leurs sources), `Items/` (les objets de chaque sorte), `Products` (achats en Robux), `Rolls` (règles et probabilités des tirages). |

## `src/server` : l'autorité

### `Data/` : ce qui est sauvegardé

| Module          | Rôle                                                                                                       |
|-----------------|------------------------------------------------------------------------------------------------------------|
| `Stores`        | Accès aux DataStores, avec repli en mémoire (Studio sans accès aux API).                                    |
| `ProfileSchema` | La forme du profil et sa remise en forme (`Sanitize`).                                                      |
| `ProfileStore`  | Chargement, copie en mémoire et écritures. `Update` écrit tout de suite (atomique), `AddCounter` et `Defer` écrivent par lots. |
| `Boards`        | Classements (OrderedDataStore et résultats de la session), noms des pilotes.                                |

Pour ajouter un champ au profil, on l'ajoute au type `Profile`, à `Empty` et à `Sanitize` de `ProfileSchema`, et nulle part ailleurs.

### `Services/` : un service par sujet

| Service            | Sujet                                                                                 |
|--------------------|---------------------------------------------------------------------------------------|
| `ProgressService`  | XP, niveau et déblocages, déduits du profil et envoyés au joueur.                     |
| `EconomyService`   | Crédits, objets possédés et portés, achats en crédits et en Robux (ProcessReceipt).   |
| `GarageService`    | Réglages et livrée.                                                                   |
| `RecordService`    | Record de la spéciale et son classement, records du tour, statistiques de carrière.   |
| `GhostService`     | Fantômes : le sien, et le défi du fantôme contre un autre pilote.                     |
| `StageService`     | Chrono officiel de la spéciale, mesuré par le serveur.                                |
| `ChallengeService` | Défis du jour et de la semaine.                                                       |
| `StyleService`     | Points de style (dérapages, sauts, dépassements), à débit plausible.                  |
| `SchoolService`    | Médailles de l'école de pilotage.                                                     |
| `HornService`      | Klaxon : relaie le coup de klaxon d'un pilote à tous les joueurs.                     |
| `RollService`      | Tirages : tire l'objet côté serveur, le donne ou le convertit en crédits.             |
| `CarService`       | Voitures des joueurs : apparition, volant, livrée, télémétrie.                        |
| `RaceService`      | Courses de rallycross : salle d'attente, départ, tours, résultats, revanche.          |
| `PaddockService`   | Le paddock : zones, panneaux, podium, choix du mode de jeu.                           |

**Dépendances :** un service appelle les autres par `require`, sans cycle. L'ordre est celui de `Main.server.luau`. Quand un service doit prévenir un service qui dépend déjà de lui, il expose un crochet (par exemple `GarageService.LiveryChanged`), et `Main.server.luau` le branche.

**Chargement d'un profil :** chaque service s'inscrit avec `ProfileStore.OnLoaded`. Les services sont appelés dans l'ordre de leur démarrage.

## `src/client` : physique et affichage

| Dossier    | Contenu                                                                                                       |
|------------|---------------------------------------------------------------------------------------------------------------|
| `Main.client.luau` | Point d'entrée. Il crée ce qui dure toute la partie et relie les modules entre eux.                   |
| `Core/`    | Commandes (`InputManager`, `TouchControls`), avatar à pied (`CharacterControls`), journal console (`DebugLog`). |
| `Physics/` | La voiture : roues, moteur, boîte, différentiels, aérodynamique.                                              |
| `Audio/`   | Son des voitures (`CarAudio`) et identifiants audio (`SoundBank`).                                            |
| `Camera/`  | Caméra de poursuite et caméra de spectateur.                                                                  |
| `Driving/` | Une session de conduite (`DrivingSession` : une voiture, de son apparition à sa disparition), tableau de bord, effets (poussière, fumée colorée `TireSmoke`, klaxon `Horn`), voitures des autres joueurs, points de style. |
| `Stage/`   | Ce qui sert sur la spéciale : chrono, copilote, fantômes, contrainte du défi.                                 |
| `School/`  | Déroulement d'une leçon.                                                                                      |
| `Replay/`  | Ralenti et mode photo.                                                                                        |
| `Race/`    | Rallycross : `RaceClient` (relie serveur, menu et affichage), HUD, minicarte, `RaceTypes`.                    |
| `UI/`      | `Theme` et `Widgets` (identité visuelle), bandeaux (`Banner`), notifications (`Toast`), classement, réglages, garage, et le menu principal (`UI/Menu`). |

Le menu principal (`UI/Menu/MainMenu`) n'est qu'un cadre, avec des onglets. Chaque rubrique est un module (`PlayPage`, `ChallengesPage`, `ShopPage`…) qui reçoit un `MenuKit.Context` et ajoute ses lignes.

## Économie

- **Ajouter un objet** (voiture, fumée, klaxon…) : une entrée dans le module de sa sorte (`shared/Economy/Items/`), avec sa rareté et ses sources (`Free`, `Credits`, `Robux`, `Pass`, `Roll`). La boutique, le garage, les tirages et le Rallye Pass le trouvent d'eux-mêmes.
- **Achats en Robux** : chaque produit se crée dans le Creator Dashboard. Son identifiant va dans `Products.luau` (packs de crédits) ou dans le champ `Robux.ProductId` de l'objet. Tant qu'il vaut 0, le produit s'affiche « bientôt ».
- Le serveur n'accorde un achat qu'une fois sauvegardé, et garde l'identifiant de l'achat pour ne jamais l'accorder deux fois.

## Catégories de voitures

Une catégorie est une fiche dans `shared/Vehicle/CarClasses.luau`. Elle définit le moteur, la boîte, la transmission, les pneus et le kit de carrosserie. Elle donne aussi un suffixe aux clés des records : la Rally2 garde les clés d'avant les catégories. La physique (`Car`, `Powertrain`, `Gearbox`) lit la fiche de la voiture conduite.

Records, fantômes, médailles et classements sont propres à chaque catégorie. La voiture achetable correspondante est un objet `Car` du catalogue (`Economy/Items/Cars.luau`).

## Conventions

- `--!strict` partout. Les types exportés sont nommés comme le module (`Car.Car`, `MainMenu.MainMenu`).
- Commentaires et textes en français. Chaque module commence par un bloc qui explique son rôle et ses choix.
- Les constantes réglables sont en tête de module, en MAJUSCULES, avec leur unité.
- Aucun identifiant d'asset en dur dans le code : ils sont rassemblés dans des catalogues (`SoundBank`, etc.).
- Tout ce qui vient du client est vérifié par le serveur : type, bornes, débit (cooldown).

## Vérifier avant de pousser

- `rojo build default.project.json -o test.rbxlx` : le projet se construit.
- `luau-lsp analyze` avec la sourcemap de Rojo (`rojo sourcemap`) : aucun avertissement nouveau.
- Les seuils (médailles, école, style, XP) se calibrent dans Studio : la sortie affiche `[Médailles]` et `[École]` à chaque essai.
