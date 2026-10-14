class_name ScreensW10Check
extends RefCounted
## VAGUE 10, chantier ECRANS : le briefing refait, le bilan de fin et le sceau
## d element, dans une vraie fenetre (captures) et au doigt.
##
##   - le briefing du niveau le plus charge (deux boss) DEBORDE et defile au
##     doigt (TouchScrollCheck), COMMENCER reste dans la fenetre ; captures du
##     haut et du bas ;
##   - les ecrans de defaite et de victoire posent le bilan des degats et le
##     conseil ; captures ;
##   - une planche de cartes en main et en detail montre le contour du sceau.
##
## Fichier a part du pilote (une ligne d appel) : plusieurs chantiers touchent
## smoke_driver.gd en parallele.

const NIVEAU_CHARGE: StringName = &"lvl_02"


static func run(driver: Node) -> void:
	SaveData.reset_profile()
	await _briefing(driver)
	await _bilan(driver)
	if DisplayServer.get_name() != "headless":
		await _sceaux(driver)
	SaveData.reset_profile()
	SceneRouter.payload = {}
	print("[SMOKE] vague 10 : briefing, bilan, sceau")


static func _briefing(driver: Node) -> void:
	SceneRouter.payload = {"level_id": NIVEAU_CHARGE, "mode": GameEnums.Mode.EXPLORATION}
	var ecran: Control = (load(SceneRouter.LOADING) as PackedScene).instantiate()
	driver.add_child(ecran)
	await _frames(driver)
	await driver._shot("w10_briefing_haut")
	var n: int = await TouchScrollCheck.check_screen(driver, ecran, "briefing")
	if n == 0:
		driver.call("_fail", "briefing de %s : rien ne deborde ou rien ne suit le doigt" % NIVEAU_CHARGE)
	var depart: Button = ecran.get_node_or_null("%StartButton")
	var fenetre: Rect2 = Rect2(Vector2.ZERO, ecran.get_viewport_rect().size)
	if depart == null or not fenetre.encloses(depart.get_global_rect()):
		driver.call("_fail", "briefing : COMMENCER sort de l ecran")
	var zone: ScrollContainer = ecran.find_child("Scroll", true, false)
	if zone != null:
		zone.scroll_vertical = int(zone.get_v_scroll_bar().max_value)
		await _frames(driver)
		await driver._shot("w10_briefing_bas")
	ecran.queue_free()
	await _frames(driver)


## Un bilan plausible : une fleche qui harcele, un contact de gnome, un regard
## de gorgone, et la boule d un Planogo rangee sous son lanceur.
static func _bilan(driver: Node) -> void:
	RunState.reset()
	RunState.mode = GameEnums.Mode.EXPLORATION
	var lv: LevelDef = ContentDB.levels.get(NIVEAU_CHARGE)
	RunState.current_level_def = lv
	RunState.build_deck_from_list(lv.exploration_deck)
	var follet: EnemyDef = ContentDB.enemies.get(&"wisp")
	var coups: Array = [[&"imp_archer", 6, 5], [&"gnome", 9, 2], [&"gorgon_queen", 40, 1]]
	if follet != null and follet.summon_def != null:
		coups.append([follet.summon_def.id, 7, 2])
	for c in coups:
		var d: EnemyDef = ContentDB.enemies.get(c[0])
		for i in int(c[2]):
			RunState.note_damage_taken(d, int(c[1]))
	for chemin in [SceneRouter.DEFEAT, SceneRouter.VICTORY]:
		SceneRouter.payload = {"level_id": NIVEAU_CHARGE, "waves": 4}
		var ecran: Control = (load(chemin) as PackedScene).instantiate()
		driver.add_child(ecran)
		await _frames(driver)
		var lignes: int = 0
		for n in ecran.find_children("*", "HBoxContainer", true, false):
			if n.has_meta(&"damage"):
				lignes += 1
		if lignes == 0:
			driver.call("_fail", "%s : aucun bilan des degats" % chemin.get_file())
		if ecran.find_child("AdviceHeading", true, false) == null:
			driver.call("_fail", "%s : aucun conseil" % chemin.get_file())
		await driver._shot("w10_bilan_" + chemin.get_file().get_basename().to_lower())
		ecran.queue_free()
		await _frames(driver)
	RunState.reset()


## Le contour noir du sceau, en main et en detail, sur le fond sombre du combat.
static func _sceaux(driver: Node) -> void:
	var fond := ColorRect.new()
	fond.color = UiTheme.BG
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	driver.add_child(fond)
	var planche := HFlowContainer.new()
	planche.position = Vector2(40.0, 80.0)
	planche.size = Vector2(1000.0, 1700.0)
	planche.add_theme_constant_override(&"h_separation", 24)
	planche.add_theme_constant_override(&"v_separation", 30)
	fond.add_child(planche)
	var ids: Array = []
	for id in ContentDB.cards.keys():
		ids.append(id)
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var elements: Dictionary = {}
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c.is_passive or elements.has(c.spell_type()):
			continue
		elements[c.spell_type()] = true
		var main := CardView.new()
		main.setup_hand(c, 150.0, 260.0)
		planche.add_child(main)
	var detail := CardView.new()
	detail.setup_detail(ContentDB.cards.get(&"fireball"), 300.0, 440.0)
	planche.add_child(detail)
	await _frames(driver)
	await driver._shot("w10_sceaux")
	fond.queue_free()
	await _frames(driver)


static func _frames(driver: Node) -> void:
	await driver.get_tree().process_frame
	await driver.get_tree().process_frame
