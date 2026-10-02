extends TestCase
## EPURATION AU CHOIX (vague 8).
##
## Epuration exilait les 2 cartes du DESSUS de la pioche : deux cartes au hasard,
## peut-etre les meilleures. Le joueur choisit maintenant 0, 1 ou 2 cartes dans
## tout son deck de partie, la partie attendant son choix ; sans ecran (banc,
## headless), AutoPick tranche par une regle documentee.
##
## Les decks de ces tests portent des DOUBLONS et des raretes differentes : sur
## un deck de cartes toutes communes et uniques, « la plus faible » et « la
## premiere » donneraient le meme choix et le test ne mordrait pas.

func get_suite_name() -> String:
	return "purge"


var _ecouteurs: Array = []


func run() -> void:
	_couper_les_ecouteurs()
	_test_le_texte_de_la_carte_dit_le_choix()
	_test_sans_ecran_le_choix_est_tranche_aussitot()
	_test_le_sort_ouvre_un_choix_sans_rien_retirer()
	_test_le_plafond_et_zero_accepte()
	_test_ordre_des_piles()
	_test_la_main_garde_ses_exemplaires_tenus()
	_test_les_demandes_s_ajoutent()
	_test_auto_pick_retire_le_plus_faible()
	_test_auto_pick_ne_depend_pas_de_l_ordre()
	_test_auto_pick_garde_une_main()
	_test_la_partie_attend_le_choix()
	_test_l_ecran_de_choix()
	_rendre_les_ecouteurs()
	RunState.reset()


## Une partie d une suite precedente encore en vie ecouterait le signal et
## trancherait a la place du test. On coupe, puis on rend.
func _couper_les_ecouteurs() -> void:
	_ecouteurs = RunState.purge_requested.get_connections()
	for c in _ecouteurs:
		RunState.purge_requested.disconnect(c["callable"])


func _rendre_les_ecouteurs() -> void:
	for c in _ecouteurs:
		if is_instance_valid(c["callable"].get_object()) \
				and not RunState.purge_requested.is_connected(c["callable"]):
			RunState.purge_requested.connect(c["callable"])


func _card(id: String, rarity: int = GameEnums.Rarity.COMMON) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.rarity = rarity
	c.base_cast_time = 1.0
	return c


## Pioche `pile`, main `main`, defausse `defausse`, sans melange ni pioche.
func _poser(pile: Array, main: Array, defausse: Array) -> void:
	RunState.reset()
	for c in pile:
		RunState.deck.append(c)
	for c in main:
		RunState.hand.append(c)
	for c in defausse:
		RunState.discard.append(c)


func _count(pile: Array, card: SpellCard) -> int:
	var n: int = 0
	for c in pile:
		if c == card:
			n += 1
	return n


func _ids(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		out.append(String((c as SpellCard).id))
	return out


func _purge_card() -> SpellCard:
	return ContentDB.cards.get(&"deck_purge")


func _plafond() -> int:
	var carte: SpellCard = _purge_card()
	for spec in carte.effects:
		if spec.key == &"remove_cards":
			return int(spec.get_param(&"count", 1))
	return 0


func _test_le_texte_de_la_carte_dit_le_choix() -> void:
	var carte: SpellCard = _purge_card()
	ok(carte != null, "la carte Epuration existe")
	if carte == null:
		return
	ok(_plafond() > 0, "Epuration a un plafond de cartes a retirer")
	var t: String = carte.description.to_lower()
	ok(t.contains("choisis") and t.contains("jusqu"),
		"le texte dit que le joueur CHOISIT, jusqu a un plafond (%s)" % carte.description)
	ok(t.contains(str(_plafond())), "le texte donne le plafond (%d)" % _plafond())


## Sans partie a l ecoute (sort lance par un test ou une vitrine), personne ne
## pourrait valider : le choix est tranche tout de suite, rien n attend.
func _test_sans_ecran_le_choix_est_tranche_aussitot() -> void:
	var a: SpellCard = _card("a")
	var b: SpellCard = _card("b", GameEnums.Rarity.RARE)
	_poser([a, a, a, b, b, b], [a, b], [a, b])
	var avant: int = RunState.total_cards()
	RunState.request_purge(2)
	eq(RunState.pending_purge, 0, "rien ne reste en attente")
	eq(RunState.total_cards(), avant - 2, "deux cartes retirees")
	eq(RunState.exiled.size(), 2, "elles sont exilees, pas perdues sans trace")


func _test_le_sort_ouvre_un_choix_sans_rien_retirer() -> void:
	var a: SpellCard = _card("a")
	_poser([a, a, a, a, a, a, a, a], [], [])
	var recus: Array = []
	var ecoute := func(n: int) -> void: recus.append(n)
	RunState.purge_requested.connect(ecoute)
	var ctx := CastContext.make(null, _purge_card())
	EffectRegistry.cast(_purge_card(), ctx)
	eq(recus, [_plafond()], "le sort demande un choix au plafond de la carte")
	eq(RunState.pending_purge, _plafond(), "le choix attend le joueur")
	eq(RunState.total_cards(), 8, "et rien n est retire avant qu il valide")
	eq(RunState.resolve_purge([]), 0, "valider sans rien choisir est permis")
	eq(RunState.pending_purge, 0, "le choix est tranche")
	eq(RunState.total_cards(), 8, "aucune carte retiree")
	RunState.purge_requested.disconnect(ecoute)


func _test_le_plafond_et_zero_accepte() -> void:
	var a: SpellCard = _card("a")
	var b: SpellCard = _card("b")
	_poser([a, a, b, b, b, b, b, b], [], [])
	var ecoute := func(_n: int) -> void: pass
	RunState.purge_requested.connect(ecoute)
	RunState.request_purge(2)
	eq(RunState.resolve_purge([a, a, b, b]), 2,
		"jamais plus que le plafond, meme si l ecran en demande davantage")
	eq(_count(RunState.deck, a), 0, "les deux premieres demandees sont parties")
	eq(_count(RunState.deck, b), 6, "les suivantes sont restees")
	# Sans choix en attente, resolve ne retire rien : le plafond est une regle de
	# la CARTE, un appel isole ne doit pas vider le deck.
	eq(RunState.resolve_purge([b]), 0, "aucun retrait hors d un choix en attente")
	RunState.request_purge(2)
	eq(RunState.resolve_purge([b]), 1, "une seule carte, c est permis")
	RunState.purge_requested.disconnect(ecoute)


## Defausse d abord, puis pioche, puis main : la carte tenue en main est celle
## que le joueur allait jouer, on la prend en dernier.
func _test_ordre_des_piles() -> void:
	var a: SpellCard = _card("a")
	var autre: SpellCard = _card("z")
	_poser([a, autre, autre, autre], [a, autre], [a, autre])
	var ecoute := func(_n: int) -> void: pass
	RunState.purge_requested.connect(ecoute)
	var recu: Array = []
	var fin := func(n: int) -> void: recu.append(n)
	RunState.purge_resolved.connect(fin)
	RunState.request_purge(3)
	eq(RunState.resolve_purge([a]), 1, "un exemplaire")
	eq(_count(RunState.discard, a), 0, "pris en DEFAUSSE d abord")
	eq(_count(RunState.deck, a), 1, "la pioche n est pas touchee")
	eq(_count(RunState.hand, a), 1, "la main non plus")
	RunState.request_purge(3)
	RunState.resolve_purge([a, a])
	eq(_count(RunState.deck, a), 0, "puis en PIOCHE")
	eq(_count(RunState.hand, a), 0, "puis en MAIN")
	eq(_count(RunState.exiled, a), 3, "les trois exemplaires sont exiles")
	eq(recu, [1, 2], "purge_resolved dit combien de cartes sont parties")
	RunState.purge_resolved.disconnect(fin)
	RunState.purge_requested.disconnect(ecoute)


## Un exemplaire petrifie en main reste a sa place : c est lui que le monstre
## designe. On prend une copie LIBRE de la meme carte.
func _test_la_main_garde_ses_exemplaires_tenus() -> void:
	var a: SpellCard = _card("a")
	var b: SpellCard = _card("b")
	_poser([], [a, b, a], [])
	RunState.set_card_block_count(1)
	var gele: int = -1
	for i in RunState.hand.size():
		if RunState.is_slot_blocked(i):
			gele = i
	ok(gele != -1, "un exemplaire est petrifie")
	var carte_gelee: SpellCard = RunState.hand[gele]
	var ecoute := func(_n: int) -> void: pass
	RunState.purge_requested.connect(ecoute)
	RunState.request_purge(1)
	RunState.resolve_purge([carte_gelee])
	var reste: int = -1
	for i in RunState.hand.size():
		if RunState.is_slot_blocked(i):
			reste = i
	if _count([a, b, a], carte_gelee) > 1:
		ok(reste != -1 and RunState.hand[reste] == carte_gelee,
			"la copie petrifiee est restee petrifiee en main")
	eq(RunState.hand.size(), 2, "une carte est partie de la main")
	RunState.purge_requested.disconnect(ecoute)
	RunState.set_card_block_count(0)


## Debordement resout un sort deux fois : deux demandes avant le choix font UN
## ecran au plafond cumule.
func _test_les_demandes_s_ajoutent() -> void:
	var a: SpellCard = _card("a")
	_poser([a, a, a, a, a, a, a, a, a, a], [], [])
	var recus: Array = []
	var ecoute := func(n: int) -> void: recus.append(n)
	RunState.purge_requested.connect(ecoute)
	RunState.request_purge(2)
	RunState.request_purge(2)
	eq(RunState.pending_purge, 4, "le plafond s additionne")
	eq(RunState.resolve_purge([a, a, a, a]), 4, "quatre cartes au plus")
	RunState.purge_requested.disconnect(ecoute)
	RunState.reset()
	eq(RunState.pending_purge, 0, "reset() efface un choix oublie")


func _test_auto_pick_retire_le_plus_faible() -> void:
	var com_peu: SpellCard = _card("c_peu")
	var com_beaucoup: SpellCard = _card("c_beaucoup")
	var rare: SpellCard = _card("rare", GameEnums.Rarity.RARE)
	var epique: SpellCard = _card("epi", GameEnums.Rarity.EPIC)
	_poser([epique, epique, rare, rare, rare, rare, rare, rare, com_peu],
		[com_beaucoup, com_beaucoup], [com_beaucoup])
	var choix: Array[SpellCard] = AutoPick.purge_choice(RunState.run_deck_groups(), 2)
	eq(choix.size(), 2, "le bot retire autant que permis")
	eq(_ids(choix), ["c_beaucoup", "c_beaucoup"],
		"la commune aux exemplaires les plus nombreux, pas la rare ni l epique")
	var un: Array[SpellCard] = AutoPick.purge_choice(RunState.run_deck_groups(), 4)
	ok(not un.has(epique), "l epique n est jamais la plus faible")


func _test_auto_pick_ne_depend_pas_de_l_ordre() -> void:
	var a: SpellCard = _card("a")
	var b: SpellCard = _card("b")
	var c: SpellCard = _card("c", GameEnums.Rarity.RARE)
	_poser([a, a, b, b, c, c, c, c, c], [], [])
	var groupes: Array[Dictionary] = RunState.run_deck_groups()
	var droit: Array[SpellCard] = AutoPick.purge_choice(groupes, 2)
	var envers: Array[Dictionary] = groupes.duplicate()
	envers.reverse()
	eq(_ids(AutoPick.purge_choice(envers, 2)), _ids(droit),
		"le choix ne depend pas de l ordre d affichage")


## Le bot ne vide jamais son deck sous une main pleine.
func _test_auto_pick_garde_une_main() -> void:
	var a: SpellCard = _card("a")
	var pile: Array = []
	for i in GameConfig.MAX_HAND_SIZE + 1:
		pile.append(a)
	_poser(pile, [], [])
	eq(AutoPick.purge_choice(RunState.run_deck_groups(), 3).size(), 1,
		"une seule carte au-dessus du plancher : une seule retiree")
	eq(AutoPick.purge_choice(RunState.run_deck_groups(), 0).size(), 0, "plafond nul : rien")


## Pendant le choix, la partie ne bouge pas : ni pioche, ni horloge, ni monstres.
func _test_la_partie_attend_le_choix() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	g.running = false
	g.simulate(0.5)
	RunState.pending_purge = 2
	var horloge: float = RunState.run_time
	var pioche: float = RunState.draw_progress()
	for i in 30:
		g.simulate(0.1)
	feq(RunState.run_time, horloge, "l horloge de la partie est figee pendant le choix")
	feq(RunState.draw_progress(), pioche, "la pioche aussi")
	not_ok(g.play_card(RunState.hand[0] if not RunState.hand.is_empty() else null,
		Vector2(540, 900)), "aucun sort ne part pendant le choix")
	# En headless, la partie tranche elle-meme une demande : rien n attend.
	RunState.pending_purge = 0
	RunState.request_purge(1)
	eq(RunState.pending_purge, 0, "la partie headless tranche par AutoPick")
	g.simulate(0.5)
	ok(RunState.run_time > horloge, "une fois tranche, la partie repart")
	detach(g)


## L ecran : choisir, ne pas depasser, valider zero, valider deux.
func _test_l_ecran_de_choix() -> void:
	var a: SpellCard = _card("a")
	var b: SpellCard = _card("b", GameEnums.Rarity.RARE)
	_poser([a, a, b], [a], [])
	var ecoute := func(_n: int) -> void: pass
	RunState.purge_requested.connect(ecoute)
	RunState.request_purge(2)
	var ecran: Control = DeckBrowser.purge_overlay(RunState.pending_purge)
	attach(ecran)
	var nav: DeckBrowser = ecran.find_child("DeckBrowser", true, false) as DeckBrowser
	ok(nav != null, "l ecran porte le composant de deck")
	if nav == null:
		detach(ecran)
		return
	eq(nav.listed_cards().size(), 2, "une ligne par carte differente")
	ok(nav.pick(b), "on retient la rare")
	not_ok(nav.pick(b), "pas plus d exemplaires qu il n y en a")
	ok(nav.pick(a), "puis une commune")
	not_ok(nav.pick(a), "pas plus que le plafond")
	eq(nav.picked_count(), 2, "deux cartes retenues")
	ok(nav.validate_text().contains("2"), "le bouton dit combien partiront (%s)" % nav.validate_text())
	ok(nav.unpick(a), "on peut se raviser")
	eq(_ids(nav.selection()), ["b"], "la selection suit")
	var bouton: Button = ecran.find_child("Validate", true, false) as Button
	ok(bouton != null and bouton.custom_minimum_size.y >= 90.0, "VALIDER est une cible de pouce")
	if bouton != null:
		bouton.pressed.emit()
	eq(RunState.pending_purge, 0, "VALIDER tranche le choix")
	eq(_count(RunState.deck, b), 0, "la rare est partie")
	eq(RunState.total_cards(), 3, "et elle seule")
	ok(ecran.is_queued_for_deletion(), "l ecran se retire")
	detach(ecran)

	# Zero est un choix.
	RunState.request_purge(2)
	var ecran2: Control = DeckBrowser.purge_overlay(RunState.pending_purge)
	attach(ecran2)
	var nav2: DeckBrowser = ecran2.find_child("DeckBrowser", true, false) as DeckBrowser
	ok(nav2.validate_text().to_lower().contains("rien"), "sans choix, VALIDER dit qu on ne retire rien")
	nav2.validate()
	eq(RunState.total_cards(), 3, "valider sans choix ne retire rien")
	eq(RunState.pending_purge, 0, "et tranche quand meme")
	detach(ecran2)
	RunState.purge_requested.disconnect(ecoute)
