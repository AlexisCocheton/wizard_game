extends TestCase
## Vitesse en POURCENTAGE (100 a 500 %), montee NATURELLE et continue.
##
## Demande du testeur (21 septembre) : "La barre de vitesse n est plus
## accelerable manuellement ni en cliquant ni par le bouton. La vitesse augmente
## naturellement progressivement, 1 % par 0,5 seconde."
##
## Ce qui est garde des demandes precedentes : "la barre va jusqu a 500 %",
## "quand on prend des degats la vitesse diminue" et "on ne peut pas accelerer
## juste apres un coup" — le verrou retient la montee naturelle.
##
## Le bouclier a DISPARU le 26 septembre avec les PV : la vitesse est la seule
## reserve. Ce que cette suppression garantit vit dans test_speed_is_life.gd.
##
## Les regles s expriment contre les constantes de GameConfig, jamais contre une
## valeur d equilibrage gravee ici (voir gotchas : un test qui fige un reglage
## bloque l equilibrage au lieu de le proteger).

func get_suite_name() -> String:
	return "speed_percent"


func run() -> void:
	_test_bornes()
	_test_plus_aucune_commande_manuelle()
	_test_la_montee_est_continue_par_pas_de_un()
	_test_la_montee_plafonne_sans_reboucler()
	_test_un_coup_fait_tomber_la_vitesse()
	_test_le_verrou_retient_la_montee_apres_un_coup()
	_test_pas_de_montee_pendant_l_agonie()
	SpeedGauge.reset()


## Secondes necessaires pour gagner UN point de pourcentage.
func _seconds_per_point() -> float:
	return 1.0 / GameConfig.SPEED_RISE_PER_SECOND


## 100 % au depart, 500 % au maximum ; le reglage interne reste borne.
func _test_bornes() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_START_PERCENT,
		"on demarre a SPEED_START_PERCENT, jamais au plancher : a 100 % on est mort")
	SpeedGauge.set_speed_percent(100)
	feq(SpeedGauge.multiplier(), 1.0, "100 % = vitesse normale")
	SpeedGauge.set_speed_percent(50)
	eq(SpeedGauge.speed_percent, 100, "jamais sous 100 %")
	SpeedGauge.set_speed_percent(9000)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "jamais au-dessus du maximum")


## "Plus accelerable manuellement ni en cliquant ni par le bouton" : les deux
## entrees manuelles n existent plus. Un HUD qui les rappellerait planterait,
## ce qui est le comportement voulu : on ne veut pas d un bouton mort qui traine.
func _test_plus_aucune_commande_manuelle() -> void:
	not_ok(SpeedGauge.has_method("bump_speed"),
		"le bouton d acceleration n a plus de point d entree")
	not_ok(SpeedGauge.has_method("set_speed_from_ratio"),
		"la barre n est plus reglable au doigt")
	ok(GameConfig.SPEED_RISE_PER_SECOND > 0.0,
		"la montee naturelle est le seul moteur de la vitesse")


## "1 % par 0,5 seconde" : la montee est CONTINUE (accumulateur), mais le
## pourcentage affiche n avance que par pas entiers de 1.
func _test_la_montee_est_continue_par_pas_de_un() -> void:
	SpeedGauge.reset()
	# On repart du plancher pour que les nombres du test restent lisibles :
	# ce qu on mesure ici est le RYTHME, pas le point de depart d une partie.
	SpeedGauge.set_speed_percent(100)
	var pas: float = _seconds_per_point()

	# Une moitie de pas ne donne rien : le pourcentage reste entier.
	SpeedGauge.tick(pas * 0.5)
	eq(SpeedGauge.speed_percent, 100, "un demi-pas ne fait pas encore avancer le pourcentage")
	# ... mais elle n est pas perdue : la seconde moitie complete le point.
	SpeedGauge.tick(pas * 0.5)
	eq(SpeedGauge.speed_percent, 101, "deux demi-pas font un point : l accumulateur retient le reste")

	# Un pas entier = exactement +1, jamais +10.
	SpeedGauge.tick(pas)
	eq(SpeedGauge.speed_percent, 102, "un pas entier ajoute exactement 1 %")

	# Sur une seconde, on gagne SPEED_RISE_PER_SECOND points.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)
	for i in 60:
		SpeedGauge.tick(1.0 / 60.0)
	eq(SpeedGauge.speed_percent, 100 + int(round(GameConfig.SPEED_RISE_PER_SECOND)),
		"apres 1 s a 60 images/s : +%d %%" % int(round(GameConfig.SPEED_RISE_PER_SECOND)))

	# Un gros delta (chute d images) ne fait pas sauter la regle : il vaut
	# exactement le nombre de points que ce temps represente.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)
	SpeedGauge.tick(10.0)
	eq(SpeedGauge.speed_percent, 100 + int(floor(10.0 * GameConfig.SPEED_RISE_PER_SECOND)),
		"10 s d un coup valent 10 s de montee, ni plus ni moins")


## Le maximum est un plafond : on y reste, on ne repasse jamais a 100 %.
func _test_la_montee_plafonne_sans_reboucler() -> void:
	SpeedGauge.reset()
	var etendue: float = float(GameConfig.SPEED_MAX_PERCENT - 100)
	var duree: float = etendue / GameConfig.SPEED_RISE_PER_SECOND
	var t: float = 0.0
	while t < duree + 5.0:
		SpeedGauge.tick(0.1)
		t += 0.1
	ok(SpeedGauge.is_at_max(), "apres %.0f s la vitesse est au maximum" % duree)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "et ne le depasse pas")
	for i in 100:
		SpeedGauge.tick(1.0)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT,
		"au maximum, le temps qui passe ne remet pas a 100 %")


## Un coup fait tomber la vitesse d EXACTEMENT ses degats : il n y a plus de
## forfait par-dessus (voir test_speed_is_life.gd pour la regle complete).
func _test_un_coup_fait_tomber_la_vitesse() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(400)
	SpeedGauge.take_hit(10)
	eq(SpeedGauge.speed_percent, 390, "la vitesse retombe de la valeur du coup")
	# Le plancher est un plancher : la chute s y arrete.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(120)
	SpeedGauge.take_hit(90)
	eq(SpeedGauge.speed_percent, 100, "la chute ne descend jamais sous 100 %")
	SpeedGauge.reset()


## Pendant SPEED_LOCK_AFTER_HIT secondes apres un coup, la montee naturelle est
## retenue : on ne relance pas la machine dans la seconde ou l on vient d etre
## touche. Le verrou se leve ensuite et la montee reprend.
func _test_le_verrou_retient_la_montee_apres_un_coup() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(200)
	SpeedGauge.take_hit(5)
	var bloque: int = SpeedGauge.speed_percent
	ok(SpeedGauge.accel_locked(), "le verrou est signale a l interface")

	# Presque toute la fenetre de verrou : rien ne bouge.
	var presque: float = GameConfig.SPEED_LOCK_AFTER_HIT - 0.2
	var t: float = 0.0
	while t < presque:
		SpeedGauge.tick(0.05)
		t += 0.05
	eq(SpeedGauge.speed_percent, bloque, "la montee est retenue pendant le verrou")
	ok(SpeedGauge.accel_locked(), "le verrou tient encore")

	# Le verrou tombe, puis la montee reprend au rythme normal.
	SpeedGauge.tick(0.3)
	not_ok(SpeedGauge.accel_locked(), "le verrou se leve apres le delai")
	for i in 20:
		SpeedGauge.tick(_seconds_per_point())
	between(float(SpeedGauge.speed_percent - bloque), 19.0, 21.0,
		"apres le verrou, 20 pas redonnent 20 points")


## Une fois le plancher atteint, la jauge d agonie se vide : la vitesse ne
## remonte plus. On ne se soigne pas en mourant.
func _test_pas_de_montee_pendant_l_agonie() -> void:
	SpeedGauge.reset()
	SpeedGauge.take_hit(SpeedGauge.max_reserve())
	ok(SpeedGauge.is_dying, "le mage agonise")
	var avant: int = SpeedGauge.speed_percent
	SpeedGauge.tick(1.0)
	eq(SpeedGauge.speed_percent, avant, "aucune montee pendant l agonie")
	SpeedGauge.reset()
