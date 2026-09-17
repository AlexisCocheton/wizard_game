class_name EnemyBody
extends Node2D
## Apparence de secours d un monstre SANS feuille animee (anim_key vide) :
## une forme et une couleur. Tout le contenu livre a une anim_key ; ce repli ne
## sert qu aux tests et a un futur monstre pas encore habille.

var def: EnemyDef = null
var shield_up: bool = false
var growth: float = 1.0
var draw_shape: bool = true


func setup(d: EnemyDef, shield: bool) -> void:
	def = d
	shield_up = shield
	queue_redraw()


func set_shield(v: bool) -> void:
	shield_up = v
	queue_redraw()


func set_growth(v: float) -> void:
	growth = v
	queue_redraw()


func radius() -> float:
	if def == null:
		return 32.0
	return def.base_radius * growth


func _draw() -> void:
	if def == null or not draw_shape:
		return
	var r: float = radius()
	var col: Color = def.color
	if def.sprite != null:
		var size: Vector2 = def.sprite.get_size()
		var scale_f: float = (r * 2.0) / maxf(size.x, size.y)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_f, scale_f))
		draw_texture(def.sprite, -size * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match def.shape:
		GameEnums.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, r, col)
		GameEnums.Shape.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r, r * 0.85), Vector2(-r, r * 0.85)]), col)
		_:
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
	if shield_up:
		draw_arc(Vector2.ZERO, r + 10.0, 0.0, TAU, 40, Color(0.92, 0.94, 1.0, 0.9), 5.0)
	if def.aura_shield_radius > 0.0:
		draw_arc(Vector2.ZERO, def.aura_shield_radius, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.35), 4.0)
