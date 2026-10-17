extends TestCase
## Les trois modes de jeu (chantier M, 29/09 ; vague 10, 14/10) :
##   EXPLORATION : "CAMPAGNE", le niveau avec son deck de campagne ;
##   FREE        : "LIBRE", le MEME niveau (vagues, objectifs) avec ton deck ;
##                 remplace l Infini par niveau, garde sa valeur 1 ;
##   MASSACRE    : l onglet du menu, le SEUL mode sans fin (MassacreMode).
##
## Ce qui est verrouille ici, c est ce qui casserait sans bruit : un renommage
## qui decale la valeur entiere d un mode, le Libre cache derriere la fin de la
## campagne, une victoire libre qui ouvrirait la suite, un Massacre qui ne
## tirerait que dans un monde ou qu un seul boss, un record range au mauvais
## endroit.

func get_suite_name() -> String:
	return "modes"


func run() -> void:
	SaveData.reset_profile()
	_test_valeurs_et_noms_des_modes()
	_test_la_fiche_de_niveau_propose_campagne_et_libre()
	_test_le_libre_s_ouvre_avec_le_niveau()
	_test_la_victoire_libre_ne_sert_qu_aux_objectifs()
	_test_le_massacre_s_ouvre_a_la_fin_de_la_campagne()
	_test_le_pool_du_massacre_couvre_tous_les_niveaux()
	_test_le_massacre_melange_les_mondes_en_jouant()
	_test_les_boss_de_tout_le_jeu_aux_paliers()
	_test_la_partie_installe_chaque_mode()
	_test_le_libre_joue_le_niveau_avec_ton_deck()
	_test_le_bandeau_de_monde()
	_test_record_par_mode()
	_test_le_record_suit_la_partie()
	_test_la_defaite_range_le_record_du_massacre()
	_test_le_briefing_du_massacre()
	SaveData.reset_profile()
	RunState.reset()


## FREE reprend la valeur 1 (l Infini par niveau, avant lui l ancien Massacre
## par niveau), le MASSACRE ferme la liste. C est une regle de COMPATIBILITE, pas
## un reglage : une valeur retenue ailleurs doit garder son sens.
func _test_valeurs_et_noms_des_modes() -> void:
	eq(int(GameEnums.Mode.EXPLORATION), 0, "la campagne reste la valeur 0")
	eq(int(GameEnums.Mode.FREE), 1,
		"le Libre reprend la valeur de l Infini par niveau qu il remplace")
	eq(int(GameEnums.Mode.MASSACRE), GameEnums.Mode.size() - 1,
		"le Massacre reste EN FIN d enum")
	not_ok(GameEnums.Mode.has("INFINITE"), "l Infini par niveau n existe plus")
	eq(GameEnums.mode_name(GameEnums.Mode.FREE), "Libre", "le Libre s ecrit Libre")
	eq(GameEnums.mode_name(GameEnums.Mode.MASSACRE), "Massacre", "le Massacre s ecrit Massacre")
	eq(GameEnums.mode_name(GameEnums.Mode.EXPLORATION), "Campagne",
		"le mode de campagne s ecrit Campagne")
	not_ok(GameEnums.is_endless(GameEnums.Mode.EXPLORATION), "la campagne a une fin")
	not_ok(GameEnums.is_endless(GameEnums.Mode.FREE), "le Libre a une fin : les vagues du niveau")
	ok(GameEnums.is_endless(GameEnums.Mode.MASSACRE), "le Massacre est sans fin")
	ok(GameEnums.advances_campaign(GameEnums.Mode.EXPLORATION), "la campagne fait avancer")
	not_ok(GameEnums.advances_campaign(GameEnums.Mode.FREE), "le Libre ne fait pas avancer")
	not_ok(GameEnums.advances_campaign(GameEnums.Mode.MASSACRE), "le Massacre non plus")


## La fiche propose CAMPAGNE et LIBRE (plus EXPLORATION / INFINI, ni MASSACRE).
func _test_la_fiche_de_niveau_propose_campagne_et_libre() -> void:
	SaveData.reset_profile()
	var p := CampaignPanel.new()
	attach(p)
	p.open_level(&"lvl_01")
	var noms: Array[String] = p.mode_labels()
	eq(noms, ["CAMPAGNE", "LIBRE"] as Array[String],
		"la fiche propose CAMPAGNE et LIBRE (%s)" % str(noms))
	for ancien in ["MASSACRE", "INFINI", "EXPLORATION"]:
		not_ok(noms.has(ancien), "le mot %s a quitte la fiche de niveau" % ancien)
	detach(p)


## Le Libre d un niveau s ouvre avec le NIVEAU, pas a la fin de la campagne.
func _test_le_libre_s_ouvre_avec_le_niveau() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	not_ok(SaveData.campaign_cleared(), "profil neuf : la campagne n est pas finie")
	ok(SaveData.free_unlocked(&"lvl_01"), "le Libre du niveau 1 est ouvert d office")
	not_ok(SaveData.free_unlocked(&"lvl_02"),
		"le Libre d un niveau verrouille reste ferme")
	not_ok(SaveData.free_unlocked(MassacreMode.LEVEL_ID),
		"le Massacre n est pas un niveau dont on ouvrirait le Libre")

	var p := CampaignPanel.new()
	attach(p)
	p.open_level(&"lvl_01")
	ok(p.free_available(), "le bouton LIBRE est actif sans avoir fini le jeu")
	p.select_mode(GameEnums.Mode.FREE)
	eq(p.current_mode(), GameEnums.Mode.FREE, "le mode LIBRE reste selectionne")
	ok(p.play_enabled(), "avec un deck valide, JOUER est actif en Libre")
	ok(p.hint_text().contains(str(DeckRules.DECK_SIZE)),
		"l aide du Libre dit la taille du deck du joueur (%s)" % p.hint_text())
	ok(p.detail_texts().has(CampaignPanel.FREE_STATUS_TEXT),
		"la fiche dit la regle du Libre : seuls les objectifs comptent")
	# Un deck du joueur hors regle coupe JOUER en Libre, avec la raison du deck.
	SaveData.set_massacre_deck([])
	p.select_mode(GameEnums.Mode.FREE)
	not_ok(p.play_enabled(), "deck vide : JOUER est coupe en Libre")
	eq(p.hint_text(), DeckRules.validation_message([]), "et l aide dit pourquoi")
	# La campagne, elle, ne depend pas du deck du joueur.
	p.select_mode(GameEnums.Mode.EXPLORATION)
	ok(p.play_enabled(), "la campagne joue son propre deck, quel que soit celui du joueur")
	detach(p)
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())

	# Debloquer le niveau 2 (victoire en CAMPAGNE au 1) ouvre SON Libre.
	SaveData.record_victory(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION, {}, 6)
	ok(SaveData.free_unlocked(&"lvl_02"), "gagner le niveau 1 ouvre le Libre du niveau 2")
	not_ok(SaveData.campaign_cleared(), "et la campagne n est toujours pas finie")
	SaveData.reset_profile()


## « Gagner ne sert qu aux objectifs » : une victoire en LIBRE marque ses
## objectifs, et RIEN d autre — ni niveau fini, ni niveau ouvert, ni record de
## campagne. Puis la meme victoire en campagne fait avancer.
func _test_la_victoire_libre_ne_sert_qu_aux_objectifs() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = ContentDB.levels.get(SaveData.FIRST_LEVEL)
	ok(lv1 != null and not lv1.next_levels.is_empty() and not lv1.objectives.is_empty(),
		"le premier niveau a une suite et des objectifs")
	if lv1 == null or lv1.next_levels.is_empty() or lv1.objectives.is_empty():
		return
	var suivant: StringName = lv1.next_levels[0]
	var obj: ObjectiveDef = lv1.objectives[0]
	SaveData.record_victory(lv1, GameEnums.Mode.FREE, {obj.id: true}, lv1.waves.size())
	ok(SaveData.is_objective_done(lv1.id, obj.id), "Libre : l objectif reussi est acquis")
	not_ok(SaveData.is_level_cleared(lv1.id), "Libre : le niveau n est PAS fini")
	not_ok(SaveData.is_level_unlocked(suivant), "Libre : le niveau suivant reste ferme")
	eq(int(SaveData.level_record(lv1.id).get("best_wave", 0)), 0,
		"Libre : la meilleure vague de la campagne ne bouge pas")
	ok(bool(SaveData.level_record(lv1.id).get("cleared_free", false)),
		"Libre : la victoire est notee a part, pour l affichage")
	eq(int(SaveData.campaign_progress()[0]), 0, "la campagne n a pas avance")
	SaveData.record_victory(lv1, GameEnums.Mode.EXPLORATION, {}, lv1.waves.size())
	ok(SaveData.is_level_cleared(lv1.id), "Campagne : le niveau est fini")
	ok(SaveData.is_level_unlocked(suivant), "Campagne : le niveau suivant s ouvre")
	ok(SaveData.is_objective_done(lv1.id, obj.id), "l objectif gagne en Libre reste acquis")
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
	# Les niveaux du FIL de la campagne (vague 10 : une annexe ne compte pas).
	var niveaux: Array = ContentDB.campaign_levels()
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
	# Le Libre, lui, n a pas attendu : il s ouvrait niveau par niveau.
	for lv: LevelDef in niveaux:
		ok(SaveData.free_unlocked(lv.id), "le Libre de %s est ouvert" % lv.id)
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
	# Le pool du Massacre depasse celui de n importe quel niveau seul : c etait
	# toute la difference avec l Infini par niveau (retire en vague 10).
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

	# Le LIBRE (vague 10) joue les vagues ECRITES du niveau, comme la campagne :
	# aucune generation, aucun monde.
	var lvl: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(lvl, GameEnums.Mode.FREE)
	g.running = false
	eq(RunState.mode, GameEnums.Mode.FREE, "RunState connait le mode Libre")
	not_ok(g.spawner.procedural, "le Libre ne genere pas ses vagues")
	eq(g.spawner.waves.size(), lvl.waves.size(), "le Libre joue les vagues ecrites du niveau")
	annonces[0] = 0
	g.spawner.world_changed.connect(compte)
	for i in lvl.waves.size():
		g.spawner.start_next()
	eq(annonces[0], 0, "le Libre n annonce aucun monde")
	g.spawner.world_changed.disconnect(compte)
	detach(g)
	SaveData.reset_profile()


## LE LIBRE : le niveau de la campagne, avec le deck du JOUEUR, ses objectifs
## suivis, un choix de carte a chaque montee de niveau, et les passifs equipes
## actifs sur un niveau qui les admet (jamais en campagne).
func _test_le_libre_joue_le_niveau_avec_ton_deck() -> void:
	SaveData.reset_profile()
	# Un deck du joueur DIFFERENT du deck de campagne, pour que le test morde.
	# Vague 10 (chantier B2) : le premier deck n a que trois communes (4/4/4), et
	# un profil neuf ne possede qu elles ; un joueur qui a pris une carte en combat
	# en a une de plus, de quoi composer un autre deck.
	var lv1: LevelDef = ContentDB.levels.get(&"lvl_01")
	for c0: SpellCard in ContentDB.act_commons(lv1.act):
		if not lv1.base_commons.has(c0):
			SaveData.discover_card(c0.id)
			break
	var campagne: Array = []
	for c: SpellCard in SaveData.campaign_deck(lv1):
		campagne.append(String(c.id))
	var mien: Array = DeckRules.default_deck_ids()
	var autre: Array = _autre_deck_valide(campagne)
	if not autre.is_empty():
		mien = autre
	SaveData.set_massacre_deck(mien)
	var g: GameController = _partie()
	g.start_level(lv1, GameEnums.Mode.FREE)
	g.running = false
	eq(_ids_tries(RunState.deck + RunState.hand + RunState.discard), _ids_tries_ids(mien),
		"le Libre distribue le deck du joueur")
	g.start_level(lv1, GameEnums.Mode.EXPLORATION)
	g.running = false
	eq(_ids_tries(RunState.deck + RunState.hand + RunState.discard), _ids_tries_ids(campagne),
		"la campagne distribue le deck de campagne, pas celui du joueur")
	ok(not autre.is_empty(), "les deux decks different : le test compare deux choses")

	# Une montee de niveau en Libre propose des cartes (comme en campagne).
	g.start_level(lv1, GameEnums.Mode.FREE)
	g.running = false
	RunState.level_up.emit(RunState.level + 1)
	ok(not RunState.pending_offer.is_empty(), "le Libre propose des cartes a la montee de niveau")
	RunState.pending_offer.clear()

	# Passifs equipes : actifs en Libre sur un niveau qui les admet, jamais en
	# campagne.
	var acte2: LevelDef = null
	for lv: LevelDef in ContentDB.campaign_levels():
		if lv.allows_passives():
			acte2 = lv
			break
	var passifs: Array = []
	for c2: SpellCard in ContentDB.base_passives():
		if passifs.size() < DeckRules.MAX_PASSIVES:
			passifs.append(String(c2.id))
	if acte2 != null:
		SaveData.unlock_level(acte2.id)
		SaveData.set_equipped_passives(passifs)
		g.start_level(acte2, GameEnums.Mode.FREE)
		g.running = false
		eq(RunState.equipped_passives.size(), passifs.size(),
			"Libre, acte des passifs : les passifs equipes sont actifs des le depart")
		g.start_level(acte2, GameEnums.Mode.EXPLORATION)
		g.running = false
		eq(RunState.equipped_passives.size(), 0, "Campagne : aucun passif equipe d avance")
		g.start_level(lv1, GameEnums.Mode.FREE)
		g.running = false
		eq(RunState.equipped_passives.size(), 0,
			"Libre, acte sans passifs : la regle de l acte du niveau tient")
	ok(acte2 != null, "un niveau de campagne admet les passifs")
	detach(g)
	SaveData.reset_profile()


## Un deck valide de cartes obtenues, DIFFERENT de `sauf` (ids, exemplaires
## compris). Vide si le profil n en permet pas.
func _autre_deck_valide(sauf: Array) -> Array:
	var cible: Array = _ids_tries_ids(sauf)
	var obtenues: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and SaveData.is_discovered(c.id):
			obtenues.append(c)
	obtenues.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) > String(b.id))
	var out: Array = []
	var progres: bool = true
	while out.size() < DeckRules.DECK_SIZE and progres:
		progres = false
		for c2 in obtenues:
			if DeckRules.can_add(out, c2, true):
				out.append(String(c2.id))
				progres = true
				if out.size() >= DeckRules.DECK_SIZE:
					break
	if not DeckRules.is_valid(out) or _ids_tries_ids(out) == cible:
		return []
	return out


func _ids_tries(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		if c != null:
			out.append(String((c as SpellCard).id))
	out.sort()
	return out


func _ids_tries_ids(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(String(id))
	out.sort()
	return out


## Aucun bandeau de monde depuis la vague 10 : le Libre joue les vagues du
## niveau, et un Massacre qui annoncerait un monde mentirait (tout est melange).
func _test_le_bandeau_de_monde() -> void:
	SaveData.reset_profile()
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	var g: GameController = _partie()
	var hud: Node = g.get_node_or_null("HUD")
	ok(hud != null, "la partie a un HUD")
	if hud == null:
		detach(g)
		return
	var lv1: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(lv1, GameEnums.Mode.FREE)
	g.running = false
	for i in lv1.waves.size():
		g.spawner.start_next()
	eq(String(hud.call("world_banner_text")), "",
		"le Libre n affiche aucun bandeau de monde")

	hud.call("hide_world_banner")
	g.start_level(MassacreMode.level_def(), GameEnums.Mode.MASSACRE)
	g.running = false
	for i in WaveBudget.WORLD_EVERY + 1:
		g.spawner.start_next()
	eq(String(hud.call("world_banner_text")), "",
		"le Massacre n affiche aucun bandeau de monde")
	detach(g)
	SaveData.reset_profile()


## Un record par mode, qui ne regresse pas et qui survit a la sauvegarde. Le
## LIBRE n en ecrit aucun (vague 10) : « Meilleure vague » est celui de la
## campagne.
func _test_record_par_mode() -> void:
	SaveData.reset_profile()
	var l1: StringName = &"lvl_01"
	not_ok(SaveData.record_run_waves(l1, GameEnums.Mode.FREE, 5), "le Libre n ecrit aucun record")
	eq(int(SaveData.level_record(l1).get("best_wave", 0)), 0,
		"une partie libre ne touche pas a la meilleure vague de la campagne")
	ok(SaveData.record_run_waves(l1, GameEnums.Mode.EXPLORATION, 3), "premier record de campagne")
	eq(int(SaveData.level_record(l1).get("best_wave", 0)), 3, "le record de campagne est lu")
	not_ok(SaveData.record_run_waves(l1, GameEnums.Mode.EXPLORATION, 2),
		"une partie moins longue n est pas un record")

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
	eq(int(SaveData.level_record(l1).get("best_wave", 0)), 3,
		"le record de campagne survit a la sauvegarde")

	# Un profil d avant le chantier n a pas la cle : il se charge a zero.
	var ancien: Dictionary = SaveData.to_dictionary()
	(ancien["profile"] as Dictionary).erase("massacre_best_wave")
	SaveData.load_from_dictionary(ancien)
	eq(SaveData.massacre_best_wave(), 0, "un ancien profil se charge sans record Massacre")

	# MIGRATION de la vague 10 : un profil qui a un record INFINI par niveau le
	# GARDE dans le fichier (rien n est retire), sans qu il se melange a rien.
	var avec_infini: Dictionary = SaveData.to_dictionary()
	var fiches: Dictionary = (avec_infini["profile"] as Dictionary).get("levels", {})
	(fiches[String(l1)] as Dictionary)["best_wave_infinite"] = 14
	SaveData.load_from_dictionary(avec_infini)
	eq(int(SaveData.level_record(l1).get("best_wave_infinite", 0)), 14,
		"l ancien record Infini reste dans le profil")
	eq(int(SaveData.level_record(l1).get("best_wave", 0)), 3,
		"et ne remplace pas la meilleure vague de la campagne")
	not_ok(SaveData.is_level_cleared(l1), "et ne fait pas passer le niveau pour fini")
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

	var massacre: int = SaveData.massacre_best_wave()
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.FREE)
	g.running = false
	g.spawner.wave_cleared.emit(0)
	eq(int(SaveData.level_record(&"lvl_01").get("best_wave", 0)), 0,
		"une vague nettoyee en Libre n ecrit aucun record de niveau")
	eq(SaveData.massacre_best_wave(), massacre, "ni celui du Massacre")
	ok(RunState.pending_offer.is_empty(),
		"le Libre ne propose pas de carte par vague : seulement a la montee de niveau")

	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.spawner.wave_cleared.emit(0)
	eq(SaveData.massacre_best_wave(), massacre, "la campagne ne touche pas au record Massacre")
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
