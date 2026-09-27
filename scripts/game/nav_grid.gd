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


## Nombre d objets qui bloquent cette cellule (0 = libre).
func block_count(cell: Vector2i) -> int:
	return int(_blocked.get(cell, 0))


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


## Cellules que `block_rect()` occuperait, SANS rien bloquer. C est la meme
## decoupe, pour que la verification de chemin faite avant la pose juge exactement
## les cellules que la pose bloquera ensuite — deux calculs voisins finiraient par
## diverger d une cellule au bord et le garde-fou mentirait.
func rect_cells(center: Vector2, half_width: float, thickness: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var left: int = int(floor((center.x - half_width) / CELL_SIZE))
	var right: int = int(floor((center.x + half_width) / CELL_SIZE))
	var top: int = int(floor((center.y - thickness * 0.5) / CELL_SIZE))
	var bottom: int = int(floor((center.y + thickness * 0.5) / CELL_SIZE))
	for cx in range(left, right + 1):
		for cy in range(top, bottom + 1):
			var cell := Vector2i(cx, cy)
			if in_bounds(cell):
				out.append(cell)
	return out


## Bloque une liste de cellules deja calculee (la riviere : toute une rangee
## moins le pont). Meme comptage que `block_rect()`.
func block_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_blocked[cell] = _blocked.get(cell, 0) + 1
	if not cells.is_empty():
		_version += 1


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


# --- GARANTIE DE CHEMIN (sorts de terrain permanents) ---
#
# Un objet qui bloque ne doit JAMAIS couper tout chemin des monstres au sol vers
# le mage. Avec des murs de 20 s, un bouclage n etait qu un contretemps : le mur
# expirait. Avec une riviere qui dure toute la bataille, un bouclage fige la vague
# pour toujours — les monstres enfermes ne frappent que les MURS, pas l eau — et
# une partie de Massacre ne se terminerait plus jamais.
#
# D ou une question posee AVANT la pose, jamais apres : poser puis retirer
# laisserait le joueur payer une carte pour rien, et un objet qui disparait tout
# seul se lirait comme un bug.


## Rangee a atteindre : celle de la ligne du mage, comme `find_path()`.
func goal_row() -> int:
	return clampi(int(floor(GameConfig.MAGE_LINE_Y / CELL_SIZE)), 0, rows - 1)


## Rangee d apparition des monstres, bornee a la grille.
func spawn_row() -> int:
	return clampi(int(floor(GameConfig.SPAWN_LINE_Y / CELL_SIZE)), 0, rows - 1)


## Cellules a considerer comme LIBEREES pendant une verification (cellule ->
## nombre de blocages retires). Sert a juger une nouvelle riviere comme si
## l ancienne, qu elle va remplacer, etait deja partie — sans toucher a la grille
## ni a `version()`, ce qui ferait recalculer le chemin de tous les monstres a
## chaque mouvement du doigt pendant la visee. Rempli puis vide par `keeps_path`.
var _freed: Dictionary = {}


func _blocked_with(cell: Vector2i, extra: Dictionary) -> bool:
	if extra.has(cell):
		return true
	return int(_blocked.get(cell, 0)) - int(_freed.get(cell, 0)) > 0


## Toutes les cellules d ou l on peut ATTEINDRE la ligne du mage, en supposant
## bloquees en plus les cellules de `extra` (cle = Vector2i).
##
## Parcours en largeur INVERSE, parti de la ligne du mage : une seule passe repond
## pour toutes les colonnes d apparition et tous les monstres deja en jeu, la ou
## un A* par source coute autant de recherches que de sources. La regle de l angle
## (pas de diagonale entre deux cellules bloquees) est symetrique, donc le
## parcours a rebours juge exactement les pas que `find_path()` s autorise.
func reachable_to_goal(extra: Dictionary = {}) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	var cible: int = goal_row()
	for cy in range(cible, rows):
		for cx in cols:
			var c := Vector2i(cx, cy)
			if not _blocked_with(c, extra):
				seen[c] = true
				queue.append(c)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for step in NEIGHBORS:
			var nxt: Vector2i = cur + step
			if seen.has(nxt) or not in_bounds(nxt) or _blocked_with(nxt, extra):
				continue
			if step.x != 0 and step.y != 0:
				if _blocked_with(Vector2i(cur.x + step.x, cur.y), extra) \
						and _blocked_with(Vector2i(cur.x, cur.y + step.y), extra):
					continue
			seen[nxt] = true
			queue.append(nxt)
	return seen


## Une source relie-t-elle la ligne du mage ? Une source BLOQUEE (monstre debout
## sur une cellule qu on vient de murer, colonne d apparition sous un mur) n est
## pas perdue pour autant : `find_path()` part de la cellule ou il se trouve, donc
## il suffit qu un voisin libre soit relie.
func _source_ok(cell: Vector2i, reach: Dictionary, extra: Dictionary) -> bool:
	if reach.has(cell):
		return true
	if not _blocked_with(cell, extra):
		return false
	for step in NEIGHBORS:
		if reach.has(cell + step):
			return true
	return false


## LA garantie. Vrai si, en bloquant en plus `extra_cells`, CHAQUE colonne
## d apparition et chaque position de `ground_positions` (les monstres au sol deja
## en jeu) garde un chemin vers le mage.
##
## Toutes les colonnes, pas seulement une : les monstres naissent a un x tire au
## hasard, et une seule colonne enfermee suffit a figer celui qui y apparait.
##
## `freed_cells` : blocages a considerer comme deja retires (l objet que le
## nouveau va remplacer).
func keeps_path(extra_cells: Array[Vector2i],
		ground_positions: Array[Vector2] = [],
		freed_cells: Array[Vector2i] = []) -> bool:
	var extra: Dictionary = {}
	for c in extra_cells:
		extra[c] = true
	_freed.clear()
	for f in freed_cells:
		_freed[f] = int(_freed.get(f, 0)) + 1
	var garde: bool = _keeps_path(extra, ground_positions)
	_freed.clear()
	return garde


func _keeps_path(extra: Dictionary, ground_positions: Array[Vector2]) -> bool:
	var reach: Dictionary = reachable_to_goal(extra)
	var ligne: int = spawn_row()
	for cx in cols:
		if not _source_ok(Vector2i(cx, ligne), reach, extra):
			return false
	var cible: int = goal_row()
	for pos in ground_positions:
		var cell: Vector2i = to_cell(pos)
		if not in_bounds(cell):
			cell = Vector2i(clampi(cell.x, 0, cols - 1), clampi(cell.y, 0, rows - 1))
		# Deja sur la ligne du mage ou au-dela : il n a plus de chemin a chercher.
		if cell.y >= cible:
			continue
		if not _source_ok(cell, reach, extra):
			return false
	return true


## Rangee de la riviere pour un point vise : celle du doigt, RAMENEE entre les
## bornes de GameConfig. Statique et pure, pour que l apercu de visee dessine la
## ligne exactement la ou la carte la posera.
static func river_row(y: float) -> int:
	var rangees: int = int(ceil(GameConfig.BATTLEFIELD_HEIGHT / CELL_SIZE))
	var haut: int = int(floor(GameConfig.SPAWN_LINE_Y / CELL_SIZE)) \
		+ GameConfig.RIVER_MIN_ROWS_BELOW_SPAWN
	var bas: int = int(floor(GameConfig.MAGE_LINE_Y / CELL_SIZE)) \
		- GameConfig.RIVER_MIN_ROWS_ABOVE_MAGE
	return clampi(int(floor(y / CELL_SIZE)), clampi(haut, 0, rangees - 1),
		clampi(bas, 0, rangees - 1))


## Centre vertical d une rangee, en pixels.
static func row_center_y(row: int) -> float:
	return (float(row) + 0.5) * CELL_SIZE


## Toutes les cellules d une rangee.
func row_cells(row: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if row < 0 or row >= rows:
		return out
	for cx in cols:
		out.append(Vector2i(cx, row))
	return out


## Le segment a -> b traverse-t-il une cellule bloquee ? Sert a la provocation :
## un monstre ne doit pas marcher sur l eau ni au travers d un mur pour rejoindre
## l arbre qui l attire. Echantillonne au tiers de cellule, assez fin pour ne pas
## sauter un coin, et gratuit quand rien n est bloque.
func segment_clear(a: Vector2, b: Vector2) -> bool:
	if _blocked.is_empty():
		return true
	var d: float = a.distance_to(b)
	var n: int = maxi(1, int(ceil(d / (CELL_SIZE / 3.0))))
	var depart: Vector2i = to_cell(a)
	for i in range(1, n + 1):
		var cell: Vector2i = to_cell(a.lerp(b, float(i) / float(n)))
		# La cellule de depart ne compte pas : un monstre pousse sur la berge
		# doit pouvoir en sortir.
		if cell != depart and is_blocked(cell):
			return false
	return true
