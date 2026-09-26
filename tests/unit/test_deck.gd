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
	_test_un_sort_accelere_la_pioche()


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
	reset_gauge_at_normal_speed()

	# A x1 : une echeance apres DRAW_INTERVAL secondes reelles.
	RunState.tick(SpeedGauge.world_delta(GameConfig.DRAW_INTERVAL))
	eq(RunState.hand.size(), GameConfig.DRAW_COUNT, "x1 : une pioche par intervalle")

	# A x4 : le meme temps reel doit rapporter quatre fois plus de cartes.
	RunState.reset()
	RunState.set_seed(7)
	RunState.build_starter_deck([_card("spark", 40)])
	SpeedGauge.set_speed_percent(400)
	feq(SpeedGauge.multiplier(), 4.0, "la jauge est bien a 400 %")
	RunState.tick(SpeedGauge.world_delta(GameConfig.DRAW_INTERVAL))
	# La main a un PLAFOND : au-dela, c est lui qui repond, pas la vitesse de
	# pioche. Le test porte sur la regle (quatre fois plus de cartes a x4), pas
	# sur un nombre qui depend de MAX_HAND_SIZE.
	var attendu: int = mini(GameConfig.DRAW_COUNT * 4, GameConfig.MAX_HAND_SIZE)
	eq(RunState.hand.size(), attendu,
		"x4 : quatre pioches dans le meme temps reel, dans la limite de la main")
	reset_gauge_at_normal_speed()


## Le cahier des charges promet une pioche "ameliorable" : aucune carte ne
## touchait au rythme de pioche, alors que RunState l exposait deja.
func _test_un_sort_accelere_la_pioche() -> void:
	RunState.reset()
	RunState.set_seed(21)
	RunState.build_starter_deck([_card("spark", 40)])
	var base: float = RunState.draw_interval

	RunState.boost_draw(2.0, 10.0)
	feq(RunState.draw_interval, base * 0.5, "la pioche va deux fois plus vite")

	# L effet expire de lui-meme et la pioche revient a la normale.
	RunState.tick(9.0)
	feq(RunState.draw_interval, base * 0.5, "l effet dure encore a 9 s")
	RunState.tick(2.0)
	feq(RunState.draw_interval, base, "la pioche est revenue a son rythme apres 10 s")

	# Deux boosts ne s empilent pas en cascade : on garde le meilleur.
	RunState.boost_draw(2.0, 5.0)
	RunState.boost_draw(1.5, 5.0)
	feq(RunState.draw_interval, base * 0.5, "le boost le plus fort l emporte")
	RunState.reset()
	feq(RunState.draw_interval, base, "une nouvelle partie repart au rythme normal")
