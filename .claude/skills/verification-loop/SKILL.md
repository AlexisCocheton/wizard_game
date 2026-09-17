---
name: verification-loop
description: >
  Checklist qualité à exécuter avant tout commit ou milestone sur Wizard Story.
  Vérifie dans l'ordre : harnais headless complet, gotchas projet, couverture de tests,
  puis contrôle visuel optionnel. Chaque phase doit être verte avant la suivante.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "valide avant commit", "lance la verification loop",
  "vérifie avant merge", "est-ce que c'est prêt", "check qualité", "tout est bon ?",
  "validation avant push". Utiliser aussi proactivement après une feature complète.
---

# Verification Loop — Wizard Story

## Phase 1 — Harnais complet (bloquante)

```bash
bash tools/run_tests.sh          # les 5 étages
bash tools/run_tests.sh unit     # règles de gameplay seules (le plus rapide)
bash tools/run_tests.sh smoke    # partie complète simulée
```

Les 5 étages doivent être verts. **C'est la phase qui remplace le test manuel** :
elle couvre le chargement, la compilation, le contenu mort, les règles de jeu et les
erreurs runtime sur une partie complète.

Si rouge → skill `build-fix` (parse/compile) ou `debug-helper` (runtime).

Rappel : le code de sortie de Godot reste 0 même sur une `SCRIPT ERROR` runtime.
C'est le parsing de stderr par `run_tests.sh` qui l'attrape — ne jamais contourner
cette vérification.

## Phase 2 — Gotchas projet

```bash
grep -rn "Engine.time_scale" scripts/           # doit être vide (hors habillage visuel)
grep -rn "SpeedGauge.tick" scripts/             # UN seul appelant : game_controller
grep -rn "\.connect(" scripts/ | grep -v is_connected   # vérifier l'idempotence
grep -rn "get_class()" scripts/                 # doit être vide
```

- [ ] Tout ce qui subit la vitesse passe par `SpeedGauge.world_delta()`
- [ ] Les `Tween` sont typés `var tw: Tween = ...`
- [ ] `position` est assignée avant `add_child`
- [ ] Aucun `print()` de débogage oublié

## Phase 3 — Couverture de tests

- [ ] Toute règle de jeu modifiée a un test dans `tests/unit/`
- [ ] Tout nouveau contenu est branché dans un pool (AUDIT vert)
- [ ] Le nombre d'assertions n'a pas diminué (`.testout/unit.out`)

Vérification utile : casser volontairement la règle qu'on vient d'écrire et confirmer
que le harnais rougit. Un test qui ne peut pas échouer ne protège rien.

## Phase 4 — Contrôle visuel (optionnel)

À faire seulement si la feature touche à l'affichage ou au ressenti.

```bash
"/c/Users/Lenovo/Desktop/New folder (6)/Godot_v4.4-stable_win64.exe/Godot_v4.4-stable_win64_console.exe" --path .
```

- [ ] Les monstres descendent et atteignent le mage
- [ ] Toucher une carte déclenche l'incantation puis le sort
- [ ] Le bouton de vitesse accélère monstres **et** incantations
- [ ] Un ennemi qui touche le mage fait retomber la jauge sans coûter de PV
- [ ] La lisibilité tient en portrait

## Rapport de sortie

```
Phase 1 — Harnais       : ✅ / ❌  [sortie réelle des 5 étages]
Phase 2 — Gotchas       : ✅ / ❌
Phase 3 — Tests         : ✅ / ❌  [N assertions]
Phase 4 — Visuel        : ✅ / ⏭️ non applicable

Verdict : prêt / à corriger
```
