extends Node
## SCENE TEMPORAIRE DU CHANTIER B2 (a supprimer avant le commit final) : captures
## en fenetre reelle portrait des briefings de trois niveaux et d une vague ou
## joue une mecanique neuve (l echeance de Chronos, la garde levee). Les PNG vont
## dans le dossier donne par CAPTURE_DIR.

var _dir: String = ""


func _ready() -> void:
	SaveData.persistence_enabled = false
	_dir = OS.get_environment("CAPTURE_DIR")
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_dir, nom])
		print("[CAPTURE] ", nom)


func _attendre(s: float) -> void:
	var t: float = 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	SaveData.reset_profile()
	for id in [&"lvl_17", &"lvl_01", &"lvl_09", &"lvl_20"]:
		SaveData.unlock_level(id)
		SceneRouter.payload = {"level_id": id, "mode": GameEnums.Mode.EXPLORATION}
		var ecran: Control = load(SceneRouter.LOADING).instantiate()
		add_child(ecran)
		await _attendre(0.4)
		await _shot("briefing_%s" % id)
		var zone: ScrollContainer = ecran.find_child("Scroll", true, false) as ScrollContainer
		if zone != null:
			zone.scroll_vertical = 700
			await _attendre(0.2)
			await _shot("briefing_%s_bas" % id)
		ecran.queue_free()
		await _attendre(0.1)
	SceneRouter.payload = {}
	# Une vague : Chronos plante sous son echeance, a cote du Gardien d ossements
	# garde levee et du Gardien dont l armure s est refermee.
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	add_child(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.battlefield.clear_all()
	SpeedGauge.set_speed_percent(200)
	var bf: Battlefield = g.battlefield
	var chronos: Enemy = bf.spawn_enemy(ContentDB.enemies.get(&"chronos"), 540.0, 0.6, Vector2(540.0, 700.0))
	var os_: Enemy = bf.spawn_enemy(ContentDB.enemies.get(&"bonewarden"), 250.0, 1.0, Vector2(250.0, 1100.0))
	var gardien: Enemy = bf.spawn_enemy(ContentDB.enemies.get(&"warden"), 830.0, 1.0, Vector2(830.0, 1100.0))
	# Le Gardien prend un coup (armure brisee), puis on le laisse au calme.
	bf._hit(gardien, 5.0, [GameEnums.DamageTag.ARCANE])
	var t: float = 0.0
	while t < 9.4:
		SpeedGauge.set_speed_percent(100)
		bf.simulate(1.0 / 60.0)
		t += 1.0 / 60.0
		if os_ != null and is_instance_valid(os_):
			os_.position = Vector2(250.0, 1100.0)
		if gardien != null and is_instance_valid(gardien):
			gardien.position = Vector2(830.0, 1100.0)
	if os_ != null and is_instance_valid(os_) and not os_.guard_up():
		os_._open_reflect(2.5)
	# Quelques images encore : les legendes (garde, echeance) se rafraichissent
	# dans advance().
	for _i in 4:
		SpeedGauge.set_speed_percent(100)
		bf.simulate(1.0 / 60.0)
		if os_ != null and is_instance_valid(os_):
			os_.position = Vector2(250.0, 1100.0)
	SpeedGauge.set_speed_percent(200)
	await _attendre(0.5)
	print("[CAPTURE] echeance ouverte : ", chronos.deadline_open(), " garde : ", os_.guard_up(),
		" bouclier du Gardien : ", gardien.has_shield())
	await _shot("vague_echeance_garde")
