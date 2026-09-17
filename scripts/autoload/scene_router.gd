extends Node
## Transitions de scene + charge utile entre ecrans.

signal scene_changed(path: String)

const MAIN_MENU: String = "res://scenes/main_menu/MainMenu.tscn"
const GAME: String = "res://scenes/game/Game.tscn"
const LOADING: String = "res://scenes/loading/LoadingScreen.tscn"
const VICTORY: String = "res://scenes/endgame/VictoryScreen.tscn"
const DEFEAT: String = "res://scenes/endgame/DefeatScreen.tscn"

## Donnees transmises a la scene suivante (niveau choisi, mode, resultats...).
var payload: Dictionary = {}


func goto(path: String, data: Dictionary = {}) -> void:
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
func start_level(level_id: StringName, mode: GameEnums.Mode) -> void:
	goto(LOADING, {"level_id": level_id, "mode": mode})
