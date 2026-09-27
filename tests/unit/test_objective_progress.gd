extends TestCase
## SUIVI DES OBJECTIFS EN COMBAT : avancement, echec annonce, bandeau du HUD.
##
## La regle qui compte le plus ici : un objectif annonce PERDU ne doit jamais
## etre valide a la victoire. Un faux « rate » ferait lacher au joueur une
## etoile encore gagnable — pire que de ne rien afficher. Chaque cle qui peut
## echouer en cours de route est donc testee dans les deux sens : juste avant le
## fait qui la ruine (pas perdue), juste apres (perdue ET evaluate() faux).
##
## Les seuils viennent des parametres poses par le test, jamais d un reglage du
## contenu.

func get_suite_name() -> String:
	return "objective_progress"


## Cles qui peuvent etre PERDUES en cours de partie (fait irreversible).
const FAILABLE: Array[StringName] = [
	&"never_dropped_speed", &"no_legendary_used", &"no_damage_taken",
	&"no_card_key", &"no_card_tag", &"boss_quick_after_revive",
	&"never_hit_reflect", &"no_enemy_past", &"win_under_time",
	&"max_distinct_cast", &"no_passive",
]
## Cles qui ne sont JAMAIS perdues avant la fin : on peut toujours compter plus,
## ou elles se jugent sur l etat final.
const NEVER_FAILED: Array[StringName] = [
	&"same_card_casts", &"win_below_speed", &"multi_kill", &"element_casts",
	&"kill_flying",
]
## Cles qui ont un compte a afficher.
const COUNTED: Array[StringName] = [
	&"same_card_casts", &"multi_kill", &"element_casts", &"kill_flying",
	&"max_distinct_cast", &"win_under_time",
]


func run() -> void:
	_test_chaque_cle_est_classee()
	_test_rien_n_est_perdu_au_depart()
	_test_perdu_implique_echec_a_la_victoire()
	_test_les_objectifs_a_atteindre_ne_sont_jamais_perdus()
	_test_l_avancement_suit_les_compteurs()
	_test_le_libelle_court_est_plus_court()
	_test_le_signal_d_echec_part_une_seule_fois()
	_test_pas_d_echec_annonce_en_massacre()
	_test_le_bandeau_du_hud()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	RunState.reset()


func _obj(key: StringName) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName("p_%s" % key)
	o.check_key = key
	o.description = "repli_%s" % key
	# Les parametres de reference de la suite du moteur : valides par construction.
	var samples: Dictionary = load("res://tests/unit/test_objective_engine.gd").SAMPLES
	o.params = (samples[key] as Dictionary).duplicate()
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


func _p(o: ObjectiveDef, name: String) -> Variant:
	return o.params[name]


func _fresh() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()


## Une cle ajoutee au moteur doit etre rangee ici : sinon personne n a decide si
## le HUD peut l annoncer perdue, et le bandeau se tait ou ment sur elle.
func _test_chaque_cle_est_classee() -> void:
	for key: StringName in ObjectiveChecker.KEYS:
		ok(FAILABLE.has(key) != NEVER_FAILED.has(key),
			"%s est classee : perdable en route OU jamais perdue, pas les deux" % key)


func _test_rien_n_est_perdu_au_depart() -> void:
	_fresh()
	for key: StringName in ObjectiveChecker.KEYS:
		not_ok(ObjectiveChecker.is_failed(_obj(key)), "%s : rien n est perdu au depart" % key)


## Pour chaque cle perdable : le fait qui la ruine, avant et apres.
func _test_perdu_implique_echec_a_la_victoire() -> void:
	for key: StringName in FAILABLE:
		_fresh()
		var o: ObjectiveDef = _obj(key)
		match key:
			&"never_dropped_speed":
				RunState.note_speed_drop()
			&"no_legendary_used":
				RunState.used_legendary = true
			&"no_damage_taken":
				RunState.note_damage_taken()
			&"no_card_key":
				RunState.note_cast(_card("autre", [], ["damage_single"]))
				not_ok(ObjectiveChecker.is_failed(o), "no_card_key : un autre effet ne ruine rien")
				RunState.note_cast(_card("interdit", [], [_p(o, "key")]))
			&"no_card_tag":
				var tag: int = ObjectiveChecker.tag_from_name(_p(o, "tag"))
				var autre: int = GameEnums.DamageTag.FROST if tag != GameEnums.DamageTag.FROST \
					else GameEnums.DamageTag.FIRE
				RunState.note_cast(_card("autre", [autre], ["damage_single"]))
				not_ok(ObjectiveChecker.is_failed(o), "no_card_tag : un autre tag ne ruine rien")
				RunState.note_cast(_card("interdit", [tag], ["damage_single"]))
			&"boss_quick_after_revive":
				var s: float = float(_p(o, "seconds"))
				RunState.note_enemy_revived(7)
				RunState.advance_clock(s * 0.5)
				not_ok(ObjectiveChecker.is_failed(o),
					"boss_quick_after_revive : releve depuis moins que le delai, encore jouable")
				RunState.advance_clock(s * 0.5)
			&"never_hit_reflect":
				RunState.note_reflect_hit()
			&"no_enemy_past":
				var r: float = float(_p(o, "ratio"))
				RunState.enemy_depth_max = r
				not_ok(ObjectiveChecker.is_failed(o), "no_enemy_past : pile au ratio, pas perdu")
				RunState.enemy_depth_max = minf(1.0, r + 0.01)
			&"win_under_time":
				var s2: float = float(_p(o, "seconds"))
				RunState.advance_clock(s2 * 0.99)
				not_ok(ObjectiveChecker.is_failed(o), "win_under_time : juste avant le chrono")
				RunState.advance_clock(s2 * 0.02)
			&"max_distinct_cast":
				var n: int = int(_p(o, "count"))
				for i in n:
					RunState.note_cast(_card("sort_%d" % i))
				not_ok(ObjectiveChecker.is_failed(o), "max_distinct_cast : pile a la limite")
				RunState.note_cast(_card("sort_de_trop"))
			&"no_passive":
				var pc := SpellCard.new()
				pc.id = &"passif_test"
				pc.is_passive = true
				RunState.equipped_passives.append(pc)
		ok(ObjectiveChecker.is_failed(o), "%s : perdu apres le fait qui le ruine" % key)
		# La victoire arrive ensuite, dans les meilleures conditions possibles.
		SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
		RunState.note_victory()
		not_ok(ObjectiveChecker.evaluate(o),
			"%s : annonce perdu, il n est PAS valide a la victoire" % key)


## Beaucoup de choses se passent — coups, sorts, morts, temps — et aucune de ces
## cles ne se declare perdue : on peut toujours compter plus, ou elles se jugent
## a la fin.
func _test_les_objectifs_a_atteindre_ne_sont_jamais_perdus() -> void:
	_fresh()
	RunState.note_damage_taken()
	RunState.note_speed_drop()
	for i in 20:
		RunState.note_cast(_card("s%d" % (i % 5), [GameEnums.DamageTag.FIRE], ["damage_single"]))
	RunState.advance_clock(600.0)
	for key: StringName in NEVER_FAILED:
		not_ok(ObjectiveChecker.is_failed(_obj(key)), "%s : jamais annonce perdu en route" % key)


func _test_l_avancement_suit_les_compteurs() -> void:
	_fresh()
	for key: StringName in ObjectiveChecker.KEYS:
		var p: Dictionary = ObjectiveChecker.progress(_obj(key))
		eq(not p.is_empty(), COUNTED.has(key),
			"%s : un compte a afficher seulement si l objectif se compte" % key)

	var meme: ObjectiveDef = _obj(&"same_card_casts")
	var a := _card("a")
	for i in 3:
		RunState.note_cast(a)
	var p1: Dictionary = ObjectiveChecker.progress(meme)
	eq(int(p1["current"]), 3, "meme sort : trois lancers comptes")
	eq(int(p1["target"]), int(_p(meme, "count")), "meme sort : la cible est le parametre")

	var elem: ObjectiveDef = _obj(&"element_casts")
	var tag: int = ObjectiveChecker.tag_from_name(_p(elem, "element"))
	RunState.note_cast(_card("e1", [tag]))
	RunState.note_cast(_card("e2", [tag]))
	eq(int(ObjectiveChecker.progress(elem)["current"]), 2, "element : deux sorts de l element")

	var vol: ObjectiveDef = _obj(&"kill_flying")
	var volant := EnemyDef.new()
	volant.flying = true
	RunState.note_kill(volant)
	RunState.note_kill(EnemyDef.new())
	eq(int(ObjectiveChecker.progress(vol)["current"]), 1, "volants : seul le volant compte")

	var chrono: ObjectiveDef = _obj(&"win_under_time")
	RunState.advance_clock(12.5)
	var pc: Dictionary = ObjectiveChecker.progress(chrono)
	ok(bool(pc["time"]), "chrono : les valeurs sont des secondes")
	feq(float(pc["current"]), RunState.run_time, "chrono : le temps de combat ecoule")


func _test_le_libelle_court_est_plus_court() -> void:
	for key: StringName in ObjectiveChecker.KEYS:
		var o: ObjectiveDef = _obj(key)
		var court: String = ObjectiveChecker.short_label(o)
		ok(court != "" and court != o.description, "%s : un libelle court genere" % key)
		ok(court.length() < ObjectiveChecker.label(o).length(),
			"%s : '%s' plus court que le libelle complet" % [key, court])


func _niveau(objs: Array) -> LevelDef:
	var lvl := LevelDef.new()
	lvl.id = &"lvl_test_objectifs"
	for o in objs:
		lvl.objectives.append(o)
	return lvl


var _echecs: Array[StringName] = []


func _note_echec(id: StringName) -> void:
	_echecs.append(id)


func _test_le_signal_d_echec_part_une_seule_fois() -> void:
	_fresh()
	var sans_degats: ObjectiveDef = _obj(&"no_damage_taken")
	var meme: ObjectiveDef = _obj(&"same_card_casts")
	RunState.current_level_def = _niveau([sans_degats, meme])
	RunState.mode = GameEnums.Mode.EXPLORATION
	_echecs.clear()
	if not RunState.objective_failed.is_connected(_note_echec):
		RunState.objective_failed.connect(_note_echec)
	RunState.advance_clock(0.1)
	eq(_echecs.size(), 0, "rien de perdu : aucun signal")
	RunState.note_damage_taken()
	RunState.advance_clock(0.1)
	RunState.advance_clock(0.1)
	eq(_echecs.size(), 1, "un seul signal, pas un par image")
	if _echecs.size() > 0:
		eq(_echecs[0], sans_degats.id, "et c est le bon objectif")
	ok(RunState.is_objective_failed(sans_degats.id), "RunState le sait perdu")
	not_ok(RunState.is_objective_failed(meme.id), "l autre objectif ne l est pas")
	RunState.reset()
	not_ok(RunState.is_objective_failed(sans_degats.id), "une nouvelle partie repart de zero")
	RunState.objective_failed.disconnect(_note_echec)


func _test_pas_d_echec_annonce_en_massacre() -> void:
	_fresh()
	RunState.current_level_def = _niveau([_obj(&"no_damage_taken")])
	RunState.mode = GameEnums.Mode.MASSACRE
	_echecs.clear()
	RunState.objective_failed.connect(_note_echec)
	RunState.note_damage_taken()
	RunState.advance_clock(0.1)
	eq(_echecs.size(), 0, "le Massacre n a pas d objectifs : rien a annoncer")
	RunState.objective_failed.disconnect(_note_echec)
	RunState.mode = GameEnums.Mode.EXPLORATION


## LE BANDEAU : une ligne pour ce qui se compte, rien pour une interdiction
## encore tenue, une ligne « rate » des qu elle est perdue.
func _test_le_bandeau_du_hud() -> void:
	_fresh()
	SaveData.reset_profile()
	var meme: ObjectiveDef = _obj(&"same_card_casts")
	var sans_degats: ObjectiveDef = _obj(&"no_damage_taken")
	RunState.current_level_def = _niveau([meme, sans_degats])
	RunState.mode = GameEnums.Mode.EXPLORATION
	var hud: Node = load("res://scenes/hud/HUD.tscn").instantiate()
	attach(hud)
	var lignes: Dictionary = hud.get("_obj_lines")
	eq(lignes.size(), 2, "une ligne par objectif non acquis")
	var l_meme: Label = lignes.get(meme)
	var l_deg: Label = lignes.get(sans_degats)
	if l_meme == null or l_deg == null:
		ok(false, "les lignes du bandeau existent")
		detach(hud)
		return
	hud.call("_refresh_objective_strip")
	ok(l_meme.visible, "l objectif qui se compte s affiche des le depart")
	ok(l_meme.text.ends_with("0/%d" % int(_p(meme, "count"))),
		"il montre son compte : '%s'" % l_meme.text)
	not_ok(l_deg.visible, "une interdiction encore tenue n affiche rien")
	var a := _card("a")
	RunState.note_cast(a)
	RunState.note_cast(a)
	hud.call("_refresh_objective_strip")
	ok(l_meme.text.ends_with("2/%d" % int(_p(meme, "count"))),
		"le compte suit les lancers : '%s'" % l_meme.text)
	RunState.note_damage_taken()
	RunState.watch_objectives()
	ok(l_deg.visible, "perdue : la ligne apparait")
	ok(l_deg.text.ends_with("rate"), "et dit que c est rate : '%s'" % l_deg.text)
	ok(l_deg.get_theme_color(&"font_color") != l_meme.get_theme_color(&"font_color"),
		"dans une autre couleur que la progression")
	eq(l_meme.get_theme_font_size(&"font_size"), UiTheme.FONT_SMALL,
		"a la plus petite police du theme, pas en dessous")
	detach(hud)
