extends TestCase
## Chaque carte a une icone RECONNAISSABLE et UNIQUE (demande du testeur).
##
## Les cartes se distinguaient par leur seul nom, ecrit petit sur une carte de
## 120 px de large : en pleine vague, impossible de reconnaitre un sort d un coup
## d oeil.

func get_suite_name() -> String:
	return "card_icons"


func run() -> void:
	_test_chaque_carte_a_une_icone()
	_test_les_icones_sont_uniques()
	_test_l_icone_existe_vraiment()


func _test_chaque_carte_a_une_icone() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var nom: String = CardIcons.for_card(card)
		ok(nom != "", "%s a une icone" % card.id)


## Deux cartes differentes ne partagent pas la meme icone : sinon on ne les
## distingue toujours pas.
func _test_les_icones_sont_uniques() -> void:
	var vues: Dictionary = {}
	for card: SpellCard in ContentDB.cards.values():
		# La signature est le couple feuille+teinte : il y a plus de cartes que de
		# feuilles, c est donc ce couple qui doit etre unique.
		var sig: String = CardIcons.signature(card)
		not_ok(vues.has(sig),
			"la signature '%s' de %s n est pas deja prise par %s" % [sig, card.id, vues.get(sig, "")])
		vues[sig] = String(card.id)


## Une icone qui pointe vers un fichier absent afficherait un trou.
func _test_l_icone_existe_vraiment() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var nom: String = CardIcons.for_card(card)
		if nom == "":
			continue
		ok(CardIcons.texture(nom) != null, "l icone '%s' se charge" % nom)
