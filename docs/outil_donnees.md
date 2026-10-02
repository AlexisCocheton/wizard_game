# L'inventaire du contenu

> « Créer un outil où on pourrait avoir toutes les données des monstres, sorts et
> niveaux de la campagne »

Un outil pour régler l'équilibrage sans ouvrir les `.tres` un par un.

## Le lancer

```bash
Godot --headless --path . tools/data_sheet.tscn
```

Il écrit six CSV dans `.testout/data/` et imprime un résumé sur la console.
Il ne modifie **aucune** donnée de jeu : il ouvre les `.tres` en lecture.

**Jamais avec `--script`.** Sur Godot 4.4 les autoloads ne sont alors pas
enregistrés, `ContentDB` est vide, et l'inventaire sortirait à zéro ligne sans
prévenir. L'outil le détecte et refuse de tourner, mais autant le savoir.

## Ce qu'on y trouve

| Fichier | Une ligne par | Ce qu'on y cherche |
|---|---|---|
| `monstres.csv` | type de monstre | trier par PV, filtrer sur une résistance, voir dans quels niveaux il descend |
| `sorts.csv` | carte | comparer deux sorts à dégâts/seconde égaux, voir par quel chemin une carte arrive en main |
| `niveaux.csv` | niveau | puissance totale, PV cumulés, saut maximal de la courbe, deck fourni |
| `vagues.csv` | vague de campagne | **la granularité où la courbe de difficulté se lit vraiment** |
| `effets.csv` | brique d'effet | quelles cartes utilisent `ground_zone`, et avec quels chiffres |
| `massacre.csv` | vague du mode infini | les budgets, qui ne sont écrits nulle part |

Les CSV sont en **point-virgule** avec les décimaux en **virgule** et une BOM
UTF-8 : c'est ce qu'attend Excel en locale française. Sans ça toutes les colonnes
atterrissent dans la première cellule et les accents sortent en mojibake.

Les lignes sont triées de façon stable (monstres par puissance, cartes par
rareté, niveaux par id) : deux exécutions produisent deux fichiers comparables
avec un `diff`, donc on peut voir ce qu'un chantier a changé dans le contenu.

## Les colonnes qui ne sont dans aucun `.tres`

C'est la moitié de l'intérêt de l'outil. Plusieurs chiffres qui décident de
l'équilibrage ne sont **écrits nulle part** — un inventaire des seuls champs
bruts les raterait tous.

| Colonne | D'où elle vient | Pourquoi le champ brut ne suffit pas |
|---|---|---|
| `degats_contact` | `GameConfig.CONTACT_DAMAGE_BY_POWER` ou le barème boss | vaut `0` dans presque tous les `.tres` ; `contact_source` dit d'où sort la valeur jouée |
| `vitesse_reelle` | `base_speed × ENEMY_SPEED_SCALE` (0,52) | un monstre écrit à 60 descend à 31 px/s en partie : lire `base_speed` se tromperait du double |
| `res_*` | `EnemyDef.resistance_to()` | remplit les trous à 1,00 et applique le repli sur l'ancien champ `immune_tags` |
| `degats_total` | conversion par handler, voir plus bas | `magnitude` ne veut pas dire la même chose selon l'effet |
| `degats_par_seconde` | dégâts réels / temps d'incantation | **le** chiffre de comparaison : 60 dégâts sur 2,8 s rendent moins que 26 sur 1,4 s |
| `acces` | croisement des decks et des tirages | aucun champ ne dit comment une carte arrive en main |
| `puissance` d'une vague | somme des puissances, nuées comptées en corps, boss hors budget | une entrée de 3 `rat_swarm` fait descendre **12** corps, pas 3 |
| `pv_par_seconde` | PV de la vague / durée | la pression réelle : les mêmes PV sur 40 s ou sur 20 s ne se jouent pas pareil |
| `saut_max` | rapport entre vagues **ordinaires** consécutives | une vague de palier porte moins de troupes ; l'inclure ferait sonner l'alarme partout |
| `niveaux` d'un monstre | croisement inverse | un `.tres` de monstre ne sait pas dans quels niveaux il descend |

### Le piège de `magnitude`

`EffectSpec.magnitude` est documenté comme « intensité principale, sens défini par
le handler » — et les handlers en font trois choses différentes :

- **un total** : `damage_single`, `pierce_line`, `knockback`, `stun_zone` ;
- **un débit par seconde** : `ground_zone`. Le paramètre de
  `battlefield.spawn_ground_zone()` s'appelle littéralement `dps`. Le Météore
  porte `magnitude = 200` sur 0,3 s de zone, soit **60 dégâts réels** — exactement
  ce qu'annonce sa description ;
- **pas un dégât du tout** : `slow_enemy_gauge` y met un pourcentage de
  ralentissement (40 = 40 %), `draw_cards` un nombre de cartes.

Additionner les magnitudes brutes faisait donc passer le Météore pour la carte la
plus violente du jeu (200) et créditait l'Entrave temporelle de 40 dégâts qu'elle
n'infligera jamais. La table `MAGNITUDE_SENS` en tête de `tools/data_sheet.gd`
fixe le sens de chaque clé ; un handler absent est traité en « autre », parce
qu'une colonne vide vaut mieux qu'un chiffre inventé.

Quand un effet de la carte n'exprime pas des dégâts, `degats_partiels` vaut `oui` :
le total ne raconte alors qu'une partie du sort.

## Les anomalies

L'outil signale ce qui cloche. Ce sont des **odeurs, pas des fautes** : à chacune
il peut y avoir une bonne raison, et c'est au testeur de trancher. Les règles
dures (3 objectifs par niveau, une clé d'effet connue) restent verrouillées par
l'étage `audit` du harnais.

Familles signalées :

- `MONSTRE ORPHELIN` — n'apparaît dans aucun niveau, aucun pool, et n'est engendré
  par personne. Du contenu écrit que personne ne verra.
- `SANS RESISTANCE` — tous les éléments l'entament pareil, donc changer de deck
  contre lui ne sert à rien.
- `CONTACT HORS BAREME` — sa puissance est absente de `CONTACT_DAMAGE_BY_POWER` et
  il n'a pas de `contact_damage` explicite : il retombe sur 5 par défaut.
- `RENVOI PERMANENT`, `ZONE INTERDITE MOBILE`, `DIVISION VIDE`, `INVOCATION VIDE`
  — des règles écrites en commentaire dans `enemy_def.gd`, que rien ne vérifiait.
- `JAMAIS GARANTIE` — la carte n'est dans aucun deck d'exploration ni récompense.
  Elle sort bien aux montées de niveau (le tirage couvre tout le catalogue), mais
  le joueur ne peut pas compter sur elle, et son équilibrage n'est jamais mesuré
  au banc sur un niveau précis.
- `DEGATS SANS ELEMENT` — aucune résistance ne s'applique, donc c'est par accident
  la meilleure carte du jeu contre le bestiaire entier.
- `DESCRIPTION TROMPEUSE` — la carte annonce au joueur un chiffre que le `.tres`
  n'applique pas. Le joueur ne lit pas le `.tres`, il lit la carte.
- `CLE D EFFET INCONNUE` / `CLE DE PASSIF INCONNUE` — un sort qui ne fera rien.
  Les deux familles sont contrôlées contre **deux registres différents** :
  `EffectRegistry` pour les sorts, `RunState.PASSIVE_KEYS` pour les passifs. Un
  passif ne s'incante pas : le contrôler contre `EffectRegistry` produisait
  14 fausses alertes.
- `COURBE QUI RECULE` / `SAUT DE DIFFICULTE` — la difficulté redescend, ou monte
  de plus de ×2, entre deux vagues **ordinaires**.
- `EFFET SANS CARTE` — une clé enregistrée qu'aucune carte n'utilise.

### La section « débit ou total ? »

À part des anomalies, parce que ce n'est pas N fautes mais **une décision**. Sept
cartes de zone annoncent dans leur texte le débit par seconde et non ce qu'un
monstre encaisse. La réponse est la même pour toutes : soit on écrit « par
seconde » sur les cartes, soit on revoit les chiffres.

## Ce qu'il ne fait pas

- **Il ne joue pas.** Un taux de victoire se mesure au banc
  (`tools/sim_balance.gd`). Les deux sont complémentaires : le banc dit « le
  niveau 6 est dur », l'inventaire dit « parce que sa vague 5 pèse 10 points
  contre 15 à la 4 ».
- **Il n'écrit aucune donnée de jeu.**
- **Il n'est pas dans le harnais.** C'est un outil de jugement, comme
  `tools/ui_preview.gd`.

---

# L'atelier du testeur (vague 8)

> « Dans les paramètres, au niveau du menu testeur, créer une option où je peux
> avoir accès à tous les sorts, tous les monstres et tout le contenu des niveaux
> […] Créer un onglet TEST […] Créer la possibilité de télécharger un document
> de changement que je pourrai te transmettre. »

**Où :** Réglages → activer le mode testeur → bouton **ATELIER : cartes,
monstres, vagues**. C'est une page à part (`scenes/tester/TesterTools.tscn`),
cinq onglets :

| Onglet | Ce qu'on y fait |
|---|---|
| SORTS / MONSTRES / NIVEAUX | liste avec recherche, puis la **fiche** : chaque champ exporté de la Resource, réglable (boutons − / + ou saisie au clavier numérique). Un champ réglé affiche sa valeur d'origine et un bouton **ORIGINE**. Aperçu du monstre ou de l'icône. |
| TEST | composer une vague (monstres et nombres, difficulté), choisir les cartes de la partie (deck de départ, deck d'un niveau, ou carte par carte), la vitesse de départ, le fond, une graine ; **JOUER LA VAGUE** lance une vraie partie, et la fin ramène à l'atelier avec le bilan. |
| DOC | la liste des réglages, **EXPORTER** (fichier dans `user://changements/`), **COPIER** (presse-papiers, à coller dans un message depuis le téléphone), **IMPORTER** (depuis le presse-papiers), **RÉINITIALISER**. |

## Comment ça marche

- Un **réglage** (une « surcharge ») = `{cible, champ, valeur}`, gardé dans
  `user://tester_overrides.json`. Il est rejoué par `TesterOverrides` juste après
  le chargement de `ContentDB` (une seule accroche, `content_db.gd`) en
  modifiant les Resources **sur place** : elles sont partagées, toute la partie
  voit la valeur sans autre branchement.
- **Seulement en mode testeur.** Éteindre le mode rend le jeu d'origine
  **immédiatement, sans redémarrer** (`sync()` est branché sur
  `SaveData.profile_changed`). Les réglages restent en réserve et reviennent en
  rallumant. Une remise à zéro du profil éteint le mode, donc pareil.
- **Une saisie invalide est écartée et signalée**, jamais appliquée à moitié :
  hors bornes, mauvais type, id inconnu, champ non éditable (`id`, textures,
  `is_passive`, `check_key`, `immune_tags` déprécié). Bornes : `@export_range`
  d'abord, puis la table `TesterOverrides.BOUNDS` (garde-fous contre la faute
  de frappe, pas des règles d'équilibrage).
- Les **résistances** affichées et réglées sont les valeurs **jouées** (déjà
  passées par `EnemyDef.accentuate`). L'outil ci-dessous retraduit en valeur de
  table.
- La **teinte du sprite** n'est pas un champ d'`EnemyDef` : c'est
  `AnimCatalog.MODULATE`. Le champ virtuel `tint` écrit dans une table que
  `AnimCatalog.modulate_for()` consulte d'abord.
- Les **vagues de campagne** sont embarquées dans les `LevelDef`
  (`resources/waves/` n'est lu par aucun code de jeu) : un réglage porte sur une
  vague **entière** (`waves/<i>`) ou sur leur nombre (`waves/#`). Ajouter une vague
  copie la dernière sans le drapeau de boss ; retirer la vague *k* fait descendre
  les suivantes d'un cran.
- La **vague de test** est un `LevelDef` fabriqué (`TesterRun.make_level`, comme
  `MassacreMode.level_def()`), jamais dans `ContentDB` : ni campagne, ni écran de
  victoire, ni récompense. Son hasard passe par `RunState.world_rng` comme toute
  partie ; une graine non nulle rejoue la même vague. Abandonner depuis la pause
  ramène au menu (le HUD n'est pas touché).

## Document de changement

Le même JSON sert d'export, d'import et de fichier de sauvegarde. Format
(version 1) :

```json
{
  "format": "time_wizard_changements",
  "version": 1,
  "jeu": {"nom": "Wizard Story", "version": "", "commit": "edb0ebc421b0 (main)"},
  "date": "2026-10-02T17:46:08",
  "mode_testeur": true,
  "resume": "3 changements : 1 sort, 1 monstre, 1 niveau",
  "changements": [
    {"cible": "enemy:gnome", "nom": "Gnome", "champ": "max_hp", "libelle": "PV",
     "avant": 12.0, "apres": 30.0, "texte": "Monstre Gnome : PV 12 -> 30"},
    {"cible": "card:frost_field", "nom": "Champ de givre",
     "champ": "effects/0/radius", "libelle": "effet 1 : rayon",
     "avant": 180.0, "apres": 240.0, "texte": "..."},
    {"cible": "level:lvl_01", "nom": "Les Marches du Temps", "champ": "waves/0",
     "libelle": "vague 1",
     "avant": {"id": "w1", "duration": 26.0, "difficulty": 1.0, "is_miniboss": false,
               "is_boss": false, "entries": [{"enemy": "gnome", "count": 5,
               "spawn_delay": 2.2, "start_offset": 0.0}]},
     "apres": {"...": "meme forme"}, "texte": "..."}
  ],
  "ignores": [{"cible": "...", "champ": "...", "apres": "...", "raison": "..."}]
}
```

- `cible` : `card:<id>`, `enemy:<id>`, `level:<id>`, `objective:<id>`.
- `champ` : nom de propriété (`max_hp`), clé de dictionnaire
  (`resistances/feu`, `params/pct`), brique d'effet (`effects/0/magnitude`,
  `effects/0/params/slow_pct`), vague (`waves/2`, `waves/#`), teinte (`tint`).
- valeurs : nombres, booléens, textes ; enum par son nom (`"Rare"`), couleur
  `"#rrggbbaa"`, références par id, listes de listes d'ids (un deck répète ses
  exemplaires).
- `commit` vaut `inconnu` sur le téléphone : c'est `avant` qui permet de voir
  qu'un contenu a bougé depuis l'export.
- À l'import, seuls `cible`, `champ`, `apres` comptent ; `avant` et `texte`
  sont recalculés.

### Chez nous : `tools/apply_changes.py`

```bash
python tools/apply_changes.py changements.json             # rapport + diff affiché
python tools/apply_changes.py changements.json --patch x.diff   # puis git apply x.diff
python tools/apply_changes.py changements.json --ecrire    # modifie les générateurs
Godot --headless --path . tools/make_content.tscn          # régénère les .tres
bash tools/run_tests.sh
```

Pour chaque changement, le rapport dit **où** (fichier:ligne dans
`tools/make_content.gd`, `tools/make_passives.gd` ou
`scripts/game/anim_catalog.gd`) et un statut :

| Statut | Sens |
|---|---|
| DIFF | modification mécanique proposée dans le diff (argument d'`_enemy`/`_card`/`_spec`, ligne `var.champ = …` remplacée ou ajoutée, table `_resist`, entrées `_entry(...)` d'une vague, `_deck([...])`, pool, teinte) |
| DÉJÀ FAIT | le code porte déjà la valeur « après » |
| À VÉRIFIER | le code ne porte pas la valeur « avant » : le contenu a bougé depuis l'export, ou la valeur est calculée. Rien n'est proposé. |
| À LA MAIN | pas mécanique : nombre de vagues, table `_progression_de` (objectifs, cartes nouvelles, récompenses), paramètres d'un objectif **partagé** (son id se déduit des paramètres, DEC-023), passifs |

Points d'attention que le rapport signale lui-même :

- **Résistances** : la valeur jouée est retraduite en valeur de table
  (inverse d'`accentuate`) ; quand l'arrondi au centième empêche d'atteindre
  exactement la valeur demandée, il dit laquelle sera jouée.
- **Rareté d'une carte** : l'enum change, mais le `_save()` écrit toujours dans
  l'ancien dossier `resources/cards/<rareté>/`.
- Le diff n'est **jamais** appliqué sans `--patch`/`--ecrire`, et l'outil ne
  lance jamais Godot : relire, régénérer, passer le harnais, et mesurer au banc
  ce qui touche l'équilibrage.
