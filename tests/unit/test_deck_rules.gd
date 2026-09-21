extends TestCase
## Regles de composition du deck Massacre.
##
## Depuis la demande du testeur (chantier K) le deck est EXACTEMENT de 15 cartes :
## ni 14 ni 16. Un intervalle laissait le joueur composer un deck de 8 cartes et
## croire qu il jouait le meme jeu que celui qui en jouait 20 ; la pioche, l XP et
## la courbe de vagues sont calees sur une taille unique.

func get_suite_name() -> String:
	return "deck_rules"


func _card(id: String, rarity: int) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.rarity = rarity
	return c


## Un deck valide fabrique a la demande : `epics` epiques, `legs` legendaires,
## le reste en communes (4 exemplaires max par id, donc plusieurs ids).
func _deck(taille: int, epics: int = 0, legs: int = 0) -> Array:
	var out: Array = []
	for i in legs:
		out.append("leg_%d" % i)
	for i in epics:
		out.append("epi_%d" % i)
	while out.size() < taille:
		out.append("com_%d" % (out.size() / 4))
	return out


func run() -> void:
	_test_copies_max()
	_test_can_add()
	_test_taille_exacte()
	_test_plafond_epiques_legendaires()
	_test_passifs_hors_deck()
	_test_message()
	_test_resolve()
	_test_deck_par_defaut()
	_test_les_decks_de_campagne_suivent_la_regle()


func _test_copies_max() -> void:
	eq(DeckRules.max_copies(GameEnums.Rarity.COMMON), 4, "4 communes max")
	eq(DeckRules.max_copies(GameEnums.Rarity.RARE), 3, "3 rares max")
	eq(DeckRules.max_copies(GameEnums.Rarity.EPIC), 2, "2 epiques max")
	eq(DeckRules.max_copies(GameEnums.Rarity.LEGENDARY), 1, "1 legendaire max")
	eq(DeckRules.DECK_SIZE, 15, "le deck fait exactement 15 cartes")
	eq(DeckRules.MAX_EPIC, 3, "au plus 3 epiques")
	eq(DeckRules.MAX_LEGENDARY, 3, "au plus 3 legendaires")
	eq(DeckRules.MAX_PASSIVES, 3, "au plus 3 passifs equipes")


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
	# Plafond global : le deck est PLEIN a 15, pas a 20.
	var full: Array = _deck(DeckRules.DECK_SIZE)
	not_ok(DeckRules.can_add(full, _card("y", GameEnums.Rarity.COMMON), true),
		"deck plein a 15 : refus")
	# Un passif ne rentre plus dans le deck : il s equipe a part (chantier F).
	var passif := _card("pass", GameEnums.Rarity.RARE)
	passif.is_passive = true
	not_ok(DeckRules.can_add([], passif, true), "un passif ne s ajoute pas au deck")


## La regle centrale : 15 et rien d autre.
func _test_taille_exacte() -> void:
	not_ok(DeckRules.is_valid(_deck(14)), "14 cartes : invalide")
	ok(DeckRules.is_valid(_deck(15)), "15 cartes : valide")
	not_ok(DeckRules.is_valid(_deck(16)), "16 cartes : invalide")
	not_ok(DeckRules.is_valid([]), "deck vide : invalide")


func _test_plafond_epiques_legendaires() -> void:
	ok(DeckRules.is_valid(_deck(15, 3, 3)), "3 epiques + 3 legendaires : valide")
	not_ok(DeckRules.is_valid(_deck(15, 4, 0)), "4 epiques : invalide")
	not_ok(DeckRules.is_valid(_deck(15, 0, 4)), "4 legendaires : invalide")
	eq(DeckRules.count_rarity(_deck(15, 4, 2), GameEnums.Rarity.EPIC), 4, "compte les epiques")
	eq(DeckRules.count_rarity(_deck(15, 4, 2), GameEnums.Rarity.LEGENDARY), 2, "compte les legendaires")
	# Le plafond de rarete doit BLOQUER l ajout, pas seulement invalider apres coup :
	# sinon le joueur remplit son deck puis decouvre qu il est injouable.
	var trois_epiques: Array = ["epi_0", "epi_1", "epi_2"]
	not_ok(DeckRules.can_add(trois_epiques, _card("epi_3", GameEnums.Rarity.EPIC), true),
		"une 4e epique est refusee a l ajout")
	ok(DeckRules.can_add(trois_epiques, _card("com_x", GameEnums.Rarity.COMMON), true),
		"une commune passe encore")


## Les passifs sont SORTIS du deck (chantier F) : ils s equipent de 0 a 3.
func _test_passifs_hors_deck() -> void:
	ok(DeckRules.passives_valid([]), "aucun passif : valide")
	ok(DeckRules.passives_valid(["a", "b", "c"]), "3 passifs : valide")
	not_ok(DeckRules.passives_valid(["a", "b", "c", "d"]), "4 passifs : invalide")


func _test_message() -> void:
	var court: String = DeckRules.validation_message(_deck(12))
	ok(court.contains("3"), "le message dit combien de cartes MANQUENT : %s" % court)
	var long: String = DeckRules.validation_message(_deck(18))
	ok(long.contains("3"), "le message dit combien de cartes EN TROP : %s" % long)
	var trop_epic: String = DeckRules.validation_message(_deck(15, 5, 0))
	ok(trop_epic.to_lower().contains("epique"), "le message nomme les epiques : %s" % trop_epic)
	var trop_leg: String = DeckRules.validation_message(_deck(15, 0, 5))
	ok(trop_leg.to_lower().contains("legendaire"), "le message nomme les legendaires : %s" % trop_leg)
	eq(DeckRules.validation_message(_deck(15, 3, 3)), "", "aucun message si valide")


func _test_resolve() -> void:
	var ids: Array = ["arcane_bolt", "arcane_bolt", "id_inconnu", "frost_field"]
	var cards: Array[SpellCard] = DeckRules.resolve(ids)
	eq(cards.size(), 3, "les ids inconnus sont ignores, les doublons gardes")
	eq(cards[0].id, &"arcane_bolt", "premier exemplaire")
	eq(cards[1].id, &"arcane_bolt", "second exemplaire")


func _test_deck_par_defaut() -> void:
	var ids: Array = DeckRules.default_deck_ids()
	eq(ids.size(), DeckRules.DECK_SIZE, "le deck de base fait pile 15 cartes")
	ok(DeckRules.is_valid(ids), "le deck de base est jouable")
	for id in ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		ok(c != null, "le deck de base ne contient que des cartes connues (%s)" % id)
		if c != null:
			not_ok(c.is_passive, "aucun passif dans le deck de base (%s)" % id)


## Le trou que ce test bouche : GameController._build_deck() prend
## level_def.exploration_deck DIRECTEMENT, sans passer par is_valid(). Seul le
## mode Massacre etait valide. Les decks de campagne pouvaient donc violer la
## regle sans que rien ne rougisse — et six sur sept la violaient (jusqu a 20
## cartes et 6 epiques). La regle du testeur vaut "que ce soit en campagne ou en
## massacre" : elle se verifie donc sur le contenu LIVRE, pas seulement sur la
## fonction qui l evalue.
func _test_les_decks_de_campagne_suivent_la_regle() -> void:
	ok(not ContentDB.levels.is_empty(), "des niveaux sont charges")
	for key in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[key]
		var deck: Array = lvl.exploration_deck
		eq(deck.size(), DeckRules.DECK_SIZE,
			"%s : le deck fait pile %d cartes" % [key, DeckRules.DECK_SIZE])
		var epiques: int = 0
		var legendaires: int = 0
		for c in deck:
			var card: SpellCard = c
			if card == null:
				continue
			not_ok(card.is_passive,
				"%s : aucun passif dans le deck, ils s equipent a part" % key)
			if card.rarity == GameEnums.Rarity.EPIC:
				epiques += 1
			elif card.rarity == GameEnums.Rarity.LEGENDARY:
				legendaires += 1
		ok(epiques <= DeckRules.MAX_EPIC,
			"%s : %d epiques, plafond %d" % [key, epiques, DeckRules.MAX_EPIC])
		ok(legendaires <= DeckRules.MAX_LEGENDARY,
			"%s : %d legendaires, plafond %d" % [key, legendaires, DeckRules.MAX_LEGENDARY])
