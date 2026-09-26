class_name TestCase
extends RefCounted
## Mini-framework d'assertions. Les echecs partent sur stderr (printerr) pour que
## la gate stderr du harnais et le code de sortie soient toujours d'accord.

var suite_name: String = ""
var _failures: Array[String] = []
var _checks: int = 0


## Nom affiche de la suite. A surcharger.
func get_suite_name() -> String:
	return "unnamed"


## Corps de la suite. A surcharger.
func run() -> void:
	pass


## Remet la jauge a NEUF ET la ramene au temps normal (x1).
##
## Depuis que la vitesse EST la vie (26 septembre), SpeedGauge.reset() repart a
## GameConfig.SPEED_START_PERCENT et non a 100 % : a 100 % le mage serait deja
## mort, une partie ne peut pas commencer la. Toutes les suites qui mesurent
## autre chose que la vitesse — pioche, XP, temps d incantation, seuils de
## passifs — veulent en revanche un monde a x1, sinon leurs nombres sont
## multiplies par 2,5 sans qu elles le sachent.
##
## Le helper porte ce que le test VEUT dire ("je mesure au temps normal") au
## lieu de repeter un reglage ; si le depart bouge, rien ici ne bouge.
func reset_gauge_at_normal_speed() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(100)


## Remet la jauge a neuf, au temps normal, et met le mage HORS DE PORTEE de la
## mort le temps du test.
##
## Depuis que la vitesse EST la vie, "monde a x1" veut dire "mage a 100 %",
## c est-a-dire pile sur le plancher mortel : le premier projectile le tue,
## is_dying s allume, world_delta tombe au ralenti et TOUT le reste du test
## mesure un monde au quart de sa vitesse. Le symptome est traitre — un boss qui
## "n arrive pas a sa ligne de tir" alors que le vrai coupable est la mort du
## mage trois secondes plus tot.
##
## Les suites de comportement (deplacements, cadences, portees) ne parlent pas
## de la survie du mage : elles lui donnent donc une reserve, et acceptent que
## le monde tourne a la vitesse correspondante. C est le prix d une mecanique ou
## la vie et l horloge sont le meme nombre, et il vaut mieux l ecrire une fois
## ici que le redecouvrir suite par suite.
func reset_gauge_with_survivable_mage() -> void:
	SpeedGauge.reset()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_START_PERCENT)


func ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func not_ok(condition: bool, message: String) -> void:
	ok(not condition, message)


func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	ok(actual == expected, "%s — attendu %s, obtenu %s" % [message, expected, actual])


func feq(actual: float, expected: float, message: String = "", eps: float = 0.0001) -> void:
	ok(absf(actual - expected) <= eps,
		"%s — attendu ~%f, obtenu %f" % [message, expected, actual])


func between(value: float, low: float, high: float, message: String = "") -> void:
	ok(value >= low and value <= high,
		"%s — attendu entre %f et %f, obtenu %f" % [message, low, high, value])


## Ajoute un noeud a la racine de l arbre pour que _ready() s execute.
func attach(node: Node) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(node)


func detach(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func failures() -> Array[String]:
	return _failures


func check_count() -> int:
	return _checks
