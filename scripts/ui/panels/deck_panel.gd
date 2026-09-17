class_name DeckPanel
extends VBoxContainer
## Onglet Deck — l equivalent de l ecran Equipement d Archero :
## en haut ce qui est equipe (le deck), en bas la collection.
## Toucher une carte de la collection l ajoute, toucher une carte du deck la retire.

var _ids: Array = []
var _filter: int = -1  # -1 = toutes les raretes

var _title: Label
var _deck_flow: HFlowContainer
var _reset_btn: Button
var _filters: HBoxContainer
var _grid: GridContainer
var _scroll: ScrollContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	_build()
	refresh()


func _build() -> void:
	var head := HBoxContainer.new()
	add_child(head)
	_title = UiTheme.label("TON DECK", UiTheme.FONT_BODY, UiTheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_reset_btn = Button.new()
	_reset_btn.text = "Deck de base"
	_reset_btn.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	_reset_btn.pressed.connect(_on_reset)
	head.add_child(_reset_btn)

	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(0, 260)
	add_child(deck_panel)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_panel.add_child(deck_scroll)
	_deck_flow = HFlowContainer.new()
	_deck_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_flow.add_theme_constant_override(&"h_separation", 10)
	_deck_flow.add_theme_constant_override(&"v_separation", 10)
	deck_scroll.add_child(_deck_flow)

	add_child(UiTheme.label("COLLECTION", UiTheme.FONT_BODY, UiTheme.GOLD))

	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override(&"separation", 8)
	add_child(_filters)
	_add_filter("Toutes", -1)
	_add_filter("Commune", GameEnums.Rarity.COMMON)
	_add_filter("Rare", GameEnums.Rarity.RARE)
	_add_filter("Epique", GameEnums.Rarity.EPIC)
	_add_filter("Legend.", GameEnums.Rarity.LEGENDARY)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	_scroll.add_child(_grid)


func _add_filter(text: String, rarity: int) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = rarity == _filter
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	b.pressed.connect(func() -> void:
		_filter = rarity
		_render())
	_filters.add_child(b)


func refresh() -> void:
	_ids = SaveData.massacre_deck().duplicate()
	# Premier passage : on propose le deck de base plutot qu un ecran vide.
	if _ids.is_empty():
		_ids = DeckRules.default_deck_ids()
		_save()
	_render()


func _save() -> void:
	SaveData.set_massacre_deck(_ids)
	SaveData.save_profile()


func _render() -> void:
	var msg: String = DeckRules.validation_message(_ids)
	_title.text = "TON DECK  %d/%d%s" % [_ids.size(), DeckRules.MAX_CARDS,
		("   -   " + msg) if msg != "" else ""]
	_title.add_theme_color_override(&"font_color", UiTheme.RED if msg != "" else UiTheme.GOLD)

	for i in _filters.get_child_count():
		var b: Button = _filters.get_child(i) as Button
		var r: int = [-1, GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY][i]
		b.button_pressed = r == _filter

	# Le deck : un jeton par carte distincte avec son compteur.
	for c in _deck_flow.get_children():
		c.queue_free()
	var counts: Dictionary = {}
	for id in _ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var deck_ids: Array = counts.keys()
	deck_ids.sort_custom(_sort_ids)
	for id in deck_ids:
		var card: SpellCard = ContentDB.cards.get(StringName(id))
		if card == null:
			continue
		var chip := Button.new()
		chip.text = "%s  x%d" % [card.display_name, counts[id]]
		chip.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		chip.add_theme_color_override(&"font_color", UiTheme.rarity_color(card.rarity))
		chip.tooltip_text = "Toucher pour retirer un exemplaire"
		chip.pressed.connect(_on_remove.bind(card))
		_deck_flow.add_child(chip)

	# La collection : toutes les cartes decouvertes, filtrees par rarete.
	for c in _grid.get_children():
		c.queue_free()
	var cards: Array = ContentDB.cards.values()
	cards.sort_custom(_sort_cards)
	for card: SpellCard in cards:
		if _filter != -1 and card.rarity != _filter:
			continue
		var discovered: bool = SaveData.is_discovered(card.id)
		var have: int = DeckRules.count_of(_ids, card.id)
		var cap: int = DeckRules.max_copies(card.rarity)
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 170)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		if discovered:
			tile.text = "%s\n%s\n%d/%d" % [card.display_name,
				GameEnums.rarity_name(card.rarity), have, cap]
			tile.add_theme_color_override(&"font_color", UiTheme.rarity_color(card.rarity))
			tile.disabled = not DeckRules.can_add(_ids, card, true)
			tile.pressed.connect(_on_add.bind(card))
		else:
			tile.text = "???\n%s" % GameEnums.rarity_name(card.rarity)
			tile.disabled = true
		_grid.add_child(tile)


func _sort_cards(a: SpellCard, b: SpellCard) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return a.display_name < b.display_name


func _sort_ids(a: String, b: String) -> bool:
	var ca: SpellCard = ContentDB.cards.get(StringName(a))
	var cb: SpellCard = ContentDB.cards.get(StringName(b))
	if ca == null or cb == null:
		return a < b
	return _sort_cards(ca, cb)


func _on_add(card: SpellCard) -> void:
	if not DeckRules.can_add(_ids, card, SaveData.is_discovered(card.id)):
		return
	_ids.append(String(card.id))
	_save()
	_render()


func _on_remove(card: SpellCard) -> void:
	var idx: int = _ids.find(String(card.id))
	if idx == -1:
		return
	_ids.remove_at(idx)
	_save()
	_render()


func _on_reset() -> void:
	_ids = DeckRules.default_deck_ids()
	_save()
	_render()
