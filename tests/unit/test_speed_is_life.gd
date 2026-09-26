extends TestCase
## LA REGLE (26 septembre) : la vitesse EST la vie. Une seule reserve.
##
## Avant, le mage avait DEUX reserves : 100 PV, et une vitesse de 100 a 500 %
## qui lui donnait du bouclier. Un coup entamait le bouclier, puis les PV.
##
## Desormais il n en a qu UNE. Un coup de N degats retire N POINTS DE
## POURCENTAGE de vitesse. A 100 %, le mage meurt. Il n y a plus de PV, plus de
## bouclier, et plus de chute forfaitaire de vitesse a chaque coup : les degats
## SONT la chute.
##
## Consequence voulue et centrale : etre blesse, c est etre LENT. Le joueur
## touche incante plus lentement, gagne moins d XP, perd ses passifs, et voit
## les monstres ralentir avec lui. Le jeu ne se contente plus de le punir, il
## change de rythme sous ses pieds.
##
## Tout s exprime ici en constantes de GameConfig ou en ratios : `eq(hp, 3)`
## nous a deja bloques une fois, on ne recommence pas.

func get_suite_name() -> String:
	return "speed_is_life"


func run() -> void:
	_test_une_seule_reserve()
	_test_un_degat_vaut_un_point_de_vitesse()
	_test_la_mort_arrive_au_plancher()
	_test_pas_de_chute_forfaitaire_en_plus_des_degats()
	_test_le_soin_rend_de_la_vitesse()
	_test_reserve_totale_et_ratio()
	_test_agonie_inchangee()
	SpeedGauge.reset()


## Le mage n a plus qu une reserve : la vitesse. Les PV et le bouclier ont
## disparu de l API — pas "mis a zero", DISPARU. Les laisser en place aurait
## garde un chemin par lequel du vieux code aurait pu continuer a les lire en
## silence, exactement comme le bouton d acceleration qu on avait retire.
func _test_une_seule_reserve() -> void:
	SpeedGauge.reset()
	not_ok(SpeedGauge.has_method("shield"),
		"shield() n existe plus : la vie ne protege pas la vie")
	not_ok(&"hp" in SpeedGauge,
		"SpeedGauge.hp n existe plus : la vitesse est la seule reserve")
	not_ok(&"max_hp" in SpeedGauge,
		"SpeedGauge.max_hp n existe plus non plus")
	not_ok(&"SHIELD_PER_PERCENT" in GameConfig,
		"SHIELD_PER_PERCENT a disparu de GameConfig")
	not_ok(&"SPEED_DROP_ON_HIT" in GameConfig,
		"SPEED_DROP_ON_HIT a disparu : les degats sont la chute")
	not_ok(&"MAGE_MAX_HP" in GameConfig,
		"MAGE_MAX_HP a disparu : le maximum du mage est SPEED_MAX_PERCENT")


## Le coeur du changement : 1 degat = 1 point de pourcentage. Pas un ratio
## cache, pas une conversion. Le testeur a dit "tout ce qui implique 1 degat
## devient un % de vitesse" — on le verifie litteralement.
func _test_un_degat_vaut_un_point_de_vitesse() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var avant: int = SpeedGauge.speed_percent
	var degats: int = 24
	SpeedGauge.take_hit(degats)
	eq(SpeedGauge.speed_percent, avant - degats,
		"un coup de %d retire exactement %d points de vitesse" % [degats, degats])

	# Deux coups s additionnent, sans arrondi ni forfait cache.
	SpeedGauge.take_hit(degats)
	eq(SpeedGauge.speed_percent, avant - 2 * degats,
		"deux coups retirent deux fois autant")


## La mort n arrive plus a "PV zero" mais au PLANCHER de la vitesse : 100 %.
## Un coup qui depasse ne descend pas sous le plancher, il tue.
func _test_la_mort_arrive_au_plancher() -> void:
	SpeedGauge.reset()
	# A peine au-dessus du plancher : le mage tient encore.
	SpeedGauge.set_speed_percent(100 + 10)
	SpeedGauge.take_hit(5)
	not_ok(SpeedGauge.is_dying, "au-dessus du plancher, le mage tient")
	ok(SpeedGauge.speed_percent > 100, "et sa vitesse est encore au-dessus de 100 %")

	# Le coup qui ramene PILE au plancher tue : a 100 % il n y a plus de reserve.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100 + 10)
	SpeedGauge.take_hit(10)
	eq(SpeedGauge.speed_percent, 100, "la vitesse s arrete au plancher")
	ok(SpeedGauge.is_dying, "et atteindre le plancher, c est mourir")

	# Un coup surdimensionne ne fait pas descendre sous 100 %.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(150)
	SpeedGauge.take_hit(GameConfig.SPEED_MAX_PERCENT * 10)
	eq(SpeedGauge.speed_percent, 100, "la vitesse ne descend jamais sous 100 %")
	ok(SpeedGauge.is_dying, "et le mage est mort")
	SpeedGauge.reset()


## L ancien systeme faisait DEUX choses a chaque coup : retirer des PV, ET
## faire retomber la vitesse de SPEED_DROP_ON_HIT. Avec la nouvelle regle, ce
## serait punir deux fois le meme coup. Le forfait est supprime : ce que le
## joueur perd, c est exactement les degats du monstre qui l a touche.
func _test_pas_de_chute_forfaitaire_en_plus_des_degats() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var avant: int = SpeedGauge.speed_percent
	# Un tout petit coup ne doit couter qu un point, pas un forfait de 60.
	SpeedGauge.take_hit(1)
	eq(SpeedGauge.speed_percent, avant - 1,
		"un coup de 1 coute 1 point, pas un forfait")
	SpeedGauge.reset()


## Rendre de la vie, c est rendre de la VITESSE — donc aussi de la puissance :
## l incantation raccourcit et l XP remonte. C est voulu, et c est ce qui rend
## le soin interessant au lieu d etre une simple rallonge.
func _test_le_soin_rend_de_la_vitesse() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(200)
	var cast_avant: float = SpeedGauge.effective_cast_time(4.0)
	SpeedGauge.heal(50)
	eq(SpeedGauge.speed_percent, 250, "un soin de 50 rend 50 points de vitesse")
	ok(SpeedGauge.effective_cast_time(4.0) < cast_avant,
		"et l incantation raccourcit : se soigner, c est aussi accelerer")

	# Le soin ne depasse pas le maximum.
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT - 5)
	SpeedGauge.heal(500)
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT,
		"un soin ne depasse pas le maximum de vitesse")

	# On ne ressuscite pas : pendant l agonie, le soin ne fait rien.
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(110)
	SpeedGauge.take_hit(10)
	ok(SpeedGauge.is_dying, "le mage agonise")
	SpeedGauge.heal(100)
	eq(SpeedGauge.speed_percent, 100, "un soin ne ressuscite pas")
	SpeedGauge.reset()


## La reserve totale du mage, exprimee en points : de 100 a SPEED_MAX_PERCENT.
## C est le nombre que l equilibrage lira pour caler les degats de contact.
func _test_reserve_totale_et_ratio() -> void:
	SpeedGauge.reset()
	eq(SpeedGauge.max_reserve(), GameConfig.SPEED_MAX_PERCENT - 100,
		"la reserve totale va du plancher au maximum")
	# Une partie NE COMMENCE PAS au plancher : a 100 % le mage serait deja mort.
	eq(SpeedGauge.reserve(), GameConfig.SPEED_START_PERCENT - 100,
		"au depart, la reserve vaut SPEED_START_PERCENT - 100")
	ok(SpeedGauge.reserve() > 0, "et elle n est jamais vide au premier tick")
	SpeedGauge.set_speed_percent(100)
	eq(SpeedGauge.reserve(), 0, "au plancher, la reserve est vide")
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	eq(SpeedGauge.reserve(), SpeedGauge.max_reserve(), "au maximum, elle est pleine")
	feq(SpeedGauge.speed_ratio(), 1.0, "et le ratio d affichage vaut 1")
	# Le ratio d affichage et la reserve disent la MEME chose : une seule barre.
	SpeedGauge.set_speed_percent(100 + SpeedGauge.max_reserve() / 2)
	between(SpeedGauge.speed_ratio(), 0.48, 0.52,
		"a mi-reserve, la barre est a moitie pleine")
	SpeedGauge.reset()


## L agonie ne change pas : le monde passe au ralenti quelques secondes avant
## la defaite. Elle garde tout son sens — on meurt PARCE QU ON EST LENT, et le
## ralenti est l image litterale de cette mort.
func _test_agonie_inchangee() -> void:
	SpeedGauge.reset()
	var ended: Array[int] = [0]
	var on_died := func() -> void: ended[0] += 1
	SpeedGauge.died.connect(on_died)

	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	SpeedGauge.take_hit(GameConfig.SPEED_MAX_PERCENT)
	ok(SpeedGauge.is_dying, "le mage agonise")
	feq(SpeedGauge.world_delta(1.0), GameConfig.DEATH_SLOWMO,
		"le monde passe au ralenti pendant l agonie")

	# Pendant l agonie, plus rien ne bouge la vitesse.
	SpeedGauge.take_hit(5)
	eq(SpeedGauge.speed_percent, 100, "take_hit est sans effet pendant l agonie")
	SpeedGauge.tick(1.0)
	eq(SpeedGauge.speed_percent, 100, "et la vitesse ne remonte pas non plus")

	# `died` est emis A CHAQUE tick une fois la jauge videe (comportement
	# historique, inchange : c est GameController qui arrete la partie au
	# premier). On verifie donc qu il part, et qu il part APRES le delai.
	#
	# Le temps restant se calcule sur la jauge COURANTE et non sur sa valeur
	# nominale : les verifications precedentes de ce test l ont deja entamee.
	var restant: float = SpeedGauge.death_gauge / GameConfig.DEATH_DRAIN_RATE
	var t: float = 0.0
	while t < restant - 0.3:
		SpeedGauge.tick(0.1)
		t += 0.1
	eq(ended[0], 0, "died n est pas emis avant la fin du drain")
	SpeedGauge.tick(0.5)
	ok(ended[0] >= 1, "died est emis une fois la jauge d agonie videe")

	SpeedGauge.died.disconnect(on_died)
	SpeedGauge.reset()
