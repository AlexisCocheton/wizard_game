extends Node
## ETAGE SMOKE — joue un niveau complet en headless avec un delta fixe.
##
## Verifie sur 4.4.stable : une SCRIPT ERROR runtime ne change pas le code de
## sortie. Le marqueur SMOKE_OK distingue donc "partie jouee jusqu au bout" de
## "mort silencieuse a la frame 3", et run_tests.sh parse stderr en plus.

const FIXED_DELTA: float = 1.0 / 60.0
const MAX_STEPS: int = 60 * 60 * 12   # 12 minutes simulees au maximum

var _game: GameController = null
var _won: bool = false
var _lost: bool = false
## get_tree().quit(code) ne stoppe pas l execution immediatement : le reste de la
## fonction continue et un quit(0) ulterieur ECRASE le code d erreur. On memorise
## donc l echec et on sort une seule fois, a la fin.
var _failed: bool = false


## Vrai quand le smoke tourne en fenetre reelle (etage `visual`) : le code de
## sprites s execute et des captures d ecran sont ecrites dans .testout/.
var _visual: bool = false
var _shot_index: int = 0


func _ready() -> void:
	# Jamais d ecriture dans le vrai profil, meme en fenetre reelle.
	SaveData.persistence_enabled = false
	_visual = DisplayServer.get_name() != "headless"
	await get_tree().process_frame
	await _run_all()
	# UNIQUE point de sortie : un `return` anticipe dans _run_all() ne peut plus
	# laisser le process tourner sans fin (verifie : ca a deja hang une fois).
	_finish()


func _finish() -> void:
	if _failed:
		get_tree().quit(1)
		return
	print("SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	_failed = true
	printerr("[SMOKE] %s" % message)


## Capture d ecran (mode visuel seulement). Attend un rendu complet avant de lire.
func _shot(label: String) -> void:
	if not _visual:
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	_shot_index += 1
	var dir: String = ProjectSettings.globalize_path("res://.testout")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = "%s/shot_%02d_%s.png" % [dir, _shot_index, label]
	img.save_png(path)
	print("[SMOKE] capture : %s" % path.get_file())


func _run_all() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		_fail("niveau lvl_01 introuvable")
		return

	# 0) Vitrines visuelles : tous les monstres, puis quelques sorts isoles.
	await _showcase_enemies()
	await _showcase_effects()

	# 1) Chaque carte doit passer dans son handler sans erreur.
	await _exercise_every_card()

	# 2) Partie complete, pilotee a delta fixe.
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	_game = packed.instantiate()
	_game.headless_mode = true
	add_child(_game)
	_game.level_won.connect(func() -> void: _won = true)
	_game.level_lost.connect(func() -> void: _lost = true)
	_game.start_level(level, GameEnums.Mode.EXPLORATION)
	# Seul le smoke fait avancer la partie : sinon _process() la joue en temps reel
	# pendant les frames d attente des captures, et l etat n est plus celui attendu.
	_game.running = false

	var steps: int = 0
	var shot_done: bool = false
	while steps < MAX_STEPS and not _won and not _lost:
		# Le mage tue tout : on veut atteindre la victoire, pas mourir de faiblesse.
		_autoplay()
		_game.simulate(FIXED_DELTA)
		steps += 1
		# Vers la vague 5 : des monstres varies, des zones au sol, une incantation.
		if _visual and not shot_done and RunState.wave_index >= 4 				and _game.battlefield.alive_count() >= 5 and RunState.pending_offer.is_empty():
			shot_done = true
			await _shot("bataille")
		if _visual and RunState.pending_offer.size() > 0 and _shot_index < 2:
			await _shot("choix")

	print("[SMOKE] %d pas simules, vagues=%d, niveau joueur=%d"
		% [steps, RunState.wave_index, RunState.level])

	if _lost:
		_fail("defaite inattendue en autoplay")
		return
	if not _won:
		_fail("la partie ne s est jamais terminee (limite de pas atteinte)")
		return

	# La partie de test est terminee : on la retire pour que son HUD (et un
	# eventuel choix de sort en attente) ne recouvre pas les ecrans suivants.
	RunState.pending_offer.clear()
	_game.queue_free()
	_game = null
	if _visual:
		await get_tree().process_frame

	# 3) Le mur doit bloquer puis liberer la navigation.
	_check_wall_pathfinding()

	# 4) Tous les ecrans du menu et de fin de niveau doivent se construire.
	await _check_menu_screens()
	await _check_briefing()
	await _check_end_screens()
	_check_massacre_deck()

	# 4) La defaite doit aussi fonctionner.
	_check_defeat_path()



## Vitrine : un exemplaire de chaque monstre en grille, pour juger sprites et tailles.
func _showcase_enemies() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("grass")
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	var cols: int = 3
	var i: int = 0
	for id in ids:
		var def: EnemyDef = ContentDB.enemies[id]
		var x: float = 200.0 + (i % cols) * 340.0
		var y: float = 230.0 + int(i / cols) * 180.0
		var e: Enemy = g.battlefield.spawn_enemy(def, x, 1.0, Vector2(x, y))
		if e != null:
			e.take_damage(1.0, [])  # fait apparaitre la barre de vie
		# Etiquette sous chaque monstre : indispensable pour verifier le mapping.
		var l := Label.new()
		l.text = "%s (P%d)" % [def.id, def.power]
		l.add_theme_font_size_override(&"font_size", 22)
		l.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
		l.position = Vector2(x - 120.0, y + 50.0)
		l.size = Vector2(240.0, 30.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.battlefield.add_child(l)
		i += 1
	await _shot("vitrine_monstres")
	g.queue_free()
	await get_tree().process_frame


## Vitrine : quelques sorts lances separement sur un terrain propre.
func _showcase_effects() -> void:
	if not _visual:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	g.backdrop.setup("sand")
	var bf: Battlefield = g.battlefield
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	for k in 4:
		bf.spawn_enemy(gnome, 300.0 + k * 160.0, 1.0, Vector2(300.0 + k * 160.0, 520.0))
	var casts: Array = [
		[&"fireball", Vector2(260.0, 900.0)],
		[&"frost_field", Vector2(800.0, 900.0)],
		[&"stone_wall", Vector2(540.0, 700.0)],
		[&"weakness_mark", Vector2(540.0, 1200.0)],
		[&"piercing_arrow", Vector2(540.0, 300.0)],
	]
	for c in casts:
		var card: SpellCard = ContentDB.cards.get(c[0])
		if card == null:
			continue
		var ctx := CastContext.make(bf, card)
		ctx.caster = g
		ctx.target_position = c[1]
		ctx.direction = (c[1] - Vector2(540.0, GameConfig.MAGE_LINE_Y)).normalized()
		ctx.target_enemy = bf.enemy_nearest_to(c[1])
		EffectRegistry.cast(card, ctx)
	for k in 6:
		bf.simulate(FIXED_DELTA)
	await _shot("vitrine_sorts")
	g.queue_free()
	await get_tree().process_frame


## Joue toutes les cartes du catalogue contre un champ de bataille reel.
## Attrape les cles d effet sans handler et les erreurs de parametres.
func _exercise_every_card() -> void:
	var bf_scene: PackedScene = load("res://scenes/game/Game.tscn")
	var probe: GameController = bf_scene.instantiate()
	probe.headless_mode = true
	add_child(probe)
	probe.running = false
	var bf: Battlefield = probe.battlefield

	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	for i in 6:
		bf.spawn_enemy(gnome, 200.0 + i * 100.0)

	var count: int = 0
	for card: SpellCard in ContentDB.cards.values():
		# On vise comme le ferait un joueur : un point sur le terrain.
		var aim := Vector2(540.0, 900.0)
		var ctx := CastContext.make(bf, card)
		ctx.caster = probe
		ctx.target_position = aim
		ctx.direction = (aim - Vector2(540.0, GameConfig.MAGE_LINE_Y)).normalized()
		ctx.target_enemy = bf.enemy_nearest_to(aim)
		EffectRegistry.cast(card, ctx)
		count += 1
	# Laisse tourner les zones et allies crees.
	for i in 30:
		bf.simulate(FIXED_DELTA)
	await _shot("effets")
	for i in 90:
		bf.simulate(FIXED_DELTA)
	print("[SMOKE] %d cartes lancees sans erreur" % count)
	probe.queue_free()


## Detruit les ennemis proches pour que la simulation avance jusqu au boss.
func _autoplay() -> void:
	_autoplay_for(_game)


func _autoplay_for(g: GameController) -> void:
	# Un choix de sort en attente met la partie en pause : on prend le premier.
	if not RunState.pending_offer.is_empty():
		g.choose_card(0)
		return
	var bf: Battlefield = g.battlefield
	# Le mage de test est invulnerable aux tirs : on veut atteindre la victoire.
	bf.shots.clear()
	for e in bf.enemies.duplicate():
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		if e.position.y > GameConfig.MAGE_LINE_Y - 500.0:
			e.take_damage(9999.0, [])
	# Joue une carte des que possible, pour exercer la boucle d incantation.
	if not g.caster.is_busy() and not RunState.hand.is_empty():
		g.play_card(RunState.hand[0], Vector2(540.0, 900.0))


## Instancie le menu et passe par chaque onglet : attrape les chemins de noeuds
## casses et les panneaux qui plantent a la construction.
func _check_menu_screens() -> void:
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	if packed == null:
		_fail("MainMenu.tscn introuvable")
		return
	var menu: Control = packed.instantiate()
	add_child(menu)
	for i in 5:
		menu.select_tab(i)
		if menu.current_tab() != i:
			_fail("l onglet %d ne s active pas" % i)
	# Un second passage exerce refresh() sur un panneau deja construit.
	menu.select_tab(2)
	await _shot("menu_campagne")
	menu.select_tab(1)
	await _shot("menu_deck")
	menu.select_tab(0)
	await _shot("menu_galerie")
	menu.select_tab(3)
	await _shot("menu_profil")
	menu.select_tab(4)
	await _shot("menu_reglages")
	menu.select_tab(2)
	menu.queue_free()
	print("[SMOKE] menu : 5 onglets construits")


## L ecran de briefing se construit pour les deux modes et mene bien a la partie.
func _check_briefing() -> void:
	var packed: PackedScene = load("res://scenes/loading/LoadingScreen.tscn")
	if packed == null:
		_fail("LoadingScreen.tscn introuvable")
		return
	for mode in [GameEnums.Mode.EXPLORATION, GameEnums.Mode.MASSACRE]:
		SceneRouter.payload = {"level_id": &"lvl_01", "mode": mode}
		var screen: Control = packed.instantiate()
		add_child(screen)
		await get_tree().process_frame
		# Le briefing doit montrer QUELQUE CHOSE : un ecran vide ne sert a rien.
		var menaces: VBoxContainer = screen.get_node_or_null("%Waves")
		if menaces == null or menaces.get_child_count() == 0:
			_fail("le briefing n affiche aucune menace (mode %d)" % mode)
		if mode == GameEnums.Mode.EXPLORATION:
			await _shot("briefing")
		screen.queue_free()
		await get_tree().process_frame
	# La route du menu passe bien par le briefing, pas directement par la partie.
	if SceneRouter.LOADING == SceneRouter.GAME:
		_fail("la route de briefing pointe sur la partie")
	print("[SMOKE] briefing construit pour les deux modes")


## Victoire puis defaite, avec la progression reelle derriere.
func _check_end_screens() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	RunState.mode = GameEnums.Mode.EXPLORATION
	SceneRouter.payload = {"level_id": &"lvl_01"}
	var v: PackedScene = load("res://scenes/endgame/VictoryScreen.tscn")
	var vs: Control = v.instantiate()
	add_child(vs)
	if not SaveData.is_level_unlocked(&"lvl_02"):
		_fail("l ecran de victoire n a pas debloque le niveau suivant")
	await _shot("victoire")
	vs.queue_free()

	SceneRouter.payload = {"level_id": &"lvl_01", "waves": 3}
	var d: PackedScene = load("res://scenes/endgame/DefeatScreen.tscn")
	var ds: Control = d.instantiate()
	add_child(ds)
	ds.queue_free()
	print("[SMOKE] ecrans de fin construits")


## Une partie en Massacre doit demarrer avec le deck du joueur.
func _check_massacre_deck() -> void:
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.start_level(level, GameEnums.Mode.MASSACRE)
	g.running = false
	if RunState.total_cards() < DeckRules.MIN_CARDS:
		_fail("deck Massacre trop petit en partie : %d" % RunState.total_cards())
	if RunState.hand.is_empty():
		_fail("aucune carte en main au depart en Massacre")
	# Mode infini : on joue 6 vagues, un choix de sort doit survenir toutes les 2.
	var offers: Array[int] = [0]
	g.cards_offered.connect(func(_c: Array[SpellCard]) -> void: offers[0] += 1)
	var steps: int = 0
	while RunState.wave_index < 6 and steps < 60 * 60 * 6 and not _lost:
		_autoplay_for(g)
		g.simulate(FIXED_DELTA)
		steps += 1
	if RunState.wave_index < 6:
		_fail("mode infini : seulement %d vagues en %d pas" % [RunState.wave_index, steps])
	if offers[0] < 3:
		_fail("mode infini : %d choix de sorts au lieu de 3 en 6 vagues" % offers[0])
	if g.spawner.is_finished():
		_fail("le mode infini ne doit jamais se terminer")
	g.queue_free()
	print("[SMOKE] mode infini : %d vagues, %d choix de sorts, deck de %d cartes"
		% [RunState.wave_index, offers[0], RunState.total_cards()])


## Verifie qu un mur devie reellement les monstres puis libere le passage.
func _check_wall_pathfinding() -> void:
	var grid := NavGrid.new()
	var depart := Vector2(540.0, 300.0)
	if grid.find_path(depart).is_empty():
		_fail("aucun chemin sans obstacle")
		return

	var cells: Array[Vector2i] = grid.block_rect(Vector2(540.0, 800.0), 240.0, 60.0)
	var devie: Array[Vector2] = grid.find_path(depart)
	if devie.is_empty():
		_fail("le mur bloque totalement alors qu il laisse les bords libres")
		return
	var ecart: float = 0.0
	for p in devie:
		ecart = maxf(ecart, absf(p.x - depart.x))
	if ecart <= NavGrid.CELL_SIZE:
		_fail("le monstre ne contourne pas le mur")
		return

	grid.unblock_cells(cells)
	if grid.blocked_count() != 0:
		_fail("cellules non liberees apres expiration du mur")
		return
	print("[SMOKE] mur : contournement de %.0f px puis liberation" % ecart)


## Verifie que 0 PV mene bien a la defaite via le drain post-mortem.
func _check_defeat_path() -> void:
	SpeedGauge.reset()
	var died: Array[bool] = [false]
	var cb := func() -> void: died[0] = true
	SpeedGauge.died.connect(cb)
	for i in 8:
		SpeedGauge.take_hit()
	var guard: int = 0
	while not died[0] and guard < 6000:
		SpeedGauge.tick(FIXED_DELTA)
		guard += 1
	SpeedGauge.died.disconnect(cb)
	if not died[0]:
		_fail("le drain post-mortem n a jamais abouti a la defaite")
		return
	print("[SMOKE] chemin de defaite verifie")
