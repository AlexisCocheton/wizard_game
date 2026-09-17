extends Control
## Menu principal — coquille a onglets inspiree d Archero :
##
##   +------------------------------------------+
##   | [mage]  Wizard Story        cartes 12/14 |  <- barre du haut
##   +------------------------------------------+
##   |                                          |
##   |            panneau de l onglet           |
##   |                                          |
##   +------------------------------------------+
##   | Galerie | Deck | [CAMPAGNE] | Profil | Param |  <- onglets, centre sureleve
##   +------------------------------------------+
##
## Les onglets changent le panneau sans changer de scene : la navigation est
## instantanee, comme sur mobile.

const TABS: Array[String] = ["GALERIE", "DECK", "CAMPAGNE", "PROFIL", "REGLAGES"]
const HOME_TAB: int = 2

@onready var _content: MarginContainer = %Content
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _cards_label: Label = %CardsLabel

var _panels: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _current: int = -1


func _ready() -> void:
	theme = UiTheme.make()
	_build_panels()
	_build_tabs()
	SaveData.profile_changed.connect(_refresh_top_bar)
	_refresh_top_bar()
	select_tab(HOME_TAB)
	AudioBus.play_music(&"menu")


func _build_panels() -> void:
	_panels = [
		GalleryPanel.new(),
		DeckPanel.new(),
		CampaignPanel.new(),
		ProfilePanel.new(),
		SettingsPanel.new(),
	]
	for p in _panels:
		p.visible = false
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(p)


func _build_tabs() -> void:
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		# L onglet central est plus grand et depasse vers le haut : c est
		# la signature visuelle d Archero, le "home" se repere au pouce.
		if i == HOME_TAB:
			b.custom_minimum_size = Vector2(0, 200)
			b.size_flags_vertical = Control.SIZE_SHRINK_END
			b.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
		else:
			b.custom_minimum_size = Vector2(0, 150)
			b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.icon = UiTheme.tex("icon_%02d" % (i + 1))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			select_tab(idx))
		_tab_bar.add_child(b)
		_tab_buttons.append(b)


func select_tab(index: int) -> void:
	index = clampi(index, 0, _panels.size() - 1)
	if index == _current:
		_panels[index].call("refresh")
		return
	_current = index
	for i in _panels.size():
		_panels[i].visible = i == index
		_tab_buttons[i].add_theme_color_override(&"font_color",
			UiTheme.GOLD if i == index else UiTheme.TEXT)
	_panels[index].call("refresh")


func current_tab() -> int:
	return _current


func _refresh_top_bar() -> void:
	if _cards_label == null:
		return
	_cards_label.text = "Cartes %d/%d" % [SaveData.discovered_count(), ContentDB.cards.size()]
