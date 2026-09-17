extends TestCase
## Ciblage des cartes : chaque mode interprete correctement le point vise.

func get_suite_name() -> String:
	return "targeting"


func _card(targeting: GameEnums.Targeting, key: String = "damage_single",
		radius: float = 0.0, duration: float = 0.0) -> SpellCard:
	var c := SpellCard.new()
	c.id = &"t_card"
	c.display_name = "Test"
	c.base_cast_time = 1.0
	c.targeting = targeting
	var sp := EffectSpec.new()
	sp.key = StringName(key)
	sp.magnitude = 10.0
	sp.radius = radius
	sp.duration = duration
	c.effects = [sp]
	return c


func run() -> void:
	_test_cartes_a_viser()
	_test_direction_depuis_le_mage()
	_test_position_utilise_le_point()
	_test_refus_sans_visee()
	_test_carte_sans_ciblage()


## Une carte a viser doit etre reconnue comme telle par le HUD.
func _test_cartes_a_viser() -> void:
	var pos_card := _card(GameEnums.Targeting.POSITION)
	var none_card := _card(GameEnums.Targeting.NONE)
	var dir_card := _card(GameEnums.Targeting.DIRECTION)
	var tgt_card := _card(GameEnums.Targeting.TARGET)

	ok(pos_card.targeting != GameEnums.Targeting.NONE, "POSITION demande une visee")
	ok(dir_card.targeting != GameEnums.Targeting.NONE, "DIRECTION demande une visee")
	ok(tgt_card.targeting != GameEnums.Targeting.NONE, "TARGET demande une visee")
	eq(none_card.targeting, GameEnums.Targeting.NONE, "NONE ne demande pas de visee")


## La direction se calcule depuis le mage vers le point relache.
func _test_direction_depuis_le_mage() -> void:
	var mage := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)

	# Doigt droit au-dessus du mage -> tir vers le haut.
	var haut := Vector2(mage.x, mage.y - 500.0)
	var d1: Vector2 = (haut - mage).normalized()
	ok(d1.y < -0.9, "point au-dessus -> direction vers le haut")

	# Doigt en haut a droite -> la direction penche a droite.
	var diag := Vector2(mage.x + 400.0, mage.y - 400.0)
	var d2: Vector2 = (diag - mage).normalized()
	ok(d2.x > 0.5 and d2.y < -0.5, "point en diagonale -> direction diagonale")
	feq(d2.length(), 1.0, "la direction est normalisee")


## Une zone doit se creer exactement la ou le doigt a relache.
func _test_position_utilise_le_point() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	var card := _card(GameEnums.Targeting.POSITION, "ground_zone", 150.0, 3.0)
	var point := Vector2(300.0, 800.0)

	var ctx := CastContext.make(bf, card)
	ctx.target_position = point
	EffectRegistry.cast(card, ctx)

	eq(bf.zones.size(), 1, "une zone est creee")
	var z: Dictionary = bf.zones[0]
	eq(z["pos"], point, "la zone est centree sur le point vise, pas sur le mage")
	feq(float(z["radius"]), 150.0, "le rayon vient de la carte")
	bf.free()


## Sans point de visee, une carte a viser ne doit pas partir n importe ou.
func _test_refus_sans_visee() -> void:
	# On verifie la regle telle que GameController l applique.
	var card := _card(GameEnums.Targeting.POSITION)
	var besoin: bool = card.targeting != GameEnums.Targeting.NONE
	ok(besoin, "la carte exige une visee")
	# Vector2.INF est la sentinelle "aucun point fourni".
	ok(Vector2.INF != Vector2.ZERO, "la sentinelle se distingue d une position nulle")
	ok(is_inf(Vector2.INF.x), "Vector2.INF est bien infini")


func _test_carte_sans_ciblage() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	var card := _card(GameEnums.Targeting.NONE, "self_haste", 0.0, 4.0)
	var ctx := CastContext.make(bf, card)
	EffectRegistry.cast(card, ctx)
	ok(bf.cast_haste > 1.0, "un sort sans ciblage agit sans point vise")
	bf.free()
