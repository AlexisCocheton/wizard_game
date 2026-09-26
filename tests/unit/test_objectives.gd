extends TestCase
## Objectifs de niveau : les 3 regles du cahier des charges.

func get_suite_name() -> String:
	return "objectives"


func _obj(key: String) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName("t_" + key)
	o.check_key = StringName(key)
	o.description = key
	return o


func run() -> void:
	_test_keys_exist()
	_test_never_dropped_speed()
	_test_no_legendary()
	_test_no_damage()


func _test_keys_exist() -> void:
	ok(ObjectiveChecker.has_key(&"never_dropped_speed"), "cle vitesse connue")
	ok(ObjectiveChecker.has_key(&"no_legendary_used"), "cle legendaire connue")
	ok(ObjectiveChecker.has_key(&"no_damage_taken"), "cle degats connue")
	not_ok(ObjectiveChecker.has_key(&"cle_inventee"), "une cle inconnue est rejetee")


## Depuis que la vitesse EST la vie, cet objectif demande DEUX choses : ne
## jamais avoir ete touche, ET finir au maximum. Sans la seconde, il serait
## devenu le jumeau exact de no_damage_taken (voir objective_checker.gd).
func _test_never_dropped_speed() -> void:
	RunState.reset()
	SpeedGauge.reset()
	var obj := _obj("never_dropped_speed")

	not_ok(ObjectiveChecker.evaluate(obj),
		"echoue tant que la vitesse n est pas au maximum")
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	ok(ObjectiveChecker.evaluate(obj),
		"valide au maximum tant que la jauge n est pas tombee")

	RunState.note_speed_drop()
	not_ok(ObjectiveChecker.evaluate(obj), "echoue des que la vitesse a baisse")
	SpeedGauge.reset()


func _test_no_legendary() -> void:
	RunState.reset()
	var obj := _obj("no_legendary_used")
	ok(ObjectiveChecker.evaluate(obj), "valide avant toute legendaire")

	var leg := SpellCard.new()
	leg.id = &"leg"
	leg.rarity = GameEnums.Rarity.LEGENDARY
	RunState.hand.append(leg)
	RunState.play_card(leg)
	not_ok(ObjectiveChecker.evaluate(obj), "echoue des qu une legendaire est jouee")


func _test_no_damage() -> void:
	RunState.reset()
	var obj := _obj("no_damage_taken")
	ok(ObjectiveChecker.evaluate(obj), "valide avant tout degat")
	RunState.note_damage_taken()
	not_ok(ObjectiveChecker.evaluate(obj), "echoue apres un degat subi")
