extends TestCase
## Carte mur : blocage du pathfinding, expiration, et deviation reelle des monstres.

func get_suite_name() -> String:
	return "wall"


func _wall_card(duration: float = 8.0, half_width: float = 200.0) -> SpellCard:
	var c := SpellCard.new()
	c.id = &"t_wall"
	c.display_name = "Mur test"
	c.base_cast_time = 1.8
	c.targeting = GameEnums.Targeting.POSITION
	var sp := EffectSpec.new()
	sp.key = &"build_wall"
	sp.radius = half_width
	sp.duration = duration
	sp.params = {&"thickness": 60.0}
	c.effects = [sp]
	return c


func run() -> void:
	_test_handler_enregistre()
	_test_mur_bloque_la_grille()
	_test_mur_expire()
	_test_monstre_devie()
	_test_le_mur_arrete_les_projectiles()


func _test_handler_enregistre() -> void:
	ok(EffectRegistry.has_key(&"build_wall"), "le handler build_wall est enregistre")


func _test_mur_bloque_la_grille() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	var card := _wall_card()
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 800.0)

	eq(bf.nav.blocked_count(), 0, "aucune cellule bloquee au depart")
	EffectRegistry.cast(card, ctx)

	eq(bf.wall_count(), 1, "un mur est pose")
	ok(bf.nav.blocked_count() > 0, "le mur bloque des cellules de navigation")
	ok(bf.nav.is_blocked(bf.nav.to_cell(Vector2(540.0, 800.0))),
		"la cellule visee est bloquee")
	bf.free()


func _test_mur_expire() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	var card := _wall_card(2.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 800.0)
	EffectRegistry.cast(card, ctx)
	ok(bf.nav.blocked_count() > 0, "cellules bloquees pendant la vie du mur")

	# On avance la simulation du mur au-dela de sa duree.
	SpeedGauge.reset()
	for i in 200:
		bf.simulate(1.0 / 60.0)

	eq(bf.wall_count(), 0, "le mur disparait a expiration")
	eq(bf.nav.blocked_count(), 0, "les cellules sont liberees")
	bf.free()


## Le test qui compte vraiment : un monstre change-t-il de trajectoire ?
func _test_monstre_devie() -> void:
	var grid := NavGrid.new()
	var depart := Vector2(540.0, 300.0)

	var direct: Array[Vector2] = grid.find_path(depart)
	ok(direct.size() > 0, "chemin libre avant le mur")

	grid.block_rect(Vector2(540.0, 800.0), 240.0, 60.0)
	var devie: Array[Vector2] = grid.find_path(depart)
	ok(devie.size() > 0, "le monstre trouve un chemin malgre le mur")

	# La deviation doit etre laterale et reelle.
	var ecart: float = 0.0
	for p in devie:
		ecart = maxf(ecart, absf(p.x - depart.x))
	ok(ecart > NavGrid.CELL_SIZE * 2.0,
		"le monstre s ecarte nettement pour contourner (ecart %.0f px)" % ecart)

	# Et il finit quand meme par descendre jusqu au mage.
	var dernier: Vector2 = devie[devie.size() - 1]
	ok(dernier.y >= GameConfig.MAGE_LINE_Y - NavGrid.CELL_SIZE,
		"le contournement aboutit tout de meme a la ligne du mage")


## Un mur de pierre doit ARRETER les fleches : demande du testeur. Sans cela il
## ne protege que du contact, et les archers le traversent comme s il n existait pas.
func _test_le_mur_arrete_les_projectiles() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)

	var centre := Vector2(540.0, 900.0)
	bf.spawn_wall(centre, 200.0, 20.0, 60.0)
	eq(bf.wall_count(), 1, "le mur est en place")

	# Une fleche juste au-dessus du mur, dans sa largeur.
	bf.shots.append({"pos": Vector2(540.0, 880.0), "damage": 2, "node": null,
		"shooter": null})
	var vitesse_avant: int = SpeedGauge.speed_percent
	for i in 30:
		bf.simulate(1.0 / 60.0)
	eq(bf.shots.size(), 0, "la fleche a ete arretee")
	eq(SpeedGauge.speed_percent, vitesse_avant, "elle n a pas touche le mage")

	# Une fleche a cote du mur passe normalement.
	bf.shots.append({"pos": Vector2(100.0, 880.0), "damage": 2, "node": null,
		"shooter": null})
	for i in 200:
		bf.simulate(1.0 / 60.0)
		if bf.shots.is_empty():
			break
	ok(SpeedGauge.speed_percent < vitesse_avant, "une fleche hors du mur touche bien le mage")
	SpeedGauge.reset()
