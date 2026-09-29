extends TestCase
## PROGRESSION DES CARTES ET PASSIFS PAR ACTE (vague 5, chantier P).
##
## Regles du co-auteur verrouillees ici :
##   - pool de montee de niveau en campagne = deck du niveau + ses cartes
##     nouvelles + les cartes des objectifs REUSSIS ; hors campagne = les cartes
##     deja OBTENUES ;
##   - toute offre passe par ce pool ;
##   - une carte s obtient la premiere fois qu on la PREND (pas en la brulant) ;
##   - grimoire et deck : obtenue / obtenable (grisee) / invisible ;
##   - un profil ancien ne perd rien (legendaires "3/3" reversees) ;
##   - passifs : rien avant l acte 2, trois equipes actifs des le debut, et les
##     passifs COMMUNS peuvent enfin etre proposes.
## Aucun nombre de reglage en dur : les tailles se lisent dans le contenu et
## dans les constantes (LevelDef.LEVELUP_NEW_CARDS, DeckRules.MAX_PASSIVES...).

## Tirages utilises pour les proprietes statistiques. Assez pour qu une famille
## a 20 % et une rarete a 50 % sortent a coup sur, assez peu pour rester rapide.
const TIRAGES: int = 300


func get_suite_name() -> String:
	return "card_progression"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_pool_de_campagne_exact()
	_test_un_objectif_reussi_ajoute_sa_carte_au_pool()
	_test_pool_hors_campagne_egal_aux_cartes_obtenues()
	_test_toute_offre_vient_du_pool()
	_test_premiere_prise_obtient_bruler_non()
	_test_visibilite_trois_etats()
	_test_le_grimoire_et_le_deck_cachent_l_invisible()
	_test_migration_d_un_ancien_profil()
	_test_rang_et_rarete_des_recompenses()
	_test_niveau_sans_contenu_de_progression()
	_test_passifs_rien_avant_l_acte_2()
	_test_passifs_hors_campagne_selon_l_acte_atteint()
	_test_passifs_equipes_actifs_au_depart()
	_test_passifs_communs_proposables()
	_test_ecran_de_deck_equipe_les_passifs()
	# Etat propre pour les suites suivantes.
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	SaveData.reset_profile()
	ContentDB.discover_starters()
	reset_gauge_at_normal_speed()


# --- Outils --------------------------------------------------------------

## Une valeur de Mode qui n est PAS la campagne. Deduite de l enum plutot que
## nommee : le chantier des modes renomme les autres valeurs, et la regle ne
## connait que "campagne ou pas".
func _mode_hors_campagne() -> GameEnums.Mode:
	for v in GameEnums.Mode.values():
		if v != GameEnums.Mode.EXPLORATION:
			return v
	return GameEnums.Mode.EXPLORATION


## Des sorts reels du catalogue, tries par id (ordre stable), filtres.
func _sorts(rarete: int = -1, sauf: Array = []) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive or sauf.has(c):
			continue
		if rarete >= 0 and c.rarity != rarete:
			continue
		out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) < String(b.id))
	return out


func _passifs() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool:
		return String(a.id) < String(b.id))
	return out


func _objectif(id: String) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName(id)
	o.check_key = &"no_damage_taken"
	return o


## Un niveau SYNTHETIQUE complet : deck de deux sorts communs, trois cartes
## nouvelles, trois objectifs recompenses rare / epique / legendaire.
func _niveau(acte: int) -> LevelDef:
	var lv := LevelDef.new()
	lv.id = StringName("test_prog_acte_%d" % acte)
	lv.act = acte
	var communs: Array[SpellCard] = _sorts(GameEnums.Rarity.COMMON)
	lv.exploration_deck = [communs[0], communs[0], communs[1]]
	var pris: Array = [communs[0], communs[1]]
	var nouvelles: Array[SpellCard] = []
	for c in _sorts(-1, pris):
		if nouvelles.size() >= LevelDef.LEVELUP_NEW_CARDS:
			break
		nouvelles.append(c)
		pris.append(c)
	lv.levelup_cards = nouvelles
	lv.objectives = [_objectif("t_obj_a"), _objectif("t_obj_b"), _objectif("t_obj_c")]
	var rec: Array[SpellCard] = []
	for rang in range(1, lv.objectives.size() + 1):
		var r: int = LevelDef.reward_rarity_for_rank(rang)
		rec.append(_sorts(r, pris)[0])
		pris.append(rec[rec.size() - 1])
	lv.objective_rewards = rec
	return lv


## Ids dans l ORDRE (pas de tri) : l ordre des emplacements compte.
func _ids_de(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		out.append(String((c as SpellCard).id))
	return out


func _ids(cartes: Array) -> Array[String]:
	var out: Array[String] = []
	for c in cartes:
		if c != null and not out.has(String((c as SpellCard).id)):
			out.append(String((c as SpellCard).id))
	out.sort()
	return out


# --- A. Le pool ------------------------------------------------------------

func _test_pool_de_campagne_exact() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau(1)
	var pool: Array[SpellCard] = RunState.levelup_pool(lv, GameEnums.Mode.EXPLORATION)
	var attendu: Array = []
	attendu.append_array(lv.exploration_deck)
	attendu.append_array(lv.levelup_cards)
	eq(_ids(pool), _ids(attendu),
		"campagne, aucun objectif reussi : deck du niveau + cartes nouvelles, rien d autre")
	eq(pool.size(), _ids(pool).size(), "chaque carte n y figure qu une fois")
	for r in lv.objective_rewards:
		not_ok(pool.has(r), "la carte d un objectif NON reussi n est pas dans le pool (%s)" % r.id)


func _test_un_objectif_reussi_ajoute_sa_carte_au_pool() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau(1)
	var premier: ObjectiveDef = lv.objectives[0]
	var dernier: ObjectiveDef = lv.objectives[lv.objectives.size() - 1]
	var nouveau: bool = SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION,
		{premier.id: true, dernier.id: true}, 1)
	ok(nouveau, "la victoire signale une carte nouvellement debloquee")
	var pool: Array[SpellCard] = RunState.levelup_pool(lv, GameEnums.Mode.EXPLORATION)
	var attendu: Array = []
	attendu.append_array(lv.exploration_deck)
	attendu.append_array(lv.levelup_cards)
	attendu.append(lv.reward_of(premier))
	attendu.append(lv.reward_of(dernier))
	eq(_ids(pool), _ids(attendu),
		"campagne : deck + cartes nouvelles + cartes des objectifs REUSSIS, exactement")
	not_ok(pool.has(lv.objective_rewards[1]), "l objectif rate ne rapporte rien")
	# Debloquer n est pas obtenir : la carte attend d etre prise en combat.
	not_ok(SaveData.is_discovered(lv.reward_of(premier).id),
		"la carte debloquee n est PAS donnee, elle entre au pool")
	var encore: bool = SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION,
		{premier.id: true}, 1)
	not_ok(encore, "un objectif deja acquis ne redebloque rien")
	# Le pool ne vaut que pour CE niveau.
	var autre: LevelDef = _niveau(1)
	autre.id = &"test_prog_autre"
	not_ok(RunState.levelup_pool(autre, GameEnums.Mode.EXPLORATION)
			.has(lv.reward_of(premier)),
		"un objectif reussi n ouvre sa carte que dans son propre niveau")


func _test_pool_hors_campagne_egal_aux_cartes_obtenues() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var lv: LevelDef = _niveau(1)
	var hors: GameEnums.Mode = _mode_hors_campagne()
	ok(hors != GameEnums.Mode.EXPLORATION, "il existe un mode hors campagne")
	# Une carte obtenue de plus, hors de tout deck : elle doit y etre.
	var rare: SpellCard = _sorts(GameEnums.Rarity.LEGENDARY)[0]
	SaveData.discover_card(rare.id)
	var obtenues: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if SaveData.is_discovered(c.id) and not c.is_passive:
			obtenues.append(c)
	var pool: Array[SpellCard] = RunState.levelup_pool(lv, hors)
	eq(_ids(pool), _ids(obtenues),
		"hors campagne : exactement les cartes obtenues (sans passif avant l acte 2)")
	ok(pool.has(rare), "une carte obtenue ailleurs est proposable hors campagne")


## Toutes les offres tirent dans le pool du niveau en cours : aucune carte
## d ailleurs, meme sur beaucoup de tirages.
func _test_toute_offre_vient_du_pool() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau(1)
	RunState.reset()
	RunState.current_level_def = lv
	RunState.mode = GameEnums.Mode.EXPLORATION
	var pool: Array[SpellCard] = RunState.levelup_pool(lv, GameEnums.Mode.EXPLORATION)
	var hors_pool: int = 0
	var vues: Dictionary = {}
	for essai in TIRAGES:
		RunState.set_seed(7000 + essai)
		for c in RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES):
			vues[c.id] = true
			if not pool.has(c):
				hors_pool += 1
		RunState.pending_offer.clear()
	eq(hors_pool, 0, "aucune carte offerte hors du pool de montee de niveau")
	# Tout ce qui n est pas commun finit par sortir. Les COMMUNES du deck ne
	# sortent qu en REPLI : la table des sorts (80/15/5, DEC-004) ne tire jamais
	# la commune. Choix assume et signale, voir run_state.gd.
	for c2 in pool:
		if c2.rarity != GameEnums.Rarity.COMMON:
			ok(vues.has(c2.id), "%s, carte du pool, finit par etre proposee" % c2.id)
	# Un pool sans rien au-dessus de la commune (un niveau sans contenu de
	# progression) propose bien ses communes : le repli les atteint toutes.
	var maigre: LevelDef = _niveau(1)
	var vide: Array[SpellCard] = []
	maigre.levelup_cards = vide
	maigre.objective_rewards = vide.duplicate()
	RunState.current_level_def = maigre
	var communes: Dictionary = {}
	for essai2 in TIRAGES:
		RunState.set_seed(7500 + essai2)
		for c3 in RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES):
			communes[c3.id] = true
		RunState.pending_offer.clear()
	eq(communes.size(), _ids(maigre.exploration_deck).size(),
		"un pool de communes seules est propose en entier")
	RunState.reset()
	RunState.current_level_def = null


# --- C. Obtention --------------------------------------------------------

func _test_premiere_prise_obtient_bruler_non() -> void:
	SaveData.reset_profile()
	RunState.reset()
	var cibles: Array[SpellCard] = _sorts(GameEnums.Rarity.EPIC)
	var prise: SpellCard = cibles[0]
	var brulee: SpellCard = cibles[1]
	not_ok(SaveData.is_discovered(prise.id), "profil neuf : la carte n est pas obtenue")
	RunState.pending_offer = [prise, brulee]
	RunState.pick_offer(0)
	ok(SaveData.is_discovered(prise.id), "la PREMIERE prise en combat l obtient")
	RunState.pending_offer = [prise, brulee]
	RunState.burn_offer(1)
	RunState.take_burned()
	not_ok(SaveData.is_discovered(brulee.id), "une carte BRULEE n est pas obtenue")
	# Arriver dans la defausse par un autre chemin n obtient rien non plus.
	var autre: SpellCard = cibles[cibles.size() - 1]
	RunState.add_card_to_discard(autre)
	not_ok(SaveData.is_discovered(autre.id),
		"seul le geste de prendre obtient, pas le passage par la defausse")
	# Un passif choisi est obtenu meme si l echange est refuse ensuite.
	var p: Array[SpellCard] = _passifs()
	for i in GameConfig.PASSIVE_SLOTS:
		RunState.equip_passive(p[i])
	var quatrieme: SpellCard = p[GameConfig.PASSIVE_SLOTS]
	RunState.pending_offer = [quatrieme]
	RunState.pick_offer(0)
	RunState.decline_pending_passive()
	ok(SaveData.is_discovered(quatrieme.id),
		"un passif choisi est obtenu, meme sans place pour l equiper")
	RunState.reset()


# --- D. Visibilite ---------------------------------------------------------

func _test_visibilite_trois_etats() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(SaveData.is_level_unlocked(&"lvl_01"), "le premier niveau est ouvert")
	# OBTENABLE : dans le deck d un niveau ouvert, jamais obtenue.
	var obtenable: SpellCard = null
	for c: SpellCard in lvl1.exploration_deck:
		if c != null and not SaveData.is_discovered(c.id):
			obtenable = c
			break
	ok(obtenable != null, "le deck du premier niveau a une carte pas encore obtenue")
	if obtenable != null:
		eq(SaveData.card_visibility(obtenable.id), SaveData.CARD_OBTAINABLE,
			"une carte du pool d un niveau ouvert, jamais prise, est OBTENABLE")
	# INVISIBLE : dans aucun pool de niveau ouvert. On la prend de preference
	# hors de TOUT pool de campagne : la victoire enregistree plus bas ouvre le
	# niveau suivant, qui ne doit pas la rendre obtenable a la place de
	# l objectif (le test passerait alors pour une mauvaise raison).
	var pool: Dictionary = SaveData.obtainable_ids()
	var partout: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for c0 in RunState.levelup_pool(lv, GameEnums.Mode.EXPLORATION):
			partout[c0.id] = true
	var cachee: SpellCard = null
	for c2: SpellCard in _sorts(GameEnums.Rarity.RARE):
		if not pool.has(c2.id) and not SaveData.is_discovered(c2.id):
			if cachee == null or not partout.has(c2.id):
				cachee = c2
			if not partout.has(c2.id):
				break
	ok(cachee != null, "une rare n est dans aucun pool ouvert")
	if cachee == null:
		return
	eq(SaveData.card_visibility(cachee.id), SaveData.CARD_HIDDEN,
		"hors de tout pool ouvert, jamais prise : INVISIBLE")
	# Un objectif reussi la rend OBTENABLE, la prendre la rend OBTENUE.
	var avant: Array[SpellCard] = lvl1.objective_rewards.duplicate()
	var rec: Array[SpellCard] = [cachee]
	lvl1.objective_rewards = rec
	eq(SaveData.card_visibility(cachee.id), SaveData.CARD_HIDDEN,
		"tant que son objectif n est pas reussi, elle reste invisible")
	SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{lvl1.objectives[0].id: true}, 1)
	eq(SaveData.card_visibility(cachee.id), SaveData.CARD_OBTAINABLE,
		"objectif reussi : sa carte devient OBTENABLE (lisible, grisee)")
	var niveaux: Array[LevelDef] = SaveData.levels_offering(cachee.id)
	ok(niveaux.has(lvl1), "et le jeu sait dire OU l obtenir")
	RunState.reset()
	RunState.pending_offer = [cachee]
	RunState.pick_offer(0)
	eq(SaveData.card_visibility(cachee.id), SaveData.CARD_OBTAINED,
		"prise en combat : OBTENUE")
	lvl1.objective_rewards = avant
	RunState.reset()


func _test_le_grimoire_et_le_deck_cachent_l_invisible() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var sorts: Array = GalleryPanel.entries_of(GalleryPanel.Section.SPELLS)
	var catalogue: Array = GalleryPanel.catalog_of(GalleryPanel.Section.SPELLS)
	ok(sorts.size() < catalogue.size(),
		"profil neuf : le grimoire ne montre pas tout le catalogue (%d / %d)"
		% [sorts.size(), catalogue.size()])
	var vu_obtenable: bool = false
	for c: SpellCard in catalogue:
		var etat: int = SaveData.card_visibility(c.id)
		eq(sorts.has(c), etat != SaveData.CARD_HIDDEN,
			"%s : affichee au grimoire si et seulement si visible" % c.id)
		if etat == SaveData.CARD_OBTAINABLE:
			vu_obtenable = true
			ok(GalleryPanel.is_obtainable(c), "%s est grisee au grimoire" % c.id)
			not_ok(GalleryPanel.is_known(c), "%s n y est pas comptee obtenue" % c.id)
	ok(vu_obtenable, "un profil neuf a deja des cartes a obtenir")
	# Le compteur : obtenues sur TOUT le catalogue, et le nombre a obtenir.
	var obtenues: int = 0
	for c3: SpellCard in catalogue:
		if SaveData.is_discovered(c3.id):
			obtenues += 1
	ok(GalleryPanel.header_text(GalleryPanel.Section.SPELLS).begins_with(
		"%d / %d" % [obtenues, catalogue.size()]),
		"le compteur dit obtenues / catalogue : %s"
		% GalleryPanel.header_text(GalleryPanel.Section.SPELLS))
	# L ecran de deck applique la meme regle a sa collection.
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	for c2: SpellCard in panel.collection():
		ok(SaveData.card_visibility(c2.id) != SaveData.CARD_HIDDEN,
			"la collection du deck ne montre pas %s, invisible" % c2.id)
		if not SaveData.is_discovered(c2.id):
			ok(panel.refusal_for(c2) != "", "%s grisee ne s ajoute pas au deck" % c2.id)
	detach(panel)


# --- B. Migration et recompenses --------------------------------------------

func _test_migration_d_un_ancien_profil() -> void:
	var legendaire: SpellCard = _sorts(GameEnums.Rarity.LEGENDARY)[0]
	var commune: SpellCard = _sorts(GameEnums.Rarity.COMMON)[0]
	# Un profil d avant le chantier P : la legendaire "3/3" est dans la liste a
	# part, PAS dans discovered_cards (cas d un profil edite ou tres ancien).
	SaveData.load_from_dictionary({
		"schema_version": 1,
		"profile": {
			"discovered_cards": [String(commune.id)],
			"unlocked_legendaries": [String(legendaire.id)],
		},
	})
	ok(SaveData.is_discovered(commune.id), "une carte deja decouverte reste obtenue")
	ok(SaveData.is_discovered(legendaire.id),
		"la legendaire gagnee par les 3 objectifs reste obtenue")
	ok(SaveData.unlocked_legendaries().has(String(legendaire.id)),
		"et comptee parmi les legendaires obtenues")
	eq(SaveData.card_visibility(legendaire.id), SaveData.CARD_OBTAINED,
		"elle est lisible et utilisable au deck")
	# Relire le profil ecrit ne perd rien non plus (migration idempotente).
	var ecrit: Dictionary = SaveData.to_dictionary()
	SaveData.load_from_dictionary(ecrit)
	ok(SaveData.is_discovered(legendaire.id), "la migration relue ne retire rien")
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _test_rang_et_rarete_des_recompenses() -> void:
	var lv: LevelDef = _niveau(1)
	eq(lv.progression_errors().size(), 0, "le niveau synthetique est conforme")
	eq(lv.missing_progression().size(), 0, "et complet")
	eq(LevelDef.objective_rank(0), 1, "le premier objectif est de rang 1")
	var raretes: Array = []
	for rang in range(1, LevelDef.REWARD_RARITY_BY_RANK.size() + 1):
		raretes.append(LevelDef.reward_rarity_for_rank(rang))
	eq(raretes, [GameEnums.Rarity.RARE, GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY],
		"objectif 1 = rare, 2 = epique, 3 = legendaire")
	# Echanger deux recompenses casse la rarete par rang : l AUDIT le refuse.
	var inverse: Array[SpellCard] = [lv.objective_rewards[2], lv.objective_rewards[1],
		lv.objective_rewards[0]]
	lv.objective_rewards = inverse
	ok(lv.progression_errors().size() > 0, "une recompense de mauvaise rarete est une erreur")
	# Une carte nouvelle deja dans le deck n est pas nouvelle.
	var lv2: LevelDef = _niveau(1)
	var doublon: Array[SpellCard] = [lv2.exploration_deck[0]]
	lv2.levelup_cards = doublon
	ok(lv2.progression_errors().size() > 0, "une carte nouvelle deja au deck est une erreur")
	ok(lv2.missing_progression().size() > 0, "et il en manque, ce qui est signale")
	# Un passif dans un niveau d acte 1 : interdit.
	var lv3: LevelDef = _niveau(1)
	var pas: Array[SpellCard] = [_passifs()[0]]
	lv3.levelup_cards = pas
	ok(lv3.progression_errors().size() > 0, "un passif avant l acte 2 est une erreur")


## Le contenu n est pas encore ecrit : un niveau sans cartes nouvelles ni
## recompense doit tourner, son pool se reduisant a son deck.
func _test_niveau_sans_contenu_de_progression() -> void:
	SaveData.reset_profile()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var avant_cartes: Array[SpellCard] = lvl1.levelup_cards.duplicate()
	var avant_rec: Array[SpellCard] = lvl1.objective_rewards.duplicate()
	var vide: Array[SpellCard] = []
	lvl1.levelup_cards = vide
	lvl1.objective_rewards = vide.duplicate()
	var faits: Dictionary = {}
	for o in lvl1.objectives:
		faits[o.id] = true
	not_ok(SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION, faits, 1),
		"trois objectifs sans recompense ecrite : rien de debloque, rien ne plante")
	var pool: Array[SpellCard] = RunState.levelup_pool(lvl1, GameEnums.Mode.EXPLORATION)
	eq(_ids(pool), _ids(lvl1.exploration_deck), "le pool se reduit au deck du niveau")
	eq(CampaignPanel.objective_reward_line(lvl1, 0).strip_edges().is_empty(), false,
		"la fiche de campagne ecrit quand meme une ligne pour l objectif")
	lvl1.levelup_cards = avant_cartes
	lvl1.objective_rewards = avant_rec
	SaveData.reset_profile()
	ContentDB.discover_starters()


# --- E. Passifs --------------------------------------------------------------

func _test_passifs_rien_avant_l_acte_2() -> void:
	SaveData.reset_profile()
	var acte1: LevelDef = _niveau(LevelDef.PASSIVES_FROM_ACT - 1)
	var acte2: LevelDef = _niveau(LevelDef.PASSIVES_FROM_ACT)
	not_ok(RunState.passives_allowed(acte1, GameEnums.Mode.EXPLORATION),
		"campagne, acte 1 : pas de passif")
	ok(RunState.passives_allowed(acte2, GameEnums.Mode.EXPLORATION),
		"campagne, acte 2 : les passifs existent")
	for c in RunState.levelup_pool(acte1, GameEnums.Mode.EXPLORATION):
		not_ok(c.is_passive, "aucun passif dans le pool d un niveau d acte 1 (%s)" % c.id)
	var passifs_acte2: int = 0
	for c2 in RunState.levelup_pool(acte2, GameEnums.Mode.EXPLORATION):
		if c2.is_passive:
			passifs_acte2 += 1
	eq(passifs_acte2, _passifs().size(), "acte 2 : tous les passifs sont proposables")
	# Ni propose...
	RunState.reset()
	RunState.current_level_def = acte1
	RunState.mode = GameEnums.Mode.EXPLORATION
	var vus: int = 0
	for essai in TIRAGES:
		RunState.set_seed(3100 + essai)
		for c3 in RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES):
			if c3.is_passive:
				vus += 1
		RunState.pending_offer.clear()
	eq(vus, 0, "acte 1 : aucun passif propose en %d montees de niveau" % TIRAGES)
	# ... ni equipe au depart, meme si le profil en a equipe.
	var p: SpellCard = _passifs()[0]
	SaveData.discover_card(p.id)
	SaveData.set_equipped_passives([p.id])
	RunState.reset()
	RunState.current_level_def = acte1
	eq(RunState.equip_saved_passives(), 0, "acte 1 : aucun passif active au depart")
	eq(RunState.equipped_passives.size(), 0, "la barre reste vide")
	RunState.reset()
	RunState.current_level_def = acte2
	eq(RunState.equip_saved_passives(), 1, "acte 2 : le passif equipe est active")
	RunState.reset()
	RunState.current_level_def = null
	SaveData.reset_profile()


func _test_passifs_hors_campagne_selon_l_acte_atteint() -> void:
	SaveData.reset_profile()
	var hors: GameEnums.Mode = _mode_hors_campagne()
	var acte1: LevelDef = _niveau(1)
	not_ok(SaveData.passives_unlocked(), "profil neuf : l acte 2 n est pas atteint")
	not_ok(RunState.passives_allowed(acte1, hors),
		"mode infini avant l acte 2 : pas de passif")
	var p: SpellCard = _passifs()[0]
	SaveData.discover_card(p.id)
	not_ok(RunState.levelup_pool(acte1, hors).has(p),
		"meme obtenu, un passif n est pas proposable avant l acte 2")
	var ouvert: LevelDef = null
	for lv: LevelDef in ContentDB.levels.values():
		if lv.allows_passives():
			ouvert = lv
			break
	ok(ouvert != null, "le contenu a un niveau d acte 2 ou plus")
	if ouvert == null:
		return
	SaveData.unlock_level(ouvert.id)
	ok(SaveData.passives_unlocked(), "un niveau d acte 2 OUVERT suffit")
	ok(RunState.passives_allowed(acte1, hors),
		"mode infini, acte 2 atteint : les passifs existent, meme sur un niveau d acte 1")
	ok(RunState.levelup_pool(acte1, hors).has(p), "et un passif obtenu y est proposable")
	not_ok(RunState.passives_allowed(acte1, GameEnums.Mode.EXPLORATION),
		"mais en campagne, un niveau d acte 1 reste sans passif")
	SaveData.reset_profile()


func _test_passifs_equipes_actifs_au_depart() -> void:
	SaveData.reset_profile()
	var acte2: LevelDef = null
	var acte1: LevelDef = null
	for lv: LevelDef in ContentDB.levels.values():
		if acte2 == null and lv.allows_passives():
			acte2 = lv
		if acte1 == null and lv.act >= 1 and not lv.allows_passives():
			acte1 = lv
	ok(acte2 != null and acte1 != null, "le contenu a des niveaux des deux cotes de l acte 2")
	if acte2 == null or acte1 == null:
		return
	var p: Array[SpellCard] = _passifs()
	var voulus: Array = []
	for i in DeckRules.MAX_PASSIVES:
		SaveData.discover_card(p[i].id)
		voulus.append(String(p[i].id))
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	# Trois passifs obtenus et equipes : les trois sont actifs DES LE DEPART.
	SaveData.set_equipped_passives(voulus)
	g.start_level(acte2, GameEnums.Mode.EXPLORATION)
	g.running = false
	eq(_ids_de(RunState.equipped_passives), voulus,
		"acte 2 : les passifs equipes au deck sont actifs DES LE DEPART, dans l ordre")
	# Rejouer ne les empile pas (reset puis re-equipement).
	g.start_level(acte2, GameEnums.Mode.EXPLORATION)
	g.running = false
	eq(RunState.equipped_passives.size(), voulus.size(), "rejouer ne double pas les passifs")
	# Un passif NON obtenu glisse dans la liste (profil edite) ne s equipe pas,
	# et ne prend pas la place des autres.
	var intrus: SpellCard = p[DeckRules.MAX_PASSIVES]
	SaveData.set_equipped_passives([voulus[0], String(intrus.id), voulus[1]])
	g.start_level(acte2, GameEnums.Mode.EXPLORATION)
	g.running = false
	eq(_ids_de(RunState.equipped_passives), [voulus[0], voulus[1]],
		"un passif non obtenu n est jamais active")
	SaveData.set_equipped_passives(voulus)
	g.start_level(acte1, GameEnums.Mode.EXPLORATION)
	g.running = false
	eq(RunState.equipped_passives.size(), 0, "acte 1 : le meme profil part sans passif")
	detach(g)
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	reset_gauge_at_normal_speed()
	SaveData.reset_profile()


## Le defaut corrige : les passifs COMMUNS n etaient jamais proposes.
func _test_passifs_communs_proposables() -> void:
	var communs: int = 0
	for c in _passifs():
		if c.rarity == GameEnums.Rarity.COMMON:
			communs += 1
	ok(communs > 0, "le catalogue a des passifs communs")
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION
	var vus: int = 0
	for essai in TIRAGES:
		RunState.set_seed(4200 + essai)
		for c2 in RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES):
			if c2.is_passive and c2.rarity == GameEnums.Rarity.COMMON:
				vus += 1
		RunState.pending_offer.clear()
	ok(vus > 0, "un passif commun est propose au moins une fois (%d)" % vus)
	var total: float = 0.0
	for r in RunState.PASSIVE_RARITY_WEIGHTS:
		total += float(RunState.PASSIVE_RARITY_WEIGHTS[r])
	feq(total, 1.0, "la table des passifs somme a 1")
	ok(float(RunState.PASSIVE_RARITY_WEIGHTS.get(GameEnums.Rarity.COMMON, 0.0)) > 0.0,
		"la table des passifs connait la commune")
	RunState.reset()


func _test_ecran_de_deck_equipe_les_passifs() -> void:
	# Logique pure des emplacements.
	eq(DeckPanel.passives_with([], 0, &"a"), ["a"], "premier emplacement")
	eq(DeckPanel.passives_with(["a", "b"], 1, &"c"), ["a", "c"], "remplacer l emplacement 2")
	eq(DeckPanel.passives_with(["a", "b"], 0, &"b"), ["b"],
		"un passif deja equipe change de place au lieu d etre en double")
	var plein: Array = []
	for i in DeckRules.MAX_PASSIVES:
		plein.append("p%d" % i)
	eq(DeckPanel.passives_with(plein, DeckRules.MAX_PASSIVES, &"z").size(),
		DeckRules.MAX_PASSIVES, "jamais plus de trois emplacements")

	SaveData.reset_profile()
	ContentDB.discover_starters()
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	var p: Array[SpellCard] = _passifs()
	SaveData.discover_card(p[0].id)
	not_ok(panel.equip_passive_in_slot(0, p[0]), "avant l acte 2, l ecran n equipe rien")
	panel.open_passive_picker(0)
	eq(panel.picker_slot(), -1, "et n ouvre pas le choix")
	for lv: LevelDef in ContentDB.levels.values():
		if lv.allows_passives():
			SaveData.unlock_level(lv.id)
			break
	not_ok(panel.equip_passive_in_slot(0, p[1]), "un passif non obtenu ne s equipe pas")
	not_ok(panel.equip_passive_in_slot(0, _sorts()[0]), "un sort ne s equipe pas en passif")
	panel.open_passive_picker(0)
	eq(panel.picker_slot(), 0, "le choix de l emplacement 1 s ouvre")
	ok(panel.passive_choices().has(p[0]), "le passif obtenu est proposable")
	not_ok(panel.passive_choices().has(p[1]), "le passif non obtenu ne l est pas")
	ok(panel.equip_passive_in_slot(0, p[0]), "on l equipe")
	eq(panel.picker_slot(), -1, "le choix se referme")
	eq(SaveData.equipped_passives(), [String(p[0].id)], "le profil le retient")
	panel.clear_passive_slot(0)
	eq(SaveData.equipped_passives().size(), 0, "RETIRER vide l emplacement")
	detach(panel)
	SaveData.reset_profile()
	ContentDB.discover_starters()
