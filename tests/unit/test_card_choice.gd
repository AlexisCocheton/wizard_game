extends TestCase
## Choix de 3 sorts : a la montee de niveau (Exploration) ou toutes les N vagues (Massacre).

func get_suite_name() -> String:
	return "card_choice"


func run() -> void:
	# SANS NIVEAU, le pool de montee de niveau est tout le catalogue (voir
	# RunState.levelup_pool) : c est le cadre de ces tests historiques. Une
	# suite precedente peut avoir laisse un niveau d acte 1 en cours, dont le
	# pool n a ni passif ni variete : on repart d un contexte explicite.
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	_test_offre_de_trois()
	_test_choix_rejoint_la_defausse()
	_test_choix_invalide()
	_test_montee_de_niveau_propose()
	# La partie lancee ci-dessus a laisse SON niveau en cours : retour au cadre.
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	_test_cadence_massacre()
	_test_un_boss_vaincu_n_offre_plus_rien_d_office()
	_test_les_trois_choix_melangent_les_raretes()
	_test_bruler_une_carte_proposee()
	_test_un_cinquieme_de_passifs_a_la_montee_de_niveau()
	_test_un_passif_choisi_s_equipe_au_lieu_d_aller_dans_le_deck()
	_test_un_quatrieme_passif_choisi_attend_un_echange()
	RunState.current_level_def = null


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
	# On prend le premier SORT de l offre, pas l option 0 : un passif choisi
	# s equipe hors deck (RunState.pick_offer) et le deck ne grandit pas. Le
	# tirage n est pas seme (RunState randomise au demarrage) : l option 0 etait
	# un passif une fois sur cinq, et chaque carte ajoutee au catalogue deplacait
	# le tirage — le test echouait alors sans qu aucune regle n ait change.
	var idx: int = -1
	for i in RunState.pending_offer.size():
		if not (RunState.pending_offer[i] as SpellCard).is_passive:
			idx = i
			break
	if idx < 0:
		# Trois passifs (moins d une fois sur cent) : la regle a verifier est
		# alors l autre branche de pick_offer, le passif s equipe.
		var equipes: int = RunState.equipped_passives.size()
		ok(g.choose_card(0) != null, "le choix est pris")
		ok(RunState.equipped_passives.size() > equipes \
				or RunState.total_cards() == cards,
			"un passif choisi s equipe sans entrer dans le deck")
	else:
		ok(g.choose_card(idx) != null, "le choix est pris")
		eq(RunState.total_cards(), cards + 1, "le deck a grandi")
	eq(RunState.pending_offer.size(), 0, "plus d offre en attente")
	detach(g)
	RunState.reset()
	reset_gauge_at_normal_speed()


func _test_cadence_massacre() -> void:
	eq(GameController.WAVES_PER_CHOICE, 2, "un choix toutes les 2 vagues en Massacre")


## CHANTIER P : les recompenses de boss d office (trois epiques au mini-boss,
## trois legendaires au boss, tirees dans TOUT le catalogue) sont supprimees.
## Les cartes fortes viennent des objectifs du niveau. Vaincre la vague de boss
## en campagne ne met donc aucune offre en attente, et la fonction qui imposait
## une rarete n existe plus : elle aurait ete une porte hors du pool.
func _test_un_boss_vaincu_n_offre_plus_rien_d_office() -> void:
	not_ok(RunState.has_method("offer_of_rarity"),
		"plus d offre de rarete imposee : toute offre passe par le pool")
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	var lvl: LevelDef = null
	var idx_boss: int = -1
	for id in ContentDB.levels:
		var l: LevelDef = ContentDB.levels[id]
		for i in l.waves.size():
			if l.waves[i] != null and (l.waves[i].is_boss or l.waves[i].is_miniboss):
				lvl = l
				idx_boss = i
				break
		if lvl != null:
			break
	ok(lvl != null, "un niveau de campagne a une vague de boss")
	if lvl != null:
		g.start_level(lvl, GameEnums.Mode.EXPLORATION)
		g.running = false
		RunState.pending_offer.clear()
		g._on_wave_cleared(idx_boss)
		eq(RunState.pending_offer.size(), 0,
			"la vague de boss nettoyee n offre aucune carte en campagne")
	detach(g)
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	reset_gauge_at_normal_speed()


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


## Option BRULER : on clique "bruler" puis une des trois cartes. Elle est lancee
## immediatement mais n entre PAS dans le deck. Demande du testeur : un choix de
## puissance immediate contre une valeur a long terme.
func _test_bruler_une_carte_proposee() -> void:
	RunState.reset()
	RunState.set_seed(77)
	var offre: Array[SpellCard] = RunState.offer_choices(3)
	if offre.size() < 1:
		return
	var avant_deck: int = RunState.deck.size()
	var avant_defausse: int = RunState.discard.size()
	var avant_main: int = RunState.hand.size()

	var brulee: SpellCard = RunState.burn_offer(0)
	ok(brulee != null, "une carte est brulee")
	eq(RunState.deck.size(), avant_deck, "elle n entre pas dans la pioche")
	eq(RunState.discard.size(), avant_defausse, "ni dans la defausse")
	eq(RunState.hand.size(), avant_main, "ni dans la main")
	ok(RunState.pending_offer.is_empty(), "l offre est consommee")
	eq(RunState.burned_card, brulee, "la carte a lancer est retenue pour le controleur")
	RunState.reset()


## "Les passifs sont plus rares que les cartes durant les montees de niveau :
## 20 pourcent de passifs."
##
## Le test se mesure sur 400 tirages et tolere une marge : un tirage aleatoire ne
## tombe jamais pile sur 20 %. La marge est large a dessein — on verrouille
## l INTENTION (environ un cinquieme), pas une graine.
func _test_un_cinquieme_de_passifs_a_la_montee_de_niveau() -> void:
	RunState.reset()
	var passifs: int = 0
	var total: int = 0
	for essai in 400:
		RunState.set_seed(9000 + essai)
		var offre: Array[SpellCard] = RunState.offer_choices(3)
		for c in offre:
			if c == null:
				continue
			total += 1
			if c.is_passive:
				passifs += 1
		RunState.pending_offer.clear()
	ok(total > 0, "des cartes ont bien ete proposees")
	var taux: float = float(passifs) / float(maxi(total, 1))
	ok(taux > 0.10 and taux < 0.32,
		"environ 20 %% de passifs a la montee de niveau (mesure : %.1f %%)" % (taux * 100.0))
	RunState.reset()


## Un passif propose ne rejoint PAS la defausse : il s EQUIPE. Le mettre dans le
## deck le rendrait piochable, et tout le chantier serait annule en un appel.
func _test_un_passif_choisi_s_equipe_au_lieu_d_aller_dans_le_deck() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var p: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			p = c
			break
	if p == null:
		ok(false, "aucun passif au catalogue")
		return
	RunState.pending_offer = [p]
	var avant_cartes: int = RunState.total_cards()
	var pris: SpellCard = RunState.pick_offer(0)
	eq(pris, p, "le passif est bien rendu")
	eq(RunState.total_cards(), avant_cartes, "le deck n a pas grandi")
	not_ok(RunState.discard.has(p), "il n est pas a la defausse")
	ok(RunState.equipped_passives.has(p), "il occupe un emplacement de passif")
	RunState.reset()


## Quand les trois emplacements sont pleins, choisir un quatrieme passif ne
## l equipe pas en douce : il reste EN ATTENTE d un echange decide par le joueur.
func _test_un_quatrieme_passif_choisi_attend_un_echange() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var tous: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			tous.append(c)
	if tous.size() < 4:
		ok(false, "il faut au moins 4 passifs au catalogue")
		return
	for i in GameConfig.PASSIVE_SLOTS:
		RunState.equip_passive(tous[i])
	RunState.pending_offer = [tous[3]]
	RunState.pick_offer(0)
	eq(RunState.pending_passive, tous[3], "le quatrieme attend un echange")
	eq(RunState.equipped_passives.size(), GameConfig.PASSIVE_SLOTS, "toujours trois equipes")
	ok(RunState.resolve_pending_passive(0), "le joueur designe l emplacement 0")
	eq(RunState.equipped_passives[0], tous[3], "le nouveau a pris la place")
	eq(RunState.pending_passive, null, "plus rien en attente")
	RunState.reset()
