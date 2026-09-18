extends Node
## Constantes et reglages d'equilibrage. Aucun etat, aucune dependance.
## Premier autoload charge : tous les autres peuvent le lire dans leur _ready().

## --- Vitesse / bouclier ---
## Vitesse en POURCENTAGE : 100 % normal, 500 % maximum, par pas de 10 %.
## Les quatre paliers fixes d origine (x1/x1.5/x2/x4) ne laissaient aucune nuance.
const SPEED_MAX_PERCENT: int = 500
const SPEED_STEP_PERCENT: int = 10
## Bouclier gagne par point de pourcentage au-dessus de 100 : a 500 % le mage
## encaisse 40 PV de plus, soit une bonne moitie de sa vie. Aller vite est un pari
## payant, mais a 0,2 le bouclier rendait le mage quasi invulnerable au banc.
const SHIELD_PER_PERCENT: float = 0.1
## Ce qu un coup fait perdre en vitesse, et le temps pendant lequel on ne peut
## plus accelerer : on ne relance pas la machine dans la seconde ou l on est touche.
const SPEED_DROP_ON_HIT: int = 60
const SPEED_LOCK_AFTER_HIT: float = 3.0
## Secondes avant que le jeu monte d'un cran tout seul.
const AUTO_RISE_INTERVAL: float = 20.0
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
const DRAW_INTERVAL: float = 5.0
const DRAW_COUNT: int = 2
const MAX_HAND_SIZE: int = 8
## Pas de delai de remelange : la defausse repart dans la pioche des qu elle est
## vide. Le cahier des charges evoquait une "vitesse de melange", mais un temps
## mort au moment ou le joueur n a plus de carte le punit deux fois.

## --- Progression ---
## XP requise pour passer du niveau N au niveau N+1.
const XP_PER_LEVEL_BASE: int = 12
const XP_PER_LEVEL_GROWTH: float = 1.25
## Nombre de cartes proposees a chaque montee de niveau.
const LEVEL_UP_CHOICES: int = 3

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
const ENEMY_SPEED_SCALE: float = 0.70

## --- Terrain ---
## Le mage se tient en bas ; les monstres descendent vers cette ligne.
const BATTLEFIELD_WIDTH: float = 1080.0
const BATTLEFIELD_HEIGHT: float = 1920.0
const MAGE_LINE_Y: float = 1500.0
const SPAWN_LINE_Y: float = -80.0


func xp_required(level: int) -> int:
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, maxi(0, level - 1))))
