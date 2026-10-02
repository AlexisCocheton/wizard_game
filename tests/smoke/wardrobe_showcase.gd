class_name WardrobeShowcase
extends RefCounted
## VITRINES DE LA GARDE-ROBE (vague 8) : chapeaux sur la tete, image par image ;
## apprentis et leurs teintes ; tours ; onglet Cosmetiques ; deux combats.
##
## Fenetre reelle seulement : MageView et les effets sont inertes en headless
## (Fx.enabled()). Les captures sont a LIRE : un chapeau qui flotte a cote de la
## tete, un apprenti qui deborde sur la main ou une vignette mal recadree ne
## font rougir aucun test, ils se voient.
##
## Appele par smoke_driver.gd ; tout passe par ses _shot / _fail / _laisser_jouer.

const FOND := Color(0.36, 0.58, 0.34)

var _d: Node


func run(driver: Node) -> void:
	_d = driver
	var profil: Dictionary = SaveData.to_dictionary()
	SaveData.set_tester_mode(true)
	await _chapeaux(false)
	await _chapeaux(true)
	await _apprentis()
	await _tours()
	await _onglet()
	await _combat(&"rw_char_bluewitch", &"rw_outfit_bluewitch_ember", &"rw_tower_tree",
		"bataille_apprentie_arbre")
	await _combat(&"rw_char_fairy", &"rw_outfit_fairy_sun", &"rw_tower_ruins",
		"bataille_fee_ruines")
	await _combat(&"rw_char_mage", &"rw_hat_wizard", &"rw_tower_monastery",
		"bataille_mage_monastere")
	SaveData.set_tester_mode(false)
	SaveData.load_from_dictionary(profil)


func _scene() -> Node2D:
	var racine := Node2D.new()
	var fond := ColorRect.new()
	fond.color = FOND
	fond.size = Vector2(1080, 1920)
	fond.z_index = -50
	racine.add_child(fond)
	_d.add_child(racine)
	return racine


func _etiquette(parent: Node, at: Vector2, texte: String, largeur: float = 260.0) -> void:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override(&"font_size", 22)
	l.add_theme_color_override(&"font_color", Color(0.04, 0.05, 0.08))
	l.position = at + Vector2(-largeur * 0.5, 0.0)
	l.size = Vector2(largeur, 40.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 20
	parent.add_child(l)


func _mage(parent: Node, at: Vector2, feuille: String, chapeau: String, echelle: float) -> MageView:
	var v := MageView.new()
	v.forced_sheet = feuille
	v.forced_hat = chapeau
	v.forced_scale = echelle
	v.position = at
	parent.add_child(v)
	return v


## Les douze chapeaux, chacun sur une robe differente : le chapeau et la robe se
## CUMULENT. `incanter` : la pose de sort, ou la tete part en arriere — c est la
## que l ancrage image par image se juge.
func _chapeaux(incanter: bool) -> void:
	var racine: Node2D = _scene()
	var robes: Array = WardrobeData.HAT_RIGS.keys()
	var vues: Array[MageView] = []
	for i in WardrobeData.HATS.size():
		var at := Vector2(180.0 + (i % 3) * 360.0, 300.0 + floorf(i / 3.0) * 420.0)
		var robe: String = String(robes[i % robes.size()])
		var v: MageView = _mage(racine, at, robe, WardrobeData.HATS[i], 2.2)
		vues.append(v)
		_etiquette(racine, at + Vector2(0.0, 110.0), "%s\n%s" % [WardrobeData.HATS[i], robe])
	await _d.get_tree().process_frame
	for v in vues:
		if v.hat_layer() == null:
			_d._fail("vitrine chapeaux : %s n a pas de calque" % v.forced_hat)
		if incanter and v.body() != null:
			v.body().play(&"cast")
	await _d._laisser_jouer(0.45 if incanter else 0.3)
	await _d._shot("garde_robe_chapeaux_incantation" if incanter else "garde_robe_chapeaux")
	racine.queue_free()
	await _d.get_tree().process_frame


## Chaque apprenti et chaque teinte, pieds sur une meme ligne, a cote du mage :
## la taille relative (APPRENTICE_SCALE) se juge d un coup d oeil.
func _apprentis() -> void:
	var racine: Node2D = _scene()
	var feuilles: Array[String] = []
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r.is_apprentice():
			feuilles.append(r.texture_name)
			for t in SaveData.outfit_rewards(r.texture_name):
				feuilles.append(t.texture_name)
	var ligne: float = 520.0
	_mage(racine, Vector2(140.0, ligne), "monk_blue", "", 1.0)
	_etiquette(racine, Vector2(140.0, ligne + 60.0), "mage")
	for i in feuilles.size():
		var col: int = (i + 1) % 5
		var rang: int = floori((i + 1) / 5.0)
		var at := Vector2(140.0 + col * 200.0, ligne + rang * 420.0)
		_mage(racine, at, feuilles[i], "", 1.0)
		_etiquette(racine, at + Vector2(0.0, 60.0), feuilles[i], 200.0)
	await _d._laisser_jouer(0.3)
	await _d._shot("garde_robe_apprentis")
	racine.queue_free()
	await _d.get_tree().process_frame


## Toutes les tours, le mage pose dessus par le point "feet" mesure.
func _tours() -> void:
	var racine: Node2D = _scene()
	var cles: Array = WardrobeData.TOWERS.keys()
	for i in cles.size():
		var col: int = i % 4
		var rang: int = floori(i / 4.0)
		var cadre := Node2D.new()
		cadre.position = Vector2(140.0 + col * 265.0, 330.0 + rang * 600.0)
		cadre.scale = Vector2.ONE * 0.5
		racine.add_child(cadre)
		# make_tower pose la tour en coordonnees d ECRAN de combat : on la ramene
		# sous le personnage pose a l origine du cadre.
		var tour: Node2D = BattleBackdrop.make_tower(String(cles[i]))
		if tour == null:
			_d._fail("vitrine tours : %s ne se construit pas" % cles[i])
			continue
		tour.position -= Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
		cadre.add_child(tour)
		_mage(cadre, Vector2.ZERO, "monk_blue", "hat_wizard", 1.0)
		_etiquette(racine, cadre.position + Vector2(0.0, 220.0), String(cles[i]), 260.0)
	await _d._laisser_jouer(0.3)
	await _d._shot("garde_robe_tours")
	racine.queue_free()
	await _d.get_tree().process_frame


## L onglet Cosmetiques au niveau maximal, en trois hauteurs de defilement : les
## vignettes (et leur recadrage) de chaque grille.
func _onglet() -> void:
	var cadre := PanelContainer.new()
	cadre.size = Vector2(1080, 1920)
	cadre.add_theme_stylebox_override(&"panel", UiTheme.flat_box(Color(0.93, 0.88, 0.76), 0, 40.0))
	_d.add_child(cadre)
	var panel := ProfilePanel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.add_child(panel)
	SaveData.equip_cosmetic(&"rw_hat_witch")
	SaveData.equip_cosmetic(&"rw_mage_forest")
	SaveData.equip_cosmetic(&"rw_avatar_monk_blue")
	panel.show_section(ProfilePanel.Section.COSMETICS)
	await _d.get_tree().process_frame
	var defil: ScrollContainer = _premier_defilement(panel)
	for etape in 4:
		if defil != null:
			defil.scroll_vertical = etape * 1300
		await _d.get_tree().process_frame
		await _d._shot("garde_robe_onglet_%d" % (etape + 1))
	# Avec un apprenti : sa grille de tenues et le chapeau grise.
	SaveData.equip_cosmetic(&"rw_char_bluewitch")
	panel.refresh()
	await _d.get_tree().process_frame
	if defil != null:
		defil.scroll_vertical = 0
	await _d.get_tree().process_frame
	await _d._shot("garde_robe_onglet_apprentie")
	SaveData.equip_cosmetic(&"rw_char_mage")
	cadre.queue_free()
	await _d.get_tree().process_frame


func _premier_defilement(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is ScrollContainer:
			return c
		var s: ScrollContainer = _premier_defilement(c)
		if s != null:
			return s
	return null


## Un vrai combat : le personnage sur sa tour, la main et la jauge a l ecran. On
## y juge que l apprenti agrandi ne deborde ni sur la main ni sur la jauge.
func _combat(perso: StringName, tenue: StringName, tour: StringName, nom: String) -> void:
	for rid in [perso, tenue, tour]:
		if not SaveData.equip_cosmetic(rid):
			_d._fail("vitrine %s : %s ne s equipe pas" % [nom, rid])
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	_d.add_child(g)
	g.running = false
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	for _i in 30:
		g.simulate(1.0 / 60.0)
	await _d._laisser_jouer(0.3)
	await _d._shot(nom)
	g.queue_free()
	await _d.get_tree().process_frame
	SaveData.equip_cosmetic(&"rw_char_mage")
	SaveData.equip_cosmetic(&"rw_tower_blue")
	SaveData.equip_cosmetic(&"rw_hat_straw")
