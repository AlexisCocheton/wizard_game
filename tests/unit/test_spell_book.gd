extends TestCase
## LE LIVRE DE SORTS : quelles cartes sont OBTENUES (retouche du co-auteur, 01/10).
##
## "Niveau 1 : les cartes de notre deck sont directement dans le livre de sorts,
## mais on peut obtenir quelques autres cartes en montant de niveau." Une carte
## est obtenue si (a) elle est dans le deck de campagne d un niveau OUVERT, (b) le
## joueur l a PRISE en combat (brulee : non), ou (c) le profil l avait deja.
## copies_in_starter ne donne plus rien.
##
## Les deux ecarts constates par l audit, et que cette suite interdit :
##   - les communes "de depart" etaient obtenues d office : l Etincelle, carte
##     NOUVELLE du niveau 1, etait deja dans le livre, et la Nappe montante,
##     hors du pool du niveau 1, y etait lisible ;
##   - le Mur de pierre, dans le deck du niveau 1, restait "a obtenir" tant que
##     la premiere partie n etait pas lancee.
## Aucun id ni aucun nombre en dur : tout se lit dans le contenu (premier niveau,
## ses cartes nouvelles, le niveau qu il ouvre, copies_in_starter).


func get_suite_name() -> String:
	return "spell_book"


func run() -> void:
	_test_profil_neuf_egal_deck_du_premier_niveau()
	_test_le_demarrage_n_ecrit_rien()
	_test_ouvrir_un_niveau_ajoute_son_deck()
	_test_prise_en_combat_et_carte_brulee()
	_test_distribuer_ou_equiper_n_obtient_rien()
	_test_migration_garde_les_anciennes_communes()
	_test_fonction_pure_des_decks()
	_test_deck_par_defaut_valide_et_obtenu()
	_test_pool_hors_campagne_suit_le_livre()
	_test_grimoire_et_ecran_de_deck_suivent_la_regle()
	# Etat propre pour les suites suivantes.
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


# --- Outils --------------------------------------------------------------

func _premier() -> LevelDef:
	return ContentDB.levels.get(SaveData.FIRST_LEVEL)


## Le niveau qu ouvre la victoire du premier : celui que le joueur voit s ouvrir.
func _second() -> LevelDef:
	var lv1: LevelDef = _premier()
	if lv1 == null:
		return null
	for id in lv1.next_levels:
		var lv: LevelDef = ContentDB.levels.get(id)
		if lv != null:
			return lv
	return null


## Ids (String) distincts et tries d une liste de cartes ou d ids.
func _ids(liste: Array) -> Array[String]:
	var out: Array[String] = []
	for x in liste:
		var id: String = String((x as SpellCard).id) if x is SpellCard else String(x)
		if not out.has(id):
			out.append(id)
	out.sort()
	return out


## Les ids (String, tries) de TOUTES les cartes du livre, sorts et passifs.
func _livre() -> Array[String]:
	var out: Array[String] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and SaveData.is_discovered(c.id):
			out.append(String(c.id))
	out.sort()
	return out


## Un sort qu aucun deck de campagne ne porte : rien ne peut l obtenir par (a).
func _sort_hors_de_tout_deck(sauf: Array = []) -> SpellCard:
	var en_deck: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for c: SpellCard in lv.exploration_deck:
			if c != null:
				en_deck[c.id] = true
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var c2: SpellCard = ContentDB.cards[id]
		if c2 != null and not c2.is_passive and not en_deck.has(c2.id) and not sauf.has(c2):
			return c2
	return null


# --- (a) Les decks des niveaux ouverts ---------------------------------------

func _test_profil_neuf_egal_deck_du_premier_niveau() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	ok(lv1 != null, "le premier niveau de la campagne existe")
	if lv1 == null:
		return
	ok(SaveData.is_level_unlocked(lv1.id), "profil neuf : le premier niveau est ouvert")
	ok(not lv1.exploration_deck.is_empty(), "le premier niveau a un deck de campagne")
	eq(_livre(), _ids(lv1.exploration_deck),
		"profil neuf : le livre est EXACTEMENT le deck du premier niveau")
	for c: SpellCard in lv1.exploration_deck:
		eq(SaveData.card_visibility(c.id), SaveData.CARD_OBTAINED,
			"%s, du deck du premier niveau, est obtenue avant toute partie" % c.id)
	eq((SaveData.profile().get("discovered_cards", []) as Array).size(), 0,
		"rien n est ECRIT au profil neuf : le deck est deduit des niveaux ouverts")
	eq(int(SaveData.card_counts()[0]), _ids(lv1.exploration_deck).size(),
		"le compteur des ecrans compte le deck du premier niveau")
	eq(SaveData.discovered_count(), _ids(lv1.exploration_deck).size(),
		"le compte brut aussi")
	# Les cartes NOUVELLES du premier niveau sont a obtenir : c est la phrase du
	# co-auteur, "on peut obtenir quelques autres cartes en montant de niveau".
	var nouvelles: int = 0
	for c2: SpellCard in lv1.levelup_cards:
		if c2 == null or _ids(lv1.exploration_deck).has(String(c2.id)):
			continue
		nouvelles += 1
		eq(SaveData.card_visibility(c2.id), SaveData.CARD_OBTAINABLE,
			"%s, carte NOUVELLE du premier niveau, est a obtenir, pas obtenue" % c2.id)
	ok(nouvelles > 0, "le premier niveau a des cartes nouvelles a obtenir")
	# copies_in_starter ne donne plus rien : une "carte de depart" hors du deck
	# du premier niveau n est pas dans le livre.
	var depart_hors_deck: int = 0
	for c3: SpellCard in ContentDB.cards.values():
		if c3 == null or c3.copies_in_starter <= 0:
			continue
		if _ids(lv1.exploration_deck).has(String(c3.id)):
			continue
		depart_hors_deck += 1
		not_ok(SaveData.is_discovered(c3.id),
			"%s a des exemplaires de depart mais n est pas au deck du premier niveau : pas obtenue"
			% c3.id)
	ok(depart_hors_deck > 0,
		"le contenu a des cartes de depart hors du premier deck (sinon ce test ne mord pas)")
	# Remettre a zero un profil qui avait pris des cartes : de nouveau le seul
	# deck du premier niveau.
	var prise: SpellCard = _sort_hors_de_tout_deck()
	if prise != null:
		SaveData.discover_card(prise.id)
	SaveData.unlock_level(_second().id if _second() != null else lv1.id)
	SaveData.reset_profile()
	eq(_livre(), _ids(lv1.exploration_deck), "profil remis a zero : le premier deck, exactement")


## Le DEMARRAGE du jeu : SaveData charge le profil, puis ContentDB indexe le
## contenu. C est la que les communes de depart etaient versees d office ; un
## test qui part de reset_profile() ne passe jamais par la et ne le verrait pas.
func _test_le_demarrage_n_ecrit_rien() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	ContentDB.reload()
	if lv1 != null:
		eq(_livre(), _ids(lv1.exploration_deck),
			"apres le chargement du contenu, le livre est toujours le premier deck")
	eq((SaveData.profile().get("discovered_cards", []) as Array).size(), 0,
		"le chargement du contenu n ecrit aucune carte au profil")


func _test_ouvrir_un_niveau_ajoute_son_deck() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	var lv2: LevelDef = _second()
	ok(lv2 != null, "le premier niveau en ouvre un autre")
	if lv1 == null or lv2 == null:
		return
	var neuves: Array[SpellCard] = []
	for c: SpellCard in lv2.exploration_deck:
		if c != null and not _ids(lv1.exploration_deck).has(String(c.id)) \
				and not neuves.has(c):
			neuves.append(c)
	ok(not neuves.is_empty(),
		"le deck du second niveau a des cartes que le premier n a pas (sinon ce test ne mord pas)")
	for c2 in neuves:
		not_ok(SaveData.is_discovered(c2.id),
			"%s, du deck d un niveau FERME, n est pas obtenue" % c2.id)
	# Le geste reel : gagner le premier niveau ouvre le second.
	SaveData.record_victory(lv1, GameEnums.Mode.EXPLORATION, {}, 1)
	ok(SaveData.is_level_unlocked(lv2.id), "la victoire ouvre le second niveau")
	for c3 in neuves:
		eq(SaveData.card_visibility(c3.id), SaveData.CARD_OBTAINED,
			"%s : son niveau s ouvre, la voila dans le livre sans avoir joue" % c3.id)
	var attendu: Array[String] = _ids(SaveData.cards_owned_by_decks([lv1.id, lv2.id]))
	eq(_livre(), attendu, "livre = decks des deux niveaux ouverts, rien d autre")
	eq((SaveData.profile().get("discovered_cards", []) as Array).size(), 0,
		"ouvrir un niveau n ecrit rien : son deck se deduit")
	SaveData.reset_profile()


# --- (b) La prise en combat ---------------------------------------------------

func _test_prise_en_combat_et_carte_brulee() -> void:
	SaveData.reset_profile()
	RunState.reset()
	var prise: SpellCard = _sort_hors_de_tout_deck()
	var brulee: SpellCard = _sort_hors_de_tout_deck([prise])
	ok(prise != null and brulee != null, "deux sorts hors de tout deck de campagne")
	if prise == null or brulee == null:
		return
	not_ok(SaveData.is_discovered(prise.id), "avant la prise : pas obtenue")
	RunState.pending_offer = [prise, brulee]
	RunState.pick_offer(0)
	eq(SaveData.card_visibility(prise.id), SaveData.CARD_OBTAINED,
		"la PREMIERE prise en combat la fait entrer au livre")
	RunState.pending_offer = [prise, brulee]
	RunState.burn_offer(1)
	RunState.take_burned()
	not_ok(SaveData.is_discovered(brulee.id), "une carte BRULEE n entre pas au livre")
	var lv1: LevelDef = _premier()
	if lv1 != null:
		var attendu: Array = _ids(lv1.exploration_deck)
		attendu.append(String(prise.id))
		attendu.sort()
		eq(_livre(), attendu, "livre = premier deck + la carte prise, exactement")
	RunState.reset()
	SaveData.reset_profile()


## Les deux chemins qui obtenaient en douce. Distribuer le deck d un niveau
## FERME (banc, tests, Infini d un niveau) et equiper un passif n ajoutent rien
## au livre : la seule porte d entree est la prise.
func _test_distribuer_ou_equiper_n_obtient_rien() -> void:
	SaveData.reset_profile()
	RunState.reset()
	var ferme: LevelDef = null
	var ids_niveaux: Array = ContentDB.levels.keys()
	ids_niveaux.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids_niveaux:
		var lv: LevelDef = ContentDB.levels[id]
		if SaveData.is_level_unlocked(lv.id):
			continue
		for c: SpellCard in lv.exploration_deck:
			if c != null and not SaveData.is_discovered(c.id):
				ferme = lv
				break
		if ferme != null:
			break
	ok(ferme != null, "un niveau ferme a dans son deck une carte hors du livre")
	if ferme != null:
		var avant: Array[String] = _livre()
		RunState.build_deck_from_list(ferme.exploration_deck)
		ok(RunState.total_cards() > 0, "le deck a bien ete distribue")
		eq(_livre(), avant, "distribuer le deck d un niveau ferme n obtient rien")
	var passif: SpellCard = null
	for c2: SpellCard in ContentDB.cards.values():
		if c2 != null and c2.is_passive and not SaveData.is_discovered(c2.id):
			passif = c2
			break
	ok(passif != null, "un passif hors du livre")
	if passif != null:
		ok(RunState.equip_passive(passif), "le passif s equipe")
		not_ok(SaveData.is_discovered(passif.id), "equiper un passif ne l obtient pas")
	RunState.reset()
	SaveData.reset_profile()


# --- (c) Rien n est retire a un profil existant -------------------------------

## Un profil ecrit avant la regle : l ancien chargement du contenu y avait verse
## toutes les cartes de depart (copies_in_starter > 0), Etincelle et Nappe
## montante comprises. Il les garde, meme hors de tout deck ouvert.
func _test_migration_garde_les_anciennes_communes() -> void:
	var lv1: LevelDef = _premier()
	if lv1 == null:
		return
	var anciennes: Array = []
	var hors_deck: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.copies_in_starter > 0:
			anciennes.append(String(c.id))
			if not _ids(lv1.exploration_deck).has(String(c.id)):
				hors_deck.append(String(c.id))
	ok(not hors_deck.is_empty(),
		"des cartes de depart sont hors du premier deck (sinon ce test ne mord pas)")
	SaveData.load_from_dictionary({
		"schema_version": 1,
		"profile": {
			"discovered_cards": anciennes.duplicate(),
			"campaign": {"current_node": String(lv1.id), "unlocked_levels": [String(lv1.id)]},
		},
	})
	for id in anciennes:
		eq(SaveData.card_visibility(StringName(id)), SaveData.CARD_OBTAINED,
			"l ancien profil garde %s" % id)
	for c2: SpellCard in lv1.exploration_deck:
		ok(SaveData.is_discovered(c2.id),
			"et a le deck du premier niveau, Mur de pierre compris (%s)" % c2.id)
	var attendu: Array = _ids(anciennes + _ids(lv1.exploration_deck))
	eq(_livre(), attendu, "ancien profil : ce qu il avait + le premier deck, rien de plus")
	# Relire le profil ecrit ne perd rien (la migration est une union).
	SaveData.load_from_dictionary(SaveData.to_dictionary())
	eq(_livre(), attendu, "relu, le profil ne perd rien")
	SaveData.reset_profile()


# --- La fonction pure ---------------------------------------------------------

func _test_fonction_pure_des_decks() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	var lv2: LevelDef = _second()
	if lv1 == null or lv2 == null:
		return
	eq(SaveData.cards_owned_by_decks([]).size(), 0, "aucun niveau : aucune carte")
	var un: Array[StringName] = SaveData.cards_owned_by_decks([lv1.id])
	eq(_ids(un), _ids(lv1.exploration_deck), "un niveau : les ids de son deck")
	var deux: Array[StringName] = SaveData.cards_owned_by_decks([lv1.id, lv2.id])
	eq(_ids(deux), _ids(lv1.exploration_deck + lv2.exploration_deck), "deux niveaux : l union")
	var noms: Array[String] = []
	for id in deux:
		noms.append(String(id))
	var tries: Array[String] = noms.duplicate()
	tries.sort()
	eq(noms, tries, "triee par id")
	eq(noms.size(), _ids(noms).size(), "sans doublon")
	eq(SaveData.cards_owned_by_decks([String(lv1.id), &"niveau_inconnu"]), un,
		"String ou StringName, et un id inconnu est ignore")
	# PURE : le profil n y entre pas.
	var prise: SpellCard = _sort_hors_de_tout_deck()
	if prise != null:
		SaveData.discover_card(prise.id)
	SaveData.unlock_level(lv2.id)
	SaveData.set_tester_mode(true)
	eq(SaveData.cards_owned_by_decks([lv1.id]), un,
		"ni les cartes prises, ni les niveaux ouverts, ni le mode testeur n y entrent")
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


# --- Ce qui lit le livre --------------------------------------------------------

func _test_deck_par_defaut_valide_et_obtenu() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	var ids: Array = DeckRules.default_deck_ids()
	ok(DeckRules.is_valid(ids), "profil neuf : deck par defaut valide (%s)"
		% DeckRules.validation_message(ids))
	for id in ids:
		ok(SaveData.is_discovered(StringName(id)), "profil neuf : %s du deck par defaut est obtenue" % id)
	if lv1 != null:
		var attendu: Array = []
		for c: SpellCard in lv1.exploration_deck:
			attendu.append(String(c.id))
		var trie: Array = ids.duplicate()
		trie.sort()
		attendu.sort()
		eq(trie, attendu, "c est le deck du premier niveau, exemplaires compris")
	# Un profil EDITE dont le premier niveau est ferme, et a qui il manque la
	# carte la plus rare de ce deck : le premier deck n est plus obtenu, le repli
	# compose avec les cartes obtenues seules, et reste valide.
	var obtenues: Array = []
	if lv1 != null:
		var plus_rare: SpellCard = null
		for c2: SpellCard in lv1.exploration_deck:
			if plus_rare == null or c2.rarity > plus_rare.rarity:
				plus_rare = c2
		for id3 in _ids(lv1.exploration_deck):
			if id3 != String(plus_rare.id):
				obtenues.append(id3)
	SaveData.load_from_dictionary({
		"schema_version": 1,
		"profile": {"discovered_cards": obtenues,
			"campaign": {"current_node": "", "unlocked_levels": []}},
	})
	var repli: Array = DeckRules.default_deck_ids()
	eq(_ids(_livre()), _ids(obtenues), "le profil edite a bien le livre voulu")
	ok(DeckRules.is_valid(repli), "premier niveau ferme : le repli est valide (%s)"
		% DeckRules.validation_message(repli))
	for id2 in repli:
		ok(SaveData.is_discovered(StringName(id2)), "repli : %s est obtenue" % id2)
	SaveData.reset_profile()


## Hors campagne (Infini, Massacre), le pool de montee de niveau est le livre.
func _test_pool_hors_campagne_suit_le_livre() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	if lv1 == null:
		return
	for m in GameEnums.Mode.values():
		if not GameEnums.is_endless(m):
			continue
		eq(_ids(RunState.levelup_pool(MassacreMode.level_def(), m)), _ids(lv1.exploration_deck),
			"profil neuf, %s : le pool est le deck du premier niveau" % GameEnums.mode_name(m))


func _test_grimoire_et_ecran_de_deck_suivent_la_regle() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _premier()
	var lv2: LevelDef = _second()
	if lv1 == null or lv2 == null:
		return
	for etape in 2:
		if etape == 1:
			SaveData.unlock_level(lv2.id)
		var ouverts: Array = [lv1.id] if etape == 0 else [lv1.id, lv2.id]
		var livre: Array[String] = _ids(SaveData.cards_owned_by_decks(ouverts))
		var quand: String = "profil neuf" if etape == 0 else "second niveau ouvert"
		# Le grimoire : obtenues = le livre, et elles passent avant les grisees.
		var connues: Array = []
		for e in GalleryPanel.entries_of(GalleryPanel.Section.SPELLS):
			if GalleryPanel.is_known(e):
				connues.append(e)
			else:
				ok(GalleryPanel.is_obtainable(e), "%s : %s visible et non obtenue est grisee"
					% [quand, (e as SpellCard).id])
				ok(CollectionStyle.where_to_obtain(e).contains("montee"),
					"%s : %s se prend a la montee de niveau" % [quand, (e as SpellCard).id])
		eq(_ids(connues), livre, "%s : le grimoire montre le livre en couleurs" % quand)
		# L ecran de deck : la meme collection, les memes obtenues.
		var panel := DeckPanel.new()
		attach(panel)
		panel.refresh()
		var posables: Array = []
		for c: SpellCard in panel.collection():
			if SaveData.is_discovered(c.id):
				posables.append(c)
				eq(panel.refusal_for(c).contains("decouverte"), false,
					"%s : %s obtenue n est pas refusee comme non decouverte" % [quand, c.id])
		eq(_ids(posables), livre, "%s : l ecran de deck compose avec le livre" % quand)
		ok(DeckRules.is_valid(SaveData.massacre_deck()),
			"%s : le deck propose par l ecran est valide" % quand)
		detach(panel)
	SaveData.reset_profile()
