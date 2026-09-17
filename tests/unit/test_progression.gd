extends TestCase
## Progression : XP, montee de niveau, distribution des raretes.

func get_suite_name() -> String:
	return "progression"


func run() -> void:
	_test_xp_scales_with_speed()
	_test_level_up()
	_test_rarity_weights_sum()
	_test_rarity_distribution()
	_test_cost_reduction()


func _test_xp_scales_with_speed() -> void:
	RunState.reset()
	SpeedGauge.reset()
	var got: Array[int] = [0]
	var on_xp := func(amount: int) -> void: got[0] = amount
	RunState.xp_gained.connect(on_xp)

	RunState.gain_xp(4)
	eq(got[0], 4, "XP brute a x1")

	SpeedGauge.set_step(3)
	RunState.gain_xp(4)
	eq(got[0], 16, "XP multipliee par 4 a x4")

	RunState.xp_gained.disconnect(on_xp)


func _test_level_up() -> void:
	RunState.reset()
	SpeedGauge.reset()
	var levels: Array[int] = []
	var on_level := func(n: int) -> void: levels.append(n)
	RunState.level_up.connect(on_level)

	eq(RunState.level, 1, "on demarre niveau 1")
	RunState.gain_xp(GameConfig.xp_required(1))
	eq(RunState.level, 2, "atteindre le seuil fait monter d'un niveau")
	eq(levels.size(), 1, "level_up emis une fois")

	RunState.level_up.disconnect(on_level)


func _test_rarity_weights_sum() -> void:
	var total: float = 0.0
	for r: GameEnums.Rarity in GameConfig.RARITY_WEIGHTS:
		total += GameConfig.RARITY_WEIGHTS[r]
	feq(total, 1.0, "les poids de rarete totalisent 1.0")
	# Lecture validee du cahier des charges.
	feq(GameConfig.RARITY_WEIGHTS[GameEnums.Rarity.RARE], 0.80, "rare = 80 %")
	feq(GameConfig.RARITY_WEIGHTS[GameEnums.Rarity.EPIC], 0.15, "epique = 15 %")
	feq(GameConfig.RARITY_WEIGHTS[GameEnums.Rarity.LEGENDARY], 0.05, "legendaire = 5 %")


## Tirage seede : deterministe, jamais instable.
func _test_rarity_distribution() -> void:
	RunState.reset()
	RunState.set_seed(20260916)
	var counts: Dictionary = {
		GameEnums.Rarity.RARE: 0,
		GameEnums.Rarity.EPIC: 0,
		GameEnums.Rarity.LEGENDARY: 0,
	}
	var n: int = 10000
	for i in n:
		counts[RunState.roll_rarity()] += 1

	var rare_pct: float = 100.0 * counts[GameEnums.Rarity.RARE] / n
	var epic_pct: float = 100.0 * counts[GameEnums.Rarity.EPIC] / n
	var leg_pct: float = 100.0 * counts[GameEnums.Rarity.LEGENDARY] / n

	between(rare_pct, 78.0, 82.0, "rare proche de 80 %")
	between(epic_pct, 13.0, 17.0, "epique proche de 15 %")
	between(leg_pct, 3.5, 6.5, "legendaire proche de 5 %")


func _test_cost_reduction() -> void:
	RunState.reset()
	SpeedGauge.reset()
	var card := SpellCard.new()
	card.base_cast_time = 4.0

	feq(RunState.effective_cast_time(card), 4.0, "cast nominal a x1")

	RunState.apply_cost_reduction(1.0, 5.0)
	feq(RunState.effective_cast_time(card), 3.0, "la reduction retire 1 s")

	SpeedGauge.set_step(3)
	feq(RunState.effective_cast_time(card), 0.75, "reduction puis multiplicateur a x4")

	# La reduction expire.
	RunState.tick(5.1)
	SpeedGauge.set_step(0)
	feq(RunState.effective_cast_time(card), 4.0, "la reduction a expire")
