extends TestCase
## MENU PAUSE A ONGLETS et composant DeckBrowser (vague 8).
##
## Le menu pause etait une seule feuille : la main, puis une ligne de noms pour
## le deck, et un temps d incantation FAUX (base_cast_time, sans le facteur
## GameConfig.CAST_TIME_SCALE). Ces tests lisent l ecran construit, pas des
## constantes : un onglet qui n affiche rien ou un chiffre faux doit rougir.

const PAPIER_LUMINANCE: float = 0.84


func get_suite_name() -> String:
	return "pause_panel"


func run() -> void:
	_test_le_hud_pose_le_panneau_a_onglets()
	_test_reprendre_et_quitter_restent_accessibles()
	_test_onglet_deck_montre_tout_le_deck()
	_test_temps_d_incantation_reel()
	_test_maturation_affichee()
	_test_onglet_vague_et_fiche_de_monstre()
	_test_fiche_de_monstre_resistances_en_logos()
	_test_encres_lisibles_sur_le_papier()
	_test_polices_au_plancher_du_theme()
	RunState.reset()
	SpeedGauge.reset()


func _partie() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	# Assez de temps pour que la premiere vague ait des monstres sur le terrain
	# ET d autres encore dans la file.
	for i in 40:
		g.simulate(0.1)
	return g


func _pause(g: GameController) -> PausePanel:
	var hud: Node = g.get_node_or_null("HUD")
	hud.call("_show_pause_panel")
	return hud.get("_pause_panel") as PausePanel


func _tous(racine: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in racine.get_children():
		out.append(c)
		out.append_array(_tous(c))
	return out


func _textes(racine: Node) -> String:
	var t: String = ""
	for n in _tous(racine):
		if n is Label:
			t += (n as Label).text + "\n"
		elif n is Button:
			t += (n as Button).text + "\n"
	return t


func _test_le_hud_pose_le_panneau_a_onglets() -> void:
	var g: GameController = _partie()
	var p: PausePanel = _pause(g)
	ok(p != null, "le HUD pose un PausePanel (scripts/ui/pause_panel.gd)")
	if p == null:
		detach(g)
		return
	eq(PausePanel.TABS, ["MAIN", "DECK", "VAGUE"] as Array[String], "trois onglets")
	eq(p.process_mode, Node.PROCESS_MODE_ALWAYS, "il repond quand l arbre est en pause")
	for i in PausePanel.TABS.size():
		var b: Button = p.find_child("Tab_" + PausePanel.TABS[i], true, false) as Button
		ok(b != null and b.custom_minimum_size.y >= 90.0,
			"l onglet %s est une cible de pouce" % PausePanel.TABS[i])
		if b != null:
			b.pressed.emit()
		eq(p.current_tab(), i, "toucher %s l ouvre" % PausePanel.TABS[i])
	p.show_tab(PausePanel.Tab.HAND)
	var texte: String = _textes(p)
	ok(texte.contains("TA MAIN"), "l onglet MAIN montre la main")
	ok(texte.contains("POUVOIRS ACTIFS"), "et les passifs")
	for c: SpellCard in RunState.hand:
		ok(texte.contains(c.display_name), "la carte en main %s est listee" % c.display_name)
	detach(g)


func _test_reprendre_et_quitter_restent_accessibles() -> void:
	var g: GameController = _partie()
	# Un panneau A PART, pas celui du HUD : celui-la est branche sur la vraie
	# sortie (SceneRouter.goto), qui changerait de scene sous les pieds du
	# harnais. On verifie ici ce que le panneau EMET ; le HUD branche ses deux
	# signaux sur _on_pause_pressed / _on_quit_pressed (lu plus bas).
	var p := PausePanel.new(g)
	attach(p)
	var repris: Array = [0]
	var quitte: Array = [0]
	p.resume_requested.connect(func() -> void: repris[0] += 1)
	p.quit_requested.connect(func() -> void: quitte[0] += 1)
	for i in PausePanel.TABS.size():
		p.show_tab(i)
		var r: Button = p.find_child("Resume", true, false) as Button
		var q: Button = p.find_child("Quit", true, false) as Button
		ok(r != null and r.is_visible_in_tree(), "REPRENDRE est la sur l onglet %s" % PausePanel.TABS[i])
		ok(q != null and q.is_visible_in_tree(), "QUITTER est la sur l onglet %s" % PausePanel.TABS[i])
		if r != null:
			ok(r.custom_minimum_size.y >= 90.0, "REPRENDRE fait au moins 90 px")
		if q != null:
			ok(q.custom_minimum_size.y >= 90.0, "QUITTER fait au moins 90 px")
	(p.find_child("Resume", true, false) as Button).pressed.emit()
	(p.find_child("Quit", true, false) as Button).pressed.emit()
	eq(repris[0], 1, "REPRENDRE demande la reprise")
	eq(quitte[0], 1, "QUITTER demande la sortie")
	detach(p)
	var hud: Node = g.get_node_or_null("HUD")
	var dans_hud: PausePanel = _pause(g)
	ok(dans_hud.resume_requested.is_connected(Callable(hud, "_on_pause_pressed")),
		"le HUD branche REPRENDRE sur sa reprise")
	ok(dans_hud.quit_requested.is_connected(Callable(hud, "_on_quit_pressed")),
		"le HUD branche QUITTER sur sa sortie")
	detach(g)


func _test_onglet_deck_montre_tout_le_deck() -> void:
	var g: GameController = _partie()
	var p: PausePanel = _pause(g)
	p.show_tab(PausePanel.Tab.DECK)
	var nav: DeckBrowser = p.deck_browser()
	ok(nav != null, "l onglet DECK porte le composant DeckBrowser")
	if nav == null:
		detach(g)
		return
	eq(nav.mode, DeckBrowser.Mode.BROWSE, "en mode lecture, pas de choix")
	var attendues: Dictionary = {}
	for pile: Array in [RunState.deck, RunState.hand, RunState.discard]:
		for c in pile:
			attendues[(c as SpellCard).id] = true
	var listees: Dictionary = {}
	for c in nav.listed_cards():
		listees[c.id] = true
	eq(listees.size(), attendues.size(), "une ligne par carte differente de la partie")
	for id in attendues:
		ok(listees.has(id), "%s (pioche, main ou defausse) est listee" % id)
	var total: int = 0
	for gr in RunState.run_deck_groups():
		total += int(gr["total"])
		eq(int(gr["total"]), int(gr["pile"]) + int(gr["hand"]) + int(gr["discard"]),
			"%s : le total est la somme des piles" % (gr["card"] as SpellCard).id)
	eq(total, RunState.total_cards(), "tous les exemplaires de la partie sont comptes")
	ok(nav.summary_text().contains(str(RunState.total_cards())),
		"l en-tete donne le nombre de cartes (%s)" % nav.summary_text())
	for c in nav.listed_cards():
		var t: String = nav.row_text(c)
		ok(t.contains(c.description), "%s : son effet est ecrit" % c.id)
		ok(t.contains(DeckBrowser.cast_time_text(c)), "%s : son temps d incantation" % c.id)
		ok(t.contains(DeckBrowser.maturation_text(c)), "%s : sa maturation" % c.id)
	ok(nav.find_child("Validate", true, false) == null, "pas de VALIDER en lecture")
	detach(g)


## Le temps affiche est celui que le Caster applique : base x CAST_TIME_SCALE,
## divise par la vitesse. L ancienne pause affichait base_cast_time.
func _test_temps_d_incantation_reel() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var c := SpellCard.new()
	c.id = &"t_cast"
	c.display_name = "t_cast"
	c.base_cast_time = 2.0
	var reel: float = RunState.effective_cast_time(c)
	eq(DeckBrowser.cast_time_text(c), "%s s" % DeckBrowser._fmt(reel),
		"le texte est le temps REEL de RunState")
	if not is_equal_approx(GameConfig.CAST_TIME_SCALE, 1.0):
		ok(not DeckBrowser.cast_time_text(c).begins_with(DeckBrowser._fmt(c.base_cast_time) + " "),
			"et non le temps de base (%s)" % DeckBrowser.cast_time_text(c))
	feq(reel, SpeedGauge.effective_cast_time(c.base_cast_time * GameConfig.CAST_TIME_SCALE),
		"le facteur global est bien dedans", 0.01)


func _test_maturation_affichee() -> void:
	RunState.reset()
	var carte: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if not c.is_passive and not RunState.upgrade_pool_for(c).is_empty():
			carte = c
			break
	ok(carte != null, "une carte ameliorable existe")
	if carte == null:
		return
	var total: int = GameConfig.CARD_UPGRADE_TIERS
	ok(DeckBrowser.maturation_text(carte).begins_with("Maturation 0 / %d" % total),
		"au depart : 0 / %d (%s)" % [total, DeckBrowser.maturation_text(carte)])
	var voie: Dictionary = RunState.upgrade_pool_for(carte)[0]
	RunState.upgrades_taken[carte.id] = [voie["id"]]
	var t: String = DeckBrowser.maturation_text(carte)
	ok(t.begins_with("Maturation 1 / %d" % total), "une voie prise : 1 / %d (%s)" % [total, t])
	ok(t.contains(str(voie["title"])), "et son nom (%s)" % t)
	RunState.reset()


func _test_onglet_vague_et_fiche_de_monstre() -> void:
	var g: GameController = _partie()
	var p: PausePanel = _pause(g)
	p.show_tab(PausePanel.Tab.WAVE)
	var groupes: Array[Dictionary] = PausePanel.wave_groups(g)
	var vivants: int = g.battlefield.alive_count()
	var file: int = g.spawner.queued_enemies().size()
	ok(vivants + file > 0, "la vague a des monstres (terrain %d, file %d)" % [vivants, file])
	var somme_v: int = 0
	var somme_f: int = 0
	for gr in groupes:
		somme_v += int(gr["alive"])
		somme_f += int(gr["queued"])
	eq(somme_v, vivants, "les monstres du terrain sont tous comptes")
	eq(somme_f, file, "ceux de la file aussi")
	var boutons: Array[Button] = []
	for n in _tous(p):
		if n is Button and n.has_meta(&"enemy_id"):
			boutons.append(n)
	eq(boutons.size(), groupes.size(), "un bouton par monstre de la vague")
	if not boutons.is_empty():
		ok(boutons[0].custom_minimum_size.y >= 90.0, "un monstre est une cible de pouce")
		boutons[0].pressed.emit()
		ok(p.open_enemy_sheet() != null, "toucher un monstre ouvre sa fiche")
		ok(_textes(p).contains(p.open_enemy_sheet().display_name), "la fiche porte son nom")
		var retour: Button = p.find_child("SheetBack", true, false) as Button
		ok(retour != null, "la fiche se referme")
		if retour != null:
			retour.pressed.emit()
		ok(p.open_enemy_sheet() == null, "retour a la liste")
	detach(g)


func _test_fiche_de_monstre_resistances_en_logos() -> void:
	var def: EnemyDef = null
	for d: EnemyDef in ContentDB.enemies.values():
		if not BestiaryLore.resistance_groups(d).is_empty():
			def = d
			break
	ok(def != null, "un monstre a des resistances")
	if def == null:
		return
	var box := VBoxContainer.new()
	attach(box)
	PausePanel.fill_enemy_sheet(box, def)
	var texte: String = _textes(box)
	ok(texte.contains(def.display_name), "la fiche porte le nom")
	ok(texte.contains(BestiaryLore.RESIST_RULE_TEXT), "la regle « degats et effets » est ecrite")
	for line in BestiaryLore.behaviours(def):
		ok(texte.contains(line), "la competence est ecrite : %s" % line)
	for gr in BestiaryLore.resistance_groups(def):
		var bloc: Node = box.find_child("Resist_" + str(gr["title"]), true, false)
		ok(bloc != null, "le groupe %s est la" % gr["title"])
		for item in gr["items"]:
			var ligne: Node = box.find_child("Resist_%d" % int(item["tag"]), true, false)
			ok(ligne != null, "l element %d a sa ligne" % int(item["tag"]))
			if ligne != null:
				var logo: bool = false
				for n in _tous(ligne):
					if n is TextureRect and (n as TextureRect).texture != null:
						logo = true
				ok(logo, "l element %d a son LOGO" % int(item["tag"]))
	detach(box)


## WCAG sur le papier de la pause (luminance mesuree sur capture, comme le bloc
## testeur des reglages).
func _test_encres_lisibles_sur_le_papier() -> void:
	var encres: Dictionary = {
		"pause titre": PausePanel.INK_TITLE, "pause texte": PausePanel.INK_TEXT,
		"pause doux": PausePanel.INK_SOFT, "pause indice": PausePanel.INK_HINT,
		"pause immunise": PausePanel.INK_BAD, "pause vulnerable": PausePanel.INK_GOOD,
		"pause resiste": PausePanel.INK_RESIST,
		"deck texte": DeckBrowser.INK_TEXT, "deck doux": DeckBrowser.INK_SOFT,
		"deck indice": DeckBrowser.INK_HINT, "deck retenue": DeckBrowser.INK_PICKED,
	}
	for nom in encres:
		var r: float = _ratio(_luminance(encres[nom]), PAPIER_LUMINANCE)
		ok(r >= UiTheme.CONTRAST_MIN, "%s lisible sur le papier (%.2f:1)" % [nom, r])


func _test_polices_au_plancher_du_theme() -> void:
	var g: GameController = _partie()
	var p: PausePanel = _pause(g)
	for i in PausePanel.TABS.size():
		p.show_tab(i)
		for n in _tous(p):
			if n is Label and (n as Label).has_theme_font_size_override(&"font_size"):
				var t: int = (n as Label).get_theme_font_size(&"font_size")
				if t < UiTheme.FONT_SMALL:
					ok(false, "onglet %s : « %s » en %d px, sous le plancher %d"
						% [PausePanel.TABS[i], (n as Label).text, t, UiTheme.FONT_SMALL])
	ok(true, "polices verifiees")
	detach(g)


func _luminance(c: Color) -> float:
	return 0.2126 * _canal(c.r) + 0.7152 * _canal(c.g) + 0.0722 * _canal(c.b)


func _canal(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func _ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
