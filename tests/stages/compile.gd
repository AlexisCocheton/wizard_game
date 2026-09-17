extends StageRunner
## ETAGE COMPILE — les scripts doivent reellement COMPILER.
##
## Verifie sur 4.4.stable : load() renvoie un objet NON-NULL pour un script en
## erreur de parse, et le process sort avec le code 0. Tester "!= null" donnerait
## un faux vert. L'oracle fiable est can_instantiate().

const SKIP_DIRS: Array[String] = [".godot", ".claude"]

## Scripts dont can_instantiate() vaut legitimement false.
const ALLOW_NON_INSTANTIABLE: Array[String] = []

var _checked: int = 0


func stage_name() -> String:
	return "COMPILE"


func run_stage() -> void:
	var files: Array[String] = []
	_scan("res://", files)
	for path in files:
		_checked += 1
		var script: Resource = load(path)
		if script == null:
			fail("%s : load() a renvoye null" % path)
			continue
		if script is GDScript:
			var gd: GDScript = script as GDScript
			if not gd.can_instantiate() and path not in ALLOW_NON_INSTANTIABLE:
				fail("%s : COMPILATION ECHOUEE (can_instantiate false)" % path)
	print("[COMPILE] %d scripts verifies" % _checked)


func _scan(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry not in SKIP_DIRS:
				_scan(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
