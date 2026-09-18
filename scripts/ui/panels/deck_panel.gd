class_name DeckPanel
extends VBoxContainer
## Onglet Deck — l equivalent de l ecran Equipement d Archero :
## en haut ce qui est equipe (le deck), en bas la collection.
##
## DOUBLE TOUCHER sur la collection : le 1er toucher OUVRE la fiche d effet de
## la carte, le 2e sur la MEME carte l ajoute au deck. Toucher une autre carte
## remet le compteur a zero et montre son effet.
## Pourquoi : on ajoutait au premier toucher, donc le joueur composait son deck
## sans jamais pouvoir lire ce que faisait une carte. La lecture doit precede
## l engagement, sans ajouter d ecran supplementaire.
##
## Le deck (en haut) garde le toucher unique : retirer est reversible d un geste,
## il n y a rien a lire avant.

var _ids: Array = []
var _filter: int = -1  # -1 = toutes les raretes

## Carte dont la fiche est ouverte et qui sera ajoutee au prochain toucher.
## Vide = aucun toucher en attente.
var _armed_id: StringName = &""

var _title: Label
var _deck_flow: HFlowContainer
var _reset_btn: Button
var _filters: HBoxContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _overlay: Control
var _detail: PanelContainer


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

	# La fiche d effet se SUPERPOSE a l onglet. Une VBoxContainer empile ses
	# enfants : un PanelContainer ajoute ici irait SOUS la collection, hors
	# ecran. On passe donc par un Control en top_level, hors du flux de la VBox.
	_overlay = Control.new()
	_overlay.top_level = true
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_detail = PanelContainer.new()
	_overlay.add_child(_detail)


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
	# Revenir sur l onglet remet le double toucher a zero : une carte armee
	# oubliee d une visite precedente s ajouterait au premier toucher suivant.
	_armed_id = &""
	_hide_detail()
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
			# La tuile armee annonce ce que fera le PROCHAIN toucher : sans ce
			# retour, un second toucher qui ajoute passerait pour un bug.
			var armed: bool = card.id == _armed_id
			tile.text = "%s\n%s\n%s" % [card.display_name,
				GameEnums.rarity_name(card.rarity),
				("> AJOUTER" if armed else "%d/%d" % [have, cap])]
			tile.add_theme_color_override(&"font_color",
				UiTheme.GOLD if armed else UiTheme.rarity_color(card.rarity))
			tile.disabled = not DeckRules.can_add(_ids, card, true)
			tile.pressed.connect(_on_collection_tap.bind(card))
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


## Toucher une carte de la COLLECTION. Deux etats, un seul bouton :
##   1er toucher (ou carte differente) -> arme la carte et montre son effet
##   2e toucher sur la MEME carte      -> ajoute au deck et desarme
## Toucher une autre carte remet le compteur a zero : on ne peut pas ajouter
## par inadvertance une carte dont on n a pas lu la fiche.
func _on_collection_tap(card: SpellCard) -> void:
	if card.id == _armed_id:
		_armed_id = &""
		_hide_detail()
		_do_add(card)
		return
	_armed_id = card.id
	_show_detail(card)
	_render()


## L ajout reel. Separe du toucher pour que la regle de deck reste testable
## sans passer par l interface.
func _do_add(card: SpellCard) -> void:
	if not DeckRules.can_add(_ids, card, SaveData.is_discovered(card.id)):
		return
	_ids.append(String(card.id))
	_save()
	_render()


## Etat du double toucher, expose pour les tests et pour le retour visuel.
func armed_card() -> StringName:
	return _armed_id


func _hide_detail() -> void:
	if _overlay != null:
		_overlay.visible = false


## Fiche d effet : ce que fait la carte, en encre SOMBRE sur le papier clair
## (le blanc y est illisible). Un bandeau rappelle qu un second toucher ajoute.
func _show_detail(card: SpellCard) -> void:
	if _overlay == null:
		return
	# L overlay est top_level : il ne suit ni la taille ni la position de la VBox
	# et garderait la taille minimale de son contenu, coince en haut a gauche.
	# On le recale a la main sur le rectangle du panneau a chaque ouverture.
	_overlay.global_position = global_position
	_overlay.size = size
	_detail.position = Vector2.ZERO
	_detail.size = size
	for c in _detail.get_children():
		c.queue_free()

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	_detail.add_child(box)
	box.add_child(UiTheme.label(card.display_name, UiTheme.FONT_TITLE,
		UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("%s   -   incantation %s s" % [
		GameEnums.rarity_name(card.rarity).capitalize(), _fmt(card.base_cast_time)],
		UiTheme.FONT_BODY, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(card.description, UiTheme.FONT_BODY,
		UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	var have: int = DeckRules.count_of(_ids, card.id)
	var cap: int = DeckRules.max_copies(card.rarity)
	box.add_child(UiTheme.label("Dans ton deck : %d / %d" % [have, cap],
		UiTheme.FONT_BODY, UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var add := Button.new()
	add.text = "AJOUTER AU DECK"
	add.custom_minimum_size = Vector2(0, 120)   # cible tactile confortable
	add.disabled = not DeckRules.can_add(_ids, card, SaveData.is_discovered(card.id))
	add.pressed.connect(func() -> void: _on_collection_tap(card))
	box.add_child(add)

	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 110)
	close.pressed.connect(func() -> void:
		_armed_id = &""
		_hide_detail()
		_render())
	box.add_child(close)

	# Le Control parent ignore la souris pour ne rien voler au reste ; la fiche
	# elle-meme doit l intercepter, sinon on touche la grille au travers.
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = true


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


func _on_remove(card: SpellCard) -> void:
	# Retirer une carte desarme : sans cela, le toucher suivant sur la tuile
	# armee la RE-ajouterait, ce que le joueur vient justement de defaire.
	_armed_id = &""
	_hide_detail()
	var idx: int = _ids.find(String(card.id))
	if idx == -1:
		return
	_ids.remove_at(idx)
	_save()
	_render()


func _on_reset() -> void:
	_armed_id = &""
	_hide_detail()
	_ids = DeckRules.default_deck_ids()
	_save()
	_render()
