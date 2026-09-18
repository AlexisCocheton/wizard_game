# Wizard Story — Battle of the Time

Document de reference narratif. Ecrit pour quelqu un qui doit **implementer** le jeu :
chaque acte dit quels monstres apparaissent, quelles cartes se gagnent, et pourquoi.

Regle de lecture : tout ce qui est en gras est un element qui existe deja dans les
donnees (`resources/enemies/`, `resources/cards/`) ou qui est cree par
`tools/make_content.gd`. Rien ici n est decoratif.

---

## 1. Le postulat

Le royaume est un archipel d **iles volantes** suspendues au-dessus du vide. Elles ne
tiennent pas par magie de levitation : elles tiennent parce que le **Temps** y coule
normalement. Une ile ou le temps s arrete tombe.

Un jour, les monstres sont venus. En quelques semaines, l humanite a ete effacee.

Le dernier survivant est un mage. Il n a pas gagne : il a **fui en arriere**. Il a
remonte le temps jusqu au matin de la premiere attaque, avec une seule question —
*qui a donne l ordre ?* Parce que les monstres qui ont detruit le royaume, il les
connaissait. Gnomes, gelees, lutins. Ce sont des nuisibles. Des nuisibles ne
coordonnent pas une extinction.

**Le mage ne cherche pas a survivre. Il cherche un coupable.**

C est ce qui justifie toute la mecanique : le multiplicateur de vitesse. Le mage
n encaisse pas les coups, il les **desynchronise**. Quand un monstre le touche, ce
n est pas sa chair qui paie d abord, c est son avance temporelle qui s effondre
(x4 -> x1). Il ne perd des PV que lorsqu il n a plus d avance a perdre. Le bouclier,
narrativement, c est le temps vole. Voir `system_speed_shield.md`.

---

## 2. Le fil rouge : la politique des monstres

Le rebondissement central du jeu n est pas « il y a un grand mechant ». C est :

> **Les monstres ne sont pas un bloc. Ils se detestent. L attaque du royaume est le
> resultat d une lutte de pouvoir interne — l humanite est un dommage collateral.**

Le mage decouvre cela par etapes, et chaque etape retourne ce qu il croyait savoir :

| Acte | Ce qu il croyait | Ce qu il apprend |
|---|---|---|
| I | Les monstres ont attaque par nature | Ils ont ete **payes**. Quelqu un du Grand Cimetiere leur a promis quelque chose |
| II | Le Cimetiere est le commanditaire | Le Cimetiere est un **sous-traitant**. Il ouvre une porte pour un client |
| III | Le client demoniaque est le boss | Les demons sont des **esclaves**. Ils obeissent a une horloge, pas a un roi |
| Final | Il y a un tyran a abattre | Il y a une **machine**. Et le mage en fait partie |

---

## 3. Acte I — Le Monde volant

**Terrain : `grass`. Niveaux `lvl_01`, `lvl_02`.**

Le mage reapparait sur les Marches du Temps, l ile-frontiere, le matin meme.
Les premieres vagues sont ce qu il attendait : des **Gnomes**, des **Lutins fileurs**,
des **Sauterelles**. De la vermine.

Sauf que la vermine avance en **colonnes**. Elle ne pille pas, elle ne se disperse pas.
Elle marche vers un point precis. Et derriere elle, il y a un **Corniste** qui sonne la
cadence — un monstre qui ne se bat pas, qui presse les autres.

### Rebondissement 1 — le Gardien parle

Au bout des Marches, le mage abat un **Gardien** (`warden`, mini-boss). Mourant, il ne
supplie pas : il **rit**. Il dit qu il n a jamais voulu de cette guerre, que sa tribu a
recu un ordre venu « de sous la terre », et que refuser coutait plus cher qu obeir.

Puis arrive **Chronos** (boss du niveau 1). Chronos n est pas le maitre : c est un
**huissier**. Une creature-horloge envoyee pour verifier que le contrat est execute
dans les delais. Le mage le detruit et lui prend son fragment : **Faille temporelle**
(`time_rift`, legendaire du niveau 1).

### La Tour des Sables (`lvl_02`)

Terrain `sand`. Une ile qui a deja commence a tomber — le temps y est detraque, d ou
les **Ombres**, les **Chevaliers du vide** et les **Pretres goules**, qui n ont rien a
faire sur une ile volante. Ils viennent d ailleurs. Ils **fuient** quelque chose.

Le mage y trouve la porte : un puits qui descend vers le **Grand Cimetiere**.
Legendaire : **Sablier fendu** (`hourglass_shard`).

---

## 4. Acte II — Le Grand Cimetiere

**Terrain : `sand`. Niveaux `lvl_03` (Ossuaire des Marees), `lvl_04` (Le Grand Appel).**

Le Grand Cimetiere n est pas un lieu de repos, c est une **administration**. Les morts
y sont tries, comptes, reaffectes. Ce sont les **Pretres goules** qui tiennent les
registres, et ils ont un probleme : leur ile se vide. Les ames partent ailleurs.

### Rebondissement 2 — le motif du Cimetiere

Les goules n ont pas attaque le royaume par haine. Elles l ont fait pour **le stock**.
Une extinction humaine, c est un afflux d ames — le carburant d une **Grande Invocation**
qu elles preparent depuis des siecles.

`lvl_03` — **Ossuaire des Marees** : le mage traverse les fosses pendant que les goules
achevent leur comptage. Vagues denses et serrees (nuees, gelees qui se divisent,
ruches qui explosent) : ici, la menace est le **nombre**, pas la masse.

Le mage y libere une **Gelee** prisonniere d un cercle de sel. Elle ne parle pas mais
elle imite : elle lui montre comment un corps peut se separer et se rassembler.
**Carte gagnee : Spirale de sel (`salt_spiral`, rare)** — le vortex qui aspire les
monstres en un tas. Legendaire : **Registre des marees** (`tide_ledger`).

`lvl_04` — **Le Grand Appel** : le rituel a lieu. **Et il reussit.** C est important —
le joueur ne l empeche pas. Le mage arrive trop tard, la porte s ouvre, et ce qui
passe n est pas ce que les goules attendaient.

### Rebondissement 3 — l invocation se retourne

Les goules croyaient invoquer un allie. Elles ont invoque un **proprietaire**. Le
**Behemoth** et les **Gardiens-totems** qui franchissent la porte ne viennent pas les
servir : ils viennent **saisir le bien**. Le Grand Cimetiere est annexe en une nuit.

Le **Pretre goule** qui dirigeait le rituel, ecrase par ce qu il a fait venir,
retourne sa veste et devient le premier **allie** du mage. Il lui apprend le seul sort
qu une goule connaisse vraiment : rappeler ce qui est deja parti.
**Carte gagnee : Rappel d ossements (`bone_recall`, rare)** — garde en main les
prochaines cartes lancees au lieu de les defausser.

Le mage descend par la porte encore ouverte. Legendaire : **Clef de l Appel**
(`summoners_key`).

---

## 5. Acte III — Le Monde demoniaque

**Terrain : `sand`. Niveaux `lvl_05` (Forges du Mauvais Temps), `lvl_06` (La Cour brisee).**

De l autre cote : un monde de forges. Pas de chateau, pas de trone. Des **ateliers**.
Les demons ne conquierent pas par appetit — ils **fabriquent**. Ils fabriquent du temps.

`lvl_05` — **Forges du Mauvais Temps** : ici tout est blinde. **Golems**, **Behemoths**,
**Chevaliers du vide**, **Berserkers**. Peu de monstres, enormement de PV. Le mage
comprend que ces creatures ne sont pas nees : elles ont ete **coulees**.

### Rebondissement 4 — les demons sont les esclaves

Un **Berserker** brise sa chaine devant le mage au lieu de le charger. Les demons ne
choisissent rien. Ils sont reveilles par une **horloge** qui bat au centre de leur
monde, et cette horloge n est pas a eux : elle appartient au Monde d origine. Chaque
raid, chaque invasion, chaque extinction est une **commande** qui arrive par le
cadran. Ils ne savent meme pas qui la passe.

Le Berserker libere donne au mage la rage qu il n a plus a porter.
**Carte gagnee : Rupture de chaine (`chain_break`, rare)** — souffle qui repousse
violemment tout autour du point vise.

`lvl_06` — **La Cour brisee** : le mage remonte jusqu a la cour des demons, ou les
seigneurs s entretuent pour savoir qui portera la faute du Grand Appel rate. Vagues
chaotiques, toutes les familles melangees : c est une **guerre civile** ou le mage
n est qu un passant. **Gloutons**, **Gardiens-totems**, **Ruches**, **Ombres**.

Le **Chevalier du vide** qui gardait le cadran se rend, et lui enseigne le geste des
gardiens : effacer ce qui a ete inscrit sur une creature.
**Carte gagnee : Vide d emprise (`void_grip`, epique)** — dissipe rage, boucliers et
buffs dans une petite zone.

Legendaire : **Cadran des forges** (`forge_dial`). Le mage y lit une adresse.

---

## 6. Acte Final — Le Monde d origine

**Terrain : `grass` (l herbe y est fausse — voir plus bas). Niveau `lvl_07` (Le Metier du Monde).**

Ce n est pas un monde. C est une **matrice** suspendue dans le vide : une grille de
fils tendus entre des etoiles, ou des **divinites** tissent les evenements. Elles ne
sont ni bonnes ni mauvaises. Elles sont **occupees**.

L herbe, le ciel, les iles volantes : tout cela est un **motif** qu elles repetent.
D ou le terrain `grass` du dernier niveau — le joueur reconnait le decor du premier
niveau, en faux. Le jeu revient a son point de depart.

### Rebondissement 5 — il n y a pas de coupable, il y a un calcul

Le commanditaire n a pas de nom. C est le **Metier** : la machine qui tisse. Le royaume
humain a ete efface parce qu un fil s y emmelait — l humanite generait trop de
**variantes**, trop de futurs possibles. Elle a ete coupee pour simplifier le motif.
L attaque des monstres n etait qu un outil, comme des ciseaux.

### Rebondissement 6 — le mage est le fil qui depasse

En remontant le temps, le mage a fait exactement ce que le Metier redoutait : il a
cree une boucle. Il est devenu la **variante** que la machine voulait supprimer. Les
divinites ne le combattent pas par colere : elles le combattent comme on retire un
noeud.

**Boss final : Chronos, deuxieme forme.** L huissier du premier niveau revient, mais
on comprend enfin ce qu il est : le **navetteur** de la machine, celui qui fait les
allers-retours. Le rencontrer au debut ET a la fin est le coeur du theme — dans une
histoire circulaire, le premier ennemi est toujours le dernier.

### Les trois fins possibles (a implementer plus tard, une seule est codee)

1. **Couper le fil** — le mage se supprime lui-meme. Le royaume revit, il n a jamais
   existe. Fin canonique.
2. **Tisser a son tour** — il prend la place du Metier et devient ce qu il combattait.
3. **Nouer** — il laisse la boucle ouverte. Le jeu recommence : c est le mode Massacre.

Le mode **Massacre** est donc diegetique : c est la troisieme fin, jouee en boucle.

Legendaire : **Metier du monde** (`world_loom`).

---

## 7. Les monstres allies et leurs cartes

Regle de design : **un monstre qui se rend apprend un sort au mage**, et ce sort
contre precisement la famille du niveau **suivant**. C est la recompense narrative
ET la cle mecanique de la progression.

| Niveau | Allie | Carte enseignee | Ce qu elle contre |
|---|---|---|---|
| `lvl_03` | Gelee liberee | **Spirale de sel** (`salt_spiral`, rare) | Les nuees dispersees : elle les rassemble pour une zone |
| `lvl_04` | Pretre goule repenti | **Rappel d ossements** (`bone_recall`, rare) | La penurie de cartes face aux vagues longues |
| `lvl_05` | Berserker libere | **Rupture de chaine** (`chain_break`, rare) | Les blocs blindes : elle gagne du temps en les repoussant |
| `lvl_06` | Chevalier du vide rendu | **Vide d emprise** (`void_grip`, epique) | Rage, bouclier de premier coup, aura de totem |

Ces cartes sont placees **dans le deck d exploration du niveau ou elles se gagnent**,
pour que le joueur les decouvre en jouant plutot qu en lisant un ecran de recompense.

---

## 8. Arborescence des niveaux

```
                     lvl_01  Les Marches du Temps        (Acte I,  grass)
                        |
                     lvl_02  La Tour des Sables          (Acte I,  sand)
                        |
                     lvl_03  Ossuaire des Marees         (Acte II, sand)
                        |
                     lvl_04  Le Grand Appel              (Acte II, sand)
                       / \
                      /   \                     la porte s ouvre sur DEUX
                     /     \                    entrees du monde demoniaque
   lvl_05  Forges du         lvl_06  La Cour brisee
   Mauvais Temps                     (Acte III, sand)
   (Acte III, sand)                    |
        |                              |
        \______________  _____________/
                       \/
                     lvl_07  Le Metier du Monde          (Final, grass)
```

`lvl_01` ne debloque **qu un** niveau : la campagne doit rester lineaire au demarrage
(verrouille par `tests/unit/test_menu_data.gd`). La premiere fourche est en `lvl_04`.

Les deux branches de l Acte III sont **equivalentes en difficulte mais opposees en
nature** :
- `lvl_05` **Forges** : peu de monstres, tres blindes -> il faut du **mono-cible lourd**.
- `lvl_06` **Cour brisee** : beaucoup de monstres, varies -> il faut des **zones**.

Le joueur choisit son epreuve. Les deux menent au final.

---

## 9. Ce que chaque niveau doit faire ressentir

| Niveau | Sensation visee | Traduction mecanique |
|---|---|---|
| `lvl_01` | apprendre | vagues espacees, monstres lents |
| `lvl_02` | ca devient serieux | familles a comportement (esquive, phase, soin) |
| `lvl_03` | etre submerge par le nombre | nuees, divisions, ruches — deck oriente zone |
| `lvl_04` | assister a une catastrophe | la vague du rituel arrive **pendant** le combat |
| `lvl_05` | taper dans du beton | peu d ennemis, enormement de PV — deck mono-cible |
| `lvl_06` | etre au milieu d une bagarre | toutes les familles a la fois — deck polyvalent |
| `lvl_07` | boucler la boucle | decor du niveau 1, boss du niveau 1, difficulte finale |

---

## 10. Notes d implementation

- Aucun nouveau type de monstre n est cree par cette histoire. Les 21 existants
  suffisent : la narration re-contextualise des creatures deja la (le Gardien devient
  un conscrit, le Pretre goule un comptable, le Berserker un esclave).
- Les champs narratifs vivent sur `LevelDef` : `act`, `subtitle`, `intro_text`,
  `outro_text`. Ils sont facultatifs — un niveau sans texte reste jouable.
- Chronos apparait deux fois (`lvl_01` et `lvl_07`) : c est **voulu**, pas un oubli.
  Le briefing du niveau 7 doit pouvoir le presenter comme un retour.
- Les trois fins ne sont pas codees. Seule la fin 1 est evoquee par `outro_text` de
  `lvl_07` ; le mode Massacre incarne la fin 3 sans texte.
