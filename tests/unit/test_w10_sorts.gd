extends TestCase
## VAGUE 10, CHANTIER A1 — les cinq verbes neufs du co-auteur et la carte de la
## main qui murit : vent du sud (global_wind), marque electrique
## (electric_mark), pluie abondante (global_rain), sable mouvant (quicksand),
## jet d eau en I (water_jet), « monte une carte de ta main » (hand_card_level).
##
## Les tests lancent les cartes par EffectRegistry.cast sur un vrai Battlefield :
## c est le chemin du jeu (attribution des morts au lancer comprise). Chaque
## regle se verifie en RAPPORT (au monstre identique sans l effet, a la vitesse
## normale du reglage), jamais contre une valeur d equilibrage.

func get_suite_name() -> String:
	return "w10_sorts"


const DT: float = 1.0 / 60.0


func run() -> void:
	_test_le_vent_ramene_les_rapides_a_la_normale()
	_test_le_vent_immobilise_les_volants()
	_test_le_vent_redresse_les_trajets()
	_test_le_vent_lisse_les_a_coups()
	_test_le_vent_suit_la_resistance()
	_test_le_vent_retombe()
	_test_la_marque_frappe_et_reste()
	_test_la_marque_saute_au_plus_proche_en_perdant_un()
	_test_la_marque_s_eteint_a_zero_et_les_morts_sont_au_lancer()
	_test_la_marque_ne_saute_pas_hors_de_portee()
	_test_plusieurs_marques_transmises_et_portees()
	_test_la_marque_ne_se_pose_pas_sur_un_immunise()
	_test_la_pluie_mord_tout_le_terrain_a_intervalle()
	_test_la_pluie_ne_depend_pas_des_images()
	_test_la_pluie_n_est_pas_un_coup()
	_test_le_sable_ralentit_puis_avale_ceux_qui_restent()
	_test_le_jet_repousse_et_frappe_selon_la_distance()
	_test_la_main_murit_au_choix()
	_test_le_bot_choisit_la_carte_la_plus_loin_de_murir()
	_test_la_main_murit_dans_une_vraie_partie()
	_test_l_ecran_du_choix_de_main()
	RunState.reset()


# --- Fabriques -------------------------------------------------------------

func _def(id: String, vitesse: float = 0.0, pv: float = 1000.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = pv
	d.base_speed = vitesse
	d.base_radius = 30.0
	d.base_xp = 1
	return d


func _card(id: String, key: StringName, el: int, magnitude: float = 0.0,
		duration: float = 0.0, radius: float = 0.0, params: Dictionary = {}) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = 1.0
	c.targeting = GameEnums.Targeting.TARGET
	c.element = el
	var sp := EffectSpec.new()
	sp.key = key
	sp.magnitude = magnitude
	sp.duration = duration
	sp.radius = radius
	sp.params = params
	c.effects = [sp]
	return c


func _fresh() -> Battlefield:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


## Simule `secondes` de monde en images de 1 / `ips` s, mage maintenu a x1.
func _avancer(bf: Battlefield, secondes: float, ips: float = 60.0) -> void:
	var t: float = 0.0
	var dt: float = 1.0 / ips
	while t < secondes - 0.0000001:
		bf.simulate(dt)
		t += SpeedGauge.world_delta(dt)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)


func _lancer(bf: Battlefield, card: SpellCard, cible: Enemy, ou: Vector2 = Vector2.INF) -> void:
	var ctx := CastContext.make(bf, card)
	ctx.target_enemy = cible
	ctx.target_position = ou if ou != Vector2.INF else (cible.position if cible != null else Vector2(540, 700))
	EffectRegistry.cast(card, ctx)


func _vent(bf: Battlefield, duree: float = 30.0) -> void:
	_lancer(bf, _card("t_w10_vent", &"global_wind", GameEnums.DamageTag.WIND, 0.0, duree),
		null, Vector2(540, 700))


# --- VENT DU SUD -----------------------------------------------------------

## Un monstre RAPIDE marche a la normale sous le vent ; un monstre a la normale
## et un monstre lent ne changent pas. La normale est celle du reglage.
func _test_le_vent_ramene_les_rapides_a_la_normale() -> void:
	var bf := _fresh()
	var rapide: Enemy = bf.spawn_enemy(_def("t_w10_rapide", GameConfig.WIND_NORMAL_SPEED * 2.5),
		200.0, 1.0, Vector2(200, 300))
	var normal: Enemy = bf.spawn_enemy(_def("t_w10_normal", GameConfig.WIND_NORMAL_SPEED),
		540.0, 1.0, Vector2(540, 300))
	var lent: Enemy = bf.spawn_enemy(_def("t_w10_lent", GameConfig.WIND_NORMAL_SPEED * 0.5),
		880.0, 1.0, Vector2(880, 300))
	var avant: Array[float] = [rapide.position.y, normal.position.y, lent.position.y]
	_avancer(bf, 1.0)
	var sans: Array[float] = [rapide.position.y - avant[0], normal.position.y - avant[1],
		lent.position.y - avant[2]]
	_vent(bf)
	ok(bf.w10_wind_active(), "le vent souffle")
	avant = [rapide.position.y, normal.position.y, lent.position.y]
	_avancer(bf, 1.0)
	var avec: Array[float] = [rapide.position.y - avant[0], normal.position.y - avant[1],
		lent.position.y - avant[2]]
	ok(sans[0] > sans[1] * 2.0, "(sans vent, le rapide va bien plus vite : %.1f contre %.1f)"
		% [sans[0], sans[1]])
	feq(avec[0], sans[1], "sous le vent, le rapide marche a la normale", 0.5)
	feq(avec[1], sans[1], "le monstre a la normale ne change pas", 0.01)
	feq(avec[2], sans[2], "le lent n est pas accelere", 0.01)
	detach(bf)


## Les VOLANTS restent sur place sous le vent, et repartent quand il tombe.
func _test_le_vent_immobilise_les_volants() -> void:
	var bf := _fresh()
	var d := _def("t_w10_volant", GameConfig.WIND_NORMAL_SPEED)
	d.flying = true
	var v: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 300))
	_avancer(bf, 0.5)
	ok(v.position.y > 300.0, "(sans vent, le volant descend)")
	_vent(bf, 2.0)
	var y: float = v.position.y
	_avancer(bf, 1.5)
	feq(v.position.y, y, "sous le vent, le volant ne bouge plus", 0.001)
	_avancer(bf, 1.0)
	ok(v.position.y > y + 1.0, "le vent tombe : il repart")
	detach(bf)


## Zigzag et ondulation : la colonne ne bouge plus sous le vent, et le monstre
## descend toujours (il marche droit, il n est pas fige).
func _test_le_vent_redresse_les_trajets() -> void:
	var bf := _fresh()
	var zz := _def("t_w10_zigzag", GameConfig.WIND_NORMAL_SPEED)
	zz.move_pattern = EnemyDef.MovePattern.ZIGZAG
	zz.pattern_lateral_speed = 90.0
	zz.pattern_width = 240.0
	var on := _def("t_w10_onde", GameConfig.WIND_NORMAL_SPEED)
	on.wave_amplitude = 80.0
	on.wave_frequency = 0.7
	var a: Enemy = bf.spawn_enemy(zz, 300.0, 1.0, Vector2(300, 300))
	var b: Enemy = bf.spawn_enemy(on, 760.0, 1.0, Vector2(760, 300))
	var xa: float = a.position.x
	var xb: float = b.position.x
	_avancer(bf, 0.8)
	ok(absf(a.position.x - xa) > 5.0, "(sans vent, le zigzag se deporte)")
	ok(absf(b.position.x - xb) > 5.0, "(sans vent, l ondulation se deporte)")
	_vent(bf)
	xa = a.position.x
	xb = b.position.x
	var ya: float = a.position.y
	_avancer(bf, 1.5)
	feq(a.position.x, xa, "sous le vent, le zigzag marche droit", 0.001)
	feq(b.position.x, xb, "sous le vent, l ondulation marche droit", 0.001)
	ok(a.position.y > ya + 10.0, "et il descend toujours")
	detach(bf)


## A-coups : sous le vent, plus aucune image a l arret.
func _test_le_vent_lisse_les_a_coups() -> void:
	var bf := _fresh()
	var d := _def("t_w10_acoups", GameConfig.WIND_NORMAL_SPEED * 0.8)
	d.burst_move = true
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 300))
	var arrets: int = 0
	for i in 120:
		var y: float = e.position.y
		bf.simulate(DT)
		SpeedGauge.set_speed_percent(100)
		if absf(e.position.y - y) < 0.0001:
			arrets += 1
	ok(arrets > 0, "(sans vent, le monstre a a-coups s arrete : %d images)" % arrets)
	_vent(bf)
	arrets = 0
	for i in 120:
		var y2: float = e.position.y
		bf.simulate(DT)
		SpeedGauge.set_speed_percent(100)
		if absf(e.position.y - y2) < 0.0001:
			arrets += 1
	eq(arrets, 0, "sous le vent, il marche sans s arreter")
	detach(bf)


## La part du vent suit la RESISTANCE au vent : un immunise n est pas touche,
## un resistant a moitie est ramene a mi-chemin.
func _test_le_vent_suit_la_resistance() -> void:
	var bf := _fresh()
	var vite: float = GameConfig.WIND_NORMAL_SPEED * 2.5
	var neutre: Enemy = bf.spawn_enemy(_def("t_w10_r_neutre", vite), 200.0, 1.0, Vector2(200, 300))
	var dm := _def("t_w10_r_moitie", vite)
	dm.resistances = {GameEnums.DamageTag.WIND: 0.5}
	var moitie: Enemy = bf.spawn_enemy(dm, 540.0, 1.0, Vector2(540, 300))
	var di := _def("t_w10_r_immun", vite)
	di.resistances = {GameEnums.DamageTag.WIND: 0.0}
	var immun: Enemy = bf.spawn_enemy(di, 880.0, 1.0, Vector2(880, 300))
	var dv := _def("t_w10_r_volant_immun", vite)
	dv.flying = true
	dv.resistances = {GameEnums.DamageTag.WIND: 0.0}
	var volant: Enemy = bf.spawn_enemy(dv, 700.0, 1.0, Vector2(700, 300))
	_vent(bf)
	var y: Array[float] = [neutre.position.y, moitie.position.y, immun.position.y, volant.position.y]
	_avancer(bf, 1.0)
	var pas_libre: float = vite * GameConfig.ENEMY_SPEED_SCALE
	var pas_normal: float = bf.w10_wind_cap()
	feq(neutre.position.y - y[0], pas_normal, "le neutre est ramene a la normale", 0.5)
	feq(moitie.position.y - y[1], (pas_libre + pas_normal) * 0.5,
		"le resistant a moitie : a mi-chemin", 0.5)
	feq(immun.position.y - y[2], pas_libre, "l immunise au vent n est pas touche", 0.5)
	feq(volant.position.y - y[3], pas_libre, "un volant immunise au vent vole toujours", 0.5)
	detach(bf)


func _test_le_vent_retombe() -> void:
	var bf := _fresh()
	_vent(bf, 1.0)
	ok(bf.w10_wind_active(), "le vent souffle")
	_avancer(bf, 1.2)
	not_ok(bf.w10_wind_active(), "apres sa duree (temps du monde), le vent tombe")
	detach(bf)


# --- MARQUE ELECTRIQUE ---------------------------------------------------

func _marque(n: float, portee: float = 320.0, par_mort: int = 1) -> SpellCard:
	return _card("t_w10_marque", &"electric_mark", GameEnums.DamageTag.LIGHTNING, n, 0.0, 0.0,
		{&"jump_range": portee, &"marks_per_death": par_mort})


func _attendre_saut(bf: Battlefield) -> void:
	_avancer(bf, GameConfig.MARK_JUMP_DELAY + 0.05)


func _test_la_marque_frappe_et_reste() -> void:
	var bf := _fresh()
	var e: Enemy = bf.spawn_enemy(_def("t_w10_m_gros"), 540.0, 1.0, Vector2(540, 600))
	_lancer(bf, _marque(6.0), e)
	feq(e.hp, e.max_hp() - 6.0, "la marque inflige ses degats")
	eq(bf.w10_marks_on(e).size(), 1, "et reste sur le monstre")
	feq(bf.w10_marks_on(e)[0], 6.0, "avec sa valeur")
	detach(bf)


## Le porteur meurt : la marque saute sur le PLUS PROCHE, un degat de moins, et
## il porte desormais la marque (de la valeur diminuee).
func _test_la_marque_saute_au_plus_proche_en_perdant_un() -> void:
	var bf := _fresh()
	var n: float = 6.0
	var porteur: Enemy = bf.spawn_enemy(_def("t_w10_m_frele", 0.0, n), 540.0, 1.0, Vector2(540, 600))
	var proche: Enemy = bf.spawn_enemy(_def("t_w10_m_proche"), 640.0, 1.0, Vector2(640, 600))
	var loin: Enemy = bf.spawn_enemy(_def("t_w10_m_loin"), 800.0, 1.0, Vector2(800, 600))
	_lancer(bf, _marque(n), porteur)
	ok(porteur.is_dead(), "le porteur meurt du coup de la marque")
	feq(proche.hp, proche.max_hp(), "(le saut attend son delai : on doit le VOIR partir)")
	_attendre_saut(bf)
	feq(proche.hp, proche.max_hp() - (n - 1.0), "le plus proche encaisse un degat de moins")
	var marques: Array[float] = bf.w10_marks_on(proche)
	ok(marques.size() == 1 and is_equal_approx(marques[0], n - 1.0),
		"et porte la marque diminuee (%s)" % [marques])
	feq(loin.hp, loin.max_hp(), "le plus lointain n est pas touche")
	eq(bf.w10_mark_jumps_done, 1, "un saut")
	detach(bf)


## Une chaine de monstres freles : la marque descend de 1 a chaque mort et
## s eteint a zero. Toutes les morts reviennent au LANCER (objectifs).
func _test_la_marque_s_eteint_a_zero_et_les_morts_sont_au_lancer() -> void:
	var bf := _fresh()
	var d := _def("t_w10_m_chaine", 0.0, 1.0)
	var chaine: Array[Enemy] = []
	for i in 5:
		chaine.append(bf.spawn_enemy(d, 200.0 + i * 150.0, 1.0, Vector2(200.0 + i * 150.0, 600)))
	var carte: SpellCard = _marque(3.0, 200.0)
	_lancer(bf, carte, chaine[0])
	for k in 6:
		_attendre_saut(bf)
	var morts: int = 0
	for e in chaine:
		if e.is_dead():
			morts += 1
	eq(morts, 3, "marque 3 : trois morts (3, puis 2, puis 1), puis la marque s eteint")
	ok(not chaine[3].is_dead() and is_equal_approx(chaine[3].hp, chaine[3].max_hp()),
		"le quatrieme n est pas touche : la marque est tombee a zero")
	eq(bf.w10_pending_jumps(), 0, "plus aucun saut en attente")
	eq(RunState.kills_with_card(carte.id, d.id), 3, "les trois morts sont creditees a la carte")
	eq(RunState.best_kills_in_one_cast(d.id), 3, "et a UN seul lancer")
	detach(bf)


func _test_la_marque_ne_saute_pas_hors_de_portee() -> void:
	var bf := _fresh()
	var porteur: Enemy = bf.spawn_enemy(_def("t_w10_m_seul", 0.0, 2.0), 200.0, 1.0, Vector2(200, 600))
	var loin: Enemy = bf.spawn_enemy(_def("t_w10_m_horsportee"), 900.0, 1.0, Vector2(900, 600))
	_lancer(bf, _marque(5.0, 300.0), porteur)
	_attendre_saut(bf)
	feq(loin.hp, loin.max_hp(), "hors de portee : la marque s eteint")
	eq(bf.w10_mark_jumps_done, 0, "aucun saut")
	detach(bf)


## marks_per_death = 2 : chaque marque part vers DEUX voisins distincts. Et un
## monstre peut porter plusieurs marques : deux lancers, deux sauts a sa mort.
func _test_plusieurs_marques_transmises_et_portees() -> void:
	var bf := _fresh()
	var n: float = 5.0
	var porteur: Enemy = bf.spawn_enemy(_def("t_w10_m_double", 0.0, n), 540.0, 1.0, Vector2(540, 600))
	var a: Enemy = bf.spawn_enemy(_def("t_w10_m_a"), 640.0, 1.0, Vector2(640, 600))
	var b: Enemy = bf.spawn_enemy(_def("t_w10_m_b"), 440.0, 1.0, Vector2(440, 610))
	var c: Enemy = bf.spawn_enemy(_def("t_w10_m_c"), 540.0, 1.0, Vector2(540, 900))
	_lancer(bf, _marque(n, 400.0, 2), porteur)
	_attendre_saut(bf)
	feq(a.hp, a.max_hp() - (n - 1.0), "deux marques transmises : le plus proche en recoit une")
	feq(b.hp, b.max_hp() - (n - 1.0), "le second plus proche aussi")
	feq(c.hp, c.max_hp(), "le troisieme non")

	var bf2 := _fresh()
	var gros: Enemy = bf2.spawn_enemy(_def("t_w10_m_gros2"), 540.0, 1.0, Vector2(540, 600))
	var voisin: Enemy = bf2.spawn_enemy(_def("t_w10_m_voisin"), 640.0, 1.0, Vector2(640, 600))
	_lancer(bf2, _marque(n), gros)
	_lancer(bf2, _marque(n), gros)
	eq(bf2.w10_marks_on(gros).size(), 2, "deux lancers : deux marques sur le meme monstre")
	gros.kill()
	_attendre_saut(bf2)
	eq(bf2.w10_marks_on(voisin).size(), 2, "a sa mort, les deux marques sautent")
	feq(voisin.hp, voisin.max_hp() - 2.0 * (n - 1.0), "et frappent chacune")
	detach(bf)
	detach(bf2)


func _test_la_marque_ne_se_pose_pas_sur_un_immunise() -> void:
	var bf := _fresh()
	var d := _def("t_w10_m_immun")
	d.resistances = {GameEnums.DamageTag.LIGHTNING: 0.0}
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	_lancer(bf, _marque(5.0), e)
	eq(bf.w10_marks_on(e).size(), 0, "immunise a la foudre : aucune marque")
	feq(e.hp, e.max_hp(), "et aucun degat")
	detach(bf)


# --- PLUIE ABONDANTE -------------------------------------------------------

func _pluie(degat: float, duree: float, intervalle: float) -> SpellCard:
	return _card("t_w10_pluie", &"global_rain", GameEnums.DamageTag.WATER, degat, duree, 0.0,
		{&"interval": intervalle})


## Tous les monstres, PARTOUT, a chaque intervalle ; la resistance a l eau joue.
func _test_la_pluie_mord_tout_le_terrain_a_intervalle() -> void:
	var bf := _fresh()
	var duree: float = 10.0
	var intervalle: float = 2.0
	var degat: float = 3.0
	var a: Enemy = bf.spawn_enemy(_def("t_w10_p_a"), 100.0, 1.0, Vector2(100, 200))
	var b: Enemy = bf.spawn_enemy(_def("t_w10_p_b"), 980.0, 1.0, Vector2(980, 1400))
	var dr := _def("t_w10_p_resiste")
	dr.resistances = {GameEnums.DamageTag.WATER: 0.5}
	var r: Enemy = bf.spawn_enemy(dr, 540.0, 1.0, Vector2(540, 800))
	_lancer(bf, _pluie(degat, duree, intervalle), null, Vector2(540, 700))
	eq(bf.w10_rain_count(), 1, "la pluie tombe")
	_avancer(bf, intervalle * 0.5)
	feq(a.hp, a.max_hp(), "(avant le premier intervalle, rien)")
	_avancer(bf, duree + 1.0)
	var gouttes: int = int(floor(duree / intervalle + 0.0001))
	feq(a.max_hp() - a.hp, gouttes * degat, "un monstre en haut prend chaque goutte")
	feq(b.max_hp() - b.hp, gouttes * degat, "un monstre en bas aussi : tout le terrain")
	feq(r.max_hp() - r.hp, gouttes * degat * 0.5, "la resistance a l eau joue")
	eq(bf.w10_rain_count(), 0, "apres sa duree, la pluie cesse")
	detach(bf)


func _test_la_pluie_ne_depend_pas_des_images() -> void:
	var pertes: Array[float] = []
	for ips in [30.0, 60.0, 240.0]:
		var bf := _fresh()
		var e: Enemy = bf.spawn_enemy(_def("t_w10_p_ips"), 540.0, 1.0, Vector2(540, 600))
		_lancer(bf, _pluie(1.0, 8.0, 2.0), null, Vector2(540, 700))
		_avancer(bf, 9.0, ips)
		pertes.append(e.max_hp() - e.hp)
		detach(bf)
	feq(pertes[0], pertes[1], "30 et 60 images/s : meme pluie")
	feq(pertes[2], pertes[1], "240 et 60 images/s : meme pluie")


## Degat CONTINU (DEC-054) : il bute sur le compteur de coups sans l user.
func _test_la_pluie_n_est_pas_un_coup() -> void:
	var bf := _fresh()
	var d := _def("t_w10_p_mage")
	d.hits_immune = 3
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	_lancer(bf, _pluie(5.0, 10.0, 2.0), null, Vector2(540, 700))
	_avancer(bf, 11.0)
	eq(e.hits_immune_left(), 3, "la pluie n use AUCUN des coups d immunite")
	ok(bf.w10_rain_bites > 0, "(elle a pourtant mordu %d fois)" % bf.w10_rain_bites)
	detach(bf)


# --- SABLE MOUVANT ----------------------------------------------------------

func _test_le_sable_ralentit_puis_avale_ceux_qui_restent() -> void:
	var bf := _fresh()
	var degats: float = 40.0
	var duree: float = 3.0
	var carte: SpellCard = _card("t_w10_sable", &"quicksand", GameEnums.DamageTag.NATURE,
		degats, duree, 150.0, {&"slow_pct": 50.0})
	var reste: Enemy = bf.spawn_enemy(_def("t_w10_s_reste"), 540.0, 1.0, Vector2(540, 600))
	var sort: Enemy = bf.spawn_enemy(_def("t_w10_s_sort"), 600.0, 1.0, Vector2(600, 600))
	var lent_dedans: Enemy = bf.spawn_enemy(_def("t_w10_s_marche", GameConfig.WIND_NORMAL_SPEED),
		480.0, 1.0, Vector2(480, 560))
	var temoin: Enemy = bf.spawn_enemy(_def("t_w10_s_temoin", GameConfig.WIND_NORMAL_SPEED),
		100.0, 1.0, Vector2(100, 300))
	_lancer(bf, carte, null, Vector2(540, 600))
	var y_dedans: float = lent_dedans.position.y
	var y_temoin: float = temoin.position.y
	_avancer(bf, 0.5)
	ok(lent_dedans.position.y - y_dedans < (temoin.position.y - y_temoin) * 0.75,
		"le sable ralentit ce qui y marche")
	feq(reste.hp, reste.max_hp(), "(pas de degats tant que le sable tient)")
	# L un s echappe avant la fin.
	sort.position = Vector2(600, 1200)
	_avancer(bf, duree)
	feq(reste.max_hp() - reste.hp, degats, "a la fin, qui est encore dedans encaisse les degats")
	feq(sort.hp, sort.max_hp(), "qui en est sorti n encaisse rien")
	eq(bf.w10_zone_ends, 1, "une seule fin de sable")
	detach(bf)


# --- JET D EAU EN I ----------------------------------------------------------

## Le jet repousse vers le haut, et les degats suivent la distance REELLEMENT
## parcourue : un monstre pres du haut recule moins, encaisse moins.
func _test_le_jet_repousse_et_frappe_selon_la_distance() -> void:
	var bf := _fresh()
	var recul: float = 300.0
	var par_pas: float = 4.0
	var carte: SpellCard = _card("t_w10_jet", &"water_jet", GameEnums.DamageTag.WATER,
		par_pas, 0.0, 50.0, {&"length": 1400.0, &"push": recul})
	var bas: Enemy = bf.spawn_enemy(_def("t_w10_j_bas"), 540.0, 1.0, Vector2(540, 1100))
	var haut: Enemy = bf.spawn_enemy(_def("t_w10_j_haut"), 540.0, 1.0,
		Vector2(540, GameConfig.SPAWN_LINE_Y + recul * 0.25))
	var cote: Enemy = bf.spawn_enemy(_def("t_w10_j_cote"), 800.0, 1.0, Vector2(800, 1000))
	var dr := _def("t_w10_j_resiste")
	dr.resistances = {GameEnums.DamageTag.WATER: 0.5}
	var resiste: Enemy = bf.spawn_enemy(dr, 560.0, 1.0, Vector2(560, 900))
	_lancer(bf, carte, null, Vector2(540, 700))
	feq(bas.position.y, 1100.0 - recul, "le monstre du bas recule de tout le jet")
	feq(bas.max_hp() - bas.hp, par_pas * recul / GameConfig.JET_DAMAGE_STEP_PX,
		"degats = par tranche de recul")
	feq(haut.position.y, GameConfig.SPAWN_LINE_Y, "celui du haut bute sur la ligne d apparition")
	feq((haut.max_hp() - haut.hp) / (bas.max_hp() - bas.hp), 0.25,
		"il a parcouru le quart : il encaisse le quart", 0.001)
	feq(cote.position.y, 1000.0, "hors de la bande : pas repousse")
	feq(cote.hp, cote.max_hp(), "ni touche")
	feq(900.0 - resiste.position.y, recul * 0.5, "un resistant a moitie recule a moitie")
	feq(resiste.max_hp() - resiste.hp, par_pas * recul * 0.5 / GameConfig.JET_DAMAGE_STEP_PX * 0.5,
		"et encaisse selon SA distance, resistance comprise")
	detach(bf)


# --- « MONTE D UN NIVEAU UNE CARTE DE TA MAIN » ------------------------------

## Une carte a GROS pool (zone qui ralentit, degats, duree) : plusieurs maturations.
func _carte_a_murir(id: String) -> SpellCard:
	return _card(id, &"ground_zone", GameEnums.DamageTag.FIRE, 8.0, 4.0, 120.0,
		{&"slow_pct": 20.0})


var _demandes: Array[int] = []


func _on_demande(n: int) -> void:
	_demandes.append(n)


func _test_la_main_murit_au_choix() -> void:
	RunState.reset()
	var a: SpellCard = _carte_a_murir("t_w10_h_a")
	var b: SpellCard = _carte_a_murir("t_w10_h_b")
	RunState.hand.append(a)
	RunState.hand.append(b)
	RunState.hand.append(a)
	_demandes.clear()
	RunState.hand_level_requested.connect(_on_demande)
	RunState.request_hand_level(1)
	eq(RunState.pending_hand_level, 1, "le choix attend")
	ok(_demandes.size() == 1 and _demandes[0] == 1, "la demande est annoncee (l ecran l ecoute)")
	var cands: Array[SpellCard] = RunState.hand_level_candidates()
	ok(cands.size() == 2 and cands[0] == a and cands[1] == b,
		"les sorts DISTINCTS de la main sont proposes")
	var palier: int = RunState.next_upgrade_at(b)
	ok(RunState.resolve_hand_level(b), "le joueur choisit b")
	eq(RunState.pending_hand_level, 0, "le choix est consomme")
	ok(RunState.card_xp(b) >= palier, "b a l XP de sa prochaine maturation")
	eq(RunState.pending_upgrade_card, b, "et sa maturation s ouvre aussitot")
	eq(RunState.card_xp(a), 0, "a n a rien recu")
	eq(RunState.casts_of(b), 0, "ce n est pas un lancer (objectifs)")
	RunState.decline_upgrade()
	# Plus rien a faire murir : pas d ecran du tout.
	RunState.reset()
	RunState.request_hand_level(1)
	eq(RunState.pending_hand_level, 0, "main vide : aucun choix")
	RunState.hand_level_requested.disconnect(_on_demande)
	RunState.reset()


func _test_le_bot_choisit_la_carte_la_plus_loin_de_murir() -> void:
	RunState.reset()
	var a: SpellCard = _carte_a_murir("t_w10_h_bot_a")
	var b: SpellCard = _carte_a_murir("t_w10_h_bot_b")
	RunState.grant_card_xp(a, 3)
	ok(RunState.hand_level_xp_needed(b) > RunState.hand_level_xp_needed(a), "(b est plus loin)")
	eq(AutoPick.hand_level_choice([a, b]), b, "le bot fait murir celle a qui il manque le plus")
	eq(AutoPick.hand_level_choice([b, a]), b, "quel que soit l ordre de la main")
	RunState.reset()


## Le vrai chemin : une carte hand_card_level lancee dans une partie headless ;
## GameController tranche par AutoPick, la carte choisie murit et le bot prend
## sa voie. La partie est figee tant qu un choix attend.
func _test_la_main_murit_dans_une_vraie_partie() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		ok(false, "lvl_01 existe")
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	var cible: SpellCard = _carte_a_murir("t_w10_h_partie")
	RunState.hand.clear()
	RunState.hand.append(cible)
	var sort: SpellCard = _card("t_w10_h_sort", &"hand_card_level", GameEnums.DamageTag.ARCANE)
	sort.targeting = GameEnums.Targeting.NONE
	var ctx := CastContext.make(g.battlefield, sort)
	ctx.caster = g
	EffectRegistry.cast(sort, ctx)
	eq(RunState.pending_hand_level, 0, "en headless, AutoPick tranche tout de suite")
	eq(RunState.maturations_done(cible), 1, "la carte de la main a muri (voie prise par le bot)")
	RunState.pending_hand_level = 1
	ok(g.game_frozen_by_choice(), "un choix en attente fige la partie")
	RunState.pending_hand_level = 0
	detach(g)
	RunState.reset()


func _test_l_ecran_du_choix_de_main() -> void:
	RunState.reset()
	# Des cartes du CATALOGUE : la carte de detail lit leur icone et leur feuille.
	var a: SpellCard = ContentDB.cards.get(&"fireball")
	var b: SpellCard = ContentDB.cards.get(&"frost_field")
	if a == null or b == null:
		ok(false, "fireball et frost_field existent")
		return
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var p := HandLevelPanel.new()
	hote.add_child(p)
	var liste: Array[SpellCard] = [a, b]
	p.show_choices(liste)
	var vus: Array[SpellCard] = p.listed_cards()
	ok(vus.size() == 2 and vus[0] == a and vus[1] == b, "les deux sorts sont a l ecran")
	ok(p.find_child("Carte1", true, false) != null, "chaque sort a sa carte")
	ok(p.find_child("Passer", true, false) != null, "et l ecran a une sortie")
	var choisis: Array = []
	p.card_chosen.connect(func(c: SpellCard) -> void: choisis.append(c))
	p.press(1)
	(p.find_child("Passer", true, false) as Button).pressed.emit()
	ok(choisis.size() == 2 and choisis[0] == b and choisis[1] == null,
		"toucher une carte la designe, PASSER ne designe rien")
	ok(p.size.x >= hote.size.x * 0.99 and p.size.y >= hote.size.y * 0.99,
		"le panneau couvre l ecran (%s)" % p.size)
	detach(hote)
	RunState.reset()
