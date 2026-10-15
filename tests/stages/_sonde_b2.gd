extends StageRunner
## SONDE TEMPORAIRE DU CHANTIER B2 (a supprimer avant le commit final) : lance
## les suites nommees par la variable d environnement SONDE_SUITES (noms courts,
## separes par des virgules), pour iterer sans jouer les 70 suites.

func stage_name() -> String:
	return "SONDE"


func run_stage() -> void:
	for nom in OS.get_environment("SONDE_SUITES").split(",", false):
		var path: String = "res://tests/unit/%s.gd" % nom.strip_edges()
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			fail("%s : suite illisible" % path)
			continue
		var suite: TestCase = script.new()
		suite.suite_name = suite.get_suite_name()
		SpeedGauge.reset()
		RunState.reset()
		suite.run()
		var fails: Array[String] = suite.failures()
		print("  %s  %-14s (%d verifications, %d echecs)" % ["PASS" if fails.is_empty() else "FAIL",
			suite.suite_name, suite.check_count(), fails.size()])
		for f in fails:
			fail("%s: %s" % [suite.suite_name, f])
