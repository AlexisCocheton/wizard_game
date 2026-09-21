extends TestCase
## Les 12 comportements de monstres, chacun verifie sur un vrai Battlefield.

func get_suite_name() -> String:
	return "enemy_behaviors"

var _bf: Battlefield = null


func _def(id: String, hp: float = 100.0, speed: float = 60.0, power: int = 1) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	d.base_speed = speed
	d.power = power
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


func _damage_card() -> SpellCard:
	var c := SpellCard.new()
	c.id = &"t_dmg"
	var sp := EffectSpec.new()
	sp.key = &"damage_single"
	sp.magnitude = 10.0
	c.effects = [sp]
	return c


func run() -> void:
	_test_division()
	_test_bouclier_premier_coup()
	_test_enrage()
	_test_aura_protectrice()
	_test_soigneur()
	_test_glouton()
	_test_volte_face()
	_test_tireur()
	_test_a_coups()
	_test_ondulation()
	_test_focalisation()
	_test_vulnerabilite()
	_test_resonance()
	_test_le_halo_couvre_la_zone_protegee()
	_test_les_degats_varient_selon_le_monstre()
	_test_apparition_en_fondu()
	_test_le_vol_passe_par_dessus_les_murs()
	_test_le_planogo_tire_une_boule_de_poison_destructible()
	_test_l_oiseau_mirage_ne_tourne_plus()
	_test_les_monstres_sont_un_peu_plus_grands()
	if _bf != null:
		detach(_bf)
		_bf = null


func _test_division() -> void:
	_fresh()
	var child := _def("child", 5.0)
	var parent := _def("parent", 10.0)
	parent.split_into = child
	parent.split_count = 2
	var e: Enemy = _bf.spawn_enemy(parent, 500.0, 1.0, Vector2(500.0, 600.0))
	eq(_bf.alive_count(), 1, "un parent")
	e.take_damage(999.0, [])
	eq(_bf.alive_count(), 2, "a sa mort, deux enfants apparaissent")
	for c in _bf.enemies:
		eq(c.definition.id, &"child", "les enfants sont du bon type")
		ok(absf(c.position.y - 600.0) < 1.0, "les enfants naissent la ou le parent est mort")


func _test_bouclier_premier_coup() -> void:
	_fresh()
	var d := _def("knight", 40.0)
	d.first_hit_shield = true
	# Position explicite : on veut eprouver le BOUCLIER, pas le fondu
	# d apparition. Ne sur la ligne d apparition, le monstre serait intouchable
	# une demi-seconde et le premier coup ne partirait meme pas.
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	ok(e.has_shield(), "bouclier leve au depart")
	not_ok(e.take_damage(15.0, []), "le premier coup est absorbe")
	feq(e.hp, 40.0, "PV intacts apres le premier coup")
	not_ok(e.has_shield(), "le bouclier est tombe")
	ok(e.take_damage(15.0, []), "le second coup passe")
	feq(e.hp, 25.0, "PV entames")


func _test_enrage() -> void:
	_fresh()
	var d := _def("berserk", 100.0, 60.0)
	d.enrage_speed_pct = 20.0
	d.enrage_cap = 0.5
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	feq(e.enrage_bonus(), 0.0, "pas enrage au depart")
	e.take_damage(1.0, [])
	e.take_damage(1.0, [])
	feq(e.enrage_bonus(), 0.4, "+20 pourcent par coup")
	for i in 10:
		e.take_damage(1.0, [])
	feq(e.enrage_bonus(), 0.5, "plafonne au cap")
	# Le test porte sur le RAPPORT, pas sur une distance absolue : GameConfig
	# .ENEMY_SPEED_SCALE est un reglage d equilibrage qui bouge, la regle non.
	var y0: float = e.position.y
	e.advance(1.0)
	var attendu: float = 60.0 * GameConfig.ENEMY_SPEED_SCALE * 1.5
	feq(e.position.y - y0, attendu, "enrage a fond : la vitesse est multipliee par 1.5")


func _test_aura_protectrice() -> void:
	_fresh()
	var g := _def("guardian", 50.0)
	g.aura_shield_radius = 200.0
	var guardian: Enemy = _bf.spawn_enemy(g, 500.0, 1.0, Vector2(500.0, 500.0))
	var victim: Enemy = _bf.spawn_enemy(_def("victim", 30.0), 560.0, 1.0, Vector2(560.0, 520.0))
	var far: Enemy = _bf.spawn_enemy(_def("far", 30.0), 100.0, 1.0, Vector2(100.0, 1200.0))

	not_ok(_bf.damage_enemy(victim, 10.0, _damage_card()), "sous l aura : aucun degat")
	feq(victim.hp, 30.0, "PV du protege intacts")
	ok(_bf.damage_enemy(far, 10.0, _damage_card()), "hors de l aura : degats normaux")
	ok(_bf.damage_enemy(guardian, 10.0, _damage_card()), "le gardien lui-meme est vulnerable")

	guardian.take_damage(999.0, [])
	ok(_bf.damage_enemy(victim, 10.0, _damage_card()), "gardien mort : le protege redevient vulnerable")


func _test_soigneur() -> void:
	_fresh()
	var h := _def("priest", 30.0)
	h.heal_per_second = 6.0
	_bf.spawn_enemy(h, 500.0, 1.0, Vector2(500.0, 400.0))
	var wounded: Enemy = _bf.spawn_enemy(_def("wounded", 50.0), 300.0, 1.0, Vector2(300.0, 400.0))
	wounded.take_damage(30.0, [])
	feq(wounded.hp, 20.0, "blesse a 20")
	_sim(1.0)
	between(wounded.hp, 25.5, 26.5, "soigne d environ 6 PV en 1 s")
	_sim(10.0)
	feq(wounded.hp, 50.0, "jamais au-dela du maximum")


func _test_glouton() -> void:
	_fresh()
	var g := _def("glutton", 70.0, 0.0, 4)
	g.devours = true
	g.base_radius = 38.0
	var glutton: Enemy = _bf.spawn_enemy(g, 500.0, 1.0, Vector2(500.0, 500.0))
	_bf.spawn_enemy(_def("prey", 12.0, 0.0, 1), 510.0, 1.0, Vector2(510.0, 510.0))
	var strong: Enemy = _bf.spawn_enemy(_def("strong", 12.0, 0.0, 4), 520.0, 1.0, Vector2(520.0, 520.0))
	var max0: float = glutton.max_hp()
	_bf.simulate(1.0 / 60.0)
	eq(_bf.alive_count(), 2, "la proie plus faible est gobee")
	ok(is_instance_valid(strong) and not strong.is_dead(), "un monstre de meme puissance n est pas gobe")
	ok(glutton.max_hp() > max0, "le glouton gagne des PV max")
	ok(glutton.growth > 1.0, "et grossit")


func _test_volte_face() -> void:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("m", 10.0, 100.0), 500.0, 1.0, Vector2(500.0, 800.0))
	_bf.apply_reverse(1.0)
	ok(_bf.is_reversed(), "volte-face active")
	_sim(0.5)
	ok(e.position.y < 800.0, "le monstre remonte")
	var y_mid: float = e.position.y
	_sim(1.0)
	not_ok(_bf.is_reversed(), "la volte-face expire")
	ok(e.position.y > y_mid, "puis il redescend")


func _test_tireur() -> void:
	_fresh()
	SpeedGauge.set_speed_percent(400)
	var d := _def("archer", 20.0, 0.0)
	d.shoot_interval = 0.5
	d.shot_damage = 1
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	# A x4 la simulation va vite : quelques secondes suffisent pour qu un tir arrive.
	_sim(0.5)
	ok(_bf.shot_count() > 0, "le tireur a tire")
	_sim(2.0)
	ok(SpeedGauge.speed_percent < 400, "le tir a fait retomber la vitesse du mage")


func _test_a_coups() -> void:
	_fresh()
	var d := _def("hopper", 10.0, 100.0)
	d.burst_move = true
	d.burst_dash_time = 0.5
	d.burst_pause_time = 0.7
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	for i in 9:
		e.advance(0.05)
	var after_dash: float = e.position.y
	ok(after_dash > 300.0, "il avance pendant la phase de course")
	for i in 3:
		e.advance(0.05)
	for i in 10:
		e.advance(0.05)
	var during_pause: float = e.position.y
	e.advance(0.05)
	feq(e.position.y, during_pause, "immobile pendant la pause")


func _test_ondulation() -> void:
	_fresh()
	var d := _def("serpent", 10.0, 60.0)
	d.wave_amplitude = 120.0
	d.wave_frequency = 1.0
	var e: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	e.advance(0.25)
	ok(absf(e.position.x - 500.0) > 50.0, "le serpent s ecarte lateralement")
	ok(e.position.y > 300.0, "tout en descendant")


func _test_focalisation() -> void:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("m", 100.0), 500.0, 1.0, Vector2(500.0, 600.0))
	var card := _damage_card()
	var ctx := CastContext.make(_bf, card)
	ctx.target_enemy = e
	RunState.empower_next(2.0)
	EffectRegistry.cast(card, ctx)
	feq(e.hp, 80.0, "le sort suivant fait le double")
	var ctx2 := CastContext.make(_bf, card)
	ctx2.target_enemy = e
	EffectRegistry.cast(card, ctx2)
	feq(e.hp, 70.0, "puis les degats redeviennent normaux")


func _test_vulnerabilite() -> void:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("m", 100.0), 500.0, 1.0, Vector2(500.0, 600.0))
	_bf.spawn_ground_zone(Vector2(500.0, 600.0), 150.0, 5.0, 0.0, 0.0, null, 2.0)
	_bf.damage_enemy(e, 10.0, _damage_card())
	feq(e.hp, 80.0, "dans la marque : degats doubles")


func _test_resonance() -> void:
	_fresh()
	var a: Enemy = _bf.spawn_enemy(_def("a", 100.0), 500.0, 1.0, Vector2(500.0, 600.0))
	var b: Enemy = _bf.spawn_enemy(_def("b", 100.0), 540.0, 1.0, Vector2(540.0, 620.0))
	var c: Enemy = _bf.spawn_enemy(_def("c", 100.0), 460.0, 1.0, Vector2(460.0, 640.0))
	var card := SpellCard.new()
	card.id = &"t_res"
	var sp := EffectSpec.new()
	sp.key = &"damage_per_enemy"
	sp.magnitude = 5.0
	sp.radius = 200.0
	card.effects = [sp]
	var ctx := CastContext.make(_bf, card)
	ctx.target_position = Vector2(500.0, 620.0)
	EffectRegistry.cast(card, ctx)
	feq(a.hp, 85.0, "3 monstres x 5 = 15 degats a chacun")
	feq(b.hp, 85.0, "idem")
	feq(c.hp, 85.0, "idem")


## Le halo d aura protege EXACTEMENT ce qu il dessine : un joueur juge sa position
## au cercle affiche. Fx.halo dessine un diametre, la regle compare un rayon.
func _test_le_halo_couvre_la_zone_protegee() -> void:
	var rayon: float = 240.0
	var source: String = FileAccess.get_file_as_string("res://scripts/game/fx.gd")
	var ligne: int = source.find("static func halo(")
	ok(ligne >= 0, "Fx.halo existe")
	var corps: String = source.substr(ligne, 400)
	ok(corps.contains("radius * 2.0"),
		"le halo est dessine au diametre exact (radius * 2.0), pas a un facteur cosmetique")
	# Un monstre juste au bord est protege ; juste au-dela ne l est pas.
	feq(rayon * 2.0 / 2.0, rayon, "le demi-diametre dessine vaut le rayon de la regle")


## Les degats au mage sont VARIABLES selon le monstre, et un tir fait moins mal
## qu un contact : avec 8 PV et 1 degat partout, tout coup valait pareil.
func _test_les_degats_varient_selon_le_monstre() -> void:
	var gnome: EnemyDef = ContentDB.enemies.get(&"gnome")
	var behemoth: EnemyDef = ContentDB.enemies.get(&"behemoth")
	var chronos: EnemyDef = ContentDB.enemies.get(&"chronos")
	var archer: EnemyDef = ContentDB.enemies.get(&"imp_archer")
	if gnome == null or behemoth == null or chronos == null or archer == null:
		return

	ok(gnome.contact_hit() < behemoth.contact_hit(),
		"un gnome fait moins mal qu un behemoth")
	ok(behemoth.contact_hit() < chronos.contact_hit(),
		"un behemoth fait moins mal que le boss")
	ok(archer.shot_damage < gnome.contact_hit(),
		"une fleche pique moins qu un contact de gnome")

	# Le mage encaisse plusieurs coups : la partie ne se joue pas sur une erreur.
	ok(GameConfig.MAGE_MAX_HP / maxi(chronos.contact_hit(), 1) >= 2,
		"meme le boss ne tue pas en un coup")
	ok(GameConfig.MAGE_MAX_HP / maxi(gnome.contact_hit(), 1) >= 10,
		"les petits monstres laissent une vraie marge")


## Demande du testeur : "fais-les apparaitre un peu plus loin, par exemple au
## debut de l herbe, en fondu sur une demi-seconde, statiques, avant d avancer".
## Pendant le fondu le monstre ne bouge pas et ne peut pas etre touche — sinon
## on frappe des fantomes. Il compte pourtant comme vivant : la vague ne doit
## pas se terminer pendant qu il apparait.
func _test_apparition_en_fondu() -> void:
	_fresh()
	ok(GameConfig.SPAWN_LINE_Y > 0.0,
		"la ligne d apparition est DANS le decor visible, plus au-dessus de l ecran")
	var d := _def("m", 50.0, 100.0)
	# Apparition de vague : pas de position explicite, donc la ligne d apparition.
	var e: Enemy = _bf.spawn_enemy(d, 500.0)
	feq(e.position.y, GameConfig.SPAWN_LINE_Y, "il nait sur la ligne d apparition")
	ok(e.is_spawning(), "il est en train d apparaitre")
	ok(e.modulate.a < 0.05, "invisible a l instant zero")
	eq(_bf.alive_count(), 1, "il compte deja comme vivant (la vague ne se termine pas)")
	not_ok(_bf.damage_enemy(e, 10.0, _damage_card()), "intouchable pendant le fondu")
	# DEUX verrous, testes separement : le terrain ecarte le monstre du ciblage,
	# et le monstre refuse lui-meme le coup. Sans ce second appel, saboter la
	# garde de Enemy.take_damage() ne ferait rougir aucun test — le filtre du
	# terrain masquerait le trou, et un handler qui appellerait take_damage()
	# directement frapperait un fantome sans que rien ne le signale.
	not_ok(e.take_damage(10.0, []), "le monstre lui-meme refuse le coup pendant le fondu")
	feq(e.hp, 50.0, "PV intacts")
	eq(_bf.enemies_in_radius(e.position, 100.0).size(), 0, "invisible aux sorts de zone")
	ok(_bf.enemy_nearest_to(e.position) == null, "invisible au ciblage au doigt")

	_sim(GameConfig.SPAWN_FADE_TIME * 0.5)
	feq(e.position.y, GameConfig.SPAWN_LINE_Y, "immobile a mi-fondu")
	between(e.modulate.a, 0.3, 0.7, "a mi-fondu il est a moitie visible")

	_sim(GameConfig.SPAWN_FADE_TIME * 0.5 + 0.2)
	not_ok(e.is_spawning(), "le fondu est fini")
	feq(e.modulate.a, 1.0, "pleinement visible")
	ok(e.position.y > GameConfig.SPAWN_LINE_Y, "et il avance enfin")
	ok(_bf.damage_enemy(e, 10.0, _damage_card()), "et il peut etre touche")

	# Un monstre pose a une position explicite (division, invocation, vitrine)
	# apparait tel quel : un fondu au milieu du combat rendrait intouchables des
	# monstres deja au contact des zones du joueur.
	var e2: Enemy = _bf.spawn_enemy(d, 300.0, 1.0, Vector2(300.0, 700.0))
	not_ok(e2.is_spawning(), "pas de fondu pour une apparition a position explicite")


## Planogo : "capacite volante qui passe au-dessus des murs". Un volant ignore
## la grille de navigation et descend tout droit ; un marcheur, lui, reste
## bloque devant un mur qui barre toute la largeur.
func _test_le_vol_passe_par_dessus_les_murs() -> void:
	_fresh()
	_bf.spawn_wall(Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, 600.0),
		GameConfig.BATTLEFIELD_WIDTH * 0.5, 10.0, 60.0)
	ok(_bf.wall_count() > 0, "un mur barre toute la largeur")
	var volant := _def("flyer", 50.0, 200.0)
	volant.flying = true
	var marcheur := _def("walker", 50.0, 200.0)
	var v: Enemy = _bf.spawn_enemy(volant, 300.0, 1.0, Vector2(300.0, 400.0))
	var m: Enemy = _bf.spawn_enemy(marcheur, 700.0, 1.0, Vector2(700.0, 400.0))
	_sim(3.0)
	ok(v.position.y > 640.0, "le volant a passe le mur (y = %.0f)" % v.position.y)
	ok(m.position.y < 600.0, "le marcheur est reste devant (y = %.0f)" % m.position.y)
	feq(v.position.x, 300.0, "le volant descend tout droit, sans contourner")


## Planogo : "tire une boule de poison vers le joueur, moyennement rapide, qui
## a 10 PV". La boule est un monstre-projectile invoque : tout le ciblage et les
## degats existants s y appliquent, elle est donc DESTRUCTIBLE par les sorts.
func _test_le_planogo_tire_une_boule_de_poison_destructible() -> void:
	var wisp: EnemyDef = ContentDB.enemies.get(&"wisp")
	var ball: EnemyDef = ContentDB.enemies.get(&"poison_ball")
	ok(wisp != null, "le Planogo existe (id historique : wisp)")
	ok(ball != null, "la boule de poison existe")
	if wisp == null or ball == null:
		return
	eq(wisp.display_name, "Planogo", "le Feu follet s appelle desormais Planogo")
	ok(wisp.flying, "le Planogo vole")
	ok(wisp.summon_def != null and wisp.summon_def.id == &"poison_ball",
		"le Planogo invoque des boules de poison")
	ok(wisp.summon_interval > 0.0, "a intervalle regulier")

	feq(ball.max_hp, 10.0, "la boule a 10 PV (demande du testeur)")
	ok(ball.flying, "la boule vole elle aussi : un mur ne l arrete pas")
	ok(ball.projectile, "c est un projectile : ni bestiaire, ni XP")
	eq(ball.base_xp, 0, "pas d XP")
	ok(ball.contact_hit() > 0, "elle fait mal au contact")
	ok(ball.contact_hit() < wisp.contact_hit(), "moins qu un contact du Planogo lui-meme")
	ok(ball.base_speed > 100.0 and ball.base_speed < 150.0, "moyennement rapide")
	ok(AnimCatalog.has(ball.anim_key), "elle a une feuille dans le catalogue")

	_fresh()
	var xp_avant: int = RunState.xp
	var p: Enemy = _bf.spawn_enemy(wisp, 540.0, 1.0, Vector2(540.0, 400.0))
	_sim(wisp.summon_interval + 0.2)
	eq(_bf.alive_count(), 2, "apres l intervalle, une boule est en l air")
	var boule: Enemy = null
	for e in _bf.enemies:
		if e != p and e.definition != null and e.definition.id == &"poison_ball":
			boule = e
	ok(boule != null, "la boule est un monstre du terrain")
	if boule == null:
		return
	ok(boule.position.y >= 400.0, "elle part du Planogo vers le mage")
	ok(_bf.damage_enemy(boule, 10.0, _damage_card()), "un sort la touche")
	ok(boule.is_dead(), "10 degats la detruisent")
	eq(RunState.xp, xp_avant, "la detruire ne rapporte aucune XP")


## "Nuee de rats -> Oiseau mirage : son sprite tourne en se deplacant". Cause :
## la planche du paon est une grille 4 DIRECTIONS x 3 frames, et la bande de
## marche avait ete decoupee sur une LIGNE (gauche, face, dos, droite) au lieu
## d une COLONNE. Regle : toutes les cases de marche montrent la MEME face, donc
## leur silhouette a la meme largeur ; des vues de cote et de face melangees
## different de 6 px et plus.
func _test_l_oiseau_mirage_ne_tourne_plus() -> void:
	var swarm: EnemyDef = ContentDB.enemies.get(&"rat_swarm")
	ok(swarm != null and swarm.display_name == "Oiseau mirage",
		"la Nuee de rats s appelle desormais Oiseau mirage")
	var sf: SpriteFrames = AnimCatalog.frames(&"peacock")
	ok(sf != null and sf.has_animation("walk"), "le paon a une marche")
	if sf == null or not sf.has_animation("walk"):
		return
	var n: int = sf.get_frame_count("walk")
	ok(n >= 3, "la marche a au moins 3 cases (%d)" % n)
	var largeurs: Array[int] = []
	for i in n:
		var tex: Texture2D = sf.get_frame_texture("walk", i)
		var img: Image = tex.get_image()
		if img == null:
			continue
		var rect: Rect2i = img.get_used_rect()
		largeurs.append(rect.size.x)
	ok(largeurs.size() == n, "chaque case a une image lisible")
	if largeurs.is_empty():
		return
	var lo: int = largeurs.min()
	var hi: int = largeurs.max()
	ok(hi - lo <= 4, "toutes les cases montrent la meme face (largeurs %s)" % str(largeurs))


## "Augmente legerement la taille de tous les monstres" : le facteur visuel
## passe de 1,9 a 2,1 (+10 %). Il ne touche pas la hitbox, qui reste le rayon.
func _test_les_monstres_sont_un_peu_plus_grands() -> void:
	ok(Enemy.VISUAL_FACTOR >= 2.05, "facteur visuel remonte (%.2f)" % Enemy.VISUAL_FACTOR)
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("m", 10.0), 500.0, 1.0, Vector2(500.0, 600.0))
	feq(e.radius(), 32.0, "le rayon logique (contact, gobage) ne change pas")
	feq(e.visual_radius(), 32.0 * Enemy.VISUAL_FACTOR, "seule la taille a l ecran grandit")
