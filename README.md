# Sim Rallye

Jeu Roblox de rallye : une spéciale chronométrée (terre et asphalte, sauts, épingles) et des courses de rallycross jusqu'à six pilotes, avec une physique de voiture faite maison.

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

Le dossier `tools/` contient des scripts à lancer dans la barre de commande de Studio. Ils construisent la spéciale, les circuits, la piste d'essai et le gabarit de la voiture.
