# Index des assets et de leurs licences

Audit du 2026-09-21 (chantier A). Couvre les **23 entrées** de `raw_assets/`
(22 archives + le dossier `monsters_2026_09`, qui en contient 6).

Méthode : le fichier de licence **embarqué dans l'archive** fait foi quand il
existe (extrait et lu) ; sinon la page officielle du pack. Les pages itch.io
refusent la lecture automatique (HTTP 403) : les clauses issues d'itch viennent
d'extraits de recherche et sont signalées comme telles.

---

## 1. À RÉGLER AVANT PUBLICATION COMMERCIALE

Trois points, du plus gênant au plus simple.

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
