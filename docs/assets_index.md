# Index des assets et de leurs licences

Audit du 2026-09-21 (chantier A) pour les **23 entrées** de `raw_assets/`
(22 archives + le dossier `monsters_2026_09`, qui en contient 6), complété le
**2026-09-26 (chantier A2)** pour les **47 archives** de
`raw_assets/packs_2026_09_26/` — section 5.

Méthode : le fichier de licence **embarqué dans l'archive** fait foi quand il
existe (extrait et lu) ; sinon la page officielle du pack. Les pages itch.io
refusent la lecture automatique (HTTP 403) : les clauses issues d'itch viennent
d'extraits de recherche et sont signalées comme telles.

**Quand aucun fichier de licence n'est embarqué et que la page n'est pas
consultable, la licence est notée INCONNUE — jamais devinée.** Trois des
nouveaux packs sont dans ce cas, dont un très exposé (§1.5).

---

## 1. À RÉGLER AVANT PUBLICATION COMMERCIALE

Six points, du plus gênant au plus simple. Les §1.5 et §1.6 sont apparus avec
les archives du 2026-09-26.

### 1.1 « Effect and FX Pixel All Free » (BDragon1727) — commercial CONDITIONNEL

**C'est le seul point réellement bloquant.** Ce pack fournit **45 feuilles
d'effets, une par carte de sort** : c'est l'ossature visuelle de tous les sorts
du jeu (`Fx.STRIPS`, règle `_check_card_fx` de l'AUDIT qui exige une feuille
propre par carte).

> « Free to use on non-commercial games. If you will be using on a commercial
> game, please contribute (any value). Modify as desired. You cannot do:
> Resell / redistribute this asset. »

- Usage commercial : **oui, mais après une contribution** (montant libre) à
  l'auteur sur itch.
- Crédit : non obligatoire, apprécié.
- Redistribution des sources : **interdite**, même modifiées.

**Ce que ça veut dire concrètement** : tant que le jeu n'est pas vendu, rien à
faire. Dès qu'il est commercialisé, il faut payer la page itch (n'importe quel
montant) — c'est peu coûteux et ça lève le point. Pas besoin de remplacer les
45 feuilles. Source : https://bdragon1727.itch.io/750-effect-and-fx-pixel-all

### 1.2 xDeviruchi (musiques) — CRÉDIT OBLIGATOIRE

Divergence importante : les résumés qui traînent sur le web disent « crédit non
obligatoire ». **C'est faux pour la version 2025 présente dans `raw_assets/`.**
Le `DOCUMENTATION & LICENSE.pdf` embarqué impose une mention exacte :

> « Attribution: Proper credit must be given to the original creator as follows:
> *Original music by Marllon Silva (xDeviruchi)* »

- Usage commercial : oui.
- Crédit : **obligatoire**, formulation imposée (+ lien vers sa chaîne si possible).
- Redistribution des sources : interdite sans accord écrit.

**À faire** : ajouter cette ligne à un écran de crédits avant publication.

### 1.3 « FreeSFX » — origine NON PROUVÉE

Aucun fichier de licence dans le zip, et **aucune preuve formelle de l'auteur**.
La piste Kronbits (« 200 Free SFX », CC0) est cohérente — même nom d'archive,
même arborescence `GameSFX/`, même nomenclature « Retro * » — mais reste une
déduction.

**À faire** : demander à Alexis d'où vient ce zip. Si c'est bien Kronbits, c'est
du CC0 et il n'y a rien à faire.

### 1.4 Duelyst — FAUSSE ALERTE, le pack est SAIN

Le soupçon était légitime (des assets d'un jeu commercial de Counterplay Games
re-empaquetés par un tiers) mais **il est levé** : Counterplay Games a ouvert
Duelyst, code **et assets**, sous **CC0 1.0 Universal** (domaine public) via le
dépôt `open-duelyst/duelyst`. Le pack itch de screensmith n'est qu'un portage
Unity de ces fichiers déjà libres.

- Usage commercial : **oui**, sans condition.
- Crédit : non requis (CC0).
- Réserve : CC0 ne cède **ni les marques ni les logos** (clause 4.a). Ne pas
  réutiliser le nom « Duelyst » ni son logo — seuls les sprites sont concernés,
  ce qui est exactement notre usage (5 boss).

Sources : https://github.com/open-duelyst/duelyst (licence CC0-1.0) et
https://www.pcgamer.com/duelyst-source-code-is-now-free-for-everyone-no-strings-attached/

### 1.5 « MAGE ICONS BIG PACK » (Batareya) — LICENCE INTROUVABLE

**C'est le point le plus exposé du lot, devant même le §1.1.**

L'archive `MAGE ICONS BIG PACk (by Batareya).rar` contient **250 PNG et
strictement rien d'autre** : pas de `license.txt`, pas de `readme`, aucun
fichier non-PNG (vérifié par listage complet de l'archive). La licence n'est
donc connaissable que sur la page d'origine,
https://batareya.itch.io/250-magical-icons-pixel-art-icons, que l'assistant ne
peut pas consulter (403 systématique).

- Usage commercial : **INCONNU**
- Crédit : **INCONNU**
- Redistribution des sources : **INCONNU**

**Pourquoi ça compte autant** : **42 des 60 icônes de sorts** du jeu viennent de
ce pack — c'est-à-dire l'image que le joueur regarde sur chaque carte, à chaque
combat. Si le pack s'avère non exploitable commercialement, ce ne sont pas
quelques fichiers à remplacer mais **les deux tiers des icônes** à refaire.

**À faire, avant d'aller plus loin sur les icônes** : Alexis ouvre la page itch
du pack et lit la section « License » (elle figure sous le bouton de
téléchargement). Trois cas :
- « commercial use allowed » → rien à faire, on note la clause ici ;
- « credit required » → une ligne de plus à l'écran de crédits ;
- « non-commercial » → il faut rebasculer ces 42 icônes sur les packs craftpix
  (Warlock, Night Elf, FireMage, EarthMage), qui sont, eux, couverts et déjà
  sur le disque. Les icônes existent, c'est un travail de remplacement, pas de
  création.

### 1.6 « Mage Voice Pack » (John Carroll) — L'AUTEUR DEMANDE À ÊTRE PRÉVENU

Ce pack n'a pas de licence formelle : son `readme.txt` tient en une phrase.

> « Thank you for checking out my mage pack. If you use any of these sound
> clips, **please let me know!** And if you'd like to work together, shoot me an
> email! — John, https://johncarroll.itch.io/, itsjohncarroll@gmail.com »

- Usage commercial : **pas interdit** (aucune restriction énoncée).
- Crédit : **pas obligatoire**.
- Redistribution des sources : non traitée — s'abstenir.

Ce n'est pas une clause contraignante mais une **demande explicite de l'auteur**,
et elle coûte un courriel. 44 répliques sont extraites dans `assets/voice/`.

**À faire** : écrire à `itsjohncarroll@gmail.com` avant publication pour dire
que le jeu utilise le pack. Un crédit « Voix du mage : John Carroll » est de
toute façon la courtoisie minimale.

---

## 2. Tableau complet des 23 entrées

Légende — Redistribution = a-t-on le droit de rediffuser **les fichiers sources**
(les zips). Partout où c'est « non », la règle en place (garder `raw_assets/`
hors du dépôt, ne versionner que les feuilles extraites) est ce qui nous protège.

| Pack | Licence | Commercial | Crédit | Redistribution sources |
|---|---|---|---|---|
| Tiny Swords (Free Pack) — Pixel Frog | itch, pay-what-you-want | oui | non | **non** |
| Tiny RPG Character Pack 02 — Zerie | itch | oui | non | **non** |
| Free Pixel Effects Pack — DavitMasia / CodeManu | domaine public (README du zip) | oui | non | oui |
| **Effect and FX Pixel All Free — BDragon1727** | itch, free/full | **conditionnel (§1.1)** | non | **non** |
| VFX Free Pack — CodeManu | domaine public | oui | non | oui |
| Pipoya HEXShield / WarpPortal / Mysterious Object | pipoya.net, termes d'usage | oui | non | oui si **gratuite** ; revente interdite |
| Pixel Holy Spell 32x32 Pack 3 — BDragon1727 | itch, free/full | conditionnel | non | **non** |
| explosion pack 1 — ansimuz | **CC0** (`public-license.pdf` du zip) | oui | non | oui |
| SpaceBackgroundSource — deep-fold | **MIT** (`LICENSE` du zip) | oui | non (mention MIT) | oui (code) ; **ne pas vendre les images seules** |
| godot-pixel-effect — henrysoftware | CC0 | oui | non | oui |
| free-pixel-magic-sprite-effects — craftpix | craftpix free | oui | non | **non** |
| craftpix battleground 298993 | craftpix free | oui | non | **non** |
| craftpix 4 nature backgrounds 593685 | craftpix free | oui | non | **non** |
| craftpix vampires locations 889507 | craftpix free | oui | non | **non** |
| craftpix animated magic book 809047 | craftpix free | oui | non | **non** |
| free-demon-characters — craftpix | craftpix free | oui | non | **non** |
| 400 Sounds Pack — Chequered Ink | site officiel | oui | non | **non** (tel quel) |
| FreeSFX — **auteur à confirmer (§1.3)** | inconnue | ? | ? | ? |
| 28 High Quality 16-bit RPG Music — HydroGene | itch (`readme.txt` du zip) | oui | non | oui |
| **xDeviruchi 16-bit Fantasy & Adventure** | PDF embarqué | oui | **OUI (§1.2)** | **non** |
| `monsters_2026_09/` Golems — MonoPixelArt | itch | oui | non | **non** |
| `monsters_2026_09/` FlyingForestEnemies — MonoPixelArt | itch | oui | non | **non** |
| `monsters_2026_09/` Peacock — Pixeline | itch | oui | non | **non** |
| `monsters_2026_09/` Enemies Pack (SunnyLand) — ansimuz | **CC0** (PDF du zip) | oui | non | oui |
| `monsters_2026_09/` **Duelyst** — Counterplay / screensmith | **CC0** (§1.4) | oui | non | oui (hors marques) |

**Licence craftpix** (https://craftpix.net/file-licenses/), qui couvre 6 packs :

> « You are permitted to use the resources in any number of personal and
> commercial projects » · « No attribution or link back to this site is
> required » · « You can NOT resell the art source files »

Elle interdit aussi explicitement d'entraîner une IA sur ces fichiers.

### Note sur « pas de modification »

Golems, FlyingForestEnemies et Peacock interdisent littéralement la
*modification*. Découper une feuille pour l'intégrer est l'usage normal attendu
d'un spritesheet ; le risque réel serait de **republier les feuilles découpées
comme pack d'assets**, ce que nous ne faisons pas.

---

## 3. Crédits à afficher dans le jeu

Un seul est **obligatoire** ; les autres sont de courtoisie et coûtent une ligne.

```
Musiques : Original music by Marllon Silva (xDeviruchi)   [OBLIGATOIRE]
           HydroGene — 16-bit RPG Music
Effets   : BDragon1727 · CodeManu · DavitMasia · ansimuz · Pipoya
Décors   : craftpix.net · deep-fold (PixelSpace, MIT)
Unités   : Pixel Frog (Tiny Swords) · Zerie · MonoPixelArt · Pixeline
           Duelyst © Counterplay Games, libéré en CC0
```

---

## 4. Où va chaque pack dans le jeu

| Destination | Contenu | Provenance |
|---|---|---|
| `assets/units/` | silhouettes animées, boss | Tiny Swords, Tiny RPG 02, Golems, FlyingForest, Peacock, SunnyLand, Duelyst |
| `assets/fx/` | 45 feuilles de sorts + HD + Pipoya | Effect and FX Pixel, Free Pixel Effects, VFX Free Pack, Pipoya, explosion pack 1 |
| `assets/terrain/`, `assets/ui/` | tuiles, 9-tranches | Tiny Swords |
| `assets/backdrops/` | 4 fonds d'acte + 2 fonds spatiaux | craftpix, deep-fold |
| `assets/portraits/` | 8 démons × 4 expressions + grille de têtes | free-demon-characters |
| `assets/sfx/`, `assets/music/` | sons et musiques | 400 Sounds, FreeSFX, HydroGene, xDeviruchi |

Détail des feuilles et des pièges de découpe : mémoire projet `assets.md`.

---

## 5. Les 47 archives du 2026-09-26 (`raw_assets/packs_2026_09_26/`)

Audit du chantier A2. Même méthode : le fichier embarqué fait foi, sinon
« inconnue ». **13 archives portent un fichier de licence**, les autres non.

### 5.1 Ce qui bloque, en une ligne chacun

| Pack | Problème | Conséquence |
|---|---|---|
| **MAGE ICONS BIG PACK (Batareya)** | **aucun fichier de licence** dans le .rar | 42 des 60 icônes en dépendent — voir §1.5 |
| **Mage Voice Pack (John Carroll)** | pas de licence, l'auteur demande à être prévenu | un courriel avant publication — §1.6 |
| **Essentials / Essentials Pre-Render** | aucun fichier de licence, origine non établie | non extraits, rien ne repose dessus |
| **Phoenixling Sprite Sheet.json** | **le .png n'a pas été livré** | inutilisable en l'état — à retélécharger |

Tout le reste est exploitable commercialement.

### 5.2 Tableau des licences

Légende — Redistribution = a-t-on le droit de rediffuser **les fichiers sources**.
« src » dans la colonne Licence = fichier de licence lu dans l'archive.

| Pack | Licence | Commercial | Crédit | Redistribution sources |
|---|---|---|---|---|
| Monsters_Creatures_Fantasy — luizmelo | itch | oui | non | **non** |
| **Evil Wizard — luizmelo** | **CC0** (src `License.txt`) | oui | non | oui |
| **Fire Worm — luizmelo** | **CC0** (src `License.txt`) | oui | non | oui |
| **Ghoul Pixel Monsters Vol.4 — elesrech** | royalty-free (src `LICENSE.txt`) | oui | non (appréciée) | **non** |
| **Lords Of Pain (DEMO) — trevor-pupkin** | src `Licence.txt` | oui | non | **non** |
| **ttrpg_legend TOO MANY CHARACTERS — Ddant1100** | src `[--Read me first--].txt` | oui | **OUI (§5.4)** | **non** ; **IA interdite** |
| **free-gorgon — craftpix** | craftpix (src `Licens.txt`) | oui | non | **non** |
| **free-slime-mobs — craftpix** | craftpix (src `License.txt`) | oui | non | **non** |
| **Free-Animated-Explosions — craftpix** | craftpix (src `license.txt`) | oui | non | **non** |
| **Free Warlock Skills — craftpix** | craftpix (src `license.txt`) | oui | non | **non** |
| **Free 50 Aeromancer Skills — craftpix** | craftpix (src `license.txt`) | oui | non | **non** |
| **Free-RPG-Night-Elf-Skill-Icons — craftpix** | craftpix (src `license.txt`) | oui | non | **non** |
| Barbarian_Free / EarthMage_Free / FireMage_Free — captaincatsparrow | craftpix (même arborescence, `license.txt`) | oui | non | **non** |
| **MAGE ICONS BIG PACK — Batareya** | **INCONNUE (§1.5)** | **?** | **?** | **?** |
| **Mage Voice Pack — John Carroll** | readme seul (§1.6) | oui | non (demandé : prévenir) | **non** |
| Blue Witch — 9e0 | itch | oui | non | **non** |
| NightBorne — creativekind | itch | oui | non | **non** |
| npc-mage-free (mage_guardian) — creativekind | itch | oui | non | **non** |
| boss_demon_slime — chierit | itch | oui | non | **non** |
| Undead executioner — darkpixel-kronovi | itch | oui | non | **non** |
| Mecha-stone Golem — darkpixel-kronovi | itch | oui | non | **non** |
| Small Monster / Slime / Fairy / Free Tank Mushroom | itch | oui | non | **non** |
| Free Sprites — robertpinero | itch | oui | non | **non** |
| Tiny RPG Character Pack 01 — Zerie | itch | oui | non | **non** |
| EPIC RPG World (FREE Demo) — rafaelmatos | itch (src READ ME, notes d'usage) | oui | non | **non** |
| Pipoya TimeMagic / LightPillar / Bell | pipoya.net | oui | non | oui si **gratuite** ; revente interdite |
| Dark VFX 01-02 — pimen | itch | oui | non | **non** |
| Menu Buttons — nectanebo | itch | oui | non | **non** |
| dungeonmode — datagoblin | itch (police + tuiles ASCII) | oui | non | **non** |
| Wood Elves — lornn | itch | oui | non | **non** |
| free_character_1_20 — cogabushi | itch | oui | non | **non** |
| **Essentials / Essentials Pre-Render** | **INCONNUE** | **?** | **?** | **?** |
| **Phoenixling** | sans objet — **image absente** | — | — | — |
| Cacodaemon / Fox (PNG nus) — elthen | itch (§5.5) | oui | **probable** | **non** |

### 5.3 Les cinq `ttrpg_legend` sont le MÊME fichier

Les cinq archives `ttrpg_legend_too-many-charaters_1.0*.zip` (230 Mo chacune,
1,15 Go au total) ont le **même CRC32 de données : `10AFB580`**. Ce sont cinq
téléchargements du même pack, que le navigateur a suffixés `(1)` à `(4)`.

Il n'y a donc **qu'un seul pack ttrpg_legend**, pas cinq. Les quatre copies
peuvent être supprimées : 920 Mo récupérés. La demande d'Alexis portait bien sur
cinq pages itch différentes (`ttrpg-legay-characters-2`, `-3`, `-4`, `-5`…) mais
c'est **cinq fois le même téléchargement** qui est arrivé — les quatre autres
packs restent à récupérer s'ils sont voulus.

### 5.4 Deuxième crédit obligatoire

ttrpg_legend rejoint xDeviruchi (§1.2) parmi les crédits **imposés** :

> Please Credit Me with : [https://ddant1100.itch.io] or [Ddant1100]

Le même fichier interdit en plus un usage précis :

> YOU CAN'T: Use in Any Project related to NFTs or **IA Picture Generator**

Rien de gênant ici — mais il ne faut pas donner ces images à un générateur
d'images, ni les inclure dans un corpus d'entraînement. La licence craftpix
porte la même interdiction.

### 5.5 Les deux PNG nus

`Cacodaemon Sprite Sheet.png` et `Fox Sprite Sheet.png` sont arrivés **sans
archive ni licence**, sortis de leur pack. Ils viennent d'elthen
(`elthen.itch.io`), dont les packs demandent habituellement un crédit et
interdisent la revente. En l'absence du fichier d'origine, on suppose le cas le
plus strict : **crédit à afficher**, pas de redistribution.

---

## 6. Inventaire des archives du 2026-09-26

Assez précis pour choisir sans rouvrir les archives. `occ` = part de la hauteur
de case réellement occupée après extraction (voir `tools/assets/probe_sheets.py`).

### 6.1 Monstres animés — EXTRAITS dans `assets/units/`

72 feuilles écrites par `tools/assets/extract_packs_2026_09_26.py`.

| id | Créature | Case | Animations (frames) | occ |
|---|---|---|---|---|
| `flyingeye` | œil volant ailé | 56 | walk 8, attack 8, hurt 4, death 4 | 0,55-0,59 |
| `goblin2` | gobelin à dague | 88 | idle 4, walk 8, attack 8, hurt 4, death 4 | 0,41-0,52 |
| `mushroom` | champignon | 71 | idle 4, walk 8, attack 8, hurt 4, death 4 | 0,52-0,63 |
| `skeleton2` | squelette à bouclier | 98 | idle 4, walk 4, attack 8, hurt 4, death 4, **shield 4** | 0,47-0,58 |
| `evilwizard` | mage ennemi | 94 | idle 8, walk 8, attack 8, hurt 4, death 5 | 0,53-0,72 |
| `fireworm` | ver de feu | 77 | idle 9, walk 9, attack 16, hurt 3, death 8 | 0,56-0,70 |
| `ghoul` | goule | 45 | idle 10, walk 6, attack 10, hurt 5, death 7 | 0,42-0,56 |
| `gorgon` | gorgone | 128 | idle 7, walk 13, attack 16, hurt 3, death 3 | 0,66-0,73 |
| `bluewitch` | sorcière bleue | 48 | idle 6, walk 8, attack 5, hurt 3, death 10 | 0,77-0,98 |
| `smallmonster` | plante-monstre | 81 | idle 6, walk 6, attack 13, death 8 | 0,41-0,47 |
| `mageguardian` | gardien-totem flottant | 58 | idle 4, attack 6, death 4 | 0,97-1,00 |
| **`demonslime`** | **BOSS** slime démoniaque | 210 | idle 6, walk 12, attack 15, hurt 5, death 22 | 0,48-0,59 |
| **`nightborne`** | **BOSS** épéiste d'ombre | 77 | idle 9, walk 6, attack 12, hurt 5, death 23 | 0,36-0,84 |
| **`executioner`** | **BOSS** bourreau à faux | 174 | idle 8, attack 12, death 9, **summon 5** | 0,78-0,96 |

`skeleton2_shield` (parade) et `executioner_summon` (invocation) sont des poses
en plus, utilisables par un comportement dédié.

### 6.2 Effets — EXTRAITS dans `assets/fx/`

| nom | Source | Case | Frames | Pour |
|---|---|---|---|---|
| `dark_soul` | Dark VFX 1, ligne 1 | 40×32 | 10 | âme violette volante — **premier effet d'OMBRE du jeu** |
| `dark_vanish` | Dark VFX 1, ligne 2 | 40×32 | 6 | fantôme blanc qui se dissout |
| `dark_swirl` | Dark VFX 2 | 48×64 | 15 | volute sombre |
| `timemagic` | Pipoya TimeMagic | 192 | 15 | **horloge verte** — le sort de vitesse n'avait aucun visuel propre |
| `lightpillar` | Pipoya LightPillar | 192 | 10 | colonne de lumière jaune |
| `bell` | Pipoya Bell | 192 | 15 | cloche lumineuse |

### 6.3 Disponible et NON extrait — à la main des autres chantiers

**Icônes de sorts** (512×512, une par fichier, fond transparent) :

| Pack | Nombre | Style |
|---|---|---|
| MAGE ICONS BIG PACK (Batareya) | **250** | icônes magiques, le plus gros — **licence §1.5** |
| Free Warlock Skills | 50 | démoniaque, violet/vert |
| Free 50 Aeromancer Skills | 50 | air, volutes blanches peu contrastées |
| Free-RPG-Night-Elf-Skill-Icons | 50 (+1 psd) | nature, lune, cascades |
| FireMage_Free | 40 | feu |
| EarthMage_Free | 40 | terre, roche |
| Barbarian_Free | 40 | personnages en pied, illisibles en petit |

**Portraits et personnages d'histoire** :

| Source | Contenu | Taille |
|---|---|---|
| `ttrpg_legend` `Faceset/` | **~200 avatars** nommés par rôle et race (`avatar_highwizard_human_woman_01`, `avatar_knight_…`, `avatar_demon_…`) | 512×512 |
| `ttrpg_legend` `Full Art/` | les mêmes en pied, très haute définition | jusqu'à 3044×6686 |
| `free_character_1_20` (cogabushi) | 20 personnages, versions avec et sans ombre | ~1520×1849 |
| `free_character_1_20` `background/` | 5 fonds, nets et flous | 1920×1080 |
| `Wood Elves` (lornn) | **41 décors** elfiques (bibliothèque, palais, rivière, taverne…) | 1792×1024 |

Les `highwizard_*` de ttrpg_legend sont **exactement le portrait humain de mage
qui manquait** : 3 hommes, 3 femmes, dont une « stellar ».

**Interface** :

| Source | Contenu |
|---|---|
| Menu Buttons | 13 boutons larges 600×200 (Play, Settings, Quit…) + 16 carrés 200×200 (pause, son, retour…), en version colorée et noir et blanc, **déjà découpés un par un** |
| dungeonmode | 2 polices `.ttf`, planches ASCII, palette |

Ces boutons portent **leur texte anglais en dur** dans l'image : utilisables tels
quels pour les icônes carrées, à éviter pour les boutons larges si le jeu doit
être en français.

**Terrain** : `EPIC RPG World — Ancient Ruins` fournit `Tileset-Terrain2.png`
(1152×448), des murs sur 2 tuiles de haut, des terrains animés sur 8 frames, un
autel, une fontaine, un marchand animé. Le `0-READ ME.txt` du pack explique les
raccords — à lire avant d'y toucher.

### 6.4 ÉCARTÉ, et pourquoi

| Pack | Raison |
|---|---|
| **Lords Of Pain** (539 PNG) | isométrique, **16 directions de boussole** par animation. Le jeu est en vue de côté : il faudrait jeter 15/16 du pack pour un style 3D pré-rendu qui ne raccorde avec aucune unité existante |
| **Essentials Pre-Render** (29 PNG) | **doublon strict** de `Essentials.zip`, dont le dossier `Pre-Render/` contient les mêmes fichiers |
| **Essentials** (46 PNG) | effets d'interface de combat au tour par tour (Guard, Steal, Scan, AggroUp), sans rapport avec le jeu ; et licence inconnue |
| **ttrpg_legend ×4** | copies identiques du cinquième (§5.3) |
| **Free Sprites** (28 PNG) | battlers RPG Maker vus de face, immobiles, résolutions incohérentes (berger allemand photo-réaliste à côté d'un gobelin 32 px) |
| **Fairy** (3 PNG) | 32×32, 8 frames, **une seule pose de vol** — ni attaque ni mort, insuffisant pour une entrée d'`AnimCatalog` |
| **Free Tank Mushroom** (5 PNG) | idle seul, 5 frames |
| **Slime / gorgon 2 et 3** | mêmes silhouettes recolorées ; `EnemyDef` sait déjà teinter un sprite |
| **Mecha-stone Golem** | la planche est exploitable (1000×1000) mais le pack livre surtout des `.aseprite` ; le golem laser est déjà couvert par un boss existant |
| **Free-Animated-Explosions** (110 PNG) | 10 explosions en frames séparées — le jeu en a déjà 5, dont deux HD |
| **Cacodaemon / Fox** (PNG nus) | sans licence ni archive (§5.5) ; à rapatrier proprement avant usage |
| **Phoenixling** | **le .png manque**, seul le .json est arrivé |
| **Mage Voice Pack** | **aucun PNG** : 130 .wav, traités séparément dans `assets/voice/` |

---

## 7. Crédits — mise à jour

Deux crédits sont **obligatoires**, plus une courtoisie demandée.

```
Musiques   : Original music by Marllon Silva (xDeviruchi)      [OBLIGATOIRE]
Personnages: Ddant1100 — https://ddant1100.itch.io             [OBLIGATOIRE]
Voix       : John Carroll — johncarroll.itch.io                [demandé : le prévenir]
Monstres   : luizmelo · elesrech · chierit · creativekind · darkpixel-kronovi
             9e0 · elthen · craftpix.net
Effets     : pimen (Dark VFX) · Pipoya · BDragon1727 · CodeManu · DavitMasia · ansimuz
Icônes     : Batareya (SOUS RÉSERVE §1.5) · craftpix.net
Décors     : lornn (Wood Elves) · cogabushi · rafaelmatos · craftpix.net · deep-fold
Interface  : nectanebo (Menu Buttons) · datagoblin (dungeonmode)
```
