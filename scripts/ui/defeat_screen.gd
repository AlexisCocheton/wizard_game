extends Control
## Ecran de defaite : resume et options.

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _breakdown: VBoxContainer = %Objectives
@onready var _retry_btn: Button = %RetryButton
@onready var _menu_btn: Button = %MenuButton


func _ready() -> void:
	theme = UiTheme.make()
	_title.text = "DEFAITE"
	_title.add_theme_color_override(&"font_color", UiTheme.RED)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)
	_summary.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	var waves: int = SceneRouter.payload.get("waves", RunState.wave_index)
	_summary.text = "%d vagues survecues   -   niveau joueur %d" % [waves, RunState.level]
	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	_retry_btn.pressed.connect(func() -> void:
		SceneRouter.start_level(level_id, RunState.mode))
	_menu_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	_build_breakdown()
	var record: Dictionary = SaveData.level_record(level_id)
	record["best_wave"] = maxi(int(record.get("best_wave", 0)), waves)
	SaveData.save_profile()


## Ce qui a tue le joueur, compte pendant la partie par RunState.
## Sans ce bilan, l ecran disait combien de vagues on avait tenu mais jamais
## pourquoi on etait mort : impossible de corriger son deck ou sa visee.
func _build_breakdown() -> void:
	var sources: Dictionary = RunState.hits_by_source
	if sources.is_empty():
		return
	_breakdown.add_theme_constant_override(&"separation", 8)
	_breakdown.add_child(UiTheme.label("CE QUI T A EU", UiTheme.FONT_BODY, UiTheme.GOLD))
	var noms: Array = sources.keys()
	noms.sort_custom(func(a, b): return int(sources[a]) > int(sources[b]))
	for nom in noms:
		var n: int = int(sources[nom])
		_breakdown.add_child(UiTheme.label(
			"%s  -  %d coup%s" % [nom, n, "s" if n > 1 else ""],
			UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
	var pire: String = RunState.worst_threat()
	if pire != "" and sources.size() > 1:
		_breakdown.add_child(UiTheme.label("La prochaine fois, garde un sort pour %s." % pire,
			UiTheme.FONT_SMALL, UiTheme.TEAL))
