---
name: content-designer
description: Concepteur de contenu pour Wizard Story. Invoquer pour créer de nouvelles cartes de sort, types de monstres, vagues, objectifs ou niveaux. Conçoit les stats, les effets et les .tres. S'assure que le contenu s'intègre aux pools existants (ContentDB, EffectRegistry, ObjectiveChecker).
---

# Content Designer — Wizard Story

## Rôle

Créer du contenu **jouable et atteignable**. Un contenu qui n'est dans aucun pool est
du contenu mort : l'étage AUDIT le refuse.

---

## Catalogue actuel

### Cartes (24) — 4 raretés, 15 clés d'effet
Communes : Trait arcanique, Flèche perçante, Champ de givre, Braises, Boule de feu, Étincelle,
Pluie de givre. Rares : Précipitation, Entrave temporelle, Cycle de pensée, Mur de pierre,
Brasier, Météore, Volte-face, Focalisation. Épiques : Apprenti miroir, Concentration, Pacte
imprudent, Épuration, Gel profond, Marque de faiblesse, Résonance. Légendaires : Faille
temporelle, Sablier fendu.

Clés : `damage_single`, `pierce_line`, `ground_zone` (`slow_pct`, `vuln_mult`),
`damage_per_enemy`, `slow_enemy_gauge`, `reverse_enemies`, `empower_next`, `self_haste`,
`cost_reduction`, `summon_ally`, `discard_draw`, `haste_enemies_boon`, `remove_cards`,
`build_wall`, `discard_hand_for_speed`. **Composer ces clés couvre presque toutes les idées.**

### Monstres (21) — hiérarchie de puissance P1..P4, boss hors budget

| P | Familles |
|---|---|
| 1 | gnome, sprite (rapide), gelées moyenne/petite (enfants de division) |
| 2 | rat_swarm (×4), wisp (esquive), shade (disparaît), imp_archer (**tire**), sand_serpent (**ondule**), hopper (**à-coups**) |
| 3 | hornblower (buff, côté), golem (tank), berserker (**s'enrage**), void_knight (**absorbe le 1er coup**), jelly (**se divise**), ghoul_priest (**soigne**), hive (**explose en lutins**) |
| 4 | totem_guardian (**aura d'invulnérabilité**), glutton (**gobe et grossit**), behemoth (gros tank) |
| boss | warden (P6, mini-boss), chronos (P10) |

Chaque famille a **sa forme et sa couleur** (`shape`, `color`, `base_radius` dans
`EnemyDef`), dessinées par `EnemyBody` tant qu'il n'y a pas de sprite. Les comportements
sont des **champs** d'`EnemyDef`, pas des scripts : `devours`, `enrage_speed_pct`,
`aura_shield_radius`, `burst_move`, `wave_amplitude`, `split_into` + `split_count`,
`first_hit_shield`, `heal_per_second`, `shoot_interval`. Un nouveau monstre = combiner
ces champs dans `make_content.gd`.

### Vagues
- Niveaux 1 et 2 : vagues écrites (`WaveDef`), montée manuelle.
- Massacre : **infini**, vagues fabriquées par `WaveBudget` — budget `8 + 3(n-1)`,
  mini-boss toutes les 5, boss toutes les 10. Une vague de budget 8 = une combinaison de
  puissances totalisant 8.

---

## Principes d'équilibrage

### Cartes
- Temps d'incantation ≈ puissance. Une commune tourne autour de 1.6–2.4 s.
- À ×4 une carte de 4 s se lance en 1 s : toujours penser l'effet **à vitesse max**,
  c'est là qu'il est le plus fort.
- Une légendaire doit changer la façon de jouer, pas seulement ajouter des dégâts.

### Monstres
- **`power` d'abord** : c'est la monnaie du budget de vagues. Un P3 doit valoir trois P1
  en pression réelle sur le mage, pas seulement en PV.
- `hp × contact_damage` mesure la menace ; `base_xp` récompense la difficulté réelle.
- Un monstre rapide doit être fragile, un tank doit être lent.
- Les immunités et les comportements créent la diversité de deck : un golem punit le
  mono-contrôle, un totem force à cibler le protecteur, un archer force à ne pas
  laisser traîner le fond de terrain.

### Vagues
- 20–30 s chacune, difficulté croissante.
- Mini-boss à mi-parcours, boss en dernière vague.
- Mélanger les archétypes : un groupe rapide + un tank oblige à arbitrer.

---

## Intégrations obligatoires

- Carte → un dossier de rareté dans `resources/cards/`
- Monstre → au moins une `WaveDef` ou un `enemy_pool` de niveau
- Objectif → une clé connue de `ObjectiveChecker`
- Nouvelle clé d'effet → un handler enregistré dans `EffectRegistry`

Sinon : **AUDIT rouge**.

---

## Sortie attendue

1. Fiche du contenu (stats, effets, intention de design)
2. Code à ajouter dans `tools/make_content.gd`
3. Pools où le brancher
4. Sortie du harnais

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
