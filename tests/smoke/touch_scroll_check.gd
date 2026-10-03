class_name TouchScrollCheck
extends RefCounted
## LE DEFILEMENT AU DOIGT, sur chaque ecran qui deborde.
##
## Retour du co-auteur, sur son telephone : "il ne peut pas faire defiler les
## options du menu", donc ni remise a zero ni mode testeur. Rien ne le voyait :
## le smoke ouvrait les reglages et les capturait, le harnais posait
## `scroll_vertical` a la main. Personne ne glissait un DOIGT dessus.
##
## Ce controle rejoue le geste par la vraie file d entree, comme le telephone :
## InputEventScreenTouch / InputEventScreenDrag passes a Input.parse_input_event,
## en coordonnees de FENETRE (letterbox compris). C est Input qui en tire les
## evenements souris emules, exactement comme sur Android. Le geste part :
##   - d un BOUTON (Button / CheckButton : mouse_filter STOP),
##   - d un CURSEUR (HSlider : STOP, et il saute a la position du doigt),
##   - du FOND (un texte, donc la page de livre derriere lui).
## Dans les trois cas la page doit suivre le doigt, le bouton ne doit pas
## partir, le curseur ne doit pas bouger.
##
## Plusieurs tailles d ecran, dont des formats de telephone allonges : le projet
## est en `canvas_items` / `keep`, la page fait toujours 1080x1920 mais le doigt
## arrive en pixels d ecran, decales par les bandes noires.
##
## Fichier a part du pilote (une ligne d appel) : plusieurs chantiers touchent
## smoke_driver.gd en parallele.

## Formats d ecran essayes (largeur x hauteur de fenetre). 16:9, 20:9, 19,5:9
## (telephones allonges) et 4:3 (tablette, bandes sur les cotes). Assez petits
## pour tenir sur l ecran du poste en fenetre reelle.
const TAILLES: Array[Vector2i] = [
	Vector2i(540, 960), Vector2i(432, 960), Vector2i(443, 960), Vector2i(720, 960),
]
## Format des ecrans autres que les reglages : un telephone allonge.
const TAILLE_TELEPHONE: Vector2i = Vector2i(432, 960)
## Formats captures en fenetre reelle (haut et bas des reglages).
const TAILLES_CAPTUREES: Array[Vector2i] = [Vector2i(540, 960), Vector2i(432, 960)]

## Course d un glisser, en fraction de la hauteur visible de la zone.
const COURSE: float = 0.35
## Part minimale de la course que la page doit avoir suivie.
const SUIVI_MIN: float = 0.5
## Pas d un glisser (evenements ScreenDrag).
const PAS: int = 6
## Glissers au plus pour atteindre le bas des reglages.
const ESSAIS_MAX: int = 12

static var _driver: Node


static func run(driver: Node) -> void:
	_driver = driver
	var fenetre: Window = driver.get_window()
	var taille_init: Vector2i = fenetre.size
	# COMME UN TELEPHONE : avec l emulation, DisplayServer annonce un ecran
	# tactile, et le glisser natif de ScrollContainer s active comme sur
	# Android. Sans elle, il dort au harnais, et un conflit entre lui et le
	# defilement du jeu n y serait jamais vu.
	var emulation: bool = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	if not DisplayServer.is_touchscreen_available():
		_fail("defilement : l ecran tactile n est pas emule, le geste ne serait pas celui du telephone")
	SaveData.reset_profile()
	SaveData.set_tester_mode(false)

	var menu: Control = (load("res://scenes/main_menu/MainMenu.tscn") as PackedScene).instantiate()
	driver.add_child(menu)
	await _disposer()
	for i in TAILLES.size():
		await _taille(TAILLES[i])
		await _reglages(menu, TAILLES[i], i == 0, i == TAILLES.size() - 1)
	menu.call("show_settings", false)

	# Le reste au format telephone allonge, profil tout ouvert : les listes y
	# sont les plus longues (grimoire, succes, atelier).
	await _taille(TAILLE_TELEPHONE)
	SaveData.set_tester_mode(true)
	var bilan: Dictionary = {}
	await _menu_onglets(menu, bilan)
	menu.queue_free()
	await _disposer()
	await _combat(bilan)
	await _atelier(bilan)
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()
	await _taille(taille_init)
	Input.emulate_touch_from_mouse = emulation

	var lignes: Array[String] = []
	for k in bilan:
		lignes.append("%s=%d" % [k, int(bilan[k])])
	print("[SMOKE] defilement au doigt : %s" % ", ".join(lignes))
	# Ces ecrans DEBORDENT par construction (listes du catalogue entier) : s ils
	# ne debordaient plus, ce controle ne verifierait plus rien sans le dire.
	for ecran in ["profil", "atelier_liste", "atelier_selecteur"]:
		if int(bilan.get(ecran, 0)) == 0:
			_fail("defilement : l ecran %s ne deborde plus, le geste n y est pas verifie" % ecran)


# --- Les reglages ---

static func _reglages(menu: Control, taille: Vector2i, interrupteur_complet: bool,
		remise_complete: bool) -> void:
	var ou: String = "reglages %dx%d" % [taille.x, taille.y]
	menu.call("show_settings", true)
	await _disposer()
	var sc: ScrollContainer = menu.find_child("SettingsScroll", true, false) as ScrollContainer
	if sc == null:
		_fail("%s : zone de defilement introuvable" % ou)
		return
	sc.scroll_vertical = 0
	await _disposer()
	var vue: Rect2 = sc.get_global_rect()
	if not _deborde(sc):
		_fail("%s : la page ne deborde pas, le controle ne prouve rien" % ou)
		return

	# 1) L interrupteur du MODE TESTEUR se touche SANS defiler.
	var inter: Button = _bouton_texte(sc, "testeur")
	if inter == null or not vue.encloses(inter.get_global_rect()):
		_fail("%s : l interrupteur MODE TESTEUR n est pas visible sans defiler (%s, vue %s)"
			% [ou, inter.get_global_rect() if inter != null else "absent", vue])
	if taille in TAILLES_CAPTUREES:
		await _driver._shot("reglages_haut_%dx%d" % [taille.x, taille.y])

	# 2) Le doigt fait defiler, d ou qu il parte.
	await _verifier_defilement(sc, ou)

	# 3) Un glisser HORIZONTAL sur un curseur le regle, et ne fait pas defiler.
	var curseur: Slider = _premier_visible(sc, func(n: Node) -> bool: return n is Slider) as Slider
	if curseur != null:
		sc.scroll_vertical = 0
		await _disposer()
		var r: Rect2 = curseur.get_global_rect()
		var avant: float = curseur.value
		var defil: int = sc.scroll_vertical
		# De la droite vers le quart gauche : la valeur doit baisser.
		var p0: Vector2 = Vector2(r.position.x + r.size.x * 0.75, r.get_center().y)
		await _glisser(p0, Vector2(r.position.x + r.size.x * 0.25, p0.y))
		if not curseur.value < avant:
			_fail("%s : un glisser horizontal ne regle plus le curseur (%.2f -> %.2f)"
				% [ou, avant, curseur.value])
		if sc.scroll_vertical != defil:
			_fail("%s : un glisser horizontal sur un curseur fait defiler" % ou)
		curseur.value = avant

	# 4) La remise a zero s atteint au doigt.
	sc.scroll_vertical = 0
	await _disposer()
	var raz: Button = _bouton_texte(sc, "reinitialiser")
	if raz == null:
		_fail("%s : bouton de remise a zero absent" % ou)
		return
	var essais: int = 0
	while not vue.encloses(raz.get_global_rect()) and essais < ESSAIS_MAX:
		var p: Vector2 = vue.get_center() + Vector2(0.0, vue.size.y * COURSE * 0.5)
		await _glisser(p, p - Vector2(0.0, vue.size.y * COURSE))
		essais += 1
	if not vue.encloses(raz.get_global_rect()):
		_fail("%s : la remise a zero reste hors de vue apres %d glissers (defilement %d / %d)"
			% [ou, essais, sc.scroll_vertical, _max(sc)])
		return
	if taille in TAILLES_CAPTUREES:
		await _driver._shot("reglages_bas_%dx%d" % [taille.x, taille.y])

	# 5) Deux touchers : le premier arme seulement.
	var marque: StringName = _carte_non_decouverte()
	if marque != &"":
		SaveData.discover_card(marque)
	await _toucher(raz.get_global_rect().get_center())
	if not raz.text.to_lower().contains("confirmer"):
		_fail("%s : un toucher sur la remise a zero ne l arme pas (%s)" % [ou, raz.text])
	if marque != &"" and not SaveData.is_discovered(marque):
		_fail("%s : le PREMIER toucher a deja efface la progression" % ou)
	if remise_complete:
		await _toucher(raz.get_global_rect().get_center())
		if marque != &"" and SaveData.is_discovered(marque):
			_fail("%s : le second toucher n a pas remis la progression a zero" % ou)
	menu.call("show_settings", true)   # desarme
	await _disposer()

	# 6) Le mode testeur au doigt : deux touchers pour allumer, l ATELIER
	#    visible sans defiler, un toucher pour eteindre.
	if interrupteur_complet:
		await _interrupteur(menu, sc, ou)


static func _interrupteur(menu: Control, sc: ScrollContainer, ou: String) -> void:
	sc.scroll_vertical = 0
	await _disposer()
	var vue: Rect2 = sc.get_global_rect()
	var inter: Button = _bouton_texte(sc, "testeur")
	if inter == null:
		return
	await _toucher(inter.get_global_rect().get_center())
	if SaveData.tester_mode():
		_fail("%s : un seul toucher a allume le mode testeur" % ou)
	await _toucher(inter.get_global_rect().get_center())
	await _disposer()
	if not SaveData.tester_mode():
		_fail("%s : deux touchers n allument pas le mode testeur" % ou)
	var atelier: Control = sc.find_child("TesterToolsButton", true, false) as Control
	if atelier == null or not vue.encloses(atelier.get_global_rect()):
		_fail("%s : le bouton ATELIER n est pas visible sans defiler (%s, vue %s)"
			% [ou, atelier.get_global_rect() if atelier != null else "absent", vue])
	inter = _bouton_texte(sc, "testeur")
	if inter != null:
		await _toucher(inter.get_global_rect().get_center())
		await _disposer()
	if SaveData.tester_mode():
		_fail("%s : un toucher n eteint pas le mode testeur" % ou)
	menu.call("show_settings", true)
	await _disposer()


# --- Les autres ecrans ---

static func _menu_onglets(menu: Control, bilan: Dictionary) -> void:
	var tabs: Array = menu.get("TABS")
	var contenu: Node = menu.get_node("%Content")

	# GRIMOIRE : les fiches, dans les trois sections.
	menu.select_tab(tabs.find("GALERIE"))
	var grimoire: GalleryPanel = _enfant_de_type(contenu, "GalleryPanel") as GalleryPanel
	if grimoire != null:
		for s in GalleryPanel.Section.values():
			grimoire.show_section(s)
			var n: int = grimoire.entries().size()
			# La premiere, une du milieu, la derniere : courtes et longues.
			for i in [0, n / 2, n - 1]:
				if i < 0 or i >= n:
					continue
				grimoire.open_detail(i)
				await _ecran(grimoire, "grimoire", bilan)
			grimoire.close_detail()

	# DECK : la fiche d une carte (touchee au doigt) et le choix des passifs.
	menu.select_tab(tabs.find("DECK"))
	var deck: DeckPanel = _enfant_de_type(contenu, "DeckPanel") as DeckPanel
	if deck != null:
		await _disposer()
		var tuiles: Array[Button] = deck.draggable_tiles(false)
		if not tuiles.is_empty():
			await _toucher(tuiles[0].get_global_rect().get_center())
			await _ecran(deck, "deck_fiche", bilan)
		deck.open_passive_picker(0)
		await _ecran(deck, "deck_passifs", bilan)
		deck.close_passive_picker()
		await _ecran(deck, "deck", bilan)

	# PROFIL : les trois sections.
	menu.select_tab(tabs.find("PROFIL"))
	var profil: ProfilePanel = _enfant_de_type(contenu, "ProfilePanel") as ProfilePanel
	if profil != null:
		for s in ProfilePanel.SECTIONS.size():
			profil.show_section(s)
			await _ecran(profil, "profil", bilan)
	menu.select_tab(menu.get("HOME_TAB"))


static func _combat(bilan: Dictionary) -> void:
	var g: GameController = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	g.headless_mode = true
	_driver.add_child(g)
	g.running = false
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	for k in 20:
		g.simulate(1.0 / 60.0)

	# PAUSE : les trois onglets, et la fiche du monstre le plus charge.
	var pause := PausePanel.new(g)
	_driver.add_child(pause)
	for t in PausePanel.TABS.size():
		pause.show_tab(t)
		await _ecran(pause, "pause_" + PausePanel.TABS[t].to_lower(), bilan)
	var charge: EnemyDef = null
	for d: EnemyDef in ContentDB.enemies.values():
		if charge == null or d.resistances.size() > charge.resistances.size():
			charge = d
	pause.open_enemy(charge)
	await _ecran(pause, "pause_fiche", bilan)
	pause.queue_free()

	# EPURATION : la liste du deck de la partie.
	var epuration: Control = DeckBrowser.purge_overlay(1)
	_driver.add_child(epuration)
	await _ecran(epuration, "epuration", bilan)
	epuration.queue_free()
	g.queue_free()
	await _disposer()


static func _atelier(bilan: Dictionary) -> void:
	TesterOverrides.reset_for_tests()
	SceneRouter.payload = {}
	var tools: TesterTools = (load(TesterRun.TOOLS_SCENE) as PackedScene).instantiate()
	_driver.add_child(tools)
	await _disposer()
	# Les onglets de listes et la fiche d un monstre. TEST et DOC lancent une
	# partie ou ecrivent un fichier : ils restent au smoke de l atelier.
	for t in ["sorts", "monstres", "niveaux"]:
		tools.show_tab(t)
		await _ecran(tools, "atelier_liste", bilan)
	var monstre: EnemyDef = ContentDB.enemies.values()[0]
	tools.open_sheet(TesterOverrides.target_of(monstre))
	await _ecran(tools, "atelier_fiche", bilan)
	tools.open_picker("Monstre", TesterField.ref_items("enemy"), func(_id: String) -> void: pass)
	await _ecran(tools, "atelier_selecteur", bilan)
	tools.close_picker()
	tools.queue_free()
	await _disposer()


## Verifie chaque zone qui DEBORDE sous `racine` et compte celles verifiees.
static func _ecran(racine: Control, nom: String, bilan: Dictionary) -> void:
	await _disposer()
	var n: int = 0
	for sc in _zones(racine):
		# Une zone RECOUVERTE (l atelier sous son selecteur plein ecran) ne
		# recoit pas le doigt : ce n est pas elle que le joueur fait defiler.
		if _deborde(sc) and await _sous_le_doigt(sc, sc.get_global_rect().get_center()):
			await _verifier_defilement(sc, nom)
			n += 1
	bilan[nom] = int(bilan.get(nom, 0)) + n


# --- Le geste ---

## Trois departs : bouton, curseur, fond. Chaque fois la page part du haut, le
## doigt monte de COURSE * hauteur visible, la page doit suivre.
static func _verifier_defilement(sc: ScrollContainer, ou: String) -> void:
	var essayes: int = 0
	for depart in ["bouton", "curseur", "fond"]:
		sc.scroll_vertical = 0
		await _disposer()
		var vue: Rect2 = sc.get_global_rect()
		var cible: Control = _cible(sc, depart)
		if cible == null or not await _sous_le_doigt(sc, cible.get_global_rect().get_center()):
			continue
		essayes += 1
		var p: Vector2 = cible.get_global_rect().get_center()
		var classe: String = cible.get_class()
		var course: float = vue.size.y * COURSE
		var attendu: float = minf(course, float(_max(sc))) * SUIVI_MIN
		var valeur: float = (cible as Slider).value if cible is Slider else 0.0
		var appuis: Array[int] = [0]
		var compte := func() -> void: appuis[0] += 1
		if cible is BaseButton:
			(cible as BaseButton).pressed.connect(compte)
		await _glisser(p, p - Vector2(0.0, course))
		if not is_instance_valid(sc) or not sc.is_inside_tree():
			_fail("%s : glisser depuis un %s (%s) a ferme l ecran" % [ou, depart, classe])
			return
		if sc.scroll_vertical < attendu:
			_fail("%s : glisser le doigt depuis un %s (%s) ne fait pas defiler (%d, attendu >= %d sur %d)"
				% [ou, depart, classe, sc.scroll_vertical, int(attendu), _max(sc)])
		if appuis[0] > 0:
			_fail("%s : un defilement parti d un bouton (%s) l a declenche" % [ou, classe])
		if is_instance_valid(cible) and cible is BaseButton:
			(cible as BaseButton).pressed.disconnect(compte)
		if is_instance_valid(cible) and cible is Slider \
				and not is_equal_approx((cible as Slider).value, valeur):
			_fail("%s : un glisser VERTICAL a deplace le curseur (%.2f -> %.2f)"
				% [ou, valeur, (cible as Slider).value])
			(cible as Slider).value = valeur
	if essayes == 0:
		_fail("%s : aucun point de depart trouve dans la zone qui deborde" % ou)
	sc.scroll_vertical = 0


## Le controle d ou part le doigt, entierement visible dans la zone.
static func _cible(sc: ScrollContainer, depart: String) -> Control:
	match depart:
		"bouton":
			return _premier_visible(sc, func(n: Node) -> bool: return n is BaseButton)
		"curseur":
			return _premier_visible(sc, func(n: Node) -> bool: return n is Slider)
		_:
			# Un texte hors de tout bouton, curseur ou champ : c est le fond de la
			# page qui recoit le doigt (le texte laisse passer).
			var actifs: Array[Rect2] = []
			for n in _descendants(sc):
				if n is BaseButton or n is Slider or n is LineEdit:
					actifs.append((n as Control).get_global_rect())
			return _premier_visible(sc, func(n: Node) -> bool:
				if not (n is Label):
					return false
				var c: Vector2 = (n as Control).get_global_rect().get_center()
				for r in actifs:
					if r.has_point(c):
						return false
				return true)


## Vrai si un doigt pose en `p` toucherait la zone `sc` (et pas un ecran pose
## par-dessus). Lu sur le moteur lui-meme : un survol, puis le controle survole.
static func _sous_le_doigt(sc: ScrollContainer, p: Vector2) -> bool:
	var survol := InputEventMouseMotion.new()
	survol.position = _driver.get_viewport().get_final_transform() * p
	Input.parse_input_event(survol)
	await _driver.get_tree().process_frame
	var dessous: Control = _driver.get_viewport().gui_get_hovered_control()
	return dessous != null and (dessous == sc or sc.is_ancestor_of(dessous))


static func _glisser(de: Vector2, a: Vector2) -> void:
	var points: Array[Vector2] = [de]
	for k in range(1, PAS + 1):
		points.append(de.lerp(a, float(k) / PAS))
	await _doigt(points)


static func _toucher(p: Vector2) -> void:
	await _doigt([p])


## Le doigt : appui, glisser par chaque point, relachement. Coordonnees de la
## page (1080x1920) converties en pixels de FENETRE par la transformation
## d etirement, bandes noires comprises.
static func _doigt(points: Array[Vector2]) -> void:
	var tree: SceneTree = _driver.get_tree()
	var xf: Transform2D = _driver.get_viewport().get_final_transform()
	var appui := InputEventScreenTouch.new()
	appui.index = 0
	appui.pressed = true
	appui.position = xf * points[0]
	Input.parse_input_event(appui)
	await tree.process_frame
	for i in range(1, points.size()):
		var g := InputEventScreenDrag.new()
		g.index = 0
		g.position = xf * points[i]
		g.relative = xf.basis_xform(points[i] - points[i - 1])
		Input.parse_input_event(g)
		await tree.process_frame
	var lache := InputEventScreenTouch.new()
	lache.index = 0
	lache.pressed = false
	lache.position = xf * points[points.size() - 1]
	Input.parse_input_event(lache)
	await tree.process_frame
	await tree.process_frame


# --- Outils ---

static func _taille(t: Vector2i) -> void:
	_driver.get_window().size = t
	await _disposer()


static func _disposer() -> void:
	var tree: SceneTree = _driver.get_tree()
	await tree.process_frame
	await tree.process_frame


static func _fail(msg: String) -> void:
	_driver.call("_fail", msg)


static func _max(sc: ScrollContainer) -> int:
	var b: VScrollBar = sc.get_v_scroll_bar()
	return int(b.max_value - b.page)


static func _deborde(sc: ScrollContainer) -> bool:
	return sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and _max(sc) > 0


## Les zones de defilement affichees sous `racine`, elle comprise.
static func _zones(racine: Control) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	var tous: Array[Node] = [racine]
	tous.append_array(_descendants(racine))
	for n in tous:
		if n is ScrollContainer and (n as Control).is_visible_in_tree():
			out.append(n)
	return out


## Descendants, sans les barres internes des ScrollContainer.
static func _descendants(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out


## Le premier controle du filtre, affiche et entierement dans la vue de `sc`, qui
## appartient a CETTE zone (pas a une zone imbriquee).
static func _premier_visible(sc: ScrollContainer, filtre: Callable) -> Control:
	var vue: Rect2 = sc.get_global_rect()
	for n in _descendants(sc):
		if not (n is Control) or not filtre.call(n):
			continue
		var c: Control = n
		if not c.is_visible_in_tree() or c.get_global_rect().size.y <= 0.0:
			continue
		if not vue.encloses(c.get_global_rect()):
			continue
		if _zone_de(c) != sc:
			continue
		return c
	return null


static func _zone_de(c: Node) -> ScrollContainer:
	var p: Node = c.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	return p as ScrollContainer


static func _bouton_texte(racine: Node, mot: String) -> Button:
	for n in _descendants(racine):
		if n is Button and (n as Button).text.to_lower().contains(mot):
			return n
	return null


static func _enfant_de_type(racine: Node, classe: String) -> Control:
	for n in racine.get_children():
		var s: Script = n.get_script()
		if s != null and s.get_global_name() == classe:
			return n
	return null


static func _carte_non_decouverte() -> StringName:
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for id in ids:
		if not SaveData.is_discovered(id):
			return id
	return &""
