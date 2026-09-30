class_name GalleryPanel
extends Control
## Onglet Galerie — le GRIMOIRE. Un seul ecran pour les trois catalogues du jeu.
##
##   +--------------------------------------------------+
##   |  [comete] SORTS  [aile] PASSIFS  [griffe] BESTES |  <- 3 sections
##   +--------------------------------------------------+
##   | ,----------------------------------------------. |
##   |(|           8 / 14 obtenues                    |)|  <- page de livre
##   |(|  +-------+  +-------+  +-------+             |)|
##   |(|  | icone |  | icone |  | grise |             |)|  grille 3 x 3
##   |(|  |  nom  |  |  nom  |  |  nom  |             |)|  acquis, puis grises
##   | [<]                                        [>]  |  <- changer de page
##   | `----------------------------------------------' |
##   +--------------------------------------------------+
##
## POURQUOI UNE FUSION
## -------------------
## La galerie et le bestiaire etaient deux onglets voisins faisant la meme chose
## (une grille de fiches a consulter) avec deux barres d onglets a traverser. Le
## testeur a demande de n en faire qu un, en forme de LIVRE. Un seul onglet, et
## la barre du bas descend de 6 a 4 entrees, donc des cibles tactiles plus larges.
##
## POURQUOI DES PAGES ET NON UN DEFILEMENT
## ---------------------------------------
## Un livre tourne des pages. Surtout : une liste de 45 cartes en defilement
## libre ne dit jamais au joueur ou il en est ni combien il reste. Une page
## numerotee ("2 / 5") est une position, un defilement n en est pas une. Les
## deux fleches sont posees sur les BORDS de l ecran, la ou le pouce tombe.
##
## POURQUOI PAS DE DOUBLE PAGE
## ---------------------------
## L ecran est portrait (1080 de large) : deux colonnes de 480 px donneraient
## des vignettes de 150 px et un texte de fiche sur 8 mots par ligne. La page
## affichee est donc UNE page du livre (`book_page`, extraite par
## tools/assets/extract_book.py), et le fait de tourner remplace la double page.

## Les trois sections du grimoire. L ordre est celui de la progression du
## joueur : il lance des sorts, puis gagne des passifs, et rencontre des
## monstres tout du long.
enum Section { SPELLS, PASSIVES, BEASTS }

const SECTIONS: Array[String] = ["SORTS", "PASSIFS", "BESTIAIRE"]
const SECTION_ICONS: Array[String] = ["book_spells", "book_passives", "book_beasts"]

## 3 colonnes x 3 lignes. Calibre sur la hauteur reelle de la page : une 4e
## ligne sortait de la page et se faisait rogner (verifie sur capture).
const COLS: int = 3
const ROWS: int = 3
const PER_PAGE: int = COLS * ROWS

## Cibles tactiles. La fleche de page fait 200x150, la vignette ~310x310 : toutes
## bien au-dela des 90 px exiges sur mobile.
##
## TILE_H est cale pour qu une page PLEINE (3 lignes) remplisse exactement le
## papier, en-tete et pied de page deduits. Mesure sur capture : a 250 px il
## restait un quart de page blanc sous la derniere ligne.
const ARROW_W: float = 200.0
const ARROW_H: float = 150.0
const TILE_H: float = 310.0
const ICON_PX: float = 110.0
## Teintes d une entree GRISEE (carte a obtenir, monstre a rencontrer). Elles
## vivent dans CollectionStyle, partagees avec l ecran de deck : le meme etat se
## lit de la meme facon partout.
const GREY_ART: Color = CollectionStyle.GREY_ART
const GREY_TILE: Color = CollectionStyle.GREY_TILE
const ICON_PX_BIG: float = 230.0

var _section: int = Section.SPELLS
var _page: int = 0
var _pages: int = 1

var _section_bar: HBoxContainer
var _section_buttons: Array[Button] = []
var _page_frame: PanelContainer
var _header: Label
var _grid: GridContainer
var _prev: Button
var _next: Button
## Le numero de page, entre les deux fleches : une position, pas un defilement.
var _page_label: Label
## Cale entre la grille et le pied de page. Masquee quand la fiche est ouverte :
## sinon la fiche et la cale se PARTAGENT la hauteur libre et la fiche se
## retrouve coupee au tiers de la page (vu sur capture, FERMER chevauchait le
## texte).
var _cale: Control
## Fiche detaillee : elle occupe la page a la place de la grille. Les memes
## fleches la font defiler d une entree a l autre (demande du testeur).
var _detail_box: VBoxContainer
var _detail_index: int = -1


func _ready() -> void:
	_build()
	refresh()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)

	_section_bar = HBoxContainer.new()
	_section_bar.add_theme_constant_override(&"separation", 10)
	root.add_child(_section_bar)
	for i in SECTIONS.size():
		var b := Button.new()
		b.text = SECTIONS[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 110)   # cible tactile confortable
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		b.clip_text = true
		b.icon = UiTheme.tex(SECTION_ICONS[i])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			show_section(idx))
		_section_bar.add_child(b)
		_section_buttons.append(b)

	_page_frame = PanelContainer.new()
	_page_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Page de livre en 9-tranches (book_page9, extraite du pack magic book).
	_page_frame.add_theme_stylebox_override(&"panel", UiTheme.book_page_box())
	root.add_child(_page_frame)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", 12)
	_page_frame.add_child(inner)

	# Encre SOMBRE : la page du livre est un papier creme (229,214,161). Un texte
	# clair y est invisible — le defaut deja corrige sur les autres panneaux.
	_header = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	inner.add_child(_header)

	_grid = GridContainer.new()
	_grid.columns = COLS
	# La grille ne s etire PAS : c est la cale sous elle qui absorbe le reste de
	# la page. Une grille etiree redistribuait la hauteur entre les vignettes
	# ET les cases vides, donc une page de 3 passifs affichait trois vignettes
	# geantes puis six trous — la page changeait de forme selon son contenu.
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	inner.add_child(_grid)

	_detail_box = VBoxContainer.new()
	_detail_box.visible = false
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override(&"separation", 8)
	inner.add_child(_detail_box)

	# Cale : elle pousse le pied de page vers le BAS quand la grille est courte
	# (les passifs ne remplissent qu une ligne). Sans elle, les fleches
	# flottaient au milieu du papier, sous trois vignettes.
	_cale = Control.new()
	_cale.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_cale)

	# Les deux fleches en BAS de la page, de part et d autre.
	#
	# Premiere version : posees en superposition au milieu des bords gauche et
	# droit. Lu sur capture, c etait un double echec — l image flottait au
	# milieu du vide sans dire qu elle etait un bouton, et elle RECOUVRAIT la
	# premiere et la troisieme colonne de vignettes, donc volait leur toucher.
	# En bas, elles sont dans la zone du pouce, encadrent le numero de page
	# qu elles changent, et ne masquent plus rien.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	inner.add_child(footer)

	_prev = _arrow("book_turn_left", -1)
	footer.add_child(_prev)

	_page_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, false)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_page_label)

	_next = _arrow("book_turn_right", 1)
	footer.add_child(_next)


## Une fleche de page : l image d une page qui se souleve, tiree du pack.
## `dir` vaut -1 (page precedente) ou +1 (suivante).
func _arrow(tex_name: String, dir: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ARROW_W, ARROW_H)
	b.icon = UiTheme.tex(tex_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Le cadre du bouton est CONSERVE : sans lui, sur la page creme, l image
	# d une page qui se souleve ressemble a un motif du papier et personne ne
	# devine qu on peut la toucher (verifie sur capture).
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		turn_page(dir))
	return b


# --- Etat, pilotable par les tests sans passer par les boutons ---

func show_section(section: int) -> void:
	section = clampi(section, 0, SECTIONS.size() - 1)
	if section != _section:
		_section = section
		_page = 0
	_detail_index = -1
	refresh()


## Tourne d une page. Dans la fiche detaillee, la meme fleche passe a l entree
## SUIVANTE : le testeur a demande que les fleches servent aux deux.
func turn_page(dir: int) -> void:
	if _detail_index >= 0:
		var n: int = entries().size()
		if n > 0:
			_detail_index = posmod(_detail_index + dir, n)
			# La page suit la fiche : en fermant, on retombe au bon endroit.
			_page = _detail_index / PER_PAGE
			_render_detail()
		return
	if _pages <= 1:
		return
	_page = posmod(_page + dir, _pages)
	refresh()


func current_section() -> int:
	return _section


func current_page() -> int:
	return _page


func page_count() -> int:
	return _pages


func detail_index() -> int:
	return _detail_index


## Les entrees de la section courante, dans l ordre d affichage.
## Statique par section : les tests comptent les pages sans construire l ecran.
func entries() -> Array:
	return entries_of(_section)


## VISIBILITE EN TROIS ETATS, pour les trois sections (chantier P, puis retouche
## du 30/09 pour le bestiaire) :
##   - SORTS / PASSIFS : les cartes OBTENUES, puis les OBTENABLES grisees
##     (SaveData.visible_cards, la MEME liste et le MEME ordre que l ecran de
##     deck). Une carte qu on ne peut pas encore obtenir est INVISIBLE.
##   - BESTIAIRE : les monstres RENCONTRES, puis ceux A RENCONTRER dans un niveau
##     ouvert, grises (SaveData.enemy_visibility). Les ombres "???" de tout le
##     bestiaire ont disparu : un monstre d un niveau pas encore atteint n a rien
##     a dire au joueur, et 85 silhouettes devoilaient la taille du jeu entier.
## Acquis d abord, grises ensuite : la premiere page montre ce que le joueur a.
static func entries_of(section: int) -> Array:
	var out: Array = []
	match section:
		Section.SPELLS, Section.PASSIVES:
			out.assign(SaveData.visible_cards(section == Section.PASSIVES))
		Section.BEASTS:
			var grises: Array = []
			var atteints: Dictionary = SaveData.reachable_enemy_ids()
			for e: EnemyDef in catalog_of(section):
				if SaveData.is_enemy_discovered(e.id):
					out.append(e)
				elif atteints.has(e.id):
					grises.append(e)
			out.append_array(grises)
	return out


## TOUT le catalogue d une section, visible ou non, dans l ordre d affichage.
## Ce n est PLUS le denominateur du compteur (retouche du 30/09) : "8 / 50"
## annoncait 50 cartes dont 36 invisibles. Le compteur compte ce qui se voit.
static func catalog_of(section: int) -> Array:
	var out: Array = []
	match section:
		Section.SPELLS:
			for card: SpellCard in ContentDB.cards.values():
				if not card.is_passive:
					out.append(card)
			out.sort_custom(_sort_cards)
		Section.PASSIVES:
			for card: SpellCard in ContentDB.cards.values():
				if card.is_passive:
					out.append(card)
			out.sort_custom(_sort_cards)
		Section.BEASTS:
			for e: EnemyDef in ContentDB.enemies.values():
				# Les PROJECTILES ne sont pas des creatures. Une boule de poison
				# tiree par un Planogo est un monstre du terrain pour le moteur
				# (donc ciblable et destructible sans code neuf), mais le
				# commentaire d EnemyDef.projectile promet "ni bestiaire, ni XP"
				# et seule la moitie XP etait tenue : elle occupait une fiche,
				# entre deux vraies especes.
				if e.projectile:
					continue
				out.append(e)
			out.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool:
				if a.power != b.power:
					return a.power < b.power
				return a.display_name < b.display_name)
	return out


static func _sort_cards(a: SpellCard, b: SpellCard) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return a.display_name < b.display_name


## Une carte OBTENABLE : visible et lisible, mais grisee (pas encore prise).
static func is_obtainable(entry: Object) -> bool:
	return entry is SpellCard and SaveData.card_visibility((entry as SpellCard).id) 		== SaveData.CARD_OBTAINABLE


## Un monstre A RENCONTRER : dans un niveau ouvert, jamais combattu.
static func is_reachable(entry: Object) -> bool:
	return entry is EnemyDef and SaveData.enemy_visibility((entry as EnemyDef).id) \
		== SaveData.ENEMY_REACHABLE


## Une entree GRISEE, quelle que soit la section : lisible, pas encore acquise.
static func is_greyed(entry: Object) -> bool:
	return is_obtainable(entry) or is_reachable(entry)


## Une entree est-elle decouverte (carte OBTENUE, monstre rencontre) ? Les
## cartes et les monstres ont deux registres distincts dans SaveData, le livre
## les unifie.
static func is_known(entry: Object) -> bool:
	if entry is SpellCard:
		return SaveData.is_discovered((entry as SpellCard).id)
	if entry is EnemyDef:
		return SaveData.is_enemy_discovered((entry as EnemyDef).id)
	return false


## Nombre de pages d une section : au moins 1, meme vide (une page "rien ici"
## vaut mieux qu un livre sans page, qui aurait l air casse).
static func pages_for(count: int) -> int:
	return maxi(1, int(ceil(float(count) / float(PER_PAGE))))


# --- Compteurs d usage (demande du testeur) ---
##
## Les compteurs vivent dans les statistiques de defis, deja persistees par
## SaveData : ajouter un troisieme registre aurait duplique la plomberie de
## sauvegarde pour la meme donnee.

static func card_uses(card_id: StringName) -> int:
	return ChallengeTracker.value_of(StringName("card_uses:%s" % card_id))


static func kills_of(enemy_id: StringName) -> int:
	return ChallengeTracker.value_of(StringName("kills:%s" % enemy_id))


# --- Affichage ---

func refresh() -> void:
	var list: Array = entries()
	_pages = pages_for(list.size())
	_page = clampi(_page, 0, _pages - 1)
	for i in _section_buttons.size():
		_section_buttons[i].add_theme_color_override(&"font_color",
			UiTheme.GOLD if i == _section else UiTheme.TEXT)
	if _detail_index >= 0:
		_render_detail()
		return
	_grid.visible = true
	_cale.visible = true
	_detail_box.visible = false
	for c in _grid.get_children():
		c.queue_free()

	_header.text = header_text(_section)
	_page_label.text = "page %d / %d" % [_page + 1, _pages]

	var start: int = _page * PER_PAGE
	var fin: int = mini(start + PER_PAGE, list.size())
	for i in range(start, fin):
		_grid.add_child(_tile(list[i], i))
	# On complete la derniere page avec des cases vides : sans cela les 2 ou 3
	# dernieres fiches s etalent sur toute la largeur et changent de taille d une
	# page a l autre.
	#
	# Ces cases vides NE s etirent PAS en hauteur (contrairement aux vignettes) :
	# sur une section courte comme les passifs, trois vignettes suivies de six
	# vides etires donnaient une page aux trois quarts blanche, qu on lit comme
	# un chargement rate. Sans etirement, la grille se tasse en haut, ce qui est
	# la forme normale d un debut de chapitre.
	for _i in PER_PAGE - (fin - start):
		var vide := Control.new()
		vide.custom_minimum_size = Vector2(0, TILE_H)
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(vide)



## Le compteur d en-tete : ACQUIS / VISIBLES (retouche du 30/09), le meme sur les
## trois sections et sur l ecran de deck (CollectionStyle.counter).
##
## Il annoncait "8 / 50 obtenues" : 50 etait tout le catalogue, dont 36 cartes
## qu aucune page ne montre. Le compteur contredisait la regle "une carte non
## obtenable est invisible" et faisait chercher au joueur des cartes absentes.
## "8 / 14" dit ce que les pages contiennent : 14 vignettes, dont 6 grisees.
static func header_text(section: int) -> String:
	if section == Section.BEASTS:
		return CollectionStyle.counter(SaveData.enemy_counts(), "rencontres")
	var texte: String = CollectionStyle.counter(
		SaveData.card_counts(1 if section == Section.PASSIVES else 0), "obtenues")
	# Une page de passifs VIDE se lisait comme un chargement rate (capture) :
	# avant l acte 2 on dit pourquoi elle est vide.
	if section == Section.PASSIVES and not SaveData.passives_unlocked():
		texte += "\nLes passifs s ouvrent a l acte %d" % LevelDef.PASSIVES_FROM_ACT
	return texte


func _tile(entry: Object, index: int) -> Control:
	var known: bool = is_known(entry)
	# Une entree GRISEE (carte a obtenir, monstre a rencontrer) se lit et s ouvre
	# comme une acquise ; seule sa teinte (et son sous-titre) dit qu elle reste
	# a prendre ou a croiser.
	var grisee: bool = is_greyed(entry)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, TILE_H)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.clip_contents = true

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Le contenu ignore la souris, sinon il avalerait le toucher du bouton.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 4)
	tile.add_child(box)

	var art: Control = _art(entry, ICON_PX, known or grisee)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(art)
	# Le FOND de la vignette et l image sont grises, pas le texte : la meme
	# regle que l ecran de deck, ecrite une fois dans CollectionStyle.
	if grisee:
		CollectionStyle.grey(tile, art)

	var nom: Label = UiTheme.label(_name_of(entry) if known or grisee else "???",
		UiTheme.FONT_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(nom)
	box.add_child(UiTheme.label(_sub_of(entry, known), UiTheme.FONT_SMALL,
		_sub_color(entry, known), HORIZONTAL_ALIGNMENT_CENTER, false))

	if known or grisee:
		tile.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			open_detail(index))
	else:
		tile.disabled = true
	return tile


static func _name_of(entry: Object) -> String:
	if entry is SpellCard:
		return (entry as SpellCard).display_name
	if entry is EnemyDef:
		return (entry as EnemyDef).display_name
	return ""


func _sub_of(entry: Object, known: bool) -> String:
	if entry is SpellCard:
		var c := entry as SpellCard
		if not known:
			return CollectionStyle.FOOT_OBTAINABLE
		var n: int = card_uses(c.id)
		return "lance %d fois" % n if n > 0 else GameEnums.rarity_name(c.rarity)
	if entry is EnemyDef:
		var e := entry as EnemyDef
		if not known:
			return CollectionStyle.FOOT_REACHABLE
		var k: int = kills_of(e.id)
		return "%d vaincus" % k if k > 0 else "P%d  %d PV" % [e.power, int(e.max_hp)]
	return ""


## Couleur du sous-titre d une vignette.
##
## La vignette est le BOUTON BLEU du pack (un teal moyen). Les couleurs de rarete
## et de puissance y sont delavees : sur la capture, "lance 1 fois" en bleu de
## rare etait un pave gris illisible. On ecrit donc en clair, et la rarete se lit
## sur l icone et sur la fiche, ou le fond est du papier.
func _sub_color(entry: Object, known: bool) -> Color:
	# Une entree grisee l est deja par la teinte de sa vignette : un second
	# assombrissement rendait "a obtenir" illisible (lu sur capture).
	return UiTheme.TEXT if known or is_greyed(entry) else UiTheme.TEXT_DIM


## L image d une entree. Pour une carte : SON icone de sort (CardIcons), qui est
## la feuille d effet qu elle affichera en jeu — le joueur reconnait le sort
## avant de lire son nom. Pour un monstre : la premiere image de sa marche.
func _art(entry: Object, px: float, known: bool) -> Control:
	if entry is SpellCard:
		var tr: TextureRect = CardIcons.make_rect(entry as SpellCard, px)
		if tr == null:
			return null
		if not known:
			# Silhouette : la forme reste, les couleurs disparaissent.
			tr.modulate = Color(0.0, 0.0, 0.0, 0.5)
			return tr
		# Le sceau de TYPE (vague 5), le meme que sur la carte en main : c est
		# dans le grimoire que le joueur apprend a le lire.
		return CardView.with_type_badge(tr, entry as SpellCard, px)
	if entry is EnemyDef:
		return BestiaryLore.portrait_of(entry as EnemyDef, px, known)
	return null


# --- Fiche detaillee ---

func open_detail(index: int) -> void:
	var list: Array = entries()
	if index < 0 or index >= list.size():
		return
	_detail_index = index
	_page = index / PER_PAGE
	_render_detail()


func close_detail() -> void:
	_detail_index = -1
	refresh()


func _render_detail() -> void:
	var list: Array = entries()
	if _detail_index < 0 or _detail_index >= list.size():
		close_detail()
		return
	var entry: Object = list[_detail_index]
	_grid.visible = false
	_cale.visible = false
	_detail_box.visible = true
	for c in _detail_box.get_children():
		c.queue_free()
	_header.text = ""
	_page_label.text = "fiche %d / %d" % [_detail_index + 1, list.size()]

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Sans ce drapeau, le contenu garde sa hauteur minimale et l alignement
	# centre ci-dessous n a rien a centrer.
	scroll.follow_focus = true
	_detail_box.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Contenu CENTRE : une fiche courte (un sort commun tient en six lignes) se
	# tassait en haut d une page aux trois quarts vide, ce qui la faisait lire
	# comme un ecran tronque plutot que comme une page de livre.
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 10)
	scroll.add_child(box)

	var art: Control = _art(entry, ICON_PX_BIG, true)
	if art != null:
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if is_greyed(entry):
			CollectionStyle.grey(null, art)
		box.add_child(art)

	if entry is SpellCard:
		_fill_card(box, entry as SpellCard)
	elif entry is EnemyDef and not is_known(entry):
		_fill_enemy_unmet(box, entry as EnemyDef)
	elif entry is EnemyDef:
		_fill_enemy(box, entry as EnemyDef)

	# Marge interne : les fleches mordent sur les bords bas de la page, le
	# bouton FERMER se tient entre les deux.
	var close := Button.new()
	close.text = "FERMER"
	close.custom_minimum_size = Vector2(0, 110)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size.x = 460.0   # ne passe pas sous les fleches
	close.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		close_detail())
	_detail_box.add_child(close)


func _fill_card(box: VBoxContainer, card: SpellCard) -> void:
	# Encre sombre partout : fond de PAPIER.
	box.add_child(UiTheme.label(card.display_name, UiTheme.FONT_TITLE,
		UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("%s   -   %s" % [
		GameEnums.rarity_name(card.rarity).capitalize(), _targeting_name(card.targeting)],
		UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	_fill_card_type(box, card)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	# 96 px, pas 40 : "Incantation" est un titre LARGE au-dessus d une valeur
	# COURTE, si bien que les deux nombres finissaient cote a cote pendant que
	# leurs titres restaient loin l un de l autre — on ne savait plus lequel
	# allait avec quoi (vu sur capture). L ecart doit separer les COLONNES, pas
	# les titres.
	stats.add_theme_constant_override(&"separation", 96)
	box.add_child(stats)
	stats.add_child(_stat("Incantation", "%s s" % _fmt(card.base_cast_time),
		UiTheme.INK_RARE))
	# Le compteur demande par le testeur : combien de fois ce sort a ete lance.
	stats.add_child(_stat("Lance", str(card_uses(card.id)), UiTheme.INK_LEGENDARY))

	box.add_child(UiTheme.label(card.description, UiTheme.FONT_BODY,
		UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	# OU L OBTENIR : une carte grisee doit dire au joueur ou aller la chercher,
	# sinon la montrer ne sert qu a frustrer.
	if not SaveData.is_discovered(card.id):
		box.add_child(UiTheme.label(where_to_obtain(card), UiTheme.FONT_BODY,
			Color(0.62, 0.12, 0.14), HORIZONTAL_ALIGNMENT_CENTER))
	_fill_upgrades(box, card)


## TYPE DU SORT (vague 5) : son logo et son nom, le meme logo que sur la carte en
## main et devant les pourcentages du bestiaire. C est ICI que le joueur apprend
## le logo : en combat il n aura que l image. Un sort bi-element nomme ses deux
## elements, parce que la resistance lue est la pire des deux.
func _fill_card_type(box: VBoxContainer, card: SpellCard) -> void:
	var ligne := HBoxContainer.new()
	ligne.name = "CardType"
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override(&"separation", 12)
	box.add_child(ligne)
	var logo: TextureRect = ElementIcons.make(card.spell_type(), 64.0)
	if logo != null:
		ligne.add_child(logo)
	var noms: Array[String] = ElementIcons.card_type_names(card)
	var l: Label = UiTheme.label(" + ".join(noms), UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
		HORIZONTAL_ALIGNMENT_LEFT, false)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ligne.add_child(l)


## La phrase qui dit ou obtenir une carte grisee. Elle vit dans CollectionStyle,
## partagee avec l ecran de deck ; gardee ici pour les appelants existants.
static func where_to_obtain(card: SpellCard) -> String:
	return CollectionStyle.where_to_obtain(card)


## Section AMELIORATIONS : tout le pool de voies du sort (RunState.upgrade_lines_for,
## lu via `card.upgrades`), les voies acquises dans la partie en cours en tete de
## ligne "+". Un sort sans voie annonce "a decouvrir" plutot que de disparaitre.
func _fill_upgrades(box: VBoxContainer, card: SpellCard) -> void:
	box.add_child(UiTheme.label("AMELIORATIONS", UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	var lignes: Array = upgrades_of(card)
	if lignes.is_empty():
		box.add_child(UiTheme.label("a decouvrir en combat", UiTheme.FONT_BODY,
			UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		return
	# La fiche montre TOUT le pool du sort, pas un tirage : l ecran de maturation
	# n en montre que trois, et sans cette ligne le joueur prendrait les trois
	# voies vues en partie pour tout ce que le sort peut devenir.
	box.add_child(UiTheme.label("%d voies : chaque maturation en tire %d" % [
		lignes.size(), mini(lignes.size(), GameConfig.LEVEL_UP_CHOICES)],
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for u in lignes:
		var texte: String = str(u.get("text", ""))
		var acquise: bool = bool(u.get("unlocked", false))
		# Non debloquee = grisee, mais LISIBLE : le joueur doit savoir ce qui
		# l attend, c est ce qui lui donne envie de rejouer le sort. En petit :
		# un pool compte jusqu a une douzaine de voies, en corps normal la fiche
		# deviendrait une page a faire defiler pour atteindre la derniere.
		box.add_child(UiTheme.label(("+ " if acquise else "- ") + texte,
			UiTheme.FONT_SMALL,
			UiTheme.TEXT_DARK if acquise else UiTheme.TEXT_DIM))


## Ameliorations d une carte, sous la forme [{text, unlocked}].
## Vide tant que le systeme d amelioration n existe pas ; le jour ou SpellCard
## portera le champ, seule cette fonction changera.
static func upgrades_of(card: SpellCard) -> Array:
	if card == null:
		return []
	if not ("upgrades" in card):
		return []
	var out: Array = []
	for u in card.get("upgrades"):
		if u is Dictionary:
			out.append(u)
	return out


func _fill_enemy(box: VBoxContainer, def: EnemyDef) -> void:
	box.add_child(UiTheme.label(def.display_name, UiTheme.FONT_TITLE,
		BestiaryLore.power_ink(def.power), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("%s   -   puissance %d" % [
		BestiaryLore.kind_name(def.kind), def.power], UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))

	# DEUX PAR DEUX, pas quatre de front. Sur une fiche de 460 px de large, quatre
	# colonnes ne laissaient que 26 px entre elles : les valeurs se touchaient et
	# un mot un peu long comme "vive" debordait sous le titre voisin (vu sur
	# capture). Une grille de deux donne a chaque paire la moitie de la largeur.
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 80)
	stats.add_theme_constant_override(&"v_separation", 10)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stats)
	stats.add_child(_stat("PV", str(int(def.max_hp)), Color(0.62, 0.12, 0.14)))
	stats.add_child(_stat("Vitesse", BestiaryLore.speed_word(def.base_speed),
		UiTheme.INK_RARE))
	stats.add_child(_stat("Degats", str(def.contact_hit()), Color(0.45, 0.30, 0.10)))
	# Le compteur demande par le testeur : combien de ces monstres sont tombes.
	stats.add_child(_stat("Vaincus", str(kills_of(def.id)), UiTheme.INK_LEGENDARY))

	box.add_child(UiTheme.label("COMPETENCES", UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	for line in BestiaryLore.behaviours(def):
		box.add_child(UiTheme.label("- " + line, UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
	_fill_resistances(box, def)


## RESISTANCES en logos (vague 5) : sous chaque mot de groupe (Immunise /
## Resiste / Vulnerable), une ligne par element — son LOGO, puis ce qu il fait
## en clair : « -53 % degats et effets », « +58 % degats », « ni degats ni
## effets ». Le mot reste ecrit : c est lui qui dit si le chiffre est une chance
## ou un obstacle, et un joueur qui ne distingue pas les couleurs lit
## « Resiste » aussi bien qu un autre.
##
## POURQUOI « ET EFFETS » ECRIT SUR CHAQUE LIGNE (retour du co-auteur : « je ne
## sais pas si c est fait ») : depuis la vague 5, une resistance freine aussi le
## ralentissement, l etourdissement, l aspiration, la provocation et le
## repoussement de l element. Une regle qu on ne lit nulle part n existe pas pour
## le joueur ; une phrase d en-tete la pose, et chaque ligne la rappelle la ou
## l oeil se pose. Une FAIBLESSE ne dit que « degats » : elle ne renforce pas
## le controle (EnemyDef.control_factor, plafond a 1).
const RESIST_ICON_PX: float = 56.0


func _fill_resistances(box: VBoxContainer, def: EnemyDef) -> void:
	var groupes: Array[Dictionary] = BestiaryLore.resistance_groups(def)
	if groupes.is_empty():
		return
	box.add_child(UiTheme.label("RESISTANCES", UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	var regle: Label = UiTheme.label(BestiaryLore.RESIST_RULE_TEXT, UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	regle.name = "ResistRule"
	box.add_child(regle)
	for g in groupes:
		var bloc := VBoxContainer.new()
		bloc.name = "Resist_" + str(g["title"])
		bloc.add_theme_constant_override(&"separation", 4)
		box.add_child(bloc)
		bloc.add_child(UiTheme.label(str(g["title"]) + " :", UiTheme.FONT_BODY,
			_resist_ink(str(g["title"])), HORIZONTAL_ALIGNMENT_LEFT, false))
		for item in g["items"]:
			var tag: int = int(item["tag"])
			var mult: float = float(item["mult"])
			var ligne: HBoxContainer = ElementIcons.resistance_row(tag, mult, RESIST_ICON_PX,
				UiTheme.TEXT_DARK, UiTheme.FONT_BODY)
			ligne.name = "Resist_%d" % tag
			bloc.add_child(ligne)


## Encre du mot de groupe, sur PAPIER : rouge sombre pour ce qui gene le joueur,
## vert sombre pour ce qui l aide. Le mot porte le sens, la couleur le confirme.
func _resist_ink(titre: String) -> Color:
	match titre:
		"Immunise": return Color(0.55, 0.10, 0.12)
		"Resiste": return Color(0.50, 0.28, 0.08)
		"Vulnerable": return Color(0.12, 0.42, 0.16)
	return UiTheme.TEXT_DARK


## Fiche d un monstre A RENCONTRER (retouche du 30/09) : lisible mais grisee.
## Son nom, sa nature et sa puissance se lisent, et surtout OU le rencontrer.
## Ses chiffres et ses competences restent a decouvrir en le combattant : c est
## la recompense de la rencontre (voir SaveData, BESTIAIRE EN TROIS ETATS). Une
## fonction a part plutot qu un drapeau dans _fill_enemy, qui porte la fiche
## complete et que d autres chantiers enrichissent.
func _fill_enemy_unmet(box: VBoxContainer, def: EnemyDef) -> void:
	box.add_child(UiTheme.label(def.display_name, UiTheme.FONT_TITLE,
		BestiaryLore.power_ink(def.power), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("%s   -   puissance %d" % [
		BestiaryLore.kind_name(def.kind), def.power], UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label(CollectionStyle.where_to_meet(def), UiTheme.FONT_BODY,
		Color(0.62, 0.12, 0.14), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("COMPETENCES", UiTheme.FONT_SMALL,
		Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("a decouvrir en le combattant", UiTheme.FONT_BODY,
		UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))


func _stat(titre: String, valeur: String, ink: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	v.add_child(UiTheme.label(titre, UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.25),
		HORIZONTAL_ALIGNMENT_CENTER, false))
	v.add_child(UiTheme.label(valeur, UiTheme.FONT_BUTTON, ink,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	return v


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


func _targeting_name(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "Zone visee"
		GameEnums.Targeting.DIRECTION: return "Tir en ligne"
		GameEnums.Targeting.TARGET: return "Cible unique"
	return "Sur soi"
