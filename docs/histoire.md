# Wizard Story — Battle of the Time

Document de reference narratif, version 2. Il remplace l histoire en 4 actes (Marches
du Temps / Grand Cimetiere / Forges / Metier du Monde), qui ne correspondait plus au
plan de campagne demande.

Ecrit pour quelqu un qui doit **implementer** : chaque niveau dit son lieu, son
ambiance, ses monstres (pris dans les 21 qui existent, voir `catalog_enemies.md`) et
les **dialogues** des scenes de visual novel qui l encadrent.

Conventions :
- Les scenes portent un id (`prologue`, `lvl_01_intro`, `lvl_01_outro`...) qui est le
  nom du `.tres` dans `resources/story/`, genere par `tools/make_story.gd`.
- Les textes sont **sans accents** : la police du jeu (`planes_valmore.ttf`) n en a pas.
  Ce document, lui, en porte — c est de la documentation, pas de la donnee.
- Une scene ne se joue qu **une fois par profil** (`SaveData.stories_seen`). Rejouer un
  niveau pour ses objectifs ne reimpose pas la lecture.

---

## 1. Les personnages

| Personnage | Qui il est | Le secret |
|---|---|---|
| **Le Mage** | Le dernier survivant. Chauve : ses cheveux sont partis avec ses pouvoirs quand il a force le temps a reculer | Il ne lui reste presque rien. Le multiplicateur de vitesse est tout ce qu il sait encore faire |
| **L Enfant** | Un gamin de la foret de Nuri, sauve au niveau 1. Suit le mage toute la campagne. Pose les questions que le joueur se pose | **C est une divinite.** Le boss final. Le mage l a sauve avant de comprendre qu il transportait sa propre fin |
| **Le Rat pilote** | Un rat parlant, mecanicien du dirigeable ecrase. Rejoint le groupe a l acte 2 | Il a deja vu le monde finir. Il ne le dit pas : il repare, c est sa facon de refuser |
| **Le Roi squelette** | Souverain du cimetiere de Tombol. Fuit devant le mage pendant tout l acte 3 | Il ne fuyait pas le mage : il fuyait les demons qui le tenaient par contrat |
| **Le Maire** | Maire du village de l enfant, acte 1 | Il sait depuis des mois que l attaque vient d une autre ile, et il s est tu pour ne pas affoler |
| **Le Gardien de la foret** | L esprit protecteur de Nuri. Un colosse de bois et de pierre | Il n est pas devenu fou : il a ete **retourne**. Premiere preuve que quelqu un commande aux monstres |

### Les visages

Les portraits des scenes de dialogue viennent du pack **TTRPG LEGEND [TOO MANY
CHARACTERS]** (Ddant1100, itch.io — commercial autorise, credit demande), dossier
`Faceset` : 100 personnages nommes par classe et par race, deja cadres en buste.
Le rat, absent de ce pack, vient de **free_character_1_20** (cogabushi).

La planche `assets/portraits/story_cast.png` est fabriquee par
`tools/story/build_cast.py` ; la table `CAST` de `scripts/ui/story_scene.gd` dit
quelle case revient a qui.

| Personnage | Source | Pourquoi celui-la |
|---|---|---|
| Le Mage | `wizard_human_man_04` | **Chauve**, age, col de mage : le seul du pack a reunir les trois. Paupieres lourdes, bouche fermee — une expression qui ne contredit aucune de ses repliques |
| L Enfant | `unknow_darkelve_boy_01` | Le seul jeune garcon du pack. Grands yeux, chemise usee, aucune arme |
| L Enfant (divinite) | `deity_man_01` | Un masque de dragon d or, rien d humain dedans : la meme creature, vue enfin |
| Le Rat pilote | `cogabushi A_18` | Un rat debout, capuche, besace d outils et de fioles. Autre pack, autre style — mais un nain etiquete "Le Rat pilote" serait un contresens |
| Le Maire | `noble_human_man_02` | Couronne, lorgnons, fraise de notable, un document a la main : un homme de papiers, celui qui "savait depuis des mois" |
| Le Roi squelette | `demon_human_man_01` | Crane decharne, chair grise recousue, yeux jaunes : un mort qui parle encore |
| Le Gardien | `knight_raceless_man_01` | Un heaume vert et or **sans visage dedans**. Le pack le nomme "raceless" — un colosse mu par autre chose que lui-meme, ce que l acte 1 revele de lui |

**Une expression par personnage.** Ce pack ne fournit qu un seul visage par
personnage, la ou l ancien en donnait quatre. On a donc choisi des visages dont
l expression ne contredit AUCUNE replique, plutot que de faire sourire le mage
en disant "je n ai pas su les arreter". `mage_grave` partage la case de `mage`.

### Les lieux des scenes

Les dialogues ne se jouent plus devant le fond de COMBAT de l acte assombri de
moitie — neuf scenes devant la meme pelouse. Chaque scene a son decor peint, pris
dans le pack **Wood Elves**, copie par `tools/story/build_backdrops.py` :

| Scene | Decor | Le lieu |
|---|---|---|
| `prologue` | `talk_shrine` | Un sanctuaire en ruine sous la lune : ce que le mage a deja perdu |
| `lvl_01_*` | `talk_glade` | La clairiere au petit matin, la lumiere entre les racines |
| `lvl_02_*` | `talk_village` | Le village de l enfant, ses maisons de bois eclairees |
| `lvl_03_*` | `talk_path` | Le sentier et la maison isolee : la grange du maire |
| `lvl_04_*` | `talk_greattree` | L arbre que le Gardien protege, et sous lequel il tombe |

---

## 2. PROLOGUE — Ce que le mage a deja perdu

**Scene `prologue`. Fond : `act1_sky`. Aucun niveau : se joue avant l intro de `lvl_01`.**

Les monstres sont arrives de nulle part. Pas une invasion : une **apparition**. En
quelques semaines ils ont assiege la foret de Nuri, puis marche sur la ville de Nox,
qui n a pas tenu la nuit.

Le mage n a pas gagne. Il a fait la seule chose qui restait : il a brule **tous** ses
pouvoirs d un coup pour remonter le temps jusqu avant le mal. Le prix a ete paye
comptant — sa magie, sa jeunesse, et ses cheveux, partis avec le reste.

Il se reveille dans une foret intacte, faible comme un apprenti, avec une seule chose
a faire : **trouver d ou vient le mal**, cette fois avant qu il ne frappe.

### Dialogue (scene `prologue`)

> *narrateur* — Ils ne sont pas venus d un pays. Ils ne sont pas venus d une mer.
> Un matin, ils etaient la.
>
> *narrateur* — Nuri a brule en six jours. Nox, promise aux siecles, a tenu une nuit.
>
> **Le Mage** — Je n ai pas su les arreter. Alors j ai arrete le temps.
>
> *narrateur* — Il a tout donne. Sa magie, ses annees, jusqu au dernier cheveu.
>
> **Le Mage** — Je suis revenu avant. Avant la foret. Avant la ville. Avant eux.
>
> **Le Mage** — Cette fois je ne vais pas defendre. Je vais **remonter le courant**.

---

## 3. ACTE 1 — La foret de Nuri

**Monstres : terrestres, animaux, vermine.** `gnome`, `sprite`, `hopper`, `rat_swarm`,
`jelly` et ses enfants, `hive`, `hornblower`, puis `warden` (le Gardien).
**Fond : `act1_sky`. Terrain `grass`.** Niveaux `lvl_01` a `lvl_04`.

C est l acte ou le joueur apprend le jeu et ou le mage apprend qu il n a rien compris :
les betes de la foret ne se comportent pas comme des betes.

### `lvl_01` — Lisiere de Nuri (tutoriel)

Ambiance : une clairiere au petit matin, tres calme, presque jolie. Vagues espacees,
monstres lents. Uniquement `gnome`, `sprite`, quelques `hopper`.

Le mage voit un **enfant** accule contre un arbre par trois gnomes. Il le sauve. C est
le geste qui condamne tout — mais il faudra cinq actes pour le savoir.

**Scene `lvl_01_intro`**

> *narrateur* — La foret de Nuri, six jours avant sa fin. Elle ne le sait pas encore.
>
> **Le Mage** — Meme odeur. Meme lumiere. Je suis au bon endroit, au bon matin.
>
> **Le Mage** — Il me reste de quoi lancer trois sorts et courir vite. Ca ira.
>
> *narrateur* — Puis un cri, entre les arbres. Une voix d enfant.

**Scene `lvl_01_outro`**

> **L Enfant** — Tu les as fait tomber ! Tous les trois ! Comment on fait ca ?
>
> **Le Mage** — On va vite. Plus vite qu eux. C est tout ce que je sais encore faire.
>
> **L Enfant** — Alors va vite jusqu a mon village. Il y en a plein la-bas. Plein.
>
> **Le Mage** — ... Des gnomes qui attaquent un village. Les gnomes ne font pas ca.
>
> **L Enfant** — Tu viens ?
>
> **Le Mage** — Je viens. Reste derriere moi et ne me lache pas.

### `lvl_02` — Le village de l enfant

Ambiance : maisons de bois, feu, cris. Le combat se joue **dans** le village.
Monstres : `gnome`, `sprite`, `rat_swarm`, `hopper`, et surtout un `hornblower` qui
reste sur le cote et presse les autres. Premiere preuve visible d une **cadence**.

**Scene `lvl_02_intro`**

> **L Enfant** — C est la ! La maison bleue, c est chez moi !
>
> **Le Mage** — Ne regarde pas la maison. Regarde la ligne.
>
> **L Enfant** — Quelle ligne ?
>
> **Le Mage** — Ils avancent en rang. Des nuisibles pillent au hasard. Ceux-la
> **marchent**. Quelqu un leur bat la mesure.

**Scene `lvl_02_outro`**

> *narrateur* — Le corniste tombe en dernier. Sa corne roule dans la boue et continue
> a sonner deux secondes de trop.
>
> **L Enfant** — Il jouait pour les autres.
>
> **Le Mage** — Il jouait pour **quelqu un d autre**. Il recevait un tempo, il le
> repetait. Ou est ton maire, petit ?
>
> **L Enfant** — Dans la grange. Il s y cache depuis trois jours.
>
> **Le Mage** — Trois jours. Avant meme l attaque, donc. Interessant.

### `lvl_03` — La route du maire

Ambiance : le sentier entre le village et la clairiere du dirigeable, sous les arbres.
Monstres : `jelly` (et ses divisions), `hive` qui explose en lutins, `rat_swarm`. La
pression est le **nombre** : premiere vraie lecon de zone.

Le maire avoue : ce n est pas Nuri qui est attaquee, c est **toute l ile**, et ca vient
d une **autre ile**, par le ciel. Il le sait depuis des mois et s est tu.

**Scene `lvl_03_intro`**

> **Le Maire** — Je n ai rien cache. J ai... attendu.
>
> **Le Mage** — Vous avez attendu quoi, exactement ?
>
> **Le Maire** — Que ca s arrete tout seul. Ca arrivait par le ciel, mage. Tous les
> mois, un peu plus bas. Des betes qui tombaient d en haut et qui ne remontaient pas.
>
> **Le Mage** — D en haut. Donc il y a une ile au-dessus de la notre.
>
> **Le Maire** — Il y a les Sky Lands. Et il y a un dirigeable ecrase au bout de cette
> route. Si vous voulez monter, c est la seule facon.
>
> **L Enfant** — Je viens.
>
> **Le Mage** — Non.
>
> **L Enfant** — Mon village est derriere moi et il n y a plus rien dedans. Je viens.

**Scene `lvl_03_outro`**

> *narrateur* — Au bout de la route, une carcasse de dirigeable, coincee dans les
> arbres comme une baleine echouee. Elle fume encore.
>
> **L Enfant** — Il y a quelqu un dedans. Ca tape.
>
> **Le Mage** — Ca tape avec un outil. Ce n est pas un monstre, c est un mecanicien.
>
> *narrateur* — Loin derriere eux, dans la foret, quelque chose de tres grand se met
> debout.

### `lvl_04` — Proteger le dirigeable

Ambiance : la clairiere, le dirigeable au centre, le rat pilote qui repare pendant le
combat. Le joueur **tient une position** pendant un compte a rebours narratif.
Monstres : la vague de fond de l acte 1, puis le **Gardien de la foret** (`warden`,
mini-boss) — l esprit protecteur de Nuri, retourne contre elle.

C est le premier boss et la premiere preuve dure : on ne **devient** pas fou en six
jours. On est **retourne** par quelqu un.

**Scene `lvl_04_intro`**

> **Le Rat pilote** — Bougez pas, touchez a rien, et surtout ne montez pas. Il manque
> une valve, deux ailerons et ma patience.
>
> **Le Mage** — Combien de temps ?
>
> **Le Rat pilote** — Le temps qu il faut. Vous, dehors. Moi, dessous.
>
> *narrateur* — Les arbres, au fond de la clairiere, s ecartent d eux-memes.
>
> **L Enfant** — C est le Gardien. C est lui qui protege la foret. Il va nous aider !
>
> **Le Mage** — Petit... il marche sur les arbres, pas entre.

**Scene `lvl_04_outro`**

> *narrateur* — Le Gardien s effondre en un tas de bois mort. Dans sa poitrine ouverte,
> plantee la comme une echarde, une plaque de metal noir que personne n a taillee ici.
>
> **Le Mage** — Il n est pas devenu fou. On lui a **mis** quelque chose dedans.
>
> **Le Rat pilote** — Vu la soudure, c est du travail d en haut. Sky Lands. Je connais
> le style, j en viens.
>
> **L Enfant** — Alors on monte ?
>
> **Le Rat pilote** — On monte. Accrochez-vous a ce qui est vise.

---

## 4. ACTE 2 — Les Sky Lands

**Monstres : volants, puis humanoides, puis zombies.** `wisp`, `imp_archer`,
`sand_serpent` (dans les courants d air), `shade`, `void_knight`, `berserker`,
`ghoul_priest`, `glutton`. **Fond : `act1_sky` puis `act2_graveyard`.**
4 niveaux. Les **premiers passifs** se debloquent ici.

Le groupe monte. Les Sky Lands ne sont pas une ile sauvage : c est un archipel habite,
en train d etre vide par le haut. Et au bout, un cimetiere ou les morts se levent et
**parlent** — ce sont eux qui lachent le premier vrai nom.

| Niveau | Lieu | Ambiance | Monstres |
|---|---|---|---|
| `lvl_05` | Les courants | tout en vol, plates-formes etroites | `wisp`, `imp_archer`, `sand_serpent` |
| `lvl_06` | Port de Haute-Nacelle | un port pille, quais de bois | `void_knight`, `berserker`, `shade` |
| `lvl_07` | Les serres d en haut | jardins suspendus pourris | `glutton`, `jelly`, `hive` |
| `lvl_08` | Cimetiere de bordure | premiers morts-vivants, brume | `ghoul_priest`, `shade`, `void_knight` |

### Dialogues cles de l acte 2

**`lvl_05_intro` — le rat prend l equipage**

> **Le Rat pilote** — Regle une : si je crie "a bas", vous vous mettez a bas.
> **Le Mage** — Il y a une regle deux ?
> **Le Rat pilote** — La regle deux c est qu il n y a pas de regle deux, on va s ecraser.

**`lvl_06_outro` — l enfant montre quelque chose qu il ne devrait pas savoir**

> **L Enfant** — Il faut passer par la droite. La gauche est fermee.
> **Le Mage** — Tu es deja venu ici ?
> **L Enfant** — Non. Mais c est ferme. Je le sais, c est tout.
> **Le Mage** — ... D accord. Par la droite.

C est le premier **grain** du plot twist : l enfant sait des choses. Le mage le note et
n y revient pas — le joueur non plus, jusqu a l acte 5.

**`lvl_08_outro` — l origine est lachee**

> *narrateur* — Les morts du cimetiere de bordure ne chargent pas. Ils s arretent,
> tous, en meme temps, et se tournent vers le mage.
>
> **Un mort** — Ce n est pas nous. Nous, on nous a **reveilles**.
>
> **Le Mage** — Par qui ?
>
> **Un mort** — Par l ordre de Tombol. Le Roi squelette a signe. Il a signe pour nous
> tous et il n avait pas le droit.
>
> **Le Rat pilote** — Tombol, c est trois iles plus loin. Le grand cimetiere.
>
> **Le Mage** — Alors on a enfin un nom. On y va.

---

## 5. ACTE 3 — Le cimetiere de Tombol

**Monstres : morts-vivants et gardiens.** `ghoul_priest`, `shade`, `void_knight`,
`golem`, `totem_guardian`, `hive`, `behemoth`. **Fond : `act2_graveyard`.**
5 niveaux.

Le Roi squelette **fuit**. Tout l acte est une poursuite : a chaque niveau on arrive
juste apres lui, on brise ce qu il a laisse derriere pour retarder. Puis on comprend
pourquoi il court.

| Niveau | Lieu | Ambiance | Monstres |
|---|---|---|---|
| `lvl_09` | Les fosses basses | tombes ouvertes, on avance dans l eau | `ghoul_priest`, `shade` |
| `lvl_10` | L ossuaire | murs d os, couloirs — terrain de murs | `void_knight`, `golem` |
| `lvl_11` | La cour des rois morts | statues, arrieres-gardes laissees par le roi | `totem_guardian`, `hive` |
| `lvl_12` | Le puits de contrat | descente, lumiere rouge par en bas | `behemoth`, `berserker` |
| `lvl_13` | Le pentacle | salle du portail, le roi accule | mixte + le portail |

### `lvl_13` — le retournement de l acte 3

**Scene `lvl_13_intro`**

> **Le Roi squelette** — Encore toi. Tu cours vite pour un homme qui n a plus rien.
>
> **Le Mage** — Tu as signe l extinction de mon royaume.
>
> **Le Roi squelette** — J ai signe pour **sauver** le mien ! Ils sont venus avec un
> contrat deja ecrit, mage. On ne negocie pas avec ce qui monte de ce puits.
>
> **Le Mage** — Qui monte de ce puits ?
>
> **Le Roi squelette** — Regarde derriere moi et arrete de poser la question.

**Scene `lvl_13_outro`**

> *narrateur* — Le pentacle tourne au fond de la salle. Ce qui passe au travers n a
> pas d yeux et sait exactement ou tout le monde se tient.
>
> **Le Roi squelette** — Voila mes creanciers. Ils m ont pris mes morts, mes terres et
> ma signature. Ils te prendront ta boucle.
>
> **Le Mage** — Ma quoi ?
>
> **Le Roi squelette** — Ils savent que tu as recule le temps, mage. Tout le monde en
> bas le sait. C est pour **ca** qu ils avancent si vite maintenant.
>
> **Le Mage** — ... Alors c est moi qui ai accelere la fin.
>
> **Le Roi squelette** — Tu as change la date, pas la fin. Fais-moi une place, je
> descends avec toi. Je n ai plus de royaume a perdre.
>
> **L Enfant** — On descend ? Vraiment ?
>
> **Le Mage** — On descend.

---

## 6. ACTE 4 — Le monde demoniaque

**Monstres : demons, blindes, gros.** `void_knight`, `golem`, `behemoth`, `berserker`,
`glutton`, `totem_guardian`, `hive`. **Fond : `act3_demon`.** 5 niveaux.

Structure particuliere, demandee : les **4 premiers niveaux sont ouverts d emblee**,
un par grand demon. Le joueur choisit son ordre et son style. Le cinquieme ne s ouvre
qu apres les quatre.

| Niveau | Le demon | Ambiance | Monstres |
|---|---|---|---|
| `lvl_14` | **Vharn, l Enclume** | forge, tout est blinde | `golem`, `behemoth` — peu, enormes |
| `lvl_15` | **Sesh, la Faim** | fosses, tout se mange | `glutton`, `jelly`, `hive` |
| `lvl_16` | **Kaltek, la Chaine** | arene, rage et esclaves | `berserker`, `void_knight` |
| `lvl_17` | **Ymoa, le Cercle** | temple, auras et protections | `totem_guardian`, `ghoul_priest` |
| `lvl_18` | le pentacle brise | apres les 4, le sol se derobe | melange des quatre |

Les quatre grands demons ne se coordonnent pas : chacun croit etre le commanditaire.
C est le comique noir de l acte — le mage descend en enfer pour trouver un chef et
trouve **quatre directeurs qui se detestent**.

### `lvl_18` — le pentacle brise

**Scene `lvl_18_intro`**

> **Le Roi squelette** — Quatre. Quatre seigneurs, quatre contrats, et pas une seule
> signature en commun.
>
> **Le Mage** — Donc aucun des quatre n a donne l ordre.
>
> **Le Roi squelette** — Aucun des quatre n a meme lu l ordre. Ils l ont **recu**.
>
> **Le Rat pilote** — J ai deja vu ca. Un atelier ou personne n est le patron : ca
> veut dire que le patron n habite pas l atelier.

**Scene `lvl_18_outro`**

> *narrateur* — Le pentacle qui tient le monde demoniaque se fend en cinq morceaux, et
> le monde avec lui.
>
> **Le Mage** — Ce n est pas nous qui l avons casse.
>
> **Le Roi squelette** — Non. On nous **retire**. Comme on retire une piece du plateau.
>
> **L Enfant** — Ne lachez pas ma main.
>
> **Le Mage** — Petit, ta main est froide comme le puits.
>
> *narrateur* — La chute ne va pas vers le bas.

---

## 7. ACTE 5 — L espace divin

**Monstres : tout, melange. Les anciens boss redeviennent des monstres ordinaires.**
`warden` et `chronos` apparaissent en vagues normales : ce qui etait un evenement
devient de la vermine, et c est exactement le propos. **Fond : `act4_origin`.**
3 niveaux.

Il n y a pas de sol. Il y a des **registres** : des dieux qui tiennent des comptes.

### Rebondissement — l extinction etait au programme

L humanite n a pas ete attaquee. Elle a ete **planifiee pour s eteindre**, a la date
prevue, comme une saison se termine. Les monstres n etaient que l outil du calendrier.
Les dieux ne sont ni cruels ni interesses : ils sont **assis**.

Et le retour en arriere du mage ne les a pas inquietes. Il les a **amuses**. Un pion
qui recule sur le plateau, c est la premiere chose distrayante depuis des eons. Ils ont
laisse courir pour voir jusqu ou il irait. Toute la campagne est un **spectacle** qu on
leur a offert.

| Niveau | Lieu | Ambiance | Monstres |
|---|---|---|---|
| `lvl_19` | La galerie des saisons | ce qui a deja ete efface, expose | melange acte 1 + 2, `warden` en vague normale |
| `lvl_20` | Le registre | colonnes de noms, dont le sien | melange acte 3 + 4, `chronos` en vague normale |
| `lvl_21` | Le siege vide | rien. Puis l enfant | boss final |

### `lvl_21` — le plot twist

**Scene `lvl_21_intro`**

> *narrateur* — Au bout du registre, un siege. Il est vide depuis toujours.
>
> **Le Mage** — Ou est celui qui a signe ?
>
> **L Enfant** — Il est la.
>
> *narrateur* — L enfant lache la main du mage. Il ne grandit pas, il ne change pas de
> forme. Il arrete simplement de faire semblant d avoir peur.
>
> **L Enfant** — Tu m as porte pendant cinq actes, mage. Merci. C etait tres long a
> pied.
>
> **Le Mage** — ... Tu etais la depuis la premiere clairiere.
>
> **L Enfant** — J etais la depuis la date. C est moi qui l ai posee. Nuri le sixieme
> jour, Nox la septieme nuit. C etait propre.
>
> **Le Roi squelette** — Le gamin. C est le gamin. J ai signe un contrat pour **un
> gamin**.
>
> **L Enfant** — Et puis tu as recule, et pour la premiere fois depuis tres longtemps
> je n ai pas su ce qui allait arriver. Tu ne peux pas savoir a quel point c etait bon.
>
> **Le Mage** — Tu m as laisse venir jusqu ici pour t amuser.
>
> **L Enfant** — Je t ai laisse venir jusqu ici parce que **je voulais voir la fin**.
> Fais-la belle.

---

## 8. ENDING — La boucle

**Scene `ending`. Fond : `act4_origin`.**

Le mage gagne. Ce n est pas prevu, et ca ne change rien — un dieu vaincu ne meurt pas,
il **arbitre**. Avant de s eteindre, l enfant rend son verdict : puisque le mage aime
tant reculer dans le temps, il y restera.

Le mage est scelle dans une boucle temporelle : la meme bataille, toujours, sans date
de fin. C est le **mode infini** (Massacre) — diegetiquement, le jeu apres le jeu.

### Dialogue (scene `ending`)

> **L Enfant** — Bien joue. Vraiment.
>
> **Le Mage** — Rends-moi Nuri. Rends-moi Nox.
>
> **L Enfant** — Je ne rends rien, je **place**. Et toi, je te place ici.
>
> *narrateur* — Le registre se referme sur une seule page, qui recommence.
>
> **L Enfant** — Tu as voulu recommencer une fois. Recommence autant que tu veux.
>
> **Le Mage** — ... C est cense etre une punition ?
>
> **L Enfant** — C est cense etre un cadeau. Tu verras a la millieme vague.
>
> *narrateur* — MODE INFINI DEBLOQUE.

---

## 9. Ce que chaque acte doit faire ressentir

| Acte | Sensation visee | Traduction mecanique |
|---|---|---|
| Prologue | on a deja perdu une fois | aucun combat, texte seul |
| 1 — Nuri | apprendre, puis douter | vagues lentes, puis le corniste qui donne la cadence |
| 2 — Sky Lands | on monte, l air est mince | volants, plates-formes, premiers passifs |
| 3 — Tombol | poursuivre quelqu un | arrieres-gardes, murs d os, on arrive toujours apres |
| 4 — Demons | choisir son epreuve | 4 niveaux ouverts, 4 styles opposes |
| 5 — Divin | tout revient, plus rien n impressionne | anciens boss en vagues normales |
| Ending | ca ne finit pas | deblocage du Massacre |

---

## 10. Notes d implementation

- **Aucun nouveau type de monstre.** Les 21 existants portent les 5 actes : la
  narration re-contextualise (le Gardien devient un conscrit retourne, Chronos devient
  de la vermine a l acte 5).
- **Etat actuel du code** (chantier N) : **9 niveaux** existent sur les 21 que decrit
  ce document. L **acte 1 est complet** — ses quatre etapes sont livrees, testees et
  capturees. Les actes 2 a 5 restent la **cible** : 12 niveaux a ecrire.

- **LES IDENTIFIANTS NE SUIVENT PAS L ORDRE DE JEU, ET C EST VOULU.** Le chantier N a
  choisi de ne PAS renumeroter la campagne : les identifiants `lvl_01`..`lvl_07` sont
  graves dans les sauvegardes des joueurs (`levels_done`, `current_level`,
  `stories_seen`). Les renumeroter pour coller aux lieux de ce document aurait casse la
  progression de quiconque a deja joue, pour un gain que le joueur ne voit jamais — il
  lit le NOM du niveau et l ACTE, pas l identifiant. C est donc `LevelDef.act` qui porte
  le plan de ce document.

  | Acte | Etapes du document | Niveaux livres, dans l ordre de jeu |
  |---|---|---|
  | 1 — La foret de Nuri | 4 | `lvl_01`, `lvl_02`, `lvl_08`, `lvl_09` — **complet** |
  | 2 — Les Sky Lands | 4 | `lvl_03`, `lvl_04` (2 manquants) |
  | 3 — Le cimetiere de Tombol | 5 | `lvl_05`, `lvl_06` (3 manquants) |
  | 4 — Le monde demoniaque | 5 | `lvl_07` (4 manquants) |
  | 5 — L espace divin | 3 | aucun (3 manquants) |

  `tests/unit/test_campaign_acts.gd` verrouille ce tableau : sa table `ACTES_LIVRES`
  dit quels actes sont declares finis, et le compte doit alors tomber juste.

- **Un boss de campagne n est pas obligatoire a chaque niveau.** Le catalogue compte
  7 boss et 8 mini-boss pour 21 niveaux vises, et `test_bosses` refuse qu un adversaire
  mene deux niveaux. On reserve donc `is_boss` aux **fins d acte** — ce que ce document
  decrit deja : l acte 1 se ferme sur le Gardien, il n aligne pas quatre boss.
  Les niveaux intermediaires culminent sur un mini-boss.

- Les scenes generees couvrent le prologue et l acte 1 entier. Attention : la route du
  maire et le dirigeable sont les scenes `lvl_08_*` et `lvl_09_*`, pas `lvl_03_*` /
  `lvl_04_*` — ces dernieres ont ete supprimees, elles faisaient parler le maire du
  dirigeable devant l ossuaire de l acte 2.
- Les scenes de visual novel sont des `DialogueDef` dans `resources/story/`, generees
  par `tools/make_story.gd`. Un niveau les nomme par `intro_story` / `outro_story`.
- `SceneRouter` seul sait qu une scene s intercale : ni le menu, ni `GameController`,
  ni l ecran de victoire n en savent rien.
- Les scenes sont **coupees en headless** (`SceneRouter.stories_enabled`) : le smoke et
  le banc d equilibrage appellent `start_level()` en boucle et n ont pas de doigt pour
  faire defiler un dialogue.
- Seule l **Exploration** raconte l histoire. Le Massacre est, diegetiquement, ce qui
  vient apres la derniere scene : il n a pas de dialogue.
