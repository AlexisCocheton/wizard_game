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
	_title.add_theme_color_override(&"font_color", UiTheme.INK_DANGER)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)
	_summary.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	var waves: int = SceneRouter.payload.get("waves", RunState.wave_index)
	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	# MODES (chantier M) : le record est range selon le MODE. L ancienne ligne
	# ecrivait dans level_record(level_id) quel que soit le mode, ce qui creait
	# une fiche de niveau "massacre" fantome. Vague 10 : le LIBRE n ecrit aucun
	# record (SaveData.record_run_waves), l Infini par niveau n existe plus.
	SaveData.record_run_waves(level_id, RunState.mode, waves)
	var resume: String = "%d vagues survecues" % waves
	if RunState.mode == GameEnums.Mode.MASSACRE:
		resume += "   -   record %d" % SaveData.massacre_best_wave()
	# Le record sur la MEME ligne debordait du papier (vu sur la capture
	# defaite_massacre) : en mode sans fin, le niveau du joueur passe dessous.
	var sep: String = "
" if GameEnums.is_endless(RunState.mode) else "   -   "
	_summary.text = "%s%sniveau joueur %d" % [resume, sep, RunState.level]
	_retry_btn.pressed.connect(func() -> void:
		SceneRouter.start_level(level_id, RunState.mode))
	_menu_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	# VAGUE 10 : le bilan et le conseil peuvent depasser la page ; REJOUER et MENU
	# restent en bas, hors defilement, sous le pouce.
	TouchScroll.wrap(_breakdown)
	_build_breakdown()
	SaveData.save_profile()


## Ce qui a tue le joueur, mesure pendant la partie.
## Sans ce bilan, l ecran disait combien de vagues on avait tenu mais jamais
## pourquoi on etait mort : impossible de corriger son deck ou sa visee.
##
## VAGUE 10 : en DEGATS (vitesse retiree) et non plus en coups — un contact de
## boss et une fleche de gnome ne valaient pas autant — avec le portrait de
## chaque monstre et un conseil concret contre le premier (BattleReport,
## ThreatLore). L ancien conseil generique (« garde un sort pour... ») n est
## plus que le repli d un monstre sans trait.
func _build_breakdown() -> void:
	_breakdown.add_theme_constant_override(&"separation", 14)
	BattleReport.build(_breakdown, false)
