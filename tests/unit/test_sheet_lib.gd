extends TestCase
## Decoupe des spritesheets : le nombre de cases doit correspondre aux feuilles.

func get_suite_name() -> String:
	return "sheet_lib"


func run() -> void:
	_test_bande()
	_test_grille()
	_test_catalogue()
	_test_cache()
	_test_chaque_feuille_est_au_catalogue()


func _test_bande() -> void:
	var tex: Texture2D = SheetLib.texture("res://assets/units/pawn_red_walk.png")
	ok(tex != null, "la feuille du pion existe")
	eq(SheetLib.strip_count(tex, 192), 6, "Pawn_Run : 6 cases de 192")
	var monk: Texture2D = SheetLib.texture("res://assets/units/monk_blue_cast.png")
	eq(SheetLib.strip_count(monk, 192), 11, "Monk Heal : 11 cases")


func _test_grille() -> void:
	var tex: Texture2D = SheetLib.texture("res://assets/fx/magickahit.png")
	eq(SheetLib.grid(tex, 100).size(), 49, "magickahit : 7x7 cases")
	var frz: Texture2D = SheetLib.texture("res://assets/fx/freezing.png")
	eq(SheetLib.grid(frz, 100).size(), 100, "freezing : 10x10 cases")


func _test_catalogue() -> void:
	var sf: SpriteFrames = AnimCatalog.frames(&"archer_red")
	ok(sf != null, "frames de l archer")
	ok(sf.has_animation("walk") and sf.has_animation("attack"), "walk et attack presents")
	eq(sf.get_frame_count("attack"), 8, "Archer_Shoot : 8 cases")
	ok(AnimCatalog.is_static(&"totem_tower"), "le totem est une texture fixe")
	ok(AnimCatalog.static_texture(&"totem_tower") != null, "et elle se charge")
	for e: EnemyDef in ContentDB.enemies.values():
		ok(AnimCatalog.has(e.anim_key), "%s a une feuille (%s)" % [e.id, e.anim_key])


func _test_cache() -> void:
	var a: SpriteFrames = AnimCatalog.frames(&"blood")
	var b: SpriteFrames = AnimCatalog.frames(&"blood")
	ok(a == b, "le cache renvoie la meme instance")


## Toute feuille posee dans assets/units/ doit etre INSCRITE au catalogue.
##
## Le defaut que ceci empeche : j ai insere quatorze silhouettes neuves dans le
## mauvais dictionnaire d `anim_catalog.gd` — dans MODULATE, la table des
## teintes, au lieu d UNITS. Le fichier COMPILAIT parfaitement, le harnais
## restait vert sur sept etages, et les quatorze creatures etaient simplement
## introuvables. Une sonde qui interroge `AnimCatalog.has()` l a montre :
## 0 sur 14.
##
## Une feuille extraite mais non inscrite est du travail perdu que rien ne
## signale : ni l AUDIT (qui verifie le contenu, pas les assets orphelins), ni
## la compilation, ni les captures.
func _test_chaque_feuille_est_au_catalogue() -> void:
	var dir: DirAccess = DirAccess.open("res://assets/units/")
	ok(dir != null, "assets/units/ existe")
	if dir == null:
		return
	# On regroupe par SILHOUETTE : "gorgon_walk.png" -> "gorgon".
	var silhouettes: Dictionary = {}
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue
		var base: String = f.trim_suffix(".png")
		var coupe: int = base.rfind("_")
		if coupe <= 0:
			continue
		var anim: String = base.substr(coupe + 1)
		# Seules les animations connues designent une silhouette ; un fichier
		# comme "tower_blue.png" n en est pas une.
		if not (anim in ["walk", "idle", "attack", "hurt", "death",
				"summon", "shield", "cast", "guard"]):
			continue
		silhouettes[base.substr(0, coupe)] = true

	ok(silhouettes.size() >= 20,
		"assets/units/ porte au moins 20 silhouettes (%d)" % silhouettes.size())
	var orphelines: Array[String] = []
	for cle in silhouettes:
		if AnimCatalog.has(StringName(cle)):
			continue
		# DEUX EXCEPTIONS LEGITIMES, verifiees dans le code avant d etre
		# ecrites ici — une exception non verifiee est un trou, pas une regle.
		#
		# 1. `monk_hat_*` : les chapeaux cosmetiques. Ils ne sont PAS des
		#    silhouettes de jeu ; `UiTheme.mage_frames()` les decoupe lui-meme,
		#    parce qu un catalogue de monstres n a pas a connaitre la garde-robe
		#    du joueur.
		# 2. `peacock_front` : deja reference par le catalogue, mais SOUS UN
		#    AUTRE NOM d entree — le fichier est cite, la cle differe.
		if String(cle).begins_with("monk_hat_"):
			continue
		var citee: bool = false
		for entree in AnimCatalog.UNITS.values():
			for v in (entree as Dictionary).values():
				if v is Array and v.size() > 0 						and String(v[0]).begins_with(String(cle) + "_"):
					citee = true
		if citee:
			continue
		orphelines.append(String(cle))
	orphelines.sort()
	ok(orphelines.is_empty(),
		"aucune feuille orpheline (hors catalogue : %s)"
		% ", ".join(orphelines))
