extends StageRunner
## ETAGE UNIT — regles de gameplay testees a froid, sans lancer le jeu.
## C'est l'etage qui permet de modifier le code sans re-tester le jeu a la main.

const SUITES: Array[String] = [
	"res://tests/unit/test_speed_gauge.gd",
	"res://tests/unit/test_deck.gd",
	"res://tests/unit/test_progression.gd",
	"res://tests/unit/test_objectives.gd",
	"res://tests/unit/test_nav_grid.gd",
	"res://tests/unit/test_targeting.gd",
	"res://tests/unit/test_wall.gd",
	"res://tests/unit/test_enemy_feedback.gd",
	"res://tests/unit/test_deck_rules.gd",
	"res://tests/unit/test_menu_data.gd",
	"res://tests/unit/test_wave_budget.gd",
	"res://tests/unit/test_balance.gd",
	"res://tests/unit/test_speed_percent.gd",
	"res://tests/unit/test_precast.gd",
	"res://tests/unit/test_passives.gd",
	"res://tests/unit/test_account.gd",
	"res://tests/unit/test_card_icons.gd",
	"res://tests/unit/test_card_view.gd",
	"res://tests/unit/test_briefing.gd",
	"res://tests/unit/test_enemy_behaviors.gd",
	"res://tests/unit/test_card_choice.gd",
	"res://tests/unit/test_sheet_lib.gd",
	"res://tests/unit/test_new_spells.gd",
	"res://tests/unit/test_bestiary.gd",
	"res://tests/unit/test_bosses.gd",
	"res://tests/unit/test_campaign_map.gd",
	"res://tests/unit/test_story.gd",
	"res://tests/unit/test_elements.gd",
	"res://tests/unit/test_upgrades.gd",
]

var _total_checks: int = 0


func stage_name() -> String:
	return "UNIT"


func run_stage() -> void:
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			fail("%s : suite illisible" % path)
			continue
		var suite: TestCase = script.new()
		suite.suite_name = suite.get_suite_name()
		# Etat remis a zero entre chaque suite : sinon l'etat des autoloads fuit
		# d'un test a l'autre et les echecs deviennent dependants de l'ordre.
		SpeedGauge.reset()
		RunState.reset()
		suite.run()
		_total_checks += suite.check_count()
		var fails: Array[String] = suite.failures()
		if fails.is_empty():
			print("  PASS  %-14s (%d verifications)" % [suite.suite_name, suite.check_count()])
		else:
			print("  FAIL  %-14s (%d echecs)" % [suite.suite_name, fails.size()])
			for f in fails:
				fail("%s: %s" % [suite.suite_name, f])
	print("[UNIT] %d verifications" % _total_checks)
