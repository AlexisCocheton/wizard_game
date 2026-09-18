class_name CampaignPanel
extends VBoxContainer
## Onglet Campagne — l ecran central, inspire du chapitre Archero :
## la carte du niveau en grand, des fleches pour naviguer, le mode, et un gros JOUER.

var _levels: Array[LevelDef] = []
var _index: int = 0
var _mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION

var _prev_btn: Button
var _next_btn: Button
var _card: PanelContainer
var _card_body: VBoxContainer
var _explore_btn: Button
var _massacre_btn: Button
var _hint: Label
var _play_btn: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 26)
	_build()
	refresh()


func _build() -> void:
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override(&"separation", 16)
	nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(nav)

	_prev_btn = Button.new()
	_prev_btn.text = "<"
	_prev_btn.custom_minimum_size = Vector2(96, 0)
	_prev_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev_btn.pressed.connect(func() -> void: _shift(-1))
	nav.add_child(_prev_btn)

	_card = PanelContainer.new()
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(_card)

	_card_body = VBoxContainer.new()
	_card_body.add_theme_constant_override(&"separation", 18)
	_card.add_child(_card_body)

	_next_btn = Button.new()
	_next_btn.text = ">"
	_next_btn.custom_minimum_size = Vector2(96, 0)
	_next_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_next_btn.pressed.connect(func() -> void: _shift(1))
	nav.add_child(_next_btn)

	# Segment de mode : deux boutons, un seul enfonce.
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override(&"separation", 12)
	add_child(modes)
	_explore_btn = Button.new()
	_explore_btn.text = "EXPLORATION"
	_explore_btn.toggle_mode = true
	_explore_btn.custom_minimum_size = Vector2(0, 100)
	_explore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_btn.pressed.connect(func() -> void: _set_mode(GameEnums.Mode.EXPLORATION))
	modes.add_child(_explore_btn)
	_massacre_btn = Button.new()
	_massacre_btn.text = "MASSACRE"
	_massacre_btn.toggle_mode = true
	_massacre_btn.custom_minimum_size = Vector2(0, 100)
	_massacre_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_massacre_btn.pressed.connect(func() -> void: _set_mode(GameEnums.Mode.MASSACRE))
	modes.add_child(_massacre_btn)

	_hint = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_hint)

	_play_btn = Button.new()
	_play_btn.text = "JOUER"
	_play_btn.custom_minimum_size = Vector2(0, 150)
	UiTheme.style_primary(_play_btn)
	_play_btn.pressed.connect(_on_play)
	add_child(_play_btn)


func refresh() -> void:
	_levels.clear()
	# Seuls les niveaux debloques : le 2 etait jouable avant d avoir fini le 1.
	_levels.assign(SaveData.playable_levels())
	# On rouvre sur le dernier niveau joue.
	var cur: StringName = SaveData.current_level()
	_index = 0
	for i in _levels.size():
		if _levels[i].id == cur:
			_index = i
	_render()


func _shift(delta: int) -> void:
	if _levels.is_empty():
		return
	_index = clampi(_index + delta, 0, _levels.size() - 1)
	SaveData.set_current_level(_levels[_index].id)
	_render()


func _set_mode(mode: GameEnums.Mode) -> void:
	_mode = mode
	_render()


func _current() -> LevelDef:
	if _levels.is_empty():
		return null
	return _levels[_index]


func _render() -> void:
	for c in _card_body.get_children():
		c.queue_free()
	_prev_btn.disabled = _index <= 0
	_next_btn.disabled = _index >= _levels.size() - 1
	_explore_btn.button_pressed = _mode == GameEnums.Mode.EXPLORATION
	_massacre_btn.button_pressed = _mode == GameEnums.Mode.MASSACRE

	var level: LevelDef = _current()
	if level == null:
		_card_body.add_child(UiTheme.label("Aucun niveau", UiTheme.FONT_BODY))
		_play_btn.disabled = true
		return

	var unlocked: bool = SaveData.is_level_unlocked(level.id)
	var cleared: bool = SaveData.is_level_cleared(level.id)

	_card_body.add_child(UiTheme.label("NIVEAU %d" % (_index + 1), UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	_card_body.add_child(UiTheme.label(level.display_name, UiTheme.FONT_TITLE,
		UiTheme.GOLD if unlocked else Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))

	# Apercu du boss : ce qui attend le joueur en fin de niveau.
	var boss: WaveDef = level.boss_wave()
	var boss_name: String = "?"
	if boss != null and not boss.enemy_defs().is_empty():
		boss_name = boss.enemy_defs()[0].display_name
	_card_body.add_child(UiTheme.label("%d vagues   -   Boss : %s" % [level.waves.size(), boss_name],
		UiTheme.FONT_BODY, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_body.add_child(spacer)

	if not unlocked:
		_card_body.add_child(UiTheme.label("VERROUILLE\nTermine le niveau precedent",
			UiTheme.FONT_BODY, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var rec: Dictionary = SaveData.level_record(level.id)
		var best: int = int(rec.get("best_wave", 0))
		var status: String = "Termine" if cleared else "Meilleure vague : %d" % best
		_card_body.add_child(UiTheme.label(status, UiTheme.FONT_BODY,
			UiTheme.GREEN if cleared else UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

		# Objectifs : les 3 badges qui debloquent la legendaire.
		var objs: Dictionary = rec.get("objectives", {})
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 6)
		_card_body.add_child(box)
		for obj in level.objectives:
			if obj == null:
				continue
			var done: bool = bool(objs.get(String(obj.id), false))
			box.add_child(UiTheme.label("%s  %s" % ["[OK]" if done else "[   ]", obj.description],
				UiTheme.FONT_SMALL, UiTheme.GREEN if done else UiTheme.TEXT_DIM))
		if level.legendary_reward != null:
			var got: bool = SaveData.unlocked_legendaries().has(String(level.legendary_reward.id))
			box.add_child(UiTheme.label("Recompense : %s%s" % [level.legendary_reward.display_name,
				"  (obtenue)" if got else ""], UiTheme.FONT_SMALL, UiTheme.GOLD))

	# Bouton JOUER et message d aide selon le mode.
	var reason: String = ""
	if not unlocked:
		reason = "Niveau verrouille"
	elif _mode == GameEnums.Mode.MASSACRE:
		reason = DeckRules.validation_message(SaveData.massacre_deck())
	_play_btn.disabled = reason != ""
	if reason != "":
		_hint.text = reason
	elif _mode == GameEnums.Mode.EXPLORATION:
		_hint.text = "Deck pre-etabli du niveau (%d cartes)" % level.exploration_deck.size()
	else:
		_hint.text = "Vagues INFINIES avec ton deck (%d cartes)  -  un sort a choisir toutes les %d vagues" % [
			SaveData.massacre_deck().size(), GameController.WAVES_PER_CHOICE]


func _on_play() -> void:
	var level: LevelDef = _current()
	if level == null:
		return
	SaveData.set_current_level(level.id)
	SaveData.save_profile()
	SceneRouter.start_level(level.id, _mode)
