extends TestCase
## QU EST-CE QU UN COUP ? (vague 9, audit du Dard venimeux)
##
## Une zone au sol et un poison mordent un peu a CHAQUE IMAGE. Ils passaient par
## Battlefield._hit() comme un coup, et tout ce qui se compte en coups suivait la
## frequence d images : un dard depouillait un Mage des arcanes de ses 10 coups
## d immunite en 10 images, tirait la riposte des monstres a laser et la Morsure
## de givre a chaque image, et une zone sur un Miroir renvoyait au mage un coup
## par image. La regle est ecrite dans Enemy (CONTINUOUS_FEEDBACK_INTERVAL) ;
## ces tests la verrouillent, chacun contre la cadence d images quand elle compte.

func get_suite_name() -> String:
	return "continuous_damage"


func _def(id: String, pv: float = 100000.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = pv
	d.base_speed = 0.0
	d.base_radius = 30.0
	d.base_xp = 1
	return d


func _card(key: StringName, magnitude: float, el: int) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName("t_cont_" + String(key))
	c.display_name = "Test " + String(key)
	c.base_cast_time = 1.0
	c.targeting = GameEnums.Targeting.TARGET
	c.element = el
	var sp := EffectSpec.new()
	sp.key = key
	sp.magnitude = magnitude
	c.effects = [sp]
	return c


func _field() -> Battlefield:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _fresh() -> Battlefield:
	reset_gauge_at_normal_speed()
	RunState.reset()
	return _field()


## Simule `secondes` de monde en images de 1 / `ips` s, mage maintenu a x1.
func _avancer(bf: Battlefield, secondes: float, ips: float = 60.0) -> void:
	var t: float = 0.0
	var dt: float = 1.0 / ips
	while t < secondes:
		bf.simulate(dt)
		t += SpeedGauge.world_delta(dt)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)


## Une zone de feu sous `e`, assez longue pour toute la mesure.
func _zone_sous(bf: Battlefield, e: Enemy, dps: float) -> void:
	bf.spawn_ground_zone(e.position, 200.0, 999.0, dps, 0.0,
		_card(&"ground_zone", dps, GameEnums.DamageTag.FIRE))


func run() -> void:
	_test_la_zone_n_use_pas_le_compteur_de_coups()
	_test_le_poison_n_use_pas_le_compteur_de_coups()
	_test_la_zone_ne_brise_pas_le_bouclier()
	_test_la_zone_ne_declenche_pas_la_riposte_laser()
	_test_les_coups_montres_ne_suivent_pas_les_images()
	_test_la_morsure_de_givre_ne_suit_pas_les_images()
	_test_le_renvoi_continu_ne_suit_pas_les_images()
	_test_l_esquive_du_continu_est_une_moyenne()
	_test_le_dard_sur_un_immunise_est_sans_effet()


## Le coeur de l audit : le compteur « immunise aux N premiers coups » ne se
## vide qu avec des COUPS. La zone bute dessus sans l user ni l entamer.
func _test_la_zone_n_use_pas_le_compteur_de_coups() -> void:
	var bf := _fresh()
	var d := _def("t_cont_mage")
	d.hits_immune = 3
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	_zone_sous(bf, e, 50.0)
	_avancer(bf, 2.0)
	eq(e.hits_immune_left(), 3, "deux secondes de zone n usent AUCUN coup")
	feq(e.hp, d.max_hp, "et ne l entament pas tant qu il est protege")
	for i in 3:
		bf.damage_enemy(e, 1.0, _card(&"damage_single", 1.0, GameEnums.DamageTag.ARCANE))
	eq(e.hits_immune_left(), 0, "trois COUPS le depouillent")
	_avancer(bf, 1.0)
	ok(e.hp < d.max_hp, "et la zone mord ensuite normalement")
	detach(bf)


func _test_le_poison_n_use_pas_le_compteur_de_coups() -> void:
	var bf := _fresh()
	var d := _def("t_cont_mage2")
	d.hits_immune = 10
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	var dard := _card(&"poison_dot", 5.0, GameEnums.DamageTag.POISON)
	ok(bf.poison_enemy(e, 5.0, dard), "le poison se pose sur un monstre non immunise")
	_avancer(bf, 1.0)
	eq(e.hits_immune_left(), 10, "un dard ne depouille pas un Mage de ses 10 coups")
	feq(e.hp, d.max_hp, "le poison attend que les coups l aient depouille")
	detach(bf)


func _test_la_zone_ne_brise_pas_le_bouclier() -> void:
	var bf := _fresh()
	var d := _def("t_cont_bouclier")
	d.first_hit_shield = true
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	ok(e.has_shield(), "il entre bouclier leve")
	_zone_sous(bf, e, 50.0)
	_avancer(bf, 1.0)
	ok(e.has_shield(), "une zone ne brise pas le bouclier du premier coup")
	bf.damage_enemy(e, 1.0, _card(&"damage_single", 1.0, GameEnums.DamageTag.ARCANE))
	not_ok(e.has_shield(), "un coup le brise")
	detach(bf)


func _test_la_zone_ne_declenche_pas_la_riposte_laser() -> void:
	var bf := _fresh()
	var d := _def("t_cont_laser")
	d.laser_damage = 1
	d.laser_cooldown = Enemy.LASER_MIN_COOLDOWN
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	_zone_sous(bf, e, 5.0)
	_avancer(bf, Enemy.LASER_MIN_COOLDOWN * 6.0)
	eq(bf.lasers_fired, 0, "une zone ne fait pas riposter le monstre a laser")
	bf.damage_enemy(e, 1.0, _card(&"damage_single", 1.0, GameEnums.DamageTag.ARCANE))
	eq(bf.lasers_fired, 1, "un coup, si")
	detach(bf)


## L eclair et le son : au plus un par intervalle, et le MEME nombre a 60 et a
## 240 images par seconde.
func _test_les_coups_montres_ne_suivent_pas_les_images() -> void:
	var duree: float = Enemy.CONTINUOUS_FEEDBACK_INTERVAL * 8.0
	var comptes: Array[int] = []
	for ips in [60.0, 240.0]:
		var bf := _fresh()
		var e: Enemy = bf.spawn_enemy(_def("t_cont_flash"), 540.0, 1.0, Vector2(540, 600))
		_zone_sous(bf, e, 5.0)
		_avancer(bf, duree, ips)
		comptes.append(bf.hit_feedbacks)
		detach(bf)
	var plafond: int = int(ceil(duree / Enemy.CONTINUOUS_FEEDBACK_INTERVAL)) + 1
	ok(comptes[0] > 0, "le degat continu se montre encore (%d)" % comptes[0])
	ok(comptes[0] <= plafond, "au plus un eclair par intervalle (%d pour %d)" % [comptes[0], plafond])
	eq(comptes[1], comptes[0], "autant d eclairs a 240 images/s qu a 60")


## « Tout degat ralentit » : le poison aussi, mais la Morsure se pose au rythme
## de l intervalle, pas de l ecran.
func _test_la_morsure_de_givre_ne_suit_pas_les_images() -> void:
	var morsure: SpellCard = ContentDB.cards.get(&"pass_frostbite")
	ok(morsure != null, "la Morsure de givre existe")
	if morsure == null:
		return
	var bf := _fresh()
	RunState.equipped_passives.append(morsure)
	var e: Enemy = bf.spawn_enemy(_def("t_cont_morsure"), 540.0, 1.0, Vector2(540, 600))
	ok(bf.poison_enemy(e, 2.0, _card(&"poison_dot", 2.0, GameEnums.DamageTag.POISON)),
		"le poison se pose")
	var vit: int = maxi(100, morsure.speed_threshold)
	var t: float = 0.0
	var dt: float = 1.0 / 240.0
	var duree: float = Enemy.CONTINUOUS_FEEDBACK_INTERVAL * 4.0
	while t < duree:
		SpeedGauge.set_speed_percent(vit)
		bf.simulate(dt)
		t += SpeedGauge.world_delta(dt)
	ok(RunState.passive_active(morsure), "la Morsure est active a %d %%" % vit)
	ok(e._slow_factor < 1.0, "le poison ralentit sous la Morsure (tout degat)")
	ok(bf.hit_feedbacks <= int(ceil(duree / Enemy.CONTINUOUS_FEEDBACK_INTERVAL)) + 1,
		"mais la Morsure ne se pose pas a chaque image (%d)" % bf.hit_feedbacks)
	RunState.equipped_passives.clear()
	detach(bf)


## Une zone sur un Miroir pendant sa garde : le renvoi suit les DEGATS, pas le
## nombre d images. Avant : un coup au mage par image.
func _test_le_renvoi_continu_ne_suit_pas_les_images() -> void:
	var comptes: Array[int] = []
	for ips in [60.0, 240.0]:
		var bf := _fresh()
		var d := _def("t_cont_miroir")
		d.reflect_interval = 100.0
		d.reflect_window = 50.0
		d.reflect_pct = 50.0
		var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
		e.force_reflect_window(50.0)
		var n: Array[int] = [0]
		bf.mage_hit.connect(func(_a: Variant, _b: Variant) -> void: n[0] += 1)
		_zone_sous(bf, e, 10.0)
		_avancer(bf, 1.0, ips)
		comptes.append(n[0])
		detach(bf)
	ok(comptes[0] < 60, "moins d un renvoi par image (%d en une seconde)" % comptes[0])
	ok(absi(comptes[1] - comptes[0]) <= 1,
		"autant de renvois a 240 images/s qu a 60 (%d contre %d)" % [comptes[1], comptes[0]])


## Esquiver un poison image par image consommait le hasard au rythme de l ecran.
## Le degat continu est reduit de la part esquivee, sans tirage.
func _test_l_esquive_du_continu_est_une_moyenne() -> void:
	var bf := _fresh()
	var d := _def("t_cont_esquive")
	d.dodge_chance = 0.4
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	var debit: float = 10.0
	_zone_sous(bf, e, debit)
	var duree: float = 2.0
	var graine_avant: int = RunState.world_rng.state
	_avancer(bf, duree)
	var perdu: float = d.max_hp - e.hp
	between(perdu / (debit * duree * (1.0 - d.dodge_chance)), 0.95, 1.05,
		"il perd le debit moins la part esquivee (%.1f PV)" % perdu)
	eq(RunState.world_rng.state, graine_avant, "sans tirer dans le hasard du monde")
	detach(bf)


## IMMUNISE au poison : le dard ne pose rien, n affiche pas la marque du poison,
## et s ecrase en eclat gris (« sans effet »).
func _test_le_dard_sur_un_immunise_est_sans_effet() -> void:
	var bf := _fresh()
	var d := _def("t_cont_immun")
	d.resistances = {GameEnums.DamageTag.POISON: 0.0}
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, Vector2(540, 600))
	var dard: SpellCard = ContentDB.cards.get(&"venom_dart")
	ok(dard != null, "le Dard venimeux existe")
	if dard == null:
		detach(bf)
		return
	Fx.begin_trace()
	var pose: bool = bf.poison_enemy(e, 5.0, dard)
	var vues: Array[String] = Fx.end_trace()
	not_ok(pose, "le poison ne se pose pas sur un immunise")
	eq(bf.poison_count(e), 0, "aucun poison en cours")
	not_ok(e.has_meta(Battlefield.POISON_MARKER_META), "aucune marque de poison sur lui")
	not_ok(vues.has(String(dard.fx_key)), "la feuille du poison n est pas jouee %s" % [vues])
	eq(bf.poison_refused, 1, "le refus est compte (eclat gris)")
	# Le meme dard sur un monstre ordinaire, lui, pose sa marque.
	var o: Enemy = bf.spawn_enemy(_def("t_cont_ordinaire"), 200.0, 1.0, Vector2(200, 600))
	Fx.begin_trace()
	ok(bf.poison_enemy(o, 5.0, dard), "sur un monstre ordinaire le poison se pose")
	ok(Fx.end_trace().has(String(dard.fx_key)), "et sa marque se joue")
	detach(bf)
