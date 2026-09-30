extends TestCase
## Les trois modes de jeu (chantier M, 29/09) :
##   EXPLORATION : le niveau de campagne ;
##   INFINITE    : "INFINI", un niveau prolonge sans fin a travers les mondes ;
##   MASSACRE    : l onglet du menu, un niveau infini A PART (MassacreMode).
##
## Ce qui est verrouille ici, c est ce qui casserait sans bruit : un renommage
## qui decale la valeur entiere d un mode, l Infini de nouveau cache derriere la
## fin de la campagne, un Massacre qui ne tirerait que dans un monde ou qu un
## seul boss, un record range au mauvais endroit.

func get_suite_name() -> String:
	return "modes"


func run() -> void:
	SaveData.reset_profile()
	_test_valeurs_et_noms_des_modes()
	_test_la_fiche_de_niveau_propose_exploration_et_infini()
	_test_l_infini_s_ouvre_sans_finir_la_campagne()
	_test_le_massacre_s_ouvre_a_la_fin_de_la_campagne()
	_test_le_pool_du_massacre_couvre_tous_les_niveaux()
	_test_le_massacre_melange_les_mondes_en_jouant()
	_test_les_boss_de_tout_le_jeu_aux_paliers()
	_test_la_partie_installe_chaque_mode()
	_test_le_bandeau_de_monde()
	_test_record_par_mode()
	_test_le_record_suit_la_partie()
	_test_la_defaite_range_le_record_du_massacre()
	_test_le_briefing_du_massacre()
	SaveData.reset_profile()
	RunState.reset()


## INFINITE garde la valeur de l ancien MASSACRE (mode infini par niveau), le
## nouveau MASSACRE ferme la liste. C est une regle de COMPATIBILITE, pas un
## reglage : une valeur retenue ailleurs doit garder son sens.
func _test_valeurs_et_noms_des_modes() -> void:
	eq(int(GameEnums.Mode.EXPLORATION), 0, "l Exploration reste la valeur 0")
	eq(int(GameEnums.Mode.INFINITE), 1,
		"l Infini reprend la valeur de l ancien Massacre par niveau")
	eq(int(GameEnums.Mode.MASSACRE), GameEnums.Mode.size() - 1,
		"le nouveau Massacre est ajoute EN FIN d enum")
	eq(GameEnums.mode_name(GameEnums.Mode.INFINITE), "Infini", "l Infini s ecrit Infini")
	eq(GameEnums.mode_name(GameEnums.Mode.MASSACRE), "Massacre", "le Massacre s ecrit Massacre")
	eq(GameEnums.mode_name(GameEnums.Mode.EXPLORATION), "Exploration",
		"l Exploration garde son nom")
	not_ok(GameEnums.is_endless(GameEnums.Mode.EXPLORATION), "l Exploration a une fin")
	ok(GameEnums.is_endless(GameEnums.Mode.INFINITE), "l Infini est sans fin")
	ok(GameEnums.is_endless(GameEnums.Mode.MASSACRE), "le Massacre est sans fin")


## Decision 1 et 2 : la fiche garde EXPLORATION, le second bouton s appelle
## INFINI (plus MASSACRE).
func _test_la_fiche_de_niveau_propose_exploration_et_infini() -> void:
	SaveData.reset_profile()
	var p := CampaignPanel.new()
	attach(p)
	p.open_level(&"lvl_01")
	var noms: Array[String] = p.mode_labels()
	eq(noms, ["EXPLORATION", "INFINI"] as Array[String],
		"la fiche propose EXPLORATION et INFINI (%s)" % str(noms))
	not_ok(noms.has("MASSACRE"), "le mot MASSACRE a quitte la fiche de niveau")
	detach(p)


## L Infini d un niveau s ouvre avec le NIVEAU, pas a la fin de la campagne.
func _test_l_infini_s_ouvre_sans_finir_la_campagne() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	not_ok(SaveData.campaign_cleared(), "profil neuf : la campagne n est pas finie")
	ok(SaveData.infinite_unlocked(&"lvl_01"), "l Infini du niveau 1 est ouvert d office")
	not_ok(SaveData.infinite_unlocked(&"lvl_02"),
		"l Infini d un niveau verrouille reste ferme")
	not_ok(SaveData.infinite_unlocked(MassacreMode.LEVEL_ID),
		"le Massacre n est pas un niveau dont on ouvrirait l Infini")

	var p := CampaignPanel.new()
	attach(p)
	p.open_level(&"lvl_01")
	ok(p.infinite_available(), "le bouton INFINI est actif sans avoir fini le jeu")
	p.select_mode(GameEnums.Mode.INFINITE)
	eq(p.current_mode(), GameEnums.Mode.INFINITE, "le mode INFINI reste selectionne")
	ok(p.play_enabled(), "avec un deck valide, JOUER est actif en Infini")
	detach(p)

	# Debloquer le niveau 2 (victoire au 1) ouvre SON Infini.
	SaveData.record_victory(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION, {}, 6)
	ok(SaveData.infinite_unlocked(&"lvl_02"), "gagner le niveau 1 ouvre l Infini du niveau 2")
	not_ok(SaveData.campaign_cleared(), "et la campagne n est toujours pas finie")
	SaveData.reset_profile()


## Le Massacre (onglet) s ouvre a la FIN DE LA CAMPAGNE, et pas avant (retouche
## du co-auteur, 30/09). L onglet reste visible et dit ce qui l ouvre.
func _test_le_massacre_s_ouvre_a_la_fin_de_la_campagne() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	not_ok(SaveData.massacre_unlocked(), "profil neuf : le Massacre est ferme")
	var panneau := MassacrePanel.new()
	attach(panneau)
	not_ok(panneau.can_play(), "JOUER est coupe tant que la campagne n est pas finie")
	ok(panneau.lock_shown(), "le bandeau du verrou est affiche")
	# Tous les niveaux sauf UN : toujours ferme, et la raison dit le chemin.
	var niveaux: Array = ContentDB.levels.values()
	for i in niveaux.size() - 1:
		SaveData.record_victory(niveaux[i], GameEnums.Mode.EXPLORATION, {}, 6)
	not_ok(SaveData.massacre_unlocked(), "il reste un niveau : le Massacre reste ferme")
	panneau.refresh()
	not_ok(panneau.can_play(), "JOUER reste coupe")
	var raison: String = MassacrePanel.block_reason()
	ok(raison.contains("campagne"), "la raison nomme la campagne (%s)" % raison)
	ok(raison.contains("%d / %d" % [niveaux.size() - 1, niveaux.size()]),
		"et le chemin qui reste, en chiffres lus dans la sauvegarde (%s)" % raison)
	# Le dernier niveau fini ouvre le Massacre.
	SaveData.record_victory(niveaux[niveaux.size() - 1], GameEnums.Mode.EXPLORATION, {}, 6)
	ok(SaveData.campaign_cleared(), "la campagne est finie")
	ok(SaveData.massacre_unlocked(), "et le Massacre s ouvre")
	panneau.refresh()
	ok(panneau.can_play(), "JOUER s active, deck valide")
	not_ok(panneau.lock_shown(), "le bandeau du verrou disparait")
	eq(MassacrePanel.block_reason(), "", "plus aucune raison de refus")
	# L Infini, lui, n a pas attendu : il s ouvrait niveau par niveau.
	for lv: LevelDef in niveaux:
		ok(SaveData.infinite_unlocked(lv.id), "l Infini de %s est ouvert" % lv.id)
	# Un deck invalide coupe JOUER avec la raison du deck, pas celle du verrou.
	SaveData.set_massacre_deck([])
	panneau.refresh()
	not_ok(panneau.can_play(), "deck vide : JOUER est coupe")
	eq(MassacrePanel.block_reason(), DeckRules.validation_message([]),
		"la raison affichee est celle des regles de deck")
	ok(MassacrePanel.rule_text().contains(str(GameController.WAVES_PER_CHOICE)),
		"la regle en une phrase cite la vraie cadence des choix")
	detach(panneau)
	SaveData.reset_profile()


## Les monstres du Massacre = ceux de TOUS les niveaux (pool et vagues ecrites),
## ni boss ni projectile.
func _test_le_pool_du_massacre_couvre_tous_les_niveaux() -> void:
	var pool: Array[EnemyDef] = MassacreMode.enemy_pool()
	var ids: Dictionary = {}
	for d in pool:
		ids[d.id] = true
		not_ok(d.is_boss(), "%s : un boss n est pas une troupe du Massacre" % d.id)
		not_ok(d.projectile, "%s : un projectile ne descend pas en vague" % d.id)
	eq(ids.size(), pool.size(), "aucun doublon dans le pool")
	var manquants: Array[String] = []
	var niveaux: int = 0
	for level_id in ContentDB.levels.keys():
		var lvl: LevelDef = ContentDB.levels.get(level_id)
		niveaux += 1
		var attendus: Array[EnemyDef] = []
		attendus.append_array(lvl.enemy_pool)
		for w: WaveDef in lvl.waves:
			for e: WaveEntry in w.entries:
				attendus.append(e.enemy)
		for d: EnemyDef in attendus:
			if d == null or d.is_boss() or d.projectile:
				continue
			if not ids.has(d.id) and not manquants.has(String(d.id)):
				manquants.append(String(d.id))
	ok(niveaux > 1, "la campagne compte plusieurs niveaux")
	eq(manquants.size(), 0, "tous les monstres de tous les niveaux sont dans le pool (%s)"
		% ", ".join(manquants))
	# Le pool du Massacre depasse celui de n importe quel niveau seul : c est
	# toute la difference avec l Infini.
	for level_id in ContentDB.levels.keys():
		var lvl2: LevelDef = ContentDB.levels.get(level_id)
		ok(pool.size() > lvl2.enemy_pool.size(),
			"le Massacre tire plus large que %s" % level_id)


## "JOUER des vagues" (lecon des monstres injoignables) : on genere de vraies
## vagues du Massacre et on verifie que chaque monde y envoie des monstres.
func _test_le_massacre_melange_les_mondes_en_jouant() -> void:
	var pool: Array[EnemyDef] = MassacreMode.enemy_pool()
	var membres: Dictionary = WaveSpawner.build_membership()
	var mondes_du_pool: Dictionary = {}
	for d in pool:
		if membres.has(d.id):
			mondes_du_pool[int(membres[d.id])] = true
	ok(mondes_du_pool.size() > 1, "le pool couvre plusieurs mondes (%d)" % mondes_du_pool.size())

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var vus: Dictionary = {}
	var vague_melee: bool = false
	# Tirage SANS appartenance (membership vide) : c est ce que fait le
	# Massacre, aucun lieu ne pese.
	for n in range(1, 61):
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, MassacreMode.boss_pool(), {})
		var dans_la_vague: Dictionary = {}
		for e: WaveEntry in w.entries:
			if e.enemy == null or e.enemy.is_boss() or not membres.has(e.enemy.id):
				continue
			vus[int(membres[e.enemy.id])] = true
			dans_la_vague[int(membres[e.enemy.id])] = true
		if dans_la_vague.size() > 1:
			vague_melee = true
	eq(vus.size(), mondes_du_pool.size(),
		"soixante vagues de Massacre envoient des monstres de chacun des %d mondes"
		% mondes_du_pool.size())
	ok(vague_melee, "au moins une vague melange des monstres de mondes differents")


## Paliers du Massacre : les boss ET mini-boss de tout le jeu, et tous sortent.
func _test_les_boss_de_tout_le_jeu_aux_paliers() -> void:
	var boss: Array[EnemyDef] = MassacreMode.boss_pool()
	var attendus: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d.is_boss():
			attendus[d.id] = true
	eq(boss.size(), attendus.size(), "le pool de paliers contient tous les boss du jeu")
	var genres: Dictionary = {}
	for d in boss:
		ok(attendus.has(d.id), "%s est bien un boss du catalogue" % d.id)
		genres[d.kind] = true
	ok(genres.has(GameEnums.EnemyKind.BOSS) and genres.has(GameEnums.EnemyKind.MINIBOSS),
		"boss et mini-boss sont tous deux dans le pool")

	# Sans monde (world = -1), pick_boss rendait le PREMIER candidat : un seul
	# boss a tous les paliers. On tire les paliers et on exige que CHACUN sorte.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var sortis: Dictionary = {}
	var pool: Array[EnemyDef] = MassacreMode.enemy_pool()
	var n: int = 0
	var garde: int = 0
	while sortis.size() < attendus.size() and garde < 4000:
		garde += 1
		n += 1
		if not (WaveBudget.is_boss_wave(n) or WaveBudget.is_miniboss_wave(n)):
			continue
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, boss, {})
		for e: WaveEntry in w.entries:
			if e.enemy != null and e.enemy.is_boss():
				sortis[e.enemy.id] = true
	var absents: Array[String] = []
	for id in attendus:
		if not sortis.has(id):
			absents.append(String(id))
	eq(absents.size(), 0, "chaque boss du jeu sort a un palier du Massacre (absents : %s)"
		% ", ".join(absents))


## GameController installe chaque mode : pool, paliers, mondes, fond.
func _test_la_partie_installe_chaque_mode() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var g: GameController = _partie()

	g.start_level(MassacreMode.level_def(), GameEnums.Mode.MASSACRE)
	g.running = false
	eq(RunState.mode, GameEnums.Mode.MASSACRE, "RunState connait le mode Massacre")
	ok(g.spawner.procedural, "le Massacre genere ses vagues")
	not_ok(g.spawner.worlds_enabled, "le Massacre n a pas de mondes")
	eq(g.spawner.membership.size(), 0, "aucune appartenance : aucun lieu ne pese")
	eq(g.spawner.pool.size(), MassacreMode.enemy_pool().size(),
		"les troupes sont celles de tous les niveaux")
	eq(g.spawner.bosses.size(), MassacreMode.boss_pool().size(),
		"les paliers tirent dans tous les boss du jeu")
	eq(RunState.current_level_def.backdrop, MassacreMode.BACKDROP,
		"le fond du Massacre est le sien")
	ok(RunState.total_cards() >= DeckRules.MIN_CARDS, "le deck du joueur est distribue")
	var annonces: Array[int] = [0]
	var compte := func(_i: int, _k: String, _n: String) -> void: annonces[0] += 1
	g.spawner.world_changed.connect(compte)
	for i in WaveBudget.WORLD_EVERY * 2 + 1:
		g.spawner.start_next()
	eq(annonces[0], 0, "le Massacre ne change jamais de monde")
	g.spawner.world_changed.disconnect(compte)

	var lvl: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(lvl, GameEnums.Mode.INFINITE)
	g.running = false
	ok(g.spawner.worlds_enabled, "l Infini traverse les mondes")
	ok(g.spawner.membership.size() > 0, "l Infini rattache les monstres a leur monde")
	eq(g.spawner.pool.size(), _sans_boss(lvl.enemy_pool),
		"l Infini garde les monstres du niveau")
	annonces[0] = 0
	g.spawner.world_changed.connect(compte)
	for i in WaveBudget.WORLD_EVERY * 2:
		g.spawner.start_next()
	ok(annonces[0] >= 2, "l Infini annonce ses changements de monde (%d)" % annonces[0])
	g.spawner.world_changed.disconnect(compte)
	detach(g)
	SaveData.reset_profile()


## Le NOM du monde s affiche en Infini quand il change, jamais en Massacre.
func _test_le_bandeau_de_monde() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var g: GameController = _partie()
	var hud: Node = g.get_node_or_null("HUD")
	ok(hud != null, "la partie a un HUD")
	if hud == null:
		detach(g)
		return
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.INFINITE)
	g.running = false
	eq(hud.call("world_banner_text"), WaveBudget.world_name_for(1),
		"la premiere vague de l Infini annonce son monde")
	# On avance jusqu au monde suivant : le bandeau doit en changer.
	for i in WaveBudget.WORLD_EVERY:
		g.spawner.start_next()
	eq(hud.call("world_banner_text"), WaveBudget.world_name_for(WaveBudget.WORLD_EVERY + 1),
		"le bandeau suit le changement de monde")
	ok(String(hud.call("world_subtitle", 1, 2)).contains("2"),
		"un deuxieme passage dit son tour")

	# Un Massacre qui annoncerait un monde mentirait : tout est melange.
	hud.call("hide_world_banner")
	g.start_level(MassacreMode.level_def(), GameEnums.Mode.MASSACRE)
	g.running = false
	for i in WaveBudget.WORLD_EVERY + 1:
		g.spawner.start_next()
	eq(String(hud.call("world_banner_text")), "",
		"le Massacre n affiche aucun bandeau de monde")
	detach(g)
	SaveData.reset_profile()


## Un record par mode, qui ne regresse pas et qui survit a la sauvegarde.
func _test_record_par_mode() -> void:
	SaveData.reset_profile()
	var l1: StringName = &"lvl_01"
	ok(SaveData.record_run_waves(l1, GameEnums.Mode.INFINITE, 5), "premier record Infini")
	eq(SaveData.infinite_best_wave(l1), 5, "le record Infini est lu")
	eq(int(SaveData.level_record(l1).get("best_wave", 0)), 0,
		"le record Infini ne se melange pas a celui de l Exploration")
	not_ok(SaveData.record_run_waves(l1, GameEnums.Mode.INFINITE, 3),
		"une partie moins longue n est pas un record")
	eq(SaveData.infinite_best_wave(l1), 5, "le record Infini ne regresse pas")
	eq(SaveData.infinite_best_wave(&"lvl_02"), 0, "le record Infini est PAR niveau")

	ok(SaveData.record_run_waves(MassacreMode.LEVEL_ID, GameEnums.Mode.MASSACRE, 7),
		"premier record Massacre")
	eq(SaveData.massacre_best_wave(), 7, "le record Massacre est lu")
	not_ok(SaveData.record_run_waves(MassacreMode.LEVEL_ID, GameEnums.Mode.MASSACRE, 2),
		"le record Massacre ne regresse pas")
	not_ok((SaveData.profile().get("levels", {}) as Dictionary).has(String(MassacreMode.LEVEL_ID)),
		"le Massacre n a pas de fiche de niveau fantome")

	# La sauvegarde : un aller-retour par le dictionnaire du profil.
	var brut: Dictionary = SaveData.to_dictionary()
	SaveData.reset_profile()
	eq(SaveData.massacre_best_wave(), 0, "profil remis a zero")
	SaveData.load_from_dictionary(brut)
	eq(SaveData.massacre_best_wave(), 7, "le record Massacre survit a la sauvegarde")
	eq(SaveData.infinite_best_wave(l1), 5, "le record Infini survit a la sauvegarde")

	# Un profil d avant le chantier n a pas la cle : il se charge a zero.
	var ancien: Dictionary = SaveData.to_dictionary()
	(ancien["profile"] as Dictionary).erase("massacre_best_wave")
	SaveData.load_from_dictionary(ancien)
	eq(SaveData.massacre_best_wave(), 0, "un ancien profil se charge sans record Massacre")
	SaveData.reset_profile()


## Le record avance PENDANT la partie, a chaque vague nettoyee : un abandon par
## la pause ne passe par aucun ecran de fin et ne doit pas le perdre.
func _test_le_record_suit_la_partie() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var g: GameController = _partie()
	g.start_level(MassacreMode.level_def(), GameEnums.Mode.MASSACRE)
	g.running = false
	g.spawner.wave_cleared.emit(0)
	eq(SaveData.massacre_best_wave(), RunState.wave_index,
		"une vague nettoyee en Massacre met le record a jour")
	ok(SaveData.massacre_best_wave() > 0, "le record n est plus nul")

	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.INFINITE)
	g.running = false
	g.spawner.wave_cleared.emit(0)
	eq(SaveData.infinite_best_wave(&"lvl_01"), RunState.wave_index,
		"une vague nettoyee en Infini met le record du niveau a jour")

	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	var avant: int = SaveData.infinite_best_wave(&"lvl_01")
	g.spawner.wave_cleared.emit(0)
	eq(SaveData.infinite_best_wave(&"lvl_01"), avant,
		"l Exploration ne touche pas au record Infini")
	RunState.pending_offer.clear()
	detach(g)
	SaveData.reset_profile()


## L ecran de defaite range le record selon le mode, sans fiche fantome.
func _test_la_defaite_range_le_record_du_massacre() -> void:
	SaveData.reset_profile()
	RunState.mode = GameEnums.Mode.MASSACRE
	var vagues: int = 9
	SceneRouter.payload = {"level_id": MassacreMode.LEVEL_ID, "waves": vagues}
	var packed: PackedScene = load("res://scenes/endgame/DefeatScreen.tscn")
	var ecran: Control = packed.instantiate()
	attach(ecran)
	eq(SaveData.massacre_best_wave(), vagues, "la defaite en Massacre enregistre son record")
	not_ok((SaveData.profile().get("levels", {}) as Dictionary).has(String(MassacreMode.LEVEL_ID)),
		"et ne cree aucune fiche de niveau \"massacre\"")
	detach(ecran)
	RunState.mode = GameEnums.Mode.EXPLORATION
	SceneRouter.payload = {}
	SaveData.reset_profile()


## Le briefing sait construire le Massacre, qui n est pas dans ContentDB.
func _test_le_briefing_du_massacre() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	not_ok(ContentDB.levels.has(MassacreMode.LEVEL_ID),
		"le Massacre n est pas un niveau de campagne")
	eq(MassacreMode.resolve_level(&"lvl_01", GameEnums.Mode.EXPLORATION),
		ContentDB.levels.get(&"lvl_01"), "un niveau de campagne se resout tel quel")
	SceneRouter.payload = {"level_id": MassacreMode.LEVEL_ID, "mode": GameEnums.Mode.MASSACRE}
	var packed: PackedScene = load("res://scenes/loading/LoadingScreen.tscn")
	var ecran: Control = packed.instantiate()
	attach(ecran)
	var titre: Label = ecran.get_node_or_null("%Title")
	ok(titre != null and titre.text == MassacreMode.DISPLAY_NAME.to_upper(),
		"le briefing titre MASSACRE (%s)" % (titre.text if titre != null else "?"))
	var menaces: Node = ecran.get_node_or_null("%Waves")
	ok(menaces != null and menaces.get_child_count() > 1,
		"le briefing du Massacre montre ce qui attend")
	var deck: Node = ecran.get_node_or_null("%Deck")
	ok(deck != null and deck.get_child_count() > 0, "et le deck du joueur")
	detach(ecran)
	SceneRouter.payload = {}
	SaveData.reset_profile()


func _partie() -> GameController:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	return g


func _sans_boss(defs: Array[EnemyDef]) -> int:
	var n: int = 0
	for d in defs:
		if d != null and not d.is_boss():
			n += 1
	return n
