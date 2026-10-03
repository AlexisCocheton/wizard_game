extends TestCase
## OUTILS DU TESTEUR (vague 8) — surcharges, document de changement, vague de test.
##
## Ce que ces tests protegent, et pourquoi :
##   - une surcharge s applique ET s annule exactement : les Resources sont
##     partagees, une valeur qui ne reviendrait pas fausserait toutes les parties
##     suivantes, y compris celles du banc ;
##   - eteindre le mode testeur rend le jeu d ORIGINE sans redemarrer : c est la
##     promesse faite au co-auteur sur son telephone de jeu ;
##   - une saisie invalide est ecartee et signalee, jamais appliquee a moitie ;
##   - export -> import redonne le MEME jeu de reglages (aller-retour par le
##     presse-papiers) ;
##   - une vague composee dans l onglet TEST se lance et se termine.
## Aucun nombre d equilibrage ecrit en dur : tout part de la valeur d origine.

const FIXED_DELTA: float = 1.0 / 60.0


func get_suite_name() -> String:
	return "tester_tools"


func run() -> void:
	SaveData.reset_profile()
	TesterOverrides.reset_for_tests()
	_test_surcharge_appliquee_puis_annulee()
	_test_mode_eteint_rend_le_jeu_d_origine()
	_test_rechargement_garde_le_calque()
	_test_validation()
	_test_vagues_de_campagne()
	_test_aller_retour_export_import()
	_test_fichier_du_document()
	_test_document_sur_telephone_copier_d_abord()
	_test_vague_de_test_se_joue()
	_test_atelier_se_construit()
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


func _on() -> void:
	SaveData.reset_profile()
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(true)


func _off() -> void:
	TesterOverrides.reset_for_tests()
	SaveData.set_tester_mode(false)


## Un monstre et une carte a zone pris dans le contenu, pas nommes : le test
## survit a un renommage.
func _un_monstre() -> EnemyDef:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var d: EnemyDef = ContentDB.enemies[id]
		if not d.is_boss() and d.max_hp > 0.0:
			return d
	return null


func _une_carte_a_zone() -> SpellCard:
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if not c.is_passive and c.has_area():
			for e in c.effects:
				if e != null and e.radius > 0.0 and not e.params.is_empty():
					return c
	return null


func _test_surcharge_appliquee_puis_annulee() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	var t: String = TesterOverrides.target_of(d)
	var pv: float = d.max_hp
	var err: String = TesterOverrides.set_override(t, "max_hp", pv * 2.0)
	eq(err, "", "une surcharge de PV valide est acceptee")
	feq(d.max_hp, pv * 2.0, "la Resource PARTAGEE porte la nouvelle valeur")
	feq(float(TesterOverrides.original_value(t, "max_hp")), pv, "l origine reste connue")
	TesterOverrides.remove_override(t, "max_hp")
	feq(d.max_hp, pv, "retirer la surcharge rend la valeur d origine")

	# Resistance : un dictionnaire DamageTag -> facteur, regle par element.
	var feu: float = d.resistance_to(GameEnums.DamageTag.FIRE)
	var voulu: float = 0.0 if feu > 0.0 else 1.0
	eq(TesterOverrides.set_override(t, "resistances/feu", voulu), "", "resistance acceptee")
	feq(d.resistance_to(GameEnums.DamageTag.FIRE), voulu, "la resistance au feu est jouee")
	TesterOverrides.remove_override(t, "resistances/feu")
	feq(d.resistance_to(GameEnums.DamageTag.FIRE), feu, "et revient")

	# Effet d une carte : rayon et parametre libre.
	var c: SpellCard = _une_carte_a_zone()
	ok(c != null, "le catalogue a une carte de zone a parametres")
	if c == null:
		return
	var tc: String = TesterOverrides.target_of(c)
	var i: int = 0
	while c.effects[i] == null or c.effects[i].radius <= 0.0 or c.effects[i].params.is_empty():
		i += 1
	var r: float = c.effects[i].radius
	eq(TesterOverrides.set_override(tc, "effects/%d/radius" % i, r + 50.0), "", "rayon accepte")
	feq(c.effects[i].radius, r + 50.0, "le rayon de l effet est joue")
	var cle: Variant = c.effects[i].params.keys()[0]
	var p: Variant = c.effects[i].params[cle]
	if typeof(p) == TYPE_INT or typeof(p) == TYPE_FLOAT:
		var champ: String = "effects/%d/params/%s" % [i, cle]
		eq(TesterOverrides.set_override(tc, champ, int(p) + 1 if typeof(p) == TYPE_INT
			else float(p) + 1.0), "", "parametre accepte")
		feq(float(c.effects[i].params[cle]), float(p) + 1.0, "le parametre est joue")
		eq(typeof(c.effects[i].params[cle]), typeof(p), "et garde son type")
	# La teinte du sprite passe par AnimCatalog.modulate_for().
	eq(TesterOverrides.set_override(t, "tint", "#ff000080"), "", "teinte acceptee")
	ok(AnimCatalog.modulate_for(d.id).is_equal_approx(Color.html("#ff000080")),
		"la teinte reglee est celle que le jeu applique")
	TesterOverrides.clear_all()
	feq(c.effects[i].radius, r, "tout effacer rend le rayon")
	ok(not AnimCatalog.modulate_for(d.id).is_equal_approx(Color.html("#ff000080")),
		"et la teinte")
	_off()


## LA PROMESSE : eteindre = jeu d origine, sans redemarrer ; rallumer = reglages.
func _test_mode_eteint_rend_le_jeu_d_origine() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	var t: String = TesterOverrides.target_of(d)
	var vitesse: float = d.base_speed
	TesterOverrides.set_override(t, "base_speed", vitesse + 10.0)
	feq(d.base_speed, vitesse + 10.0, "joue en mode testeur")
	SaveData.set_tester_mode(false)
	feq(d.base_speed, vitesse, "eteindre le mode rend la vitesse d origine IMMEDIATEMENT")
	eq(TesterOverrides.count(), 1, "mais le reglage est garde en reserve")
	not_ok(TesterOverrides.is_active(), "le calque se dit inactif")
	SaveData.set_tester_mode(true)
	feq(d.base_speed, vitesse + 10.0, "rallumer rejoue le reglage")
	# Une remise a zero du profil eteint aussi le mode (test_tester_mode).
	SaveData.reset_profile()
	feq(d.base_speed, vitesse, "une remise a zero rend aussi le jeu d origine")
	_off()


## Le cache de Godot rend le MEME objet au rechargement : sans le retour
## arriere avant de rejouer, la valeur d origine relevee serait la surchargee.
func _test_rechargement_garde_le_calque() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	var t: String = TesterOverrides.target_of(d)
	var pv: float = d.max_hp
	TesterOverrides.set_override(t, "max_hp", pv + 7.0)
	ContentDB.reload()
	var d2: EnemyDef = ContentDB.enemies[d.id]
	feq(d2.max_hp, pv + 7.0, "apres ContentDB.reload() le reglage est toujours joue")
	feq(float(TesterOverrides.original_value(t, "max_hp")), pv,
		"et l origine n a pas ete contaminee par le reglage")
	SaveData.set_tester_mode(false)
	ContentDB.reload()
	feq(ContentDB.enemies[d.id].max_hp, pv, "mode eteint, un rechargement rend l origine")
	_off()


func _test_validation() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	var t: String = TesterOverrides.target_of(d)
	var pv: float = d.max_hp
	var refus: Array = [
		[t, "max_hp", -5.0, "PV negatifs"],
		[t, "max_hp", "beaucoup", "PV en texte"],
		[t, "id", "autre", "l id n est pas editable"],
		[t, "champ_qui_n_existe_pas", 1.0, "champ inconnu"],
		["enemy:monstre_inexistant", "max_hp", 10.0, "cible inconnue"],
		[t, "kind", "PasUneFamille", "enum inconnu"],
		[t, "split_into", "monstre_inexistant", "reference inconnue"],
		# « physique » n est plus un element depuis la vague 8 (le vent l est).
		[t, "resistances/physique", 1.0, "element inconnu"],
		[t, "anim_key", "feuille_inexistante", "apparence hors catalogue"],
	]
	for r in refus:
		var err: String = TesterOverrides.set_override(r[0], r[1], r[2])
		ok(err != "", "refuse : %s" % r[3])
		not_ok(TesterOverrides.has_override(r[0], r[1]), "et non garde : %s" % r[3])
	feq(d.max_hp, pv, "aucune saisie refusee n a touche le monstre")
	eq(TesterOverrides.count(), 0, "aucun reglage fantome")
	# Une borne d @export_range prime sur le reste.
	ok(TesterOverrides.set_override(t, "power", 99) != "", "puissance au-dela de l export_range")

	# Import d un document contenant une ligne invalide : elle est ecartee et
	# SIGNALEE, les autres passent.
	var doc: Dictionary = {"format": TesterOverrides.FORMAT, "version": 1, "changements": [
		{"cible": t, "champ": "max_hp", "apres": pv + 1.0},
		{"cible": t, "champ": "max_hp_inexistant", "apres": 3.0},
	]}
	var res: Dictionary = TesterDocument.import_text(JSON.stringify(doc))
	eq(res["error"], "", "le document est lisible")
	eq(int(res["imported"]), 1, "la ligne valide est importee")
	eq((res["rejected"] as Array).size(), 1, "la ligne invalide est signalee")
	feq(d.max_hp, pv + 1.0, "et la valide est jouee")
	ok(TesterDocument.import_text("ceci n est pas un document")["error"] != "",
		"un texte quelconque est refuse sans planter")
	ok(TesterDocument.import_text(JSON.stringify({"format": "autre"}))["error"] != "",
		"un JSON sans la signature est refuse")
	feq(d.max_hp, pv + 1.0, "un import refuse ne touche a rien")
	_off()


func _niveau_a_plusieurs_vagues() -> LevelDef:
	var ids: Array = ContentDB.levels.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var l: LevelDef = ContentDB.levels[id]
		if l.waves.size() >= 3:
			return l
	return null


func _test_vagues_de_campagne() -> void:
	_on()
	var lvl: LevelDef = _niveau_a_plusieurs_vagues()
	ok(lvl != null, "un niveau a au moins trois vagues")
	if lvl == null:
		return
	var t: String = TesterOverrides.target_of(lvl)
	var n: int = lvl.waves.size()
	var avant: Array = []
	for w in lvl.waves:
		avant.append(TesterOverrides.encode_wave(w))

	# Regler la premiere vague : nombre et difficulte.
	var w0: Dictionary = (avant[0] as Dictionary).duplicate(true)
	w0["entries"][0]["count"] = int(w0["entries"][0]["count"]) + 2
	w0["difficulty"] = float(w0["difficulty"]) * 1.5
	eq(TesterOverrides.set_override(t, "waves/0", w0), "", "vague reglee acceptee")
	eq(lvl.waves[0].entries[0].count, int(avant[0]["entries"][0]["count"]) + 2,
		"le nombre de l entree est joue")
	feq(lvl.waves[0].difficulty, float(avant[0]["difficulty"]) * 1.5, "la difficulte aussi")
	ok(lvl.waves[0].entries[0].enemy == ContentDB.enemies.get(
		StringName(String(avant[0]["entries"][0]["enemy"]))),
		"l entree pointe le MEME EnemyDef (une surcharge du monstre s y appliquera)")

	# Ajouter une vague : copie de la derniere, sans drapeau de boss.
	eq(TesterOverrides.set_override(t, "waves/#", n + 1), "", "ajout d une vague accepte")
	eq(lvl.waves.size(), n + 1, "le niveau a une vague de plus")
	not_ok(lvl.waves[n].is_boss, "la vague ajoutee n est pas un second boss")
	ok(lvl.waves[n].entries[0].enemy == lvl.waves[n - 1].entries[0].enemy,
		"la copie partage les EnemyDef au lieu de les dupliquer")
	# Une vague a regler AU-DELA de l origine n existe que grace au "waves/#".
	var w_n: Dictionary = TesterOverrides.encode_wave(lvl.waves[n])
	w_n["duration"] = float(w_n["duration"]) + 5.0
	eq(TesterOverrides.set_override(t, "waves/%d" % n, w_n), "", "la vague ajoutee se regle")

	# Retirer une vague du MILIEU : les suivantes descendent d un cran.
	var enc_suivante: Dictionary = TesterOverrides.encode_wave(lvl.waves[2])
	eq(TesterWaveEditor.remove_wave_of(lvl, 1), "", "retrait d une vague du milieu")
	eq(lvl.waves.size(), n, "une vague de moins")
	ok(TesterOverrides.same_value(TesterOverrides.encode_wave(lvl.waves[1]), enc_suivante),
		"la vague 3 a pris la place de la 2")

	# Une vague sans entree, un monstre inconnu : refuses.
	var vide: Dictionary = (avant[0] as Dictionary).duplicate(true)
	vide["entries"] = []
	ok(TesterOverrides.set_override(t, "waves/0", vide) != "", "une vague vide est refusee")
	var faux: Dictionary = (avant[0] as Dictionary).duplicate(true)
	faux["entries"][0]["enemy"] = "monstre_inexistant"
	ok(TesterOverrides.set_override(t, "waves/0", faux) != "", "un monstre inconnu est refuse")

	TesterOverrides.clear_all()
	eq(lvl.waves.size(), n, "tout effacer rend le nombre de vagues")
	for i in n:
		ok(TesterOverrides.same_value(TesterOverrides.encode_wave(lvl.waves[i]), avant[i]),
			"la vague %d est revenue a l identique" % (i + 1))
	_off()


func _test_aller_retour_export_import() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	var t: String = TesterOverrides.target_of(d)
	var c: SpellCard = _une_carte_a_zone()
	var tc: String = TesterOverrides.target_of(c)
	var lvl: LevelDef = _niveau_a_plusieurs_vagues()
	var tl: String = TesterOverrides.target_of(lvl)
	TesterOverrides.set_override(t, "max_hp", d.max_hp + 3.0)
	TesterOverrides.set_override(t, "flying", not d.flying)
	TesterOverrides.set_override(t, "tint", "#80ff80ff")
	TesterOverrides.set_override(t, "resistances/glace", 0.5)
	var rarete: String = "Rare" if c.rarity != GameEnums.Rarity.RARE else "Epic"
	TesterOverrides.set_override(tc, "rarity", rarete)
	TesterOverrides.set_override(tc, "description", "Texte regle par le testeur")
	TesterOverrides.set_override(tc, "effects/0/magnitude", c.effects[0].magnitude + 1.0)
	var deck: Array = TesterOverrides.current_value(tl, "exploration_deck")
	deck.pop_back()
	TesterOverrides.set_override(tl, "exploration_deck", deck)
	TesterOverrides.set_override(tl, "waves/#", lvl.waves.size() + 1)
	var n1: int = TesterOverrides.count()
	eq(n1, 9, "neuf reglages poses")
	eq(TesterOverrides.rejected().size(), 0, "aucun refuse")

	var doc: String = TesterDocument.build()
	var d1: Dictionary = JSON.parse_string(doc)
	eq(String(d1["format"]), TesterOverrides.FORMAT, "le document porte sa signature")
	for cle in ["version", "jeu", "date", "resume", "changements"]:
		ok(d1.has(cle), "l en-tete porte '%s'" % cle)
	for ch in d1["changements"]:
		for cle in ["cible", "champ", "avant", "apres", "texte"]:
			ok(ch.has(cle), "chaque changement porte '%s'" % cle)
	var pv_ch: Dictionary = {}
	for ch in d1["changements"]:
		if ch["cible"] == t and ch["champ"] == "max_hp":
			pv_ch = ch
	feq(float(pv_ch.get("avant", -1.0)), d.max_hp - 3.0, "l AVANT est la valeur d origine")
	feq(float(pv_ch.get("apres", -1.0)), d.max_hp, "l APRES est la valeur jouee")

	TesterOverrides.clear_all()
	eq(TesterOverrides.count(), 0, "efface")
	var r: Dictionary = TesterDocument.import_text(doc)
	eq(r["error"], "", "le document se relit")
	eq(int(r["imported"]), n1, "tous les reglages reviennent")
	var d2: Dictionary = JSON.parse_string(TesterDocument.build())
	ok(TesterOverrides.same_value(d1["changements"], d2["changements"]),
		"export -> import -> export : les changements sont IDENTIQUES")
	TesterOverrides.clear_all()
	_off()


func _test_fichier_du_document() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	TesterOverrides.set_override(TesterOverrides.target_of(d), "max_hp", d.max_hp + 1.0)
	var dossier: String = "user://tester_tools_test"
	var chemin: String = TesterDocument.write_file(dossier)
	ok(chemin != "" and FileAccess.file_exists(chemin), "le document est ecrit dans user://")
	if chemin != "":
		var relu: Dictionary = TesterDocument.parse(FileAccess.get_file_as_string(chemin))
		eq(relu["error"], "", "et se relit")
		eq((relu["entries"] as Array).size(), 1, "avec son reglage")
		DirAccess.remove_absolute(chemin)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dossier))
	_off()


func _test_vague_de_test_se_joue() -> void:
	_on()
	var comp: Dictionary = TesterRun.default_composition()
	var lvl: LevelDef = TesterRun.make_level(comp)
	not_ok(ContentDB.levels.has(lvl.id), "le niveau de test n est PAS dans ContentDB")
	eq(lvl.waves.size(), 1, "une seule vague")
	ok(not lvl.exploration_deck.is_empty(), "avec un deck")
	ok(TesterRun.is_test_payload({TesterRun.PAYLOAD_KEY: comp}), "la charge utile se reconnait")
	not_ok(TesterRun.end_run(ContentDB.levels.values()[0], true),
		"une partie de campagne suit sa route normale")
	eq(TesterRun.problems({"entries": [], "cards": []}).size(), 2,
		"une composition vide dit ce qui manque")

	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	# La vitesse de depart demandee est posee APRES start_level (qui remet la
	# jauge a neuf) : on en demande une autre que celle du jeu pour que le test
	# distingue les deux.
	var voulue: int = mini(GameConfig.SPEED_START_PERCENT + 100, GameConfig.SPEED_MAX_PERCENT)
	comp["speed"] = voulue
	comp["seed"] = 4242
	TesterRun.start_in(g, {TesterRun.PAYLOAD_KEY: comp})
	g.running = false
	eq(SpeedGauge.speed_percent, voulue, "la vitesse de depart composee est appliquee")
	eq(g.level_def.id, TesterRun.LEVEL_ID, "la partie joue le niveau fabrique")
	var gagne: Array = [false]
	var perdu: Array = [false]
	g.level_won.connect(func() -> void: gagne[0] = true)
	g.level_lost.connect(func() -> void: perdu[0] = true)
	var pas: int = 0
	while pas < 60 * 240 and not gagne[0] and not perdu[0]:
		_autoplay(g)
		g.simulate(FIXED_DELTA)
		pas += 1
	ok(gagne[0], "la vague de test se termine par une victoire (%d pas)" % pas)
	RunState.pending_offer.clear()
	detach(g)
	_off()


## Comme le SMOKE : on achieve ce qui approche et on joue la premiere carte.
func _autoplay(g: GameController) -> void:
	if not RunState.pending_offer.is_empty():
		g.choose_card(0)
		return
	var bf: Battlefield = g.battlefield
	bf.shots.clear()
	for e in bf.enemies.duplicate():
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		if e.position.y > GameConfig.MAGE_LINE_Y - 500.0:
			e.take_damage(9999.0, [])
	if not g.caster.is_busy() and not RunState.hand.is_empty():
		g.play_card(RunState.hand[0], Vector2(540.0, 900.0))


func _boutons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_boutons(c, out)


func _champs(n: Node, out: Array) -> void:
	if n is TesterField:
		out.append(n)
	for c in n.get_children():
		_champs(c, out)


## L ecran se construit sur chaque onglet et chaque genre de fiche, les cibles
## tactiles font au moins 90 px, et une valeur touchee devient un reglage.
func _test_atelier_se_construit() -> void:
	_on()
	SceneRouter.payload = {}
	var scene: PackedScene = load(TesterRun.TOOLS_SCENE)
	var tools: TesterTools = scene.instantiate()
	attach(tools)
	for t in TesterTools.TABS:
		tools.show_tab(t[0])
		eq(tools.current_tab(), t[0], "l onglet %s s ouvre" % t[0])
		ok(tools.body().get_child_count() > 0, "l onglet %s a du contenu" % t[0])
	tools.show_tab("monstres")
	var total: int = tools.visible_rows()
	eq(total, ContentDB.enemies.size(), "la liste montre TOUS les monstres")
	var d: EnemyDef = _un_monstre()
	tools.filter_rows(String(d.id))
	ok(tools.visible_rows() >= 1 and tools.visible_rows() < total, "la recherche filtre")

	var cibles: Array = [TesterOverrides.target_of(d),
		TesterOverrides.target_of(_une_carte_a_zone()),
		TesterOverrides.target_of(_niveau_a_plusieurs_vagues())]
	for cible in cibles:
		tools.open_sheet(cible)
		eq(tools.current_detail(), cible, "la fiche %s s ouvre" % cible)
		var champs: Array = []
		_champs(tools.body(), champs)
		ok(champs.size() >= 5, "la fiche %s porte des champs (%d)" % [cible, champs.size()])
		var boutons: Array = []
		_boutons(tools.body(), boutons)
		var petits: Array = []
		for b: Button in boutons:
			if b.get_combined_minimum_size().y < TesterField.TOUCH:
				petits.append(b.text)
		eq(petits.size(), 0, "fiche %s : toutes les cibles tactiles >= %d px %s"
			% [cible, int(TesterField.TOUCH), str(petits.slice(0, 3))])

	# Toucher "+" sur les PV : la valeur devient un reglage.
	tools.open_sheet(TesterOverrides.target_of(d))
	var pv_avant: float = d.max_hp
	var champs2: Array = []
	_champs(tools.body(), champs2)
	var pv: TesterField = null
	for f: TesterField in champs2:
		if f.field == "max_hp":
			pv = f
	ok(pv != null, "la fiche du monstre a un champ PV")
	if pv != null:
		pv.commit(pv_avant + 1.0)
		feq(d.max_hp, pv_avant + 1.0, "regler depuis la fiche change le monstre en jeu")
		pv.revert()
		feq(d.max_hp, pv_avant, "le bouton ORIGINE le rend")

	tools.open_picker("test", TesterField.ref_items("enemy"), func(_id: String) -> void: pass)
	ok(tools.picker_open(), "le selecteur plein ecran s ouvre")
	tools.close_picker()
	detach(tools)

	# L entree depuis les Reglages : presente en mode testeur, absente sinon.
	var reglages := SettingsPanel.new()
	attach(reglages)
	var entree: Node = reglages.find_child("TesterToolsButton", true, false)
	ok(entree != null, "mode testeur allume : les Reglages ouvrent l atelier")
	if entree != null:
		ok((entree as Button).custom_minimum_size.y >= TesterField.TOUCH,
			"le bouton de l atelier est une cible tactile")
		not_ok((entree as Button).text.to_lower().contains("testeur"),
			"son libelle ne se confond pas avec l interrupteur du mode")
	detach(reglages)
	SaveData.set_tester_mode(false)
	reglages = SettingsPanel.new()
	attach(reglages)
	ok(reglages.find_child("TesterToolsButton", true, false) == null,
		"mode eteint : pas d atelier")
	detach(reglages)
	_off()


## LE DOCUMENT SUR TELEPHONE (audit vague 9). EXPORTER ecrivait dans
## user://changements, un dossier PRIVE sur Android, et l ecran affichait un
## chemin /data/... inutilisable. Sur mobile : COPIER est la voie, en tete, avec
## le mode d emploi (« colle-le dans un message »), aucun bouton d export ni
## chemin de fichier. Sur PC : EXPORTER et COPIER, comme avant.
func _test_document_sur_telephone_copier_d_abord() -> void:
	_on()
	var d: EnemyDef = _un_monstre()
	TesterOverrides.set_override(TesterOverrides.target_of(d), "max_hp", d.max_hp + 1.0)
	var tab: TesterDocTab = TesterDocTab.new()
	attach(tab)
	tab.setup(null)
	# Le harnais tourne sur PC : la presentation par defaut garde l export.
	eq(tab.mobile, TesterDocTab.is_mobile_os(), "la presentation suit l OS par defaut")

	tab.set_mobile(true)
	var copier: Button = tab.find_child("CopyButton", true, false) as Button
	ok(copier != null, "telephone : un bouton COPIER")
	eq(tab.find_child("ExportButton", true, false), null, "telephone : pas de bouton EXPORTER")
	var boutons: Array = []
	_boutons(tab, boutons)
	if copier != null:
		eq(boutons.find(copier), 0, "telephone : COPIER est le PREMIER bouton de l ecran")
		ok(copier.get_combined_minimum_size().y >= TesterField.TOUCH, "COPIER se touche")
		for b: Button in boutons:
			ok(copier.get_combined_minimum_size().y >= b.get_combined_minimum_size().y,
				"COPIER est au moins aussi grand que %s" % b.text)
	for b: Button in boutons:
		not_ok(b.text.to_upper().contains("EXPORT") or b.text.to_upper().contains("DOSSIER"),
			"telephone : aucun bouton d export ni de dossier (%s)" % b.text)
	var aide: Label = tab.find_child("DocMessage", true, false) as Label
	ok(aide != null and aide.text.to_lower().contains("message"),
		"telephone : le mode d emploi dit de le coller dans un message")
	ok(tab.find_child("NoExportNote", true, false) != null, "telephone : l absence d export est expliquee")
	# La copie : le presse-papiers recoit le document, le message dit quoi faire.
	tab.copy_now()
	# Le presse-papiers n existe pas en headless : on ne le relit qu en fenetre.
	if DisplayServer.get_name() != "headless":
		ok(TesterDocument.parse(DisplayServer.clipboard_get())["error"] == "",
			"COPIER met le document dans le presse-papiers")
	tab._build()
	aide = tab.find_child("DocMessage", true, false) as Label
	ok(aide != null and aide.text.to_lower().contains("colle"),
		"apres la copie : « colle-le » (%s)" % (aide.text if aide != null else "absent"))
	for l in _labels(tab):
		not_ok(l.text.contains("user://") or l.text.contains("/data/"),
			"telephone : aucun chemin de fichier a l ecran (%s)" % l.text)

	tab.set_mobile(false)
	ok(tab.find_child("ExportButton", true, false) != null, "PC : EXPORTER reste")
	ok(tab.find_child("CopyButton", true, false) != null, "PC : COPIER reste")
	detach(tab)
	TesterOverrides.clear_all()
	_off()


func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out
