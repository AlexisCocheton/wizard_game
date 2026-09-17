class_name ZoneRing
extends Node2D
## Anneau de portee d une zone au sol.
##
## Pourquoi il est TRACE et non pris dans une feuille : la seule feuille en forme
## d anneau du pack (protectioncircle) n occupe que 34 px de sa case. Etiree au
## rayon d une zone (180 px de rayon, 360 de diametre) elle subissait un
## agrandissement x10 et devenait une bouillie de gros pixels.
##
## Ce n est pas un "visuel dessine par le code" au sens de la regle d AUDIT :
## celle-ci interdit de remplacer un MONSTRE par une forme geometrique. Ici le
## trait EST l information — il dit exactement jusqu ou porte le sort, et il doit
## rester net a n importe quel rayon.

const SEGMENTS: int = 64
const THICKNESS: float = 5.0

var radius: float = 100.0
var tint: Color = Color.WHITE

var _phase: float = 0.0


func setup(r: float, col: Color) -> void:
	radius = maxf(r, 8.0)
	tint = col
	queue_redraw()


func _process(delta: float) -> void:
	# Lente respiration : la zone se distingue du decor sans attirer l oeil.
	_phase = fmod(_phase + delta * 1.6, TAU)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + 0.02 * sin(_phase)
	var r: float = radius * pulse

	# Interieur teinte, tres discret : il marque la surface couverte.
	draw_circle(Vector2.ZERO, r, Color(tint.r, tint.g, tint.b, 0.10))

	# Le bord, qui porte l information : jusqu ou le sort agit.
	var points: PackedVector2Array = PackedVector2Array()
	for i in SEGMENTS + 1:
		var a: float = TAU * float(i) / float(SEGMENTS)
		points.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(points, Color(tint.r, tint.g, tint.b, 0.85), THICKNESS, true)

	# Liseré interne plus clair : lisible sur l herbe comme sur le sable.
	var inner: PackedVector2Array = PackedVector2Array()
	for i in SEGMENTS + 1:
		var a: float = TAU * float(i) / float(SEGMENTS)
		inner.append(Vector2(cos(a), sin(a)) * (r - THICKNESS))
	draw_polyline(inner, Color(1.0, 1.0, 1.0, 0.30), 2.0, true)
