extends TestCase
## LEGENDE AU-DESSUS DES MONSTRES (vague 10, chantier C1) : la boite de
## Fx.mech_label (420 px centres sur le monstre) n etait jamais ramenee dans le
## cadre ; pres du bord gauche ou droit, la legende etait coupee (capture du
## 17/10, « GARDE : les coups glissent »). Elle est ramenee dans le terrain
## (1080 px) avec une marge, resserree sur son contenu.
##
## Bornes ecrites EN DUR (voir gotchas : un test qui relit la constante qu il
## contraint passe toujours) : terrain de 1080 px, marge de 24 px.
## Sabotage verifie : caption_box_x rendant la boite centree sans la ramener ->
## les verifications de bord echouent.

const TERRAIN: float = 1080.0
const MARGE: float = 24.0


func get_suite_name() -> String:
	return "mech_label_clamp"


func run() -> void:
	_test_les_reglages_attendus()
	_test_au_milieu_la_boite_reste_centree()
	_test_au_bord_gauche_la_boite_est_ramenee()
	_test_au_bord_droit_la_boite_est_ramenee()
	_test_une_boite_plus_large_que_le_terrain_se_centre()
	_test_fit_caption_resserre_et_ramene()


func _test_les_reglages_attendus() -> void:
	feq(GameConfig.BATTLEFIELD_WIDTH, TERRAIN, "le terrain fait 1080 px de large")
	feq(Fx.MECH_LABEL_MARGIN, MARGE, "marge de la legende")


## Bords GLOBAUX de la boite (repere du terrain) pour un monstre en `x`.
func _bords(x: float, large: float) -> Vector2:
	var gauche: float = x + Fx.caption_box_x(x, large)
	return Vector2(gauche, gauche + large)


func _test_au_milieu_la_boite_reste_centree() -> void:
	feq(Fx.caption_box_x(540.0, 420.0), -210.0, "au centre : boite centree sur le monstre")
	feq(Fx.caption_box_x(300.0, 300.0), -150.0, "loin des bords : boite centree")
	# Juste a la limite : centree, et deja a la marge.
	var b: Vector2 = _bords(234.0, 420.0)
	feq(b.x, 24.0, "a la limite gauche, rien ne bouge")


func _test_au_bord_gauche_la_boite_est_ramenee() -> void:
	for x in [0.0, 30.0, 60.0, 120.0, 200.0]:
		var b: Vector2 = _bords(x, 420.0)
		ok(b.x >= 24.0 - 0.01, "monstre en x=%d : bord gauche %.1f >= 24" % [int(x), b.x])
		ok(b.y <= 1056.0 + 0.01, "monstre en x=%d : bord droit dans le terrain" % int(x))
		feq(b.x, 24.0, "monstre en x=%d : boite collee a la marge gauche" % int(x), 0.01)
	# Une legende COURTE reste pres de son monstre : on ne la ramene que de ce
	# qu il faut.
	var courte: Vector2 = _bords(60.0, 160.0)
	feq(courte.x, 24.0, "legende courte : collee a la marge")
	feq((courte.x + courte.y) * 0.5, 104.0, "legende courte : centre au plus pres du monstre")


func _test_au_bord_droit_la_boite_est_ramenee() -> void:
	for x in [1080.0, 1050.0, 1020.0, 960.0, 880.0]:
		var b: Vector2 = _bords(x, 420.0)
		ok(b.y <= 1056.0 + 0.01, "monstre en x=%d : bord droit %.1f <= 1056" % [int(x), b.y])
		ok(b.x >= 24.0 - 0.01, "monstre en x=%d : bord gauche dans le terrain" % int(x))
		feq(b.y, 1056.0, "monstre en x=%d : boite collee a la marge droite" % int(x), 0.01)


func _test_une_boite_plus_large_que_le_terrain_se_centre() -> void:
	var b: Vector2 = _bords(100.0, 1200.0)
	feq((b.x + b.y) * 0.5, 540.0, "boite trop large : centree sur le terrain")


## Le chemin du jeu : une legende ENFANT du monstre, resserree sur son contenu
## (ici un controle de 300 px minimum, comme un texte) et ramenee quand le
## monstre est colle a un bord. Rappelee quand il bouge : elle suit.
func _test_fit_caption_resserre_et_ramene() -> void:
	var monstre := Node2D.new()
	var legende := Control.new()
	legende.custom_minimum_size = Vector2(300.0, 40.0)
	legende.size = Vector2(420.0, 150.0)
	legende.position = Vector2(-210.0, -200.0)
	monstre.add_child(legende)
	attach(monstre)
	for x in [20.0, 540.0, 1060.0]:
		monstre.position = Vector2(x, 800.0)
		Fx.fit_caption(legende, monstre)
		feq(legende.size.x, 300.0, "x=%d : la boite se resserre sur son contenu" % int(x))
		var gauche: float = monstre.position.x + legende.position.x
		var droite: float = gauche + legende.size.x
		ok(gauche >= 24.0 - 0.01 and droite <= 1056.0 + 0.01,
			"x=%d : legende [%.1f, %.1f] dans le terrain, a la marge" % [int(x), gauche, droite])
		feq(legende.position.y, -200.0, "x=%d : la hauteur n est pas touchee" % int(x))
	monstre.position = Vector2(540.0, 800.0)
	Fx.fit_caption(legende, monstre)
	feq(legende.position.x, -150.0, "au centre : legende centree sur le monstre")
	detach(monstre)
