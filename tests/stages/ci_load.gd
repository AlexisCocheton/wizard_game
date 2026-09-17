extends StageRunner
## ETAGE CI-LOAD — toute ressource .tscn/.tres se charge, toute scene s'instancie.

const SKIP_DIRS: Array[String] = [".godot", ".claude"]

var _checked: int = 0


func stage_name() -> String:
	return "CI-LOAD"


func run_stage() -> void:
	var files: Array[String] = []
	_scan("res://", files)
	for path in files:
		_checked += 1
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			fail("%s : load() a renvoye null" % path)
			continue
		if res is PackedScene:
			var inst: Node = (res as PackedScene).instantiate()
			if inst == null:
				fail("%s : instantiate() a renvoye null" % path)
			else:
				inst.free()
	print("[CI-LOAD] %d ressources verifiees" % _checked)


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
		elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
