extends Control
## Menu principal — coquille a onglets inspiree d Archero :
##
##   +--------------------------------------------------+
##   | [Niv 7]   ,~~ TIME WIZARD ~~,     [engrenage]    |  <- barre du haut
##   |           Cartes 39 / 45            REGLAGES     |
##   +--------------------------------------------------+
##   |                                                  |
##   |            panneau de l onglet actif             |
##   |                                                  |
##   +--------------------------------------------------+
##   | GALERIE | DECK | [CAMPAGNE] | MASSACRE | PROFIL   |  <- centre sureleve
##   +--------------------------------------------------+
##
## Les onglets changent le panneau sans changer de scene : la navigation est
## instantanee, comme sur mobile.

## QUATRE onglets, contre six auparavant.
##
##   - le BESTIAIRE a fusionne avec la GALERIE, qui est devenue un grimoire a
##     trois sections (Sorts / Passifs / Bestiaire) ;
##   - le PROFIL etait monte dans la barre du HAUT, derriere l avatar (il est
##     redescendu en vague 8, voir plus bas).
##
## 4 boutons sur 1080 px = 270 px chacun, au lieu de 170 : le nom de l onglet
## tient enfin en entier ("CAMPA" etait tronque sur la capture d avant).
##
## CINQ depuis le 29/09 (chantier M) : le MASSACRE, niveau infini a part, a son
## onglet. Place a DROITE du centre pour que la CAMPAGNE reste au milieu, deux
## onglets de chaque cote : c est la symetrie d Archero, et le pouce retrouve le
## centre sans regarder. 216 px par onglet : "MASSACRE" (8 lettres) tient a
## FONT_SMALL, verifie sur la capture menu_massacre.
##
## PROFIL ET REGLAGES ONT ECHANGE LEUR PLACE (vague 8, demande du co-auteur). Le
## profil redescend en 5e onglet, a la place des reglages : c est l ecran du
## joueur (son niveau, ses succes, ses cosmetiques), il revient le voir apres
## chaque partie, il merite un onglet sous le pouce. Les REGLAGES montent en haut
## a droite, derriere l engrenage : on les ouvre rarement, et c est la qu un
## joueur mobile cherche un engrenage. L ordre et les largeurs ne bougent pas :
## la campagne reste au centre, deux onglets de chaque cote.
const TABS: Array[String] = ["GALERIE", "DECK", "CAMPAGNE", "MASSACRE", "PROFIL"]
const HOME_TAB: int = 2

## Icone de chaque onglet. Retour du testeur : "utilise les bonnes icones pour
## les menus, PAS UN STEAK pour la campagne". Les `icon_01..12` de Tiny Swords
## sont un marteau, une buche, une piece, un steak, une epee... : du materiel de
## jeu de construction. On les remplace par des images qui disent l ecran :
##   - GALERIE  : la couverture du grimoire (pack magic book) ;
##   - DECK     : des cartes empilees ;
##   - CAMPAGNE : une carte au tresor marquee d une croix ;
##   - MASSACRE : l epee de Tiny Swords (icon_05), de la meme planche que
##                l engrenage des reglages : le combat sans fin, dit par l objet ;
##   - PROFIL   : la TETE DU MAGE, decoupee dans la planche du casting
##                (UiTheme.mage_head). L ancien avatar etait un visage
##                generique : le profil est celui du heros, on montre le heros.
## Les noms sont des cles de UiTheme.tex, sauf MAGE_HEAD_ICON (voir tab_icon).
const TAB_ICONS: Array[String] = ["tab_gallery", "tab_deck", "tab_campaign", "icon_05", "mage_head"]
## Cle d icone qui n est pas un fichier mais un decoupage de planche.
const MAGE_HEAD_ICON: String = "mage_head"
## L engrenage des reglages, en haut a droite (le seul `icon_*` qui convienne).
const SETTINGS_ICON: String = "icon_10"


## L onglet du profil, lu dans TABS : un index ecrit en dur mentirait le jour ou
## un onglet s ajoute.
static func profile_tab() -> int:
	return TABS.find("PROFIL")


## La texture d un onglet. Une fonction plutot que `UiTheme.tex` directement :
## l icone du profil n est pas un fichier, c est un morceau de planche.
static func tab_icon(key: String) -> Texture2D:
	if key == MAGE_HEAD_ICON:
		return UiTheme.mage_head()
	return UiTheme.tex(key)


@onready var _content: MarginContainer = %Content
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _cards_label: Label = %CardsLabel
@onready var _level_label: Label = %LevelLabel
@onready var _settings_button: Button = %SettingsButton
## La banniere du titre : elle CHANGE avec le niveau de compte (chantier L).
@onready var _title_ribbon: NinePatchRect = %TitleRibbon

var _panels: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _current: int = -1
var _settings_panel: SettingsPanel
var _settings_layer: PanelContainer


func _ready() -> void:
	theme = UiTheme.make()
	_build_panels()
	_build_tabs()
	_build_settings_layer()
	_settings_button.icon = UiTheme.tex(SETTINGS_ICON)
	# Idempotent : _ready peut etre rejoue si la scene est reinstanciee dans un test.
	if not SaveData.profile_changed.is_connected(_refresh_top_bar):
		SaveData.profile_changed.connect(_refresh_top_bar)
	if not _settings_button.pressed.is_connected(_toggle_settings):
		_settings_button.pressed.connect(_toggle_settings)
	_refresh_top_bar()
	select_tab(HOME_TAB)
	AudioBus.play_music(&"menu")


func _build_panels() -> void:
	_panels = [
		GalleryPanel.new(),
		DeckPanel.new(),
		CampaignPanel.new(),
		MassacrePanel.new(),
		ProfilePanel.new(),
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
			# PLUS LARGE aussi, pas seulement plus haut. A cinq onglets egaux
			# (211 px), "CAMPAGNE" en corps 36 etait coupe en "CAMPAG" sur la
			# capture menu_massacre. Mesure a l ecran : ~216 px de texte pour
			# "CAMPAGNE", ~161 px pour "MASSACRE" en corps 30, contour compris.
			# A 1,25 le centre prend ~251 px et les cotes ~201 px.
			b.size_flags_stretch_ratio = 1.25
		else:
			b.custom_minimum_size = Vector2(0, 160)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.icon = tab_icon(TAB_ICONS[i])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			select_tab(idx))
		_tab_bar.add_child(b)
		# Marges laterales reduites a 8 px (20 dans le theme) : a cinq onglets,
		# ce sont elles qui coupaient "MASSACR" meme avec le centre elargi. Le
		# haut et le bas gardent celles du theme, l icone ne bouge pas. APRES
		# l ajout a l arbre : avant, le bouton ne voit pas encore le theme du
		# menu et copierait la boite par defaut de Godot.
		_serrer_marges(b)
		_tab_buttons.append(b)


const TAB_SIDE_MARGIN: float = 8.0


func _serrer_marges(b: Button) -> void:
	for etat in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(etat)
		if sb == null:
			continue
		var copie: StyleBox = sb.duplicate()
		copie.content_margin_left = TAB_SIDE_MARGIN
		copie.content_margin_right = TAB_SIDE_MARGIN
		b.add_theme_stylebox_override(etat, copie)


## Les reglages en superposition PLEIN ECRAN sous la barre du haut : ils
## couvrent le panneau courant sans le detruire, donc on revient exactement ou
## on etait. C est le traitement qu avait le profil quand il etait en haut.
func _build_settings_layer() -> void:
	_settings_layer = PanelContainer.new()
	_settings_layer.visible = false
	_settings_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_settings_layer)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_settings_layer.add_child(box)

	# DANS UN DEFILEMENT : les reglages (audio, credits, mode testeur) sont plus
	# hauts que la zone de contenu. Poses tels quels, leur hauteur minimale
	# poussait la barre du haut et les onglets HORS de l ecran (vu sur capture :
	# plus d engrenage, plus de barre du bas, seul FERMER restait).
	var defile := ScrollContainer.new()
	defile.name = "SettingsScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(defile)
	_settings_panel = SettingsPanel.new()
	_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defile.add_child(_settings_panel)

	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 120)   # cible tactile
	close.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		show_settings(false))
	box.add_child(close)


func select_tab(index: int) -> void:
	index = clampi(index, 0, _panels.size() - 1)
	# Changer d onglet ferme les reglages : sinon ils resteraient poses par-dessus.
	show_settings(false)
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


## Les reglages, ouverts ou fermes. Pilotable par les tests et par le SMOKE, qui
## doit pouvoir les capturer sans simuler un toucher.
func show_settings(open: bool) -> void:
	if _settings_layer == null:
		return
	_settings_layer.visible = open
	if open:
		_settings_panel.refresh()
		_settings_button.add_theme_color_override(&"font_color", UiTheme.GOLD)
	else:
		_settings_button.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)


func settings_open() -> bool:
	return _settings_layer != null and _settings_layer.visible


func _toggle_settings() -> void:
	AudioBus.play_sfx(&"ui_tap")
	show_settings(not settings_open())


## Le profil est un ONGLET depuis la vague 8. Ces deux fonctions gardent le
## vocabulaire des appelants (smoke, tests) : ouvrir le profil = choisir son
## onglet ; le fermer = revenir a l accueil s il etait affiche.
func show_profile(open: bool) -> void:
	if open:
		select_tab(profile_tab())
	elif profile_open():
		select_tab(HOME_TAB)


func profile_open() -> bool:
	return _current == profile_tab() and not settings_open()


## Le compteur de cartes du haut : obtenues / VISIBLES, sorts et passifs
## (SaveData.card_counts). Il affichait "Cartes 8 / 64", tout le catalogue :
## la seule ligne de l ecran d accueil devoilait 50 cartes que la regle des
## trois etats rend invisibles (retouche du 30/09).
static func cards_counter_text() -> String:
	var n: Array = SaveData.card_counts()
	return "Cartes %d / %d" % [int(n[0]), int(n[1])]


## En-tete : le niveau de compte a gauche, le compteur de cartes sous le titre.
## Les deux viennent de SaveData, jamais d un compteur tenu par l interface.
func _refresh_top_bar() -> void:
	if _cards_label != null:
		_cards_label.text = cards_counter_text()
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
