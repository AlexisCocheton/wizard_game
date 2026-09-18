extends TestCase
## Donnees derriere le menu : decouverte, deck, campagne, victoire, reglages.
## Tout se passe en memoire : la persistance est coupee en headless.

func get_suite_name() -> String:
	return "menu_data"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_persistance_coupee()
	_test_cartes_de_depart_decouvertes()
	_test_deck_massacre()
	_test_reglages()
	_test_victoire_debloque_le_niveau_suivant()
	_test_legendaire_cumulative()
	_test_niveau_courant()
	_test_deck_exploration_contient_le_mur()
	_test_deck_explicite_conserve_les_exemplaires()
	_test_seuls_les_niveaux_debloques_sont_jouables()
	_test_le_hud_reste_actif_en_pause()
	# Etat propre pour les suites suivantes.
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _test_persistance_coupee() -> void:
	not_ok(SaveData.persistence_enabled, "en headless, le vrai profil n est jamais touche")


func _test_cartes_de_depart_decouvertes() -> void:
	ok(SaveData.is_discovered(&"arcane_bolt"), "les communes de depart sont decouvertes")
	not_ok(SaveData.is_discovered(&"time_rift"), "la legendaire ne l est pas")
	ok(SaveData.discovered_count() >= 4, "au moins les 4 communes")


func _test_deck_massacre() -> void:
	eq(SaveData.massacre_deck().size(), 0, "aucun deck au depart")
	SaveData.set_massacre_deck([&"arcane_bolt", &"arcane_bolt", "frost_field"])
	var ids: Array = SaveData.massacre_deck()
	eq(ids.size(), 3, "le deck est memorise avec ses doublons")
	eq(ids[0], "arcane_bolt", "les ids sont stockes en String")


func _test_reglages() -> void:
	SaveData.set_setting("master_volume", 0.25)
	feq(float(SaveData.get_setting("master_volume", 1.0)), 0.25, "reglage relu")
	eq(SaveData.get_setting("cle_inconnue", "defaut"), "defaut", "cle absente -> defaut")


func _test_victoire_debloque_le_niveau_suivant() -> void:
	SaveData.reset_profile()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(lvl1 != null, "lvl_01 existe")
	ok(SaveData.is_level_unlocked(&"lvl_01"), "le niveau 1 est ouvert d office")
	not_ok(SaveData.is_level_unlocked(&"lvl_02"), "le niveau 2 est verrouille au depart")

	var newly: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION, {}, 6)
	not_ok(newly, "sans objectif, pas de legendaire")
	ok(SaveData.is_level_cleared(&"lvl_01"), "le niveau 1 est marque termine")
	ok(SaveData.is_level_unlocked(&"lvl_02"), "la victoire debloque le niveau 2")
	eq(int(SaveData.level_record(&"lvl_01").get("best_wave", 0)), 6, "meilleure vague enregistree")

	SaveData.record_victory(lvl1, GameEnums.Mode.MASSACRE, {}, 3)
	eq(int(SaveData.level_record(&"lvl_01").get("best_wave", 0)), 6, "la meilleure vague ne regresse pas")
	ok(bool(SaveData.level_record(&"lvl_01").get("cleared_massacre", false)), "massacre marque aussi")


## Les objectifs s accumulent d un run a l autre : 2 puis 1 = les 3.
func _test_legendaire_cumulative() -> void:
	SaveData.reset_profile()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var ids: Array[StringName] = []
	for o in lvl1.objectives:
		ids.append(o.id)
	eq(ids.size(), 3, "3 objectifs sur le niveau 1")

	var first: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[0]: true, ids[1]: true, ids[2]: false}, 6)
	not_ok(first, "2 objectifs sur 3 : pas encore la legendaire")
	eq(SaveData.objectives_done_count(lvl1), 2, "2 objectifs acquis")

	var second: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[2]: true}, 6)
	ok(second, "le 3e objectif, meme sur un autre run, debloque la legendaire")
	ok(SaveData.is_discovered(lvl1.legendary_reward.id), "la legendaire est decouverte")
	ok(SaveData.unlocked_legendaries().has(String(lvl1.legendary_reward.id)), "et listee")

	var third: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[0]: true, ids[1]: true, ids[2]: true}, 6)
	not_ok(third, "deja obtenue : pas signalee comme nouvelle")


func _test_niveau_courant() -> void:
	SaveData.set_current_level(&"lvl_02")
	eq(SaveData.current_level(), &"lvl_02", "le niveau courant est memorise")


## Regression : le mur avait copies_in_starter = 0 et n entrait jamais dans le deck.
func _test_deck_exploration_contient_le_mur() -> void:
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var murs: int = 0
	for c in lvl1.exploration_deck:
		if c != null and c.id == &"stone_wall":
			murs += 1
	ok(murs >= 1, "le Mur de pierre est bien dans le deck d exploration (%d ex.)" % murs)
	ok(lvl1.exploration_deck.size() >= DeckRules.MIN_CARDS,
		"le deck pre-etabli est jouable (%d cartes)" % lvl1.exploration_deck.size())


func _test_deck_explicite_conserve_les_exemplaires() -> void:
	RunState.reset()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	RunState.build_deck_from_list(lvl1.exploration_deck)
	eq(RunState.total_cards(), lvl1.exploration_deck.size(),
		"une entree de la liste = un exemplaire dans le deck")
	var murs_en_jeu: int = 0
	for c in RunState.deck:
		if c.id == &"stone_wall":
			murs_en_jeu += 1
	ok(murs_en_jeu >= 1, "le mur est piochable en partie")


## Un niveau verrouille ne doit pas etre jouable : le niveau 2 etait accessible
## avant d avoir termine le 1, la campagne listait tout sans filtrer.
func _test_seuls_les_niveaux_debloques_sont_jouables() -> void:
	SaveData.reset_profile()
	var jouables: Array[LevelDef] = SaveData.playable_levels()
	ok(jouables.size() >= 1, "au moins un niveau est jouable sur un profil neuf")
	for lv in jouables:
		ok(SaveData.is_level_unlocked(lv.id),
			"%s est bien debloque" % lv.id)
	var total: int = ContentDB.levels.size()
	ok(jouables.size() < total or total == 1,
		"tous les niveaux ne sont pas offerts d emblee")

	# Apres la victoire sur le niveau 1, le niveau 2 devient jouable.
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	if l1 != null and not l1.next_levels.is_empty():
		var suivant: StringName = l1.next_levels[0]
		not_ok(SaveData.is_level_unlocked(suivant), "le niveau suivant est verrouille au depart")
		SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {}, 6)
		ok(SaveData.is_level_unlocked(suivant), "il se debloque a la victoire")
		var apres: Array[LevelDef] = SaveData.playable_levels()
		eq(apres.size(), jouables.size() + 1, "la campagne propose un niveau de plus")
	SaveData.reset_profile()


## Le bouton pause doit pouvoir RELANCER la partie. Le HUD etait mis en pause avec
## le jeu : un seul clic figeait tout, y compris le moyen de repartir.
func _test_le_hud_reste_actif_en_pause() -> void:
	var packed: PackedScene = load("res://scenes/hud/HUD.tscn")
	ok(packed != null, "la scene du HUD existe")
	if packed == null:
		return
	var hud: Node = packed.instantiate()
	# Le mode est pose dans _ready() : on l appelle via l arbre.
	Engine.get_main_loop().root.add_child(hud)
	eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"le HUD continue de tourner quand l arbre est en pause")
	hud.queue_free()
