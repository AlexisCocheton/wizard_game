extends TestCase
## LE BRISEUR DE TERRAIN, les poses de feuille jouees, et les anciens boss promus
## en vermine (chantier W3).
##
## Les regles verifiees ici, dans l ordre ou elles cassent une partie :
##   1. il brise l objet le plus PROCHE a sa portee, et seulement APRES son geste ;
##   2. pendant son geste il est plante — c est ce qui rend le geste lisible ;
##   3. le tuer ou l etourdir pendant le geste SAUVE l objet ;
##   4. l eau (nappe, Riviere) ne se brise pas ;
##   5. il brise aussi les murs, et la grille de navigation est rendue ;
##   6. le monstre livre a quelque chose a briser : il mene un palier dans un
##      niveau dont le deck pose du terrain, et le Massacre le tire vraiment ;
##   7. le renard JOUE sa pose de sommeil, le golem a noyau sa pose de laser.
##
## Les monstres des regles 1 a 5 sont construits ici : un reglage du contenu ne
## doit pas faire rougir une regle. Aucune valeur d equilibrage n est figee, tout
## se lit dans la definition construite.

func get_suite_name() -> String:
	return "briseur"


const DT: float = 1.0 / 60.0
## Point de depart du Briseur dans les tests : au milieu du terrain, assez haut
## pour qu un objet pose devant lui reste dans les bornes de `spawn_prop`.
const DEPART := Vector2(540.0, 500.0)

var _bf: Battlefield = null


func run() -> void:
	_test_brise_le_plus_proche_apres_son_geste()
	_test_plante_pendant_son_geste()
	_test_hors_de_portee_rien_ne_tombe()
	_test_l_eau_est_epargnee()
	_test_le_tuer_pendant_le_geste_sauve_l_objet()
	_test_l_etourdir_lui_fait_perdre_son_geste()
	_test_une_cible_partie_pendant_le_geste()
	_test_il_brise_aussi_les_murs()
	_test_sa_legende_dit_ce_qui_va_tomber()
	_test_la_fiche_du_bestiaire_le_dit()
	_test_le_briseur_livre_a_du_terrain_a_briser()
	_test_le_renard_joue_sa_pose_de_sommeil()
	_test_le_golem_joue_sa_pose_de_laser()
	_test_le_choix_des_poses_suit_la_feuille()
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


func _briseur(speed: float = 0.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"test_briseur"
	d.display_name = "Briseur"
	d.kind = GameEnums.EnemyKind.MINIBOSS
	d.max_hp = 99999.0
	d.base_speed = speed
	d.base_radius = 40.0
	d.terrain_break_interval = 3.0
	d.terrain_break_reach = 400.0
	d.terrain_break_windup = 1.0
	return d


## Simule `seconds` de MONDE a x1 en gardant le mage en vie (voir test_bosses).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(DT)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
		t += DT


## Duree reelle du geste et de l intervalle, planchers du moteur compris.
func _geste(d: EnemyDef) -> float:
	return maxf(d.terrain_break_windup, Enemy.BREAK_MIN_WINDUP)


func _periode(d: EnemyDef) -> float:
	return Enemy._brk_period(d)


func _arbre(at: Vector2) -> TerrainProp:
	# Sans provocation : un Briseur attire marcherait vers l arbre, et le test
	# mesurerait sa marche au lieu de son geste.
	return _bf.spawn_prop(TerrainProp.Kind.TREE, at, 0.0, 100.0, 0.0)


func _vivant(p: TerrainProp) -> bool:
	return p != null and _bf.props.has(p)


# --- 1. Le coup ---

func _test_brise_le_plus_proche_apres_son_geste() -> void:
	_fresh()
	var d := _briseur()
	var pres: TerrainProp = _arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.4))
	var loin: TerrainProp = _bf.spawn_prop(TerrainProp.Kind.BRAMBLE,
		DEPART + Vector2(0.0, d.terrain_break_reach * 0.8), 0.0, 0.0)
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) * 0.9)
	not_ok(b.is_breaking(), "avant son intervalle, il ne prepare rien")
	_sim(_periode(d) * 0.1 + DT * 3.0)
	ok(b.is_breaking(), "l intervalle passe, il prepare son coup")
	ok(b.break_target() == pres.anchor, "il vise l objet le PLUS PROCHE")
	ok(_vivant(pres), "pendant le geste, l objet tient encore")
	_sim(_geste(d) + DT * 2.0)
	not_ok(_vivant(pres), "le geste fini, l objet vise est brise")
	ok(_vivant(loin), "l objet plus lointain tient toujours")
	eq(b.terrain_broken(), 1, "le Briseur compte UN objet brise")
	eq(_bf.terrain_broken, 1, "le terrain aussi")
	not_ok(b.is_breaking(), "et il n est plus en geste")


func _test_plante_pendant_son_geste() -> void:
	_fresh()
	var d := _briseur(60.0)
	# L objet est pose loin devant : a 60 px/s le Briseur ne l atteint pas avant
	# son intervalle, donc on mesure bien l arret du GESTE et pas un contact.
	_arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.9))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	var t: float = 0.0
	while not b.is_breaking() and t < _periode(d) * 2.0:
		_sim(DT)
		t += DT
	ok(b.is_breaking(), "il finit par preparer son coup")
	ok(b.position.y > DEPART.y, "il avancait avant son geste")
	var y: float = b.position.y
	_sim(_geste(d) * 0.8)
	feq(b.position.y, y, "pendant son geste il est PLANTE", 0.01)
	_sim(_geste(d) * 0.2 + DT * 3.0)
	_sim(0.5)
	ok(b.position.y > y, "le coup parti, il se remet en marche")


func _test_hors_de_portee_rien_ne_tombe() -> void:
	_fresh()
	var d := _briseur()
	var loin: TerrainProp = _arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 1.5))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) * 3.0)
	ok(_vivant(loin), "hors de sa portee, l objet tient")
	not_ok(b.is_breaking(), "et il ne prepare rien dans le vide")
	eq(b.terrain_broken(), 0, "aucun objet brise")


## L eau ne se brise pas : c est une decision (voir Battlefield.BREAKER_SPARED_KINDS),
## et le test mord si quelqu un retire la nappe ou la Riviere de la liste.
func _test_l_eau_est_epargnee() -> void:
	_fresh()
	var d := _briseur()
	var riviere: TerrainProp = _bf.spawn_river(DEPART.y + d.terrain_break_reach * 0.5)
	var nappe: TerrainProp = _bf.spawn_prop(TerrainProp.Kind.WATER,
		DEPART + Vector2(120.0, d.terrain_break_reach * 0.3), 30.0, 0.0, 0.0, 60.0, 150.0)
	ok(riviere != null and nappe != null, "la riviere et la nappe sont posees")
	var bloquees: int = _bf.nav.blocked_count()
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) * 3.0)
	ok(_vivant(riviere), "la Riviere n est pas brisee")
	ok(_vivant(nappe), "la nappe d eau non plus")
	eq(_bf.nav.blocked_count(), bloquees, "la riviere bloque toujours autant de cases")
	eq(b.terrain_broken(), 0, "le Briseur n a rien brise")


# --- 2. Les reponses du joueur ---

func _test_le_tuer_pendant_le_geste_sauve_l_objet() -> void:
	_fresh()
	var d := _briseur()
	d.max_hp = 50.0
	var arbre: TerrainProp = _arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.4))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) + DT * 3.0)
	ok(b.is_breaking(), "il prepare son coup")
	_bf._hit(b, 99999.0, [])
	ok(b.is_dead(), "il meurt pendant son geste")
	_sim(_geste(d) + 0.5)
	ok(_vivant(arbre), "tue pendant son geste, il ne brise RIEN")
	eq(_bf.terrain_broken, 0, "aucun objet brise sur le terrain")
	ok(arbre.anchor != null and arbre.anchor.get_node_or_null("BreakMark") == null,
		"et sa marque ne reste pas sur l arbre")


## L etourdissement annule le geste ET coute un intervalle complet : sinon le stun
## ne ferait que decaler le coup d une fraction de seconde.
func _test_l_etourdir_lui_fait_perdre_son_geste() -> void:
	_fresh()
	var d := _briseur()
	var arbre: TerrainProp = _arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.4))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) + DT * 3.0)
	ok(b.is_breaking(), "il prepare son coup")
	var stun: float = _geste(d) * 0.5
	ok(b.apply_stun(stun), "l etourdissement prend")
	not_ok(b.is_breaking(), "etourdi, il perd son geste")
	_sim(stun + _geste(d) + DT * 3.0)
	ok(_vivant(arbre), "l arbre a survecu au geste interrompu")
	_sim(_periode(d) * 0.5)
	ok(_vivant(arbre), "il repart d un intervalle PLEIN, pas du geste perdu")
	_sim(_periode(d) * 0.5 + _geste(d) + DT * 6.0)
	not_ok(_vivant(arbre), "l intervalle suivant, il frappe : ce n est qu un sursis")


func _test_une_cible_partie_pendant_le_geste() -> void:
	_fresh()
	var d := _briseur()
	var arbre: TerrainProp = _arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.4))
	var autre: TerrainProp = _arbre(DEPART + Vector2(200.0, d.terrain_break_reach * 0.6))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) + DT * 3.0)
	# L ancre est retenue AVANT le retrait : `_destroy_prop` remet `arbre.anchor` a
	# null, et comparer a null serait vrai pour un Briseur qui ne vise plus rien.
	var ancre: Node = arbre.anchor
	ok(ancre != null and b.break_target() == ancre, "il vise le premier arbre")
	_bf.destroy_terrain(arbre)
	_sim(DT * 2.0)
	not_ok(b.is_breaking(), "l arbre parti, il cesse son geste")
	not_ok(b.break_target() == ancre, "et ne vise plus l ancre partie")
	_sim(Enemy.BREAK_RETRY + _geste(d) + DT * 6.0)
	not_ok(_vivant(autre), "et il se rabat vite sur l objet suivant, sans attendre un intervalle")


# --- 3. Les murs ---

func _test_il_brise_aussi_les_murs() -> void:
	_fresh()
	var d := _briseur()
	_bf.spawn_breakable_wall(DEPART + Vector2(0.0, d.terrain_break_reach * 0.5), 150.0, 60.0,
		99999.0)
	eq(_bf.wall_count(), 1, "le mur est pose")
	ok(_bf.nav.blocked_count() > 0, "et il bloque la grille")
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	_sim(_periode(d) + _geste(d) + DT * 6.0)
	eq(_bf.wall_count(), 0, "un mur aux PV enormes tombe quand meme sous son geste")
	eq(_bf.nav.blocked_count(), 0, "la grille est rendue")
	eq(b.terrain_broken(), 1, "c est bien lui qui l a brise")


# --- 4. Ce que le joueur lit ---

func _test_sa_legende_dit_ce_qui_va_tomber() -> void:
	_fresh()
	var d := _briseur()
	_arbre(DEPART + Vector2(0.0, d.terrain_break_reach * 0.4))
	var b: Enemy = _bf.spawn_enemy(d, DEPART.x, 1.0, DEPART)
	eq(b.mech_caption(), "", "au repos, aucune legende")
	_sim(_periode(d) + DT * 3.0)
	var txt: String = b.mech_caption()
	ok(txt.find("BRISE") >= 0, "pendant le geste, la legende dit BRISE (%s)" % txt)
	ok(txt.find(TerrainProp.kind_label(TerrainProp.Kind.TREE).to_upper()) >= 0,
		"et nomme ce qui va tomber (%s)" % txt)


func _test_la_fiche_du_bestiaire_le_dit() -> void:
	var d := _briseur()
	var lignes: Array[String] = BestiaryLore.behaviours(d)
	var trouve: bool = false
	for l in lignes:
		if l.find("Brise vos objets de terrain") >= 0 and l.find("Riviere") >= 0:
			trouve = true
	ok(trouve, "la fiche dit la regle, la reponse et l exception de l eau")


# --- 5. Le contenu livre ---

## Cles d effet qui posent un objet que le Briseur PEUT briser. L eau (nappe,
## Riviere) n y est pas : un niveau dont le deck ne pose que de l eau ne montrerait
## jamais sa mecanique.
const CLES_BRISABLES: Array[StringName] = [&"taunt_prop", &"place_terrain", &"build_wall"]


func _deck_pose_du_terrain(lv: LevelDef) -> bool:
	for c: SpellCard in lv.exploration_deck:
		if c == null:
			continue
		for fx: EffectSpec in c.effects:
			if fx != null and fx.key in CLES_BRISABLES:
				return true
	return false


func _test_le_briseur_livre_a_du_terrain_a_briser() -> void:
	var briseurs: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.terrain_break_interval > 0.0:
			briseurs.append(d)
	ok(not briseurs.is_empty(), "le contenu livre un Briseur de terrain")
	var membership: Dictionary = WaveSpawner.build_membership()
	var pool: Array[EnemyDef] = []
	var tetes: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile:
			continue
		if d.is_boss():
			tetes.append(d)
		else:
			pool.append(d)
	for br in briseurs:
		ok(br.is_boss(), "%s est une tete (boss ou mini-boss)" % br.id)
		# Il MENE un palier dans un niveau dont le deck pose du terrain brisable.
		var ou: StringName = &""
		for lv: LevelDef in ContentDB.levels.values():
			if not _deck_pose_du_terrain(lv):
				continue
			for w: WaveDef in lv.waves:
				if w != null and (w.is_boss or w.is_miniboss) and not w.entries.is_empty() \
						and w.entries[0] != null and w.entries[0].enemy == br:
					ou = lv.id
		ok(ou != &"", ("%s ne mene aucun palier d un niveau dont le deck pose du terrain :"
			+ " sa mecanique ne se verra jamais") % br.id)
		# Le Massacre le connait et le tire.
		ok(membership.has(br.id), "%s est rattache a un monde" % br.id)
		var sorti: bool = false
		var rng := RandomNumberGenerator.new()
		for graine in 64:
			rng.seed = 2709 + graine
			for n in range(1, 31):
				var w: WaveDef = WaveBudget.build_wave(n, pool, rng, tetes, membership)
				if w != null and not w.entries.is_empty() and w.entries[0] != null \
						and w.entries[0].enemy == br:
					sorti = true
			if sorti:
				break
		ok(sorti, "%s mene reellement un palier de Massacre" % br.id)
		# Etourdissable : c est l une des deux reponses a son geste.
		ok(br.resistance_to(GameEnums.DamageTag.SLOW) > Enemy.STUN_RESIST_THRESHOLD,
			"%s peut etre etourdi pendant son geste" % br.id)


# --- 6. Les poses de feuille ---

func _anim_de(e: Enemy) -> AnimatedSprite2D:
	return e.get_node_or_null("Anim") as AnimatedSprite2D


func _test_le_renard_joue_sa_pose_de_sommeil() -> void:
	_fresh()
	ok(AnimCatalog.has_anim(&"fox", "sleep"), "la feuille du renard porte une pose de sommeil")
	var d := EnemyDef.new()
	d.id = &"test_renard"
	d.max_hp = 999.0
	d.base_speed = 0.0
	d.base_radius = 22.0
	d.anim_key = &"fox"
	d.sleep_interval = 1.0
	d.sleep_duration = 1.5
	var r: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	var a: AnimatedSprite2D = _anim_de(r)
	ok(a != null and a.sprite_frames != null, "le renard a son sprite anime")
	if a == null or a.sprite_frames == null:
		return
	_sim(d.sleep_interval + DT * 3.0)
	ok(r.is_sleeping(), "il dort")
	eq(String(a.animation), "sleep", "endormi, il JOUE sa pose de sommeil")
	ok(a.is_playing(), "et la pose tourne, elle n est pas figee")
	# Frappe pendant son sommeil : la pose de coup, puis il se RENDORT a l ecran.
	r.take_damage(1.0, [])
	a.animation_finished.emit()
	eq(String(a.animation), "sleep", "frappe en dormant, il se rendort a l ecran")
	_sim(minf(d.sleep_duration, Enemy.SLEEP_MAX_DURATION) + DT * 3.0)
	not_ok(r.is_sleeping(), "il se reveille")
	eq(String(a.animation), Enemy.resting_anim(&"fox"), "reveille, il reprend sa pose de repos")


func _test_le_golem_joue_sa_pose_de_laser() -> void:
	_fresh()
	ok(AnimCatalog.has_anim(&"mechagolem", "laser"), "la feuille du golem porte une pose de laser")
	var d := EnemyDef.new()
	d.id = &"test_golem"
	d.max_hp = 9999.0
	d.base_speed = 0.0
	d.base_radius = 40.0
	d.anim_key = &"mechagolem"
	d.laser_damage = 1
	d.laser_cooldown = 1.0
	var g: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	var a: AnimatedSprite2D = _anim_de(g)
	ok(a != null and a.sprite_frames != null, "le golem a son sprite anime")
	if a == null or a.sprite_frames == null:
		return
	var tirs: int = _bf.lasers_fired
	_bf._hit(g, 1.0, [])
	eq(_bf.lasers_fired, tirs + 1, "le coup declenche le laser")
	eq(String(a.animation), "laser", "au tir de son laser, il JOUE sa pose de laser")
	a.animation_finished.emit()
	eq(String(a.animation), Enemy.resting_anim(&"mechagolem"), "puis il revient a sa pose de repos")


## La regle est GENERIQUE : toute feuille qui porte ces poses les joue. Lue sur tout
## le catalogue, pas sur deux ids.
func _test_le_choix_des_poses_suit_la_feuille() -> void:
	var laser_vu: bool = false
	var sommeil_vu: bool = false
	for k in AnimCatalog.keys():
		var key := StringName(k)
		if AnimCatalog.has_anim(key, "laser"):
			laser_vu = true
			eq(Enemy.shot_anim(key, true), "laser", "%s : le laser joue `laser`" % key)
		elif AnimCatalog.has_anim(key, "shoot"):
			eq(Enemy.shot_anim(key, true), "shoot", "%s : faute de `laser`, `shoot`" % key)
		if AnimCatalog.has_anim(key, "shoot"):
			eq(Enemy.shot_anim(key, false), "shoot", "%s : un tir ordinaire joue `shoot`" % key)
		elif AnimCatalog.has_anim(key, "attack"):
			eq(Enemy.shot_anim(key, false), "attack", "%s : faute de `shoot`, l attaque" % key)
		if AnimCatalog.has_anim(key, "sleep"):
			sommeil_vu = true
			eq(Enemy.sleep_anim(key), "sleep", "%s : le sommeil joue `sleep`" % key)
		else:
			eq(Enemy.sleep_anim(key), "", "%s : sans pose de sommeil, on fige" % key)
	ok(laser_vu and sommeil_vu, "le catalogue porte au moins une pose de laser et une de sommeil")
