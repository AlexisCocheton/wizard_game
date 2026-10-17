@static_unload
class_name CleanExit
extends RefCounted
## SORTIE COMMUNE des etages du harnais et des outils (vague 10, chantier C3).
## Personne n appelle `get_tree().quit()` en direct : `test_clean_exit` balaye
## scripts/, tests/ et tools/ et refuse tout appel nu.
##
## LE DEFAUT. Depuis la vague 10, un etage ou un banc finissait son travail,
## imprimait son marqueur (« [AUDIT] OK », « === FIN === »), puis le moteur
## plantait PENDANT sa fermeture : « CrashHandlerException: signal 11 », code 139,
## compte FAIL par le harnais. Mesure au chantier C3 (lanceur de N fermetures en
## parallele, voir gotchas) :
##   - une scene qui ne fait QUE charger les autoloads puis quitte plante 5 a 12
##     fois sur 100 ; un projet vide (ou un autoload a 3000 ressources) 0 sur 300 ;
##   - le plantage tombe TOUJOURS dans ScriptServer::finish_languages(), la boucle
##     ou GDScript vide ses scripts (temoins imprimes a la liberation) ;
##   - vider les caches statiques, ContentDB, liberer les autoloads ou attendre
##     des images avant le quit n y change RIEN ;
##   - `@static_unload` sur les scripts a static var le fait tomber a 0 : en 4.4.0
##     ces scripts restent tenus par le cache statique de GDScript, que la
##     fermeture ne vide pas (corrige en 4.4.1, GH-104281). `test_clean_exit`
##     exige l annotation sur tout script a static var.
##
## CE QUE FAIT LA SORTIE. Le correctif est l annotation ; cette sortie est le seul
## endroit ou mettre un contournement de fermeture s il en faut un autre demain.
## Elle libere tot ce qui peut l etre (les caches a ressources, les noeuds en
## attente), laisse passer deux images pour que les liberations differees se
## fassent pendant que tout le moteur est encore debout, puis quitte avec le PIRE
## code demande.

## Le code retenu : le premier code d echec gagne. Un second appel a 0 n efface
## jamais un echec (le piege documente dans smoke_driver : quit(1) puis quit(0)).
static var _code: int = 0
static var _demandee: bool = false

## Imprime sur stderr juste avant le quit du moteur. tools/run_tests.sh le
## cherche (texte exact) : ne pas le changer sans changer le harnais.
const EXIT_MARK: String = "[SORTIE] quit(%d)"


## Quitte le moteur avec `code` (0 = vert). Rend la main tout de suite : la
## sortie se fait deux images plus tard. L appelant n a rien a attendre ; un
## `return` juste apres reste la bonne facon de s arreter.
static func quit(code: int = 0) -> void:
	_code = worst_code(_code, code)
	if _demandee:
		return
	_demandee = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	release_static_caches()
	GameController.free_queued_below(tree.root)
	await tree.process_frame
	await tree.process_frame
	# Repere sur stderr, LE MEME FLUX que la banniere du gestionnaire de plantage :
	# run_tests.sh y lit qu un signal 11 est tombe APRES la sortie demandee.
	printerr(EXIT_MARK % _code)
	tree.quit(_code)


## Le pire de deux codes de sortie : le premier echec gagne.
static func worst_code(deja: int, demande: int) -> int:
	return deja if deja != 0 else demande


## Vide les caches statiques qui tiennent des RESSOURCES (textures decoupees,
## materiau du sceau, fonte, vignettes, portraits). Ils se reconstruisent a la
## demande : appeler ceci en cours de jeu ne casse rien, ca coute de les refaire.
static func release_static_caches() -> void:
	SheetLib.clear_cache()
	UiTheme._font = null
	UiTheme._visible_cache.clear()
	UiTheme._preview_cache.clear()
	CardView._seal_material = null
	CampaignMap._portrait_cache.clear()
