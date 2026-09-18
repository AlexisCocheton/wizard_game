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
	## Feuilles haute definition (VFX Free Pack, Pipoya), extraites par
	## tools/assets/extract_vfx.py. Cases de 160 px : elles restent nettes la ou
	## les grilles de 100 px bavaient.
	"shield_hex": ["shield_hex", 160, 160, 20],
	"vortex_hd": ["vortex_hd", 160, 160, 26],
	"boom_hd": ["boom_hd", 160, 160, 28],
	## --- Pack "Effect and FX Pixel All Free" : genere par tools/assets/extract_fxpack.py ---
	"orb_burst": ["orb_burst", 64, 64, 16],
	"pin_thrust": ["pin_thrust", 64, 64, 16],
	"rune_square": ["rune_square", 64, 64, 16],
	"ember_flames": ["ember_flames", 64, 64, 16],
	"fireball_hit": ["fireball_hit", 64, 64, 16],
	"spark_burst": ["spark_burst", 64, 64, 16],
	"crystal_field": ["crystal_field", 64, 64, 16],
	"ray_wheel": ["ray_wheel", 64, 64, 16],
	"clock_spiral": ["clock_spiral", 64, 64, 16],
	"cycle_swirl": ["cycle_swirl", 64, 64, 16],
	"wisp_rise": ["wisp_rise", 64, 64, 16],
	"stone_peak": ["stone_peak", 64, 64, 16],
	"flame_pillar": ["flame_pillar", 64, 64, 16],
	"meteor_streak": ["meteor_streak", 64, 64, 16],
	"pinwheel_turn": ["pinwheel_turn", 64, 64, 16],
	"star_focus": ["star_focus", 64, 64, 16],
	"spiral_salt": ["spiral_salt", 64, 64, 16],
	"bone_shards": ["bone_shards", 64, 64, 16],
	"shatter_burst": ["shatter_burst", 64, 64, 16],
	"ring_expand": ["ring_expand", 64, 64, 16],
	"halo_ring": ["halo_ring", 64, 64, 16],
	"sun_burst": ["sun_burst", 64, 64, 16],
	"lotus_bloom": ["lotus_bloom", 64, 64, 16],
	"hex_sigil": ["hex_sigil", 64, 64, 16],
	"lightning_web": ["lightning_web", 64, 64, 16],
	"orb_shatter": ["orb_shatter", 64, 64, 16],
	"frost_spikes": ["frost_spikes", 64, 64, 16],
	"diamond_mark": ["diamond_mark", 64, 64, 16],
	"pulse_ring": ["pulse_ring", 64, 64, 16],
	"void_mandala": ["void_mandala", 64, 64, 16],
	"spiral_pull": ["spiral_pull", 64, 64, 16],
	"dome_bastion": ["dome_bastion", 64, 64, 16],
	"orbit_cross": ["orbit_cross", 64, 64, 16],
	"glass_shards": ["glass_shards", 64, 64, 16],
	"tide_waves": ["tide_waves", 64, 64, 16],
	"hex_summon": ["hex_summon", 64, 64, 16],
	"fire_bloom": ["fire_bloom", 64, 64, 16],
	"weave_bloom": ["weave_bloom", 64, 64, 16],
	"echo_rings": ["echo_rings", 64, 64, 16],
	"twin_flames": ["twin_flames", 64, 64, 16],
	"magma_burst": ["magma_burst", 64, 64, 16],
	"skull_burst": ["skull_burst", 64, 64, 16],
	"slash_arc": ["slash_arc", 64, 64, 16],
	"lightning_fork": ["lightning_fork", 64, 64, 16],
	"flame_gust": ["flame_gust", 64, 64, 16],
	## --- fin du pack Effect and FX ---
}


## Part de la case reellement occupee par l effet (mesuree sur les feuilles).
const OCC: Dictionary = {
	"bluefire": 0.52,
	"bone_shards": 1.00,
	"boom_hd": 0.91,
	"brightfire": 0.32,
	"casting": 0.37,
	"clock_spiral": 0.69,
	"crystal_field": 0.97,
	"cycle_swirl": 0.83,
	"diamond_mark": 0.84,
	"dome_bastion": 0.77,
	"echo_rings": 0.88,
	"ember_flames": 1.00,
	"explosion_c": 0.98,
	"explosion_d": 0.98,
	"explosion_e": 1.00,
	"felspell": 0.71,
	"fire": 0.50,
	"fire_bloom": 0.78,
	"fireball_hit": 0.72,
	"firespin": 0.38,
	"flame_gust": 0.84,
	"flame_pillar": 0.95,
	"freezing": 0.78,
	"frost_spikes": 1.00,
	"glass_shards": 1.00,
	"halo_ring": 1.00,
	"heal_effect": 0.67,
	"hex_sigil": 1.00,
	"hex_summon": 0.80,
	"lightning_fork": 1.00,
	"lightning_web": 1.00,
	"lotus_bloom": 1.00,
	"magic8": 0.59,
	"magicbubbles": 0.49,
	"magickahit": 0.60,
	"magicspell": 0.45,
	"magma_burst": 0.66,
	"meteor_streak": 0.94,
	"midnight": 0.56,
	"orb_burst": 0.62,
	"orb_shatter": 0.83,
	"orbit_cross": 0.97,
	"pin_thrust": 0.55,
	"pinwheel_turn": 1.00,
	"protectioncircle": 0.34,
	"pulse_ring": 0.70,
	"ray_wheel": 0.97,
	"ring_expand": 0.50,
	"rune_square": 0.91,
	"shatter_burst": 1.00,
	"shield_hex": 0.84,
	"skull_burst": 0.91,
	"slash_arc": 0.75,
	"spark_burst": 0.91,
	"spiral_pull": 0.66,
	"spiral_salt": 0.91,
	"star_focus": 0.66,
	"stone_peak": 0.67,
	"sun_burst": 0.89,
	"tide_waves": 0.88,
	"ts_dust_01": 0.55,
	"ts_explosion_01": 0.33,
	"ts_fire_02": 0.56,
	"twin_flames": 0.89,
	"void_mandala": 0.77,
	"vortex": 0.76,
	"vortex_hd": 0.99,
	"weaponhit": 0.37,
	"weave_bloom": 0.95,
	"wisp_rise": 0.52,
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


## Une feuille est-elle connue (grille ou bande) ?
static func has_sheet(name: String) -> bool:
	return name != "" and (GRIDS.has(name) or STRIPS.has(name))


## Feuille PROPRE a une carte, "" si elle n en a pas (ou si elle est inconnue :
## on prefere l effet de l element a un trou dans l ecran).
static func card_sheet(card: SpellCard) -> String:
	if card == null or card.fx_key == &"":
		return ""
	var name: String = String(card.fx_key)
	return name if has_sheet(name) else ""


## Projectile magique du mage vers la cible, puis impact.
## `sheet` : feuille propre a la carte pour l impact, sinon celle de l element.
static func projectile(parent: Node2D, from: Vector2, to: Vector2, col: Color,
		sheet: String = "") -> void:
	if not enabled() or parent == null:
		return
	var dot: AnimatedSprite2D = sprite(parent, "magic8", from, 90.0, true, col.lightened(0.3))
	if dot == null:
		return
	dot.rotation = (to - from).angle()
	var tw: Tween = parent.create_tween()
	tw.tween_property(dot, "position", to, 0.22)
	tw.tween_callback(func() -> void:
		impact(parent, to, col, 70.0, sheet)
		if is_instance_valid(dot):
			dot.queue_free())


## Eclat a l impact : la feuille PROPRE a la carte si elle en a une, sinon
## celle de l element. Sans cela tous les sorts de feu explosaient pareil.
static func impact(parent: Node2D, at: Vector2, col: Color, radius: float = 70.0,
		sheet: String = "") -> void:
	sprite(parent, sheet if sheet != "" else impact_sheet(col), at, radius * 2.2, false)


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
		_duration: float, col: Color, sheet: String = "") -> Node:
	if not enabled() or parent == null:
		return null
	var root := Node2D.new()
	root.position = at
	parent.add_child(root)
	# L anneau est TRACE : la feuille protectioncircle n occupe que 34 px de sa case
	# et devenait une bouillie une fois etiree au rayon reel (agrandissement x10).
	var ring := ZoneRing.new()
	ring.setup(radius, col)
	root.add_child(ring)
	# L effet elementaire reste une feuille, a taille contenue pour rester net.
	# Au centre, l effet PROPRE a la carte quand elle en a un : deux zones de feu
	# ne doivent pas se ressembler.
	sprite(root, sheet if sheet != "" else zone_sheet(col), Vector2.ZERO,
		clampf(radius * 1.2, 110.0, 200.0), true, Color(1, 1, 1, 0.9))
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
## Trois paliers : les gros monstres meurent avec `boom_hd` (cases de 160 px), qui
## tient l agrandissement la ou `explosion_e` (192 px, mais 100 % de case) pixelisait.
static func death(parent: Node2D, at: Vector2, radius: float) -> void:
	var sheet: String = "explosion_d"
	if radius >= 70.0:
		sheet = "boom_hd"
	elif radius >= 45.0:
		sheet = "explosion_e"
	sprite(parent, sheet, at, radius * 3.2, false)


## Aura sur le mage : sorts qui agissent sur soi.
static func self_aura(parent: Node2D, col: Color) -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	sprite(parent, "protectioncircle", at, 260.0, false, col.lightened(0.2))


## Effet plein ecran bref (ralentissement, volte-face).
static func screen_tint(parent: Node2D, col: Color) -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y * 0.5)
	# `vortex_hd` (VFX Free Pack, cases de 160 px) plutot que la grille de 100 px :
	# cet effet est affiche a 1400 px de large, la ou l ancienne feuille pixelisait.
	var sheet: String = "vortex_hd" if col == COL_ARCANE else "midnight"
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
## Le halo doit couvrir EXACTEMENT la zone protegee : le joueur s en sert pour juger
## s il est dans la portee. Un facteur cosmetique mentirait sur la regle.
##
## Feuille `shield_hex` (Pipoya) et non `protectioncircle` : l ancienne n occupait
## que 34 % de sa case, donc un halo de 200 px l agrandissait 6x et la reduisait en
## bouillie. L hexagone en remplit 84 % et reste net a la taille protegee.
static func halo(parent: Node2D, radius: float, tint: Color = Color.WHITE) -> Node:
	return sprite(parent, "shield_hex", Vector2.ZERO, radius * 2.0, true, tint)
