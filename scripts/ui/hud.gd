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
## Rail des icones de passifs, pose le long de la barre de vitesse.
## Cree par code : les passifs equipes changent en cours de partie, une
## scene figee ne pourrait pas les suivre.
var _passive_rail: Control = null
var _passive_icons: Array[Control] = []

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
	_build_passive_rail()
	# Le rail se reconstruit quand la barre de passifs change (gain, echange).
	if not RunState.passives_changed.is_connected(_build_passive_rail):
		RunState.passives_changed.connect(_build_passive_rail)
	if not RunState.passive_swap_needed.is_connected(_on_passive_swap_needed):
		RunState.passive_swap_needed.connect(_on_passive_swap_needed)
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

	_refresh_passive_rail()


# --- Icones des passifs, le long de la barre de vitesse ---
#
# Demande du testeur : "en combat, afficher l icone des passifs a cote de la
# barre de speed, AU NIVEAU CORRESPONDANT D ACTIVATION du passif."
#
# La barre de vitesse (EnemyBar) est un TextureProgressBar tourne de -90 deg :
# son origine est en bas et elle monte. On ne peut donc pas y ranger des enfants
# sans qu ils tournent avec elle. Le rail est un Control SOEUR, pose a cote, qui
# recalcule les memes coordonnees en droit fil.
#
# Chaque icone est placee a la HAUTEUR de son seuil : le joueur lit d un coup
# d oeil ce qui va s allumer s il tient encore un peu, et ce qu il vient de
# perdre en se faisant toucher. Grise sous le seuil, allumee au-dessus.

## Geometrie de la barre de vitesse, relevee sur HUD.tscn. Le rail doit suivre
## la barre a l identique ; une valeur en dur ici et une autre dans la scene
## divergeraient au premier deplacement.
const RAIL_BAS: float = 1484.0      ## y de 100 % (bas de la barre)
const RAIL_HAUT: float = 234.0      ## y du maximum (haut de la barre)
const RAIL_X: float = 104.0         ## a droite de la barre, hors de son epaisseur
const ICONE: float = 54.0


func _build_passive_rail() -> void:
	if _passive_rail == null:
		_passive_rail = Control.new()
		_passive_rail.name = "PassiveRail"
		# IGNORE : le rail couvre la zone ou commencent les glissements de carte.
		# Un Control en STOP y avalerait le geste (piege du Button, en memoire).
		_passive_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passive_rail.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(_passive_rail)
	for c in _passive_icons:
		if is_instance_valid(c):
			c.queue_free()
	_passive_icons.clear()

	var etendue: float = float(GameConfig.SPEED_MAX_PERCENT - 100)
	# Trie par seuil CROISSANT : le rail se lit de bas en haut, et deux passifs
	# proches doivent s ecarter dans le bon ordre, jamais se croiser.
	var equipes: Array[SpellCard] = []
	for p: SpellCard in RunState.equipped_passives:
		if p != null:
			equipes.append(p)
	equipes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return a.speed_threshold < b.speed_threshold)

	# Hauteur du dernier pose, pour ecarter ce qui se chevauche.
	var precedent_y: float = INF
	for p: SpellCard in equipes:
		var t: float = clampf(float(p.speed_threshold - 100) / maxf(etendue, 1.0), 0.0, 1.0)
		# Marge d une demi-pastille en haut ET en bas : un passif a 110 % tombait
		# pile sur le bord bas de la barre, derriere le mage et la main, donc
		# invisible — alors que c est justement le passif le plus souvent allume.
		var y: float = clampf(RAIL_BAS - t * (RAIL_BAS - RAIL_HAUT),
			RAIL_HAUT + ICONE * 0.5, RAIL_BAS - ICONE * 0.7)
		# ECARTEMENT MINIMAL. Deux passifs a 140 % et 150 % tombent a 5 px l un de
		# l autre sur une echelle de 100 a 500 : les pastilles se chevauchaient et
		# les deux seuils se superposaient en un pate illisible (vu sur capture).
		# On pousse le suivant VERS LE HAUT, donc dans le sens de son seuil : la
		# hauteur reste approximativement juste et l ordre, lui, est exact.
		# L ecart doit tenir la PASTILLE **et** son etiquette. A 66 px les
		# pastilles se separaient mais les nombres "150 %" et "140 %" se
		# touchaient encore (vu sur capture) : le seuil est la seule information
		# chiffree du rail, deux nombres colles n en font aucun de lisible.
		var ecart: float = ICONE + UiTheme.FONT_SMALL + 14.0
		if precedent_y - y < ecart:
			y = precedent_y - ecart
		# RE-BORNER apres le decalage, sinon une pastille poussee vers le haut
		# sort du rail : sur la capture, celle du seuil 300 avait disparu et
		# seule son etiquette restait, ce qui se lit comme un bug d affichage.
		y = clampf(y, RAIL_HAUT + ICONE * 0.5, RAIL_BAS - ICONE * 0.7)
		precedent_y = y
		var pastille := Panel.new()
		# IGNORE par defaut : hors echange, le rail ne doit rien avaler du geste de
		# glisser-deposer qui commence souvent a gauche de l ecran. Il ne redevient
		# cliquable que pendant un echange (voir _on_passive_swap_needed).
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.custom_minimum_size = Vector2(ICONE, ICONE)
		# position AVANT add_child : _ready() part des l ajout.
		pastille.position = Vector2(RAIL_X, y - ICONE * 0.5)
		pastille.size = Vector2(ICONE, ICONE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.11, 0.92)
		sb.set_border_width_all(4)
		sb.border_color = UiTheme.rarity_color(p.rarity)
		sb.set_corner_radius_all(int(ICONE * 0.5))
		pastille.add_theme_stylebox_override(&"panel", sb)

		# L initiale suffit a distinguer trois passifs et tient dans 54 px ; un
		# nom entier y serait illisible et une icone d asset n existe pas encore.
		var lettre := Label.new()
		lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lettre.text = p.display_name.substr(0, 1).to_upper()
		lettre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lettre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lettre.set_anchors_preset(Control.PRESET_FULL_RECT)
		lettre.add_theme_font_override(&"font", UiTheme.font())
		lettre.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		lettre.add_theme_color_override(&"font_color", UiTheme.rarity_color(p.rarity))
		pastille.add_child(lettre)

		# Le SEUIL en clair sous la pastille : sans le nombre, le joueur devine la
		# hauteur sans jamais savoir combien il lui manque.
		var seuil := Label.new()
		seuil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seuil.text = "%d%%" % p.speed_threshold
		seuil.position = Vector2(RAIL_X + ICONE + 6.0, y - 16.0)
		seuil.add_theme_font_override(&"font", UiTheme.font())
		# 22 px etait sous le plancher du theme : le seuil, qui est la seule
		# information CHIFFREE du rail, etait le texte le moins lisible de l ecran.
		seuil.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		seuil.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.06, 0.95))
		seuil.add_theme_constant_override(&"outline_size", 8)
		pastille.set_meta(&"seuil_label", seuil)
		pastille.set_meta(&"carte", p)

		_passive_rail.add_child(pastille)
		_passive_rail.add_child(seuil)
		_passive_icons.append(pastille)


func _refresh_passive_rail() -> void:
	for pastille in _passive_icons:
		if not is_instance_valid(pastille):
			continue
		var p: SpellCard = pastille.get_meta(&"carte") as SpellCard
		if p == null:
			continue
		var allume: bool = SpeedGauge.speed_percent >= p.speed_threshold
		# Grise tant que la vitesse n atteint pas le seuil, pleine au-dessus. Le
		# changement doit etre FRANC : c est la seule facon de voir, au moment ou
		# on encaisse un coup, ce que la chute de vitesse vient d eteindre.
		pastille.modulate = Color.WHITE if allume else Color(0.55, 0.55, 0.62, 0.8)
		var l: Label = pastille.get_meta(&"seuil_label") as Label
		if l != null and is_instance_valid(l):
			l.modulate = pastille.modulate
		# Pendant un echange, la pastille designee clignote pour dire "touche-moi".
		if RunState.pending_passive != null:
			pastille.modulate = Color(1, 1, 1, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006))


## Un quatrieme passif est gagne alors que les trois emplacements sont pleins.
## "On doit selectionner un des trois passifs a changer" : le choix se fait SUR
## LE RAIL lui-meme, la ou les trois passifs sont deja affiches a leur hauteur.
## Un panneau separe aurait oblige le joueur a retrouver, dans une liste, les
## memes trois icones qu il a sous les yeux.
func _on_passive_swap_needed(card: SpellCard) -> void:
	if card == null:
		return
	_build_passive_rail()
	for i in _passive_icons.size():
		var pastille: Control = _passive_icons[i]
		if not is_instance_valid(pastille):
			continue
		# Seules ces trois pastilles redeviennent cliquables, et seulement le temps
		# de l echange : ensuite le rail redevient transparent au doigt.
		pastille.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot: int = i
		pastille.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				_resolve_passive_swap(slot))
	_passive_prompt(card)


## Bandeau qui annonce le passif gagne et ce qu il attend du joueur. Sans lui,
## trois pastilles qui clignotent ne veulent rien dire.
func _passive_prompt(card: SpellCard) -> void:
	if _passive_swap_label != null and is_instance_valid(_passive_swap_label):
		_passive_swap_label.queue_free()
	var l := UiTheme.label_hud(
		"%s\nTouche le pouvoir a remplacer" % card.display_name,
		UiTheme.FONT_BODY, UiTheme.rarity_color(card.rarity))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(180.0, 1180.0)
	l.size = Vector2(760.0, 140.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	_passive_swap_label = l


var _passive_swap_label: Label = null


func _resolve_passive_swap(slot: int) -> void:
	if RunState.pending_passive == null:
		return
	AudioBus.play_sfx(&"card_pick")
	RunState.resolve_pending_passive(slot)
	if _passive_swap_label != null and is_instance_valid(_passive_swap_label):
		_passive_swap_label.queue_free()
		_passive_swap_label = null
	# _build_passive_rail() est rappele par passives_changed : les pastilles
	# reviennent en MOUSE_FILTER_IGNORE et cessent de clignoter.


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
		_ajouter_jauge_amelioration(cv, card, width)


## Le liseré de PROGRESSION VERS L AMELIORATION, en bas de la carte en main.
##
## Sans lui, le palier des 8 lancers tombe comme une surprise : le joueur voit
## surgir un ecran modal sans avoir rien vu venir, et il ne peut pas decider de
## rejouer un sort plutot qu un autre pour le faire murir. Le systeme d amelioration
## n a de sens que si sa progression se voit.
##
## Pose PAR-DESSUS la carte plutot qu integre a `CardView` : ce script est
## partage par le grimoire, le deck et l ecran de choix, ou la notion de
## "lancers dans la partie en cours" n existe pas.
##
## Un LISERE et non un texte : la main descend a 118 px de large quand elle est
## pleine, un "5/8" y serait illisible, alors qu une barre qui se remplit se lit
## du coin de l oeil pendant qu on joue.
func _ajouter_jauge_amelioration(cv: Control, card: SpellCard, width: float) -> void:
	if card == null or card.is_passive:
		return
	var avance: float = RunState.upgrade_progress(card)
	if avance <= 0.0:
		return
	var acquise: bool = RunState.upgrade_of(card) != &""
	var jauge := ProgressBar.new()
	jauge.show_percentage = false
	jauge.value = avance * 100.0
	# La jauge est INSEREE dans la colonne de la carte, en dernier enfant : c est
	# ce qui la pose au bas quelle que soit la hauteur reelle. Deux tentatives
	# ont echoue avant, toutes deux vues en capture :
	#   - une position en dur ("230 - 14") la collait EN HAUT, parce que
	#     `setup_hand` pose une taille MINIMALE et que le conteneur donne a la
	#     carte une autre hauteur ;
	#   - un `set_anchors_preset` la reduisait a un trait, le conteneur
	#     redimensionnant l enfant par-dessus les marges.
	jauge.custom_minimum_size = Vector2(0, 10.0)
	jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.20, 0.17, 0.14, 0.55)
	fond.set_corner_radius_all(4)
	var plein := StyleBoxFlat.new()
	# DOREE quand l amelioration est prise, TEAL tant qu elle mûrit : le joueur
	# distingue d un coup d oeil un sort fini d un sort en cours.
	plein.bg_color = UiTheme.GOLD if acquise else UiTheme.TEAL
	plein.set_corner_radius_all(4)
	jauge.add_theme_stylebox_override(&"background", fond)
	jauge.add_theme_stylebox_override(&"fill", plein)
	# La colonne interne de CardView, pas la carte elle-meme.
	var colonne: Node = null
	for enfant in cv.get_children():
		if enfant is VBoxContainer:
			colonne = enfant
			break
	if colonne == null:
		return
	var marge := MarginContainer.new()
	marge.add_theme_constant_override(&"margin_left", 6)
	marge.add_theme_constant_override(&"margin_right", 6)
	marge.add_theme_constant_override(&"margin_bottom", 4)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(jauge)
	colonne.add_child(marge)


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
	if RunState.equipped_passives.is_empty():
		box.add_child(UiTheme.label("Aucun pour l instant.", UiTheme.FONT_SMALL, UiTheme.TEXT_DARK))
	else:
		for p: SpellCard in RunState.equipped_passives:
			var ligne := HBoxContainer.new()
			ligne.add_theme_constant_override(&"separation", 12)
			var ico: TextureRect = CardIcons.make_rect(p, 64.0)
			if ico != null:
				ligne.add_child(ico)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Tailles prises dans le THEME et jamais ecrites en dur : une taille
			# litterale ne profite d aucun reglage global, et ce panneau s etait
			# deja detache une fois de cette facon (piege consigne en memoire).
			col.add_child(UiTheme.label(p.display_name, UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
				HORIZONTAL_ALIGNMENT_LEFT, false))
			col.add_child(UiTheme.label(p.description, UiTheme.FONT_SMALL,
				Color(0.40, 0.31, 0.22)))
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
		var tag := UiTheme.label("%s x%d" % [nom, restant[nom]], UiTheme.FONT_SMALL,
			UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_LEFT, false)
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
		var nom := UiTheme.label(c.display_name, UiTheme.FONT_BODY, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_LEFT, false)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entete.add_child(nom)
		entete.add_child(UiTheme.label("%ss" % _fmt(c.base_cast_time), UiTheme.FONT_SMALL,
			UiTheme.rarity_ink(c.rarity), HORIZONTAL_ALIGNMENT_RIGHT, false))
		col.add_child(entete)

		# La description, elle, DOIT se replier : c est une phrase.
		col.add_child(UiTheme.label(c.description, UiTheme.FONT_SMALL,
			Color(0.36, 0.28, 0.20)))
		if c.targeting != GameEnums.Targeting.NONE:
			col.add_child(UiTheme.label(_targeting_hint(c.targeting), UiTheme.FONT_SMALL,
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
