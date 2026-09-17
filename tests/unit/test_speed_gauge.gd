extends TestCase
## Mecanique signature : multiplicateur, scaling du cast, XP, bouclier, agonie.

func get_suite_name() -> String:
	return "speed_gauge"


func run() -> void:
	_test_cycle_order()
	_test_cast_time_scaling()
	_test_xp_multiplication()
	_test_shield_before_hp()
	_test_shield_sequence()
	_test_death_drain()
	_test_world_delta()
	_test_auto_rise()


func _test_cycle_order() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.multiplier(), 1.0, "depart a x1")
	SpeedGauge.cycle()
	eq(SpeedGauge.multiplier(), 1.5, "x1 -> x1.5")
	SpeedGauge.cycle()
	eq(SpeedGauge.multiplier(), 2.0, "x1.5 -> x2")
	SpeedGauge.cycle()
	eq(SpeedGauge.multiplier(), 4.0, "x2 -> x4")
	ok(SpeedGauge.is_at_max(), "x4 est le maximum")
	SpeedGauge.cycle()
	eq(SpeedGauge.multiplier(), 1.0, "x4 reboucle sur x1")


func _test_cast_time_scaling() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.effective_cast_time(4.0), 4.0, "cast 4 s a x1")
	SpeedGauge.set_step(1)
	feq(SpeedGauge.effective_cast_time(3.0), 2.0, "cast 3 s a x1.5")
	SpeedGauge.set_step(2)
	feq(SpeedGauge.effective_cast_time(4.0), 2.0, "cast 4 s a x2")
	SpeedGauge.set_step(3)
	feq(SpeedGauge.effective_cast_time(4.0), 1.0, "cast 4 s a x4 = 1 s")


func _test_xp_multiplication() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.xp_for(10), 10, "XP a x1")
	SpeedGauge.set_step(1)
	eq(SpeedGauge.xp_for(10), 15, "XP a x1.5")
	SpeedGauge.set_step(3)
	eq(SpeedGauge.xp_for(10), 40, "XP a x4")


## LA regle a ne jamais casser.
func _test_shield_before_hp() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_step(3)
	var hp_before: int = SpeedGauge.hp

	var collapsed: Array[bool] = [false]
	var hp_touched: Array[bool] = [false]
	var on_collapse := func() -> void: collapsed[0] = true
	var on_hp := func(_v: int) -> void: hp_touched[0] = true
	SpeedGauge.shield_collapsed.connect(on_collapse)
	SpeedGauge.hp_changed.connect(on_hp)

	SpeedGauge.take_hit()

	eq(SpeedGauge.multiplier(), 1.0, "le coup fait retomber la jauge a x1")
	eq(SpeedGauge.hp, hp_before, "le coup ne coute AUCUN PV tant que la jauge est haute")
	ok(collapsed[0], "shield_collapsed est emis")
	not_ok(hp_touched[0], "hp_changed n'est PAS emis sur l'effondrement du bouclier")

	SpeedGauge.shield_collapsed.disconnect(on_collapse)
	SpeedGauge.hp_changed.disconnect(on_hp)

	SpeedGauge.take_hit()
	eq(SpeedGauge.hp, hp_before - 1, "le coup suivant, deja a x1, entame les PV")


func _test_shield_sequence() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_step(3)
	SpeedGauge.take_hit()  # consomme le bouclier
	eq(SpeedGauge.hp, 3, "PV intacts apres l'effondrement")
	SpeedGauge.take_hit()
	eq(SpeedGauge.hp, 2, "2e coup -> 2 PV")
	SpeedGauge.take_hit()
	eq(SpeedGauge.hp, 1, "3e coup -> 1 PV")
	not_ok(SpeedGauge.is_dying, "pas encore mourant a 1 PV")
	SpeedGauge.take_hit()
	eq(SpeedGauge.hp, 0, "4e coup -> 0 PV")
	ok(SpeedGauge.is_dying, "0 PV declenche l'agonie")


func _test_death_drain() -> void:
	SpeedGauge.reset()
	var started: Array[int] = [0]
	var ended: Array[int] = [0]
	var on_start := func() -> void: started[0] += 1
	var on_died := func() -> void: ended[0] += 1
	SpeedGauge.death_started.connect(on_start)
	SpeedGauge.died.connect(on_died)

	for i in 3:
		SpeedGauge.take_hit()
	eq(started[0], 1, "death_started emis une seule fois")
	eq(ended[0], 0, "died pas encore emis")

	# La jauge d'agonie se vide a DEATH_DRAIN_RATE par seconde reelle.
	var elapsed: float = 0.0
	while elapsed < 3.9:
		SpeedGauge.tick(0.1)
		elapsed += 0.1
	eq(ended[0], 0, "toujours vivant juste avant la fin du drain")

	SpeedGauge.tick(0.2)
	eq(ended[0], 1, "died emis quand la jauge d'agonie atteint 0")

	var hp_at_death: int = SpeedGauge.hp
	SpeedGauge.take_hit()
	eq(SpeedGauge.hp, hp_at_death, "take_hit est sans effet pendant l'agonie")

	SpeedGauge.death_started.disconnect(on_start)
	SpeedGauge.died.disconnect(on_died)


func _test_world_delta() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.world_delta(1.0), 1.0, "world_delta a x1")
	SpeedGauge.set_step(3)
	feq(SpeedGauge.world_delta(1.0), 4.0, "world_delta a x4")
	# En agonie le monde passe au ralenti, quel que soit le multiplicateur.
	SpeedGauge.set_step(0)
	for i in 3:
		SpeedGauge.take_hit()
	feq(SpeedGauge.world_delta(1.0), GameConfig.DEATH_SLOWMO, "world_delta au ralenti en agonie")


func _test_auto_rise() -> void:
	SpeedGauge.reset()
	SpeedGauge.tick(GameConfig.AUTO_RISE_INTERVAL - 0.1)
	eq(SpeedGauge.step_index, 0, "pas encore de montee automatique")
	SpeedGauge.tick(0.2)
	eq(SpeedGauge.step_index, 1, "montee automatique d'un cran")
	# Ne doit jamais depasser le maximum.
	for i in 10:
		SpeedGauge.tick(GameConfig.AUTO_RISE_INTERVAL + 0.1)
	ok(SpeedGauge.is_at_max(), "la montee automatique plafonne a x4")
