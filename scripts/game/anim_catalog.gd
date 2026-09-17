class_name AnimCatalog
extends RefCounted
## Catalogue des feuilles animees. Une cle par silhouette ; les monstres y font
## reference par EnemyDef.anim_key. Toutes les feuilles viennent des packs fournis
## (Tiny Swords, Tiny RPG Character Pack 02) — rien n est dessine par le code.
##
## "occupancy" = part de la case reellement occupee par le personnage : sert a
## mettre le sprite a l echelle du rayon logique du monstre.

const U := "res://assets/units/"

const UNITS: Dictionary = {
	"pawn_red":    {"frame": 192, "occupancy": 0.40, "walk": ["pawn_red_walk", 10], "idle": ["pawn_red_idle", 6]},
	"pawn_yellow": {"frame": 192, "occupancy": 0.40, "walk": ["pawn_yellow_walk", 14], "idle": ["pawn_yellow_idle", 6]},
	"pawn_purple": {"frame": 192, "occupancy": 0.40, "walk": ["pawn_purple_walk", 12], "idle": ["pawn_purple_idle", 6]},
	"pawn_black":  {"frame": 192, "occupancy": 0.40, "walk": ["pawn_black_walk", 12], "idle": ["pawn_black_idle", 6]},
	"archer_red":  {"frame": 192, "occupancy": 0.47, "walk": ["archer_red_walk", 8], "idle": ["archer_red_idle", 6], "attack": ["archer_red_attack", 12]},
	"warrior_black": {"frame": 192, "occupancy": 0.48, "walk": ["warrior_black_walk", 8], "idle": ["warrior_black_idle", 6], "guard": ["warrior_black_guard", 8]},
	"warrior_red": {"frame": 192, "occupancy": 0.62, "walk": ["warrior_red_walk", 10], "idle": ["warrior_red_idle", 6], "attack": ["warrior_red_attack", 10]},
	"warrior_yellow": {"frame": 192, "occupancy": 0.48, "walk": ["warrior_yellow_walk", 8], "idle": ["warrior_yellow_idle", 6]},
	"lancer_purple": {"frame": 320, "occupancy": 0.47, "walk": ["lancer_purple_walk", 8], "idle": ["lancer_purple_idle", 8], "guard": ["lancer_purple_guard", 8]},
	"lancer_red":  {"frame": 320, "occupancy": 0.48, "walk": ["lancer_red_walk", 8], "idle": ["lancer_red_idle", 8], "attack": ["lancer_red_attack", 8]},
	"lancer_yellow": {"frame": 320, "occupancy": 0.47, "walk": ["lancer_yellow_walk", 8], "idle": ["lancer_yellow_idle", 8]},
	"monk_black":  {"frame": 192, "occupancy": 0.63, "walk": ["monk_black_walk", 8], "idle": ["monk_black_idle", 6], "cast": ["monk_black_cast", 12]},
	"monk_purple": {"frame": 192, "occupancy": 0.63, "walk": ["monk_purple_walk", 8], "idle": ["monk_purple_idle", 6], "cast": ["monk_purple_cast", 12]},
	"monk_blue":   {"frame": 192, "occupancy": 0.63, "walk": ["monk_blue_walk", 8], "idle": ["monk_blue_idle", 6], "cast": ["monk_blue_cast", 12]},
	"blood":       {"frame": 100, "occupancy": 0.31, "walk": ["blood_walk", 10], "idle": ["blood_idle", 6], "hurt": ["blood_hurt", 14, false], "death": ["blood_death", 10, false], "attack": ["blood_attack", 10, false]},
	"demon":       {"frame": 100, "occupancy": 0.35, "walk": ["demon_walk", 10], "idle": ["demon_idle", 6], "hurt": ["demon_hurt", 14, false], "death": ["demon_death", 10, false], "attack": ["demon_attack", 10, false]},
	## Feuilles a cases RECTANGULAIRES : "frame" est la largeur, "frame_h" la hauteur.
	## "count" borne les cases quand la derniere colonne est vide.
	"golem_blue":   {"frame": 90, "frame_h": 64, "occupancy": 0.66,
		"walk": ["golem_blue_walk", 10], "idle": ["golem_blue_idle", 6],
		"hurt": ["golem_blue_hurt", 12, false], "attack": ["golem_blue_attack", 12, false],
		"death": ["golem_blue_death", 10, false]},
	"golem_orange": {"frame": 90, "frame_h": 64, "occupancy": 0.66,
		"walk": ["golem_orange_walk", 10], "idle": ["golem_orange_idle", 6],
		"hurt": ["golem_orange_hurt", 12, false], "attack": ["golem_orange_attack", 12, false],
		"death": ["golem_orange_death", 10, false]},
	"flyer":        {"frame": 64, "occupancy": 0.83,
		"walk": ["flyer_walk", 12], "idle": ["flyer_idle", 8],
		"hurt": ["flyer_hurt", 12, false], "attack": ["flyer_attack", 14, false],
		"death": ["flyer_death", 12, false]},
	"peacock":      {"frame": 32, "frame_h": 32, "occupancy": 1.00,
		"walk": ["peacock_walk", 8], "idle": ["peacock_idle", 5]},
	## Enemies Pack : petites creatures, bandes composees depuis les images unitaires.
	"dog":     {"frame": 33, "frame_h": 26, "occupancy": 0.88,
		"walk": ["dog_walk", 8], "idle": ["dog_idle", 5]},
	"beetle":  {"frame": 36, "frame_h": 39, "occupancy": 0.87,
		"walk": ["beetle_walk", 8]},
	"dino":    {"frame": 32, "frame_h": 26, "occupancy": 0.85,
		"walk": ["dino_walk", 8], "idle": ["dino_idle", 5]},
	## Attention : dans ce pack le dossier "Slimer" est l animation de MORT (la gelee
	## fond puis eclate) et "Slimer-Idle" est la boucle vivante.
	"slimer":  {"frame": 41, "frame_h": 38, "occupancy": 0.66,
		"walk": ["slimer_walk", 8], "idle": ["slimer_idle", 5],
		"death": ["slimer_death", 10, false]},
	"vulture": {"frame": 39, "frame_h": 39, "occupancy": 0.74,
		"walk": ["vulture_walk", 8], "idle": ["vulture_idle", 5]},
	## Le totem est un batiment : texture fixe.
	"totem_tower": {"static": "totem_tower", "occupancy": 0.72},
}

## Teintes legeres pour distinguer deux familles qui partagent une feuille.
const MODULATE: Dictionary = {
	"chronos": Color(1.0, 0.75, 0.75),
	## Le dino du pack est rose vif : trop tendre pour un devoreur.
	"glutton": Color(0.55, 0.45, 0.70),
	## Le "chien" du pack est un petit saurien rose ; la Sauterelle est verte.
	"hopper": Color(0.62, 0.95, 0.45),
	## Le vautour est brun : l Ombre doit rester spectrale.
	"shade": Color(0.42, 0.42, 0.62, 0.80),
}


static func has(key: StringName) -> bool:
	return UNITS.has(String(key))


static func keys() -> Array:
	return UNITS.keys()


static func is_static(key: StringName) -> bool:
	return has(key) and UNITS[String(key)].has("static")


static func static_texture(key: StringName) -> Texture2D:
	if not is_static(key):
		return null
	return SheetLib.texture(U + str(UNITS[String(key)]["static"]) + ".png")


static func frame_px(key: StringName) -> int:
	if not has(key):
		return 192
	var u: Dictionary = UNITS[String(key)]
	if u.has("static"):
		var t: Texture2D = static_texture(key)
		return int(t.get_height()) if t != null else 256
	# L echelle se calcule sur la HAUTEUR de case. Une case large (golem 90x64) est
	# large pour loger le balayage de l attaque, pas parce que le monstre est large :
	# prendre la largeur le rendrait enorme en permanence.
	return int(u.get("frame_h", u.get("frame", 192)))


static func occupancy(key: StringName) -> float:
	if not has(key):
		return 0.55
	return float(UNITS[String(key)].get("occupancy", 0.55))


static func has_anim(key: StringName, anim: String) -> bool:
	return has(key) and UNITS[String(key)].has(anim)


## Chemins de toutes les feuilles d une cle (pour l AUDIT).
static func sheet_paths(key: StringName) -> Array[String]:
	var out: Array[String] = []
	if not has(key):
		return out
	var u: Dictionary = UNITS[String(key)]
	if u.has("static"):
		out.append(U + str(u["static"]) + ".png")
		return out
	for k in u:
		if u[k] is Array:
			out.append(U + str(u[k][0]) + ".png")
	return out


static func frames(key: StringName) -> SpriteFrames:
	if not has(key) or is_static(key):
		return null
	var u: Dictionary = UNITS[String(key)]
	var spec: Dictionary = {}
	for anim in u:
		if not (u[anim] is Array):
			continue
		var a: Array = u[anim]
		spec[anim] = {
			"path": U + str(a[0]) + ".png",
			"frame": int(u["frame"]),
			"fps": float(a[1]),
			"loop": bool(a[2]) if a.size() > 2 else true,
		}
		# Cases rectangulaires (golems 90x64, paon 36x38) : sans cela la decoupe
		# prend toute la hauteur de la feuille et les cases se chevauchent.
		if u.has("frame_h"):
			spec[anim]["frame_h"] = int(u["frame_h"])
	return SheetLib.frames("unit:" + String(key), spec)


static func modulate_for(enemy_id: StringName) -> Color:
	return MODULATE.get(String(enemy_id), Color.WHITE)
