class_name SettingsPanel
extends VBoxContainer
## Onglet Parametres — volumes, vibrations, remise a zero.

var _reset_btn: Button
var _reset_armed: bool = false


func _ready() -> void:
	add_theme_constant_override(&"separation", 22)
	_build()


func _slider(title: String, key: String) -> void:
	add_child(UiTheme.label(title, UiTheme.FONT_BODY, UiTheme.TEXT_DIM))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveData.get_setting(key, 1.0))
	s.custom_minimum_size = Vector2(0, 70)
	s.value_changed.connect(func(v: float) -> void:
		SaveData.set_setting(key, v)
		AudioBus.apply_settings()
		SaveData.save_profile())
	add_child(s)


func _build() -> void:
	add_child(UiTheme.label("AUDIO", UiTheme.FONT_BODY, UiTheme.GOLD))
	_slider("Volume general", "master_volume")
	_slider("Effets", "sfx_volume")
	_slider("Musique", "music_volume")

	add_child(UiTheme.label("JEU", UiTheme.FONT_BODY, UiTheme.GOLD))
	var haptics := CheckButton.new()
	haptics.text = "Vibrations"
	haptics.button_pressed = bool(SaveData.get_setting("haptics", true))
	haptics.toggled.connect(func(on: bool) -> void:
		SaveData.set_setting("haptics", on)
		SaveData.save_profile())
	add_child(haptics)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# Remise a zero en deux touchers : le premier arme, le second confirme.
	_reset_btn = Button.new()
	_reset_btn.text = "Reinitialiser la progression"
	_reset_btn.custom_minimum_size = Vector2(0, 100)
	_reset_btn.add_theme_color_override(&"font_color", UiTheme.RED)
	_reset_btn.pressed.connect(_on_reset)
	add_child(_reset_btn)

	add_child(UiTheme.label("Wizard Story  -  prototype", UiTheme.FONT_SMALL,
		UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Confirmer ? Tout sera efface"
		return
	_reset_armed = false
	_reset_btn.text = "Reinitialiser la progression"
	SaveData.reset_profile()
	ContentDB.discover_starters()
	SaveData.save_profile()


func refresh() -> void:
	_reset_armed = false
	if _reset_btn != null:
		_reset_btn.text = "Reinitialiser la progression"
