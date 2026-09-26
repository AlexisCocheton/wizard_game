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
	reset_gauge_at_normal_speed()
	RunState.reset()


## Simule `seconds` de MONDE A x1, en maintenant le mage en vie.
##
## Depuis que la vitesse EST la vie (26 septembre), ces deux exigences sont la
## meme : le monde tourne a x1 quand le mage est a 100 %, et 100 % est le
## plancher mortel. Un boss qui tire tuait donc le mage en quelques secondes, et
## TOUT le reste de la simulation basculait au ralenti d agonie (x0,25) — le
## symptome etant un boss qui "n arrive jamais a sa ligne de tir", trois etages
## en aval de la vraie cause.
##
## Ces suites mesurent des deplacements, des cadences et des portees ; la survie
## du mage n y est jamais le sujet. On la lui rend donc image par image, ce qui
## tient l horloge du monde exactement a x1. Les tests qui veulent au contraire
## VERIFIER qu un coup coute quelque chose relevent la vitesse avant et apres,
## et ils la lisent dans la meme image que le coup.
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(1.0 / 60.0)
		# `is_dying` ne se leve pas tout seul : le remettre a 100 % sans sortir
		# de l agonie laisserait world_delta() au ralenti pour toujours, et le
		# test mesurerait un monde au quart de sa vitesse sans rien signaler.
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
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
	_test_la_resistance_change_les_degats_recus()
	_test_la_gorgone_petrifie_une_carte_de_la_main()
	_test_tuer_la_gorgone_degele_la_main()
	_test_jamais_plus_de_cinq_cartes_sur_six_petrifiees()
	_test_le_plafond_suit_la_main_reelle()
	_test_la_petrification_est_stable()
	_test_les_trois_gorgones_sont_livrees()
	_test_l_onde_de_choc_frappe_le_mage_et_le_terrain()
	_test_l_onde_de_choc_a_une_portee()
	_test_le_bourreau_livre_n_avance_pas()
	_test_le_slime_demoniaque_est_un_slime_immunise_au_feu()
	_test_un_monstre_sans_marche_a_une_animation_de_repos()
	_test_l_invocation_est_ecrite_sur_la_fiche()
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
	ok(SpeedGauge.max_reserve() / maxi(chronos.contact_hit(), 1) >= 2,
		"meme le boss ne tue pas en un coup")
	ok(SpeedGauge.max_reserve() / maxi(gnome.contact_hit(), 1) >= 10,
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


## RESISTANCES ELEMENTAIRES — le meme sort, deux monstres, deux resultats.
##
## C est la raison d etre du systeme : si ce test tombe, changer de deck ne sert
## plus a rien et le bestiaire redevient decoratif. On mesure sur un VRAI
## Battlefield parce que la resistance vit dans `_hit()`, pas dans `Enemy`.
func _test_la_resistance_change_les_degats_recus() -> void:
	_fresh()
	var feu := _def("brulable", 100.0)
	feu.resistances = {GameEnums.DamageTag.FIRE: 1.5}
	var pierre := _def("pierreux", 100.0)
	pierre.resistances = {GameEnums.DamageTag.FIRE: 0.5}

	var a: Enemy = _bf.spawn_enemy(feu, 300.0, 1.0, Vector2(300.0, 600.0))
	var b: Enemy = _bf.spawn_enemy(pierre, 700.0, 1.0, Vector2(700.0, 600.0))
	_sim(0.6)  # on epuise le fondu d apparition, sinon rien ne porte

	var brulure := SpellCard.new()
	brulure.id = &"t_feu"
	var tags: Array[GameEnums.DamageTag] = []
	tags.append(GameEnums.DamageTag.FIRE)
	brulure.tags = tags
	_bf.damage_enemy(a, 40.0, brulure)
	_bf.damage_enemy(b, 40.0, brulure)

	feq(a.hp, 40.0, "le monstre vulnerable au feu prend 150 pourcent", 0.01)
	feq(b.hp, 80.0, "le monstre resistant au feu prend 50 pourcent", 0.01)
	ok(a.hp < b.hp, "le MEME sort ne vaut pas la meme chose sur deux monstres")

	# Et le contenu livre porte bien cet ecart : golem contre gelee, sur le feu.
	var golem: EnemyDef = ContentDB.enemies.get(&"golem")
	var gelee: EnemyDef = ContentDB.enemies.get(&"jelly")
	if golem != null and gelee != null:
		ok(golem.resistance_to(GameEnums.DamageTag.FIRE)
			< gelee.resistance_to(GameEnums.DamageTag.FIRE),
			"la pierre encaisse le feu mieux que la gelee")
		ok(golem.resistance_to(GameEnums.DamageTag.ARCANE)
			> gelee.resistance_to(GameEnums.DamageTag.ARCANE),
			"et l inverse sur l arcane : chaque element a sa bonne cible")


# --- CHANTIER I2 : LE REGARD DE LA GORGONE -------------------------------
#
# La mecanique demandee par le testeur : « Bosse qui a la capacite de bloquer
# des cartes de ta main en les rendant injouable. Creer un monstre normal qui
# en bloque 1, un mini bosse qui en bloque 2 et un bosse qui en bloque 3. Fait
# en sorte que l on puisse pas avoir plus de 5 carte sur 6 bloquer. »
#
# Ce qu elle change dans le jeu, et pourquoi elle merite son champ plutot qu un
# effet : toutes les autres mecaniques de monstre agissent sur le TERRAIN (ou
# frapper, quand, avec quoi). Celle-ci agit sur la MAIN. C est la premiere fois
# qu un monstre touche les cartes du joueur, donc la premiere fois que la
# reponse est « tue-le pour recuperer ton deck » et non « choisis mieux ta
# cible ». Un joueur dont la main est petrifiee doit pouvoir la degeler en
# tuant la source, sans quoi la mecanique est une punition et pas une decision.

func _gorgone(blocks: int, hp: float = 60.0) -> EnemyDef:
	var d := _def("g%d" % blocks, hp, 40.0, 3)
	d.blocks_cards = blocks
	return d


func _main_de(n: int) -> void:
	RunState.hand.clear()
	for i in n:
		var c := SpellCard.new()
		c.id = StringName("main_%d" % i)
		c.display_name = "Carte %d" % i
		RunState.hand.append(c)


## UNE gorgone normale petrifie UNE carte, et cette carte-la refuse de partir.
func _test_la_gorgone_petrifie_une_carte_de_la_main() -> void:
	_fresh()
	_main_de(5)
	_bf.spawn_enemy(_gorgone(1), 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(0.6)
	eq(RunState.blocked_cards().size(), 1,
		"une gorgone a 1 regard petrifie exactement 1 carte")
	var gelee: SpellCard = RunState.blocked_cards()[0]
	ok(RunState.is_card_blocked(gelee), "la carte visee se sait petrifiee")
	not_ok(RunState.play_card(gelee), "une carte petrifiee ne se lance pas")
	eq(RunState.hand.size(), 5, "et elle reste en main : elle est gelee, pas defaussee")
	# Les autres, elles, partent normalement.
	var libre: SpellCard = null
	for c: SpellCard in RunState.hand:
		if not RunState.is_card_blocked(c):
			libre = c
			break
	ok(libre != null, "quatre cartes sur cinq restent jouables")
	ok(RunState.play_card(libre), "une carte libre se lance toujours")


## TUER la gorgone rend la main. C est la reponse que la mecanique doit avoir :
## sans elle le joueur subit, il ne joue pas.
func _test_tuer_la_gorgone_degele_la_main() -> void:
	_fresh()
	_main_de(5)
	var g: Enemy = _bf.spawn_enemy(_gorgone(2), 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(0.6)
	eq(RunState.blocked_cards().size(), 2, "deux regards, deux cartes petrifiees")
	g.kill()
	_sim(0.2)
	eq(RunState.blocked_cards().size(), 0,
		"la gorgone morte, la main est rendue — tuer la source EST la reponse")
	for c: SpellCard in RunState.hand:
		ok(RunState.play_card(c), "toutes les cartes repartent apres sa mort")
		break


## LE PLAFOND EXIGE PAR LE TESTEUR : jamais plus de 5 cartes sur 6. Deux
## gorgones de boss (3 chacune) totalisent 6 regards ; le plafond doit en
## laisser une jouable, sinon le joueur regarde son ecran sans rien pouvoir
## faire et ce n est plus un jeu.
func _test_jamais_plus_de_cinq_cartes_sur_six_petrifiees() -> void:
	_fresh()
	_main_de(6)
	_bf.spawn_enemy(_gorgone(3), 300.0, 1.0, Vector2(300.0, 400.0))
	_bf.spawn_enemy(_gorgone(3), 700.0, 1.0, Vector2(700.0, 400.0))
	_sim(0.6)
	eq(RunState.blocked_cards().size(), 5,
		"six regards, mais le plafond s arrete a 5 : une carte reste toujours jouable")
	var libres: int = 0
	for c: SpellCard in RunState.hand:
		if not RunState.is_card_blocked(c):
			libres += 1
	eq(libres, 1, "il reste EXACTEMENT une carte jouable, jamais zero")


## Une main plus PETITE que le nombre de regards : le plafond est relatif a la
## main reelle, pas au maximum theorique. Avec 3 cartes en main et 3 regards,
## le joueur doit encore pouvoir en jouer une.
func _test_le_plafond_suit_la_main_reelle() -> void:
	_fresh()
	_main_de(3)
	_bf.spawn_enemy(_gorgone(3), 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(0.6)
	eq(RunState.blocked_cards().size(), 2,
		"3 cartes en main : au plus 2 petrifiees, jamais la main entiere")


## La carte petrifiee ne change pas a chaque image. Sans stabilite, le joueur
## voit la petrification sauter de carte en carte et ne peut rien planifier.
func _test_la_petrification_est_stable() -> void:
	_fresh()
	_main_de(5)
	_bf.spawn_enemy(_gorgone(2), 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(0.6)
	var avant: Array[SpellCard] = RunState.blocked_cards().duplicate()
	_sim(2.0)
	var apres: Array[SpellCard] = RunState.blocked_cards()
	eq(apres.size(), avant.size(), "le nombre de cartes gelees ne bouge pas")
	for c in avant:
		ok(apres.has(c), "la MEME carte reste gelee : le joueur peut planifier")


## LE CONTENU LIVRE. Trois gorgones, un par palier, exactement comme demande.
func _test_les_trois_gorgones_sont_livrees() -> void:
	var par_regard: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.blocks_cards > 0:
			par_regard[d.blocks_cards] = d
			ok(d.blocks_cards <= 3,
				"%s : au-dela de 3 regards un seul monstre viderait la main" % d.id)
	ok(par_regard.has(1), "un monstre NORMAL qui bloque 1 carte est livre")
	ok(par_regard.has(2), "un MINI-BOSS qui bloque 2 cartes est livre")
	ok(par_regard.has(3), "un BOSS qui bloque 3 cartes est livre")
	if par_regard.has(1):
		eq((par_regard[1] as EnemyDef).kind, GameEnums.EnemyKind.NORMAL,
			"celui a 1 regard est bien un monstre commun")
	if par_regard.has(2):
		eq((par_regard[2] as EnemyDef).kind, GameEnums.EnemyKind.MINIBOSS,
			"celui a 2 regards est bien un mini-boss")
	if par_regard.has(3):
		eq((par_regard[3] as EnemyDef).kind, GameEnums.EnemyKind.BOSS,
			"celui a 3 regards est bien un boss")
	# La fiche du bestiaire doit le DIRE : une main qui se gele sans explication
	# se lit comme un bug, pas comme un monstre.
	for regard in par_regard:
		var lignes: Array[String] = BestiaryLore.behaviours(par_regard[regard])
		var dit: bool = false
		for l in lignes:
			if l.to_lower().contains("carte"):
				dit = true
		ok(dit, "%s : sa fiche explique qu il petrifie des cartes"
			% (par_regard[regard] as EnemyDef).id)


# --- CHANTIER I2 : L ONDE DE CHOC DU BOURREAU ----------------------------
#
# Demande du testeur : « peut etre un bosse qui n avance pas qui tape le sol
# pour faire une onde de choque qui fait des degats ».
#
# Le boss immobile existait deja a moitie (`keeps_distance_at` fait camper le
# Seigneur Spectre), mais camper en TIRANT et camper en FRAPPANT LE SOL ne se
# jouent pas pareil : un tir vise le mage, une onde balaie un RAYON. Le joueur
# ne peut donc plus se contenter de rester hors de la ligne de tir, il doit
# tenir ses invocations et ses murs hors du cercle.

func _test_l_onde_de_choc_frappe_le_mage_et_le_terrain() -> void:
	_fresh()
	var b := _def("bourreau", 300.0, 0.0, 10)
	b.kind = GameEnums.EnemyKind.BOSS
	b.shockwave_interval = 1.0
	b.shockwave_radius = 300.0
	b.shockwave_damage = 7
	# De la marge, sans emballer le monde : l onde doit BLESSER le mage, pas le
	# tuer, et le test chronometre aussi son intervalle de frappe.
	SpeedGauge.heal(40)
	var pv_avant: int = SpeedGauge.speed_percent
	# Une victime dans le cercle : l onde n epargne pas le decor du joueur.
	_bf.spawn_enemy(b, 540.0, 1.0, Vector2(540.0, GameConfig.MAGE_LINE_Y - 150.0))
	_sim(0.6)
	eq(_bf.shockwave_strike_count(), 0, "avant son heure, aucune onde")
	_sim(1.2)
	ok(_bf.shockwave_strike_count() >= 1, "le bourreau a frappe le sol au moins une fois")
	ok(SpeedGauge.speed_percent < pv_avant,
		"l onde coute de la vitesse au mage, c est-a-dire de la vie")


## Hors du cercle, rien. Une onde qui porterait a l ecran entier ne serait plus
## une position a tenir, ce serait une taxe.
func _test_l_onde_de_choc_a_une_portee() -> void:
	_fresh()
	var b := _def("bourreau_loin", 300.0, 0.0, 10)
	b.kind = GameEnums.EnemyKind.BOSS
	b.shockwave_interval = 1.0
	b.shockwave_radius = 120.0
	b.shockwave_damage = 7
	# Pose TRES haut : le mage est hors de portee de son cercle.
	_bf.spawn_enemy(b, 540.0, 1.0, Vector2(540.0, 200.0))
	reset_gauge_at_normal_speed()
	var pv: int = SpeedGauge.speed_percent
	var vitesse: int = SpeedGauge.speed_percent
	_sim(2.5)
	ok(_bf.shockwave_strike_count() >= 1, "il frappe le sol quand meme")
	eq(SpeedGauge.speed_percent, pv, "mais hors de portee le mage n encaisse rien")
	eq(SpeedGauge.speed_percent, vitesse, "et son bouclier de vitesse ne tombe pas")


## Le bourreau N AVANCE PAS. C est le mot exact du testeur, et c est ce qui
## rend l onde jouable : un boss qui avancerait EN frappant le sol ne laisserait
## aucun endroit sur : il suffirait d attendre.
func _test_le_bourreau_livre_n_avance_pas() -> void:
	var trouve: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.shockwave_interval <= 0.0:
			continue
		trouve += 1
		ok(d.shockwave_radius > 0.0,
			"%s : une onde sans rayon ne touche jamais rien" % d.id)
		ok(d.shockwave_damage > 0, "%s : une onde sans degats n est qu un bruit" % d.id)
		ok(d.base_speed <= 0.0 or d.keeps_distance_at > 0.0,
			"%s : il doit rester en place, c est la demande" % d.id)
	ok(trouve >= 1, "un boss a onde de choc est livre")


## LE SLIME DEMONIAQUE. Demande du testeur : « toujours le meme concept de slime
## mais dans le monde demon et immunise au feu ». Un slime immunise au feu
## retourne exactement la lecon du bestiaire — la Gelee ordinaire est le monstre
## qu on brule — donc le joueur qui applique son reflexe se fait punir.
func _test_le_slime_demoniaque_est_un_slime_immunise_au_feu() -> void:
	var ds: EnemyDef = ContentDB.enemies.get(&"demon_slime")
	ok(ds != null, "le slime demoniaque est livre")
	if ds == null:
		return
	eq(ds.resistance_to(GameEnums.DamageTag.FIRE), 0.0,
		"immunise au feu, mot pour mot la demande du testeur")
	ok(ds.split_into != null and ds.split_count > 0,
		"c est bien un SLIME : il se divise, sinon ce n est qu un gros monstre rouge")
	# Et le reflexe appris sur la Gelee doit vraiment se retourner.
	var gelee: EnemyDef = ContentDB.enemies.get(&"jelly")
	if gelee != null:
		ok(gelee.resistance_to(GameEnums.DamageTag.FIRE)
			> ds.resistance_to(GameEnums.DamageTag.FIRE),
			"la Gelee brule, le slime demoniaque non : le meme deck ne marche plus")


## UN MONSTRE QUI NE MARCHE PAS DOIT QUAND MEME S ANIMER.
##
## LE DEFAUT MESURE, et c est l etage `visual` qui l a attrape, pas l unite :
## « ERROR: There is no animation with name 'walk'. » Le code de sprite jouait
## `walk` en dur a la mise en place, au retour de coup et au retour d attaque. Or
## une feuille n a pas forcement de marche : le Bourreau n avance pas, sa planche
## porte idle / attack / death / summon et RIEN d autre. Le Gardien-totem flottant
## est dans le meme cas.
##
## C etait invisible en headless (le code de sprite ne s execute pas) et invisible
## a l audit (la feuille existe, le monstre est dans un pool). Seule une fenetre
## reelle le montre — exactement ce que l etage `visual` est fait pour attraper.
##
## Le repli est le REPOS : un monstre immobile doit respirer sur place, pas figer
## sur une image. Ce test verrouille la regle sur le catalogue livre.
func _test_un_monstre_sans_marche_a_une_animation_de_repos() -> void:
	var sans_marche: Array[String] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or String(d.anim_key) == "" or not AnimCatalog.has(d.anim_key):
			continue
		if AnimCatalog.is_static(d.anim_key):
			continue
		if AnimCatalog.has_anim(d.anim_key, "walk"):
			continue
		# Pas de marche : il DOIT avoir un repos, sinon Enemy n a rien a jouer.
		if not AnimCatalog.has_anim(d.anim_key, "idle"):
			sans_marche.append("%s (%s)" % [d.id, d.anim_key])
	ok(sans_marche.is_empty(),
		("ces monstres n ont ni marche ni repos : le lecteur d animation n a rien"
		+ " a jouer et l etage visual rougit — %s") % ", ".join(sans_marche))

	# Et la fonction qui CHOISIT l animation de repos doit rendre quelque chose
	# de jouable pour chaque monstre livre : c est elle que le bug contournait.
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or String(d.anim_key) == "" or not AnimCatalog.has(d.anim_key) \
				or AnimCatalog.is_static(d.anim_key):
			continue
		var choisie: String = Enemy.resting_anim(d.anim_key)
		ok(choisie != "", "%s : aucune animation de repos trouvable" % d.id)
		ok(AnimCatalog.has_anim(d.anim_key, choisie),
			"%s : l animation de repos choisie (%s) n existe pas sur sa feuille"
			% [d.id, choisie])


## L INVOCATION DOIT ETRE ECRITE SUR LA FICHE.
##
## Defaut PRE-EXISTANT trouve par la sonde du chantier I2, en relisant la fiche du
## Bourreau : `BestiaryLore.behaviours()` traduisait onze comportements et PAS
## l invocation. L Ensevelisseur (dont invoquer EST tout le combat), le Planogo et
## le Bourreau avaient donc une fiche qui ne disait rien de ce qu ils font.
##
## Ce n est pas cosmetique : la reponse a un invocateur est « tue la source
## d abord », et c est la seule chose que le joueur ne peut pas deviner en
## regardant l ecran — il voit des sbires arriver, pas qui les envoie.
func _test_l_invocation_est_ecrite_sur_la_fiche() -> void:
	var invocateurs: int = 0
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.summon_interval <= 0.0 or d.summon_def == null:
			continue
		invocateurs += 1
		var dit: bool = false
		for l in BestiaryLore.behaviours(d):
			var bas: String = l.to_lower()
			if bas.contains("invoque") or bas.contains("appelle"):
				dit = true
		ok(dit, "%s invoque des %s et sa fiche ne le dit pas : le joueur ne peut"
			% [d.id, d.summon_def.display_name]
			+ " pas deviner qu il faut tuer la source")
	ok(invocateurs >= 2, "le jeu a plusieurs invocateurs (%d)" % invocateurs)
