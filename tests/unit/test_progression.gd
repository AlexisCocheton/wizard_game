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
	_test_les_reglages_de_depart_du_combat()


func _test_xp_scales_with_speed() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var got: Array[int] = [0]
	var on_xp := func(amount: int) -> void: got[0] = amount
	RunState.xp_gained.connect(on_xp)

	RunState.gain_xp(4)
	eq(got[0], 4, "XP brute a x1")

	SpeedGauge.set_speed_percent(400)
	RunState.gain_xp(4)
	eq(got[0], 16, "XP multipliee par 4 a x4")

	RunState.xp_gained.disconnect(on_xp)


func _test_level_up() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
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
	reset_gauge_at_normal_speed()
	var card := SpellCard.new()
	card.base_cast_time = 4.0
	# Le multiplicateur GLOBAL s applique a tout : les attentes sont exprimees
	# contre lui, jamais en secondes brutes. Ce test disait "4,0 s" en dur et a
	# rougi des que le testeur a rallonge les incantations — or c est
	# exactement le reglage qu il doit pouvoir changer sans casser un test.
	var k: float = GameConfig.CAST_TIME_SCALE

	feq(RunState.effective_cast_time(card), 4.0 * k, "cast nominal a x1")

	RunState.apply_cost_reduction(1.0, 5.0)
	# La reduction retire 1 s a la BASE, donc avant le multiplicateur.
	feq(RunState.effective_cast_time(card), 3.0 * k, "la reduction retire 1 s")

	SpeedGauge.set_speed_percent(400)
	feq(RunState.effective_cast_time(card), 0.75 * k,
		"reduction puis multiplicateur a x4")

	# La reduction expire.
	RunState.tick(5.1)
	SpeedGauge.set_speed_percent(100)
	feq(RunState.effective_cast_time(card), 4.0 * k, "la reduction a expire")


## Les trois reglages de depart demandes le 27 septembre.
##
## Ils sont testes ENSEMBLE parce qu ils decrivent une meme chose : les
## premieres secondes d un combat. Et ils sont exprimes CONTRE les constantes,
## jamais contre un nombre : `eq(cast, 2.1)` bloquerait le prochain reglage du
## testeur, qui est justement la personne pour qui ces constantes existent.
func _test_les_reglages_de_depart_du_combat() -> void:
	# A. Le multiplicateur global RALLONGE et ne raccourcit pas.
	ok(GameConfig.CAST_TIME_SCALE >= 1.0,
		"le multiplicateur d incantation rallonge (x%.2f)" % GameConfig.CAST_TIME_SCALE)
	# Il s applique a TOUS les sorts dans la meme proportion : c est ce qui
	# preserve la hierarchie reglee carte par carte.
	reset_gauge_at_normal_speed()
	RunState.reset()
	var vus: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive or c.base_cast_time < 0.5:
			continue  # sous 0,5 s le plancher de 0,1 s peut mordre
		var attendu: float = c.base_cast_time * GameConfig.CAST_TIME_SCALE
		var reel: float = RunState.effective_cast_time(c)
		ok(absf(reel - attendu) < 0.02,
			"%s : %.2f s attendu, %.2f s obtenu" % [c.id, attendu, reel])
		vus += 1
	ok(vus >= 20, "assez de sorts verifies (%d)" % vus)

	# B. Le combat commence a la vitesse reglee, et elle est AU-DESSUS du
	#    plancher mortel — sinon le mage nait mort.
	SpeedGauge.reset()
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_START_PERCENT,
		"le combat demarre a SPEED_START_PERCENT")
	ok(GameConfig.SPEED_START_PERCENT > 100,
		"la vitesse de depart est au-dessus du plancher mortel de 100 %")

	# C. La main de depart est plus PETITE que le plafond : sinon le joueur
	#    commence plein et la pioche ne sert plus a rien dans les premieres
	#    secondes, ce qui est exactement l inverse de la demande.
	ok(GameConfig.START_HAND_SIZE >= 1,
		"on commence avec au moins une carte jouable")
	ok(GameConfig.START_HAND_SIZE < GameConfig.MAX_HAND_SIZE,
		"la main de depart (%d) est sous le plafond (%d)"
		% [GameConfig.START_HAND_SIZE, GameConfig.MAX_HAND_SIZE])
