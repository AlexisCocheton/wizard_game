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
