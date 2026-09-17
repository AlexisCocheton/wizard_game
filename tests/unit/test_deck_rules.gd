extends TestCase
## Regles de composition du deck Massacre.

func get_suite_name() -> String:
	return "deck_rules"


func _card(id: String, rarity: int) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.rarity = rarity
	return c


func run() -> void:
	_test_copies_max()
	_test_can_add()
	_test_validite()
	_test_message()
	_test_resolve()
	_test_deck_par_defaut()


func _test_copies_max() -> void:
	eq(DeckRules.max_copies(GameEnums.Rarity.COMMON), 4, "4 communes max")
	eq(DeckRules.max_copies(GameEnums.Rarity.RARE), 3, "3 rares max")
	eq(DeckRules.max_copies(GameEnums.Rarity.EPIC), 2, "2 epiques max")
	eq(DeckRules.max_copies(GameEnums.Rarity.LEGENDARY), 1, "1 legendaire max")


func _test_can_add() -> void:
	var leg := _card("leg", GameEnums.Rarity.LEGENDARY)
	var com := _card("com", GameEnums.Rarity.COMMON)
	var deck: Array = []
	ok(DeckRules.can_add(deck, leg, true), "une legendaire decouverte s ajoute")
	not_ok(DeckRules.can_add(deck, leg, false), "une carte non decouverte est refusee")
	deck.append("leg")
	not_ok(DeckRules.can_add(deck, leg, true), "pas de second exemplaire d une legendaire")
	for i in 4:
		deck.append("com")
	not_ok(DeckRules.can_add(deck, com, true), "pas de 5e exemplaire d une commune")
	# Plafond global.
	var full: Array = []
	for i in DeckRules.MAX_CARDS:
		full.append("x%d" % i)
	not_ok(DeckRules.can_add(full, _card("y", GameEnums.Rarity.COMMON), true),
		"deck plein : refus")


func _test_validite() -> void:
	var small: Array = ["a", "b"]
	not_ok(DeckRules.is_valid(small), "deck trop petit invalide")
	var okd: Array = []
	for i in DeckRules.MIN_CARDS:
		okd.append("c")
	ok(DeckRules.is_valid(okd), "deck au minimum valide")
	var big: Array = []
	for i in DeckRules.MAX_CARDS + 1:
		big.append("c")
	not_ok(DeckRules.is_valid(big), "deck trop grand invalide")


func _test_message() -> void:
	eq(DeckRules.validation_message(["a"]).is_empty(), false, "message si trop petit")
	var okd: Array = []
	for i in DeckRules.MIN_CARDS:
		okd.append("c")
	eq(DeckRules.validation_message(okd), "", "aucun message si valide")


func _test_resolve() -> void:
	var ids: Array = ["arcane_bolt", "arcane_bolt", "id_inconnu", "frost_field"]
	var cards: Array[SpellCard] = DeckRules.resolve(ids)
	eq(cards.size(), 3, "les ids inconnus sont ignores, les doublons gardes")
	eq(cards[0].id, &"arcane_bolt", "premier exemplaire")
	eq(cards[1].id, &"arcane_bolt", "second exemplaire")


func _test_deck_par_defaut() -> void:
	var ids: Array = DeckRules.default_deck_ids()
	ok(ids.size() >= DeckRules.MIN_CARDS, "le deck de base est jouable (%d cartes)" % ids.size())
	ok(DeckRules.is_valid(ids), "le deck de base respecte les bornes")
	for id in ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		ok(c != null and c.copies_in_starter > 0, "le deck de base ne contient que des cartes de depart")
		break
