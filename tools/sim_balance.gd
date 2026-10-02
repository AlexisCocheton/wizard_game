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
##
## Options, apres `--` (toutes facultatives) :
##   --niveaux=lvl_16,lvl_20   ne mesurer que ces niveaux (defaut : tous)
##   --parties=60              parties par niveau (defaut : 30)
##   --massacre=20             parties de Massacre (0 : aucune ; defaut : 20)
##   --premiere                l ANCIEN bot : toujours la premiere option
##   --premiere=cartes         ... pour les cartes seulement (ou =ameliorations)
##   --graine=1000             decale les graines (bancs paralleles d un niveau)
##   --visee-naive             vise aussi les monstres proteges par un halo
##   --sans-vagues             sans le releve du contenu des vagues
## Plusieurs bancs peuvent tourner en parallele sur des niveaux differents : le
## pas de temps est FIXE et les graines aussi, la charge de la machine change la
## duree du banc, pas son resultat.

const FIXED_DELTA: float = 1.0 / 60.0
## Garde-fou anti-blocage, pas une limite de jeu. Une partie qui l atteint est
## comptee comme un ECHEC, donc il doit rester largement au-dessus de la duree
## reelle du niveau le plus long (214 s de vagues au niveau 7, soit ~330 s joue)
## sinon on mesure la longueur du niveau et non sa difficulte.
const MAX_SECONDS: float = 900.0
## Les niveaux de campagne mesures par le banc — DEDUITS du contenu.
##
## C etait une liste ecrite a la main, avec le commentaire « ajouter ici tout
## nouveau niveau ». Personne ne l a fait sur QUATORZE ajouts : la campagne est
## passee de 7 a 21 niveaux et le banc en mesurait toujours 7, sans rien dire.
## Un outil de mesure qui ignore les deux tiers du jeu est pire qu absent : on
## le croit.
##
## Ordre de JEU et non ordre d identifiant, pour que le rapport se lise comme la
## campagne se parcourt (la campagne s est etendue en ajoutant des niveaux a la
## suite, donc `lvl_17` se joue avant `lvl_03`).
static func _levels() -> Array[String]:
	var niveaux: Dictionary = ContentDB.levels
	var pointes: Dictionary = {}
	for k in niveaux:
		for s in (niveaux[k] as LevelDef).next_levels:
			pointes[StringName(s)] = true
	var departs: Array[StringName] = []
	for k in niveaux:
		if not pointes.has(StringName(k)):
			departs.append(StringName(k))
	departs.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var out: Array[String] = []
	var vus: Dictionary = {}
	var file: Array[StringName] = departs.duplicate()
	var garde: int = 512
	while not file.is_empty() and garde > 0:
		garde -= 1
		var id: StringName = file.pop_front()
		if vus.has(id) or not niveaux.has(id):
			continue
		vus[id] = true
		out.append(String(id))
		for s in (niveaux[id] as LevelDef).next_levels:
			if not vus.has(StringName(s)):
				file.append(StringName(s))
	# Les orphelins : un niveau non mesure doit apparaitre, pas disparaitre.
	var reste: Array[String] = []
	for k in niveaux:
		if not vus.has(StringName(k)):
			reste.append(String(k))
	reste.sort()
	out.append_array(reste)
	return out

var _total_damage: float = 0.0
var _cast_time: float = 0.0
var _alive_sum: float = 0.0
var _samples: int = 0
var _by_enemy: Dictionary = {}
## Vitesse retiree par source, et pas seulement le nombre de coups : un contact de
## Behemoth et une piqure de lutin comptaient pareil, et le classement des causes
## s inversait.
var _dmg_by_enemy: Dictionary = {}
var _passed: int = 0
var _killed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var opts: Dictionary = _options()
	var premiere: String = String(opts.get("premiere", ""))
	if opts.get("premiere", "") is bool:
		premiere = "tout"
	AutoPick.first_upgrade = premiere in ["tout", "ameliorations"]
	AutoPick.first_offer = premiere in ["tout", "cartes"]
	_graine = int(opts.get("graine", 0))
	_visee_naive = opts.has("visee-naive")
	print("=== BANC D EQUILIBRAGE ===")
	print("  choix automatiques : ameliorations %s, cartes %s"
		% ["PREMIERE option" if AutoPick.first_upgrade else "regle AutoPick",
			"PREMIERE option" if AutoPick.first_offer else "regle AutoPick"])
	if not opts.has("sans-vagues"):
		_report_waves()
	var niveaux: Array[String] = _levels()
	if opts.has("niveaux"):
		niveaux.assign(Array(String(opts["niveaux"]).split(",", false)))
	var parties: int = int(opts.get("parties", 30))
	# Une seule partie ne prouve rien : le tirage des cartes et la composition des
	# vagues varient. On mesure un TAUX DE REUSSITE sur plusieurs graines.
	for level_id in niveaux:
		await _run_level_many(StringName(level_id), parties)
	var massacre: int = int(opts.get("massacre", 20))
	if massacre > 0:
		await _run_massacre_many(massacre)
	print("=== FIN ===")
	get_tree().quit(0)


## Decalage des graines (--graine) : deux bancs paralleles du meme niveau ne
## rejouent pas les memes tirages.
var _graine: int = 0


## Options de la ligne de commande (apres `--`) : {nom -> valeur ou true}.
func _options() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var t: String = String(a).trim_prefix("--")
		var i: int = t.find("=")
		if i < 0:
			out[t] = true
		else:
			out[t.substr(0, i)] = t.substr(i + 1)
	return out


## Ce que chaque vague envoie, avant meme de jouer.
func _report_waves() -> void:
	print("\n-- Contenu des vagues (puissance totale, nombre de monstres) --")
	for level_id in _levels():
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
				# Une NUEE compte pour plusieurs corps : `_entry(rat_swarm, 3)`
				# fait descendre 12 rats, pas 3. Compter les entrees cachait
				# le vrai nombre de monstres a l ecran, donc la vraie densite.
				var corps: int = entry.count * maxi(1, entry.enemy.swarm_count)
				power += entry.enemy.power * entry.count
				count += corps
				hp += entry.enemy.max_hp * corps * wave.difficulty
			print("    %-14s puissance %3d, %2d monstres, %5.0f PV cumules, %.0f s"
				% [wave.id, power, count, hp, wave.duration])
		_report_deck_fit(level)


## ADEQUATION DU DECK AU LIEU : pour chaque carte du deck de campagne, le facteur
## de degats moyen contre les monstres des vagues, pondere par leurs PV. Depuis
## que la resistance coute double (degats ET effets, vague 5), un deck qui ne
## repond plus a son lieu se lit ici avant de se lire dans le taux de victoire.
func _report_deck_fit(level: LevelDef) -> void:
	var vus: Dictionary = {}
	var parts: Array[String] = []
	for c: SpellCard in level.exploration_deck:
		if c == null or c.is_passive or vus.has(c.id):
			continue
		vus[c.id] = true
		var somme: float = 0.0
		var poids: float = 0.0
		for wave: WaveDef in level.waves:
			for entry: WaveEntry in wave.entries:
				if entry.enemy == null:
					continue
				var pv: float = entry.enemy.max_hp * entry.count * maxi(1, entry.enemy.swarm_count)
				somme += entry.enemy.resistance_to_tags(c.combat_tags()) * pv
				poids += pv
		parts.append("%s %.2f" % [c.id, somme / maxf(poids, 1.0)])
	print("      deck contre le lieu (facteur moyen pondere par les PV) : " + ", ".join(parts))


## Rejoue le meme niveau avec des graines differentes et resume.
## Ouvre dans le profil (en memoire) `level_id` et tous les niveaux qui le
## precedent dans l ordre de jeu. Aussi utilise par le banc des objectifs.
static func open_levels_up_to(level_id: StringName) -> void:
	for id in _levels():
		SaveData.unlock_level(StringName(id))
		if StringName(id) == level_id:
			return


func _run_level_many(level_id: StringName, runs: int) -> void:
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level == null:
		return
	# PROFIL REALISTE (regle du livre) : une carte est obtenue par le deck d un
	# niveau OUVERT ou par sa prise en combat. Le niveau mesure et ceux qui le
	# precedent dans l ordre de jeu sont ouverts, comme chez un joueur qui y
	# arrive ; sans cela le Massacre mesure apres eux partirait d un pool vide.
	open_levels_up_to(level_id)
	var wins: int = 0
	var vagues: Array[int] = []
	## Vitesse restante a l arrivee. C est la reserve de VIE du mage depuis le
	## 26 septembre : les deux nombres n en font plus qu un.
	var pv: Array[int] = []
	# AMELIORATIONS PRISES, par voie. En headless GameController tranche seul
	# (AutoPick.upgrade_index, la regle d un joueur raisonnable) : sans ce
	# releve, on ne savait pas si le banc mesurait des sorts ameliores ni
	# lesquels, et un ecart de taux ne se rattachait a rien.
	_prises.clear()
	_cartes_prises.clear()
	if not RunState.upgrade_taken.is_connected(_on_upgrade_taken):
		RunState.upgrade_taken.connect(_on_upgrade_taken)
	# CUMULS sur toutes les parties du niveau : une partie seule ne dit pas ce
	# qui tue, trente le disent. Vitesse retiree par source, vague de la mort,
	# temps d incantation, interception, et le temps pour abattre le boss.
	var src_total: Dictionary = {}
	var morts_par_vague: Dictionary = {}
	var incant: float = 0.0
	var duree: float = 0.0
	var tues: int = 0
	var passes: int = 0
	var boss_temps: Array[float] = []
	var boss_vus: int = 0
	# CHANTIER W8 : vagues ECOURTEES (la suivante arrive alors que des monstres
	# restent, GameConfig.WAVE_OVERTIME_SECONDS). Sans ce releve, un ecart de taux
	# apres le minuteur ne se rattachait a rien.
	var ecourtees: int = 0
	_src_par_vague = {}
	for i in runs:
		var g: GameController = _make_game()
		RunState.set_seed(1000 + (_graine + i) * 37)
		g.start_level(level, GameEnums.Mode.EXPLORATION)
		var st: Dictionary = _play(g)
		ecourtees += g.spawner.overtime_count
		if not st["mort"]:
			wins += 1
			pv.append(st["vitesse"])
		else:
			morts_par_vague[st["vague"]] = int(morts_par_vague.get(st["vague"], 0)) + 1
		vagues.append(st["vague"])
		for k in st["degats_par_source"]:
			src_total[k] = int(src_total.get(k, 0)) + int(st["degats_par_source"][k])
		incant += st["temps_incantation"]
		duree += st["temps"]
		tues += st["tues"]
		passes += st["passes"]
		if st["boss_apparu"] >= 0.0:
			boss_vus += 1
			if st["boss_abattu"] >= 0.0:
				boss_temps.append(st["boss_abattu"] - st["boss_apparu"])
		_drop_game(g)
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
  %s (%s) : %d victoires sur %d, vague atteinte %.1f en moyenne, %.0f %% de vitesse restants quand ca passe (plancher 100)"
		% [level_id, level.display_name, wins, runs, moy, pv_moy])
	var total: int = 0
	var parts: Array[String] = []
	var cles: Array = _prises.keys()
	cles.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for k in cles:
		total += int(_prises[k])
		parts.append("%s x%d" % [k, int(_prises[k])])
	print("    ameliorations prises : %d (%.1f par partie) : %s"
		% [total, float(total) / maxf(runs, 1), ", ".join(parts)])
	print("    cartes prises a la montee : " + _top(_cartes_prises, 8))
	print("    vitesse retiree par source (cumul) : " + _top(src_total, 6))
	var vk: Array = _src_par_vague.keys()
	vk.sort()
	for v in vk:
		print("      en vague %d : %s" % [int(v) + 1, _top(_src_par_vague[v], 4)])
	var mv: Array = morts_par_vague.keys()
	mv.sort()
	var mparts: Array[String] = []
	for k in mv:
		mparts.append("v%d x%d" % [int(k) + 1, morts_par_vague[k]])
	print("    morts par vague : " + (", ".join(mparts) if not mparts.is_empty() else "aucune"))
	print("    incantation %.0f %% du temps, interception %.0f %%"
		% [100.0 * incant / maxf(duree, 0.01), 100.0 * tues / maxf(tues + passes, 1.0)])
	print("    vagues ecourtees (restants en jeu) : %d (%.2f par partie)"
		% [ecourtees, float(ecourtees) / maxf(runs, 1)])
	if boss_vus > 0:
		var bt: float = 0.0
		for x in boss_temps:
			bt += x
		print("    boss : abattu %d fois sur %d apparitions, en %.1f s en moyenne"
			% [boss_temps.size(), boss_vus, bt / maxf(boss_temps.size(), 1)])


## Les `n` plus grosses entrees d un compteur {nom -> nombre}, decroissant.
func _top(d: Dictionary, n: int) -> String:
	var cles: Array = d.keys()
	cles.sort_custom(func(a: Variant, b: Variant) -> bool: return int(d[a]) > int(d[b]))
	var parts: Array[String] = []
	for k in cles.slice(0, n):
		parts.append("%s %d" % [k, int(d[k])])
	return ", ".join(parts) if not parts.is_empty() else "rien"


## Cartes prises a la montee de niveau pendant les parties d un niveau.
var _cartes_prises: Dictionary = {}
## Vitesse retiree par VAGUE puis par source, cumulee sur les parties d un
## niveau : {vague -> {source -> vitesse}}. Dit QUELLE vague tue, et avec quoi.
var _src_par_vague: Dictionary = {}
## Monstres DEJA croises dans la partie en cours : ce qu un joueur a vu a l ecran,
## seule information que le choix automatique des cartes a le droit de lire.
var _vus: Dictionary = {}
var _boss_apparu: float = -1.0
var _boss_abattu: float = -1.0
var _t: float = 0.0


## Voies retenues pendant les parties d un niveau : {id de voie -> nombre}.
var _prises: Dictionary = {}


func _on_upgrade_taken(_card: SpellCard, path: Dictionary) -> void:
	var id: String = String(path.get("id", "?"))
	_prises[id] = int(_prises.get(id, 0)) + 1


## `plafond_vagues` borne la partie : une partie qui l atteint n est PAS morte,
## elle a survecu a la mesure. Les compter a part evite de lire "vague 30" comme
## une difficulte alors que c est une absence de difficulte.
##
## LE RESULTAT DEPEND DU PROFIL. Hors campagne, le pool de montee de niveau est
## fait des cartes OBTENUES (RunState.levelup_pool). Apres les 21 niveaux, le
## profil (en memoire, jamais ecrit en headless) contient ce que le bot y a pris ;
## lance seul (--niveaux=none), le Massacre part d un profil neuf, sans aucune
## carte a proposer. Mesure : 13,4 vagues dans le premier cas, 7,7 dans le second,
## au meme code. Ne comparer que deux Massacres mesures de la meme facon.
func _run_massacre_many(runs: int, plafond_vagues: int = 30) -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	var vagues: Array[int] = []
	for i in runs:
		var g: GameController = _make_game()
		RunState.set_seed(2000 + (_graine + i) * 53)
		g.start_level(level, GameEnums.Mode.INFINITE)
		var st: Dictionary = _play(g, plafond_vagues)
		vagues.append(st["vague"])
		_drop_game(g)
		await get_tree().process_frame
	var brut: Array[int] = vagues.duplicate()
	vagues.sort()
	var moy: float = 0.0
	for v in vagues:
		moy += v
	moy /= maxf(runs, 1)
	print("
  Massacre : vague %.1f en moyenne (min %d, max %d) sur %d parties"
		% [moy, vagues[0], vagues[-1], runs])
	# OU la partie s arrete, pas seulement quand. Le mode infini est decoupe en
	# blocs de monde termines par un boss : savoir si les parties meurent SUR le
	# palier ou entre deux paliers est ce qui dit si le boss est trop dur.
	var sur_boss: int = 0
	var sur_mini: int = 0
	var ordinaire: int = 0
	var plafond: int = 0
	var par_monde: Dictionary = {}
	for v in brut:
		if v >= plafond_vagues:
			plafond += 1
			continue
		if WaveBudget.is_boss_wave(v):
			sur_boss += 1
		elif WaveBudget.is_miniboss_wave(v):
			sur_mini += 1
		else:
			ordinaire += 1
		var m: int = WaveBudget.world_index_for(maxi(1, v))
		par_monde[m] = int(par_monde.get(m, 0)) + 1
	print("    fins : %d sur un boss, %d sur un mini-boss, %d sur une vague ordinaire, %d au plafond (%d vagues)"
		% [sur_boss, sur_mini, ordinaire, plafond, plafond_vagues])
	var cles: Array = par_monde.keys()
	cles.sort()
	var parts: Array[String] = []
	for m in cles:
		parts.append("%s x%d" % [WaveBudget.backdrop_for(m * WaveBudget.WORLD_EVERY + 1),
			int(par_monde[m])])
	print("    monde ou ca s arrete : " + ", ".join(parts))


func _run_level(level_id: StringName) -> void:
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level == null:
		return
	print("\n-- %s (%s) --" % [level_id, level.display_name])
	var g: GameController = _make_game()
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	var stats: Dictionary = _play(g)
	_print_stats(level.display_name, stats)
	_drop_game(g)


func _run_massacre(waves: int) -> void:
	print("\n-- Massacre (mode infini) --")
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	var g: GameController = _make_game()
	g.start_level(level, GameEnums.Mode.INFINITE)
	var stats: Dictionary = _play(g, waves)
	_print_stats("Massacre", stats)
	_drop_game(g)


func _make_game() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	# On avance la partie nous-memes avec un delta FIXE. Mettre `running = false`
	# ne suffit pas : `start_level()` le remet a vrai, et `_process` se remet alors
	# a appeler `simulate()` avec le delta REEL, en plus de nos appels. Deux
	# simulations partageaient les memes autoloads (SpeedGauge, RunState).
	# Couper le traitement du noeud est la seule barriere qui tient.
	g.set_process(false)
	g.set_physics_process(false)
	return g


## Detruit la partie IMMEDIATEMENT. `queue_free()` laissait la partie precedente
## vivante une frame de plus : elle continuait a piloter SpeedGauge et RunState
## pendant que la suivante demarrait. Avec 30 parties d affilee, le banc mesurait
## la pollution accumulee et non le niveau — deux executions identiques rendaient
## 30/30 puis 16/30 sur le niveau 1.
func _drop_game(g: GameController) -> void:
	if g == null or not is_instance_valid(g):
		return
	g.running = false
	g.set_process(false)
	g.set_physics_process(false)
	remove_child(g)
	g.free()


## Joue jusqu a la mort, la victoire, ou la limite de vagues.
func _play(g: GameController, stop_after_wave: int = 0) -> Dictionary:
	var t: float = 0.0
	_total_damage = 0.0
	_cast_time = 0.0
	_alive_sum = 0.0
	_samples = 0
	_by_enemy = {}
	_dmg_by_enemy = {}
	_passed = 0
	_killed = 0
	_vus = {}
	_boss_apparu = -1.0
	_boss_abattu = -1.0
	_t = 0.0
	if not g.battlefield.enemy_killed.is_connected(_on_enemy_killed):
		g.battlefield.enemy_killed.connect(_on_enemy_killed)
	if not g.battlefield.mage_hit.is_connected(_on_mage_hit):
		g.battlefield.mage_hit.connect(_on_mage_hit)
	_watch = g
	var hits: int = 0
	var cards_played: int = 0
	var cards_missed: int = 0      # main pleine, rien de jouable
	var max_enemies: int = 0
	var wave_reached: int = 0
	var hp_at: Dictionary = {}
	## Le niveau a-t-il ete TERMINE ? Sans ce drapeau, une partie qui atteignait
	## la limite de temps sans finir comptait pour une victoire : les niveaux les
	## plus longs paraissaient les plus faciles.
	var fini: bool = false

	while t < MAX_SECONDS:
		t += FIXED_DELTA
		# La VITESSE est la seule reserve du mage depuis le 26 septembre : ce
		# qu on mesurait comme "PV restants" est desormais "vitesse restante",
		# et c est le meme nombre qui dit sa vie et sa puissance.
		var before_hp: int = SpeedGauge.speed_percent
		g.simulate(FIXED_DELTA)

		if SpeedGauge.speed_percent < before_hp:
			hits += 1
		_t = t
		for e in g.battlefield.enemies:
			if e != null and is_instance_valid(e) and e.definition != null:
				_vus[e.definition.id] = e.definition
				if _boss_apparu < 0.0 and e.definition.kind == GameEnums.EnemyKind.BOSS:
					_boss_apparu = t
		max_enemies = maxi(max_enemies, g.battlefield.enemies.size())
		_alive_sum += g.battlefield.enemies.size()
		_samples += 1
		if RunState.wave_index != wave_reached:
			wave_reached = RunState.wave_index
			hp_at[wave_reached] = SpeedGauge.speed_percent

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
			var k: int = AutoPick.offer_index(RunState.pending_offer, _vus.values())
			var prise: SpellCard = RunState.pending_offer[k]
			_cartes_prises[String(prise.id)] = int(_cartes_prises.get(String(prise.id), 0)) + 1
			RunState.pick_offer(k)
		if SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0:
			break
		if g.spawner.is_finished():
			fini = true
			break
		if stop_after_wave > 0 and wave_reached >= stop_after_wave:
			fini = true
			break

	return {
		"degats_infliges": _total_damage, "temps_incantation": _cast_time,
		"monstres_moyen": _alive_sum / maxf(_samples, 1.0),
		"passes": _passed, "tues": _killed,
		"par_source": _by_enemy, "degats_par_source": _dmg_by_enemy, "temps": t, "coups_recus": hits,
		"cartes_jouees": cards_played, "cartes_bloquees": cards_missed,
		"monstres_max": max_enemies, "vague": wave_reached,
		"vitesse": SpeedGauge.speed_percent,
		# Une partie qui n a NI tue le joueur NI fini le niveau (limite de temps)
		# n est pas une victoire : elle ne compte pas comme un succes.
		"mort": (SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0) or not fini,
		"fini": fini, "vitesse_par_vague": hp_at,
		"boss_apparu": _boss_apparu, "boss_abattu": _boss_abattu,
	}


## Vise le monstre le plus avance (le plus proche du mage) : c est ce que fait
## un joueur qui veut survivre.
## La partie observee, pour le repli d attribution d un coup sans source.
var _watch: GameController = null

func _on_enemy_killed(def: EnemyDef) -> void:
	_killed += 1
	if def != null and def.kind == GameEnums.EnemyKind.BOSS and _boss_abattu < 0.0:
		_boss_abattu = _t


func _on_mage_hit(dmg: int, source: EnemyDef = null) -> void:
	var nom: String = ""
	# Le signal PORTE sa source (contact, tir, laser, riposte) : c est elle qui
	# compte. L ancienne attribution prenait le monstre le plus bas a l instant du
	# coup, et accusait un Berserker au corps a corps d un « tir a distance » des
	# que le vrai tireur etait plus haut que lui.
	if source != null:
		nom = String(source.id)
	else:
		# Repli sans source (degats d environnement) : le monstre le plus bas.
		nom = "sans source"
		var y_max: float = -1e9
		if _watch != null:
			for e in _watch.battlefield.enemies:
				if e != null and is_instance_valid(e) and e.position.y > y_max:
					y_max = e.position.y
					nom = "sans source (%s)" % (String(e.definition.id) if e.definition != null else "?")
	_by_enemy[nom] = int(_by_enemy.get(nom, 0)) + 1
	_dmg_by_enemy[nom] = int(_dmg_by_enemy.get(nom, 0)) + dmg
	var v: int = RunState.wave_index
	if not _src_par_vague.has(v):
		_src_par_vague[v] = {}
	_src_par_vague[v][nom] = int(_src_par_vague[v].get(nom, 0)) + dmg
	_passed += 1


## Le geste du bot (quelle carte, sur qui, ou poser une zone) vit dans AutoPick
## (try_play) : le banc des objectifs (tools/objective_bench.gd) joue avec le
## MEME geste, a sa politique d objectif pres. Le halo des totems, la cible la
## plus avancee et la zone sur le plus gros groupe y sont documentes.
## `--visee-naive` vise aussi les monstres proteges par un halo, pour mesurer.
var _visee_naive: bool = false


func _try_play(g: GameController) -> bool:
	return AutoPick.try_play(g, null, _visee_naive)


func _print_stats(nom: String, s: Dictionary) -> void:
	var issue: String = "MORT" if s["mort"] else "survit"
	print("  %s : %s a la vague %d apres %.0f s" % [nom, issue, s["vague"], s["temps"]])
	# "vitesse restante" et non "PV restants" : c est la MEME reserve, et c est
	# ce que le testeur regle. 100 % est le plancher mortel, pas un zero.
	print("    vitesse restante %d %% (plancher 100, max %d), coups encaisses %d"
		% [s["vitesse"], GameConfig.SPEED_MAX_PERCENT, s["coups_recus"]])
	print("    cartes jouees %d, tours sans carte jouable (main pleine) %d, pic de monstres %d"
		% [s["cartes_jouees"], s["cartes_bloquees"], s["monstres_max"]])
	print("    monstres tues %d, monstres passes %d (taux d interception %.0f %%)"
		% [s["tues"], s["passes"], 100.0 * s["tues"] / maxf(s["tues"] + s["passes"], 1.0)])
	print("    monstres presents en moyenne %.1f (pic %d)"
		% [s["monstres_moyen"], s["monstres_max"]])
	print("    temps passe a incanter %.0f s sur %.0f s (%.0f %%)"
		% [s["temps_incantation"], s["temps"], 100.0 * s["temps_incantation"] / maxf(s["temps"], 0.01)])
	var src: Dictionary = s["par_source"]
	var dmg: Dictionary = s["degats_par_source"]
	if not src.is_empty():
		var parts: Array[String] = []
		for k in src:
			parts.append("%s x%d (-%d %%)" % [k, src[k], int(dmg.get(k, 0))])
		print("    coups par source : " + ", ".join(parts))
	var par_vague: Dictionary = s["vitesse_par_vague"]
	var keys: Array = par_vague.keys()
	keys.sort()
	var line: String = ""
	for k in keys:
		line += "v%d:%d%%  " % [k, par_vague[k]]
	if line != "":
		print("    " + line)
