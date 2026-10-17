extends TestCase
## SORTIE COMMUNE (vague 10, chantier C3) : personne n appelle `quit()` en direct.
##
## POURQUOI LE BALAYAGE DES SOURCES. Le signal 11 A LA FERMETURE (voir gotchas)
## tombe APRES le marqueur de reussite, pendant le nettoyage du moteur. La sortie
## commune `CleanExit.quit()` est le seul endroit qui sait l eviter. Un
## etage ou un outil ajoute demain avec un `get_tree().quit(0)` nu retrouverait le
## plantage, invisible au harnais tant que le tirage ne tombe pas dessus : le
## balayage le refuse des l ecriture, comme `test_touch_scroll` refuse un
## `ScrollContainer.new()` nu.

## Le seul fichier qui appelle `SceneTree.quit()`.
const SORTIE: String = "res://scripts/game/clean_exit.gd"

## Fichiers dont la ligne de sortie appartient a un autre chantier. A RETIRER de
## cette liste des que le fichier passe par CleanExit.
##   make_story.gd : generateur de l histoire, hors perimetre du chantier C3
##                   (chantier histoire en parallele) ; outil lance a la main,
##                   jamais par le harnais.
const EN_ATTENTE: Array[String] = [
	"res://tools/make_story.gd",
]

const DOSSIERS: Array[String] = ["res://scripts", "res://tests", "res://tools"]


func get_suite_name() -> String:
	return "clean_exit"


func run() -> void:
	_test_le_pire_code_gagne()
	_test_aucun_quit_direct()
	_test_le_detecteur_mord()
	_test_les_caches_se_vident()
	_test_game_config_ouvre_la_liste()
	_test_le_porteur_tient_tout()
	_test_static_var_sans_static_unload()
	_test_le_detecteur_static_mord()


## LE CONTOURNEMENT DU PLANTAGE (voir CleanExit) repose sur un fait d ordre : le
## porteur des scripts, GameConfig, est le PREMIER script cree, donc le DERNIER
## que GDScript vide en quittant. Il l est parce qu il est le premier autoload.
## Le deplacer dans la liste rendrait le porteur inutile, sans aucun symptome
## avant le prochain signal 11 : ce test le refuse.
func _test_game_config_ouvre_la_liste() -> void:
	var premier: String = ""
	var dans_autoload: bool = false
	for brute in FileAccess.get_file_as_string("res://project.godot").split("\n"):
		var l: String = brute.strip_edges()
		if l.begins_with("["):
			dans_autoload = l == "[autoload]"
			continue
		if dans_autoload and l.contains("="):
			premier = l.get_slice("=", 0)
			break
	eq(premier, "GameConfig", "GameConfig est le premier autoload (porteur des scripts a la fermeture)")


## Le porteur tient TOUT : les scripts en cache, les classes internes, la sortie
## elle-meme et GameConfig (qui se tient lui-meme : sinon il pourrait mourir avant
## la boucle et lacher les autres au mauvais moment).
func _test_le_porteur_tient_tout() -> void:
	var tenus: Array = CleanExit.hold_loaded_scripts()
	ok(tenus.size() > 20, "des dizaines de scripts tenus (%d)" % tenus.size())
	ok(tenus.has(load(SORTIE)), "la sortie commune est tenue")
	ok(tenus.has(load("res://scripts/autoload/game_config.gd")), "GameConfig se tient lui-meme")
	ok(tenus.has(get_script()), "le script de cette suite est tenu")
	ok(tenus.has(EffectHandlers.DamageSingle), "une classe interne est tenue")
	eq(GameConfig.held_scripts().size(), tenus.size(), "c est GameConfig qui les tient")
	var doubles: Dictionary = {}
	for s in tenus:
		doubles[s] = true
	eq(doubles.size(), tenus.size(), "aucun script tenu deux fois")
	# Rien a garder pendant le reste de l etage : la vraie sortie refait la liste.
	GameConfig.hold_scripts([])


## AUSSI MESURE AU CHANTIER C3 (voir gotchas) : en 4.4.0, un script a `static
## var` SANS `@static_unload` est tenu par le cache statique de GDScript
## (GDScriptCache::static_gdscript_cache), que la fermeture ne vide pas (corrige
## en 4.4.1, GH-104281) : il meurt APRES la boucle de fermeture, hors de portee
## du porteur. Tout script a static var porte donc `@static_unload` : en jeu il
## ne change rien (le cache complet de GDScript tient deja chaque script charge
## jusqu a la fermeture), il ne joue qu a la sortie.
func _test_static_var_sans_static_unload() -> void:
	var fautifs: Array[String] = []
	for dossier in DOSSIERS:
		for chemin in _fichiers(dossier, ".gd"):
			if sans_static_unload(FileAccess.get_file_as_string(chemin)):
				fautifs.append(chemin)
	ok(fautifs.is_empty(),
		"static var sans @static_unload en tete (plantage a la fermeture) : %s" % str(fautifs))


func _test_le_detecteur_static_mord() -> void:
	ok(sans_static_unload("class_name A\nextends RefCounted\nstatic var x: int = 0\n"),
		"une static var sans l annotation est vue")
	not_ok(sans_static_unload("@static_unload\nclass_name A\nextends RefCounted\nstatic var x: int = 0\n"),
		"l annotation en tete suffit")
	not_ok(sans_static_unload("class_name A\nextends RefCounted\nstatic func f() -> void:\n\tpass\n"),
		"une fonction statique n est pas une donnee statique")
	not_ok(sans_static_unload("extends Node\n## static var x en commentaire\n"),
		"un commentaire n est pas une static var")
	ok(sans_static_unload("class_name A\nextends RefCounted\n@static_unload\nstatic var x: int = 0\n"),
		"l annotation APRES class_name ne compte pas (elle doit preceder la classe)")


## Un etage rouge reste rouge : un second appel a 0 n efface pas un echec.
func _test_le_pire_code_gagne() -> void:
	eq(CleanExit.worst_code(0, 0), 0, "deux sorties propres : 0")
	eq(CleanExit.worst_code(0, 1), 1, "un echec apres un succes : 1")
	eq(CleanExit.worst_code(1, 0), 1, "un succes apres un echec n efface pas l echec")
	eq(CleanExit.worst_code(2, 1), 2, "le premier code d echec est garde")


func _test_aucun_quit_direct() -> void:
	var directs: Array[String] = []
	for dossier in DOSSIERS:
		for chemin in _fichiers(dossier, ".gd"):
			if chemin == SORTIE or chemin in EN_ATTENTE:
				continue
			for ligne in quits_directs(FileAccess.get_file_as_string(chemin)):
				directs.append("%s:%d" % [chemin, ligne])
	ok(directs.is_empty(),
		"quit() appele en direct (passer par CleanExit.quit) : %s" % str(directs))
	# La liste d attente ne doit pas devenir un depotoir : chaque fichier y est
	# encore REELLEMENT en attente.
	for chemin in EN_ATTENTE:
		ok(not quits_directs(FileAccess.get_file_as_string(chemin)).is_empty(),
			"%s passe par CleanExit : le retirer de EN_ATTENTE" % chemin)


## Le detecteur lui-meme, sur des sources ecrites ici : il doit voir les formes
## reelles d un quit et ignorer les commentaires. Les sources d essai ecrivent
## `@Q` a la place de l appel : ce fichier-ci est balaye comme les autres, et
## un appel ecrit en clair dans une chaine le ferait rougir lui-meme.
func _test_le_detecteur_mord() -> void:
	eq(quits_directs(_q("func _f() -> void:\n\tget_tree()@Q(0)\n")), [2],
		"un quit nu sur get_tree() est vu")
	eq(quits_directs(_q("\tvar t := get_tree()\n\tt@Q(code)\n")), [2],
		"un quit sur une variable est vu")
	eq(quits_directs(_q("\t(Engine.get_main_loop() as SceneTree)@Q()\n")), [1],
		"un quit sans code est vu")
	eq(quits_directs(_q("\tget_tree()@Q.call_deferred(1)\n")), [1],
		"un quit differe est vu")
	eq(quits_directs(_q("## get_tree()@Q(code) ne stoppe pas l execution\n")), [],
		"un commentaire n est pas un appel")
	eq(quits_directs("\tCleanExit.quit(1)\n"), [],
		"la sortie commune n est pas un quit direct")
	eq(quits_directs(_q("\tCleanExit.quit(1)\n\tget_tree()@Q(1)\n")), [2],
		"un quit nu a cote de la sortie commune est vu")
	eq(quits_directs(_q("\tprint(\"x\")  # puis get_tree()@Q()\n")), [],
		"un quit en fin de ligne commentee n est pas un appel")


## `@Q` -> l appel au quit du moteur (voir _test_le_detecteur_mord).
func _q(source: String) -> String:
	return source.replace("@Q", "." + "quit")


## Les caches statiques qui tiennent des RESSOURCES sont vides apres le menage.
func _test_les_caches_se_vident() -> void:
	SheetLib.frames("c3:test", {})
	ok(not SheetLib._cache.is_empty(), "le cache des feuilles a une entree")
	CardView.seal_material()
	ok(CardView._seal_material != null, "le materiau du sceau est cree")
	CleanExit.release_static_caches()
	ok(SheetLib._cache.is_empty(), "cache des feuilles vide")
	ok(CardView._seal_material == null, "materiau du sceau libere")
	ok(UiTheme._font == null, "fonte liberee")
	ok(UiTheme._visible_cache.is_empty(), "mesures de silhouette videes")
	ok(UiTheme._preview_cache.is_empty(), "vignettes videes")
	ok(CampaignMap._portrait_cache.is_empty(), "portraits vides")
	# Un cache vide se reconstruit a la demande : rien n est casse pour la suite.
	ok(CardView.seal_material() != null, "le sceau se recree apres le menage")


## Numeros des lignes (a partir de 1) qui appellent quit() en direct. Le texte
## apres un `#` est un commentaire (aucune chaine du projet ne contient de quit).
static func quits_directs(source: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("\\.quit\\b\\s*(\\(|\\.call_deferred)")
	var lignes: PackedStringArray = source.split("\n")
	for i in lignes.size():
		var code: String = lignes[i].split("#")[0].replace("CleanExit.quit", "")
		if re.search(code) != null:
			out.append(i + 1)
	return out


## Vrai si le script declare une `static var` (classe principale ou interne) sans
## porter `@static_unload` AVANT sa premiere ligne de classe (`class_name` /
## `extends`) : c est la que le moteur l attend.
static func sans_static_unload(source: String) -> bool:
	var a_static: bool = false
	var annote: bool = false
	var en_tete: bool = true
	for brute in source.split("\n"):
		var l: String = brute.split("#")[0].strip_edges()
		if l.is_empty():
			continue
		if en_tete:
			if l == "@static_unload":
				annote = true
				continue
			if l.begins_with("class_name") or l.begins_with("extends"):
				en_tete = false
		if l.begins_with("static var "):
			a_static = true
	return a_static and not annote


func _fichiers(dossier: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dossier.path_join(f))
	for sous in d.get_directories():
		out.append_array(_fichiers(dossier.path_join(sous), ext))
	return out
