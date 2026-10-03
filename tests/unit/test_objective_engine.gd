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
	&"element_casts": {"element": "ICE", "count": 10},
	&"kill_flying": {"count": 8},
	&"boss_quick_after_revive": {"seconds": 5},
	&"never_hit_reflect": {},
	&"no_enemy_past": {"ratio": 0.5},
	&"win_under_time": {"seconds": 180},
	&"max_distinct_cast": {"count": 4},
	&"no_passive": {},
	# Ids du CATALOGUE : validate() les confronte a ContentDB.
	&"card_casts": {"card": "piercing_arrow", "count": 6},
	&"no_card": {"card": "fireball"},
	&"win_above_speed": {"pct": 300},
	&"kill_type_one_cast": {"enemy": "imp_archer", "count": 4},
	&"kill_type_with_card": {"enemy": "imp_archer", "card": "piercing_arrow", "count": 3},
	&"no_hit_from": {"enemy": "imp_archer"},
	&"hit_from": {"enemy": "sleepy_fox"},
	&"enemy_travel": {"enemy": "sleepy_fox", "distance": 3000.0},
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
	# Cles liees aux cartes et aux monstres.
	_test_killing_effects_are_real_effects()
	_test_card_casts()
	_test_no_card()
	_test_win_above_speed()
	_test_cast_ids()
	_test_kill_type_one_cast()
	_test_kill_type_one_cast_zone_later()
	_test_kill_type_with_card()
	_test_summons_kill_for_their_card()
	_test_passive_blast_is_nobodys()
	_test_hits_from_enemy()
	_test_enemy_travel()
	_test_enemy_travel_counts_detours_not_pushes()
	_test_new_keys_validation()
	_test_new_keys_labels()
	_test_new_keys_coherence_with_level()
	_test_new_counters_reset()
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
	RunState.note_cast(_card("givre", [GameEnums.DamageTag.ICE], ["damage_single"]))
	ok(ObjectiveChecker.evaluate(o), "no_card_tag : aucun sort de feu, reussi")
	RunState.note_cast(_card("feu", [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.SLOW],
		["damage_single"]))
	not_ok(ObjectiveChecker.evaluate(o), "no_card_tag : un sort de feu, echoue")


func _test_element_casts() -> void:
	_fresh()
	var n: int = 3
	var o := _obj(&"element_casts", {"element": "ICE", "count": n})
	var givre := _card("givre", [GameEnums.DamageTag.ICE], ["damage_single"])
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
		"Gagner sans sort d arcanique", "elision devant une voyelle")
	eq(ObjectiveChecker.label(_obj(&"element_casts", {"element": "ICE", "count": 4})),
		"Lancer 4 sorts de glace", "element de la vague 8, sans elision")
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

	var el := _obj(&"element_casts", {"element": "ICE", "count": 3})
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


# =============================================================================
# CLES LIEES AUX CARTES ET AUX MONSTRES
#
# Chaque cle se joue par le VRAI chemin des evenements : un sort part par
# EffectRegistry.cast(), un monstre meurt sous Battlefield._hit(), un coup
# arrive au mage par Battlefield.mage_hit et GameController. Les especes sont
# des EnemyDef neufs qui portent l id du catalogue : c est l id que les
# objectifs comptent, et un monstre immobile et fragile ne parasite pas la
# mesure avec son propre comportement.

func _catalog_card(id: String) -> SpellCard:
	return ContentDB.cards.get(StringName(id))


func _fragile(id: String) -> EnemyDef:
	var d := _enemy_def(id)
	d.max_hp = 1.0
	return d


func _arena() -> Battlefield:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _cast_at(bf: Battlefield, card: SpellCard, at: Vector2, target: Object = null) -> CastContext:
	var ctx := CastContext.make(bf, card)
	ctx.target_position = at
	ctx.direction = Vector2.UP
	ctx.target_enemy = target
	EffectRegistry.cast(card, ctx)
	return ctx


func _run(bf: Battlefield, seconds: float) -> void:
	var pas: float = 1.0 / 30.0
	for i in int(ceil(seconds / pas)):
		bf.simulate(pas)


func _test_killing_effects_are_real_effects() -> void:
	for k: StringName in ObjectiveChecker.KILLING_EFFECTS:
		ok(EffectRegistry.has_key(k), "la cle qui tue %s existe dans EffectRegistry" % k)


func _test_card_casts() -> void:
	_fresh()
	var bf := _arena()
	var n: int = 3
	var o := _obj(&"card_casts", {"card": "piercing_arrow", "count": n})
	var fleche: SpellCard = _catalog_card("piercing_arrow")
	var autre: SpellCard = _catalog_card("arcane_bolt")
	for i in n - 1:
		_cast_at(bf, fleche, Vector2(540.0, 600.0))
	for i in n + 1:
		_cast_at(bf, autre, Vector2(540.0, 600.0))
	not_ok(ObjectiveChecker.evaluate(o), "card_casts : n-1 lancers de LA carte echouent, "
		+ "meme si un autre sort a ete lance plus de n fois")
	eq(int(ObjectiveChecker.progress(o)["current"]), n - 1, "card_casts : le bandeau compte n-1")
	_cast_at(bf, fleche, Vector2(540.0, 600.0))
	ok(ObjectiveChecker.evaluate(o), "card_casts : n lancers de la carte reussissent")
	detach(bf)


func _test_no_card() -> void:
	_fresh()
	var bf := _arena()
	var o := _obj(&"no_card", {"card": "fireball"})
	_cast_at(bf, _catalog_card("ember_pool"), Vector2(540.0, 600.0))
	ok(ObjectiveChecker.evaluate(o), "no_card : un autre sort de feu ne compte pas")
	not_ok(ObjectiveChecker.is_failed(o), "no_card : rien de perdu")
	_cast_at(bf, _catalog_card("fireball"), Vector2(540.0, 600.0))
	not_ok(ObjectiveChecker.evaluate(o), "no_card : la carte lancee une fois, echoue")
	ok(ObjectiveChecker.is_failed(o), "no_card : perdu des le lancer")
	detach(bf)


func _test_win_above_speed() -> void:
	var pct: int = 300
	var o := _obj(&"win_above_speed", {"pct": pct})
	_fresh()
	SpeedGauge.set_speed_percent(pct + 1)
	RunState.note_victory()
	SpeedGauge.set_speed_percent(pct - 50)
	ok(ObjectiveChecker.evaluate(o), "win_above_speed : au-dessus a la victoire, reussi")
	_fresh()
	SpeedGauge.set_speed_percent(pct)
	RunState.note_victory()
	SpeedGauge.set_speed_percent(pct + 50)
	not_ok(ObjectiveChecker.evaluate(o), "win_above_speed : pile au seuil, echoue (strict)")


## Chaque passage dans EffectRegistry.cast() est un lancer neuf, et la source
## est refermee a la sortie : un coup porte ensuite n appartient a personne.
func _test_cast_ids() -> void:
	_fresh()
	var bf := _arena()
	var c1: CastContext = _cast_at(bf, _catalog_card("spark"), Vector2(540.0, 600.0))
	var c2: CastContext = _cast_at(bf, _catalog_card("spark"), Vector2(540.0, 600.0))
	ok(c1.cast_id > 0, "le lancer recoit un numero")
	ok(c2.cast_id > c1.cast_id, "deux lancers, deux numeros")
	ok(RunState.damage_source.is_empty(), "hors lancer, aucune source de degats")
	detach(bf)


func _test_kill_type_one_cast() -> void:
	_fresh()
	var bf := _arena()
	var n: int = 3
	var o := _obj(&"kill_type_one_cast", {"enemy": "imp_archer", "count": n})
	var feu: SpellCard = _catalog_card("fireball")
	var centre := Vector2(540.0, 700.0)
	var ecart: float = feu.effects[0].radius / float(n + 2)
	# n-1 lutins ET un renard dans la meme boule de feu.
	for i in n - 1:
		bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, centre + Vector2(ecart * i, 0.0))
	bf.spawn_enemy(_fragile("sleepy_fox"), 0.0, 1.0, centre + Vector2(0.0, ecart))
	_cast_at(bf, feu, centre)
	_run(bf, 1.0)
	eq(bf.alive_count(), 0, "(la boule de feu a tout tue)")
	eq(RunState.best_kills_in_one_cast(&"imp_archer"), n - 1, "les lutins du lancer sont comptes")
	eq(RunState.best_kills_in_one_cast(&"sleepy_fox"), 1, "le renard compte pour SON espece")
	not_ok(ObjectiveChecker.evaluate(o), "kill_type_one_cast : n-1 lutins d un sort echouent")
	# Le n-ieme lutin tombe sous un AUTRE lancer : le record ne bouge pas.
	bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, centre)
	_cast_at(bf, feu, centre)
	_run(bf, 1.0)
	not_ok(ObjectiveChecker.evaluate(o),
		"kill_type_one_cast : n lutins en deux lancers ne font pas n d un seul")
	for i in n:
		bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, centre + Vector2(ecart * i, 0.0))
	_cast_at(bf, feu, centre)
	_run(bf, 1.0)
	ok(ObjectiveChecker.evaluate(o), "kill_type_one_cast : n lutins d un seul sort reussissent")
	eq(int(ObjectiveChecker.progress(o)["current"]), n, "le bandeau montre le record")
	detach(bf)


## LA REGLE DES DEGATS SUR LA DUREE : la zone emporte le numero de son lancer,
## et ce qui y meurt APRES la fin du lancer lui appartient.
func _test_kill_type_one_cast_zone_later() -> void:
	_fresh()
	var bf := _arena()
	var braises: SpellCard = _catalog_card("ember_pool")
	var centre := Vector2(540.0, 700.0)
	_cast_at(bf, braises, centre)
	_run(bf, 0.2)
	ok(RunState.damage_source.is_empty(), "(le lancer est referme avant les morts)")
	bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, centre)
	bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, centre + Vector2(20.0, 0.0))
	_run(bf, 1.0)
	eq(bf.alive_count(), 0, "(la zone a tue les deux)")
	eq(RunState.best_kills_in_one_cast(&"imp_archer"), 2,
		"deux morts dans la zone, apres le lancer : le meme lancer")
	eq(RunState.kills_with_card(&"ember_pool", &"imp_archer"), 2, "et la carte de la zone")
	# Un coup sans source ne credite personne.
	var e: Enemy = bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, Vector2(200.0, 400.0))
	bf.damage_enemy(e, 99.0, null)
	eq(RunState.best_kills_in_one_cast(&"imp_archer"), 2, "une mort sans lancer ne compte pour aucun")
	detach(bf)


func _test_kill_type_with_card() -> void:
	_fresh()
	var bf := _arena()
	var n: int = 2
	var o := _obj(&"kill_type_with_card", {"enemy": "imp_archer", "card": "spark", "count": n})
	var etincelle: SpellCard = _catalog_card("spark")
	var bolt: SpellCard = _catalog_card("arcane_bolt")
	var ou := Vector2(540.0, 600.0)
	var a: Enemy = bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, ou)
	_cast_at(bf, bolt, ou, a)
	var f: Enemy = bf.spawn_enemy(_fragile("sleepy_fox"), 0.0, 1.0, ou)
	_cast_at(bf, etincelle, ou, f)
	for i in n - 1:
		var b: Enemy = bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, ou)
		_cast_at(bf, etincelle, ou, b)
	eq(bf.alive_count(), 0, "(chaque cible est morte)")
	not_ok(ObjectiveChecker.evaluate(o), "kill_type_with_card : un lutin tue par une autre carte "
		+ "et un renard tue par la bonne ne comptent pas")
	eq(int(ObjectiveChecker.progress(o)["current"]), n - 1, "le bandeau compte n-1")
	var c: Enemy = bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, ou)
	_cast_at(bf, etincelle, ou, c)
	ok(ObjectiveChecker.evaluate(o), "kill_type_with_card : n lutins par la carte reussissent")
	detach(bf)


## Un allie invoque frappe au nom de sa carte ; un allie d autel au nom de
## l autel ; un allie de PASSIF au nom de personne.
func _test_summons_kill_for_their_card() -> void:
	_fresh()
	var bf := _arena()
	_cast_at(bf, _catalog_card("mirror_apprentice"), Vector2(540.0, 1300.0))
	bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, Vector2(540.0, 600.0))
	_run(bf, 2.0)
	eq(bf.alive_count(), 0, "(l allie a tue le lutin)")
	eq(RunState.kills_with_card(&"mirror_apprentice", &"imp_archer"), 1,
		"la mort par l allie est creditee a la carte qui l invoque")
	detach(bf)

	_fresh()
	var bf2 := _arena()
	var autel: SpellCard = _catalog_card("terrain_altar")
	var tous_les: float = float(autel.effects[0].get_param(&"summon_every", 0.0))
	ok(tous_les > 0.0, "(l autel est un generateur)")
	_cast_at(bf2, autel, Vector2(300.0, 900.0))
	bf2.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, Vector2(540.0, 600.0))
	_run(bf2, tous_les * 1.5)
	eq(bf2.alive_count(), 0, "(un allie d autel a tue le lutin)")
	eq(RunState.kills_with_card(&"terrain_altar", &"imp_archer"), 1,
		"la mort par un allie d autel est creditee a l autel")
	detach(bf2)

	_fresh()
	var bf3 := _arena()
	bf3.spawn_ally(5.0, 50.0)
	bf3.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, Vector2(540.0, 600.0))
	_run(bf3, 2.0)
	eq(bf3.alive_count(), 0, "(l allie de passif a tue le lutin)")
	eq(RunState.best_kills_in_one_cast(&"imp_archer"), 0, "un allie de passif n est pas un lancer")
	detach(bf3)


## L explosion de Combustion n est pas le sort : la victime qu elle fait n est
## creditee a aucune carte.
func _test_passive_blast_is_nobodys() -> void:
	_fresh()
	var passif: SpellCard = _catalog_card("pass_fireboom")
	RunState.equipped_passives.append(passif)
	SpeedGauge.set_speed_percent(maxi(passif.speed_threshold, GameConfig.SPEED_START_PERCENT))
	ok(RunState.passive_magnitude(&"passive_death_blast") > 0.0, "(Combustion est active)")
	var bf := _arena()
	var ou := Vector2(540.0, 600.0)
	var a: Enemy = bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, ou)
	bf.spawn_enemy(_fragile("imp_archer"), 0.0, 1.0, ou + Vector2(30.0, 0.0))
	_cast_at(bf, _catalog_card("spark"), ou, a)
	eq(bf.alive_count(), 0, "(l explosion a tue le voisin)")
	eq(RunState.kills_with_card(&"spark", &"imp_archer"), 1,
		"seule la cible du sort est creditee, pas la victime de l explosion")
	detach(bf)
	RunState.equipped_passives.clear()
	reset_gauge_at_normal_speed()


## COUPS RECUS, sur la vraie scene : contact, fleche, et boule de poison
## imputee a l espece qui l invoque.
func _test_hits_from_enemy() -> void:
	_fresh()
	var g: GameController = load("res://scenes/game/Game.tscn").instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.battlefield.clear_all()
	reset_gauge_with_survivable_mage()
	var bf: Battlefield = g.battlefield
	var sans_lutin := _obj(&"no_hit_from", {"enemy": "imp_archer"})
	var par_renard := _obj(&"hit_from", {"enemy": "sleepy_fox"})
	ok(ObjectiveChecker.evaluate(sans_lutin), "no_hit_from : aucun coup, reussi")
	not_ok(ObjectiveChecker.evaluate(par_renard), "hit_from : aucun coup du renard, echoue")

	var renard := _enemy_def("sleepy_fox")
	renard.base_speed = 200.0
	bf.spawn_enemy(renard, 0.0, 1.0, Vector2(540.0, GameConfig.MAGE_LINE_Y - 2.0))
	_run(bf, 0.5)
	ok(ObjectiveChecker.evaluate(par_renard), "hit_from : touche par le renard, reussi")
	eq(int(ObjectiveChecker.progress(par_renard)["current"]), 1, "le bandeau le dit")
	ok(ObjectiveChecker.evaluate(sans_lutin), "no_hit_from : un coup d une AUTRE espece ne compte pas")
	not_ok(ObjectiveChecker.is_failed(sans_lutin), "no_hit_from : rien de perdu")

	var archer := _enemy_def("imp_archer")
	archer.shoot_interval = 0.2
	bf.spawn_enemy(archer, 0.0, 1.0, Vector2(300.0, GameConfig.MAGE_LINE_Y * 0.5))
	for i in 300:
		bf.simulate(1.0 / 30.0)
		if RunState.hits_from_enemy(&"imp_archer") > 0:
			break
	ok(RunState.hits_from_enemy(&"imp_archer") > 0, "(la fleche du lutin est arrivee)")
	not_ok(ObjectiveChecker.evaluate(sans_lutin), "no_hit_from : une FLECHE du lutin, echoue")
	ok(ObjectiveChecker.is_failed(sans_lutin), "no_hit_from : perdu des la fleche")

	# La boule de poison touche au nom du feu follet qui l invoque.
	var sans_follet := _obj(&"no_hit_from", {"enemy": "wisp"})
	var follet: EnemyDef = ContentDB.enemies.get(&"wisp")
	ok(follet != null and follet.summon_def != null and follet.summon_def.projectile,
		"(le feu follet invoque un projectile)")
	ok(ObjectiveChecker.evaluate(sans_follet), "(aucun coup du feu follet)")
	var boule := _enemy_def(String(follet.summon_def.id))
	boule.projectile = true
	boule.base_speed = 200.0
	bf.spawn_enemy(boule, 0.0, 1.0, Vector2(700.0, GameConfig.MAGE_LINE_Y - 2.0))
	_run(bf, 0.5)
	not_ok(ObjectiveChecker.evaluate(sans_follet), "no_hit_from : sa boule touche AU NOM du lanceur")
	detach(g)
	reset_gauge_at_normal_speed()


## Fait marcher `e` jusqu a `px` de chemin (ou sa mort). Rend son chemin.
func _walk(bf: Battlefield, e: Enemy, px: float) -> float:
	for i in 3000:
		if not is_instance_valid(e) or e.is_dead():
			break
		if float(e.get_meta(RunState.TRAVEL_META, 0.0)) >= px:
			break
		bf.simulate(1.0 / 30.0)
	return float(e.get_meta(RunState.TRAVEL_META, 0.0)) if is_instance_valid(e) else -1.0


func _test_enemy_travel() -> void:
	_fresh()
	var bf := _arena()
	var d: float = ObjectiveChecker.terrain_length() * 0.5
	var o := _obj(&"enemy_travel", {"enemy": "sleepy_fox", "distance": d})
	var quiconque := _obj(&"enemy_travel", {"distance": d})
	var lutins := _obj(&"enemy_travel", {"enemy": "imp_archer", "distance": d})
	var renard := _enemy_def("sleepy_fox")
	renard.base_speed = 150.0

	var e1: Enemy = bf.spawn_enemy(renard, 0.0, 1.0, Vector2(540.0, GameConfig.SPAWN_LINE_Y))
	var depart_y: float = e1.position.y
	var fait: float = _walk(bf, e1, d * 0.5)
	feq(fait, e1.position.y - depart_y, "une descente droite : chemin = descente", 1.0)
	bf.damage_enemy(e1, 9999.0, null)
	not_ok(ObjectiveChecker.evaluate(o), "enemy_travel : tue a mi-chemin, echoue")
	feq(RunState.travel_record_of(&"sleepy_fox"), fait, "le chemin est retenu a la mort", 0.001)

	var e2: Enemy = bf.spawn_enemy(renard, 0.0, 1.0, Vector2(540.0, GameConfig.SPAWN_LINE_Y))
	_walk(bf, e2, d)
	ok(is_instance_valid(e2) and not e2.is_dead() and e2.position.y < GameConfig.MAGE_LINE_Y,
		"(le renard a fait la distance sans atteindre le mage)")
	RunState.note_enemy_travel_live(bf.enemies)
	not_ok(ObjectiveChecker.evaluate(o), "enemy_travel : VIVANT, il ne valide pas encore")
	ok(int(ObjectiveChecker.progress(o)["current"]) >= 100, "mais le bandeau le montre a portee")
	bf.damage_enemy(e2, 9999.0, null)
	ok(ObjectiveChecker.evaluate(o), "enemy_travel : tue apres la distance, reussi")
	ok(ObjectiveChecker.evaluate(quiconque), "enemy_travel sans espece : n importe lequel suffit")
	not_ok(ObjectiveChecker.evaluate(lutins), "enemy_travel : le chemin d une autre espece ne compte pas")
	detach(bf)


## CHEMIN : un detour compte, une repousse non, une remontee (Volte-face) oui.
func _test_enemy_travel_counts_detours_not_pushes() -> void:
	_fresh()
	var bf := _arena()
	var renard := _enemy_def("sleepy_fox")
	renard.base_speed = 150.0
	var e: Enemy = bf.spawn_enemy(renard, 0.0, 1.0, Vector2(540.0, GameConfig.SPAWN_LINE_Y + 400.0))
	bf.simulate(1.0 / 30.0)
	var avant: float = float(e.get_meta(RunState.TRAVEL_META, 0.0))
	var y_avant: float = e.position.y
	bf.knockback_from(e.position + Vector2(0.0, 10.0), 100.0, 150.0)
	ok(e.position.y < y_avant, "(la repousse l a deplace)")
	feq(float(e.get_meta(RunState.TRAVEL_META, 0.0)), avant, "une repousse n allonge pas le chemin")

	bf.apply_reverse(1.0)
	var y_rev: float = e.position.y
	var c_rev: float = float(e.get_meta(RunState.TRAVEL_META, 0.0))
	_run(bf, 0.5)
	ok(e.position.y < y_rev, "(Volte-face : il remonte)")
	ok(float(e.get_meta(RunState.TRAVEL_META, 0.0)) > c_rev, "la remontee est du chemin")
	_run(bf, 1.0)

	# Un mur en travers : il faut le contourner.
	var y0: float = e.position.y
	var c0: float = float(e.get_meta(RunState.TRAVEL_META, 0.0))
	var demi: float = 200.0
	var mur_y: float = y0 + 300.0
	bf.spawn_wall(Vector2(e.position.x, mur_y), demi, 120.0)
	for i in 3000:
		bf.simulate(1.0 / 30.0)
		if not is_instance_valid(e) or e.position.y > mur_y + 80.0:
			break
	ok(is_instance_valid(e) and e.position.y > mur_y, "(il a passe le mur)")
	var chemin: float = float(e.get_meta(RunState.TRAVEL_META, 0.0)) - c0
	ok(chemin > (e.position.y - y0) + demi * 0.5,
		"le detour autour du mur compte : chemin %.0f pour une descente de %.0f"
		% [chemin, e.position.y - y0])
	detach(bf)


func _test_new_keys_validation() -> void:
	var cas: Array = [
		[&"card_casts", {"card": "carte_inventee", "count": 3}, "carte inconnue"],
		[&"card_casts", {"card": "pass_fireboom", "count": 3}, "un passif ne se lance pas"],
		[&"card_casts", {"card": "fireball", "count": 0}, "zero lancer"],
		[&"card_casts", {"card": 3, "count": 3}, "carte en entier"],
		[&"no_card", {}, "carte manquante"],
		[&"win_above_speed", {"pct": 100}, "au plancher : gratuit"],
		[&"win_above_speed", {"pct": GameConfig.SPEED_MAX_PERCENT}, "au maximum : impossible"],
		[&"kill_type_one_cast", {"enemy": "imp_archer", "count": 1}, "un seul monstre d un sort"],
		[&"kill_type_one_cast", {"enemy": "monstre_invente", "count": 3}, "monstre inconnu"],
		[&"kill_type_one_cast", {"enemy": "poison_ball", "count": 3}, "un projectile"],
		[&"kill_type_with_card", {"enemy": "imp_archer", "count": 3}, "carte manquante"],
		[&"no_hit_from", {"enemy": "imp_archer", "card": "fireball"}, "parametre en trop"],
		[&"hit_from", {}, "monstre manquant"],
		[&"enemy_travel", {"enemy": "sleepy_fox"}, "distance manquante"],
		[&"enemy_travel", {"distance": 0.0}, "distance nulle"],
		[&"enemy_travel", {"distance": (ObjectiveChecker.MAX_TRAVEL_LENGTHS + 1.0)
			* ObjectiveChecker.terrain_length()}, "distance au-dela du plafond"],
		[&"enemy_travel", {"enemy": "poison_ball", "distance": 100.0}, "espece projectile"],
	]
	for c in cas:
		not_ok(ObjectiveChecker.validate(_obj(c[0], c[1])).is_empty(),
			"validate refuse : %s (%s)" % [c[2], c[0]])
	eq(ObjectiveChecker.validate(_obj(&"enemy_travel", {"distance": 100.0})).size(), 0,
		"enemy_travel : l espece est facultative")
	eq(ObjectiveChecker.validate(_obj(&"card_casts", {&"card": &"fireball", &"count": 2})).size(), 0,
		"ids en StringName acceptes")


func _test_new_keys_labels() -> void:
	# Les exemples du co-auteur, mot pour mot a la syntaxe du moteur pres.
	eq(ObjectiveChecker.label(_obj(&"card_casts", {"card": "piercing_arrow", "count": 6})),
		"Lancer 6 fois %s" % _catalog_card("piercing_arrow").display_name, "jouer Fleche 6 fois")
	eq(ObjectiveChecker.label(_obj(&"no_card", {"card": "fireball"})),
		"Gagner sans lancer %s" % _catalog_card("fireball").display_name, "sans Boule de feu")
	eq(ObjectiveChecker.label(_obj(&"win_above_speed", {"pct": 300})),
		"Gagner avec plus de 300 % de vitesse", "plus de 300 %")
	var lutin: String = (ContentDB.enemies.get(&"imp_archer") as EnemyDef).display_name
	eq(ObjectiveChecker.label(_obj(&"kill_type_one_cast", {"enemy": "imp_archer", "count": 4})),
		"%s : en tuer 4 d un seul sort" % lutin, "4 d une seule attaque")
	eq(ObjectiveChecker.label(_obj(&"no_hit_from", {"enemy": "imp_archer"})),
		"%s : gagner sans en etre touche" % lutin, "ne pas etre touche par le lutin")
	var l: float = ObjectiveChecker.terrain_length()
	eq(ObjectiveChecker.label(_obj(&"enemy_travel", {"distance": 3.0 * l})),
		"Faire marcher un monstre sur 3 longueurs de terrain", "en longueurs de terrain")
	eq(ObjectiveChecker.label(_obj(&"enemy_travel", {"distance": 1.5 * l})),
		"Faire marcher un monstre sur 1,5 longueur de terrain", "singulier sous 2")


func _test_new_keys_coherence_with_level() -> void:
	var lutin: EnemyDef = ContentDB.enemies.get(&"imp_archer")
	var bolt: SpellCard = _catalog_card("arcane_bolt")
	var nappe: SpellCard = _catalog_card("tidal_pool")
	var lv := _level_with([lutin], [bolt, nappe])
	# _level_with pose deux exemplaires par espece.
	var par_niveau: int = 2 * maxi(1, lutin.swarm_count)

	not_ok(ObjectiveChecker.impossible_reasons(
		_obj(&"card_casts", {"card": "fireball", "count": 3}), lv).is_empty(),
		"card_casts d une carte absente du deck : impossible")
	eq(ObjectiveChecker.impossible_reasons(
		_obj(&"card_casts", {"card": "arcane_bolt", "count": 3}), lv).size(), 0,
		"card_casts d une carte du deck : possible")
	if "levelup_cards" in lv:
		# Le pool de montee de niveau (chantier progression) rend la carte jouable.
		var pool: Array = lv.get("levelup_cards")
		pool.append(_catalog_card("fireball"))
		eq(ObjectiveChecker.impossible_reasons(
			_obj(&"card_casts", {"card": "fireball", "count": 3}), lv).size(), 0,
			"card_casts d une carte du pool de montee de niveau : possible")
		pool.clear()
	not_ok(ObjectiveChecker.trivial_reasons(_obj(&"no_card", {"card": "fireball"}), lv).is_empty(),
		"no_card d une carte injouable : gratuit")
	eq(ObjectiveChecker.trivial_reasons(_obj(&"no_card", {"card": "arcane_bolt"}), lv).size(), 0,
		"no_card d une carte du deck : ca mord")

	not_ok(ObjectiveChecker.impossible_reasons(
		_obj(&"kill_type_one_cast", {"enemy": "sleepy_fox", "count": 2}), lv).is_empty(),
		"kill_type_one_cast d une espece absente : impossible")
	eq(ObjectiveChecker.impossible_reasons(
		_obj(&"kill_type_one_cast", {"enemy": "imp_archer", "count": par_niveau}), lv).size(), 0,
		"autant que le niveau en produit : possible")
	not_ok(ObjectiveChecker.impossible_reasons(
		_obj(&"kill_type_one_cast", {"enemy": "imp_archer", "count": par_niveau + 1}), lv).is_empty(),
		"plus que le niveau n en produit : impossible")
	# Une espece qui n arrive QUE par division reste atteignable, et comptee.
	var gelee: EnemyDef = ContentDB.enemies.get(&"jelly")
	ok(gelee != null and gelee.split_into != null, "(la gelee se divise)")
	if gelee != null and gelee.split_into != null:
		var moyenne: EnemyDef = gelee.split_into
		var lv_gelee := _level_with([gelee], [bolt])
		ok(ObjectiveChecker.type_capacity(lv_gelee, moyenne.id) >= 2 * gelee.split_count,
			"les divisions comptent dans la capacite")
		eq(ObjectiveChecker.impossible_reasons(_obj(&"kill_type_one_cast",
			{"enemy": String(moyenne.id), "count": 2}), lv_gelee).size(), 0,
			"une espece nee d une division est presente")

	not_ok(ObjectiveChecker.impossible_reasons(_obj(&"kill_type_with_card",
		{"enemy": "imp_archer", "card": "tidal_pool", "count": 1}), lv).is_empty(),
		"kill_type_with_card avec une carte qui ne blesse pas : impossible")
	eq(ObjectiveChecker.impossible_reasons(_obj(&"kill_type_with_card",
		{"enemy": "imp_archer", "card": "arcane_bolt", "count": 1}), lv).size(), 0,
		"kill_type_with_card avec un sort de degats du deck : possible")
	var insensible := _enemy_def("insensible")
	insensible.resistances = {GameEnums.DamageTag.FIRE: 0.0}
	not_ok(ObjectiveChecker.card_can_kill(_catalog_card("fireball"), insensible),
		"une carte de feu ne tue pas un monstre insensible au feu")
	ok(ObjectiveChecker.card_can_kill(_catalog_card("spark"), insensible),
		"une carte d un autre element, si")
	ok(ObjectiveChecker.card_can_kill(_catalog_card("mirror_apprentice"), insensible),
		"un allie frappe sans element : il tue toujours")

	# Qui peut toucher le mage.
	var immobile := _enemy_def("immobile")
	not_ok(ObjectiveChecker.can_hurt_mage(immobile), "immobile et sans arme : ne touche jamais")
	immobile.shoot_interval = 2.0
	ok(ObjectiveChecker.can_hurt_mage(immobile), "immobile mais qui tire : touche")
	var canonnier := _enemy_def("canonnier")
	canonnier.base_speed = 60.0
	canonnier.keeps_distance_at = 400.0
	not_ok(ObjectiveChecker.can_hurt_mage(canonnier), "s arrete a distance sans tirer : ne touche pas")
	ok(ObjectiveChecker.can_hurt_mage(ContentDB.enemies.get(&"wisp")),
		"le feu follet touche par sa boule")
	not_ok(ObjectiveChecker.trivial_reasons(_obj(&"no_hit_from", {"enemy": "sleepy_fox"}), lv).is_empty(),
		"no_hit_from d une espece absente : gratuit")
	eq(ObjectiveChecker.trivial_reasons(_obj(&"no_hit_from", {"enemy": "imp_archer"}), lv).size(), 0,
		"no_hit_from d une espece presente qui tire : ca mord")
	not_ok(ObjectiveChecker.impossible_reasons(_obj(&"hit_from", {"enemy": "sleepy_fox"}), lv).is_empty(),
		"hit_from d une espece absente : impossible")
	eq(ObjectiveChecker.impossible_reasons(_obj(&"hit_from", {"enemy": "imp_archer"}), lv).size(), 0,
		"hit_from d une espece presente : possible")
	not_ok(ObjectiveChecker.impossible_reasons(
		_obj(&"enemy_travel", {"enemy": "sleepy_fox", "distance": 100.0}), lv).is_empty(),
		"enemy_travel d une espece absente : impossible")
	eq(ObjectiveChecker.impossible_reasons(_obj(&"enemy_travel", {"distance": 100.0}), lv).size(), 0,
		"enemy_travel sans espece : possible")


func _test_new_counters_reset() -> void:
	RunState.open_cast_source(_catalog_card("spark"))
	RunState.note_kill_by_source(_enemy_def("imp_archer"))
	RunState.note_damage_taken(_enemy_def("imp_archer"))
	RunState.note_travel_at_death(_enemy_def("imp_archer"), 500.0)
	RunState.reset()
	ok(RunState.damage_source.is_empty(), "reset referme la source")
	eq(RunState.best_kills_in_one_cast(&"imp_archer"), 0, "reset efface les morts par lancer")
	eq(RunState.kills_with_card(&"spark", &"imp_archer"), 0, "reset efface les morts par carte")
	eq(RunState.hits_from_enemy(&"imp_archer"), 0, "reset efface les coups par espece")
	eq(RunState.travel_record_of(&""), 0.0, "reset efface les chemins")
