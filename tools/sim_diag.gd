extends Node
## Banc d equilibrage : joue les niveaux en accelere, sans fenetre, et rapporte
## ce qui tue reellement le joueur.
##
## Le mage est pilote par une IA simple mais honnete : elle joue la carte la plus
## adaptee des qu elle le peut, en visant le monstre le plus avance. Elle ne triche
## pas (pas de portee infinie, pas de lancer instantane) : ce qu elle n arrive pas
## a tenir, un joueur humain ne le tiendra pas non plus.
##
## Usage : Godot --headless --path . tools/sim_balance.tscn

const FIXED_DELTA: float = 1.0 / 60.0
const MAX_SECONDS: float = 400.0
## Les niveaux de campagne mesures par le banc. Ajouter ici tout nouveau niveau.
const LEVELS: Array[String] = ["lvl_01", "lvl_02", "lvl_03", "lvl_04", "lvl_05",
	"lvl_06", "lvl_07"]

var _total_damage: float = 0.0
var _cast_time: float = 0.0
var _alive_sum: float = 0.0
var _samples: int = 0
var _by_enemy: Dictionary = {}
var _passed: int = 0
var _killed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("=== DIAG ===")
	var lid: String = OS.get_environment("DIAG_LEVEL")
	for s in range(6):
		RunState.set_seed(1000 + s * 37)
		await _run_level(StringName(lid))
	get_tree().quit(0)


func _unused() -> void:
	print("=== BANC D EQUILIBRAGE ===")
	_report_waves()
	# Une seule partie ne prouve rien : le tirage des cartes et la composition des
	# vagues varient. On mesure un TAUX DE REUSSITE sur plusieurs graines.
	for level_id in LEVELS:
		await _run_level_many(StringName(level_id), 30)
	await _run_massacre_many(20)
	print("=== FIN ===")
	get_tree().quit(0)


## Ce que chaque vague envoie, avant meme de jouer.
func _report_waves() -> void:
	print("\n-- Contenu des vagues (puissance totale, nombre de monstres) --")
	for level_id in LEVELS:
		var level: LevelDef = ContentDB.levels.get(StringName(level_id))
		if level == null:
			continue
		print("  %s :" % level_id)
		for wave: WaveDef in level.waves:
			var power: int = 0
			var count: int = 0
			var hp: float = 0.0
			for entry: WaveEntry in wave.entries:
				if entry.enemy == null:
					continue
				power += entry.enemy.power * entry.count
				count += entry.count
				hp += entry.enemy.max_hp * entry.count * wave.difficulty
			print("    %-14s puissance %3d, %2d monstres, %5.0f PV cumules, %.0f s"
				% [wave.id, power, count, hp, wave.duration])


## Rejoue le meme niveau avec des graines differentes et resume.
func _run_level_many(level_id: StringName, runs: int) -> void:
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level == null:
		return
	var wins: int = 0
	var vagues: Array[int] = []
	var pv: Array[int] = []
	for i in runs:
		var g: GameController = _make_game()
		RunState.set_seed(1000 + i * 37)
		g.start_level(level, GameEnums.Mode.EXPLORATION)
		var st: Dictionary = _play(g)
		if not st["mort"]:
			wins += 1
			pv.append(st["pv"])
		vagues.append(st["vague"])
		g.queue_free()
		await get_tree().process_frame
	var moy: float = 0.0
	for v in vagues:
		moy += v
	moy /= maxf(runs, 1)
	var pv_moy: float = 0.0
	for p in pv:
		pv_moy += p
	pv_moy /= maxf(pv.size(), 1)
	print("
  %s (%s) : %d victoires sur %d, vague atteinte %.1f en moyenne, %.1f PV restants quand ca passe"
		% [level_id, level.display_name, wins, runs, moy, pv_moy])


func _run_massacre_many(runs: int) -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	var vagues: Array[int] = []
	for i in runs:
		var g: GameController = _make_game()
		RunState.set_seed(2000 + i * 53)
		g.start_level(level, GameEnums.Mode.MASSACRE)
		var st: Dictionary = _play(g, 30)
		vagues.append(st["vague"])
		g.queue_free()
		await get_tree().process_frame
	vagues.sort()
	var moy: float = 0.0
	for v in vagues:
		moy += v
	moy /= maxf(runs, 1)
	print("
  Massacre : vague %.1f en moyenne (min %d, max %d) sur %d parties"
		% [moy, vagues[0], vagues[-1], runs])


func _run_level(level_id: StringName) -> void:
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level == null:
		return
	print("\n-- %s (%s) --" % [level_id, level.display_name])
	var g: GameController = _make_game()
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	var stats: Dictionary = _play(g)
	_print_stats(level.display_name, stats)
	g.free()
	await get_tree().process_frame


func _run_massacre(waves: int) -> void:
	print("\n-- Massacre (mode infini) --")
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	var g: GameController = _make_game()
	g.start_level(level, GameEnums.Mode.MASSACRE)
	var stats: Dictionary = _play(g, waves)
	_print_stats("Massacre", stats)
	g.queue_free()


func _make_game() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false      # on avance nous-memes, pas par _process
	return g


## Joue jusqu a la mort, la victoire, ou la limite de vagues.
func _play(g: GameController, stop_after_wave: int = 0) -> Dictionary:
	var t: float = 0.0
	_total_damage = 0.0
	_cast_time = 0.0
	_alive_sum = 0.0
	_samples = 0
	_by_enemy = {}
	_passed = 0
	_killed = 0
	if not g.battlefield.enemy_killed.is_connected(_on_enemy_killed):
		g.battlefield.enemy_killed.connect(_on_enemy_killed)
	if not g.battlefield.mage_hit.is_connected(_on_mage_hit):
		g.battlefield.mage_hit.connect(_on_mage_hit)
	_watch = g
	var hits: int = 0
	var shield_breaks: int = 0
	var cards_played: int = 0
	var cards_missed: int = 0      # main pleine, rien de jouable
	var max_enemies: int = 0
	var wave_reached: int = 0
	var hp_at: Dictionary = {}

	while t < MAX_SECONDS:
		t += FIXED_DELTA
		var before_hp: int = SpeedGauge.hp
		var before_idx: int = SpeedGauge.speed_percent
		g.simulate(FIXED_DELTA)

		if SpeedGauge.hp < before_hp:
			hits += 1
		if SpeedGauge.speed_percent < before_idx and before_idx > 100:
			shield_breaks += 1
		max_enemies = maxi(max_enemies, g.battlefield.enemies.size())
		_alive_sum += g.battlefield.enemies.size()
		_samples += 1
		if RunState.wave_index != wave_reached:
			wave_reached = RunState.wave_index
			hp_at[wave_reached] = SpeedGauge.hp

		if g.caster.is_busy():
			_cast_time += FIXED_DELTA
		# L IA joue des qu une carte est lancable.
		if not g.caster.is_busy():
			var played: bool = _try_play(g)
			if played:
				cards_played += 1
			elif RunState.hand.size() >= GameConfig.MAX_HAND_SIZE:
				cards_missed += 1

		if RunState.pending_offer.size() > 0:
			RunState.pick_offer(0)
		if (SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0) or g.spawner.is_finished():
			break
		if stop_after_wave > 0 and wave_reached >= stop_after_wave:
			break

	return {
		"degats_infliges": _total_damage, "temps_incantation": _cast_time,
		"monstres_moyen": _alive_sum / maxf(_samples, 1.0),
		"passes": _passed, "tues": _killed,
		"par_source": _by_enemy, "temps": t, "coups_recus": hits, "boucliers_brises": shield_breaks,
		"cartes_jouees": cards_played, "cartes_bloquees": cards_missed,
		"monstres_max": max_enemies, "vague": wave_reached,
		"pv": SpeedGauge.hp, "mort": (SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0),
		"pv_par_vague": hp_at,
	}


## Vise le monstre le plus avance (le plus proche du mage) : c est ce que fait
## un joueur qui veut survivre.
## Qui a touche le mage ? On regarde le monstre le plus bas au moment du coup.
var _watch: GameController = null

func _on_enemy_killed(_def: EnemyDef) -> void:
	_killed += 1


func _on_mage_hit(_dmg: int, _source: EnemyDef = null) -> void:
	var nom: String = "projectile ou contact inconnu"
	var y_max: float = -1e9
	if _watch != null:
		for e in _watch.battlefield.enemies:
			if e != null and is_instance_valid(e) and e.position.y > y_max:
				y_max = e.position.y
				nom = String(e.definition.id) if e.definition != null else "?"
	# Un monstre encore loin signifie que le coup vient d un projectile.
	if y_max < GameConfig.MAGE_LINE_Y - 250.0:
		nom = "tir a distance (%s)" % nom
	_by_enemy[nom] = int(_by_enemy.get(nom, 0)) + 1
	_passed += 1


func _try_play(g: GameController) -> bool:
	if RunState.hand.is_empty():
		return false
	var cible: Enemy = null
	var y_max: float = -1e9
	for e in g.battlefield.enemies:
		if e != null and is_instance_valid(e) and e.hp > 0.0 and e.position.y > y_max:
			y_max = e.position.y
			cible = e
	if cible == null:
		return false
	for card: SpellCard in RunState.hand.duplicate():
		var aim: Vector2 = cible.position
		# Une zone se pose la ou il y a le PLUS de monstres, pas sur le plus avance :
		# c est ce qui fait la difference entre subir et nettoyer.
		if card.targeting == GameEnums.Targeting.POSITION:
			aim = _best_cluster(g, _zone_radius(card), cible.position)
		if g.play_card(card, aim, cible):
			return true
	return false


func _zone_radius(card: SpellCard) -> float:
	var r: float = 0.0
	for spec in card.effects:
		if spec != null:
			r = maxf(r, spec.radius)
	return maxf(r, 60.0)


## Centre du groupe le plus fourni dans la moitie basse du terrain.
func _best_cluster(g: GameController, radius: float, defaut: Vector2) -> Vector2:
	var best: Vector2 = defaut
	var best_n: int = 0
	for e in g.battlefield.enemies:
		if e == null or not is_instance_valid(e) or e.hp <= 0.0:
			continue
		var n: int = 0
		for o in g.battlefield.enemies:
			if o != null and is_instance_valid(o) and o.hp > 0.0 					and o.position.distance_to(e.position) <= radius:
				n += 1
		# A nombre egal, on prefere le groupe le plus avance.
		if n > best_n or (n == best_n and e.position.y > best.y):
			best_n = n
			best = e.position
	return best


func _print_stats(nom: String, s: Dictionary) -> void:
	var issue: String = "MORT" if s["mort"] else "survit"
	print("  %s : %s a la vague %d apres %.0f s" % [nom, issue, s["vague"], s["temps"]])
	print("    PV restants %d/%d, boucliers brises %d, coups encaisses %d"
		% [s["pv"], GameConfig.MAGE_MAX_HP, s["boucliers_brises"], s["coups_recus"]])
	print("    cartes jouees %d, tours sans carte jouable (main pleine) %d, pic de monstres %d"
		% [s["cartes_jouees"], s["cartes_bloquees"], s["monstres_max"]])
	print("    monstres tues %d, monstres passes %d (taux d interception %.0f %%)"
		% [s["tues"], s["passes"], 100.0 * s["tues"] / maxf(s["tues"] + s["passes"], 1.0)])
	print("    monstres presents en moyenne %.1f (pic %d)"
		% [s["monstres_moyen"], s["monstres_max"]])
	print("    temps passe a incanter %.0f s sur %.0f s (%.0f %%)"
		% [s["temps_incantation"], s["temps"], 100.0 * s["temps_incantation"] / maxf(s["temps"], 0.01)])
	var src: Dictionary = s["par_source"]
	if not src.is_empty():
		var parts: Array[String] = []
		for k in src:
			parts.append("%s x%d" % [k, src[k]])
		print("    coups par source : " + ", ".join(parts))
	var par_vague: Dictionary = s["pv_par_vague"]
	var keys: Array = par_vague.keys()
	keys.sort()
	var line: String = ""
	for k in keys:
		line += "v%d:%dPV  " % [k, par_vague[k]]
	if line != "":
		print("    " + line)
