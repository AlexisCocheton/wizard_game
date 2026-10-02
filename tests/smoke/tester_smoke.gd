class_name TesterSmoke
extends RefCounted
## SMOKE / VISUAL des OUTILS DU TESTEUR (vague 8).
##
## Construit l atelier comme le testeur le verrait, avec quelques reglages
## poses, et en capture les ecrans demandes : la liste, la fiche d un monstre,
## la fiche d une carte avec ses effets, une vague de campagne reglee, l onglet
## TEST et l onglet DOCUMENT apres un export. En headless rien n est capture
## mais tout est construit : c est ce qui attrape une SCRIPT ERROR d interface.
##
## Fichier a part du pilote (smoke_driver.gd ne porte qu une ligne d appel) :
## plusieurs chantiers touchent le pilote en parallele, un bloc de cent lignes
## au milieu serait un conflit de fusion assure.

const SMOKE_DOC_DIR: String = "user://smoke_tester_docs"


static func run(driver: Node) -> void:
	SaveData.reset_profile()
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(true)

	# Quelques reglages, pour que les captures montrent l etat "modifie".
	var monstre: EnemyDef = ContentDB.enemies.get(&"gnome")
	var carte: SpellCard = ContentDB.cards.get(&"frost_field")
	var niveau: LevelDef = ContentDB.levels.get(&"lvl_01")
	if monstre == null or carte == null or niveau == null:
		driver.call("_fail", "atelier : contenu de vitrine introuvable")
		return
	var tm: String = TesterOverrides.target_of(monstre)
	var tc: String = TesterOverrides.target_of(carte)
	var tl: String = TesterOverrides.target_of(niveau)
	TesterOverrides.set_override(tm, "max_hp", monstre.max_hp * 2.0)
	TesterOverrides.set_override(tm, "resistances/feu", 0.5)
	TesterOverrides.set_override(tc, "effects/0/radius", carte.effects[0].radius + 60.0)
	var w: Dictionary = TesterOverrides.encode_wave(niveau.waves[0])
	w["entries"][0]["count"] = int(w["entries"][0]["count"]) + 3
	w["difficulty"] = 1.3
	TesterOverrides.set_override(tl, "waves/0", w)
	if TesterOverrides.count() != 4 or not TesterOverrides.rejected().is_empty():
		driver.call("_fail", "atelier : reglages de vitrine refuses %s" % str(TesterOverrides.rejected()))

	SceneRouter.payload = {}
	var scene: PackedScene = load(TesterRun.TOOLS_SCENE)
	var tools: TesterTools = scene.instantiate()
	driver.add_child(tools)
	var tree: SceneTree = driver.get_tree()
	await tree.process_frame

	tools.show_tab("monstres")
	await tree.process_frame
	await driver._shot("atelier_liste")

	tools.open_sheet(tm)
	await tree.process_frame
	await driver._shot("atelier_fiche_monstre")
	await _scroll_to(tools, "RESISTANCES", tree)
	await driver._shot("atelier_fiche_monstre_resistances")

	tools.open_sheet(tc)
	await tree.process_frame
	await _scroll_to(tools, "EFFETS", tree)
	await driver._shot("atelier_fiche_carte_effets")

	tools.open_sheet(tl)
	await tree.process_frame
	await _scroll_to(tools, "VAGUES", tree)
	await driver._shot("atelier_vague_editee")

	tools.show_tab("test")
	await tree.process_frame
	await driver._shot("atelier_test")
	await _scroll_to(tools, "JOUER", tree)
	await driver._shot("atelier_test_jouer")

	tools.show_tab("document")
	await tree.process_frame
	var doc: TesterDocTab = null
	for c in tools.body().get_children():
		if c is TesterDocTab:
			doc = c
	if doc == null:
		driver.call("_fail", "atelier : onglet DOCUMENT absent")
	else:
		var chemin: String = doc.export_now(SMOKE_DOC_DIR)
		if chemin == "" or not FileAccess.file_exists(chemin):
			driver.call("_fail", "atelier : export du document impossible")
		await tree.process_frame
		await tree.process_frame
		await driver._shot("atelier_document")
		await _scroll_to(tools, "APERCU", tree)
		await driver._shot("atelier_document_apercu")
		if chemin != "":
			DirAccess.remove_absolute(chemin)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_DOC_DIR))

	# Le selecteur plein ecran, sur la liste la plus longue.
	tools.open_picker("Monstre", TesterField.ref_items("enemy"), func(_id: String) -> void: pass)
	await tree.process_frame
	await driver._shot("atelier_selecteur")
	tools.go_back()
	if tools.picker_open():
		driver.call("_fail", "atelier : le retour ne ferme pas le selecteur")

	tools.queue_free()
	await tree.process_frame
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()
	print("[SMOKE] atelier du testeur construit")


## Fait defiler la page jusqu au titre de groupe (bouton "v  EFFETS"...).
static func _scroll_to(tools: TesterTools, mot: String, tree: SceneTree) -> void:
	await tree.process_frame
	var cible: Control = _find_button(tools.body(), mot)
	if cible == null:
		return
	var scroll: ScrollContainer = tools.body().get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(cible.global_position.y - tools.body().global_position.y)
	await tree.process_frame


static func _find_button(n: Node, mot: String) -> Control:
	if (n is Button and (n as Button).text.contains(mot)) or (n is Label and (n as Label).text == mot):
		return n
	for c in n.get_children():
		var r: Control = _find_button(c, mot)
		if r != null:
			return r
	return null
