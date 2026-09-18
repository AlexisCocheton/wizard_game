extends Node
## Apercu VISUEL de la main de cartes et du panneau de pause, en fenetre reelle.
##
## Pourquoi un apercu separe de l etage `visual` : le harnais juge la lisibilite
## sur des captures, et l etage `visual` traverse une partie complete. Quand la
## partie ne demarre pas (regression ailleurs dans le jeu), on perd le seul moyen
## de juger l interface. Cet apercu ne depend que de l UI : il instancie la main a
## 8 cartes et le panneau de pause, capture, et sort.
##
## Il n est pas dans le harnais : c est un outil de jugement, pas un test. Ce qui
## doit etre verrouille l est par tests/unit/test_card_view.gd.

const OUT := "res://.testout"


func _ready() -> void:
	SaveData.persistence_enabled = false
	await get_tree().process_frame
	await _apercu_main()
	await _apercu_pause()
	get_tree().quit(0)


## La main a 8 cartes, le cas le plus dense : c est la que la lisibilite casse.
func _apercu_main() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.theme = UiTheme.make()
	add_child(racine)

	var fond := ColorRect.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.color = Color(0.22, 0.42, 0.20)   # vert du champ de bataille
	racine.add_child(fond)

	var cartes: Array[SpellCard] = _huit_cartes()
	var n: int = cartes.size()
	var largeur: float = clampf((1052.0 - 6.0 * (n - 1)) / n, 118.0, 200.0)

	# PRESET_CENTER ecraserait position/size : on pose la boite a la main, comme
	# dans le HUD reel (anchors bas, offsets fixes).
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 6)
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ligne.offset_left = 20.0
	ligne.offset_right = -20.0
	ligne.offset_top = -320.0
	ligne.offset_bottom = -80.0
	racine.add_child(ligne)
	for c in cartes:
		var cv := CardView.new()
		cv.setup_hand(c, largeur, 230.0)
		ligne.add_child(cv)

	# Une carte de detail a cote, pour comparer les deux presentations.
	var det := CardView.new()
	det.setup_detail(cartes[0], 300.0, 440.0, 30, 22)
	det.position = Vector2(390, 700)
	det.size = Vector2(300, 440)
	racine.add_child(det)

	var t := UiTheme.label_hud("MAIN A 8 CARTES (largeur %d px)" % int(largeur),
		34, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(0, 180)
	t.size = Vector2(1080, 50)
	racine.add_child(t)

	await _capture("ui_01_main")
	racine.queue_free()
	await get_tree().process_frame


func _apercu_pause() -> void:
	var jeu: PackedScene = load("res://scenes/game/Game.tscn")
	var g: Node = jeu.instantiate()
	g.set("headless_mode", true)
	add_child(g)
	var niveau: LevelDef = ContentDB.levels.get(&"lvl_01")
	if niveau != null:
		g.call("start_level", niveau, GameEnums.Mode.EXPLORATION)
	g.set("running", false)

	# Une main pleine et un passif : le panneau doit montrer les deux.
	RunState.hand.clear()
	for c in _huit_cartes():
		RunState.hand.append(c)
	var passif: SpellCard = ContentDB.cards.get(&"pass_celerity")
	if passif != null:
		RunState.activate_passive(passif)

	var hud: Node = g.get_node_or_null("HUD")
	if hud != null and hud.has_method("_show_pause_panel"):
		hud.call("_refresh_hand")
		hud.call("_show_pause_panel")
		await _capture("ui_02_pause")
	g.queue_free()
	await get_tree().process_frame


## 8 cartes aux noms les plus longs du jeu : c est le pire cas de lisibilite,
## celui qui produisait "Double incantatio / n" sur la capture du testeur.
func _huit_cartes() -> Array[SpellCard]:
	var toutes: Array = ContentDB.cards.values()
	toutes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return a.display_name.length() > b.display_name.length())
	var sortie: Array[SpellCard] = []
	for c: SpellCard in toutes:
		sortie.append(c)
		if sortie.size() >= 8:
			break
	return sortie


func _capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s.png" % [dir, nom])
	print("[APERCU] %s.png" % nom)
