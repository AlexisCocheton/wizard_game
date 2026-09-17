---
name: godot-code-reviewer
description: >
  Revue de code niveau senior pour Wizard Story (GDScript / Godot 4.4).
  Analyse le diff ou les fichiers modifiés selon : qualité GDScript, patterns Godot,
  gotchas du projet, performance, intégration avec les autoloads, et couverture de tests.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "revue de code", "review",
  "audite mes changes", "code review", "analyse mes modifications", "fais une revue",
  "regarde mon code", "check mon diff".
---

# Godot Code Reviewer — Wizard Story

## Étape 1 — Collecter

```bash
git diff HEAD --stat 2>/dev/null || echo "pas de dépôt git — revoir les fichiers indiqués"
bash tools/run_tests.sh
```

Une revue commence par l'état du harnais : inutile de commenter le style si le build est rouge.

## Étape 2 — Analyser

### A — Gotchas du projet (priorité)

- [ ] `Engine.time_scale` utilisé pour le gameplay → **interdit**, doit être `world_delta()`
- [ ] `SpeedGauge.tick()` appelé ailleurs que dans `GameController.simulate()` → double comptage
- [ ] `Array[T]` en paramètre recevant un `Array` → erreur de type au runtime
- [ ] `connect()` sans garde `is_connected` dans du code rejouable
- [ ] Étage de test lancé via `--script` → les autoloads n'existent pas
- [ ] `position` assignée après `add_child`
- [ ] `get_class()` surchargé
- [ ] `preload` circulaire
- [ ] `Tween` non typé

### B — La mécanique signature

Si le diff touche `speed_gauge.gd`, `battlefield.gd` ou `game_controller.gd` :

- [ ] L'ordre **bouclier puis PV** est-il préservé ? (le `return` après l'effondrement)
- [ ] Le drain post-mortem aboutit-il toujours à `died` ?
- [ ] Les tests de `tests/unit/test_speed_gauge.gd` couvrent-ils le changement ?

C'est la partie du code où une régression passe le plus facilement inaperçue.

### C — Qualité GDScript

- [ ] Types explicites sur les signatures publiques
- [ ] Pas de `print()` oublié
- [ ] Gardes `is_instance_valid()` sur les nœuds stockés
- [ ] Itération sur une liste modifiée pendant la boucle → `.duplicate()`

### D — Performance

- [ ] Pas d'allocation par frame dans `_process` / `simulate`
- [ ] Pas de `load()` répété dans une boucle chaude

### E — Couverture

- [ ] Une règle de jeu modifiée sans test → **demander le test**
- [ ] Du contenu ajouté sans pool → AUDIT rouge

## Étape 3 — Rapport

```
## Revue — [périmètre]

Harnais : ✅ / ❌ [sortie]

### 🔴 Critique
- [fichier:ligne] [problème] → [correction]

### 🟠 Important
### 🟡 Mineur

Verdict : ✅ OK | ⚠️ changements recommandés | 🚫 changements requis
```

Être précis et factuel. Pointer un fichier et une ligne, proposer la correction.
