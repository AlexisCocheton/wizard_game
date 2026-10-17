# Wizard Story — Battle of the Time

Document de reference narratif, version 3 (vague 10, chantier B4, 14/10). Il
decrit l histoire TELLE QU ELLE SE JOUE : les 21 niveaux de la campagne, leurs
noms, leurs tetes et les 43 scenes qui les encadrent. La version 2 decrivait un
plan dont les identifiants ne correspondaient plus au jeu (revue A4, §2.5).

**La source de verite du texte est `tools/make_story.gd`** (scenes) et, pour les
niveaux, `tools/make_content.gd` (`display_name`, `subtitle`, `intro_text`). Ce
document donne le lieu, ce que chaque scene doit faire et les repliques qui
portent l intrigue ; il ne recopie pas chaque replique, pour ne plus diverger.

Conventions :
- Les scenes portent un id (`prologue`, `lvl_01_intro`, `lvl_01_outro`...) qui est le
  nom du `.tres` dans `resources/story/`, genere par `tools/make_story.gd`.
- Une scene n existe que si un niveau la cite (`intro_story` / `outro_story`) : une
  scene orpheline ne se joue jamais, et `test_story` la refuse. Le prologue est la
  seule exception (`SceneRouter` le joue avant le premier niveau).
- Les textes de jeu sont **sans accents ni tiret long** : la police du jeu
  (`planes_valmore.ttf`) n en a pas. Ce document, lui, en porte — c est de la
  documentation, pas de la donnee.
- Une scene ne se joue qu **une fois par profil** (`SaveData.stories_seen`), et
  seulement en mode CAMPAGNE : le LIBRE et le MASSACRE n ont pas d histoire.

### Regles d ecriture (pour qui ajoute une scene, quetes annexes comprises)

- Une replique tient en **moins de 180 caracteres** (la boite fait ~54 x 7) ; la
  plus longue du jeu en fait 145.
- **Le mage parle a gauche**, tous les autres a droite. Le narrateur n a ni nom ni
  portrait.
- **Le narrateur decrit ce qui se passe a l ecran.** S il nomme un monstre, ce
  monstre est dans les vagues du niveau (`test_story` le verifie). Les personnages,
  eux, ont le droit de se souvenir.
- **Une scene ne suppose jamais un ordre que le joueur peut ne pas avoir suivi** :
  la fourche de l acte 3 se joue en une branche ou deux, l acte 4 dans n importe
  quel ordre.
- Un locuteur porte son NOM (« Sesh », « Kaltek ») des que le mage le connait ;
  « Un mort » reste anonyme parce que c est un choeur.
- Chaque niveau de la campagne a son intro et son outro (`test_story`). Une quete
  annexe peut s en passer.

---

## 1. Les personnages

| Personnage | Qui il est | Le secret |
|---|---|---|
| **Le Mage** | Le dernier survivant. Chauve : ses cheveux sont partis avec ses pouvoirs quand il a force le temps a reculer | Il ne lui reste presque rien. Le multiplicateur de vitesse est tout ce qu il sait encore faire |
| **L Enfant** | Un gamin de la foret de Nuri, sauve au niveau 1. Suit le mage toute la campagne. Pose les questions que le joueur se pose | **C est une divinite.** Le boss final. Le mage l a sauve avant de comprendre qu il transportait sa propre fin |
| **Le Rat pilote** | Un rat parlant, mecanicien du dirigeable ecrase. Rejoint le groupe a la fin de l acte 1 (`lvl_09`) ; reste avec la nacelle pendant la poursuite de Tombol et revient pour la descente (`lvl_21_outro`) | Il a deja vu le monde finir. Il ne le dit pas : il repare, c est sa facon de refuser |
| **Le Roi squelette** | Souverain du cimetiere de Tombol. Fuit devant le mage pendant tout l acte 3, puis descend avec lui (`lvl_21_outro`) et l accompagne jusqu a la fin | Il ne fuyait pas le mage : il fuyait les demons qui le tenaient par contrat |
| **Le Maire** | Maire du village de l enfant, acte 1. Le seul du village qui ne soit pas en pierre : il se cachait dans la grange depuis trois jours | Il sait depuis des mois que l attaque vient d une autre ile, et il s est tu pour ne pas affoler |
| **Le Gardien de la foret** | L esprit protecteur de Nuri, « celui de l arbre ». Un chevalier en armure noire ; dedans, du bois | Il n est pas devenu fou : il a ete **retourne** (une plaque de metal noir dans la poitrine). Premiere preuve que quelqu un commande aux monstres |

Les adversaires qui ont un nom :

| Nom | Ou | Ce qu il est dans l histoire |
|---|---|---|
| **Chronos** | boss de `lvl_01`, Echos aux `lvl_15` et `lvl_16` | « l huissier des delais » ; le mage le reconnait (il etait la, la premiere fois). Le boss final porte SA silhouette, en or : l huissier avait la forme de son maitre |
| **Les gorgones** (Gorgone, Matrone, Reine) | `lvl_02` ; la Reine revient en mini-boss de `lvl_13` | Leur regard fige des sorts dans la main du mage tant qu elles vivent. Elles sont passees au village, mais ce ne sont pas elles qui l ont petrifie |
| **Vharn, Sesh, Kaltek, Ymoa** | `lvl_07`, `lvl_10`, `lvl_11`, `lvl_12` | Les quatre grands demons. Chacun se croit le patron ; chacun a signe sans lire |
| **Malyk** | boss de `lvl_13` | Celui qui porte les ordres aux seigneurs, et mange ce qu il appelle. Un coursier de plus |
| **L Enfant** | boss de `lvl_16` | Le compagnon du mage depuis la premiere clairiere, et l auteur de la date |

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

Les dialogues ne se jouent pas devant le fond de COMBAT de l acte (`test_story`
refuse un fond `act*`). Il n existe que cinq decors peints, pris dans le pack
**Wood Elves** et copies par `tools/story/build_backdrops.py`, tous forestiers. Ils
sont choisis par ce que l IMAGE montre (relu au chantier B4) :

| Decor | Ce qu il montre | Scenes |
|---|---|---|
| `talk_glade` | la clairiere au petit matin, la lumiere entre les racines | `lvl_01_*`, et `lvl_16_outro` (la boucle se referme sur le premier matin) |
| `talk_village` | des maisons de bois sous de grands arbres | `lvl_02_*` |
| `talk_path` | un sentier et une cabane de bois | `lvl_08_*` (la grange du maire), `lvl_18_*` (les entrepots du port) |
| `talk_greattree` | un grand arbre blanc sur une colline, des nuages | `lvl_09_*` (l arbre du Gardien), `lvl_17_*` (le ciel des courants) |
| `talk_shrine` | un sanctuaire de pierre sous la lune, des statues, de l eau | le `prologue`, et tout ce qui est funeraire, souterrain ou hors du monde : `lvl_03`, `lvl_04`, tout l acte 3, tout l acte 4, l acte 5 sauf la fin |

**Limite connue** : les actes 3 a 5 (forge, arene, fosses, temple, registre) se
jouent tous devant `talk_shrine`, le moins faux des cinq. Des decors dedies sont a
fabriquer (asset-pipeline).

---

## 2. PROLOGUE — Ce que le mage a deja perdu

**Scene `prologue`. Decor : `talk_shrine`. Aucun niveau : se joue avant l intro de `lvl_01`.**

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
> *narrateur* — La foret de Nuri a brule en six jours. La ville de Nox, promise aux
> siecles, a tenu une nuit.
>
> **Le Mage** — Je n ai pas su les arreter. Alors j ai arrete le temps.
>
> *narrateur* — Il a tout donne d un coup. Sa magie, ses annees, et jusqu au dernier
> de ses cheveux.
>
> **Le Mage** — Me voila revenu avant. Avant la foret. Avant la ville. Avant eux.
>
> **Le Mage** — Il ne me reste qu une chose : aller vite. Plus vite que ce qui arrive.
>
> **Le Mage** — Cette fois je ne vais pas defendre. Je vais remonter le courant jusqu a
> l origine du mal.

---

## 3. ACTE 1 — La foret de Nuri

**Niveaux, dans l ordre de jeu : `lvl_01`, `lvl_02`, `lvl_08`, `lvl_09`.** Fond de
combat `act1_sky`. Vermine de foret (`gnome`, `sprite`, `hopper`, `rat_swarm`,
gelees, `hive`, `hornblower`, `sleepy_fox`), la lignee des gorgones au village,
le Gardien a la fin.

C est l acte ou le joueur apprend le jeu et ou le mage apprend qu il n a rien compris :
les betes de la foret ne se comportent pas comme des betes.

### `lvl_01` — « La lisiere de Nuri » (tutoriel)

Mini-boss : le Gardien (a remplacer, voir plus bas). Boss : **Chronos**.

Le mage revient au premier matin, vide, et entend un cri : un **enfant**. Il le
sauve. C est le geste qui condamne tout — mais il faudra cinq actes pour le savoir.

**Scene `lvl_01_intro`** (`talk_glade`) : le lieu, le jour (six jours avant la fin
de Nuri), la faiblesse du mage (« De quoi lancer quelques sorts et courir vite »),
le cri.

**Scene `lvl_01_outro`** (`talk_glade`) : l enfant entre dans l histoire. Le mage
**reconnait Chronos** a son cadran — « L huissier des delais. Il etait deja la, la
premiere fois, quand Nox est tombee » — puis l enfant l emmene a son village.

> **L Enfant** — Tu les as tous fait tomber ! Meme le grand ! Comment on fait ca ?
>
> *narrateur* — Le plus grand d entre eux porte un cadran a la place du coeur. Les
> aiguilles tournent encore.
>
> **Le Mage** — Chronos. L huissier des delais. Il etait deja la, la premiere fois,
> quand Nox est tombee.
>
> **Le Mage** — ... Des gnomes qui attaquent un village. Les gnomes ne font pas ca.

Le mini-boss du tutoriel est le Gardien, que l enfant presente en allie au
`lvl_09` puis qui y meurt : aucune scene du `lvl_01` ne le cite, et le
remplacer est demande a B2 (`docs/revue_vague10.md` §2.7).

### `lvl_02` — « Le village petrifie »

Mini-boss : la **Matrone gorgone** (fige 2 cartes). Dans les vagues : deux
Gorgones (1 carte chacune), un Corniste qui presse les autres. Boss : le Coagule,
puis la **Reine gorgone** (3 cartes) a la fin de la vague de boss.

Demande du co-auteur (vague 10) : quand on retrouve les gorgones, le dialogue dit
qu on retrouve **le village petrifie**. La scene fait trois choses :
1. montrer le village en pierre ;
2. apprendre la mecanique AVANT la Matrone : un regard de gorgone fige des sorts
   dans la main tant qu elle vit, la reponse est de l abattre d abord ;
3. garder l indice de la **cadence** (ils marchent au pas), qui revient chez Vharn.

**Scene `lvl_02_intro`** (`talk_village`)

> **L Enfant** — C est la ! La maison sous le grand arbre, c est chez moi !
>
> *narrateur* — Le village est debout. Ses gens aussi : en pierre, figes au milieu
> d un geste.
>
> **L Enfant** — Ils ne repondent pas. Pourquoi ils ne repondent pas ?
>
> **Le Mage** — Des gorgones sont passees. Il en reste. Si l une d elles regarde mes
> sorts, ils se figeront dans ma main.
>
> **Le Mage** — Alors on les abat en premier. Et regarde les autres : ils marchent au
> pas. Quelqu un leur bat la mesure.

**Scene `lvl_02_outro`** (`talk_village`) — le PREMIER GRAIN du retournement final :

> *narrateur* — La Reine gorgone s effondre au milieu de la place. Les sorts du mage
> se degelent d un coup. Les gens du village, eux, restent en pierre.
>
> **Le Mage** — Ce qu une gorgone fige, sa mort le libere. Pas eux. Quelqu un les a
> figes avant elle.
>
> **L Enfant** — Ils sont bien comme ca. Ils n ont plus peur.
>
> **Le Mage** — ... Ou est ton maire, petit ?
>
> **L Enfant** — Dans la grange. Il s y cache depuis trois jours.
>
> **Le Mage** — Trois jours. Avant meme l attaque. Et lui n est pas en pierre.

Echos : « Mon village est en pierre derriere moi » (`lvl_08_intro`) ; la Reine
« recollee » garde le pentacle (`lvl_13_intro`) ; « Les statues du village, c etait
moi. Les gorgones n ont fait que signer en dessous » (`lvl_16_intro`).

### `lvl_08` — « La route du maire »

Mini-boss : le Totem ancien. Gelees qui se divisent, ruches qui eclatent : la
pression est le **nombre**, premiere vraie lecon de zone.

**Scene `lvl_08_intro`** (`talk_path`) : le maire, seul du village a ne pas etre en
pierre, avoue : ce n est pas Nuri qui est attaquee, c est **toute l ile**, et ca vient
d en haut — les **Sky Lands**. Un dirigeable s est ecrase au bout de la route.
L enfant insiste pour venir : « Mon village est en pierre derriere moi. Il n y a plus
rien a garder. Je viens. »

**Scene `lvl_08_outro`** (`talk_path`) : la carcasse du dirigeable, « quelqu un tape
dedans avec un outil » ; au loin, quelque chose de tres grand se met debout.

### `lvl_09` — « Proteger le dirigeable » (fin de l acte 1)

Mini-boss : le Seigneur de braise. Boss : **le Gardien de la foret**. Le rat repare
pendant le combat.

C est la premiere preuve dure : on ne **devient** pas fou en six jours. On est
**retourne** par quelqu un.

**Scene `lvl_09_intro`** (`talk_greattree`) : le rat pilote se presente (« Il manque
une valve, deux ailerons et ma patience »), les arbres s ecartent.

> **L Enfant** — C est le Gardien ! Le vrai, celui de l arbre. C est lui qui protege
> la foret, il va nous aider !
>
> **Le Mage** — Petit... il marche sur les arbres, pas entre.

**Scene `lvl_09_outro`** (`talk_greattree`)

> *narrateur* — Le Gardien s effondre. Son armure s ouvre comme une ecorce : dedans,
> du bois mort, et plantee comme une echarde, une plaque de metal noir.
>
> **Le Gardien** — ... pas... voulu...
>
> **Le Mage** — Il n est pas devenu fou. On lui a mis quelque chose dedans.
>
> **Le Rat pilote** — Vu la soudure, c est du travail d en haut. Sky Lands. Je connais
> le style, j en viens.

---

## 4. ACTE 2 — Les Sky Lands

**Niveaux, dans l ordre de jeu : `lvl_17`, `lvl_18`, `lvl_03`, `lvl_04`.** Fond de
combat `act1_sky` pour les deux etapes de vol, `act2_graveyard` pour les deux
dernieres : on monte, puis on touche le cimetiere. Les **premiers passifs** se
debloquent ici.

Le groupe monte. Les Sky Lands ne sont pas une ile sauvage : c est un archipel habite,
un **atelier**, en train d etre vide par le haut. Et au bout, un cimetiere ou les morts
se levent et **parlent** — ce sont eux qui lachent le premier vrai nom.

| Niveau | Nom affiche | Tetes | Ce que disent les scenes |
|---|---|---|---|
| `lvl_17` | Les courants | mini-boss **Grand Oeil des courants** | le rat et ses regles (« la regle deux c est qu il n y a pas de regle deux ») ; le Grand Oeil tombe dans les cordages : « derriere l oeil, la meme soudure noire que dans la poitrine de votre Gardien ». Les Sky Lands sont un atelier, le rat y a travaille |
| `lvl_18` | Port de Haute-Nacelle | mini-boss **Mage noir de Haute-Nacelle** | un port vide « par le haut » ; le Mage noir porte la meme soudure ; **premier grain du retournement** : l enfant sait que « la gauche est fermee » |
| `lvl_03` | L ossuaire de bordure | mini-boss Slime enorme ; boss **le Reliquaire** | des tombes rangees en quantites ; le Reliquaire livre les registres : « Les trois dernieres annees, on n a plus compte des morts. On les a COMMANDES. » |
| `lvl_04` | Le Grand Appel | mini-boss Briseur de tertres ; boss **l Ensevelisseur** | le rituel des Pretres goules reussit ; ce qui sort du cercle s appelle l Ensevelisseur ; quand il tombe, les morts s arretent et **parlent** |

**`lvl_18_outro` — l enfant montre quelque chose qu il ne devrait pas savoir**

> **L Enfant** — Il faut passer par la droite. La gauche est fermee.
> **Le Mage** — Tu es deja venu ici ?
> **L Enfant** — Non. Mais c est ferme. Je le sais, c est tout.
> **Le Mage** — ... D accord. Par la droite.

Le mage le note et n y revient pas — le joueur non plus, jusqu a l acte 5.

**`lvl_03_outro` — le stock**

> **Le Mage** — Ils ne vont pas nous effacer par haine. Ils vont nous effacer pour
> faire du STOCK.
>
> **Le Mage** — On ne range pas des morts en colonnes si on ne compte pas s en servir
> tous ensemble.

Le mage parle au FUTUR : dans cette boucle-ci, l extinction n a pas encore eu lieu.

**`lvl_04_outro` — l origine est lachee**

> *narrateur* — Ce qui est sorti du cercle s appelle l Ensevelisseur. Quand il tombe,
> les morts cessent de charger.
>
> **Un mort** — Ce n est pas nous. Nous, on nous a reveilles.
>
> **Un mort** — Par l ordre de Tombol. Le Roi squelette a signe. Il a signe pour nous
> tous et il n avait pas le droit.
>
> **Le Rat pilote** — Tombol, c est trois iles plus loin. Le grand cimetiere.

---

## 5. ACTE 3 — Le cimetiere de Tombol

**Niveaux, dans l ordre de jeu : `lvl_19`, `lvl_20`, la fourche `lvl_05` /
`lvl_06` (une branche ou les deux, dans l ordre voulu), puis `lvl_21`.** Fond de
combat `act2_graveyard`, sauf la fourche en `act3_demon` (voir plus bas).

Le Roi squelette **fuit**. Tout l acte est une poursuite : a chaque niveau on arrive
juste apres lui, on brise ce qu il a laisse derriere pour retarder. Puis on comprend
pourquoi il court. Le rat reste avec la nacelle (`lvl_19_intro`) ; le mage et
l enfant avancent seuls jusqu au pentacle.

| Niveau | Nom affiche | Tetes | Ce que disent les scenes |
|---|---|---|---|
| `lvl_19` | Les fosses basses | mini-boss Sorciere des fosses ; boss : **le trio des mages** (braise, givre, arcanes) | on entre dans Tombol par le bas, l eau est encore trouble : le roi vient de passer. Les trois mages ne cherchaient pas a tuer le mage, mais a le RETARDER |
| `lvl_20` | La cour des rois morts | mini-boss Epeiste d ombre | des statues de rois, des gardes laisses a mourir pour gagner une heure : « on fait ca quand on fuit un creancier ». Au fond, **deux escaliers** : l un descend vers une lueur rouge, l autre remonte vers la salle du trone |
| `lvl_05` | Les forges sous Tombol | mini-boss Miroir de Forge ; boss Colosse des Forges | l escalier qui descend mene a une forge : Tombol ne coule pas d armures, quelqu un l a installee sous ses pieds. Poincon sur chaque piece : **un cercle a cinq branches**. « Tombol paie l atelier. Avec ses morts. » |
| `lvl_06` | La cour brisee | mini-boss le Bourreau ; boss Seigneur Spectre | l escalier qui remonte mene a la salle du trone vide : la cour du roi s entretue pour le trone. Le dernier seigneur tombe sur le **sceau royal, casse** : « ce qu il a signe est deja parti. En bas. » |
| `lvl_21` | Le pentacle | mini-boss le Fossoyeur ; boss **Sceau de Tombol** | le roi accule ; le retournement (ci-dessous) ; le rat revient avec la nacelle, et tout le monde descend |

**La fourche.** `lvl_05` et `lvl_06` etaient une fourche equilibree au banc
(blindes d un cote, monstres a effets de l autre), conservee au milieu de l acte.
Elles n avaient ni scene ni texte de l histoire actuelle jusqu au chantier B4.
Leurs scenes se lisent chacune SEULE (on peut n en jouer qu une) et ne se citent
pas l une l autre. Leur fond de combat rouge (`act3_demon`) est devenu un INDICE :
« rouge de ce qui remonte d en dessous ». On y voit que quelque chose remonte sous
Tombol, jamais QUI : c est le roi qui le montre, au `lvl_21` (« Voila mes
creanciers »).

**Le trio des fosses basses** (chantier W2). Trois gardiens de la pierre du
pentacle — la famille du Sceau de Tombol — que le roi laisse derriere lui au
premier niveau de la poursuite. Ils arrivent ensemble, chacun avec sa table et son
pouvoir : le rouge revient trois fois du haut, le bleu avance au rythme du mage,
le magenta ignore ses dix premiers coups. Le document les voulait dans la cour
des rois morts (« statues ») ; le banc a tranche : `lvl_20` se gagnait 13 fois sur
30 avant tout ajout, `lvl_19` 30 fois sur 30. Ils reviennent en ADEPTES (vermine)
dans l acte 5.

`lvl_21` EST LE PORTAIL DE L ACTE 4, et le seul : c est lui qui ouvre les quatre
grands demons d un coup.

### `lvl_21` — le retournement de l acte 3

**Scene `lvl_21_intro`** (`talk_shrine`)

> **Le Roi squelette** — Te voila enfin. Tu cours vite pour un homme qui n a plus rien.
>
> **Le Mage** — Tu as signe la fin de Nuri et de Nox.
>
> **Le Roi squelette** — J ai signe pour SAUVER Tombol. Ils sont venus avec un contrat
> deja ecrit, mage. On ne negocie pas avec ce qui monte de ce puits.
>
> **Le Mage** — Qui monte de ce puits ?
>
> **Le Roi squelette** — Regarde derriere moi et arrete de poser la question.

**Scene `lvl_21_outro`** (`talk_shrine`)

> *narrateur* — Le sceau se fend. Ce qui passe au travers n a pas d yeux et sait
> exactement ou tout le monde se tient.
>
> **Le Roi squelette** — Voila mes creanciers. Ils m ont pris mes morts, mes terres et
> ma signature. Ils te prendront ta boucle.
>
> **Le Roi squelette** — Ils savent que tu as recule le temps, mage. Tout le monde en
> bas le sait. C est pour CA qu ils avancent si vite maintenant.
>
> **Le Mage** — ... Alors c est moi qui ai accelere la fin.
>
> **Le Roi squelette** — Tu as change la date, pas la fin. Fais-moi une place, je
> descends avec toi. Je n ai plus rien a perdre.
>
> *narrateur* — Au bord du puits, la nacelle attend, moteur deja chaud.
>
> **Le Rat pilote** — J ai dit que je restais avec la nacelle. Elle descend, alors je
> descends.
>
> **Le Mage** — On descend.

---

## 6. ACTE 4 — Le monde demoniaque

**Niveaux : `lvl_07`, `lvl_10`, `lvl_11`, `lvl_12` dans l ordre libre, puis
`lvl_13`.** Fond de combat `act3_demon`. Groupe : le mage, l enfant, le rat, le roi.

Structure particuliere, demandee : les **4 premiers niveaux sont ouverts d emblee**,
un par grand demon. Le joueur choisit son ordre et son style. Le cinquieme doit
s ouvrir apres les quatre.

| Niveau | Le demon | Tetes | Ce que disent les scenes |
|---|---|---|---|
| `lvl_07` | **Vharn, l Enclume** (« La forge de Vharn ») | mini-boss Golem a noyau | une forge sans forgeron, la cadence du corniste ; Vharn ne parle pas. Dans l Enclume, un contrat : la signature du roi, et au-dessus une ecriture « petite et soignee ». L enfant a compte : « Le pentacle a cinq branches. Quatre portent un nom. » |
| `lvl_10` | **Sesh, la Faim** (« Les fosses de Sesh ») | — | Sesh a suivi l odeur d un monde qui finit ; il a signe sans lire, « il etait deja a table ». Quelqu un a prevenu les charognards avant le mort |
| `lvl_11` | **Kaltek, la Chaine** (« L arene de Kaltek ») | mini-boss Ecumeur du ciel | « Personne ne me tient ! » ; ses chaines partaient de lui, vers le haut : un contremaitre |
| `lvl_12` | **Ymoa, le Cercle** (« Le temple d Ymoa ») | mini-boss Jumeaux du Cercle | « Je ne me bats jamais. Je PROTEGE. » Il protegeait l ordre sans savoir ce qu il contenait. « Bienvenue en enfer, mage. C est une administration. » |
| `lvl_13` | le pentacle brise | mini-boss **Reine gorgone** ; boss **Malyk** | la Reine, brisee au village, « recollee », garde la porte ; Malyk porte les ordres aux seigneurs et mange ce qu il appelle : un coursier de plus. Le pentacle se fend en cinq ; « ta main est froide comme le puits » ; la chute ne va pas vers le bas |

**L ecriture est commutative.** Aucune scene des quatre demons ne suppose ce que
le joueur a deja vu, ni ne compte ce qui reste (« il y en a trois autres »,
« quatre seigneurs » sont retires). Chaque outro apporte le meme fait — celui-la
non plus ne savait pas ce qu il signait — par un chemin different.

**La logique des contrats**, une fois pour toutes : chaque seigneur tient un
contrat signe par le Roi squelette, et AU-DESSUS de sa signature une ecriture
petite et soignee que personne n a jamais vue. Malyk porte les ordres ; l ecriture
est celle du registre (« meme encre, meme main », `lvl_15`), donc de l enfant.

**Le deblocage, limite connue.** Chaque demon porte `next_levels = [lvl_13]` ;
`SaveData.record_victory` ouvre tout `next_levels` des la PREMIERE victoire, donc le
pentacle s ouvre apres UN seul demon. Le corriger est du code (renvoye,
`docs/revue_vague10.md` §2.7) ; en attendant, les scenes de `lvl_13` parlent « des
seigneurs », jamais « des quatre », et tiennent dans les deux cas.

**Les quatre grands demons** partagent la SILHOUETTE de la famille qu ils commandent
(golem, glouton, berserker, totem) : le seigneur porte l apparence de ses sujets.
Ils parlent avec un portrait commun (le pack n a qu un visage de demon), mais sous
leur NOM.

Les quatre grands demons ne se coordonnent pas : chacun croit etre le commanditaire.
C est le comique noir de l acte — le mage descend en enfer pour trouver un chef et
trouve **quatre directeurs** dont aucun n a lu ce qu il signait.

### `lvl_13` — le pentacle brise

**Scene `lvl_13_intro`** (`talk_shrine`)

> *narrateur* — Au centre du monde demoniaque, le pentacle. Devant sa porte, une
> silhouette que le mage connait.
>
> **Le Mage** — La Reine gorgone. Je l ai brisee dans le village de l enfant.
>
> **Le Roi squelette** — Ici, on recolle les statues. Elle garde la porte. Derriere,
> Malyk ramasse ce qui a deja servi.
>
> **Le Roi squelette** — Celui qui porte les ordres aux seigneurs. Il mange ce qu il
> appelle. Les seigneurs n ont jamais lu l ordre : ils l ont RECU de lui.
>
> **Le Rat pilote** — J ai deja vu ca. Un atelier ou personne n est le patron : ca
> veut dire que le patron n habite pas l atelier.

**Scene `lvl_13_outro`** — LA DERNIERE REPLIQUE DU MAGE EST LE SEUL INDICE HONNETE
du plot twist, posee sans commentaire comme « la gauche est fermee » a l acte 2 :

> *narrateur* — Malyk tombe, et le pentacle qui tient le monde demoniaque se fend en
> cinq morceaux. Le monde avec lui.
>
> **Le Roi squelette** — Non. On nous RETIRE. Comme on retire une piece du plateau.
>
> **L Enfant** — Ne lachez pas ma main.
>
> **Le Mage** — Petit, ta main est froide comme le puits.
>
> *narrateur* — La chute ne va pas vers le bas.

---

## 7. ACTE 5 — L espace divin

**Niveaux : `lvl_14`, `lvl_15`, `lvl_16`.** Fond de combat `act5_divine`. Les
anciens boss redeviennent des monstres ordinaires : les Echos du Gardien et de
Chronos descendent en vagues sans nom, et c est exactement le propos.

Il n y a pas de sol. Il y a des **registres** : des dieux qui tiennent des comptes.

### Rebondissement — l extinction etait au programme

L humanite n a pas ete attaquee. Elle a ete **planifiee pour s eteindre**, a la date
prevue, comme une saison se termine. Les monstres n etaient que l outil du calendrier.
Les dieux ne sont ni cruels ni interesses : ils sont **assis**.

Et le retour en arriere du mage ne les a pas inquietes. Il les a **amuses**. Un pion
qui recule sur le plateau, c est la premiere chose distrayante depuis des eons. Ils ont
laisse courir pour voir jusqu ou il irait. Toute la campagne est un **spectacle** qu on
leur a offert.

| Niveau | Nom affiche | Tetes | Ce que disent les scenes |
|---|---|---|---|
| `lvl_14` | La galerie des saisons | mini-boss Cameleon des saisons ; boss Slime colossal | un musee de tout ce qui a deja ete efface, range par saison : « C est un Gardien. Il y en a deux autres derriere. » Les gardiens de la galerie tombent « sans bruit, comme des pieces qu on range ». L enfant ne parle plus depuis le pentacle |
| `lvl_15` | Le registre | mini-boss le Greffier ; boss **l Horloger** | des colonnes de DATES : Nuri, Nox, Tombol, « meme encre, meme main ». Le rat savait. L Horloger tombe et le registre s ouvre sur la ligne du mage : la date raturee, et dans la marge, d une ecriture petite et soignee, « inattendu », souligne deux fois |
| `lvl_16` | Le siege vide | boss **L Enfant** | le plot twist (ci-dessous), puis la fin du jeu |

**Le propos de l acte est une regle mecanique**, pas une ambiance. Les Echos du
Gardien descendent par deux puis par trois dans des vagues SANS nom, ceux de
Chronos aussi, et la premiere vague du siege vide les envoie sans fanfare. Les
anciens boss promus en vermine sont des `.tres` DERIVES (plus legers, mecanique
simplifiee) : `warden_echo`, `chronos_echo`, `blood_clot` (le Coagule),
`mirror_shard` (le Miroir de Forge), les adeptes du trio des fosses.

**Les tetes de l acte 5** (chantier W2). La galerie et le registre n avaient ni
mini-boss ni (pour le registre) boss, faute de catalogue. Ils en ont, et ce sont
des tetes qui ne sont PAS d anciens boss : le Cameleon des saisons (la galerie qui
tourne avec les saisons), le Slime colossal (toutes les gelees du voyage refondues
en une), le Greffier (le commis qui rature une carte de la main) et l Horloger
(celui qui remonte le temps, comme le mage l a fait). Le siege vide garde son
tete-a-tete : aucune tete intermediaire.

`lvl_16` ferme la campagne (`next_levels` vide). Le Massacre s ouvre quand CHAQUE
niveau de la campagne est fini (`SaveData.massacre_unlocked()` =
`campaign_cleared()`, les deux branches de la fourche comprises, les quetes
annexes non) : la recompense demande la campagne entiere, ce qui est son sens, et
ce que la fin raconte.

### `lvl_16` — le plot twist

**Scene `lvl_16_intro`** (`talk_shrine`). LE PORTRAIT BASCULE au milieu de la
scene : l enfant parle avec le visage du gamin (`child`), puis le narrateur dit
qu il arrete de faire semblant, et toutes ses repliques suivantes portent le
masque d or (`child_god`).

> *narrateur* — L enfant lache la main du mage. Il ne grandit pas, il ne change pas de
> forme. Il arrete simplement de faire semblant d avoir peur.
>
> **L Enfant** — Tu m as porte jusqu ici, mage. Merci. C etait tres long a pied.
>
> **Le Mage** — ... Tu etais la depuis la premiere clairiere.
>
> **L Enfant** — J etais la depuis la date. C est moi qui l ai posee. Nuri le sixieme
> jour, Nox la septieme nuit. C etait propre.
>
> **L Enfant** — Les statues du village, c etait moi. Les gorgones n ont fait que
> signer en dessous.
>
> **Le Roi squelette** — Le gamin. C est le gamin. J ai signe un contrat pour UN GAMIN.
>
> **L Enfant** — Je t ai laisse venir jusqu ici parce que je voulais voir la fin.
> Fais-la belle.
>
> *narrateur* — Il s assoit sur le siege, et ce qui s en releve n a plus rien d un
> enfant : une bete de cadrans, toute en or.
>
> **Le Mage** — La forme de Chronos. Ton huissier portait ta forme depuis le premier
> matin.

Le boss final a la silhouette de Chronos (`juggernaut`), teinte d or : la scene le
dit, sinon le joueur croit affronter un Chronos de plus. « Il ne change pas de
forme » reste vrai au moment ou le masque tombe ; c est en se relevant du siege,
pour le combat, qu il la prend.

---

## 8. LA FIN — La boucle

**Elle se joue en OUTRO de `lvl_16`** (`talk_glade`), et non comme une scene a
part : `SceneRouter` ne connait que `intro_story` et `outro_story`. Son decor est la
clairiere du premier matin — la boucle se referme a l image en meme temps que dans
le texte.

Le mage gagne. Ce n est pas prevu, et ca ne change rien — un dieu vaincu ne meurt pas,
il **arbitre** : puisque le mage aime tant reculer dans le temps, il y restera. Le rat
et le roi restent avec lui. C est le **Massacre** — diegetiquement, le jeu apres le
jeu.

> **L Enfant** — Je ne rends rien, je PLACE. Et toi, je te place ici.
>
> *narrateur* — Le registre se referme sur une seule page, qui recommence.
>
> **L Enfant** — Tu as voulu recommencer une fois. Recommence autant que tu veux.
>
> **Le Mage** — ... C est cense etre une punition ?
>
> **L Enfant** — C est cense etre un cadeau. Tu verras a la millieme vague.
>
> **Le Rat pilote** — Moi je repare. Meme une boucle, ca se repare.
>
> **Le Roi squelette** — Je reste. Plus de royaume, autant avoir une boucle.
>
> *narrateur* — Une clairiere, au petit matin. La meme odeur de mousse, la meme
> lumiere entre les branches.
>
> *narrateur* — LE MASSACRE, la boucle sans fin, s ouvre quand chaque niveau de la
> campagne est fini.

(L ancienne derniere ligne, « MODE INFINI DEBLOQUE », annoncait un mode retire a
la vague 10 : le mode par niveau s appelle LIBRE et il a une fin ; le seul sans fin
est le Massacre.)

---

## 9. Ce que chaque acte doit faire ressentir

| Acte | Sensation visee | Traduction mecanique |
|---|---|---|
| Prologue | on a deja perdu une fois | aucun combat, texte seul |
| 1 — Nuri | apprendre, puis douter | vagues lentes ; le village petrifie et les gorgones qui figent la main ; le corniste qui donne la cadence |
| 2 — Sky Lands | on monte, l air est mince | volants, plates-formes, premiers passifs |
| 3 — Tombol | poursuivre quelqu un | arrieres-gardes, une fourche, on arrive toujours apres |
| 4 — Demons | choisir son epreuve | 4 niveaux ouverts, 4 styles opposes |
| 5 — Divin | tout revient, plus rien n impressionne | anciens boss en vagues normales |
| Fin | ca ne finit pas | le Massacre |

---

## 10. Notes d implementation

- **Les monstres** : le catalogue compte 86 `EnemyDef` (voir la memoire
  `catalog_enemies.md`). La narration re-contextualise les anciens (le Gardien devient
  un conscrit retourne, Chronos devient de la vermine a l acte 5).
- **Etat actuel du code** : **les 21 niveaux existent**, les cinq actes sont livres
  et chacun de leurs niveaux est encadre de scenes. La campagne va du prologue au
  siege vide, et la finir en entier ouvre le Massacre.

- **LES IDENTIFIANTS NE SUIVENT PAS L ORDRE DE JEU, ET C EST VOULU.** Le chantier N a
  choisi de ne PAS renumeroter la campagne : les identifiants `lvl_01`..`lvl_07` sont
  graves dans les sauvegardes des joueurs (`levels_done`, `current_level`,
  `stories_seen`). Les renumeroter pour coller aux lieux de ce document aurait casse la
  progression de quiconque a deja joue, pour un gain que le joueur ne voit jamais — il
  lit le NOM du niveau et l ACTE, pas l identifiant. C est donc `LevelDef.act` qui porte
  le plan de ce document.

  | Acte | Etapes du document | Niveaux livres, dans l ordre de jeu |
  |---|---|---|
  | 1 — La foret de Nuri | 4 | `lvl_01`, `lvl_02`, `lvl_08`, `lvl_09` |
  | 2 — Les Sky Lands | 4 | `lvl_17`, `lvl_18`, `lvl_03`, `lvl_04` |
  | 3 — Le cimetiere de Tombol | 5 | `lvl_19`, `lvl_20`, `lvl_05`, `lvl_06`, `lvl_21` |
  | 4 — Le monde demoniaque | 5 | `lvl_07`, `lvl_10`, `lvl_11`, `lvl_12` **en eventail**, puis `lvl_13` |
  | 5 — L espace divin | 3 | `lvl_14`, `lvl_15`, `lvl_16` |

  `tests/unit/test_campaign_acts.gd` verrouille ce tableau : sa table `ACTES_LIVRES`
  dit quels actes sont declares finis, et le compte doit alors tomber juste.

- **Un boss de campagne n est pas obligatoire a chaque niveau.** `test_bosses` refuse
  qu un adversaire mene deux niveaux. Jusqu au 27/09 le catalogue etait EPUISE et
  `lvl_12` a `lvl_15` se passaient de mini-boss, `lvl_15` de boss. Le chantier W2 a
  livre les tetes qui manquaient (tableau ci-dessous) ; restent sans mini-boss
  `lvl_16` (le siege vide, voulu) et sans boss les niveaux intermediaires de la
  poursuite (`lvl_08`, `lvl_17`, `lvl_18`, `lvl_20`), qui culminent sur un mini-boss.

- **Le bestiaire du 27 septembre (chantier W2).** La note « aucun nouveau type de
  monstre » ci-dessus visait la vermine qu on aurait ajoutee pour remplir ; la vague 1
  a livre douze MECANIQUES et onze SILHOUETTES qui attendaient des porteurs. Chaque
  monstre neuf porte une mecanique, et chaque mecanique a son porteur :

  | Id | Nom | Role | Mecanique | Ou il apparait |
  |---|---|---|---|---|
  | `slime_mid` | Slime moyen | P1 | enfant de division | `lvl_03`, et sort du Slime enorme |
  | `slime_huge` | Slime enorme | mini-boss | se divise en 3 Slimes moyens | mene le palier de `lvl_03` ; 2 sortent du Slime colossal |
  | `slime_colossal` | Slime colossal | boss | croute de lave, se divise en 2 Slimes enormes | boss de `lvl_14` |
  | `slime_ghost` | Slime fantome | P2 | renait en Slime squelette apres 3 s ; zigzag | `lvl_19` |
  | `slime_ghost_big` | Gros slime fantome | P4 | renait en 2 Slimes squelettes | `lvl_19` |
  | `slime_skeleton` | Slime squelette | P2 | — (la renaissance des fantomes) | `lvl_19` |
  | `sleepy_fox` | Renard dormeur | P2 | dort 2 s : aucun sort pendant son sommeil | `lvl_09`, `lvl_14` |
  | `cacodaemon` | Cacodemon | P3 | vole, rebondit d un bord a l autre | `lvl_10`, sbire de Malyk |
  | `mecha_golem` | Golem a noyau | mini-boss | laser sur le mage a chaque coup qui mord | mene le palier de `lvl_07` |
  | `circle_twins` | Jumeaux du Cercle | mini-boss (paire) | jumeaux : se relevent tant que l autre tient | mene le palier de `lvl_12` |
  | `demon_lord` | Malyk, Seigneur demon | boss | devoreur-invocateur (mange ses Cacodemons) | boss de `lvl_13` |
  | `trio_ember` | Mage de braise | boss | trois vies depuis le haut, de plus en plus vite | mene le trio, boss de `lvl_19` |
  | `trio_frost` | Mage du givre | mini-boss | miroir du mage (sa vitesse suit celle du mage) | trio de `lvl_19` |
  | `trio_arcane` | Mage des arcanes | mini-boss | immunise aux 10 premiers coups | trio de `lvl_19` |
  | `adept_frost` / `adept_ember` / `adept_arcane` | Adeptes | P3 | zigzag / une vie de rechange / sauts + 2 sceaux | `lvl_15`, `lvl_16` |
  | `gravedigger` | Le Fossoyeur | mini-boss | entre par le cote, releve les morts autour de lui | mene le palier de `lvl_21` |
  | `season_chameleon` | Cameleon des saisons | mini-boss | cameleon : faiblesse feu, poison, givre, foudre en cycle | mene le palier de `lvl_14` |
  | `spell_clerk` | Le Greffier | mini-boss | voleur de sorts | mene le palier de `lvl_15` |
  | `clockmaker` | L Horloger | boss | revient 3 s en arriere toutes les 7 s | boss de `lvl_15` |
  | `blood_clot` | Caillot | P3 | le Coagule promu : se releve une fois | `lvl_14` |
  | `mirror_shard` | Eclat de miroir | P3 | le Miroir de Forge promu : renvoi court | `lvl_15` |

  Trois feuilles partagees sont departagees par une teinte (`AnimCatalog.MODULATE`),
  verifiee en capture (`shot_07_vitrine_teintes`) : la Sorciere des fosses (bleue)
  contre l Ensevelisseur, le Sceau de Tombol (vert-de-gris) contre le trio bleu,
  l Horloger (laiton) contre le Colosse des Forges. `tests/unit/test_bestiaire_w2.gd`
  verrouille le placement, la chaine de PV des boss qui se divisent et le trio.

- **Les scenes generees couvrent le prologue et les 21 niveaux** (43 scenes). Les
  scenes `lvl_03_*` / `lvl_04_*` racontent l ossuaire et le Grand Appel (acte 2) ;
  la route du maire et le dirigeable sont `lvl_08_*` et `lvl_09_*`.
- Les scenes de visual novel sont des `DialogueDef` dans `resources/story/`, generees
  par `tools/make_story.gd` (`Godot --headless --path . tools/make_story.tscn`). Un
  niveau les nomme par `intro_story` / `outro_story`, dans `tools/make_content.gd`.
- `SceneRouter` seul sait qu une scene s intercale : ni le menu, ni `GameController`,
  ni l ecran de victoire n en savent rien.
- Les scenes sont **coupees en headless** (`SceneRouter.stories_enabled`) : le smoke et
  le banc d equilibrage appellent `start_level()` en boucle et n ont pas de doigt pour
  faire defiler un dialogue.
- Seule la **Campagne** raconte l histoire. Le LIBRE rejoue un niveau deja raconte ;
  le Massacre est, diegetiquement, ce qui vient apres la derniere scene.
- Ce que le joueur lit d un niveau en dehors des scenes : le nom (`display_name`) et le
  sous-titre (`subtitle`) sur la carte, et `intro_text` au briefing. `outro_text`
  n est affiche NULLE PART (et raconte souvent l ancienne histoire : renvoye a B2,
  `docs/revue_vague10.md` §2.7).
- `tests/unit/test_story.gd` garde : scene citee -> scene sur le disque ; scene sur le
  disque -> citee par un niveau ; chaque niveau de campagne encadre ; le narrateur ne
  nomme que des monstres des vagues du niveau ; pas d accent dans les scenes ni dans
  les textes du niveau ; chaque personnage a un visage.

---

## 11. Les quêtes annexes (vague 10, chantier B3)

Huit quêtes hors du fil : une par acte, ouverte après un niveau de campagne de cet
acte, et une par apprenti, fermée tant qu il n est pas gagné au compte. Chacune se
ferme sur un **boss doré** : un monstre de base renforcé, à la teinte d or. Contenu :
`tools/make_side_quests.gd` ; scènes : `tools/make_story.gd`, section « QUÊTES
ANNEXES » ; règles : `tests/unit/test_side_quests.gd`.

**Une annexe est ancrée à son niveau d ouverture** : ses scènes savent ce que le mage
sait à ce moment-là, sans supposer une autre annexe ni une branche de fourche.

**L or est le fil.** Le boss final est « une bête de cadrans, toute en or » : chaque
boss doré porte sa couleur. Les scènes posent, sans rien dévoiler, qu un « client »
aime l or et que l enfant aime ce qui brille et ce qu on lui donne en spectacle.

| Annexe | Ouverte après | Qui est là | Boss doré | Ce que disent les scènes |
|---|---|---|---|---|
| « La mesure » | `lvl_02` | mage, enfant | Corniste doré | le cor qui bat la cadence du village ; « personne ne paie un cor en or à un corniste de forêt » : quelqu un, plus loin, donne le tempo |
| « L atelier du rat » | `lvl_17` | + rat | Gardien-totem doré | l atelier où le rat a travaillé ; un totem de port taillé de sa main, doré et retourné, « pour que le client le reconnaisse » |
| « Le trésor de Tombol » | `lvl_20` | mage, enfant | Squelette pareur doré | la salle du trésor vide ; il ne reste qu une garde dorée : « une quittance, le créancier est passé avant nous » |
| « Le champion de Kaltek » | `lvl_11` | + rat, roi | Berserker doré | le champion enchaîné de l arène vide ; « même le champion était en laisse » ; l enfant a trouvé ça « joli à regarder » |
| « La vitrine de Nuri » | `lvl_14` | mage, rat, roi (l enfant se tait) | Gorgone dorée | l aile NURI de la galerie ; la plaque « STATUES DU VILLAGE : FAITES » confirme ce que le mage déduisait au village, sans dire qui |
| « L écuyer du port » | `lvl_18` + l écuyer | + l écuyer | Lutin archer doré | le dernier garde de Haute-Nacelle a posé l épée pour l arc ; il tirera « à la place » du mage |
| « La fée des fosses » | `lvl_19` + la fée | mage, enfant, la fée | Champignon doré | une fée qui ne se pose jamais, parce qu ici « le sol mange » |
| « L apprentie d azur » | `lvl_12` + l apprentie | + roi, l apprentie | Chevalier du vide doré | sous un cristal du temple d Ymoa, l apprentie du mage de la PREMIÈRE boucle, morte à Nox : il se souvient, pas elle |

**Les apprentis parlent sans visage** : le casting de `StoryScene` n a pas leur
portrait (à fabriquer, asset-pipeline) ; leur nom s affiche, comme « Un mort ».
