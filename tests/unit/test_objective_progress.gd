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
	&"no_card", &"no_hit_from",
]
## Cles qui ne sont JAMAIS perdues avant la fin : on peut toujours compter plus,
## ou elles se jugent sur l etat final.
const NEVER_FAILED: Array[StringName] = [
	&"same_card_casts", &"win_below_speed", &"multi_kill", &"element_casts",
	&"kill_flying",
	&"card_casts", &"win_above_speed", &"kill_type_one_cast", &"kill_type_with_card",
	&"hit_from", &"enemy_travel",
]
## Cles qui ont un compte a afficher.
const COUNTED: Array[StringName] = [
	&"same_card_casts", &"multi_kill", &"element_casts", &"kill_flying",
	&"max_distinct_cast", &"win_under_time",
	&"card_casts", &"kill_type_one_cast", &"kill_type_with_card", &"hit_from",
	&"enemy_travel",
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
	_test_le_bandeau_ne_cache_rien_et_se_lit()
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
			&"no_card":
				RunState.note_cast(_card("une_autre_carte", [], ["damage_single"]))
				not_ok(ObjectiveChecker.is_failed(o), "no_card : une autre carte ne ruine rien")
				RunState.note_cast(_card(String(_p(o, "card")), [], ["damage_single"]))
			&"no_hit_from":
				var autre_espece := EnemyDef.new()
				autre_espece.id = &"une_autre_espece"
				RunState.note_damage_taken(autre_espece)
				not_ok(ObjectiveChecker.is_failed(o), "no_hit_from : une autre espece ne ruine rien")
				RunState.note_damage_taken(ContentDB.enemies.get(StringName(_p(o, "enemy"))))
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
	# Les DEUX modes sans fin : l Infini (ancien Massacre par niveau) et le
	# nouveau Massacre.
	for m in [GameEnums.Mode.INFINITE, GameEnums.Mode.MASSACRE]:
		RunState.mode = m
		_echecs.clear()
		RunState.objective_failed.connect(_note_echec)
		RunState.note_damage_taken()
		RunState.advance_clock(0.1)
		eq(_echecs.size(), 0, "le mode %s n a pas d objectifs : rien a annoncer"
			% GameEnums.mode_name(m))
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


## OU EST LE BANDEAU. Il etait sous le bouton pause, en plein dans la bande ou
## naissent les monstres : le texte cachait le debut de chaque vague. On pose des
## objectifs, on force chaque ligne a son texte le plus long (compte plein ou
## « rate ») et on verifie que la plaque ne recouvre ni la bande d apparition, ni
## la main, ni la jauge, ni le rail des passifs, ni la tour, ni la pioche, ni la
## barre d incantation, et qu elle tient dans l ecran. Deux passes :
##   - chaque niveau LIVRE, avec ses trois objectifs et son fond peint ;
##   - TOUTES les lignes que le moteur sait ecrire (chaque cle, chaque effet
##     interdisable, chaque element), trois par trois comme dans un niveau : un
##     objectif ajoute demain ne doit pas pouvoir deborder sur la tour.
##
## La bande d apparition se deduit des constantes de spawn et du catalogue : de
## la ligne d apparition moins la plus grande demi-silhouette, jusqu au plus bas
## point ou un monstre peut naitre (entree par le cote comprise) plus sa
## demi-silhouette. Aucun y ecrit en dur.
##
## LE CONTRASTE, sur le fond peint du niveau, sous la plaque : les tons sombre et
## clair (10e et 90e centiles) de la zone, recouverts de la plaque, doivent
## laisser chaque couleur de texte a 4,5:1 au moins (plancher du projet, en dur).
func _test_le_bandeau_ne_cache_rien_et_se_lit() -> void:
	_fresh()
	SaveData.reset_profile()
	RunState.mode = GameEnums.Mode.EXPLORATION
	var niveaux: Array = ContentDB.levels.values()
	niveaux.sort_custom(func(a: LevelDef, b: LevelDef) -> bool:
		return String(a.id) < String(b.id))
	if niveaux.is_empty():
		ok(false, "des niveaux livres a controler")
		return
	# Un niveau quelconque pour que le HUD construise son bandeau des l entree.
	RunState.current_level_def = niveaux[0]
	# Le rail des passifs a son plein : autant de passifs que d emplacements, aux
	# seuils livres.
	var passifs: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive and passifs.size() < GameConfig.PASSIVE_SLOTS:
			passifs.append(c)
	for p: SpellCard in passifs:
		RunState.equipped_passives.append(p)
	var hud: Node = load("res://scenes/hud/HUD.tscn").instantiate()
	attach(hud)
	hud.call("_build_passive_rail")

	var interdits: Dictionary = _zones_du_hud(hud)
	var bande: Vector2 = _bande_d_apparition()
	ok(bande.y > GameConfig.SPAWN_LINE_Y, "(la bande d apparition a une epaisseur : %.0f..%.0f)"
		% [bande.x, bande.y])
	var plaque: StyleBoxFlat = null
	var actes_vus: Dictionary = {}
	var actes_livres: Dictionary = {}
	var controles: int = 0
	for lvl: LevelDef in niveaux:
		actes_livres[lvl.act] = true
		var r: Rect2 = _bandeau_de(hud, lvl, bande, interdits)
		if r.size == Vector2.ZERO:
			continue
		controles += 1
		var panneau: Control = hud.get("_obj_panel")
		if plaque == null:
			plaque = panneau.get_theme_stylebox(&"panel") as StyleBoxFlat
		# Contraste sur le fond de CE niveau, dans l emprise de CE bandeau.
		if lvl.backdrop != "" and plaque != null:
			var tons: Array[Color] = _tons_sous(lvl.backdrop, r)
			ok(tons.size() == 2, "%s : le fond %s se lit sur le disque" % [lvl.id, lvl.backdrop])
			for ton in tons:
				var fond: Color = ton.lerp(Color(plaque.bg_color, 1.0), plaque.bg_color.a)
				for encre: Color in [UiTheme.TEXT, UiTheme.GOLD, hud.OBJ_ECHEC]:
					var ratio: float = _ratio(encre, fond)
					ok(ratio >= 4.5, "%s (acte %d) : texte %s a %.2f:1 sur %s sous la plaque"
						% [lvl.id, lvl.act, encre.to_html(false), ratio, fond.to_html(false)])
			actes_vus[lvl.act] = true
	ok(controles > 0, "au moins un niveau livre a un bandeau")
	ok(plaque != null and plaque.bg_color.a < 1.0,
		"la plaque laisse deviner le terrain (alpha < 1)")
	for a in actes_livres:
		ok(actes_vus.has(a), "le contraste est mesure sur le fond de l acte %d" % a)

	# Toutes les lignes possibles, trois par trois.
	var toutes: Array[ObjectiveDef] = _tous_les_objectifs_ecrivables()
	var i: int = 0
	while i < toutes.size():
		var lvl := _niveau(toutes.slice(i, i + 3))
		lvl.id = StringName("lvl_toutes_les_lignes_%d" % i)
		_bandeau_de(hud, lvl, bande, interdits)
		i += 3

	for p: SpellCard in passifs:
		RunState.equipped_passives.erase(p)
	detach(hud)
	SaveData.reset_profile()


## Construit le bandeau de `lvl`, force chaque ligne a son texte le plus long,
## verifie l emprise et la rend (Rect2 vide si le niveau n a pas de bandeau).
func _bandeau_de(hud: Node, lvl: LevelDef, bande: Vector2, interdits: Dictionary) -> Rect2:
	RunState.current_level_def = lvl
	hud.call("_build_objective_strip")
	var lignes: Dictionary = hud.get("_obj_lines")
	if lignes.is_empty():
		return Rect2()
	var textes: Array[String] = []
	for o: ObjectiveDef in lignes:
		var l: Label = lignes[o]
		var plein: Dictionary = ObjectiveChecker.progress(o).duplicate()
		if not plein.is_empty():
			plein["current"] = plein["target"]
		var t_rate: String = hud.objective_line_text(o, true, {})
		var t_compte: String = hud.objective_line_text(o, false, plein)
		l.text = t_rate if t_rate.length() >= t_compte.length() else t_compte
		l.visible = true
		textes.append(l.text)
	var panneau: Control = hud.get("_obj_panel")
	panneau.visible = true
	var r: Rect2 = hud.objective_strip_rect()
	var ecran := Rect2(0.0, 0.0, GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	ok(r.size.x > 0.0 and r.size.y > 0.0, "%s : le bandeau a une emprise" % lvl.id)
	ok(r.position.y > bande.y,
		"%s : le bandeau (haut a y=%.0f) est sous la bande d apparition (bas a y=%.0f)"
		% [lvl.id, r.position.y, bande.y])
	ok(ecran.encloses(r), "%s : le bandeau tient dans l ecran (%s)" % [lvl.id, r])
	for nom: String in interdits:
		var z: Rect2 = interdits[nom]
		not_ok(r.intersects(z), "%s : le bandeau %s %s ne recouvre pas %s %s"
			% [lvl.id, textes, r, nom, z])
	return r


## Un objectif par cle, plus un par effet interdisable, un par tag interdisable
## et un par element compte : tout ce que short_label() sait ecrire.
func _tous_les_objectifs_ecrivables() -> Array[ObjectiveDef]:
	var out: Array[ObjectiveDef] = []
	for key: StringName in ObjectiveChecker.KEYS:
		out.append(_obj(key))
	for k: StringName in ObjectiveChecker.EFFECT_PHRASES:
		var o: ObjectiveDef = _obj(&"no_card_key")
		o.id = StringName("p_no_card_key_%s" % k)
		o.params["key"] = String(k)
		out.append(o)
	# Interdiction : tout tag est permis (ralentissement et invocation compris).
	for nom: String in GameEnums.DamageTag.keys():
		var sans: ObjectiveDef = _obj(&"no_card_tag")
		sans.id = StringName("p_no_card_tag_%s" % nom)
		sans.params["tag"] = nom
		out.append(sans)
	# Compte : les seuls elements.
	for t: int in GameEnums.ELEMENTS:
		var nom: String = String(GameEnums.DamageTag.find_key(t))
		var avec: ObjectiveDef = _obj(&"element_casts")
		avec.id = StringName("p_element_casts_%s" % nom)
		avec.params["element"] = nom
		out.append(avec)
	for o in out:
		ok(ObjectiveChecker.validate(o).is_empty(), "(objectif ecrivable %s valide)" % o.id)
	return out


## Les zones que le bandeau ne doit JAMAIS recouvrir, lues sur les noeuds du HUD
## (et sur la tour pour la seule qui n est pas au HUD).
func _zones_du_hud(hud: Node) -> Dictionary:
	var z: Dictionary = {}
	var main: Control = hud.get("_hand")
	z["la main"] = main.get_global_rect()
	# La jauge est TOURNEE de -90 deg : son rectangle non tourne mentirait.
	var jauge: Control = hud.get("_enemy_bar")
	z["la jauge"] = jauge.get_global_transform() * Rect2(Vector2.ZERO, jauge.size)
	var pioche: Control = hud.get("_draw_label")
	z["la pioche"] = pioche.get_global_rect()
	var incant: Control = hud.get("_cast_bar")
	z["la barre d incantation"] = incant.get_global_rect()
	var rail := Rect2()
	var noeuds: Array = hud.get("_passive_nodes")
	for n: Control in noeuds:
		var nr := Rect2(n.global_position, n.size.max(n.get_combined_minimum_size()))
		rail = nr if rail.size == Vector2.ZERO else rail.merge(nr)
	ok(noeuds.size() > 0, "(le rail des passifs est garni pour le controle)")
	z["le rail des passifs"] = rail
	var tour: Rect2 = BattleBackdrop.tower_rect()
	ok(tour.size != Vector2.ZERO, "(la tour du mage a une emprise)")
	z["la tour du mage"] = tour
	return z


## (haut, bas) de la bande ou un monstre du catalogue peut apparaitre, silhouette
## affichee comprise. Meme calcul de naissance que le jeu (Battlefield.v3_spawn_y).
func _bande_d_apparition() -> Vector2:
	var bf := Battlefield.new()
	var haut: float = GameConfig.SPAWN_LINE_Y
	var bas: float = GameConfig.SPAWN_LINE_Y
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null:
			continue
		var demi: float = d.base_radius * Enemy.VISUAL_FACTOR * maxf(d.sprite_scale, 0.1)
		var y: float = bf.v3_spawn_y(d)
		haut = minf(haut, y - demi)
		bas = maxf(bas, y + demi)
	bf.free()
	return Vector2(haut, bas)


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


## Luminance relative WCAG (Color.get_luminance() ne lineairise pas).
func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _ratio(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Tons sombre et clair (10e et 90e centiles de luminance) du fond peint dans
## l emprise `r` de l ecran. Le fond est peint a la taille de l ecran ; on
## rapporte quand meme les coordonnees a la taille reelle de l image.
func _tons_sous(backdrop: String, r: Rect2) -> Array[Color]:
	var out: Array[Color] = []
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/backdrops/%s.png" % backdrop))
	if img == null or img.is_empty():
		return out
	if img.is_compressed():
		img.decompress()
	var sx: float = float(img.get_width()) / GameConfig.BATTLEFIELD_WIDTH
	var sy: float = float(img.get_height()) / GameConfig.BATTLEFIELD_HEIGHT
	var px: Array = []
	for y in range(int(r.position.y * sy), int(r.end.y * sy), 4):
		for x in range(int(r.position.x * sx), int(r.end.x * sx), 4):
			var c: Color = img.get_pixel(clampi(x, 0, img.get_width() - 1),
				clampi(y, 0, img.get_height() - 1))
			px.append([_lum(c), c])
	if px.is_empty():
		return out
	px.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	out.append(px[int(px.size() * 0.10)][1])
	out.append(px[int(px.size() * 0.90)][1])
	return out
