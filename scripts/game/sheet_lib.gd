class_name SheetLib
extends RefCounted
## Decoupe des spritesheets en SpriteFrames, avec cache.
## Deux formats : bandes horizontales (Tiny Swords, Tiny RPG : une animation par
## fichier) et grilles carrees (Free Pixel Effects : N x N cases de 100 px).

static var _cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Nombre de cases d une bande horizontale.
static func strip_count(tex: Texture2D, frame_w: int) -> int:
	if tex == null or frame_w <= 0:
		return 0
	return int(tex.get_width()) / frame_w


## Cases d une bande horizontale (une seule ligne).
static func strip(tex: Texture2D, frame_w: int, frame_h: int = -1) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if tex == null:
		return out
	var h: int = frame_h if frame_h > 0 else int(tex.get_height())
	for i in strip_count(tex, frame_w):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_w, 0, frame_w, h)
		out.append(at)
	return out


## Cases d une grille (lecture ligne par ligne).
static func grid(tex: Texture2D, cell: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if tex == null or cell <= 0:
		return out
	var cols: int = int(tex.get_width()) / cell
	var rows: int = int(tex.get_height()) / cell
	for r in rows:
		for c in cols:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(c * cell, r * cell, cell, cell)
			out.append(at)
	return out


## Construit (ou relit du cache) un SpriteFrames a partir d une description :
##   { "walk": {"path": "res://...png", "frame": 192, "fps": 10, "loop": true}, ... }
## Une case "cell" a la place de "frame" signifie une grille.
static func frames(key: String, spec: Dictionary) -> SpriteFrames:
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_name in spec:
		var a: Dictionary = spec[anim_name]
		var tex: Texture2D = texture(str(a.get("path", "")))
		var cells: Array[Texture2D] = []
		if a.has("cell"):
			cells = grid(tex, int(a["cell"]))
		else:
			cells = strip(tex, int(a.get("frame", 192)), int(a.get("frame_h", -1)))
		var max_frames: int = int(a.get("count", cells.size()))
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(a.get("fps", 10)))
		sf.set_animation_loop(anim_name, bool(a.get("loop", true)))
		for i in mini(cells.size(), max_frames):
			sf.add_frame(anim_name, cells[i])
	_cache[key] = sf
	return sf


static func clear_cache() -> void:
	_cache.clear()
