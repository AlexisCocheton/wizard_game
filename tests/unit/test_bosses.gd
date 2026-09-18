extends TestCase
## Les trois mecaniques de BOSS. Un boss doit demander une reponse DIFFERENTE,
## pas seulement plus de sorts : ces tests verrouillent ce qui rend la reponse
## differente, et rien d autre.
##
##   1. morcele     -> il faut detruire les parties AVANT de pouvoir l entamer
##   2. tireur loin -> il ne descend pas jusqu au mage, il campe et harcele
##   3. invocateur  -> il fabrique des monstres tant qu il vit
##
## Ecrit AVANT le code : chaque assertion decrit une regle, pas une valeur
## d equilibrage (voir gotchas.md, « un test qui fige un REGLAGE bloque
## l equilibrage »).

func get_suite_name() -> String:
	return "bosses"

var _bf: Battlefield = null


func _def(id: String, hp: float = 100.0, speed: float = 60.0, power: int = 1) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	d.base_speed = speed
	d.power = power
	d.base_radius = 40.0
	return d


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	SpeedGauge.reset()
	RunState.reset()


func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(1.0 / 60.0)
		t += 1.0 / 60.0


func run() -> void:
	_test_morcele_les_parties_protegent_le_coeur()
	_test_morcele_chaque_partie_detruite_affaiblit()
	_test_morcele_sans_parties_se_comporte_normalement()
	_test_tireur_a_distance_s_arrete_a_sa_ligne()
	_test_tireur_a_distance_harcele_depuis_sa_ligne()
	_test_invocateur_fabrique_des_monstres()
	_test_invocateur_mort_cesse_d_invoquer()
	_test_invocateur_ne_noie_pas_l_ecran()
	_test_les_boss_livres_ont_bien_leurs_mecaniques()
	if _bf != null:
		detach(_bf)
		_bf = null


# --- 1. Boss en plusieurs morceaux -----------------------------------------

## La regle centrale : tant qu une partie tient, le coeur n encaisse rien. C est
## ce qui change la reponse du joueur — il doit VISER les parties, pas empiler
## les degats sur la masse centrale.
func _test_morcele_les_parties_protegent_le_coeur() -> void:
	_fresh()
	var d := _def("morcele", 100.0, 0.0, 10)
	d.parts_count = 3
	d.part_hp = 20.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))

	eq(boss.parts_left(), 3, "le boss entre avec ses trois parties")
	# Le coup PORTE (flash et son : le joueur voit qu il tape juste), mais il
	# entame la partie, pas le coeur.
	ok(boss.take_damage(15.0, []), "le coup porte sur la partie visee")
	feq(boss.hp, 100.0, "et le coeur reste intact")
	eq(boss.parts_left(), 3, "la partie visee tient encore")

	# Il restait 5 PV a la partie entamee : elle cede.
	boss.take_damage(20.0, [])
	eq(boss.parts_left(), 2, "une partie cede")
	feq(boss.hp, 100.0, "le coeur n a toujours rien pris")

	boss.take_damage(200.0, [])
	eq(boss.parts_left(), 1, "un coup enorme ne detruit QU UNE partie : pas de report")
	feq(boss.hp, 100.0, "le surplus est perdu, il ne coule pas sur le coeur")

	boss.take_damage(20.0, [])
	eq(boss.parts_left(), 0, "derniere partie detruite")
	feq(boss.hp, 100.0, "le coeur est encore intact a cet instant")

	ok(boss.take_damage(30.0, []), "parties tombees : le coeur devient enfin touchable")
	feq(boss.hp, 70.0, "et il encaisse normalement")


## Chaque partie detruite doit RECOMPENSER immediatement, sinon le joueur a
## l impression de taper dans le vide pendant la moitie du combat.
func _test_morcele_chaque_partie_detruite_affaiblit() -> void:
	_fresh()
	var d := _def("morcele2", 100.0, 60.0, 10)
	d.parts_count = 2
	d.part_hp = 10.0
	d.part_slow_pct = 25.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))

	var y0: float = boss.position.y
	boss.advance(1.0)
	var pleine_vitesse: float = boss.position.y - y0

	boss.take_damage(10.0, [])
	eq(boss.parts_left(), 1, "une partie de moins")
	var y1: float = boss.position.y
	boss.advance(1.0)
	var vitesse_reduite: float = boss.position.y - y1
	ok(vitesse_reduite < pleine_vitesse,
		"une partie detruite ralentit le boss : le joueur voit son travail")

	boss.take_damage(10.0, [])
	var y2: float = boss.position.y
	boss.advance(1.0)
	ok(boss.position.y - y2 < vitesse_reduite,
		"la seconde partie le ralentit encore")


## Un boss sans parties (Chronos, Gardien) ne doit rien changer a son comportement :
## le champ est facultatif, pas une refonte du modele de degats.
func _test_morcele_sans_parties_se_comporte_normalement() -> void:
	_fresh()
	var boss: Enemy = _bf.spawn_enemy(_def("simple", 50.0, 0.0, 10), 500.0, 1.0, Vector2(500.0, 500.0))
	eq(boss.parts_left(), 0, "aucune partie declaree")
	ok(boss.take_damage(10.0, []), "les degats passent directement")
	feq(boss.hp, 40.0, "PV entames des le premier coup")


# --- 2. Boss qui tire a distance -------------------------------------------

## Il ne descend PAS jusqu au mage : il s arrete a sa ligne de tir. Le joueur ne
## peut donc pas l ignorer en attendant le contact, ni compter sur sa propre
## ligne de defense — il faut aller le chercher.
func _test_tireur_a_distance_s_arrete_a_sa_ligne() -> void:
	_fresh()
	var d := _def("canonnier", 200.0, 120.0, 10)
	d.keeps_distance_at = 500.0
	d.shoot_interval = 1.0
	d.shot_damage = 1
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 100.0))

	_sim(20.0)
	var ligne: float = GameConfig.MAGE_LINE_Y - 500.0
	ok(boss.position.y <= ligne + 6.0, "il s arrete au plus loin a sa ligne de tir")
	ok(boss.position.y >= ligne - 40.0, "mais il y monte bien : il ne reste pas en haut")
	ok(absf(boss.position.y - ligne) < 20.0, "il se stabilise sur sa ligne, il n oscille pas")
	ok(not boss.is_dead(), "et il n a jamais atteint le mage")


## Une fois campe, il continue de harceler : la distance n est pas une pause.
func _test_tireur_a_distance_harcele_depuis_sa_ligne() -> void:
	_fresh()
	var d := _def("canonnier2", 200.0, 200.0, 10)
	d.keeps_distance_at = 400.0
	d.shoot_interval = 0.4
	d.shot_damage = 1
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	var pv0: int = SpeedGauge.hp
	SpeedGauge.set_speed_percent(100)
	_sim(12.0)
	ok(SpeedGauge.hp < pv0, "camper loin n empeche pas de faire mal")


# --- 3. Boss qui invoque ----------------------------------------------------

func _test_invocateur_fabrique_des_monstres() -> void:
	_fresh()
	var sbire := _def("sbire", 5.0, 40.0, 1)
	var d := _def("invocateur", 300.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 1.0
	d.summon_count = 2
	d.summon_max_alive = 99
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))

	eq(_bf.alive_count(), 1, "seul au depart")
	_sim(1.2)
	eq(_bf.alive_count(), 3, "une salve de deux sbires")
	_sim(1.1)
	eq(_bf.alive_count(), 5, "puis une deuxieme salve")


## Tuer l invocateur doit ARRETER le flux : c est toute la reponse que le boss
## demande (couper la source plutot que nettoyer les sbires).
func _test_invocateur_mort_cesse_d_invoquer() -> void:
	_fresh()
	var sbire := _def("sbire2", 5.0, 0.0, 1)
	var d := _def("invocateur2", 30.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 0.5
	d.summon_count = 1
	d.summon_max_alive = 99
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(1.1)
	var apres_deux_salves: int = _bf.alive_count()
	ok(apres_deux_salves >= 3, "le flux a commence")
	boss.take_damage(999.0, [])
	var restants: int = _bf.alive_count()
	_sim(3.0)
	eq(_bf.alive_count(), restants, "boss mort : plus aucune invocation")


## Le plafond existe pour que l invocation reste une PRESSION et non un
## ensevelissement : sans lui, un joueur qui traine perd par accumulation
## mecanique, ce qui n est plus une decision.
func _test_invocateur_ne_noie_pas_l_ecran() -> void:
	_fresh()
	var sbire := _def("sbire3", 5.0, 0.0, 1)
	var d := _def("invocateur3", 500.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 0.2
	d.summon_count = 2
	d.summon_max_alive = 4
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(8.0)
	ok(_bf.alive_count() <= 5, "le plafond tient : 4 sbires + le boss au plus")
	ok(_bf.alive_count() >= 3, "mais il invoque quand meme")


# --- Le contenu livre --------------------------------------------------------

## Les trois mecaniques doivent exister DANS LE JEU, pas seulement dans le
## moteur : un champ implemente que personne n utilise est du code mort.
func _test_les_boss_livres_ont_bien_leurs_mecaniques() -> void:
	var morcele: int = 0
	var distant: int = 0
	var invocateur: int = 0
	for def: EnemyDef in ContentDB.enemies.values():
		if not def.is_boss():
			continue
		if def.parts_count > 0:
			morcele += 1
			ok(def.part_hp > 0.0, "%s : des parties sans PV seraient increvables" % def.id)
		if def.keeps_distance_at > 0.0:
			distant += 1
			ok(def.shoot_interval > 0.0,
				"%s : camper loin sans tirer ne serait qu une absence" % def.id)
		if def.summon_interval > 0.0:
			invocateur += 1
			ok(def.summon_def != null, "%s : invoque du vide" % def.id)
			ok(def.summon_max_alive > 0, "%s : invocation sans plafond" % def.id)
			ok(def.summon_def.power < def.power,
				"%s : un boss invoque des sbires, pas ses egaux" % def.id)
	ok(morcele >= 1, "au moins un boss en plusieurs morceaux est livre")
	ok(distant >= 1, "au moins un boss qui campe et harcele est livre")
	ok(invocateur >= 1, "au moins un boss qui invoque est livre")
