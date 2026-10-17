extends TestCase
## LEGENDE AU-DESSUS DES MONSTRES (vague 10, chantier C1) : la boite de
## Fx.mech_label (420 px centres sur le monstre) n etait jamais ramenee dans le
## cadre ; pres du bord gauche ou droit, la legende etait coupee (capture du
## 17/10, « GARDE : les coups glissent »). Elle est ramenee dans le terrain
## VISIBLE, resserree sur son contenu : a droite jusqu a 24 px du bord, a
## gauche jusqu au bord de la jauge de vitesse du HUD, qui couvre le terrain.
##
## Bornes ecrites EN DUR (voir gotchas : un test qui relit la constante qu il
## contraint passe toujours) : terrain de 1080 px, legende entre 96 et 1056 px.
## La marge gauche est confrontee a la VRAIE jauge, relue dans HUD.tscn.
## Sabotage verifie : caption_box_x rendant la boite centree sans la ramener ->
## 25 echecs.

const TERRAIN: float = 1080.0
const BORD_GAUCHE: float = 96.0
const BORD_DROIT: float = 1056.0


func get_suite_name() -> String:
	return "mech_label_clamp"


func run() -> void:
	_test_les_reglages_attendus()
	_test_la_marge_gauche_degage_la_jauge_de_vitesse()
	_test_au_milieu_la_boite_reste_centree()
	_test_au_bord_gauche_la_boite_est_ramenee()
	_test_au_bord_droit_la_boite_est_ramenee()
	_test_une_boite_plus_large_que_le_terrain_se_centre()
	_test_fit_caption_resserre_et_ramene()


func _test_les_reglages_attendus() -> void:
	feq(GameConfig.BATTLEFIELD_WIDTH, TERRAIN, "le terrain fait 1080 px de large")
	feq(Fx.MECH_LABEL_MARGIN_LEFT, BORD_GAUCHE, "marge gauche de la legende")
	feq(TERRAIN - Fx.MECH_LABEL_MARGIN, BORD_DROIT, "marge droite de la legende")


## La jauge de vitesse (EnemyBar, tournee) couvre le bord gauche du terrain : sa
## limite droite, calculee depuis la scene du HUD, doit rester a gauche de la
## marge des legendes, avec du jour entre les deux.
func _test_la_marge_gauche_degage_la_jauge_de_vitesse() -> void:
	var packed: PackedScene = load("res://scenes/hud/HUD.tscn")
	ok(packed != null, "HUD.tscn se charge")
	if packed == null:
		return
	var hud: Node = packed.instantiate()
	var jauge: Control = hud.get_node_or_null("Root/EnemyBar") as Control
	ok(jauge != null, "la jauge de vitesse est dans le HUD (Root/EnemyBar)")
	if jauge != null:
		# Hors de l arbre (son _ready brancherait la partie) : la geometrie se lit
		# sur ses offsets, sa rotation et son pivot, tels que la scene les pose.
		var taille := Vector2(jauge.offset_right - jauge.offset_left,
			jauge.offset_bottom - jauge.offset_top)
		var origine := Vector2(jauge.offset_left, jauge.offset_top)
		var t := Transform2D(jauge.rotation, jauge.scale, 0.0, origine + jauge.pivot_offset)
		var droite: float = -1e9
		for coin in [Vector2.ZERO, Vector2(taille.x, 0.0), Vector2(0.0, taille.y), taille]:
			droite = maxf(droite, (t * ((coin as Vector2) - jauge.pivot_offset)).x)
		ok(droite > 40.0, "la jauge occupe bien le bord gauche (bord droit a %.0f px)" % droite)
		ok(Fx.MECH_LABEL_MARGIN_LEFT >= droite + 8.0,
			"la legende s arrete a droite de la jauge (%.0f px) : marge %.0f"
			% [droite, Fx.MECH_LABEL_MARGIN_LEFT])
	hud.free()


## Bords GLOBAUX de la boite (repere du terrain) pour un monstre en `x`.
func _bords(x: float, large: float) -> Vector2:
	var gauche: float = x + Fx.caption_box_x(x, large)
	return Vector2(gauche, gauche + large)


func _test_au_milieu_la_boite_reste_centree() -> void:
	feq(Fx.caption_box_x(540.0, 420.0), -210.0, "au centre : boite centree sur le monstre")
	feq(Fx.caption_box_x(400.0, 300.0), -150.0, "loin des bords : boite centree")
	# Juste a la limite : centree, et deja a la marge.
	var b: Vector2 = _bords(306.0, 420.0)
	feq(b.x, 96.0, "a la limite gauche, rien ne bouge")


func _test_au_bord_gauche_la_boite_est_ramenee() -> void:
	for x in [0.0, 30.0, 60.0, 120.0, 200.0]:
		var b: Vector2 = _bords(x, 420.0)
		ok(b.x >= 96.0 - 0.01, "monstre en x=%d : bord gauche %.1f >= 96" % [int(x), b.x])
		ok(b.y <= 1056.0 + 0.01, "monstre en x=%d : bord droit dans le terrain" % int(x))
		feq(b.x, 96.0, "monstre en x=%d : boite collee a la marge gauche" % int(x), 0.01)
	# Une legende COURTE reste pres de son monstre : on ne la ramene que de ce
	# qu il faut.
	var courte: Vector2 = _bords(60.0, 160.0)
	feq(courte.x, 96.0, "legende courte : collee a la marge")
	feq((courte.x + courte.y) * 0.5, 176.0, "legende courte : centre au plus pres du monstre")


func _test_au_bord_droit_la_boite_est_ramenee() -> void:
	for x in [1080.0, 1050.0, 1020.0, 960.0, 880.0]:
		var b: Vector2 = _bords(x, 420.0)
		ok(b.y <= 1056.0 + 0.01, "monstre en x=%d : bord droit %.1f <= 1056" % [int(x), b.y])
		ok(b.x >= 96.0 - 0.01, "monstre en x=%d : bord gauche dans le terrain" % int(x))
		feq(b.y, 1056.0, "monstre en x=%d : boite collee a la marge droite" % int(x), 0.01)


func _test_une_boite_plus_large_que_le_terrain_se_centre() -> void:
	var b: Vector2 = _bords(100.0, 1200.0)
	feq((b.x + b.y) * 0.5, 576.0, "boite trop large : centree entre les deux marges")


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
		ok(gauche >= 96.0 - 0.01 and droite <= 1056.0 + 0.01,
			"x=%d : legende [%.1f, %.1f] dans le terrain visible" % [int(x), gauche, droite])
		feq(legende.position.y, -200.0, "x=%d : la hauteur n est pas touchee" % int(x))
	monstre.position = Vector2(540.0, 800.0)
	Fx.fit_caption(legende, monstre)
	feq(legende.position.x, -150.0, "au centre : legende centree sur le monstre")
	detach(monstre)
