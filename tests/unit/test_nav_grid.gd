extends TestCase
## Pathfinding A* : descente normale, contournement de mur, blocage total.

func get_suite_name() -> String:
	return "nav_grid"


func run() -> void:
	_test_conversion_cellules()
	_test_chemin_direct()
	_test_contournement_mur()
	_test_mur_complet_bloque()
	_test_liberation_mur()
	_test_murs_superposes()


func _test_conversion_cellules() -> void:
	var g := NavGrid.new()
	ok(g.cols > 0 and g.rows > 0, "la grille a des dimensions")
	var cell: Vector2i = g.to_cell(Vector2(130.0, 250.0))
	eq(cell, Vector2i(2, 4), "position monde -> cellule")
	var back: Vector2 = g.to_world(cell)
	ok(absf(back.x - 150.0) < 0.01, "cellule -> centre monde en x")
	ok(g.is_walkable(Vector2i(3, 3)), "cellule libre praticable")
	not_ok(g.is_walkable(Vector2i(-1, 3)), "hors grille non praticable")


func _test_chemin_direct() -> void:
	var g := NavGrid.new()
	var path: Array[Vector2] = g.find_path(Vector2(540.0, 100.0))
	ok(path.size() > 0, "un chemin existe sans obstacle")
	var last: Vector2 = path[path.size() - 1]
	ok(last.y >= GameConfig.MAGE_LINE_Y - NavGrid.CELL_SIZE,
		"le chemin atteint la ligne du mage")
	# Sans obstacle, la descente reste dans la meme colonne.
	var start_x: float = 540.0
	var max_ecart: float = 0.0
	for p in path:
		max_ecart = maxf(max_ecart, absf(p.x - start_x))
	ok(max_ecart <= NavGrid.CELL_SIZE, "descente droite sans obstacle")


## Le coeur de la feature : un mur doit devier la trajectoire, pas l arreter.
func _test_contournement_mur() -> void:
	var g := NavGrid.new()
	var start := Vector2(540.0, 300.0)

	var sans_mur: Array[Vector2] = g.find_path(start)
	ok(sans_mur.size() > 0, "chemin avant le mur")

	# Mur centre sur la trajectoire, mais laissant les bords libres.
	var cells: Array[Vector2i] = g.block_rect(Vector2(540.0, 700.0), 240.0, 60.0)
	ok(cells.size() > 0, "le mur occupe des cellules")

	var avec_mur: Array[Vector2] = g.find_path(start)
	ok(avec_mur.size() > 0, "un chemin existe encore : le mur est contourne")

	# La trajectoire doit s ecarter lateralement pour passer.
	var ecart_max: float = 0.0
	for p in avec_mur:
		ecart_max = maxf(ecart_max, absf(p.x - start.x))
	ok(ecart_max > NavGrid.CELL_SIZE, "la trajectoire s ecarte pour contourner")

	# Aucun point du chemin ne traverse une cellule bloquee.
	var traverse: bool = false
	for p in avec_mur:
		if g.is_blocked(g.to_cell(p)):
			traverse = true
	not_ok(traverse, "le chemin ne traverse aucune cellule bloquee")


func _test_mur_complet_bloque() -> void:
	var g := NavGrid.new()
	# Mur couvrant toute la largeur : plus aucun passage.
	g.block_rect(Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, 700.0),
		GameConfig.BATTLEFIELD_WIDTH, 60.0)
	var path: Array[Vector2] = g.find_path(Vector2(540.0, 300.0))
	eq(path.size(), 0, "aucun chemin si toute la largeur est bloquee")


func _test_liberation_mur() -> void:
	var g := NavGrid.new()
	var avant: int = g.blocked_count()
	var cells: Array[Vector2i] = g.block_rect(Vector2(540.0, 700.0), 240.0, 60.0)
	ok(g.blocked_count() > avant, "le mur bloque des cellules")
	var v: int = g.version()
	g.unblock_cells(cells)
	eq(g.blocked_count(), avant, "toutes les cellules sont liberees a l expiration")
	ok(g.version() > v, "la version change pour invalider les chemins en cache")


## Deux murs qui se chevauchent : liberer l un ne doit pas debloquer l autre.
func _test_murs_superposes() -> void:
	var g := NavGrid.new()
	var a: Array[Vector2i] = g.block_rect(Vector2(540.0, 700.0), 120.0, 60.0)
	var b: Array[Vector2i] = g.block_rect(Vector2(540.0, 700.0), 120.0, 60.0)
	ok(g.blocked_count() > 0, "les deux murs occupent la zone")
	g.unblock_cells(a)
	ok(g.blocked_count() > 0, "la zone reste bloquee tant que le second mur vit")
	g.unblock_cells(b)
	eq(g.blocked_count(), 0, "zone liberee quand les deux murs ont expire")
