extends Node
## Sonde du mode infini : ce que la descente envoie REELLEMENT, vague par vague.
## Pas un test : un instrument de mesure, a lancer a la main.
## Usage : Godot --headless --path . tools/_probe_infinite.tscn

func _ready() -> void:
	await get_tree().process_frame
	var membership: Dictionary = WaveSpawner.build_membership()
	print("=== APPARTENANCE DES MONSTRES AUX MONDES ===")
	var par_monde: Dictionary = {}
	for id in membership:
		var w: int = int(membership[id])
		if not par_monde.has(w):
			par_monde[w] = []
		par_monde[w].append(String(id))
	var cles: Array = par_monde.keys()
	cles.sort()
	for w in cles:
		var noms: Array = par_monde[w]
		noms.sort()
		print("  monde %d (%s) : %s" % [w,
			String(WaveBudget.WORLDS[w].get("name", "")), ", ".join(noms)])
	var orphelins: Array[String] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if not membership.has(d.id):
			orphelins.append(String(d.id))
	orphelins.sort()
	print("  sans monde : %s" % ", ".join(orphelins))

	# Le pool du mode infini tel que le jeu le construit pour lvl_01.
	var pool: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and not d.is_boss() and not d.projectile:
			pool.append(d)
	var bosses: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.is_boss():
			bosses.append(d)

	print("\n=== LA DESCENTE, VAGUE PAR VAGUE (graine 7) ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in range(1, 31):
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, bosses, membership)
		var noms: Array[String] = []
		var pv: float = 0.0
		var corps: int = 0
		var locaux: int = 0
		var etrangers: int = 0
		var monde: int = WaveBudget.world_index_for(n)
		for e: WaveEntry in w.entries:
			if e.enemy == null:
				continue
			var c: int = e.count * maxi(1, e.enemy.swarm_count)
			corps += c
			pv += e.enemy.max_hp * c * w.difficulty
			noms.append("%sx%d" % [String(e.enemy.id), e.count])
			if not e.enemy.is_boss():
				if int(membership.get(e.enemy.id, -1)) == monde:
					locaux += e.count
				else:
					etrangers += e.count
		var tag: String = ""
		if w.is_boss:
			tag = " [BOSS]"
		elif w.is_miniboss:
			tag = " [mini]"
		print("  v%-2d %-14s budget %2d (brut %2d) | %2d corps, %5.0f PV | local %d / etranger %d%s"
			% [n, WaveBudget.backdrop_for(n), WaveBudget.budget_for(n),
				WaveBudget.raw_budget_for(n), corps, pv, locaux, etrangers, tag])
		print("        %s" % ", ".join(noms))

	# Le DOSAGE, mesure sur le vrai contenu et non sur un pool de test.
	print("\n=== DOSAGE DU LIEU SUR LE VRAI BESTIAIRE ===")
	for monde in WaveBudget.WORLDS.size():
		var dedans: int = 0
		var total: int = 0
		for s in range(1, 200):
			var r := RandomNumberGenerator.new()
			r.seed = s
			for d in WaveBudget.compose_for_world(24, pool, r, monde, membership):
				total += 1
				if int(membership.get(d.id, -1)) == monde:
					dedans += 1
		print("  monde %d (%-20s) : %.0f %% de monstres du lieu"
			% [monde, String(WaveBudget.WORLDS[monde].get("name", "")),
				100.0 * dedans / maxf(total, 1.0)])
	get_tree().quit(0)
