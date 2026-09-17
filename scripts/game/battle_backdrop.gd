class_name BattleBackdrop
extends Node2D
## Decor du champ de bataille, entierement en tuiles et sprites Tiny Swords :
## eau autour, ile d herbe (ou de sable) bordee, rochers, buissons, arbres, et
## la tour du mage en bas. Rien n est dessine par le code : seules des textures
## du pack sont posees.

const T := "res://assets/terrain/"
const TILE: int = 64
## Ile : marge autour du terrain jouable.
const ISLAND := Rect2(32.0, 96.0, 1016.0, 1536.0)

var terrain: String = "grass"
var _rng := RandomNumberGenerator.new()


func setup(terrain_key: String, seed_value: int = 7) -> void:
	terrain = terrain_key
	_rng.seed = seed_value
	for c in get_children():
		c.queue_free()
	if not Fx.enabled():
		return
	_build()


func _build() -> void:
	_tile_water()
	_tile_island()
	_scatter_decor()
	_mage_tower()


func _tile_water() -> void:
	var tex: Texture2D = SheetLib.texture(T + "water.png")
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.position = Vector2.ZERO
	tr.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	tr.z_index = -20
	add_child(tr)


## L ile utilise le bloc 3x3 du tileset : coins, bords, centre plat.
func _tile_island() -> void:
	var sheet: String = "tilemap_sand.png" if terrain == "sand" else "tilemap_grass.png"
	var tex: Texture2D = SheetLib.texture(T + sheet)
	if tex == null:
		return
	var cols: int = int(ISLAND.size.x / TILE)
	var rows: int = int(ISLAND.size.y / TILE)
	for r in rows:
		for c in cols:
			var tx: int = 1
			var ty: int = 1
			if c == 0: tx = 0
			elif c == cols - 1: tx = 2
			if r == 0: ty = 0
			elif r == rows - 1: ty = 2
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(tx * TILE, ty * TILE, TILE, TILE)
			var s := Sprite2D.new()
			s.texture = at
			s.centered = false
			s.position = ISLAND.position + Vector2(c * TILE, r * TILE)
			s.z_index = -15
			add_child(s)


func _scatter_decor() -> void:
	# Rochers et souches sur les bords, hors de la trajectoire centrale.
	var rocks: Array[Texture2D] = []
	for i in range(1, 5):
		var t: Texture2D = SheetLib.texture(T + "rock%d.png" % i)
		if t != null:
			rocks.append(t)
	for i in 10:
		if rocks.is_empty():
			break
		var s := Sprite2D.new()
		s.texture = rocks[_rng.randi_range(0, rocks.size() - 1)]
		var left: bool = _rng.randi() % 2 == 0
		s.position = Vector2(_rng.randf_range(60.0, 160.0) if left else _rng.randf_range(920.0, 1020.0),
			_rng.randf_range(160.0, 1400.0))
		s.z_index = -10
		add_child(s)
	# Buissons animes (bande de 8 cases de 128).
	var bush: Texture2D = SheetLib.texture(T + "bush1.png")
	if bush != null:
		var sf: SpriteFrames = SheetLib.frames("decor:bush1", {"sway": {"path": T + "bush1.png", "frame": 128, "fps": 6, "loop": true}})
		for i in 6:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = sf
			var left: bool = i % 2 == 0
			a.position = Vector2(_rng.randf_range(70.0, 150.0) if left else _rng.randf_range(930.0, 1010.0),
				_rng.randf_range(200.0, 1350.0))
			a.z_index = -9
			a.play("sway")
			a.frame = _rng.randi_range(0, 7)
			add_child(a)
	# Arbres en haut, la ou les monstres apparaissent.
	var tree: Texture2D = SheetLib.texture(T + "tree1.png")
	if tree != null:
		var sf: SpriteFrames = SheetLib.frames("decor:tree1", {"sway": {"path": T + "tree1.png", "frame": 192, "frame_h": 256, "fps": 5, "loop": true}})
		for x in [110.0, 560.0, 980.0]:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = sf
			a.position = Vector2(x, 60.0)
			a.z_index = 5
			a.play("sway")
			add_child(a)


func _mage_tower() -> void:
	var tex: Texture2D = SheetLib.texture(T + "tower_blue.png")
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y + 40.0)
	s.scale = Vector2(1.6, 1.6)
	s.z_index = -5
	add_child(s)
