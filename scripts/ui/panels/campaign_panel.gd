class_name CampaignPanel
extends VBoxContainer
## Onglet Campagne — deux vues qui se remplacent dans le meme onglet :
##
##   1. LA CARTE (`CampaignMap`) : un ecran par acte, pose sur le fond de combat
##      de l acte, avec les points des niveaux, leurs noms et leurs etoiles.
##      On change d acte avec les fleches de bord. C est l ecran d accueil.
##   2. LE DETAIL : exactement l ecran qui existait avant (nom, vagues, boss,
##      objectifs, segment Exploration/Massacre, gros JOUER), plus un RETOUR.
##
## POURQUOI garder le detail tel quel : le testeur a demande que le niveau
## « amene a une interface qui ressemble a l actuelle ». On ne refait pas la
## fiche, on la deplace derriere un toucher sur un point de la carte. Les fleches
## < > ne changent plus de NIVEAU mais d ACTE : elles sont passees dans la carte,
## ou elles tournent les pages du voyage.

var _mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION

## Vue 1 : la carte.
var _map: CampaignMap

## Vue 2 : le detail d un niveau.
var _detail: VBoxContainer
var _detail_id: StringName = &""
var _card: PanelContainer
var _card_body: VBoxContainer
var _explore_btn: Button
var _massacre_btn: Button
var _hint: Label
var _play_btn: Button
var _back_btn: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 18)
	_build()
	refresh()


func _build() -> void:
	_map = CampaignMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.level_pressed.connect(open_level)
	add_child(_map)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override(&"separation", 22)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.visible = false
	add_child(_detail)

	# RETOUR en HAUT : c est une action de navigation, pas une action de jeu.
	# Le bas de l ecran (zone du pouce) reste reserve a JOUER, qui est l action
	# que le joueur repete.
	_back_btn = Button.new()
	_back_btn.text = "< CARTE"
	_back_btn.custom_minimum_size = Vector2(0, 96)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back_btn.pressed.connect(func() -> void:
		AudioBus.play_sfx(&"ui_tap")
		back_to_map())
	_detail.add_child(_back_btn)

	_card = PanelContainer.new()
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(_card)

	_card_body = VBoxContainer.new()
	_card_body.add_theme_constant_override(&"separation", 18)
	_card.add_child(_card_body)

	# Segment de mode : deux boutons, un seul enfonce.
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override(&"separation", 12)
	_detail.add_child(modes)
	_explore_btn = Button.new()
	_explore_btn.text = "EXPLORATION"
	_explore_btn.toggle_mode = true
	_explore_btn.custom_minimum_size = Vector2(0, 100)
	_explore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_btn.pressed.connect(func() -> void: _set_mode(GameEnums.Mode.EXPLORATION))
	modes.add_child(_explore_btn)
	_massacre_btn = Button.new()
	_massacre_btn.text = "MASSACRE"
	_massacre_btn.toggle_mode = true
	_massacre_btn.custom_minimum_size = Vector2(0, 100)
	_massacre_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_massacre_btn.pressed.connect(func() -> void: _set_mode(GameEnums.Mode.MASSACRE))
	modes.add_child(_massacre_btn)

	_hint = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_detail.add_child(_hint)

	_play_btn = Button.new()
	_play_btn.text = "JOUER"
	_play_btn.custom_minimum_size = Vector2(0, 150)
	UiTheme.style_primary(_play_btn)
	_play_btn.pressed.connect(_on_play)
	_detail.add_child(_play_btn)


## Appelee par le menu a chaque retour sur l onglet. On revient TOUJOURS a la
## carte : c est le point de repere de l onglet, et revenir sur la fiche du
## dernier niveau joue apres une defaite serait un mur.
func refresh() -> void:
	_map.rebuild()
	if _detail.visible and _detail_id != &"" and SaveData.is_level_unlocked(_detail_id):
		# On etait sur une fiche et elle est toujours valable : on la reaffiche
		# a jour (les etoiles ont pu changer apres une victoire).
		_render_detail()
	else:
		back_to_map()


# --------------------------------------------------------------------------
# Navigation entre les deux vues
# --------------------------------------------------------------------------

func showing_map() -> bool:
	return _map.visible


func detail_level_id() -> StringName:
	return _detail_id


## Le detail garde bien les commandes de l ancien ecran.
func has_detail_controls() -> bool:
	return _play_btn != null and _explore_btn != null and _massacre_btn != null \
		and _explore_btn.get_parent() != null and _play_btn.get_parent() != null


func back_to_map() -> void:
	_detail.visible = false
	_map.visible = true
	# On revient sur l ACTE du niveau ou en est le joueur : sans cela, la carte
	# rouvre toujours sur l acte I et il faut re-appuyer 4 fois sur la fleche.
	# Appel direct : `show_act` ne depend plus de la taille du noeud, les points
	# sont exprimes en fraction et se replacent au `resized`.
	_map.focus_level(SaveData.current_level())


## Ouvre la fiche d un niveau. Un niveau verrouille est REFUSE ici et pas
## seulement dans la carte : c est la garde qui compte, l affichage n est
## qu une commodite.
func open_level(level_id: StringName) -> void:
	if not ContentDB.levels.has(level_id) or not SaveData.is_level_unlocked(level_id):
		return
	_detail_id = level_id
	SaveData.set_current_level(level_id)
	_map.visible = false
	_detail.visible = true
	_render_detail()


func _set_mode(mode: GameEnums.Mode) -> void:
	_mode = mode
	_render_detail()


func _current() -> LevelDef:
	return ContentDB.levels.get(_detail_id)


# --------------------------------------------------------------------------
# Fiche du niveau — contenu identique a l ancien ecran
# --------------------------------------------------------------------------

func _render_detail() -> void:
	for c in _card_body.get_children():
		c.queue_free()
	_explore_btn.button_pressed = _mode == GameEnums.Mode.EXPLORATION
	_massacre_btn.button_pressed = _mode == GameEnums.Mode.MASSACRE

	var level: LevelDef = _current()
	if level == null:
		_card_body.add_child(UiTheme.label("Aucun niveau", UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
		_play_btn.disabled = true
		return

	var unlocked: bool = SaveData.is_level_unlocked(level.id)
	var cleared: bool = SaveData.is_level_cleared(level.id)

	if level.act > 0:
		_card_body.add_child(UiTheme.label(String(CampaignMap.ACT_NAMES.get(level.act, "")),
			UiTheme.FONT_SMALL, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	_card_body.add_child(UiTheme.label(level.display_name, UiTheme.FONT_TITLE,
		UiTheme.GOLD if unlocked else Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	if level.subtitle != "":
		_card_body.add_child(UiTheme.label(level.subtitle, UiTheme.FONT_SMALL,
			UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	# Les memes etoiles que sur la carte : le joueur retrouve ce qu il a touche.
	var stars: int = SaveData.objectives_done_count(level)
	var star_text: String = ""
	for i in level.objectives.size():
		star_text += "*" if i < stars else "."
	_card_body.add_child(UiTheme.label(star_text, 40,
		UiTheme.GOLD if stars > 0 else Color(0.55, 0.50, 0.45), HORIZONTAL_ALIGNMENT_CENTER))

	# Apercu du boss : ce qui attend le joueur en fin de niveau.
	var boss: WaveDef = level.boss_wave()
	var boss_name: String = "?"
	if boss != null and not boss.enemy_defs().is_empty():
		boss_name = boss.enemy_defs()[0].display_name
	_card_body.add_child(UiTheme.label("%d vagues   -   Boss : %s" % [level.waves.size(), boss_name],
		UiTheme.FONT_BODY, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_body.add_child(spacer)

	if not unlocked:
		_card_body.add_child(UiTheme.label("VERROUILLE\nTermine le niveau precedent",
			UiTheme.FONT_BODY, Color(0.45, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var rec: Dictionary = SaveData.level_record(level.id)
		var best: int = int(rec.get("best_wave", 0))
		var status: String = "Termine" if cleared else "Meilleure vague : %d" % best
		_card_body.add_child(UiTheme.label(status, UiTheme.FONT_BODY,
			UiTheme.GREEN if cleared else UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

		# Objectifs : les 3 badges qui debloquent la legendaire.
		var objs: Dictionary = rec.get("objectives", {})
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 6)
		_card_body.add_child(box)
		for obj in level.objectives:
			if obj == null:
				continue
			var done: bool = bool(objs.get(String(obj.id), false))
			# Meme formulation que le briefing et l ecran de victoire : le mot
			# porte l etat, jamais un prefixe entre crochets.
			box.add_child(UiTheme.label(
				"%s  -  %s" % ["Acquis" if done else "A faire", obj.description],
				UiTheme.FONT_SMALL, UiTheme.GREEN if done else UiTheme.TEXT_DARK))
		if level.legendary_reward != null:
			var got: bool = SaveData.unlocked_legendaries().has(String(level.legendary_reward.id))
			box.add_child(UiTheme.label("Recompense : %s%s" % [level.legendary_reward.display_name,
				"  (obtenue)" if got else ""], UiTheme.FONT_SMALL, UiTheme.rarity_ink(GameEnums.Rarity.LEGENDARY)))

	# Bouton JOUER et message d aide selon le mode.
	var reason: String = ""
	if not unlocked:
		reason = "Niveau verrouille"
	elif _mode == GameEnums.Mode.MASSACRE:
		reason = DeckRules.validation_message(SaveData.massacre_deck())
	_play_btn.disabled = reason != ""
	if reason != "":
		_hint.text = reason
	elif _mode == GameEnums.Mode.EXPLORATION:
		_hint.text = "Deck pre-etabli du niveau (%d cartes)" % level.exploration_deck.size()
	else:
		_hint.text = "Vagues INFINIES avec ton deck (%d cartes)  -  un sort a choisir toutes les %d vagues" % [
			SaveData.massacre_deck().size(), GameController.WAVES_PER_CHOICE]


func _on_play() -> void:
	var level: LevelDef = _current()
	if level == null:
		return
	SaveData.set_current_level(level.id)
	SaveData.save_profile()
	SceneRouter.start_level(level.id, _mode)
