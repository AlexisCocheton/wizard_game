# Banc d equilibrage

```bash
Godot --headless --path . tools/sim_balance.tscn
```

Joue chaque niveau 30 fois avec des graines differentes et rapporte un taux de
victoire. Une seule partie ne prouve rien : les tirages de cartes et la
composition des vagues font varier le resultat du simple au double.

## Reperes vises

| Mesure | Cible | Pourquoi |
|---|---|---|
| **Victoires, TOUT niveau** | **60 a 95 %** | voir ci-dessous |
| Massacre | vague 4 a 8 en moyenne | assez long pour construire un deck |
| Taux d interception | > 75 % | sous 70 %, le joueur subit |
| Temps passe a incanter | < 60 % | au-dela il regarde au lieu de jouer |

### Pourquoi une seule fenetre pour les sept niveaux

Ce tableau donnait deux cibles differentes pour les niveaux 1 et 2 (70-85 et
50-70). Elles dataient d une epoque a deux niveaux et n ont jamais ete etendues
aux cinq suivants : chaque chantier visait donc une fenetre 60-95 qui n etait
ecrite NULLE PART, et se la transmettait de rapport en rapport.

**Sous 60 %**, le joueur rejoue le meme niveau plus d une fois sur trois, et un
jeu mobile se ferme a ce moment-la. **Au-dessus de 95 %**, le niveau ne demande
plus de choix : mesure faite sur lvl_03 a 29 victoires sur 30, la cause etait que
cinq de ses dix monstres craignaient le feu et qu un tiers du deck en etait — le
joueur ne pouvait pas se tromper d element.

La difficulte se lit dans la PROGRESSION a l interieur de la fenetre, pas dans
des cibles separees : les derniers niveaux se tiennent vers le bas (63 %), les
premiers vers le haut (83 %).

### Variance : ne jamais regler sur un seul banc

Deux passages du banc sur un contenu IDENTIQUE ont rendu 66,7 % puis 96,7 % sur
lvl_02. Trente parties ne suffisent pas a departager deux reglages proches. Une
correction ne se juge que sur un ecart FRANC, et un banc lance pendant que
d autres processus Godot tournent mesure une machine chargee, pas le jeu.

## Les leviers, du plus fort au plus faible

1. `GameConfig.ENEMY_SPEED_SCALE` — la fenetre de reaction. Le levier le plus
   puissant : 0,72 -> 0,62 a fait passer le niveau 1 de 53 % a 77 % de victoires.
2. `GameConfig.MAGE_MAX_HP` — la tolerance a l erreur.
3. `GameConfig.DRAW_INTERVAL` — le nombre de reponses disponibles.
4. Les `spawn_delay` des vagues — un groupe serre est bien plus dur que le meme
   nombre de monstres etale.
5. Les PV et la puissance des monstres — le levier le plus fin.

## Ce que le banc a revele

- La **pioche suivait le temps reel** alors que les monstres suivaient le temps
  accelere : a x4, le joueur se retrouvait les mains vides au pire moment.
- Les monstres apparaissaient **disperses sur toute la largeur**, donc les sorts
  de zone ne touchaient jamais plus d une cible. Ils descendent maintenant par
  couloirs.
- L **Ombre etait invulnerable** la moitie du temps sur un cycle de 2,5 s, plus
  long que la plupart des incantations. Elle encaisse desormais 40 % des degats
  en phase, et reste visible en transparence.
- Le **niveau 2 envoyait le double de PV** du niveau 1 avec le meme deck.

- Un **Berserker s enrageait a chaque frame** passee dans une zone de degats
  (la zone frappe a chaque image) : rage maximale en un cinquieme de seconde.
  La rage se compte maintenant au plus une fois par `Enemy.ENRAGE_HIT_INTERVAL`
  (lvl_11 : 44 -> 73 victoires sur 90).

## Le bot du banc (chantier W7)

Le banc joue avec un bot qui doit ressembler a un joueur RAISONNABLE, pas a un
joueur parfait. Tous ses choix vivent dans `scripts/game/auto_pick.gd` (`AutoPick` ;
les parties headless des tests et le banc des objectifs les utilisent aussi). Le
geste (quelle carte, sur qui, ou poser une zone) y a ete deplace depuis `_try_play`
du banc (`AutoPick.try_play`), a l identique :

| Choix | Regle | Pourquoi |
|---|---|---|
| Amelioration de sort | identite du sort en forte, sinon vitesse forte, sinon identite legere, sinon la premiere | l offre est melangee : "la premiere" etait une voie au hasard (lvl_16 43 -> 59 / 90) |
| Carte a la montee de niveau | la premiere proposee, sauf si les monstres deja croises la resistent | chaque case est un tirage du pool ; "sort qui frappe puis rarete" coutait 11 a 21 points (deck referme sur une carte) |
| Cible | le monstre le plus avance que le halo d un Gardien-totem ne protege pas | viser un monstre intouchable videait la main sur la cour des rois morts (lvl_20 29 -> 59 / 90) |

Options (apres `--`) : `--niveaux=lvl_16,lvl_20`, `--parties=60`,
`--massacre=0`, `--graine=30` (decale les graines), `--premiere` (ancien bot,
ou `--premiere=cartes` / `=ameliorations`), `--visee-naive`, `--sans-vagues`.
Plusieurs bancs peuvent tourner en parallele sur des niveaux differents.

**Le Massacre depend du profil.** Hors campagne, le pool de montee de niveau est
fait des cartes OBTENUES. Le banc complet mesure le Massacre APRES avoir joue
les 21 niveaux, avec les cartes que le bot y a prises (13,4 vagues avant W7) ;
lance seul (`--niveaux=none`), il part d un profil neuf et le pool est vide
(7,7 vagues). Comparer deux Massacres mesures de la meme facon.

**Regle du livre (02/10)** : distribuer un deck n obtient plus rien ; une carte
est obtenue si elle est dans le deck d un niveau OUVERT ou prise en combat. Le
banc ouvre donc, avant de mesurer un niveau, ce niveau et tous ceux qui le
precedent dans l ordre de jeu (`open_levels_up_to`). **Les chiffres de Massacre
mesures avant et apres cette regle ne sont pas comparables** (le pool n est plus
le meme) ; les niveaux de campagne, dont le pool ne lit pas le profil, ne
bougent pas.

Le rapport par niveau donne aussi : vitesse retiree par source (cumul et par
vague), vague de la mort, cartes et ameliorations prises, temps pour abattre
le boss, et l adequation du deck au lieu (facteur moyen pondere par les PV).

## Determinisme (chantier W8)

**A graine egale, deux processus rendent le meme resultat**, partie par partie.
Ce n etait pas le cas : le spawner (couloirs, cotes d apparition), la Pluie de
meteores, l esquive, la place des allies invoques et le pont d une riviere
tiraient au hasard SANS la graine de la partie. Ils passent tous par
`RunState.world_rng`, que `RunState.set_seed()` fixe en meme temps que la pioche
(un second generateur, pour que la pioche d une graine ne change pas selon la
facon de jouer). Le jeu reel ne seme jamais : rien n y change. Verrouille par
`tests/unit/test_objective_bench.gd` (le hasard global est re-seme entre deux
parties de meme graine, comme dans un autre processus ; chaque source sabotee le
fait rougir).

Consequences : un ecart entre deux bancs de meme graine vient du CODE ou du
CONTENU, jamais du tirage. Le hasard reste dans la graine : 30 parties ne
departagent toujours pas deux reglages voisins (variance d une graine a
l autre), il en faut 60 a 90.

## Le banc des objectifs

```bash
Godot --headless --path . tools/objective_bench.tscn
Godot --headless --path . tools/objective_bench.tscn -- --niveaux=lvl_03,lvl_04 --parties=60
```

Pour chaque objectif de niveau : N parties (60 par defaut, ce que
`test_level_progression` exige) avec le bot du banc, ORIENTE vers l objectif
mesure. Rend, par niveau et dans l ordre du niveau : le nombre de reussites, le
taux, le rang mesure (1 = le plus facile), les victoires, la politique jouee, le
verdict du classement (strictement decroissant, chaque objectif reussi et rate),
et la ligne prete a coller dans `MESURES`. Toutes les lignes sont recopiees a la
fin, sous `=== A COLLER DANS MESURES ===`.

Options (apres `--`) : `--niveaux=lvl_01,lvl_02` (defaut : tous, ordre de jeu),
`--objectifs=obj_a,obj_b` (re-mesurer un objectif retouche ; la ligne est marquee
PARTIELLE), `--parties=60`, `--graine=0` (partie i : graine `1000 + 37 (graine + i)`,
celles du banc d equilibrage), `--detail` (une ligne par partie avec son empreinte :
deux sorties a comparer).

**En parallele** : un processus par groupe de niveaux, puis concatener les
lignes « A COLLER ». Avant chaque partie, le profil est remis a neuf puis le
niveau et ceux qui le precedent sont ouverts : le resultat ne depend ni de
l ordre ni du decoupage.

```bash
for g in lvl_01,lvl_02,lvl_08,lvl_09,lvl_17 lvl_18,lvl_03,lvl_04,lvl_19,lvl_20 \
         lvl_05,lvl_06,lvl_21,lvl_07,lvl_10 lvl_11,lvl_12,lvl_13,lvl_14,lvl_15,lvl_16; do
  Godot --headless --path . tools/objective_bench.tscn -- --niveaux=$g > banc_$g.txt &
done; wait
```

Duree mesuree : environ 1,5 s par partie ; les objectifs a politique neutre d un
niveau partagent leurs parties (meme graines, memes parties : le banc est
deterministe).

**La politique par cle** est un tableau en tete de la section « LE BOT QUI VISE
UN OBJECTIF » de `scripts/game/auto_pick.gd` (`AutoPick.politique_pour`). En bref :
jouer d abord la carte / l element / la carte la plus nombreuse demandes (et les
prendre aux montees) jusqu au compte ; ne jamais jouer ni prendre une carte, un
tag, un effet, une legendaire interdits ; ne prendre aucun passif ; viser d abord
l espece qui ne doit pas toucher, les volants, les monstres releves ; ne jamais
frapper l espece dont le coup est requis, ni une garde de renvoi levee ; poser
ses zones sur le plus gros groupe de l espece a tuer d un seul sort ; laisser
marcher le monstre jusqu a sa distance, puis le viser. Les paris de fin de
combat (vitesse, chrono, intact, multi_kill) : bot tel quel. Une cle ajoutee au
moteur sans politique documentee fait rougir `test_objective_bench`.

## Memoire : le banc libere a chaque image comme le moteur (03/10)

Le banc des objectifs PLANTAIT sur lvl_21, objectif sans sort de feu, partie 30
(graine 2110) : « Element limit reached », memoire epuisee, signal 11. Cause :
une partie de banc se joue tout entiere dans UNE image moteur, et le moteur ne
libere ce qui est `queue_free` qu a la fin d une image. La main du HUD, recreee a
chaque carte jouee, les monstres morts, s accumulaient jusqu a la fin de la
partie. Cette partie-la durait jusqu a la limite de 900 s : le bot avait exile
par Epuration toutes ses communes (ses seuls degats qui ne sont pas du feu), le
Sceau de Tombol, immobile, ne pouvait plus etre blesse, et les cartes sans degats
tournaient a x5 : 17 000 cartes de main, 400 000 objets.

Les trois bancs (`objective_bench`, `sim_balance`, `sim_diag`) et la partie du
smoke appellent maintenant `GameController.flush_freed()` apres chaque image.
Effet de bord voulu : la partie simulee est FIDELE au jeu, ou un monstre mort ou
arrive au contact est libere a la fin de l image. Ce n etait pas le cas, et
cela cachait un vrai defaut de jeu (le filtre de sbires de `Enemy._do_summon`
plantait sur un sbire libere : en jeu, le Sceau n invoquait plus apres la
premiere mort d un squelette). lvl_21 re-mesure en entier : 57 / 55 / 13, comme
avant.

Garde-fou : une partie qui depasse `SimBalance.PLAFOND_OBJETS` objets de plus
qu a son depart est ARRETEE, comptee perdue, et signalee (`ALERTE MEMOIRE`).
`--detail` affiche, par partie, le pic d objets (`objets +N`).

## Chantier W8 (combat) : vagues qui trainent, protecteurs, devoreurs, paliers

Banc complet (21 niveaux x 30 parties + Massacre x 20, `--sans-vagues`), meme
machine, banc deterministe : `main` avant fusion contre la branche W8.

| | avant | apres |
|---|---|---|
| Victoires, tous niveaux | 590 / 630 | 594 / 630 |
| lvl_20 (Gardiens-totems) | 23 / 30 | 27 / 30 |
| Autres niveaux | — | identiques au point pres |
| Ameliorations par partie (moyenne des 21) | 5,78 | 5,78 |
| Vagues ecourtees par partie (campagne) | — | 0,00 partout |
| Massacre | vague 14,4 | vague 13,9 |

Ce que disent ces chiffres :

- **Les paliers 3 a 5** (48, 80, 120 lancers) ne sont jamais atteints en campagne :
  le nombre d ecrans d amelioration par partie ne bouge pas. Ils servent les
  longues parties (Infini, Massacre), c est voulu.
- **La vague qui traine** : un premier essai a delai FIXE (40 s apres la derniere
  apparition) a fait tomber lvl_16 de 27 a 16 victoires (1,67 vague ecourtee par
  partie) : son Echo d enclume, a 28 px/s, mettait 95 s a traverser et etait
  simplement en route. Le delai suit desormais la traversee du monstre MOBILE le
  plus lent (x1,25, plancher 40 s) : en campagne le bot n ecourte plus aucune
  vague, le minuteur ne mord que sur ce qui CALE.
- **Le pat d aura** : un premier essai (tous les monstres frappables couverts
  pendant 4 s) cassait aussi les Gardiens-totems qui MARCHENT : lvl_20 passait de
  23 a 30 / 30, hors fenetre. Il ne vaut plus que pour des proteges qui ne
  descendent pas (campeurs, tours immobiles) : lvl_20 27 / 30 (90 %, dans la
  fenetre). La part des +4 qui revient a la dissipation (qui coupe maintenant
  les auras) et celle qui revient au pat n ont pas ete separees.
- **La force des devoreurs** ne fait bouger aucun niveau de campagne au banc ;
  le Massacre perd 0,5 vague (14,4 -> 13,9), effet cumule de la force des
  devoreurs, des vagues ecourtees et des paliers, non separe.
- Le banc releve maintenant les **vagues ecourtees** par niveau.

Les garde-fous sont dans `tests/unit/test_balance.gd` : ils verrouillent les
rapports (pas de saut superieur a x2 entre deux vagues, enchainement des niveaux,
pioche suffisante). Le banc reste la mesure de verite.

## Vague 8 : l incantation nettement plus longue (`GameConfig.CAST_TIME_SCALE`)

Demande du co-auteur : « augmente significativement le temps de lancement de
tous les sorts ». Le premier essai, x2,25, faisait tomber cinq niveaux sous
60 %. Banc complet (21 niveaux x 60 parties, deterministe) pour chaque valeur :

| `CAST_TIME_SCALE` | victoires / 1260 | niveaux les plus bas (sur 60) |
|---|---|---|
| 1,5 (avant) | 1192 | lvl_05 41, lvl_13 42, lvl_11 49 |
| 1,8 | 1146 | lvl_18 37, lvl_11 39, lvl_13 43 |
| **1,9 (retenu)** | **1135** | lvl_13 37, lvl_18 37, lvl_11 38 |
| 1,95 | 1115 | lvl_11 36, lvl_13 37, lvl_20 38 |
| 2,0 | 1106 | lvl_13 31, lvl_11 33, lvl_18 34 |
| 2,25 | 987 | lvl_18 15, lvl_20 19, lvl_11 22, lvl_13 34, lvl_14 35 |

1,8 a 1,95 sont comptes AVEC la correction de w13_4 ci-dessous, 2,0 et 2,25
sans. 1,95 passe encore le repere, mais pile (lvl_11 36 / 60) et lvl_20 y perd
neuf parties : la courbe plonge entre 1,9 et 2,0, et le bot joue mieux qu un
doigt.

- **Le pentacle (lvl_13) ne dependait pas de l incantation** : 34 / 60 a x1,8
  comme a x2,25. Toutes ses defaites tombaient dans w13_4, qui sautait x2,28 sur
  la vague precedente, et le mage y avait la MAIN VIDE presque chaque fois qu il
  n incantait pas : le niveau est limite par la pioche. Difficulte de w13_4
  1,45 -> 1,25 (x1,97) : 34 -> 43 a x1,8, 29 -> 37 a x1,9. Retirer le Totem
  ancien de la vague a la place ne changeait rien (34 / 60). Verrouille par
  `test_balance` (regle du saut x2 etendue a lvl_13).
- **Temps passe a incanter** : au-dessus du repere de 60 % sur 19 niveaux sur
  21 a x1,9 (77 a 97 %), et deja sur 19 a x1,5 (62 a 86 %). C est la demande
  elle-meme ; le repere est a revoir avec le co-auteur, pas a corriger ici.
- **Massacre** (20 parties, banc lance seul apres ouverture des 21 niveaux,
  `--niveaux=lvl_16 --parties=0 --massacre=20`) : vague 12,1 a x1,9 contre 7,8
  a x2,25, mesures de la meme facon.

Incident de mesure : douze bancs lances ensemble se sont figes apres leur
premier niveau, processus vivants et CPU quasi nul, pendant deux heures. Cause
non etablie ; le suspect est un `tail -F` qui suivait leurs sorties. Relances
sans lui, ils ont fini en quinze minutes, avec des resultats identiques (banc
deterministe). Pour suivre un banc : compter les lignes de temps en temps, ne
pas garder ses sorties ouvertes.
