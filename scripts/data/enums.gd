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

## Tags portes par les sorts ; les ennemis peuvent y etre immunises.
enum DamageTag { PHYSICAL, FIRE, FROST, ARCANE, SLOW, SUMMON }

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
enum RewardKind { TITLE, AVATAR }


static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON: return "commune"
		Rarity.RARE: return "rare"
		Rarity.EPIC: return "epique"
		Rarity.LEGENDARY: return "legendaire"
	return "?"
