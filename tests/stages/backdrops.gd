extends Node
## Etage VISUEL des fonds peints : pose chaque fond d acte sous de vrais monstres
## et capture le resultat dans .testout/.
##
## POURQUOI un etage a part : le smoke ne joue qu un niveau (lvl_01), donc une
## seule ambiance. Un fond mal compose (sol etire sur un arbre, monstre sombre
## invisible sur une pierre sombre) ne se voit qu a l oeil, et seulement si on
## regarde les QUATRE. Le headless n execute rien derriere Fx.enabled().
##
## Il verifie aussi, lui, une regle qui doit tenir sans oeil humain : chaque cle
## de LevelDef.backdrop doit designer un fichier existant. C est le test qui
## verrouille la correction — un chemin casse par un renommage rougit ici.

const ACT_KEYS: Array[String] = ["act1_sky", "act2_graveyard", "act3_demon", "act4_origin"]

var _failed: bool = false
var _shot: int = 0


func _ready() -> void:
	await _run_all()
	_finish()


func _run_all() -> void:
	_check_files_exist()
	_check_levels_point_to_real_files()
	if DisplayServer.get_name() == "headless":
		print("[BACKDROPS] headless : captures sautees")
		return
	for key in ACT_KEYS:
		await _shoot_backdrop(key)


## Les 4 fonds composes doivent etre presents dans res://.
##
## On charge REELLEMENT la texture au lieu d appeler ResourceLoader.exists() :
## verifie en supprimant act3_demon.png, l etage restait VERT. Le cache d import
## (.godot/imported/*.ctex) survit a la disparition du PNG source, et exists()
## repond oui sur la foi du seul .import. Un test qui ne peut pas echouer n a pas
## sa place dans le harnais (voir gotchas.md).
func _check_files_exist() -> void:
	for key in ACT_KEYS:
		var path: String = "res://assets/backdrops/%s.png" % key
		if not FileAccess.file_exists(path):
			_fail("fond manquant sur le disque : %s (relancer tools/assets/compose_backdrops.py)" % path)
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null or tex.get_width() <= 0:
			_fail("fond illisible : %s" % path)
			continue
		# Les fonds sont composes en 1080x1920 : une autre taille signale un
		# script de composition modifie sans que le jeu soit relu.
		if tex.get_width() != 1080 or tex.get_height() != 1920:
			_fail("%s fait %dx%d, attendu 1080x1920" % [path, tex.get_width(), tex.get_height()])
			continue
		print("[BACKDROPS] ok %s (%dx%d)" % [path, tex.get_width(), tex.get_height()])


## Un niveau qui nomme un fond doit nommer un fond QUI EXISTE. Sans ce controle,
## une faute de frappe dans make_content.gd retomberait silencieusement sur les
## tuiles et personne ne le verrait avant une capture.
func _check_levels_point_to_real_files() -> void:
	for id in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[id]
		if lvl == null or lvl.backdrop.is_empty():
			continue
		var path: String = "res://assets/backdrops/%s.png" % lvl.backdrop
		if not ResourceLoader.exists(path):
			_fail("%s : backdrop \"%s\" ne designe aucun fichier" % [id, lvl.backdrop])


## Pose le fond, un mage et quelques monstres dessus, puis capture.
func _shoot_backdrop(key: String) -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.running = false
	# On impose la cle a la main : cet etage teste le RENDU du fond, pas la
	# resolution via RunState (que le smoke exerce deja).
	g.backdrop.setup("grass", key)
	# Des monstres de tailles et de teintes variees : c est le contraste
	# monstre/fond qu on vient juger, surtout sur les fonds sombres.
	var ids: Array[StringName] = [&"gnome", &"golem", &"shade", &"behemoth", &"void_knight"]
	var i: int = 0
	for id in ids:
		var def: EnemyDef = ContentDB.enemies.get(id)
		if def == null:
			continue
		var x: float = 200.0 + i * 170.0
		g.battlefield.spawn_enemy(def, x, 1.0, Vector2(x, 400.0 + (i % 2) * 260.0))
		i += 1
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		_shot += 1
		var dir: String = ProjectSettings.globalize_path("res://.testout")
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png("%s/bg_%02d_%s.png" % [dir, _shot, key])
		print("[BACKDROPS] capture : bg_%02d_%s.png" % [_shot, key])
	g.queue_free()
	await get_tree().process_frame


func _fail(msg: String) -> void:
	push_error("[BACKDROPS] " + msg)
	print("[BACKDROPS] ECHEC : " + msg)
	_failed = true


## Un seul point de sortie : voir gotchas.md, quit() ne stoppe pas l execution.
func _finish() -> void:
	if _failed:
		print("BACKDROPS_FAIL")
		get_tree().quit(1)
		return
	print("BACKDROPS_OK")
	get_tree().quit(0)
