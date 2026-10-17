# Banc de contrôle de la vague 10 (chantier C2, 17/10)

**Les chiffres qui font foi sont ceux de la [mesure finale (C8)](#mesure-finale-c8-1710), en fin de document.**
Les sections de C2 et de C7c sont gardées pour l'historique.

Mesure faite sur main d6668a0, qui contient toute la vague 10 (A1 à A4, B1a, B1b, B2, B3, B4, C1).
C3 (sortie commune) et C6 (portraits) ont été fusionnés ensuite sans toucher au jeu ; un contrôle après fusion rend les mêmes chiffres.
Le bot est `scripts/game/auto_pick.gd`, et les parties sont déterministes.
Les tirages de campagne suivent les mêmes groupes de processus que B2.

**Attention : le profil en mémoire garde les cartes prises en combat**, et le pool de montée de niveau = cartes obtenues + communes de l'acte.
Pour comparer deux mesures, il faut donc garder les mêmes groupes de processus.
Une annexe jouée avant un niveau de campagne peut changer ce niveau : c'était le cas de `side_a2_atelier` avec la Lumière purifiante, voir plus bas (corrigé par C7c).

## Campagne (`tools/sim_balance.tscn`, 60 parties)

Colonnes :
- victoires avant B2, après B2, puis au contrôle C2 ;
- `inc` : temps passé à incanter ;
- `int` : interception ;
- `PV` : vitesse restante à la victoire ;
- boss : abattu / vu (durée moyenne).

| niveau | nom | av. B2 | ap. B2 | C2 | inc | int | PV | boss |
|---|---|---|---|---|---|---|---|---|
| lvl_01 | La lisière de Nuri | 60 | 60 | 60 | 72 % | 85 % | 223 | 60/60 (22,2 s) |
| lvl_02 | Le village pétrifié | 60 | 59 | 59 | 82 % | 86 % | 284 | 50/59 (24,6 s) |
| lvl_08 | La route du maire | 60 | 58 | 58 | 76 % | 84 % | 182 | 6/60 (24,9 s) |
| lvl_09 | Protéger le dirigeable | 59 | 58 | 58 | 57 % | 79 % | 233 | 57/59 (22,3 s) |
| lvl_17 | Les courants | 59 | 44 | 44 | 88 % | 45 % | 248 | 40/52 (12,1 s) |
| lvl_18 | Port de Haute-Nacelle | 39 | 41 | **36** | 88 % | 45 % | 221 | 41/55 (12,0 s) |
| lvl_03 | L'ossuaire de bordure | 60 | 56 | 56 | 74 % | 78 % | 231 | 15/60 (19,7 s) |
| lvl_04 | Le Grand Appel | 58 | 53 | 53 | 80 % | 56 % | 271 | 43/60 (39,1 s) |
| lvl_19 | Les fosses basses | 60 | 60 | 60 | 83 % | 98 % | 341 | 35/60 (28,9 s) |
| lvl_20 | La cour des rois morts | 56 | 60 | 60 | 81 % | 81 % | 294 | **0/60** |
| lvl_05 | Les forges sous Tombol | 56 | 60 | 60 | 73 % | 93 % | 477 | 60/60 (26,5 s) |
| lvl_06 | La cour brisée | 59 | 60 | 60 | 82 % | 81 % | 321 | 60/60 (7,6 s) |
| lvl_21 | Le pentacle | 58 | 58 | 58 | 89 % | 61 % | 313 | 58/58 (42,4 s) |
| lvl_07 | La forge de Vharn | 57 | 60 | 60 | 62 % | 59 % | 315 | 38/60 (24,1 s) |
| lvl_10 | Les fosses de Sesh | 60 | 58 | 58 | 79 % | 61 % | 285 | 54/58 (10,1 s) |
| lvl_11 | L'arène de Kaltek | 41 | 50 | 50 | 67 % | 57 % | 226 | 26/58 (9,8 s) |
| lvl_12 | Le temple d'Ymoa | 60 | 54 | 54 | 83 % | 51 % | 290 | 55/57 (9,3 s) |
| lvl_13 | Le pentacle brisé | 48 | 57 | 57 | 80 % | 52 % | 275 | 45/57 (19,8 s) |
| lvl_14 | La galerie des saisons | 60 | 60 | 60 | 48 % | 86 % | 411 | 60/60 (10,7 s) |
| lvl_15 | Le registre | 60 | 59 | 59 | 53 % | 60 % | 391 | 24/59 (22,3 s) |
| lvl_16 | Le siège vide | 47 | 60 | 60 | 72 % | 78 % | 376 | 44/60 (17,7 s) |
| **Total** | | **1177** | **1185** | **1180 / 1260** | moy. 74,7 % | moy. 70,3 % | moy. 296 | |

Repères :
- minimum lvl_18 à 36/60, puis lvl_17 à 44 et lvl_11 à 50 ;
- 14 niveaux sont à 58-60/60 pour le bot, qui joue mieux qu'un doigt sur ce terrain ;
- temps passé à incanter : de 48 % (lvl_14) à 89 % (lvl_21), médiane 79 %, au-dessus de 60 % sur 18 niveaux.

**Les boss rarement abattus alors que le niveau est gagné** : le boss touche le mage, puis le niveau se termine.
- lvl_20 (0/60) : l'Épéiste d'ombre a une vie de plus, et sa deuxième vie touche le mage à chaque partie.
- lvl_08 (6/60) : le Coagulé.
- lvl_03 (15/60) et lvl_15 (24/59).

## Quêtes annexes (60 parties, insérées après leur niveau d'ouverture)

| annexe | nom | victoires | inc | int | PV | boss | défaites par vague |
|---|---|---|---|---|---|---|---|
| side_a1_mesure | La mesure | 24 (40 %) | 72 % | 61 % | 135 | 21/60 | v4 ×36 |
| side_a2_atelier | L'atelier du rat | 34 (57 %) | 72 % | 46 % | 221 | 34/38 | v3 ×22, v4 ×4 |
| side_squire | L'écuyer du port | 39 (65 %) | 74 % | 34 % | 157 | 42/60 | v4 ×21 |
| side_fairy | La fée des fosses | 27 (45 %) | 78 % | 71 % | 177 | 5/53 | v2 ×2, v3 ×5, v4 ×26 |
| side_a3_tresor | Le trésor de Tombol | 29 (48 %) | 83 % | 71 % | 167 | 4/44 | v2 ×8, v3 ×8, v4 ×15 |
| side_a4_champion | Le champion de Kaltek | 34 (57 %) | 70 % | 58 % | 122 | 0/45 | v3 ×15, v4 ×11 |
| side_bluewitch | L'apprentie d'azur | 30 (50 %) | 67 % | 51 % | 162 | 3/44 | v3 ×16, v4 ×14 |
| side_a5_vitrine | La vitrine de Nuri | 26 (43 %) | 79 % | 63 % | 221 | 14/27 | v2 ×22, v3 ×11, v4 ×1 |
| **Total** | | **243 / 480 (50,6 %)** | moy. 74,4 % | moy. 56,9 % | moy. 170 | | |

`side_a1_mesure` est pile à la borne basse.
Le bot qui vise d'abord le Corniste doré gagne 59 fois sur 60, contre 30 pour le bot tel quel.
L'angle mort vient de sa visée « le plus avancé ».

## Massacre (20 parties, après lvl_16 joué 60 fois)

En moyenne la partie finit à la **17,5e vague** (de 8 à 29). Elle se termine :
- 2 fois sur un boss ;
- 3 fois sur un mini-boss ;
- 15 fois sur une vague ordinaire ;
- jamais au plafond.

Mondes de fin : act2 ×4, act3 ×7, act4 ×6, act5 ×3.

## Objectifs (`tools/objective_bench.tscn`, 60 parties)

Format : taux mesuré [MESURES du test].
Les 29 classements sont conformes (rang 1 plus facile que rang 2, plus facile que rang 3).
Aucun objectif n'est à 0/60 ni à 60/60.

| niveau | rang 1 | rang 2 | rang 3 | écart aux MESURES |
|---|---|---|---|---|
| lvl_01 | 52 [52] | 26 [26] | 9 [9] | — |
| lvl_02 | 58 [58] | 45 [45] | 31 [30] | +1 |
| side_a1 | 59 [59] | 15 [15] | 8 [8] | — |
| lvl_08 | 55 [55] | 22 [22] | 6 [6] | — |
| lvl_09 | 57 [56] | 14 [14] | 11 [11] | +1 |
| lvl_17 | 46 [46] | 37 [37] | 10 [10] | — |
| side_a2 | 39 [39] | 30 [30] | 10 [10] | — |
| lvl_18 | 34 [29] | 17 [18] | 11 [16] | +5 / −1 / −5 |
| side_squire | 41 [41] | 25 [25] | 5 [5] | — |
| lvl_03 | 47 [54] | 7 [16] | 2 [1] | −7 / −9 / +1 |
| lvl_04 | 42 [41] | 17 [20] | 9 [9] | +1 / −3 |
| lvl_19 | 58 [58] | 47 [49] | 10 [7] | −2 / +3 |
| side_fairy | 29 [29] | 7 [7] | 3 [3] | — |
| lvl_20 | 53 [53] | 37 [37] | 7 [7] | — |
| side_a3 | 28 [28] | 22 [22] | 4 [4] | — |
| lvl_05 | 56 [56] | 23 [24] | 11 [11] | −1 |
| lvl_06 | 59 [59] | 20 [20] | 2 [2] | — |
| lvl_21 | 50 [50] | 41 [41] | 7 [7] | — |
| lvl_07 | 59 [59] | 19 [19] | 9 [9] | — |
| lvl_10 | 56 [56] | 34 [34] | 10 [10] | — |
| lvl_11 | 53 [53] | 51 [51] | 2 [2] | — |
| side_a4 | 25 [25] | 23 [23] | 12 [12] | — |
| lvl_12 | 59 [59] | 45 [45] | 6 [6] | — |
| side_bluewitch | 25 [25] | 15 [15] | 3 [3] | — |
| lvl_13 | 57 [57] | 51 [51] | 12 [12] | — |
| lvl_14 | 59 [59] | 29 [29] | 9 [9] | — |
| side_a5 | 38 [38] | 15 [15] | 9 [9] | — |
| lvl_15 | 58 [58] | 37 [37] | 21 [21] | — |
| lvl_16 | 56 [56] | 39 [39] | 12 [12] | — |

Moyennes sur 60 :

| | rang 1 | rang 2 | rang 3 |
|---|---|---|---|
| Campagne | 53,5 (34-59) | 31,3 (7-51) | 9,9 (2-31) |
| Annexes | 35,5 (25-59) | 19,0 (7-30) | 6,8 (3-12) |

Les 7 lignes de campagne qui ont dérivé ont été recollées dans `tests/unit/test_level_progression.gd`, avec une note datée.
Deux causes :
- **C1**, qui a rendu leurs zones décalées aux majeures : lvl_02, lvl_09, lvl_05.
- **La fuite de l'annexe de l'atelier** : lvl_18, lvl_03, lvl_04, lvl_19. Ouverte après lvl_17, `side_a2_atelier` porte la Lumière purifiante (dissipation, DEC-057), qu'aucun niveau ne donne avant lvl_20. La carte devient obtenue et entre au pool de montée des niveaux joués ensuite. Elle est prise 41 fois à lvl_18, d'où le passage de 41 à 36. Correction confiée au chantier C7c.
  - **Corrigé par C7c** : le boss doré de l'atelier est un Oeil des courants doré, sans aura, et le Gardien-totem de sa vague 2 est parti ; son deck n'a plus de Lumière purifiante. Rejoués sur la base C7a, lvl_18, lvl_03, lvl_04 et lvl_19 rendent exactement les lignes de B2. Sur main 854577c (C7b), deux classements tombent du fait du bot de C7b (lvl_03 rang 1, lvl_04 rangs 2 et 3) : voir la note C7c de `MESURES`.

## Erreurs

Sur les 54 sorties de banc : **0 `SCRIPT ERROR`, 0 `ERROR:`**.
Il y a eu un signal 11 à la fermeture, avant la fusion de C3 ; il n'y en a plus aucun depuis.

## Mesure finale (C8, 17/10)

Mesure faite sur main a3c68b0 : toute la vague 10, plus les corrections de l'audit :
- **C7a** : sauvegarde et écrans, dont la migration des étoiles (`SaveData._carry_legacy_objectives`) ;
- **C7b** : les deux majeures d'un sort au choix à la 2e maturation ;
- **C7c** : annexes d'apprenti sans recrutement, atelier sans aura ni Lumière purifiante.

Mêmes groupes de processus que C2 (voir plus haut), mêmes graines, 60 parties.
Le bot prend maintenant **2,51 majeures par partie** au banc de campagne (21 distinctes, aucune à lvl_01).

### Campagne (`tools/sim_balance.tscn`, 60 parties)

Colonnes :
- victoires à C2, puis à C8 ;
- `inc` : temps passé à incanter ;
- `int` : interception ;
- `PV` : vitesse restante à la victoire ;
- boss : abattu / vu (durée moyenne).

| niveau | nom | C2 | C8 | inc | int | PV | boss |
|---|---|---|---|---|---|---|---|
| lvl_01 | La lisière de Nuri | 60 | 60 | 72 % | 85 % | 223 | 60/60 (22,2 s) |
| lvl_02 | Le village pétrifié | 59 | 59 | 83 % | 88 % | 297 | 55/59 (23,4 s) |
| lvl_08 | La route du maire | 58 | 58 | 77 % | 84 % | 189 | 7/60 (25,5 s) |
| lvl_09 | Protéger le dirigeable | 58 | 58 | 58 % | 79 % | 233 | 57/59 (20,0 s) |
| lvl_17 | Les courants | 44 | **50** | 85 % | 48 % | 258 | 49/52 (15,1 s) |
| lvl_18 | Port de Haute-Nacelle | 36 | **46** | 88 % | 50 % | 237 | 48/59 (10,3 s) |
| lvl_03 | L'ossuaire de bordure | 56 | 57 | 78 % | 80 % | 274 | 31/58 (16,8 s) |
| lvl_04 | Le Grand Appel | 53 | **58** | 84 % | 57 % | 274 | 46/60 (55,7 s) |
| lvl_19 | Les fosses basses | 60 | 60 | 83 % | 98 % | 340 | 36/60 (29,2 s) |
| lvl_20 | La cour des rois morts | 60 | 60 | 84 % | 81 % | 293 | **0/60** |
| lvl_05 | Les forges sous Tombol | 60 | 60 | 79 % | 94 % | 477 | 60/60 (25,0 s) |
| lvl_06 | La cour brisée | 60 | 60 | 81 % | 82 % | 328 | 60/60 (7,4 s) |
| lvl_21 | Le pentacle | 58 | 58 | 87 % | 60 % | 296 | 58/58 (36,5 s) |
| lvl_07 | La forge de Vharn | 60 | 60 | 63 % | 62 % | 336 | 51/60 (23,0 s) |
| lvl_10 | Les fosses de Sesh | 58 | 59 | 80 % | 59 % | 278 | 56/59 (11,5 s) |
| lvl_11 | L'arène de Kaltek | 50 | **54** | 68 % | 57 % | 214 | 23/58 (8,9 s) |
| lvl_12 | Le temple d'Ymoa | 54 | **60** | 87 % | 57 % | 303 | 60/60 (6,4 s) |
| lvl_13 | Le pentacle brisé | 57 | 57 | 79 % | 52 % | 274 | 45/57 (19,7 s) |
| lvl_14 | La galerie des saisons | 60 | 60 | 49 % | 87 % | 378 | 60/60 (10,6 s) |
| lvl_15 | Le registre | 59 | 60 | 54 % | 64 % | **291** | 24/60 (27,9 s) |
| lvl_16 | Le siège vide | 60 | 60 | 77 % | 79 % | 376 | 49/60 (16,2 s) |
| **Total** | | **1180** | **1214 / 1260** | moy. 76,0 % | moy. 71,6 % | moy. 294 | |

Repères :
- **aucun niveau sous 36 / 60** : minimum lvl_18 à 46, puis lvl_17 à 50 et lvl_11 à 54 ;
- 16 niveaux sont à 58-60 / 60 pour le bot, qui joue mieux qu'un doigt sur ce terrain ;
- temps passé à incanter : de 49 % (lvl_14) à 88 % (lvl_18), médiane 79 %, au-dessus de 60 % sur 18 niveaux.

D'où viennent les hausses (+34 victoires) :
- **lvl_18 (36 → 46)** : la fuite de la Lumière purifiante est fermée par C7c (41, la ligne de B2), puis C7b ajoute 5 victoires (le chiffre de C7c sur main 854577c).
- **lvl_17, lvl_04, lvl_11, lvl_12** : C7b, deux majeures au choix. C7a ne touche que la sauvegarde et les écrans, et lvl_17 se joue avant l'atelier : il ne reste que C7b. lvl_12 : la majeure « Ossuaire » du Rappel d'ossements est prise dans les 60 parties.
- **lvl_15** gagne toujours, mais finit bien plus bas (391 % de vitesse moyenne à C2, 291 % à C8) : d'où son objectif de vitesse relu, plus bas.

Les boss rarement abattus quand le niveau est gagné n'ont pas bougé :
- lvl_20 (0/60) : l'Épéiste d'ombre et sa deuxième vie ;
- lvl_08 (7/60) : le Coagulé ;
- lvl_11 (23/58) et lvl_15 (24/60).

**Aucune correction d'équilibrage** : aucune rupture, ni sous 36 / 60 en campagne, ni hors de 40-70 % dans les annexes.

### Quêtes annexes (60 parties, insérées après leur niveau d'ouverture)

| annexe | nom | C2 | C8 | inc | int | PV | boss | défaites par vague |
|---|---|---|---|---|---|---|---|---|
| side_a1_mesure | La mesure | 24 | 24 (40 %) | 72 % | 61 % | 135 | 21/60 | v4 ×36 |
| side_a2_atelier | L'atelier du rat | 34 | 32 (53 %) | 78 % | 42 % | 154 | 23/45 | v3 ×15, v4 ×13 |
| side_squire | L'écuyer du port | 39 | 39 (65 %) | 76 % | 33 % | 146 | 44/60 | v4 ×21 |
| side_fairy | La fée des fosses | 27 | 31 (52 %) | 79 % | 72 % | 187 | 4/51 | v2 ×2, v3 ×7, v4 ×20 |
| side_a3_tresor | Le trésor de Tombol | 29 | 31 (52 %) | 84 % | 72 % | 172 | 6/44 | v2 ×8, v3 ×8, v4 ×13 |
| side_a4_champion | Le champion de Kaltek | 34 | 34 (57 %) | 70 % | 58 % | 122 | 0/45 | v3 ×15, v4 ×11 |
| side_bluewitch | L'apprentie d'azur | 30 | 30 (50 %) | 67 % | 51 % | 163 | 2/44 | v3 ×16, v4 ×14 |
| side_a5_vitrine | La vitrine de Nuri | 26 | 26 (43 %) | 79 % | 63 % | 222 | 15/27 | v2 ×22, v3 ×11, v4 ×1 |
| **Total** | | **243** | **247 / 480 (51,5 %)** | moy. 75,6 % | moy. 56,5 % | moy. 163 | | |

Les huit annexes sont dans la fenêtre de 40 à 70 %.
`side_a1_mesure` reste pile à la borne basse (angle mort du bot : il vise le plus avancé, pas le Corniste doré, voir C2).
L'atelier (32) est le chiffre de C7c, avec son nouveau boss doré.
Le champion de Kaltek n'abat jamais son Berserker doré dans une victoire (0/45).

### Massacre (20 parties, après lvl_16 joué 60 fois)

En moyenne la partie finit à la **15,9e vague** (de 7 à 25), contre 17,5 à C2. Elle se termine :
- 4 fois sur un boss ;
- 2 fois sur un mini-boss ;
- 14 fois sur une vague ordinaire ;
- jamais au plafond (30 vagues).

Mondes de fin : act2_graveyard ×3, act3_demon ×14, act4_origin ×2, act5_divine ×1.
Le repère de 4 à 8 vagues reste dépassé ; la cause n'est pas analysée.

### Objectifs (`tools/objective_bench.tscn`, 60 parties)

Format : taux final [MESURES d'avant C8].
**Les 29 classements sont conformes** (rang 1 plus facile que rang 2, plus facile que rang 3).
Aucun objectif n'est à 0/60 ni à 60/60.
En gras, les sept niveaux corrigés par C8 ; leur ligne est rejouée en entier sur le contenu régénéré.

| niveau | rang 1 | rang 2 | rang 3 |
|---|---|---|---|
| lvl_01 | 52 [52] | 26 [26] | 9 [9] |
| lvl_02 | 57 [58] | 38 [45] | 30 [31] |
| side_a1 | 59 [59] | 15 [15] | 8 [8] |
| lvl_08 | 58 [55] | 22 [22] | 5 [6] |
| **lvl_09** | 58 [57] sans Boule de feu | 12 [14] | 7 [11] sous 185 % |
| lvl_17 | 49 [46] | 42 [37] | 5 [10] |
| side_a2 | 35 [35] | 17 [17] | 6 [6] |
| lvl_18 | 34 [34] | 29 [29] | 13 [13] |
| side_squire | 41 [41] | 19 [25] | 5 [5] |
| **lvl_03** | 53 [à mesurer] 32 Pluies | 15 [15] | 1 [1] |
| **lvl_04** | 42 [42] | 19 [à mesurer] moins de 220 s | 12 [à mesurer] |
| lvl_19 | 58 [58] | 49 [49] | 9 [9] |
| **side_fairy** | 30 [29] | 5 [7] | 3 [3] plus de 300 % |
| lvl_20 | 53 [53] | 41 [37] | 9 [7] |
| side_a3 | 27 [28] | 23 [22] | 3 [4] |
| lvl_05 | 51 [56] | 32 [23] | 12 [11] |
| lvl_06 | 59 [59] | 20 [20] | 3 [2] |
| lvl_21 | 51 [50] | 39 [41] | 10 [7] |
| lvl_07 | 59 [59] | 19 [19] | 14 [9] |
| lvl_10 | 56 [56] | 36 [34] | 9 [10] |
| **lvl_11** | 53 [51] un volant | 51 [53] 32 sorts de glace | 4 [2] |
| side_a4 | 25 [25] | 23 [23] | 12 [12] |
| **lvl_12** | 59 [59] | 37 [45] le même sort 45 fois | 4 [6] |
| side_bluewitch | 25 [25] | 15 [15] | 4 [3] |
| lvl_13 | 57 [57] | 51 [51] | 11 [12] |
| lvl_14 | 59 [59] | 29 [29] | 9 [9] |
| side_a5 | 38 [38] | 15 [15] | 9 [9] |
| **lvl_15** | 55 [58] | 34 [21] sans renvoi | 8 [37] plus de 360 % |
| lvl_16 | 55 [56] | 45 [39] | 15 [12] |

Pour lvl_11 et lvl_15, deux objectifs échangent leur rang : le taux entre crochets est celui de l'objectif à son ancien rang.

Moyennes sur 60 :

| | rang 1 | rang 2 | rang 3 |
|---|---|---|---|
| Campagne | 53,7 (34-59) | 32,7 (12-51) | 9,5 (1-30) |
| Annexes | 35,0 (25-59) | 16,5 (5-23) | 6,2 (3-12) |

Avant les corrections, sur main a3c68b0, **sept classements étaient tombés**, tous du fait de C7b (le bot prend plus de majeures, gagne plus vite ou plus bas) :

| niveau | mesuré | ce qui tombait | correction |
|---|---|---|---|
| lvl_03 | 60 / 15 / 1 | 20 Pluies de givre jamais raté | 32 Pluies (le bot qui les joue d'abord en lance de 24 à 58) |
| lvl_04 | 42 / 10 / 12 | moins de 195 s sous le Serpent des sables | moins de 220 s (aucune victoire entre 211 et 224 s) ; le Serpent, défi du co-auteur, reste au rang 3 |
| lvl_09 | 60 / 12 / 14 | sans Trait arcanique jamais raté, rangs 2-3 inversés | sans Boule de feu (essayés aussi : l'Étincelle 30 fois, 27 ; 50 et 70 fois, 0) ; sous 185 % au lieu de 200 (aucune victoire entre 181 et 189 %) |
| lvl_11 | 51 / 53 / 4 | 32 sorts de glace sous un volant | rangs 1 et 2 échangés |
| lvl_12 | 59 / 60 / 4 | le même sort 30 fois jamais raté | 45 fois (50 : 20) |
| lvl_15 | 55 / 2 / 34 | plus de 380 % sous la garde de renvoi | rangs 2 et 3 échangés, plus de 360 % (aucune victoire entre 360 et 367 %) |
| side_fairy | 30 / 5 / 5 | plus de 260 % à égalité avec les 3 Champignons | plus de 300 % (aucune victoire entre 282 et 320 %) |

Méthode :
- les seuils de chrono et de vitesse sont lus sur les victoires du bot neutre (`--detail`) ;
- les comptes de sorts sur une sonde qui écrit le compteur de chaque objectif à la fin de chaque partie, puis sur des lots de candidats joués dans une copie du projet.

Un seuil de compte change la politique du bot, qui joue d'abord la carte **jusqu'au compte** : 32 Pluies rendent 53 et non les 51 que la sonde à 20 promettait.
Les récompenses restent attachées au rang (rare, épique, légendaire), comme le veut la table du co-auteur.

Deux corrections touchent un exemple du co-auteur, ou ne vont pas aussi loin qu'il faudrait :
- **lvl_12** : « le même sort 30 fois » devient 45 fois.
- **lvl_11** : l'écart entre ses rangs 1 et 2 reste de 2 (53 / 51). Chacun ne se rate que sur une défaite.
  55 sorts de glace donneraient un vrai écart (41), mais l'id `obj_element_casts_32_ice` est la cible du renommage du givre (`SaveData.RENAMED_OBJECTIVES`), que `test_eight_elements` et `test_save_migration_w10` tiennent.

Une étoile gagnée sous un ancien id n'est pas perdue : `SaveData._carry_legacy_objectives` (C7a) la rend à l'objectif actuel non acquis du plus bas rang.

### Erreurs

Sur les 44 sorties du banc, les sondes, les candidats et les re-mesures : **0 `SCRIPT ERROR`, 0 `ERROR:`, aucun signal 11**.
