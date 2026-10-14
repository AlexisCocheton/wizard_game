class_name MonsterFeedbackShowcase
extends RefCounted
## VITRINES DE LA VAGUE 10 (revue globale, chantier A4) : morts animees, retour de
## coup generique, images fixes qui vivent.
##
## Fenetre reelle seulement : tout ce code est derriere Fx.enabled(). Chaque
## planche CONTROLE en plus de capturer : un cadavre doit jouer `death`, un
## corps frappe doit revenir EXACTEMENT a sa taille et a sa teinte, une tour doit
## bouger. Les captures, elles, sont a LIRE (.testout/shot_*_mort_animee...).
##
## Appele par smoke_driver.gd ; tout passe par ses _shot / _fail / _laisser_jouer.

var _d: Node


func run(driver: Node) -> void:
	_d = driver
	await _morts()
	await _coups()
	await _totems()
	# Les morts de la vitrine ont rapporte de l XP : rien ne doit attendre un choix.
	RunState.pending_offer.clear()


func _partie() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	_d.add_child(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false          # APRES start_level (gotchas : start_level le remet)
	g.battlefield.clear_all()
	return g


func _def(id: String, sheet: String, hp: float, boss: bool = false) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.kind = GameEnums.EnemyKind.BOSS if boss else GameEnums.EnemyKind.NORMAL
	d.max_hp = hp
	d.base_speed = 0.0
	d.base_radius = 40.0
	d.power = 2
	# Aucune XP : une montee de niveau ouvrirait le choix de sort PAR-DESSUS la
	# planche (vu sur la premiere capture).
	d.base_xp = 0
	d.anim_key = StringName(sheet)
	return d


func _etiquette(bf: Node2D, at: Vector2, texte: String) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override(&"font_size", 20)
	l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
	l.position = at + Vector2(-150.0, 80.0)
	l.size = Vector2(300.0, 60.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bf.add_child(l)


func _grille(i: int) -> Vector2:
	return Vector2(220.0 + (i % 3) * 330.0, 330.0 + floorf(i / 3.0) * 330.0)


## 1) MORTS : chaque feuille qui a une pose de mort la joue ; les autres
## s affaissent sous l explosion ; le boss s effondre puis explose.
func _morts() -> void:
	var g: GameController = _partie()
	var bf: Battlefield = g.battlefield
	var feuilles: Array[String] = ["skeleton2", "golem_blue", "gorgon", "slime_big",
		"nightborne", "evilwizard", "pawn_red", "totem_tower"]
	var avant: int = Fx.corpse_count()
	var avec_pose: int = 0
	var i: int = 0
	for f in feuilles:
		var at: Vector2 = _grille(i)
		var e: Enemy = bf.spawn_enemy(_def("mort_" + f, f, 30.0), at.x, 1.0, at)
		_etiquette(bf, at, f + (" (pose)" if AnimCatalog.has_anim(StringName(f), "death") else " (affaisse)"))
		if AnimCatalog.has_anim(StringName(f), "death"):
			avec_pose += 1
		i += 1
		await _d.get_tree().process_frame
		if e != null:
			bf._hit(e, 99999.0, [])
	var boss_at: Vector2 = _grille(i)
	var b: Enemy = bf.spawn_enemy(_def("mort_boss", "juggernaut", 30.0, true), boss_at.x, 1.0, boss_at)
	_etiquette(bf, boss_at, "boss : pose PUIS explosion")
	await _d.get_tree().process_frame
	if b != null:
		bf._hit(b, 99999.0, [])
	if Fx.corpse_count() - avant < feuilles.size() + 1:
		_d._fail("vitrine morts : %d cadavres pour %d morts"
			% [Fx.corpse_count() - avant, feuilles.size() + 1])
	await _d._laisser_jouer(0.35)
	var en_pose: int = 0
	for n in bf.get_children():
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).animation == &"death":
			en_pose += 1
	if en_pose < avec_pose:
		_d._fail("vitrine morts : %d cadavres jouent `death`, %d attendus" % [en_pose, avec_pose])
	await _d._shot("mort_animee")
	# Les cadavres se liberent seuls : la vitrine n en laisse aucun derriere elle.
	await _d._laisser_jouer(Fx.DEATH_ANIM_MAX_S + Fx.DEATH_HOLD_S + Fx.DEATH_FADE_S + 0.5)
	if Fx.corpse_count() != avant:
		_d._fail("vitrine morts : %d cadavres restent a l ecran" % (Fx.corpse_count() - avant))
	g.queue_free()
	await _d.get_tree().process_frame


## 2) RETOUR DE COUP : les feuilles SANS pose de douleur s ecrasent, reculent et
## rougissent ; le golem (qui a `hurt`) joue la sienne. Puis le controle du
## defaut de teinte : deux coups a 60 ms d ecart ne laissent pas le monstre blanc.
func _coups() -> void:
	var g: GameController = _partie()
	var bf: Battlefield = g.battlefield
	var feuilles: Array[String] = ["pawn_red", "warrior_red", "lancer_yellow", "peacock",
		"beetle", "totem_tower", "archer_red", "golem_blue"]
	var cibles: Array[Enemy] = []
	var i: int = 0
	for f in feuilles:
		var at: Vector2 = _grille(i)
		var e: Enemy = bf.spawn_enemy(_def("coup_" + f, f, 99999.0), at.x, 1.0, at)
		_etiquette(bf, at, f + (" (sa pose)" if AnimCatalog.has_anim(StringName(f), "hurt") else " (generique)"))
		cibles.append(e)
		i += 1
	await _d._laisser_jouer(0.2)
	var repos: Dictionary = {}
	for e in cibles:
		var c: CanvasItem = Fx.body_of(e)
		repos[e] = [(c as Node2D).scale, c.modulate]
	for e in cibles:
		bf._hit(e, 1.0, [])
	await _d.get_tree().process_frame
	var generique: Enemy = cibles[0]
	var corps: Node2D = Fx.body_of(generique) as Node2D
	if corps.scale.is_equal_approx(repos[generique][0]) and corps.offset == Vector2.ZERO:
		_d._fail("vitrine coups : %s n a ni ecrasement ni recul" % feuilles[0])
	await _d._laisser_jouer(0.03)
	await _d._shot("retour_de_coup")
	# Deux coups rapproches, le defaut de teinte de la vague 10.
	await _d._laisser_jouer(0.6)
	for e in cibles:
		bf._hit(e, 1.0, [])
	await _d._laisser_jouer(0.06)
	for e in cibles:
		bf._hit(e, 1.0, [])
	await _d._laisser_jouer(0.8)
	for k in cibles.size():
		var e: Enemy = cibles[k]
		var c: CanvasItem = Fx.body_of(e)
		var n2: Node2D = c as Node2D
		if not n2.scale.is_equal_approx(repos[e][0]):
			_d._fail("vitrine coups : %s ne revient pas a sa taille (%s, %s attendu)"
				% [feuilles[k], n2.scale, repos[e][0]])
		var m: Color = c.modulate
		var base: Color = repos[e][1]
		if absf(m.r - base.r) > 0.02 or absf(m.g - base.g) > 0.02 or absf(m.b - base.b) > 0.02:
			_d._fail("vitrine coups : %s reste teinte apres deux coups rapproches (%s, %s attendu)"
				% [feuilles[k], m, base])
		var off: Vector2 = (c as AnimatedSprite2D).offset if c is AnimatedSprite2D \
			else ((c as Sprite2D).offset if c is Sprite2D else Vector2.ZERO)
		if off.length() > 0.01 or absf(n2.rotation) > 0.001:
			_d._fail("vitrine coups : %s reste decale ou penche" % feuilles[k])
	g.queue_free()
	await _d.get_tree().process_frame


## 3) IMAGES FIXES : les quatre tours du jeu flottent, leur anneau pulse, leur
## aura respire. Deux captures a une demi-periode d ecart montrent le mouvement.
func _totems() -> void:
	var g: GameController = _partie()
	var bf: Battlefield = g.battlefield
	var ids: Array[StringName] = [&"demon_circle", &"demon_circle_echo", &"totem_elder",
		&"totem_guardian"]
	var tours: Array[Enemy] = []
	for k in ids.size():
		var d: EnemyDef = ContentDB.enemies.get(ids[k])
		if d == null:
			_d._fail("vitrine totems : %s introuvable" % ids[k])
			continue
		if not AnimCatalog.is_static(d.anim_key):
			continue
		var at := Vector2(270.0 + (k % 2) * 540.0, 520.0 + floorf(k / 2.0) * 760.0)
		var e: Enemy = bf.spawn_enemy(d, at.x, 1.0, at)
		_etiquette(bf, at + Vector2(0.0, 120.0), String(ids[k]))
		tours.append(e)
	if tours.is_empty():
		_d._fail("vitrine totems : aucune tour a image fixe")
	await _d._laisser_jouer(0.3)
	var y0: Array[float] = []
	for e in tours:
		var s: Node2D = e.get_node_or_null("Static") as Node2D
		y0.append(s.position.y if s != null else 0.0)
		if e.get_node_or_null("IdleRune") == null:
			_d._fail("vitrine totems : %s n a pas d anneau de runes" % e.definition.id)
	await _d._shot("totem_anime_1")
	await _d._laisser_jouer(Fx.IDLE_PERIOD * 0.5)
	for k in tours.size():
		var s: Node2D = tours[k].get_node_or_null("Static") as Node2D
		if s == null or absf(s.position.y - y0[k]) < 1.0:
			_d._fail("vitrine totems : %s ne bouge pas" % tours[k].definition.id)
	await _d._shot("totem_anime_2")
	g.queue_free()
	await _d.get_tree().process_frame
