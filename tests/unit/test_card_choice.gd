extends TestCase
## Choix de 3 sorts : a la montee de niveau (Exploration) ou toutes les N vagues (Massacre).

func get_suite_name() -> String:
	return "card_choice"


func run() -> void:
	_test_offre_de_trois()
	_test_choix_rejoint_la_defausse()
	_test_choix_invalide()
	_test_montee_de_niveau_propose()
	_test_cadence_massacre()


func _test_offre_de_trois() -> void:
	RunState.reset()
	RunState.set_seed(77)
	var cards: Array[SpellCard] = RunState.offer_choices(3)
	eq(cards.size(), 3, "trois propositions")
	ok(cards[0] != cards[1] and cards[1] != cards[2] and cards[0] != cards[2], "toutes distinctes")
	eq(RunState.pending_offer.size(), 3, "l offre est en attente")


func _test_choix_rejoint_la_defausse() -> void:
	RunState.reset()
	RunState.set_seed(78)
	var cards: Array[SpellCard] = RunState.offer_choices(3)
	var before: int = RunState.total_cards()
	var picked: SpellCard = RunState.pick_offer(1)
	eq(picked, cards[1], "la carte choisie est renvoyee")
	ok(RunState.discard.has(picked), "elle rejoint la defausse")
	eq(RunState.total_cards(), before + 1, "le deck grandit d une carte")
	eq(RunState.pending_offer.size(), 0, "l offre est consommee")


func _test_choix_invalide() -> void:
	RunState.reset()
	RunState.offer_choices(3)
	eq(RunState.pick_offer(7), null, "index hors bornes : rien")
	eq(RunState.pending_offer.size(), 3, "l offre reste en attente")
	RunState.reset()


func _test_montee_de_niveau_propose() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	eq(RunState.pending_offer.size(), 0, "pas d offre au depart")
	RunState.gain_xp(GameConfig.xp_required(1))
	eq(RunState.pending_offer.size(), 3, "la montee de niveau propose 3 sorts")
	var cards: int = RunState.total_cards()
	# La partie est en pause : rien ne bouge tant qu on n a pas choisi.
	g.simulate(1.0)
	ok(g.choose_card(0) != null, "le choix est pris")
	eq(RunState.total_cards(), cards + 1, "le deck a grandi")
	eq(RunState.pending_offer.size(), 0, "plus d offre en attente")
	detach(g)
	RunState.reset()
	SpeedGauge.reset()


func _test_cadence_massacre() -> void:
	eq(GameController.WAVES_PER_CHOICE, 2, "un choix toutes les 2 vagues en Massacre")
