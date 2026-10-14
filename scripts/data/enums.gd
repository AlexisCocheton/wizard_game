class_name GameEnums
extends RefCounted
## Enumerations partagees par tout le jeu.
## Ce script n'est jamais instancie : il sert uniquement de porteur de constantes.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Ce que le joueur doit designer apres avoir touche la carte.
enum Targeting {
	NONE,       ## effet immediat, aucun ciblage
	POSITION,   ## une position au sol
	DIRECTION,  ## une direction (sorts en ligne)
	TARGET,     ## un ennemi precis
}

## LES HUIT ELEMENTS (vague 8, demande du co-auteur) et deux MARQUEURS d effet.
##
## Feu, Eau, Nature, Vent, Foudre, Glace, Arcanique, Poison : chaque sort a
## EXACTEMENT un element (SpellCard.element) et chaque monstre leur oppose un
## pourcentage de resistance (EnemyDef.resistances). SLOW et SUMMON ne sont pas
## des elements mais des CATEGORIES d effet : un sort peut etre de glace ET
## ralentissant ; la ligne SLOW garde sa resistance a part (un golem immunise au
## ralentissement n est pas ralenti, quel que soit l element du sort).
##
## POURQUOI DES VALEURS ECRITES A LA MAIN. Les .tres stockent la valeur ENTIERE
## du tag. Les noms qui survivent gardent leur valeur d avant (ICE = l ancien
## FROST = 2, POISON = 6...), les trois neufs s ajoutent EN FIN (8, 9, 10), et
## la valeur 0 de l ancien PHYSICAL devient NONE, un trou inerte. Un .tres d un
## autre chantier, ou une donnee d un telephone, qui porterait encore un 0 ne se
## lit donc pas comme du feu ou de l eau : il ne se lit plus du tout. Renumeroter
## de 0 a 9 aurait transforme silencieusement le physique en feu.
## Aucune sauvegarde ne stocke de DamageTag (verifie dans SaveData le 02/10).
enum DamageTag {
	NONE = 0,       ## aucun element (ancien PHYSICAL, retire en vague 8)
	FIRE = 1,
	ICE = 2,        ## l ancien FROST (givre) : meme valeur, nouveau nom
	ARCANE = 3,
	SLOW = 4,       ## marqueur d effet : ralentit / fige
	SUMMON = 5,     ## marqueur d effet : invoque
	POISON = 6,
	LIGHTNING = 7,
	WATER = 8,
	NATURE = 9,
	WIND = 10,
}

## Les tags qui sont de vrais ELEMENTS, dans l ORDRE D AFFICHAGE (fiches de
## monstre, legende du Cameleon, filtres) : celui que le co-auteur a donne.
## Une carte de sort en porte exactement un (verifie par test_elements) : sans
## element, elle echapperait a toutes les resistances.
const ELEMENTS: Array[int] = [
	DamageTag.FIRE, DamageTag.WATER, DamageTag.NATURE, DamageTag.WIND,
	DamageTag.LIGHTNING, DamageTag.ICE, DamageTag.ARCANE, DamageTag.POISON,
]


## Nom joueur d un element, au masculin sans article. Sert partout ou l element
## doit s ecrire : fiche de monstre, carte, bilan de fin.
## « arcanique » et non « arcane » (vague 9) : c est le nom que le co-auteur a
## donne a l element. L IDENTIFIANT interne reste ARCANE / &"arcane".
static func tag_name(tag: int) -> String:
	match tag:
		DamageTag.FIRE: return "feu"
		DamageTag.WATER: return "eau"
		DamageTag.NATURE: return "nature"
		DamageTag.WIND: return "vent"
		DamageTag.LIGHTNING: return "foudre"
		DamageTag.ICE: return "glace"
		DamageTag.ARCANE: return "arcanique"
		DamageTag.POISON: return "poison"
		DamageTag.SLOW: return "ralentissement"
		DamageTag.SUMMON: return "invocation"
	return "inconnu"


## Valeur d un tag a partir de son NOM d enum ("FIRE", "ICE"), -1 si inconnu.
## Les valeurs sont ecrites a la main (voir plus haut) : elles se suivent
## aujourd hui, mais `keys()[i]` ne rend le nom de la valeur i que par hasard.
## Passer toujours par ici ou par `tag_key` (find_key).
static func tag_from_name(s: String) -> int:
	if not DamageTag.has(s):
		return -1
	return int(DamageTag[s])


## Nom d enum d une valeur ("ICE"), "" si inconnue.
static func tag_key(tag: int) -> String:
	var k: Variant = DamageTag.find_key(tag)
	return String(k) if k != null else ""

## Famille de monstre : sert a l affichage et a l equilibrage.
## Les comportements eux-memes sont pilotes par les champs d EnemyDef.
enum EnemyKind {
	NORMAL, FAST, TANK, EVASIVE, SWARM, BUFFER, PHASER, MINIBOSS, BOSS,
	DEVOURER,   ## gobe les autres et grossit
	ENRAGER,    ## accelere a chaque coup recu
	GUARDIAN,   ## aura qui protege les autres
	BURSTER,    ## avance par a-coups
	WAVER,      ## avance en ondulant
	SPLITTER,   ## se divise a la mort
	SHIELDED,   ## encaisse le premier coup
	HEALER,     ## soigne les autres
	BOMBER,     ## explose en petits monstres
	SHOOTER,    ## tire sur le mage
}

## Forme dessinee du monstre tant qu il n a pas de sprite.
enum Shape { SQUARE, CIRCLE, TRIANGLE, DIAMOND, HEXAGON, CAPSULE, STAR }

## Les trois facons de jouer (vague 10, regles du co-auteur du 14/10).
##   EXPLORATION : "CAMPAGNE" a l ecran. Le niveau de campagne : ses vagues
##                 ecrites, son deck IMPOSE (LevelDef.campaign_deck, qui evolue
##                 avec les objectifs reussis). La victoire ouvre la suite.
##   FREE        : "LIBRE" a l ecran. Le MEME niveau (memes vagues, memes
##                 objectifs), joue avec le deck construit par le joueur.
##                 Gagner ne sert qu aux objectifs : aucun niveau ne s ouvre,
##                 le niveau n est pas compte comme fini. Ouvert des que le
##                 niveau l est.
##   MASSACRE    : l onglet MASSACRE du menu. LE mode sans fin, a part, hors
##                 campagne : les monstres de tous les niveaux melanges, les boss
##                 de tout le jeu aux paliers (voir MassacreMode).
##
## FREE REMPLACE L INFINI PAR NIVEAU (decision d Alexis, 14/10) et garde sa
## valeur 1, qui etait deja celle de l ancien « Massacre par niveau ». Aucune
## sauvegarde ne stocke un Mode (verifie le 14/10 : seule la charge utile du
## routeur, en memoire, le porte) ; garder la valeur ne coute rien et protege une
## donnee qu un autre chantier aurait retenue. Le nom change EXPRES : un appelant
## reste sur INFINITE casse a la compilation au lieu de lancer un mode qui n est
## plus sans fin (voir le piege « renommer expres » de la memoire du projet).
enum Mode { EXPLORATION, FREE, MASSACRE }


## Vrai pour le mode SANS FIN, le seul depuis la vague 10 : le Massacre. Pas de
## vague finale, pas d objectifs, pas d histoire, un record de vague. Un mode qui
## n est pas sans fin joue un NIVEAU : ses vagues ecrites et ses objectifs.
static func is_endless(mode: int) -> bool:
	return mode == Mode.MASSACRE


## Vrai si une victoire dans ce mode fait AVANCER la campagne (niveau fini,
## niveaux suivants ouverts, passifs du niveau debloques). Le LIBRE joue les
## memes vagues, mais sa victoire ne compte que pour les objectifs.
static func advances_campaign(mode: int) -> bool:
	return mode == Mode.EXPLORATION


## Nom du mode tel qu il s ecrit a l ecran.
static func mode_name(mode: int) -> String:
	match mode:
		Mode.EXPLORATION: return "Campagne"
		Mode.FREE: return "Libre"
		Mode.MASSACRE: return "Massacre"
	return "?"

## Recompenses de compte : COSMETIQUES uniquement. Ajouter ici un type qui
## donnerait de la puissance perimerait l equilibrage mesure des niveaux.
##
## Les trois derniers changent l APPARENCE du mage en combat, et rien d autre :
## une couleur de robe, une couleur de chapeau, une tour. Aucun ne touche aux
## PV, aux degats ni a la vitesse — c est la regle qui protege les taux de
## victoire mesures au banc sur les sept niveaux.
enum RewardKind {
	TITLE,       ## un titre affiche sur le profil
	AVATAR,      ## un portrait pour le profil
	MAGE_COLOR,  ## la robe du mage (feuilles monk_blue / black / purple)
	HAT,         ## la couleur de son chapeau (palette remappee)
	TOWER,       ## la tour posee sur la ligne du mage
	## Le PERSONNAGE joue en combat : le mage, ou l un de ses apprentis.
	## Ajoute EN DERNIER : les .tres stockent le type en entier (kind = 4), un
	## type insere au milieu decalerait toutes les recompenses deja ecrites.
	## Un apprenti ne change que la silhouette, jamais les stats.
	CHARACTER,
}


static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON: return "commune"
		Rarity.RARE: return "rare"
		Rarity.EPIC: return "epique"
		Rarity.LEGENDARY: return "legendaire"
	return "?"
