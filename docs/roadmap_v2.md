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
| Niveau du joueur + cartes en haut, profil en haut a droite | **FAIT** | C |
| Fusionner bestiaire et galerie (onglets Sorts / Passifs / Bestiaire) | **FAIT** | C |
| Livre a pages (asset magic book), fleches gauche/droite | **FAIT** | C |
| Detail avec nb d'utilisations, monstres tues, ameliorations | **FAIT** (le crochet des ameliorations attend G) | C |
| Inconnu = grise | FAIT | — |
| Icones de sort partout | FAIT (45 feuilles propres) ; a re-choisir dans les packs d'icones quand ils arriveront | C |
| Police plus lisible, tout un peu plus grand | **FAIT** (la cause etait le contour de 6 px, pas la taille) | C |
| Vraies icones de menu (pas un steak) | **FAIT** | C |
| Titre stylise, nom "Time Wizard" | **FAIT** | C |
| Deck : 15 cartes exactement, 0-3 passifs, ≤3 legendaires, ≤3 epiques | **FAIT** (verifie aussi sur les 7 decks de campagne) | K |
| Plusieurs onglets de deck | **FAIT** | K |
| Profil : succes par rarete au lieu des defis | **FAIT** (16 succes, XP deduite de la rarete) | L |
| Contour de couleur par rarete (cartes, monstres, succes) | **FAIT** (epaisseur croissante en plus de la couleur) | L |
| Cosmetiques : couleur du mage, chapeau, tour ; onglet dedie | **FAIT** (11 pieces, avec apercu) | L |
| Fond de la barre de titre selon le niveau | **FAIT** (bois / argent / or / cristal) | L |

### Campagne
| Demande | Etat | Chantier |
|---|---|---|
| Carte de campagne sur les fonds de combat, points jaunes, fleches d'acte | **FAIT** (5 actes, une page par acte) | E |
| 3 objectifs par niveau | FAIT (3 par niveau, 4 types) ; types a enrichir | H |
| Histoire : prologue, 5 actes, plot twist de l'enfant | **FAIT** (docs/histoire.md) | D |
| Sequences visual novel entre les niveaux | **FAIT** (systeme + 9 scenes : prologue et acte 1) | D |
| Niveau 1 tutoriel, deck 9 cartes, 3 vagues ; niveau 2 en 4 vagues ; puis 6 | **PARTIEL** (niveau 2 raccourci ; le niveau 1 resiste, voir section 9) | H |
| Pool de cartes qui grandit de 3 par niveau | **FAIT** (6 -> 11 cartes differentes, plus aucun recul) | H |
| Fin : deblocage du mode infini | **FAIT** (`SaveData.campaign_cleared()`) | — |

### Mode infini
| Demande | Etat | Chantier |
|---|---|---|
| Tous monstres et boss, fond change toutes les 6 vagues, mini-boss v3 / boss v6, fond qui pese sur le tirage | **FAIT** (5 mondes qui bouclent, 47-70 % de monstres du lieu) | J |

### Sorts et passifs
| Demande | Etat | Chantier |
|---|---|---|
| Passifs hors du deck, actifs des le debut, 3 emplacements, echange au 4e | **FAIT** | F |
| Passif actif seulement au-dela d'une vitesse (ex. 140 %) | **FAIT** | F |
| Plus de passifs, avec raretes ; 20 % de passifs a la montee de niveau | **FAIT** (14 passifs) | F |
| Icone des passifs a cote de la barre de vitesse, a leur seuil | **FAIT** | F |
| Amelioration des cartes en combat (XP par lancer, choix parmi 3) | **FAIT** (8 lancers, 3 pactes, per-partie) | G |
| Arbre qui attire les ennemis ; sort de stun ; arbre a zone de poison ; eau qui ralentit | **FAIT** (4 cartes, 3 verbes d effet neufs) | H |
| Element sur chaque sort de degats + resistances en % par monstre | **FAIT** (6 elements, table par monstre) | B3 |

### Monstres
| Demande | Etat | Chantier |
|---|---|---|
| Monstres un peu plus grands | **FAIT** (2.1) | B1 |
| Apparition plus bas + fondu de 0,5 s | **FAIT** | B1 |
| Feu follet -> Planogo, vole par-dessus les murs, boule de poison 10 PV | **FAIT** | B1 |
| Nuee de rats -> Oiseau mirage, sprite qui ne tourne plus | **FAIT** | B1 |
| Boss a mecaniques originales (revient 3 fois, ressuscite, bouclier renvoi, 10 coups immunises, slime enorme qui se divise, 3 mages a resistances, renard qui dort, mecha laser, executeur onde de choc, demon slime immunise au feu) | PARTIEL (3 boss a mecanique) ; la plupart BLOQUES par les packs absents | I |
| Boss d'un acte devenant monstre courant ensuite | **PARTIEL** (`totem_guardian` : boss en lvl_02, mini-boss en lvl_05) | I |

### Combat
| Demande | Etat | Chantier |
|---|---|---|
| Vitesse non accelerable manuellement, +1 % toutes les 0,5 s | **FAIT** (bouton et barre supprimes) | B1 |
| Main a 6 cartes | FAIT | — |
| Quitter le combat depuis la pause | **FAIT** | B1 |

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

**Le pool de cartes GRANDIT** desormais sans jamais reculer : 6, 10, 10, 10, 10,
11, 11 cartes differentes du niveau 1 au niveau 7, pour des decks qui font
toujours 15 cartes. Il reculait avant (dix au niveau 4, huit au niveau 5) : un
joueur qui avance recevait moins d outils qu au niveau precedent.

Les ajouts collent au LIEU, ils ne remplissent pas : aux Forges, Golem, Colosse
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
