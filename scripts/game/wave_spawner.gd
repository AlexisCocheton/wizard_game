class_name WaveSpawner
extends Node
## Deroule les vagues : apparitions echelonnees, fin de vague, mini-boss et boss.
## Deux modes : liste de vagues ecrites (Exploration) ou generation par budget
## sans fin (Massacre / infini).

signal wave_started(index: int, wave: WaveDef)
signal wave_cleared(index: int)
signal all_waves_cleared()

var battlefield: Battlefield = null
var waves: Array[WaveDef] = []
var index: int = -1
var active: bool = false

## Mode infini : les vagues sont fabriquees a la volee par WaveBudget.
var procedural: bool = false
var pool: Array[EnemyDef] = []
var bosses: Array[EnemyDef] = []

var _elapsed: float = 0.0
var _queue: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(bf: Battlefield, wave_list: Array[WaveDef], rng_seed: int = 0) -> void:
	battlefield = bf
	waves = wave_list.duplicate()
	procedural = false
	index = -1
	active = false
	_seed(rng_seed)


func setup_procedural(bf: Battlefield, enemy_pool: Array[EnemyDef],
		boss_pool: Array[EnemyDef], rng_seed: int = 0) -> void:
	battlefield = bf
	waves = []
	procedural = true
	pool = enemy_pool
	bosses = boss_pool
	index = -1
	active = false
	_seed(rng_seed)


func _seed(rng_seed: int) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func start_next() -> bool:
	index += 1
	if procedural and index >= waves.size():
		waves.append(WaveBudget.build_wave(index + 1, pool, _rng, bosses))
	if index >= waves.size():
		active = false
		all_waves_cleared.emit()
		return false
	var w: WaveDef = waves[index]
	_elapsed = 0.0
	_queue.clear()
	for entry in w.entries:
		if entry == null or entry.enemy == null:
			continue
		var count: int = entry.count * maxi(1, entry.enemy.swarm_count)
		for i in count:
			_queue.append({
				"def": entry.enemy,
				"at": entry.start_offset + i * entry.spawn_delay,
				"difficulty": w.difficulty,
			})
	_queue.sort_custom(func(a, b): return a["at"] < b["at"])
	active = true
	wave_started.emit(index, w)
	return true


func tick(delta: float) -> void:
	if not active or battlefield == null:
		return
	_elapsed += SpeedGauge.world_delta(delta)
	while not _queue.is_empty() and _queue[0]["at"] <= _elapsed:
		var item: Dictionary = _queue.pop_front()
		var def: EnemyDef = item["def"]
		battlefield.spawn_enemy(def, _spawn_x(def), item["difficulty"])
	# La vague est finie quand la file est vide et le terrain nettoye.
	if _queue.is_empty() and battlefield.alive_count() == 0:
		active = false
		wave_cleared.emit(index)


func _spawn_x(def: EnemyDef) -> float:
	var margin: float = 90.0
	if def.entry_side:
		return margin if _rng.randi() % 2 == 0 else GameConfig.BATTLEFIELD_WIDTH - margin
	return _rng.randf_range(margin, GameConfig.BATTLEFIELD_WIDTH - margin)


func current_wave() -> WaveDef:
	if index >= 0 and index < waves.size():
		return waves[index]
	return null


## Vrai seulement quand start_next() a franchi la derniere vague ecrite.
## En procedural il n y a pas de derniere vague : jamais fini.
func is_finished() -> bool:
	if procedural:
		return false
	return index >= waves.size()
