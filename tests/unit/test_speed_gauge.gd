extends TestCase
## Mecanique signature : echelle de vitesse, scaling du cast, XP, agonie.
##
## Ce fichier protege ce qui n a PAS change le 26 septembre : le temps
## d incantation suit la vitesse, l XP aussi, le monde aussi, et l agonie laisse
## quelques secondes avant la defaite.
##
## Ce qui a change — la vitesse est devenue la seule reserve de vie, le bouclier
## et les PV ont disparu — vit dans test_speed_is_life.gd. Garder les deux ici
## aurait melange la regle d hier et celle d aujourd hui dans un meme fichier.
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
	_test_death_drain()
	_test_world_delta()
	SpeedGauge.reset()


func _test_echelle_de_vitesse() -> void:
	SpeedGauge.reset()
	feq(SpeedGauge.multiplier(), float(GameConfig.SPEED_START_PERCENT) * 0.01,
		"depart a SPEED_START_PERCENT")
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
	SpeedGauge.set_speed_percent(100)
	feq(SpeedGauge.effective_cast_time(4.0), 4.0, "cast 4 s a 100 %")
	SpeedGauge.set_speed_percent(200)
	feq(SpeedGauge.effective_cast_time(4.0), 2.0, "cast 4 s a 200 %")
	SpeedGauge.set_speed_percent(400)
	feq(SpeedGauge.effective_cast_time(4.0), 1.0, "cast 4 s a 400 % = 1 s")


func _test_xp_multiplication() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)
	eq(SpeedGauge.xp_for(10), 10, "XP a 100 %")
	SpeedGauge.set_speed_percent(150)
	eq(SpeedGauge.xp_for(10), 15, "XP a 150 %")
	SpeedGauge.set_speed_percent(400)
	eq(SpeedGauge.xp_for(10), 40, "XP a 400 %")


func _test_death_drain() -> void:
	SpeedGauge.reset()
	var started: Array[int] = [0]
	var ended: Array[int] = [0]
	var on_start := func() -> void: started[0] += 1
	var on_died := func() -> void: ended[0] += 1
	SpeedGauge.death_started.connect(on_start)
	SpeedGauge.died.connect(on_died)

	# Un coup a hauteur de la reserve entiere ramene la vitesse au plancher,
	# et le plancher c est la mort.
	SpeedGauge.take_hit(SpeedGauge.max_reserve())
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

	var vitesse_a_la_mort: int = SpeedGauge.speed_percent
	SpeedGauge.take_hit(5)
	eq(SpeedGauge.speed_percent, vitesse_a_la_mort,
		"take_hit est sans effet pendant l'agonie")

	SpeedGauge.death_started.disconnect(on_start)
	SpeedGauge.died.disconnect(on_died)


func _test_world_delta() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)
	feq(SpeedGauge.world_delta(1.0), 1.0, "world_delta a 100 %")
	SpeedGauge.set_speed_percent(400)
	feq(SpeedGauge.world_delta(1.0), 4.0, "world_delta a 400 %")
	# En agonie le monde passe au ralenti, quelle que soit la vitesse.
	SpeedGauge.reset()
	SpeedGauge.take_hit(SpeedGauge.max_reserve())
	feq(SpeedGauge.world_delta(1.0), GameConfig.DEATH_SLOWMO, "world_delta au ralenti en agonie")
	SpeedGauge.reset()

