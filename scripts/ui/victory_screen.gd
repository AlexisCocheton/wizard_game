extends Control
## Ecran de victoire : resume, badges d objectifs, legendaire debloquee.
## Toute la logique de progression vit dans SaveData.record_victory() — testee
## a froid — cet ecran ne fait que l afficher.

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _objectives: VBoxContainer = %Objectives
@onready var _menu_btn: Button = %MenuButton


func _ready() -> void:
	theme = UiTheme.make()
	_menu_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	_title.text = "NIVEAU TERMINE"
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)

	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	var level: LevelDef = ContentDB.levels.get(level_id)
	_summary.text = "Niveau joueur %d   -   %d vagues survecues" % [
		RunState.level, RunState.wave_index]
	_summary.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	if level == null:
		return

	var done: Dictionary = {}
	for obj in level.objectives:
		if obj != null:
			done[obj.id] = ObjectiveChecker.evaluate(obj)

	var newly: bool = SaveData.record_victory(level, RunState.mode, done, RunState.wave_index)
	SaveData.save_profile()

	for obj in level.objectives:
		if obj == null:
			continue
		var ok: bool = bool(done.get(obj.id, false))
		_objectives.add_child(UiTheme.label("%s  %s" % ["[OK]" if ok else "[   ]", obj.description],
			UiTheme.FONT_BODY, Color(0.2, 0.5, 0.25) if ok else Color(0.45, 0.35, 0.25)))
	if newly and level.legendary_reward != null:
		_objectives.add_child(UiTheme.label("Legendaire debloquee : %s" % level.legendary_reward.display_name,
			UiTheme.FONT_BODY, UiTheme.GOLD))
	if not level.next_levels.is_empty():
		_objectives.add_child(UiTheme.label("Niveau suivant debloque", UiTheme.FONT_BODY, UiTheme.TEAL))
