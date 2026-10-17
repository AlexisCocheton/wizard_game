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
## parallele, variantes alternees sous la meme charge ; detail dans gotchas,
## « Signal 11 A LA FERMETURE ») :
##   - une scene qui ne fait QUE charger les autoloads puis quitte plante 4 a 12
##     fois sur 100 ; audit et ci_load 2 sur 100 ; un projet vide, 0 ;
##   - le plantage tombe TOUJOURS dans ScriptServer::finish_languages(), la boucle
##     ou GDScript vide ses scripts (temoins imprimes a la liberation) ;
##   - vider les caches statiques, ContentDB, liberer les autoloads ou attendre
##     des images avant le quit n y change RIEN ;
##   - le taux bouge des qu on ajoute ou retire un script : il depend du GRAPHE
##     des scripts charges, pas de ce qu ils contiennent.
##
## LA CAUSE (source 4.4.0 lue, confirmee par la mesure). GDScriptLanguage::finish()
## parcourt la liste des scripts du plus recent au plus ancien. Il tient le script
## courant (`scr`) le temps de le vider, lit le SUIVANT, puis relache `scr`. Si ce
## relachement detruit en cascade le script suivant (un script de base que seul
## `scr` tenait encore), la boucle repart d un pointeur libere. Le plantage n a
## lieu que si cette memoire a deja ete reutilisee : d ou l intermittence, et la
## sensibilite a la charge.
##
## LE CONTOURNEMENT : `hold_loaded_scripts()`. Juste avant de quitter, GameConfig
## (le PREMIER script cree, donc le DERNIER vide) recoit une reference forte a
## chaque script charge. Aucun script ne peut alors mourir en fin d iteration :
## ils meurent tous ensemble quand la boucle vide GameConfig, a l interieur de son
## clear(), AVANT la lecture du suivant (il n y en a plus). Mesure, sous la meme
## charge que la copie d origine : 0 plantage sur 600 fermetures (audit 0/100,
## ci_load 0/100, autoloads seuls 0/400), contre 21 sur 700 sans lui.
##
## Le reste de la sortie (caches, noeuds en attente, deux images) libere tot ce
## qui peut l etre ; mesure : sans effet sur le taux, garde parce qu il ne coute
## rien et que les bancs liberent ainsi leurs ressources avant le moteur.

## Le code retenu : le premier code d echec gagne. Un second appel a 0 n efface
## jamais un echec (le piege documente dans smoke_driver : quit(1) puis quit(0)).
static var _code: int = 0
static var _demandee: bool = false

## Dossiers sautes en cherchant les scripts charges : le cache d import, les
## worktrees des agents (copies completes du depot), et les dossiers sans script.
const SKIP_DIRS: Array[String] = [".godot", ".claude", ".git", ".testout", "raw_assets", "assets", "resources"]


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
	# EN DERNIER : tout script charge d ici la doit etre tenu.
	hold_loaded_scripts()
	tree.quit(_code)


## Le pire de deux codes de sortie : le premier echec gagne.
static func worst_code(deja: int, demande: int) -> int:
	return deja if deja != 0 else demande


## Fait tenir par GameConfig chaque script charge (fichiers .gd en cache, puis
## leurs classes internes et les scripts qu ils prechargent). Rend la liste.
## Sans danger en jeu : ces scripts sont deja tenus par le cache de GDScript.
static func hold_loaded_scripts() -> Array:
	var tenus: Array = []
	_collect_loaded("res://", tenus)
	var i: int = 0
	while i < tenus.size():
		var s: GDScript = tenus[i]
		for v in s.get_script_constant_map().values():
			if v is GDScript and not tenus.has(v):
				tenus.append(v)
		i += 1
	GameConfig.hold_scripts(tenus)
	return tenus


static func _collect_loaded(dossier: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dossier)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		if f.ends_with(".gd"):
			var chemin: String = dossier.path_join(f)
			if ResourceLoader.has_cached(chemin):
				out.append(load(chemin))
	for sous in d.get_directories():
		if sous not in SKIP_DIRS:
			_collect_loaded(dossier.path_join(sous), out)


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
