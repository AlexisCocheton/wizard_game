extends CanvasLayer
## HUD portrait 1080x1920, dispose selon le cahier des charges :
##
##   [x2]        Vague 3/6  Niv.4          [||]
##   +--------------------------------------+
##   | jauge |                      | jauge |
##   | ennemi|    champ de bataille | sorts |
##   | (gauche)                     |(droite
##   |       |                      | = PV) |
##   +--------------------------------------+
##            [carte][carte][carte]
##   ================ XP ====================
##
## Les cartes sont des CardView (nom, effet, rarete) ; on les glisse sur le
## terrain pour viser. Un choix de 3 cartes se superpose au jeu quand il y a lieu.

var game: GameController = null

@onready var _root: Control = $Root
@onready var _speed_btn: Button = %SpeedButton
@onready var _pause_btn: Button = %PauseButton
@onready var _wave_label: Label = %WaveLabel
@onready var _enemy_bar: TextureProgressBar = %EnemyBar
@onready var _spell_bar: TextureProgressBar = %SpellBar
@onready var _hp_label: Label = %HpLabel
@onready var _xp_bar: TextureProgressBar = %XpBar
@onready var _hand: HBoxContainer = %Hand
@onready var _cast_bar: TextureProgressBar = %CastBar
@onready var _draw_label: Label = %DrawTimer
@onready var _aim: Control = %AimOverlay

## Carte en cours de glissement (null si aucun geste en cours).
var _dragging: SpellCard = null
var _choice: Control = null


func _ready() -> void:
	# Sans cela le HUD gele avec le jeu : son propre bouton pause ne repond plus
	# et la partie reste bloquee pour de bon.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = UiTheme.make()
	_speed_btn.pressed.connect(_on_speed_pressed)
	# La barre de vitesse se regle au doigt : toucher un point y place la vitesse.
	_enemy_bar.gui_input.connect(_on_speed_bar_input)
	_enemy_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_btn.pressed.connect(_on_pause_pressed)
	RunState.card_drawn.connect(func(_c: SpellCard) -> void: AudioBus.play_sfx(&"card_draw"))
	SpeedGauge.multiplier_changed.connect(_on_multiplier_changed)
	SpeedGauge.hp_changed.connect(_on_hp_changed)
	RunState.hand_changed.connect(_refresh_hand)
	RunState.wave_changed.connect(_on_wave_changed)
	# Le choix peut etre pris ailleurs que par un clic (tests, reprise) : on suit l etat.
	RunState.offer_taken.connect(func(_c: SpellCard) -> void:
		if _choice != null:
			_choice.visible = false)
	_build_choice_overlay()
	_refresh_all()


func bind(controller: GameController) -> void:
	game = controller
	if game != null:
		# Idempotent : bind() peut etre rappele si le niveau redemarre.
		if not game.caster.cast_progress.is_connected(_on_cast_progress):
			game.caster.cast_progress.connect(_on_cast_progress)
		if not game.caster.cast_finished.is_connected(_on_cast_finished):
			game.caster.cast_finished.connect(_on_cast_finished)
		if not game.cards_offered.is_connected(_show_choice):
			game.cards_offered.connect(_show_choice)
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_gauges()


func _refresh_all() -> void:
	_refresh_gauges()
	_refresh_hand()
	_on_wave_changed(RunState.wave_index)
	_on_hp_changed(SpeedGauge.hp)


func _refresh_gauges() -> void:
	# Gauche : la vitesse, de 100 a 500 %. Droite : les PV du mage, bouclier inclus.
	_enemy_bar.value = SpeedGauge.speed_ratio() * 100.0
	var pv_max: float = float(maxi(1, SpeedGauge.max_hp))
	_spell_bar.value = 100.0 * float(SpeedGauge.hp) / pv_max
	_speed_btn.text = "%d%%" % SpeedGauge.speed_percent
	# Verrou apres un coup : le bouton dit pourquoi il ne repond pas.
	_speed_btn.disabled = SpeedGauge.accel_locked()
	_speed_btn.modulate = Color(1, 0.6, 0.6) if SpeedGauge.accel_locked() else Color.WHITE

	# Le sort prepare doit se voir, sinon le joueur ne sait pas ce qui va partir.
	var en_attente: SpellCard = null
	if game != null and game.caster != null:
		en_attente = game.caster.queued_card()
	for child in _hand.get_children():
		if child is CardView:
			var cv := child as CardView
			cv.modulate = Color(1.0, 0.92, 0.6) if (en_attente != null and cv.card == en_attente) 				else Color.WHITE

	# Compte a rebours de la prochaine pioche : le joueur jouait a l aveugle
	# entre deux pioches, sans savoir s il devait garder une carte ou la depenser.
	var dans: float = RunState.seconds_to_draw()
	_draw_label.text = "pioche dans %.1f s" % dans
	_draw_label.add_theme_color_override(&"font_color",
		UiTheme.GOLD if dans < 1.0 else UiTheme.TEXT)
	_draw_label.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)

	var need: int = GameConfig.xp_required(RunState.level)
	_xp_bar.value = 100.0 * float(RunState.xp) / float(maxi(1, need))

	if SpeedGauge.is_dying:
		_spell_bar.modulate = Color(1, 1, 1, 0.4 + 0.6 * SpeedGauge.death_gauge)


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


# --- Main de cartes ---

func _refresh_hand() -> void:
	for child in _hand.get_children():
		child.queue_free()
	var n: int = RunState.hand.size()
	if n == 0:
		return
	# La main tient dans la largeur : les cartes retrecissent quand elles sont nombreuses.
	var width: float = clampf((1052.0 - 6.0 * (n - 1)) / n, 118.0, 200.0)
	var compact: bool = width < 150.0
	var name_size: int = 24 if width >= 160.0 else 16
	var body_size: int = 17 if width >= 160.0 else 15
	for card: SpellCard in RunState.hand:
		var cv := CardView.new()
		cv.setup(card, width, 190.0 if compact else 250.0, name_size, body_size, compact)
		cv.gui_input.connect(_on_card_input.bind(card))
		_hand.add_child(cv)


func _needs_aim(card: SpellCard) -> bool:
	return card != null and card.targeting != GameEnums.Targeting.NONE


## Glisser-deposer : on appuie sur la carte, on glisse sur le terrain, on relache.
## Une carte sans ciblage part au simple appui.
##
## La carte a mouse_filter = STOP : elle CONSOMME le relachement, qui n atteint
## donc jamais _unhandled_input. Le suivi et le relachement sont pour cette
## raison geres dans _input(), qui recoit l evenement avant l UI.
func _on_card_input(event: InputEvent, card: SpellCard) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		if _needs_aim(card):
			_begin_drag(card, mb.global_position)
		else:
			_play(card, Vector2.INF)


func _begin_drag(card: SpellCard, screen_pos: Vector2) -> void:
	_dragging = card
	var point: Vector2 = _battlefield_point(screen_pos)
	_aim.show_aim(card, point, _is_valid_aim(point))


## Recoit TOUS les evenements, y compris ceux que les cartes consomment ensuite.
func _input(event: InputEvent) -> void:
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = _battlefield_point((event as InputEventMouseMotion).global_position)
		_aim.show_aim(_dragging, point, _is_valid_aim(point))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_drag(mb.global_position)
			get_viewport().set_input_as_handled()


func _end_drag(screen_pos: Vector2) -> void:
	var card: SpellCard = _dragging
	_dragging = null
	_aim.hide_aim()
	if card == null:
		return
	var point: Vector2 = _battlefield_point(screen_pos)
	if _is_valid_aim(point):
		_play(card, point)
	# Visee hors terrain : la carte reste en main, le geste est simplement annule.


## La zone jouable exclut la main de cartes et la barre du haut.
func _is_valid_aim(point: Vector2) -> bool:
	return point.y > 160.0 and point.y < GameConfig.MAGE_LINE_Y \
		and point.x > 0.0 and point.x < GameConfig.BATTLEFIELD_WIDTH


## Convertit un point ecran en coordonnees du champ de bataille.
func _battlefield_point(screen_pos: Vector2) -> Vector2:
	if game == null:
		return screen_pos
	return game.battlefield.to_local(screen_pos)


func _play(card: SpellCard, aim: Vector2) -> void:
	if game != null:
		game.play_card(card, aim)


# --- Choix de cartes ---

func _build_choice_overlay() -> void:
	_choice = Control.new()
	_choice.name = "CardChoice"
	_choice.visible = false
	_choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_choice)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice.add_child(dim)


func _show_choice(cards: Array[SpellCard]) -> void:
	for ch in _choice.get_children():
		if ch is ColorRect:
			continue
		ch.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 380.0
	box.offset_bottom = -420.0
	box.add_theme_constant_override(&"separation", 40)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice.add_child(box)
	box.add_child(UiTheme.label("CHOISIS UN SORT", UiTheme.FONT_TITLE, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Il rejoint ta defausse et reviendra dans la pioche.",
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in cards.size():
		var cv := CardView.new()
		cv.setup(cards[i], 300.0, 440.0, 28, 20)
		cv.pressed.connect(func(_c: SpellCard) -> void: _pick(i))
		row.add_child(cv)
	_choice.visible = true


func _pick(i: int) -> void:
	AudioBus.play_sfx(&"card_pick")
	_choice.visible = false
	if game != null:
		game.choose_card(i)


# --- Divers ---

func _on_cast_progress(ratio: float) -> void:
	_cast_bar.visible = true
	_cast_bar.value = ratio * 100.0


func _on_cast_finished(_card: SpellCard) -> void:
	_cast_bar.visible = false
	_cast_bar.value = 0.0


## Toucher la barre de vitesse : elle est pivotee de -90 degres, donc c est la
## coordonnee X locale qui monte, pas Y.
func _on_speed_bar_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if SpeedGauge.accel_locked():
		return
	var largeur: float = maxf(_enemy_bar.size.x, 1.0)
	SpeedGauge.set_speed_from_ratio(clampf(mb.position.x / largeur, 0.0, 1.0))
	AudioBus.play_sfx(&"speed_up")


func _on_speed_pressed() -> void:
	if SpeedGauge.accel_locked():
		return
	AudioBus.play_sfx(&"speed_up")
	SpeedGauge.bump_speed()


## Le HUD DOIT continuer a tourner en pause, sinon son propre bouton ne repond
## plus et la partie reste bloquee. C est ce qui arrivait : un seul clic figeait
## tout, y compris le moyen de repartir.
func _on_pause_pressed() -> void:
	var tree: SceneTree = get_tree()
	tree.paused = not tree.paused
	_pause_btn.text = ">" if tree.paused else "II"


func _on_multiplier_changed(_old: int, _new: int) -> void:
	_refresh_gauges()


func _on_hp_changed(hp: int) -> void:
	_hp_label.text = "PV %d/%d" % [hp, SpeedGauge.max_hp]


func _on_wave_changed(index: int) -> void:
	var total: int = 0
	if RunState.current_level_def != null and RunState.mode == GameEnums.Mode.EXPLORATION:
		total = RunState.current_level_def.waves.size()
	if total > 0:
		_wave_label.text = "Vague %d/%d   Niv.%d" % [mini(index + 1, total), total, RunState.level]
	else:
		_wave_label.text = "Vague %d   Niv.%d" % [index + 1, RunState.level]
