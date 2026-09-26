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
## Deux elements ajoutes avec les resistances (chantier B3). Teintes choisies
## LOIN des quatre autres : un element qu on ne distingue pas a l impact ne
## sert a rien, le joueur ne peut pas verifier qu il a joue le bon sort.
const COL_POISON := Color(0.55, 0.90, 0.30)
const COL_LIGHTNING := Color(0.95, 0.90, 0.35)
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
	## Pipoya WarpPortal / Mysterious Object (extract_vfx.py, 2026-09-21) : extraits
	## pour les chantiers a venir (deplacement, acte final). Pas encore joues par une
	## carte ; les entrees existent pour que l AUDIT verifie deja les feuilles.
	"portal_blue": ["portal_blue", 160, 160, 12],
	"portal_violet": ["portal_violet", 160, 160, 12],
	"portal_red": ["portal_red", 160, 160, 12],
	"spirit_violet": ["spirit_violet", 160, 160, 12],
	"spirit_gold": ["spirit_gold", 160, 160, 12],
	"orb_magenta": ["orb_magenta", 160, 160, 15],
	"orb_cyan": ["orb_cyan", 160, 160, 15],
	"orb_gold": ["orb_gold", 160, 160, 15],
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
	##
	## --- Packs du 26/09 (chantier F2), tools/assets/extract_packs_2026_09_26.py ---
	##
	## Deux feuilles de 192 px et trois d OMBRE. Les 192 px sont la reponse au
	## testeur — « si tu veux faire des gros effet qui prend une grande partie de
	## l ecran utilise plutot des animation qui on une grosse resolution » : ce
	## sont les seules du jeu, avec explosion_e, a tenir un agrandissement plein
	## ecran. `timemagic` est une HORLOGE verte, et le jeu s appelle Time Wizard :
	## sa mecanique signature n avait aucun visuel a elle.
	"timemagic": ["timemagic", 192, 192, 18],
	"lightpillar": ["lightpillar", 192, 192, 14],
	## Les trois feuilles d OMBRE : le premier element visuel sombre du jeu. 40 px
	## de case, donc reservees aux effets PROCHES du joueur (impact, aura sur le
	## mage), jamais a une nappe ou a un plein ecran.
	"dark_soul": ["dark_soul", 40, 32, 14],
	"dark_vanish": ["dark_vanish", 40, 32, 12],
	"dark_swirl": ["dark_swirl", 48, 64, 16],
}


## Feuilles jouees a PLEINE LARGEUR (screen_tint, 1400 px). Elles sont nommees
## ici plutot que devinees : c est la liste que test_card_fx.gd confronte a la
## taille de case, pour qu une feuille de 64 px ne revienne jamais s etirer sur
## tout l ecran.
## `midnight` n y figure PAS, bien que `screen_tint` puisse encore l afficher en
## dernier recours : c est une grille de 100 px, donc agrandie 25 fois a cette
## taille. Elle est le repli d un sort qui n a pas de feuille a lui, et le jeu
## n en compte plus aucun — toute carte de ralentissement porte desormais la
## sienne. La lister ici reviendrait a declarer bonne une resolution qu on juge
## mauvaise.
const PLEIN_ECRAN: Array[String] = ["vortex_hd", "timemagic"]


static func plein_ecran_sheets() -> Array[String]:
	return PLEIN_ECRAN.duplicate()


## Cote de la case d une feuille, en pixels. 100 pour les grilles.
static func cell_size(name: String) -> int:
	if STRIPS.has(name):
		return int(STRIPS[name][1])
	if GRIDS.has(name):
		return 100
	return 0


## ---------------------------------------------------------------------------
## MOUCHARD DE RENDU (tests seulement)
##
## `test_card_fx.gd` verifie qu une carte affiche bien SA feuille. Sans ce
## crochet, le test devrait reimplementer le choix de feuille et ne prouverait
## que sa propre coherence. Ici il observe le vrai `sprite()`, c est-a-dire le
## seul point par ou passe tout ce qui s affiche.
##
## Inerte en dehors d un trace : un booleen teste par appel, et rien de plus.
static var _trace_on: bool = false
static var _traced: Array[String] = []


static func begin_trace() -> void:
	_trace_on = true
	_traced = []


## Declare au mouchard une feuille qu on s apprete a jouer.
##
## `sprite()` note deja tout ce qui passe par lui, mais les helpers composites
## (`zone_visual`, `projectile`, `prop_visual`) sortent AVANT sur le garde
## headless : le sort est bien branche, il n y a simplement pas d ecran. Sans
## cette annonce, le test verrait une zone parfaitement cablee comme muette.
static func _note(name: String) -> void:
	if _trace_on and name != "":
		_traced.append(name)


static func end_trace() -> Array[String]:
	_trace_on = false
	# Copie : rendre le tableau interne laisserait l appelant le vider a notre
	# insu (le gotcha `offer_choices` du projet, deja paye une fois).
	var out: Array[String] = _traced.duplicate()
	_traced = []
	return out


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
	"dark_soul": 0.70,
	"dark_swirl": 0.77,
	"dark_vanish": 0.88,
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
	"lightpillar": 0.97,
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
	"orb_cyan": 0.66,
	"orb_gold": 0.61,
	"orb_magenta": 0.69,
	"orb_shatter": 0.83,
	"orbit_cross": 0.97,
	"pin_thrust": 0.55,
	"pinwheel_turn": 1.00,
	"portal_blue": 0.89,
	"portal_red": 0.89,
	"portal_violet": 0.89,
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
	"spirit_gold": 0.93,
	"spirit_violet": 0.93,
	"star_focus": 0.66,
	"stone_peak": 0.67,
	"sun_burst": 0.89,
	"tide_waves": 0.88,
	"timemagic": 0.83,
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
			GameEnums.DamageTag.POISON: return COL_POISON
			GameEnums.DamageTag.LIGHTNING: return COL_LIGHTNING
			GameEnums.DamageTag.PHYSICAL: return COL_PHYSICAL
			GameEnums.DamageTag.SUMMON: return COL_SUMMON
			# SLOW passe APRES les elements : un Champ de givre est givre AVANT
			# d etre ralentissant, et une Mare de venin doit rester verte.
			GameEnums.DamageTag.SLOW: return COL_FROST
	return COL_ARCANE


## Feuille d effet selon l element du sort.
static func impact_sheet(col: Color) -> String:
	if col == COL_FIRE: return "brightfire"
	if col == COL_FROST: return "freezing"
	if col == COL_POISON: return "skull_burst"
	if col == COL_LIGHTNING: return "lightning_fork"
	if col == COL_PHYSICAL: return "weaponhit"
	if col == COL_SUMMON: return "magicbubbles"
	return "magickahit"


static func zone_sheet(col: Color) -> String:
	if col == COL_FIRE: return "fire"
	if col == COL_FROST: return "freezing"
	if col == COL_POISON: return "spiral_salt"
	if col == COL_LIGHTNING: return "lightning_web"
	if col == COL_PHYSICAL: return "stone_peak"
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
	# Le mouchard note la feuille DEMANDEE, avant le retour headless : les tests
	# unitaires tournent sans serveur d affichage, et un trace qui s arreterait
	# ici ne verrait jamais rien.
	_note(name)
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
	_note(sheet if sheet != "" else impact_sheet(col))
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
	_note(sheet if sheet != "" else zone_sheet(col))
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
	var feuille: String = sheet if sheet != "" else zone_sheet(col)
	var taille: float = clampf(radius * 1.2, 110.0, 200.0)
	sprite(root, feuille, Vector2.ZERO, taille, true, Color(1, 1, 1, 0.9))

	# PLUSIEURS exemplaires quand la zone est LARGE. Un seul sprite plafonne a
	# 200 px laissait un anneau de 230 px de rayon vide sur les trois quarts :
	# la portee etait tracee, mais rien ne l OCCUPAIT, et le joueur lisait un
	# cercle dessine plutot qu un terrain empoisonne (vu sur capture de la Mare
	# de venin).
	#
	# On ne les disperse pas au hasard : ils sont poses en couronne a mi-rayon,
	# plus petits et plus pales que celui du centre, pour que la zone garde un
	# CENTRE lisible. Trois suffisent — au-dela, une zone animee devient une
	# bouillie a haute vitesse.
	if radius > taille * 0.9:
		var n: int = 3
		var r: float = radius * 0.55
		for i in n:
			var a: float = TAU * float(i) / float(n) - PI * 0.5
			sprite(root, feuille, Vector2(cos(a) * r, sin(a) * r),
				taille * 0.62, true, Color(1, 1, 1, 0.55))
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
##
## `sheet` est la feuille PROPRE de la carte. Sans elle, les onze sorts qui
## agissent sur le mage (Focalisation, Precipitation, Flux de mana, Intuition,
## Echo de la main, Canalisation jumelle...) affichaient tous le meme cercle de
## protection : le joueur ne pouvait pas voir LEQUEL il venait de lancer, alors
## que leur `fx_key` etait deja unique et verifiee par l AUDIT. Le champ existait,
## personne ne le lisait.
##
## LA TAILLE SUIT LA RESOLUTION DE LA FEUILLE.
## Premiere capture de la vitrine : les deux feuilles d ombre (cases de 40 px)
## affichees a 260 px etaient agrandies 6,5 fois et donnaient une tache violette
## carree sur le mage, ou l on ne reconnaissait ni le crane ni le fantome. C est
## le defaut exact que le testeur decrit en demandant une « grosse resolution »
## pour les gros effets — ici pris par l autre bout : une PETITE feuille doit
## rester petite. `max_px_for` borne l agrandissement a 4x la case, ce qui rend
## les feuilles d ombre a ~160 px : assez grandes pour se lire au-dessus du mage,
## assez fines pour qu on distingue encore le dessin.
static func self_aura(parent: Node2D, col: Color, sheet: String = "") -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	var nom: String = sheet if sheet != "" else "protectioncircle"
	sprite(parent, nom, at, max_px_for(nom, 260.0),
		false, col.lightened(0.2) if sheet == "" else Color(1, 1, 1, 0.95))


## Taille d affichage d une feuille, bornee par sa propre definition.
##
## Le facteur 4 est un compromis mesure sur les captures : en deca, les feuilles
## de 64 px du gros pack (deja la moitie du catalogue) deviendraient trop petites
## pour se voir ; au-dela, les feuilles de 40 px repassent en gros carres.
const AGRANDISSEMENT_MAX: float = 4.0


static func max_px_for(name: String, voulue: float) -> float:
	var cote: int = cell_size(name)
	if cote <= 0:
		return voulue
	# On raisonne sur la partie VISIBLE de la case, comme `sprite()` : une case a
	# moitie vide n offre que la moitie des pixels.
	var file: String = str(STRIPS[name][0]) if STRIPS.has(name) else name
	var occ: float = float(OCC.get(file, OCC.get(name, 1.0)))
	return minf(voulue, float(cote) * maxf(occ, 0.05) * AGRANDISSEMENT_MAX)


## Effet plein ecran bref (ralentissement, volte-face).
##
## Meme correction que `self_aura`, et le meme piege en plus gros : cet effet est
## etire a 1400 px de large. `midnight` est une grille de 100 px — a cette taille
## elle est agrandie 25 fois et ne montre plus qu une tache. C est exactement ce
## que le testeur decrivait en demandant « une grosse resolution » pour les gros
## effets. Les feuilles admises ici sont listees dans PLEIN_ECRAN et leur taille
## de case est verrouillee par test_card_fx.gd.
static func screen_tint(parent: Node2D, col: Color, sheet: String = "") -> void:
	var at := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y * 0.5)
	# `vortex_hd` (VFX Free Pack, cases de 160 px) plutot que la grille de 100 px :
	# cet effet est affiche a 1400 px de large, la ou l ancienne feuille pixelisait.
	var choisie: String = sheet
	if choisie == "":
		choisie = "vortex_hd" if col == COL_ARCANE else "midnight"
	sprite(parent, choisie, at, 1400.0, false, Color(1, 1, 1, 0.6))


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


## ACCESSOIRE DE TERRAIN (chantier H) : un arbre plante ou une nappe d eau.
##
## Le corps de l objet vient des assets du pack Tiny Swords deja extraits
## (`terrain/tree1.png`, bande de 192x256 qui ondule au vent ; `terrain/water.png`,
## texture carrelable), exactement comme les decore le fond de bataille. Rien n est
## dessine par le code : un arbre trace au polygone se lirait comme un bug a cote
## des sprites peints du reste du terrain.
##
## Par-dessus, `sheet` est la feuille PROPRE a la carte. C est elle qui distingue le
## totem de l arbre empoisonne : le corps est le meme arbre du pack, l aura qui
## l entoure ne l est pas. Sans cela deux cartes de terrain seraient rigoureusement
## identiques a l ecran, ce que l AUDIT refuse et ce dont le testeur s est plaint.
static func prop_visual(parent: Node2D, at: Vector2, kind: int, duration: float,
		sheet: String = "", tint: Color = Color.WHITE, area: float = 0.0) -> Node:
	_note(sheet)
	if not enabled() or parent == null:
		return null
	var root := Node2D.new()
	root.position = at
	# Au-dessus du decor et du sol, sous les monstres : un arbre qui masquerait le
	# monstre en train de le frapper cacherait justement ce qu on veut montrer.
	root.z_index = -2
	parent.add_child(root)

	if kind == TerrainProp.Kind.WATER:
		# La nappe est un DISQUE, pas un carre.
		#
		# Premiere version : `assets/terrain/water.png` carrelee dans un
		# TextureRect. La capture l a montree comme un rectangle bleu a bords nets
		# pose sur l herbe — ca ne se lisait pas comme une flaque mais comme un
		# panneau d interface oublie sur le terrain. Le fichier du pack ne fait que
		# 222 octets : c est un aplat, il n a aucune texture a carreler, et
		# l etirer ne pouvait donner qu un rectangle.
		#
		# ZoneRing, lui, TRACE un anneau au rayon exact : c est deja ce que les
		# zones au sol utilisent, le joueur en connait la lecture, et le contour
		# rond dit la portee sans mentir d un pixel.
		#
		# Il est empile a rayons DECROISSANTS. Un seul anneau ne remplit son
		# interieur qu a 10 % d opacite — reglage juste pour une zone de degats,
		# qu on ne doit pas confondre avec le decor, mais qui donnait ici un simple
		# cercle vide sur l herbe : la capture ne montrait aucune eau. Trois
		# disques concentriques additionnent leur remplissage vers le centre, ce
		# qui donne une nappe plus profonde au milieu qu au bord — la lecture
		# exacte d une flaque — sans toucher a ZoneRing, dont toutes les autres
		# zones du jeu dependent.
		var rayon: float = area if area > 0.0 else PROP_WATER_PX * 0.5
		for part in PROP_WATER_LAYERS:
			var anneau := ZoneRing.new()
			anneau.setup(rayon * part, COL_FROST)
			root.add_child(anneau)
	else:
		var sf: SpriteFrames = SheetLib.frames("decor:tree1",
			{"sway": {"path": "res://assets/terrain/tree1.png", "frame": 192,
				"frame_h": 256, "fps": 5, "loop": true}})
		if sf != null:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = sf
			# A l echelle 1 la capture montrait un buisson, pas un repere : l arbre
			# du pack fait 192x256 et les monstres, eux, sont dessines a 2,1 fois
			# leur rayon logique. Un accessoire qu on plante pour que la vague le
			# REMARQUE doit dominer ce qui vient le frapper.
			a.scale = Vector2.ONE * PROP_TREE_SCALE
			# Teinte de l element du sort : le semis empoisonne doit se lire VERT au
			# premier coup d oeil, le totem dore non. `lightened` plutot qu une
			# teinte pleine : l arbre garde son feuillage peint au lieu de devenir
			# une silhouette monochrome.
			a.modulate = Color(tint.r, tint.g, tint.b, 1.0).lightened(0.45)
			root.add_child(a)
			a.play("sway")

	# L effet propre a la carte, en boucle sur toute la vie de l accessoire : c est
	# le signe que l objet est ACTIF, et pas un morceau de decor.
	if sheet != "":
		sprite(root, sheet, Vector2.ZERO, PROP_AURA_PX, true, Color(1, 1, 1, 0.85))
	# Clignotement de fin, comme pour le mur : le joueur doit voir venir la
	# disparition pour ne pas compter sur une protection qui n existe plus.
	if duration > 1.2 and duration < INF:
		var blink: Tween = parent.create_tween()
		blink.tween_interval(duration - 1.2)
		for i in 3:
			blink.tween_property(root, "modulate:a", 0.35, 0.2)
			blink.tween_property(root, "modulate:a", 1.0, 0.2)
	return root


## Reglages visuels de la famille, nommes plutot qu eparpilles en nombres au
## milieu du code : ce sont les trois seuls, et ils se relisent ensemble.
##
## PROP_TREE_SCALE : l arbre du pack fait 192x256 a l echelle 1, ce que la capture
## a montre comme un buisson perdu dans l herbe. 1,6 le porte a ~410 px de haut,
## au-dessus des monstres qui viennent le frapper — c est un repere, il doit se
## voir de loin.
## PROP_AURA_PX : taille de la feuille propre a la carte posee sur l accessoire.
## PROP_WATER_PX : rayon de secours d une nappe dont personne n a donne l aire.
const PROP_TREE_SCALE: float = 1.6
const PROP_AURA_PX: float = 180.0
const PROP_WATER_PX: float = 560.0
## Rayons relatifs des disques empiles qui font la nappe. Le premier porte la
## portee exacte : c est lui que le joueur lit, les autres ne font qu epaissir.
const PROP_WATER_LAYERS: Array[float] = [1.0, 0.74, 0.46]


## Halo persistant (bouclier du premier coup, aura protectrice).
## Le halo doit couvrir EXACTEMENT la zone protegee : le joueur s en sert pour juger
## s il est dans la portee. Un facteur cosmetique mentirait sur la regle.
##
## Feuille `shield_hex` (Pipoya) et non `protectioncircle` : l ancienne n occupait
## que 34 % de sa case, donc un halo de 200 px l agrandissait 6x et la reduisait en
## bouillie. L hexagone en remplit 84 % et reste net a la taille protegee.
static func halo(parent: Node2D, radius: float, tint: Color = Color.WHITE) -> Node:
	return sprite(parent, "shield_hex", Vector2.ZERO, radius * 2.0, true, tint)
