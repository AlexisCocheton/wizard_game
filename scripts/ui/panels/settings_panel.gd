class_name SettingsPanel
extends VBoxContainer
## Onglet Parametres — volumes, vibrations, remise a zero.

var _reset_btn: Button
var _reset_armed: bool = false


## La colonne des reglages, posee DANS la page de livre.
##
## LES ENCRES SONT CALCULEES, pas choisies a l oeil. Le papier du livre a une
## luminance de 0,84 ; pour atteindre le seuil de lisibilite de 4,5:1 il faut
## donc une encre sous 0,147 de luminance (formule WCAG). L or du theme, meme
## assombri de 45 %, plafonnait a 3,14:1 — un titre en petites capitales sur
## fond clair ne pardonne rien.
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 0)
	# UNE PAGE DE LIVRE, comme les autres onglets. Les reglages ecrivaient
	# directement sur le fond de bois : mesure du contraste, 3,65:1 et 3,71:1
	# pour les libelles et les titres, sous le seuil de 4,5:1. Le bois est un
	# fond decoratif, pas une surface de lecture.
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	add_child(page)
	var marge := MarginContainer.new()
	for cote in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		marge.add_theme_constant_override(cote, 26)
	page.add_child(marge)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 22)
	marge.add_child(_body)
	_build()


func _slider(title: String, key: String) -> void:
	_body.add_child(UiTheme.label(title, UiTheme.FONT_BODY, Color(0.20, 0.13, 0.07)))
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
	_body.add_child(s)


func _build() -> void:
	_body.add_child(UiTheme.label("AUDIO", UiTheme.FONT_BODY, Color(0.20, 0.13, 0.02)))
	_slider("Volume general", "master_volume")
	_slider("Effets", "sfx_volume")
	_slider("Musique", "music_volume")

	_body.add_child(UiTheme.label("JEU", UiTheme.FONT_BODY, Color(0.20, 0.13, 0.02)))
	var haptics := CheckButton.new()
	haptics.text = "Vibrations"
	haptics.button_pressed = bool(SaveData.get_setting("haptics", true))
	haptics.toggled.connect(func(on: bool) -> void:
		SaveData.set_setting("haptics", on)
		SaveData.save_profile())
	_body.add_child(haptics)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)

	# Remise a zero en deux touchers : le premier arme, le second confirme.
	_reset_btn = Button.new()
	_reset_btn.text = "Reinitialiser la progression"
	_reset_btn.custom_minimum_size = Vector2(0, 100)
	_reset_btn.add_theme_color_override(&"font_color", UiTheme.RED)
	_reset_btn.pressed.connect(_on_reset)
	_body.add_child(_reset_btn)

	# Le jeu s appelle "Time Wizard" depuis le 2026-09-21 (demande du testeur).
	# Verrouille par un test sur le titre du menu : ce pied de page etait la
	# derniere occurrence de l ancien nom dans l interface.
	# Encre SOMBRE et non TEXT_DIM : ce violet pale est fait pour un fond
	# sombre, il disparait sur le papier creme.
	_body.add_child(UiTheme.label("Time Wizard  -  prototype", UiTheme.FONT_SMALL,
		Color(0.18, 0.14, 0.08), HORIZONTAL_ALIGNMENT_CENTER))


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
