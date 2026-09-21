extends Node
## Transitions de scene + charge utile entre ecrans.
##
## Il porte aussi le fil de l HISTOIRE (docs/histoire.md) : c est le seul
## endroit qui sait qu entre "le joueur appuie sur JOUER" et "le briefing
## s affiche" il peut y avoir une ou plusieurs scenes de visual novel, et
## qu entre "victoire" et "ecran de victoire" il peut y en avoir une autre.
## Ni le menu, ni GameController, ni l ecran de victoire n ont a le savoir.

signal scene_changed(path: String)

const MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const GAME: String = "res://scenes/game/Game.tscn"
const LOADING: String = "res://scenes/loading/LoadingScreen.tscn"
const VICTORY: String = "res://scenes/endgame/VictoryScreen.tscn"
const DEFEAT: String = "res://scenes/endgame/DefeatScreen.tscn"
const STORY: String = "res://scenes/story/StoryScene.tscn"

## Le prologue n appartient a aucun niveau : il se joue avant l intro du
## premier, une seule fois par profil.
const PROLOGUE_STORY: StringName = &"prologue"
const FIRST_LEVEL: StringName = &"lvl_01"

## Donnees transmises a la scene suivante (niveau choisi, mode, resultats...).
var payload: Dictionary = {}

## Faux en headless : le smoke et le banc d equilibrage appellent start_level()
## et attendent le briefing, pas une scene de dialogue qui attend un doigt.
## Les tests unitaires le forcent pour verifier le plan de route sans changer
## de scene (plan_level_start ne route pas, il repond).
var stories_enabled: bool = true

## Scenes restant a jouer avant de reprendre la route, et la destination.
var _story_queue: Array[StringName] = []
var _story_next_path: String = ""
var _story_next_payload: Dictionary = {}
## Vrai pendant la reprise apres une scene : evite que goto(VICTORY) intercepte
## a nouveau l outro qu on vient de jouer (elle est marquee vue, mais un
## drapeau explicite ne depend pas de la persistance).
var _resuming: bool = false


func _ready() -> void:
	stories_enabled = DisplayServer.get_name() != "headless"


func goto(path: String, data: Dictionary = {}) -> void:
	# La victoire passe par l outro du niveau si elle n a jamais ete vue.
	# GameController appelle goto(VICTORY) sans rien savoir de l histoire.
	if path == VICTORY and not _resuming:
		var outro: StringName = story_outro_for(data.get("level_id", &""), RunState.mode)
		if outro != &"":
			_start_story_chain([outro], VICTORY, data)
			return
	_resuming = false
	payload = data
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var err: int = tree.change_scene_to_file(path)
	if err != OK:
		push_error("Changement de scene impossible : %s (err %d)" % [path, err])
		return
	scene_changed.emit(path)


## Passe par l ecran de briefing : le joueur voit ce qui l attend avant de jouer.
## Avant lui, les scenes d histoire non vues (prologue puis intro du niveau).
func start_level(level_id: StringName, mode: GameEnums.Mode) -> void:
	var plan: Dictionary = plan_level_start(level_id, mode)
	if plan.get("stories", []).is_empty():
		goto(LOADING, plan["payload"])
		return
	_start_story_chain(plan["stories"], LOADING, plan["payload"])


## Ce que start_level VA faire, sans le faire : le test unitaire s en sert
## pour verifier la route sans changer la scene du lanceur de tests.
##   {"path": premiere scene, "stories": [ids a jouer], "payload": pour le briefing}
func plan_level_start(level_id: StringName, mode: GameEnums.Mode) -> Dictionary:
	var stories: Array[StringName] = stories_before_level(level_id, mode)
	return {
		"path": STORY if not stories.is_empty() else LOADING,
		"stories": stories,
		"payload": {"level_id": level_id, "mode": mode},
	}


## Les scenes a jouer avant ce niveau, dans l ordre, en sautant celles deja vues.
## Seule l Exploration raconte l histoire : le Massacre est le mode infini,
## diegetiquement la boucle APRES la fin (docs/histoire.md, epilogue).
func stories_before_level(level_id: StringName, mode: GameEnums.Mode) -> Array[StringName]:
	var out: Array[StringName] = []
	if not stories_enabled or mode != GameEnums.Mode.EXPLORATION:
		return out
	if level_id == FIRST_LEVEL and not SaveData.is_story_seen(PROLOGUE_STORY):
		out.append(PROLOGUE_STORY)
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level != null and level.intro_story != &"" and not SaveData.is_story_seen(level.intro_story):
		out.append(level.intro_story)
	# Une scene nommee mais absente du disque est ignoree : le jeu ne bloque
	# pas sur un .tres manquant, c est test_story.gd qui le signale.
	var present: Array[StringName] = []
	for id in out:
		if DialogueDef.load_by_id(id) != null:
			present.append(id)
	return present


## L outro a jouer a la victoire de ce niveau, ou &"" s il n y en a pas / deja vue.
func story_outro_for(level_id: StringName, mode: GameEnums.Mode) -> StringName:
	if not stories_enabled or mode != GameEnums.Mode.EXPLORATION:
		return &""
	var level: LevelDef = ContentDB.levels.get(level_id)
	if level == null or level.outro_story == &"" or SaveData.is_story_seen(level.outro_story):
		return &""
	if DialogueDef.load_by_id(level.outro_story) == null:
		return &""
	return level.outro_story


## Appele par StoryScene quand la scene est finie ou passee : on la retient
## comme vue, puis on joue la suivante ou on reprend la route.
func story_finished(story_id: StringName) -> void:
	SaveData.mark_story_seen(story_id)
	SaveData.save_profile()
	_play_next_story()


## Pour les tests : la file en attente (copie).
func pending_stories() -> Array[StringName]:
	return _story_queue.duplicate()


func _start_story_chain(stories: Array[StringName], next_path: String,
		next_payload: Dictionary) -> void:
	_story_queue = stories.duplicate()
	_story_next_path = next_path
	_story_next_payload = next_payload
	_play_next_story()


func _play_next_story() -> void:
	if _story_queue.is_empty():
		var path: String = _story_next_path
		var data: Dictionary = _story_next_payload
		_story_next_path = ""
		_story_next_payload = {}
		if path == "":
			return
		_resuming = true
		goto(path, data)
		return
	var id: StringName = _story_queue.pop_front()
	# Le payload de la scene d histoire ne porte que son id : la destination
	# reste ici, pour que la scene n ait pas a la transporter.
	_resuming = false
	goto(STORY, {"story_id": id})
