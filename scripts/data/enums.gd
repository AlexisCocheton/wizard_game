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

## Tags portes par les sorts. Les six PREMIERS sont des ELEMENTS de degats :
## chaque monstre leur oppose un pourcentage de resistance (EnemyDef.resistances).
## SLOW et SUMMON ferment la liste parce qu ils ne sont pas des elements mais des
## CATEGORIES d effet — un sort peut etre a la fois de givre et ralentissant.
##
## POISON et LIGHTNING ont ete ajoutes en fin d enum, jamais inseres au milieu :
## les .tres livres et les sauvegardes stockent la valeur ENTIERE du tag, et
## glisser une valeur decalerait toutes les suivantes (le feu deviendrait du
## givre sur les telephones deja installes).
enum DamageTag { PHYSICAL, FIRE, FROST, ARCANE, SLOW, SUMMON, POISON, LIGHTNING }

## Les tags qui sont de vrais ELEMENTS de degats. Une carte qui inflige des
## degats doit en porter au moins un (verifie par tests/unit/test_elements.gd) :
## sans element, elle echapperait a toutes les resistances et serait par
## accident la meilleure carte du jeu.
const ELEMENTS: Array[int] = [
	DamageTag.PHYSICAL, DamageTag.FIRE, DamageTag.FROST,
	DamageTag.ARCANE, DamageTag.POISON, DamageTag.LIGHTNING,
]


## Nom joueur d un element, au masculin sans article. Sert partout ou l element
## doit s ecrire : fiche de monstre, carte, bilan de fin.
static func tag_name(tag: int) -> String:
	match tag:
		DamageTag.PHYSICAL: return "physique"
		DamageTag.FIRE: return "feu"
		DamageTag.FROST: return "givre"
		DamageTag.ARCANE: return "arcane"
		DamageTag.POISON: return "poison"
		DamageTag.LIGHTNING: return "foudre"
		DamageTag.SLOW: return "ralentissement"
		DamageTag.SUMMON: return "invocation"
	return "inconnu"

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

enum Mode { EXPLORATION, MASSACRE }

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
}


static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON: return "commune"
		Rarity.RARE: return "rare"
		Rarity.EPIC: return "epique"
		Rarity.LEGENDARY: return "legendaire"
	return "?"
