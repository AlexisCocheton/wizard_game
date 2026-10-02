class_name PassiveSwapPanel
extends Control
## ECHANGE DE POUVOIR — un quatrieme passif est pris alors que les trois
## emplacements sont pleins (chantier W8).
##
##   +--------------------------------------------------+
##   |               NOUVEAU POUVOIR                    |
##   |                 [ la carte ]                     |  <- ce qu on gagne
##   |  Tu as deja trois pouvoirs : touche celui a      |
##   |  retirer.                                        |
##   |     [carte 1]    [carte 2]    [carte 3]          |  <- ce qu on perd
##   |      140 %        210 %        300 %             |
##   |         [ REFUSER : garder mes trois ]           |
##   +--------------------------------------------------+
##
## POURQUOI UN PANNEAU ET PLUS LE RAIL
## -----------------------------------
## Avant, le joueur touchait une pastille du rail qui clignotait, sans pause et
## sans refus possible. Et c etait FAUX : le rail trie ses pastilles par seuil,
## l indice touche etait passe tel quel a swap_passive(), qui compte en
## emplacements — toucher le passif du bas pouvait retirer celui du haut. Ici
## chaque carte porte SON emplacement (son indice dans RunState.equipped_passives),
## jamais une position a l ecran. Verrouille par test_level_up_w8.
##
## Les cartes et non des pastilles : remplacer un pouvoir est une decision qu on
## LIT (seuil, effet), et le rail n affiche ni l un ni l autre en entier. Le jeu
## est en pause pendant le choix (GameController.simulate), comme pour le choix
## de carte et l amelioration.

signal slot_chosen(slot: int)
signal refused()

const MIN_TOUCH: float = 96.0
const NEW_CARD_SIZE := Vector2(320.0, 430.0)
const SLOT_CARD_SIZE := Vector2(300.0, 420.0)

var _box: VBoxContainer = null
## Carte affichee pour chaque emplacement, dans l ORDRE DES EMPLACEMENTS.
var _slot_cards: Array[SpellCard] = []


func _ready() -> void:
	# Repond meme si l arbre est en pause, comme les autres ecrans modaux.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ancres ET offsets : sans offsets le panneau reste a (0,0) (piege deja vu
	# sur l ecran d amelioration).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP : un glissement de carte ne doit pas traverser l ecran de choix.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Affiche l echange : `card` est le passif gagne, `equipped` les passifs
## equipes DANS L ORDRE DES EMPLACEMENTS (RunState.equipped_passives).
func show_swap(card: SpellCard, equipped: Array[SpellCard]) -> void:
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_slot_cards = equipped.duplicate()
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 30.0
	_box.offset_right = -30.0
	_box.add_theme_constant_override(&"separation", 22)
	add_child(_box)
	_box.add_child(_ressort())
	_box.add_child(UiTheme.label("NOUVEAU POUVOIR", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	if card != null:
		var centre := CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var neuf := CardView.new()
		neuf.name = "Nouveau"
		neuf.setup_detail(card, NEW_CARD_SIZE.x, NEW_CARD_SIZE.y, 30, 22)
		# La nouvelle carte se LIT, elle ne se choisit pas : elle n avale pas le
		# doigt (un toucher dessus ne doit rien declencher).
		neuf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(neuf)
		_box.add_child(centre)
		_box.add_child(_seuil_label(card))
	_box.add_child(UiTheme.label("Tu as deja %d pouvoirs : touche celui a retirer."
		% _slot_cards.size(), UiTheme.FONT_BODY, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var rang := HBoxContainer.new()
	rang.alignment = BoxContainer.ALIGNMENT_CENTER
	rang.add_theme_constant_override(&"separation", 18)
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rang)
	for slot in _slot_cards.size():
		var p: SpellCard = _slot_cards[slot]
		if p == null:
			continue
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override(&"separation", 6)
		var cv := CardView.new()
		cv.name = "Equipe%d" % slot
		cv.setup_detail(p, SLOT_CARD_SIZE.x, SLOT_CARD_SIZE.y, 26, 20)
		# L EMPLACEMENT est capture ici, pas une position a l ecran.
		var s: int = slot
		cv.pressed.connect(func(_c: SpellCard) -> void: _choose(s))
		col.add_child(cv)
		col.add_child(_seuil_label(p))
		rang.add_child(col)

	var refuser := Button.new()
	refuser.name = "Refuser"
	refuser.text = "REFUSER : GARDER MES %d POUVOIRS" % _slot_cards.size()
	refuser.custom_minimum_size = Vector2(0, MIN_TOUCH)
	refuser.add_theme_font_override(&"font", UiTheme.font())
	refuser.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	# Cree par code, le panneau n herite pas du theme de la scene : sans cadre,
	# le bouton serait un texte nu (meme defaut corrige sur l ecran d amelioration).
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = Color(0.20, 0.17, 0.24, 0.92)
	cadre.border_color = Color(0.62, 0.58, 0.52)
	cadre.set_border_width_all(3)
	cadre.set_corner_radius_all(10)
	cadre.content_margin_left = 18.0
	cadre.content_margin_right = 18.0
	for etat in [&"normal", &"hover", &"pressed", &"focus"]:
		refuser.add_theme_stylebox_override(etat, cadre)
	refuser.add_theme_color_override(&"font_color", Color(0.88, 0.86, 0.82))
	refuser.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		refused.emit())
	_box.add_child(refuser)
	_box.add_child(_ressort())
	visible = true


## Les passifs proposes au retrait, dans l ordre des emplacements (tests).
func slot_cards() -> Array[SpellCard]:
	return _slot_cards.duplicate()


## Equivalent du toucher sur la carte de l emplacement `slot` (tests, smoke).
func press_slot(slot: int) -> void:
	_choose(slot)


func _choose(slot: int) -> void:
	AudioBus.play_sfx(&"card_pick")
	slot_chosen.emit(slot)


## Le SEUIL en clair sous chaque carte : c est la donnee qui decide le plus
## souvent lequel retirer (un pouvoir a 400 % ne s allume presque jamais).
func _seuil_label(p: SpellCard) -> Label:
	var l: Label = UiTheme.label("a partir de %d %%" % p.speed_threshold, UiTheme.FONT_SMALL,
		UiTheme.rarity_color(p.rarity), HORIZONTAL_ALIGNMENT_CENTER, false)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ressort() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
