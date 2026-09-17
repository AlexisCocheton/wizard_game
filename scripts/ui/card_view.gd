class_name CardView
extends PanelContainer
## Une carte de sort a l ecran : nom bien visible, effet ecrit dessus, temps
## d incantation, fond teinte selon la rarete. Grossit au survol pour se lire.
## Utilisee dans la main et dans le choix de cartes.

signal pressed(card: SpellCard)

const HOVER_SCALE: float = 1.18

var card: SpellCard = null
var _hovered: bool = false
var _tween: Tween = null


## compact : nom + rarete/temps seulement (main pleine, cartes etroites).
func setup(c: SpellCard, width: float, height: float, name_size: int = 26,
		body_size: int = 18, compact: bool = false) -> void:
	card = c
	custom_minimum_size = Vector2(width, height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_paper(self, UiTheme.rarity_bg(c.rarity), c.rarity == GameEnums.Rarity.LEGENDARY)
	for ch in get_children():
		ch.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var title := UiTheme.label(c.display_name, name_size, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Une carte de main fait ~120 px : "Trait arcanique" s y replierait lettre par lettre.
	# On retrecit la police jusqu a ce que le nom tienne sur deux lignes au plus.
	title.add_theme_font_size_override(&"font_size", _fit_size(c.display_name, name_size, width - 26.0))
	box.add_child(title)

	var meta := UiTheme.label("%s  -  %ss" % [GameEnums.rarity_name(c.rarity), _fmt(c.base_cast_time)],
		body_size, UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_CENTER)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)

	if compact:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(spacer)
		if not mouse_entered.is_connected(_on_enter):
			mouse_entered.connect(_on_enter)
			mouse_exited.connect(_on_exit)
			resized.connect(_on_resized)
			gui_input.connect(_on_gui_input)
		return

	var desc := UiTheme.label(c.description, body_size, Color(0.35, 0.28, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)

	if c.targeting != GameEnums.Targeting.NONE:
		var aim := UiTheme.label(_targeting_hint(c.targeting), body_size - 2, Color(0.2, 0.4, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(aim)

	if not mouse_entered.is_connected(_on_enter):
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
		resized.connect(_on_resized)
		gui_input.connect(_on_gui_input)


## Plus grande taille de police pour laquelle le nom tient en deux lignes dans `width`.
func _fit_size(text: String, wanted: int, width: float) -> int:
	var font: Font = get_theme_default_font()
	if font == null:
		return wanted
	var longest: float = 0.0
	for word in text.split(" ", false):
		longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wanted).x)
	if longest <= width or longest <= 0.0:
		return wanted
	# La largeur d un mot est proportionnelle a la taille de police.
	return clampi(int(floor(float(wanted) * width / longest)), 11, wanted)


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


func _targeting_hint(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "glisser sur une zone"
		GameEnums.Targeting.DIRECTION: return "glisser pour viser"
		GameEnums.Targeting.TARGET: return "glisser sur un monstre"
	return ""


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _on_enter() -> void:
	_hovered = true
	z_index = 20
	_animate(Vector2(HOVER_SCALE, HOVER_SCALE))


func _on_exit() -> void:
	_hovered = false
	z_index = 0
	_animate(Vector2.ONE)


func _animate(target: Vector2) -> void:
	if not Fx.enabled():
		scale = target
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, 0.10).set_trans(Tween.TRANS_QUAD)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(card)
