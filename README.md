# Sim Rallye

Jeu Roblox de rallye : des spéciales chronométrées (forêt, neige) et des courses de rallycross jusqu'à six pilotes, avec une physique de voiture faite maison, trois catégories de voitures, une progression (défis, école, trophées, Rallye Pass) et des écuries entre amis.

L'organisation du code est décrite dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Démarrer

Le projet se synchronise avec [Rojo](https://rojo.space) 7.7.

```bash
rojo build -o "simulation-rallye.rbxlx"   # construire la place
rojo serve                                 # synchroniser avec Studio
```

Ouvre `simulation-rallye.rbxlx` dans Roblox Studio, puis connecte le plugin Rojo.

Dans Studio, les sauvegardes demandent d'activer l'accès aux services d'API : *Paramètres du jeu > Sécurité > Activer l'accès Studio aux services d'API*. Sans cet accès, le jeu fonctionne quand même, mais les données restent en mémoire pour la session.

## Outils

Le dossier `tools/` contient des scripts à lancer dans la barre de commande de Studio, avec `rojo serve` actif. Ils construisent les spéciales (`build-stage.luau`), les circuits (`build-circuit.luau`), l'ambiance (`setup-ambiance.luau`), la piste d'essai et le gabarit de la voiture. Rojo les range dans `ServerStorage.Tools` : ils ne tournent jamais en jeu.
