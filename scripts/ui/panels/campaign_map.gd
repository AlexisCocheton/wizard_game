class_name CampaignMap
extends Control
## Carte de campagne : UN ECRAN PAR ACTE, pose sur le fond de combat de l acte.
##
##   +--------------------------------------------------+
##   |  ####  bande decoree du fond de l acte  ########  |
##   |                                                   |
##   |         ACTE II  -  Le Grand Cimetiere            |
##   | +-+                                         +-+   |
##   | |<|     (o) Ossuaire des Marees             |>|   |
##   | +-+     * * .                               +-+   |
##   |                                                   |
##   |              (o) Le Grand Appel                   |
##   |              . . .                                |
##   |                                                   |
##   |  ####  premier plan du fond  ###################   |
##   +--------------------------------------------------+
##
## POURQUOI un ecran par acte et non plus un defilement vertical : demande du
## testeur, mot pour mot — « utilise les fonds de combat pour l image de fond de
## l acte, change d acte avec les fleches ». Un fond peint ne se defile pas : il
## est compose pour 1080x1920 (bande decoree en haut, sol au milieu, premier plan
## en bas). Le faire glisser sous une colonne d iles le decoupe n importe ou.
##
## POURQUOI un Control et non plus une ScrollContainer : il n y a plus rien a
## faire defiler. Un acte tient dans un ecran, et c est precisement ce qui rend
## la navigation par fleches lisible — on voit d un coup tout l acte.
##
## POURQUOI le fond vient de `LevelDef.backdrop` et non d une table dans l UI :
## le combat de lvl_03 et le point de lvl_03 sur la carte doivent montrer le meme
## lieu. Deux tables finiraient par diverger a la premiere reorganisation des
## actes ; ici la carte lit la meme donnee que `BattleBackdrop`.

signal level_pressed(level_id: StringName)

## Un point de niveau. 96 px de diametre, mais la CIBLE TACTILE est le bouton qui
## le porte (DOT_HIT), largement au-dessus des 90 px du cahier des charges : le
## joueur vise le point ET son etiquette.
const DOT_SIZE: float = 96.0
const DOT_HIT_W: float = 420.0
const DOT_HIT_H: float = 190.0

## Bande utilisable du fond, en fraction de la hauteur de l ecran. Les fonds ont
## une bande DECOREE en haut (arbres, grilles, vitraux) et un PREMIER PLAN en bas
## (herbes hautes, dalles). Un point pose dedans se noie dans le decor : ces deux
## bornes delimitent le SOL, ou un point et son nom restent lisibles.
## Le haut est fixe par le TITRE de l acte (qui occupe jusqu a ~0.07) plus la
## bande decoree ; le bas par le premier plan, qui commence vers 0.85 sur les
## quatre fonds composes. Verifie a l oeil sur les 5 captures `map_acte*.png`.
const GROUND_TOP: float = 0.24
const GROUND_BOTTOM: float = 0.83

## Largeur reservee aux fleches sur chaque bord. Un point sous une fleche serait
## inatteignable : les positions sont contraintes a l interieur.
const SIDE_MARGIN: float = 150.0

## Fleches de changement d acte : 120x170, bien au-dela des 90 px minimum, et
## collees aux BORDS de l ecran — c est la ou tombe naturellement le pouce.
const ARROW_W: float = 120.0
const ARROW_H: float = 170.0

## Fond de repli quand l acte n a aucun niveau (donc aucun `backdrop` a lire).
## L acte 5 existe dans l histoire mais n a pas encore de niveau : il doit tout
## de meme s afficher, sinon le joueur croit que le jeu s arrete a l acte 4.
const ACT_BACKDROPS: Dictionary = {
	1: "act1_sky",
	2: "act2_graveyard",
	3: "act3_demon",
	4: "act4_origin",
	5: "act5_divine",
}
const BACKDROP_DIR: String = "res://assets/backdrops/"
const FALLBACK_BACKDROP: String = "menu_space"

## Le pack Tiny Swords n a pas d icone d etoile. La piece d or (icon_03) est la
## seule pastille ronde qui se lit a 34 px, doree quand elle est acquise et
## eteinte sinon. On ne DESSINE pas une etoile : la regle du projet est de
## n utiliser que les assets fournis (DEC-012).
const STAR_ICON: int = 3

## Jaune du point jouable — l or du cahier des charges, demande mot pour mot
## (« des points de couleur jaune, qui sont grises quand pas encore debloques »).
const DOT_OPEN: Color = Color(0.95, 0.80, 0.35)
const DOT_LOCKED: Color = Color(0.42, 0.42, 0.46)

const ACT_NAMES: Dictionary = {
	1: "ACTE I  -  Le Monde volant",
	2: "ACTE II  -  Le Grand Cimetiere",
	3: "ACTE III  -  Le Monde demoniaque",
	4: "ACTE IV  -  Le Monde d origine",
	5: "ACTE V  -  L espace divin",
}

## Message d un acte encore vide. Il dit la VERITE (le contenu n existe pas
## encore) plutot que de laisser un ecran nu que le joueur lirait comme un bug.
const EMPTY_NOTICE: String = "Le voyage ne va pas encore jusqu ici."

## Etat calcule : acte -> [ids ordonnes], et id -> donnees du point.
var _by_act: Dictionary = {}          # int -> Array[StringName]
var _nodes: Dictionary = {}           # StringName -> {level, pos, stars, max_stars, enabled}
var _acts: Array[int] = []
var _act: int = 0

var _backdrop: TextureRect
var _title: Label
var _empty_lbl: Label
var _layer: Control                   # porte les points ; vide a chaque changement d acte
var _prev_btn: Button
var _next_btn: Button
var _buttons: Dictionary = {}         # StringName -> Button


func _ready() -> void:
	clip_contents = true
	if _backdrop == null:
		rebuild()
	# Un changement de taille (rotation, redimension du menu) replace les points :
	# ils sont exprimes en fraction de la taille, pas en pixels figes.
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	_layout_dots()


## Reconstruit entierement la carte depuis ContentDB + SaveData.
## Appelee a chaque `refresh()` du panneau : les etoiles et les verrous sont
## relus du profil, jamais memorises a cote.
func rebuild() -> void:
	_compute()
	_build_shell()
	# On rouvre sur l acte du niveau en cours : avec 5 actes, retomber sur l acte I
	# a chaque retour obligerait a quatre appuis pour revenir ou on en est.
	show_act(_act_of_current_level())


# --------------------------------------------------------------------------
# Donnees
# --------------------------------------------------------------------------

func _compute() -> void:
	_by_act.clear()
	_nodes.clear()
	_acts.clear()

	# ORDRE DE LECTURE DE L ACTE. Mesure sur 4.4.stable : `sort()` sur l `Array`
	# NON TYPE rendu par `Dictionary.keys()` ne trie PAS des StringName de facon
	# fiable — il a rendu [lvl_02..lvl_07, lvl_01], et l acte I affichait « La
	# Tour des Sables » AU-DESSUS de « Les Marches du Temps » : le joueur lisait
	# son voyage a l envers. Le resultat dependait en plus du contexte d appel,
	# donc le defaut apparaissait a l ecran sans apparaitre au test.
	# On compare explicitement les valeurs en String : plus rien a deviner.
	var ids: Array[StringName] = []
	for k in ContentDB.levels.keys():
		ids.append(StringName(k))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		var lv: LevelDef = ContentDB.levels[id]
		var a: int = lv.act
		if not _by_act.has(a):
			_by_act[a] = []
		(_by_act[a] as Array).append(StringName(id))
		_nodes[StringName(id)] = {
			"level": lv,
			"act": a,
			"pos": Vector2.ZERO,
			"stars": SaveData.objectives_done_count(lv),
			"max_stars": lv.objectives.size(),
			"enabled": SaveData.is_level_unlocked(id),
		}

	# Les actes affichables sont ceux du contenu UNION ceux de l histoire : l acte
	# 5 est ecrit mais n a pas encore de niveau, et le joueur doit voir qu il y a
	# une suite. C est exactement la demande « un acte ... reste visible ».
	var seen: Dictionary = {}
	for a in _by_act.keys():
		if int(a) > 0:
			seen[int(a)] = true
	for a in ACT_BACKDROPS.keys():
		seen[int(a)] = true
	_acts = []
	for a in seen.keys():
		_acts.append(int(a))
	_acts.sort()


func _act_of_current_level() -> int:
	var cur: StringName = SaveData.current_level()
	if _nodes.has(cur):
		return int(_nodes[cur]["act"])
	return _acts[0] if not _acts.is_empty() else 1


# --------------------------------------------------------------------------
# Vue : la coquille (fond, titre, fleches) ne se reconstruit qu au rebuild ;
# seuls les POINTS changent quand on tourne les pages.
# --------------------------------------------------------------------------

func _build_shell() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()

	# 1) le fond de l acte, en pleine surface. COVERED : le fond est compose pour
	# 1080x1920 et la zone de contenu du menu est plus courte ; l etirer libre
	# ecraserait les arbres. On rogne plutot que de deformer.
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# 2) le titre de l acte. Contour sombre (label_hud) : le fond est un decor
	# PEINT dont on ne maitrise pas la couleur sous le texte — l acte I est un
	# ciel clair, l acte III une salle sombre. C est le piege connu du projet.
	_title = UiTheme.label_hud("", UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 24.0
	_title.offset_bottom = 90.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	# 3) la couche des points, videe a chaque changement d acte.
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	# 4) le message d acte vide, au centre du sol.
	_empty_lbl = UiTheme.label_hud(EMPTY_NOTICE, UiTheme.FONT_BODY,
		Color(0.88, 0.86, 0.92), HORIZONTAL_ALIGNMENT_CENTER, true)
	_empty_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_empty_lbl.anchor_left = 0.12
	_empty_lbl.anchor_right = 0.88
	_empty_lbl.anchor_top = 0.45
	_empty_lbl.anchor_bottom = 0.45
	_empty_lbl.offset_left = 0.0
	_empty_lbl.offset_right = 0.0
	_empty_lbl.offset_bottom = 140.0
	_empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_lbl.visible = false
	add_child(_empty_lbl)

	# 5) les fleches, PAR-DESSUS tout le reste : ce sont elles qui doivent gagner
	# le toucher sur les bords, jamais un point qui deborderait.
	_prev_btn = _make_arrow("<", false)
	_next_btn = _make_arrow(">", true)


## Une fleche de bord. Ancrage sur le bord et centrage vertical : elle reste au
## meme endroit quelle que soit la hauteur reelle de la zone de contenu.
func _make_arrow(glyph: String, at_right: bool) -> Button:
	var b := Button.new()
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW_W, ARROW_H)
	b.add_theme_font_size_override(&"font_size", 64)
	# Bois du pack, comme les autres commandes de navigation du menu : une fleche
	# sans fond disparaitrait sur la bande decoree de certains actes.
	b.add_theme_stylebox_override(&"normal", UiTheme.tex_box("wood", 40, 6.0))
	b.add_theme_stylebox_override(&"hover", UiTheme.tex_box("wood", 40, 6.0, Color(1.15, 1.15, 1.15)))
	b.add_theme_stylebox_override(&"pressed", UiTheme.tex_box("wood", 40, 6.0, Color(0.8, 0.8, 0.8)))
	b.add_theme_stylebox_override(&"disabled", UiTheme.tex_box("wood", 40, 6.0, Color(0.5, 0.5, 0.55, 0.6)))
	b.add_theme_color_override(&"font_color", UiTheme.GOLD)
	b.add_theme_color_override(&"font_disabled_color", Color(0.6, 0.58, 0.55, 0.7))
	b.set_anchors_preset(Control.PRESET_CENTER_RIGHT if at_right else Control.PRESET_CENTER_LEFT)
	b.offset_top = -ARROW_H * 0.5
	b.offset_bottom = ARROW_H * 0.5
	if at_right:
		b.offset_left = -ARROW_W - 8.0
		b.offset_right = -8.0
	else:
		b.offset_left = 8.0
		b.offset_right = ARROW_W + 8.0
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		if at_right: go_next() else: go_previous())
	add_child(b)
	return b


# --------------------------------------------------------------------------
# Navigation entre actes
# --------------------------------------------------------------------------

func acts() -> Array[int]:
	return _acts.duplicate()


func current_act() -> int:
	return _act


func act_title(act: int) -> String:
	return String(ACT_NAMES.get(act, "ACTE %d" % act))


func empty_notice() -> String:
	return EMPTY_NOTICE


func levels_in_act(act: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _by_act.get(act, []):
		out.append(StringName(id))
	return out


## Un acte est « ouvert » des qu UN de ses niveaux est jouable. Ferme, il reste
## affiche et atteignable : le joueur doit voir qu il y a une suite.
func act_is_open(act: int) -> bool:
	for id in levels_in_act(act):
		if bool(_nodes[id]["enabled"]):
			return true
	return false


func can_go_previous() -> bool:
	return _acts.find(_act) > 0


func can_go_next() -> bool:
	var i: int = _acts.find(_act)
	return i >= 0 and i < _acts.size() - 1


## Les bornes sont INERTES plutot que bouclantes : un joueur qui appuie une fois
## de trop a droite ne doit pas se retrouver a l acte I sans avoir rien compris.
func go_next() -> void:
	if can_go_next():
		show_act(_acts[_acts.find(_act) + 1])


func go_previous() -> void:
	if can_go_previous():
		show_act(_acts[_acts.find(_act) - 1])


func show_act(act: int) -> void:
	_act = act
	if _backdrop == null:
		return
	_backdrop.texture = SheetLib.texture(BACKDROP_DIR + backdrop_for_act(act) + ".png")
	_title.text = act_title(act)
	if _prev_btn != null:
		_prev_btn.disabled = not can_go_previous()
		_next_btn.disabled = not can_go_next()
	_build_dots()


## Le fond de l acte se LIT dans les niveaux de cet acte, pas dans une table de
## l UI : combat et carte montrent alors forcement le meme lieu. La table
## `ACT_BACKDROPS` n est qu un repli pour un acte encore sans niveau.
func backdrop_for_act(act: int) -> String:
	for id in levels_in_act(act):
		var lv: LevelDef = _nodes[id]["level"]
		if lv.backdrop != "":
			return lv.backdrop
	return String(ACT_BACKDROPS.get(act, FALLBACK_BACKDROP))


# --------------------------------------------------------------------------
# Les points
# --------------------------------------------------------------------------

## Place les points de l acte courant sur le sol du fond. Le calcul est separe de
## la construction pour qu un simple redimensionnement les replace sans
## reconstruire les boutons (et donc sans recasser les connexions).
func _layout_dots() -> void:
	var ids: Array[StringName] = levels_in_act(_act)
	if ids.is_empty():
		return
	var w: float = maxf(size.x, 1.0)
	var h: float = maxf(size.y, 1.0)
	# Repartition sur la hauteur du sol : le premier niveau de l acte en haut, le
	# dernier en bas — on lit l acte dans le sens de la marche, du fond vers soi.
	var top: float = h * GROUND_TOP
	var bottom: float = h * GROUND_BOTTOM
	var step: float = (bottom - top) / float(maxi(ids.size(), 1))
	# Zigzag horizontal : deux niveaux d affilee au meme x donneraient une colonne,
	# ou le nom du second passerait sous le point du premier. L amplitude est
	# bornee par SIDE_MARGIN pour ne jamais passer sous une fleche.
	#
	# UN SEUL niveau dans l acte (cas de l acte IV) : pas de zigzag du tout. Le
	# decaler le collait contre une fleche, ce qui etait pire que la colonne que
	# le zigzag cherche a eviter. Vu sur la capture `map_acte4.png`.
	var amp: float = 0.0
	if ids.size() > 1:
		amp = minf(w * 0.16, maxf((w - 2.0 * SIDE_MARGIN - DOT_HIT_W) * 0.5, 0.0))
	for i in ids.size():
		var id: StringName = ids[i]
		var y: float = top + step * (float(i) + 0.5)
		var x: float = w * 0.5 + (amp if i % 2 == 1 else -amp)
		var pos := Vector2(x, y)
		_nodes[id]["pos"] = pos
		var b: Button = _buttons.get(id)
		if b != null:
			b.position = pos - Vector2(DOT_HIT_W, DOT_HIT_H) * 0.5


func _build_dots() -> void:
	if _layer == null:
		return
	for c in _layer.get_children():
		_layer.remove_child(c)
		c.queue_free()
	_buttons.clear()

	var ids: Array[StringName] = levels_in_act(_act)
	_empty_lbl.visible = ids.is_empty()
	for id in ids:
		_add_dot(id)
	_layout_dots()


## Un point = un Button transparent de 420x190 qui porte la pastille, le nom et
## les etoiles. Le bouton est la racine pour que TOUTE l etiquette reponde au
## doigt, pas seulement la pastille de 96 px.
func _add_dot(id: StringName) -> void:
	var data: Dictionary = _nodes[id]
	var lv: LevelDef = data["level"]
	var enabled: bool = bool(data["enabled"])

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(DOT_HIT_W, DOT_HIT_H)
	b.custom_minimum_size = b.size
	b.disabled = not enabled
	# Un bouton desactive ne montre pas d infobulle ; on met la raison dans le
	# nom accessible, ce qui sert aussi au debogage des captures.
	b.tooltip_text = lv.display_name if enabled else "Verrouille"
	_layer.add_child(b)
	_buttons[id] = b

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override(&"separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)

	# LA PASTILLE. Jaune quand jouable, grise sinon : la demande litterale du
	# testeur. Un Panel rond plutot qu une icone du pack : aucune icone ronde
	# unie n existe dans les feuilles, et un point est une forme, pas un dessin.
	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(dot_row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
	# Bord sombre epais : sur le ciel clair de l acte I comme sur les dalles
	# sombres de l acte III, c est le contour qui detache la pastille du fond.
	dot.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
		DOT_OPEN if enabled else DOT_LOCKED, int(DOT_SIZE * 0.5), 0.0,
		Color(0.10, 0.07, 0.05, 0.95), 7))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_row.add_child(dot)

	# Le niveau ou en est le joueur porte un halo : sur un acte de 3 points il
	# faut un repere « tu es ici », sinon on cherche.
	if enabled and id == SaveData.current_level():
		var here := Panel.new()
		here.add_theme_stylebox_override(&"panel", UiTheme.flat_box(
			Color.TRANSPARENT, int(DOT_SIZE * 0.62), 0.0, Color(1.0, 0.95, 0.6, 0.85), 5))
		here.set_anchors_preset(Control.PRESET_FULL_RECT)
		here.offset_left = -14.0
		here.offset_top = -14.0
		here.offset_right = 14.0
		here.offset_bottom = 14.0
		here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(here)

	# LE NOM, en contour sombre : le fond est peint et sa couleur sous le texte
	# n est pas maitrisee. Un texte clair sans contour disparait sur le ciel de
	# l acte I — c est le piege deja paye sur le HUD.
	#
	# Le nom est ecrit MEME VERROUILLE, juste plus terne. Le testeur demande
	# « on voit les noms des etapes » : masquer en « ? ? ? » repondrait a la
	# question inverse, et une carte dont les etapes n ont pas de nom ne donne
	# plus envie d y aller.
	var name_lbl: Label = UiTheme.label_hud(lv.display_name, UiTheme.FONT_SMALL,
		Color(1.0, 0.97, 0.90) if enabled else Color(0.74, 0.74, 0.78),
		HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	# LES ETOILES : une par objectif, en icones du pack (jamais du texte ASCII,
	# qui ne se lit pas comme une note). Pleines = acquises, ternies = restantes.
	var stars: int = int(data["stars"])
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override(&"separation", 8)
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(star_row)
	for i in int(data["max_stars"]):
		var acquise: bool = i < stars
		# MESURE, pas impression : sur la capture de l acte I, une pastille
		# acquise rendait rgb(171,148,54) et une vide rgb(149,152,78). Un ecart
		# aussi faible ne se lit pas sur de l herbe, et la teinte grise prenait
		# la couleur du fond. Les deux etats se distinguent donc par le
		# CONTRASTE et la TAILLE, pas par la seule teinte : la pastille acquise
		# est pleine, doree et plus grande ; la vide est un creux sombre et
		# reduit. Un joueur daltonien compte alors ses etoiles a la forme.
		var s: TextureRect = UiTheme.icon(STAR_ICON, 40.0 if acquise else 30.0)
		if acquise:
			s.modulate = Color(1.0, 0.88, 0.35)
		else:
			# Sombre et translucide : un CREUX. Il reste visible sur les fonds
			# clairs comme sur les fonds sombres, sans jamais passer pour de l or.
			s.modulate = Color(0.22, 0.20, 0.18, 0.55)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star_row.add_child(s)

	if enabled:
		var idx: StringName = id
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			level_pressed.emit(idx))


# --------------------------------------------------------------------------
# Lecture (utilisee par le panneau et par les tests)
# --------------------------------------------------------------------------

func node_count() -> int:
	return _nodes.size()


func has_node_for(level_id: StringName) -> bool:
	return _nodes.has(level_id)


func label_for(level_id: StringName) -> String:
	if not _nodes.has(level_id):
		return ""
	return (_nodes[level_id]["level"] as LevelDef).display_name


## Position du point. Pour un niveau qui n est pas sur l acte affiche, on calcule
## la position qu il AURAIT : les tests verifient le placement de tous les actes
## sans avoir a tourner les pages, et le resultat est le meme.
func position_of(level_id: StringName) -> Vector2:
	if not _nodes.has(level_id):
		return Vector2.ZERO
	var pos: Vector2 = _nodes[level_id]["pos"]
	if pos != Vector2.ZERO:
		return pos
	var memo: int = _act
	_act = int(_nodes[level_id]["act"])
	_layout_dots()
	_act = memo
	return _nodes[level_id]["pos"]


func stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("stars", 0))


func max_stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("max_stars", 0))


func is_enabled(level_id: StringName) -> bool:
	return bool(_nodes.get(level_id, {}).get("enabled", false))


## Amene le joueur sur l acte d un niveau. Remplace l ancien `focus_level`, qui
## faisait defiler une carte verticale qui n existe plus.
func focus_level(level_id: StringName) -> void:
	if _nodes.has(level_id):
		show_act(int(_nodes[level_id]["act"]))
