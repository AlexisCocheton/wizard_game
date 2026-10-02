extends TestCase
## CHANTIER W8 — vagues qui trainent, protecteurs, devoreurs.
##
##   - VAGUE QUI TRAINE : GameConfig.WAVE_OVERTIME_SECONDS de monde apres la
##     derniere apparition, la vague suivante demarre meme si des monstres
##     restent ; jamais la derniere (la victoire attend que TOUT soit mort), jamais
##     une vague de boss, jamais pour ouvrir une vague de boss en avance.
##   - PROTECTEURS : deux porteurs d aura croises se couvrent l un l autre ; la
##     dissipation coupe l aura du porteur touche ; si plus rien n est a decouvert,
##     les auras cedent d elles-memes (pat d aura).
##   - DEVOREURS : la force (contact, tir) croit avec les proies, plafonnee ; le
##     devoreur qui se soigne n en gagne pas.

func get_suite_name() -> String:
	return "waves_protectors_w8"


var _bf: Battlefield = null


func run() -> void:
	_test_la_vague_qui_traine_laisse_place_a_la_suivante()
	_test_la_derniere_vague_ne_s_ecourte_jamais()
	_test_les_vagues_de_boss_ne_sont_pas_court_circuitees()
	_test_en_partie_la_victoire_attend_tous_les_restants()
	_test_deux_totems_croises_se_protegent()
	_test_la_dissipation_coupe_l_aura_meme_entre_protecteurs()
	_test_l_aura_revient_apres_la_coupure()
	_test_le_pat_d_aura_rend_la_vague_battable()
	_test_pas_de_pat_tant_qu_une_cible_est_a_decouvert()
	_test_le_glouton_gagne_en_force_plafonnee()
	_test_le_devoreur_soigneur_ne_gagne_pas_en_force()
	_test_l_arrivee_sur_le_mage_frappe_avec_la_force()
	if _bf != null:
		detach(_bf)
		_bf = null
	RunState.reset()
	SpeedGauge.reset()


# --- Fabriques ---

func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()


## `seconds` de MONDE a x1, mage maintenu en vie (voir test_enemy_behaviors).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(1.0 / 60.0)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
		t += 1.0 / 60.0


## Un monstre qui CAMPE : immobile, solide, il ne meurt ni n atteint le mage.
func _campeur(id: String = "t_campeur") -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 1000.0
	d.base_speed = 0.0
	d.power = 1
	return d


func _vague(id: String, defs: Array, boss: bool = false, miniboss: bool = false) -> WaveDef:
	var w := WaveDef.new()
	w.id = StringName(id)
	w.is_boss = boss
	w.is_miniboss = miniboss
	var entrees: Array[WaveEntry] = []
	for d in defs:
		var e := WaveEntry.new()
		e.enemy = d
		e.count = 1
		entrees.append(e)
	w.entries = entrees
	return w


func _spawner(vagues: Array) -> WaveSpawner:
	var sp := WaveSpawner.new()
	attach(sp)
	var typed: Array[WaveDef] = []
	for w in vagues:
		typed.append(w)
	sp.setup(_bf, typed, 4242)
	return sp


## Fait tourner le spawner `seconds` de monde a x1 ; rend le nombre de vagues
## ecourtees pendant ce temps.
func _tick(sp: WaveSpawner, seconds: float) -> int:
	var avant: int = sp.overtime_count
	var t: float = 0.0
	while t < seconds and sp.active:
		SpeedGauge.set_speed_percent(100)
		sp.tick(1.0 / 60.0)
		t += 1.0 / 60.0
	return sp.overtime_count - avant


func _carte_arcane() -> SpellCard:
	var c := SpellCard.new()
	c.id = &"t_arcane"
	c.tags = [GameEnums.DamageTag.ARCANE]
	return c


# --- VAGUES ---

func _test_la_vague_qui_traine_laisse_place_a_la_suivante() -> void:
	_fresh()
	var sp: WaveSpawner = _spawner([_vague("a", [_campeur()]), _vague("b", [_campeur()]),
		_vague("c", [_campeur()])])
	var vu: Array[int] = []
	sp.wave_overtime.connect(func(i: int) -> void: vu.append(i))
	sp.start_next()
	eq(_tick(sp, GameConfig.WAVE_OVERTIME_SECONDS - 1.0), 0,
		"avant le delai, la vague attend ses restants")
	ok(sp.active, "elle est toujours en cours")
	ok(sp.overtime_left() > 0.0, "le compte a rebours est lisible")
	eq(_tick(sp, 2.0), 1, "passe le delai, elle cede la place")
	not_ok(sp.active, "la vague est close")
	eq(vu.size(), 1, "un seul signal")
	if vu.size() == 1:
		eq(vu[0], 0, "le signal nomme la vague ecourtee")
	eq(_bf.alive_count(), 1, "le restant reste en jeu")
	ok(sp.start_next(), "la suivante peut demarrer")
	eq(sp.index, 1, "c est bien la suivante")


func _test_la_derniere_vague_ne_s_ecourte_jamais() -> void:
	_fresh()
	var sp: WaveSpawner = _spawner([_vague("seule", [_campeur()])])
	sp.start_next()
	not_ok(sp.can_cut_short(), "la derniere vague ne s ecourte pas")
	eq(_tick(sp, GameConfig.WAVE_OVERTIME_SECONDS * 3.0), 0,
		"meme tres au-dela du delai : la victoire attend que tout soit mort")
	ok(sp.active, "elle reste en cours")
	feq(sp.overtime_left(), -1.0, "aucun compte a rebours affiche")


func _test_les_vagues_de_boss_ne_sont_pas_court_circuitees() -> void:
	_fresh()
	var sp: WaveSpawner = _spawner([_vague("boss", [_campeur()], true),
		_vague("apres", [_campeur()])])
	sp.start_next()
	not_ok(sp.can_cut_short(), "une vague de boss se joue jusqu au bout")
	eq(_tick(sp, GameConfig.WAVE_OVERTIME_SECONDS * 2.0), 0, "aucune vague par-dessus le boss")
	_fresh()
	var sp2: WaveSpawner = _spawner([_vague("avant", [_campeur()]),
		_vague("mini", [_campeur()], false, true), _vague("fin", [_campeur()])])
	sp2.start_next()
	not_ok(sp2.can_cut_short(), "on n ouvre pas une vague de mini-boss en avance")
	eq(_tick(sp2, GameConfig.WAVE_OVERTIME_SECONDS * 2.0), 0,
		"le boss se presente sur un terrain nettoye")
	# Le mode infini lit la cadence de WaveBudget : meme regle.
	_fresh()
	var sp3 := WaveSpawner.new()
	attach(sp3)
	var pool: Array[EnemyDef] = [_campeur()]
	var aucun: Array[EnemyDef] = []
	sp3.setup_procedural(_bf, pool, aucun, 7, {}, false)
	var n_boss: int = WaveBudget.MINIBOSS_EVERY
	for i in n_boss - 1:
		sp3.start_next()
	eq(sp3.index + 2, n_boss, "(la vague suivante est un palier)")
	not_ok(sp3.can_cut_short(), "en infini, la vague qui precede un palier ne s ecourte pas")


func _test_en_partie_la_victoire_attend_tous_les_restants() -> void:
	var lvl: LevelDef = (ContentDB.levels.get(&"lvl_01") as LevelDef).duplicate()
	var campeur: EnemyDef = _campeur("t_campeur_partie")
	var dernier: EnemyDef = _campeur("t_dernier")
	var vagues: Array[WaveDef] = [_vague("p1", [campeur]), _vague("p2", [dernier])]
	lvl.waves = vagues
	var g: GameController = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	g.headless_mode = true
	attach(g)
	var gagne: Array[bool] = [false]
	g.level_won.connect(func() -> void: gagne[0] = true)
	g.start_level(lvl, GameEnums.Mode.EXPLORATION)
	g.running = false
	g.set_process(false)
	var hud: Node = g.get_node_or_null("HUD")
	var annonce: String = ""
	var t: float = 0.0
	while t < GameConfig.WAVE_OVERTIME_SECONDS + 5.0 and g.spawner.index < 1:
		SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT)
		g.simulate(1.0 / 30.0)
		t += 1.0 / 30.0
		if hud != null and annonce == "":
			annonce = String(hud.call("overtime_banner_text"))
	eq(g.spawner.index, 1, "la seconde vague arrive alors que le campeur vit")
	eq(RunState.wave_index, 1, "le compteur de vagues avance")
	if hud != null:
		ok(annonce != "", "le HUD annonce « la vague suivante arrive »")
	# Tuer le monstre de la DERNIERE vague ne suffit pas : le campeur reste.
	for i in 90:
		SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT)
		g.simulate(1.0 / 30.0)
	for e in g.battlefield.enemies.duplicate():
		if e.definition == dernier:
			e.kill()
	for i in 60:
		SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT)
		g.simulate(1.0 / 30.0)
	not_ok(gagne[0], "pas de victoire tant qu un restant vit")
	for e in g.battlefield.enemies.duplicate():
		e.kill()
	for i in 60:
		if gagne[0]:
			break
		SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT)
		g.simulate(1.0 / 30.0)
	ok(gagne[0], "tout mort : victoire")
	detach(g)
	RunState.reset()


# --- PROTECTEURS ---

## Deux Gardiens-totems a portee l un de l autre, rien d autre, fondu passe.
func _deux_totems() -> Array[Enemy]:
	_fresh()
	var d: EnemyDef = ContentDB.enemies.get(&"totem_guardian")
	var ecart: float = d.aura_shield_radius * 0.5
	var a: Enemy = _bf.spawn_enemy(d, 400.0, 1.0, Vector2(400.0, 500.0))
	var b: Enemy = _bf.spawn_enemy(d, 400.0 + ecart, 1.0, Vector2(400.0 + ecart, 500.0))
	_sim(GameConfig.SPAWN_FADE_TIME + 0.1)
	return [a, b]


func _test_deux_totems_croises_se_protegent() -> void:
	var t: Array[Enemy] = _deux_totems()
	ok(_bf.is_shielded_by_aura(t[0]) and _bf.is_shielded_by_aura(t[1]),
		"deux protecteurs se couvrent l un l autre (« deux tours, c est ok »)")
	var pv: float = t[0].hp
	not_ok(_bf.damage_enemy(t[0], 10.0, _carte_arcane()), "aucun degat ne passe")
	feq(t[0].hp, pv, "les PV ne bougent pas")


func _test_la_dissipation_coupe_l_aura_meme_entre_protecteurs() -> void:
	var t: Array[Enemy] = _deux_totems()
	var arcane: Array = [GameEnums.DamageTag.ARCANE]
	# Une petite zone sur le PREMIER seulement.
	var r: float = t[0].position.distance_to(t[1].position) * 0.25
	eq(_bf.dispel_at(t[0].position, r, arcane), 1, "(un seul porteur dans la zone)")
	not_ok(t[0].aura_active(), "son aura est coupee")
	ok(t[1].aura_active(), "celle du voisin, non touche, tient")
	feq(t[0].aura_off_left(), GameConfig.AURA_DISPEL_SECONDS, "pour la duree reglee", 0.05)
	not_ok(_bf.is_shielded_by_aura(t[1]), "le voisin n a plus de protecteur : il est frappable")
	ok(_bf.is_shielded_by_aura(t[0]), "le dissipe reste couvert par le voisin")
	var pv: float = t[1].hp
	ok(_bf.damage_enemy(t[1], 10.0, _carte_arcane()), "le coup passe sur le voisin")
	ok(t[1].hp < pv, "et retire des PV")
	# Une zone qui couvre les DEUX : plus rien ne protege personne.
	var milieu: Vector2 = (t[0].position + t[1].position) * 0.5
	_bf.dispel_at(milieu, t[0].position.distance_to(t[1].position), arcane)
	not_ok(_bf.is_shielded_by_aura(t[0]) or _bf.is_shielded_by_aura(t[1]),
		"dissipes ensemble, les deux sont frappables")


func _test_l_aura_revient_apres_la_coupure() -> void:
	var t: Array[Enemy] = _deux_totems()
	t[0].suppress_aura(GameConfig.AURA_DISPEL_SECONDS)
	t[1].suppress_aura(GameConfig.AURA_DISPEL_SECONDS)
	_sim(GameConfig.AURA_DISPEL_SECONDS * 0.5)
	not_ok(t[0].aura_active(), "a mi-coupure, l aura est toujours eteinte")
	_sim(GameConfig.AURA_DISPEL_SECONDS * 0.5 + 0.1)
	ok(t[0].aura_active() and t[1].aura_active(), "la coupure finie, les auras reviennent")
	ok(_bf.is_shielded_by_aura(t[0]), "et protegent de nouveau")


func _test_le_pat_d_aura_rend_la_vague_battable() -> void:
	var t: Array[Enemy] = _deux_totems()
	ok(_bf.all_targets_shielded(), "(plus rien n est a decouvert)")
	_sim(GameConfig.AURA_STALEMATE_SECONDS * 0.5)
	ok(t[0].aura_active() and t[1].aura_active(), "le pat ne cede pas tout de suite")
	_sim(GameConfig.AURA_STALEMATE_SECONDS * 0.5 + 0.2)
	not_ok(t[0].aura_active() or t[1].aura_active(), "le pat dure : les auras cedent")
	ok(_bf.damage_enemy(t[0], 10.0, _carte_arcane()), "la vague redevient battable")


func _test_pas_de_pat_tant_qu_une_cible_est_a_decouvert() -> void:
	var t: Array[Enemy] = _deux_totems()
	var d: EnemyDef = ContentDB.enemies.get(&"totem_guardian")
	var loin := Vector2(t[1].position.x + d.aura_shield_radius * 2.5, 500.0)
	_bf.spawn_enemy(_campeur("t_decouvert"), loin.x, 1.0, loin)
	_sim(GameConfig.SPAWN_FADE_TIME + GameConfig.AURA_STALEMATE_SECONDS + 0.5)
	not_ok(_bf.all_targets_shielded(), "(un monstre est a decouvert)")
	ok(t[0].aura_active() and t[1].aura_active(),
		"tant qu il reste quelque chose a frapper, les auras tiennent")


# --- DEVOREURS ---

func _proie(pos: Vector2) -> Enemy:
	var d := _campeur("t_proie")
	d.max_hp = 10.0
	return _bf.spawn_enemy(d, pos.x, 1.0, pos)


func _test_le_glouton_gagne_en_force_plafonnee() -> void:
	_fresh()
	var d: EnemyDef = ContentDB.enemies.get(&"glutton")
	var pos := Vector2(500.0, 400.0)
	var g: Enemy = _bf.spawn_enemy(d, pos.x, 1.0, pos)
	_proie(pos + Vector2(8.0, 0.0))
	var base: int = d.contact_hit()
	eq(g.contact_damage(), base, "a jeun, le bareme de sa definition")
	_sim(GameConfig.SPAWN_FADE_TIME + 0.2)
	eq(g.devour_prey, 1, "(il a avale sa proie)")
	eq(g.contact_damage(), int(round(base * (1.0 + GameConfig.DEVOUR_FORCE_PER_PREY))),
		"une proie : il frappe plus fort")
	ok(g.contact_damage() > base, "la force croit")
	g.devour_prey = 1000
	eq(g.contact_damage(), int(round(base * (1.0 + GameConfig.DEVOUR_FORCE_CAP))),
		"plafonnee, meme repu")
	g.devour_prey = 1
	eq(g.shot_damage_now(), int(round(d.shot_damage * (1.0 + GameConfig.DEVOUR_FORCE_PER_PREY))),
		"le tir suit la meme force")


func _test_le_devoreur_soigneur_ne_gagne_pas_en_force() -> void:
	_fresh()
	var d: EnemyDef = ContentDB.enemies.get(&"demon_lord")
	ok(d.devours and d.devour_heal_pct > 0.0, "(le Seigneur demon avale et se soigne)")
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	e.devour_prey = 5
	eq(e.contact_damage(), d.contact_hit(), "son gain est le soin, pas la force")


func _test_l_arrivee_sur_le_mage_frappe_avec_la_force() -> void:
	_fresh()
	reset_gauge_with_survivable_mage()
	var d: EnemyDef = ContentDB.enemies.get(&"glutton")
	var g: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	g.devour_prey = 2
	var recu: Array[int] = [0]
	_bf.mage_hit.connect(func(dmg: int, _src: EnemyDef) -> void: recu[0] = dmg)
	var attendu: int = g.contact_damage()
	_bf._on_enemy_reached_mage(g)
	eq(recu[0], attendu, "le coup au mage porte la force du devoreur")
	ok(recu[0] > d.contact_hit(), "plus fort que le bareme de sa definition")
	SpeedGauge.reset()
