extends TestCase
## Vitesse en POURCENTAGE (100 a 500 %) au lieu de quatre paliers fixes.
##
## Demande du testeur : "un systeme en pourcentage et pas en 1/2/4, qu on puisse
## augmenter avec plus de parcimonie", "la barre va jusqu a 500 %", "quand on
## augmente la vitesse ca augmente le bouclier", "quand on prend des degats la
## vitesse diminue" et "on ne peut pas accelerer pendant 3 s apres un coup".

func get_suite_name() -> String:
	return "speed_percent"


func run() -> void:
	_test_bornes_et_pas()
	_test_le_bouclier_suit_la_vitesse()
	_test_un_coup_fait_tomber_la_vitesse()
	_test_pas_d_acceleration_juste_apres_un_coup()
	_test_reglage_direct_par_la_barre()
	SpeedGauge.reset()


## 100 % au depart, 500 % au maximum, +10 % par appui.
func _test_bornes_et_pas() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.speed_percent, 100, "on demarre a 100 %")
	feq(SpeedGauge.multiplier(), 1.0, "100 % = vitesse normale")

	SpeedGauge.bump_speed()
	eq(SpeedGauge.speed_percent, 110, "un appui ajoute 10 %")
	feq(SpeedGauge.multiplier(), 1.1, "110 % = x1,1")

	for i in 100:
		SpeedGauge.bump_speed()
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "on plafonne a 500 %")
	# Au maximum, un appui de plus ne fait PAS repasser a 100 % : c est le bug
	# signale ("quand on accelere ca ne repasse pas a 0 quand on est au max").
	SpeedGauge.bump_speed()
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT,
		"au maximum, un appui de plus ne remet pas a 100 %")


## Le bouclier vient de la vitesse : plus on va vite, plus on encaisse.
func _test_le_bouclier_suit_la_vitesse() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.shield(), 0, "aucun bouclier a 100 %")
	SpeedGauge.set_speed_percent(300)
	ok(SpeedGauge.shield() > 0, "a 300 % le mage a du bouclier")
	var a_300: int = SpeedGauge.shield()
	SpeedGauge.set_speed_percent(500)
	ok(SpeedGauge.shield() > a_300, "a 500 % il en a davantage")


## Un coup consomme le bouclier ET fait retomber la vitesse.
func _test_un_coup_fait_tomber_la_vitesse() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(400)
	var avant: int = SpeedGauge.speed_percent
	var pv_avant: int = SpeedGauge.hp
	SpeedGauge.take_hit(10)
	ok(SpeedGauge.speed_percent < avant, "la vitesse retombe apres un coup")
	ok(SpeedGauge.hp >= pv_avant - 10, "le bouclier a absorbe une partie du coup")


## Trois secondes sans pouvoir accelerer apres un coup : on ne relance pas la
## machine dans la seconde ou on vient de se faire toucher.
func _test_pas_d_acceleration_juste_apres_un_coup() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(200)
	SpeedGauge.take_hit(5)
	var bloque: int = SpeedGauge.speed_percent
	SpeedGauge.bump_speed()
	eq(SpeedGauge.speed_percent, bloque, "l acceleration est refusee juste apres le coup")
	ok(SpeedGauge.accel_locked(), "le verrou est signale a l interface")

	SpeedGauge.tick(GameConfig.SPEED_LOCK_AFTER_HIT + 0.1)
	not_ok(SpeedGauge.accel_locked(), "le verrou se leve apres le delai")
	SpeedGauge.bump_speed()
	ok(SpeedGauge.speed_percent > bloque, "on peut de nouveau accelerer")


## La barre est cliquable : toucher un point la regle directement.
func _test_reglage_direct_par_la_barre() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_from_ratio(0.0)
	eq(SpeedGauge.speed_percent, 100, "tout en bas = 100 %")
	SpeedGauge.set_speed_from_ratio(1.0)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "tout en haut = 500 %")
	SpeedGauge.set_speed_from_ratio(0.5)
	eq(SpeedGauge.speed_percent, 300, "au milieu = 300 %")
