class_name Fx
extends RefCounted
## Effets visuels des sorts et des monstres, tous issus des packs fournis :
## Free Pixel Effects Pack (grilles 100 px, domaine public), explosion pack 1,
## Tiny Swords (fleche, poussiere, rochers). Aucune forme n est dessinee par le code.
##
## Tout est inerte en headless : les tests n instancient aucun noeud graphique.

const F := "res://assets/fx/"

## Couleurs de reference (utilisees pour teinter, plus pour dessiner).
const COL_ARCANE := Color(0.62, 0.45, 0.95)
const COL_FIRE := Color(0.95, 0.45, 0.20)
const COL_FROST := Color(0.45, 0.80, 0.95)
const COL_PHYSICAL := Color(0.90, 0.85, 0.70)
const COL_SUMMON := Color(0.55, 0.90, 0.55)
const COL_WALL := Color(0.60, 0.55, 0.50)
const COL_HASTE := Color(0.95, 0.80, 0.35)
const COL_VULN := Color(0.95, 0.30, 0.65)

## Grilles 100 px : nom -> (fichier, fps)
const GRIDS: Dictionary = {
	"magicspell": ["magicspell", 30], "magic8": ["magic8", 24], "bluefire": ["bluefire", 24],
	"casting": ["casting", 24], "magickahit": ["magickahit", 30], "firespin": ["firespin", 24],
	"protectioncircle": ["protectioncircle", 20], "brightfire": ["brightfire", 24],
	"fire": ["fire", 20], "vortex": ["vortex", 24], "felspell": ["felspell", 24],
	"midnight": ["midnight", 20], "freezing": ["freezing", 20], "magicbubbles": ["magicbubbles", 20],
	"weaponhit": ["weaponhit", 30],
}
## Bandes : nom -> (fichier, largeur de case, hauteur de case, fps)
const STRIPS: Dictionary = {
	"explosion_d": ["explosion_d", 128, 128, 24], "explosion_e": ["explosion_e", 192, 192, 30],
	"explosion_c": ["explosion_c", 128, 80, 24], "dust": ["ts_dust_01", 64, 64, 16],
	"ts_explosion": ["ts_explosion_01", 192, 192, 20], "ts_fire": ["ts_fire_02", 64, 64, 14],
	"heal_effect": ["heal_effect", 192, 192, 14],
}


## Part de la case reellement occupee par l effet (mesuree sur les feuilles).
const OCC: Dictionary = {
	"bluefire": 0.52,
	"brightfire": 0.32,
	"casting": 0.37,
	"explosion_c": 0.98,
	"explosion_d": 0.98,
	"explosion_e": 1.00,
	"felspell": 0.71,
	"fire": 0.50,
	"firespin": 0.38,
	"freezing": 0.78,
	"heal_effect": 0.67,
	"magic8": 0.59,
	"magicbubbles": 0.49,
	"magickahit": 0.60,
	"magicspell": 0.45,
	"midnight": 0.56,
	"protectioncircle": 0.34,
	"ts_dust_01": 0.55,
	"ts_explosion_01": 0.33,
	"ts_fire_02": 0.56,
	"vortex": 0.76,
	"weaponhit": 0.37,
}


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func color_for(tags: Array) -> Color:
	for t in tags:
		match t:
			GameEnums.DamageTag.FIRE: return COL_FIRE
			GameEnums.DamageTag.FROST: return COL_FROST
			GameEnums.DamageTag.SLOW: return COL_FROST
			GameEnums.DamageTag.PHYSICAL: return COL_PHYSICAL
			GameEnums.DamageTag.SUMMON: return COL_SUMMON
	return COL_ARCANE


## Feuille d effet selon l element du sort.
static func impact_sheet(col: Color) -> String:
	if col == COL_FIRE: return "brightfire"
	if col == COL_FROST: return "freezing"
	if col == COL_PHYSICAL: return "weaponhit"
	if col == COL_SUMMON: return "magicbubbles"
	return "magickahit"


static func zone_sheet(col: Color) -> String:
	if col == COL_FIRE: return "fire"
	if col == COL_FROST: return "freezing"
	if col == COL_VULN: return "felspell"
	return "magicspell"


static func frames_of(name: String) -> SpriteFrames:
	if GRIDS.has(name):
		var g: Array = GRIDS[name]
		return SheetLib.frames("fx:" + name, {"play": {"path": F + str(g[0]) + ".png", "cell": 100, "fps": g[1], "loop": true}})
	if STRIPS.has(name):
		var s: Array = STRIPS[name]
		return SheetLib.frames("fx:" + name, {"play": {"path": F + str(s[0]) + ".png", "frame": s[1], "frame_h": s[2], "fps": s[3], "loop": true}})
	return null


static func sheet_names() -> Array:
	return GRIDS.keys() + STRIPS.keys()


## Cree un sprite anime a `at`. `size_px` = taille voulue a l ecran.
## loop = false : se libere seul en fin d animation.
static func sprite(parent: Node2D, name: String, at: Vector2, size_px: float,
		loop: bool = false, tint: Color = Color.WHITE) -> AnimatedSprite2D:
	if not enabled() or parent == null:
		return null
	var sf: SpriteFrames = frames_of(name)
	if sf == null:
		return null
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = sf
	sp.position = at
	sp.modulate = tint
	var cell: float = 100.0
	var file: String = name
	if STRIPS.has(name):
		cell = float(STRIPS[name][1])
		file = str(STRIPS[name][0])
	# On met a l echelle la partie VISIBLE de la case, pas la case entiere.
	var occ: float = float(OCC.get(file, OCC.get(name, 1.0)))
	sp.scale = Vector2.ONE * (size_px / (cell * maxf(occ, 0.05)))
	parent.add_child(sp)
	sp.play("play")
	if not loop:
		# Un seul jeu de frames est partage : on gere la fin nous-memes.
		sp.frame_changed.connect(func() -> void:
			if is_instance_valid(sp) and sp.frame >= sp.sprite_frames.get_frame_count("play") - 1:
				sp.queue_free())
	return sp


## Projectile magique du mage vers la cible, puis impact.
static func projectile(parent: Node2D, from: Vector2, to: Vector2, col: Color) -> void:
	if not enabled() or parent == null:
		return
	var dot: AnimatedSprite2D = sprite(parent, "magic8", from, 90.0, true, col.lightened(0.3))
	if dot == null:
		return
	dot.rotation = (to - from).angle()
	var tw: Tween = parent.create_tween()
	tw.tween_property(dot, "position", to, 0.22)
	tw.tween_callback(func() -> void:
		impact(parent, to, col)
		if is_instance_valid(dot):
			dot.queue_free())


## Eclat a l impact, feuille selon l element.
static func impact(parent: Node2D, at: Vector2, col: Color, radius: float = 70.0) -> void:
	sprite(parent, impact_sheet(col), at, radius * 2.2, false)


## Fleche percante : une fleche du pack qui file du mage vers le haut.
static func beam(parent: Node2D, from: Vector2, direction: Vector2,
		width: float, col: Color) -> void:
	if not enabled() or parent == null:
		return
	var tex: Texture2D = SheetLib.texture(F + "arrow.png")
	if tex == null:
		return
	var arrow := Sprite2D.new()
	arrow.texture = tex
	arrow.position = from
	arrow.rotation = direction.angle()
	arrow.scale = Vector2.ONE * maxf(1.4, width / 60.0)
	arrow.modulate = col.lightened(0.4)
	parent.add_child(arrow)
	var to: Vector2 = from + direction.normalized() * GameConfig.BATTLEFIELD_HEIGHT
	var tw: Tween = parent.create_tween()
	tw.tween_property(arrow, "position", to, 0.35)
	tw.tween_callback(arrow.queue_free)


## Zone au sol persistante, liberee par Battlefield a expiration :
## un anneau (cercle de protection) a l echelle du VRAI rayon pour lire la portee,
## et l effet elementaire au centre a taille contenue pour rester net.
static func zone_visual(parent: Node2D, at: Vector2, radius: float,
		_duration: float, col: Color) -> Node:
	if not enabled() or parent == null:
		return null
	var root := Node2D.new()
	root.position = at
	parent.add_child(root)
	sprite(root, "protectioncircle", Vector2.ZERO, radius * 2.15, true, Color(col.r, col.g, col.b, 0.8))
	sprite(root, zone_sheet(col), Vector2.ZERO, clampf(radius * 1.3, 120.0, 240.0), true, Color(1, 1, 1, 0.9))
	return root


## Mur : une rangee de rochers du pack, soulevee dans un nuage de poussiere.
static func spawn_wall_visual(parent: Node2D, center: Vector2, half_width: float,
		thickness: float, duration: float) -> Node:
	if not enabled() or parent == null:
		return null
	var root := Node2D.new()
	root.position = center
	parent.add_child(root)
	var rocks: Array[Texture2D] = []
	for i in range(1, 5):
		var t: Texture2D = SheetLib.texture("res://assets/terrain/rock%d.png" % i)
		if t != null:
			rocks.append(t)
	if rocks.is_empty():
		return root
	var step: float = 56.0
	var n: int = maxi(1, int(half_width * 2.0 / step))
	for i in n:
		var s := Sprite2D.new()
		s.texture = rocks[i % rocks.size()]
		s.position = Vector2(-half_width + step * 0.5 + i * step, 0.0)
		s.scale = Vector2.ONE * (thickness / 48.0)
		root.add_child(s)
	sprite(root, "dust", Vector2.ZERO, minf(half_width * 1.2, 220.0), false)
	if duration > 1.2:
		var blink: Tween = parent.create_tween()
		blink.tween_interval(duration - 1.2)
		for i in 3:
			blink.tween_property(root, "modulate:a", 0.35, 0.2)
			blink.tween_property(root, "modulate:a", 1.0, 0.2)
	return root


## Flash blanc sur un monstre touche (teinte, pas dessin).
static func hit_flash(enemy: Node2D) -> void:
	if not enabled() or enemy == null or not is_instance_valid(enemy):
		return
	var body: CanvasItem = enemy.get_node_or_null("Anim") as CanvasItem
	if body == null or not body.visible:
		body = enemy.get_node_or_null("Static") as CanvasItem
	if body == null:
		body = enemy.get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	if enemy.has_method("reset_flash"):
		enemy.reset_flash()
	var base: Color = body.modulate
	var tw: Tween = enemy.create_tween()
	tw.tween_property(body, "modulate", Color(4.0, 4.0, 4.0, base.a), 0.05)
	tw.tween_property(body, "modulate", base, 0.14)
	if enemy.has_method("set_flash_tween"):
		enemy.set_flash_tween(tw)


## Mort d un monstre : explosion du pack, proportionnee a sa taille.
static func death(parent: Node2D, at: Vector2, radius: float) -> void:
	sprite(parent, "explosion_d" if radius < 45.0 else "explosion_e", at, radius * 3.2, false)


## Aura sur le mage : sorts qui agissent sur soi.
static func self_aura(parent: Node2D, col: Color) -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	sprite(parent, "protectioncircle", at, 260.0, false, col.lightened(0.2))


## Effet plein ecran bref (ralentissement, volte-face).
static func screen_tint(parent: Node2D, col: Color) -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y * 0.5)
	var sheet: String = "vortex" if col == COL_ARCANE else "midnight"
	sprite(parent, sheet, at, 1400.0, false, Color(1, 1, 1, 0.6))


## Projectile ennemi : fleche du pack pointee vers le bas, deplacee par Battlefield.
static func shot_visual(parent: Node2D, at: Vector2, col: Color) -> Node:
	if not enabled() or parent == null:
		return null
	var tex: Texture2D = SheetLib.texture(F + "arrow.png")
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	s.rotation = PI * 0.5
	s.scale = Vector2(1.1, 1.1)
	s.modulate = col.lightened(0.3)
	parent.add_child(s)
	return s


## Incantation en cours : cercle de lancement sous le mage, boucle jusqu a liberation.
static func cast_charge(parent: Node2D, at: Vector2) -> Node:
	return sprite(parent, "casting", at, 220.0, true)


## Soin recu : effet du moine.
static func heal_effect(parent: Node2D, at: Vector2) -> void:
	sprite(parent, "heal_effect", at, 140.0, false)


## Halo persistant (bouclier du premier coup, aura protectrice).
static func halo(parent: Node2D, radius: float, tint: Color = Color.WHITE) -> Node:
	return sprite(parent, "protectioncircle", Vector2.ZERO, radius * 2.4, true, tint)
