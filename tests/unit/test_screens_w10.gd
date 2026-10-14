extends TestCase
## VAGUE 10, chantier ECRANS : le bilan de fin de niveau en DEGATS et son
## conseil, l ecran de lancement refait, le contour noir du sceau d element.
##
## Les degats se mesurent par le VRAI chemin du coup (GameController, Battlefield,
## SpeedGauge) ; les regles du conseil sur des monstres fabriques, un trait a la
## fois ; l ecran de lancement sur TOUS les niveaux de la campagne. Aucune valeur
## d equilibrage n est ecrite ici : les degats attendus sont lus sur le monstre
## (contact_hit, shot_damage), les seuils sur ThreatLore.

func get_suite_name() -> String:
	return "screens_w10"


func run() -> void:
	SaveData.reset_profile()
	_test_le_bilan_compte_la_vitesse_retiree()
	_test_le_projectile_est_range_sous_son_lanceur()
	_test_les_lignes_sont_triees_par_degats()
	_test_repli_sur_les_coups_sans_montant()
	_test_les_familles_de_reponse_se_lisent_dans_les_donnees()
	_test_chaque_trait_a_sa_reponse_et_ses_mots()
	_test_le_conseil_d_element()
	_test_le_conseil_de_mecanique()
	_test_le_deck_passe_avant_le_livre()
	_test_les_ecrans_de_fin_posent_le_bilan()
	_test_le_briefing_annonce_tous_les_boss()
	_test_le_briefing_de_chaque_niveau()
	_test_les_cartes_a_gagner()
	_test_la_fonction_d_affichage_suit_la_liste()
	_test_le_sceau_porte_son_contour()
	_test_les_encres_du_papier_tiennent_le_contraste()
	SaveData.reset_profile()
	RunState.reset()
	reset_gauge_at_normal_speed()


# --- outils ---------------------------------------------------------------------

func _def(id: String) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 1000.0
	d.base_speed = 55.0
	return d


func _card(id: String) -> SpellCard:
	return ContentDB.cards.get(StringName(id))


func _partie() -> GameController:
	var g: GameController = load("res://scenes/game/Game.tscn").instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.battlefield.clear_all()
	reset_gauge_with_survivable_mage()
	return g


func _run(bf: Battlefield, seconds: float) -> void:
	var pas: float = 1.0 / 30.0
	for i in int(ceil(seconds / pas)):
		bf.simulate(pas)


## Les noeuds qui portent la meta `cle`, dans l ordre de l ecran (parcours en
## profondeur). Par meta et non par nom : deux freres ne partagent jamais un nom
## dans Godot, le second serait renomme.
func _with_meta(racine: Node, cle: StringName) -> Array[Node]:
	var out: Array[Node] = []
	var pile: Array[Node] = [racine]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n.has_meta(cle):
			out.append(n)
		var enfants: Array[Node] = n.get_children()
		for i in range(enfants.size() - 1, -1, -1):
			pile.append(enfants[i])
	return out


# --- BILAN : la mesure ----------------------------------------------------------

## Le bilan compte la vitesse REELLEMENT retiree, pas le bareme du coup : un
## contact a pleine vitesse coute son bareme, un contact au bord du plancher ne
## coute que ce qui restait, un coup pendant l agonie ne coute rien.
func _test_le_bilan_compte_la_vitesse_retiree() -> void:
	var g: GameController = _partie()
	var bf: Battlefield = g.battlefield
	var perdu: Array = [0]
	var ecoute := func(a: int, _p: int) -> void: perdu[0] += a
	SpeedGauge.speed_lost.connect(ecoute)
	ok(RunState.damage_by_enemy_id.is_empty(), "le bilan est vide au depart d une partie")

	var gnome := _def("gnome")
	gnome.base_speed = 200.0
	var bareme: int = gnome.contact_hit()
	bf.spawn_enemy(gnome, 0.0, 1.0, Vector2(540.0, GameConfig.MAGE_LINE_Y - 2.0))
	_run(bf, 0.5)
	eq(int(RunState.damage_by_enemy_id.get(&"gnome", 0)), bareme,
		"un contact a pleine vitesse coute son bareme au bilan")
	eq(int(RunState.damage_by_enemy_id.get(&"gnome", 0)), int(perdu[0]),
		"le bilan est la perte que la jauge a reellement subie")

	# Une fleche : la meme regle, au nom du tireur.
	var archer := _def("imp_archer")
	archer.shoot_interval = 0.2
	archer.base_speed = 0.0
	bf.spawn_enemy(archer, 0.0, 1.0, Vector2(300.0, GameConfig.MAGE_LINE_Y * 0.5))
	for i in 300:
		bf.simulate(1.0 / 30.0)
		if RunState.hits_from_enemy(&"imp_archer") > 0:
			break
	var fleches: int = RunState.hits_from_enemy(&"imp_archer")
	ok(fleches > 0, "(la fleche du lutin est arrivee)")
	eq(int(RunState.damage_by_enemy_id.get(&"imp_archer", 0)), fleches * archer.shot_damage,
		"une fleche coute au bilan ce qu elle coute a la jauge, au nom du tireur")
	bf.clear_all()

	# Au bord du plancher : le coup ne retire que ce qui restait.
	var avant: int = int(RunState.damage_by_enemy_id.get(&"gnome", 0))
	var reste: int = maxi(1, bareme / 2)
	SpeedGauge.set_speed_percent(100 + reste)
	bf.spawn_enemy(gnome, 0.0, 1.0, Vector2(540.0, GameConfig.MAGE_LINE_Y - 2.0))
	_run(bf, 0.5)
	eq(int(RunState.damage_by_enemy_id.get(&"gnome", 0)) - avant, reste,
		"au bord du plancher, le bilan ne compte que la vitesse qui restait")
	ok(SpeedGauge.is_dying, "(le mage est a l agonie)")

	# Pendant l agonie : le coup compte, la vitesse non (il n y en a plus).
	var coups: int = int(RunState.hits_by_enemy_id.get(&"gnome", 0))
	var apres: int = int(RunState.damage_by_enemy_id.get(&"gnome", 0))
	bf.spawn_enemy(gnome, 0.0, 1.0, Vector2(540.0, GameConfig.MAGE_LINE_Y - 2.0))
	_run(bf, 0.5)
	eq(int(RunState.hits_by_enemy_id.get(&"gnome", 0)), coups + 1, "(le coup de l agonie est compte)")
	eq(int(RunState.damage_by_enemy_id.get(&"gnome", 0)), apres,
		"un coup pendant l agonie n ajoute rien au bilan")
	SpeedGauge.speed_lost.disconnect(ecoute)
	detach(g)
	RunState.reset()
	ok(RunState.damage_by_enemy_id.is_empty(), "le bilan repart a zero a chaque partie")
	reset_gauge_at_normal_speed()


## La boule de poison du Planogo frappe au nom de la boule ; le bilan la range
## sous son LANCEUR, comme RunState.hits_from_enemy le fait pour les coups.
func _test_le_projectile_est_range_sous_son_lanceur() -> void:
	var follet: EnemyDef = ContentDB.enemies.get(&"wisp")
	ok(follet != null and follet.summon_def != null and follet.summon_def.projectile,
		"(le Planogo lance un projectile-monstre)")
	if follet == null or follet.summon_def == null:
		return
	var boule: EnemyDef = follet.summon_def
	eq(BattleReport.launcher_of(boule, ContentDB.levels.get(&"lvl_01")), follet,
		"la boule a pour lanceur le Planogo du niveau")
	eq(BattleReport.launcher_of(boule), follet, "et sans niveau, le lanceur du catalogue")
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	eq(BattleReport.launcher_of(gnome), gnome, "un monstre ordinaire est son propre lanceur")
	var lignes: Array[Dictionary] = BattleReport.rows(
		{boule.id: 7, follet.id: 3}, {boule.id: 2, follet.id: 1}, ContentDB.levels.get(&"lvl_01"))
	eq(lignes.size(), 1, "boule et lanceur font UNE ligne")
	if lignes.size() == 1:
		eq(lignes[0]["def"], follet, "la ligne est celle du lanceur")
		eq(int(lignes[0]["damage"]), 10, "ses degats et ceux de sa boule s additionnent")
		eq(int(lignes[0]["hits"]), 3, "ses coups aussi")


func _test_les_lignes_sont_triees_par_degats() -> void:
	var a: EnemyDef = ContentDB.enemies.get(&"gnome")
	var b: EnemyDef = ContentDB.enemies.get(&"imp_archer")
	var c: EnemyDef = ContentDB.enemies.get(&"sprite")
	# Le PLUS DE COUPS n est pas le plus de degats : 7 fleches a 2 < 1 contact a 30.
	var lignes: Array[Dictionary] = BattleReport.rows(
		{a.id: 30, b.id: 14, c.id: 14}, {a.id: 1, b.id: 7, c.id: 2})
	eq(lignes.size(), 3, "une ligne par espece")
	if lignes.size() == 3:
		eq(lignes[0]["def"], a, "en tete : le plus de vitesse retiree, meme en un coup")
		eq(lignes[1]["def"], b, "a degats egaux : le plus de coups d abord")
		eq(lignes[2]["def"], c, "puis l autre")
	var avec_zero: Array[Dictionary] = BattleReport.rows({a.id: 5, b.id: 0}, {a.id: 1, b.id: 4})
	eq(avec_zero.size(), 1, "une espece qui n a rien retire ne figure pas au bilan")


func _test_repli_sur_les_coups_sans_montant() -> void:
	var a: EnemyDef = ContentDB.enemies.get(&"gnome")
	var b: EnemyDef = ContentDB.enemies.get(&"imp_archer")
	var lignes: Array[Dictionary] = BattleReport.rows({}, {a.id: 1, b.id: 3})
	eq(lignes.size(), 2, "sans montant connu, le bilan nomme quand meme les coupables")
	if lignes.size() == 2:
		eq(lignes[0]["def"], b, "par nombre de coups")


# --- CONSEIL : les regles -------------------------------------------------------

func _test_les_familles_de_reponse_se_lisent_dans_les_donnees() -> void:
	ok(ThreatLore.answers_of(_card("stone_wall")).has(ThreatLore.MUR), "un mur arrete les tirs")
	ok(ThreatLore.answers_of(_card("purifying_light")).has(ThreatLore.DISSIPER),
		"la Lumiere purifiante dissipe")
	ok(ThreatLore.answers_of(_card("fireball")).has(ThreatLore.ZONE), "la Boule de feu est une zone")
	ok(ThreatLore.answers_of(_card("venom_dart")).has(ThreatLore.DUREE),
		"le Dard venimeux blesse sur la duree")
	ok(ThreatLore.answers_of(_card("frost_field")).has(ThreatLore.RALENTIR),
		"le Champ de givre ralentit")
	not_ok(ThreatLore.answers_of(_card("fireball")).has(ThreatLore.DUREE),
		"une zone breve n est pas un degat sur la duree")
	# SpellCard.has_damage repond vrai a des sorts qui ne blessent personne (la
	# magnitude y est un nombre de cartes, de l XP) : le conseil ne s y fie pas.
	var concentration: SpellCard = _card("deep_focus")
	if concentration != null:
		ok(concentration.has_damage(), "(la magnitude de Concentration n est pas des degats)")
		not_ok(ThreatLore.deals_damage(concentration), "Concentration ne blesse aucun monstre")
		not_ok(ThreatLore.answers_of(concentration).has(ThreatLore.DEGATS),
			"et ne sera jamais conseillee comme sort de degats")
	# Chaque REPONSE que le conseil peut demander existe dans le catalogue.
	var familles: Dictionary = {}
	for t in ThreatLore.REPONSE_DU_TRAIT:
		familles[ThreatLore.REPONSE_DU_TRAIT[t]] = true
	familles[ThreatLore.DEGATS] = true
	for f in familles:
		var trouve: bool = false
		for c: SpellCard in ContentDB.cards.values():
			if ThreatLore.answers_of(c).has(f):
				trouve = true
				break
		ok(trouve, "la reponse %s a au moins une carte au catalogue" % f)


func _test_chaque_trait_a_sa_reponse_et_ses_mots() -> void:
	eq(ThreatLore.REPONSE_DU_TRAIT.size(), ThreatLore.TRAITS.size(),
		"une reponse par trait, ni plus ni moins")
	var neutre := _def("neutre")
	neutre.summon_def = _def("sbire")
	neutre.blocks_cards = 2
	neutre.hits_immune = 3
	neutre.swarm_count = 4
	neutre.parts_count = 2
	for t in ThreatLore.TRAITS:
		ok(ThreatLore.REPONSE_DU_TRAIT.has(t), "le trait %s a une reponse" % t)
		ok(ThreatLore.PHRASE_DE_REPONSE.has(ThreatLore.REPONSE_DU_TRAIT.get(t, &"")),
			"la reponse du trait %s a sa phrase" % t)
		ok(ThreatLore.trait_text(t, neutre) != "", "le trait %s a ses mots courts" % t)
		ok(ThreatLore.trait_advice(t, neutre) != ThreatLore.trait_advice(&"", neutre),
			"le trait %s a sa phrase de conseil" % t)
	eq(ThreatLore.traits(_def("rien")).size(), 0, "un monstre sans champ n a aucun trait")
	ok(ThreatLore.mechanic_line(_def("rien")) != "", "et sa ligne de briefing n est pas vide")


func _test_le_conseil_d_element() -> void:
	var feu: SpellCard = _card("fireball")
	var d := _def("faible_au_feu")
	d.resistances = {GameEnums.DamageTag.FIRE: 1.5, GameEnums.DamageTag.ICE: 1.2}
	var lignes: Array[Dictionary] = ThreatLore.advice(d, [feu], [])
	ok(not lignes.is_empty() and lignes[0]["kind"] == &"element", "la premiere ligne dit l element")
	if lignes.is_empty():
		return
	eq(int(lignes[0]["tag"]), GameEnums.DamageTag.FIRE, "sa PLUS FORTE faiblesse")
	eq(lignes[0]["card"], feu, "avec la carte de cet element qui blesse")
	ok(String(lignes[0]["text"]).contains(feu.display_name), "nommee dans la phrase")
	var sans: Array[Dictionary] = ThreatLore.advice(d, [], [])
	eq(sans[0]["card"], null, "aucune carte de feu : on n en invente pas")
	# Pas de faiblesse : la plus forte resistance, sans carte.
	var dur := _def("dur")
	dur.resistances = {GameEnums.DamageTag.POISON: 0.0, GameEnums.DamageTag.FIRE: 0.5}
	var l2: Array[Dictionary] = ThreatLore.advice(dur, [feu], [])
	eq(int(l2[0]["tag"]), GameEnums.DamageTag.POISON, "sans faiblesse, sa plus forte resistance")
	eq(l2[0]["card"], null, "et aucune carte n est conseillee contre une resistance")
	# Neutre partout : pas de ligne d element.
	var l3: Array[Dictionary] = ThreatLore.advice(_def("neutre"), [feu], [])
	eq(l3.size(), 1, "un monstre neutre n a que la ligne de mecanique")
	eq(l3[0]["kind"], &"mecanique", "(c est bien elle)")


## Un trait a la fois : la reponse attendue, et la carte du deck qui y repond.
func _test_le_conseil_de_mecanique() -> void:
	var deck: Array = []
	for id in ["stone_wall", "fireball", "purifying_light", "arcane_insight", "frost_field",
			"venom_dart", "focus", "about_face", "arcane_bolt", "spark"]:
		if _card(id) != null:
			deck.append(_card(id))
	var cas: Array = []
	var tireur := _def("tireur")
	tireur.shoot_interval = 2.0
	cas.append([tireur, &"tire", ThreatLore.MUR])
	var nuee := _def("nuee")
	nuee.swarm_count = 5
	cas.append([nuee, &"nuee", ThreatLore.ZONE])
	var gardien := _def("gardien")
	gardien.aura_shield_radius = 200.0
	cas.append([gardien, &"protege", ThreatLore.DISSIPER])
	var gorgone := _def("gorgone")
	gorgone.blocks_cards = 1
	cas.append([gorgone, &"petrifie", ThreatLore.PIOCHE])
	var volant := _def("volant")
	volant.flying = true
	cas.append([volant, &"vole", ThreatLore.CIBLE])
	var rapide := _def("rapide")
	rapide.base_speed = ThreatLore.RAPIDE_PX
	cas.append([rapide, &"rapide", ThreatLore.RALENTIR])
	var appel := _def("appel")
	appel.summon_interval = 3.0
	appel.summon_def = _def("sbire")
	cas.append([appel, &"invoque", ThreatLore.DUREE])
	var colosse := _def("colosse")
	colosse.kind = GameEnums.EnemyKind.TANK
	cas.append([colosse, &"colosse", ThreatLore.GROS_SORT])
	var zigzag := _def("zigzag")
	zigzag.move_pattern = EnemyDef.MovePattern.ZIGZAG
	cas.append([zigzag, &"imprevisible", ThreatLore.CONTROLE])
	var lent := _def("lent")
	lent.base_speed = ThreatLore.LENT_PX * 0.5
	cas.append([lent, &"lent", ThreatLore.DUREE])
	cas.append([_def("simple"), &"", ThreatLore.DEGATS])
	for c in cas:
		var d: EnemyDef = c[0]
		var lignes: Array[Dictionary] = ThreatLore.advice(d, deck, [])
		var m: Dictionary = lignes[lignes.size() - 1]
		eq(m["trait"], c[1], "%s : trait lu" % d.id)
		eq(m["answer"], c[2], "%s : reponse %s" % [d.id, c[2]])
		var carte: SpellCard = m["card"]
		ok(carte != null and ThreatLore.answers_of(carte).has(c[2]),
			"%s : une carte du deck qui y repond (%s)" % [d.id, carte.id if carte != null else "aucune"])
		ok(bool(m["from_deck"]), "%s : prise dans le deck" % d.id)
	# L ORDRE : un protecteur qui tire est d abord un protecteur.
	var les_deux := _def("les_deux")
	les_deux.aura_shield_radius = 200.0
	les_deux.shoot_interval = 2.0
	var l: Array[Dictionary] = ThreatLore.advice(les_deux, deck, [])
	eq(l[l.size() - 1]["trait"], &"protege", "le premier trait de TRAITS decide du conseil")
	ok(ThreatLore.TRAITS.find(&"protege") < ThreatLore.TRAITS.find(&"tire"),
		"(protege passe avant tire dans l ordre)")
	# Aucune carte ne repond : la phrase seule.
	var seule: Array[Dictionary] = ThreatLore.advice(tireur, [_card("fireball")], [])
	eq(seule[seule.size() - 1]["card"], null, "sans mur ni au deck ni au livre, la phrase seule")


func _test_le_deck_passe_avant_le_livre() -> void:
	var tireur := _def("tireur")
	tireur.shoot_interval = 2.0
	var mur_deck: SpellCard = _card("stone_wall")
	var mur_livre: SpellCard = _card("bastion")
	if mur_deck == null or mur_livre == null:
		ok(false, "(murs du catalogue introuvables)")
		return
	ok(mur_livre.rarity > mur_deck.rarity, "(le mur du livre est plus rare : le test discrimine)")
	var l: Array[Dictionary] = ThreatLore.advice(tireur, [mur_deck], [mur_livre])
	eq(l[l.size() - 1]["card"], mur_deck, "le mur du DECK, meme moins rare que celui du livre")
	var l2: Array[Dictionary] = ThreatLore.advice(tireur, [_card("fireball")], [mur_livre])
	eq(l2[l2.size() - 1]["card"], mur_livre, "a defaut, celui du LIVRE")
	not_ok(bool(l2[l2.size() - 1]["from_deck"]), "et l ecran le dit")
	ok(String(l2[l2.size() - 1]["text"]).contains(ThreatLore.source_text(false)),
		"« dans ton livre »")


# --- BILAN : les ecrans ---------------------------------------------------------

func _test_les_ecrans_de_fin_posent_le_bilan() -> void:
	SaveData.reset_profile()
	RunState.reset()
	RunState.mode = GameEnums.Mode.EXPLORATION
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	RunState.current_level_def = lv
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	var archer: EnemyDef = ContentDB.enemies.get(&"imp_archer")
	var sprite: EnemyDef = ContentDB.enemies.get(&"sprite")
	RunState.note_damage_taken(gnome, 9)
	for i in 4:
		RunState.note_damage_taken(archer, 6)
	RunState.note_damage_taken(sprite, 3)
	for chemin in ["res://scenes/endgame/DefeatScreen.tscn", "res://scenes/endgame/VictoryScreen.tscn"]:
		SceneRouter.payload = {"level_id": lv.id, "waves": 2}
		var ecran: Control = load(chemin).instantiate()
		attach(ecran)
		var lignes: Array[Node] = _with_meta(ecran, &"damage")
		eq(lignes.size(), 3, "%s : une ligne par monstre" % chemin.get_file())
		var ordre: Array = []
		for n in lignes:
			ordre.append(n.get_meta(&"enemy_id"))
		eq(ordre, [archer.id, gnome.id, sprite.id], "%s : par degats decroissants" % chemin.get_file())
		if not lignes.is_empty():
			var premiere: Node = lignes[0]
			var chiffre: Label = premiere.find_child("Damage", true, false)
			ok(chiffre != null and chiffre.text == "-%d" % 24, "%s : la vitesse perdue est ecrite"
				% chemin.get_file())
			ok(premiere.get_child(0) is Control and not (premiere.get_child(0) is TextureRect),
				"%s : le portrait est dans un porteur (le smoke compte les etoiles)" % chemin.get_file())
		var conseil: Node = ecran.find_child("AdviceHeading", true, false)
		ok(conseil != null and (conseil as Label).text.contains(archer.display_name.to_upper()),
			"%s : le conseil vise le monstre qui a le plus coute" % chemin.get_file())
		ok(_with_meta(ecran, &"advice").size() >= 1, "%s : et dit quoi faire" % chemin.get_file())
		var zone: Node = ecran.find_child("Scroll", true, false)
		ok(zone is ScrollContainer and TouchScroll.of(zone) != null,
			"%s : le bilan defile au doigt" % chemin.get_file())
		var menu: Button = ecran.get_node_or_null("%MenuButton")
		ok(menu != null and not (zone as Node).is_ancestor_of(menu),
			"%s : MENU reste hors du defilement" % chemin.get_file())
		detach(ecran)
	SceneRouter.payload = {}
	RunState.reset()
	SaveData.reset_profile()


# --- BRIEFING -------------------------------------------------------------------

## L ancien ecran ecrasait sa variable : un seul boss et un seul mini-boss. Sur
## TOUS les niveaux, chaque boss et chaque mini-boss des vagues est annonce, en
## tete, avant les autres monstres.
func _test_le_briefing_annonce_tous_les_boss() -> void:
	var vu_deux: bool = false
	for lv: LevelDef in ContentDB.levels.values():
		var attendus: Dictionary = {}
		for w: WaveDef in lv.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null and e.enemy.is_boss():
					attendus[e.enemy] = true
		var boss_vagues: int = 0
		for d in attendus:
			if (d as EnemyDef).kind == GameEnums.EnemyKind.BOSS:
				boss_vagues += 1
		vu_deux = vu_deux or boss_vagues >= 2
		var liste: Array[Dictionary] = LoadingScreen.threat_list(lv, GameEnums.Mode.EXPLORATION)
		var annonces: int = 0
		var fini_les_boss: bool = false
		var en_tete: bool = true
		for e in liste:
			var d: EnemyDef = e["def"]
			ok(not d.projectile, "%s : aucun projectile annonce comme monstre" % lv.id)
			if d.is_boss():
				annonces += 1
				if fini_les_boss:
					en_tete = false
			else:
				fini_les_boss = true
		eq(annonces, attendus.size(), "%s : tous les boss et mini-boss annonces" % lv.id)
		ok(en_tete, "%s : boss et mini-boss en tete" % lv.id)
	ok(vu_deux, "(un niveau au moins a deux boss : le test discrimine)")


## Chaque niveau de la campagne : une ligne par monstre avec sa mecanique, un
## defilement au doigt, COMMENCER hors du defilement et a portee de pouce.
func _test_le_briefing_de_chaque_niveau() -> void:
	SaveData.reset_profile()
	var ids: Array = ContentDB.levels.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var lv: LevelDef = ContentDB.levels[id]
		SceneRouter.payload = {"level_id": lv.id, "mode": GameEnums.Mode.EXPLORATION}
		var ecran: Control = load(SceneRouter.LOADING).instantiate()
		attach(ecran)
		var liste: Array[Dictionary] = LoadingScreen.threat_list(lv, GameEnums.Mode.EXPLORATION)
		var lignes: Array[Node] = _with_meta(ecran, &"briefing_enemy")
		eq(lignes.size(), liste.size(), "%s : une ligne par monstre" % lv.id)
		for n in lignes:
			var meca: Label = n.find_child("Mechanic", true, false)
			ok(meca != null and meca.text != "", "%s : %s a sa ligne de mecanique"
				% [lv.id, n.get_meta(&"briefing_enemy")])
		var zone: Node = ecran.find_child("Scroll", true, false)
		ok(zone is ScrollContainer and TouchScroll.of(zone) != null, "%s : le corps defile au doigt" % lv.id)
		var waves: Node = ecran.get_node_or_null("%Waves")
		ok(waves != null and zone != null and zone.is_ancestor_of(waves),
			"%s : %%Waves reste joignable, dans le defilement" % lv.id)
		for b in ["%StartButton", "%BackButton"]:
			var bouton: Button = ecran.get_node_or_null(b)
			ok(bouton != null and zone != null and not zone.is_ancestor_of(bouton),
				"%s : %s hors du defilement, toujours accessible" % [lv.id, b])
			ok(bouton != null and bouton.custom_minimum_size.y >= 90.0,
				"%s : %s fait au moins 90 px" % [lv.id, b])
		if lv.intro_text.strip_edges() != "":
			var intro: Label = ecran.find_child("Intro", true, false)
			ok(intro != null and intro.text == lv.intro_text.strip_edges(),
				"%s : le texte d ouverture est lu" % lv.id)
		var objectifs: Array[Node] = _with_meta(ecran, &"objective_id")
		eq(objectifs.size(), lv.objectives.size(), "%s : chaque objectif" % lv.id)
		for i in mini(objectifs.size(), lv.objectives.size()):
			eq(objectifs[i].get_meta(&"objective_id"), lv.objectives[i].id,
				"%s : objectifs dans l ordre de difficulte" % lv.id)
		var copies: int = 0
		for t in _with_meta(ecran, &"deck_card"):
			var n: Label = t.find_child("Copies", true, false)
			copies += int(n.text.trim_prefix("x")) if n != null else 0
		eq(copies, lv.exploration_deck.size(), "%s : le deck entier en vignettes" % lv.id)
		detach(ecran)
	SceneRouter.payload = {}


func _test_les_cartes_a_gagner() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	var mode: int = GameEnums.Mode.EXPLORATION
	var liste: Array[SpellCard] = LoadingScreen.cards_to_win(lv, mode, lv.exploration_deck)
	for c in liste:
		not_ok(lv.exploration_deck.has(c), "%s : une carte du deck n est pas « a gagner »" % c.id)
	for c in lv.levelup_cards:
		ok(liste.has(c), "la carte nouvelle %s est annoncee" % c.id)
	for i in lv.objectives.size():
		var r: SpellCard = lv.objective_reward(i)
		if r == null:
			continue
		ok(liste.has(r), "la recompense de l objectif %d est annoncee" % (i + 1))
		var pool: Array[SpellCard] = RunState.levelup_pool(lv, mode)
		var st: Dictionary = LoadingScreen.card_state(r, lv, pool)
		eq(int(st["etat"]), LoadingScreen.Etat.OBJECTIF, "objectif %d pas fait : fermee" % (i + 1))
		eq(int(st["rank"]), LevelDef.objective_rank(i), "avec le rang de son objectif")
	var passif_vu: bool = false
	for c in liste:
		if c.is_passive:
			passif_vu = true
		else:
			not_ok(passif_vu, "les sorts avant les passifs (%s)" % c.id)
	# Objectif reussi : sa carte entre au pool, elle devient « a gagner ».
	var obj: ObjectiveDef = lv.objectives[0]
	var r0: SpellCard = lv.objective_reward(0)
	if r0 != null:
		var done: Dictionary = {}
		for o in lv.objectives:
			done[o.id] = (o == obj)
		SaveData.record_victory(lv, mode, done, lv.waves.size())
		var st2: Dictionary = LoadingScreen.card_state(r0, lv, RunState.levelup_pool(lv, mode))
		eq(int(st2["etat"]), LoadingScreen.Etat.A_GAGNER, "objectif reussi : sa carte est a gagner")
		SaveData.discover_card(r0.id)
		var st3: Dictionary = LoadingScreen.card_state(r0, lv, RunState.levelup_pool(lv, mode))
		eq(int(st3["etat"]), LoadingScreen.Etat.OBTENUE, "prise en combat : obtenue")
	SaveData.reset_profile()


## La fonction d affichage montre la liste QU ON LUI DONNE, dans son ordre : la
## regle du pool vit ailleurs (RunState.levelup_pool).
func _test_la_fonction_d_affichage_suit_la_liste() -> void:
	SaveData.reset_profile()
	SceneRouter.payload = {"level_id": &"lvl_01", "mode": GameEnums.Mode.EXPLORATION}
	var ecran: LoadingScreen = load(SceneRouter.LOADING).instantiate()
	attach(ecran)
	var a_moi: Array[SpellCard] = []
	for id in ["meteor_storm", "spark", "about_face"]:
		if _card(id) != null:
			a_moi.append(_card(id))
	var avant: int = _with_meta(ecran, &"win_card").size()
	ecran.show_cards_to_win(a_moi)
	var tuiles: Array[Node] = _with_meta(ecran, &"win_card")
	eq(tuiles.size() - avant, a_moi.size(), "une vignette par carte de la liste")
	var ordre: Array = []
	for i in range(avant, tuiles.size()):
		ordre.append(tuiles[i].get_meta(&"win_card"))
	var attendu: Array = []
	for c in a_moi:
		attendu.append(c.id)
	eq(ordre, attendu, "dans l ordre recu")
	detach(ecran)
	SceneRouter.payload = {}


# --- SCEAU ----------------------------------------------------------------------

## Le sceau porte le materiau du contour, en main, en detail, au grimoire et au
## deck (tous passent par CardView.with_type_badge) ; la case s agrandit de
## l epaisseur du contour sans que le logo change de taille ni de place.
func _test_le_sceau_porte_son_contour() -> void:
	var mat: ShaderMaterial = CardView.seal_material()
	ok(mat != null and mat.shader != null, "le materiau du contour existe")
	if mat != null and mat.shader != null:
		ok(mat.shader.code.contains("epaisseur"), "(c est bien le shader du contour)")
		feq(float(mat.get_shader_parameter(&"epaisseur")), CardView.SEAL_OUTLINE,
			"son epaisseur est celle de CardView")
	var c: SpellCard = _card("fireball")
	var vues: Array = []
	var main := CardView.new()
	main.setup_hand(c, 118.0, 230.0)
	vues.append(["main", main])
	var detail := CardView.new()
	detail.setup_detail(c, 300.0, 440.0)
	vues.append(["detail", detail])
	vues.append(["deck", DeckPanel.type_art(c, 96.0)])
	for v in vues:
		var badge: TextureRect = (v[1] as Node).find_child("TypeBadge", true, false)
		ok(badge != null and badge.material == mat, "%s : le sceau porte le contour" % v[0])
		(v[1] as Node).free()
	# La geometrie : le logo (case reduite du contour) garde sa taille.
	var px: float = 96.0
	var art: Control = CardView.with_type_badge(CardIcons.make_rect(c, px), c, px)
	var badge2: TextureRect = art.find_child("TypeBadge", true, false)
	var cote: float = maxf(px * CardView.BADGE_RATIO, CardView.BADGE_MIN)
	var case: float = badge2.offset_right - badge2.offset_left
	feq(case / (1.0 + 2.0 * CardView.SEAL_OUTLINE), cote, "le logo dessine garde sa taille", 0.01)
	feq(badge2.offset_left + (case - cote) * 0.5, -cote * 0.22, "et sa place", 0.01)
	art.free()


# --- CONTRASTE ------------------------------------------------------------------

func _lum(c: Color) -> float:
	var f := func(x: float) -> float:
		return x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func _ratio(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Les encres de sens du briefing et du bilan tiennent le plancher sur le papier
## REEL (le centre de la texture), pas sur un fond suppose.
func _test_les_encres_du_papier_tiennent_le_contraste() -> void:
	var tex: Texture2D = UiTheme.tex("paper9")
	ok(tex != null, "(la texture du papier se lit)")
	if tex == null:
		return
	var img: Image = tex.get_image()
	var papier: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	ok(absf(papier.r - UiTheme.PAPER_CREAM.r) < 0.02 and absf(papier.g - UiTheme.PAPER_CREAM.g) < 0.02
		and absf(papier.b - UiTheme.PAPER_CREAM.b) < 0.02, "PAPER_CREAM est le papier mesure")
	for paire in [["INK_DANGER", UiTheme.INK_DANGER], ["INK_SUCCESS", UiTheme.INK_SUCCESS],
			["INK_HINT", UiTheme.INK_HINT], ["INK_HEADING", UiTheme.INK_HEADING],
			["INK_SOFT", UiTheme.INK_SOFT]]:
		ok(_ratio(paire[1], papier) >= UiTheme.CONTRAST_MIN,
			"%s : %.2f:1 sur le papier" % [paire[0], _ratio(paire[1], papier)])
