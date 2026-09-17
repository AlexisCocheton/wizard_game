extends TestCase
## Decoupe des spritesheets : le nombre de cases doit correspondre aux feuilles.

func get_suite_name() -> String:
	return "sheet_lib"


func run() -> void:
	_test_bande()
	_test_grille()
	_test_catalogue()
	_test_cache()


func _test_bande() -> void:
	var tex: Texture2D = SheetLib.texture("res://assets/units/pawn_red_walk.png")
	ok(tex != null, "la feuille du pion existe")
	eq(SheetLib.strip_count(tex, 192), 6, "Pawn_Run : 6 cases de 192")
	var monk: Texture2D = SheetLib.texture("res://assets/units/monk_blue_cast.png")
	eq(SheetLib.strip_count(monk, 192), 11, "Monk Heal : 11 cases")


func _test_grille() -> void:
	var tex: Texture2D = SheetLib.texture("res://assets/fx/magickahit.png")
	eq(SheetLib.grid(tex, 100).size(), 49, "magickahit : 7x7 cases")
	var frz: Texture2D = SheetLib.texture("res://assets/fx/freezing.png")
	eq(SheetLib.grid(frz, 100).size(), 100, "freezing : 10x10 cases")


func _test_catalogue() -> void:
	var sf: SpriteFrames = AnimCatalog.frames(&"archer_red")
	ok(sf != null, "frames de l archer")
	ok(sf.has_animation("walk") and sf.has_animation("attack"), "walk et attack presents")
	eq(sf.get_frame_count("attack"), 8, "Archer_Shoot : 8 cases")
	ok(AnimCatalog.is_static(&"totem_tower"), "le totem est une texture fixe")
	ok(AnimCatalog.static_texture(&"totem_tower") != null, "et elle se charge")
	for e: EnemyDef in ContentDB.enemies.values():
		ok(AnimCatalog.has(e.anim_key), "%s a une feuille (%s)" % [e.id, e.anim_key])


func _test_cache() -> void:
	var a: SpriteFrames = AnimCatalog.frames(&"blood")
	var b: SpriteFrames = AnimCatalog.frames(&"blood")
	ok(a == b, "le cache renvoie la meme instance")
