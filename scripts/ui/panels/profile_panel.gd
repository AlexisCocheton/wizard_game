class_name ProfilePanel
extends VBoxContainer
## Onglet Profil — la progression du joueur en un coup d oeil.
## Uniquement des donnees reelles de SaveData : pas de statistique inventee.

var _box: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override(&"separation", 14)
	scroll.add_child(_box)
	refresh()


func _row(title: String, value: String, color: Color = UiTheme.TEXT_DARK) -> void:
	var p := PanelContainer.new()
	_box.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := UiTheme.label(title, UiTheme.FONT_BODY, UiTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	# Pas de retour a la ligne : dans une HBox, la valeur se plierait lettre par lettre.
	var v := UiTheme.label(value, UiTheme.FONT_BODY, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)


func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()

	var total_cards: int = ContentDB.cards.size()
	var legendaries: int = ContentDB.cards_of_rarity(GameEnums.Rarity.LEGENDARY).size()
	var cleared: int = 0
	for level: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_cleared(level.id):
			cleared += 1

	_box.add_child(UiTheme.label("PROGRESSION", UiTheme.FONT_BODY, UiTheme.GOLD))
	_row("Cartes decouvertes", "%d / %d" % [SaveData.discovered_count(), total_cards])
	_row("Legendaires obtenues", "%d / %d" % [SaveData.unlocked_legendaries().size(), legendaries], UiTheme.GOLD)
	_row("Niveaux termines", "%d / %d" % [cleared, ContentDB.levels.size()], UiTheme.GREEN)
	_row("Deck Massacre", "%d cartes" % SaveData.massacre_deck().size())

	_box.add_child(UiTheme.label("PAR NIVEAU", UiTheme.FONT_BODY, UiTheme.GOLD))
	var ids: Array = ContentDB.levels.keys()
	ids.sort()
	for id in ids:
		var level: LevelDef = ContentDB.levels[id]
		if not SaveData.is_level_unlocked(level.id):
			_row(level.display_name, "verrouille", UiTheme.TEXT_DIM)
			continue
		var rec: Dictionary = SaveData.level_record(level.id)
		var objs: int = SaveData.objectives_done_count(level)
		_row(level.display_name, "vague %d   -   objectifs %d/%d" % [
			int(rec.get("best_wave", 0)), objs, level.objectives.size()],
			UiTheme.GREEN if SaveData.is_level_cleared(level.id) else UiTheme.TEXT_DARK)
