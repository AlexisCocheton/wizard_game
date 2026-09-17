extends TestCase
## Vagues par budget de puissance : composition, bornes, determinisme, boss.

func get_suite_name() -> String:
	return "wave_budget"


func _def(id: String, power: int, kind: int = GameEnums.EnemyKind.NORMAL) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.power = power
	d.kind = kind
	return d


func _pool() -> Array[EnemyDef]:
	return [_def("p1", 1), _def("p2", 2), _def("p3", 3), _def("p4", 4)]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func run() -> void:
	_test_budget_progressif()
	_test_composition_respecte_le_budget()
	_test_pool_seul()
	_test_determinisme()
	_test_boss_periodiques()
	_test_vague_jouable()


func _test_budget_progressif() -> void:
	eq(WaveBudget.budget_for(1), 8, "vague 1 : budget 8")
	ok(WaveBudget.budget_for(2) > WaveBudget.budget_for(1), "le budget monte a la vague 2")
	ok(WaveBudget.budget_for(10) > WaveBudget.budget_for(5), "et continue de monter")
	ok(WaveBudget.difficulty_for(10) > WaveBudget.difficulty_for(1), "la difficulte monte aussi")


## Un budget de 8 avec des monstres 1..4 est exactement rempli, jamais depasse.
func _test_composition_respecte_le_budget() -> void:
	for seed_value in [1, 7, 42, 999]:
		var picks: Array[EnemyDef] = WaveBudget.compose(8, _pool(), _rng(seed_value))
		eq(WaveBudget.total_power(picks), 8, "budget 8 exactement rempli (graine %d)" % seed_value)
	var big: Array[EnemyDef] = WaveBudget.compose(23, _pool(), _rng(3))
	eq(WaveBudget.total_power(big), 23, "budget 23 exactement rempli")


func _test_pool_seul() -> void:
	var pool: Array[EnemyDef] = [_def("only", 3), _def("boss", 10, GameEnums.EnemyKind.BOSS)]
	var picks: Array[EnemyDef] = WaveBudget.compose(10, pool, _rng(5))
	for d in picks:
		eq(d.id, &"only", "seuls les monstres du pool, boss exclus")
	eq(WaveBudget.total_power(picks), 9, "3+3+3 : on s arrete quand plus rien n est abordable")


func _test_determinisme() -> void:
	var a: Array[EnemyDef] = WaveBudget.compose(14, _pool(), _rng(2026))
	var b: Array[EnemyDef] = WaveBudget.compose(14, _pool(), _rng(2026))
	eq(a.size(), b.size(), "meme graine, meme nombre")
	var same: bool = true
	for i in a.size():
		if a[i].id != b[i].id:
			same = false
	ok(same, "meme graine, meme composition")


func _test_boss_periodiques() -> void:
	var bosses: Array[EnemyDef] = [
		_def("mini", 6, GameEnums.EnemyKind.MINIBOSS),
		_def("big", 10, GameEnums.EnemyKind.BOSS),
	]
	var w3: WaveDef = WaveBudget.build_wave(3, _pool(), _rng(1), bosses)
	not_ok(w3.is_miniboss or w3.is_boss, "vague 3 : pas de boss")
	var w5: WaveDef = WaveBudget.build_wave(5, _pool(), _rng(1), bosses)
	ok(w5.is_miniboss, "vague 5 : mini-boss")
	eq(w5.entries[0].enemy.id, &"mini", "le mini-boss ouvre la vague")
	var w10: WaveDef = WaveBudget.build_wave(10, _pool(), _rng(1), bosses)
	ok(w10.is_boss, "vague 10 : boss")


func _test_vague_jouable() -> void:
	var w: WaveDef = WaveBudget.build_wave(4, _pool(), _rng(11))
	eq(w.id, &"proc_4", "id de vague procedurale")
	var total: int = 0
	for e in w.entries:
		total += e.count * e.enemy.power
	eq(total, WaveBudget.budget_for(4), "les entrees totalisent le budget")
	ok(w.total_enemies() > 0, "la vague contient des monstres")
