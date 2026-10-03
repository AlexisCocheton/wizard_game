class_name PausePanel
extends Control
## MENU PAUSE A ONGLETS (vague 8). Il etait une seule feuille defilante dans
## hud.gd : la main, les passifs, puis une ligne de noms « Boule de feu x3 »
## pour tout le deck. Trois questions differentes que le joueur se pose en pause
## avaient une seule page ; il les a maintenant chacune la sienne.
##
##   +------------------------------------------+
##   |                 PAUSE                    |
##   |  [  MAIN  ]  [  DECK  ]  [  VAGUE  ]     |  <- onglets, 110 px
##   | +--------------------------------------+ |
##   | |                                      | |
##   | |   contenu de l onglet (defile)       | |
##   | |                                      | |
##   | +--------------------------------------+ |
##   |  [            REPRENDRE             ]   |  <- toujours la, tiers bas
##   |  [         QUITTER LE COMBAT         ]   |
##   +------------------------------------------+
##
##   - MAIN  : les cartes en main (icone, effet, temps REEL) et les passifs —
##             ce qu affichait l ancienne pause ;
##   - DECK  : TOUT le deck de la partie (pioche, main, defausse), carte par
##             carte, avec effet, temps d incantation reel et maturation. C est
##             le composant DeckBrowser, le meme que l ecran d Epuration ;
##   - VAGUE : les monstres de la vague en cours, sur le terrain et a venir.
##             Toucher un monstre ouvre sa FICHE (resistances en logos,
##             competences), comme au bestiaire.
##
## REPRENDRE et QUITTER sont HORS des onglets, sous le pouce : changer d onglet
## ne doit jamais les cacher, c est la sortie de l ecran.
##
## Le panneau tourne en PROCESS_MODE_ALWAYS : l arbre est en pause, un panneau
## qui heriterait ne repondrait a aucun toucher (piege deja vecu par le HUD).

signal resume_requested()
signal quit_requested()

enum Tab { HAND, DECK, WAVE }
const TABS: Array[String] = ["MAIN", "DECK", "VAGUE"]

const TAB_H: float = 110.0
const BUTTON_H: float = 110.0
const ICON_PX: float = 76.0
const PORTRAIT_PX: float = 96.0
const SHEET_PORTRAIT_PX: float = 180.0
const RESIST_ICON_PX: float = 56.0
## Encres sur le PAPIER (luminance ~0,84), verifiees contre UiTheme.CONTRAST_MIN
## par test_pause_panel. L ancienne pause ecrivait ses titres en OR sur ce
## papier : 1,3:1, c est-a-dire illisible au soleil.
const INK_TITLE: Color = UiTheme.TEXT_DARK
const INK_TEXT: Color = UiTheme.TEXT_DARK
const INK_SOFT: Color = Color(0.36, 0.28, 0.20)
const INK_HINT: Color = Color(0.12, 0.30, 0.60)
const INK_BAD: Color = Color(0.55, 0.10, 0.12)
const INK_GOOD: Color = Color(0.12, 0.42, 0.16)
const INK_RESIST: Color = Color(0.50, 0.28, 0.08)

var game: Node = null

var _tab: int = Tab.HAND
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer = null
var _enemy: EnemyDef = null
var _browser: DeckBrowser = null


func _init(p_game: Node = null) -> void:
	game = p_game
	name = "PausePanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	show_tab(_tab)


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.05, 0.04, 0.09, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var paper := PanelContainer.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 40.0
	paper.offset_right = -40.0
	paper.offset_top = 200.0
	paper.offset_bottom = -110.0
	UiTheme.style_paper(paper)
	add_child(paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	paper.add_child(box)

	box.add_child(UiTheme.label("PAUSE", UiTheme.FONT_TITLE, INK_TITLE,
		HORIZONTAL_ALIGNMENT_CENTER, false))

	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override(&"separation", 10)
	box.add_child(onglets)
	for i in TABS.size():
		var b := Button.new()
		b.name = "Tab_" + TABS[i]
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(0, TAB_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		var idx: int = i
		b.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			show_tab(idx))
		onglets.add_child(b)
		_tab_buttons.append(b)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 12)
	box.add_child(_content)

	var reprendre := Button.new()
	reprendre.name = "Resume"
	reprendre.text = "REPRENDRE"
	reprendre.custom_minimum_size = Vector2(0, BUTTON_H)
	reprendre.process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.style_primary(reprendre)
	reprendre.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(reprendre)

	# QUITTER (demande du testeur) : "dans l onglet pause on peut quitter le
	# combat pour retourner au menu". En dessous de REPRENDRE et non au-dessus :
	# on ne met pas la sortie definitive sous le pouce de quelqu un qui voulait
	# seulement reprendre.
	var quitter := Button.new()
	quitter.name = "Quit"
	quitter.text = "QUITTER LE COMBAT"
	quitter.custom_minimum_size = Vector2(0, BUTTON_H - 14.0)
	quitter.process_mode = Node.PROCESS_MODE_ALWAYS
	quitter.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quitter)


# --- Onglets ---

func show_tab(index: int) -> void:
	_tab = clampi(index, 0, TABS.size() - 1)
	_enemy = null
	for i in _tab_buttons.size():
		_tab_buttons[i].add_theme_color_override(&"font_color",
			UiTheme.GOLD if i == _tab else UiTheme.TEXT)
	_render()


func current_tab() -> int:
	return _tab


## La fiche de monstre ouverte dans l onglet VAGUE, null sinon.
func open_enemy_sheet() -> EnemyDef:
	return _enemy


func open_enemy(def: EnemyDef) -> void:
	if def == null:
		return
	_tab = Tab.WAVE
	_enemy = def
	_render()


func close_enemy() -> void:
	_enemy = null
	_render()


## Le composant DeckBrowser de l onglet DECK (null sur les autres onglets).
func deck_browser() -> DeckBrowser:
	return _browser if is_instance_valid(_browser) else null


func _render() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_browser = null
	match _tab:
		Tab.HAND: _render_hand()
		Tab.DECK: _render_deck()
		Tab.WAVE:
			if _enemy != null:
				_render_enemy(_enemy)
			else:
				_render_wave()


func _scroll_box() -> VBoxContainer:
	var scroll := TouchScroll.make()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 16)
	scroll.add_child(box)
	return box


# --- MAIN : la main et les passifs ---

## LA MAIN EN GRAND, en premier : "on peut mettre pause pour regarder ses cartes
## et lire dans le detail" (retour du testeur). En jeu la carte ne montre qu une
## icone ; c est ICI qu on apprend ce que l icone veut dire.
##
## Disposition en LIGNES et non en grille de cartes : une description tient sur
## une ligne de texte, pas dans une carte de 200 px. L icone est a gauche, a la
## meme taille et avec la meme teinte qu en main.
func _render_hand() -> void:
	var box: VBoxContainer = _scroll_box()
	box.add_child(UiTheme.label("TA MAIN  (%d)" % RunState.hand.size(),
		UiTheme.FONT_BODY, INK_TITLE))
	if RunState.hand.is_empty():
		box.add_child(UiTheme.label("Main vide : la prochaine pioche arrive.",
			UiTheme.FONT_SMALL, INK_TEXT))
	for c: SpellCard in RunState.hand:
		box.add_child(_hand_row(c))

	# Les passifs ensuite : information qu on ne peut lire nulle part ailleurs.
	box.add_child(UiTheme.label("POUVOIRS ACTIFS", UiTheme.FONT_BODY, INK_TITLE))
	if RunState.equipped_passives.is_empty():
		box.add_child(UiTheme.label("Aucun pour l instant.", UiTheme.FONT_SMALL, INK_TEXT))
	for p: SpellCard in RunState.equipped_passives:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override(&"separation", 12)
		var ico: TextureRect = CardIcons.make_rect(p, 64.0)
		if ico != null:
			ligne.add_child(ico)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiTheme.label(p.display_name, UiTheme.FONT_BODY, INK_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, false))
		# Vague 8 : l element cite porte son logo dans la phrase.
		col.add_child(ElementIcons.rich_label(ElementIcons.decorate(p.description,
			ElementIcons.inline_px(UiTheme.FONT_SMALL)), UiTheme.FONT_SMALL, INK_SOFT))
		ligne.add_child(col)
		box.add_child(ligne)


func _hand_row(c: SpellCard) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 16)
	var ico: TextureRect = CardIcons.make_rect(c, ICON_PX)
	if ico != null:
		ligne.add_child(ico)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 2)

	# Nom + temps sur la meme ligne, sans autowrap : dans la colonne etroite que
	# le conteneur accorde, UiTheme.label replierait LETTRE PAR LETTRE.
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override(&"separation", 14)
	var nom := UiTheme.label(c.display_name, UiTheme.FONT_BODY, UiTheme.rarity_ink(c.rarity),
		HORIZONTAL_ALIGNMENT_LEFT, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(nom)
	# Le temps REEL (DeckBrowser.cast_time_text) : l ancienne pause affichait
	# base_cast_time, sans le facteur GameConfig.CAST_TIME_SCALE.
	entete.add_child(UiTheme.label(DeckBrowser.cast_time_text(c), UiTheme.FONT_SMALL,
		INK_HINT, HORIZONTAL_ALIGNMENT_RIGHT, false))
	col.add_child(entete)

	# La description, elle, DOIT se replier : c est une phrase. Les elements
	# cites y portent leur logo (vague 8, ElementIcons.decorate).
	col.add_child(ElementIcons.rich_label(ElementIcons.decorate(c.description,
		ElementIcons.inline_px(UiTheme.FONT_SMALL)), UiTheme.FONT_SMALL, INK_SOFT))
	if c.targeting != GameEnums.Targeting.NONE:
		col.add_child(UiTheme.label(targeting_hint(c.targeting), UiTheme.FONT_SMALL,
			INK_HINT, HORIZONTAL_ALIGNMENT_LEFT, false))
	ligne.add_child(col)
	return ligne


## Meme libelle que sur la carte de detail : le geste s apprend une seule fois.
static func targeting_hint(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "glisser sur une zone"
		GameEnums.Targeting.DIRECTION: return "glisser pour viser"
		GameEnums.Targeting.TARGET: return "glisser sur un monstre"
	return ""


# --- DECK : tout le deck de la partie ---

func _render_deck() -> void:
	_browser = DeckBrowser.new(DeckBrowser.Mode.BROWSE)
	_browser.name = "DeckBrowser"
	_content.add_child(_browser)


# --- VAGUE : les monstres de la vague en cours ---

## Les monstres de la vague EN COURS, regroupes : {def, alive, queued}. `alive`
## = sur le terrain maintenant, `queued` = pas encore nes. Dans l ordre ou ils
## arrivent : ceux du terrain d abord, puis la file du spawner.
static func wave_groups(g: Node) -> Array[Dictionary]:
	var par_id: Dictionary = {}
	var ordre: Array[EnemyDef] = []
	if g == null:
		return []
	var bf: Node = g.get("battlefield")
	if bf != null:
		for e in bf.get("enemies"):
			if e == null or not is_instance_valid(e) or e.is_dead():
				continue
			_count(par_id, ordre, e.definition, "alive")
	var spawner: Node = g.get("spawner")
	if spawner != null and spawner.has_method("queued_enemies"):
		for d: EnemyDef in spawner.queued_enemies():
			_count(par_id, ordre, d, "queued")
	var out: Array[Dictionary] = []
	for d in ordre:
		out.append(par_id[d.id])
	return out


static func _count(par_id: Dictionary, ordre: Array[EnemyDef], d: EnemyDef, cle: String) -> void:
	if d == null:
		return
	if not par_id.has(d.id):
		par_id[d.id] = {"def": d, "alive": 0, "queued": 0}
		ordre.append(d)
	par_id[d.id][cle] = int(par_id[d.id][cle]) + 1


func _render_wave() -> void:
	var box: VBoxContainer = _scroll_box()
	box.add_child(UiTheme.label("VAGUE %d" % (RunState.wave_index + 1),
		UiTheme.FONT_BODY, INK_TITLE))
	var groupes: Array[Dictionary] = wave_groups(game)
	if groupes.is_empty():
		box.add_child(UiTheme.label("Plus aucun monstre dans cette vague.",
			UiTheme.FONT_SMALL, INK_TEXT))
		return
	box.add_child(UiTheme.label("Touche un monstre pour lire sa fiche.",
		UiTheme.FONT_SMALL, INK_HINT))
	for g in groupes:
		box.add_child(_wave_row(g))


## Une ligne de monstre : un BOUTON entier (cible tactile de toute la largeur),
## portrait, nom, ce qui en reste sur le terrain et a venir.
func _wave_row(g: Dictionary) -> Button:
	var def: EnemyDef = g["def"]
	var b := Button.new()
	b.name = "Enemy_" + String(def.id)
	b.custom_minimum_size = Vector2(0, PORTRAIT_PX + 24.0)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.set_meta(&"enemy_id", def.id)
	var fond: StyleBox = UiTheme.flat_box(Color(0.99, 0.96, 0.88, 0.6), 12, 10.0,
		BestiaryLore.power_color(def.power), 4)
	for etat in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(etat, fond)
	b.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		open_enemy(def))

	var ligne := HBoxContainer.new()
	ligne.set_anchors_preset(Control.PRESET_FULL_RECT)
	ligne.offset_left = 12.0
	ligne.offset_right = -12.0
	ligne.add_theme_constant_override(&"separation", 16)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ligne)
	var portrait: Control = BestiaryLore.portrait_of(def, PORTRAIT_PX, true)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(col)
	var nom: Label = UiTheme.label(def.display_name, UiTheme.FONT_BODY,
		BestiaryLore.power_ink(def.power), HORIZONTAL_ALIGNMENT_LEFT, false)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nom)
	var compte: Label = UiTheme.label(wave_count_text(g), UiTheme.FONT_SMALL, INK_SOFT,
		HORIZONTAL_ALIGNMENT_LEFT, false)
	compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(compte)
	return b


static func wave_count_text(g: Dictionary) -> String:
	return "sur le terrain %d  -  a venir %d" % [int(g.get("alive", 0)), int(g.get("queued", 0))]


## La FICHE d un monstre, a la place de la liste : la meme lecture qu au
## bestiaire (BestiaryLore, ElementIcons), dans la page de la pause.
func _render_enemy(def: EnemyDef) -> void:
	var box: VBoxContainer = _scroll_box()
	fill_enemy_sheet(box, def)
	var retour := Button.new()
	retour.name = "SheetBack"
	retour.text = "RETOUR A LA VAGUE"
	retour.custom_minimum_size = Vector2(0, BUTTON_H - 14.0)
	retour.process_mode = Node.PROCESS_MODE_ALWAYS
	retour.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		close_enemy())
	_content.add_child(retour)


## Remplit `box` avec la fiche de `def` : portrait, nom, nature, chiffres,
## competences, puis les resistances en LOGOS par groupe (Immunise / Resiste /
## Vulnerable) et la regle « degats et effets ». Statique pour etre lue par les
## tests sans ouvrir de pause.
static func fill_enemy_sheet(box: VBoxContainer, def: EnemyDef) -> void:
	var portrait: Control = BestiaryLore.portrait_of(def, SHEET_PORTRAIT_PX, true)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(portrait)
	box.add_child(UiTheme.label(def.display_name, UiTheme.FONT_TITLE,
		BestiaryLore.power_ink(def.power), HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("%s   -   puissance %d" % [
		BestiaryLore.kind_name(def.kind), def.power], UiTheme.FONT_SMALL,
		INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label("PV %d   -   vitesse %s   -   degats %d" % [
		int(def.max_hp), BestiaryLore.speed_word(def.base_speed), def.contact_hit()],
		UiTheme.FONT_SMALL, INK_TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	box.add_child(UiTheme.label("COMPETENCES", UiTheme.FONT_SMALL, INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	# `true` : la legende du Cameleon porte les logos de ses elements (vague 8).
	var lignes: Array[String] = BestiaryLore.behaviours(def, true)
	if lignes.is_empty():
		box.add_child(UiTheme.label("- aucune particularite", UiTheme.FONT_SMALL, INK_TEXT))
	for line in lignes:
		box.add_child(ElementIcons.rich_label("- " + line, UiTheme.FONT_SMALL, INK_TEXT))

	var groupes: Array[Dictionary] = BestiaryLore.resistance_groups(def)
	if groupes.is_empty():
		return
	box.add_child(UiTheme.label("RESISTANCES", UiTheme.FONT_SMALL, INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(UiTheme.label(BestiaryLore.RESIST_RULE_TEXT, UiTheme.FONT_SMALL,
		INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	for gr in groupes:
		var bloc := VBoxContainer.new()
		bloc.name = "Resist_" + str(gr["title"])
		bloc.add_theme_constant_override(&"separation", 4)
		box.add_child(bloc)
		bloc.add_child(UiTheme.label(str(gr["title"]) + " :", UiTheme.FONT_BODY,
			resist_ink(str(gr["title"])), HORIZONTAL_ALIGNMENT_LEFT, false))
		# Vague 8 : « [feu] feu -30 %   [eau] eau +60 % » sur une ligne, le meme
		# helper que le bestiaire (ElementIcons.resist_bbcode).
		var ligne: RichTextLabel = ElementIcons.rich_label(
			ElementIcons.resist_bbcode(gr["items"], ElementIcons.inline_px(UiTheme.FONT_SMALL)),
			UiTheme.FONT_SMALL, INK_TEXT)
		ligne.name = "ResistLine_" + str(gr["title"])
		bloc.add_child(ligne)


## Encre du mot de groupe, sur PAPIER (comme au bestiaire) : rouge sombre pour ce
## qui gene le joueur, vert sombre pour ce qui l aide. Le mot porte le sens, la
## couleur le confirme.
static func resist_ink(titre: String) -> Color:
	match titre:
		"Immunise": return INK_BAD
		"Resiste": return INK_RESIST
		"Vulnerable": return INK_GOOD
	return INK_TEXT
