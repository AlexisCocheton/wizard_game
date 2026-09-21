class_name DeckPanel
extends Control
## Onglet Deck — le GRIMOIRE DE COMPOSITION.
##
##   +--------------------------------------------------+
##   | [Feu] [Givre] [+]        [renommer]  [supprimer] |  <- onglets de decks
##   +--------------------------------------------------+
##   | ,----------------------------------------------. |
##   |(|  Feu                          15 / 15        |)|  <- en-tete papier
##   |(|  +-------+  +-------+  +-------+             |)|
##   |(|  | icone |  | icone |  | icone |             |)|  grille 3 x 2
##   |(|  | nom x3|  | nom x2|  | nom x1|             |)|  = LE DECK (toucher
##   |(|  +-------+  +-------+  +-------+             |)|    = retirer)
##   |(|  ---------- COLLECTION ---------------       |)|
##   |(|  [Toutes][Com][Rare][Epi][Leg]               |)|  <- filtres
##   |(|  +-------+  +-------+  +-------+             |)|  grille 3 x 2
##   |(|  | icone |  | icone |  | icone |             |)|  = la collection
##   |(|  +-------+  +-------+  +-------+             |)|    (double toucher)
##   |(| [<]         page 1 / 4              [>]      |)|  <- pied de page
##   | `----------------------------------------------' |
##   +--------------------------------------------------+
##
## POURQUOI CETTE FORME
## --------------------
## Demande du testeur : "utilise bien les memes demandes que pour le bestiaire en
## termes de graphisme". L ecran reprend donc la langue visuelle du GRIMOIRE
## (gallery_panel.gd) : page de livre en 9-tranches, vignettes a icone CardIcons,
## encre SOMBRE sur le papier creme, et un pied de page a deux fleches avec un
## numero de page entre elles. Le defilement libre de l ancien ecran ne disait
## jamais au joueur ou il en etait dans sa collection de 45 cartes.
##
## DOUBLE TOUCHER sur la collection (conserve tel quel) : le 1er toucher OUVRE la
## fiche d effet de la carte, le 2e sur la MEME carte l ajoute au deck. Toucher
## une autre carte remet le compteur a zero et montre son effet.
## Pourquoi : on ajoutait au premier toucher, donc le joueur composait son deck
## sans jamais pouvoir lire ce que faisait une carte. La lecture doit preceder
## l engagement, sans ajouter d ecran supplementaire.
##
## Le deck (en haut) garde le toucher UNIQUE : retirer est reversible d un geste,
## il n y a rien a lire avant.
##
## PLUSIEURS DECKS
## ---------------
## Les onglets du haut sont les decks nommes de SaveData. En changer n est qu un
## `set_current_deck` : le contenu de l autre deck n est jamais recopie ni perdu.
## Le joueur peut donc garder un deck de campagne monte pendant qu il essaie
## autre chose en Massacre.
##
## LES PASSIFS NE SONT PAS DANS LE DECK
## ------------------------------------
## Ils s equipent a part (0 a 3, chantier F). Cet ecran les montre dans une bande
## SOUS les onglets, bien separee des 15 cartes, pour que le joueur ne cherche
## jamais un passif dans sa collection de sorts.

## Grille 3 colonnes, comme le grimoire. Deux lignes par zone : le deck et la
## collection doivent tenir ENSEMBLE sur une page portrait.
const COLS: int = 3
const DECK_ROWS: int = 2
const COLL_ROWS: int = 2
const PER_PAGE: int = COLS * COLL_ROWS

## Cibles tactiles. Toutes au-dela des 90 px exiges sur mobile.
const TILE_H: float = 210.0
## Largeur MINIMALE d une vignette. Elle existe a cause du ScrollContainer du
## deck : un ScrollContainer accorde a son enfant sa largeur minimale, et des
## vignettes de largeur minimale nulle repliaient toute la grille en un filet
## colle a gauche (lu sur capture). 250 px tient trois colonnes sur 1080, marges
## de page et separations comprises.
const TILE_W: float = 250.0
const ICON_PX: float = 86.0
const ARROW_W: float = 170.0
const ARROW_H: float = 120.0
const TAB_H: float = 110.0

var _ids: Array = []
var _filter: int = -1  # -1 = toutes les raretes
var _page: int = 0
var _pages: int = 1

## Carte dont la fiche est ouverte et qui sera ajoutee au prochain toucher.
## Vide = aucun toucher en attente.
var _armed_id: StringName = &""

var _tab_bar: HBoxContainer
var _passive_row: HBoxContainer
var _header: Label
var _deck_grid: GridContainer
var _deck_scroll: ScrollContainer
var _coll_label: Label
var _filters: HBoxContainer
var _grid: GridContainer
var _page_label: Label
var _prev: Button
var _next: Button
var _body: VBoxContainer
## Cale entre les grilles et le pied de page. Masquee quand la fiche est ouverte :
## sinon la fiche et la cale se PARTAGENT la hauteur libre et la fiche se tasse
## en haut d une page aux trois quarts vide (defaut deja corrige sur le grimoire).
var _cale: Control
var _detail_box: VBoxContainer
var _detail_card: SpellCard = null


func _ready() -> void:
	_build()
	refresh()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 10)
	add_child(root)

	# --- Barre des onglets de decks, reconstruite a chaque refresh() ---
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override(&"separation", 8)
	root.add_child(_tab_bar)

	# --- Bande des passifs equipes : SOUS les onglets, HORS de la page du deck,
	# pour qu on ne puisse pas la confondre avec les 15 cartes.
	_passive_row = HBoxContainer.new()
	_passive_row.add_theme_constant_override(&"separation", 8)
	root.add_child(_passive_row)

	# --- La page du livre ---
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	root.add_child(page)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 8)
	page.add_child(_body)

	# Encre SOMBRE : la page est un papier creme, un texte clair y est invisible.
	_header = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_body.add_child(_header)

	# Le deck peut compter jusqu a 15 cartes DISTINCTES : une grille figee a deux
	# lignes en cachait neuf sans le dire. La zone garde donc une hauteur fixe
	# (deux lignes visibles, pour que la collection reste sur la meme page) mais
	# DEFILE au-dela. C est la seule zone qui defile de l ecran : le deck est la
	# liste que le joueur parcourt, la collection est ce qu il feuillette.
	_deck_scroll = ScrollContainer.new()
	_deck_scroll.custom_minimum_size = Vector2(0, TILE_H * DECK_ROWS + 10.0)
	_deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_deck_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_deck_scroll)

	_deck_grid = GridContainer.new()
	_deck_grid.columns = COLS
	_deck_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_grid.add_theme_constant_override(&"h_separation", 8)
	_deck_grid.add_theme_constant_override(&"v_separation", 8)
	_deck_scroll.add_child(_deck_grid)

	_coll_label = UiTheme.label("COLLECTION", UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false)
	_body.add_child(_coll_label)

	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override(&"separation", 6)
	_body.add_child(_filters)
	_add_filter("Toutes", -1)
	_add_filter("Com.", GameEnums.Rarity.COMMON)
	_add_filter("Rare", GameEnums.Rarity.RARE)
	_add_filter("Epi.", GameEnums.Rarity.EPIC)
	_add_filter("Leg.", GameEnums.Rarity.LEGENDARY)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	_body.add_child(_grid)

	# La fiche d effet prend la place de la grille sur la MEME page, comme dans
	# le grimoire : une superposition flottante ne ressemblait a rien de ce que
	# le joueur connait deja de l ecran voisin.
	_detail_box = VBoxContainer.new()
	_detail_box.visible = false
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override(&"separation", 8)
	_body.add_child(_detail_box)

	# Cale : elle pousse le pied de page vers le bas quand les grilles sont
	# courtes. Sans elle, les fleches flotteraient au milieu du papier.
	_cale = Control.new()
	_cale.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_cale)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 12)
	_body.add_child(footer)
	_prev = _arrow("book_turn_left", -1)
	footer.add_child(_prev)
	_page_label = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_page_label)
	_next = _arrow("book_turn_right", 1)
	footer.add_child(_next)


## Une fleche de page, meme image que le grimoire : le joueur a deja appris ce
## geste sur l ecran voisin.
func _arrow(tex_name: String, dir: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ARROW_W, ARROW_H)
	b.icon = UiTheme.tex(tex_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		turn_page(dir))
	return b


func _add_filter(text: String, rarity: int) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = rarity == _filter
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)   # cible tactile minimale mobile
	b.clip_text = true
	b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		_filter = rarity
		# Changer de filtre change le nombre de pages : repartir de la premiere
		# evite d atterrir sur une page 4 qui n existe plus.
		_page = 0
		_render())
	_filters.add_child(b)


# --- Etat, pilotable par les tests sans passer par les boutons ---

func current_page() -> int:
	return _page


func page_count() -> int:
	return _pages


func turn_page(dir: int) -> void:
	if _pages <= 1:
		return
	_page = posmod(_page + dir, _pages)
	_render()


## Bascule sur un autre onglet de deck. Rien n est recopie : on change seulement
## quel deck le profil considere comme courant.
func select_deck(index: int) -> void:
	SaveData.set_current_deck(index)
	SaveData.save_profile()
	refresh()


func create_deck() -> void:
	SaveData.create_deck()
	SaveData.save_profile()
	refresh()


func delete_current_deck() -> void:
	SaveData.delete_deck(SaveData.current_deck_index())
	SaveData.save_profile()
	refresh()


func refresh() -> void:
	# Revenir sur l onglet remet le double toucher a zero : une carte armee
	# oubliee d une visite precedente s ajouterait au premier toucher suivant.
	_armed_id = &""
	_detail_card = null
	_ids = SaveData.massacre_deck().duplicate()
	# Premier passage : on propose le deck de base plutot qu un ecran vide.
	if _ids.is_empty() and SaveData.deck_count() == 1:
		_ids = DeckRules.default_deck_ids()
		_save()
	_render()


func _save() -> void:
	SaveData.set_massacre_deck(_ids)
	SaveData.save_profile()


# --- Rendu ---

func _render() -> void:
	_render_tabs()
	_render_passives()
	if _detail_card != null:
		_render_detail()
		return
	_detail_box.visible = false
	_deck_scroll.visible = true
	_coll_label.visible = true
	_grid.visible = true
	_filters.visible = true
	_cale.visible = true

	var msg: String = DeckRules.validation_message(_ids)
	# Le compteur "15 / 15" est ce que le joueur regarde en premier. Il tient sur
	# une ligne (AUTOWRAP_OFF), vire au rouge des qu il ne colle pas, et le
	# pourquoi s ecrit JUSTE DESSOUS. Ce message etait dans le pied de page : il
	# y chassait le numero de page, donc le joueur perdait sa position dans la
	# collection au moment precis ou il cherchait la carte qui lui manque.
	_header.text = "%s        %d / %d%s" % [
		SaveData.deck_name(SaveData.current_deck_index()),
		_ids.size(), DeckRules.DECK_SIZE,
		"\n" + msg if msg != "" else ""]
	_header.add_theme_color_override(&"font_color",
		Color(0.62, 0.12, 0.14) if msg != "" else UiTheme.TEXT_DARK)

	_render_deck_grid()
	_render_filters()
	_render_collection()

	_page_label.text = "page %d / %d" % [_page + 1, _pages]
	_page_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)


## Les onglets de decks. Reconstruits a chaque rendu : creer ou supprimer un
## deck change leur nombre, et un bouton survivant pointerait sur un index mort.
func _render_tabs() -> void:
	for c in _tab_bar.get_children():
		_tab_bar.remove_child(c)
		c.queue_free()
	var courant: int = SaveData.current_deck_index()
	for i in SaveData.deck_count():
		var b := Button.new()
		b.text = SaveData.deck_name(i)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, TAB_H)
		b.clip_text = true
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		# L onglet courant est en or, comme la section active du grimoire.
		b.add_theme_color_override(&"font_color",
			UiTheme.GOLD if i == courant else UiTheme.TEXT)
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			# Retoucher l onglet DEJA courant ouvre le renommage : un bouton
			# "renommer" de plus aurait mange la largeur des onglets eux-memes.
			if idx == SaveData.current_deck_index():
				_open_rename(idx)
			else:
				select_deck(idx))
		_tab_bar.add_child(b)

	# Le "+" ne s affiche que tant qu il reste de la place : un bouton qui ne
	# fait rien est pire qu un bouton absent.
	if SaveData.deck_count() < SaveData.MAX_DECKS:
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(TAB_H, TAB_H)
		plus.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
		plus.tooltip_text = "Nouveau deck"
		plus.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			create_deck())
		_tab_bar.add_child(plus)

	if SaveData.deck_count() > 1:
		var suppr := Button.new()
		suppr.text = "X"
		suppr.custom_minimum_size = Vector2(TAB_H, TAB_H)
		suppr.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
		suppr.add_theme_color_override(&"font_color", UiTheme.RED)
		suppr.tooltip_text = "Supprimer ce deck"
		suppr.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			delete_current_deck())
		_tab_bar.add_child(suppr)


## Les passifs EQUIPES, en lecture seule ici : 0 a 3 emplacements, montres hors
## de la page du deck pour qu ils ne se confondent jamais avec les 15 cartes.
func _render_passives() -> void:
	for c in _passive_row.get_children():
		_passive_row.remove_child(c)
		c.queue_free()
	_passive_row.add_child(UiTheme.label("PASSIFS", UiTheme.FONT_SMALL,
		UiTheme.TEAL, HORIZONTAL_ALIGNMENT_LEFT, false))
	var equipes: Array = SaveData.equipped_passives()
	for slot in DeckRules.MAX_PASSIVES:
		var l: Label
		if slot < equipes.size():
			var c2: SpellCard = ContentDB.cards.get(StringName(equipes[slot]))
			l = UiTheme.label(c2.display_name if c2 != null else "?",
				UiTheme.FONT_SMALL, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
		else:
			l = UiTheme.label("- vide -", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM,
				HORIZONTAL_ALIGNMENT_CENTER, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_passive_row.add_child(l)


## Le deck : une vignette par carte DISTINCTE, avec son nombre d exemplaires.
## Toucher retire un exemplaire.
func _render_deck_grid() -> void:
	# remove_child() AVANT queue_free() : un noeud en attente de suppression est
	# encore un enfant, donc get_child_count() le compte et l arithmetique des
	# cases vides ci-dessous se trompait d autant (une grille de 2 cases apres
	# un deck de 4 — vu sur capture). Il se voit aussi encore a l ecran pendant
	# la frame en cours.
	for c in _deck_grid.get_children():
		_deck_grid.remove_child(c)
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
		_deck_grid.add_child(_tile(card, "x%d" % counts[id],
			UiTheme.rarity_color(card.rarity), _on_remove.bind(card),
			"Toucher pour retirer un exemplaire"))
	# On complete la grille avec des emplacements VIDES visibles plutot qu un
	# trou : le joueur voit qu il lui reste de la place sans lire le compteur.
	# On n en met QUE de quoi finir la page visible — au-dela, la zone defile et
	# des cases vides supplementaires n apprendraient plus rien.
	var cases: int = COLS * DECK_ROWS
	for _i in maxi(0, cases - _deck_grid.get_child_count()):
		_deck_grid.add_child(_empty_slot())


func _empty_slot() -> Control:
	# Un BOUTON desactive et non un panneau nu : sur le papier creme, un
	# PanelContainer sans style est invisible, et la zone du deck se lisait comme
	# une page blanche cassee (vu sur capture). Le cadre grise dit "emplacement
	# a remplir", ce qui est exactement l information.
	var b := Button.new()
	b.text = "vide"
	b.disabled = true
	b.custom_minimum_size = Vector2(TILE_W, TILE_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	return b


func _render_filters() -> void:
	for i in _filters.get_child_count():
		var b: Button = _filters.get_child(i) as Button
		var r: int = [-1, GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY][i]
		b.button_pressed = r == _filter


## Les cartes offertes a la composition, filtrees par rarete et paginees.
## Les PASSIFS en sont exclus : ils ne se mettent plus dans le deck.
func collection() -> Array:
	var out: Array = []
	for card: SpellCard in ContentDB.cards.values():
		if card == null or card.is_passive:
			continue
		if _filter != -1 and card.rarity != _filter:
			continue
		out.append(card)
	out.sort_custom(_sort_cards)
	return out


func _render_collection() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var cards: Array = collection()
	_pages = maxi(1, int(ceil(float(cards.size()) / float(PER_PAGE))))
	_page = clampi(_page, 0, _pages - 1)

	var start: int = _page * PER_PAGE
	var fin: int = mini(start + PER_PAGE, cards.size())
	for i in range(start, fin):
		var card: SpellCard = cards[i]
		var discovered: bool = SaveData.is_discovered(card.id)
		if not discovered:
			# Non decouverte : silhouette et "???", exactement comme le grimoire.
			var muet := Button.new()
			muet.custom_minimum_size = Vector2(0, TILE_H)
			muet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			muet.disabled = true
			var boite := VBoxContainer.new()
			boite.set_anchors_preset(Control.PRESET_FULL_RECT)
			boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boite.alignment = BoxContainer.ALIGNMENT_CENTER
			muet.add_child(boite)
			boite.add_child(UiTheme.label("???", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM,
				HORIZONTAL_ALIGNMENT_CENTER, false))
			boite.add_child(UiTheme.label(GameEnums.rarity_name(card.rarity),
				UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
			_grid.add_child(muet)
			continue
		var have: int = DeckRules.count_of(_ids, card.id)
		var cap: int = DeckRules.max_copies(card.rarity)
		# La vignette armee annonce ce que fera le PROCHAIN toucher : sans ce
		# retour, un second toucher qui ajoute passerait pour un bug.
		var armed: bool = card.id == _armed_id
		var tile: Button = _tile(card,
			"> AJOUTER" if armed else "%d/%d" % [have, cap],
			UiTheme.GOLD if armed else UiTheme.TEXT,
			_on_collection_tap.bind(card), "")
		# Une carte non ajoutable reste TOUCHABLE : sa fiche doit pouvoir
		# s ouvrir pour qu on comprenne pourquoi elle est refusee. C est le
		# bouton AJOUTER de la fiche qui se desactive, pas la vignette.
		_grid.add_child(tile)
	for _i in PER_PAGE - (fin - start):
		var vide := Control.new()
		vide.custom_minimum_size = Vector2(0, TILE_H)
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(vide)


## Une vignette de carte : l icone du sort (CardIcons, la meme qu en jeu), son
## nom, et une ligne de pied. Meme forme que celles du grimoire.
func _tile(card: SpellCard, pied: String, teinte: Color,
		action: Callable, aide: String) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.clip_contents = true
	tile.tooltip_text = aide

	# CONTOUR de rarete, comme dans le profil et la galerie. La rarete ne
	# teintait jusqu ici que le compteur "x1" en pied de tuile : deux caracteres,
	# invisibles dans une grille ou l on compose justement en comptant ses
	# epiques et ses legendaires. Le cadre encadre toute la tuile et son
	# EPAISSEUR monte avec le rang, donc le classement se lit meme sans
	# distinguer les couleurs.
	var cadre: StyleBox = UiTheme.rarity_border(card.rarity,
		UiTheme.PANEL_LIGHT.lightened(0.05))
	tile.add_theme_stylebox_override(&"normal", cadre)
	tile.add_theme_stylebox_override(&"hover", cadre)
	tile.add_theme_stylebox_override(&"pressed", cadre)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Le contenu ignore la souris, sinon il avalerait le toucher du bouton.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 2)
	tile.add_child(box)

	var art: TextureRect = CardIcons.make_rect(card, ICON_PX)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)

	var nom: Label = UiTheme.label(card.display_name, UiTheme.FONT_SMALL,
		UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(nom)
	box.add_child(UiTheme.label(pied, UiTheme.FONT_SMALL, teinte,
		HORIZONTAL_ALIGNMENT_CENTER, false))

	tile.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		action.call())
	return tile


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


# --- Double toucher ---

## Toucher une carte de la COLLECTION. Deux etats, un seul bouton :
##   1er toucher (ou carte differente) -> arme la carte et montre son effet
##   2e toucher sur la MEME carte      -> ajoute au deck et desarme
## Toucher une autre carte remet le compteur a zero : on ne peut pas ajouter
## par inadvertance une carte dont on n a pas lu la fiche.
func _on_collection_tap(card: SpellCard) -> void:
	if card.id == _armed_id:
		_armed_id = &""
		_detail_card = null
		_do_add(card)
		return
	_armed_id = card.id
	_detail_card = card
	_render()


## L ajout reel. Separe du toucher pour que la regle de deck reste testable
## sans passer par l interface.
func _do_add(card: SpellCard) -> void:
	if not DeckRules.can_add(_ids, card, SaveData.is_discovered(card.id)):
		_render()
		return
	_ids.append(String(card.id))
	_save()
	_render()


## Etat du double toucher, expose pour les tests et pour le retour visuel.
func armed_card() -> StringName:
	return _armed_id


func _on_remove(card: SpellCard) -> void:
	# Retirer une carte desarme : sans cela, le toucher suivant sur la vignette
	# armee la RE-ajouterait, ce que le joueur vient justement de defaire.
	_armed_id = &""
	_detail_card = null
	var idx: int = _ids.find(String(card.id))
	if idx == -1:
		return
	_ids.remove_at(idx)
	_save()
	_render()


# --- Fiche d effet, a la place de la grille sur la page ---

func _render_detail() -> void:
	var card: SpellCard = _detail_card
	_deck_scroll.visible = false
	_coll_label.visible = false
	_grid.visible = false
	_filters.visible = false
	# La cale disparait AUSSI : sinon elle se partage la hauteur libre avec la
	# fiche, et la fiche se tasse en haut d une page aux trois quarts blanche.
	_cale.visible = false
	_detail_box.visible = true
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	_header.text = ""
	_page_label.text = "%d / %d dans le deck" % [_ids.size(), DeckRules.DECK_SIZE]
	_page_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 10)
	scroll.add_child(box)

	var art: TextureRect = CardIcons.make_rect(card, 180.0)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)

	# Encre SOMBRE partout : fond de PAPIER.
	box.add_child(UiTheme.label(card.display_name, UiTheme.FONT_TITLE,
		UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("%s   -   incantation %s s" % [
		GameEnums.rarity_name(card.rarity).capitalize(), _fmt(card.base_cast_time)],
		UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label(card.description, UiTheme.FONT_BODY,
		UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	var have: int = DeckRules.count_of(_ids, card.id)
	var cap: int = DeckRules.max_copies(card.rarity)
	box.add_child(UiTheme.label("Dans ton deck : %d / %d" % [have, cap],
		UiTheme.FONT_BODY, UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_CENTER, false))

	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override(&"separation", 12)
	_detail_box.add_child(boutons)

	var add := Button.new()
	add.text = "AJOUTER"
	add.custom_minimum_size = Vector2(0, 110)   # cible tactile confortable
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = not DeckRules.can_add(_ids, card, SaveData.is_discovered(card.id))
	# Un bouton grise sans raison est une impasse : on dit POURQUOI juste dessous.
	if add.disabled:
		box.add_child(UiTheme.label(_refus(card), UiTheme.FONT_SMALL,
			Color(0.62, 0.12, 0.14), HORIZONTAL_ALIGNMENT_CENTER))
	add.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		_on_collection_tap(card))
	boutons.add_child(add)

	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 110)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		_armed_id = &""
		_detail_card = null
		_render())
	boutons.add_child(close)


## Pourquoi cette carte ne peut pas entrer dans le deck. Le joueur doit pouvoir
## corriger : "deck plein" et "trop d epiques" n appellent pas le meme geste.
func _refus(card: SpellCard) -> String:
	if not SaveData.is_discovered(card.id):
		return "Carte non decouverte"
	if _ids.size() >= DeckRules.DECK_SIZE:
		return "Deck complet : retire une carte d abord"
	if DeckRules.count_of(_ids, card.id) >= DeckRules.max_copies(card.rarity):
		return "Deja %d exemplaires, le maximum pour cette rarete" % DeckRules.max_copies(card.rarity)
	var plafond: int = DeckRules.max_of_rarity(card.rarity)
	if plafond >= 0:
		return "Deja %d %s dans le deck, le maximum" % [plafond,
			GameEnums.rarity_name(card.rarity) + "s"]
	return "Ajout impossible"


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


# --- Renommage : une boite posee sur la page ---

func _open_rename(index: int) -> void:
	var fond := PanelContainer.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	# Il INTERCEPTE le toucher : sans cela on viserait les onglets au travers.
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 20)
	fond.add_child(box)
	box.add_child(UiTheme.label("NOM DU DECK", UiTheme.FONT_TITLE, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, false))

	var champ := LineEdit.new()
	champ.text = SaveData.deck_name(index)
	champ.max_length = 16   # au-dela, le nom ne tient plus dans un onglet
	champ.custom_minimum_size = Vector2(0, 120)
	champ.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	box.add_child(champ)

	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 16)
	box.add_child(ligne)
	var valider := Button.new()
	valider.text = "VALIDER"
	valider.custom_minimum_size = Vector2(0, 120)
	valider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	valider.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		SaveData.rename_deck(index, champ.text)
		SaveData.save_profile()
		fond.queue_free()
		_render())
	ligne.add_child(valider)
	var annuler := Button.new()
	annuler.text = "ANNULER"
	annuler.custom_minimum_size = Vector2(0, 120)
	annuler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	annuler.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		fond.queue_free())
	ligne.add_child(annuler)
