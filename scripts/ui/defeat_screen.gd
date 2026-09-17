extends Control
## Ecran de defaite : resume et options.

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
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
	var record: Dictionary = SaveData.level_record(level_id)
	record["best_wave"] = maxi(int(record.get("best_wave", 0)), waves)
	SaveData.save_profile()
