extends Node
## Constantes et reglages d'equilibrage. Aucun etat, aucune dependance.
## Premier autoload charge : tous les autres peuvent le lire dans leur _ready().

## --- Vitesse / bouclier ---
## Vitesse en POURCENTAGE : 100 % normal, 500 % maximum.
## Les quatre paliers fixes d origine (x1/x1.5/x2/x4) ne laissaient aucune nuance.
## Le pas de 10 % a disparu avec le bouton d acceleration : la vitesse monte
## desormais en continu (SPEED_RISE_PER_SECOND) et ne se commande plus.
const SPEED_MAX_PERCENT: int = 500
## Bouclier gagne par point de pourcentage au-dessus de 100 : a 500 % le mage
## encaisse 40 PV de plus, soit une bonne moitie de sa vie. Aller vite est un pari
## payant, mais a 0,2 le bouclier rendait le mage quasi invulnerable au banc.
const SHIELD_PER_PERCENT: float = 0.1
## Ce qu un coup fait perdre en vitesse, et le temps pendant lequel on ne peut
## plus accelerer : on ne relance pas la machine dans la seconde ou l on est touche.
const SPEED_DROP_ON_HIT: int = 60
const SPEED_LOCK_AFTER_HIT: float = 3.0
## Points de pourcentage gagnes par seconde, tout seuls.
##
## Retour du testeur (21 septembre) : "La barre de vitesse n est plus accelerable
## manuellement ni en cliquant ni par le bouton. La vitesse augmente naturellement
## progressivement, 1 % par 0,5 seconde." Soit 2 points par seconde.
##
## La montee est CONTINUE, pas par paliers : SpeedGauge garde un accumulateur
## flottant et ne fait avancer le pourcentage affiche que par pas entiers de 1.
## Les paliers de 10 % toutes les 8 s se voyaient comme des a-coups — le monde
## changeait de vitesse d un coup au milieu d une vague, sans que le joueur ait
## rien fait. A 2 points/s, l echelle complete (100 -> 500) prend 200 s, soit la
## duree d une partie : la montee se sent sans jamais se remarquer.
const SPEED_RISE_PER_SECOND: float = 2.0
## Vitesse a laquelle le monde tourne pendant l'agonie (25 %).
const DEATH_SLOWMO: float = 0.25
## Fraction de jauge d'agonie perdue par seconde reelle -> 4 s avant la defaite.
const DEATH_DRAIN_RATE: float = 0.25
## Echelle de 100 PV : avec 8 PV, tout coup valait 12,5 % de la vie et les degats
## ne pouvaient pas etre nuances. Ici un gnome egratigne, un boss fait vraiment mal,
## et la fleche d un archer se distingue d une charge de behemoth.
const MAGE_MAX_HP: int = 100

## Degats de contact par puissance de monstre (P1 a P4), puis mini-boss et boss.
## Un monstre sans valeur explicite prend celle de sa puissance.
## Mesure au banc : a 4/7/12/18 le mage finissait a 83 PV sur 100, il n y avait
## plus aucune tension. Ces valeurs laissent environ 10 erreurs avant la defaite.
const CONTACT_DAMAGE_BY_POWER: Dictionary = {
	1: 9, 2: 15, 3: 24, 4: 36,
}
const CONTACT_DAMAGE_MINIBOSS: int = 42
const CONTACT_DAMAGE_BOSS: int = 50

## --- Deck / pioche ---
## Mesure au banc (tools/sim_balance.gd) : a 8 s, le joueur restait sans carte
## jouable pendant que la vague arrivait. A 5 s il a toujours un choix.
## Retour du testeur : "la pioche est un peu trop rapide, on n a pas le temps de
## lire le texte des cartes". Elle suit le TEMPS DU MONDE : a 300 % de vitesse,
## 5 s d intervalle devenaient 1,7 s reelles, soit deux cartes nouvelles toutes
## les deux secondes. A 8 s, meme a pleine vitesse, la main reste lisible.
## 6,5 s et non 8 : a 8 s le garde-fou de test_balance.gd se declenche, la pioche
## passant sous le rythme d arrivee des monstres de la vague la plus dense. Le
## joueur se retrouverait les mains vides, ce qui est pire que de lire vite.
const DRAW_INTERVAL: float = 6.5
const DRAW_COUNT: int = 2
## 6 et non 8 : a 8 cartes chacune tombait sous 130 px de large et le nom se
## coupait. Une main plus courte se lit d un coup d oeil, ce qui compte plus que
## d avoir le choix entre huit options qu on n a pas le temps de comparer.
const MAX_HAND_SIZE: int = 6
## Pas de delai de remelange : la defausse repart dans la pioche des qu elle est
## vide. Le cahier des charges evoquait une "vitesse de melange", mais un temps
## mort au moment ou le joueur n a plus de carte le punit deux fois.

## --- Progression ---
## XP requise pour passer du niveau N au niveau N+1.
const XP_PER_LEVEL_BASE: int = 12
const XP_PER_LEVEL_GROWTH: float = 1.25
## Nombre de cartes proposees a chaque montee de niveau.
const LEVEL_UP_CHOICES: int = 3
## Emplacements de pouvoirs passifs. Les passifs ne sont PLUS dans le deck : ils
## sont equipes et agissent des le debut du combat (demande du testeur du
## 21 septembre). Trois, et pas plus : un quatrieme impose un ECHANGE, ce qui
## transforme chaque nouveau passif en decision au lieu d une accumulation.
const PASSIVE_SLOTS: int = 3
## Ancien nom, garde le temps que les ecrans de menu migrent. Meme valeur.
const STARTING_PASSIVES: int = PASSIVE_SLOTS

## --- Amelioration des cartes en combat ---
## Nombre de LANCERS d une meme carte avant qu elle propose son amelioration.
##
## "XP par lancer, choix parmi 3" (demande du testeur). Le compteur suit les
## incantations REELLEMENT resolues, pas les pioches : c est le sort dont on se
## sert qui progresse, pas celui qui dort en main.
##
## 8 et non 4 ni 12, mesure sur 30 parties (sonde jetable, 3 niveaux x 10) :
##   seuil  4 -> 6,6 a 11,8 ameliorations par partie
##   seuil  8 -> 4,7 a  6,4 ameliorations par partie
##   seuil 12 -> 1,6 a  3,0 ameliorations par partie
## Une partie dure environ 160 s. A 4, un ecran modal s ouvre toutes les 15 s :
## le joueur passe son temps dans des menus au lieu de jouer. A 12, le niveau 4
## en voit MOINS que le niveau 1 (1,6 contre 3,0) parce que ses cartes tournent
## plus : le palier devient illisible. A 8 la cadence (un choix toutes les 25 a
## 35 s) colle a celle des montees de niveau, et les trois niveaux mesures
## restent dans la meme fourchette.
const CARD_UPGRADE_CASTS: int = 8

## Ce que chaque voie d amelioration donne, et ce qu elle coute. Un seul jeu de
## trois nombres pour tout le catalogue : les voies sont DERIVEES des effets de
## la carte (voir RunState.upgrade_paths_for), pas ecrites carte par carte.
##
## POURQUOI DES PACTES ET NON DES BONUS
## ------------------------------------
## Trois lignes de "+10 %" ne sont pas un choix, c est un classement : le joueur
## prend la plus grosse et l ecran ne sert a rien. Chaque voie DONNE et PREND,
## sur des axes differents, pour que le sort change d IDENTITE :
##   PUISSANCE : il frappe fort mais se charge lentement
##   CELERITE  : il part vite mais tape moins
##   AMPLEUR   : il couvre large, un peu plus lentement
## Aucune ne domine les autres sur les trois axes a la fois — c est ce que
## verrouille test_upgrades.gd (_test_les_trois_voies_sont_des_choix_pas_un_classement).
##
## REGLAGE MESURE AU BANC (30 parties par niveau, sept niveaux)
## -----------------------------------------------------------
## Le banc a une variance LARGE par niveau : deux passages du meme contenu ont
## rendu 96,7 % puis 83,3 % au niveau 2. On ne regle donc PAS sur un niveau, mais
## sur la MOYENNE des sept, qui s est revelee stable a 0,1 point pres.
##   sans amelioration            : moyenne 80,9 %
##   gains 45/35/40, prix 30/20/10 : moyenne 87,7 % puis 87,6 % — trop fort, et
##                                   le niveau 2 sortait de la bande par le haut
##   gains 30/25/28, prix 35/25/15 : moyenne 81,9 % puis 82,4 % — retenu
## L amelioration reste un vrai gain (le joueur sent son sort changer) mais elle
## se paie assez cher pour que la difficulte mesuree ne bouge pas.
const UPGRADE_POWER_GAIN: float = 0.30    # +30 % de degats
const UPGRADE_POWER_COST: float = 0.35    # +35 % de temps d incantation
const UPGRADE_HASTE_GAIN: float = 0.25    # -25 % de temps d incantation
const UPGRADE_HASTE_COST: float = 0.25    # -25 % de degats
const UPGRADE_AREA_GAIN: float = 0.28     # +28 % de rayon et de duree
const UPGRADE_AREA_COST: float = 0.15     # +15 % de temps d incantation

## Part de PASSIFS dans les cartes proposees a la montee de niveau.
## "Les passifs sont plus rares que les cartes : 20 pourcent de passifs."
const PASSIVE_OFFER_CHANCE: float = 0.20

## --- Raretes au drop de montee de niveau ---
## Lecture validee du cahier des charges : la raretes la plus haute est la plus rare.
const RARITY_WEIGHTS: Dictionary = {
	GameEnums.Rarity.RARE: 0.80,
	GameEnums.Rarity.EPIC: 0.15,
	GameEnums.Rarity.LEGENDARY: 0.05,
}

## Ralentissement global de la descente. Mesure au banc : a vitesse d origine, la
## fenetre de tir sur un lutin (10 s) etait trop courte pour viser au doigt sur
## mobile alors que d autres monstres arrivaient en meme temps.
## Mesure au banc : avec les trois pouvoirs passifs dans le deck, tous les niveaux
## sont montes a 100 % de victoires. Les passifs sont un vrai gain de puissance ;
## la difficulte de base doit remonter pour qu ils restent un choix et non un
## cadeau.
##
## 0,61 et non 0,70 depuis que la ligne d apparition est descendue a y=120 :
## la descente est passee de 1580 px a 1380 px, soit 12,7 % de moins. Mesure au
## banc (30 parties par niveau), le RACCOURCISSEMENT SEUL faisait tomber les
## taux de 57-93 % a 27-77 % — le joueur perdait un huitieme de sa fenetre de
## reaction sans que rien d autre ait bouge. On rend ce temps en ralentissant
## les monstres du meme rapport (0,70 x 1380/1580), ce qui conserve la DUREE de
## descente au lieu de la vitesse : c est le temps de viser qui fait la
## difficulte, pas les pixels par seconde.
##
## 0,51 et non 0,61 depuis que les PASSIFS ont quitte le deck. L ancienne valeur
## avait ete calibree AVEC trois passifs offerts d office dans le deck de depart.
## Mesure au banc (30 parties par niveau), les retirer SEUL faisait tomber les
## taux de 63-93 % a 0-77 % — le niveau 6 devenait invincible. Les passifs
## arrivent desormais par les montees de niveau, un sur cinq, et seulement
## au-dela de leur seuil de vitesse : le joueur commence donc nu et il faut lui
## rendre le temps de reaction que les trois passifs gratuits lui donnaient.
## Apres reglage : 77/87/93/77/77/77/77 %, les sept niveaux dans la bande 60-95.
const ENEMY_SPEED_SCALE: float = 0.52

## --- Terrain ---
## Le mage se tient en bas ; les monstres descendent vers cette ligne.
const BATTLEFIELD_WIDTH: float = 1080.0
const BATTLEFIELD_HEIGHT: float = 1920.0
const MAGE_LINE_Y: float = 1500.0
## Ligne d apparition des monstres. Retour du testeur : "les monstres
## apparaissent au fond de l ecran, c est bizarre avec le decor : fais-les
## apparaitre un peu plus loin, au debut de l herbe".
##
## A -80 le monstre naissait HORS CHAMP et glissait dans l image comme une
## affiche qu on fait defiler ; le decor peint commence pourtant par une bande
## d arbres, et rien ne sortait de dessous. A 120 il nait DANS le decor, juste
## sous la bande decoree des fonds peints (mesuree entre y=140 et y=210 selon
## l acte), la ou l herbe s ouvre. Le fondu (SPAWN_FADE_TIME) remplace la
## glissade : il apparait, puis il avance.
const SPAWN_LINE_Y: float = 120.0
## Duree du fondu d apparition. Pendant ce temps le monstre est IMMOBILE et
## INTOUCHABLE : sans cette immunite le joueur frapperait des fantomes a peine
## visibles, et une zone au sol posee sur la ligne d apparition tuerait les
## vagues avant qu elles existent.
const SPAWN_FADE_TIME: float = 0.5


func xp_required(level: int) -> int:
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, maxi(0, level - 1))))
