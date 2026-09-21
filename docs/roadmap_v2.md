# Time Wizard — feuille de route de la version 2

Document de travail. Il confronte la demande du 21 septembre (liste complete de
l'utilisateur) a ce qui existe dans le depot, et repartit le reste entre agents
par chantiers a fichiers DISJOINTS : deux agents qui editent le meme fichier en
parallele s'ecrasent (vu sur `tools/make_content.gd`).

Legende : **FAIT** = en place et teste · **PARTIEL** = base en place, a etendre ·
**A FAIRE** · **BLOQUE** = attend un pack absent du disque.

---

## 1. Assets

### Presents dans `raw_assets/` (23 packs)

| Pack | Usage actuel |
|---|---|
| Tiny Swords (Free Pack) | 15 silhouettes, decor, UI 9-tranches, arbres, rochers |
| Tiny RPG Character Pack 02 | Blood Monster, Demon |
| Free Pixel Effects Pack | grilles 100 px, encore quelques zones/impacts |
| Effect and FX Pixel All Free (750 effets) | **45 feuilles, une par carte** (DEC-017) |
| VFX Free Pack, Pipoya HEXShield / WarpPortal / Mysterious Object | vortex_hd, boom_hd, shield_hex ; **+ 8 feuilles extraites** (3 portails, 2 esprits, 3 orbes) dans `Fx.STRIPS`, en attente d'une carte qui les joue |
| Pixel Holy Spell 32x32 (.rar, ouvrir avec 7-Zip) | **ECARTE** — les 2 planches vues a l'oeil : anneaux et moulinets en traits fins qui se DISSOLVENT en fin d'animation. Meme en icone c'est illisible (piege deja paye sur 7 effets du pack FX), et 32 px sous les 64 px en place |
| craftpix battleground / 4 nature / vampires locations | 4 fonds peints par acte |
| craftpix animated magic book | **pas branche** — prioritaire pour galerie/bestiaire/deck |
| free-demon-characters (portraits statiques) | **extrait** : `assets/portraits/` — 8 demons x 4 expressions + `demon_heads.png` (grille 8x4 de tetes 64 px). Pret pour le chantier D |
| free-pixel-magic-sprite-effects | police Planes_ValMore ; effets 72 px non branches |
| godot-pixel-effect (henrysoftware) | **SANS OBJET** — le zip ne contient que `PixelEffect.exe` + `.pck` : c'est un LOGICIEL d'edition d'effets, pas un pack d'assets. Rien a extraire |
| explosion pack 1 | explosion_c/d/e |
| SpaceBackgroundSource (deep-fold) | **2 fonds composes** : `assets/backdrops/menu_space.png` et `act5_divine.png` (1080x1920, 22 et 39 ko). Le zip n'a AUCUNE image : c'est un generateur Godot 3 a shaders, porte en Python par `tools/assets/compose_space.py`. Rien n'est branche : a afficher par les chantiers C et D/J |
| 400 Sounds, FreeSFX, 16-bit RPG Music, xDeviruchi | 42 sons, 10 musiques |
| monsters_2026_09 : Golems, FlyingForest, Peacock, Enemies Pack (Sunnyland), Duelyst | 8 familles + 5 boss |

### ABSENTS du disque — a deposer a la racine du projet

L'assistant ne peut pas telecharger depuis itch.io / craftpix (connexion et
conditions d'utilisation par pack). Deposer les archives a la racine, elles
seront rangees dans `raw_assets/`.

*Liste VERIFIEE le 2026-09-21 : chacun de ces noms a ete cherche sur le disque
(projet, Bureau, Telechargements). Tous sont bien absents, aucune archive neuve
n'attend a la racine, et rien de cette liste n'est present sous un autre nom.
Deux besoins sont toutefois DEJA couverts en partie, voir les corrections :*

- *visual novel (D) : les portraits de `free-demon-characters` sont extraits
  (`assets/portraits/`). Les packs ci-dessous restent utiles pour varier les
  PNJ, mais le chantier D n'est plus bloque faute de tout portrait.*
- *fonds (C et D/J) : `menu_space.png` et `act5_divine.png` sont composes.*

**Debloquent les menus (chantier C)** : paper-texture-pack (oddsandents),
dungeonmode (datagoblin), menu-buttons (nectanebo).

**Debloquent les icones de sorts (chantier C, puis passifs)** : warlock skill
icons, 40 fire mage icons, 250 magical icons (batareya), 40 earth mage, 40
barbarian, night elf skill icons, 50 aeromancer icons.

**Debloquent le visual novel (chantier D)** : 20 Free Fantasy characters
(cogabushi), ttrpg-legacy-characters 1 a 5 (ddant1100), dark-elf et halfling
(craftpix), wood-elves-backgrounds (lornn).

**Debloquent les nouveaux monstres et boss (chantier I)** : tiny-rpg-character
pack 01 (zerie), sci-fi-character-pack-9, monsters-creatures-fantasy (luizmelo),
pixel-art-animated-slime (rvros), cacodaemon (elthen), lords-of-pain, nightborne
warrior, free-animated-enemy-sprites (robertpinero), evil-wizard, c3-3dobject-alpha,
npc-mage-free, fox sprites (elthen), mecha-golem, fire-worm, boss-frost-guardian,
undead-executioner, boss-demon-slime.

**Debloquent les nouveaux sorts physiques (chantier H)** : free-undead-tileset
(craftpix), epic-rpg-world ancient ruins.

**Effets et fonds** : forest-battle-backgrounds (craftpix), pipoya time-magic /
bell / light-pillar, animated-explosion-sprite-pack, codemanu pixelart-effect-pack,
dark-spell-effect (pimen), sc-anime-essentials (seraphcircle).

**Skins du mage** : witches-pack (9e0).

### Licences — AUDITEES le 2026-09-21 (chantier A)

Les 23 entrees ont ete auditees. Tableau complet : **`docs/assets_index.md`**.
Aucun pack n'est a retirer ; il reste **trois points a regler avant de VENDRE**
le jeu (rien ne bloque le developpement) :

1. **Effect and FX Pixel All Free** (BDragon1727) — les 45 feuilles de sorts,
   donc l'ossature visuelle du jeu. Gratuit en non-commercial ; en commercial
   l'auteur demande une **contribution de montant libre** sur sa page itch. A
   payer avant la sortie ; aucun remplacement d'asset n'est necessaire.
2. **xDeviruchi** (musiques) — le PDF embarque impose un credit a la lettre :
   `Original music by Marllon Silva (xDeviruchi)`. Les resumes web qui disent
   l'inverse sont faux pour la version 2025 qu'on a. A mettre dans un ecran de
   credits.
3. **FreeSFX** — aucun fichier de licence, auteur non prouve (piste Kronbits /
   CC0, deduite mais non certaine). Demander a Alexis d'ou vient le zip.

**Duelyst : la crainte est levee.** Counterplay Games a ouvert Duelyst, code ET
assets, en **CC0** (depot `open-duelyst/duelyst`) ; le pack itch n'est qu'un
portage Unity de fichiers deja dans le domaine public. Seule reserve, propre au
CC0 : les marques et logos ne sont pas cedes — on n'utilise que les sprites.

craftpix (6 packs) : usage commercial libre, sans credit, **redistribution des
sources interdite** — c'est ce qui justifie de garder `raw_assets/` hors du depot.

---

## 2. Etat de la demande, point par point

### Interface des menus
| Demande | Etat | Chantier |
|---|---|---|
| Structure titre / centre / menu bas | FAIT | — |
| Niveau du joueur + cartes en haut, profil en haut a droite | A FAIRE | C |
| Fusionner bestiaire et galerie (onglets Sorts / Passifs / Bestiaire) | PARTIEL (les deux existent, separes) | C |
| Livre a pages (asset magic book), fleches gauche/droite | A FAIRE | C |
| Detail avec nb d'utilisations, monstres tues, ameliorations | PARTIEL (detail sans stats) | C |
| Inconnu = grise | FAIT | — |
| Icones de sort partout | FAIT (45 feuilles propres) ; a re-choisir dans les packs d'icones quand ils arriveront | C |
| Police plus lisible, tout un peu plus grand | PARTIEL (Planes_ValMore posee, tailles a remonter) | C |
| Vraies icones de menu (pas un steak) | A FAIRE (Tiny Swords icon_01..12 seulement) | C |
| Titre stylise, nom "Time Wizard" | A FAIRE | C |
| Deck : 15 cartes exactement, 0-3 passifs, ≤3 legendaires, ≤3 epiques | A FAIRE (regles actuelles : 8-20 cartes) | K |
| Plusieurs onglets de deck | A FAIRE | K |
| Profil : succes par rarete au lieu des defis | PARTIEL (10 defis + niveau de compte existent) | L |
| Contour de couleur par rarete (cartes, monstres, succes) | A FAIRE | L |
| Cosmetiques : couleur du mage, chapeau, tour ; onglet dedie | PARTIEL (titres et avatars) | L |
| Fond de la barre de titre selon le niveau | A FAIRE | L |

### Campagne
| Demande | Etat | Chantier |
|---|---|---|
| Carte de campagne sur les fonds de combat, points jaunes, fleches d'acte | PARTIEL (carte en iles existe) | E |
| 3 objectifs par niveau | FAIT (3 par niveau, 4 types) ; types a enrichir | H |
| Histoire : prologue, 5 actes (Nuri, Sky, Tombol, Demons, Divin), plot twist de l'enfant | A FAIRE (histoire actuelle = 4 actes differents) | D |
| Sequences visual novel entre les niveaux | A FAIRE (aucun systeme de dialogue) | D |
| Niveau 1 tutoriel, deck 9 cartes, 3 vagues ; niveau 2 en 4 vagues ; puis 6 | A FAIRE | H |
| Pool de cartes qui grandit de 3 par niveau | A FAIRE | H |
| Fin : deblocage du mode infini | A FAIRE | J |

### Mode infini
| Demande | Etat | Chantier |
|---|---|---|
| Tous monstres et boss, fond change toutes les 6 vagues, mini-boss v3 / boss v6, fond qui pese sur le tirage | PARTIEL (Massacre = infini par budget, mini-boss v5 / boss v10) | J |

### Sorts et passifs
| Demande | Etat | Chantier |
|---|---|---|
| Passifs hors du deck, actifs des le debut, 3 emplacements, echange au 4e | A FAIRE (aujourd'hui : cartes jouees) | F |
| Passif actif seulement au-dela d'une vitesse (ex. 140 %) | A FAIRE | F |
| Plus de passifs, avec raretes ; 20 % de passifs a la montee de niveau | A FAIRE (3 passifs) | F |
| Icone des passifs a cote de la barre de vitesse, a leur seuil | A FAIRE | F |
| Amelioration des cartes en combat (XP par lancer, choix parmi 3) | A FAIRE | G |
| Arbre qui attire les ennemis ; sort de stun ; arbre a zone de poison ; eau qui ralentit | A FAIRE (Tiny Swords, undead tileset) | H |
| Element sur chaque sort de degats + resistances en % par monstre | PARTIEL (tags d'element, immunites binaires) | B3 |

### Monstres
| Demande | Etat | Chantier |
|---|---|---|
| Monstres un peu plus grands | A FAIRE (VISUAL_FACTOR 1.9) | B1 |
| Apparition plus bas + fondu de 0,5 s | A FAIRE | B1 |
| Feu follet -> Planogo, vole par-dessus les murs, boule de poison 10 PV | A FAIRE | B1 |
| Nuee de rats -> Oiseau mirage, sprite qui ne tourne plus | A FAIRE | B1 |
| Boss a mecaniques originales (revient 3 fois, ressuscite, bouclier renvoi, 10 coups immunises, slime enorme qui se divise, 3 mages a resistances, renard qui dort, mecha laser, executeur onde de choc, demon slime immunise au feu) | PARTIEL (3 boss a mecanique) ; la plupart BLOQUES par les packs absents | I |
| Boss d'un acte devenant monstre courant ensuite | A FAIRE | I |

### Combat
| Demande | Etat | Chantier |
|---|---|---|
| Vitesse non accelerable manuellement, +1 % toutes les 0,5 s | PARTIEL (monte de 10 % / 8 s ET bouton + barre cliquable, a retirer) | B1 |
| Main a 6 cartes | FAIT | — |
| Quitter le combat depuis la pause | A FAIRE | B1 |

---

## 3. Chantiers, agents et ordre

Chaque chantier a un perimetre de fichiers. Un agent n'ecrit que dans le sien.

**Vague 1 (lances en parallele, perimetres disjoints)**
- **A — Assets et licences** (asset-pipeline) : audit des licences des 23 packs,
  extraction de ce qui est present et non branche (WarpPortal, Mysterious Object,
  godot-pixel-effect, SpaceBackground, portraits demons), index `docs/assets_index.md`.
  Fichiers : `raw_assets/`, `assets/`, `tools/assets/`, `docs/assets_index.md`.
  Ne touche PAS au livre magique (reserve a C).
- **B1 — Sensation de combat** (gdscript-dev) : vitesse naturelle seule, pause ->
  menu, apparition basse en fondu, monstres +10 %, Planogo volant a boule de
  poison, Oiseau mirage. Fichiers : `speed_gauge.gd`, `game_config.gd`, `hud.gd`
  (bouton vitesse, pause), `enemy.gd`, `enemy_def.gd`, `battlefield.gd`,
  `wave_spawner.gd`, section `_enemies()` de `make_content.gd`, `test_speed_percent.gd`.
- **C — Menus et galerie-livre** (godot-ui-dev) : en-tete (niveau, cartes, profil
  a droite), titre "Time Wizard", polices, icones de menu, fusion galerie +
  bestiaire dans le livre a pages avec stats d'usage. Fichiers : `scripts/ui/panels/
  gallery_panel.gd`, `bestiary_panel.gd`, `main_menu.gd`, `ui_theme.gd`, extraction
  du livre magique dans `assets/ui/`, ajouts dans `save_data.gd` (compteurs d'usage).
- **D — Histoire et visual novel** (content-designer) : reecriture de `docs/histoire.md`
  selon le nouveau plan (prologue, 5 actes, plot twist), systeme de scenes de
  dialogue (`scripts/data/dialogue_def.gd`, `scenes/story/`, `scripts/ui/story_scene.gd`,
  un crochet dans `scene_router.gd`), prologue et acte 1 ecrits. Portraits :
  ceux presents sur le disque en attendant les packs.

**Vague 2 (apres B1 et C, car ils partagent le HUD et le deck)**
- **F — Passifs v2** : hors deck, seuils de vitesse, raretes, icones sur la barre.
- **K — Regles de deck** : 15 cartes, plafonds par rarete, plusieurs decks.
- **B3 — Elements et resistances** ; **G — Amelioration des cartes en combat** ;
  **H — Nouveaux sorts et rebati des niveaux 1-2** ; **L — Profil, succes, cosmetiques**.

**Vague 3 (quand les packs sont la)**
- **I — Nouveaux boss et monstres** ; **J — Mode infini** ; **E — Carte de
  campagne sur fonds** (peut demarrer avant, elle ne depend que des fonds presents).

Chaque chantier se termine par : harnais vert, mesure au banc si la puissance
change (`balance-tester`), captures lues pour tout ce qui se voit.
