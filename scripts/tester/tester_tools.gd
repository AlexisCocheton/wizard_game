class_name TesterTools
extends Control
## L ATELIER DU TESTEUR — page dediee, ouverte depuis les Reglages en mode testeur.
##
##   +--------------------------------------------------+
##   | [< MENU]        ATELIER DU TESTEUR               |
##   | SORTS | MONSTRES | NIVEAUX | TEST | DOCUMENT       |
##   | Mode testeur ACTIF : 3 reglages joues            |
##   | +----------------------------------------------+ |
##   | | [rechercher..........................]       | |  liste
##   | | [portrait] Gnome          gnome  P1  *       | |   ou
##   | | ...                                          | |  fiche
##   | +----------------------------------------------+ |
##   +--------------------------------------------------+
##
## UNE SCENE A PART et non un onglet des Reglages : la colonne des reglages n a
## pas de defilement, et une fiche de monstre fait cent lignes. Le menu principal
## n est pas touche ; on y revient par "< MENU".
##
## Toute la page est construite en code, comme le menu : les listes viennent de
## ContentDB, les fiches de l introspection des Resources (TesterSheet).

const TABS: Array = [
	["sorts", "SORTS"], ["monstres", "MONSTRES"], ["niveaux", "NIVEAUX"],
	["test", "TEST"], ["document", "DOC"],
]
const TOUCH: float = TesterField.TOUCH
const ROW_H: float = 120.0

## Onglet et recherche gardes d une visite a l autre : revenir d une partie de
## test ou du menu ne doit pas faire tout rechercher a nouveau.
static var last_tab: String = "monstres"
static var last_search: Dictionary = {}

var _tab: String = ""
var _detail: String = ""
var _scroll: ScrollContainer
var _body: VBoxContainer
var _status: Label
var _toast: Label
var _tab_buttons: Dictionary = {}
var _picker: Control = null
var _rows: Array = []   # [[Button, texte de recherche]]


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	var p: Dictionary = SceneRouter.payload
	show_tab(String(p.get("tab", last_tab)))
	var ouvrir: String = String(p.get("open", ""))
	if ouvrir != "":
		open_sheet(ouvrir)


## Le bouton retour d Android : ferme d abord ce qui est ouvert.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func go_back() -> void:
	if _picker != null:
		close_picker()
	elif _detail != "":
		show_tab(_tab)
	else:
		SceneRouter.goto(SceneRouter.MAIN_MENU)


func _build_layout() -> void:
	var fond := TextureRect.new()
	fond.texture = UiTheme.tex("wood_tile")
	fond.stretch_mode = TextureRect.STRETCH_TILE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in [&"margin_left", &"margin_right"]:
		marge.add_theme_constant_override(cote, 16)
	marge.add_theme_constant_override(&"margin_top", 24)
	marge.add_theme_constant_override(&"margin_bottom", 24)
	add_child(marge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	marge.add_child(col)

	var haut := HBoxContainer.new()
	haut.add_theme_constant_override(&"separation", 16)
	col.add_child(haut)
	var menu := Button.new()
	menu.text = "< MENU"
	menu.custom_minimum_size = Vector2(230, 110)
	menu.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		SceneRouter.goto(SceneRouter.MAIN_MENU))
	haut.add_child(menu)
	var titre: Label = UiTheme.label_hud("ATELIER DU TESTEUR", UiTheme.FONT_BODY, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haut.add_child(titre)

	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override(&"separation", 6)
	col.add_child(onglets)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		b.clip_text = true
		var cle: String = t[0]
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			show_tab(cle))
		onglets.add_child(b)
		_tab_buttons[cle] = b

	_status = UiTheme.label_hud("", UiTheme.FONT_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	col.add_child(_status)

	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	col.add_child(page)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Un glissement du doigt sur un bouton doit faire defiler, pas appuyer.
	_scroll.scroll_deadzone = 24
	page.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 12)
	_scroll.add_child(_body)

	_toast = UiTheme.label_hud("", UiTheme.FONT_SMALL, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast.visible = false
	col.add_child(_toast)


func current_tab() -> String:
	return _tab


func current_detail() -> String:
	return _detail


func body() -> VBoxContainer:
	return _body


func refresh_status() -> void:
	var n: int = TesterOverrides.count()
	var r: int = TesterOverrides.rejected().size()
	var t: String = ""
	if TesterOverrides.is_active():
		t = "Mode testeur ACTIF : %d reglage%s joue%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]
	else:
		t = "Mode testeur ETEINT : %d reglage%s en reserve, NON joue%s" % [n,
			"s" if n > 1 else "", "s" if n > 1 else ""]
	if r > 0:
		t += " - %d ignore%s (voir DOC)" % [r, "s" if r > 1 else ""]
	_status.text = t


func toast(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	var tw: Tween = create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void: _toast.visible = false)


func _clear_body() -> void:
	for c in _body.get_children().duplicate():
		_body.remove_child(c)
		c.queue_free()
	_rows.clear()
	_scroll.scroll_vertical = 0


func show_tab(cle: String) -> void:
	var connu: bool = false
	for t in TABS:
		if t[0] == cle:
			connu = true
	if not connu:
		cle = "monstres"
	_tab = cle
	_detail = ""
	last_tab = cle
	for k in _tab_buttons.keys():
		(_tab_buttons[k] as Button).add_theme_color_override(&"font_color",
			UiTheme.GOLD if k == cle else UiTheme.TEXT)
	_clear_body()
	refresh_status()
	match cle:
		"sorts":
			_build_list("card")
		"monstres":
			_build_list("enemy")
		"niveaux":
			_build_list("level")
		"test":
			_body.add_child(TesterTestTab.new().setup(self))
		"document":
			_body.add_child(TesterDocTab.new().setup(self))


## --- LISTES ------------------------------------------------------------------

func _build_list(kind: String) -> void:
	var recherche := LineEdit.new()
	recherche.placeholder_text = "Rechercher (nom ou id)"
	recherche.custom_minimum_size = Vector2(0, 110)
	recherche.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	recherche.clear_button_enabled = true
	recherche.text = String(last_search.get(kind, ""))
	_body.add_child(recherche)
	for item: Dictionary in TesterField.ref_items(kind):
		var res: Resource = item["res"]
		var b: Button = _list_row(kind, res)
		_body.add_child(b)
		_rows.append([b, (String(item["label"]) + " " + String(item["id"])).to_lower()])
	recherche.text_changed.connect(func(t: String) -> void:
		last_search[kind] = t
		filter_rows(t))
	filter_rows(recherche.text)


## Filtre SANS reconstruire : le champ de recherche garde le clavier ouvert.
func filter_rows(text: String) -> void:
	var q: String = text.strip_edges().to_lower()
	for r in _rows:
		(r[0] as Button).visible = q == "" or String(r[1]).contains(q)


func visible_rows() -> int:
	var n: int = 0
	for r in _rows:
		if (r[0] as Button).visible:
			n += 1
	return n


func _list_row(kind: String, res: Resource) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ROW_H)
	var t: String = TesterOverrides.target_of(res)
	var ligne := HBoxContainer.new()
	ligne.set_anchors_preset(Control.PRESET_FULL_RECT)
	ligne.offset_left = 14
	ligne.offset_right = -14
	ligne.add_theme_constant_override(&"separation", 16)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ligne)
	var art: Control = null
	if res is EnemyDef:
		art = BestiaryLore.portrait_of(res as EnemyDef, 100.0, true)
	elif res is SpellCard:
		art = CardIcons.make_rect(res as SpellCard, 96.0)
	if art != null:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(art)
	var n: int = 0
	for e in TesterOverrides.entries():
		if e["target"] == t:
			n += 1
	var detail: String = String(res.get("id"))
	if res is EnemyDef:
		detail += "  P%d  %d PV" % [(res as EnemyDef).power, int((res as EnemyDef).max_hp)]
	elif res is SpellCard:
		detail += "  " + GameEnums.rarity_name((res as SpellCard).rarity)
	elif res is LevelDef:
		detail += "  acte %d, %d vagues" % [(res as LevelDef).act, (res as LevelDef).waves.size()]
	if n > 0:
		detail += "  - %d reglage%s" % [n, "s" if n > 1 else ""]
	var textes := VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textes.alignment = BoxContainer.ALIGNMENT_CENTER
	textes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(textes)
	var nom: Label = UiTheme.label(String(res.get("display_name")), UiTheme.FONT_SMALL,
		UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	nom.clip_text = true
	textes.add_child(nom)
	var sous: Label = UiTheme.label(detail, UiTheme.FONT_SMALL,
		UiTheme.GOLD if n > 0 else UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	sous.clip_text = true
	textes.add_child(sous)
	for l in [nom, sous]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		open_sheet(t))
	return b


## --- FICHE -------------------------------------------------------------------

func open_sheet(target: String) -> void:
	var res: Resource = TesterOverrides.resolve_target(target)
	if res == null:
		toast("Introuvable : " + target)
		return
	var genre: String = target.split(":")[0]
	var onglet: String = {"card": "sorts", "enemy": "monstres", "level": "niveaux"}.get(genre, _tab)
	if onglet != _tab:
		show_tab(onglet)
	_clear_body()
	_detail = target
	refresh_status()
	var retour := Button.new()
	retour.text = "< RETOUR A LA LISTE"
	retour.custom_minimum_size = Vector2(0, TOUCH)
	retour.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		show_tab(_tab))
	_body.add_child(retour)
	_body.add_child(TesterSheet.new().setup(res, self))


## --- SELECTEUR PLEIN ECRAN -------------------------------------------------
##
## Pour toute liste longue (monstres, cartes, apparences). Une OptionButton de
## 86 lignes est inutilisable au doigt ; ici on cherche, puis on touche une
## grande ligne. items : [{id, label, res?}] ; on_pick(id: String).

func open_picker(title: String, items: Array, on_pick: Callable) -> void:
	close_picker()
	var voile := PanelContainer.new()
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.offset_left = 24
	voile.offset_right = -24
	voile.offset_top = 120
	voile.offset_bottom = -120
	voile.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)
	_picker = voile
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	voile.add_child(col)
	col.add_child(UiTheme.label("CHOISIR : " + title.to_upper(), UiTheme.FONT_BODY, TesterField.INK))
	var recherche := LineEdit.new()
	recherche.placeholder_text = "Rechercher"
	recherche.custom_minimum_size = Vector2(0, 110)
	recherche.clear_button_enabled = true
	col.add_child(recherche)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24
	col.add_child(scroll)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override(&"separation", 8)
	scroll.add_child(liste)
	var lignes: Array = []
	for it: Dictionary in items:
		var b := Button.new()
		b.text = String(it.get("label", it.get("id", "")))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 100)
		b.clip_text = true
		var r: Variant = it.get("res")
		if r is EnemyDef:
			b.icon = BestiaryLore.portrait_texture(r)
			b.expand_icon = true
		elif r is SpellCard:
			b.icon = CardIcons.art(r)
			b.expand_icon = true
		var id: String = String(it.get("id", ""))
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			close_picker()
			on_pick.call(id))
		liste.add_child(b)
		lignes.append([b, (b.text + " " + id).to_lower()])
	recherche.text_changed.connect(func(t: String) -> void:
		var q: String = t.strip_edges().to_lower()
		for l in lignes:
			(l[0] as Button).visible = q == "" or String(l[1]).contains(q))
	var fermer := Button.new()
	fermer.text = "FERMER"
	fermer.custom_minimum_size = Vector2(0, 110)
	fermer.pressed.connect(close_picker)
	col.add_child(fermer)


func picker_open() -> bool:
	return _picker != null


func close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null
