---
name: debug-helper
description: >
  Guide de débogage structuré pour Wizard Story (Godot 4.4 GDScript).
  Identifie la cause racine d'une erreur runtime, d'un comportement inattendu en jeu,
  d'un signal non déclenché, d'un état UI bloqué ou d'un crash pendant la partie.
  Propose une correction minimale et valide.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "ça plante en jeu", "le signal ne se déclenche pas",
  "l'UI reste bloquée", "les dégâts ne s'appliquent pas", "l'ennemi ne meurt pas",
  "la vague ne démarre pas", "le multiplicateur ne fait rien", "la carte ne se lance pas",
  "crash pendant la partie", "ça ne marche pas", "debug".
  Ne pas confondre avec les erreurs de parse (→ skill build-fix).
---

# Debug Helper — Wizard Story

## Étape 1 — Reproduire dans le harnais

```bash
bash tools/run_tests.sh smoke
```

Le SMOKE joue un niveau complet. Si le bug s'y reproduit, on l'a en headless : beaucoup
plus rapide à itérer qu'en jouant.

**Important** : une `SCRIPT ERROR` runtime **ne change pas** le code de sortie de Godot.
Toujours lire `.testout/smoke.err`, pas seulement le résultat.

## Étape 2 — Patterns fréquents sur ce projet

### La mécanique de vitesse

| Symptôme | Cause probable |
|---|---|
| Le multiplicateur monte deux fois trop vite | `SpeedGauge.tick()` appelé par deux endroits |
| Les monstres n'accélèrent pas | l'appelant utilise `delta` au lieu de `SpeedGauge.world_delta(delta)` |
| L'incantation n'accélère pas | on n'est pas passé par `RunState.effective_cast_time()` |
| Un coup coûte des PV alors que la jauge était haute | le `return` après `shield_collapsed.emit()` a sauté — **régression grave**, couverte par `tests/unit/test_speed_gauge.gd` |
| La défaite n'arrive jamais à 0 PV | `tick()` n'est plus appelé pendant l'agonie |

### Cartes et deck

| Symptôme | Cause probable |
|---|---|
| Rien ne se passe en jouant une carte | le mage est déjà en incantation (`caster.is_busy()`) |
| `Aucun handler pour la clé d'effet` | clé absente de `EffectRegistry` → l'AUDIT l'aurait dit |
| Des cartes disparaissent du deck | vérifier l'invariant de conservation (`total_cards()`) |
| La pioche ne se remplit plus | `RunState.tick()` doit recevoir le delta **brut** |

### Monstres

| Symptôme | Cause probable |
|---|---|
| Les dégâts ne s'appliquent pas | `Array` typé passé à `take_damage` → erreur de type |
| Un monstre est invincible | `immune_tags` couvre le tag du sort, ou il est en phase d'invisibilité |
| La vague ne se termine jamais | `alive_count()` > 0 : un monstre est bloqué hors écran |
| La victoire n'arrive jamais | `is_finished()` doit être `index >= waves.size()`, pas `size() - 1` |

### Signaux

- `Signal ... is already connected` → brancher avec `if not sig.is_connected(cb)`
- Signal jamais reçu → vérifier que l'émetteur est bien celui qu'on écoute
  (`spawner` vs `battlefield` vs `SpeedGauge`)

## Étape 3 — Correction minimale

Corriger la cause racine, pas le symptôme. Si c'est une règle de jeu, **ajouter un test
unitaire qui échoue avant le correctif et passe après** — c'est ce qui empêche la
régression de revenir.

## Étape 4 — Valider

```bash
bash tools/run_tests.sh
```

## Format de sortie

```
Cause racine : [explication]
Fichier      : scripts/....gd:ligne
Correction   : [ce qui a changé]
Test ajouté  : tests/unit/....gd  (si règle de jeu)
Harnais      : [sortie réelle]
```
