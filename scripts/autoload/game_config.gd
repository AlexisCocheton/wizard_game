extends Node
## Constantes et reglages d'equilibrage. Aucun etat, aucune dependance.
## Premier autoload charge : tous les autres peuvent le lire dans leur _ready().

## --- Vitesse / bouclier ---
const SPEED_STEPS: Array[float] = [1.0, 1.5, 2.0, 4.0]
## Secondes avant que le jeu monte d'un cran tout seul.
const AUTO_RISE_INTERVAL: float = 20.0
## Vitesse a laquelle le monde tourne pendant l'agonie (25 %).
const DEATH_SLOWMO: float = 0.25
## Fraction de jauge d'agonie perdue par seconde reelle -> 4 s avant la defaite.
const DEATH_DRAIN_RATE: float = 0.25
## Mesure au banc : le joueur intercepte ~2 monstres sur 3. Avec 3 PV il perdait
## avant la vague 2. A 8 PV il encaisse ses erreurs et apprend, tout en mourant
## quand meme s il decroche vraiment.
const MAGE_MAX_HP: int = 8

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
const ENEMY_SPEED_SCALE: float = 0.62

## --- Terrain ---
## Le mage se tient en bas ; les monstres descendent vers cette ligne.
const BATTLEFIELD_WIDTH: float = 1080.0
const BATTLEFIELD_HEIGHT: float = 1920.0
const MAGE_LINE_Y: float = 1500.0
const SPAWN_LINE_Y: float = -80.0


func xp_required(level: int) -> int:
	return int(round(XP_PER_LEVEL_BASE * pow(XP_PER_LEVEL_GROWTH, maxi(0, level - 1))))
