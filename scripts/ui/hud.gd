extends CanvasLayer
## HUD portrait 1080x1920, dispose selon le cahier des charges :
##
##   [285%]      Vague 3/6  Niv.4          [||]
##   +--------------------------------------+
##   |vitesse|                              |
##   |  =    |      champ de bataille       |
##   |  vie  |                              |
##   |       |                              |
##   +--------------------------------------+
##            [carte][carte][carte]
##   ================ XP ====================
##
## UNE SEULE BARRE VERTICALE depuis le 26 septembre. La barre de vie de droite a
## ete SUPPRIMEE : le mage n a plus de PV, sa vitesse est sa vie. La barre de
## gauche porte donc les deux lectures a la fois, et sa couleur passe de l or au
## rouge a mesure qu elle descend vers le plancher mortel de 100 %.
##
## On a retire la barre plutot que de la laisser pleine en permanence : une
## jauge qui ne bouge jamais apprend au joueur a ne plus la regarder, et il
## aurait cherche sa vie du mauvais cote de l ecran.
##
## Les cartes sont des CardView (nom, effet, rarete) ; on les glisse sur le
## terrain pour viser. Un choix de 3 cartes se superpose au jeu quand il y a lieu.

var game: GameController = null

@onready var _root: Control = $Root
@onready var _speed_btn: Button = %SpeedButton
@onready var _pause_btn: Button = %PauseButton
@onready var _wave_label: Label = %WaveLabel
## La barre de VITESSE, qui est aussi la barre de VIE. Son nom de noeud
## (EnemyBar) est historique : renommer le noeud casserait la scene et toutes
## les captures de reference pour un gain nul.
@onready var _enemy_bar: TextureProgressBar = %EnemyBar
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
## Tout ce que le rail a POSE et qui doit disparaitre a la reconstruction —
## pastilles ET etiquettes. Distincte de `_passive_icons`, qui ne contient que
## les pastilles parce que deux autres fonctions les parcourent en attendant
## un `meta` de carte. Melanger les deux roles faisait chercher ce meta sur une
## etiquette.
var _passive_nodes: Array[Control] = []

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
	# L echange d un quatrieme passif ne se fait plus sur le rail : c est un
	# panneau en pause, ouvert par GameController (PassiveSwapPanel, chantier W8).
	if not RunState.objective_failed.is_connected(_on_objective_failed):
		RunState.objective_failed.connect(_on_objective_failed)
	_refresh_all()


## Les trois labels poses A MEME le champ de bataille (vague, PV, pioche) sont
## ecrits sur un fond PEINT dont la couleur change d un acte a l autre : sur le
## ciel clair de l acte I, un texte clair disparaissait purement et simplement.
## Un contour sombre epais les detache de n importe quel fond, et une taille
## fixee ici evite qu ils heritent d une valeur choisie pour un panneau.
func _style_hud_labels() -> void:
	for l: Label in [_wave_label, _draw_label]:
		l.add_theme_font_override(&"font", UiTheme.font())
		l.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.06, 0.95))
		l.add_theme_constant_override(&"outline_size", 10)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wave_label.add_theme_font_size_override(&"font_size", 32)
	_wave_label.add_theme_color_override(&"font_color", UiTheme.TEXT)


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
		# MODES (chantier M) : le bandeau du monde, en Infini seulement (le
		# spawner du Massacre n emet jamais ce signal).
		if game.spawner != null and not game.spawner.world_changed.is_connected(_on_world_changed):
			game.spawner.world_changed.connect(_on_world_changed)
		_w8_bind(game)
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_gauges()
	_refresh_overtime_countdown()


func _refresh_all() -> void:
	# Le bandeau AVANT les jauges : _refresh_gauges() le met a jour, et bind()
	# vient de fixer le niveau dont il lit les objectifs.
	_build_objective_strip()
	_refresh_gauges()
	_refresh_hand()
	_on_wave_changed(RunState.wave_index)


func _refresh_gauges() -> void:
	# UNE SEULE barre : la vitesse, de 100 % (mort) a 500 % (pleine forme).
	# speed_ratio() est a la fois la position sur l echelle de vitesse et la
	# fraction de vie restante — c est le meme nombre, c est la mecanique.
	var part: float = SpeedGauge.speed_ratio()
	_enemy_bar.value = part * 100.0
	# LA COULEUR PORTE LE DANGER. Une barre qui descend sans changer de teinte
	# se lit comme un compteur ; le joueur doit voir qu il s approche du
	# plancher mortel sans avoir a lire le nombre au milieu d une vague.
	_enemy_bar.tint_progress = _speed_color(part)
	_speed_btn.text = "%d%%" % SpeedGauge.speed_percent
	_speed_btn.add_theme_color_override(&"font_color", _speed_color(part))
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
			cv.modulate = _teinte_carte(cv.card, int(cv.get_meta(&"slot", -1)), en_attente)
			# Le temps REEL suit la vitesse (CardView, en-tete) : n ecrit que
			# s il change au dixieme.
			cv.refresh_cast_time()

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

	# AGONIE : la barre unique s eteint au rythme de la jauge de mort. C est le
	# dernier retour visuel de la partie, il doit etre sur la barre qui reste.
	_enemy_bar.modulate = Color(1, 1, 1, 0.4 + 0.6 * SpeedGauge.death_gauge) 		if SpeedGauge.is_dying else Color.WHITE

	_refresh_passive_rail()
	_refresh_objective_strip()


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
## Pastille d un passif. 54 -> 80 px (audit vague 9, lisibilite telephone) :
## l icone se reconnaissait mal a 42 px utiles. Pas plus : le rail empiete sur
## la voie gauche du terrain, ou descendent les monstres.
const ICONE: float = 80.0
## Zone de TOUCHER d une pastille : un toucher ouvre la fiche du passif. Plus
## grande que la pastille (cible tactile du projet : 90 px au moins) et
## prolongee sur le seuil ecrit a droite, qu on touche aussi naturellement.
const TOUCHE: float = 100.0
const TOUCHE_SEUIL: float = 80.0


func _build_passive_rail() -> void:
	if _passive_rail == null:
		_passive_rail = Control.new()
		_passive_rail.name = "PassiveRail"
		# IGNORE : le rail couvre la zone ou commencent les glissements de carte.
		# Un Control en STOP y avalerait le geste (piege du Button, en memoire).
		_passive_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passive_rail.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(_passive_rail)
	for c in _passive_nodes:
		if is_instance_valid(c):
			c.queue_free()
	_passive_nodes.clear()
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

	# PLACEMENT EN DEUX PASSES, et c est la seule facon correcte.
	#
	# Ma premiere version ecartait les pastilles a la volee, puis re-bornait
	# chacune dans les limites du rail. Avec deux ou trois passifs ca marchait ;
	# a cinq, plusieurs se faisaient pousser au-dela du haut et le bornage les
	# ECRASAIT TOUTES A LA MEME HAUTEUR — deux etiquettes superposees et
	# illisibles, vu sur capture. Corriger apres coup ne peut pas marcher :
	# l espace disponible est une contrainte GLOBALE, pas locale.
	#
	# Passe 1 : la hauteur ideale de chacun, d apres son seuil.
	# Passe 2 : si l ensemble ne tient pas, on repartit REGULIEREMENT sur toute
	# la hauteur du rail. On perd alors la correspondance exacte entre hauteur
	# et seuil, mais le nombre reste ecrit a cote de chaque pastille : mieux
	# vaut un rail lisible et approximatif qu un rail exact et illisible.
	var bas: float = RAIL_BAS - ICONE * 0.7
	var haut: float = RAIL_HAUT + ICONE * 0.5
	var ecart: float = ICONE + UiTheme.FONT_SMALL + 14.0
	var ys: Array[float] = []
	for p: SpellCard in equipes:
		var t: float = clampf(float(p.speed_threshold - 100) / maxf(etendue, 1.0), 0.0, 1.0)
		# Marge d une demi-pastille en haut ET en bas : un passif a 110 % tombait
		# pile sur le bord bas de la barre, derriere le mage et la main, donc
		# invisible — alors que c est justement le passif le plus souvent allume.
		ys.append(clampf(RAIL_BAS - t * (RAIL_BAS - RAIL_HAUT), haut, bas))

	# AUCUN PASSIF EQUIPE : il n y a rien a placer, et la suite lit `ys[size-1]`,
	# donc l indice -1. C est le cas du debut de partie, le plus courant de
	# tous — et il faisait planter l affichage a chaque image.
	if ys.is_empty():
		return

	var place_requise: float = ecart * float(maxi(0, ys.size() - 1))
	if place_requise > bas - haut:
		# Trop de passifs pour la hauteur : repartition reguliere, du bas vers
		# le haut, dans l ordre des seuils (la liste est deja triee).
		var pas: float = (bas - haut) / float(maxi(1, ys.size() - 1))
		for i in ys.size():
			ys[i] = bas - pas * float(i)
	else:
		# Assez de place : on garde la hauteur du seuil et on ne pousse que ce
		# qui se chevauche, vers le HAUT, donc dans le sens du seuil croissant.
		for i in range(1, ys.size()):
			if ys[i - 1] - ys[i] < ecart:
				ys[i] = ys[i - 1] - ecart
		# Si le dernier deborde, on redescend tout le paquet d un bloc plutot
		# que d ecraser les derniers les uns sur les autres.
		if ys[ys.size() - 1] < haut:
			var recul: float = haut - ys[ys.size() - 1]
			for i in ys.size():
				ys[i] = minf(bas, ys[i] + recul)

	for idx in equipes.size():
		var p: SpellCard = equipes[idx]
		var y: float = ys[idx]
		var pastille := Panel.new()
		# IGNORE toujours : le rail ne doit rien avaler du geste de glisser-deposer
		# qui commence souvent a gauche de l ecran. L echange d un passif ne passe
		# plus par lui (PassiveSwapPanel, chantier W8).
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.custom_minimum_size = Vector2(ICONE, ICONE)
		# position AVANT add_child : _ready() part des l ajout.
		pastille.position = Vector2(RAIL_X, y - ICONE * 0.5)
		pastille.size = Vector2(ICONE, ICONE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.11, 0.92)
		sb.set_border_width_all(4)
		sb.border_color = UiTheme.rarity_color(p.rarity)
		# Carre aux coins arrondis et non plus rond : l icone est carree, un cercle
		# en mangeait les coins ou la reduisait a un timbre illisible.
		sb.set_corner_radius_all(int(ICONE * 0.22))
		pastille.add_theme_stylebox_override(&"panel", sb)
		pastille.add_child(_rail_icon(p))

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

		# LE TOUCHER (audit vague 9) : la pastille ne reagissait a rien, le
		# joueur voyait une icone sans pouvoir apprendre ce qu elle fait. Un
		# bouton TRANSPARENT par-dessus, pas la pastille elle-meme : elle reste
		# IGNORE et purement visuelle. Le glisser d une carte n est pas gene :
		# il part de la main et son relachement est pris dans _input(), avant
		# l interface (piege du Button en memoire).
		var toucher := Button.new()
		toucher.name = "PassiveHit_" + String(p.id)
		toucher.flat = true
		toucher.focus_mode = Control.FOCUS_NONE
		toucher.mouse_filter = Control.MOUSE_FILTER_STOP
		toucher.process_mode = Node.PROCESS_MODE_ALWAYS
		var vide := StyleBoxEmpty.new()
		for etat in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			toucher.add_theme_stylebox_override(etat, vide)
		toucher.position = Vector2(RAIL_X + (ICONE - TOUCHE) * 0.5, y - TOUCHE * 0.5)
		toucher.size = Vector2(TOUCHE + TOUCHE_SEUIL, TOUCHE)
		toucher.custom_minimum_size = toucher.size
		toucher.set_meta(&"carte", p)
		toucher.pressed.connect(func() -> void:
			AudioBus.play_sfx(&"ui_tap")
			open_passive_sheet(p))

		_passive_rail.add_child(pastille)
		_passive_rail.add_child(seuil)
		_passive_rail.add_child(toucher)
		_passive_icons.append(pastille)
		_passive_nodes.append(pastille)
		_passive_nodes.append(toucher)
		# L ETIQUETTE AUSSI, sinon elle survit a la reconstruction du rail.
		#
		# Le defaut, vu sur capture : deux "150 %" a l ecran, dont un sans
		# pastille. Le nettoyage ne vidait que `_passive_icons`, ou seules les
		# pastilles etaient inscrites ; les etiquettes, ajoutees au rail mais
		# jamais suivies, s accumulaient a chaque `_build_passive_rail()` — et
		# le rail se reconstruit a chaque gain ou echange de passif. Au bout de
		# quelques vagues, le bord de l ecran se couvre de nombres fantomes que
		# plus rien ne relie a un passif.
		_passive_nodes.append(seuil)


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


## L ICONE du passif dans sa pastille (chantier W8) : la meme image que le menu
## pause et l ecran de deck (CardIcons). L initiale d avant ne distinguait pas
## deux pouvoirs de meme lettre, et elle ne se rapprochait de rien : le joueur
## devait retenir une lettre par pouvoir. Repli sur l initiale si une carte n a
## pas d icone (cas que test_card_icons interdit de livrer).
## `name` fixe : le test du rail cherche l icone sans lire les pixels.
func _rail_icon(p: SpellCard) -> Control:
	var ico: TextureRect = CardIcons.make_rect(p, ICONE - 12.0)
	if ico != null:
		ico.name = "Icone"
		ico.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ico.offset_left = 6.0
		ico.offset_top = 6.0
		ico.offset_right = -6.0
		ico.offset_bottom = -6.0
		return ico
	var lettre := Label.new()
	lettre.name = "Initiale"
	lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lettre.text = p.display_name.substr(0, 1).to_upper()
	lettre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lettre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lettre.set_anchors_preset(Control.PRESET_FULL_RECT)
	lettre.add_theme_font_override(&"font", UiTheme.font())
	lettre.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	lettre.add_theme_color_override(&"font_color", UiTheme.rarity_color(p.rarity))
	return lettre


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
	for slot in n:
		var card: SpellCard = RunState.hand[slot]
		var cv := CardView.new()
		cv.setup_hand(card, width, 230.0)
		# La POSITION suit la carte : deux copies d une meme carte sont la meme
		# ressource, seule leur place dans la main dit laquelle est gelee.
		cv.set_meta(&"slot", slot)
		cv.gui_input.connect(_on_card_input.bind(card, slot))
		_hand.add_child(cv)
		_ajouter_jauge_amelioration(cv, card, width)
		_marquer_si_petrifiee(cv, card, slot)
		_marquer_si_sommeil(cv, card, slot)


## Une carte PETRIFIEE par le regard d une gorgone doit SE VOIR.
##
## Le moteur refuse deja de la jouer (`RunState.play_card`), et les tests le
## prouvent — mais le joueur, lui, voyait six cartes identiques et appuyait dans
## le vide sans comprendre pourquoi rien ne partait. Une regle qu on subit sans
## la voir se lit comme un bug, pas comme un adversaire.
##
## GRISEE ET PLUS PALE, pas seulement teintee : a 118 px de large dans une main
## pleine, une nuance de couleur ne se distingue pas. La carte doit sortir du
## rang par sa LUMINOSITE, ce qui se voit du coin de l oeil pendant qu on joue.
## Teinte d une carte de la main, recalculee a CHAQUE image par _refresh_gauges.
##
## LE DEFAUT QUE CECI REPARE, vu en capture : la boucle du sort prepare remettait
## toutes les cartes a blanc a chaque image, ce qui effacait aussitot le gris de
## la petrification et celui du sommeil poses par _refresh_hand. Le mot restait,
## la couleur disparaissait — et c est la couleur qui se voit du coin de l oeil.
## La teinte depend donc de l ETAT de la carte, pas de l ordre des appels.
const TEINTE_BLOQUEE := Color(0.46, 0.46, 0.56, 0.85)
const TEINTE_VOLEE := Color(0.62, 0.40, 0.40, 0.85)
const TEINTE_SOMMEIL := Color(0.46, 0.48, 0.60, 0.85)
const TEINTE_PREPAREE := Color(1.0, 0.92, 0.6)


## Le bandeau (le MOT) est un enfant de la carte, donc il herite de son gris et
## perdait la moitie de son contraste. On lui applique l inverse de la teinte :
## la carte s eteint, le mot reste a pleine lumiere.
static func _contre_teinte(t: Color) -> Color:
	return Color(1.0 / maxf(t.r, 0.05), 1.0 / maxf(t.g, 0.05), 1.0 / maxf(t.b, 0.05),
		1.0 / maxf(t.a, 0.05))


func _teinte_carte(card: SpellCard, slot: int, en_attente: SpellCard) -> Color:
	# La carte VOLEE est aussi "bloquee" pour RunState : on la teste d abord,
	# sinon cette boucle, qui tourne a chaque image, repeindrait son rouge en gris.
	# Par EXEMPLAIRE (slot) et non par carte : demander par ressource grisait
	# toutes les copies d une carte dont une seule etait gelee.
	if card != null and RunState.is_slot_stolen(slot):
		return TEINTE_VOLEE
	if card != null and RunState.is_slot_blocked(slot):
		return TEINTE_BLOQUEE
	if RunState.is_silenced():
		return TEINTE_SOMMEIL
	if en_attente != null and card == en_attente:
		return TEINTE_PREPAREE
	return Color.WHITE


func _marquer_si_petrifiee(cv: Control, card: SpellCard, slot: int) -> void:
	if card == null or not RunState.is_slot_blocked(slot):
		return
	# VOLEE par un voleur de sorts : meme gel, autre mot et teinte chaude. Le
	# joueur doit distinguer la carte qui revient quand la gorgone tombe de celle
	# qui va lui etre LANCEE dessus s il ne tue pas le voleur a temps.
	var volee: bool = RunState.is_slot_stolen(slot)
	cv.modulate = TEINTE_VOLEE if volee else TEINTE_BLOQUEE
	# Le mot en clair par-dessus : la couleur dit "quelque chose ne va pas",
	# le mot dit QUOI. Un joueur daltonien ne lit que le mot.
	var bandeau := Label.new()
	# Nomme pour que le smoke puisse compter les cartes marquees sans lire le texte.
	bandeau.name = "Volee" if volee else "Petrifiee"
	bandeau.text = "VOLEE" if volee else "PETRIFIEE"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandeau.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bandeau.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Meme correctif que le bandeau du sommeil (voir _marquer_si_sommeil) : sans
	# `clip_text`, le mot elargit la carte et la main pleine deborde de l ecran.
	bandeau.clip_text = true
	bandeau.add_theme_font_override(&"font", UiTheme.font())
	bandeau.add_theme_font_size_override(&"font_size", int(UiTheme.FONT_SMALL * 0.8))
	bandeau.add_theme_color_override(&"font_color", Color(0.94, 0.92, 0.98))
	bandeau.add_theme_color_override(&"font_outline_color", Color(0.10, 0.08, 0.16))
	bandeau.add_theme_constant_override(&"outline_size", 10)
	bandeau.modulate = _contre_teinte(TEINTE_VOLEE if volee else TEINTE_BLOQUEE)
	cv.add_child(bandeau)


## SOMMEIL (comportements v3) : un dormeur sur le terrain coupe TOUTE la magie.
## Meme traitement que la petrification — grisee, plus pale, le mot en clair —
## parce que c est la meme experience pour le joueur : des cartes qui refusent
## de partir. Le mot est different parce que la reponse l est : ici on ne tue
## pas une gorgone, on tue le monstre qui porte les Zzz.
##
## Une carte deja petrifiee garde son propre mot : elle restera bloquee APRES le
## reveil, et le joueur doit le savoir avant.
func _marquer_si_sommeil(cv: Control, card: SpellCard, slot: int) -> void:
	if card == null or not RunState.is_silenced() or RunState.is_slot_blocked(slot):
		return
	cv.modulate = TEINTE_SOMMEIL
	var bandeau := Label.new()
	bandeau.name = "Sommeil"
	bandeau.text = "Zzz\nSOMMEIL"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandeau.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bandeau.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CardView est un PanelContainer : tout enfant entre dans le calcul de sa
	# taille MINIMALE. Vu en capture au premier jet — le mot, plus large qu une
	# carte de main pleine, elargissait les six cartes et la main debordait de
	# l ecran des deux cotes. `clip_text` retire le texte de ce calcul, et la
	# police a 80 % du petit corps fait tenir le mot dans une carte de 118 px.
	bandeau.clip_text = true
	bandeau.add_theme_font_override(&"font", UiTheme.font())
	bandeau.add_theme_font_size_override(&"font_size", int(UiTheme.FONT_SMALL * 0.8))
	bandeau.add_theme_color_override(&"font_color", Color(0.86, 0.90, 1.0))
	bandeau.add_theme_color_override(&"font_outline_color", Color(0.08, 0.08, 0.18))
	bandeau.add_theme_constant_override(&"outline_size", 10)
	bandeau.modulate = _contre_teinte(TEINTE_SOMMEIL)
	cv.add_child(bandeau)


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
func _on_card_input(event: InputEvent, card: SpellCard, slot: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		# L exemplaire TOUCHE est gele : on refuse ici, avant le moteur. Le moteur
		# ne recoit que la carte et lancerait une copie libre de la meme carte —
		# le joueur verrait partir une carte qu il n a pas touchee.
		if RunState.is_slot_blocked(slot):
			return
		# CHANTIER W8 : une carte BRULEE attend d etre visee, la partie est en
		# pause ; la main ne repond pas tant qu elle n est pas partie.
		if RunState.burned_card != null:
			return
		if _needs_aim(card):
			_begin_drag(card, mb.global_position)
		else:
			_play(card, Vector2.INF)


func _begin_drag(card: SpellCard, screen_pos: Vector2) -> void:
	_dragging = card
	var point: Vector2 = _battlefield_point(screen_pos)
	_aim.show_aim(card, point, _is_valid_aim(point, card))


## Recoit TOUS les evenements, y compris ceux que les cartes consomment ensuite.
func _input(event: InputEvent) -> void:
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = _battlefield_point((event as InputEventMouseMotion).global_position)
		_aim.show_aim(_dragging, point, _is_valid_aim(point, _dragging))
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
	# CHANTIER W8 : la carte glissee est la carte BRULEE, pas une carte de main.
	# Meme geste, meme apercu, mais elle part sans incantation (cast_burned).
	if _dragging_burned:
		_dragging_burned = false
		if _is_valid_aim(point, card) and game != null:
			game.cast_burned(point)
		return
	if _is_valid_aim(point, card):
		_play(card, point)
	# Visee hors terrain : la carte reste en main, le geste est simplement annule.


## La zone jouable exclut la main de cartes et la barre du haut. Un objet qui
## BLOQUE (mur, riviere) est aussi refuse la ou il couperait tout chemin des
## monstres : l apercu passe au rouge et la carte reste en main.
func _is_valid_aim(point: Vector2, card: SpellCard = null) -> bool:
	var dans_le_terrain: bool = point.y > 160.0 and point.y < GameConfig.MAGE_LINE_Y \
		and point.x > 0.0 and point.x < GameConfig.BATTLEFIELD_WIDTH
	if not dans_le_terrain or card == null or game == null:
		return dans_le_terrain
	return game.aim_allowed(card, point)


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
	# Un nouvel ecran repart TOUJOURS desarme : un mode bruler reste arme d une
	# montee a l autre brulerait la carte que le joueur voulait prendre.
	_burn_armed = false
	_choice_views.clear()
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
		_choice_views.append(cv)
	_w8_choice_actions(box)
	_choice.visible = true


## Armement du mode bruler : le joueur clique le bouton, puis la carte.
var _burn_armed: bool = false
## Les cartes de l ecran de choix, dans l ordre de l offre (pour les griser quand
## le mode bruler est arme : un passif ne se brule pas, chantier W8).
var _choice_views: Array[CardView] = []


func _pick(i: int) -> void:
	if game == null:
		return
	if _burn_armed:
		# UN PASSIF NE SE BRULE PAS (RunState.burn_offer le refuse) : l ecran
		# reste ouvert et arme, le joueur touche un sort ou desarme.
		if i < 0 or i >= RunState.pending_offer.size() \
				or not RunState.can_burn(RunState.pending_offer[i]):
			AudioBus.play_sfx(&"ui_tap")
			return
		AudioBus.play_sfx(&"card_pick")
		_burn_armed = false
		_choice.visible = false
		game.burn_card(i)
		return
	AudioBus.play_sfx(&"card_pick")
	_choice.visible = false
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
##
## Depuis la vague 8 c est un ecran A ONGLETS (MAIN / DECK / VAGUE) qui vit dans
## son propre fichier, scripts/ui/pause_panel.gd. Le HUD ne fait plus que le
## poser et brancher ses deux sorties.
var _pause_panel: Control = null


## FICHE D UN PASSIF, ouverte en touchant sa pastille du rail (audit vague 9).
## Elle vit dans la PAUSE (onglet MAIN) : lire un texte demande d arreter le
## temps, et REPRENDRE / RETOUR y sont deja sous le pouce. Si la pause est deja
## ouverte, on y montre simplement la fiche.
func open_passive_sheet(p: SpellCard) -> void:
	if p == null:
		return
	var tree: SceneTree = get_tree()
	if not tree.paused:
		tree.paused = true
		_pause_btn.text = ">"
	if _pause_panel == null or not is_instance_valid(_pause_panel):
		_show_pause_panel()
	(_pause_panel as PausePanel).open_passive(p)


func _show_pause_panel() -> void:
	if _pause_panel != null:
		_pause_panel.queue_free()
	var panneau := PausePanel.new(game)
	panneau.resume_requested.connect(_on_pause_pressed)
	panneau.quit_requested.connect(_on_quit_pressed)
	_pause_panel = panneau
	_root.add_child(_pause_panel)


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


func _on_multiplier_changed(_old: int, _new: int) -> void:
	_refresh_gauges()


## Teinte de la barre selon ce qu il reste : or en pleine forme, orange a
## mi-course, rouge pres du plancher. Les seuils sont des FRACTIONS de la
## reserve, jamais des pourcentages en dur : SPEED_MAX_PERCENT peut bouger.
func _speed_color(part: float) -> Color:
	if part <= 0.25:
		return UiTheme.RED.lightened(0.25)
	if part <= 0.5:
		return Color(0.95, 0.5, 0.3)
	return UiTheme.GOLD


func _on_wave_changed(index: int) -> void:
	var total: int = 0
	if RunState.current_level_def != null and RunState.mode == GameEnums.Mode.EXPLORATION:
		total = RunState.current_level_def.waves.size()
	if total > 0:
		_wave_label.text = "Vague %d/%d   Niv.%d" % [mini(index + 1, total), total, RunState.level]
	else:
		_wave_label.text = "Vague %d   Niv.%d" % [index + 1, RunState.level]


# --- Objectifs du niveau, suivis EN COMBAT ---
#
# Le moteur d objectifs jugeait tout a l ecran de victoire : le joueur visait
# « 30 fois le meme sort » sans savoir s il en etait a 12 ou a 29, et apprenait
# qu il avait perdu « sans subir de degats » bien apres le coup qui l avait
# ruine. Le bandeau dit deux choses et rien d autre :
#   - OU il en est, pour ce qui se compte   ("Meme sort  12/30") ;
#   - QUAND c est perdu, pour tout objectif ("Sans degats : rate").
# Une interdiction encore tenue n affiche rien : « Sans degats » ecrit en
# permanence serait une ligne de plus que l oeil apprend a ignorer.
#
# EN BAS A DROITE, entre la tour du mage et le bord, juste au-dessus du compte a
# rebours de pioche. Il etait en haut a droite, sous le bouton pause : c est la
# que naissent les monstres (GameConfig.SPAWN_LINE_Y), et le texte cachait les
# premieres secondes de chaque vague. En bas, les monstres ont fini leur
# course (ils frappent en atteignant MAGE_LINE_Y) ; a gauche courent la jauge et
# le rail des passifs, dessous la main et la barre d incantation. C est le seul
# coin que rien de tout cela n occupe.
#
# Le bandeau pousse VERS LE HAUT et VERS LA GAUCHE depuis son coin (ancre en bas
# a droite, croissance inversee) : une ligne de plus ne descend jamais sur la
# pioche, un libelle plus long ne sort jamais de l ecran.
#
# UN FOND, desormais. Sans fond, texte + contour ne tenaient pas 4,5:1 sur les
# tons moyens des fonds peints (2,8:1 mesure sur l acte II : ni le remplissage
# ni le contour ne se detachent d une herbe grise). Une plaque sombre sous le
# texte, a la taille des lignes, regle le contraste pour les cinq actes ; elle
# ne couvre que la fin de course a droite de la tour, et laisse passer le doigt.
#
# Police : FONT_SMALL, le plancher du theme — rien en dessous, c est la plainte
# du testeur sur les polices. Un objectif deja acquis dans une partie precedente
# n est pas repete : il n y a plus rien a y gagner.

const OBJ_MARGIN: float = 24.0
## Ecart entre le bas du bandeau et le haut du compte a rebours de pioche.
const OBJ_GAP: float = 6.0
const OBJ_ECHEC := Color(1.0, 0.48, 0.42)
## Plaque sous le texte. L alpha est ce qui tient le contraste : le test du
## bandeau le mesure sur les fonds des cinq actes.
const OBJ_PLAQUE := Color(0.05, 0.04, 0.08, 0.8)

## La plaque (PanelContainer) ; c est elle qui est ancree et qui grandit.
var _obj_panel: PanelContainer = null
var _obj_box: VBoxContainer = null
## ObjectiveDef -> Label, dans l ordre du niveau.
var _obj_lines: Dictionary = {}


func _build_objective_strip() -> void:
	if _obj_panel != null and is_instance_valid(_obj_panel):
		_obj_panel.queue_free()
	_obj_panel = null
	_obj_box = null
	_obj_lines.clear()
	var lvl: LevelDef = RunState.current_level_def
	if lvl == null or RunState.mode != GameEnums.Mode.EXPLORATION or lvl.objectives.is_empty():
		return
	_obj_panel = PanelContainer.new()
	_obj_panel.name = "ObjectiveStrip"
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = OBJ_PLAQUE
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_obj_panel.add_theme_stylebox_override(&"panel", sb)
	# Coin bas-droit, sur le compte a rebours de pioche : on lit sa position dans
	# la scene plutot que de la recopier, pour que les deux ne divergent pas.
	_obj_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_obj_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_obj_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bas: float = _draw_label.offset_top - OBJ_GAP
	_obj_panel.offset_right = -OBJ_MARGIN
	_obj_panel.offset_left = -OBJ_MARGIN
	_obj_panel.offset_bottom = bas
	_obj_panel.offset_top = bas
	_obj_panel.visible = false
	_root.add_child(_obj_panel)
	_obj_box = VBoxContainer.new()
	_obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_box.add_theme_constant_override(&"separation", 2)
	_obj_panel.add_child(_obj_box)
	for o: ObjectiveDef in lvl.objectives:
		if o == null or SaveData.is_objective_done(lvl.id, o.id):
			continue
		var l: Label = UiTheme.label_hud("", UiTheme.FONT_SMALL, UiTheme.TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		_obj_box.add_child(l)
		_obj_lines[o] = l


## Emprise du bandeau a l ecran, recalculee sur ses lignes ACTUELLES. Le
## conteneur ne se redimensionne qu a l image suivante ; on force le calcul pour
## que la reponse soit juste tout de suite (le test la lit sans attendre).
func objective_strip_rect() -> Rect2:
	if _obj_panel == null or not is_instance_valid(_obj_panel):
		return Rect2()
	_obj_panel.reset_size()
	return _obj_panel.get_global_rect()


func _refresh_objective_strip() -> void:
	for o: ObjectiveDef in _obj_lines:
		var l: Label = _obj_lines[o]
		if l == null or not is_instance_valid(l):
			continue
		var texte: String = ""
		var couleur: Color = UiTheme.TEXT
		if RunState.is_objective_failed(o.id):
			texte = objective_line_text(o, true, {})
			couleur = OBJ_ECHEC
		else:
			var p: Dictionary = ObjectiveChecker.progress(o)
			if not p.is_empty():
				texte = objective_line_text(o, false, p)
				# Un compte qui a atteint sa cible passe a l or : l etoile est a
				# portee, il reste a gagner. (Un plafond atteint, lui, reste neutre :
				# max_distinct_cast pile a la limite n est pas un succes, c est un
				# avertissement.)
				if o.check_key != &"max_distinct_cast" and float(p["current"]) >= float(p["target"]):
					couleur = UiTheme.GOLD
		l.visible = texte != ""
		if l.text != texte:
			l.text = texte
		l.add_theme_color_override(&"font_color", couleur)
	# La plaque n existe que s il y a quelque chose a lire : une plaque vide au
	# coin de l ecran serait un bouton qui ne fait rien.
	if _obj_panel != null and is_instance_valid(_obj_panel):
		var une: bool = false
		for o: ObjectiveDef in _obj_lines:
			var l: Label = _obj_lines[o]
			if l != null and is_instance_valid(l) and l.visible:
				une = true
				break
		if _obj_panel.visible != une:
			_obj_panel.visible = une


## Le texte d une ligne : « <libelle> : rate » si l objectif est perdu,
## « <libelle>  <compte> » s il se compte, vide sinon. Seul endroit ou ce texte
## s ecrit : le test d emprise du bandeau mesure les memes chaines que l ecran.
static func objective_line_text(o: ObjectiveDef, failed: bool, p: Dictionary) -> String:
	if failed:
		return "%s : rate" % ObjectiveChecker.short_label(o)
	if p.is_empty():
		return ""
	return "%s  %s" % [ObjectiveChecker.short_label(o), _obj_count(p)]


## "12/30", ou "1:23 / 3:00" pour un chrono.
static func _obj_count(p: Dictionary) -> String:
	if bool(p.get("time", false)):
		return "%s / %s" % [_mmss(float(p["current"])), _mmss(float(p["target"]))]
	return "%d/%d" % [int(p["current"]), int(p["target"])]


static func _mmss(sec: float) -> String:
	var t: int = int(floor(maxf(sec, 0.0)))
	return "%d:%02d" % [t / 60, t % 60]


## L objectif vient d etre perdu : la ligne passe au rouge (par le rafraichissement)
## et BAT une fois. Un texte qui change de couleur en haut de l ecran pendant une
## vague ne se remarque pas ; un battement, si. Un seul, et bref : c est une
## information, pas une alarme qui detournerait le regard des monstres.
func _on_objective_failed(objective_id: StringName) -> void:
	_refresh_objective_strip()
	for o: ObjectiveDef in _obj_lines:
		if o.id != objective_id:
			continue
		var l: Label = _obj_lines[o]
		if l == null or not is_instance_valid(l):
			return
		# Par la LUMINOSITE et non par l echelle : la ligne vit dans un
		# VBoxContainer, qui remet l echelle de ses enfants a 1 a chaque tri.
		var tw: Tween = l.create_tween()
		for i in 2:
			tw.tween_property(l, "modulate", Color(2.2, 2.0, 2.0), 0.12)
			tw.tween_property(l, "modulate", Color.WHITE, 0.28)
		return


# --- Bandeau de MONDE, mode Infini (chantier M) ---
#
# Le fond changeait toutes les six vagues et rien ne disait OU l on etait : le
# joueur voyait un cimetiere apparaitre sans savoir que les morts-vivants allaient
# peser sur le tirage. Le bandeau nomme le lieu au moment ou il change, puis
# s efface : c est une annonce, pas un panneau permanent qui mangerait le terrain.
#
# Pose au TIERS HAUT du terrain, sous la barre du haut : la zone du pouce (main,
# XP) reste libre, et il ne couvre pas la ligne du mage ou se joue le danger.
# Il laisse passer le doigt (MOUSE_FILTER_IGNORE) : un glisser de carte qui
# passerait dessus ne doit pas etre avale.

## Duree de l annonce, fondus compris. Assez pour lire deux lignes, assez court
## pour ne pas masquer les premiers monstres du nouveau lieu.
const WORLD_BANNER_SECONDS: float = 2.6
const WORLD_BANNER_Y: float = 380.0

var _world_banner: PanelContainer = null
var _world_title: Label = null
var _world_sub: Label = null
var _world_tween: Tween = null


func _on_world_changed(world_index: int, _backdrop_key: String, world_name: String) -> void:
	# Le spawner a DEJA avance son index sur la vague qui s ouvre.
	var vague: int = game.spawner.index + 1 if game != null and game.spawner != null else 1
	show_world_banner(world_name, world_subtitle(world_index, WaveBudget.cycle_for(vague)))


## Deuxieme ligne du bandeau : le rang du monde, et le TOUR quand on repasse par
## un lieu deja vu — c est la seule chose qui distingue le deuxieme cimetiere du
## premier, alors que ses monstres ont trois fois plus de points.
static func world_subtitle(world_index: int, cycle: int) -> String:
	var t: String = "Monde %d / %d" % [world_index + 1, WaveBudget.WORLDS.size()]
	if cycle > 1:
		t += "   -   tour %d" % cycle
	return t


func show_world_banner(title: String, subtitle: String) -> void:
	if title.is_empty():
		return
	_ensure_world_banner()
	_world_title.text = title
	_world_sub.text = subtitle
	_world_banner.visible = true
	_world_banner.modulate = Color(1, 1, 1, 0)
	if _world_tween != null and _world_tween.is_valid():
		_world_tween.kill()
	var tw: Tween = _world_banner.create_tween()
	tw.tween_property(_world_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(WORLD_BANNER_SECONDS - 0.75)
	tw.tween_property(_world_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _world_banner.visible = false)
	_world_tween = tw


func hide_world_banner() -> void:
	if _world_tween != null and _world_tween.is_valid():
		_world_tween.kill()
	if _world_banner != null and is_instance_valid(_world_banner):
		_world_banner.visible = false


## Pour les tests et le SMOKE : le texte affiche, "" si le bandeau est cache.
func world_banner_text() -> String:
	if _world_banner == null or not _world_banner.visible:
		return ""
	return _world_title.text


func _ensure_world_banner() -> void:
	if _world_banner != null and is_instance_valid(_world_banner):
		return
	_world_banner = PanelContainer.new()
	_world_banner.name = "WorldBanner"
	_world_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Aplat SOMBRE sous le texte : les cinq fonds vont du ciel clair au rouge
	# demoniaque, un texte pose a nu y serait illisible sur l un ou l autre.
	_world_banner.add_theme_stylebox_override(&"panel",
		UiTheme.flat_box(Color(UiTheme.BG, 0.82), 18, 22.0))
	_world_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_world_banner.anchor_left = 0.08
	_world_banner.anchor_right = 0.92
	_world_banner.offset_left = 0.0
	_world_banner.offset_right = 0.0
	_world_banner.offset_top = WORLD_BANNER_Y
	_world_banner.offset_bottom = WORLD_BANNER_Y
	_world_banner.visible = false
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 6)
	_world_banner.add_child(col)
	_world_title = UiTheme.label_hud("", UiTheme.FONT_TITLE, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)
	_world_sub = UiTheme.label_hud("", UiTheme.FONT_BODY, UiTheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_world_title)
	col.add_child(_world_sub)
	_root.add_child(_world_banner)


# =====================================================================
# CHANTIER W8 — montee de niveau (BRULER vise, MEDITER) et vague qui traine.
# Section a part : chaque accroche ailleurs dans ce fichier est une ligne qui
# appelle une fonction d ici (bind, _show_choice, _end_drag).
# =====================================================================

const CHOICE_HINT := "Bruler : la carte part tout de suite, la ou tu la vises, sans entrer dans ton deck.\nMediter : aucune carte, +%d XP a chaque carte de ta main."
const CHOICE_HINT_ARMED := "Touche le sort a bruler. Un pouvoir ne se brule pas."
## Teinte des cartes que le mode bruler ne peut pas prendre (les pouvoirs).
const TEINTE_NON_BRULABLE := Color(0.45, 0.45, 0.52, 0.75)

## Vrai si le glisser en cours est celui de la carte BRULEE (voir _end_drag).
var _dragging_burned: bool = false
## Le plateau qui presente la carte brulee a viser. Null hors visee.
var _burn_tray: Control = null


func _w8_bind(g: GameController) -> void:
	if g == null:
		return
	if not g.burn_aim_requested.is_connected(_on_burn_aim_requested):
		g.burn_aim_requested.connect(_on_burn_aim_requested)
	if not g.burn_resolved.is_connected(_on_burn_resolved):
		g.burn_resolved.connect(_on_burn_resolved)
	if g.spawner != null and not g.spawner.wave_overtime.is_connected(_on_wave_overtime):
		g.spawner.wave_overtime.connect(_on_wave_overtime)


## BRULER et MEDITER, sous les trois cartes de l ecran de choix. Deux boutons cote
## a cote, chacun de 96 px de haut (cible tactile), et UNE phrase d aide qui dit
## ce que fait chacun — puis, une fois bruler arme, ce que le joueur doit toucher.
##
## Sous les cartes et non plus au-dessus : le geste principal (prendre une carte)
## reste le premier que l oeil rencontre, les deux alternatives se lisent apres.
func _w8_choice_actions(box: VBoxContainer) -> void:
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override(&"separation", 24)
	box.add_child(actions)
	var bruler := Button.new()
	bruler.name = "Bruler"
	bruler.text = "BRULER"
	bruler.toggle_mode = true
	bruler.custom_minimum_size = Vector2(0, 96)
	bruler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(bruler)
	var mediter := Button.new()
	mediter.name = "Mediter"
	mediter.text = "MEDITER"
	mediter.custom_minimum_size = Vector2(0, 96)
	mediter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(mediter)
	var aide: Label = UiTheme.label(CHOICE_HINT % GameConfig.MEDITATE_CARD_XP,
		UiTheme.FONT_SMALL, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	aide.name = "Aide"
	box.add_child(aide)
	bruler.toggled.connect(func(on: bool) -> void:
		_burn_armed = on
		bruler.text = "ANNULER" if on else "BRULER"
		aide.text = CHOICE_HINT_ARMED if on else CHOICE_HINT % GameConfig.MEDITATE_CARD_XP
		_shade_unburnable(on))
	mediter.pressed.connect(_on_meditate_pressed)


## Mode bruler arme : les POUVOIRS de l offre se grisent. Le joueur voit avant de
## toucher qu ils ne se brulent pas, au lieu de toucher et de ne rien voir partir.
func _shade_unburnable(armed: bool) -> void:
	for cv in _choice_views:
		if not is_instance_valid(cv):
			continue
		cv.modulate = TEINTE_NON_BRULABLE if armed and not RunState.can_burn(cv.card) \
			else Color.WHITE


func _on_meditate_pressed() -> void:
	if game == null:
		return
	AudioBus.play_sfx(&"level_up")
	_burn_armed = false
	_choice.visible = false
	game.meditate()
	# Le lisere de progression des cartes en main vient de bouger : on le redessine.
	_refresh_hand()


## La carte brulee attend d etre visee : on la pose AU-DESSUS de la main, avec ce
## qu elle attend du joueur. Le geste est celui de la main — appuyer sur la carte,
## glisser, relacher — avec le meme apercu de visee (AimOverlay).
func _on_burn_aim_requested(card: SpellCard) -> void:
	_hide_burn_tray()
	if card == null:
		return
	var tray := VBoxContainer.new()
	tray.name = "BurnTray"
	tray.add_theme_constant_override(&"separation", 10)
	tray.custom_minimum_size = Vector2(BURN_TRAY_WIDTH, 0.0)
	# position AVANT add_child : _ready() part des l ajout.
	tray.position = Vector2((GameConfig.BATTLEFIELD_WIDTH - BURN_TRAY_WIDTH) * 0.5, BURN_TRAY_Y)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titre: Label = UiTheme.label_hud("BRULEE : glisse-la sur le terrain",
		UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	titre.name = "Consigne"
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(titre)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(centre)
	var cv := CardView.new()
	cv.name = "CarteBrulee"
	# `instant` : la carte brulee part SANS incantation (cast_burned) ; elle dit
	# « instantane » au lieu d un temps d incantation qu elle ne subira pas.
	cv.setup_hand(card, 200.0, 230.0, true)
	cv.gui_input.connect(_on_burn_card_input.bind(card))
	centre.add_child(cv)
	_root.add_child(tray)
	_burn_tray = tray


## Le plateau de la carte brulee : centre, juste au-dessus de la tour du mage,
## la ou le pouce part deja pour jouer une carte de la main.
const BURN_TRAY_WIDTH: float = 760.0
const BURN_TRAY_Y: float = 1080.0


func _on_burn_card_input(event: InputEvent, card: SpellCard) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if RunState.burned_card != card:
		return
	_dragging_burned = true
	_begin_drag(card, mb.global_position)


func _on_burn_resolved(_card: SpellCard) -> void:
	_hide_burn_tray()


func _hide_burn_tray() -> void:
	if _burn_tray != null and is_instance_valid(_burn_tray):
		_burn_tray.queue_free()
	_burn_tray = null


## Pour les tests : la carte que le plateau presente, null hors visee.
func burn_tray_card() -> SpellCard:
	if _burn_tray == null or not is_instance_valid(_burn_tray):
		return null
	var cv: CardView = _burn_tray.find_child("CarteBrulee", true, false) as CardView
	return cv.card if cv != null else null


# --- La vague suivante arrive alors que des monstres restent ---
#
# Sans annonce, le joueur voit une nouvelle vague tomber sur les restants de la
# precedente et croit a un bug du compteur (« j avais pas fini »). Un bandeau
# BREF, sous celui du monde (les deux peuvent tomber ensemble en Infini), qui
# laisse passer le doigt et s efface seul.

const OVERTIME_BANNER_SECONDS: float = 2.4
const OVERTIME_BANNER_Y: float = 600.0

var _overtime_banner: PanelContainer = null
var _overtime_title: Label = null
var _overtime_tween: Tween = null


func _on_wave_overtime(_index: int) -> void:
	show_overtime_banner()


func show_overtime_banner() -> void:
	_ensure_overtime_banner()
	_overtime_banner.visible = true
	_overtime_banner.modulate = Color(1, 1, 1, 0)
	if _overtime_tween != null and _overtime_tween.is_valid():
		_overtime_tween.kill()
	var tw: Tween = _overtime_banner.create_tween()
	tw.tween_property(_overtime_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(OVERTIME_BANNER_SECONDS - 0.6)
	tw.tween_property(_overtime_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _overtime_banner.visible = false)
	_overtime_tween = tw


## Pour les tests et le SMOKE : le titre affiche, "" si le bandeau est cache.
func overtime_banner_text() -> String:
	if _overtime_banner == null or not _overtime_banner.visible:
		return ""
	return _overtime_title.text


func _ensure_overtime_banner() -> void:
	if _overtime_banner != null and is_instance_valid(_overtime_banner):
		return
	_overtime_banner = PanelContainer.new()
	_overtime_banner.name = "OvertimeBanner"
	_overtime_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Meme aplat sombre que le bandeau de monde, pour la meme raison : les cinq
	# fonds vont du ciel clair au rouge, un texte nu y serait illisible.
	_overtime_banner.add_theme_stylebox_override(&"panel",
		UiTheme.flat_box(Color(UiTheme.BG, 0.82), 18, 16.0))
	_overtime_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_overtime_banner.anchor_left = 0.12
	_overtime_banner.anchor_right = 0.88
	_overtime_banner.offset_left = 0.0
	_overtime_banner.offset_right = 0.0
	_overtime_banner.offset_top = OVERTIME_BANNER_Y
	_overtime_banner.offset_bottom = OVERTIME_BANNER_Y
	_overtime_banner.visible = false
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)
	_overtime_banner.add_child(col)
	_overtime_title = UiTheme.label_hud("LA VAGUE SUIVANTE ARRIVE", UiTheme.FONT_BODY,
		UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var sous: Label = UiTheme.label_hud("Les monstres restants restent en jeu",
		UiTheme.FONT_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_overtime_title)
	col.add_child(sous)
	_root.add_child(_overtime_banner)


# --- Compte a rebours de la vague qui TRAINE (vague 9) ---
#
# WaveSpawner.overtime_left() savait depuis la vague 8 quand la vague suivante
# allait tomber sur les restants, mais aucun ecran ne le disait : le joueur ne
# voyait que le bandeau, au moment ou il etait trop tard. Un petit compte a
# rebours sous le compteur de vagues, SEULEMENT pendant les dernieres secondes
# (au-dela, ce serait un chiffre de plus a ignorer), en secondes REELLES : a x4
# le delai de monde fond quatre fois plus vite, et c est ce que le joueur vit.

## Le compte a rebours apparait sous ce nombre de secondes reelles.
const OVERTIME_COUNTDOWN_SECONDS: float = 10.0
const OVERTIME_COUNTDOWN_Y: float = 146.0

var _overtime_countdown: Label = null


## Secondes REELLES avant que la vague en cours cede la place, -1 si elle ne le
## fera pas (apparitions pas finies, vague de boss, derniere vague, pas de partie).
func overtime_seconds_left() -> float:
	if game == null or not is_instance_valid(game) or game.spawner == null:
		return -1.0
	var monde: float = game.spawner.overtime_left()
	if monde < 0.0:
		return -1.0
	# world_delta(1 s) : secondes de monde par seconde reelle, agonie comprise.
	return monde / maxf(SpeedGauge.world_delta(1.0), 0.01)


## Pour les tests et le SMOKE : le texte affiche, "" si le compte est cache.
func overtime_countdown_text() -> String:
	if _overtime_countdown == null or not _overtime_countdown.visible:
		return ""
	return _overtime_countdown.text


func _refresh_overtime_countdown() -> void:
	var reste: float = overtime_seconds_left()
	var montrer: bool = reste > 0.0 and reste <= OVERTIME_COUNTDOWN_SECONDS
	if not montrer:
		if _overtime_countdown != null and is_instance_valid(_overtime_countdown):
			_overtime_countdown.visible = false
		return
	_ensure_overtime_countdown()
	_overtime_countdown.visible = true
	_overtime_countdown.text = "Vague suivante dans %d s" % int(ceilf(reste))
	# Les trois dernieres secondes virent au rouge : le joueur lit l urgence
	# sans avoir a lire le chiffre.
	_overtime_countdown.add_theme_color_override(&"font_color",
		UiTheme.RED.lightened(0.25) if reste <= 3.0 else UiTheme.GOLD)


func _ensure_overtime_countdown() -> void:
	if _overtime_countdown != null and is_instance_valid(_overtime_countdown):
		return
	_overtime_countdown = UiTheme.label_hud("", UiTheme.FONT_SMALL, UiTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)
	_overtime_countdown.name = "OvertimeCountdown"
	# Laisse passer le doigt : il est pose au-dessus du terrain, la ou l on vise.
	_overtime_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overtime_countdown.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_overtime_countdown.anchor_left = 0.2
	_overtime_countdown.anchor_right = 0.8
	_overtime_countdown.offset_left = 0.0
	_overtime_countdown.offset_right = 0.0
	_overtime_countdown.offset_top = OVERTIME_COUNTDOWN_Y
	_overtime_countdown.offset_bottom = OVERTIME_COUNTDOWN_Y + 56.0
	_overtime_countdown.visible = false
	_root.add_child(_overtime_countdown)
