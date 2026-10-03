extends Node
## Constantes et reglages d'equilibrage. Aucun etat, aucune dependance.
## Premier autoload charge : tous les autres peuvent le lire dans leur _ready().

## --- Vitesse : LA SEULE RESERVE DU MAGE ---
## Vitesse en POURCENTAGE : 100 % est le PLANCHER, et le plancher c est la mort.
## 500 % est le maximum, la pleine forme.
##
## Depuis le 26 septembre la vitesse EST la vie : le mage n a plus de PV ni de
## bouclier, et un coup de N degats lui retire N points de pourcentage. La
## reserve de vie du mage vaut donc SPEED_MAX_PERCENT - 100 points, et elle est
## la meme chose que sa puissance. Voir speed_gauge.gd pour la regle complete.
const SPEED_MAX_PERCENT: int = 500
## Vitesse de DEPART d une partie. Elle ne peut pas valoir 100 : a 100 % le mage
## est mort. C est son capital de vie initial (250 - 100 = 150 points), et c est
## aussi la vitesse a laquelle le jeu commence — les deux sont le meme nombre,
## c est tout le sujet de la mecanique.
##
## 250 et non 100 : sous l ancien systeme le mage partait a 100 % avec 100 PV a
## cote, soit une reserve confortable des la premiere seconde. Le faire partir
## au plancher l aurait tue au premier gnome. 250 lui donne 150 points de marge,
## soit une poignee de contacts, et la montee naturelle fait le reste.
## L EQUILIBRAGE FIN DE CETTE VALEUR APPARTIENT AU TESTEUR.
## Vitesse au debut d un combat (demande du testeur, 27/09 : 150 %).
##
## C est AUSSI la reserve de depart depuis que la vitesse est la vie : a 150 %,
## le mage commence avec 50 points au-dessus du plancher mortel de 100, contre
## 150 auparavant. Le combat demarre donc plus lent ET plus fragile — les deux
## vont ensemble, c est le principe de la mecanique.
const SPEED_START_PERCENT: int = 150
## Le temps pendant lequel la montee naturelle est retenue apres un coup.
##
## Ce verrou a CHANGE DE NATURE avec la nouvelle regle. Avant, il empechait de
## regagner de la puissance trop vite apres un contact. Maintenant que la montee
## naturelle est la seule facon de se SOIGNER, il empeche de se soigner — et
## trois secondes sous le feu, c est long. Il est donc raccourci a 1,2 s : le
## coup se sent toujours (la barre se fige une seconde, on le voit), mais il
## n enchaine plus deux punitions sur le meme contact.
##
## Il n a PAS ete supprime : sans lui, se faire toucher a 40 points du plancher
## serait sans consequence visible, la barre repartant dans l image suivante.
const SPEED_LOCK_AFTER_HIT: float = 1.2
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
## rien fait.
##
## C est AUSSI, desormais, le rythme auquel le mage se regenere : 2 points de
## vie par seconde. Le seul soin permanent du jeu est de tenir sans etre touche.
const SPEED_RISE_PER_SECOND: float = 2.0
## Vitesse a laquelle le monde tourne pendant l'agonie (25 %).
##
## Le ralenti garde tout son sens avec la nouvelle regle : on meurt PARCE QU ON
## EST LENT, et le ralenti est l image litterale de cette mort. C est meme la
## seule mise en scene du jeu qui dise exactement ce qui vient de se passer.
const DEATH_SLOWMO: float = 0.25
## Fraction de jauge d'agonie perdue par seconde reelle -> 4 s avant la defaite.
const DEATH_DRAIN_RATE: float = 0.25

## Degats de contact par puissance de monstre (P1 a P4), puis mini-boss et boss.
## Un monstre sans valeur explicite prend celle de sa puissance.
##
## CES VALEURS SONT DESORMAIS DES POINTS DE POURCENTAGE DE VITESSE, pas des PV :
## un gnome (P1) fait perdre 9 points de vitesse, un boss 50. Elles n ont PAS
## ete retouchees lors du passage a la vitesse-vie, volontairement :
## l equilibrage appartient au testeur, et changer l echelle en meme temps que
## la regle aurait rendu impossible de dire lequel des deux a bouge.
##
## Ce qu il faut savoir pour les regler : l ancienne reserve valait 100 PV plus
## un bouclier d au plus 40 points, soit 140 au mieux et 100 le plus souvent.
## La nouvelle vaut SPEED_MAX_PERCENT - 100 = 400 points au maximum, et
## SPEED_START_PERCENT - 100 = 150 au depart. A degats egaux le mage encaisse
## donc PLUS de coups en pleine forme qu avant, et a peu pres autant au debut de
## la partie — mais chaque coup le RALENTIT, ce que l ancienne barre de PV ne
## faisait pas. Les chiffres du banc sont dans le rapport du chantier.
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
## MULTIPLICATEUR GLOBAL du temps d incantation (demande du testeur, 27/09).
##
## Un seul nombre plutot que 46 valeurs reecrites : la HIERARCHIE entre les
## sorts est deja reglee carte par carte (0,45 s pour le plus vif, 2,8 s pour le
## plus lourd), et c est elle qui porte l identite de chaque sort. La rallonger
## d un facteur commun garde cette hierarchie intacte et se re-regle d un seul
## chiffre — alors que retoucher 46 cartes une a une la deformerait a coup sur.
##
## Applique dans `RunState.effective_cast_time()`, le point de passage UNIQUE.
##
## 1,5 -> 1,9 (vague 8, co-auteur : « augmente SIGNIFICATIVEMENT le temps de
## lancement de tous les sorts, quitte a le diminuer un peu plus tard ») : +27 %
## sur l ancien reglage. Un premier essai a 2,25 cassait la campagne.
##
## LE BANC QUI LE JUSTIFIE (tools/sim_balance, 60 parties par niveau, 21 niveaux,
## banc deterministe ; victoires sur 1260, puis les niveaux les plus bas) :
##   1,5  : 1192  lvl_13 42, lvl_05 41, lvl_11 49
##   1,8  : 1146  lvl_13 43, lvl_18 37, lvl_11 39   (avec le correctif de w13_4)
##   1,9  : 1135  lvl_13 37, lvl_18 37, lvl_11 38   <- retenu
##   1,95 : 1115  lvl_11 36, lvl_13 37, lvl_20 38   (lvl_20 perd 9 parties)
##   2,0  : 1106  lvl_13 31, lvl_11 33, lvl_18 34   (sans le correctif de w13_4)
##   2,25 :  987  lvl_18 15, lvl_20 19, lvl_11 22, lvl_13 34, lvl_14 35
## Repere : 36 victoires sur 60 (60 %) pour TOUT niveau. A 1,9 les trois plus bas
## sont a une partie du repere ; 1,95 y pose lvl_11 pile et la courbe plonge
## entre 1,9 et 2,0. Le bot du banc joue mieux qu un doigt : on garde la marge.
## Le pentacle (lvl_13) ne suit pas ce chiffre : il est limite par la pioche,
## sa correction est dans w13_4 (tools/make_content.gd).
##
## CONSEQUENCE ASSUMEE : le mage incante plus de 60 % du temps sur 19 niveaux
## sur 21 (77 a 97 % ; deja 62 a 86 % a 1,5). C est ce que la demande rallonge.
##
## POUR LE CHANGER : ce seul chiffre, puis le banc complet sur les 21 niveaux
## (README_equilibrage : plusieurs processus en parallele, --parties=60), en
## surveillant d abord lvl_11, lvl_18, lvl_20 et lvl_13, les premiers a tomber.
const CAST_TIME_SCALE: float = 1.9

const DRAW_COUNT: int = 2
## 6 et non 8 : a 8 cartes chacune tombait sous 130 px de large et le nom se
## coupait. Une main plus courte se lit d un coup d oeil, ce qui compte plus que
## d avoir le choix entre huit options qu on n a pas le temps de comparer.
## Cartes en main au tout debut du combat (demande du testeur, 27/09).
##
## Distinct de MAX_HAND_SIZE : le plafond reste a 6, c est le DEPART qui est
## maigre. Le joueur commence avec deux options et doit attendre la pioche —
## les premieres secondes deviennent un choix serre plutot qu un tri.
const START_HAND_SIZE: int = 2

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

## Ce que chaque voie d amelioration donne, et ce qu elle coute. UN SEUL endroit
## pour tout le catalogue : les voies sont DERIVEES des effets de chaque carte
## (voir RunState.upgrade_pool_for), pas ecrites carte par carte. Chaque
## maturation TIRE trois voies de ce pool (RNG de la partie), si bien que la
## proposition change d une partie a l autre.
##
## DEUX FORMES, demandees par le co-auteur
## ---------------------------------------
##   LEGERE : un petit gain SANS contrepartie     (+10 % degats)
##   FORTE  : un gros gain qui se PAIE ailleurs   (+30 % degats, -15 % vitesse de
##            lancement)
## Trois lignes de "+10 %" ne seraient pas un choix mais un classement. Le melange
## des deux formes donne deux facons de gagner : un bonus sur, ou un pari qui
## change l identite du sort. Aucune voie ne domine une autre sur tous les axes a
## la fois — verrouille par test_upgrades.gd.
##
## AXES : degats, ralentissement, acceleration, force (aspiration, courant,
## recul), amplification (vulnerabilite, Focalisation), PV d un objet, nombre
## (cibles, impacts, cartes), zone, duree, vitesse de lancement. Chaque axe est un
## multiplicateur "plus c est haut, mieux c est" : la vitesse de lancement est
## l INVERSE du temps d incantation, donc "+10 % de vitesse" divise le temps par
## 1,10 — le libelle dit exactement ce que fait le sort.
##
## REGLAGE MESURE (21 niveaux x 30 parties, 29/09/2026, AVANT le pool tire : voir
## CARD_UPGRADE_TIERS pour le banc U2). Le bot du banc prend la
## PREMIERE voie, donc l identite du sort en forme forte (+30 % degats contre
## -15 % de vitesse, soit un temps x1,18) la ou l ancien pacte Puissance coutait
## +35 % de temps. Resultat : 559 -> 583 victoires sur 630, Massacre vague 14,9 ->
## 18,2. Les hausses se concentrent sur les niveaux durs (lvl_18 18 -> 26,
## lvl_20 16 -> 24, qui rentre dans la fenetre 60-95 %) ; aucun niveau n en sort
## par le haut. Pas de rupture franche : rien n a ete retouche ailleurs.
const UPGRADE_LIGHT_GAIN: float = 0.10     # forme legere : +10 %, rien a payer
const UPGRADE_STRONG_GAIN: float = 0.30    # forme forte : +30 % ...
const UPGRADE_STRONG_COST: float = 0.15    # ... contre -15 % sur un autre axe
## Ralentissement maximal atteignable par une amelioration, en %. C est le
## plancher de vitesse de Battlefield.apply_global_enemy_slow (facteur 0,1) : au
## dela, un ralentissement de zone ferait RECULER les monstres, ce que seul le
## courant de la Nappe d eau a le droit de faire. Un sort deja trop pres du plafond
## (Gel profond, 85 %) ne recoit pas la voie : elle promettrait +10 % et en
## donnerait trois.
const UPGRADE_SLOW_CAP: float = 90.0
## Duree minimale pour qu un effet "dure". Une Boule de feu (0,6 s) ou un Meteore
## (0,3 s) ne sont pas des effets de duree : leur zone n existe que pour porter
## l impact, et la rallonger ajouterait des degats sous un faux nom.
const UPGRADE_MIN_DURATION: float = 1.0
## Au-dela de ce nombre de cibles, une ligne perce "tout" (Faille temporelle : 99).
## Lui promettre "+1 cible" serait un mensonge : la voie n est pas proposee.
const UPGRADE_COUNT_UNLIMITED: int = 20
## AXES DE COMPLEMENT, en CARTES, pour les sorts trop simples pour que leur pool
## depasse les LEVEL_UP_CHOICES voies de l ecran (voir RunState.upgrade_pool_for).
## Pioche au lancement (Riviere seulement) : la legere en donne une, la forte
## deux contre UPGRADE_STRONG_COST de vitesse.
const UPGRADE_DRAW_LIGHT: int = 1
const UPGRADE_DRAW_STRONG: int = 2
## Prix de la vitesse forte d un sort qui n a RIEN d autre a payer (sorts de
## pioche ou de retour en main, Riviere) : une carte de la main defaussee a
## chaque lancer. Une carte et non deux : ces sorts se lancent en moins d une
## seconde, deux cartes par lancer videraient la main plus vite qu elle ne
## se remplit.
const UPGRADE_DISCARD_PRICE: int = 1
## MATURATIONS par sort et par partie. Le sort murit a CARD_UPGRADE_CASTS lancers,
## puis a des ecarts de plus en plus longs. Le co-auteur parle de "montees de
## niveau des sorts" au pluriel : un sort favori doit pouvoir s affirmer au fil
## de la partie. (Jusqu au chantier W8 : deux et pas plus, voir plus bas.)
##
## BANC U2 (21 niveaux x 30 parties + Massacre x 20, 30/09/2026, meme machine) :
##                         victoires   Massacre   ameliorations / partie
##   trio fixe, 1 palier    533 / 630    11,9       3,1 a 6,0
##   pool tire, 1 palier    525 / 630    10,1       3,1 a 6,0
##   pool, paliers 8+16     533 / 630    10,1       3,0 a 10,5
##   pool, paliers 8+16*    532 / 630    10,4       3,1 a 8,7   <- retenu
##   (* ecart qui grandit : paliers a 8 et 24, ancien facteur x2 remplace en W8
##    par CARD_UPGRADE_GAP_STEP)
## Le bot prend la PREMIERE voie de l offre : avec le trio fixe c etait toujours
## l identite en forte (+30 % degats x94 sur lvl_16) ; avec le tirage c est une
## voie au hasard (37 voies differentes prises au lieu de 10). Ce hasard coute
## 8 victoires ; la seconde maturation les rend. Seul ecart franc : lvl_16 25 ->
## 14 (17 et 15 sur les deux autres variantes), un niveau qui ne passait que
## grace a "+30 % degats" pris a chaque fois. Non retouche ici : c est la
## politique du bot qui a change, pas le jeu (voir le rapport U2).
## Depuis le chantier W7, le bot choisit par une REGLE (AutoPick.upgrade_index :
## l identite du sort en forme forte, sinon la vitesse forte) et non plus la
## premiere voie : lvl_16 43 -> 59 victoires sur 90 a jeu egal.
##
## CINQ PALIERS DEPUIS LE CHANTIER W8 (02/10/2026). Le co-auteur : « les cartes
## peuvent monter PLUSIEURS fois de niveau ». Deux paliers ne laissaient a un
## sort favori que deux choix par partie, et rien a viser au-dela de 24 lancers
## en Infini ou en Massacre, ou une partie dure vingt vagues. Les deux premiers
## paliers restent a 8 et 24 lancers (meme cadence qu avant en campagne) ; les
## trois suivants s ecartent de plus en plus (48, 80, 120) : ils recompensent le
## sort qu on joue en boucle sur une longue partie sans multiplier les ecrans
## modaux d une partie courte. Mesure au banc dans le rapport du chantier W8
## (ecrans par partie avant / apres). Chaque maturation montre LEVEL_UP_CHOICES
## voies : un sort au petit pool murit moins souvent, autant de fois qu il peut
## encore en montrer trois (RunState.upgrade_tiers_for, vague 9).
const CARD_UPGRADE_TIERS: int = 5
## L ecart entre deux maturations GRANDIT de ce nombre de lancers a chaque
## palier : 8, puis 16, 24, 32, 40 (paliers cumules a 8, 24, 48, 80, 120).
## Croissance ARITHMETIQUE et non plus geometrique (l ancien facteur x2) : a x2,
## le cinquieme palier tombait a 248 lancers, jamais atteint, et la promesse
## « plusieurs maturations » aurait ete une ligne morte. A ecart constant, le banc
## montait a 10,5 ecrans d amelioration par partie sur les niveaux longs (DEC-034).
const CARD_UPGRADE_GAP_STEP: int = 8

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

## --- Chantier W8 : vagues qui trainent, protecteurs, devoreurs ---------------

## MEDITER, a la montee de niveau : XP de carte donnee a chaque carte distincte
## de la main (RunState.meditate_offer). UNE, la demande du co-auteur : la
## meditation est le choix de qui veut faire murir sa main plutot que l elargir,
## et une XP vaut un lancer — en donner plus ferait d un ecran de choix un
## raccourci vers les maturations (paliers a 8, 24... lancers).
const MEDITATE_CARD_XP: int = 1

## VAGUE QUI TRAINE. Une vague dont toutes les apparitions sont faites, mais dont
## des monstres restent en jeu trop longtemps apres la DERNIERE apparition (temps
## de MONDE), laisse la place a la suivante : les restants restent en jeu. Avant,
## la vague suivante attendait la mort du dernier monstre, et deux campeurs
## proteges (ou un tank bloque contre un mur) figeaient la partie.
##
## « Trop longtemps » = le temps qu il faut au monstre MOBILE le plus lent de la
## vague pour traverser le terrain a sa vitesse de base, fois
## WAVE_OVERTIME_TRAVEL_FACTOR, et jamais moins que WAVE_OVERTIME_SECONDS (voir
## WaveSpawner.overtime_delay). Passe ce temps, chaque monstre aurait du arriver
## ou mourir : ceux qui restent CALENT (campeurs, proteges, bloques).
##
## Pourquoi pas WaveDef.duration (24 a 60 s) : releve sur les 106 vagues
## ecrites, `duration` n est que la duree des APPARITIONS plus ~7 s (mediane).
## Pourquoi pas un delai fixe : BANC W8, 40 s fixes ont fait tomber lvl_16 de 27 a
## 16 victoires sur 30 (1,67 vague ecourtee par partie) — son Echo d enclume
## (28 px/s, 95 s de traversee) etait simplement en route quand la vague 3 lui
## tombait dessus. Rapport W8 : banc avant / apres dans tools/README_equilibrage.md.
##
## Jamais pour la DERNIERE vague (la victoire attend que TOUT soit mort), jamais
## pour une vague de boss ou de mini-boss, ni pour ouvrir une vague de boss en
## avance (voir WaveSpawner.can_cut_short) : un combat de boss se joue seul.
const WAVE_OVERTIME_SECONDS: float = 40.0
## Marge sur le temps de traversee : un monstre ralenti par le joueur (givre,
## courant, volte-face) met plus longtemps sans pour autant caler. 1,25 couvre
## un ralentissement moyen sur un quart du trajet.
const WAVE_OVERTIME_TRAVEL_FACTOR: float = 1.25

## PROTECTEURS (aura d invulnerabilite). Une DISSIPATION (Lumiere purifiante,
## Vide d emprise) coupe l aura des porteurs touches pendant ce temps de monde :
## le halo disparait, et tout ce qu il couvrait redevient frappable. Assez long
## pour lancer deux ou trois sorts derriere la dissipation, assez court pour que
## la carte reste un geste de timing et pas une suppression definitive.
const AURA_DISPEL_SECONDS: float = 8.0
## PAT D AURA : si TOUS les monstres frappables sont couverts par une aura ET
## qu aucun ne descend vers le mage pendant ce temps de monde (deux Echos d Ymoa
## qui campent en se couvrant l un l autre, et rien d autre a viser), les auras se
## brisent comme sous une dissipation (AURA_DISPEL_SECONDS). Des proteges qui
## MARCHENT (Gardiens-totems) ne declenchent rien : ils finiront au contact, la
## vague n est pas imbattable (banc W8 : sans cette condition, lvl_20 passait de
## 23 a 30 victoires sur 30). C est le filet qui garantit qu une
## protection ne rend JAMAIS une vague imbattable, meme sans carte de dissipation
## dans le deck. Le delai laisse voir l aura tenir avant de ceder : ce n est pas
## une invulnerabilite qui n existe pas, c est une invulnerabilite qui s use.
const AURA_STALEMATE_SECONDS: float = 4.0

## DEVOREURS : chaque proie avalee par un devoreur qui GROSSIT (Glouton, Sesh et
## son echo) ajoute cette part a sa FORCE (degats de contact, et de tir s il
## tire), jusqu au plafond. +20 % par proie, x2 au plus apres cinq proies : un
## Glouton qui a mange toute une nuee frappe comme un mini-boss (36 -> 72 points
## de vitesse), ce qui est la lecon du monstre — le tuer AVANT qu il mange.
## Le devoreur-invocateur (devour_heal_pct, Seigneur demon) n en gagne PAS : son
## gain est deja le soin, et le doubler ferait de chaque sbire avale deux
## punitions pour une seule erreur.
const DEVOUR_FORCE_PER_PREY: float = 0.20
const DEVOUR_FORCE_CAP: float = 1.0

## --- Sorts de terrain PERMANENTS ---
## Plafond d objets de terrain permanents actifs en meme temps (arbres, ronces,
## fosses, autels). Au-dela, le PLUS ANCIEN est remplace par le nouveau.
##
## Pourquoi un plafond et pas une duree : la demande est que ces sorts restent
## toute la bataille, et une partie de Massacre dure vingt vagues et plus. Sans
## borne, le terrain s accumulerait carte apres carte jusqu a ce que chaque case
## soit empoisonnee, vulnerable et gardee par un autel — le joueur ne jouerait
## plus, il aurait fini de construire. Six, c est assez pour composer un vrai
## decor (deux arbres, deux ronces, une fosse, un autel), trop peu pour tout
## couvrir sur un champ de 1080 px de large.
##
## Remplacer le plus ancien plutot que REFUSER la pose : une carte refusee pour
## un plafond que le joueur ne voit pas se lirait comme un bug, alors qu un vieil
## objet qui s efface au moment ou le neuf apparait se comprend tout seul.
##
## La RIVIERE n est pas comptee : elle a sa propre regle (une seule a la fois,
## la nouvelle remplace l ancienne), parce qu elle ne s ajoute pas au decor —
## elle le coupe en deux.
const TERRAIN_PERMANENT_MAX: int = 6

## Temps (secondes MONDE) que l arbre qui ATTIRE doit tenir au pied d une vague
## normale mediane, tous ses monstres au contact. C est la regle que
## test_terrain.gd verifie contre les PV de la carte livree.
##
## Mesure a la sonde sur les 204 vagues normales des niveaux 3 a 21 : une vague
## entiere au pied de l arbre frappe a ~670 PV/s (mediane), jusqu a ~1500 pour la
## pire. L ancien totem de 90 PV tombait en 0,13 s — « il meurt en 1 s » etait
## encore genereux. Il doit tenir PLUSIEURS secondes, pas devenir invulnerable :
## le plafond MAX existe pour que la verification morde aussi dans l autre sens.
##
## VAGUE 8 : 4,0 -> 1,0. Le co-auteur passe l arbre a 800 PV « pour voir »
## (3500 avant) : il tient alors environ une seconde de monde au pied de la
## vague mediane. C est un essai de design assume, pas un oubli ; la borne dit
## seulement qu il ne tombe pas a l instant. Revenir a 4,0 avec les 3500 PV si
## l essai est abandonne.
const TERRAIN_TAUNT_MIN_HOLD: float = 1.0
const TERRAIN_TAUNT_MAX_HOLD: float = 12.0

## Bornes de hauteur de la riviere, en rangees de la grille de navigation
## (cellules de 60 px) comptees depuis la ligne d apparition et depuis la ligne
## du mage. Trop haut, les monstres naitraient dans l eau ou juste au bord et le
## pont ne servirait a rien ; trop bas, il ne resterait plus la place de viser
## ceux qui l ont franchie. Le point vise par le joueur est RAMENE dans ces
## bornes, jamais refuse : une riviere a une rangee pres de la ou on l a lachee
## vaut mieux qu une carte qui ne part pas.
const RIVER_MIN_ROWS_BELOW_SPAWN: int = 3
const RIVER_MIN_ROWS_ABOVE_MAGE: int = 4


func xp_required(level: int) -> int:
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, maxi(0, level - 1))))
