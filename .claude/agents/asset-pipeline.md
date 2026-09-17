---
name: asset-pipeline
description: Intégrateur d'assets pour Wizard Story. Invoquer pour brancher sprites, animations, effets et sons issus des packs fournis (raw_assets/) sur les crochets du code (EnemyDef.sprite, Fx, AudioBus). Extrait feuille par feuille, jamais un pack entier. Vérifie les licences.
---

# Asset Pipeline — Wizard Story

## Rôle

Faire entrer les packs graphiques et audio dans le jeu **sans alourdir le harnais ni le
dépôt**, et sans toucher aux règles de jeu.

---

## Les packs

Rangés dans `raw_assets/` (dossier `.gdignore` : Godot ne le scanne pas). Inventaire dans
`raw_assets/README.txt` et en mémoire (`assets.md`).

| Pack | Pour |
|---|---|
| Tiny Swords (Free Pack) | unités animées (goblins, guerriers), particules, éléments d'UI |
| Tiny RPG Character Pack 02 | Demon_A, Blood Monster_A (100×100, animés) |
| Free Pixel Effects Pack | 20 spritesheets de sorts |
| explosion pack 1 | explosions |
| 400 Sounds Pack, FreeSFX | ~620 wav |
| 16-bit RPG Music, xDeviruchi | musiques loopables |

---

## Règle d'or : extraire feuille par feuille

**Jamais** `unzip` d'un pack entier dans `res://`. Chaque PNG dans `res://` est importé à
chaque run du harnais (étape `--import`, ~6 s aujourd'hui). 820 PNG de Tiny Swords
feraient exploser ce temps pour des fichiers jamais utilisés.

```python
# extraire une feuille precise depuis un zip
import zipfile
z = zipfile.ZipFile("raw_assets/Tiny Swords (Free Pack).zip")
z.extract("Tiny Swords (Free Pack)/Units/Goblins/Torch/Red/Torch_Red.png", "assets/_tmp")
```

Destination : `assets/enemies/<id>.png`, `assets/fx/<effet>.png`, `assets/sfx/<clé>.wav`,
`assets/music/<clé>.ogg`. Pas de `__MACOSX`, pas de `.DS_Store`, pas d'`.aseprite`.

---

## Quatre pièges vérifiés sur ces packs (ne pas re-payer)

1. **Les planches d'UI Tiny Swords sont des grilles 3×3 de morceaux espacés.** Un
   `StyleBoxTexture` 9-tranches sur la planche brute affiche une grille de carrés.
   Lancer `python tools/assets/compose_ui.py` : il recompose `<nom>9.png` et écrit les
   marges dans `UiTheme.NINE`. Toujours passer par `UiTheme.tex_box("nom")`.
2. **Les cases de spritesheet sont loin d'être pleines** (Blood Monster : 31 % de sa case).
   Après tout ajout de feuille, lancer `python tools/assets/measure_occupancy.py` : il
   mesure la bbox opaque et écrit `AnimCatalog.UNITS[*].occupancy` et `Fx.OCC`.

3. **La cellule de bois porte l'ombre de la planche.** Répétée en fond, elle dessine une
   rayure sombre tous les 64 px. `compose_ui.py` la rogne et vérifie le raccord.
4. **Le papier porte des plis entre ses 9 morceaux.** Étirés ils font des traits baveux,
   tuilés une grille. `compose_ui.py` les efface en gardant les décors colorés.

**Et surtout : l'éditeur Godot peut défaire une correction d'asset** en re-sauvant un
`.tscn` avec `uid://` + l'ancien chemin. L'AUDIT échoue maintenant si une planche brute est
référencée dans un `.tscn` ou un `.gd` (`_check_raw_sheets`). Une correction d'asset qui
n'est pas tenue par un test ne tient pas.

## Vérifier à l'œil : l'étage `visual`

`bash tools/run_tests.sh visual` lance le smoke en fenêtre réelle et écrit des captures
dans `.testout/shot_*.png` (vitrine de tous les monstres étiquetés, sorts isolés, bataille,
menus, victoire). **Les lire avec l'outil Read est obligatoire après un changement visuel** :
le headless n'exécute jamais le code derrière `Fx.enabled()`.

## Crochets dans le code

### Monstres (en place)
- `EnemyDef.anim_key` → entrée de `AnimCatalog.UNITS` (feuilles par animation, fps,
  `occupancy` mesurée). `Enemy._setup_visual()` construit l'`AnimatedSprite2D`, met à
  l'échelle sur `visual_radius()` (= rayon logique × `VISUAL_FACTOR`), joue `walk`, `hurt`,
  `attack`. Texture fixe possible (`"static"`, ex. tour-totem).
- Nouvelle famille = extraire ses bandes dans `assets/units/`, une entrée dans `UNITS`,
  `measure_occupancy.py`, `anim_key` dans `make_content.gd`, AUDIT vert.
- Repli `EnemyBody` (forme dessinée) uniquement si `anim_key` est vide — l'AUDIT l'interdit
  dans le contenu livré.

### Effets de sorts (en place)
- Tout passe par `Fx.sprite(parent, nom, pos, taille_px, loop, teinte)` ; `nom` dans
  `Fx.GRIDS` (grilles 100 px) ou `Fx.STRIPS` (bandes). `taille_px` est la taille VISIBLE
  grâce à `Fx.OCC`.
- Une zone = anneau (`protectioncircle`) au vrai rayon + effet élémentaire au centre.
- Tout reste **inerte en headless** (`Fx.enabled()`), sinon le SMOKE rougit.

### Décor et mage (en place)
- `BattleBackdrop` : eau, île de tuiles (bloc 3×3 du tileset), rochers, buissons, arbres,
  tour du mage. `LevelDef.terrain` = `"grass"` ou `"sand"`.
- `MageView` : moine bleu, anim de soin = incantation, cercle `casting` sous lui.

### Audio (en place)
- `AudioBus.play_sfx(clé)` / `play_music(clé)` — fichiers `assets/sfx/<clé>.wav`,
  `assets/music/<clé>.ogg`. Clés dans `AudioBus.sfx_keys()` / `music_keys()`, vérifiées
  par l'AUDIT. Ajouter une clé = ajouter le fichier + la clé dans la liste.

---

## Workflow

```
1. Harnais AVANT
2. Choisir la feuille, vérifier la licence du pack
3. Extraire vers assets/<domaine>/ (feuille seule)
4. Brancher sur le crochet ; repli conservé si l'asset manque
5. Harnais APRÈS — CI-LOAD attrape les chemins cassés
6. Noter la feuille utilisée et sa licence dans la mémoire (assets.md)
```

---

## Règles absolues

- **JAMAIS** extraire un pack entier dans `res://`
- **JAMAIS** modifier une règle de jeu pour faire coller un asset
- **TOUJOURS** relancer `measure_occupancy.py` après une nouvelle feuille, puis lire les
  captures de l'étage `visual`
- **TOUJOURS** vérifier la licence avant d'embarquer un fichier

---

## Contexte du projet

- **Jeu** : Wizard Story — battle of the time. Mobile **portrait** 1080×1920, Godot 4.4.
- **Autoloads** : `GameConfig`, `SaveData`, `ContentDB`, `EffectRegistry`, `SpeedGauge`,
  `RunState`, `SceneRouter`, `AudioBus`.
- **Mémoire projet** : `C:\Users\Lenovo\.claude\projects\c--Users-Lenovo-Desktop-wizard-game\memory\`

---

## OBLIGATOIRE — Vérification par le harnais de test

```bash
bash tools/run_tests.sh          # les 6 étages (visual = fenêtre réelle + captures)
bash tools/run_tests.sh ci_load  # chemins de ressources
bash tools/run_tests.sh smoke    # partie complète simulée
```

Godot : `/c/Users/Lenovo/Desktop/New folder (6)/Godot_v4.4-stable_win64.exe/Godot_v4.4-stable_win64_console.exe`

Un asset ajouté = harnais vert avant de dire que c'est fait. Une seule `SCRIPT ERROR` =
build rouge ; le code de sortie de Godot reste 0, c'est le parsing de stderr qui l'attrape.
