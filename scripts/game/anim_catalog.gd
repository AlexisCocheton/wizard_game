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
	"warrior_red": {"frame": 192, "occupancy": 0.48, "walk": ["warrior_red_walk", 10], "idle": ["warrior_red_idle", 6], "attack": ["warrior_red_attack", 10]},
	"warrior_yellow": {"frame": 192, "occupancy": 0.48, "walk": ["warrior_yellow_walk", 8], "idle": ["warrior_yellow_idle", 6]},
	"lancer_purple": {"frame": 320, "occupancy": 0.45, "walk": ["lancer_purple_walk", 8], "idle": ["lancer_purple_idle", 8], "guard": ["lancer_purple_guard", 8]},
	"lancer_red":  {"frame": 320, "occupancy": 0.45, "walk": ["lancer_red_walk", 8], "idle": ["lancer_red_idle", 8], "attack": ["lancer_red_attack", 8]},
	"lancer_yellow": {"frame": 320, "occupancy": 0.45, "walk": ["lancer_yellow_walk", 8], "idle": ["lancer_yellow_idle", 8]},
	"monk_black":  {"frame": 192, "occupancy": 0.43, "walk": ["monk_black_walk", 8], "idle": ["monk_black_idle", 6], "cast": ["monk_black_cast", 12]},
	"monk_purple": {"frame": 192, "occupancy": 0.43, "walk": ["monk_purple_walk", 8], "idle": ["monk_purple_idle", 6], "cast": ["monk_purple_cast", 12]},
	"monk_blue":   {"frame": 192, "occupancy": 0.43, "walk": ["monk_blue_walk", 8], "idle": ["monk_blue_idle", 6], "cast": ["monk_blue_cast", 12]},
	"blood":       {"frame": 100, "occupancy": 0.20, "walk": ["blood_walk", 10], "idle": ["blood_idle", 6], "hurt": ["blood_hurt", 14, false], "death": ["blood_death", 10, false], "attack": ["blood_attack", 10, false]},
	"demon":       {"frame": 100, "occupancy": 0.22, "walk": ["demon_walk", 10], "idle": ["demon_idle", 6], "hurt": ["demon_hurt", 14, false], "death": ["demon_death", 10, false], "attack": ["demon_attack", 10, false]},
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
	## Oiseau mirage. Les planches du pack sont des grilles 4 DIRECTIONS x N poses :
	## une COLONNE est une direction, une LIGNE une pose. La premiere extraction
	## avait pris une LIGNE, donc quatre orientations a la suite — l oiseau
	## semblait pivoter sur lui meme en marchant. Les bandes "_front_" sont la
	## colonne de FACE, celle que montre un monstre qui descend vers le mage.
	## Voir tools/assets/extract_peacock.py.
	"peacock":      {"frame": 32, "frame_h": 32, "occupancy": 0.78,
		"walk": ["peacock_front_walk", 8], "idle": ["peacock_front_idle", 5]},
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
	## Boule de poison du Planogo. Pas de feuille dediee dans les packs : on
	## reprend la silhouette de la gelee, qui est deja une masse ronde sans
	## membres — exactement ce qu on veut lire comme "projectile" — et la teinte
	## verte du poison est posee par MODULATE. Cle distincte de "slimer" pour
	## que la Gelee garde sa propre couleur.
	"poison_ball": {"frame": 41, "frame_h": 38, "occupancy": 0.66,
		"walk": ["slimer_idle", 8], "idle": ["slimer_idle", 5],
		"death": ["slimer_death", 12, false]},
	"vulture": {"frame": 39, "frame_h": 39, "occupancy": 0.74,
		"walk": ["vulture_walk", 8], "idle": ["vulture_idle", 5]},
	## Duelyst (atlas recomposes par tools/assets/extract_duelyst.py) : reserve aux
	## boss, dont la silhouette doit ecraser celle des monstres ordinaires.
	"juggernaut":  {"frame": 120, "frame_h": 120, "occupancy": 0.73,
		"walk": ["juggernaut_walk", 10], "idle": ["juggernaut_idle", 8],
		"hurt": ["juggernaut_hurt", 12, false], "attack": ["juggernaut_attack", 18, false],
		"death": ["juggernaut_death", 14, false]},
	"chaosknight": {"frame": 140, "frame_h": 140, "occupancy": 0.56,
		"walk": ["chaosknight_walk", 10], "idle": ["chaosknight_idle", 8],
		"hurt": ["chaosknight_hurt", 12, false], "attack": ["chaosknight_attack", 18, false],
		"death": ["chaosknight_death", 14, false]},
	## Boss a mecanique unique (docs/histoire.md). Meme pack Duelyst : leur
	## silhouette plus fine et plus sombre doit trancher sur les monstres du
	## bestiaire ordinaire.
	"unhallowed":  {"frame": 120, "frame_h": 120, "occupancy": 0.45,
		"walk": ["unhallowed_walk", 10], "idle": ["unhallowed_idle", 8],
		"hurt": ["unhallowed_hurt", 12, false], "attack": ["unhallowed_attack", 18, false],
		"death": ["unhallowed_death", 14, false]},
	"decepticle":  {"frame": 100, "frame_h": 100, "occupancy": 0.33,
		"walk": ["decepticle_walk", 10], "idle": ["decepticle_idle", 8],
		"hurt": ["decepticle_hurt", 12, false], "attack": ["decepticle_attack", 18, false],
		"death": ["decepticle_death", 14, false]},
	"wraith":      {"frame": 120, "frame_h": 120, "occupancy": 0.62,
		"walk": ["wraith_walk", 10], "idle": ["wraith_idle", 8],
		"hurt": ["wraith_hurt", 12, false], "attack": ["wraith_attack", 18, false],
		"death": ["wraith_death", 14, false]},
	## Le totem est un batiment : texture fixe.
	"totem_tower": {"static": "totem_tower", "occupancy": 0.72},
	## --- PACKS DU 26 SEPTEMBRE ---
	## Quatorze silhouettes neuves, extraites par
	## tools/assets/extract_packs_2026_09_26.py. Geometrie et occupation
	## MESUREES sur les feuilles livrees, jamais reprises d un readme :
	## les cases de ces packs sont souvent plus petites que la planche
	## ne le laisse croire, et une occupation supposee donne un monstre
	## minuscule ou geant. `walk` et `idle` bouclent, le reste joue une
	## fois.
	"flyingeye": {"frame": 56, "frame_h": 56, "occupancy": 0.73,
		"walk": ["flyingeye_walk", 8], "attack": ["flyingeye_attack", 8, false], "hurt": ["flyingeye_hurt", 4, false], "death": ["flyingeye_death", 4, false]},
	"goblin2": {"frame": 88, "frame_h": 88, "occupancy": 0.41,
		"walk": ["goblin2_walk", 8], "idle": ["goblin2_idle", 4], "attack": ["goblin2_attack", 8, false], "hurt": ["goblin2_hurt", 4, false], "death": ["goblin2_death", 4, false]},
	"mushroom": {"frame": 71, "frame_h": 71, "occupancy": 0.52,
		"walk": ["mushroom_walk", 8], "idle": ["mushroom_idle", 4], "attack": ["mushroom_attack", 8, false], "hurt": ["mushroom_hurt", 4, false], "death": ["mushroom_death", 4, false]},
	"skeleton2": {"frame": 98, "frame_h": 98, "occupancy": 0.52,
		"walk": ["skeleton2_walk", 4], "idle": ["skeleton2_idle", 4], "attack": ["skeleton2_attack", 8, false], "hurt": ["skeleton2_hurt", 4, false], "death": ["skeleton2_death", 4, false], "shield": ["skeleton2_shield", 4, false]},
	"evilwizard": {"frame": 94, "frame_h": 94, "occupancy": 0.59,
		"walk": ["evilwizard_walk", 8], "idle": ["evilwizard_idle", 8], "attack": ["evilwizard_attack", 8, false], "hurt": ["evilwizard_hurt", 4, false], "death": ["evilwizard_death", 5, false]},
	"fireworm": {"frame": 77, "frame_h": 77, "occupancy": 0.66,
		"walk": ["fireworm_walk", 9], "idle": ["fireworm_idle", 9], "attack": ["fireworm_attack", 16, false], "hurt": ["fireworm_hurt", 3, false], "death": ["fireworm_death", 8, false]},
	"ghoul": {"frame": 45, "frame_h": 45, "occupancy": 0.51,
		"walk": ["ghoul_walk", 6], "idle": ["ghoul_idle", 10], "attack": ["ghoul_attack", 10, false], "hurt": ["ghoul_hurt", 5, false], "death": ["ghoul_death", 7, false]},
	"gorgon": {"frame": 128, "frame_h": 128, "occupancy": 0.60,
		"walk": ["gorgon_walk", 13], "idle": ["gorgon_idle", 7], "attack": ["gorgon_attack", 16, false], "hurt": ["gorgon_hurt", 3, false], "death": ["gorgon_death", 3, false]},
	"bluewitch": {"frame": 48, "frame_h": 48, "occupancy": 0.79,
		"walk": ["bluewitch_walk", 8], "idle": ["bluewitch_idle", 6], "attack": ["bluewitch_attack", 5, false], "hurt": ["bluewitch_hurt", 3, false], "death": ["bluewitch_death", 10, false]},
	"smallmonster": {"frame": 81, "frame_h": 81, "occupancy": 0.35,
		"walk": ["smallmonster_walk", 6], "idle": ["smallmonster_idle", 6], "attack": ["smallmonster_attack", 13, false], "death": ["smallmonster_death", 8, false]},
	"mageguardian": {"frame": 58, "frame_h": 58, "occupancy": 0.97,
		"idle": ["mageguardian_idle", 4], "attack": ["mageguardian_attack", 6, false], "death": ["mageguardian_death", 4, false]},
	"demonslime": {"frame": 210, "frame_h": 210, "occupancy": 0.50,
		"walk": ["demonslime_walk", 12], "idle": ["demonslime_idle", 6], "attack": ["demonslime_attack", 15, false], "hurt": ["demonslime_hurt", 5, false], "death": ["demonslime_death", 22, false]},
	"nightborne": {"frame": 77, "frame_h": 77, "occupancy": 0.45,
		"walk": ["nightborne_walk", 6], "idle": ["nightborne_idle", 9], "attack": ["nightborne_attack", 12, false], "hurt": ["nightborne_hurt", 5, false], "death": ["nightborne_death", 23, false]},
	"executioner": {"frame": 84, "frame_h": 84, "occupancy": 0.74,
		"idle": ["executioner_idle", 8], "attack": ["executioner_attack", 12, false], "death": ["executioner_death", 18, false], "summon": ["executioner_summon", 5, false]},
}

## Teintes legeres pour distinguer deux familles qui partagent une feuille.
const MODULATE: Dictionary = {
	## Le dino du pack est rose vif : trop tendre pour un devoreur.
	"glutton": Color(0.55, 0.45, 0.70),
	## Le "chien" du pack est un petit saurien rose ; la Sauterelle est verte.
	"hopper": Color(0.62, 0.95, 0.45),
	## Le vautour est brun : l Ombre doit rester spectrale.
	"shade": Color(0.42, 0.42, 0.62, 0.80),
	## La boule de poison reprend la gelee : il faut un vert franc, nettement
	## plus acide que celui de la Gelee, pour qu on ne confonde pas une munition
	## avec un monstre qu il vaut la peine de tuer.
	"poison_ball": Color(0.45, 1.00, 0.30),

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
