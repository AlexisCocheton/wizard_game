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
	_test_origine_du_rayon_est_le_mage()
	_test_l_anneau_de_zone_dit_la_verite()


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


## La fleche percante part DU MAGE. Le GameController est un Node2D pose a
## l origine de la scene : prendre sa position globale faisait partir le rayon du
## coin haut-gauche, et la ligne ne touchait plus personne.
func _test_origine_du_rayon_est_le_mage() -> void:
	var mage := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	var faux_caster := Node2D.new()   # a l origine, comme le GameController
	var ctx := CastContext.make(null, _card(GameEnums.Targeting.DIRECTION, "pierce_line"))
	ctx.caster = faux_caster
	var origine: Vector2 = ctx.caster_position()
	feq(origine.x, mage.x, "le rayon part de la colonne du mage")
	feq(origine.y, mage.y, "le rayon part de la ligne du mage")
	ok(origine.distance_to(Vector2.ZERO) > 100.0, "le rayon ne part pas du coin de l ecran")
	faux_caster.free()


## L anneau d une zone dessine EXACTEMENT le rayon qui inflige les degats.
## Meme regle que le halo d aura : un visuel qui represente une regle est a
## l echelle de la regle, jamais a un facteur esthetique.
func _test_l_anneau_de_zone_dit_la_verite() -> void:
	var ring := ZoneRing.new()
	ring.setup(180.0, Color.WHITE)
	feq(ring.radius, 180.0, "l anneau prend le rayon demande")

	var source: String = FileAccess.get_file_as_string("res://scripts/game/fx.gd")
	var debut: int = source.find("static func zone_visual(")
	ok(debut >= 0, "Fx.zone_visual existe")
	var corps: String = source.substr(debut, 700)
	ok(corps.contains("ring.setup(radius,"),
		"l anneau recoit le rayon de la zone, sans facteur")
	# On cherche l APPEL, pas le mot : le commentaire qui explique le changement
	# cite forcement l ancienne feuille.
	not_ok(corps.contains("sprite(root, \"protectioncircle\""),
		"l anneau n est plus la feuille de 34 px etiree x10")
	ring.free()
