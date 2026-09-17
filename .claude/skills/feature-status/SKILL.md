---
name: feature-status
description: >
  Vérifie l'avancement réel d'une feature Wizard Story en comparant le statut déclaré dans
  backlog.md avec la réalité du code (fichiers présents, signaux branchés, contenu dans les pools,
  tests existants). Produit un dashboard par couche : spec / data / scripts / scènes / UI / tests / docs.

  TOUJOURS utiliser ce skill quand l'utilisateur dit : "où en est la feature X", "status de CARD-003",
  "qu'est-ce qui reste à faire", "avancement de la feature", "check la feature",
  "la feature est-elle terminée", "qu'est-ce qui est implémenté", "fais un point sur X".
---

# Feature Status — Wizard Story

## Étape 1 — Identifier la feature

Extraire le slug (`CARD-004`, `SPEED-002`, `UI-003`…) et lire son entrée dans
`memory/backlog.md`.

## Étape 2 — Vérifier couche par couche

### Data / Resources
- Les `.tres` existent-ils dans `resources/` ?
- Les nouveaux champs sont-ils dans le script de Resource correspondant ?
- Nouvelle clé SaveData présente dans `_defaults()` ?

### Scripts
- Les `.gd` annoncés existent-ils ?
- Un nouveau handler d'effet est-il enregistré dans `EffectRegistry.register_defaults()` ?

### Scènes
- Les `.tscn` existent-ils, et se chargent-ils (`bash tools/run_tests.sh ci_load`) ?

### Intégration
- Le contenu est-il **atteignable** ? `bash tools/run_tests.sh audit`
  Un avertissement « jamais utilisé / jamais placé » signale du contenu mort.

### Tests
- Existe-t-il un test dans `tests/unit/` couvrant la règle ?
- `bash tools/run_tests.sh unit` — combien d'assertions ?

### Documentation
- `backlog.md` à jour ? Décision notable enregistrée dans `decisions.md` ?

## Étape 3 — Dashboard

```
Feature : CARD-004 — Sort de résurrection
Statut déclaré : 🔵 En cours
Statut réel    : ⚠️ Partiellement implémenté

✅ Data        resources/cards/epic/resurrection.tres
✅ Scripts     handler `summon_ally` enregistré
✅ Scènes      —
❌ Tests       aucun test dans tests/unit/
⚠️ AUDIT       avertissement : carte dans aucun deck de niveau
❌ Docs        backlog toujours en "En cours"

Reste à faire :
1. Brancher la carte dans lvl_01.exploration_deck ou un pool de rareté
2. Ajouter un test de l'effet d'invocation
3. Mettre à jour le backlog
```

Toujours confronter le statut **déclaré** au statut **réel** : c'est tout l'intérêt du skill.
