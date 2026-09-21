extends Control
## Menu principal — coquille a onglets inspiree d Archero :
##
##   +--------------------------------------------------+
##   | [Niv 7]   ,~~ TIME WIZARD ~~,      [avatar]      |  <- barre du haut
##   |           Cartes 39 / 45            PROFIL       |
##   +--------------------------------------------------+
##   |                                                  |
##   |            panneau de l onglet actif             |
##   |                                                  |
##   +--------------------------------------------------+
##   | GALERIE |  DECK  | [CAMPAGNE] | REGLAGES         |  <- centre sureleve
##   +--------------------------------------------------+
##
## Les onglets changent le panneau sans changer de scene : la navigation est
## instantanee, comme sur mobile.

## QUATRE onglets, contre six auparavant.
##
##   - le BESTIAIRE a fusionne avec la GALERIE, qui est devenue un grimoire a
##     trois sections (Sorts / Passifs / Bestiaire) ;
##   - le PROFIL est monte dans la barre du HAUT, derriere l avatar : c est
##     l ecran qu on ouvre pour se regarder, pas pour jouer, et il n a rien a
##     faire dans la zone du pouce a cote du bouton JOUER.
##
## 4 boutons sur 1080 px = 270 px chacun, au lieu de 170 : le nom de l onglet
## tient enfin en entier ("CAMPA" etait tronque sur la capture d avant).
const TABS: Array[String] = ["GALERIE", "DECK", "CAMPAGNE", "REGLAGES"]
const HOME_TAB: int = 2

## Icone de chaque onglet. Retour du testeur : "utilise les bonnes icones pour
## les menus, PAS UN STEAK pour la campagne". Les `icon_01..12` de Tiny Swords
## sont un marteau, une buche, une piece, un steak, une epee... : du materiel de
## jeu de construction. On les remplace par des images qui disent l ecran :
##   - GALERIE  : la couverture du grimoire (pack magic book) ;
##   - DECK     : des cartes empilees ;
##   - CAMPAGNE : une carte au tresor marquee d une croix ;
##   - REGLAGES : l engrenage, le seul `icon_*` qui convienne (icon_10).
const TAB_ICONS: Array[String] = ["tab_gallery", "tab_deck", "tab_campaign", "icon_10"]

## Le panneau PROFIL n est plus un onglet mais une superposition, ouverte par
## l avatar en haut a droite. Il se ferme par son propre bouton.
const PROFILE_TAB: int = -1

@onready var _content: MarginContainer = %Content
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _cards_label: Label = %CardsLabel
@onready var _level_label: Label = %LevelLabel
@onready var _profile_button: Button = %ProfileButton
## La banniere du titre : elle CHANGE avec le niveau de compte (chantier L).
@onready var _title_ribbon: NinePatchRect = %TitleRibbon

var _panels: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _current: int = -1
var _profile_panel: ProfilePanel
var _profile_layer: PanelContainer


func _ready() -> void:
	theme = UiTheme.make()
	_build_panels()
	_build_tabs()
	_build_profile_layer()
	# Idempotent : _ready peut etre rejoue si la scene est reinstanciee dans un test.
	if not SaveData.profile_changed.is_connected(_refresh_top_bar):
		SaveData.profile_changed.connect(_refresh_top_bar)
	if not _profile_button.pressed.is_connected(_toggle_profile):
		_profile_button.pressed.connect(_toggle_profile)
	_refresh_top_bar()
	select_tab(HOME_TAB)
	AudioBus.play_music(&"menu")


func _build_panels() -> void:
	_panels = [
		GalleryPanel.new(),
		DeckPanel.new(),
		CampaignPanel.new(),
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
		b.clip_text = true
		# L onglet central est plus grand et depasse vers le haut : c est
		# la signature visuelle d Archero, le "home" se repere au pouce.
		if i == HOME_TAB:
			b.custom_minimum_size = Vector2(0, 210)
			b.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
		else:
			b.custom_minimum_size = Vector2(0, 160)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.icon = UiTheme.tex(TAB_ICONS[i])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			select_tab(idx))
		_tab_bar.add_child(b)
		_tab_buttons.append(b)


## Le profil en superposition PLEIN ECRAN sous la barre du haut : il couvre le
## panneau courant sans le detruire, donc on revient exactement ou on etait.
func _build_profile_layer() -> void:
	_profile_layer = PanelContainer.new()
	_profile_layer.visible = false
	_profile_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_profile_layer)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_profile_layer.add_child(box)

	_profile_panel = ProfilePanel.new()
	_profile_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_profile_panel)

	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 120)   # cible tactile
	close.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		show_profile(false))
	box.add_child(close)


func select_tab(index: int) -> void:
	index = clampi(index, 0, _panels.size() - 1)
	# Changer d onglet ferme le profil : sinon il resterait pose par-dessus.
	show_profile(false)
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


## Le profil, ouvert ou ferme. Pilotable par les tests et par le SMOKE, qui doit
## pouvoir le capturer sans simuler un toucher.
func show_profile(open: bool) -> void:
	if _profile_layer == null:
		return
	_profile_layer.visible = open
	if open:
		_profile_panel.refresh()
		_profile_button.add_theme_color_override(&"font_color", UiTheme.GOLD)
	else:
		_profile_button.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)


func profile_open() -> bool:
	return _profile_layer != null and _profile_layer.visible


func _toggle_profile() -> void:
	AudioBus.play_sfx(&"ui_tap")
	show_profile(not profile_open())


## En-tete : le niveau de compte a gauche, le compteur de cartes sous le titre.
## Les deux viennent de SaveData, jamais d un compteur tenu par l interface.
func _refresh_top_bar() -> void:
	if _cards_label != null:
		_cards_label.text = "Cartes %d / %d" % [
			SaveData.discovered_count(), ContentDB.cards.size()]
	if _level_label != null:
		_level_label.text = "Niv.\n%d" % SaveData.account_level()
	# La banniere du titre suit le NIVEAU DE COMPTE : bois, argent, or, cristal.
	# C est la recompense la plus visible du compte — elle se voit a l ouverture
	# du jeu, sans ouvrir le moindre ecran, et c est ce que le testeur demandait.
	# Les paliers vivent dans UiTheme.BANNER_TIERS, jamais ici : le profil affiche
	# le meme palier, et deux listes se seraient contredites.
	if _title_ribbon != null:
		var banniere: Texture2D = UiTheme.tex(UiTheme.banner_for_level(SaveData.account_level()))
		if banniere != null:
			_title_ribbon.texture = banniere
