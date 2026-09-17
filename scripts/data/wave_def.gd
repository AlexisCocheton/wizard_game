class_name WaveDef
extends Resource
## Une vague de monstres (~20-30 s).

@export var id: StringName = &""
@export var duration: float = 25.0
@export var entries: Array[WaveEntry] = []
## Echelle de difficulte appliquee aux PV/vitesse des monstres de la vague.
@export var difficulty: float = 1.0
@export var is_miniboss: bool = false
@export var is_boss: bool = false


func enemy_defs() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for e in entries:
		if e != null and e.enemy != null:
			out.append(e.enemy)
	return out


func total_enemies() -> int:
	var n := 0
	for e in entries:
		if e != null:
			n += e.count * maxi(1, e.enemy.swarm_count if e.enemy != null else 1)
	return n
