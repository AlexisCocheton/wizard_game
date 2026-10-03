class_name DeckBrowser
extends VBoxContainer
## PARCOURIR LE DECK DE LA PARTIE — composant reutilisable (vague 8).
##
## Deux usages, un seul composant :
##   - l onglet DECK du menu pause (Mode.BROWSE) : lire tout son deck ;
##   - le sort EPURATION (Mode.PICK) : choisir 0, 1 ou 2 cartes a retirer.
## Les deux montrent la MEME liste, construite de la meme facon : un joueur qui a
## parcouru son deck en pause reconnait l ecran d Epuration au premier coup d oeil.
##
## MODE BROWSE (onglet DECK de la pause)
##   +------------------------------------------+
##   | 12 cartes  -  pioche 6  main 4  defausse 2|
##   | +--------------------------------------+ |
##   | |[ico] Boule de feu  x3        2,3 s   | |  <- temps d incantation REEL
##   | |      pioche 2 - main 1 - defausse 0  | |
##   | |      20 degats de feu en zone...     | |  <- l effet, en entier
##   | |      Maturation 1 / 2 : Puissance    | |
##   | +--------------------------------------+ |
##
## MODE PICK (Epuration)
##   +------------------------------------------+
##   |  Choisis jusqu a 2 cartes a retirer      |
##   |  (aucune, c est permis)    retirees 1 / 2|
##   | +--------------------------------------+ |
##   | |[ico] Boule de feu x3  [ - ]  1  [ + ]| |  <- boutons de 96 px
##   | |      ...                             | |
##   | +--------------------------------------+ |
##   |  [         VALIDER (retirer 1)        ]  |  <- tiers bas, sous le pouce
##   +------------------------------------------+
##
## POURQUOI UNE LIGNE PAR CARTE ET NON PAR EXEMPLAIRE. Les copies d une carte sont
## la MEME ressource : douze lignes dont trois identiques se liraient comme un
## bug d affichage. Une ligne dit « x3 » et ou sont les trois ; en Epuration, les
## boutons - / + disent combien on en retire. RunState choisit lui-meme dans
## quelle pile prendre l exemplaire (defausse, puis pioche, puis main).
##
## LE TEMPS D INCANTATION EST LE TEMPS REEL. La pause affichait `base_cast_time`,
## sans le multiplicateur global GameConfig.CAST_TIME_SCALE ni les ajustements de
## la partie (passifs, maturations, vitesse) : le chiffre lu en pause n etait pas
## celui que le joueur subissait. On lit RunState.effective_cast_time, le meme
## calcul que le Caster.

signal validated(cards: Array)

enum Mode { BROWSE, PICK }

## Hauteur des boutons - / + et du bouton VALIDER : cible tactile d un pouce.
const BUTTON_PX: float = 96.0
const ICON_PX: float = 76.0
## Encres posees sur le PAPIER du menu pause (luminance ~0,84). Verifiees contre
## UiTheme.CONTRAST_MIN par test_deck_browser : un gris « elegant » sur du creme
## tombait sous 4,5:1 sur la capture d un autre ecran.
const INK_TEXT: Color = UiTheme.TEXT_DARK
const INK_SOFT: Color = Color(0.36, 0.28, 0.20)
const INK_HINT: Color = Color(0.12, 0.30, 0.60)
const INK_PICKED: Color = Color(0.55, 0.10, 0.12)
## Fond d une ligne : un creme a peine plus clair que le papier, pour que chaque
## carte se lise comme un bloc sans dessiner une grille.
const ROW_BG: Color = Color(0.99, 0.96, 0.88, 0.55)

var mode: int = Mode.BROWSE
## Maximum de cartes a retirer (Mode.PICK).
var max_pick: int = 0

## Choix en cours : id de carte -> nombre d exemplaires a retirer.
var _picked: Dictionary = {}
var _groups: Array[Dictionary] = []
var _summary: Label = null
var _list: VBoxContainer = null
var _validate_btn: Button = null


func _init(p_mode: int = Mode.BROWSE, p_max_pick: int = 0) -> void:
	mode = p_mode
	max_pick = maxi(0, p_max_pick)
	add_theme_constant_override(&"separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	refresh()


## Reconstruit la liste depuis RunState. Le choix en cours est garde tant que
## les cartes choisies sont encore dans le deck.
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_groups = RunState.run_deck_groups()
	_clamp_picks()

	_summary = UiTheme.label("", UiTheme.FONT_SMALL, INK_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_summary.name = "Summary"
	add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)

	if _groups.is_empty():
		_list.add_child(UiTheme.label("Aucune carte dans le deck de la partie.",
			UiTheme.FONT_BODY, INK_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for g in _groups:
		_list.add_child(_row(g))

	if mode == Mode.PICK:
		_validate_btn = Button.new()
		_validate_btn.name = "Validate"
		_validate_btn.custom_minimum_size = Vector2(0, BUTTON_PX + 14.0)
		_validate_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		UiTheme.style_primary(_validate_btn)
		_validate_btn.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			validate())
		add_child(_validate_btn)
	# Etat des boutons - / + et des textes, une fois la liste posee.
	_after_change()


# --- API du choix (Mode.PICK) ---

## Ajoute un exemplaire de `card` au choix. Faux si le plafond est atteint ou si
## la carte n a plus d exemplaire a retirer.
func pick(card: SpellCard) -> bool:
	if mode != Mode.PICK or card == null:
		return false
	if picked_count() >= max_pick:
		return false
	var n: int = int(_picked.get(card.id, 0))
	if n >= _copies_of(card):
		return false
	_picked[card.id] = n + 1
	_after_change()
	return true


## Retire un exemplaire de `card` du choix.
func unpick(card: SpellCard) -> bool:
	if card == null:
		return false
	var n: int = int(_picked.get(card.id, 0))
	if n <= 0:
		return false
	if n == 1:
		_picked.erase(card.id)
	else:
		_picked[card.id] = n - 1
	_after_change()
	return true


func picked_count() -> int:
	var n: int = 0
	for k in _picked:
		n += int(_picked[k])
	return n


## Le choix, un element par EXEMPLAIRE a retirer : la forme que lit
## RunState.resolve_purge.
func selection() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for g in _groups:
		var c: SpellCard = g["card"]
		for i in int(_picked.get(c.id, 0)):
			out.append(c)
	return out


## VALIDER : zero carte est un choix permis (la regle dit « jusqu a »).
func validate() -> void:
	validated.emit(selection())


## Les cartes listees, dans l ordre d affichage (lu par les tests).
func listed_cards() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for g in _groups:
		out.append(g["card"])
	return out


## Le texte de la ligne d une carte, tel qu affiche (lu par les tests).
func row_text(card: SpellCard) -> String:
	if _list == null:
		return ""
	for row in _list.get_children():
		if row.get_meta(&"card_id", &"") == card.id:
			var t: String = ""
			for n in _labels_of(row):
				t += n.text + "\n"
			# L effet est un texte a logos : relu sans eux, tel que le joueur le lit.
			for n in row.find_children("*", "RichTextLabel", true, false):
				t += ElementIcons.strip_inline((n as RichTextLabel).text) + "\n"
			return t
	return ""


func summary_text() -> String:
	return _summary.text if _summary != null else ""


func validate_text() -> String:
	return _validate_btn.text if _validate_btn != null else ""


# --- Construction ---

func _row(g: Dictionary) -> Control:
	var card: SpellCard = g["card"]
	var row := PanelContainer.new()
	row.set_meta(&"card_id", card.id)
	row.name = "Row_" + String(card.id)
	# PASS : le doigt qui glisse sur une ligne doit faire defiler la liste.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_stylebox_override(&"panel", _row_box(card))

	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override(&"separation", 14)
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(ligne)
	# Meme icone qu en main : c est la cle de lecture entre ici et le combat.
	var ico: TextureRect = CardIcons.make_rect(card, ICON_PX)
	if ico != null:
		ico.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(ico)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(col)

	# Nom + exemplaires + temps sur une ligne, sans autowrap : dans une colonne
	# etroite, UiTheme.label replierait LETTRE PAR LETTRE.
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override(&"separation", 12)
	col.add_child(entete)
	var nom: Label = UiTheme.label("%s  x%d" % [card.display_name, int(g["total"])],
		UiTheme.FONT_BODY, UiTheme.rarity_ink(card.rarity), HORIZONTAL_ALIGNMENT_LEFT, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	entete.add_child(nom)
	entete.add_child(UiTheme.label(cast_time_text(card), UiTheme.FONT_SMALL, INK_HINT,
		HORIZONTAL_ALIGNMENT_RIGHT, false))

	col.add_child(UiTheme.label(piles_text(g), UiTheme.FONT_SMALL, INK_SOFT,
		HORIZONTAL_ALIGNMENT_LEFT, false))
	# L effet, lui, DOIT se replier : c est une phrase. Les elements cites y
	# portent leur logo, comme dans la CardView de detail.
	var effet: RichTextLabel = ElementIcons.decorated_label(card.description,
		UiTheme.FONT_SMALL, INK_TEXT)
	effet.name = "Description"
	col.add_child(effet)
	col.add_child(UiTheme.label(maturation_text(card), UiTheme.FONT_SMALL, INK_SOFT))

	if mode == Mode.PICK:
		ligne.add_child(_stepper(card))
	return row


## Les boutons - / + d une ligne, et le nombre retenu entre eux.
func _stepper(card: SpellCard) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var moins := Button.new()
	moins.name = "Minus"
	moins.text = "-"
	moins.custom_minimum_size = Vector2(BUTTON_PX, BUTTON_PX)
	moins.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	moins.process_mode = Node.PROCESS_MODE_ALWAYS
	moins.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		unpick(card))
	box.add_child(moins)
	var n := UiTheme.label("0", UiTheme.FONT_BUTTON, INK_PICKED, HORIZONTAL_ALIGNMENT_CENTER, false)
	n.name = "Count"
	n.custom_minimum_size = Vector2(44, 0)
	box.add_child(n)
	var plus := Button.new()
	plus.name = "Plus"
	plus.text = "+"
	plus.custom_minimum_size = Vector2(BUTTON_PX, BUTTON_PX)
	plus.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	plus.process_mode = Node.PROCESS_MODE_ALWAYS
	plus.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		pick(card))
	box.add_child(plus)
	return box


func _row_box(card: SpellCard) -> StyleBox:
	var retenue: bool = int(_picked.get(card.id, 0)) > 0
	if retenue:
		# Une carte qu on va RETIRER s encadre en rouge sombre : c est une perte,
		# le joueur doit la voir avant de valider.
		return UiTheme.flat_box(ROW_BG, 12, 14.0, INK_PICKED, 6)
	return UiTheme.rarity_border(card.rarity, ROW_BG, 12, 14.0)


func _after_change() -> void:
	if _list == null:
		return
	for row in _list.get_children():
		if not row.has_meta(&"card_id"):
			continue
		var id: StringName = row.get_meta(&"card_id", &"")
		if id == &"":
			continue
		var card: SpellCard = null
		for g in _groups:
			if (g["card"] as SpellCard).id == id:
				card = g["card"]
		if card == null:
			continue
		(row as PanelContainer).add_theme_stylebox_override(&"panel", _row_box(card))
		var compte: Label = row.find_child("Count", true, false) as Label
		if compte != null:
			compte.text = str(int(_picked.get(id, 0)))
		var plus: Button = row.find_child("Plus", true, false) as Button
		if plus != null:
			plus.disabled = picked_count() >= max_pick \
				or int(_picked.get(id, 0)) >= _copies_of(card)
		var moins: Button = row.find_child("Minus", true, false) as Button
		if moins != null:
			moins.disabled = int(_picked.get(id, 0)) <= 0
	_update_texts()


func _update_texts() -> void:
	if _summary != null:
		if mode == Mode.PICK:
			_summary.text = "Choisis jusqu a %d carte%s a retirer de ton deck pour la partie. Aucune, c est permis.\nRetenues : %d / %d" % [
				max_pick, "s" if max_pick > 1 else "", picked_count(), max_pick]
		else:
			_summary.text = deck_summary_text()
	if _validate_btn != null:
		var n: int = picked_count()
		_validate_btn.text = "VALIDER  (rien retirer)" if n == 0 \
			else "VALIDER  (retirer %d)" % n


func _clamp_picks() -> void:
	for id in _picked.keys():
		var c: SpellCard = ContentDB.cards.get(id)
		var copies: int = 0
		for g in _groups:
			if (g["card"] as SpellCard).id == id:
				copies = int(g["total"])
				c = g["card"]
		if c == null or copies == 0:
			_picked.erase(id)
		else:
			_picked[id] = mini(int(_picked[id]), copies)


func _copies_of(card: SpellCard) -> int:
	for g in _groups:
		if (g["card"] as SpellCard).id == card.id:
			return int(g["total"])
	return 0


func _labels_of(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	for c in n.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels_of(c))
	return out


# --- Textes (statiques : lus par les tests sans construire l ecran) ---

## Le temps d incantation que le joueur SUBIT maintenant : base, reduction de
## cout, passifs, maturation, multiplicateur global ET vitesse courante.
static func cast_time_text(card: SpellCard) -> String:
	return "%s s" % _fmt(RunState.effective_cast_time(card))


static func piles_text(g: Dictionary) -> String:
	return "pioche %d  -  main %d  -  defausse %d" % [
		int(g.get("pile", 0)), int(g.get("hand", 0)), int(g.get("discard", 0))]


## Ou en est la carte dans ses maturations, et les voies prises. C est
## l information qu on ne lit nulle part en combat : le lisere de la carte dit
## seulement qu elle progresse.
## CHANTIER W8 : le total est celui de CETTE carte (RunState.upgrade_tiers_for :
## jamais plus de maturations que de voies), et le reste se compte en XP de
## carte (lancers ET meditations, RunState.card_xp) — compter les seuls lancers
## annoncait « 1 lancer » a une carte que la meditation venait de porter au palier.
static func maturation_text(card: SpellCard) -> String:
	var faites: int = RunState.maturations_done(card)
	var total: int = RunState.upgrade_tiers_for(card)
	var t: String = "Maturation %d / %d" % [mini(faites, total), total]
	var noms: Array[String] = []
	for id in RunState.upgrade_ids_of(card):
		var v: Dictionary = RunState.upgrade_path_by_id(card, id)
		var titre: String = str(v.get("title", ""))
		if titre != "":
			noms.append(titre)
	if not noms.is_empty():
		t += " : " + ", ".join(noms)
	if faites < total:
		var reste: int = maxi(0, RunState.next_upgrade_at(card) - RunState.card_xp(card))
		t += "  -  prochaine dans %d lancer%s" % [reste, "s" if reste > 1 else ""]
	var meditee: int = RunState.card_xp_given(card)
	if meditee > 0:
		t += " (%d XP de meditation)" % meditee
	return t


static func deck_summary_text() -> String:
	return "%d cartes  -  pioche %d  -  main %d  -  defausse %d" % [
		RunState.total_cards(), RunState.deck.size(), RunState.hand.size(),
		RunState.discard.size()]


static func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


# --- Superposition d EPURATION, posee sur le HUD par GameController ---

## Construit l ecran de choix d Epuration : un voile, une feuille de papier, le
## composant en Mode.PICK. VALIDER tranche dans RunState (resolve_purge) puis
## retire l ecran. Le jeu est en pause tant que RunState.pending_purge > 0
## (GameController.simulate), sans toucher a `get_tree().paused`, que tient
## deja le bouton pause du HUD.
static func purge_overlay(max_count: int) -> Control:
	var overlay := Control.new()
	overlay.name = "PurgeOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.theme = UiTheme.make()

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.05, 0.04, 0.09, 0.82)
	# Il INTERCEPTE le toucher : on ne doit ni lancer un sort ni toucher la pause
	# au travers pendant qu on choisit.
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)

	var paper := PanelContainer.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 40.0
	paper.offset_right = -40.0
	paper.offset_top = 200.0
	paper.offset_bottom = -120.0
	UiTheme.style_paper(paper)
	overlay.add_child(paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	paper.add_child(box)
	box.add_child(UiTheme.label("EPURATION", UiTheme.FONT_TITLE, UiTheme.INK_EPIC,
		HORIZONTAL_ALIGNMENT_CENTER, false))

	var browser := DeckBrowser.new(Mode.PICK, max_count)
	browser.name = "DeckBrowser"
	box.add_child(browser)
	browser.validated.connect(func(cards: Array) -> void:
		RunState.resolve_purge(cards)
		overlay.queue_free())
	return overlay


## Releve le plafond d un ecran d Epuration deja ouvert (une seconde Epuration
## resolue pendant le choix, par Debordement). Le choix en cours est garde.
static func set_overlay_max(overlay: Control, max_count: int) -> void:
	var browser: DeckBrowser = overlay.find_child("DeckBrowser", true, false) as DeckBrowser
	if browser != null:
		browser.set_max_pick(max_count)


func set_max_pick(n: int) -> void:
	max_pick = maxi(0, n)
	_after_change()
