class_name WaveBudget
extends RefCounted
## Composition de vagues par budget de puissance.
##
## Chaque monstre a une puissance 1..4. Une vague de budget 8 est une combinaison
## dont les puissances totalisent 8 : par exemple un monstre 4 + deux monstres 2.
## Le budget croit vague apres vague : c est la montee progressive du mode infini.
##
## Logique pure, RNG injecte : deterministe et testable a froid.

const BASE_BUDGET: int = 8
const GROWTH_PER_WAVE: int = 3
## Un mini-boss toutes les 5 vagues, un boss toutes les 10.
const MINIBOSS_EVERY: int = 5
const BOSS_EVERY: int = 10
## Au-dela, la difficulte (PV/vitesse) monte aussi, pas seulement le nombre.
const DIFFICULTY_PER_WAVE: float = 0.04


## Budget de puissance de la vague n (n commence a 1).
static func budget_for(wave_number: int) -> int:
	return BASE_BUDGET + GROWTH_PER_WAVE * maxi(0, wave_number - 1)


static func difficulty_for(wave_number: int) -> float:
	return 1.0 + DIFFICULTY_PER_WAVE * maxi(0, wave_number - 1)


## Tire des monstres du pool jusqu a epuiser le budget. Ne depasse jamais.
static func compose(budget: int, pool: Array[EnemyDef], rng: RandomNumberGenerator) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var remaining: int = budget
	var guard: int = 256
	while remaining > 0 and guard > 0:
		guard -= 1
		var affordable: Array[EnemyDef] = []
		for def in pool:
			if def != null and not def.is_boss() and def.power <= remaining:
				affordable.append(def)
		if affordable.is_empty():
			break
		var pick: EnemyDef = affordable[rng.randi_range(0, affordable.size() - 1)]
		out.append(pick)
		remaining -= pick.power
	return out


static func total_power(defs: Array[EnemyDef]) -> int:
	var n: int = 0
	for d in defs:
		if d != null:
			n += d.power
	return n


## Construit une WaveDef jouable pour la vague n.
static func build_wave(wave_number: int, pool: Array[EnemyDef],
		rng: RandomNumberGenerator, bosses: Array[EnemyDef] = []) -> WaveDef:
	var w := WaveDef.new()
	w.id = StringName("proc_%d" % wave_number)
	w.duration = 25.0
	w.difficulty = difficulty_for(wave_number)

	var picks: Array[EnemyDef] = compose(budget_for(wave_number), pool, rng)
	# Regroupe par type pour espacer les apparitions d un meme groupe.
	var counts: Dictionary = {}
	var order: Array[EnemyDef] = []
	for d in picks:
		if not counts.has(d):
			counts[d] = 0
			order.append(d)
		counts[d] = int(counts[d]) + 1
	var offset: float = 0.0
	for d in order:
		var e := WaveEntry.new()
		e.enemy = d
		e.count = int(counts[d])
		# Les faibles arrivent serres, les forts espaces.
		e.spawn_delay = 0.6 + 0.35 * d.power
		e.start_offset = offset
		offset += 1.5
		w.entries.append(e)

	# Boss et mini-boss ponctuels, hors budget.
	if not bosses.is_empty():
		var boss: EnemyDef = null
		if wave_number % BOSS_EVERY == 0:
			boss = _first_of_kind(bosses, GameEnums.EnemyKind.BOSS)
			w.is_boss = boss != null
		elif wave_number % MINIBOSS_EVERY == 0:
			boss = _first_of_kind(bosses, GameEnums.EnemyKind.MINIBOSS)
			w.is_miniboss = boss != null
		if boss != null:
			var be := WaveEntry.new()
			be.enemy = boss
			be.count = 1
			be.spawn_delay = 1.0
			be.start_offset = 0.0
			w.entries.insert(0, be)
			w.duration += 15.0
	return w


static func _first_of_kind(defs: Array[EnemyDef], kind: GameEnums.EnemyKind) -> EnemyDef:
	for d in defs:
		if d != null and d.kind == kind:
			return d
	return null
