extends TestCase
## MOTEUR D OBJECTIFS PARAMETRES (voir le tableau en tete de objective_checker.gd).
##
## Pour chaque cle : un cas qui la REUSSIT et un cas qui la FAIT ECHOUER, au
## seuil exact quand il y en a un. Les seuils viennent des PARAMETRES poses par
## le test, jamais d une valeur d equilibrage : le chantier de contenu doit
## pouvoir regler "30 lancers" en 20 sans toucher a cette suite.
##
## Puis : la validation que lit l AUDIT (parametre manquant, en trop, mal type,
## hors bornes), les libelles generes, la coherence avec un niveau, et les
## CROCHETS reellement branches dans le jeu (horloge, morts, releve, renvoi,
## profondeur, victoire). Un compteur juste mais jamais appele ne vaut rien.

func get_suite_name() -> String:
	return "objective_engine"


## Un jeu de parametres VALIDES par cle. Une cle ajoutee au moteur sans entree
## ici fait echouer _test_every_key_has_a_sample : pas de cle sans test.
const SAMPLES: Dictionary = {
	&"never_dropped_speed": {},
	&"no_legendary_used": {},
	&"no_damage_taken": {},
	&"same_card_casts": {"count": 30},
	&"win_below_speed": {"pct": 300},
	&"multi_kill": {"count": 5, "window": 1.0},
	&"no_card_key": {"key": "build_wall"},
	&"no_card_tag": {"tag": "FIRE"},
	&"element_casts": {"element": "FROST", "count": 10},
	&"kill_flying": {"count": 8},
	&"boss_quick_after_revive": {"seconds": 5},
	&"never_hit_reflect": {},
	&"no_enemy_past": {"ratio": 0.5},
	&"win_under_time": {"seconds": 180},
	&"max_distinct_cast": {"count": 4},
	&"no_passive": {},
}


func _obj(key: StringName, params: Dictionary = {}) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName("t_%s" % key)
	o.check_key = key
	o.description = "repli_%s" % key
	o.params = params.duplicate()
	return o


func _card(id: String, tags: Array = [], keys: Array = []) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	for t in tags:
		c.tags.append(t)
	for k in keys:
		var s := EffectSpec.new()
		s.key = StringName(k)
		c.effects.append(s)
	return c


func _enemy_def(id: String) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 100.0
	d.base_speed = 0.0
	d.base_radius = 40.0
	return d


func _fresh() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()


func run() -> void:
	_test_every_key_has_a_sample()
	_test_effect_phrases_are_real_effects()
	_test_same_card_casts()
	_test_win_below_speed()
	_test_multi_kill()
	_test_multi_kill_same_frame()
	_test_no_card_key()
	_test_no_card_tag()
	_test_element_casts()
	_test_kill_flying()
	_test_boss_quick_after_revive()
	_test_never_hit_reflect()
	_test_no_enemy_past()
	_test_win_under_time()
	_test_max_distinct_cast()
	_test_no_passive()
	_test_validation_rejects_bad_params()
	_test_malformed_never_validates()
	_test_labels()
	_test_coherence_with_level()
	_test_hook_revive_and_reflect()
	_test_hook_enemy_depth()
	_test_hooks_in_game_controller()
	_test_reset_clears_counters()
	_fresh()


# --- Catalogue ----------------------------------------------------------------

func _test_every_key_has_a_sample() -> void:
	for key: StringName in ObjectiveChecker.KEYS:
		ok(SAMPLES.has(key), "la cle %s a un jeu de parametres dans cette suite" % key)
		ok(ObjectiveChecker.SCHEMA.has(key), "la cle %s a un schema" % key)
		if SAMPLES.has(key):
			eq(ObjectiveChecker.validate(_obj(key, SAMPLES[key])).size(), 0,
				"les parametres d exemple de %s sont valides" % key)
	eq(ObjectiveChecker.SCHEMA.size(), ObjectiveChecker.KEYS.size(),
		"pas de schema orphelin")


## Une cle d effet renommee dans handlers.gd laisserait un objectif "sans X"
## gratuit a jamais : aucun sort ne porterait plus la cle interdite.
func _test_effect_phrases_are_real_effects() -> void:
	for k: StringName in ObjectiveChecker.EFFECT_PHRASES:
		ok(EffectRegistry.has_key(k), "la cle d effet %s existe dans EffectRegistry" % k)


# --- Une cle, deux issues -----------------------------------------------------

func _test_same_card_casts() -> void:
	_fresh()
	var n: int = 3
	var o := _obj(&"same_card_casts", {"count": n})
	# Deux EXEMPLAIRES du meme sort : ils comptent ensemble.
	var a1 := _card("sort_a")
	var a2 := _card("sort_a")
	var b := _card("sort_b")
	for i in n - 1:
		RunState.note_cast(a1 if i % 2 == 0 else a2)
	for i in n + 2:
		RunState.note_cast(b if i < n - 1 else _card("autre_%d" % i))
	not_ok(ObjectiveChecker.evaluate(o), "same_card_casts : n-1 lancers du meme sort echouent")
	RunState.note_cast(a2)
	ok(ObjectiveChecker.evaluate(o), "same_card_casts : n lancers, exemplaires confondus, reussissent")


func _test_win_below_speed() -> void:
	_fresh()
	var pct: int = 300
	var o := _obj(&"win_below_speed", {"pct": pct})
	SpeedGauge.set_speed_percent(pct - 1)
	RunState.note_victory()
	# La jauge bouge APRES la victoire : c est la photo qui compte.
	SpeedGauge.set_speed_percent(pct + 50)
	ok(ObjectiveChecker.evaluate(o), "win_below_speed : sous le seuil a la victoire, reussi")
	_fresh()
	SpeedGauge.set_speed_percent(pct)
	RunState.note_victory()
	SpeedGauge.set_speed_percent(pct - 50)
	not_ok(ObjectiveChecker.evaluate(o), "win_below_speed : pile au seuil, echoue (strict)")


func _test_multi_kill() -> void:
	_fresh()
	var w: float = 1.0
	var o := _obj(&"multi_kill", {"count": 3, "window": w})
	var d := _enemy_def("m")
	RunState.note_kill(d)
	RunState.advance_clock(w * 0.6)
	RunState.note_kill(d)
	RunState.advance_clock(w * 0.6)
	RunState.note_kill(d)
	not_ok(ObjectiveChecker.evaluate(o), "multi_kill : 3 morts etalees sur plus que la fenetre echouent")
	eq(RunState.best_kill_burst(w), 2, "deux morts tiennent dans la fenetre")
	RunState.advance_clock(w * 0.3)
	RunState.note_kill(d)
	ok(ObjectiveChecker.evaluate(o), "multi_kill : 3 morts dans la fenetre reussissent")


func _test_multi_kill_same_frame() -> void:
	_fresh()
	var o := _obj(&"multi_kill", {"count": 4, "window": 0.1})
	var d := _enemy_def("m")
	RunState.advance_clock(3.0)
	for i in 4:
		RunState.note_kill(d)
	ok(ObjectiveChecker.evaluate(o), "multi_kill : quatre morts de la meme image tiennent ensemble")


func _test_no_card_key() -> void:
	_fresh()
	var o := _obj(&"no_card_key", {"key": "build_wall"})
	RunState.note_cast(_card("trait", [GameEnums.DamageTag.FIRE], ["damage_single"]))
	ok(ObjectiveChecker.evaluate(o), "no_card_key : sans mur, reussi")
	RunState.note_cast(_card("muraille", [], ["build_wall", "knockback"]))
	not_ok(ObjectiveChecker.evaluate(o), "no_card_key : un mur pose, echoue")


func _test_no_card_tag() -> void:
	_fresh()
	var o := _obj(&"no_card_tag", {"tag": "FIRE"})
	RunState.note_cast(_card("givre", [GameEnums.DamageTag.FROST], ["damage_single"]))
	ok(ObjectiveChecker.evaluate(o), "no_card_tag : aucun sort de feu, reussi")
	RunState.note_cast(_card("feu", [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.SLOW],
		["damage_single"]))
	not_ok(ObjectiveChecker.evaluate(o), "no_card_tag : un sort de feu, echoue")


func _test_element_casts() -> void:
	_fresh()
	var n: int = 3
	var o := _obj(&"element_casts", {"element": "FROST", "count": n})
	var givre := _card("givre", [GameEnums.DamageTag.FROST], ["damage_single"])
	for i in n - 1:
		RunState.note_cast(givre)
	RunState.note_cast(_card("feu", [GameEnums.DamageTag.FIRE], ["damage_single"]))
	not_ok(ObjectiveChecker.evaluate(o), "element_casts : n-1 sorts de givre echouent")
	RunState.note_cast(givre)
	ok(ObjectiveChecker.evaluate(o), "element_casts : n sorts de givre reussissent")


func _test_kill_flying() -> void:
	_fresh()
	var o := _obj(&"kill_flying", {"count": 2})
	var vol := _enemy_def("vol")
	vol.flying = true
	RunState.note_kill(vol)
	RunState.note_kill(_enemy_def("sol"))
	RunState.note_kill(_enemy_def("sol2"))
	not_ok(ObjectiveChecker.evaluate(o), "kill_flying : les rampants ne comptent pas")
	RunState.note_kill(vol)
	ok(ObjectiveChecker.evaluate(o), "kill_flying : deux volants abattus, reussi")


func _test_boss_quick_after_revive() -> void:
	var s: float = 5.0
	var o := _obj(&"boss_quick_after_revive", {"seconds": s})
	_fresh()
	not_ok(ObjectiveChecker.evaluate(o), "boss_quick_after_revive : aucun releve, echoue")

	_fresh()
	RunState.note_enemy_revived(101)
	RunState.advance_clock(s * 0.8)
	RunState.note_revived_enemy_killed(101)
	ok(ObjectiveChecker.evaluate(o), "boss_quick_after_revive : acheve a temps, reussi")

	_fresh()
	RunState.note_enemy_revived(102)
	RunState.advance_clock(s)
	RunState.note_revived_enemy_killed(102)
	not_ok(ObjectiveChecker.evaluate(o), "boss_quick_after_revive : pile au delai, echoue (strict)")

	_fresh()
	RunState.note_enemy_revived(103)
	RunState.note_revived_enemy_killed(103)
	RunState.note_enemy_revived(104)
	not_ok(ObjectiveChecker.evaluate(o),
		"boss_quick_after_revive : un releve jamais acheve fait echouer")


func _test_never_hit_reflect() -> void:
	_fresh()
	var o := _obj(&"never_hit_reflect")
	ok(ObjectiveChecker.evaluate(o), "never_hit_reflect : aucun renvoi, reussi")
	RunState.note_reflect_hit()
	not_ok(ObjectiveChecker.evaluate(o), "never_hit_reflect : un renvoi, echoue")


func _y_at(ratio: float) -> float:
	return GameConfig.SPAWN_LINE_Y + ratio * (GameConfig.MAGE_LINE_Y - GameConfig.SPAWN_LINE_Y)


func _test_no_enemy_past() -> void:
	_fresh()
	var r: float = 0.5
	var o := _obj(&"no_enemy_past", {"ratio": r})
	RunState.enemy_depth_max = r - 0.01
	ok(ObjectiveChecker.evaluate(o), "no_enemy_past : reste au-dessus du seuil, reussi")
	RunState.enemy_depth_max = r + 0.01
	not_ok(ObjectiveChecker.evaluate(o), "no_enemy_past : un monstre passe le seuil, echoue")


func _test_win_under_time() -> void:
	var s: float = 180.0
	var o := _obj(&"win_under_time", {"seconds": s})
	_fresh()
	RunState.advance_clock(s - 1.0)
	RunState.note_victory()
	RunState.advance_clock(60.0)  # le temps passe apres la victoire : sans effet
	ok(ObjectiveChecker.evaluate(o), "win_under_time : victoire avant la limite, reussi")
	_fresh()
	RunState.advance_clock(s)
	RunState.note_victory()
	not_ok(ObjectiveChecker.evaluate(o), "win_under_time : pile a la limite, echoue (strict)")


func _test_max_distinct_cast() -> void:
	_fresh()
	var o := _obj(&"max_distinct_cast", {"count": 2})
	RunState.note_cast(_card("a"))
	RunState.note_cast(_card("a"))
	RunState.note_cast(_card("b"))
	ok(ObjectiveChecker.evaluate(o), "max_distinct_cast : deux sorts differents, reussi")
	RunState.note_cast(_card("c"))
	not_ok(ObjectiveChecker.evaluate(o), "max_distinct_cast : un troisieme sort, echoue")


func _test_no_passive() -> void:
	_fresh()
	var o := _obj(&"no_passive")
	ok(ObjectiveChecker.evaluate(o), "no_passive : aucun passif, reussi")
	var p := _card("passif_test")
	p.is_passive = true
	ok(RunState.equip_passive(p), "le passif s equipe")
	not_ok(ObjectiveChecker.evaluate(o), "no_passive : un passif equipe, echoue")


# --- Validation (lue par l AUDIT) ---------------------------------------------

func _test_validation_rejects_bad_params() -> void:
	var cas: Array = [
		[&"same_card_casts", {}, "parametre manquant"],
		[&"same_card_casts", {"count": 30.0}, "entier ecrit en flottant"],
		[&"same_card_casts", {"count": 1}, "seuil gratuit"],
		[&"same_card_casts", {"count": 30, "cout": 3}, "parametre en trop"],
		[&"multi_kill", {"count": 5}, "fenetre manquante"],
		[&"multi_kill", {"count": 5, "window": "1"}, "fenetre en texte"],
		[&"multi_kill", {"count": 5, "window": 0.0}, "fenetre nulle"],
		[&"win_below_speed", {"pct": 100}, "seuil au plancher mortel"],
		[&"win_below_speed", {"pct": GameConfig.SPEED_MAX_PERCENT + 1}, "seuil au-dela du maximum"],
		[&"no_card_tag", {"tag": "FEU"}, "tag inconnu"],
		[&"no_card_tag", {"tag": 1}, "tag en entier"],
		[&"element_casts", {"element": "SLOW", "count": 3}, "SLOW n est pas un element"],
		[&"no_card_key", {"key": "cle_inventee"}, "cle d effet inconnue"],
		[&"no_card_key", {"key": "draw_boost"}, "cle d effet sans libelle"],
		[&"no_enemy_past", {"ratio": 1.0}, "ratio au contact"],
		[&"win_under_time", {"seconds": -5}, "duree negative"],
		[&"never_hit_reflect", {"x": 1}, "parametre sur une cle qui n en a pas"],
		[&"cle_inventee", {}, "cle inconnue"],
	]
	for c in cas:
		var errs: Array[String] = ObjectiveChecker.validate(_obj(c[0], c[1]))
		not_ok(errs.is_empty(), "validate refuse : %s (%s)" % [c[2], c[0]])
	# Les cles String et StringName se valent dans un Dictionary de .tres.
	eq(ObjectiveChecker.validate(_obj(&"kill_flying", {&"count": 3})).size(), 0,
		"un parametre en StringName est accepte")


func _test_malformed_never_validates() -> void:
	_fresh()
	# Parametre manquant : sans ce garde, int(null) = 0 et "0 lancer" reussirait.
	not_ok(ObjectiveChecker.evaluate(_obj(&"same_card_casts", {})),
		"un objectif mal ecrit ne se valide jamais")
	not_ok(ObjectiveChecker.evaluate(_obj(&"max_distinct_cast", {"count": "4"})),
		"un parametre mal type ne se valide jamais")


# --- Libelles -----------------------------------------------------------------

func _test_labels() -> void:
	# Les trois exemples du co-auteur, mot pour mot.
	eq(ObjectiveChecker.label(_obj(&"same_card_casts", {"count": 30})),
		"Lancer 30 fois le meme sort", "exemple co-auteur : 30 lancers")
	eq(ObjectiveChecker.label(_obj(&"win_below_speed", {"pct": 300})),
		"Gagner avec moins de 300 % de vitesse", "exemple co-auteur : 300 %")
	eq(ObjectiveChecker.label(_obj(&"multi_kill", {"count": 5, "window": 1})),
		"Tuer 5 monstres en moins de 1 s", "exemple co-auteur : 5 monstres")
	eq(ObjectiveChecker.label(_obj(&"no_card_key", {"key": "build_wall"})),
		"Gagner sans poser de mur", "sans poser de mur")
	eq(ObjectiveChecker.label(_obj(&"no_card_tag", {"tag": "ARCANE"})),
		"Gagner sans sort d arcane", "elision devant une voyelle")
	eq(ObjectiveChecker.label(_obj(&"element_casts", {"element": "PHYSICAL", "count": 4})),
		"Lancer 4 sorts physiques", "accord de physique")
	eq(ObjectiveChecker.label(_obj(&"win_under_time", {"seconds": 150})),
		"Gagner en moins de 2 min 30", "duree en minutes")
	eq(ObjectiveChecker.label(_obj(&"multi_kill", {"count": 3, "window": 0.5})),
		"Tuer 3 monstres en moins de 0,5 s", "decimale a la francaise")
	eq(ObjectiveChecker.label(_obj(&"no_enemy_past", {"ratio": 0.5})),
		"Aucun monstre au-dela de la moitie du terrain", "la moitie")
	# Les trois historiques gardent leur texte : les ecrans ne changent pas.
	eq(ObjectiveChecker.label(_obj(&"no_damage_taken")), "Gagner sans subir de degats",
		"libelle historique inchange")
	for key: StringName in ObjectiveChecker.KEYS:
		var o := _obj(key, SAMPLES.get(key, {}))
		var txt: String = ObjectiveChecker.label(o)
		ok(txt != "" and txt != o.description, "%s a un libelle genere" % key)
		# Chaque parametre numerique se LIT dans le libelle : sinon le joueur ne
		# sait pas ce qu on lui demande.
		for p in o.params:
			var v: Variant = o.params[p]
			if typeof(v) == TYPE_INT and String(p) != "window":
				ok(txt.contains(str(v)) or key == &"win_under_time",
					"%s : le parametre %s (%s) apparait dans \"%s\"" % [key, p, v, txt])
	# Genere, donc il suit les parametres.
	ok(ObjectiveChecker.label(_obj(&"same_card_casts", {"count": 20})).contains("20"),
		"le libelle suit le parametre")
	# Repli : un objectif mal ecrit affiche sa description plutot qu un texte faux.
	eq(ObjectiveChecker.label(_obj(&"same_card_casts", {})), "repli_same_card_casts",
		"objectif mal ecrit : repli sur la description")


# --- Coherence avec le niveau -------------------------------------------------

func _level_with(defs: Array, deck: Array) -> LevelDef:
	var lv := LevelDef.new()
	lv.id = &"lvl_test"
	var w := WaveDef.new()
	for d in defs:
		var e := WaveEntry.new()
		e.enemy = d
		e.count = 2
		w.entries.append(e)
	lv.waves.append(w)
	for c in deck:
		lv.exploration_deck.append(c)
	return lv


func _test_coherence_with_level() -> void:
	var sol := _enemy_def("sol")
	var vol := _enemy_def("vol")
	vol.flying = true
	var feu := _card("feu", [GameEnums.DamageTag.FIRE], ["damage_single"])
	var mur := _card("mur", [], ["build_wall"])
	var sans_vol := _level_with([sol], [feu])
	var avec_vol := _level_with([sol, vol], [feu, mur])

	var kf := _obj(&"kill_flying", {"count": 2})
	not_ok(ObjectiveChecker.impossible_reasons(kf, sans_vol).is_empty(),
		"kill_flying sans aucun volant : impossible")
	eq(ObjectiveChecker.impossible_reasons(kf, avec_vol).size(), 0,
		"kill_flying avec assez de volants : possible")
	not_ok(ObjectiveChecker.impossible_reasons(_obj(&"kill_flying", {"count": 3}), avec_vol).is_empty(),
		"kill_flying plus que de volants produits : impossible")
	# Un volant qui n arrive QUE par invocation reste atteignable.
	var invoc := _enemy_def("invoc")
	invoc.summon_def = vol
	eq(ObjectiveChecker.flying_capacity(_level_with([invoc], [])), -1,
		"un invocateur de volants n a pas de borne")

	var rv := _obj(&"boss_quick_after_revive", {"seconds": 5})
	not_ok(ObjectiveChecker.impossible_reasons(rv, avec_vol).is_empty(),
		"boss_quick_after_revive sans monstre qui se releve : impossible")
	var phenix := _enemy_def("phenix")
	phenix.revive_hp_pct = 40.0
	eq(ObjectiveChecker.impossible_reasons(rv, _level_with([phenix], [])).size(), 0,
		"boss_quick_after_revive avec un phenix : possible")

	var el := _obj(&"element_casts", {"element": "FROST", "count": 3})
	not_ok(ObjectiveChecker.impossible_reasons(el, avec_vol).is_empty(),
		"element_casts sans carte de givre au deck : impossible")

	not_ok(ObjectiveChecker.trivial_reasons(_obj(&"no_card_key", {"key": "build_wall"}), sans_vol).is_empty(),
		"sans mur quand le deck n a pas de mur : gratuit")
	eq(ObjectiveChecker.trivial_reasons(_obj(&"no_card_key", {"key": "build_wall"}), avec_vol).size(), 0,
		"sans mur quand le deck a un mur : ca mord")
	not_ok(ObjectiveChecker.trivial_reasons(_obj(&"never_hit_reflect"), avec_vol).is_empty(),
		"never_hit_reflect sans garde de renvoi : gratuit")
	not_ok(ObjectiveChecker.trivial_reasons(_obj(&"max_distinct_cast", {"count": 2}), avec_vol).is_empty(),
		"au plus 2 sorts avec un deck de 2 sorts : gratuit")


# --- Crochets dans le jeu -----------------------------------------------------

func _test_hook_revive_and_reflect() -> void:
	_fresh()
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	reset_gauge_with_survivable_mage()

	var d := _enemy_def("phenix_obj")
	d.revive_hp_pct = 40.0
	var boss: Enemy = bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	boss.take_damage(999.0, [])
	ok(boss.has_revived(), "le boss s est releve")
	eq(RunState.revived_still_standing(), 1, "Enemy._try_revive note le releve")
	RunState.advance_clock(1.0)
	# Le repit de releve suit le temps du monde : on le laisse s ecouler.
	for i in 90:
		bf.simulate(1.0 / 60.0)
	boss.take_damage(999.0, [])
	ok(boss.is_dead(), "le boss releve meurt pour de bon")
	eq(RunState.revive_kill_delays.size(), 1, "Enemy.kill note la mort du releve")
	eq(RunState.revived_still_standing(), 0, "plus aucun releve debout")

	var m := _enemy_def("miroir_obj")
	m.max_hp = 10000.0
	m.reflect_pct = 50.0
	var miroir: Enemy = bf.spawn_enemy(m, 300.0, 1.0, Vector2(300.0, 500.0))
	bf.damage_enemy(miroir, 10.0, null)
	eq(RunState.reflect_hits, 0, "un coup hors garde n est pas un renvoi")
	miroir.force_reflect_window(5.0)
	bf.damage_enemy(miroir, 10.0, null)
	eq(RunState.reflect_hits, 1, "Battlefield._reflect_to_mage note le renvoi")
	detach(bf)
	reset_gauge_at_normal_speed()


func _test_hook_enemy_depth() -> void:
	_fresh()
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	var d := _enemy_def("profond")
	var e: Enemy = bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, _y_at(0.4)))
	var boule := _enemy_def("boule")
	boule.projectile = true
	bf.spawn_enemy(boule, 300.0, 1.0, Vector2(300.0, _y_at(0.9)))
	RunState.note_enemy_depths(bf.enemies)
	feq(RunState.enemy_depth_max, 0.4, "profondeur du monstre le plus bas", 0.001)
	e.position.y = _y_at(0.7)
	RunState.note_enemy_depths(bf.enemies)
	e.position.y = _y_at(0.2)
	RunState.note_enemy_depths(bf.enemies)
	feq(RunState.enemy_depth_max, 0.7, "le maximum est retenu, pas la derniere position", 0.001)
	detach(bf)


## Les crochets de GameController : horloge, morts, victoire. Sur la vraie
## scene de jeu, parce que c est elle qui branche les signaux.
func _test_hooks_in_game_controller() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	reset_gauge_with_survivable_mage()

	# Un monstre immobile, deja bas : simulate() doit relever sa profondeur.
	var bas := _enemy_def("bas_gc")
	g.battlefield.spawn_enemy(bas, 200.0, 1.0, Vector2(200.0, _y_at(0.6)))
	var pas: float = 0.25
	g.simulate(pas)
	feq(RunState.run_time, pas, "simulate() avance l horloge en temps REEL", 0.0001)
	ok(RunState.enemy_depth_max >= 0.6 - 0.001,
		"simulate() releve la profondeur des monstres")

	var vol := _enemy_def("vol_gc")
	vol.flying = true
	vol.max_hp = 1.0
	var e: Enemy = g.battlefield.spawn_enemy(vol, 500.0, 1.0, Vector2(500.0, 600.0))
	g.battlefield.damage_enemy(e, 999.0, null)
	eq(RunState.kill_times.size(), 1, "une mort sur le terrain est notee")
	eq(RunState.flying_kills, 1, "et reconnue comme volante")

	# Une pause (choix de carte) n avance pas l horloge.
	RunState.offer_choices(3)
	var avant: float = RunState.run_time
	g.simulate(1.0)
	feq(RunState.run_time, avant, "l horloge ne tourne pas pendant un choix de carte")
	RunState.pending_offer.clear()

	SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT + 10)
	g.spawner.all_waves_cleared.emit()
	eq(RunState.victory_speed_percent, GameConfig.SPEED_START_PERCENT + 10,
		"la victoire photographie la vitesse")
	feq(RunState.victory_time, RunState.run_time, "et le temps")
	detach(g)
	reset_gauge_at_normal_speed()


func _test_reset_clears_counters() -> void:
	RunState.advance_clock(3.0)
	RunState.note_kill(_enemy_def("x"))
	RunState.note_reflect_hit()
	RunState.note_enemy_revived(7)
	RunState.enemy_depth_max = 0.8
	RunState.note_cast(_card("r", [GameEnums.DamageTag.FIRE], ["build_wall"]))
	RunState.note_victory()
	RunState.reset()
	eq(RunState.run_time, 0.0, "reset remet l horloge a zero")
	eq(RunState.kill_times.size(), 0, "reset efface les morts")
	eq(RunState.reflect_hits, 0, "reset efface les renvois")
	eq(RunState.revived_still_standing(), 0, "reset efface les releves")
	eq(RunState.enemy_depth_max, 0.0, "reset efface la profondeur")
	eq(RunState.casts_with_tag(GameEnums.DamageTag.FIRE), 0, "reset efface les tags")
	eq(RunState.casts_with_effect(&"build_wall"), 0, "reset efface les effets")
	eq(RunState.victory_time, -1.0, "reset efface la photo de victoire")
