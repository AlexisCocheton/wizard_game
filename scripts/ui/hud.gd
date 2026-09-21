extends CanvasLayer
## HUD portrait 1080x1920, dispose selon le cahier des charges :
##
##   [x2]        Vague 3/6  Niv.4          [||]
##   +--------------------------------------+
##   | jauge |                      | jauge |
##   | ennemi|    champ de bataille | sorts |
##   | (gauche)                     |(droite
##   |       |                      | = PV) |
##   +--------------------------------------+
##            [carte][carte][carte]
##   ================ XP ====================
##
## Les cartes sont des CardView (nom, effet, rarete) ; on les glisse sur le
## terrain pour viser. Un choix de 3 cartes se superpose au jeu quand il y a lieu.

var game: GameController = null

@onready var _root: Control = $Root
@onready var _speed_btn: Button = %SpeedButton
@onready var _pause_btn: Button = %PauseButton
@onready var _wave_label: Label = %WaveLabel
@onready var _enemy_bar: TextureProgressBar = %EnemyBar
@onready var _spell_bar: TextureProgressBar = %SpellBar
@onready var _hp_label: Label = %HpLabel
@onready var _xp_bar: TextureProgressBar = %XpBar
@onready var _hand: HBoxContainer = %Hand
@onready var _cast_bar: TextureProgressBar = %CastBar
@onready var _draw_label: Label = %DrawTimer
@onready var _aim: Control = %AimOverlay

## Carte en cours de glissement (null si aucun geste en cours).
var _dragging: SpellCard = null
var _choice: Control = null


func _ready() -> void:
	# Sans cela le HUD gele avec le jeu : son propre bouton pause ne repond plus
	# et la partie reste bloquee pour de bon.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = UiTheme.make()
	_style_hud_labels()
	# La vitesse n est plus PILOTABLE (demande du testeur du 21 septembre) : ni
	# par le bouton, ni en touchant la barre. Le bouton reste comme AFFICHAGE du
	# pourcentage, sans signal `pressed` — et la barre laisse passer le doigt,
	# sinon elle avalerait les glissements de carte qui commencent au-dessus
	# d elle (un Control en MOUSE_FILTER_STOP consomme l evenement, voir le
	# piege du Button documente en memoire).
	_speed_btn.disabled = true
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_enemy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_btn.pressed.connect(_on_pause_pressed)
	RunState.card_drawn.connect(func(_c: SpellCard) -> void: AudioBus.play_sfx(&"card_draw"))
	SpeedGauge.multiplier_changed.connect(_on_multiplier_changed)
	SpeedGauge.hp_changed.connect(_on_hp_changed)
	RunState.hand_changed.connect(_refresh_hand)
	RunState.wave_changed.connect(_on_wave_changed)
	# Le choix peut etre pris ailleurs que par un clic (tests, reprise) : on suit l etat.
	RunState.offer_taken.connect(func(_c: SpellCard) -> void:
		if _choice != null:
			_choice.visible = false)
	_build_choice_overlay()
	_refresh_all()


## Les trois labels poses A MEME le champ de bataille (vague, PV, pioche) sont
## ecrits sur un fond PEINT dont la couleur change d un acte a l autre : sur le
## ciel clair de l acte I, un texte clair disparaissait purement et simplement.
## Un contour sombre epais les detache de n importe quel fond, et une taille
## fixee ici evite qu ils heritent d une valeur choisie pour un panneau.
func _style_hud_labels() -> void:
	for l: Label in [_wave_label, _hp_label, _draw_label]:
		l.add_theme_font_override(&"font", UiTheme.font())
		l.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.06, 0.95))
		l.add_theme_constant_override(&"outline_size", 10)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wave_label.add_theme_font_size_override(&"font_size", 32)
	_wave_label.add_theme_color_override(&"font_color", UiTheme.TEXT)
	_hp_label.add_theme_font_size_override(&"font_size", 34)
	_hp_label.add_theme_color_override(&"font_color", UiTheme.RED.lightened(0.35))


func bind(controller: GameController) -> void:
	game = controller
	if game != null:
		# Idempotent : bind() peut etre rappele si le niveau redemarre.
		if not game.caster.cast_progress.is_connected(_on_cast_progress):
			game.caster.cast_progress.connect(_on_cast_progress)
		if not game.caster.cast_finished.is_connected(_on_cast_finished):
			game.caster.cast_finished.connect(_on_cast_finished)
		if not game.cards_offered.is_connected(_show_choice):
			game.cards_offered.connect(_show_choice)
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_gauges()


func _refresh_all() -> void:
	_refresh_gauges()
	_refresh_hand()
	_on_wave_changed(RunState.wave_index)
	_on_hp_changed(SpeedGauge.hp)


func _refresh_gauges() -> void:
	# Gauche : la vitesse, de 100 a 500 %. Droite : les PV du mage, bouclier inclus.
	_enemy_bar.value = SpeedGauge.speed_ratio() * 100.0
	var pv_max: float = float(maxi(1, SpeedGauge.max_hp))
	_spell_bar.value = 100.0 * float(SpeedGauge.hp) / pv_max
	_speed_btn.text = "%d%%" % SpeedGauge.speed_percent
	# Simple afficheur : il reste `disabled` en permanence (regle une fois dans
	# _ready), et sa teinte dit seulement si la montee est retenue par un coup
	# recu — la seule chose que le joueur peut encore lire sur la vitesse.
	_speed_btn.modulate = Color(1, 0.6, 0.6) if SpeedGauge.accel_locked() else Color.WHITE

	# Le sort prepare doit se voir, sinon le joueur ne sait pas ce qui va partir.
	var en_attente: SpellCard = null
	if game != null and game.caster != null:
		en_attente = game.caster.queued_card()
	for child in _hand.get_children():
		if child is CardView:
			var cv := child as CardView
			cv.modulate = Color(1.0, 0.92, 0.6) if (en_attente != null and cv.card == en_attente) 				else Color.WHITE

	# Compte a rebours de la prochaine pioche : le joueur jouait a l aveugle
	# entre deux pioches, sans savoir s il devait garder une carte ou la depenser.
	var dans: float = RunState.seconds_to_draw()
	_draw_label.text = "pioche dans %.1f s" % dans
	_draw_label.add_theme_color_override(&"font_color",
		UiTheme.GOLD if dans < 1.0 else UiTheme.TEXT)
	# 24 px sur un fond peint se lisait mal : c est pourtant le compte a rebours
	# qui dit s il faut depenser une carte ou en garder une.
	_draw_label.add_theme_font_size_override(&"font_size", 28)

	var need: int = GameConfig.xp_required(RunState.level)
	_xp_bar.value = 100.0 * float(RunState.xp) / float(maxi(1, need))

	if SpeedGauge.is_dying:
		_spell_bar.modulate = Color(1, 1, 1, 0.4 + 0.6 * SpeedGauge.death_gauge)


func _fmt(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


# --- Main de cartes ---

## La main ne porte QUE l icone, le nom court et le temps d incantation.
## Le detail (description, ciblage) est dans le panneau de PAUSE : c est la seule
## reponse possible a "on n a pas le temps de lire le texte des cartes en jeu".
## Une carte de main fait 120 px a 8 cartes ; aucune police lisible n y fait tenir
## une description, donc on a cesse d essayer.
func _refresh_hand() -> void:
	for child in _hand.get_children():
		child.queue_free()
	var n: int = RunState.hand.size()
	if n == 0:
		return
	# La main tient dans la largeur : les cartes retrecissent quand elles sont
	# nombreuses. A 8 cartes (le maximum) on tombe a ~125 px, ce qui reste une
	# cible tactile confortable et laisse 100 px d icone.
	var width: float = clampf((1052.0 - 6.0 * (n - 1)) / n, 118.0, 200.0)
	# Hauteur constante : la main ne doit pas sauter quand une carte entre ou sort.
	for card: SpellCard in RunState.hand:
		var cv := CardView.new()
		cv.setup_hand(card, width, 230.0)
		cv.gui_input.connect(_on_card_input.bind(card))
		_hand.add_child(cv)


func _needs_aim(card: SpellCard) -> bool:
	return card != null and card.targeting != GameEnums.Targeting.NONE


## Glisser-deposer : on appuie sur la carte, on glisse sur le terrain, on relache.
## Une carte sans ciblage part au simple appui.
##
## La carte a mouse_filter = STOP : elle CONSOMME le relachement, qui n atteint
## donc jamais _unhandled_input. Le suivi et le relachement sont pour cette
## raison geres dans _input(), qui recoit l evenement avant l UI.
func _on_card_input(event: InputEvent, card: SpellCard) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		if _needs_aim(card):
			_begin_drag(card, mb.global_position)
		else:
			_play(card, Vector2.INF)


func _begin_drag(card: SpellCard, screen_pos: Vector2) -> void:
	_dragging = card
	var point: Vector2 = _battlefield_point(screen_pos)
	_aim.show_aim(card, point, _is_valid_aim(point))


## Recoit TOUS les evenements, y compris ceux que les cartes consomment ensuite.
func _input(event: InputEvent) -> void:
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = _battlefield_point((event as InputEventMouseMotion).global_position)
		_aim.show_aim(_dragging, point, _is_valid_aim(point))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_drag(mb.global_position)
			get_viewport().set_input_as_handled()


func _end_drag(screen_pos: Vector2) -> void:
	var card: SpellCard = _dragging
	_dragging = null
	_aim.hide_aim()
	if card == null:
		return
	var point: Vector2 = _battlefield_point(screen_pos)
	if _is_valid_aim(point):
		_play(card, point)
	# Visee hors terrain : la carte reste en main, le geste est simplement annule.


## La zone jouable exclut la main de cartes et la barre du haut.
func _is_valid_aim(point: Vector2) -> bool:
	return point.y > 160.0 and point.y < GameConfig.MAGE_LINE_Y \
		and point.x > 0.0 and point.x < GameConfig.BATTLEFIELD_WIDTH


## Convertit un point ecran en coordonnees du champ de bataille.
func _battlefield_point(screen_pos: Vector2) -> Vector2:
	if game == null:
		return screen_pos
	return game.battlefield.to_local(screen_pos)


func _play(card: SpellCard, aim: Vector2) -> void:
	if game != null:
		game.play_card(card, aim)


# --- Choix de cartes ---

func _build_choice_overlay() -> void:
	_choice = Control.new()
	_choice.name = "CardChoice"
	_choice.visible = false
	_choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_choice)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice.add_child(dim)


func _show_choice(cards: Array[SpellCard]) -> void:
	for ch in _choice.get_children():
		if ch is ColorRect:
			continue
		ch.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 380.0
	box.offset_bottom = -420.0
	box.add_theme_constant_override(&"separation", 40)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice.add_child(box)
	box.add_child(UiTheme.label("CHOISIS UN SORT", UiTheme.FONT_TITLE, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Il rejoint ta defausse et reviendra dans la pioche.",
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# Mode BRULER : on arme d abord, puis on touche la carte a sacrifier.
	var burn_btn := Button.new()
	burn_btn.text = "BRULER UNE CARTE"
	burn_btn.custom_minimum_size = Vector2(0, 76)
	burn_btn.toggle_mode = true
	burn_btn.toggled.connect(func(on: bool) -> void:
		_burn_armed = on
		burn_btn.text = "CHOISIS LA CARTE A BRULER" if on else "BRULER UNE CARTE")
	box.add_child(burn_btn)
	box.add_child(UiTheme.label("Brulee : lancee tout de suite, mais elle n entre pas dans ton deck.",
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in cards.size():
		var cv := CardView.new()
		# Le choix de sort suspend le jeu : c est un ecran de LECTURE, donc la
		# carte y est en mode detail, description comprise.
		cv.setup_detail(cards[i], 300.0, 440.0, 30, 22)
		cv.pressed.connect(func(_c: SpellCard) -> void: _pick(i))
		row.add_child(cv)
	_choice.visible = true


## Armement du mode bruler : le joueur clique le bouton, puis la carte.
var _burn_armed: bool = false


func _pick(i: int) -> void:
	AudioBus.play_sfx(&"card_pick")
	_choice.visible = false
	if game == null:
		return
	if _burn_armed:
		_burn_armed = false
		game.burn_card(i)
		return
	game.choose_card(i)


# --- Divers ---

func _on_cast_progress(ratio: float) -> void:
	_cast_bar.visible = true
	_cast_bar.value = ratio * 100.0


func _on_cast_finished(_card: SpellCard) -> void:
	_cast_bar.visible = false
	_cast_bar.value = 0.0


## Le HUD DOIT continuer a tourner en pause, sinon son propre bouton ne repond
## plus et la partie reste bloquee. C est ce qui arrivait : un seul clic figeait
## tout, y compris le moyen de repartir.
func _on_pause_pressed() -> void:
	var tree: SceneTree = get_tree()
	tree.paused = not tree.paused
	_pause_btn.text = ">" if tree.paused else "II"
	if tree.paused:
		_show_pause_panel()
	elif _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null


## Panneau de pause : ce que le joueur a en cours. Les pouvoirs passifs sont
## invisibles une fois joues — sans cet ecran, il ne peut plus savoir lesquels il
## a pris ni ce qui lui reste en deck.
var _pause_panel: Control = null


func _show_pause_panel() -> void:
	if _pause_panel != null:
		_pause_panel.queue_free()
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_pause_panel)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.05, 0.04, 0.09, 0.82)
	_pause_panel.add_child(scrim)

	var paper := PanelContainer.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 50.0
	paper.offset_right = -50.0
	paper.offset_top = 260.0
	paper.offset_bottom = -260.0
	UiTheme.style_paper(paper)
	_pause_panel.add_child(paper)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 16)
	scroll.add_child(box)

	box.add_child(UiTheme.label("PAUSE", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER))

	# LA MAIN EN GRAND, en premier. C est la raison d etre de cet ecran depuis le
	# retour du testeur : "on peut mettre pause pour regarder ses cartes et lire
	# dans le detail". En jeu la carte ne montre qu une icone ; c est ICI qu on
	# apprend ce que l icone veut dire, une fois pour toutes.
	_build_pause_hand(box)

	# Les passifs ensuite : information qu on ne peut lire nulle part ailleurs.
	box.add_child(UiTheme.label("POUVOIRS ACTIFS", UiTheme.FONT_BODY, UiTheme.GOLD))
	if RunState.active_passives.is_empty():
		box.add_child(UiTheme.label("Aucun pour l instant.", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))
	else:
		for p: SpellCard in RunState.active_passives:
			var ligne := HBoxContainer.new()
			ligne.add_theme_constant_override(&"separation", 12)
			var ico: TextureRect = CardIcons.make_rect(p, 64.0)
			if ico != null:
				ligne.add_child(ico)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# 22/17 px etait illisible sur la capture : le nom du passif ne se
			# distinguait pas de sa description.
			col.add_child(UiTheme.label(p.display_name, 28, UiTheme.TEXT_DARK,
				HORIZONTAL_ALIGNMENT_LEFT, false))
			col.add_child(UiTheme.label(p.description, 22, Color(0.40, 0.31, 0.22)))
			ligne.add_child(col)
			box.add_child(ligne)

	box.add_child(UiTheme.label("TON DECK", UiTheme.FONT_BODY, UiTheme.GOLD))
	box.add_child(UiTheme.label(
		"Pioche %d   -   Main %d   -   Defausse %d"
		% [RunState.deck.size(), RunState.hand.size(), RunState.discard.size()],
		UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))

	# Composition restante, par nom : le joueur decide s il garde ou depense.
	var restant: Dictionary = {}
	for c: SpellCard in RunState.deck:
		restant[c.display_name] = int(restant.get(c.display_name, 0)) + 1
	for c2: SpellCard in RunState.discard:
		restant[c2.display_name] = int(restant.get(c2.display_name, 0)) + 1
	var noms: Array = restant.keys()
	noms.sort()
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override(&"h_separation", 14)
	wrap.add_theme_constant_override(&"v_separation", 6)
	for nom in noms:
		# `wrap = false` : sans cela le nom se replie LETTRE PAR LETTRE dans la
		# colonne etroite que le conteneur lui accorde.
		var tag := UiTheme.label("%s x%d" % [nom, restant[nom]], 22, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		wrap.add_child(tag)
	box.add_child(wrap)

	var reprendre := Button.new()
	reprendre.text = "REPRENDRE"
	reprendre.custom_minimum_size = Vector2(0, 96)
	reprendre.process_mode = Node.PROCESS_MODE_ALWAYS
	reprendre.pressed.connect(_on_pause_pressed)
	box.add_child(reprendre)

	# QUITTER (demande du testeur) : "dans l onglet pause on peut quitter le
	# combat pour retourner au menu". En dessous de REPRENDRE et non au-dessus :
	# on ne met pas la sortie definitive sous le pouce de quelqu un qui voulait
	# seulement reprendre.
	var quitter := Button.new()
	quitter.text = "QUITTER LE COMBAT"
	quitter.custom_minimum_size = Vector2(0, 96)
	quitter.process_mode = Node.PROCESS_MODE_ALWAYS
	quitter.pressed.connect(_on_quit_pressed)
	box.add_child(quitter)


## Quitter le combat et revenir au menu.
##
## L ORDRE compte et c est tout le piege : on DEPAUSE avant de changer de scene.
## Partir en laissant `get_tree().paused` a vrai rendrait le menu inerte — ses
## boutons ne repondraient plus et le joueur serait coince sur un ecran mort,
## sans meme comprendre pourquoi.
##
## On arrete ensuite la partie (`abandon_run`) AVANT `goto()` : le champ de
## bataille part en liberation avec la scene, et une simulation qui continuerait
## dessus planterait.
func _on_quit_pressed() -> void:
	get_tree().paused = false
	if _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null
	_pause_btn.text = "II"
	if game != null and game.has_method("abandon_run"):
		game.abandon_run()
	AudioBus.play_music(&"menu")
	SceneRouter.goto(SceneRouter.MAIN_MENU)


## Les cartes en main, en grand et avec leur description complete.
##
## Disposition en LIGNES et non en grille de cartes : une description tient sur
## une ligne de texte, pas dans une carte de 200 px. L icone est a gauche, a la
## meme taille et avec la meme teinte qu en main — c est ce qui fait le lien entre
## ce qu on lit ici et ce qu on reconnait en jeu.
func _build_pause_hand(box: VBoxContainer) -> void:
	box.add_child(UiTheme.label("TA MAIN  (%d)" % RunState.hand.size(),
		UiTheme.FONT_BODY, UiTheme.GOLD))
	if RunState.hand.is_empty():
		box.add_child(UiTheme.label("Main vide : la prochaine pioche arrive.",
			UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))
		return
	for c: SpellCard in RunState.hand:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override(&"separation", 16)
		# Meme icone qu en main, en plus grand : c est la cle de lecture.
		var ico: TextureRect = CardIcons.make_rect(c, 76.0)
		if ico != null:
			ligne.add_child(ico)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override(&"separation", 2)

		# Nom + temps sur la meme ligne, sans autowrap : dans la colonne etroite
		# que le conteneur accorde, UiTheme.label replierait LETTRE PAR LETTRE.
		var entete := HBoxContainer.new()
		entete.add_theme_constant_override(&"separation", 14)
		var nom := UiTheme.label(c.display_name, 28, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entete.add_child(nom)
		entete.add_child(UiTheme.label("%ss" % _fmt(c.base_cast_time), 26,
			UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_RIGHT, false))
		col.add_child(entete)

		# La description, elle, DOIT se replier : c est une phrase.
		col.add_child(UiTheme.label(c.description, 22, Color(0.36, 0.28, 0.20)))
		if c.targeting != GameEnums.Targeting.NONE:
			col.add_child(UiTheme.label(_targeting_hint(c.targeting), 20,
				Color(0.20, 0.38, 0.70), HORIZONTAL_ALIGNMENT_LEFT, false))
		ligne.add_child(col)
		box.add_child(ligne)


## Meme libelle que sur la carte de detail : le geste s apprend une seule fois.
func _targeting_hint(t: int) -> String:
	match t:
		GameEnums.Targeting.POSITION: return "glisser sur une zone"
		GameEnums.Targeting.DIRECTION: return "glisser pour viser"
		GameEnums.Targeting.TARGET: return "glisser sur un monstre"
	return ""


func _on_multiplier_changed(_old: int, _new: int) -> void:
	_refresh_gauges()


func _on_hp_changed(hp: int) -> void:
	_hp_label.text = "PV %d/%d" % [hp, SpeedGauge.max_hp]


func _on_wave_changed(index: int) -> void:
	var total: int = 0
	if RunState.current_level_def != null and RunState.mode == GameEnums.Mode.EXPLORATION:
		total = RunState.current_level_def.waves.size()
	if total > 0:
		_wave_label.text = "Vague %d/%d   Niv.%d" % [mini(index + 1, total), total, RunState.level]
	else:
		_wave_label.text = "Vague %d   Niv.%d" % [index + 1, RunState.level]
