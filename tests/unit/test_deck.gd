extends TestCase
## Deck : pioche, remelange, conservation des cartes, main.

func get_suite_name() -> String:
	return "deck"


func _card(id: String, copies: int = 0, rarity: int = GameEnums.Rarity.COMMON) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.copies_in_starter = copies
	c.rarity = rarity
	c.base_cast_time = 2.0
	return c


func run() -> void:
	_test_starter_deck()
	_test_draw()
	_test_reshuffle_conserves_cards()
	_test_draw_timer()
	_test_hand_limit()
	_test_play_card()
	_test_pioche_suit_la_vitesse()


func _test_starter_deck() -> void:
	RunState.reset()
	RunState.set_seed(1234)
	var cards: Array[SpellCard] = [_card("spark", 4), _card("frost", 3)]
	RunState.build_starter_deck(cards)
	eq(RunState.deck.size(), 7, "le deck de depart contient 4+3 cartes")
	eq(RunState.hand.size(), 0, "la main demarre vide")


func _test_draw() -> void:
	RunState.reset()
	RunState.set_seed(99)
	RunState.build_starter_deck([_card("spark", 5)])
	var drawn: int = RunState.draw(2)
	eq(drawn, 2, "on pioche bien 2 cartes")
	eq(RunState.hand.size(), 2, "2 cartes en main")
	eq(RunState.deck.size(), 3, "3 cartes restantes dans la pioche")


## Invariant anti-duplication / anti-perte de cartes.
func _test_reshuffle_conserves_cards() -> void:
	RunState.reset()
	RunState.set_seed(7)
	RunState.build_starter_deck([_card("spark", 3)])
	var total_before: int = RunState.total_cards()

	RunState.draw(3)
	eq(RunState.deck.size(), 0, "pioche videe")
	RunState.discard_hand()
	eq(RunState.discard.size(), 3, "3 cartes a la defausse")

	# Piocher sur une pioche vide doit remelanger la defausse.
	var drawn: int = RunState.draw(1)
	eq(drawn, 1, "la pioche sur deck vide remelange la defausse")
	eq(RunState.discard.size(), 0, "la defausse est videe par le remelange")
	eq(RunState.total_cards(), total_before, "aucune carte creee ni perdue")


func _test_draw_timer() -> void:
	RunState.reset()
	RunState.set_seed(3)
	RunState.build_starter_deck([_card("spark", 10)])
	RunState.tick(GameConfig.DRAW_INTERVAL - 0.1)
	eq(RunState.hand.size(), 0, "rien avant l'echeance de pioche")
	RunState.tick(0.2)
	eq(RunState.hand.size(), GameConfig.DRAW_COUNT, "+2 cartes a l'echeance")


func _test_hand_limit() -> void:
	RunState.reset()
	RunState.set_seed(5)
	RunState.build_starter_deck([_card("spark", 20)])
	RunState.draw(50)
	eq(RunState.hand.size(), GameConfig.MAX_HAND_SIZE, "la main est plafonnee")


func _test_play_card() -> void:
	RunState.reset()
	RunState.set_seed(11)
	var legendary := _card("time_rift", 0, GameEnums.Rarity.LEGENDARY)
	RunState.hand.append(legendary)
	ok(RunState.play_card(legendary), "la carte en main est jouable")
	eq(RunState.hand.size(), 0, "la carte quitte la main")
	eq(RunState.discard.size(), 1, "la carte part a la defausse")
	ok(RunState.used_legendary, "jouer une legendaire est trace pour les objectifs")
	not_ok(RunState.play_card(legendary), "une carte absente de la main n'est pas jouable")


## La pioche suit le TEMPS DU MONDE, comme les monstres et l incantation.
##
## Mesure au banc d equilibrage : quand la pioche suivait le temps reel, passer a
## x4 quadruplait les monstres arrives et le nombre de sorts lances, mais pas les
## cartes piochees. Le joueur se retrouvait les mains vides exactement quand le
## jeu devenait le plus dur, et le multiplicateur devenait une punition.
func _test_pioche_suit_la_vitesse() -> void:
	RunState.reset()
	RunState.set_seed(7)
	RunState.build_starter_deck([_card("spark", 40)])
	SpeedGauge.reset()

	# A x1 : une echeance apres DRAW_INTERVAL secondes reelles.
	RunState.tick(SpeedGauge.world_delta(GameConfig.DRAW_INTERVAL))
	eq(RunState.hand.size(), GameConfig.DRAW_COUNT, "x1 : une pioche par intervalle")

	# A x4 : le meme temps reel doit rapporter quatre fois plus de cartes.
	RunState.reset()
	RunState.set_seed(7)
	RunState.build_starter_deck([_card("spark", 40)])
	SpeedGauge.set_step(GameConfig.SPEED_STEPS.size() - 1)
	feq(SpeedGauge.multiplier(), 4.0, "la jauge est bien a x4")
	RunState.tick(SpeedGauge.world_delta(GameConfig.DRAW_INTERVAL))
	eq(RunState.hand.size(), GameConfig.DRAW_COUNT * 4,
		"x4 : quatre pioches dans le meme temps reel")
	SpeedGauge.reset()
