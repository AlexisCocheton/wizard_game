extends TestCase
## LES MECANIQUES DES TETES DE LA VAGUE 10 (chantier B2) : chacune se DECLENCHE,
## fait ce que dit sa fiche, et a une FIN.
##
##   1. L ECHEANCE (Chronos) : il se plante, un COUP l honore et l etourdit,
##      sinon le mage perd de la vitesse ; un degat continu ne compte pas ; la
##      fenetre se referme toujours ; etourdi, il n en rouvre pas. Sa version
##      simple (l Echo) s accelere au lieu de punir, et l acceleration retombe.
##   2. L ARMURE QUI SE REFERME (le Gardien) : le bouclier revient apres le calme,
##      jamais sous les coups ; sans le champ, il ne revient pas.
##   3. LA GARDE LEVEE (le Gardien d ossements) : les COUPS glissent pendant la
##      garde, le continu passe en entier, rien n est renvoye, la garde retombe.
##   4. Les poses enfin jouees : `cast` en repli de l attaque, `shield` a la parade.
##   5. Le CONTENU : les cinq tetes sans mecanique en ont une, et leur fiche la dit.
##
## Les monstres des regles 1 a 4 sont construits ici : un reglage d equilibrage
## du contenu ne fait rougir aucune regle.

func get_suite_name() -> String:
	return "tetes_w10"


const DT: float = 1.0 / 60.0
const DEPART := Vector2(540.0, 500.0)

var _bf: Battlefield = null
var _coups_mage: Array = []


func run() -> void:
	_test_l_echeance_se_plante_et_punit()
	_test_un_coup_honore_l_echeance()
	_test_le_continu_n_honore_pas()
	_test_etourdi_il_ne_rouvre_pas_d_echeance()
	_test_l_echo_s_accelere_puis_ralentit()
	_test_l_armure_se_referme_au_calme()
	_test_l_armure_ne_revient_pas_sous_les_coups()
	_test_sans_champ_le_bouclier_ne_revient_pas()
	_test_la_garde_levee_amortit_les_coups()
	_test_la_garde_retombe()
	_test_les_poses_de_feuille()
	_test_les_tetes_livrees_ont_leur_mecanique()
	if _bf != null:
		detach(_bf)
		_bf = null


# --- Outils ---

func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()
	_coups_mage.clear()
	_bf.mage_hit.connect(func(dmg: int, source: EnemyDef) -> void:
		_coups_mage.append([dmg, source]))


func _base(id: String) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.kind = GameEnums.EnemyKind.BOSS
	d.max_hp = 99999.0
	d.base_speed = 0.0
	d.base_radius = 40.0
	return d


func _huissier(penalite: int = 6, hate: float = 0.0) -> EnemyDef:
	var d := _base("test_huissier")
	d.base_speed = 40.0
	d.deadline_interval = 3.0
	d.deadline_window = 1.5
	d.deadline_stun = 1.0
	d.deadline_penalty = penalite
	d.deadline_haste_pct = hate
	d.deadline_haste_time = 2.0
	return d


## Simule `seconds` de MONDE a x1. La jauge est remise a 300 % a chaque image
## (assez pour encaisser une penalite, le monde reste a x1 parce que le test ne
## lit que le temps de monde du terrain : world_delta suit la jauge, on la
## remet donc a 100 % pendant l avance et on la lit entre deux images).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		SpeedGauge.set_speed_percent(100)
		_bf.simulate(DT)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		t += DT


func _hit(e: Enemy, amount: float, continu: bool = false) -> void:
	_bf._hit(e, amount, [GameEnums.DamageTag.ARCANE], continu)


# --- 1. L echeance ---

func _test_l_echeance_se_plante_et_punit() -> void:
	_fresh()
	var d := _huissier(6)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + d.deadline_interval * 0.5)
	not_ok(e.deadline_open(), "avant son intervalle, aucune echeance")
	_sim(d.deadline_interval * 0.5 + DT * 3.0)
	ok(e.deadline_open(), "l intervalle passe, la fenetre s ouvre")
	ok(e.mech_caption().contains("ECHEANCE"), "la legende dit l echeance")
	var y0: float = e.position.y
	_sim(d.deadline_window * 0.5)
	feq(e.position.y, y0, "pendant la fenetre, il est PLANTE", 0.5)
	_sim(d.deadline_window * 0.5 + DT * 3.0)
	not_ok(e.deadline_open(), "GARANTIE DE FIN : la fenetre se referme d elle-meme")
	eq(e.b2_deadlines_missed, 1, "sans coup, l echeance est manquee")
	eq(_bf.b2_deadlines_missed, 1, "le terrain fait payer le mage une fois")
	ok(_coups_mage.size() == 1 and int(_coups_mage[0][0]) == d.deadline_penalty,
		"le mage perd exactement la penalite (%s)" % str(_coups_mage))
	ok(_coups_mage.size() == 1 and _coups_mage[0][1] == d,
		"la perte est imputee a l huissier (objectifs « ne pas etre touche par »)")
	_sim(d.deadline_window)
	ok(e.position.y > y0 + 1.0, "la fenetre refermee, il repart")


func _test_un_coup_honore_l_echeance() -> void:
	_fresh()
	var d := _huissier(6)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + d.deadline_interval + DT * 3.0)
	ok(e.deadline_open(), "la fenetre est ouverte")
	_hit(e, 5.0)
	not_ok(e.deadline_open(), "un COUP pendant la fenetre la referme")
	eq(e.b2_deadlines_met, 1, "l echeance est honoree")
	ok(e.is_stunned(), "honoree, il reste etourdi")
	_sim(d.deadline_window + DT * 6.0)
	eq(_coups_mage.size(), 0, "honoree, le mage ne perd rien")
	eq(e.b2_deadlines_missed, 0, "et rien n est compte comme manque")
	_sim(d.deadline_stun)
	not_ok(e.is_stunned(), "GARANTIE DE FIN : l etourdissement retombe")


func _test_le_continu_n_honore_pas() -> void:
	_fresh()
	var d := _huissier(6)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + d.deadline_interval + DT * 3.0)
	ok(e.deadline_open(), "la fenetre est ouverte")
	var t: float = 0.0
	while t < d.deadline_window * 0.6:
		_hit(e, 0.2, true)
		_sim(DT)
		t += DT
	ok(e.deadline_open(), "une zone ou un poison (degat continu) ne l honorent pas")
	eq(e.b2_deadlines_met, 0, "aucune echeance honoree par le continu")


func _test_etourdi_il_ne_rouvre_pas_d_echeance() -> void:
	_fresh()
	var d := _huissier(6)
	d.max_hp = 99999.0
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME)
	# Etourdi plus longtemps que son intervalle : le minuteur attend.
	e._stun_time = d.deadline_interval * 2.0
	_sim(d.deadline_interval * 1.5)
	not_ok(e.deadline_open(), "etourdi, il n ouvre pas d echeance")
	eq(_coups_mage.size(), 0, "et le mage ne paie rien pendant l etourdissement")


func _test_l_echo_s_accelere_puis_ralentit() -> void:
	_fresh()
	var d := _huissier(0, 40.0)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + d.deadline_interval + d.deadline_window + DT * 6.0)
	eq(e.b2_deadlines_missed, 1, "l echeance de l Echo est manquee")
	eq(_coups_mage.size(), 0, "l Echo ne punit pas le mage")
	feq(e._b2_speed_factor(), 1.4, "manquee, il accelere de 40 %")
	_sim(d.deadline_haste_time + DT * 3.0)
	feq(e._b2_speed_factor(), 1.0, "GARANTIE DE FIN : l acceleration retombe")


# --- 2. L armure qui se referme ---

func _gardien(regen: float) -> EnemyDef:
	var d := _base("test_gardien")
	d.first_hit_shield = true
	d.shield_regen = regen
	return d


func _test_l_armure_se_referme_au_calme() -> void:
	_fresh()
	var d := _gardien(2.0)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + DT)
	ok(e.has_shield(), "il entre avec son bouclier")
	var pv0: float = e.hp
	_hit(e, 50.0)
	not_ok(e.has_shield(), "le premier coup brise le bouclier")
	feq(e.hp, pv0, "et ne fait aucun degat")
	_sim(d.shield_regen * 0.5)
	not_ok(e.has_shield(), "avant son delai, l armure reste ouverte")
	_hit(e, 10.0)
	ok(e.hp < pv0, "ouverte, les coups portent")
	_sim(d.shield_regen + DT * 3.0)
	ok(e.has_shield(), "apres le calme, l armure se REFERME")
	eq(e.b2_shield_regens, 1, "un retour compte")
	var pv1: float = e.hp
	_hit(e, 50.0)
	feq(e.hp, pv1, "refermee, elle absorbe de nouveau un coup")


func _test_l_armure_ne_revient_pas_sous_les_coups() -> void:
	_fresh()
	var d := _gardien(1.0)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + DT)
	_hit(e, 50.0)
	var t: float = 0.0
	while t < d.shield_regen * 4.0:
		_hit(e, 0.1, true)  # une zone qui ronge sans arret
		_sim(DT)
		t += DT
	not_ok(e.has_shield(), "frappe sans arret (meme en continu), il ne recupere rien")
	eq(e.b2_shield_regens, 0, "aucun retour sous les coups")


func _test_sans_champ_le_bouclier_ne_revient_pas() -> void:
	_fresh()
	var d := _gardien(0.0)
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + DT)
	_hit(e, 50.0)
	_sim(10.0)
	not_ok(e.has_shield(), "sans shield_regen, le bouclier ne sert qu une fois")


# --- 3. La garde levee ---

func _ossements() -> EnemyDef:
	var d := _base("test_ossements")
	d.reflect_interval = 3.0
	d.reflect_window = 1.0
	d.reflect_pct = 0.0
	d.guard_block_pct = 80.0
	return d


func _test_la_garde_levee_amortit_les_coups() -> void:
	_fresh()
	var d := _ossements()
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + DT)
	not_ok(e.guard_up(), "il entre garde baissee")
	var pv: float = e.hp
	_hit(e, 10.0)
	feq(pv - e.hp, 10.0, "garde baissee, un coup porte en entier", 0.01)
	_sim(d.reflect_interval + DT * 3.0)
	ok(e.guard_up(), "l intervalle passe, la garde se leve")
	ok(e.mech_caption().contains("GARDE"), "la legende dit la garde")
	pv = e.hp
	_hit(e, 10.0)
	feq(pv - e.hp, 2.0, "garde levee, un COUP ne fait que 20 %", 0.01)
	pv = e.hp
	_hit(e, 10.0, true)
	feq(pv - e.hp, 10.0, "le degat continu passe en entier", 0.01)
	eq(_coups_mage.size(), 0, "la garde levee ne renvoie RIEN au mage")


func _test_la_garde_retombe() -> void:
	_fresh()
	var d := _ossements()
	var e: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(GameConfig.SPAWN_FADE_TIME + d.reflect_interval + DT * 3.0)
	ok(e.guard_up(), "garde levee")
	_sim(d.reflect_window + DT * 3.0)
	not_ok(e.guard_up(), "GARANTIE DE FIN : la garde retombe a la fin de sa fenetre")


# --- 4. Les poses ---

func _test_les_poses_de_feuille() -> void:
	eq(Enemy.attack_pose(&"monk_black"), "cast",
		"une feuille de moine (Pretre goule) joue son incantation en guise d attaque")
	eq(Enemy.attack_pose(&"skeleton2"), "attack", "une feuille qui a une attaque la garde")
	eq(Enemy.shield_pose(&"skeleton2"), "shield",
		"le Squelette pareur joue sa pose de bouclier a la parade")
	eq(Enemy.shield_pose(&"lancer_purple"), "guard",
		"le Chevalier du vide leve sa garde quand son bouclier tient")
	eq(Enemy.shield_pose(&"pawn_red"), "", "une feuille sans parade n en joue aucune")


# --- 5. Le contenu ---

## Les cinq tetes livrees SANS mecanique (revue A4, §1.2) en ont une, et leur
## fiche la dit avec ses chiffres.
func _test_les_tetes_livrees_ont_leur_mecanique() -> void:
	var chronos: EnemyDef = ContentDB.enemies.get(&"chronos")
	var gardien: EnemyDef = ContentDB.enemies.get(&"warden")
	var ossements: EnemyDef = ContentDB.enemies.get(&"bonewarden")
	var braise: EnemyDef = ContentDB.enemies.get(&"emberlord")
	var totem: EnemyDef = ContentDB.enemies.get(&"totem_elder")
	for d in [chronos, gardien, ossements, braise, totem]:
		ok(d != null, "la tete existe")
	if chronos == null or gardien == null or ossements == null or braise == null or totem == null:
		return
	ok(chronos.has_deadline() and chronos.deadline_penalty > 0, "Chronos tient ses echeances")
	ok(_fiche(chronos).contains("ECHEANCE"), "la fiche de Chronos dit l echeance")
	ok(gardien.first_hit_shield and gardien.shield_regen > 0.0,
		"l armure du Gardien se referme")
	ok(_fiche(gardien).contains("REFERME"), "sa fiche le dit")
	ok(ossements.guard_block_pct > 0.0 and ossements.has_guard_cycle()
		and ossements.reflect_pct <= 0.0, "le Gardien d ossements leve sa garde, sans renvoi")
	ok(ossements.reflect_window < ossements.reflect_interval,
		"sa garde retombe avant la suivante")
	ok(_fiche(ossements).contains("garde"), "sa fiche dit la garde")
	ok(braise.laser_damage > 0, "le Seigneur de braise riposte a chaque coup")
	ok(totem.aura_shield_radius > 0.0, "le Totem ancien protege (aura ancienne)")
	var echo: EnemyDef = ContentDB.enemies.get(&"chronos_echo")
	ok(echo != null and echo.has_deadline() and echo.deadline_penalty == 0
		and echo.deadline_haste_pct > 0.0,
		"l Echo de Chronos garde une echeance SIMPLIFIEE : il s accelere, il ne punit pas")


func _fiche(d: EnemyDef) -> String:
	return "\n".join(BestiaryLore.behaviours(d))
