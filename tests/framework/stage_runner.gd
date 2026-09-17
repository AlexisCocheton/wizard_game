class_name StageRunner
extends Node
## Socle commun des etages executes comme SCENE PRINCIPALE (et non via --script).
##
## Pourquoi une scene et pas --script : verifie sur 4.4.stable, le mode --script
## n'enregistre PAS les singletons d'autoload. Tout script nommant GameConfig,
## SpeedGauge ou RunState echoue alors a la COMPILATION, pas seulement au runtime.
## Booter une scene principale donne les autoloads deja prets, exactement comme
## dans le vrai jeu.

var _failures: Array[String] = []


func _ready() -> void:
	# Laisse les autoloads finir leur _ready() avant de commencer.
	await get_tree().process_frame
	run_stage()
	finish()


## A surcharger par chaque etage.
func run_stage() -> void:
	pass


func stage_name() -> String:
	return "STAGE"


func fail(message: String) -> void:
	_failures.append(message)


func failures() -> Array[String]:
	return _failures


func finish() -> void:
	var tag: String = stage_name()
	if _failures.is_empty():
		print("[%s] OK" % tag)
		_quit(0)
		return
	for f in _failures:
		printerr("[%s] %s" % [tag, f])
	print("[%s] %d echec(s)" % [tag, _failures.size()])
	_quit(1)


func _quit(code: int) -> void:
	get_tree().quit(code)
