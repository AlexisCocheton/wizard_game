extends Control
## Apercu de visee pendant le glisser-deposer d une carte, compose d assets :
##   zone -> cercle de protection (Free Pixel Effects) a l echelle du vrai rayon
##   mur  -> rangee de rochers Tiny Swords
##   ligne -> fleches Tiny Swords en enfilade depuis le mage
##   cible -> croix de la feuille magickahit
## Purement visuel : aucune regle de jeu ici.

var card: SpellCard = null
var aim_point: Vector2 = Vector2.ZERO
var valid: bool = false
var wall_half_width: float = 0.0
var zone_radius: float = 0.0

const COL_OK := Color(1.0, 1.0, 1.0, 0.75)
const COL_BAD := Color(1.0, 0.45, 0.45, 0.6)

var _circle: Texture2D = null
var _arrow: Texture2D = null
var _rocks: Array[Texture2D] = []
var _cross: Texture2D = null


func _ready() -> void:
	var circ: Texture2D = SheetLib.texture("res://assets/fx/protectioncircle.png")
	if circ != null:
		var frames: Array[Texture2D] = SheetLib.grid(circ, 100)
		if frames.size() > 20:
			_circle = frames[20]
	_arrow = SheetLib.texture("res://assets/fx/arrow.png")
	for i in range(1, 5):
		var t: Texture2D = SheetLib.texture("res://assets/terrain/rock%d.png" % i)
		if t != null:
			_rocks.append(t)
	var hit: Texture2D = SheetLib.texture("res://assets/fx/magickahit.png")
	if hit != null:
		var frames: Array[Texture2D] = SheetLib.grid(hit, 100)
		if frames.size() > 10:
			_cross = frames[10]


func show_aim(c: SpellCard, point: Vector2, is_valid: bool) -> void:
	card = c
	aim_point = point
	valid = is_valid
	_read_shape()
	visible = true
	queue_redraw()


func hide_aim() -> void:
	card = null
	visible = false
	queue_redraw()


## Lit le rayon / la largeur directement dans les effets de la carte :
## l apercu reflete les vraies valeurs, pas une estimation.
func _read_shape() -> void:
	zone_radius = 0.0
	wall_half_width = 0.0
	if card == null:
		return
	for spec in card.effects:
		if spec == null:
			continue
		if spec.key == &"build_wall":
			wall_half_width = maxf(spec.radius, 60.0)
		elif spec.key == &"ground_zone" or spec.key == &"damage_per_enemy":
			zone_radius = maxf(spec.radius, 10.0)


func _tex_centered(t: Texture2D, at: Vector2, size: Vector2, tint: Color) -> void:
	draw_texture_rect(t, Rect2(at - size * 0.5, size), false, tint)


func _draw() -> void:
	if card == null:
		return
	var col: Color = COL_OK if valid else COL_BAD

	if wall_half_width > 0.0 and not _rocks.is_empty():
		var step: float = 56.0
		var n: int = maxi(1, int(wall_half_width * 2.0 / step))
		for i in n:
			var at := aim_point + Vector2(-wall_half_width + step * 0.5 + i * step, 0.0)
			_tex_centered(_rocks[i % _rocks.size()], at, Vector2(64, 64), col)
		return

	if zone_radius > 0.0 and _circle != null:
		_tex_centered(_circle, aim_point, Vector2.ONE * zone_radius * 2.4, col)
		return

	match card.targeting:
		GameEnums.Targeting.DIRECTION:
			if _arrow == null:
				return
			var origin := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
			var d: Vector2 = aim_point - origin
			if d.length() < 1.0:
				return
			var dir: Vector2 = d.normalized()
			var count: int = int(GameConfig.BATTLEFIELD_HEIGHT / 90.0)
			for i in count:
				var at: Vector2 = origin + dir * (60.0 + i * 90.0)
				draw_set_transform(at, dir.angle(), Vector2(1.2, 1.2))
				draw_texture(_arrow, Vector2(-32, -32), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		GameEnums.Targeting.TARGET:
			if _cross != null:
				_tex_centered(_cross, aim_point, Vector2(160, 160), col)
		_:
			if _circle != null:
				_tex_centered(_circle, aim_point, Vector2(120, 120), col)
