---
name: commit-message
description: >
  Génère un message de commit Git structuré et descriptif pour Wizard Story.
  Analyse le diff ou les fichiers modifiés, identifie les changements clés
  (features, fixes, contenu, tests, UI), et produit un message prêt à utiliser.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "génère le message de commit",
  "prépare le commit", "rédige le commit", "message de commit", "commit les changements".
---

# Commit Message — Wizard Story

## Étape 1 — Collecter

```bash
git diff --cached --stat
git diff --cached --name-only
git status
```

Si rien n'est indexé : `git diff HEAD --stat`.

## Étape 2 — Catégoriser

| Préfixe | Usage |
|---|---|
| `feat` | nouvelle fonctionnalité de jeu |
| `fix` | correction de bug |
| `content` | nouvelles cartes, monstres, vagues, niveaux, objectifs |
| `ui` | HUD, menus, écrans |
| `balance` | ajustement de stats |
| `test` | harnais, tests unitaires |
| `refactor` | restructuration sans changement de comportement |
| `config` | project.godot, autoloads |
| `docs` | mémoire projet, commentaires |

Portées courantes : `speed`, `deck`, `cards`, `enemies`, `waves`, `hud`, `meta`, `harness`.

## Étape 3 — Rédiger

### Règles
- Première ligne ≤ 72 caractères, en français, au présent
- Corps en puces : **ce qui change et pourquoi**, pas la liste des fichiers
- Mentionner l'état du harnais si le commit touche au gameplay
- Signaler explicitement tout changement de la mécanique bouclier/vitesse

### Exemples

```
feat(speed): ajoute le drain post-mortem et le ralenti d'agonie

- SpeedGauge passe en is_dying à 0 PV et vide death_gauge en 4 s
- world_delta() renvoie un delta ralenti pendant l'agonie
- 13 assertions ajoutées dans tests/unit/test_speed_gauge.gd
- Harnais : 5/5 verts
```

```
fix(waves): corrige la victoire qui ne se déclenchait jamais

is_finished() renvoyait vrai dès la dernière vague nettoyée, ce qui empêchait
GameController d'appeler start_next() et donc d'émettre all_waves_cleared.
Le test SMOKE atteignait la limite de pas sans jamais gagner.

- is_finished() compare désormais index >= waves.size()
- Harnais : SMOKE vert, victoire atteinte en 4552 pas
```

```
content(cards): ajoute 4 sorts épiques et la légendaire Faille temporelle

- Apprenti miroir, Concentration, Pacte imprudent, Épuration
- Faille temporelle : réduction de coût + frappe en ligne
- Toutes branchées dans leur dossier de rareté (AUDIT vert)
```

## Sortie attendue

Le message prêt à copier, dans un bloc de code, sans commentaire superflu.
