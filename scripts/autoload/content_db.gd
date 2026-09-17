extends Node
## Index de tout le contenu .tres. Source de verite unique pour l'etage AUDIT.

signal content_loaded()

var cards: Dictionary = {}       # StringName -> SpellCard
var enemies: Dictionary = {}     # StringName -> EnemyDef
var waves: Dictionary = {}       # StringName -> WaveDef
var levels: Dictionary = {}      # StringName -> LevelDef
var objectives: Dictionary = {}  # StringName -> ObjectiveDef

## Ids rencontres deux fois — l'AUDIT echoue dessus (ecrasement silencieux sinon).
var duplicate_ids: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	cards.clear()
	enemies.clear()
	waves.clear()
	levels.clear()
	objectives.clear()
	duplicate_ids.clear()
	_scan_dir("res://resources")
	discover_starters()
	content_loaded.emit()


## Les communes de depart sont connues d office : sans ca la galerie et le deck
## seraient vides a la premiere ouverture.
func discover_starters() -> void:
	for c: SpellCard in cards.values():
		if c.copies_in_starter > 0:
			SaveData.discover_card(c.id)


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.ends_with(".tres"):
			_index(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _index(path: String) -> void:
	var res: Resource = load(path)
	if res == null:
		push_error("Ressource illisible : %s" % path)
		return
	if res is SpellCard:
		_put(cards, (res as SpellCard).id, res, path)
	elif res is EnemyDef:
		_put(enemies, (res as EnemyDef).id, res, path)
	elif res is WaveDef:
		_put(waves, (res as WaveDef).id, res, path)
	elif res is LevelDef:
		_put(levels, (res as LevelDef).id, res, path)
	elif res is ObjectiveDef:
		_put(objectives, (res as ObjectiveDef).id, res, path)


func _put(target: Dictionary, id: StringName, res: Resource, path: String) -> void:
	if id == &"":
		push_error("Ressource sans id : %s" % path)
		return
	if target.has(id):
		duplicate_ids.append("%s (%s)" % [id, path])
		return
	target[id] = res


func cards_of_rarity(rarity: GameEnums.Rarity) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in cards.values():
		if c.rarity == rarity:
			out.append(c)
	return out


func starter_cards() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in cards.values():
		if c.copies_in_starter > 0:
			out.append(c)
	return out
