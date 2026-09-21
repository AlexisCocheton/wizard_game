extends TestCase
## Mecanique signature : vitesse en pourcentage, scaling du cast, XP, bouclier, agonie.
##
## Le systeme est passe de quatre paliers (x1/x1.5/x2/x4) a un pourcentage continu
## (100 a 500 %). Les regles protegees ici n ont PAS change : le bouclier passe
## avant les PV, le temps d incantation suit la vitesse, l XP aussi, et l agonie
## laisse quelques secondes avant la defaite.
##
## La MONTEE de la vitesse (continue, 2 points par seconde, plus aucune commande
## manuelle) vit dans test_speed_percent.gd : elle a change le 21 septembre et
## la garder en double ici aurait fige l ancienne regle par paliers.

func get_suite_name() -> String:
	return "speed_gauge"


func run() -> void:
	_test_echelle_de_vitesse()
	_test_cast_time_scaling()
	_test_xp_multiplication()
	_test_shield_before_hp()
	_test_death_drain()
	_test_world_delta()
	SpeedGauge.reset()


func _test_echelle_de_vitesse() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.multiplier(), 1.0, "depart a 100 %")
	SpeedGauge.set_speed_percent(250)
	feq(SpeedGauge.multiplier(), 2.5, "250 % = x2,5")
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	ok(SpeedGauge.is_at_max(), "500 % est le maximum")
	# Le pourcentage ne peut pas descendre sous 100 ni depasser le maximum.
	SpeedGauge.set_speed_percent(50)
	eq(SpeedGauge.speed_percent, 100, "la vitesse ne descend pas sous 100 %")
	SpeedGauge.set_speed_percent(9000)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "et ne depasse pas le maximum")


func _test_cast_time_scaling() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.effective_cast_time(4.0), 4.0, "cast 4 s a 100 %")
	SpeedGauge.set_speed_percent(200)
	feq(SpeedGauge.effective_cast_time(4.0), 2.0, "cast 4 s a 200 %")
	SpeedGauge.set_speed_percent(400)
	feq(SpeedGauge.effective_cast_time(4.0), 1.0, "cast 4 s a 400 % = 1 s")


func _test_xp_multiplication() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.xp_for(10), 10, "XP a 100 %")
	SpeedGauge.set_speed_percent(150)
	eq(SpeedGauge.xp_for(10), 15, "XP a 150 %")
	SpeedGauge.set_speed_percent(400)
	eq(SpeedGauge.xp_for(10), 40, "XP a 400 %")


## LA regle a ne jamais casser : le bouclier absorbe AVANT les PV.
func _test_shield_before_hp() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(400)
	var hp_before: int = SpeedGauge.hp
	var bouclier: int = SpeedGauge.shield()
	ok(bouclier > 0, "a 400 % le mage a du bouclier")

	var collapsed: Array[bool] = [false]
	var hp_touched: Array[bool] = [false]
	var on_collapse := func() -> void: collapsed[0] = true
	var on_hp := func(_v: int) -> void: hp_touched[0] = true
	SpeedGauge.shield_collapsed.connect(on_collapse)
	SpeedGauge.hp_changed.connect(on_hp)

	# Un coup plus petit que le bouclier ne coute AUCUN PV.
	SpeedGauge.take_hit(maxi(1, bouclier - 1))

	eq(SpeedGauge.hp, hp_before, "le coup absorbe ne coute aucun PV")
	ok(collapsed[0], "shield_collapsed est emis")
	not_ok(hp_touched[0], "hp_changed n'est PAS emis quand le bouclier absorbe tout")
	ok(SpeedGauge.speed_percent < 400, "le coup fait retomber la vitesse")

	SpeedGauge.shield_collapsed.disconnect(on_collapse)
	SpeedGauge.hp_changed.disconnect(on_hp)

	# Sans bouclier, le coup entame les PV.
	SpeedGauge.reset()
	SpeedGauge.take_hit(7)
	eq(SpeedGauge.hp, hp_before - 7, "a 100 % le coup entame directement les PV")


func _test_death_drain() -> void:
	SpeedGauge.reset()
	var started: Array[int] = [0]
	var ended: Array[int] = [0]
	var on_start := func() -> void: started[0] += 1
	var on_died := func() -> void: ended[0] += 1
	SpeedGauge.death_started.connect(on_start)
	SpeedGauge.died.connect(on_died)

	SpeedGauge.take_hit(GameConfig.MAGE_MAX_HP)
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
	SpeedGauge.take_hit(5)
	eq(SpeedGauge.hp, hp_at_death, "take_hit est sans effet pendant l'agonie")

	SpeedGauge.death_started.disconnect(on_start)
	SpeedGauge.died.disconnect(on_died)


func _test_world_delta() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.world_delta(1.0), 1.0, "world_delta a 100 %")
	SpeedGauge.set_speed_percent(400)
	feq(SpeedGauge.world_delta(1.0), 4.0, "world_delta a 400 %")
	# En agonie le monde passe au ralenti, quelle que soit la vitesse.
	SpeedGauge.reset()
	SpeedGauge.take_hit(GameConfig.MAGE_MAX_HP)
	feq(SpeedGauge.world_delta(1.0), GameConfig.DEATH_SLOWMO, "world_delta au ralenti en agonie")

