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
	_test_un_boss_vaincu_offre_une_carte()
	_test_les_trois_choix_melangent_les_raretes()


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


## Le cahier des charges : "Mini-boss a mi-parcours (drop d une carte legendaire)"
## et "Recompenses de boss : cartes rares ou legendaires". Vaincre un boss ne
## rapportait rien du tout : la seule source de cartes etait la montee de niveau.
func _test_un_boss_vaincu_offre_une_carte() -> void:
	RunState.reset()
	RunState.set_seed(42)

	# Mini-boss : choix parmi des EPIQUES.
	var epiques: Array[SpellCard] = RunState.offer_of_rarity(GameEnums.Rarity.EPIC, 3)
	ok(not epiques.is_empty(), "le mini-boss propose des cartes")
	for c in epiques:
		eq(c.rarity, GameEnums.Rarity.EPIC, "le mini-boss propose bien de l epique")
	eq(RunState.pending_offer.size(), epiques.size(),
		"l offre est en attente : la partie se met en pause dessus")

	# Le joueur choisit : la carte rejoint la defausse, comme a la montee de niveau.
	var avant: int = RunState.discard.size()
	var prise: SpellCard = RunState.pick_offer(0)
	ok(prise != null, "une carte est bien prise")
	eq(RunState.discard.size(), avant + 1, "la carte du boss rejoint la defausse")
	ok(RunState.pending_offer.is_empty(), "l offre est consommee")

	# Boss final : la LEGENDAIRE d abord. Il n en existe que 2 au catalogue, donc
	# demander 3 choix complete forcement avec la rarete du dessous — mieux qu une
	# offre incomplete, mais la premiere doit etre legendaire.
	var legendaires: Array[SpellCard] = RunState.offer_of_rarity(GameEnums.Rarity.LEGENDARY, 3)
	ok(not legendaires.is_empty(), "le boss final propose des cartes")
	eq(legendaires[0].rarity, GameEnums.Rarity.LEGENDARY,
		"le premier choix du boss final est legendaire")
	var toutes: Array[SpellCard] = ContentDB.cards_of_rarity(GameEnums.Rarity.LEGENDARY)
	var n_leg: int = 0
	for c in legendaires:
		if c.rarity == GameEnums.Rarity.LEGENDARY:
			n_leg += 1
	eq(n_leg, mini(3, toutes.size()), "toutes les legendaires disponibles sont proposees")
	RunState.reset()


## Les trois cartes proposees a la montee de niveau peuvent etre de RARETES
## DIFFERENTES. Avant, une seule rarete etait tiree pour toute l offre : les trois
## choix se ressemblaient et le tirage n avait aucun relief.
func _test_les_trois_choix_melangent_les_raretes() -> void:
	RunState.reset()
	var vu_melange: bool = false
	# Sur 40 tirages, un melange doit apparaitre au moins une fois. Le contraire
	# signifierait qu une seule rarete est tiree pour toute l offre.
	for essai in 40:
		RunState.set_seed(500 + essai)
		var offre: Array[SpellCard] = RunState.offer_choices(3)
		if offre.size() < 2:
			continue
		var premiere: GameEnums.Rarity = offre[0].rarity
		for c in offre:
			if c.rarity != premiere:
				vu_melange = true
				break
		RunState.pending_offer.clear()
		if vu_melange:
			break
	ok(vu_melange, "les trois choix ne sont pas tous de la meme rarete")
	RunState.reset()
