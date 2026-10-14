class_name HandLevelPanel
extends Control
## « MONTE D UN NIVEAU UNE CARTE DE TA MAIN » (vague 10, chantier A1, cle
## hand_card_level) : le joueur touche un sort de sa main, qui recoit aussitot
## l XP de sa prochaine maturation (RunState.resolve_hand_level).
##
##   +--------------------------------------------------+
##   |              FAIS MURIR UN SORT                  |
##   |   Touche un sort de ta main : il murit tout de   |
##   |   suite (prochaine maturation).                  |
##   |     [carte]        [carte]        [carte]        |  <- sorts DISTINCTS
##   |  Maturation 1/5   Maturation 0/2  Maturation 2/5 |     de la main
##   |     [carte]        [carte]                       |
##   |               [ PASSER ]                         |
##   +--------------------------------------------------+
##
## Les CARTES et non une liste de noms : en combat la main est une rangee
## d icones, le joueur reconnait son sort a son image. Sous chaque carte, la
## maturation ou il en est et ce qui lui manque : c est ce qui decide le choix
## (faire murir le sort qui en est le plus loin, ou celui qu on joue le plus).
## Le jeu est fige pendant le choix (GameController.game_frozen_by_choice).
## PASSER consomme le choix sans effet : un ecran modal sans sortie bloquerait la
## partie si le joueur ne veut d aucune des cartes.

signal card_chosen(card: SpellCard)

const MIN_TOUCH: float = 96.0
const CARD_SIZE := Vector2(300.0, 400.0)
const COLUMNS: int = 3

var _box: VBoxContainer = null
var _cards: Array[SpellCard] = []


func _ready() -> void:
	# Repond meme si l arbre est en pause, comme les autres ecrans modaux.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ancres ET offsets : sans offsets le panneau reste a (0,0) (piege vu sur
	# l ecran d amelioration).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP : un glissement de carte ne doit pas traverser l ecran de choix.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func show_choices(cards: Array[SpellCard]) -> void:
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_cards = cards.duplicate()
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 30.0
	_box.offset_right = -30.0
	_box.add_theme_constant_override(&"separation", 22)
	add_child(_box)
	_box.add_child(_ressort())
	_box.add_child(UiTheme.label("FAIS MURIR UN SORT", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	_box.add_child(UiTheme.label(
		"Touche un sort de ta main : il atteint tout de suite sa prochaine maturation.",
		UiTheme.FONT_BODY, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(centre)
	var grille := GridContainer.new()
	grille.columns = mini(COLUMNS, maxi(_cards.size(), 1))
	grille.add_theme_constant_override(&"h_separation", 18)
	grille.add_theme_constant_override(&"v_separation", 18)
	grille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(grille)
	for i in _cards.size():
		var c: SpellCard = _cards[i]
		if c == null:
			continue
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override(&"separation", 6)
		var cv := CardView.new()
		cv.name = "Carte%d" % i
		cv.setup_detail(c, CARD_SIZE.x, CARD_SIZE.y, 26, 20)
		var choisie: SpellCard = c
		cv.pressed.connect(func(_x: SpellCard) -> void: _choose(choisie))
		col.add_child(cv)
		var l: Label = UiTheme.label(progress_text(c), UiTheme.FONT_SMALL, UiTheme.TEAL,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		l.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
		grille.add_child(col)

	var passer := Button.new()
	passer.name = "Passer"
	passer.text = "PASSER"
	passer.custom_minimum_size = Vector2(0, MIN_TOUCH)
	passer.add_theme_font_override(&"font", UiTheme.font())
	passer.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	# Cree par code, le panneau n herite pas du theme de la scene : sans cadre le
	# bouton serait un texte nu (defaut corrige sur l ecran d amelioration).
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Color(0.20, 0.17, 0.24, 0.92)
	cadre.border_color = Color(0.62, 0.58, 0.52)
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(10)
	cadre.content_margin_left = 18.0
	cadre.content_margin_right = 18.0
	for etat in [&"normal", &"hover", &"pressed", &"focus"]:
		passer.add_theme_stylebox_override(etat, cadre)
	passer.add_theme_color_override(&"font_color", Color(0.88, 0.86, 0.82))
	passer.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		card_chosen.emit(null))
	_box.add_child(passer)
	_box.add_child(_ressort())
	visible = true


## « Maturation 1 / 5 - manque 12 XP » : ou en est le sort, et ce que le choix
## lui donne.
static func progress_text(c: SpellCard) -> String:
	return "Maturation %d / %d - manque %d XP" % [RunState.maturations_done(c),
		RunState.upgrade_tiers_for(c), RunState.hand_level_xp_needed(c)]


## Les sorts proposes, dans l ordre de l ecran (tests).
func listed_cards() -> Array[SpellCard]:
	return _cards.duplicate()


## Equivalent du toucher sur la carte `i` (tests, smoke).
func press(i: int) -> void:
	if i >= 0 and i < _cards.size():
		_choose(_cards[i])


func _choose(c: SpellCard) -> void:
	AudioBus.play_sfx(&"card_pick")
	card_chosen.emit(c)


func _ressort() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
