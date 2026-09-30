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
joueur parfait. Ses choix vivent dans `scripts/game/auto_pick.gd` (`AutoPick` ; les parties
headless des tests les utilisent aussi) et dans `_try_play` du banc :

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

Le rapport par niveau donne aussi : vitesse retiree par source (cumul et par
vague), vague de la mort, cartes et ameliorations prises, temps pour abattre
le boss, et l adequation du deck au lieu (facteur moyen pondere par les PV).

Les garde-fous sont dans `tests/unit/test_balance.gd` : ils verrouillent les
rapports (pas de saut superieur a x2 entre deux vagues, enchainement des niveaux,
pioche suffisante). Le banc reste la mesure de verite.
