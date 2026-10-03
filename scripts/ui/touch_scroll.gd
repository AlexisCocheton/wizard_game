class_name TouchScroll
extends Node
## DEFILEMENT AU DOIGT d un ScrollContainer, d ou que parte le doigt.
##
## LE DEFAUT (retour du co-auteur, sur son telephone, 03/10) : "il ne peut pas
## faire defiler les options du menu" — donc ni remise a zero, ni mode testeur,
## poses en bas de la page. Cause mesuree, pas devinee :
##
##   1. Le glisser natif de ScrollContainer (Godot 4.4) ne recoit que les
##      evenements qui REMONTENT jusqu a lui. Un controle en MOUSE_FILTER_STOP
##      les garde pour lui. Or la page de livre des reglages est un
##      PanelContainer, et PanelContainer est STOP PAR DEFAUT (contrairement aux
##      autres Container) : elle couvrait toute la zone, aucun toucher n arrivait
##      jamais au ScrollContainer. Mesure : 0 px de defilement en partant d un
##      texte, d un curseur ou d un bouton ; 520 px des que la page passe en PASS.
##   2. Meme la page reglee, un glisser qui part d un Button, d un CheckButton
##      ou d un HSlider (STOP eux aussi) ne defile pas. Sur un ecran fait de
##      curseurs et de boutons pleine largeur, c est presque toute la surface.
##      Et le HSlider SAUTE a la position du doigt des l appui : un pouce qui
##      voulait descendre changeait le volume.
##   3. Le glisser natif n existe que si DisplayServer.is_touchscreen_available()
##      (telephone, ou emulation) : rien ne le voyait au harnais.
##
## Le meme defaut touchait TOUS les ecrans qui defilent (grimoire, profil,
## pause, Epuration, atelier) : leurs listes sont faites de boutons.
##
## LA CORRECTION. Ce noeud s accroche au signal `gui_input` de chaque controle
## de la zone. Ce signal est emis AVANT le traitement propre du controle (c est
## documente dans le moteur pour pouvoir "surcharger un evenement puis
## l accepter") : on voit donc l appui sur un bouton ou un curseur avant lui, et
## on decide du geste au premier mouvement franc :
##   - surtout VERTICAL  -> la page suit le doigt ; le bouton touche est annule
##     (NOTIFICATION_SCROLL_BEGIN, comme le fait le moteur) et ne part pas ;
##   - surtout HORIZONTAL sur un curseur -> le curseur suit le doigt ;
##   - sinon, sous le seuil -> c est un toucher, rendu au controle.
## Un curseur ne bouge donc JAMAIS sur un glisser vertical : son appui lui est
## retenu jusqu a ce que le geste soit connu.
##
## Le glisser natif est neutralise sur la zone (les evenements de bouton gauche
## et de mouvement qui lui remontent sont acceptes) : deux defilements qui se
## disputent le meme doigt, c est une page qui saute. La molette, elle, reste au
## moteur.
##
## Verrouille par tests/smoke/touch_scroll_check.gd (le geste au doigt, sur
## chaque ecran qui deborde, a plusieurs formats d ecran) et
## tests/unit/test_touch_scroll.gd (la regle de decision, et aucune zone de
## defilement construite sans ce noeud).

enum Geste { AUCUN, DEFILER, REGLER, LAISSER }
enum Etat { LIBRE, ATTENTE, DEFILE, REGLE }

## Deplacement, en pixels de page (1080 de large), sous lequel rien n est
## decide : c est encore un toucher. Meme ordre de grandeur que le seuil du
## glisser-deposer du deck.
const SEUIL_PX: float = 24.0

const META: StringName = &"touch_scroll"

var _scroll: ScrollContainer = null
var _etat: int = Etat.LIBRE
var _depart: Vector2 = Vector2.ZERO
var _depart_defil: int = 0
var _curseur: Slider = null
## Le dernier evenement traite : un evenement qui remonte d un enfant PASS a son
## parent declenche le signal des deux, il ne doit compter qu une fois.
var _dernier: InputEvent = null


## Une zone de defilement VERTICAL prete pour le doigt. A utiliser a la place
## de `ScrollContainer.new()` dans toute l interface.
static func make() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	attach(sc)
	return sc


## Accroche le defilement au doigt a une zone existante. Idempotent.
static func attach(sc: ScrollContainer) -> TouchScroll:
	var deja: TouchScroll = of(sc)
	if deja != null:
		return deja
	var t := TouchScroll.new()
	t.name = "TouchScroll"
	t._scroll = sc
	sc.set_meta(META, t)
	# INTERNE : la zone garde un seul enfant visible, son contenu. Du code
	# (et des tests) lisent `get_child(0)` ou le parent du contenu.
	sc.add_child(t, false, Node.INTERNAL_MODE_FRONT)
	return t


## Le noeud accroche a une zone, null s il n y en a pas.
static func of(sc: ScrollContainer) -> TouchScroll:
	if sc == null or not sc.has_meta(META):
		return null
	var t: Variant = sc.get_meta(META)
	if t is TouchScroll and is_instance_valid(t):
		return t
	return null


## LA REGLE. Ce que devient un appui qui a bouge de `delta` (pixels de page).
## Statique : le test la lit sans construire d ecran.
static func gesture_for(delta: Vector2, on_slider: bool) -> int:
	if delta.length() < SEUIL_PX:
		return Geste.AUCUN
	if absf(delta.y) > absf(delta.x):
		return Geste.DEFILER
	return Geste.REGLER if on_slider else Geste.LAISSER


## Vrai si la zone a quelque chose a faire defiler verticalement.
static func can_scroll(sc: ScrollContainer) -> bool:
	if sc == null or sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var b: VScrollBar = sc.get_v_scroll_bar()
	return b.max_value - b.page > 0.5


func is_scrolling() -> bool:
	return _etat == Etat.DEFILE


func _enter_tree() -> void:
	if _scroll == null:
		_scroll = get_parent() as ScrollContainer
	if _scroll == null:
		return
	_accrocher_tout(_scroll)
	var tree: SceneTree = get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	_etat = Etat.LIBRE
	_curseur = null


func _accrocher_tout(n: Node) -> void:
	if n is Control:
		_accrocher(n as Control)
	for c in n.get_children():
		_accrocher_tout(c)


## Les barres internes de la zone (et de toute zone imbriquee) gardent leur
## comportement : on les saisit pour defiler, c est deja le bon geste.
func _accrocher(c: Control) -> void:
	if c is ScrollBar:
		return
	var cb: Callable = _on_gui_input.bind(c)
	if not c.gui_input.is_connected(cb):
		c.gui_input.connect(cb)


## Les controles ajoutes APRES coup (listes reconstruites, bloc du mode testeur,
## fiches) sont accroches a leur entree dans l arbre.
func _on_node_added(n: Node) -> void:
	if n is Control and _scroll != null and _scroll.is_ancestor_of(n):
		_accrocher(n as Control)


func _on_gui_input(ev: InputEvent, c: Control) -> void:
	var neuf: bool = ev != _dernier
	_dernier = ev
	if neuf:
		_traiter(ev, c)
	# Le glisser NATIF de la zone ne recoit plus rien du bouton gauche : il se
	# disputerait le doigt avec celui-ci (et lancerait son inertie au lacher).
	if c == _scroll and _geste_du_doigt(ev):
		c.accept_event()


static func _geste_du_doigt(ev: InputEvent) -> bool:
	if ev is InputEventMouseMotion:
		return true
	return ev is InputEventMouseButton \
		and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


func _traiter(ev: InputEvent, c: Control) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_appui(mb, c)
		else:
			_lacher(mb, c)
	elif ev is InputEventMouseMotion and _etat != Etat.LIBRE:
		_bouger(ev as InputEventMouseMotion, c)


func _appui(mb: InputEventMouseButton, c: Control) -> void:
	_etat = Etat.LIBRE
	_curseur = null
	if not can_scroll(_scroll) or not _a_moi(c):
		return
	_etat = Etat.ATTENTE
	_depart = mb.global_position
	_depart_defil = _scroll.scroll_vertical
	if c is Slider and (c as Slider).editable:
		# L appui est RETENU : un curseur saute a la position du doigt des
		# l appui, et un pouce qui veut descendre changerait le volume.
		_curseur = c as Slider
		c.accept_event()


func _bouger(mm: InputEventMouseMotion, c: Control) -> void:
	if _etat == Etat.ATTENTE:
		match gesture_for(mm.global_position - _depart, _curseur != null):
			Geste.AUCUN:
				if _curseur != null:
					c.accept_event()
				return
			Geste.DEFILER:
				_etat = Etat.DEFILE
				# Le bouton sous le doigt abandonne son appui : le lacher ne le
				# declenchera pas. C est la notification qu envoie le moteur
				# quand SON glisser demarre (verifie sur 4.4).
				_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
				_scroll.scroll_started.emit()
			Geste.REGLER:
				_etat = Etat.REGLE
			_:
				# Horizontal sur un bouton : c est son affaire.
				_etat = Etat.LIBRE
				return
	if _etat == Etat.DEFILE:
		# La page suit le doigt : doigt vers le haut = on descend. Le
		# ScrollContainer borne lui-meme la valeur.
		_scroll.scroll_vertical = _depart_defil + int(round(_depart.y - mm.global_position.y))
		c.accept_event()
	elif _etat == Etat.REGLE and _curseur != null:
		_regler(mm.global_position)
		c.accept_event()


func _lacher(mb: InputEventMouseButton, c: Control) -> void:
	match _etat:
		Etat.ATTENTE:
			# Un TOUCHER sur un curseur : il va a la position du doigt, comme
			# l aurait fait le curseur lui-meme.
			if _curseur != null:
				_regler(mb.global_position)
				c.accept_event()
		Etat.DEFILE:
			_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
			_scroll.scroll_ended.emit()
	_etat = Etat.LIBRE
	_curseur = null


## Le curseur a la position horizontale du doigt, avec la meme geometrie que le
## moteur (la poignee ne sort pas de la piste).
func _regler(p: Vector2) -> void:
	if _curseur == null or not is_instance_valid(_curseur):
		return
	var r: Rect2 = _curseur.get_global_rect()
	var poignee: Texture2D = _curseur.get_theme_icon(&"grabber")
	var gw: float = float(poignee.get_width()) if poignee != null else 0.0
	var piste: float = maxf(1.0, r.size.x - gw)
	_curseur.ratio = clampf((p.x - r.position.x - gw * 0.5) / piste, 0.0, 1.0)


## Vrai si le controle touche releve de CETTE zone et non d une zone imbriquee
## qui peut defiler elle-meme (elle a son propre noeud).
func _a_moi(c: Control) -> bool:
	var n: Node = c
	while n != null and n != _scroll:
		if n is ScrollContainer and of(n as ScrollContainer) != null \
				and can_scroll(n as ScrollContainer):
			return false
		n = n.get_parent()
	return n == _scroll
