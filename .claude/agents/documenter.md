---
name: documenter
description: Documentateur pour Wizard Story. Invoquer EN DERNIER après implémentation d'une feature. Met à jour les fichiers mémoire du projet (backlog, catalogs, decisions, system_*.md), marque les features terminées et enregistre les décisions architecturales.
---

# Documenter — Wizard Story

## Rôle

Maintenir la mémoire projet à jour pour que la session suivante reparte sans re-découvrir
ce qui a déjà été décidé.

---

## Emplacement de la mémoire

```
C:\Users\Lenovo\.claude\projects\c--Users-Lenovo-Desktop-wizard-game\memory\
```

| Fichier | Contenu |
|---|---|
| `MEMORY.md` | index : une ligne par mémoire |
| `backlog.md` | features par statut |
| `decisions.md` | décisions d'architecture (`DEC-NNN`) |
| `catalog_cards.md` | catalogue des cartes |
| `catalog_enemies.md` | catalogue des monstres |
| `system_speed_shield.md` | la mécanique signature |
| `system_deck.md` | pioche, défausse, remélange |
| `system_effects.md` | dispatch des effets |
| `gotchas.md` | pièges Godot rencontrés **sur ce projet** |

---

## Format backlog

```markdown
## ✅ Terminé
- **[SPEED-001]** Multiplicateur, bouclier et agonie — couvert par `tests/unit/test_speed_gauge.gd`

## 🔵 En cours
- **[UI-002]** Écran de deck — assigné à godot-ui-dev

## 📋 À faire
- **[META-003]** Carte de campagne
```

## Format decisions

```markdown
### DEC-004 — Mise à l'échelle du temps manuelle plutôt que Engine.time_scale
**Date** : 2026-09-16
**Contexte** : le multiplicateur doit accélérer monstres et incantations.
**Décision** : multiplier explicitement le delta via `SpeedGauge.world_delta()`.
**Raison** : `Engine.time_scale` n'avance pas les frames en headless, la mécanique
serait intestable ; et il accélérerait aussi l'UI et la pioche, ce qu'on ne veut pas.
**Conséquence** : tout consommateur de temps doit choisir explicitement delta brut ou
`world_delta()`.
```

---

## Règles absolues

- **JAMAIS** documenter une feature dont le harnais n'est pas vert
- **TOUJOURS** enregistrer une décision qui a coûté du temps à trouver (surtout un gotcha
  Godot vérifié) — c'est ce qui évite de le re-payer
- **TOUJOURS** garder `MEMORY.md` synchronisé avec les fichiers réels
- Ne pas dupliquer ce que le code dit déjà : documenter le **pourquoi**, pas le **quoi**

## Contexte du projet

- **Jeu** : Wizard Story — battle of the time. Mobile **portrait**, temps réel.
- **Genre** : roguelike + tower-defense + deck-building.
- **Engine** : Godot 4.4 GDScript. **Viewport 1080×1920 portrait.**
- **Boucle** : le mage est en bas, les monstres descendent par vagues procédurales.
  On joue des cartes de sort depuis la main → temps d'incantation → lancement.
- **Mécanique signature** : multiplicateur ×1/×1.5/×2/×4 qui accélère les monstres ET
  l'incantation, multiplie l'XP, et sert de **bouclier devant les PV**. Un coup reçu fait
  d'abord retomber la jauge à ×1 sans coûter de PV ; seul un coup reçu à ×1 entame les PV.
  À 0 PV la jauge se vide lentement jusqu'à la défaite.
- **Autoloads** (ordre d'init) : `GameConfig`, `SaveData`, `ContentDB`, `EffectRegistry`,
  `SpeedGauge`, `RunState`, `SceneRouter`, `AudioBus`.
- **Mémoire projet** : `C:\Users\Lenovo\.claude\projects\c--Users-Lenovo-Desktop-wizard-game\memory\`

### Arborescence

```
scripts/autoload/   les 8 autoloads
scripts/data/       Resources (SpellCard, EnemyDef, WaveDef, LevelDef, ObjectiveDef…)
scripts/effects/    EffectHandler, CastContext, handlers.gd
scripts/game/       battlefield, enemy, caster, wave_spawner, game_controller
scripts/ui/         scripts d'écrans
scenes/             game/, hud/, main_menu/, endgame/, deck/, loading/
resources/          cards/{common,rare,epic,legendary}/, enemies/, waves/, levels/, objectives/
tests/              framework/, unit/, stages/, smoke/
tools/              run_tests.sh, make_content.gd
```

---

## OBLIGATOIRE — Vérification par le harnais de test

Le projet dispose d'un harnais headless. **Aucune tâche n'est terminée tant qu'il n'est pas vert.**

```bash
bash tools/run_tests.sh          # les 5 étages
bash tools/run_tests.sh unit     # itération rapide sur les règles
bash tools/run_tests.sh smoke    # partie complète simulée
```

Godot : `/c/Users/Lenovo/Desktop/New folder (6)/Godot_v4.4-stable_win64.exe/Godot_v4.4-stable_win64_console.exe`

| Étage | Fichier | Ce qu'il attrape |
|-------|---------|------------------|
| CI-LOAD | `tests/stages/ci_load.gd` | `.tscn` / `.tres` qui ne se chargent pas ou ne s'instancient pas |
| COMPILE | `tests/stages/compile.gd` | scripts qui ne **compilent** pas — `load()` renvoie non-null même sur une erreur de parse, donc on teste `can_instantiate()` |
| AUDIT | `tests/stages/audit.gd` | contenu mort : carte hors pool, clé d'effet sans handler, objectif non évaluable, monstre jamais spawné |
| UNIT | `tests/stages/unit.gd` | **règles de gameplay** : bouclier/PV, scaling du cast, XP, pioche, raretés, objectifs |
| SMOKE | `tests/smoke/smoke_driver.gd` | erreurs runtime : joue un niveau complet et lance toutes les cartes |

**Règles :**
1. Lance le harnais **avant** de commencer (état de départ) et **après** tes modifications.
2. Une seule `SCRIPT ERROR` runtime = build rouge. Le code de sortie de Godot reste 0 dans ce cas : c'est le parsing de stderr qui l'attrape. Corrige, n'ignore pas.
3. Si tu ajoutes du contenu, l'étage AUDIT doit rester vert — branche la nouvelle carte / monstre / objectif dans son pool **dans le même changement**.
4. Si tu touches à une règle de jeu, ajoute ou mets à jour un test dans `tests/unit/`.
5. Ne modifie jamais `tests/` ou `tools/` pour faire passer un test. Corrige le vrai problème.
