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
## GLISSER-DEPOSER (UI-006), EN PLUS DU TOUCHER
## -------------------------------------------
##   +--------------------------------------------------+
##   |  Deck 1                          14 / 15         |
##   | +==============================================+ |
##   | |  DEPOSER ICI POUR AJOUTER    (ou la raison   | |  <- zone de depot
##   | |  du refus, en rouge, AVANT de lacher)        | |     (or / rouge)
##   | +==============================================+ |
##   |               .-------.                          |
##   |               | icone |  <- la carte suit le doigt,
##   |               `-------'     AU-DESSUS de lui     |
##   |                   o  <- doigt                    |
##   |  COLLECTION   [x] [x] [ ] <- vignette source pale |
##   +--------------------------------------------------+
##
## Collection -> deck ajoute un exemplaire ; deck -> collection en retire un.
## Le geste ne demarre qu apres DRAG_START_PX de deplacement : en deca, c est un
## toucher, et le toucher garde exactement son effet d avant (les habitues vont
## plus vite au toucher). Au relachement hors de la zone, ou si l ajout est
## refuse, la carte REVIENT a sa vignette : rien n a change, et on le voit.
## Pourquoi la carte flotte AU-DESSUS du doigt : sous le pouce, on ne verrait
## plus ce qu on transporte. Pourquoi montrer la raison du refus PENDANT le
## glisser : le joueur apprend qu il ne peut pas deposer avant d avoir lache,
## au lieu de le decouvrir par un retour qu il pourrait prendre pour un bug.
##
## DEFILER OU PRENDRE. Quand la zone du deck deborde (deck hors regle, plus de
## six cartes differentes), un geste parti a la VERTICALE sur une de ses
## vignettes fait defiler la zone au lieu de prendre la carte ; parti de cote,
## il la prend. Voir `gesture_for`. Un deck conforme ne defile jamais et garde
## le geste d origine dans toutes les directions.
##
## Le suivi se fait dans `_input()` et non `_gui_input` : une vignette est un
## Button, qui avale le relachement (piege documente du projet, meme cause que
## le viseur des sorts). Le relachement d un glisser est marque traite pour que
## le Button ne le prenne pas pour un toucher.
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
##
## Depuis le chantier P la bande est EQUIPABLE : trois emplacements, un toucher
## ouvre sur la page la liste des passifs OBTENUS, un second equipe. Ils sont
## actifs des le debut du combat (RunState.equip_saved_passives), mais SEULEMENT
## en Infini et en Massacre (retouche du 30/09) : un niveau de campagne part sans
## eux. Une phrase sous la bande le dit. Avant l acte 2 la bande le dit aussi au
## lieu de montrer des emplacements inutilisables.
##
##   +--------------------------------------------------+
##   | PASSIFS [Celerite] [Ecorce vive] [ + libre ]     |  <- 3 emplacements
##   +--------------------------------------------------+
##   |  PASSIF - emplacement 2 / 3                      |  <- la page devient
##   |  [icone Celerite  ] [icone Ecorce   ] [ ... ]    |     le choix du passif
##   |  [ RETIRER ]                    [ FERMER ]       |
##
## VISIBILITE (chantier P) : la collection ne montre que les cartes OBTENUES
## (utilisables) et OBTENABLES (grisees, fiche lisible, bouton AJOUTER refuse avec
## le geste qui les obtient). Les autres sont invisibles : plus de "???".
## Depuis la retouche du 30/09, la liste, son ordre (obtenues d abord), le
## compteur et l aspect grise sont ceux du grimoire (SaveData.visible_cards,
## CollectionStyle).

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
## Teinte du fond d une vignette OBTENABLE (lisible, grisee, non utilisable).
## Elle vit dans CollectionStyle, partagee avec le grimoire.
const OBTAINABLE_TINT: Color = CollectionStyle.GREY_TILE
## La phrase sous les emplacements de passifs. Courte, parce qu elle est lue a
## cote de trois boutons ; elle dit OU ils servent, c est la seule chose que le
## joueur ne peut pas deviner (retouche du 30/09 : pas en campagne).
const PASSIVES_SCOPE_TEXT: String = "Actifs en Infini et en Massacre, pas en campagne"
## Hauteur d un emplacement de passif : une cible tactile (>= 90 px).
const PASSIVE_SLOT_H: float = 100.0

## Deplacement a partir duquel un appui devient un glisser. Un doigt qui touche
## « sans bouger » derive de 5 a 15 px sur un ecran de 1080 : en dessous de ce
## seuil, on laisse le toucher faire son office.
const DRAG_START_PX: float = 28.0
## La carte transportee flotte au-dessus du doigt, pas dessous : sinon le pouce
## la cache precisement quand on vise.
const GHOST_LIFT: float = 130.0
## Retour de la carte a sa vignette quand le depot est refuse ou manque.
const RETURN_S: float = 0.22
## Duree d affichage de la raison d un refus. Assez pour lire une phrase courte,
## assez court pour ne pas masquer le deck au geste suivant.
const NOTICE_S: float = 3.2

## Ou se trouve le doigt au moment du depot.
enum Zone { NONE, DECK, COLLECTION }

## Ce que devient un appui sur une vignette une fois que le doigt a bouge.
## AUCUN = pas encore decide (sous le seuil) ; le relachement sera un toucher.
enum Geste { AUCUN, DEFILER, PRENDRE }

## Couleurs de la zone de depot. Or = « tu peux lacher ici », rouge = « lacher
## ici sera refuse » — les deux couleurs d etat deja employees par l ecran
## (compteur valide / compteur en defaut).
const HINT_OK: Color = Color(0.95, 0.80, 0.35)
const HINT_REFUSED: Color = Color(0.85, 0.25, 0.28)
## Fond du bandeau de refus : rouge sombre sous un texte creme. Un rouge vif
## sous du texte clair ne passe pas le plancher de contraste.
const NOTICE_BG: Color = Color(0.36, 0.07, 0.09, 0.96)

var _ids: Array = []
var _filter: int = -1  # -1 = toutes les raretes
var _page: int = 0
var _pages: int = 1

## Carte dont la fiche est ouverte et qui sera ajoutee au prochain toucher.
## Vide = aucun toucher en attente.
var _armed_id: StringName = &""

var _tab_bar: HBoxContainer
var _passive_row: HBoxContainer
var _passive_note: Label
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
## Emplacement de passif dont le choix est ouvert sur la page, -1 = aucun.
var _picker_slot: int = -1

## Appui en cours sur une vignette, pas encore un glisser :
## {card, from_deck, start, tile}. Vide = aucun doigt pose sur une carte.
var _press: Dictionary = {}
## Glisser en cours. `_drag_card == null` = aucun.
var _drag_card: SpellCard = null
var _drag_from_deck: bool = false
var _drag_tile: Control = null
var _drag_origin: Vector2 = Vector2.ZERO
## Raison pour laquelle la carte transportee NE POURRA PAS entrer, calculee au
## depart du glisser ("" = elle peut). Affichee dans la zone de depot.
var _drag_refusal: String = ""
var _ghost: Control = null
var _hint: PanelContainer = null
var _hint_lbl: Label = null
var _hint_hover: bool = false
## Defilement au doigt de la zone du deck, commence sur une vignette.
var _scrolling: bool = false
var _scroll_anchor_y: float = 0.0
var _scroll_from: int = 0
## Vignette dont le PROCHAIN `pressed` doit etre ignore : celle sur laquelle un
## defilement a commence (voir `_input`).
var _eat_tap_tile: Control = null
## Bandeau de refus, pose sur le deck.
var _notice: PanelContainer = null
var _notice_lbl: Label = null
var _notice_tween: Tween = null
var _last_refusal: String = ""


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
	# La portee des passifs equipes, juste sous leurs emplacements : sans elle,
	# le joueur qui en equipe trois les attend en campagne, ou ils ne sont pas.
	_passive_note = UiTheme.label(PASSIVES_SCOPE_TEXT, UiTheme.FONT_SMALL, UiTheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	root.add_child(_passive_note)

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
	_picker_slot = -1
	# Un glisser ou un bandeau d une visite precedente n a plus de sens : les
	# vignettes qu ils designent vont etre reconstruites.
	cancel_drag()
	_hide_refusal()
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
	if _picker_slot >= 0:
		_render_passive_picker()
		return
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

	# Le MEME compteur que la section SORTS du grimoire : obtenues / visibles.
	# L ecran de deck n en avait aucun, et le grimoire en avait un autre.
	_coll_label.text = "COLLECTION   -   %s" % collection_counter()

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


## Les passifs EQUIPES : trois emplacements TOUCHABLES (chantier P), hors de la
## page du deck pour qu ils ne se confondent jamais avec les 15 cartes.
## Toucher un emplacement ouvre sur la page le choix parmi les passifs obtenus.
func _render_passives() -> void:
	for c in _passive_row.get_children():
		_passive_row.remove_child(c)
		c.queue_free()
	_passive_row.add_child(UiTheme.label("PASSIFS", UiTheme.FONT_SMALL,
		UiTheme.TEAL, HORIZONTAL_ALIGNMENT_LEFT, false))
	# Rien avant l acte 2 : trois emplacements qui ne serviraient a rien se
	# liraient comme une fonction cassee. On dit plutot QUAND ils s ouvrent.
	if not SaveData.passives_unlocked():
		var verrou: Label = UiTheme.label("s ouvrent a l acte %d" % LevelDef.PASSIVES_FROM_ACT,
			UiTheme.FONT_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
		verrou.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_passive_row.add_child(verrou)
		return
	var equipes: Array[SpellCard] = equipped_passive_cards()
	for slot in DeckRules.MAX_PASSIVES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, PASSIVE_SLOT_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		if slot < equipes.size():
			b.text = equipes[slot].display_name
			b.add_theme_color_override(&"font_color", UiTheme.GOLD)
		else:
			b.text = "+ libre"
			b.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM)
		# L emplacement dont le choix est ouvert est encadre : le joueur sait
		# lequel il est en train de remplir.
		if slot == _picker_slot:
			b.add_theme_stylebox_override(&"normal", UiTheme.flat_box(
				UiTheme.PANEL_LIGHT, 12, 12.0, UiTheme.GOLD, 5))
		var idx: int = slot
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			open_passive_picker(idx))
		_passive_row.add_child(b)


## La phrase de portee des passifs equipes, telle qu elle est affichee.
## Exposee pour les tests : la regle "pas en campagne" doit se LIRE a l ecran.
func passive_scope_text() -> String:
	return _passive_note.text if _passive_note != null and _passive_note.visible else ""


## Les passifs equipes et valides, dans l ordre des emplacements.
func equipped_passive_cards() -> Array[SpellCard]:
	return SaveData.equipped_passive_cards()


## Les passifs que le joueur PEUT equiper : obtenus, tries comme la collection.
func passive_choices() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive and SaveData.is_discovered(c.id):
			out.append(c)
	out.sort_custom(_sort_cards)
	return out


## La liste d ids equipes apres avoir mis `card_id` dans l emplacement `slot`.
## Logique pure, testee a froid. Un passif deja equipe AILLEURS change de place
## au lieu d etre en double (deux fois le meme passif ne fait rien de plus et
## volerait un emplacement). Un emplacement au-dela de la fin se range a la
## suite : les emplacements sont une liste, pas des trous.
static func passives_with(ids: Array, slot: int, card_id: StringName) -> Array:
	var out: Array = []
	for id in ids:
		out.append(String(id))
	var deja: int = out.find(String(card_id))
	if deja != -1:
		out.remove_at(deja)
		if deja < slot:
			slot -= 1
	slot = clampi(slot, 0, out.size())
	if slot < out.size():
		out[slot] = String(card_id)
	else:
		out.append(String(card_id))
	while out.size() > DeckRules.MAX_PASSIVES:
		out.pop_back()
	return out


## Emplacement dont le choix est ouvert, -1 si aucun.
func picker_slot() -> int:
	return _picker_slot


func open_passive_picker(slot: int) -> void:
	if not SaveData.passives_unlocked():
		return
	_picker_slot = clampi(slot, 0, DeckRules.MAX_PASSIVES - 1)
	_armed_id = &""
	_detail_card = null
	_render()


func close_passive_picker() -> void:
	_picker_slot = -1
	_render()


## Equipe `card` dans l emplacement `slot`. Refuse un passif non obtenu ou un
## sort : l ecran ne doit jamais ecrire au profil ce que le combat refuserait.
func equip_passive_in_slot(slot: int, card: SpellCard) -> bool:
	if card == null or not card.is_passive or not SaveData.is_discovered(card.id):
		return false
	if not SaveData.passives_unlocked():
		return false
	var ids: Array = []
	for c in equipped_passive_cards():
		ids.append(String(c.id))
	SaveData.set_equipped_passives(passives_with(ids, slot, card.id))
	SaveData.save_profile()
	_picker_slot = -1
	_render()
	return true


## Vide l emplacement `slot` ; les suivants remontent d un cran.
func clear_passive_slot(slot: int) -> void:
	var ids: Array = []
	for c in equipped_passive_cards():
		ids.append(String(c.id))
	if slot >= 0 and slot < ids.size():
		ids.remove_at(slot)
	SaveData.set_equipped_passives(ids)
	SaveData.save_profile()
	_picker_slot = -1
	_render()


## Le choix d un passif, a la place des grilles sur la MEME page (comme la fiche
## d une carte) : une grille des passifs obtenus, l equipe en or.
func _render_passive_picker() -> void:
	_deck_scroll.visible = false
	_coll_label.visible = false
	_grid.visible = false
	_filters.visible = false
	_cale.visible = false
	_detail_box.visible = true
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	_header.text = "PASSIF  -  emplacement %d / %d" % [_picker_slot + 1, DeckRules.MAX_PASSIVES]
	_header.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	_page_label.text = "actifs des le debut, en Infini et en Massacre"
	_page_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 10)
	scroll.add_child(box)

	var choix: Array[SpellCard] = passive_choices()
	if choix.is_empty():
		box.add_child(UiTheme.label(
			"Aucun passif obtenu. Ils se gagnent a la montee de niveau, a partir de l acte %d."
			% LevelDef.PASSIVES_FROM_ACT, UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_CENTER))
	var grille := GridContainer.new()
	grille.columns = COLS
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override(&"h_separation", 8)
	grille.add_theme_constant_override(&"v_separation", 8)
	box.add_child(grille)
	var equipes: Array[SpellCard] = equipped_passive_cards()
	for p in choix:
		var ou: int = equipes.find(p)
		# Le SEUIL en pied de vignette : c est la seule chose qui distingue deux
		# passifs d un coup d oeil, et ce qui dit quand il agira.
		var pied: String = "des %d %%" % p.speed_threshold
		if ou != -1:
			pied = "equipe (%d)" % (ou + 1)
		var t: Button = _tile(p, pied, UiTheme.GOLD if ou != -1 else UiTheme.TEXT,
			equip_passive_in_slot.bind(_picker_slot, p), p.description)
		grille.add_child(t)

	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override(&"separation", 12)
	_detail_box.add_child(boutons)
	var retirer := Button.new()
	retirer.text = "RETIRER"
	retirer.custom_minimum_size = Vector2(0, 110)
	retirer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retirer.disabled = _picker_slot >= equipes.size()
	var slot: int = _picker_slot
	retirer.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		clear_passive_slot(slot))
	boutons.add_child(retirer)
	var fermer := Button.new()
	fermer.text = "FERMER"
	fermer.custom_minimum_size = Vector2(0, 110)
	fermer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fermer.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		close_passive_picker())
	boutons.add_child(fermer)


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
		var t: Button = _tile(card, "x%d" % counts[id],
			UiTheme.rarity_color(card.rarity), _on_remove.bind(card),
			"Toucher pour retirer un exemplaire, ou glisser vers la collection")
		_make_draggable(t, card, true)
		_deck_grid.add_child(t)
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
##
## La liste ET son ordre viennent de SaveData.visible_cards, la meme que le
## grimoire (retouche du 30/09) : obtenues d abord, grisees ensuite. Avant, les
## cartes grisees etaient melangees aux autres par rarete, si bien que le joueur
## tournait des pages de cartes inutilisables pour trouver de quoi composer.
func collection() -> Array:
	var out: Array = []
	for card: SpellCard in SaveData.visible_cards(false):
		if _filter != -1 and card.rarity != _filter:
			continue
		out.append(card)
	return out


## Le compteur de la collection, mot pour mot celui du grimoire (section SORTS).
static func collection_counter() -> String:
	return CollectionStyle.counter(SaveData.card_counts(0), "obtenues")


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
			# OBTENABLE : lisible mais GRISEE. Elle reste touchable pour que sa
			# fiche dise ou l obtenir ; AJOUTER y est refuse par DeckRules. Pas
			# glissable : un glisser montrerait la meme raison, sans la fiche.
			# Grisee comme au grimoire (CollectionStyle) : fond et icone, PAS le
			# texte. L ancien `modulate` voilait aussi le nom, et le pied en
			# TEXT_DIM etait assombri deux fois : illisible sur capture.
			var grise: Button = _tile(card, CollectionStyle.FOOT_OBTAINABLE, UiTheme.TEXT,
				_on_collection_tap.bind(card), "")
			CollectionStyle.grey(grise, grise.get_meta(&"art", null) as Control)
			_grid.add_child(grise)
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
		# Elle reste aussi GLISSABLE : le glisser montre la raison du refus
		# dans la zone de depot, et la carte revient.
		_make_draggable(tile, card, false)
		_grid.add_child(tile)
	for _i in PER_PAGE - (fin - start):
		var vide := Control.new()
		vide.custom_minimum_size = Vector2(0, TILE_H)
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(vide)


## L image d une carte de cet ecran : son icone de sort (CardIcons) portant le
## SCEAU DE TYPE (CardView.with_type_badge), comme au grimoire et sur la carte
## en main. L ecran de deck etait le seul a montrer l icone nue : c est pourtant
## ici qu on compose en comptant ses elements. Rend un porteur (icone + sceau)
## que CollectionStyle.grey sait griser image par image. Nul si la carte n a
## pas d icone. Statique : le test la lit sans construire l ecran.
static func type_art(card: SpellCard, px: float) -> Control:
	var icone: TextureRect = CardIcons.make_rect(card, px)
	if icone == null:
		return null
	return CardView.with_type_badge(icone, card, px)


## Une vignette de carte : l icone du sort (CardIcons, la meme qu en jeu) et son
## sceau de type, son nom, et une ligne de pied. Meme forme que celles du grimoire.
func _tile(card: SpellCard, pied: String, teinte: Color,
		action: Callable, aide: String) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.clip_contents = true
	tile.tooltip_text = aide
	# La carte de TOUTE vignette, grisee comprise (`card_id`, lui, ne marque que
	# les vignettes glissables). Lue par le test du sceau de type.
	tile.set_meta(&"tile_card_id", card.id)

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

	var art: Control = type_art(card, ICON_PX)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)
		# Retrouvee par l appelant pour griser l image seule (CollectionStyle) :
		# l icone ET le sceau, jamais le texte.
		tile.set_meta(&"art", art)

	var nom: Label = UiTheme.label(card.display_name, UiTheme.FONT_SMALL,
		UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(nom)
	box.add_child(UiTheme.label(pied, UiTheme.FONT_SMALL, teinte,
		HORIZONTAL_ALIGNMENT_CENTER, false))

	tile.pressed.connect(func() -> void:
		# Le relachement d un DEFILEMENT n est pas un toucher : le contenu a
		# suivi le doigt, qui se retrouve donc au-dessus de la meme vignette,
		# et le Button croit a un appui complet. Sans cette garde, faire
		# defiler le deck retirait la carte sous le pouce.
		if _eat_tap_tile == tile:
			_eat_tap_tile = null
			return
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
##
## La decision passe par `DeckRules.refusal_reason` et par elle seule : c est la
## SEULE source des regles de composition. Le joueur lit la chaine qu elle rend,
## telle quelle — l ecran ne reformule pas une regle qu il ne possede pas.
func _do_add(card: SpellCard) -> bool:
	var raison: String = refusal_for(card)
	if raison != "":
		_render()
		show_refusal(raison)
		return false
	_hide_refusal()
	_ids.append(String(card.id))
	_save()
	_render()
	return true


## Pourquoi `card` ne peut pas entrer dans le deck courant ("" = elle peut).
func refusal_for(card: SpellCard) -> String:
	if card == null:
		return ""
	return DeckRules.refusal_reason(_ids, card, SaveData.is_discovered(card.id))


## Etat du double toucher, expose pour les tests et pour le retour visuel.
func armed_card() -> StringName:
	return _armed_id


func _on_remove(card: SpellCard) -> void:
	# Retirer une carte desarme : sans cela, le toucher suivant sur la vignette
	# armee la RE-ajouterait, ce que le joueur vient justement de defaire.
	_armed_id = &""
	_detail_card = null
	if not _remove_one(card):
		return
	# Le refus affiche (« deck complet »...) vient peut-etre d etre resolu par ce
	# retrait : le laisser a l ecran dirait le contraire de l etat du deck.
	_hide_refusal()
	_render()


## Retire UN exemplaire. Rend faux si la carte n est pas dans le deck.
func _remove_one(card: SpellCard) -> bool:
	var idx: int = _ids.find(String(card.id))
	if idx == -1:
		return false
	_ids.remove_at(idx)
	_save()
	return true


# --- Glisser-deposer (UI-006) ---

## Rend une vignette glissable. On n ecoute que l APPUI ici : le suivi et le
## relachement passent par `_input()`, seul endroit ou le relachement arrive
## avant que le Button ne l avale.
func _make_draggable(tile: Button, card: SpellCard, from_deck: bool) -> void:
	tile.set_meta(&"card_id", card.id)
	tile.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_press = {"card": card, "from_deck": from_deck,
					"start": mb.global_position, "tile": tile})


## Ce que devient un appui qui a bouge de `delta` depuis son point de depart.
##
## Sous DRAG_START_PX : rien n est decide, le relachement sera un toucher.
## Au-dela, un appui sur une vignette du DECK dont la zone DEBORDE, parti
## surtout a la verticale, fait DEFILER la zone ; tout le reste PREND la carte.
##
## Pourquoi la direction : la zone du deck ne defile que verticalement, et le
## pouce qui la parcourt part a la verticale. Sans cette regle, le glisser-
## deposer prenait la carte des 28 px dans toutes les directions, et un deck
## trop long ne pouvait defiler qu en visant l interstice de 8 px entre deux
## vignettes (les Button gardent l appui pour eux).
##
## Pourquoi SEULEMENT quand la zone deborde : un deck conforme (6 cartes
## differentes au plus) tient en deux rangees et ne defile jamais. Il garde
## alors le geste d UI-006 a l identique : on tire une carte vers le bas pour
## la rendre a la collection. Retirer d un deck qui deborde reste possible au
## toucher, ou en partant de cote.
##
## La collection n est jamais concernee : elle se feuillette par pages, elle ne
## defile pas, et c est d elle que partent les ajouts vers le deck.
static func gesture_for(from_deck: bool, can_scroll: bool, delta: Vector2) -> int:
	if delta.length() < DRAG_START_PX:
		return Geste.AUCUN
	if from_deck and can_scroll and absf(delta.y) > absf(delta.x):
		return Geste.DEFILER
	return Geste.PRENDRE


func is_scrolling() -> bool:
	return _scrolling


func _input(event: InputEvent) -> void:
	if _press.is_empty() and _drag_card == null and not _scrolling:
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = (event as InputEventMouseMotion).global_position
		if _scrolling:
			# Le contenu suit le doigt : doigt vers le haut = on descend dans
			# le deck. ScrollContainer borne lui-meme la valeur.
			_deck_scroll.scroll_vertical = _scroll_from + int(round(_scroll_anchor_y - p.y))
			get_viewport().set_input_as_handled()
			return
		if _drag_card == null:
			var start: Vector2 = _press["start"]
			match gesture_for(bool(_press["from_deck"]), deck_can_scroll(), p - start):
				Geste.AUCUN:
					return
				Geste.DEFILER:
					_begin_scroll(start.y)
					_deck_scroll.scroll_vertical = _scroll_from + int(round(_scroll_anchor_y - p.y))
					get_viewport().set_input_as_handled()
					return
				_:
					begin_drag(_press["card"], _press["from_deck"], p, _press["tile"])
		drag_to(p)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		if _scrolling:
			_scrolling = false
			# Le relachement va a la vignette, qui emettra `pressed` : c est la
			# garde de `_tile` qui l ignore. On ne marque PAS l evenement traite :
			# un Button prive de son relachement garde le focus souris et
			# volerait l appui suivant, ou qu il tombe.
			# La garde est levee en fin de frame : si le doigt a quitte la
			# vignette (defilement en butee), aucun `pressed` ne viendra, et la
			# garde ne doit pas avaler le toucher suivant.
			_clear_eat_tap.call_deferred()
		if _drag_card != null:
			drop_at(mb.global_position)
			# Le relachement d un glisser n est PAS un toucher. Double garde :
			# le depot reconstruit les vignettes (le Button source quitte
			# l arbre et perd le focus souris), et le relachement est marque
			# traite, pour le jour ou un depot ne reconstruirait plus rien.
			# Verifie par sabotage : retirer cette ligne seule ne suffit pas a
			# rougir le smoke, c est la reconstruction qui porte la garde.
			get_viewport().set_input_as_handled()
		_press = {}


func _begin_scroll(anchor_y: float) -> void:
	_scrolling = true
	_scroll_anchor_y = anchor_y
	_scroll_from = _deck_scroll.scroll_vertical
	_eat_tap_tile = _press.get("tile")
	_press = {}
	# Un defilement n est pas une lecture : pas de carte armee derriere soi.
	_armed_id = &""


func _clear_eat_tap() -> void:
	_eat_tap_tile = null


## Prend une carte. Public pour les tests, qui rejouent le geste sans souris.
func begin_drag(card: SpellCard, from_deck: bool, at: Vector2,
		tile: Control = null) -> void:
	cancel_drag()
	_press = {}
	_drag_card = card
	_drag_from_deck = from_deck
	_drag_tile = tile
	_drag_origin = tile.get_global_rect().get_center() if tile != null else at
	# La raison est connue DES LE DEPART : la zone de depot l affiche pendant
	# tout le glisser (un retrait, lui, ne se refuse jamais).
	_drag_refusal = "" if from_deck else refusal_for(card)
	# Prendre une carte n est pas la lire : on ne laisse aucune carte armee
	# derriere soi, sinon le toucher suivant l ajouterait sans fiche.
	_armed_id = &""
	_hide_refusal()
	if tile != null:
		tile.modulate = Color(1, 1, 1, 0.35)
	_ghost = _make_ghost(card)
	add_child(_ghost)
	_show_hint()
	drag_to(at)


func drag_to(at: Vector2) -> void:
	if _drag_card == null:
		return
	if _ghost != null:
		_ghost.position = at - _ghost.size * 0.5 - Vector2(0.0, GHOST_LIFT)
	var sur: bool = zone_at(at) == _target_zone()
	if sur != _hint_hover:
		_hint_hover = sur
		_style_hint()


## Lache la carte en `at`. Rend vrai si le deck a change.
func drop_at(at: Vector2) -> bool:
	return drop_on(zone_at(at))


## Le coeur du depot, separe de la geometrie pour etre testable a froid :
## en headless les conteneurs ne sont pas encore disposes quand le test lit.
func drop_on(zone: int) -> bool:
	var card: SpellCard = _drag_card
	if card == null:
		return false
	var accepte: bool = false
	if zone == _target_zone():
		if _drag_from_deck:
			accepte = _remove_one(card)
		else:
			# Relue au depot et non reprise du depart : c est la regle a
			# l instant du geste qui fait foi.
			var raison: String = refusal_for(card)
			if raison == "":
				_ids.append(String(card.id))
				_save()
				accepte = true
			else:
				show_refusal(raison)
	_end_drag(accepte)
	return accepte


## Abandonne le glisser en cours sans rien changer au deck.
func cancel_drag() -> void:
	if _drag_card != null:
		_end_drag(false)
	_press = {}
	_scrolling = false
	_eat_tap_tile = null


func is_dragging() -> bool:
	return _drag_card != null


## Les vignettes glissables affichees (deck ou page de collection courante).
## Pour le smoke, qui rejoue le geste au doigt sur de vraies positions.
func draggable_tiles(in_deck: bool) -> Array[Button]:
	var out: Array[Button] = []
	for c in (_deck_grid if in_deck else _grid).get_children():
		if c is Button and c.has_meta(&"card_id"):
			out.append(c)
	return out


## La zone du deck qui defile (pour le smoke, qui mesure le defilement).
func deck_scroll() -> ScrollContainer:
	return _deck_scroll


## Vrai si le deck a plus de vignettes que sa zone n en montre. C est le cas
## d un deck HORS REGLE (plus de DeckRules.MAX_DISTINCT cartes differentes,
## typiquement un profil anterieur a la regle des six) : justement celui ou le
## joueur doit tout voir pour savoir quoi retirer.
func deck_can_scroll() -> bool:
	if _deck_scroll == null or _deck_grid == null:
		return false
	return _deck_grid.get_combined_minimum_size().y > _deck_scroll.size.y + 1.0


## La zone ou il faut lacher : le deck pour une carte de la collection, la
## collection pour une carte du deck.
func _target_zone() -> int:
	return Zone.COLLECTION if _drag_from_deck else Zone.DECK


func zone_at(at: Vector2) -> int:
	if deck_zone_rect().has_point(at):
		return Zone.DECK
	if collection_zone_rect().has_point(at):
		return Zone.COLLECTION
	return Zone.NONE


## Zone du deck : l en-tete (le compteur) PLUS la grille. Une cible genereuse,
## parce qu on vise au pouce et que l en-tete est ce que l on regarde en
## deposant.
func deck_zone_rect() -> Rect2:
	return _header.get_global_rect().merge(_deck_scroll.get_global_rect())


## Zone de la collection : de son titre au bas de la grille, filtres compris.
func collection_zone_rect() -> Rect2:
	return _coll_label.get_global_rect().merge(_filters.get_global_rect()) \
		.merge(_grid.get_global_rect())


func _end_drag(accepte: bool) -> void:
	var ghost: Control = _ghost
	_ghost = null
	_drag_card = null
	_drag_tile = null
	_hint_hover = false
	if _hint != null:
		_hint.visible = false
	if ghost != null:
		if accepte or not Fx.enabled() or not is_inside_tree():
			ghost.queue_free()
		else:
			# Le RETOUR : la carte repart vers sa vignette. C est lui qui dit
			# « rien n a change », sans un mot.
			var tw: Tween = ghost.create_tween()
			tw.tween_property(ghost, "position",
				_drag_origin - ghost.size * 0.5, RETURN_S) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_callback(ghost.queue_free)
	# Reconstruire rend aussi a la vignette source son opacite, et remet a zero
	# l etat « enfonce » du Button dont on a avale le relachement.
	_render()


## La carte transportee : meme forme que la vignette, un peu plus petite, pour
## que la zone de depot reste visible autour.
func _make_ghost(card: SpellCard) -> Control:
	var g := PanelContainer.new()
	g.top_level = true
	g.z_index = 50
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size = Vector2(TILE_W, TILE_H * 0.8)
	g.custom_minimum_size = g.size
	g.add_theme_stylebox_override(&"panel", UiTheme.rarity_border(card.rarity,
		UiTheme.PANEL_LIGHT.lightened(0.05)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(box)
	# La carte transportee garde son sceau : c est la meme carte.
	var art: Control = type_art(card, ICON_PX)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)
	var nom: Label = UiTheme.label(card.display_name, UiTheme.FONT_SMALL,
		UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nom)
	return g


## La zone de depot, posee PAR-DESSUS la zone visee pendant tout le glisser.
func _show_hint() -> void:
	if _hint == null:
		_hint = PanelContainer.new()
		_hint.top_level = true
		_hint.z_index = 40
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_lbl = UiTheme.label_hud("", UiTheme.FONT_BODY, UiTheme.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.add_child(_hint_lbl)
		add_child(_hint)
	var r: Rect2 = collection_zone_rect() if _drag_from_deck else deck_zone_rect()
	_hint.position = r.position
	_hint.size = r.size
	if _drag_from_deck:
		_hint_lbl.text = "DEPOSER ICI\npour retirer du deck"
	elif _drag_refusal != "":
		_hint_lbl.text = _drag_refusal
	else:
		_hint_lbl.text = "DEPOSER ICI\npour ajouter au deck"
	_hint_hover = false
	_style_hint()
	_hint.visible = true


## Or si on peut lacher, rouge si ce sera refuse ; plus appuye quand le doigt
## est DANS la zone, pour que le joueur sache qu il vise juste.
func _style_hint() -> void:
	if _hint == null:
		return
	var teinte: Color = HINT_REFUSED if _drag_refusal != "" else HINT_OK
	var fond := Color(0.08, 0.06, 0.12, 0.72 if _hint_hover else 0.50)
	_hint.add_theme_stylebox_override(&"panel", UiTheme.flat_box(fond, 18, 24.0,
		teinte, 10 if _hint_hover else 6))
	_hint_lbl.add_theme_color_override(&"font_color",
		Color(1.0, 0.80, 0.80) if _drag_refusal != "" else Color(1.0, 0.93, 0.70))


func drop_hint_visible() -> bool:
	return _hint != null and _hint.visible


func drop_hint_text() -> String:
	return _hint_lbl.text if _hint_lbl != null else ""


## Affiche POURQUOI un ajout vient d etre refuse, en bandeau sur le deck.
## Il s efface seul : c est un retour sur un geste, pas un etat de l ecran.
func show_refusal(raison: String) -> void:
	_last_refusal = raison
	if raison == "":
		_hide_refusal()
		return
	if _notice == null:
		_notice = PanelContainer.new()
		_notice.top_level = true
		_notice.z_index = 45
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice.add_theme_stylebox_override(&"panel", UiTheme.flat_box(NOTICE_BG, 18, 22.0,
			HINT_REFUSED, 4))
		_notice_lbl = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		_notice_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice.add_child(_notice_lbl)
		add_child(_notice)
	_notice_lbl.text = raison
	_notice.visible = true
	_fit_notice()
	# Second recalage APRES le tri differe du conteneur. Un Label a retour a la
	# ligne mesure sa hauteur sur sa largeur COURANTE : tant que le conteneur ne
	# lui a pas donne la sienne, il la mesure a largeur nulle, une lettre par
	# ligne — le bandeau naissait haut comme la page (vu sur `deck_refus`). Un
	# Control `top_level` ne rapetisse jamais seul : il faut le remesurer.
	_fit_notice.call_deferred()
	# Minuterie portee par le bandeau lui-meme : liberee avec lui, elle ne peut
	# pas rappeler un ecran detruit. Un nouveau refus relance le compte.
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	if _notice.is_inside_tree():
		_notice_tween = _notice.create_tween()
		_notice_tween.tween_interval(NOTICE_S)
		_notice_tween.tween_callback(_hide_refusal)


## Pose le bandeau en bas de la zone du deck : c est la que le joueur vient de
## lacher, donc la que son regard se trouve. Hauteur = celle du texte, pas plus.
func _fit_notice() -> void:
	if _notice == null or not is_instance_valid(_notice) or not _notice.visible:
		return
	var r: Rect2 = deck_zone_rect()
	var w: float = maxf(r.size.x - 40.0, 120.0)
	_notice_lbl.custom_minimum_size = Vector2(w - 44.0, 0.0)
	_notice.reset_size()
	_notice.size = Vector2(w, _notice.get_combined_minimum_size().y)
	_notice.position = Vector2(r.position.x + 20.0, r.end.y - _notice.size.y - 12.0)


func _hide_refusal() -> void:
	_last_refusal = ""
	if _notice != null:
		_notice.visible = false


## Le message de refus affiche en ce moment ("" = aucun).
func refusal_message() -> String:
	return _last_refusal


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

	var art: Control = type_art(card, 180.0)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Fiche d une carte grisee : l icone et le sceau grises, comme au grimoire.
		if not SaveData.is_discovered(card.id):
			CollectionStyle.grey(null, art)
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
	var raison: String = refusal_for(card)
	add.disabled = raison != ""
	# Un bouton grise sans raison est une impasse : on dit POURQUOI juste dessous.
	if add.disabled:
		# Pour une carte OBTENABLE, le pourquoi est aussi un OU : la meme phrase
		# que le grimoire, qui nomme les niveaux ou la prendre.
		if not SaveData.is_discovered(card.id):
			raison = CollectionStyle.where_to_obtain(card)
		box.add_child(UiTheme.label(raison, UiTheme.FONT_SMALL,
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
