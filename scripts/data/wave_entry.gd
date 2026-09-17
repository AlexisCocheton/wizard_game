class_name WaveEntry
extends Resource
## Un groupe de monstres au sein d'une vague.

@export var enemy: EnemyDef
@export var count: int = 1
## Delai entre deux apparitions de ce groupe, en secondes.
@export var spawn_delay: float = 0.8
## Decalage avant la premiere apparition, en secondes depuis le debut de la vague.
@export var start_offset: float = 0.0
