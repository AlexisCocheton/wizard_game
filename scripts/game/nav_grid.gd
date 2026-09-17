class_name NavGrid
extends RefCounted
## Grille de navigation A* du champ de bataille.
##
## Les monstres descendent du haut vers la ligne du mage. Un mur pose par une carte
## bloque des cellules : le chemin est alors recalcule pour le contourner.
##
## Logique pure (aucun noeud, aucun rendu) : l etage UNIT peut la tester a froid.
## Resolution volontairement grossiere (cellules de 60 px) : on veut un contournement
## lisible a l ecran, pas une precision au pixel qui couterait cher en CPU.

const CELL_SIZE: float = 60.0

## 8 directions : le contournement diagonal evite les trajectoires en escalier.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var cols: int = 0
var rows: int = 0
## Cellules bloquees -> nombre de murs qui les occupent (plusieurs murs peuvent
## se chevaucher ; on compte pour ne pas debloquer trop tot a l expiration).
var _blocked: Dictionary = {}
## Cache des chemins, invalide des qu un mur apparait ou disparait.
var _version: int = 0


func _init(width: float = GameConfig.BATTLEFIELD_WIDTH,
		height: float = GameConfig.BATTLEFIELD_HEIGHT) -> void:
	cols = int(ceil(width / CELL_SIZE))
	rows = int(ceil(height / CELL_SIZE))


func version() -> int:
	return _version


func to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))


func to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.get(cell, 0) > 0


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not is_blocked(cell)


## Bloque un segment horizontal de cellules. Renvoie les cellules effectivement
## occupees, pour pouvoir les liberer exactement a l expiration du mur.
func block_rect(center: Vector2, half_width: float, thickness: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var left: int = int(floor((center.x - half_width) / CELL_SIZE))
	var right: int = int(floor((center.x + half_width) / CELL_SIZE))
	var top: int = int(floor((center.y - thickness * 0.5) / CELL_SIZE))
	var bottom: int = int(floor((center.y + thickness * 0.5) / CELL_SIZE))
	for cx in range(left, right + 1):
		for cy in range(top, bottom + 1):
			var cell := Vector2i(cx, cy)
			if not in_bounds(cell):
				continue
			_blocked[cell] = _blocked.get(cell, 0) + 1
			out.append(cell)
	if not out.is_empty():
		_version += 1
	return out


func unblock_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var n: int = _blocked.get(cell, 0) - 1
		if n <= 0:
			_blocked.erase(cell)
		else:
			_blocked[cell] = n
	if not cells.is_empty():
		_version += 1


func clear() -> void:
	_blocked.clear()
	_version += 1


func blocked_count() -> int:
	return _blocked.size()


## A* de `from` vers la ligne du mage (n importe quelle colonne de `goal_row`).
## Renvoie une liste de positions monde, vide si aucun chemin n existe.
func find_path(from: Vector2, goal_row: int = -1) -> Array[Vector2]:
	var start: Vector2i = to_cell(from)
	var target_row: int = goal_row if goal_row >= 0 else int(floor(GameConfig.MAGE_LINE_Y / CELL_SIZE))
	target_row = clampi(target_row, 0, rows - 1)

	# Depart hors grille (spawn au-dessus de l ecran) : on entre par la colonne courante.
	if not in_bounds(start):
		start = Vector2i(clampi(start.x, 0, cols - 1), clampi(start.y, 0, rows - 1))
	if start.y >= target_row:
		return []

	var open: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var f_score: Dictionary = {start: float(target_row - start.y)}
	var closed: Dictionary = {}
	# Garde-fou : une grille 18x32 fait ~576 cellules ; au-dela on abandonne.
	var budget: int = cols * rows + 64

	while not open.is_empty() and budget > 0:
		budget -= 1
		var current: Vector2i = _pop_lowest(open, f_score)
		if current.y >= target_row:
			return _rebuild(came_from, current)
		closed[current] = true

		for step in NEIGHBORS:
			var next: Vector2i = current + step
			if closed.has(next) or not is_walkable(next):
				continue
			# Interdit de couper un angle entre deux murs en diagonale.
			if step.x != 0 and step.y != 0:
				if is_blocked(Vector2i(current.x + step.x, current.y)) \
						and is_blocked(Vector2i(current.x, current.y + step.y)):
					continue
			var cost: float = 1.0 if (step.x == 0 or step.y == 0) else 1.4142
			var tentative: float = float(g_score.get(current, INF)) + cost
			if tentative >= float(g_score.get(next, INF)):
				continue
			came_from[next] = current
			g_score[next] = tentative
			# Heuristique : distance verticale restante (admissible, on descend).
			f_score[next] = tentative + float(maxi(0, target_row - next.y))
			if not open.has(next):
				open.append(next)
	return []


func _pop_lowest(open: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best_i: int = 0
	var best: float = float(f_score.get(open[0], INF))
	for i in range(1, open.size()):
		var f: float = float(f_score.get(open[i], INF))
		if f < best:
			best = f
			best_i = i
	var cell: Vector2i = open[best_i]
	open.remove_at(best_i)
	return cell


func _rebuild(came_from: Dictionary, end: Vector2i) -> Array[Vector2]:
	var cells: Array[Vector2i] = [end]
	var cur: Vector2i = end
	while came_from.has(cur):
		cur = came_from[cur]
		cells.append(cur)
	cells.reverse()
	var out: Array[Vector2] = []
	# On saute la cellule de depart : le monstre y est deja.
	for i in range(1, cells.size()):
		out.append(to_world(cells[i]))
	return out
