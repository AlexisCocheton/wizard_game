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
	_test_chaque_carte_a_une_icone_dediee()
	_test_les_icones_dediees_se_chargent()
	_test_les_icones_dediees_sont_uniques()


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


## ---------------------------------------------------------------------------
## ICONE DEDIEE (demande du testeur : "chaque sort doit avoir une icone qui le
## represente bien et qui lui est unique").
##
## Les icones etaient des INSTANTANES D ANIMATION recadres : un sort de feu
## donnait trois taches orange, une fleche donnait un objet gris allonge. Une
## feuille d effet est dessinee pour bouger en plein ecran, pas pour etre lue
## dans 118 px de large. On pose donc une image DESSINEE POUR ETRE UNE ICONE,
## issue des packs de competences, a cote de la feuille d effet qui, elle,
## continue de s animer sur le terrain.
## ---------------------------------------------------------------------------


## Chaque carte ET chaque passif porte une icone dediee : sinon la carte
## reapparait en instantane d animation, et le defaut revient sans bruit.
func _test_chaque_carte_a_une_icone_dediee() -> void:
	var manquantes: Array[String] = []
	for card: SpellCard in ContentDB.cards.values():
		if CardIcons.art_path(card) == "":
			manquantes.append(String(card.id))
	ok(manquantes.is_empty(),
		"toutes les cartes ont une icone dediee (sans : %s)" % ", ".join(manquantes))


## Le fichier existe vraiment : une entree de table qui pointe dans le vide
## afficherait un trou, et seule une capture le montrerait.
func _test_les_icones_dediees_se_chargent() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var p: String = CardIcons.art_path(card)
		if p == "":
			continue
		ok(ResourceLoader.exists(p), "l icone dediee de %s existe : %s" % [card.id, p])


## Deux cartes ne partagent jamais le meme fichier d icone : c est la demande
## litterale ("une icone ... qui lui est unique").
func _test_les_icones_dediees_sont_uniques() -> void:
	var vues: Dictionary = {}
	for card: SpellCard in ContentDB.cards.values():
		var p: String = CardIcons.art_path(card)
		if p == "":
			continue
		not_ok(vues.has(p),
			"l icone %s de %s n est pas deja prise par %s" % [p, card.id, vues.get(p, "")])
		vues[p] = String(card.id)
