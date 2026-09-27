extends TestCase
## Regles de composition du deck, en campagne comme en Massacre.
##
## Depuis la demande du testeur (chantier K) le deck est EXACTEMENT de 15 cartes :
## ni 14 ni 16. Un intervalle laissait le joueur composer un deck de 8 cartes et
## croire qu il jouait le meme jeu que celui qui en jouait 20 ; la pioche, l XP et
## la courbe de vagues sont calees sur une taille unique.
##
## Depuis la demande du co-auteur du 27/09 il compte au plus 6 cartes
## DIFFERENTES, et les plafonds par rarete (3 epiques, 3 legendaires) ont
## disparu : la regle des 6 borne deja la rarete, ce que ce fichier verifie en
## enumerant les compositions plutot qu en recopiant l arithmetique.

func get_suite_name() -> String:
	return "deck_rules"


func _card(id: String, rarity: int) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.rarity = rarity
	return c


## Un deck de communes synthetiques : `taille` cartes, 4 exemplaires par id
## (le maximum d une commune), donc le moins d ids possible.
func _deck(taille: int) -> Array:
	var out: Array = []
	while out.size() < taille:
		out.append("com_%d" % (out.size() / DeckRules.max_copies(GameEnums.Rarity.COMMON)))
	return out


## Un deck de `taille` cartes reparties sur `ids` ids communs DIFFERENTS, en
## tournant (a, b, c, a, b, c...) : sert a fabriquer 7 ids sur 15 cartes sans
## depasser les exemplaires.
func _deck_en_ids(taille: int, ids: int) -> Array:
	var out: Array = []
	for i in taille:
		out.append("com_%d" % (i % ids))
	return out


func run() -> void:
	_test_copies_max()
	_test_can_add()
	_test_taille_exacte()
	_test_six_cartes_differentes()
	_test_is_valid_verifie_les_exemplaires()
	_test_la_rarete_est_bornee_par_la_regle_des_six()
	_test_refusal_reason()
	_test_can_add_et_refusal_reason_ne_divergent_jamais()
	_test_passifs_hors_deck()
	_test_message()
	_test_un_deck_sauvegarde_hors_regle_est_garde_et_explique()
	_test_resolve()
	_test_deck_par_defaut()
	_test_les_decks_de_campagne_suivent_la_regle()
	_test_chaque_niveau_fait_decouvrir_une_carte()


func _test_copies_max() -> void:
	eq(DeckRules.max_copies(GameEnums.Rarity.COMMON), 4, "4 communes max")
	eq(DeckRules.max_copies(GameEnums.Rarity.RARE), 3, "3 rares max")
	eq(DeckRules.max_copies(GameEnums.Rarity.EPIC), 2, "2 epiques max")
	eq(DeckRules.max_copies(GameEnums.Rarity.LEGENDARY), 1, "1 legendaire max")
	eq(DeckRules.DECK_SIZE, 15, "le deck fait exactement 15 cartes")
	eq(DeckRules.MAX_DISTINCT, 6, "au plus 6 cartes differentes")
	eq(DeckRules.MAX_PASSIVES, 3, "au plus 3 passifs equipes")
	# Les plafonds par rarete ont disparu : la regle des 6 les remplace. Un
	# retour de MAX_EPIC recreerait deux regles qui se contredisent a l ecran.
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/deck_rules.gd")
	not_ok(src.contains("const MAX_EPIC"), "plus de plafond d epiques")
	not_ok(src.contains("const MAX_LEGENDARY"), "plus de plafond de legendaires")


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
	not_ok(DeckRules.can_add(full, _card("com_0", GameEnums.Rarity.COMMON), true),
		"deck plein a 15 : refus")
	# Un passif ne rentre plus dans le deck : il s equipe a part (chantier F).
	var passif := _card("pass", GameEnums.Rarity.RARE)
	passif.is_passive = true
	not_ok(DeckRules.can_add([], passif, true), "un passif ne s ajoute pas au deck")


## La regle centrale : 15 et rien d autre.
func _test_taille_exacte() -> void:
	not_ok(DeckRules.is_valid(_deck(DeckRules.DECK_SIZE - 1)), "14 cartes : invalide")
	ok(DeckRules.is_valid(_deck(DeckRules.DECK_SIZE)), "15 cartes : valide")
	not_ok(DeckRules.is_valid(_deck(DeckRules.DECK_SIZE + 1)), "16 cartes : invalide")
	not_ok(DeckRules.is_valid([]), "deck vide : invalide")


## Six ids : valide. Sept : invalide, meme a 15 cartes et exemplaires respectes.
## Et la limite doit BLOQUER l ajout d un 7e id, pas seulement invalider apres
## coup — mais jamais un exemplaire de plus d un id deja present.
func _test_six_cartes_differentes() -> void:
	var six: Array = _deck_en_ids(DeckRules.DECK_SIZE, DeckRules.MAX_DISTINCT)
	eq(DeckRules.count_distinct(six), DeckRules.MAX_DISTINCT, "le deck fabrique a 6 ids")
	ok(DeckRules.is_valid(six), "15 cartes en 6 ids : valide")
	var sept: Array = _deck_en_ids(DeckRules.DECK_SIZE, DeckRules.MAX_DISTINCT + 1)
	eq(DeckRules.count_distinct(sept), DeckRules.MAX_DISTINCT + 1, "le deck fabrique a 7 ids")
	not_ok(DeckRules.is_valid(sept), "15 cartes en 7 ids : invalide")

	var partiel: Array = _deck_en_ids(DeckRules.MAX_DISTINCT, DeckRules.MAX_DISTINCT)
	not_ok(DeckRules.can_add(partiel, _card("com_neuf", GameEnums.Rarity.COMMON), true),
		"un 7e id est refuse a l ajout")
	ok(DeckRules.can_add(partiel, _card("com_0", GameEnums.Rarity.COMMON), true),
		"un exemplaire de plus d un id present passe encore")


## Le defaut d origine : is_valid() ne regardait pas les exemplaires, seul
## can_add() le faisait. Un deck sauvegarde ou fabrique a la main avec cinq
## exemplaires d une commune passait donc la validation.
func _test_is_valid_verifie_les_exemplaires() -> void:
	for rarete in [GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY]:
		var prefixe: String = ["com", "rare", "epi", "leg"][rarete]
		var trop: int = DeckRules.max_copies(rarete) + 1
		var deck: Array = []
		for i in trop:
			deck.append(prefixe + "_x")
		# Complete avec des communes en ids neufs, sans jamais depasser 4 par id.
		var k: int = 0
		while deck.size() < DeckRules.DECK_SIZE:
			deck.append("com_%d" % (k / DeckRules.max_copies(GameEnums.Rarity.COMMON)))
			k += 1
		ok(DeckRules.count_distinct(deck) <= DeckRules.MAX_DISTINCT,
			"le deck d essai ne viole QUE les exemplaires (%s)" % prefixe)
		not_ok(DeckRules.is_valid(deck),
			"%s : %d exemplaires d une meme carte -> invalide"
			% [GameEnums.rarity_name(rarete), trop])


## LE RAISONNEMENT DU CO-AUTEUR, VERIFIE ET NON RECOPIE.
##
## On enumere toutes les compositions de 1 a 7 ids (combien de legendaires,
## d epiques, de rares, de communes), on fabrique pour chacune le deck le plus
## proche de 15 cartes qu autorisent les exemplaires, et on demande a is_valid()
## lesquels passent. Les bornes qui en sortent sont celles que la regle des 6
## impose d elle-meme :
##   - au plus 3 legendaires (3 x 1 + 3 communes x 4 = 15) ;
##   - au plus 4 epiques (4 x 2 + 2 communes x 4 = 16 ; 5 x 2 + 4 = 14) ;
##   - au moins 4 ids (3 communes x 4 = 12).
## Si quelqu un change MAX_DISTINCT ou les exemplaires, ces bornes bougent et le
## test le dit : c est le moment de se demander s il faut un plafond de rarete.
func _test_la_rarete_est_bornee_par_la_regle_des_six() -> void:
	var raretes: Array = [GameEnums.Rarity.LEGENDARY, GameEnums.Rarity.EPIC,
		GameEnums.Rarity.RARE, GameEnums.Rarity.COMMON]
	var prefixes: Array = ["leg", "epi", "rare", "com"]
	var max_leg: int = -1
	var max_epi: int = -1
	var min_ids: int = 99
	var valides: int = 0
	var sept_valides: int = 0
	var plafond_ids: int = DeckRules.MAX_DISTINCT + 1
	for nl in plafond_ids + 1:
		for ne in plafond_ids + 1 - nl:
			for nr in plafond_ids + 1 - nl - ne:
				for nc in plafond_ids + 1 - nl - ne - nr:
					var compte: Array = [nl, ne, nr, nc]
					var total_ids: int = nl + ne + nr + nc
					if total_ids == 0:
						continue
					var deck: Array = _deck_de_composition(compte, raretes, prefixes)
					if not DeckRules.is_valid(deck):
						continue
					valides += 1
					if total_ids > DeckRules.MAX_DISTINCT:
						sept_valides += 1
					max_leg = maxi(max_leg, nl)
					max_epi = maxi(max_epi, ne)
					min_ids = mini(min_ids, total_ids)
	ok(valides > 0, "l enumeration trouve des decks valides (%d)" % valides)
	eq(sept_valides, 0, "aucune composition a 7 ids n est valide")
	eq(max_leg, 3, "la regle des 6 borne les legendaires a 3")
	eq(max_epi, 4, "la regle des 6 borne les epiques a 4")
	eq(min_ids, 4, "un deck de 15 compte au moins 4 cartes differentes")


## Le deck d une composition : chaque id recoit ses exemplaires maximum, puis on
## en retire (jamais sous 1 par id) jusqu a 15. S il manque des cartes, le deck
## reste court et is_valid() le refusera — c est ce qui doit se produire.
func _deck_de_composition(compte: Array, raretes: Array, prefixes: Array) -> Array:
	var copies: Array = []
	var noms: Array = []
	var total: int = 0
	for r in raretes.size():
		for i in int(compte[r]):
			noms.append("%s_%d" % [prefixes[r], i])
			var n: int = DeckRules.max_copies(raretes[r])
			copies.append(n)
			total += n
	var i2: int = 0
	var garde: int = 256
	while total > DeckRules.DECK_SIZE and garde > 0:
		garde -= 1
		if copies[i2] > 1:
			copies[i2] -= 1
			total -= 1
		i2 = (i2 + 1) % copies.size()
	var out: Array = []
	for k in noms.size():
		for c in int(copies[k]):
			out.append(noms[k])
	return out


## Chaque refus dit SA raison : le joueur doit savoir quel geste corrige.
func _test_refusal_reason() -> void:
	var com := _card("com_0", GameEnums.Rarity.COMMON)
	var leg := _card("leg_0", GameEnums.Rarity.LEGENDARY)
	var neuve := _card("com_neuf", GameEnums.Rarity.COMMON)

	eq(DeckRules.refusal_reason([], com, true), "", "ajout possible : aucune raison")
	ok(DeckRules.refusal_reason([], com, false).to_lower().contains("decouverte"),
		"non decouverte : %s" % DeckRules.refusal_reason([], com, false))
	var passif := _card("pass", GameEnums.Rarity.RARE)
	passif.is_passive = true
	ok(DeckRules.refusal_reason([], passif, true).to_lower().contains("passif"),
		"passif : %s" % DeckRules.refusal_reason([], passif, true))

	var plein: Array = _deck(DeckRules.DECK_SIZE)
	var r_plein: String = DeckRules.refusal_reason(plein, com, true)
	ok(r_plein.to_lower().contains("complet") and r_plein.contains(str(DeckRules.DECK_SIZE)),
		"deck plein : %s" % r_plein)

	var r_leg: String = DeckRules.refusal_reason(["leg_0"], leg, true)
	ok(r_leg.to_lower().contains("legendaire") and r_leg.contains("1"),
		"exemplaires de legendaire : %s" % r_leg)
	var quatre: Array = ["com_0", "com_0", "com_0", "com_0"]
	var r_com: String = DeckRules.refusal_reason(quatre, com, true)
	ok(r_com.to_lower().contains("commune")
		and r_com.contains(str(DeckRules.max_copies(GameEnums.Rarity.COMMON))),
		"exemplaires de commune : %s" % r_com)

	var six: Array = _deck_en_ids(DeckRules.MAX_DISTINCT, DeckRules.MAX_DISTINCT)
	var r_six: String = DeckRules.refusal_reason(six, neuve, true)
	ok(r_six.to_lower().contains("differentes") and r_six.contains(str(DeckRules.MAX_DISTINCT)),
		"7e carte differente : %s" % r_six)

	# Les raisons sont DISTINCTES deux a deux : une meme phrase pour deux causes
	# enverrait le joueur corriger la mauvaise.
	var raisons: Array = [DeckRules.refusal_reason([], com, false),
		DeckRules.refusal_reason([], passif, true), r_plein, r_leg, r_com, r_six]
	var vues: Dictionary = {}
	for r in raisons:
		not_ok(vues.has(r), "raison unique : %s" % r)
		vues[r] = true


## can_add() EST refusal_reason() == "". On le verifie sur tout le catalogue reel
## contre une serie de decks (vide, partiel, 6 ids, plein, exemplaires au plafond),
## decouvert ou non : la moindre divergence rendrait l ecran incoherent.
func _test_can_add_et_refusal_reason_ne_divergent_jamais() -> void:
	var cartes: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null:
			cartes.append(c)
	ok(not cartes.is_empty(), "le catalogue est charge")
	var decks: Array = [[], _deck(DeckRules.DECK_SIZE),
		_deck_en_ids(DeckRules.MAX_DISTINCT, DeckRules.MAX_DISTINCT)]
	# Un deck reel : le deck par defaut, et le meme ampute de 3 cartes.
	var defaut: Array = DeckRules.default_deck_ids()
	decks.append(defaut)
	decks.append(defaut.slice(0, defaut.size() - 3))
	var ecarts: int = 0
	var cas: int = 0
	for d in decks:
		for c: SpellCard in cartes:
			for dec in [true, false]:
				cas += 1
				if DeckRules.can_add(d, c, dec) != (DeckRules.refusal_reason(d, c, dec) == ""):
					ecarts += 1
	eq(ecarts, 0, "can_add et refusal_reason concordent sur %d cas" % cas)


## Les passifs sont SORTIS du deck (chantier F) : ils s equipent de 0 a 3.
func _test_passifs_hors_deck() -> void:
	ok(DeckRules.passives_valid([]), "aucun passif : valide")
	ok(DeckRules.passives_valid(["a", "b", "c"]), "3 passifs : valide")
	not_ok(DeckRules.passives_valid(["a", "b", "c", "d"]), "4 passifs : invalide")


func _test_message() -> void:
	var court: String = DeckRules.validation_message(_deck(DeckRules.DECK_SIZE - 3))
	ok(court.contains("3"), "le message dit combien de cartes MANQUENT : %s" % court)
	var long: String = DeckRules.validation_message(_deck(DeckRules.DECK_SIZE + 3))
	ok(long.contains("3"), "le message dit combien de cartes EN TROP : %s" % long)
	var sept: String = DeckRules.validation_message(
		_deck_en_ids(DeckRules.DECK_SIZE, DeckRules.MAX_DISTINCT + 1))
	ok(sept.to_lower().contains("differentes") and sept.contains(str(DeckRules.MAX_DISTINCT)),
		"le message nomme les cartes differentes : %s" % sept)
	# Un deck court ET a 7 ids : le message parle des ids d abord, sinon il
	# enverrait le joueur ajouter des cartes que l ecran refuserait.
	var court_sept: String = DeckRules.validation_message(
		_deck_en_ids(DeckRules.MAX_DISTINCT + 1, DeckRules.MAX_DISTINCT + 1))
	ok(court_sept.to_lower().contains("differentes"),
		"7 ids sur un deck court : on parle des ids d abord (%s)" % court_sept)
	var copies: Array = ["com_x", "com_x", "com_x", "com_x", "com_x"]
	while copies.size() < DeckRules.DECK_SIZE:
		copies.append("com_y")
	var trop_copies: String = DeckRules.validation_message(copies)
	ok(trop_copies.contains("com_x") and trop_copies.contains("5"),
		"le message nomme la carte en trop d exemplaires : %s" % trop_copies)
	eq(DeckRules.validation_message(_deck(DeckRules.DECK_SIZE)), "", "aucun message si valide")


## Un deck compose AVANT la regle des 6 ne doit etre ni detruit ni tronque en
## silence : SaveData le garde tel quel, is_valid() le refuse (le Massacre ne
## le jouera pas) et validation_message() — affiche sous JOUER et dans l ecran
## de deck — dit pourquoi. Le joueur choisit lui-meme ce qu il retire.
func _test_un_deck_sauvegarde_hors_regle_est_garde_et_explique() -> void:
	SaveData.reset_profile()
	# Sept ids REELS, exemplaires respectes, 15 cartes : le deck typique d un
	# joueur d avant la regle.
	var ids: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and ids.size() < DeckRules.MAX_DISTINCT + 1:
			ids.append(String(c.id))
	var deck: Array = []
	var k: int = 0
	while deck.size() < DeckRules.DECK_SIZE and not ids.is_empty():
		deck.append(ids[k % ids.size()])
		k += 1
	SaveData.set_massacre_deck(deck)
	eq(SaveData.massacre_deck(), deck, "le deck sauvegarde est rendu intact")
	not_ok(DeckRules.is_valid(SaveData.massacre_deck()), "et il n est pas jouable")
	ok(DeckRules.validation_message(SaveData.massacre_deck()).to_lower().contains("differentes"),
		"le joueur lit pourquoi : %s" % DeckRules.validation_message(SaveData.massacre_deck()))
	SaveData.reset_profile()


func _test_resolve() -> void:
	var ids: Array = ["arcane_bolt", "arcane_bolt", "id_inconnu", "frost_field"]
	var cards: Array[SpellCard] = DeckRules.resolve(ids)
	eq(cards.size(), 3, "les ids inconnus sont ignores, les doublons gardes")
	eq(cards[0].id, &"arcane_bolt", "premier exemplaire")
	eq(cards[1].id, &"arcane_bolt", "second exemplaire")


func _test_deck_par_defaut() -> void:
	var ids: Array = DeckRules.default_deck_ids()
	eq(ids.size(), DeckRules.DECK_SIZE, "le deck de base fait pile 15 cartes")
	ok(DeckRules.count_distinct(ids) <= DeckRules.MAX_DISTINCT,
		"le deck de base tient en %d cartes differentes (%d)"
		% [DeckRules.MAX_DISTINCT, DeckRules.count_distinct(ids)])
	ok(DeckRules.is_valid(ids), "le deck de base est jouable : %s"
		% DeckRules.validation_message(ids))
	for id in ids:
		var c: SpellCard = ContentDB.cards.get(StringName(id))
		ok(c != null, "le deck de base ne contient que des cartes connues (%s)" % id)
		if c != null:
			not_ok(c.is_passive, "aucun passif dans le deck de base (%s)" % id)


## Les ids d un deck de campagne (une entree par exemplaire).
func _ids_du_niveau(lvl: LevelDef) -> Array:
	var out: Array = []
	for c in lvl.exploration_deck:
		if c != null:
			out.append(String((c as SpellCard).id))
	return out


## Ce qui ne va pas dans un deck de campagne, "" s il suit la regle. Isole pour
## pouvoir l appliquer AUSSI a un deck volontairement casse : un controle qu on
## n a jamais vu echouer ne protege rien.
func _defaut_du_deck(lvl: LevelDef) -> String:
	for c in lvl.exploration_deck:
		if c == null:
			return "une entree vide"
		if (c as SpellCard).is_passive:
			return "un passif (%s), ils s equipent a part" % (c as SpellCard).id
	return DeckRules.validation_message(_ids_du_niveau(lvl))


## Le trou que ce test bouche : GameController._build_deck() prend
## level_def.exploration_deck DIRECTEMENT, sans passer par is_valid(). Seul le
## mode Massacre etait valide. Les decks de campagne pouvaient donc violer la
## regle sans que rien ne rougisse — et six sur sept la violaient (jusqu a 20
## cartes et 6 epiques), puis vingt sur vingt et un depassaient 6 cartes
## differentes (jusqu a 11) quand la regle des 6 est arrivee. La regle vaut "que
## ce soit en campagne ou en massacre" : elle se verifie sur le contenu LIVRE.
func _test_les_decks_de_campagne_suivent_la_regle() -> void:
	ok(not ContentDB.levels.is_empty(), "des niveaux sont charges")
	for key in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[key]
		var ids: Array = _ids_du_niveau(lvl)
		eq(ids.size(), DeckRules.DECK_SIZE,
			"%s : le deck fait pile %d cartes" % [key, DeckRules.DECK_SIZE])
		ok(DeckRules.count_distinct(ids) <= DeckRules.MAX_DISTINCT,
			"%s : %d cartes differentes, %d au maximum"
			% [key, DeckRules.count_distinct(ids), DeckRules.MAX_DISTINCT])
		var defaut: String = _defaut_du_deck(lvl)
		eq(defaut, "", "%s : le deck suit la regle (%s)" % [key, defaut])

	# SABOTAGE PERMANENT : le meme controle, sur un niveau reel auquel on greffe
	# une 7e carte differente a la place d un exemplaire. Il DOIT rougir.
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	if lvl1 == null:
		ok(false, "lvl_01 introuvable pour le sabotage")
		return
	var casse: LevelDef = lvl1.duplicate()
	var cartes: Array[SpellCard] = lvl1.exploration_deck.duplicate()
	var etrangeres: Array[SpellCard] = []
	for c2: SpellCard in ContentDB.cards.values():
		if c2 != null and not c2.is_passive and not lvl1.exploration_deck.has(c2):
			etrangeres.append(c2)
	# On remplace des DOUBLONS (la taille et les ids d origine restent) jusqu a
	# depasser 6 ids d un seul : le sabotage ne vise que la regle des 6, meme si
	# le tutoriel descendait un jour sous 6 cartes differentes.
	var garde: int = DeckRules.DECK_SIZE
	while garde > 0 and not etrangeres.is_empty():
		garde -= 1
		var ids_casse: Array = []
		for c3 in cartes:
			ids_casse.append((c3 as SpellCard).id)
		if DeckRules.count_distinct(ids_casse) > DeckRules.MAX_DISTINCT:
			break
		var i_doublon: int = _index_d_un_doublon(ids_casse)
		if i_doublon < 0:
			break
		cartes[i_doublon] = etrangeres.pop_back()
	casse.exploration_deck = cartes
	var n_ids: int = DeckRules.count_distinct(_ids_du_niveau(casse))
	eq(n_ids, DeckRules.MAX_DISTINCT + 1, "le sabotage donne 7 ids au niveau 1")
	eq(_ids_du_niveau(casse).size(), DeckRules.DECK_SIZE, "le sabotage garde 15 cartes")
	ok(_defaut_du_deck(casse) != "",
		"une 7e carte differente au niveau 1 fait rougir le controle")


## Un index dont l id apparait au moins deux fois : le remplacer garde la taille
## et tous les ids d origine, et ajoute exactement un id.
func _index_d_un_doublon(ids: Array) -> int:
	for i in ids.size():
		if DeckRules.count_of(ids, StringName(ids[i])) > 1:
			return i
	return -1


## Les niveaux dans l ORDRE OU ON LES JOUE, en suivant `next_levels` (meme
## parcours que la carte de campagne et le banc) : lvl_17 se joue avant lvl_03,
## l ordre des identifiants mentirait.
func _ordre_de_jeu() -> Array[StringName]:
	var pointes: Dictionary = {}
	for k in ContentDB.levels:
		for s in (ContentDB.levels[k] as LevelDef).next_levels:
			pointes[StringName(s)] = true
	var departs: Array[StringName] = []
	for k in ContentDB.levels:
		if not pointes.has(StringName(k)):
			departs.append(StringName(k))
	departs.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var ordre: Array[StringName] = []
	var vus: Dictionary = {}
	var file: Array[StringName] = departs.duplicate()
	var garde: int = 512
	while not file.is_empty() and garde > 0:
		garde -= 1
		var id: StringName = file.pop_front()
		if vus.has(id) or not ContentDB.levels.has(id):
			continue
		vus[id] = true
		ordre.append(id)
		for s in (ContentDB.levels[id] as LevelDef).next_levels:
			if not vus.has(StringName(s)):
				file.append(StringName(s))
	var reste: Array[StringName] = []
	for k in ContentDB.levels:
		if not vus.has(StringName(k)):
			reste.append(StringName(k))
	reste.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	ordre.append_array(reste)
	return ordre


## LE PRINCIPE QUI REMPLACE "LE POOL GRANDIT DE NIVEAU EN NIVEAU".
##
## L ancien principe voulait que chaque deck compte au moins autant de cartes
## differentes que le precedent (6, 10, 10, 10, 10, 11...). Avec 6 ids au
## maximum, il ne peut plus croitre : tous les decks plafonnent a 6 des le
## tutoriel. Ce qui peut encore grandir, c est ce que le joueur a VU.
##
## D ou la regle tenable : dans l ORDRE DE JEU, chaque niveau fait decouvrir au
## moins une carte qu aucun deck de campagne precedent n avait montree, tant
## que le catalogue de sorts n est pas epuise. La variete passe de l interieur
## d un deck (ou elle diluait la pioche) a la succession des decks.
func _test_chaque_niveau_fait_decouvrir_une_carte() -> void:
	var catalogue: Dictionary = {}
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive:
			catalogue[c.id] = true
	var ordre: Array[StringName] = _ordre_de_jeu()
	eq(ordre.size(), ContentDB.levels.size(), "l ordre de jeu couvre tous les niveaux")
	var vues: Dictionary = {}
	for i in ordre.size():
		var lvl: LevelDef = ContentDB.levels[ordre[i]]
		var nouvelles: Array = []
		for c in lvl.exploration_deck:
			var carte: SpellCard = c
			if carte != null and not vues.has(carte.id) and not nouvelles.has(carte.id):
				nouvelles.append(carte.id)
		if i > 0 and vues.size() < catalogue.size():
			ok(not nouvelles.is_empty(),
				"%s (%de joue) fait decouvrir au moins une carte (%d deja vues sur %d)"
				% [ordre[i], i + 1, vues.size(), catalogue.size()])
		for id in nouvelles:
			vues[id] = true
