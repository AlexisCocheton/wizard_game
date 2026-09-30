class_name MassacrePanel
extends VBoxContainer
## Onglet MASSACRE — le niveau infini a part (voir MassacreMode).
##
##   +--------------------------------------------------+
##   | +----------------------------------------------+ |
##   | |      fond du Seuil divin (le lieu du mode)   | |
##   | |                 MASSACRE                     | |  <- information :
##   | |   regle du mode en une phrase                | |     le haut
##   | +----------------------------------------------+ |
##   | +------------------ papier --------------------+ |
##   | |  RECORD                         vague 14     | |
##   | |  PALIERS : mini-boss / 3, boss / 6           | |
##   | |  BESTIAIRE : 64 monstres, 15 boss            | |
##   | |  DECK UTILISE : Deck 1  (15 cartes)          | |
##   | |  Boule de feu x3   Eclair x2   ...           | |
##   | |                                              | |
##   | |       raison si le bouton est coupe          | |
##   | +----------------------------------------------+ |
##   | [==================== JOUER ===================] |  <- action : le pouce
##   +--------------------------------------------------+
##
## QUAND IL S OUVRE : a la FIN DE LA CAMPAGNE (SaveData.massacre_unlocked,
## retouche du co-auteur apres test, 30/09 : "accessible uniquement a la fin de
## la campagne ; le mode INFINI au fur et a mesure"). Il s ouvrait au premier
## niveau gagne. Le mode sans fin de la progression, c est l Infini de chaque
## niveau ; le Massacre, qui melange tous les mondes et tous les boss, est
## l epreuve d apres l histoire.
##
## L onglet reste VISIBLE tant qu il est ferme, et dit ce qui l ouvre : un
## bandeau dans le lieu ("S ouvre a la fin de la campagne") et, au-dessus de
## JOUER coupe, le chemin qui reste ("3 / 21 niveaux finis"). Un onglet cache
## n aurait donne au joueur aucune raison de finir la campagne.
##
## Toutes les valeurs affichees viennent de SaveData : le record n est jamais
## tenu par l ecran.

## Le fond du haut, en fraction de la hauteur du panneau : assez grand pour dire
## "un lieu", assez court pour que JOUER reste dans le tiers bas.
const HERO_HEIGHT: float = 520.0
## Encre des titres sur le papier : sous 0,147 de luminance pour tenir 4,5:1
## (meme calcul que l ecran des reglages). L or du theme y tombe a 1,3:1.
const INK_TITLE := Color(0.20, 0.13, 0.02)
## Encre du REFUS, sur le papier aussi. Le rouge du theme (vie) n y tient que
## 3,7:1 ; assombri, 7,8:1. La raison est ecrite DANS le papier et non sur le
## bois : mesure sur la capture, le bois fait 0,16 a 0,22 de luminance, ou ni le
## texte clair (3,3:1) ni le texte sombre (3,2:1) ne tiennent 4,5:1.
const INK_REFUSAL := Color(0.55, 0.10, 0.10)
## Le bandeau du verrou, dans le lieu.
const LOCK_BANNER: String = "S ouvre a la fin de la campagne"

var _hero_rule: Label
## Bandeau du verrou, dans le lieu, sous le titre. Visible tant que le Massacre
## est ferme : c est la premiere chose lue en ouvrant l onglet.
var _hero_lock: Label
var _record_value: Label
var _stakes: Label
var _deck_title: Label
var _deck_tags: HFlowContainer
var _hint: Label
var _play_btn: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 18)
	_build()
	refresh()


func _build() -> void:
	# --- Le lieu : le fond du mode, recadre, avec le titre par-dessus. ---
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, HERO_HEIGHT)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.clip_contents = true
	add_child(hero)
	var fond := TextureRect.new()
	fond.texture = SheetLib.texture("res://assets/backdrops/%s.png" % MassacreMode.BACKDROP)
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED et non SCALE : le fond est un portrait 1080x1920, l etirer dans
	# un bandeau l ecraserait. On en garde le coeur, a ses proportions.
	fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(fond)
	var titres := VBoxContainer.new()
	titres.set_anchors_preset(Control.PRESET_FULL_RECT)
	titres.alignment = BoxContainer.ALIGNMENT_CENTER
	titres.add_theme_constant_override(&"separation", 14)
	titres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(titres)
	# label_hud : contour sombre epais, parce que le fond est PEINT et que ses
	# nebuleuses claires passent sous le texte a certains endroits.
	titres.add_child(UiTheme.label_hud("MASSACRE", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER))
	_hero_rule = UiTheme.label_hud("", UiTheme.FONT_BODY, UiTheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	titres.add_child(_hero_rule)
	# En or, comme le titre : c est l information la plus importante de
	# l onglet tant qu il est ferme, et le contour de label_hud la garde lisible
	# sur le fond peint.
	_hero_lock = UiTheme.label_hud(LOCK_BANNER, UiTheme.FONT_BODY, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	titres.add_child(_hero_lock)

	# --- Le papier : record et deck utilise. ---
	var papier := PanelContainer.new()
	papier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	papier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(papier)
	var corps := VBoxContainer.new()
	corps.add_theme_constant_override(&"separation", 16)
	papier.add_child(corps)

	var ligne := HBoxContainer.new()
	corps.add_child(ligne)
	var record_titre := UiTheme.label("RECORD", UiTheme.FONT_BODY, INK_TITLE)
	record_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(record_titre)
	_record_value = UiTheme.label("", UiTheme.FONT_TITLE, INK_TITLE,
		HORIZONTAL_ALIGNMENT_RIGHT, false)
	ligne.add_child(_record_value)

	# Ce qui attend, en chiffres REELS lus dans le jeu : cadences des paliers et
	# taille du bestiaire. Le texte de la regle le dit en mots, ceci le chiffre.
	_stakes = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK)
	corps.add_child(_stakes)

	_deck_title = UiTheme.label("", UiTheme.FONT_BODY, INK_TITLE)
	corps.add_child(_deck_title)
	_deck_tags = HFlowContainer.new()
	_deck_tags.add_theme_constant_override(&"h_separation", 18)
	_deck_tags.add_theme_constant_override(&"v_separation", 8)
	corps.add_child(_deck_tags)

	# La raison du refus en BAS du papier, juste au-dessus de JOUER : lue au
	# moment ou le pouce arrive sur le bouton coupe.
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_child(vide)
	_hint = UiTheme.label("", UiTheme.FONT_SMALL, INK_REFUSAL, HORIZONTAL_ALIGNMENT_CENTER)
	corps.add_child(_hint)

	# --- L action, en bas. ---
	_play_btn = Button.new()
	_play_btn.name = "PlayButton"
	_play_btn.text = "JOUER"
	_play_btn.custom_minimum_size = Vector2(0, 150)
	UiTheme.style_primary(_play_btn)
	_play_btn.pressed.connect(_on_play)
	add_child(_play_btn)


## Appelee par le menu a chaque passage sur l onglet : le record, le deck et le
## verrou ont pu changer depuis (partie jouee, deck modifie, niveau gagne).
func refresh() -> void:
	if _play_btn == null:
		return
	_hero_rule.text = rule_text()
	var best: int = SaveData.massacre_best_wave()
	_record_value.text = "vague %d" % best if best > 0 else "aucun"
	_stakes.text = stakes_text()

	var ids: Array = SaveData.massacre_deck()
	_deck_title.text = "DECK UTILISE : %s  (%d cartes)" % [
		SaveData.deck_name(SaveData.current_deck_index()), ids.size()]
	for c in _deck_tags.get_children():
		c.queue_free()
	var copies: Dictionary = {}
	var ordre: Array[SpellCard] = []
	for id in ids:
		var card: SpellCard = ContentDB.cards.get(StringName(id))
		if card == null:
			continue
		if not copies.has(card.id):
			copies[card.id] = 0
			ordre.append(card)
		copies[card.id] = int(copies[card.id]) + 1
	for card in ordre:
		var tag := UiTheme.label("%s x%d" % [card.display_name, copies[card.id]],
			UiTheme.FONT_SMALL, UiTheme.rarity_ink(card.rarity))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		_deck_tags.add_child(tag)
	if ordre.is_empty():
		_deck_tags.add_child(UiTheme.label("Aucune carte : compose ton deck dans l onglet DECK.",
			UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))

	var reason: String = block_reason()
	_play_btn.disabled = reason != ""
	_hint.text = reason
	_hero_lock.visible = not SaveData.massacre_unlocked()


## Le bandeau du verrou est-il affiche ? Pour les tests : la regle doit se LIRE.
func lock_shown() -> bool:
	return _hero_lock != null and _hero_lock.visible


## La regle du mode, en UNE phrase : c est ce que le joueur lit avant de
## toucher JOUER. La cadence des choix vient du code, jamais d un nombre ecrit.
static func rule_text() -> String:
	return "Les monstres de tous les mondes a la fois, les boss de tout le jeu aux paliers, un sort a choisir toutes les %d vagues." % GameController.WAVES_PER_CHOICE


## Paliers et bestiaire, tires des constantes et du contenu : jamais un nombre
## ecrit ici, qui mentirait au premier reglage.
static func stakes_text() -> String:
	return "PALIERS : un mini-boss toutes les %d vagues, un boss toutes les %d\nBESTIAIRE : %d monstres, %d boss et mini-boss" % [
		WaveBudget.MINIBOSS_EVERY, WaveBudget.BOSS_EVERY,
		MassacreMode.enemy_pool().size(), MassacreMode.boss_pool().size()]


## Pourquoi JOUER est coupe, ou "" s il ne l est pas. Public pour les tests : la
## regle vit ici et non dans l etat d un bouton.
static func block_reason() -> String:
	if not SaveData.massacre_unlocked():
		# Le CHEMIN qui reste, en chiffres lus dans la sauvegarde : "finis la
		# campagne" seul ne dit pas si c est pour demain ou pour dans un mois.
		var p: Array = SaveData.campaign_progress()
		return "Finis la campagne pour ouvrir le Massacre : %d / %d niveaux finis" % [
			int(p[0]), int(p[1])]
	return DeckRules.validation_message(SaveData.massacre_deck())


func can_play() -> bool:
	return _play_btn != null and not _play_btn.disabled


func _on_play() -> void:
	if block_reason() != "":
		return
	AudioBus.play_sfx(&"ui_tap")
	SaveData.save_profile()
	SceneRouter.start_level(MassacreMode.LEVEL_ID, GameEnums.Mode.MASSACRE)
