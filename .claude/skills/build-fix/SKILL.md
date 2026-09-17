---
name: build-fix
description: >
  Résolution rapide des erreurs de parse et de compilation Godot 4.4 pour Wizard Story.
  Corrections minimales uniquement — pas de refacto, pas de changements architecturaux.
  Remet le projet au vert le plus vite possible.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "le projet ne compile pas",
  "erreur de parse", "erreur Godot", "corrige les erreurs", "le projet crash au démarrage",
  "parse error", "identifier not declared", "expected", "corrige", "crrige".
  Ne pas confondre avec les erreurs runtime pendant le jeu (→ skill debug-helper).
---

# Build Fix — Wizard Story

## Étape 1 — Diagnostiquer

```bash
bash tools/run_tests.sh compile
```

L'étage COMPILE liste les scripts qui ne compilent pas. Lire aussi `.testout/compile.err`
pour le message exact.

Attention : `load()` renvoie un objet **non-null** même sur une erreur de parse. C'est
`can_instantiate() == false` qui révèle le problème — ne pas se fier à un test de nullité.

## Étape 2 — Catégoriser

| Message | Cause probable | Correction |
|---|---|---|
| `Identifier not found: SpeedGauge` | script chargé hors contexte autoload | vérifier qu'on ne tourne pas en `--script` ; les étages doivent être des scènes |
| `Could not find type "X"` | `class_name` pas encore enregistré | relancer `--import` (c'est ce que fait `run_tests.sh` en préambule) |
| `does not have the same element type` | `Array` passé à un `Array[T]` | typer le paramètre en `Array` non typé |
| `Cannot infer type` | `:=` sur un helper sans `-> Type` | annoter la fonction ou typer explicitement |
| `Identifier "x" shadows` | nom réservé | renommer (`gravity`, `priority`, `linear_damp`…) |
| `Circular dependency` | `preload` croisé | `const PATH: String` + `load(PATH)` au runtime |
| `Invalid call ... in base 'Nil'` | nœud absent | `get_node_or_null()` + garde |

## Étape 3 — Corriger

Correction **minimale**. Pas de refacto opportuniste pendant un build rouge :
on remet au vert, on refactore ensuite si nécessaire.

## Étape 4 — Vérifier

```bash
bash tools/run_tests.sh
```

Les 5 étages doivent être verts. Donner la sortie réelle, pas une affirmation.

## Gotchas de ce projet

- `SpeedGauge.tick()` n'a qu'un seul appelant légitime : `GameController.simulate()`
- Les tags de dégâts circulent en `Array` non typé
- Les connexions de signaux doivent être idempotentes (`is_connected` avant `connect`)
- Ne jamais modifier `tests/` ou `tools/` pour faire passer un test
