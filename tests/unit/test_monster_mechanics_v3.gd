extends TestCase
## Les mecaniques de monstres v3 (groupe « Comportements v3 » d EnemyDef).
##
##   1. plusieurs vies        -> revient DU HAUT, de plus en plus vite, une mort comptee
##   2. renaissance differee  -> une marque, un delai, la vague attend
##   3. reanimateur           -> releve les morts proches, avec un plafond
##   4. laser de riposte      -> tire a chaque degat, avec un delai minimal
##   5. sommeil               -> coupe la magie, fenetre garantie entre dormeurs
##   6. motifs de deplacement -> zigzag, rebond, sauts ; les murs gardent la main
##   7. entree par le cote    -> un gros monstre reste dans le cadre
##   8. bestiaire             -> chaque mecanique dite en clair, avec ses chiffres
##
## Chaque mecanique a un test qui la DECLENCHE et un test qui verifie qu elle se
## TERMINE : un comportement sans plafond est une vague sans fin. Les monstres
## sont construits en code : le contenu (les .tres) viendra d un autre chantier.
## Aucune valeur d equilibrage n est figee ; les bornes de securite (plafonds)
## sont ecrites en dur quand un test relisant la constante ne mordrait pas.

func get_suite_name() -> String:
	return "monstres_v3"

var _bf: Battlefield = null
var _tues: int = 0
## XP recue, sommee sur le signal : RunState.xp repart a zero a chaque montee de
## niveau, une difference de `xp` mentirait des qu un palier tombe.
var _xp_recu: int = 0


func _def(id: String, hp: float = 100.0, speed: float = 60.0, power: int = 1) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	d.base_speed = speed
	d.power = power
	d.base_radius = 32.0
	return d


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()
	_tues = 0
	_xp_recu = 0
	if not RunState.xp_gained.is_connected(_compte_xp):
		RunState.xp_gained.connect(_compte_xp)
	if not _bf.enemy_killed.is_connected(_compte_mort):
		_bf.enemy_killed.connect(_compte_mort)


func _compte_mort(_d: EnemyDef) -> void:
	_tues += 1


func _compte_xp(amount: int) -> void:
	_xp_recu += amount


## Simule `seconds` de MONDE a x1 en gardant le mage en vie (voir test_bosses).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_step()
		t += 1.0 / 60.0


func _step() -> void:
	_bf.simulate(1.0 / 60.0)
	if SpeedGauge.is_dying:
		SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)


func _vivants() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in _bf.enemies:
		if e != null and is_instance_valid(e) and not e.is_dead():
			out.append(e)
	return out


func _contient(lignes: Array[String], mot: String) -> bool:
	for l in lignes:
		if l.to_lower().contains(mot.to_lower()):
			return true
	return false


func run() -> void:
	_test_vies_repartent_du_haut()
	_test_vies_repit_a_chaque_retour()
	_test_vies_de_plus_en_plus_rapides()
	_test_vies_une_seule_mort_comptee()
	_test_vies_et_releve_sur_place_se_cumulent()
	_test_renaissance_attend_son_delai()
	_test_renaissance_retient_la_fin_de_vague()
	_test_renaissance_se_termine()
	_test_renaissance_effacee_avec_la_partie()
	_test_reanimateur_releve_un_mort_proche()
	_test_reanimateur_ignore_les_morts_lointaines_et_froides()
	_test_reanimateur_a_un_plafond()
	_test_revenant_ne_rapporte_rien()
	_test_laser_riposte_a_un_coup()
	_test_laser_respecte_son_delai_minimal()
	_test_laser_plancher_moteur()
	_test_laser_ne_part_pas_sur_un_coup_absorbe()
	_test_laser_arrete_par_un_mur()
	_test_sommeil_coupe_la_magie_puis_la_rend()
	_test_sommeil_tuer_le_dormeur_rend_la_magie()
	_test_sommeil_la_main_reste_grisee()
	_test_sommeil_fenetre_garantie_entre_dormeurs()
	_test_sommeil_plafonne()
	_test_motif_droit_par_defaut()
	_test_motif_zigzag()
	_test_motif_rebond()
	_test_motif_sauts()
	_test_motif_au_sol_ne_traverse_pas_un_mur()
	_test_motif_au_sol_enferme_ne_traverse_pas()
	_test_motif_volant_ignore_les_murs()
	_test_motif_spirale()
	_test_motif_spirale_sans_recul_par_defaut()
	_test_motif_au_sol_ne_traverse_pas_un_mur(EnemyDef.MovePattern.SPIRAL)
	_test_motif_au_sol_enferme_ne_traverse_pas(EnemyDef.MovePattern.SPIRAL)
	_test_motif_volant_ignore_les_murs(EnemyDef.MovePattern.SPIRAL)
	_test_gros_monstre_par_le_cote_reste_visible()
	_test_gros_monstre_par_le_cote_ne_se_coince_pas()
	_test_bestiaire_dit_chaque_mecanique()
	if _bf != null:
		detach(_bf)
		_bf = null
	# RunState survit a la suite : on ne lui laisse pas un rappel vers un test fini.
	if RunState.xp_gained.is_connected(_compte_xp):
		RunState.xp_gained.disconnect(_compte_xp)


# --- 1. PLUSIEURS VIES ---------------------------------------------------------

func _test_vies_repartent_du_haut() -> void:
	_fresh()
	var d := _def("trois_vies", 40.0)
	d.extra_lives = 3
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	e.take_damage(999.0, [])
	not_ok(e.is_dead(), "a zero PV il ne meurt pas : il lui reste des vies")
	feq(e.position.y, GameConfig.SPAWN_LINE_Y, "il repart du HAUT du terrain")
	feq(e.position.x, 500.0, "dans la meme colonne")
	eq(e.lives_left(), d.extra_lives - 1, "une vie consommee")
	feq(e.hp, e.max_hp(), "avec ses PV (100 % par defaut)")
	eq(_bf.alive_count(), 1, "c est le MEME monstre, pas un second")


func _test_vies_repit_a_chaque_retour() -> void:
	_fresh()
	var d := _def("repit", 40.0)
	d.extra_lives = 2
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	e.take_damage(999.0, [])
	not_ok(e.take_damage(999.0, []), "juste revenu : intouchable le temps du repit")
	eq(e.lives_left(), d.extra_lives - 1, "le sort qui l a tue ne lui prend pas une 2e vie")
	_sim(Enemy.REVIVE_GRACE + 0.1)
	ok(e.take_damage(1.0, []), "le repit passe, il redevient touchable")


func _test_vies_de_plus_en_plus_rapides() -> void:
	_fresh()
	var d := _def("rapide", 40.0, 60.0)
	d.extra_lives = 2
	d.extra_life_speed_pct = 40.0
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	var parcours: Array[float] = []
	for vie in d.extra_lives + 1:
		# On laisse passer le repit (il ne gele pas la marche), puis on mesure.
		_sim(Enemy.REVIVE_GRACE + 0.05)
		var y0: float = e.position.y
		_sim(1.0)
		parcours.append(e.position.y - y0)
		if vie < d.extra_lives:
			e.take_damage(999.0, [])
	for i in range(1, parcours.size()):
		# Le rapport est celui du champ, pas un nombre recopie : +40 % par vie.
		var attendu: float = (1.0 + i * d.extra_life_speed_pct * 0.01) \
			/ (1.0 + (i - 1) * d.extra_life_speed_pct * 0.01)
		feq(parcours[i] / maxf(parcours[i - 1], 0.001), attendu,
			"vie %d : plus rapide que la precedente dans le rapport du champ" % (i + 1), 0.03)


func _test_vies_une_seule_mort_comptee() -> void:
	_fresh()
	var d := _def("compte", 20.0)
	d.extra_lives = 3
	d.base_xp = 10
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	var morts: int = 0
	# Plafond : au plus 1 + extra_lives coups mortels. On en tente davantage pour
	# verifier que la mecanique SE TERMINE.
	for i in 10:
		if e.is_dead():
			break
		e.take_damage(999.0, [])
		morts += 1
		_sim(Enemy.REVIVE_GRACE + 0.05)
	ok(e.is_dead(), "il finit par mourir pour de bon")
	eq(morts, d.extra_lives + 1, "au bout de exactement 1 + extra_lives morts")
	eq(_tues, 1, "une seule mort comptee (objectifs, bestiaire)")
	ok(_xp_recu > 0, "l XP tombe a la mort definitive")
	var xp_une_fois: int = _xp_recu
	# Un monstre ordinaire de meme XP rapporte autant : pas de ferme d XP.
	var n := _def("temoin", 20.0)
	n.base_xp = 10
	var t: Enemy = _bf.spawn_enemy(n, 500.0, 1.0, Vector2(500.0, 900.0))
	_xp_recu = 0
	t.take_damage(999.0, [])
	eq(_xp_recu, xp_une_fois, "et une seule fois : autant qu un monstre a une vie")
	_sim(0.1)
	eq(_bf.alive_count(), 0, "il quitte le terrain")


func _test_vies_et_releve_sur_place_se_cumulent() -> void:
	_fresh()
	var d := _def("phenix_v3", 100.0)
	d.revive_hp_pct = 50.0
	d.extra_lives = 1
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	e.take_damage(999.0, [])
	feq(e.position.y, 900.0, "le releve historique passe d abord, SUR PLACE")
	ok(e.has_revived(), "le releve est consomme")
	_sim(Enemy.REVIVE_GRACE + 0.05)
	var y: float = e.position.y
	e.take_damage(999.0, [])
	ok(y > GameConfig.SPAWN_LINE_Y + 100.0, "(il etait bien descendu)")
	feq(e.position.y, GameConfig.SPAWN_LINE_Y, "puis la vie supplementaire, depuis le haut")


# --- 2. RENAISSANCE DIFFEREE ---------------------------------------------------

func _fantome() -> EnemyDef:
	var enfant := _def("slime_ne", 10.0)
	var d := _def("slime_fantome", 10.0, 0.0)
	d.rebirth_def = enfant
	d.rebirth_count = 2
	d.rebirth_delay = 3.0
	return d


func _test_renaissance_attend_son_delai() -> void:
	_fresh()
	var d := _fantome()
	var e: Enemy = _bf.spawn_enemy(d, 400.0, 1.0, Vector2(400.0, 700.0))
	e.take_damage(999.0, [])
	_sim(0.05)
	eq(_bf.alive_count(), 0, "a sa mort, rien ne nait tout de suite")
	eq(_bf.pending_rebirth_count(), 1, "mais une marque est au sol")
	not_ok(_bf.is_clear(), "et le terrain n est PAS considere comme vide")
	_sim(d.rebirth_delay * 0.5)
	eq(_bf.alive_count(), 0, "a mi-delai, toujours rien")
	_sim(d.rebirth_delay * 0.5 + 0.1)
	eq(_bf.alive_count(), d.rebirth_count, "le delai passe, N exemplaires naissent")
	eq(_bf.pending_rebirth_count(), 0, "la marque est consommee")
	for c in _vivants():
		eq(c.definition, d.rebirth_def, "c est l AUTRE monstre qui nait")
		ok(c.position.distance_to(Vector2(400.0, 700.0)) < 120.0, "a l endroit de la mort")


func _test_renaissance_retient_la_fin_de_vague() -> void:
	_fresh()
	var d := _fantome()
	var entree := WaveEntry.new()
	entree.enemy = d
	entree.count = 1
	var vague := WaveDef.new()
	var entrees: Array[WaveEntry] = [entree]
	vague.entries = entrees
	var sp := WaveSpawner.new()
	var liste: Array[WaveDef] = [vague]
	sp.setup(_bf, liste, 7)
	var nettoyees: Array[int] = []
	sp.wave_cleared.connect(func(i: int) -> void: nettoyees.append(i))
	sp.start_next()
	for i in 60:
		sp.tick(1.0 / 60.0)
		_step()
	eq(_bf.alive_count(), 1, "le fantome est entre")
	_vivants()[0].kill()
	for i in 60:
		sp.tick(1.0 / 60.0)
		_step()
	eq(nettoyees.size(), 0, "marque au sol : la vague n est PAS finie")
	ok(sp.active, "le deroule attend la renaissance")
	_sim(d.rebirth_delay)
	sp.tick(1.0 / 60.0)
	eq(nettoyees.size(), 0, "les enfants sont nes : toujours pas finie")
	for c in _vivants():
		c.kill()
	_step()
	sp.tick(1.0 / 60.0)
	eq(nettoyees.size(), 1, "enfants tues : la vague se termine, une fois")
	sp.free()


func _test_renaissance_se_termine() -> void:
	_fresh()
	# Le pire contenu possible : un fantome qui renait en LUI-MEME, deux fois.
	var d := _def("boucle", 5.0, 0.0)
	d.rebirth_def = d
	d.rebirth_count = 2
	d.rebirth_delay = 0.5
	_bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 700.0))
	var tours: int = 0
	# Borne ecrite en dur : si le plafond de generations disparaissait, ce test
	# ne finirait jamais de nettoyer le terrain en six tours.
	while not _bf.is_clear() and tours < 6:
		tours += 1
		for c in _vivants():
			c.kill()
		_sim(d.rebirth_delay + 0.1)
	ok(_bf.is_clear(), "la chaine de renaissances finit par s arreter")
	ok(tours <= 4, "en quelques generations seulement (%d tours)" % tours)


func _test_renaissance_effacee_avec_la_partie() -> void:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_fantome(), 400.0, 1.0, Vector2(400.0, 700.0))
	e.kill()
	eq(_bf.pending_rebirth_count(), 1, "une marque en attente")
	_bf.clear_all()
	eq(_bf.pending_rebirth_count(), 0, "rejouer efface les marques")
	_sim(5.0)
	eq(_bf.alive_count(), 0, "et rien ne nait dans la partie suivante")


# --- 3. REANIMATEUR ------------------------------------------------------------

func _pretre(maxi: int = 2) -> EnemyDef:
	var d := _def("pretre", 200.0, 0.0)
	d.reanimate_radius = 300.0
	d.reanimate_interval = 1.0
	d.reanimate_max = maxi
	return d


func _test_reanimateur_releve_un_mort_proche() -> void:
	_fresh()
	var p: Enemy = _bf.spawn_enemy(_pretre(), 500.0, 1.0, Vector2(500.0, 400.0))
	var v: Enemy = _bf.spawn_enemy(_def("victime", 10.0, 0.0), 560.0, 1.0, Vector2(560.0, 520.0))
	v.kill()
	eq(_bf.alive_count(), 1, "la victime est tombee")
	_sim(p.definition.reanimate_interval + GameConfig.SPAWN_FADE_TIME + 0.1)
	eq(_bf.alive_count(), 2, "le reanimateur l a relevee")
	var revenant: Enemy = null
	for e in _vivants():
		if e != p:
			revenant = e
	ok(revenant != null and revenant.is_reanimated(), "et c est un revenant marque")
	ok(revenant != null and revenant.position.distance_to(Vector2(560.0, 520.0)) < 1.0,
		"la ou il etait tombe")


func _test_reanimateur_ignore_les_morts_lointaines_et_froides() -> void:
	_fresh()
	var p: Enemy = _bf.spawn_enemy(_pretre(), 200.0, 1.0, Vector2(200.0, 400.0))
	var loin: Enemy = _bf.spawn_enemy(_def("loin", 10.0, 0.0), 900.0, 1.0, Vector2(900.0, 1100.0))
	loin.kill()
	_sim(p.definition.reanimate_interval * 3.0)
	eq(_bf.alive_count(), 1, "une mort hors de son rayon ne se releve pas")
	# Une mort ANCIENNE est oubliee : un reanimateur qui arrive tard ne releve pas
	# tout le debut de la bataille.
	_fresh()
	var v: Enemy = _bf.spawn_enemy(_def("froid", 10.0, 0.0), 500.0, 1.0, Vector2(500.0, 500.0))
	v.kill()
	_sim(Battlefield.REANIMATE_MEMORY + 0.5)
	_bf.spawn_enemy(_pretre(), 500.0, 1.0, Vector2(500.0, 420.0))
	_sim(3.0)
	eq(_bf.alive_count(), 1, "un corps froid ne se releve pas")


func _test_reanimateur_a_un_plafond() -> void:
	_fresh()
	var d := _pretre(3)
	var p: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_bf.spawn_enemy(_def("chair", 10.0, 0.0), 560.0, 1.0, Vector2(560.0, 520.0))
	# On tue en boucle tout ce qui n est pas le pretre : sans plafond, cela ne
	# finirait jamais. Borne de boucle ecrite en dur.
	for i in 12:
		for e in _vivants():
			if e != p:
				e.take_damage(999.0, [])
		_sim(d.reanimate_interval + GameConfig.SPAWN_FADE_TIME + 0.1)
	for e in _vivants():
		if e != p:
			e.take_damage(999.0, [])
	_sim(d.reanimate_interval * 3.0)
	eq(p.reanimations_done(), d.reanimate_max, "il a releve exactement son plafond")
	eq(_bf.reanimations, d.reanimate_max, "et pas un de plus sur le terrain")
	eq(_bf.alive_count(), 1, "la mecanique est terminee : il reste seul")


func _test_revenant_ne_rapporte_rien() -> void:
	_fresh()
	var p: Enemy = _bf.spawn_enemy(_pretre(1), 500.0, 1.0, Vector2(500.0, 400.0))
	var d := _def("chair2", 10.0, 0.0)
	d.base_xp = 10
	var v: Enemy = _bf.spawn_enemy(d, 560.0, 1.0, Vector2(560.0, 520.0))
	v.kill()
	var xp_apres_premiere: int = _xp_recu
	eq(_tues, 1, "premiere mort comptee")
	_sim(p.definition.reanimate_interval + GameConfig.SPAWN_FADE_TIME + 0.1)
	for e in _vivants():
		if e != p:
			e.take_damage(999.0, [])
	eq(_tues, 1, "le revenant tue ne compte pas une seconde fois")
	eq(_xp_recu, xp_apres_premiere, "et ne rapporte aucune XP")


# --- 4. LASER DE RIPOSTE -------------------------------------------------------

func _golem() -> EnemyDef:
	var d := _def("mecha_golem", 5000.0, 0.0)
	d.laser_damage = 6
	d.laser_cooldown = 1.0
	return d


func _test_laser_riposte_a_un_coup() -> void:
	_fresh()
	var g: Enemy = _bf.spawn_enemy(_golem(), 540.0, 1.0, Vector2(540.0, 600.0))
	reset_gauge_with_survivable_mage()
	var avant: int = SpeedGauge.speed_percent
	ok(_bf._hit(g, 1.0, []), "le coup mord")
	eq(_bf.lasers_fired, 1, "un coup recu : un laser tire")
	eq(avant - SpeedGauge.speed_percent, g.definition.laser_damage,
		"le laser coute au mage ses points de vitesse")


func _test_laser_respecte_son_delai_minimal() -> void:
	_fresh()
	var d := _golem()
	var g: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 600.0))
	# Une Mare de venin : un coup a chaque image.
	_bf.zones.append({"pos": g.position, "radius": 200.0, "time": 99.0, "dps": 1.0,
		"slow_pct": 0.0, "vuln_mult": 1.0, "tags": [], "node": null})
	_sim(d.laser_cooldown * 0.5)
	eq(_bf.lasers_fired, 1, "trente coups en une demi-seconde : UN seul laser")
	var duree: float = d.laser_cooldown * 4.0
	_sim(duree)
	ok(_bf.lasers_fired >= 4, "le delai passe, il riposte de nouveau (%d)" % _bf.lasers_fired)
	ok(_bf.lasers_fired <= int(duree / d.laser_cooldown) + 2,
		"mais jamais plus d un par delai (%d)" % _bf.lasers_fired)


func _test_laser_plancher_moteur() -> void:
	_fresh()
	var d := _golem()
	d.laser_cooldown = 0.0   # contenu oublie : le moteur doit tenir quand meme
	var g: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 600.0))
	_bf.zones.append({"pos": g.position, "radius": 200.0, "time": 99.0, "dps": 1.0,
		"slow_pct": 0.0, "vuln_mult": 1.0, "tags": [], "node": null})
	_sim(1.0)
	# 60 coups en une seconde. Borne en dur : un plancher retire laisserait passer
	# des dizaines de lasers.
	ok(_bf.lasers_fired <= 3, "un delai a zero ne fait pas une rafale (%d)" % _bf.lasers_fired)


func _test_laser_ne_part_pas_sur_un_coup_absorbe() -> void:
	_fresh()
	var d := _golem()
	d.first_hit_shield = true
	var g: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 600.0))
	_bf._hit(g, 1.0, [])
	eq(_bf.lasers_fired, 0, "un coup absorbe par le bouclier n est pas une blessure")
	var d2 := _golem()
	d2.max_hp = 5.0
	var g2: Enemy = _bf.spawn_enemy(d2, 300.0, 1.0, Vector2(300.0, 600.0))
	_bf._hit(g2, 999.0, [])
	eq(_bf.lasers_fired, 0, "un golem tue d un coup ne tire pas depuis la tombe")


func _test_laser_arrete_par_un_mur() -> void:
	_fresh()
	var g: Enemy = _bf.spawn_enemy(_golem(), 540.0, 1.0, Vector2(540.0, 500.0))
	_bf.spawn_wall(Vector2(540.0, 1000.0), 200.0, 30.0)
	reset_gauge_with_survivable_mage()
	var avant: int = SpeedGauge.speed_percent
	_bf._hit(g, 1.0, [])
	eq(_bf.lasers_fired, 1, "il tire quand meme")
	eq(SpeedGauge.speed_percent, avant, "mais le mur arrete le rayon")


# --- 5. SOMMEIL QUI COUPE LA MAGIE ---------------------------------------------

func _renard(interval: float = 2.0, duree: float = 2.0) -> EnemyDef:
	var d := _def("renard", 50.0, 0.0)
	d.sleep_interval = interval
	d.sleep_duration = duree
	return d


func _une_carte() -> SpellCard:
	var c := SpellCard.new()
	c.id = &"test_sort"
	c.display_name = "Sort de test"
	RunState.hand.append(c)
	return c


func _test_sommeil_coupe_la_magie_puis_la_rend() -> void:
	_fresh()
	var d := _renard()
	d.base_speed = 60.0
	var r: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	var c: SpellCard = _une_carte()
	_sim(d.sleep_interval * 0.5)
	not_ok(RunState.is_silenced(), "eveille : la magie passe")
	_sim(d.sleep_interval * 0.5 + 0.05)
	ok(r.is_sleeping(), "l intervalle passe, il s endort")
	ok(RunState.is_silenced(), "et la magie est coupee")
	var y: float = r.position.y
	not_ok(RunState.play_card(c), "aucune carte ne part pendant son sommeil")
	ok(RunState.hand.has(c), "la carte reste en main")
	_sim(d.sleep_duration * 0.5)
	feq(r.position.y, y, "il dort : il n avance pas")
	_sim(d.sleep_duration * 0.5 + 0.05)
	not_ok(r.is_sleeping(), "il se reveille")
	not_ok(RunState.is_silenced(), "la magie revient")
	ok(RunState.play_card(c), "et la carte part")


func _test_sommeil_tuer_le_dormeur_rend_la_magie() -> void:
	_fresh()
	var d := _renard()
	var r: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	var c: SpellCard = _une_carte()
	_sim(d.sleep_interval + 0.05)
	ok(RunState.is_silenced(), "il dort, la magie est coupee")
	r.take_damage(999.0, [])
	not_ok(RunState.is_silenced(), "le tuer rend la magie AUSSITOT, sans attendre l image")
	ok(RunState.play_card(c), "le sort suivant part")


## Trois renards regles pareil : ils ne doivent pas enchainer leurs siestes.
## La main GRISEE doit le rester : le HUD recalcule la teinte des cartes a chaque
## image (sort prepare), et ce recalcul effacait le gris du sommeil comme celui de
## la petrification — vu en capture, le mot restait et la couleur disparaissait.
func _test_sommeil_la_main_reste_grisee() -> void:
	RunState.reset()
	var hud: Node = load("res://scripts/ui/hud.gd").new()
	var c := SpellCard.new()
	RunState.hand.append(c)
	eq(hud._teinte_carte(c, 0, null), Color.WHITE, "eveille : carte normale")
	RunState.set_silenced(true)
	var t: Color = hud._teinte_carte(c, 0, null)
	ok(t.r < 0.8 and t.g < 0.8, "sommeil : la carte est grisee, image apres image")
	RunState.set_silenced(false)
	# Deux cartes : le plafond en laisse toujours une jouable, la DERNIERE gele.
	# La teinte se demande par POSITION (c en 0, c2 en 1) : c est l exemplaire
	# qui est gele, pas la ressource.
	var c2 := SpellCard.new()
	RunState.hand.append(c2)
	RunState.set_card_block_count(1)
	ok(RunState.is_card_blocked(c2), "(la derniere carte est petrifiee)")
	var p: Color = hud._teinte_carte(c2, 1, null)
	ok(p.r < 0.8 and p.g < 0.8, "petrifiee : la carte reste grisee elle aussi")
	eq(hud._teinte_carte(c, 0, null), Color.WHITE, "sa voisine libre reste normale")
	hud.free()
	RunState.reset()


func _test_sommeil_fenetre_garantie_entre_dormeurs() -> void:
	_fresh()
	var d := _renard(1.0, 2.0)
	for i in 3:
		_bf.spawn_enemy(d, 300.0 + i * 200.0, 1.0, Vector2(300.0 + i * 200.0, 400.0))
	var dt: float = 1.0 / 60.0
	var plus_long_silence: float = 0.0
	var plus_courte_fenetre: float = INF
	var silence: float = 0.0
	var fenetre: float = 0.0
	var episodes: int = 0
	var temps_coupe: float = 0.0
	var total: float = 30.0
	var t: float = 0.0
	var avant: bool = false
	while t < total:
		_step()
		var s: bool = RunState.is_silenced()
		if s:
			silence += dt
			temps_coupe += dt
			if not avant:
				episodes += 1
				# Fenetre ENTRE deux sommeils : la premiere (debut de partie) ne compte pas.
				if episodes > 1:
					plus_courte_fenetre = minf(plus_courte_fenetre, fenetre)
			fenetre = 0.0
		else:
			fenetre += dt
			if avant:
				plus_long_silence = maxf(plus_long_silence, silence)
			silence = 0.0
		avant = s
		t += dt
	ok(episodes >= 3, "les renards dorment bien, plusieurs fois (%d)" % episodes)
	ok(plus_long_silence <= d.sleep_duration + 0.05,
		"les siestes ne s additionnent pas (plus long silence %.2f s)" % plus_long_silence)
	ok(plus_courte_fenetre >= Battlefield.SLEEP_MIN_MAGIC_WINDOW - 0.05,
		"une fenetre de magie garantie entre deux sommeils (%.2f s)" % plus_courte_fenetre)
	# Bornes en dur : si la fenetre garantie tombait a zero, trois renards
	# couperaient la magie en permanence.
	ok(plus_courte_fenetre >= 1.0, "au moins une seconde de magie entre deux siestes")
	ok(temps_coupe / total < 0.5, "la magie reste possible la majorite du temps (%.0f %%)"
		% (temps_coupe / total * 100.0))


func _test_sommeil_plafonne() -> void:
	_fresh()
	var d := _renard(1.0, 60.0)   # contenu deraisonnable
	var r: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(d.sleep_interval + 0.05)
	ok(r.is_sleeping(), "il dort")
	# Borne en dur : une minute de silence n est pas un combat.
	_sim(5.0)
	not_ok(r.is_sleeping(), "une sieste ne depasse jamais quelques secondes")


# --- 6. MOTIFS DE DEPLACEMENT --------------------------------------------------

func _trace_x(e: Enemy, seconds: float) -> Array[float]:
	var xs: Array[float] = []
	var t: float = 0.0
	while t < seconds:
		_step()
		if is_instance_valid(e) and not e.is_dead():
			xs.append(e.position.x)
		t += 1.0 / 60.0
	return xs


func _test_motif_droit_par_defaut() -> void:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("droit"), 500.0, 1.0, Vector2(500.0, 300.0))
	var xs: Array[float] = _trace_x(e, 3.0)
	feq(xs.max() - xs.min(), 0.0, "sans motif, il descend tout droit")


func _test_motif_zigzag() -> void:
	_fresh()
	var d := _def("zigzag", 100.0, 60.0)
	d.move_pattern = EnemyDef.MovePattern.ZIGZAG
	d.pattern_width = 200.0
	d.pattern_lateral_speed = 120.0
	var e: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 300.0))
	var y0: float = e.position.y
	var xs: Array[float] = _trace_x(e, 12.0)
	var demi_tours: int = 0
	for i in range(2, xs.size()):
		if signf(xs[i] - xs[i - 1]) != signf(xs[i - 1] - xs[i - 2]) and xs[i] != xs[i - 1]:
			demi_tours += 1
	ok(demi_tours >= 3, "il change de sens plusieurs fois (%d)" % demi_tours)
	between(xs.max() - xs.min(), d.pattern_width * 0.8, d.pattern_width * 1.05,
		"l ecart lateral suit la largeur du motif")
	ok(e.position.y > y0 + 50.0, "et il descend quand meme")


func _test_motif_rebond() -> void:
	_fresh()
	var d := _def("rebond", 100.0, 20.0)
	d.move_pattern = EnemyDef.MovePattern.BOUNCE
	d.pattern_lateral_speed = 400.0
	var e: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 300.0))
	var demi: float = e.visual_radius() * d.sprite_scale
	var xs: Array[float] = _trace_x(e, 20.0)
	ok(xs.min() <= demi + 10.0, "il touche le bord gauche")
	ok(xs.max() >= GameConfig.BATTLEFIELD_WIDTH - demi - 10.0, "et le bord droit")
	ok(xs.min() - demi >= -0.5 and xs.max() + demi <= GameConfig.BATTLEFIELD_WIDTH + 0.5,
		"sans jamais deborder de l ecran")


func _test_motif_sauts() -> void:
	_fresh()
	var d := _def("sauteur", 100.0, 30.0)
	d.move_pattern = EnemyDef.MovePattern.HOP
	d.pattern_width = 180.0
	d.pattern_interval = 1.0
	var e: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 300.0))
	var xs: Array[float] = _trace_x(e, 6.5)
	# Les paliers : des positions TENUES (au moins une demi-seconde).
	var paliers: Array[float] = []
	var tenue: int = 0
	for i in range(1, xs.size()):
		if absf(xs[i] - xs[i - 1]) < 0.01:
			tenue += 1
			if tenue == 30 and (paliers.is_empty() or absf(paliers[-1] - xs[i]) > 1.0):
				paliers.append(xs[i])
		else:
			tenue = 0
	ok(paliers.size() >= 4, "il tient une colonne, puis saute, plusieurs fois (%d)" % paliers.size())
	for i in range(1, paliers.size()):
		feq(absf(paliers[i] - paliers[i - 1]), d.pattern_width,
			"chaque saut franchit une colonne", 1.0)


func _test_motif_au_sol_ne_traverse_pas_un_mur(motif: int = EnemyDef.MovePattern.ZIGZAG) -> void:
	_fresh()
	var d := _def("motif_sol", 100.0, 60.0)
	d.move_pattern = motif
	d.pattern_width = 400.0
	d.pattern_lateral_speed = 200.0
	var e: Enemy = _bf.spawn_enemy(d, 480.0, 1.0, Vector2(480.0, 300.0))
	# Un mur a DROITE de sa colonne, sur le chemin de son zigzag.
	_bf.spawn_wall(Vector2(760.0, 600.0), 120.0, 999.0, 240.0)
	var dans_le_mur: int = 0
	var t: float = 0.0
	while t < 40.0 and is_instance_valid(e) and not e.is_dead():
		_step()
		if is_instance_valid(e) and _bf.nav.is_blocked(_bf.nav.to_cell(e.position)):
			dans_le_mur += 1
		t += 1.0 / 60.0
	eq(dans_le_mur, 0, "%s : le motif d un monstre au sol n entre jamais dans un mur"
		% _nom_motif(motif))
	ok(not is_instance_valid(e) or e.is_dead() or e.position.y > 800.0,
		"%s : et il ne reste pas coince derriere" % _nom_motif(motif))


## Le cas ou la garde laterale travaille vraiment. Avec un mur pose, l A* rend un
## chemin COMPLET jusqu au mage et le motif est suspendu tout du long (test
## precedent) ; il ne reprend la main que quand le chemin est vide — un monstre
## ENFERME. La, son zigzag le pousse contre les parois : il doit les longer, pas
## les traverser, et repartir quand elles tombent.
func _test_motif_au_sol_enferme_ne_traverse_pas(motif: int = EnemyDef.MovePattern.ZIGZAG) -> void:
	_fresh()
	var d := _def("motif_enferme", 100.0, 60.0)
	d.move_pattern = motif
	d.pattern_width = 500.0
	d.pattern_lateral_speed = 240.0
	var e: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 560.0))
	var duree_murs: float = 4.0
	# Une cuve en U : un fond sur toute la largeur, deux parois proches.
	_bf.spawn_wall(Vector2(540.0, 700.0), 540.0, duree_murs)
	_bf.spawn_wall(Vector2(330.0, 560.0), 30.0, duree_murs, 300.0)
	_bf.spawn_wall(Vector2(750.0, 560.0), 30.0, duree_murs, 300.0)
	var dans_le_mur: int = 0
	var x_min: float = INF
	var x_max: float = -INF
	var t: float = 0.0
	while t < duree_murs - 0.2:
		_step()
		if _bf.nav.is_blocked(_bf.nav.to_cell(e.position)):
			dans_le_mur += 1
		x_min = minf(x_min, e.position.x)
		x_max = maxf(x_max, e.position.x)
		t += 1.0 / 60.0
	ok(x_max - x_min > 60.0, "%s : enferme, il garde son motif dans sa cuve (%.0f px)"
		% [_nom_motif(motif), x_max - x_min])
	eq(dans_le_mur, 0, "%s : sans jamais entrer dans une paroi" % _nom_motif(motif))
	var y: float = e.position.y
	_sim(3.0)
	ok(e.position.y > y + 40.0, "%s : les murs tombes, il repart vers le mage"
		% _nom_motif(motif))


func _test_motif_volant_ignore_les_murs(motif: int = EnemyDef.MovePattern.ZIGZAG) -> void:
	_fresh()
	var d := _def("motif_vol", 100.0, 60.0)
	d.flying = true
	d.move_pattern = motif
	d.pattern_width = 400.0
	d.pattern_lateral_speed = 200.0
	var e: Enemy = _bf.spawn_enemy(d, 480.0, 1.0, Vector2(480.0, 300.0))
	_bf.spawn_wall(Vector2(760.0, 600.0), 120.0, 999.0, 240.0)
	var dans_le_mur: int = 0
	var t: float = 0.0
	while t < 30.0 and is_instance_valid(e) and not e.is_dead():
		_step()
		if is_instance_valid(e) and _bf.nav.is_blocked(_bf.nav.to_cell(e.position)):
			dans_le_mur += 1
		t += 1.0 / 60.0
	ok(dans_le_mur > 0, "%s : un volant garde son motif au-dessus du mur" % _nom_motif(motif))


## Duree (s de monde a x1) de `n` tours de spirale : derivee du motif et de la
## vitesse, pas ecrite en dur (un reglage de vitesse ne casse pas le test).
func _tours(d: EnemyDef, n: float) -> float:
	var tangente: float = d.pattern_lateral_speed if d.pattern_lateral_speed > 0.0 \
		else d.base_speed
	return n * TAU * d.pattern_width * 0.5 / (tangente * GameConfig.ENEMY_SPEED_SCALE)


func _nom_motif(motif: int) -> String:
	return String(EnemyDef.MovePattern.keys()[motif])


## SPIRAL, plus rapide sur son cercle qu a la descente : il TOURNE. Il va et
## vient autour de sa colonne sur la largeur du motif, remonte un instant a
## chaque boucle, ne passe jamais au-dessus de son point de depart, et descend.
func _test_motif_spirale() -> void:
	_fresh()
	var d := _def("spirale", 100.0, 60.0)
	d.move_pattern = EnemyDef.MovePattern.SPIRAL
	d.pattern_width = 200.0
	d.pattern_lateral_speed = 150.0
	var x0: float = 300.0
	var e: Enemy = _bf.spawn_enemy(d, x0, 1.0, Vector2(x0, 300.0))
	_sim(GameConfig.SPAWN_FADE_TIME + 0.05)
	var depart: Vector2 = e.position
	var pts: Array[Vector2] = []
	var t: float = 0.0
	while t < _tours(d, 2.5) and is_instance_valid(e) and not e.is_dead():
		_step()
		pts.append(e.position)
		t += 1.0 / 60.0
	ok(pts.size() > 60, "il a vecu assez pour tourner")
	var x_min: float = INF
	var x_max: float = -INF
	var y_min: float = INF
	var remontees: int = 0
	var demi_tours: int = 0
	var premier_dx: float = 0.0
	for i in range(1, pts.size()):
		var dx: float = pts[i].x - pts[i - 1].x
		if premier_dx == 0.0 and absf(dx) > 0.001:
			premier_dx = dx
		if pts[i].y < pts[i - 1].y - 0.001:
			remontees += 1
		if i >= 2:
			var dx0: float = pts[i - 1].x - pts[i - 2].x
			if signf(dx) != signf(dx0) and dx != 0.0 and dx0 != 0.0:
				demi_tours += 1
		x_min = minf(x_min, pts[i].x)
		x_max = maxf(x_max, pts[i].x)
		y_min = minf(y_min, pts[i].y)
	ok(premier_dx > 0.0, "il part vers le centre du terrain")
	between(x_max - x_min, d.pattern_width * 0.8, d.pattern_width * 1.05,
		"l ecart lateral est le diametre du cercle")
	ok(x_min < depart.x and x_max > depart.x, "il tourne AUTOUR de sa colonne")
	ok(demi_tours >= 3, "il change de sens lateral a chaque demi-tour (%d)" % demi_tours)
	ok(remontees > 0, "plus rapide sur son cercle qu a la descente, il fait des boucles")
	ok(y_min >= depart.y - 0.5, "jamais au-dessus de son point de depart")
	ok(pts[-1].y > depart.y + 50.0, "et il descend quand meme")


## Vitesse sur le cercle egale a la descente (defaut) : une roue qui roule, il
## ne remonte jamais. Le joueur ne le voit pas reculer vers le haut.
func _test_motif_spirale_sans_recul_par_defaut() -> void:
	_fresh()
	var d := _def("spirale_roue", 100.0, 60.0)
	d.move_pattern = EnemyDef.MovePattern.SPIRAL
	d.pattern_width = 200.0
	var e: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 300.0))
	_sim(GameConfig.SPAWN_FADE_TIME + 0.05)
	var y: float = e.position.y
	var recul: float = 0.0
	var x_min: float = INF
	var x_max: float = -INF
	var t: float = 0.0
	while t < _tours(d, 1.5) and is_instance_valid(e) and not e.is_dead():
		_step()
		recul = maxf(recul, y - e.position.y)
		y = e.position.y
		x_min = minf(x_min, e.position.x)
		x_max = maxf(x_max, e.position.x)
		t += 1.0 / 60.0
	ok(recul < 0.01, "il ne remonte jamais (%.3f px)" % recul)
	ok(x_max - x_min > d.pattern_width * 0.8, "mais il tourne bien (%.0f px)" % (x_max - x_min))


# --- 7. ENTREE PAR LE COTE D UN GROS MONSTRE -----------------------------------

func _gros_par_le_cote() -> EnemyDef:
	var d := _def("gros_cote", 300.0, 60.0, 6)
	d.kind = GameEnums.EnemyKind.MINIBOSS
	d.base_radius = 62.0
	d.sprite_scale = 1.5
	d.entry_side = true
	return d


func _test_gros_monstre_par_le_cote_reste_visible() -> void:
	_fresh()
	var d := _gros_par_le_cote()
	var sp := WaveSpawner.new()
	var vide: Array[WaveDef] = []
	sp.setup(_bf, vide, 11)
	var vus_gauche: bool = false
	var vus_droite: bool = false
	for i in 12:
		var x: float = sp._spawn_x(d)
		var e: Enemy = _bf.spawn_enemy(d, x)
		var demi: float = e.visual_radius() * d.sprite_scale
		# Un demi-pixel de tolerance : pose pile au bord, l arrondi flottant donne
		# 1080,0001 — ce n est pas un debordement visible.
		ok(e.position.x - demi >= -0.5 and e.position.x + demi <= GameConfig.BATTLEFIELD_WIDTH + 0.5,
			"entierement dans la largeur (x=%.0f, demi=%.0f)" % [e.position.x, demi])
		ok(e.position.y - demi >= 0.0, "et sous le haut de l ecran (y=%.0f)" % e.position.y)
		vus_gauche = vus_gauche or x < GameConfig.BATTLEFIELD_WIDTH * 0.5
		vus_droite = vus_droite or x > GameConfig.BATTLEFIELD_WIDTH * 0.5
	ok(vus_gauche and vus_droite, "il entre bien par les DEUX cotes")
	_sim(GameConfig.SPAWN_FADE_TIME + 0.1)
	var un: Enemy = _vivants()[0]
	eq(_bf.enemy_nearest_to(un.position, 10.0), un, "ciblable au doigt")
	ok(_bf.enemies_in_radius(un.position, 10.0).has(un), "et par un sort de zone")
	sp.free()


func _test_gros_monstre_par_le_cote_ne_se_coince_pas() -> void:
	_fresh()
	var d := _gros_par_le_cote()
	var sp := WaveSpawner.new()
	var vide: Array[WaveDef] = []
	sp.setup(_bf, vide, 3)
	var e: Enemy = _bf.spawn_enemy(d, sp._spawn_x(d))
	# Un mur en travers de SA colonne, a mi-terrain.
	_bf.spawn_wall(Vector2(e.position.x, 800.0), 150.0, 999.0)
	var arrive: bool = false
	var t: float = 0.0
	while t < 90.0:
		_step()
		if _bf.alive_count() == 0:
			arrive = true
			break
		t += 1.0 / 60.0
	ok(arrive, "il contourne le mur et atteint le mage (%.0f s)" % t)
	sp.free()


# --- 8. BESTIAIRE ----------------------------------------------------------------

func _test_bestiaire_dit_chaque_mecanique() -> void:
	var nu := _def("nu")
	eq(BestiaryLore.v3_lines(nu).size(), 0, "un monstre sans mecanique v3 n a aucune ligne v3")

	var vies := _def("vies")
	vies.extra_lives = 3
	vies.extra_life_speed_pct = 35.0
	var l: Array[String] = BestiaryLore.behaviours(vies)
	ok(_contient(l, "3 fois") and _contient(l, "haut") and _contient(l, "35 %"),
		"plusieurs vies : combien, d ou, et de combien plus vite")

	var f := _fantome()
	l = BestiaryLore.behaviours(f)
	ok(_contient(l, "marque") and _contient(l, "2 slime_ne") and _contient(l, "3 s"),
		"renaissance : la marque, qui nait, en combien de temps")

	l = BestiaryLore.behaviours(_pretre(4))
	ok(_contient(l, "releve") and _contient(l, "4 fois"),
		"reanimateur : ce qu il fait et son plafond")

	l = BestiaryLore.behaviours(_golem())
	ok(_contient(l, "laser") and _contient(l, "6 degats") and _contient(l, "1 s"),
		"laser : quand, combien, et le delai")

	l = BestiaryLore.behaviours(_renard(5.0, 2.0))
	ok(_contient(l, "aucun sort") and _contient(l, "2 s") and _contient(l, "5 s")
		and _contient(l, "tuer"), "sommeil : la regle, les chiffres et la reponse")

	var z := _def("z")
	z.move_pattern = EnemyDef.MovePattern.ZIGZAG
	ok(_contient(BestiaryLore.behaviours(z), "zigzag"), "motif zigzag nomme")
	var b := _def("b")
	b.move_pattern = EnemyDef.MovePattern.BOUNCE
	ok(_contient(BestiaryLore.behaviours(b), "rebondit"), "motif rebond nomme")
	var h := _def("h")
	h.move_pattern = EnemyDef.MovePattern.HOP
	h.pattern_interval = 2.0
	ok(_contient(BestiaryLore.behaviours(h), "2 s"), "motif sauts nomme avec sa cadence")
	var sp := _def("sp")
	sp.move_pattern = EnemyDef.MovePattern.SPIRAL
	ok(_contient(BestiaryLore.behaviours(sp), "spirale"), "motif spirale nomme")
	# Chaque motif autre que la ligne droite a sa ligne : un motif ajoute a
	# l enum sans phrase au bestiaire fait rougir ce test.
	var nu_motif: Array[String] = BestiaryLore.behaviours(_def("lore"))
	for m in EnemyDef.MovePattern.values():
		if m == EnemyDef.MovePattern.STRAIGHT:
			continue
		var dm := _def("lore")
		dm.move_pattern = m
		ok(BestiaryLore.behaviours(dm) != nu_motif,
			"le motif %s a sa ligne au bestiaire" % _nom_motif(m))

	var vol := _def("vol")
	vol.flying = true
	ok(_contient(BestiaryLore.behaviours(vol), "vole"), "la ligne des volants existe")
	var pr := _def("pr")
	pr.projectile = true
	ok(_contient(BestiaryLore.behaviours(pr), "projectile"), "la ligne des projectiles existe")
