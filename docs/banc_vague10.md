# Banc de contrôle de la vague 10 (chantier C2, 17/10)

Mesure faite sur main d6668a0, qui contient toute la vague 10 (A1 à A4, B1a, B1b, B2, B3, B4, C1).
C3 (sortie commune) et C6 (portraits) ont été fusionnés ensuite sans toucher au jeu ; un contrôle après fusion rend les mêmes chiffres.
Le bot est `scripts/game/auto_pick.gd`, et les parties sont déterministes.
Les tirages de campagne suivent les mêmes groupes de processus que B2.

**Attention : le profil en mémoire garde les cartes prises en combat**, et le pool de montée de niveau = cartes obtenues + communes de l'acte.
Pour comparer deux mesures, il faut donc garder les mêmes groupes de processus.
Une annexe jouée avant un niveau de campagne peut changer ce niveau : c'est le cas de `side_a2_atelier` avec la Lumière purifiante, voir plus bas.

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

## Erreurs

Sur les 54 sorties de banc : **0 `SCRIPT ERROR`, 0 `ERROR:`**.
Il y a eu un signal 11 à la fermeture, avant la fusion de C3 ; il n'y en a plus aucun depuis.
