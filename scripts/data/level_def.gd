class_name LevelDef
extends Resource
## Un niveau de la campagne.

@export var id: StringName = &""
@export var display_name: String = ""
## Tuiles du decor : "grass" ou "sand" (tilesets Tiny Swords).
@export var terrain: String = "grass"
@export var waves: Array[WaveDef] = []
## Pool de monstres utilisable par la generation procedurale de vagues.
@export var enemy_pool: Array[EnemyDef] = []
## Deck impose en mode Exploration.
@export var exploration_deck: Array[SpellCard] = []
## Exactement 3 objectifs (verifie par l'etage AUDIT).
@export var objectives: Array[ObjectiveDef] = []
## Carte legendaire debloquee en validant les 3 objectifs.
@export var legendary_reward: SpellCard
## Niveaux accessibles apres victoire.
@export var next_levels: Array[StringName] = []


func boss_wave() -> WaveDef:
	for w in waves:
		if w != null and w.is_boss:
			return w
	return null
