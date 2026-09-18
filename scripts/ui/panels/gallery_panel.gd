class_name GalleryPanel
extends Control
## Onglet Galerie — toutes les cartes du jeu. Les non decouvertes restent
## masquees ("???") pour donner envie de les debloquer.
##
## Racine en Control (pas en conteneur) : la fiche detaillee doit se superposer
## a la grille, ce qu un VBoxContainer interdirait en la placant en dessous.

var _grid: GridContainer
var _counter: Label
var _detail: PanelContainer


func _ready() -> void:
	_build()
	refresh()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override(&"separation", 16)
	add_child(vbox)

	_counter = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_counter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_grid)

	# Fiche detaillee par-dessus la grille, fermee d un toucher.
	_detail = PanelContainer.new()
	_detail.visible = false
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_detail)


func refresh() -> void:
	_detail.visible = false
	for c in _grid.get_children():
		c.queue_free()
	var cards: Array = ContentDB.cards.values()
	cards.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.display_name < b.display_name)
	var found: int = 0
	for card: SpellCard in cards:
		var discovered: bool = SaveData.is_discovered(card.id)
		if discovered:
			found += 1
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 180)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		if discovered:
			tile.text = "%s\n%s\n%ss" % [card.display_name,
				GameEnums.rarity_name(card.rarity), _fmt(card.base_cast_time)]
			tile.add_theme_color_override(&"font_color", UiTheme.rarity_color(card.rarity))
			tile.pressed.connect(_show_detail.bind(card))
		else:
			tile.text = "???\n%s" % GameEnums.rarity_name(card.rarity)
			tile.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM)
		_grid.add_child(tile)
	_counter.text = "Cartes decouvertes : %d / %d" % [found, cards.size()]


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


func _targeting_name(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "Zone visee"
		GameEnums.Targeting.DIRECTION: return "Tir en ligne"
		GameEnums.Targeting.TARGET: return "Cible unique"
	return "Sur soi"


func _show_detail(card: SpellCard) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	_detail.add_child(box)
	box.add_child(UiTheme.label(card.display_name, UiTheme.FONT_TITLE,
		UiTheme.rarity_color(card.rarity), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("%s   -   %s" % [GameEnums.rarity_name(card.rarity).capitalize(),
		_targeting_name(card.targeting)], UiTheme.FONT_BODY, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Incantation : %s s" % _fmt(card.base_cast_time),
		UiTheme.FONT_BODY, UiTheme.BLUE, HORIZONTAL_ALIGNMENT_CENTER))
	# Encre SOMBRE : le panneau est un papier clair, le blanc y etait illisible.
	box.add_child(UiTheme.label(card.description, UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 110)
	close.pressed.connect(func() -> void: _detail.visible = false)
	box.add_child(close)
	_detail.visible = true
