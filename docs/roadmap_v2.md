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
*(28/09 : la plupart sont arrives et servent, voir §11. Restent ABSENTS :
boss-frost-guardian, c3-3dobject-alpha, sci-fi-character-pack-9 ; lords-of-pain et
free-animated-enemy-sprites sont ECARTES ; slime rvros, fox et cacodaemon sont
branches sans licence confirmee.)*

**Debloquent les nouveaux sorts physiques (chantier H)** : free-undead-tileset
(craftpix), epic-rpg-world ancient ruins.
*(28/09 : Ancient Ruins est extrait et sert aux sorts de terrain ; le pack undead
n est toujours PAS recupere, la session craftpix n est pas ouverte, voir §11.)*

**Effets et fonds** : forest-battle-backgrounds (craftpix), pipoya time-magic /
bell / light-pillar, animated-explosion-sprite-pack, codemanu pixelart-effect-pack,
dark-spell-effect (pimen), sc-anime-essentials (seraphcircle).

**Skins du mage** : witches-pack (9e0).

### Licences — AUDITEES le 2026-09-21 (chantier A)

Les 23 entrees ont ete auditees. Tableau complet : **`docs/assets_index.md`**.
Aucun pack n'est a retirer ; il restait **trois points a regler avant de VENDRE**
le jeu (rien ne bloque le developpement). *La liste s est allongee depuis
(Batareya, rvros, elthen, voix) : la liste a jour est au §11.* Les trois du 21/09 :

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
| Niveau du joueur + cartes en haut, profil en haut a droite | **FAIT**. **Change le 02/10** (co-auteur) : REGLAGES en haut a droite, PROFIL en 5e onglet, tete du mage en portrait par defaut (§13) | C |
| Fusionner bestiaire et galerie (onglets Sorts / Passifs / Bestiaire) | **FAIT** | C |
| Livre a pages (asset magic book), fleches gauche/droite | **FAIT** | C |
| Detail avec nb d'utilisations, monstres tues, ameliorations | **FAIT** (le crochet des ameliorations attend G) | C |
| Inconnu = grise | FAIT, **precise le 30/09** : trois etats (obtenu / obtenable grise / invisible) au grimoire, au deck et au bestiaire, compteur obtenues / visibles (§12) | — |
| Icones de sort partout | FAIT (45 feuilles propres) ; a re-choisir dans les packs d'icones quand ils arriveront | C |
| Police plus lisible, tout un peu plus grand | **FAIT** (la cause etait le contour de 6 px, pas la taille) | C |
| Vraies icones de menu (pas un steak) | **FAIT** | C |
| Titre stylise, nom "Time Wizard" | **FAIT** | C |
| Deck : ~~15~~ **12** cartes exactement, 0-3 passifs, ~~≤3 legendaires, ≤3 epiques~~ | **FAIT**, puis **remplace le 27/09** par la regle des 6 cartes differentes (plafonds de rarete retires, voir §11). **12 cartes depuis le 02/10** (§13) : la regle des 6 laisse alors passer 4 legendaires ou 6 epiques | K |
| Plusieurs onglets de deck | **FAIT** | K |
| Profil : succes par rarete au lieu des defis | **FAIT** (16 succes, XP deduite de la rarete) | L |
| Contour de couleur par rarete (cartes, monstres, succes) | **FAIT** (epaisseur croissante en plus de la couleur) | L |
| Cosmetiques : couleur du mage, chapeau, tour ; onglet dedie | **FAIT** (11 pieces, avec apercu). **Refait le 02/10** : garde-robe (chapeaux dessines en calque, apprentis provisoires, tours, robes, portraits, §13) | L |
| Fond de la barre de titre selon le niveau | **FAIT** (bois / argent / or / cristal). Le cristal (niveau 14) est **inatteignable** : le compte plafonne au niveau 12 (§13) | L |

### Campagne
| Demande | Etat | Chantier |
|---|---|---|
| Carte de campagne sur les fonds de combat, points jaunes, fleches d'acte | **FAIT** (5 actes, une page par acte) | E |
| 3 objectifs par niveau | ~~FAIT (3 par niveau, 4 types)~~ **FAUX au 27/09** : 3 types seulement, le meme trio sur les 21 niveaux. **FAIT le 28/09** : 16 controles, 3 objectifs coherents par niveau (§11). **Refait le 30/09** : 24 controles, objectifs lies au deck et aux monstres, classes par taux mesure, chacun debloque une carte (§12) | H |
| Histoire : prologue, 5 actes, plot twist de l'enfant | **FAIT** (docs/histoire.md) | D |
| Sequences visual novel entre les niveaux | **FAIT** (systeme + 9 scenes : prologue et acte 1) | D |
| Niveau 1 tutoriel, deck 9 cartes, 3 vagues ; niveau 2 en 4 vagues ; puis 6 | **PARTIEL** (niveau 2 raccourci ; le niveau 1 resiste, voir section 9) | H |
| Pool de cartes qui grandit de 3 par niveau | **ABANDONNE le 27/09** : incompatible avec la regle des 6 cartes differentes. Remplace par « chaque niveau fait decouvrir au moins une carte » (§9, §11) | H |
| Fin : deblocage du mode infini | ~~FAIT (`SaveData.campaign_cleared()`)~~ **Change le 29-30/09** : l Infini d un niveau s ouvre avec le niveau ; c est le nouvel onglet **Massacre** qui s ouvre a la fin de la campagne (§12) | — |

### Mode infini
| Demande | Etat | Chantier |
|---|---|---|
| Tous monstres et boss, fond change toutes les 6 vagues, mini-boss v3 / boss v6, fond qui pese sur le tirage | **FAIT** (5 mondes qui bouclent, 47-70 % de monstres du lieu). Depuis le 29/09 ce mode s appelle **Infini** ; le **Massacre** est un niveau a part, tous les monstres melanges sans monde (§12) | J |

### Sorts et passifs
| Demande | Etat | Chantier |
|---|---|---|
| Passifs hors du deck, actifs des le debut, 3 emplacements, echange au 4e | **FAIT**, **restreint le 30/09** : rien avant l acte 2, et les 3 emplacements n agissent qu en Infini et en Massacre, pas en campagne (§12) | F |
| Passif actif seulement au-dela d'une vitesse (ex. 140 %) | **FAIT** | F |
| Plus de passifs, avec raretes ; 20 % de passifs a la montee de niveau | **FAIT** (14 passifs ; **30** depuis le 02/10, dont 16 elementaires, §13) | F |
| Icone des passifs a cote de la barre de vitesse, a leur seuil | **FAIT** | F |
| Amelioration des cartes en combat (XP par lancer, choix parmi 3) | **FAIT** (8 lancers, 3 pactes, per-partie). ~~3 pactes~~ **remplaces le 29-30/09** : pool de voies propre a chaque sort, 3 tirees, legeres ou fortes, deux maturations (§12) ; **cinq maturations** depuis le 02/10 (§13) | G |
| Arbre qui attire les ennemis ; sort de stun ; arbre a zone de poison ; eau qui ralentit | **FAIT** (4 cartes, 3 verbes d effet neufs) | H |
| Element sur chaque sort de degats + resistances en % par monstre | **FAIT** (6 elements, table par monstre). **30/09** : ecarts accentues, appliques aussi aux effets, logo d element et type sur chaque sort (§12). **02/10** : **huit elements**, un par sort (§13) | B3 |

### Monstres
| Demande | Etat | Chantier |
|---|---|---|
| Monstres un peu plus grands | **FAIT** (2.1) | B1 |
| Apparition plus bas + fondu de 0,5 s | **FAIT** | B1 |
| Feu follet -> Planogo, vole par-dessus les murs, boule de poison 10 PV | **FAIT** | B1 |
| Nuee de rats -> Oiseau mirage, sprite qui ne tourne plus | **FAIT** | B1 |
| Boss a mecaniques originales (...) | **FAIT le 27/09** : mecaniques de monstres v3 et de boss v3, 23 monstres neufs, Briseur de tertres (§11) | I |
| Boss d'un acte devenant monstre courant ensuite | **FAIT le 27/09** : `EnemyDef.demoted_from`, echos du Gardien et de Chronos, vermine du trio, du Coagule et du Miroir (§11) | I |

### Combat
| Demande | Etat | Chantier |
|---|---|---|
| Vitesse non accelerable manuellement, +1 % toutes les 0,5 s | **FAIT** (bouton et barre supprimes) | B1 |
| Main a 6 cartes | FAIT | — |
| Quitter le combat depuis la pause | **FAIT** ; pause a onglets MAIN / DECK / VAGUE depuis le 02/10 (§13) | B1 |

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


---

## 4. Etat au 21 septembre, apres la premiere vague

**Livres et pousses** (commit `da704a2`) : chantiers A (licences et assets),
B1 (combat), C (menus et grimoire), D (histoire et visual novel).

**Ce qui bloque encore, et sur quoi** :
- Le **mage est un demon cornu** dans les scenes d histoire : aucun portrait
  humain sur le disque. Une ligne a changer quand les packs de personnages
  arrivent.
- `poison_ball` emprunte la feuille du slime teintee en vert : une vraie feuille
  d effet serait plus lisible.
- Le **bestiaire ne traduit pas** les champs `flying` et `projectile` ajoutes par
  B1. `flying` merite une ligne : le joueur doit comprendre avant de poser un mur
  inutile.
- `lvl_05` est a 97 % de victoires, au-dessus de la cible. Il etait deja le plus
  facile avant : a passer au `balance-tester`.

**Vague 2, a lancer** : F (passifs hors deck, seuils de vitesse, raretes),
K (regles de deck 15 cartes), B3 (elements et resistances), G (amelioration des
cartes en combat), H (nouveaux sorts et rebati des niveaux 1-2), L (profil,
succes par rarete, cosmetiques), E (carte de campagne sur les fonds d acte).

**Vague 3, quand les packs arrivent** : I (boss et monstres), J (mode infini).

---

## 5. Etat au 21 septembre, apres la deuxieme vague

**Livres** : K (regles de deck), L (profil, succes par rarete, cosmetiques),
E (carte de campagne sur les fonds d acte). F (passifs) et B3 (elements) etaient
encore en vol a la redaction de cette section.

**Arbitrage tranche — les decks de campagne** : K a signale que six niveaux sur
sept violaient la nouvelle regle des 15 cartes (jusqu a 20 cartes et 6 epiques
sur `lvl_06`). Ils ne plantaient rien parce que `GameController._build_deck()`
prend `level_def.exploration_deck` directement, sans passer par
`DeckRules.is_valid()` : seul le mode Massacre etait valide. La regle du testeur
vaut pourtant "que ce soit en campagne ou en massacre", donc les sept decks ont
ete ramenes a 15 cartes dans `tools/make_content.gd`, avec au plus 3 epiques.
Chaque coupe retire des exemplaires du fond commun (eclair arcanique, boule de
feu) pour garder l identite du niveau ; `lvl_06` et `lvl_07` perdent en plus des
epiques, parce que le plafond mord chez eux.

Le trou de verification est bouche par
`test_deck_rules._test_les_decks_de_campagne_suivent_la_regle()`, qui verifie le
contenu LIVRE et non seulement la fonction qui l evalue. Sabotage teste : une
carte ajoutee a `lvl_01` rend le harnais rouge.

**Chantiers restants** : G (amelioration des cartes en combat), H (nouveaux
sorts et rebati des niveaux 1-2), puis vague 3 (I, J) quand les packs arrivent.

### Defauts trouves EN CAPTURE pendant la vague 2, corriges

Tous invisibles aux tests : rien ne plantait, aucune assertion ne rougissait.
Chacun est desormais verrouille par un controle qui mord (sabotage verifie).

1. **La barre de VIE paraissait vide a 100 / 100.** `SpellBar` portait encore
   `tint_progress` bleu de son ancien role (la barre d incantation). La texture
   du pack etant rouge, la multiplication rendait un violet sombre. Verrouille
   par `_check_gauge_tints()` dans l AUDIT, parce qu un passage dans l editeur
   Godot reecrit ces valeurs en silence — c est deja arrive au fond du menu.
2. **Les succes deja merites n etaient jamais accordes.** `_check()` ne validait
   qu au FRANCHISSEMENT du seuil : les six succes ajoutes par le chantier L
   seraient restes inaccessibles a tout profil existant. Corrige par
   `ChallengeTracker.rattraper()` au demarrage.
3. **Les barres d avancement du profil etaient rouges**, la couleur de la vie.
   Un `modulate` dore ne suffisait pas (rouge x or = rouge orange) : la planche
   est reteintee couleur par couleur (`tools/assets/make_gold_bar.py`).
4. **L onglet des cosmetiques n etait que du texte** : on choisissait une robe
   sans voir sa couleur. Ajout de `UiTheme.cosmetic_preview()`. Le recadrage
   compte autant que la vignette : le mage occupe 58 px sur 192, donc la case
   entiere donnait une silhouette perdue dans le vide.
5. **Les etoiles acquises ne se distinguaient pas des vides** sur la carte de
   campagne (ecart mesure : 40 sur 255). Acquise = pleine, doree, grande ;
   vide = un creux sombre et reduit. Ecart porte a 76, et la FORME porte
   l information autant que la couleur.
6. **L ecran de victoire ressemblait a un journal d erreurs** : prefixes
   "[OK]" / "[   ]", aucune etoile, aucune trace de l XP de compte, moitie de
   page vide. Refait autour des etoiles. Le prefixe entre crochets a ete retire
   des trois ecrans qui le portaient.
7. **Le briefing ecrivait en corps 17** la ou le plancher du theme est 30, et
   coupait les noms de monstres au milieu d un mot.
8. **La rarete ne se voyait pas dans l ecran de deck** : elle ne teintait que le
   compteur "x1". Contour de rarete ajoute, comme dans le profil.

**Reverifie et toujours vrai** : le mage reste un demon cornu dans les scenes
d histoire. Les sept feuilles de cosmetique ajoutees depuis sont des vues de
DESSUS (on voit le sommet du chapeau, pas un visage) : aucune ne peut servir de
buste. Il faut un vrai portrait humain sur le disque.

---

## 6. Vague 2 terminee — etat au 21 septembre (commits `0406e0c`, `b35820a`)

**Les cinq chantiers sont livres** : F (passifs hors deck), B3 (elements et
resistances), K (regles de deck), L (profil et cosmetiques), E (carte de
campagne). Harnais 7/7 vert, sept niveaux dans la fenetre 60-95 %.

| Niveau | 1 | 2 | 3 | 4 | 5 | 6 | 7 | Massacre |
|---|---|---|---|---|---|---|---|---|
| Victoires | 83 % | 80 % | 83 % | 83 % | 87 % | 63 % | 63 % | vague 6,7 |

`ENEMY_SPEED_SCALE` est passe de 0,61 a 0,52 : la valeur d origine avait ete
calibree AVEC trois passifs offerts d office, et les sortir du deck faisait
tomber `lvl_06` a 0 victoire sur 30.

`lvl_03` gagnait 29 fois sur 30. La cause n etait ni la vitesse ni le budget des
vagues : cinq de ses dix monstres craignent le feu et un tiers du deck en etait,
donc le joueur ne pouvait pas se tromper d element. Corrige par le CONTENU du
niveau. Premiere tentative a deux cartes remplacees : 53 %, correction plus
grosse que le defaut ; ramenee a une seule.

**Reste a faire** :
- **G** — amelioration des cartes en combat.
- **H** — nouveaux sorts et rebati des niveaux 1-2.
- **Vague 3, bloquee sur les packs absents** : I (boss et monstres), J (mode
  infini). La liste des ~45 packs est en section 1.

**Dette connue, non bloquante** :
- Le **mage reste un demon cornu** dans les scenes d histoire. Reverifie : les
  sept feuilles de cosmetique sont des vues de DESSUS (on voit le sommet du
  chapeau, pas un visage), aucune ne peut servir de buste. Il faut un vrai
  portrait humain sur le disque.
- `poison_ball` emprunte la feuille du slime teintee en vert.
- Trois points de licence a regler avant une vente (section 1).


---

## 7. Mesure du 25 septembre : les boss se repetent

Constat chiffre sur le contenu genere, pas une impression :

| Niveau | Mini-boss | Boss |
|---|---|---|
| lvl_01 | — | — (tutoriel, voulu) |
| lvl_02 | `warden` | `chronos` |
| lvl_03 | `warden` | `chronos` |
| lvl_04 | `warden` | `gravecaller` |
| lvl_05 | `warden` | `forge_colossus` |
| lvl_06 | `warden` | `chronos` |
| lvl_07 | `warden` | `chronos` |

**Sur six niveaux a boss, le joueur affronte DEUX adversaires uniques** : le meme
Gardien six fois, et Chronos quatre fois — dont le premier et le dernier niveau
de la campagne. C est exactement ce que le testeur voulait eviter en demandant
des boss a mecaniques originales.

**Le manque de monstres n est PAS la cause.** Quatre P10 existent (`chronos`,
`gravecaller`, `forge_colossus`, `wraith_lord`) et plusieurs P3-P6 feraient des
mini-boss (`warden`, `totem_guardian`, `glutton`, `behemoth`, `void_knight`,
`berserker`, `golem`). Il y a de quoi donner un adversaire different a chaque
niveau sans rien creer.

**La cause est une compression.** `docs/histoire.md` decrit 21 niveaux sur
5 actes ; le jeu en a 7. En repliant 21 en 7, chaque niveau a herite du meme
gardien d acte. Le document prescrit d ailleurs l inverse de ce qui est
genere : le Gardien doit mourir en `lvl_04` (l Enfant le reconnait, la scene en
depend), et `chronos` doit devenir un monstre ORDINAIRE a l acte V.

**A trancher** : soit on redistribue les boss sur les 7 niveaux existants, soit
on ouvre les niveaux manquants. La premiere option est faisable aujourd hui, la
seconde demande les packs absents. Le fichier a modifier est
`tools/make_content.gd`, occupe par un chantier en cours au moment de ce constat.


### Boss redistribues — mesure du 25 septembre corrigee

Onze adversaires uniques au lieu de deux :

| Niveau | Mini-boss | Boss |
|---|---|---|
| lvl_01 | — | — (tutoriel) |
| lvl_02 | Corniste | Gardien-totem |
| lvl_03 | Pretre goule | Behemoth |
| lvl_04 | Ombre | L Ensevelisseur |
| lvl_05 | Gardien-totem | Colosse des Forges |
| lvl_06 | Chevalier du vide | Seigneur Spectre |
| lvl_07 | Glouton | **Chronos** |

La seule repetition restante est **voulue** : Chronos ferme `lvl_06` et `lvl_07`,
c est la boucle narrative de `docs/histoire.md` — "l huissier du niveau 1
revient". `test_bosses` l autorise NOMMEMENT, donc une deuxieme repetition, elle,
fait rougir le harnais.

Le **Gardien de la foret** ne reapparait plus apres `lvl_04`, ou l histoire le
fait mourir : "il s effondre en un tas de bois mort", et la plaque de metal dans
sa poitrine lance toute l intrigue. Le voir vivant ensuite contredisait la scene
que le joueur venait de lire.

Deux corrections faites en cours de route, toutes deux attrapees par un test :
1. le Pretre goule menait `lvl_03` ET `lvl_04` — collision creee par ma propre
   redistribution, rattrapee par le test que je venais d ecrire ;
2. remplacer le Gardien (94 PV) par le Corniste (18 PV) a vide la vague 4 de
   `lvl_02` et cree un saut de x3,1 vers la vague 5. Le garde-fou
   d equilibrage l a vu ("294 PV apres 94"). Le poids est rendu par le NOMBRE,
   ce qui colle au role du Corniste : il presse, il ne cogne pas.

**Taux mesures apres coup** : 70 / 83 / 77 / 77 / 77 / 80 / 93 %. Les sept sont
dans la fenetre, mais la courbe est PLATE et `lvl_07` est le plus facile des
sept. A regarder : un dernier niveau qui se gagne 9 fois sur 10 ne cloture pas
une campagne.


---

## 8. Mode infini et mini-boss — 25 septembre

*(30/09 : ce mode par niveau s appelle desormais **Infini** ; le nom Massacre designe un
niveau a part, sans monde, voir §12. Ce qui suit decrit l Infini.)*

**Le Massacre traverse cinq mondes.** Le fond change toutes les 6 vagues, un
mini-boss tous les 3 tours, un boss tous les 6, et le lieu pese sur le tirage
(47 a 70 % de monstres de la famille locale). Apres le cinquieme monde on boucle
SANS remettre le budget a zero : le deuxieme passage dans le Monde volant envoie
les memes creatures avec trois fois plus de points.

**Quatre mini-boss crees**, un par monde : Ecumeur du ciel (volant, leger et
rapide), Gardien d ossements (lourd, immunise au poison), Seigneur de braise
(resiste au feu, craint le givre), Totem ancien (promotion du Gardien-totem).
Le jeu n en avait qu UN — c etait le meme Gardien a chaque palier de chaque
monde, exactement le defaut corrige pour la campagne.

**Le piege qui a failli passer** : les CREER ne suffisait pas.
`WaveSpawner.build_membership()` deduit le monde d un monstre de sa DENSITE dans
les vagues ECRITES ; les quatre nouveaux n apparaissaient dans aucune vague,
donc ils n appartenaient a aucun monde et le mode infini ne les proposait
jamais. Une sonde l a montre : invisibles malgre leur existence, et l AUDIT ne
voyait rien. Chacun est desormais place une fois dans une vague de son acte, et
`test_wave_budget` verifie l APPARTENANCE et le TIRAGE REEL, pas seulement le
catalogue.

**Deux corrections attrapees par le garde-fou d equilibrage**, pas par moi :
1. l Ecumeur en vague 5 de `lvl_02` creait un saut de plus de x2 ("428 PV apres
   182") — deplace en vague 6, qui l absorbe ;
2. l Ombre en mini-boss de `lvl_04` pesait 16 PV la ou le Gardien en pesait 140 :
   la vague 3 devenait plus legere que la vague 2 et le niveau tombait a 57-63 %.
   Remplacee par le Gardien d ossements (165 PV).

**Dernier niveau renforce** : `lvl_07` se gagnait 93 fois sur 100, le plus facile
des sept. Mesure du poids brut : la courbe n est pas monotone (recul de 33 % au
niveau 3, de 43 % au niveau 6) et le multiplicateur de difficulte etait plat
partout (1,20-1,29), donc il ne compensait rien. Les vagues normales passent de
1,25-1,30 a 1,40-1,45.

**A surveiller** : `lvl_04` est le niveau le plus VARIABLE du banc — trois
mesures ont donne 57 %, 63 % et 73 %. Sa moyenne est proche du plancher de 60 %.
Ne pas le regler sur une seule mesure.


---

## 9. Structure des premiers niveaux — 25 septembre

~~**Le pool de cartes GRANDIT** desormais sans jamais reculer : 6, 10, 10, 10, 10,
11, 11 cartes differentes du niveau 1 au niveau 7.~~ **Corrige le 28/09 — ce principe
n a plus cours.** La regle du co-auteur du 27/09 limite un deck a **6 cartes
differentes** (15 cartes, exemplaires 4/3/2/1), en campagne comme en deck construit :
un pool qui grandit jusqu a 11 ids ne peut plus exister. Les 20 decks qui depassaient
6 ids ont ete recomposes, et le principe devient **« chaque niveau fait decouvrir au
moins une carte qu aucun deck joue avant lui n avait montree »**, verifie dans l ordre
de jeu par `test_deck_rules`. La variete vient du CHOIX des six cartes selon le niveau,
des sorts choisis en combat et des cartes gagnees en recompense. Aucun test ne
verifiait l ancien principe.

Ce qui reste vrai : les cartes collent au LIEU, elles ne remplissent pas : aux Forges, Golem, Colosse
et Behemoth sont immunises au ralentissement, donc le controle n y sert a rien
et la Pluie de givre y apporte des DEGATS de givre que le Colosse craint. A la
Cour brisee, le Chevalier du vide avale l arcane et le Seigneur Spectre se tient
hors de portee, d ou le Totem qui attire et la Nappe qui rend du terrain.

**Le niveau 2 passe de 7 a 6 vagues.** On retire la vague 2 (86 PV), doublon de
la vague 1 (94 PV) : deux vagues d ouverture de meme poids n apprennent pas deux
choses differentes.

**Le niveau 1 RESISTE au raccourcissement, et c est mesure.** Le testeur
demandait un tutoriel en 3 vagues ; il en dure 6 (173 s avant le boss). Deux
essais ont ete refuses par le garde-fou d equilibrage :
- a quatre vagues (w1, w2, mini, boss) : « 356 PV apres 165 » ;
- a cinq (sans w5) : le meme.

Chaque vague retiree est un PALIER en moins, et le boss se retrouve a plus du
double de ce qui le precede — c est-a-dire un mur, exactement ce qu un tutoriel
ne doit pas etre. Le raccourcir demande d alleger AUSSI le boss, donc de refaire
la courbe du niveau entiere. C est un chantier a part.

**Note du testeur (25/09)** : l equilibrage n est pas la priorite pour l instant,
le jeu va encore beaucoup changer. Les chiffres du banc de cette section sont
donc des CONSTATS, pas des cibles atteintes. Le banc et ses garde-fous restent
en place pour attraper les ruptures franches (un saut de PV qui double, une
vague qui vide la barre de vie d un coup).


---

## 10. Boss a mecaniques et tirage du mode infini — 26 septembre

**Trois mecaniques de plus**, chacune changeant une question differente :
- **Le Coagule** (`lvl_02`) se releve une fois a 40 % de ses PV — il change le
  sens du mot "tuer" ;
- **Le Reliquaire** (`lvl_03`) ignore ses 6 premiers coups QUELLE QUE SOIT leur
  puissance — il change la monnaie : on paie en coups, pas en points ;
- **Le Miroir de Forge** (`lvl_05`) leve une garde qui renvoie 45 % des degats —
  il change le MOMENT du lancement.

**Le defaut le plus grave de la journee, et aucun audit ne pouvait le voir.**
`WaveBudget.pick_boss()` rendait le PREMIER boss dont le monde correspondait, et
le pool arrive dans l ordre de lecture du disque, donc alphabetique. Des qu un
monde comptait deux boss du meme genre, **le second n etait JAMAIS tire** en
Massacre. Releve sur 300 vagues : quatre sur douze etaient injoignables, dont le
Gardien, mini-boss du tout premier niveau.

Le monstre existe, il est rattache a un monde, son contenu est ecrit, et il ne
sort jamais. Rien ne plante, rien ne rougit. La correction tient en trois
lignes — tirer au hasard parmi les candidats du monde — et `test_wave_budget`
verifie desormais que chaque boss rattache SORT REELLEMENT, en jouant
720 vagues. Sabotage verifie : 4 echecs nommes.

**Ecarte, et c est le bon choix** : le "renard qui dort". La mecanique est
triviale, mais son interet tient a ce que le joueur DECIDE quand commencer —
donc a un geste de reveil, qui passe par le ciblage. Livree sans ce geste, elle
se reduit a "un monstre qui demarre en retard", ce qui n est pas une question
posee au joueur.
*(28/09 : un AUTRE renard est livre, `sleepy_fox` — il s arrete 2 s pour dormir et,
pendant ce temps, aucun sort n est jouable. La question posee au joueur est « lancer
avant qu il s endorme », pas « quand le reveiller ».)*


---

## 11. Etat au 28 septembre, apres trois vagues de chantiers (27-28/09)

Reference : le retour du co-auteur du 27/09 (regle de deck, objectifs, Riviere,
monstres, terrain permanent, apprentis, boss, packs). Chaque chantier a tourne dans
son worktree git ; seul l orchestrateur a fusionne dans `main`, une branche a la fois,
en relancant le harnais. Le detail et les chiffres sont dans les messages des commits de fusion
(`git log --first-parent main`) ; cette section ne dit que l etat.

### Fait

| Demande | Livre |
|---|---|
| Regle de deck : 6 cartes differentes | `DeckRules.MAX_DISTINCT = 6` ; plafonds de rarete retires (la regle borne deja a 3 legendaires, 4 epiques) ; `is_valid()` verifie enfin les exemplaires ; 20 decks de campagne recomposes ; deck sauvegarde hors regle garde et explique, refuse en Massacre |
| Trois objectifs par niveau, coherents | *(refait le 30/09, §12)* Moteur a 16 controles parametres, libelle genere, AUDIT impossible/gratuit ; 63 objectifs sur 21 niveaux, 15 controles differents, chacun appuye sur le contenu du niveau ; exemples du co-auteur presents ; progression suivie EN COMBAT (bandeau, echec annonce) |
| Riviere (legendaire) | ligne d eau, un pont au hasard qui garde toujours un chemin, une seule a la fois, volants et projectiles passent dessus |
| Sorts de terrain permanents | `duration <= 0` = fin du combat, 6 objets au plus (le plus ancien cede), garantie de chemin avant et apres la pose (Mur et Bastion compris) ; Autel d appel, Ronces, Fosse ; Totem a 3500 PV (mesure ; **800 PV depuis le 02/10**, essai du co-auteur, §13), Semis permanent qui n attire plus |
| Monstres (§0.4 du plan) | mecaniques v3 : vies multiples depuis le haut, renaissance differee avec marque au sol (slime fantome -> squelette), reanimateur, laser de riposte, sommeil qui coupe la magie, zigzag / rebond / sauts |
| Boss (§0.7) | mecaniques v3 : Horloger, Jumeaux, Cameleon, Voleur de sorts, Devoreur-invocateur, Miroir du mage, chacune avec sa garantie de fin ; Briseur de tertres (epargne l eau) |
| Packs de monstres (§0.8) | 23 monstres et boss neufs : trio de mages, Mecha-golem, slimes geants (colossal -> enorme -> moyen), renard dormeur, cacodemon, Malyk le Seigneur demon (Duelyst), Fossoyeur, Horloger, Greffier, Cameleon ; les tetes manquantes des actes 3 a 5 |
| Anciens boss en vermine | champ `EnemyDef.demoted_from` ; echos du Gardien et de Chronos a l acte 5 ; vermine du trio, du Coagule et du Miroir |
| Apprentis du mage | `RewardKind.CHARACTER` data-driven ; Apprentie d azur au niveau de compte 9 ; robe et chapeau mis de cote ; la Sorciere des fosses change de silhouette |
| UI-006, UI-007 | glisser-deposer au deck avec raison de refus ; medaillon du monstre signature sur chaque niveau ; acte IV en eventail ; etoiles vides lisibles sur tous les fonds ; defilement du deck au doigt |
| Copies petrifiees | la petrification et le vol visent un EXEMPLAIRE (carte + position), plus toutes les copies d une carte |

### Equilibrage (BAL-002, 28/09) : ruptures franches corrigees, reglage fin au testeur

- **Corrige** : les quatre seigneurs de l acte 4 descendaient dans des vagues ordinaires
  avec leurs PV de boss ; ils ont des echos (`demoted_from`). `lvl_13` 44 -> 68 %,
  `lvl_16` 48 -> 78 % (series cumulees). Garde-fou : aucune tete en vague ordinaire,
  six exceptions nommees. **Tutoriel `lvl_01` en 3 vagues** (106 -> 189 -> 356 PV,
  ~96 s au lieu de 173, 98 %). Le banc accuse desormais la vraie source des coups.
  Total : 571 victoires sur 630, aucun niveau sous 60 %.
- **A trancher** (leviers chiffres dans le message de fusion BAL-002) : le **Massacre est
  beaucoup trop facile** (vague 17 en moyenne, repere 4-8 ; *c etait l Infini d un niveau,
  le Massacre du 30/09 est un autre mode, mesure a 10,4 vagues, voir §12*) ; une douzaine de niveaux a
  29-30/30 (PV x1,5 + espacement x0,7 les ramene vers 82-88 %) ; l arbre appat a 3500 PV
  quasi automatique dans `lvl_04` (~800 propose) ; Boule de feu a 26 reels = +14 points
  de victoire sur les niveaux durs.

### Reste — actions du testeur (l assistant ne peut pas les faire)

*(Liste reprise et completee au §12, etat au 30/09.)*

1. **URGENT : licence Batareya** — 42 des 60 icones de cartes en dependent
   (`docs/assets_index.md` §1.5).
2. `python tools/assets/fetch_craftpix.py login`, pour que l assistant recupere le pack
   **Free Undead Tileset** (les sorts de terrain utilisent Ancient Ruins en attendant).
3. **Witches Pack complet** (itch.io, 9e0) : les 5 autres apprenties.
4. Archives completes du **renard** et du **cacodemon** (elthen) : branches sur des PNG
   nus, licence a confirmer.
5. **Licence rvros** du `Slime.zip` (slimes geants).
6. Packs absents demandes pour des boss : **frost-guardian, c3-3dobject, sci-fi-9**.
7. **L image du necromancien** citee par le co-auteur n a jamais ete transmise.
8. **ART-004** (taille des monstres) et **AUDIO-003** (volumes) : a juger a l oeil et a
   l oreille.
9. Avant toute vente : contribution a BDragon1727, courriel a John Carroll (voix),
   origine de FreeSFX.

### Reste — limites connues signalees par les chantiers

- ~~Le **Voleur de sorts** ne retient que la carte volee~~ : il retient SON exemplaire
  (id stable de la Tenue) depuis `339dd41`.
- ~~La **bande d objectifs** chevauche la zone d apparition~~ : elle vit en bas a droite,
  entre la tour et le bord, sur une plaque sombre ; son emprise et son contraste
  sont testes (`test_objective_progress`).
- Le **Slime colossal** est une feuille agrandie a gros pixels : a juger en jeu.
- Les quatre nouvelles cartes de terrain ne sont dans aucun deck de campagne *(30/09 :
  toujours vrai pour les decks, mais elles s obtiennent comme cartes nouvelles ou
  recompenses d objectif, voir §12)*.
- Regles depuis : le niveau 1 est en 3 vagues (BAL-002) ; le mage a un vrai portrait
  humain dans les scenes d histoire depuis le 26/09 (commit `b5535d7`).

### Ce que ces vagues ont appris sur le travail en parallele

Une fusion SANS conflit n est pas une fusion sans defaut : git a garde deux
`refusal_reason` homonymes posees par deux chantiers, et un recalcul de teinte par
image aurait repeint en gris le rouge des cartes volees. Les worktrees peuvent partir
d une base ancienne : les fichiers generes se regenerent apres fusion, ils ne se
resolvent pas a la main. Detail dans la memoire projet (`gotchas.md`).


---

## 12. Etat au 30 septembre, apres les retours du co-auteur du 29 et du 30

Deux retours : celui du 29/09 (vague 5 : modes, progression des cartes, passifs,
resistances, logos, ameliorations, objectifs) et les retouches du 30/09 apres test
(passifs hors campagne, Massacre en fin de campagne, collections honnetes, communes en
campagne, objectifs « mal realises, pas encore lies aux cartes »). Chantiers M (modes),
P (progression), O (objectifs), R (resistances et logos), U (ameliorations), W7 (bot du
banc et contenu par niveau), puis lisibilite. Fusionnes dans `main` le 29 et le 30/09 par
l orchestrateur, une branche a la fois. Les chiffres sont dans les messages des commits
de branche (`git log <fusion>^2`) ; les raisons dans la memoire projet
(`decisions.md`, DEC-028 a DEC-037).

### Fait

| Demande | Livre |
|---|---|
| Modes | `Mode { EXPLORATION, INFINITE, MASSACRE }`. **Exploration** = la campagne. **Infini** par niveau (l ancien « Massacre » par niveau, meme valeur enregistree), ouvert des que le niveau l est, a travers les 5 mondes. **Massacre** = nouvel onglet : niveau fabrique (aucun .tres), monstres de TOUS les niveaux sans monde, boss de tout le jeu, fond fixe du Seuil divin, deck du joueur ; ouvert seulement **campagne finie** (l onglet reste visible et dit ce qui l ouvre). Records separes par mode |
| Cartes a la montee de niveau | Pool de campagne = deck du niveau + **3 cartes nouvelles** (`LevelDef.levelup_cards`) + cartes **debloquees par les objectifs reussis** (`objective_rewards`, rang 1 / 2 / 3 -> rare / epique / legendaire). Hors campagne : les cartes obtenues. Une carte est **obtenue** la premiere fois qu on la prend en combat. **Supprimes** : recompenses de boss d office et `legendary_reward` (« 3/3 objectifs ») ; les legendaires deja gagnees restent |
| Visibilite | Cartes : obtenue (lisible) / obtenable (grisee, « ou l obtenir ») / invisible. Bestiaire : rencontre / a rencontrer (grise) / invisible, plus d ombres « ??? ». Compteurs obtenues / VISIBLES, les memes au grimoire, au deck, en haut du menu, au profil et dans les succes |
| Communes | Proposees en campagne : commune 40 / rare 40 / epique 15 / legendaire 5. Hors campagne, la table 80/15/5 reste |
| Passifs | **Rien avant l acte 2**. 3 emplacements equipables a l ecran de deck, **actifs seulement en Infini et en Massacre**, pas en campagne (combat mesure). Table de rarete propre : les 4 passifs communs sont enfin proposes |
| Objectifs (moteur) | **24 cles** : 8 neuves (`card_casts`, `no_card`, `win_above_speed`, `kill_type_one_cast`, `kill_type_with_card`, `no_hit_from`, `hit_from`, `enemy_travel`). Chaque mort est **attribuee au lancer** qui l a causee (zones, meteores, allies poses compris) |
| Objectifs (contenu) | 3 objectifs par niveau, **lies au deck et aux monstres** (deux sur trois au moins), **classes par difficulte** ; classement MESURE (60 parties par objectif, bot qui le vise) et verrouille par `test_level_progression.MESURES` ; tout le catalogue est obtenable en campagne |
| Resistances | **Accentuees** par une regle unique (`EnemyDef.accentuate` : 0,5 -> 0,30 ; 1,2 -> 1,58 ; plafond x2) et **appliquees aux effets** (`control_factor` : ralentir, etourdir, repousser, aspirer, attirer, volte-face, vulnerabilite...). Defaut corrige : le Champ de givre ne faisait AUCUN degat a un monstre immunise au ralentissement (Chronos, golem, Behemoth). Berserker retouche (givre -> poison) |
| Logos | Logo d element (forme + couleur + image, formes toutes differentes) sur la carte ET devant chaque pourcentage du bestiaire ; type de chaque sort (`SpellCard.spell_type()`) ; sceau de type aussi a l ecran de deck |
| Ameliorations | Pool de voies **propre a chaque sort** (4 a 12, derive de ses effets), **3 tirees** a chaque maturation, **legeres** (+10 %, sans prix) ou **fortes** (+30 % contre -15 % ailleurs), **deux maturations** (8 puis 24 lancers ; **cinq** depuis le 02/10, §13) |
| Banc | Bot **AutoPick** qui choisit comme un joueur raisonnable et vise hors de l aura des totems ; **rage des Berserkers** bornee dans le temps (elle dependait des images par seconde) ; **Chronos du tutoriel** allege (vague `w1_boss` a difficulte 0,6, 87 abattus sur 87) ; aucun niveau sous 60 % |
| Lisibilite | Encres de rarete du theme partout (l AUDIT refuse une couleur de rarete ecrite en dur) ; les **4 encres >= 4,5:1** sur le papier creme, la page du grimoire et le papier de leur carte ; bandeau des passifs de l ecran de deck entier ; compteurs du profil alignes |

### Ce qui etait faux dans ce document et a ete corrige

- §2 « Fin : deblocage du mode infini » : l Infini ne se debloque plus en fin de
  campagne ; c est le Massacre.
- §2 et §8 : le « Massacre a travers cinq mondes » est l **Infini** ; le Massacre
  actuel n a pas de monde.
- §2 « Passifs actifs des le debut » : plus en campagne.
- §2 « 3 pactes » d amelioration : remplaces par un pool par sort.
- §11 « Massacre vague 17 » : mesure de l ancien mode par niveau.
- §11 « cartes de terrain dans aucun deck » : vrai pour les decks, mais elles
  s obtiennent desormais (cartes nouvelles ou recompenses de lvl_03, 04, 06, 07, 10,
  11, 18, 21).

### Equilibrage : leviers mesures mais NON appliques (decision du co-auteur)

- Plusieurs niveaux **au-dessus de 95 %** : ils ne demandent plus de choix.
- **`lvl_13`** : saut de PV **x2,28** d une vague a l autre (`w13_4` : 879 PV apres 385).
  **Corrige le 03/10** (w13_4 a x1,97, regle du saut verrouillee sur lvl_13, §13).
- La regle « jamais plus de x2 entre deux vagues » n est verifiee par `test_balance`
  que sur `lvl_01` et `lvl_02`. Mesure des .tres le 30/09 : **10 niveaux** la depassent
  (lvl_03 x2,41, lvl_04, 06, 07, 10, lvl_12 x2,61, lvl_13, 14, 15, 17).
- **Massacre** : 10,4 vagues au banc complet (repere 4-8), et le chiffre depend du
  profil (cartes obtenues) : 7,7 vagues lance seul sur un profil neuf.
- Anciens leviers du 28/09 encore ouverts : arbre appat a 3500 PV dans `lvl_04`
  (**800 PV depuis le 02/10**, essai du co-auteur), Boule de feu a 26 reels.

Le banc n est pas deterministe d un processus a l autre : 60 a 90 parties pour
departager deux reglages proches (`--parties=60`). **Devenu faux le 02/10** : le banc
est deterministe (`RunState.world_rng`, §13) ; les 60 a 90 parties restent necessaires
a cause de la variance entre graines.

### Reste — actions du testeur (l assistant ne peut pas les faire)

1. **URGENT : licence Batareya** — 42 des 60 icones de cartes en dependent.
2. `python tools/assets/fetch_craftpix.py login` : l assistant recupere ensuite le
   pack **Free Undead Tileset** (les sorts de terrain utilisent Ancient Ruins).
3. **Witches Pack complet** (itch.io) : les 5 autres apprenties.
4. Archives completes du **renard** et du **cacodemon** (elthen) : branches sur des PNG
   nus, licence a confirmer.
5. **Licence rvros** du `Slime.zip` (slimes geants).
6. Packs absents demandes pour des boss : **frost-guardian, c3-3dobject, sci-fi-9**.
7. **L image du necromancien** citee par le co-auteur n a jamais ete transmise.
8. **ART-004** (taille des monstres) et **AUDIO-003** (volumes) : a l oeil et a l oreille.
9. Avant toute vente : contribution a **BDragon1727**, courriel a **John Carroll** (voix),
   origine de **FreeSFX**.
10. Arreter les **4 processus Godot orphelins** signales le 30/09 : un
    banc lance a cote d eux mesure une machine chargee.

### Reste — decisions pour le co-auteur

1. Les niveaux au-dessus de 95 %, `lvl_13` et son saut x2,28, la regle x2 depassee sur
   10 niveaux (ci-dessus).
2. Le **Massacre** : sa difficulte, et le fait qu il depende des cartes obtenues.
3. Un boss croise en **Infini** passe directement a « rencontre » au bestiaire, avant
   que la campagne ne l ait montre. Voulu ?
4. **11 legendaires pour 21 niveaux** : la recompense de l objectif le plus dur revient
   forcement sur plusieurs niveaux (elle entre alors dans le pool d un autre niveau).
5. La **Riviere** ne murit presque jamais : une seule a la fois, peu lancee, et son
   pool n a que 4 voies (vitesse, pioche au lancement).

### Reste — limites connues

- ~~**Le banc des objectifs n a pas d outil permanent**~~ : **leve le 02/10**,
  `tools/objective_bench.tscn` (§13).
- Le **Slime colossal** est une feuille agrandie a gros pixels : a juger en jeu.
- Niveaux sans boss (`lvl_08`, `17`, `18`, `20`) et sans mini-boss (`lvl_16`) : voulu.

---

## 13. Etat au 3 octobre, apres la vague 8 (retour du co-auteur du 02/10)

Retour du co-auteur du 02/10 (plan « vague 8 ») : regle du livre de sorts, vraies
nouveautes par niveau, garde-robe, outils du testeur, menus, huit elements, combat,
sorts et decks de 12, incantation plus longue, defilement au doigt ; puis recalibrage
des 63 objectifs et correction du banc. Quatorze fusions dans `main` les 02 et 03/10,
une branche a la fois, harnais vert a chaque fois. Les chiffres sont dans les messages
des commits de branche (`git log <fusion>^2`) ; les raisons dans la memoire projet
(`decisions.md`, DEC-038 a DEC-053) et dans `tools/README_equilibrage.md`.

### Fait

| Demande | Livre |
|---|---|
| Livre de sorts | Une carte est **obtenue** si elle est dans le deck d un niveau OUVERT ou si le joueur l a **prise** en combat (brulee : non), rien d autre. Deduit a chaque lecture (`SaveData.cards_owned_by_decks`) : profil neuf = deck de lvl_01, sans migration. `copies_in_starter` ne donne plus rien |
| Vraies nouveautes | Dans l ordre de jeu, aucune carte nouvelle ni recompense n est deja possedee (avant : 33 et 19 l etaient). 42 sorts a decouvrir, 84 reprises jamais sur deux niveaux de suite. Deux defis du co-auteur places (sous 120 %, distance du Serpent) |
| Banc | **Deterministe** : tout le hasard du monde suit la graine (`RunState.world_rng`). **Banc des objectifs permanent** (`tools/objective_bench.tscn`) : bot oriente vers l objectif, une politique par cle, ligne prete pour `MESURES`. Motif de deplacement **spirale** (porte par aucun monstre livre) |
| Garde-robe | 12 **chapeaux dessines** poses en calque image par image, cumulables avec la robe ; apprentis **provisoires** (ecuyer, fee) et teintes par apprenti ; apprenti **x1,5** ; 7 tours ; 4 robes ; 10 portraits ; tete du mage en portrait par defaut. Tout tient dans les 12 niveaux de compte atteignables |
| Atelier du testeur | Surcharges du contenu actives en mode testeur seulement, editeur (sorts, monstres, niveaux, vagues de campagne, resistances, element), onglet **TEST** (vraie partie), **document de changement** (COPIER + JSON), `tools/apply_changes.py` (rapport + diff sur les generateurs). Voir `docs/outil_donnees.md` |
| Menus | REGLAGES en haut a droite, PROFIL en 5e onglet ; **pause a onglets** MAIN / DECK / VAGUE (temps d incantation reel, fiche des monstres au toucher) ; **Epuration au choix** (0 a 2 cartes) dans un parcours du deck ; un passif se lit avant de s equiper ; plus de cases « vide » |
| Elements | **Huit** : Feu, Eau, Nature, Vent, Foudre, Glace, Arcanique, Poison. Un element par sort ; resistances des 86 monstres remappees par une regle ; objets de terrain d un element ; **16 passifs elementaires** ; logos dans tous les textes de carte |
| Combat | **Bruler** = viser ou l on veut (sans incantation, partie figee pendant la visee) ; **MEDITER** (+1 XP a chaque carte de la main) ; echange de passif sur les trois cartes, refus possible ; **cinq maturations** (8, 24, 48, 80, 120 lancers) ; **vague qui traine** (la suivante part quand des monstres calent) ; **auras dissipables** et pat d aura ; **devoreurs** plus forts a chaque proie ; un seul etat de partie figee |
| Sorts du co-auteur | **Dard venimeux** (commune, poison), **Elan du temps** (rare, +30 de vitesse), Concentration = +1 XP a la main, Nappe montante rare, Intuition epique pioche 2, Totem 800 PV, Marque 8 s, Semis rayon 300, Rappel 1 carte, Pluie de meteorites et Registre des marees plus lents. **Decks de 12 cartes** |
| Incantation | `CAST_TIME_SCALE` **x1,9** (x1,5 avant). Le premier essai a x2,25 faisait tomber cinq niveaux sous 60 % |
| Defilement | Tous les ecrans qui defilent suivent le doigt (`TouchScroll`) ; MODE TESTEUR et ATELIER en haut des reglages. Teste par de vrais evenements tactiles sur 4 formats d ecran |
| Objectifs | Les 63 **re-mesures** (60 parties chacun) et recales : 12 niveaux sur 21 etaient hors regle, les 21 sont conformes |
| Banc (memoire) | Les bancs liberent a chaque image comme le moteur (plantage de lvl_21 corrige) ; **vrai bug de jeu** trouve au passage : l invocateur (Sceau de Tombol) n invoquait plus apres la mort d un premier sbire |

### Ce qui etait faux dans ce document et a ete corrige

- §2 « profil en haut a droite » : ce sont les REGLAGES ; le profil est un onglet.
- §2 « Deck : 15 cartes » : 12 depuis le 02/10.
- §2 « 6 elements », « 14 passifs », « deux maturations » : huit elements, 30 passifs,
  cinq maturations.
- §2 « bois / argent / or / cristal » : le cristal est inatteignable (compte plafonne
  au niveau 12).
- §11 et §12 « Totem a 3500 PV » : 800 PV (essai du co-auteur).
- §12 « le banc n est pas deterministe » : il l est depuis le 02/10.
- §12 « `lvl_13` et son saut x2,28 » : corrige (w13_4 a x1,97, verrouille par test).
- §12 « le banc des objectifs n a pas d outil permanent » : il en a un.

### Equilibrage au 03/10

| Mesure | Valeur |
|---|---|
| Victoires, banc complet x1,9 (21 x 60) | **1135 / 1260** ; les plus bas lvl_13 37, lvl_18 37, lvl_11 38 (repere : 36) |
| Autres valeurs essayees | 1,5 : 1192 ; 1,8 : 1146 ; 1,95 : 1115 ; 2,0 : 1106 ; 2,25 : 987 |
| Temps passe a incanter | 77 a 97 % sur 19 niveaux (repere < 60 %) ; 62-86 % a x1,5 |
| Massacre | vague **12,1** (repere 4-8) |
| Objectifs | 21 niveaux conformes ; rangs 3 les plus durs a 3-4 / 60 (lvl_07, 08, 09, 15, 19) |

### Reste — actions du testeur (l assistant ne peut pas les faire)

1. **URGENT : licence Batareya** (icones de cartes ; aucune neuve n en vient depuis le
   27/09, les icones de la vague 8 sont toutes craftpix).
2. `python tools/assets/fetch_craftpix.py login` : pack **Free Undead Tileset**.
3. **Witches Pack complet** : les vraies apprenties (l ecuyer et la fee sont provisoires).
4. Archives completes du **renard** et du **cacodemon** (elthen, PNG nus) ; licence de
   la **fee** (`Fairy.zip` : trois PNG, ni licence ni auteur).
5. **Licence rvros** du `Slime.zip`.
6. Packs absents pour des boss : **frost-guardian, c3-3dobject, sci-fi-9**.
7. **L image du necromancien** citee par le co-auteur : jamais transmise.
8. **ART-004** (taille des monstres), **AUDIO-003** (volumes) : a l oeil et a l oreille.
9. Avant toute vente : contribution a **BDragon1727**, courriel a **John Carroll**,
   origine de **FreeSFX**.

### Reste — decisions pour le co-auteur

1. **Incantation** : x1,9 ou x1,95 ? x1,95 passe le repere de justesse (lvl_11 36 / 60,
   lvl_20 perd 9 parties). Et le temps passe a incanter (77-97 %) : garder le repere de
   60 % ou l abandonner, puisque c est la demande ?
2. **Compte plafonne au niveau 12** (seuls les succes donnent de l XP) : la banniere
   cristal du niveau 14 est inatteignable.
3. **Decks de 12** : jusqu a 4 legendaires ou 6 epiques possibles ; un plafond de
   rarete doit-il revenir ?
4. **Rappel d ossements** et **Epuration** classes Poison faute d element evident.
5. Un boss croise en **Infini** passe directement a « rencontre » au bestiaire.
6. Niveaux **au-dessus de 95 %** ; regle du saut x2 encore depassee sur 9 niveaux
   (mesure du 30/09) ; Massacre a 12,1 vagues.
7. **Rangs 3 tres durs** : 3 ou 4 reussites sur 60 sur cinq niveaux.

### Reste — limites connues

- Le bot du banc ne **medite** ni ne **brule** : ces choix ne sont pas mesures.
- Un **boss immobile** face a un deck qui n a plus de degats jouables ne peut plus etre
  blesse : la partie ne finit qu a la limite du banc (vu sur lvl_21, objectif « sans
  feu », communes exilees par l Epuration).
- Le banc ne va pas chercher les campeurs ni les invocateurs, ne lit pas les renvois.
- Le motif **spirale** n est porte par aucun monstre livre.
- **Slime colossal** a gros pixels ; niveaux sans boss (`lvl_08`, `17`, `18`, `20`) voulus.

## 14. Etat au 3 octobre au soir, apres l audit independant du 03/10

Un audit independant du jeu livre en §13 a releve des ecarts entre ce que le jeu
affiche, ce qu il fait et ce que ce document disait. Quatre chantiers correctifs (UI,
moteur, contenu, banc) ont ete fusionnes dans `main` le 03/10, une branche a la fois,
harnais vert a chaque fois (66 suites UNIT). Chiffres : `git log <fusion>^2` des
fusions `37b9600`, `e0a52ce`, `c2433c4` (et `df4e3f3` pour le banc) ; raisons : memoire
projet, `decisions.md` DEC-053 a DEC-057.

### Corrige

| Releve de l audit | Correction |
|---|---|
| La carte en main affichait le temps BRUT du `.tres` (« 1.4s » pour 2,66 s joues) | En combat, le temps **reel** (`RunState.effective_cast_time`, meme calcul que l incantation), rafraichi a chaque image : il raccourcit quand on accelere. Au grimoire et au deck : base x 1,9, le temps a 100 %. Le chiffre brut ne s affiche plus nulle part (test qui balaie `scripts/ui`) |
| Atelier du testeur peu utilisable sur telephone | **COPIER LE DOCUMENT** en tete avec le mode d emploi ; saisie validee aussi a la perte du focus et a la fermeture du clavier |
| Defilement de la pause non verifie | Onglets MAIN, VAGUE et fiche de monstre remplis pour deborder et testes au doigt |
| Libelles et cibles tactiles | Portrait par defaut « Le vieux mage » ; « **Arcanique** » partout a l ecran ; pastilles de passifs 80 px (toucher 100 px, ouvre la fiche) ; boutons >= 90 px |
| Un poison ou une zone comptait comme un COUP a chaque image | **Un degat continu n est pas un coup** : il n use plus les « N premiers coups », ne fait plus riposter le laser, ne declenche la Morsure, l eclair et le son qu une fois par 0,5 s, et le Miroir ne renvoie plus un coup par image. Le bouclier du premier coup tombe a la premiere morsure |
| Un sort a 4 voies n offrait plus que 2 puis 1 voie a ses dernieres maturations | **Trois voies a chaque maturation** : un sort murit (voies - 2) fois, au plus 5. 20 sorts murissent 2 fois, les 33 autres 5 fois |
| La vague qui traine partait sans prevenir | « **Vague suivante dans N s** » pendant les 10 dernieres secondes, rouge sous 3 s |
| Des niveaux a porteur d aura sans aucune dissipation jouable | **Une dissipation dans chaque niveau a aura** (deck, nouvelle ou recompense), verifie par test |
| L exemple du co-auteur (une enclume ne s envole pas) n etait pas dans le jeu | **Vharn et son Echo immunises au vent** ; seuls eux, pour ne pas annuler les Fleches du deck de depart |
| Le motif spirale etait code sans porteur | **Oeil des courants** et **Grand Oeil** en spirale ; un test exige que chaque motif soit porte |
| Pas d objet de glace | **Mur de glace** (rare, Glace, mur permanent de 70 PV), nouvelle de lvl_05 |
| Objectifs mesures avant ces changements | Les 21 niveaux re-mesures (60 parties) ; lvl_19 « sans degats » (0 / 60) remplace par « ne pas etre touche par une Goule des fosses » ; w13_4 a 1,05 |
| Le banc plantait sur lvl_21 | Bancs liberes a chaque image ; **vrai bug de jeu** trouve au passage : le Sceau de Tombol n invoquait plus apres la mort d un sbire (deja en §13) |

### Ce qui etait faux dans ce document et a ete corrige

- §13 « Motif de deplacement spirale (porte par aucun monstre livre) » : porte par deux
  monstres depuis le 03/10 au soir.
- §13 « cinq maturations » : cinq AU PLUS ; 20 sorts n en ont que deux.
- §13 « 84 reprises » : 82 apres les deplacements de cartes de la vague 9.
- §13 « rangs 3 les plus durs a 3-4 / 60 (lvl_07, 08, 09, 15, 19) » : re-mesures,
  voir ci-dessous.

### Equilibrage au 03/10 au soir

| Mesure | Valeur |
|---|---|
| Banc 21 x 30, avant / apres le moteur de la vague 9 | **571 -> 581 / 630** (lvl_05 20 -> 30, lvl_16 28 -> 24) |
| Massacre | vague **11,4** (11,9 avant ; repere 4-8) |
| lvl_13 | Vide d emprise au deck : 47 -> 30 / 60 a w13_4 1,25 ; **44** a 1,05 |
| Banc complet 21 x 60 | **non relance** depuis la vague 8 (1135 / 1260) : a refaire avant tout reglage |
| Objectifs | 21 niveaux re-mesures ; rangs 3 les plus durs : lvl_15 2 / 60, lvl_07 et lvl_09 4, lvl_04 5, lvl_02 et lvl_08 6 |

### Reste — actions du testeur (l assistant ne peut pas les faire)

1. **URGENT : licence Batareya** (icones de cartes).
2. **Licence de la fee** (`Fairy.zip` : ni licence ni auteur).
3. `python tools/assets/fetch_craftpix.py login` : pack **Free Undead Tileset**.
4. **Witches Pack complet** : les vraies apprenties (ecuyer et fee provisoires).
5. Archives completes du **renard** et du **cacodemon** (elthen).
6. **Licence rvros** du `Slime.zip`.
7. Packs absents pour des boss : **frost-guardian, c3-3dobject, sci-fi-9**.
8. **L image du necromancien** citee par le co-auteur.
9. Avant toute vente : contribution a **BDragon1727**, courriel a **John Carroll**,
   origine de **FreeSFX**.

### Reste — decisions pour le co-auteur

1. **Incantation** x1,9 ou x1,95, et le temps passe a incanter (77-97 %) : garder le
   repere de 60 % ?
2. **19 sorts limites a 2 maturations** (20 avec le Mur de glace, dont le Trait et le
   Mur de pierre du deck de depart) : l accepter, ou leur donner des voies ?
3. **Compte plafonne au niveau 12** : la banniere cristal est inatteignable.
4. Garde-robe et decor : **robes de meme silhouette** ; **ecuyer** peu « eleve » ;
   **arbre-nid** qui se lit comme un buisson.
5. **82 reprises** de cartes « nouvelles » qu un joueur a pu deja prendre en combat.
6. **lvl_10 « grande distance »** du Cacodemon a 1,5 longueur (1,7 et 2,0 : 0 / 60).
7. **Rangs 3 tres durs** (2 a 6 reussites sur 60 sur six niveaux).
8. Toujours ouverts depuis §13 : plafond de rarete des decks de 12, Rappel d ossements
   et Epuration classes Poison, boss d Infini au bestiaire, niveaux au-dessus de 95 % et
   regle du saut x2, Massacre au-dessus du repere.

### Reste — limites connues

- Le bot du banc ne **medite** ni ne **brule**, et ne vise pas le **porteur d aura**
  avec la dissipation : ces choix ne sont pas mesures.
- Le document du testeur s exporte en fichier sur PC seulement ; sur Android il se
  COPIE (pas de partage de fichier).
- Pas d `export_presets.cfg` dans le depot : aucun export Android reproductible.
- Un boss immobile face a un deck sans degats jouables ne peut plus etre blesse (§13).

## 15. Vague 10 (14-17/10) : la refonte de la campagne (retour du co-auteur du 14/10)

Retour du co-auteur du 14/10 : un deck de base de trois communes qui evolue avec les
objectifs, deux modes par niveau, un vrai boss et un mini-boss partout, l arrivee des
monstres par acte, six cartes, des ameliorations « enormes » qui changent la
structure d un sort, un ecran de lancement plus clair, un bilan des degats en fin de
niveau, des quetes annexes a boss dores, une revue globale (sprites, sons, histoire).
Decisions d Alexis : le LIBRE remplace l Infini par niveau ; des rares passent
communes ; environ huit quetes annexes, une par acte et une par apprenti.

Treize fusions dans `main` du 14 au 17/10, une branche a la fois, harnais 7/7 vert a
chaque fois : phase A `97066f6` (ecrans), `ca1308e` (progression), `2e16aa1` (revue
globale), `965c964` (mecaniques de sorts) ; phase B `9373b5b` (histoire), `ff38d70`
(cartes), `9e12fea` (majeures), `e6b195d` (campagne), `ca345ec` (quetes annexes) ;
phase C `9e571ac` (SCRIPT ERROR invisibles), `5556dd6` (portraits des apprentis),
`9aa4f31` (sortie propre, fin du plantage a la fermeture), `b8264d7` (banc de
controle, MESURES recollees) ; puis `e3c905a` (`make_story` sort aussi par
`CleanExit`). Chiffres : `git log <fusion>^2` ; raisons : memoire projet,
`decisions.md` DEC-058 a DEC-066 ; constats de la revue : `docs/revue_vague10.md`.
Le banc de controle de C2 a ete fusionne pendant la redaction de ce paragraphe : son
detail est dans `docs/banc_vague10.md` : campagne 1180 / 1260 (minimum `lvl_18` 36),
annexes 243 / 480 (40 a 65 %), Massacre 17,5 vagues, 29 classements d objectifs
conformes, 0 SCRIPT ERROR. Apres l audit (C7a, C7b, C7c), la mesure finale de C8 sur
`main` `a3c68b0` fait foi : campagne 1214 / 1260 (minimum `lvl_18` 46), annexes
247 / 480, Massacre 15,9 vagues, 29 classements conformes (meme document). Chaque point
ci-dessous a ete relu dans le code et le contenu livres (`main` `e3c905a`).

### La demande, point par point

FAIT = livre, avec le fichier et le test qui le tiennent ; PARTIEL = livre en
partie ; PAS FAIT. **Bilan : 25 FAIT, 2 PARTIEL, 1 PAS FAIT** (28 points ; le point 28
est passe de PARTIEL a FAIT avec la mesure finale de C8).

**La campagne**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 1 | Deck de base d un niveau = 3 communes x4, jamais sans degats | FAIT | `LevelDef.base_commons` (la 1re = la nouvelle), `exploration_deck` = 4/4/4 ; `test_campagne_w10` §1 (trois communes distinctes, deux deja vues, un sort qui blesse) | |
| 2 | Une commune NOUVELLE par niveau | PARTIEL | 21 communes (DEC-059) pour 21 niveaux ; `test_campagne_w10` §1 | `lvl_01` en porte trois (le deck de depart) : `lvl_15` (Fleche percante) et `lvl_16` (Trait arcanique) reprennent une commune deja vue. Il en faudrait deux de plus |
| 3 | Le deck de campagne change avec les objectifs reussis (table du co-auteur) | FAIT | `LevelDef.CAMPAIGN_DECK_TABLE`, `campaign_deck()`, lu par `SaveData.campaign_deck` (la partie par `GameController.run_deck`, le briefing, la fiche, le livre) ; `test_campaign_deck` (8 cas : 12 cartes, 6 ids, plafonds) | La combinaison E+L manque a la table du co-auteur : deduite (3/3/3 + E x2 + L x1), a valider. Une recompense entree au deck d un niveau ouvert est dans le livre |
| 4 | Deux modes des le debut du niveau : CAMPAGNE et LIBRE | FAIT | `GameEnums.Mode { EXPLORATION, FREE, MASSACRE }`, fiche `campaign_panel.gd`, `SaveData.free_unlocked` ; une victoire en LIBRE ne marque que les objectifs (`cleared_free`) ; `test_modes`, `test_campaign_progression` | L Infini par niveau est retire ; le Massacre est le seul mode sans fin. Les profils gardent leur ancien record Infini, plus lu ni ecrit |
| 5 | Montee de niveau : toutes les cartes obtenues et toutes les communes de l acte, des le niveau 1 | FAIT | `RunState.levelup_pool`, `ContentDB.act_commons` ; `levelup_cards` vide sur les 21 niveaux ; `test_campaign_progression` | Consequence : la commune nouvelle d un niveau peut etre prise en combat plus tot dans l acte (question au co-auteur) |
| 6 | Recompenses d objectif coherentes avec le niveau | FAIT | `_progression_de` (`tools/make_content.gd`) dit, niveau par niveau, a quel trait chaque carte repond ; rang 1 rare, 2 epique, 3 legendaire, jamais la meme a deux niveaux qui peuvent se suivre (`test_campagne_w10` §6) | Seule la regle « auras -> dissipation » est tenue par un test (`test_level_progression`, DEC-057) : le reste de la table se relit, il ne se verifie pas |
| 7 | Un vrai boss (derniere vague) et un mini-boss (autre vague), chacun avec un effet, dans chaque niveau | FAIT | 21 / 21. Trois mecaniques neuves : ECHEANCE (Chronos), ARMURE QUI SE REFERME (le Gardien, devenu boss de `lvl_09`), GARDE LEVEE (Gardien d ossements), DEC-065 ; le Seigneur de braise riposte, le Totem ancien a une aura ; `test_campagne_w10` §2, `test_tetes_w10` | Sesh n a que `devours`, le verbe du Glouton (proposition « L outre » de la revue, non faite) |
| 8 | Promotions : mini-boss -> ordinaire a l acte suivant, boss -> mini-boss a +2 ou ordinaire a +3 | FAIT | 20 promus (`_promus_w10`, DEC-063) ; les echos des quatre demons sont retires (aucune place legale) ; `test_campagne_w10` §4 (delais, PV), `test_bosses` | |
| 9 | Arrivee des monstres : 5 ordinaires neufs a l ouverture d un acte, puis 1 ou 2 par niveau | FAIT | vagues des 21 niveaux (`make_content.gd`) ; `test_campagne_w10` §3 | Avant : `lvl_02` introduisait 13 especes d un coup |
| 10 | Passifs : 6 de base a l acte 2, 1 ou 2 par niveau de campagne, le reste en annexes | FAIT | `GameConfig.BASE_PASSIVES` (6), `LevelDef.passive_unlocks` (un par niveau des l acte 2 : 17), 7 dans les annexes ; `test_campagne_w10` §5, `test_side_quests` | Un par niveau, jamais deux |
| 11 | Gorgones : elles bloquent meme une main d une carte, jamais la 6e carte | FAIT | `RunState.max_held_cards()` (`UNHOLDABLE_IN_FULL_HAND`), `MIN_PLAYABLE_CARDS` retire ; `test_boss_mechanics_v3`, `test_hand_copies` | |
| 12 | Resistances arrondies, alignees par monstre, moins d immunites au poison | FAIT | `EnemyDef.tiered_table` (paliers de 25, ecart < 15 neutre, voisins groupes), `IMMUNISES_AU_POISON` ; `test_resist_tiers` | 20 valeurs distinctes -> 8 ; 32 immunises au poison -> 6 (DEC-058) |
| 13 | Incantation legerement reduite (x1,9 -> environ x1,75) | FAIT | `GameConfig.CAST_TIME_SCALE` = 1,75 (DEC-060) | Banc de B1a : 1157 -> 1170 / 1260 |

**Les cartes**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 14 | Six cartes : Vent du sud, Marque electrique, Pluie abondante, Lumiere purifiante commune a 1,3 s, Sable mouvant, Jet d eau en I | FAIT | cles `global_wind`, `electric_mark`, `global_rain`, `quicksand`, `water_jet` (`scripts/effects/handlers.gd`, section VAGUE 10 de `battlefield.gd`) ; cartes dans `make_content.gd` ; `test_w10_sorts`, `test_w10_cartes`, smoke `w10_sorts_smoke.gd` | |
| 15 | Rares converties en communes, le surplus aux annexes | FAIT | 7 rares -> communes sans changer leurs chiffres (DEC-059) : 21 communes, 11 rares, 15 epiques, 11 legendaires ; `test_w10_cartes` | Il ne reste aucune rare en surplus : la campagne donne les 11. Les annexes donnent la Concentration, 7 passifs et des reprises |
| 16 | Deux ameliorations « enormes » par carte, qui changent la STRUCTURE du sort | FAIT | `MajorUpgradeDef` (ops `axis`, `add_effect`, `set`, `scale`, `duplicate`, `repeat`, `cast_time`), `SpellCard.major_upgrades` : 116 ; une seule offerte, a partir de la 2e maturation (`MAJOR_UPGRADE_FROM_TIER` = 2) ; `hand_card_level` (« un sort de ta main monte d un niveau »). Tous les exemples du co-auteur existent (Seconde ligne, Vague de fleches, Venin tenace, zones qui respirent, Orage en chaine, Muraille geante, Ronces de fer, Meteore eclair, Maitrise). `test_major_upgrades`, `test_majeures_contenu`, smoke `w10_majeures_smoke.gd` (les 116 sur des cibles qui meurent) | Le bot du banc n en prend que 0,42 par partie : la 2e maturation (24 XP) n est atteinte que par les sorts les plus joues. Propositions moteur de B1b non faites (voir Reste) |

**Les ecrans**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 17 | Bilan de fin de niveau en DEGATS par monstre, avec un conseil concret, en victoire ET en defaite | FAIT | `BattleReport`, `ThreatLore` (conseil : la plus forte faiblesse et une carte possedee de cet element, le premier trait et la carte qui y repond), `RunState.damage_by_enemy_id` ; `test_screens_w10` | |
| 18 | Ecran de lancement refait : monstres et leurs effets et resistances, cartes obtenables, objectifs, defilement au doigt | FAIT | `LoadingScreen` (tous les boss et mini-boss en tete, avec leur vague), `ThreatLore.mechanic_line`, `TouchScroll.wrap` ; `test_screens_w10`, smoke `ScreensW10Check` (au doigt, captures) | |
| 19 | Contour noir du sceau d element | FAIT | `scripts/ui/seal_outline.gdshader` sur `CardView.with_type_badge` (main, detail, grimoire, deck, pause) ; `test_screens_w10` | |
| 20 | Fiche CAMPAGNE / LIBRE ; page des quetes annexes sur la carte, hors progression | FAIT | `campaign_panel.gd` (deck de campagne et passifs debloques), `CampaignMap.SIDE_PAGE`, `LevelDef.is_campaign_level()` (hors `campaign_progress`) ; `test_campaign_progression`, `test_campaign_map` | |

**Quetes annexes et histoire**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 21 | Environ huit quetes annexes (une par acte, une par apprenti), boss dores, sorts et passifs restants | FAIT | `tools/make_side_quests.gd` : 8 `side_*`, 8 boss dores (`EnemyDef.gilded_from`, `AnimCatalog.GOLD_TINT`), recompenses CALCULEES depuis la campagne (DEC-066) ; `test_side_quests` (MESURES des 24 objectifs) | « La mesure » (acte 1) ne se gagne que 24 fois sur 60 au banc, la plus dure (cible 40-70 %) |
| 22 | Dialogues des annexes coherents avec les personnages | FAIT | `tools/make_story.gd`, section des annexes ; les apprentis parlent avec leur visage (`assets/portraits/apprentice_cast.png`, `tools/assets/make_apprentice_portraits.py`) ; `test_story`, vitrine `apprentice_story_showcase.gd` | `docs/histoire.md` §1 « Les visages » ne cite pas les apprentis (ils sont au §11) |
| 23 | Histoire : gorgones et village petrifie, `lvl_02` (nom, intro), scenes de `lvl_05` et `lvl_06`, relecture de coherence | FAIT | `make_story.gd`, `docs/histoire.md` ; `lvl_02` = « Le village petrifie » ; les 26 constats de la revue corriges dans le texte ou renvoyes a B2 (revue §2.7 : mini-boss du tutoriel, ouverture du pentacle, sous-titres, `outro_text` vides, faits par B2) ; `test_story` (aucune scene orpheline, intro et outro par niveau, le narrateur ne nomme que des monstres du niveau) | |

**La revue globale**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 24 | Animations de mort jouees, douleur | FAIT | `Fx.death_plan` (la pose `death` des 37 feuilles qui l ont, un cadavre sans effet de jeu), retour de coup generique pour les 45 monstres sans pose `hurt`, tours qui vivent ; vitrine `MonsterFeedbackShowcase` (etage visual) | |
| 25 | Sons par monstre, musiques, voix | FAIT | `AudioBus` : 15 familles de monstres, sons par objet de terrain et par mecanique, un son par sort, musique par acte, theme du boss final, musique du Massacre, voix branchees ; `tools/assets/extract_w10_audio.py` ; `test_audio_w10` | Une vingtaine des sons neufs viennent de FreeSFX, dont l origine n est pas prouvee |
| 26 | Monstres fades | PARTIEL | 11 ordinaires et 5 tetes sans comportement au 14/10 (revue §1) : les tetes en ont toutes un, et la plupart des ordinaires (Lutin en sauts, Champignon et Slime squelette a bouclier, Plante qui crache, Slime moyen par a-coups, Charognard qui vole, Echo de Chronos a echeance) | Restent sans mecanique : Gnome, Golem, Behemoth, Gelee (petite) ; le Golem et le Behemoth n ont que leur immunite au ralentissement |
| 27 | Sprites et decors devenus mediocres face aux nouveaux | PAS FAIT | constats : `docs/revue_vague10.md` §1.3 et §3 | Feuilles qui contredisent le nom (Ymoa en tour comme le Gardien-totem, Seigneur de braise en paysan, Charognard en vautour...), halo d aura, decors de dialogue dedies (port, forge, fosses, arene, temple, registre ; les actes 3 a 5 jouent devant `talk_shrine`) : il faut des packs ou des feuilles neuves |

**La verification demandee**

| # | Demande | Etat | Livre (fichier, test) | Pourquoi, ce qui manque |
|---|---|---|---|---|
| 28 | Banc des 21 niveaux >= 60 %, objectifs classes au banc des objectifs | FAIT | Mesure finale de C8 (main `a3c68b0`, toute la vague 10 et l audit) : campagne **1214 / 1260**, les 21 niveaux au-dessus de 60 % (minimum `lvl_18` 46 / 60, `lvl_17` 50, `lvl_11` 54) ; annexes 247 / 480, toutes entre 40 et 70 % ; objectifs : **21 + 8 classements conformes**, aucun a 0 ni a 60 / 60, apres 7 corrections dues a C7b (`lvl_03`, `04`, `09`, `11`, `12`, `15`, `side_fairy`) ; `test_level_progression`, `test_side_quests` (MESURES) | Detail dans `docs/banc_vague10.md`, « Mesure finale (C8) ». Hors de ce point : incantation 49-88 % (moyenne 76,0, repere < 60 %), Massacre 15,9 vagues pour un repere de 4-8 (cause non analysee) ; `lvl_12` « le meme sort 30 fois » passe a 45 ; `lvl_11` garde un ecart de 2 entre ses rangs 1 et 2 |

### Corrige en route (hors demande)

- **SCRIPT ERROR invisibles au harnais** (C1) : une majeure decalee sur une cible
  morte (`EffectRegistry._w10_ctx_for`) et un residu qui tuait pendant le parcours
  des residus (`Battlefield._w10_tick_dots`) ; environ 2200 erreurs par banc complet
  apres B1b, 0 sur les bancs de controle de C1 (21 niveaux x 5 et Massacre). Le
  smoke lance les 116 majeures sur des cibles qui meurent.
- **Legendes des monstres gardees dans l ecran** (`Fx.caption_box_x`), entre la
  jauge de vitesse et le bord ; `test_mech_label_clamp`.
- **Monstre reste blanc pour tout le combat** apres deux coups rapproches (un tween
  interrompu prenait son blanc pour la teinte de repos), corrige par A4.
- **Le pentacle s ouvrait apres UN seul demon** : `LevelDef.requires_all_previous`
  (vrai sur `lvl_13` seul), DEC-064.
- **Regle du saut x2** : verifiee sur les 21 niveaux (`test_campagne_w10` §8, PV des
  boss et des chaines compris) ; elle n etait tenue que sur trois.
- **Plantage a la fermeture du moteur** (signal 11 apres le marqueur de fin, sur tous
  les etages et les bancs, intermittent) (C3) : la boucle de fermeture de GDScript
  repartait d un script deja libere. Etages, smoke et outils sortent par
  `CleanExit.quit(code)`, qui fait tenir chaque script charge par GameConfig ;
  `test_clean_exit`. Mesure de C3 : 0 plantage sur 800 fermetures, 24 sur 800 avant.

### Ce qui etait faux dans ce document et a ete corrige

- §12 « `Mode { EXPLORATION, INFINITE, MASSACRE }` », « Infini par niveau » : depuis
  le 14/10, `Mode { EXPLORATION, FREE, MASSACRE }` ; le LIBRE joue les memes vagues
  ecrites et a une fin.
- §12 « passifs actifs seulement en Infini et en Massacre » : en LIBRE (des l acte 2)
  et en Massacre ; en campagne, ils viennent des montees de niveau, parmi les
  passifs debloques.
- §12, §13 « niveaux sans boss (`lvl_08`, `17`, `18`, `20`) et sans mini-boss
  (`lvl_16`) : voulu » : les 21 niveaux ont un boss et un mini-boss.
- §12 a §14 « regle du saut x2 depassee sur 9 niveaux » : tenue sur les 21.
- §13, §14 « x1,9 » : x1,75.
- §13 « 86 monstres » : 112 `EnemyDef` (+20 promus, +2 tetes neuves de l acte 2,
  +8 boss dores, -4 echos des demons).
- §12 « pool de campagne = deck du niveau + 3 cartes nouvelles + cartes des
  objectifs », §13 « 84 reprises », §14 « 82 reprises » : les niveaux refaits n ont
  plus de cartes nouvelles (`levelup_cards` vide) ; le pool est « cartes obtenues +
  communes de l acte » et le compte des reprises n a plus d objet.
- §14 « `lvl_10` grande distance du Cacodemon » : l objectif n existe plus.
- §14 « 20 sorts a 2 maturations » : 23 (sonde du 17/10 sur `RunState.upgrade_tiers_for`) ;
  les 35 autres en ont 5.
- `docs/histoire.md` (corrige dans le meme changement) : les tetes de ses tableaux
  d actes dataient d avant B2 (Gardien en mini-boss du tutoriel, Grand Oeil et Mage
  noir en mini-boss, Reine gorgone en mini-boss de `lvl_13`...), et il disait que le
  pentacle s ouvrait apres un seul demon.

### Equilibrage au 17/10 (chiffres des chantiers, banc de controle de C2 en derniere ligne)

| Mesure | Valeur |
|---|---|
| Incantation (B1a, 21 x 60) | x1,9 : 1157 / 1260 ; **x1,75 : 1170**, le plus bas `lvl_11` 39 ; temps passe a incanter 70 a 92 % sur 19 niveaux |
| Majeures (B1b) | 1159 -> 1169 / 1260 ; le bot en accepte 83 sur 116 et en prend 0,42 par partie (15 distinctes) |
| Gorgones (A1, 60 parties) | `lvl_13` 44 -> 49, `lvl_02`, `lvl_15`, `lvl_16` inchanges ; Massacre 9,0 -> 9,5 vagues |
| Campagne refaite (B2) | 1177 -> **1185 / 1260** ; minimum `lvl_18` 41, `lvl_17` 44 |
| Annexes (B3, 60 parties, chacune juste apres son niveau d ouverture) | la mesure 24, l atelier 34, le tresor 29, le champion 34, la vitrine 26, l ecuyer 39, la fee 27, l apprentie 30 |
| Objectifs (MESURES recollees par C2) | 21 classements de campagne et 8 d annexes conformes ; rangs 1 a 58-59 / 60 sur sept niveaux, rangs 3 a 2 / 60 sur `lvl_03`, `lvl_06` et `lvl_11` |
| Banc de controle (C2, `b8264d7`) | campagne 1180 / 1260, annexes 243 / 480, Massacre 17,5 vagues ; detail dans `docs/banc_vague10.md` |
| Mesure finale (C8, main `a3c68b0`) | campagne **1214 / 1260** (minimum `lvl_18` 46), annexes **247 / 480** (40 a 65 %), Massacre **15,9** vagues ; majeures prises 2,51 par partie ; 29 classements d objectifs conformes ; detail dans `docs/banc_vague10.md`, « Mesure finale (C8) » |

### Reste — actions du testeur (l assistant ne peut pas les faire)

1. **URGENT : licence Batareya** (icones de cartes ; les icones de la vague 10 sont
   craftpix).
2. **Licence de la fee** (`Fairy.zip`, ni licence ni auteur) : elle couvre aussi son
   portrait d histoire depuis C6.
3. `python tools/assets/fetch_craftpix.py login` : pack **Free Undead Tileset**.
4. **Witches Pack complet** : les vraies apprenties (ecuyer et fee provisoires).
5. Archives completes du **renard** et du **cacodemon** (elthen) ; **licence rvros**
   du `Slime.zip`.
6. Packs absents pour des boss : **frost-guardian, c3-3dobject, sci-fi-9** ; et de
   quoi dessiner les tetes de l acte 4 et les decors de dialogue (point 27).
7. **L image du necromancien** citee par le co-auteur.
8. Avant toute vente : contribution a **BDragon1727**, courriel a **John Carroll**,
   origine de **FreeSFX** (la dette a grossi d une vingtaine de sons avec A4).

### Reste — decisions pour le co-auteur

1. **Table du deck** : E+L deduit (3/3/3 + E x2 + L x1).
2. **`lvl_15` et `lvl_16`** reprennent une commune : deux communes de plus ?
3. **Communes de l acte au pool des le niveau 1** : la commune nouvelle d un niveau
   peut avoir ete prise en combat avant lui.
4. **Passifs** : les six de base (Ecorce vive, Celerite, Main leste, Erudition,
   Compagnon fidele, Pulsation) et un passif par niveau, jamais deux.
5. **Objectifs aux extremes** : rangs 1 quasi gratuits (58-59 / 60 : `lvl_02`, `06`,
   `07`, `12`, `14`, `15`, `19`) ; rangs 3 quasi impossibles a 2 / 60 (`lvl_03` « ne
   pas etre touche par le Lutin archer », 1 / 60 a B2 ; `lvl_06` moins de 110 s ;
   `lvl_11` sous 120 %) ; `lvl_09` et `lvl_10` ont le meme rang 1 (« sans Trait
   arcanique », 57 et 56 / 60) ; « sans perdre de vie » ne reste qu au `lvl_19`
   (rang 3, 10 / 60).
6. **Annexes plus dures que la campagne** (40 a 65 %) : « La mesure » a 40 %.
7. **Monstres encore fades** (Gnome, Golem, Behemoth, Gelee petite) ; **Sesh**
   partage le verbe du Glouton (« L outre » : garder 5 proies, les relacher a sa
   mort).
8. **Majeures** : une par sort et par partie, des la 2e maturation, donc rares en
   campagne (0,42 par partie au bot).
9. **Temps passe a incanter** 70 a 92 % (repere < 60 %).
10. Toujours ouvertes : compte plafonne au niveau 12 (succes inchanges a la vague
    10) ; garde-robe (robes, ecuyer, arbre-nid) ; **23 sorts a 2 maturations** (les
    20 d avant, plus Vent du sud, Marque electrique et Pluie abondante) ; Rappel
    d ossements et Epuration classes Poison ; plafond de rarete des decks de 12 (en
    LIBRE et en Massacre : en campagne le deck est impose) ; Massacre au-dessus du
    repere (17,5 vagues au banc de C2 pour 4-8).

### Reste — limites connues et propositions non faites

- **Propositions moteur de B1b** : `grow_end`, `add_effect` en tete des effets, un
  axe de degats pour les cles de A1 (leurs majeures paient en vitesse ou en cartes),
  la couleur du laser de marque par element, un delai de rejeu qui suit la duree.
- **Banc des objectifs et banc d equilibrage ne jouent pas les annexes pareil** :
  « La mesure » gagne 24 fois sur 60 au second et au moins 59 fois sur 60 au premier
  (son rang 1, identique a la re-mesure de C2). Le banc d equilibrage la joue avec le
  profil accumule de la campagne, le banc des objectifs avec un profil neuf ou seuls
  les niveaux qui la precedent sont ouverts : a comprendre.
- **La dissipation garantie (DEC-057) est plus faible qu au 03/10** : a `lvl_06`,
  `lvl_13` et `lvl_21`, ou descendent des porteurs d aura, elle n est qu une commune
  de l acte offerte a la montee de niveau, ou une recompense d objectif ; seuls
  `lvl_05`, `12`, `16` et `20` ont la Lumiere purifiante au deck de base.
- Le bot du banc ne **medite** ni ne **brule**, ne vise pas le porteur d aura avec la
  dissipation, et prend peu de majeures : ces choix ne sont pas mesures.
- La descente a travers les cinq mondes (`WaveSpawner.setup_procedural` avec les
  mondes) n est plus appelee par aucun mode.
- **Une annexe change la campagne qui la suit** (constate par C2, commentaire de
  `test_level_progression.MESURES`) : le deck de « L atelier du rat » porte la
  Lumiere purifiante, qu aucun niveau ne donne avant `lvl_20` ; des que l annexe est
  ouverte, la regle du livre (deck d un niveau ouvert) la rend OBTENUE, donc presente
  au pool de montee de tous les niveaux joues ensuite. Les MESURES
  de `lvl_18`, `03`, `04` et `19` ont bouge pour cette seule raison. Un deck d annexe
  se regle donc aussi en pensant aux niveaux d apres.
- Toujours vrai : document du testeur copie (pas de fichier) sur Android, pas
  d `export_presets.cfg`, boss immobile face a un deck sans degats (§13).
