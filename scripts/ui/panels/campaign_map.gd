class_name CampaignMap
extends ScrollContainer
## Carte de l archipel : les niveaux poses sur des iles volantes, relies par les
## chemins de `LevelDef.next_levels`.
##
##   +--------------------------------------------------+
##   |  ACTE I   Le Monde volant                        |
##   |               [ ile : Les Marches du Temps ]      |  <- rang 0
##   |                        |                          |
##   |               [ ile : La Tour des Sables  ]       |  <- rang 1
##   |  ...                                              |
##   |  ACTE III                                         |
##   |     [ ile : Forges ]        [ ile : Cour brisee ] |  <- rang 4, deux freres
##   |              \                    /               |
##   |               [ ile : Le Metier du Monde ]        |  <- rang 5
##   +--------------------------------------------------+
##
## POURQUOI une ScrollContainer et pas un Control fixe : 7 niveaux a 260 px de
## haut font 1800 px, ce qui depasse la zone de contenu du menu. Le defilement
## vertical est explicitement demande, et il encaisse les niveaux a venir sans
## qu on ait a re-serrer la mise en page a chaque ajout.
##
## POURQUOI les liens sont dessines par un Control dedie (`_links`) sous les iles :
## un trait entre deux points n est pas du decor, c est l INFORMATION elle-meme
## (quel niveau mene ou). Meme raisonnement que ZoneRing, DEC-015 : une texture
## etiree entre deux points arbitraires serait moins lisible qu un trait exact.

signal level_pressed(level_id: StringName)

## Geometrie de la carte. Les iles sont des cibles tactiles : 300x230 depasse
## largement les 90 px minimum, un doigt ne peut pas rater.
const ISLAND_W: float = 330.0
const ISLAND_H: float = 240.0
## Ecart vertical entre deux rangs : l ile (240) + le trait de liaison + la place
## d un bandeau d acte. En dessous, le bandeau se pose SUR l ile suivante.
const RANK_STEP: float = 360.0
## Marge du haut : la place du bandeau de l acte I, qui se pose AU-DESSUS de la
## premiere ile. Sans elle, « ACTE I » sort de la zone defilante.
const MARGIN_TOP: float = 190.0
const MAP_WIDTH: float = 1080.0
## Bandeau d acte : hauteur reservee au-dessus du premier niveau d un acte.
const ACT_BANNER_H: float = 60.0

const TERRAIN: String = "res://assets/terrain/"
## Colonne de depart du bloc 4x4 dans le tileset : 0 = bord clair (herbe),
## 5 = bord de pierre. Le pack n a pas de vraie feuille de sable, les deux
## fichiers sont identiques ; on distingue les terrains par le BORD de l ile.
const GRASS_BLOCK_X: int = 0
const SAND_BLOCK_X: int = 5
## Le pack Tiny Swords n a pas d icone d etoile. La piece d or (icon_03) est la
## seule pastille ronde qui se lit a 34 px, doree quand elle est acquise et
## eteinte sinon. On ne DESSINE pas une etoile : la regle du projet est de
## n utiliser que les assets fournis (DEC-012).
const STAR_ICON: int = 3

const ACT_NAMES: Dictionary = {
	1: "ACTE I  -  Le Monde volant",
	2: "ACTE II  -  Le Grand Cimetiere",
	3: "ACTE III  -  Le Monde demoniaque",
	4: "ACTE FINAL  -  Le Monde d origine",
}

## Un noeud de la carte : tout ce que les tests et le rendu ont besoin de savoir.
## Dictionnaire plutot qu une classe interne : il traverse `node_data()` sans
## qu un appelant puisse modifier l etat de la carte par reference.
var _nodes: Dictionary = {}          # StringName -> {level, rank, col, pos, stars, enabled}
var _links: Array = []               # [{from, to}]
var _order: Array[StringName] = []   # ids tries par rang puis colonne

var _canvas: Control
var _link_layer: Control
var _buttons: Dictionary = {}        # StringName -> Button


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Le doigt fait defiler : sur mobile c est le geste attendu, et il ne doit pas
	# etre confondu avec un appui sur une ile (Godot gere le seuil de glissement).
	follow_focus = true
	if _canvas == null:
		rebuild()


## Reconstruit entierement la carte depuis ContentDB + SaveData.
## Appelee a chaque `refresh()` du panneau : les etoiles et les verrous sont
## relus du profil, jamais memorises a cote.
func rebuild() -> void:
	_compute_graph()
	_build_view()


# --------------------------------------------------------------------------
# Graphe
# --------------------------------------------------------------------------

## Rang = profondeur dans l arborescence. On prend le rang MAXIMAL sur tous les
## chemins menant a un niveau : lvl_07 est atteint par lvl_05 ET lvl_06, il doit
## se poser SOUS les deux, pas sous le premier trouve.
func _compute_graph() -> void:
	_nodes.clear()
	_links.clear()
	_order.clear()

	var ids: Array = ContentDB.levels.keys()
	ids.sort()
	if ids.is_empty():
		return

	# Qui a un parent ? Ceux qui n en ont pas sont les racines.
	var has_parent: Dictionary = {}
	for id in ids:
		var lv: LevelDef = ContentDB.levels[id]
		for nxt in lv.next_levels:
			if ContentDB.levels.has(nxt):
				has_parent[nxt] = true
				_links.append({"from": lv.id, "to": StringName(nxt)})

	var rank: Dictionary = {}
	for id in ids:
		if not has_parent.has(id):
			rank[id] = 0

	# Relaxation : on repasse tant qu un rang augmente. Le graphe a 7 sommets,
	# le cout est nul, et cela tolere un ordre d ids quelconque. La borne de
	# passes est la taille du graphe : elle empeche une boucle infinie si un
	# jour un `next_levels` creait un cycle par erreur de contenu.
	for _pass in ids.size() + 1:
		var changed: bool = false
		for link: Dictionary in _links:
			if not rank.has(link["from"]):
				continue
			var candidate: int = int(rank[link["from"]]) + 1
			if candidate > int(rank.get(link["to"], -1)):
				rank[link["to"]] = candidate
				changed = true
		if not changed:
			break
	# Un niveau orphelin (ni racine ni cible) tomberait hors de la carte.
	for id in ids:
		if not rank.has(id):
			rank[id] = 0

	# Regroupement par rang pour repartir les colonnes.
	var by_rank: Dictionary = {}
	for id in ids:
		var r: int = int(rank[id])
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(id)

	var ranks: Array = by_rank.keys()
	ranks.sort()
	for r: int in ranks:
		var row: Array = by_rank[r]
		row.sort()
		for c in row.size():
			var id: StringName = StringName(row[c])
			var lv: LevelDef = ContentDB.levels[id]
			# Colonnes centrees : un seul niveau tombe au milieu, deux freres
			# s ecartent symetriquement de part et d autre.
			var span: float = MAP_WIDTH / float(row.size() + 1)
			var x: float = span * float(c + 1)
			var y: float = MARGIN_TOP + float(r) * RANK_STEP
			_nodes[id] = {
				"level": lv,
				"rank": r,
				"col": c,
				"pos": Vector2(x, y),
				"stars": SaveData.objectives_done_count(lv),
				"max_stars": lv.objectives.size(),
				"enabled": SaveData.is_level_unlocked(id),
				"cleared": SaveData.is_level_cleared(id),
			}
			_order.append(id)


# --------------------------------------------------------------------------
# Vue
# --------------------------------------------------------------------------

func _build_view() -> void:
	if _canvas != null:
		_canvas.queue_free()
	_buttons.clear()

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(MAP_WIDTH, _content_height())
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_canvas)

	# Couche des traits SOUS les iles : un chemin passe derriere l ile, pas devant.
	# Classe dediee et non `draw.connect` : Godot 4.4 refuse tout appel de dessin
	# qui ne vient pas du `_draw()` du noeud lui-meme, y compris depuis un
	# callable connecte au signal `draw` d un autre objet.
	_link_layer = LinkLayer.new()
	_link_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_link_layer as LinkLayer).segments = _link_segments()
	_canvas.add_child(_link_layer)

	var seen_acts: Dictionary = {}
	for id in _order:
		var data: Dictionary = _nodes[id]
		var lv: LevelDef = data["level"]
		# Bandeau d acte, pose une seule fois, au premier niveau de l acte.
		if lv.act > 0 and not seen_acts.has(lv.act):
			seen_acts[lv.act] = true
			# Centre dans l espace LIBRE au-dessus de l ile : le bandeau ne doit
			# jamais mordre sur le sol de l ile ni sur celle du rang precedent.
			_add_act_banner(lv.act, data["pos"].y - ISLAND_H * 0.5 - ACT_BANNER_H - 24.0)
		_add_island(id, data)


func _content_height() -> float:
	var max_y: float = MARGIN_TOP
	for id in _nodes:
		max_y = maxf(max_y, _nodes[id]["pos"].y)
	return max_y + ISLAND_H * 0.5 + 60.0


## Bandeau d acte : un titre sur une bande de bois du pack, pour qu il se
## detache du fond et se lise comme un separateur de chapitre et non comme une
## legende flottante posee sur l ile.
func _add_act_banner(act: int, y: float) -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override(&"panel", UiTheme.tex_box("wood", 40, 10.0))
	holder.position = Vector2(MAP_WIDTH * 0.18, y)
	holder.size = Vector2(MAP_WIDTH * 0.64, ACT_BANNER_H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(holder)

	var l: Label = UiTheme.label(String(ACT_NAMES.get(act, "ACTE %d" % act)),
		UiTheme.FONT_SMALL, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)


## Une ile = un Button (la cible tactile) qui porte le decor de tuiles, le nom
## et les etoiles. Le Button est la racine pour que TOUTE la surface reponde au
## doigt, y compris le sol de l ile.
func _add_island(id: StringName, data: Dictionary) -> void:
	var lv: LevelDef = data["level"]
	var enabled: bool = data["enabled"]

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ISLAND_W, ISLAND_H)
	b.size = Vector2(ISLAND_W, ISLAND_H)
	b.position = data["pos"] - Vector2(ISLAND_W, ISLAND_H) * 0.5
	b.disabled = not enabled
	# Un bouton desactive ne montre pas d infobulle ; on met la raison dans le
	# nom accessible, ce qui sert aussi au debogage des captures.
	b.tooltip_text = lv.display_name if enabled else "Verrouille"
	_canvas.add_child(b)
	_buttons[id] = b

	# Sol de l ile : les tuiles du terrain du niveau, donc l ile ressemble a ce
	# qu on va reellement jouer (grass = acte I et final, sand = le reste).
	# Elle occupe TOUTE la surface du bouton : le contour rocheux du tileset est
	# ce qui donne la silhouette d ile volante, il ne doit pas etre recouvert.
	var ground: Control = _build_ground(lv.terrain, enabled)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ground)

	# Cartouche papier du nom, pose sur le BAS de l ile : le haut reste de l herbe
	# visible, sinon l ile disparait sous son etiquette et ne se lit plus.
	var plate := PanelContainer.new()
	UiTheme.style_paper(plate, Color.WHITE if enabled else Color(0.80, 0.78, 0.82))
	plate.position = Vector2(10.0, ISLAND_H - 122.0)
	plate.size = Vector2(ISLAND_W - 20.0, 116.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(plate)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(vb)

	# Texte SOMBRE sur le papier clair, y compris verrouille : un gris pale sur
	# du papier ne se lit pas, et le joueur doit pouvoir lire ou il va.
	var name_text: String = lv.display_name if enabled else "? ? ?"
	var name_lbl: Label = UiTheme.label(name_text, 22,
		UiTheme.TEXT_DARK if enabled else Color(0.44, 0.34, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deux lignes au maximum : « Forges du Mauvais Temps » tient en deux lignes,
	# une troisieme chasserait les etoiles hors du papier.
	name_lbl.max_lines_visible = 2
	name_lbl.custom_minimum_size = Vector2(0, 58)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vb.add_child(name_lbl)

	# Etoiles : une par objectif, en icones du pack (jamais du texte ASCII, qui
	# ne se lit pas comme une note). Pleines = acquises, ternies = restantes.
	var stars: int = int(data["stars"])
	var max_stars: int = int(data["max_stars"])
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override(&"separation", 6)
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(star_row)
	for i in max_stars:
		var s: TextureRect = UiTheme.icon(STAR_ICON, 34.0)
		# Acquise : l or du cahier des charges. Restante : la meme icone eteinte,
		# pour que le joueur compte les etoiles qui lui manquent d un coup d oeil.
		s.modulate = UiTheme.GOLD if i < stars else Color(0.42, 0.36, 0.30, 0.55)
		star_row.add_child(s)

	# Le niveau ou en est le joueur porte un liseré : sur une carte de 7 iles il
	# faut un repere « tu es ici », sinon on cherche.
	if enabled and id == SaveData.current_level():
		var here := Panel.new()
		here.add_theme_stylebox_override(&"panel",
			UiTheme.flat_box(Color.TRANSPARENT, 14, 0.0, UiTheme.GOLD, 5))
		here.set_anchors_preset(Control.PRESET_FULL_RECT)
		here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(here)

	if enabled:
		var idx: StringName = id
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			level_pressed.emit(idx))


## Sol de l ile, decoupe dans le tileset du terrain. On reprend le bloc 3x3 du
## tileset comme `BattleBackdrop` : coins, bords, centre. Un niveau verrouille
## est assombri, pas cache : le joueur doit voir ou il va.
func _build_ground(terrain: String, enabled: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ISLAND_W, ISLAND_H)
	holder.size = Vector2(ISLAND_W, ISLAND_H)
	var tex: Texture2D = SheetLib.texture(TERRAIN + "tilemap_grass.png")
	if tex == null:
		return holder
	# Le tileset est un bloc 4x4 de tuiles de 64 avec un CONTOUR ROCHEUX complet
	# (colonnes 0-3 : bord clair, colonnes 5-8 : bord de pierre). C est ce contour
	# qui fait l ile volante ; on prend donc les tuiles de bord sur tout le tour
	# et les tuiles pleines au centre. Les deux feuilles du pack sont identiques
	# en herbe : la variante de bord sert a distinguer les terrains.
	var col0: int = SAND_BLOCK_X if terrain == "sand" else GRASS_BLOCK_X
	var cols: int = 5
	var rows: int = 4
	var tile: int = 64
	# Tuiles presque carrees : le contour rocheux du tileset est dessine pour une
	# case carree. L etirer en 110x80 ecrase les rochers et l ile redevient un
	# rectangle — c est ce que montrait la premiere capture.
	var cw: float = ISLAND_W / float(cols)
	var ch: float = ISLAND_H / float(rows)
	for r in rows:
		for c in cols:
			# Colonne / ligne de la tuile DANS le bloc 4x4 : bords aux extremites,
			# interieur repete au milieu.
			var tx: int = 1
			var ty: int = 1
			if c == 0: tx = 0
			elif c == cols - 1: tx = 3
			if r == 0: ty = 0
			elif r == rows - 1: ty = 3
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((col0 + tx) * tile, ty * tile, tile, tile)
			var tr := TextureRect.new()
			tr.texture = at
			tr.position = Vector2(float(c) * cw, float(r) * ch)
			tr.size = Vector2(cw, ch)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Verrouille : assombri et desature par modulation. L ile reste
			# VISIBLE — c est une carte, le joueur doit voir la suite du voyage.
			tr.modulate = Color.WHITE if enabled else Color(0.42, 0.44, 0.50)
			holder.add_child(tr)
	return holder


## Les chemins de l archipel, convertis en segments prets a dessiner. Un trait
## clair quand la suite est ouverte, sombre quand elle ne l est pas : le joueur
## lit son avancement sans compter les iles.
func _link_segments() -> Array:
	var out: Array = []
	for link: Dictionary in _links:
		if not _nodes.has(link["from"]) or not _nodes.has(link["to"]):
			continue
		var a: Vector2 = _nodes[link["from"]]["pos"] + Vector2(0.0, ISLAND_H * 0.42)
		var b: Vector2 = _nodes[link["to"]]["pos"] - Vector2(0.0, ISLAND_H * 0.42)
		var open: bool = bool(_nodes[link["to"]]["enabled"])
		var col: Color = UiTheme.GOLD if open else Color(0.35, 0.30, 0.28, 0.75)
		# Coude a mi-hauteur : une fourche se lit mieux en angles droits qu en
		# diagonale, surtout quand deux traits partent du meme point.
		var mid_y: float = (a.y + b.y) * 0.5
		out.append({"a": a, "b": Vector2(a.x, mid_y), "color": col})
		out.append({"a": Vector2(a.x, mid_y), "b": Vector2(b.x, mid_y), "color": col})
		out.append({"a": Vector2(b.x, mid_y), "b": b, "color": col})
	return out


## Couche de traits. Elle ne calcule rien : la carte lui donne des segments deja
## resolus, elle se contente de les tracer dans son propre `_draw()`.
class LinkLayer extends Control:
	const WIDTH: float = 8.0
	var segments: Array = []

	func _draw() -> void:
		for s: Dictionary in segments:
			draw_line(s["a"], s["b"], s["color"], WIDTH)


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


func rank_of(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("rank", -1))


func position_of(level_id: StringName) -> Vector2:
	return _nodes.get(level_id, {}).get("pos", Vector2.ZERO)


func stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("stars", 0))


func max_stars_for(level_id: StringName) -> int:
	return int(_nodes.get(level_id, {}).get("max_stars", 0))


func is_enabled(level_id: StringName) -> bool:
	return bool(_nodes.get(level_id, {}).get("enabled", false))


func link_count() -> int:
	return _links.size()


func has_link(from_id: StringName, to_id: StringName) -> bool:
	for link: Dictionary in _links:
		if link["from"] == from_id and link["to"] == to_id:
			return true
	return false


## Fait defiler la carte jusqu a une ile. Le joueur rouvre la campagne sur le
## niveau ou il en est, pas en haut d une carte de 1800 px.
##
## Le defilement est REPORTE d une frame : appele depuis `refresh()`, la
## ScrollContainer n a pas encore sa taille finale (`size.y` vaut 0), et le
## calcul de centrage renvoyait un decalage absurde — c est ce qui coupait le
## premier acte en haut de la capture.
func focus_level(level_id: StringName) -> void:
	if not _nodes.has(level_id) or not is_inside_tree():
		return
	var target_y: float = _nodes[level_id]["pos"].y
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	scroll_vertical = int(maxf(0.0, target_y - size.y * 0.5))
