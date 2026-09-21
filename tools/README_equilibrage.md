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

Les garde-fous sont dans `tests/unit/test_balance.gd` : ils verrouillent les
rapports (pas de saut superieur a x2 entre deux vagues, enchainement des niveaux,
pioche suffisante). Le banc reste la mesure de verite.
