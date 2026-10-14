extends TestCase
## LE DECK DE CAMPAGNE QUI EVOLUE (vague 10, chantier A3, regle du co-auteur du
## 14/10) : 3 communes de base (la premiere est la NOUVELLE du niveau), et chaque
## objectif reussi (rang 1 rare, 2 epique, 3 legendaire) change le deck selon SA
## table. Ce test verrouille LevelDef.campaign_deck pour les HUIT combinaisons.
##
## La table est ecrite ICI dans la notation du co-auteur (2e commune, 3e commune,
## nouvelle ; puis R, E, L) et pas relue dans LevelDef.CAMPAIGN_DECK_TABLE : un
## test qui relirait la constante qu il contraint passerait quelle que soit la
## table (voir les gotchas du projet). C est une REGLE du co-auteur, pas un
## reglage d equilibrage : elle s ecrit en dur.
##
## E+L n est pas dans la table du co-auteur : la regle deduite (3/3/3 + E x2 +
## L x1) est documentee dans level_def.gd et verrouillee ici comme les autres.

func get_suite_name() -> String:
	return "campaign_deck"


## [rangs reussis, 2e, 3e, nouvelle, R, E, L] — mot pour mot la table du 14/10.
const TABLE_DU_CO_AUTEUR: Array = [
	[[], 4, 4, 4, 0, 0, 0],
	[[1], 3, 3, 3, 3, 0, 0],
	[[2], 3, 3, 4, 0, 2, 0],
	[[3], 4, 4, 3, 0, 0, 1],
	[[1, 2], 2, 2, 3, 3, 2, 0],
	[[1, 3], 2, 3, 3, 3, 0, 1],
	[[2, 3], 3, 3, 3, 0, 2, 1],
	[[1, 2, 3], 2, 2, 3, 2, 2, 1],
]


func run() -> void:
	SaveData.reset_profile()
	_test_les_huit_combinaisons()
	_test_chaque_deck_est_jouable()
	_test_rangs_dans_le_desordre_ou_hors_bornes()
	_test_recompense_absente_ou_passive()
	_test_repli_sans_communes_de_base()
	_test_contenu_de_base_mal_forme()
	_test_le_profil_regle_le_deck()
	_test_la_partie_et_le_briefing_lisent_le_meme_deck()
	_test_une_recompense_au_deck_est_dans_le_livre()
	_test_la_fiche_montre_le_deck()
	SaveData.reset_profile()
	RunState.reset()


# --- Outils ------------------------------------------------------------------

func _cartes(rarete: int, n: int) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var toutes: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.rarity == rarete:
			toutes.append(c)
	toutes.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	for i in mini(n, toutes.size()):
		out.append(toutes[i])
	return out


func _objectif(id: String) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName(id)
	o.check_key = &"no_damage_taken"
	return o


## Un niveau de la vague 10 : trois communes de base, trois objectifs, une
## recompense rare / epique / legendaire.
func _niveau(id: String = "test_deck_v10") -> LevelDef:
	var lv := LevelDef.new()
	lv.id = StringName(id)
	lv.act = 1
	lv.base_commons = _cartes(GameEnums.Rarity.COMMON, LevelDef.BASE_COMMONS_COUNT)
	lv.objectives = [_objectif(id + "_a"), _objectif(id + "_b"), _objectif(id + "_c")]
	var rec: Array[SpellCard] = []
	for rang in range(1, lv.objectives.size() + 1):
		rec.append(_cartes(LevelDef.reward_rarity_for_rank(rang), 1)[0])
	lv.objective_rewards = rec
	return lv


func _compte(deck: Array, c: SpellCard) -> int:
	var n: int = 0
	for x in deck:
		if x == c:
			n += 1
	return n


func _ids(deck: Array) -> Array:
	var out: Array = []
	for c in deck:
		out.append(String((c as SpellCard).id))
	return out


# --- Les huit cas --------------------------------------------------------------

func _test_les_huit_combinaisons() -> void:
	var lv: LevelDef = _niveau()
	ok(lv.has_base_commons(), "le niveau de test a son deck de base")
	eq(lv.new_common(), lv.base_commons[0], "la nouvelle commune est la premiere de la liste")
	var vus: Dictionary = {}
	for ligne: Array in TABLE_DU_CO_AUTEUR:
		var rangs: Array = ligne[0]
		var deck: Array[SpellCard] = lv.campaign_deck(rangs)
		var nom: String = "objectifs %s" % str(rangs)
		eq(_compte(deck, lv.base_commons[1]), int(ligne[1]), "%s : 2e commune" % nom)
		eq(_compte(deck, lv.base_commons[2]), int(ligne[2]), "%s : 3e commune" % nom)
		eq(_compte(deck, lv.base_commons[0]), int(ligne[3]), "%s : la NOUVELLE commune" % nom)
		eq(_compte(deck, lv.objective_reward(0)), int(ligne[4]), "%s : la rare" % nom)
		eq(_compte(deck, lv.objective_reward(1)), int(ligne[5]), "%s : l epique" % nom)
		eq(_compte(deck, lv.objective_reward(2)), int(ligne[6]), "%s : la legendaire" % nom)
		eq(deck.size(), DeckRules.DECK_SIZE, "%s : un deck complet" % nom)
		vus[lv.campaign_deck_mask(rangs)] = true
	eq(vus.size(), TABLE_DU_CO_AUTEUR.size(), "les huit combinaisons sont huit cas distincts")


## Chaque deck de la table passe les regles du deck (taille, 6 ids au plus,
## exemplaires par rarete) : la table ne doit jamais fabriquer un deck que
## l ecran de deck refuserait.
func _test_chaque_deck_est_jouable() -> void:
	var lv: LevelDef = _niveau()
	for ligne: Array in TABLE_DU_CO_AUTEUR:
		var ids: Array = _ids(lv.campaign_deck(ligne[0]))
		eq(DeckRules.validation_message(ids), "", "objectifs %s : deck valide" % str(ligne[0]))
		ok(DeckRules.count_distinct(ids) <= DeckRules.MAX_DISTINCT,
			"objectifs %s : %d ids" % [str(ligne[0]), DeckRules.count_distinct(ids)])
	eq(lv.structure_errors().size(), 0, "le niveau de test est conforme (%s)" % str(lv.structure_errors()))


func _test_rangs_dans_le_desordre_ou_hors_bornes() -> void:
	var lv: LevelDef = _niveau()
	eq(_ids(lv.campaign_deck([3, 1])), _ids(lv.campaign_deck([1, 3])),
		"l ordre des rangs ne compte pas")
	eq(_ids(lv.campaign_deck([1, 1, 3, 3])), _ids(lv.campaign_deck([1, 3])),
		"un rang en double ne compte qu une fois")
	eq(_ids(lv.campaign_deck([0, 4, -1])), _ids(lv.campaign_deck([])),
		"un rang hors bornes est ignore")


## Un objectif sans carte (case vide) ou dont la carte est un passif (qui ne se
## pioche pas) ne change pas le deck : sinon la table retirerait des communes
## pour une carte absente et le deck tomberait sous sa taille.
func _test_recompense_absente_ou_passive() -> void:
	var lv: LevelDef = _niveau()
	var rec: Array[SpellCard] = [lv.objective_reward(0), null, lv.objective_reward(2)]
	lv.objective_rewards = rec
	eq(_ids(lv.campaign_deck([2])), _ids(lv.campaign_deck([])),
		"objectif 2 sans carte : le deck reste celui sans objectif")
	eq(_ids(lv.campaign_deck([1, 2])), _ids(lv.campaign_deck([1])),
		"objectifs 1 et 2, le 2 sans carte : le deck du seul objectif 1")
	var passif: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			passif = c
			break
	var rec2: Array[SpellCard] = [passif, lv.objective_reward(1), lv.objective_reward(2)]
	lv.objective_rewards = rec2
	eq(_ids(lv.campaign_deck([1])), _ids(lv.campaign_deck([])),
		"une recompense PASSIVE n entre pas au deck")
	eq(lv.campaign_deck([1, 2, 3]).size(), DeckRules.DECK_SIZE,
		"et le deck garde sa taille")


## REPLI : sans deck de base, c est exploration_deck (passifs exclus), et les
## objectifs n y changent rien.
func _test_repli_sans_communes_de_base() -> void:
	var lv: LevelDef = _niveau()
	var vide: Array[SpellCard] = []
	lv.base_commons = vide
	var passif: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			passif = c
			break
	var expl: Array[SpellCard] = _cartes(GameEnums.Rarity.COMMON, 2)
	expl.append(passif)
	lv.exploration_deck = expl
	not_ok(lv.has_base_commons(), "sans communes de base")
	eq(_ids(lv.campaign_deck([])), _ids(_cartes(GameEnums.Rarity.COMMON, 2)),
		"repli : le deck d exploration, passif retire")
	eq(_ids(lv.campaign_deck([1, 2, 3])), _ids(lv.campaign_deck([])),
		"repli : les objectifs ne changent pas le deck")
	eq(lv.new_common(), null, "repli : pas de commune nouvelle")
	eq(_ids(lv.campaign_base_cards()), _ids(lv.campaign_deck([])),
		"le deck de base est le deck sans objectif")
	# Le contenu LIVRE au 14/10 n a pas encore de communes de base : chaque
	# niveau de campagne joue donc exactement son exploration_deck.
	for lv2: LevelDef in ContentDB.campaign_levels():
		if lv2.has_base_commons():
			continue
		var attendu: Array = []
		for c2: SpellCard in lv2.exploration_deck:
			if c2 != null and not c2.is_passive:
				attendu.append(String(c2.id))
		eq(_ids(lv2.campaign_deck([1, 2, 3])), attendu,
			"%s (repli) : deck de campagne = exploration_deck" % lv2.id)


func _test_contenu_de_base_mal_forme() -> void:
	var deux: LevelDef = _niveau()
	var c2: Array[SpellCard] = _cartes(GameEnums.Rarity.COMMON, 2)
	deux.base_commons = c2
	not_ok(deux.has_base_commons(), "deux communes : pas un deck de base")
	ok(deux.structure_errors().size() > 0, "et l AUDIT le refuse")
	var double: LevelDef = _niveau()
	var c3: Array[SpellCard] = _cartes(GameEnums.Rarity.COMMON, 2)
	c3.append(c3[0])
	double.base_commons = c3
	ok(double.structure_errors().size() > 0, "une commune en double au deck de base est refusee")
	var rare: LevelDef = _niveau()
	var c4: Array[SpellCard] = _cartes(GameEnums.Rarity.COMMON, 2)
	c4.append(_cartes(GameEnums.Rarity.RARE, 1)[0])
	rare.base_commons = c4
	ok(rare.structure_errors().size() > 0, "une rare au deck de base est refusee")
	ok(rare.progression_errors().size() > 0, "progression_errors la remonte (AUDIT)")


# --- Le profil, la partie, le livre ---------------------------------------------

## SaveData.campaign_deck lit les objectifs REUSSIS du profil.
func _test_le_profil_regle_le_deck() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau("test_deck_profil")
	eq(_ids(SaveData.campaign_deck(lv)), _ids(lv.campaign_deck([])),
		"profil neuf : le deck sans objectif")
	SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {lv.objectives[1].id: true}, 1)
	eq(SaveData.achieved_ranks(lv), [2] as Array[int], "l objectif de rang 2 est acquis")
	eq(_ids(SaveData.campaign_deck(lv)), _ids(lv.campaign_deck([2])),
		"rang 2 reussi : le deck de la ligne E")
	# Un objectif reussi en LIBRE compte aussi : c est l objectif, pas le mode.
	SaveData.record_victory(lv, GameEnums.Mode.FREE, {lv.objectives[2].id: true}, 1)
	eq(_ids(SaveData.campaign_deck(lv)), _ids(lv.campaign_deck([2, 3])),
		"rang 3 reussi en Libre : le deck de la ligne E+L")
	SaveData.reset_profile()


func _test_la_partie_et_le_briefing_lisent_le_meme_deck() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau("test_deck_partie")
	SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {lv.objectives[0].id: true}, 1)
	var attendu: Array = _ids(SaveData.campaign_deck(lv))
	attendu.sort()
	var briefing: Array = _ids(GameController.run_deck(lv, GameEnums.Mode.EXPLORATION))
	briefing.sort()
	eq(briefing, attendu, "run_deck rend le deck de campagne du profil")
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(lv, GameEnums.Mode.EXPLORATION)
	g.running = false
	var distribue: Array = _ids(RunState.deck + RunState.hand + RunState.discard)
	distribue.sort()
	eq(distribue, attendu, "la partie distribue exactement ce deck")
	detach(g)
	RunState.reset()
	SaveData.reset_profile()


## « Les cartes de notre deck sont directement dans le livre » : une recompense
## qui ENTRE au deck de campagne d un niveau OUVERT est obtenue. Un niveau de
## repli garde l ancienne regle (la carte est a prendre en combat).
func _test_une_recompense_au_deck_est_dans_le_livre() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau("test_deck_livre")
	ContentDB.levels[lv.id] = lv
	SaveData.unlock_level(lv.id)
	var rare: SpellCard = lv.objective_reward(0)
	var deja: bool = SaveData.is_discovered(rare.id)
	not_ok(deja, "la rare du test n est pas obtenue d avance")
	for c: SpellCard in lv.base_commons:
		ok(SaveData.is_discovered(c.id), "commune de base d un niveau ouvert : obtenue (%s)" % c.id)
	SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {lv.objectives[0].id: true}, 1)
	ok(SaveData.is_discovered(rare.id), "objectif reussi : sa carte entre au deck, donc au livre")
	eq(SaveData.card_visibility(rare.id), SaveData.CARD_OBTAINED, "elle est OBTENUE")
	# Le meme niveau en REPLI : la carte reste a prendre.
	var vide: Array[SpellCard] = []
	lv.base_commons = vide
	lv.exploration_deck = _cartes(GameEnums.Rarity.COMMON, 2)
	not_ok(SaveData.is_discovered(rare.id), "niveau de repli : la recompense n est pas donnee")
	eq(SaveData.card_visibility(rare.id), SaveData.CARD_OBTAINABLE,
		"elle est OBTENABLE (pool de montee de niveau du niveau)")
	ContentDB.levels.erase(lv.id)
	SaveData.reset_profile()


func _test_la_fiche_montre_le_deck() -> void:
	SaveData.reset_profile()
	var lv: LevelDef = _niveau("test_deck_fiche")
	lv.display_name = "Niveau du deck"
	ContentDB.levels[lv.id] = lv
	SaveData.unlock_level(lv.id)
	SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {lv.objectives[0].id: true}, 1)
	var p := CampaignPanel.new()
	attach(p)
	p.open_level(lv.id)
	p.select_mode(GameEnums.Mode.EXPLORATION)
	var textes: Array[String] = p.detail_texts()
	var lignes: Array = CampaignPanel.campaign_deck_lines(lv)
	eq(lignes.size(), DeckRules.count_distinct(_ids(SaveData.campaign_deck(lv))),
		"une ligne par carte distincte du deck")
	for ligne: Array in lignes:
		ok(textes.has(String(ligne[0])), "la fiche affiche « %s »" % ligne[0])
	var nouvelle: String = "%s x%d (nouvelle)" % [lv.base_commons[0].display_name,
		_compte(SaveData.campaign_deck(lv), lv.base_commons[0])]
	ok(textes.has(nouvelle), "la commune nouvelle est nommee comme telle (%s)" % nouvelle)
	ok(p.hint_text().contains(str(SaveData.campaign_deck(lv).size())),
		"l aide de la campagne dit la taille du deck de campagne (%s)" % p.hint_text())
	# En Libre, le deck de campagne n est PAS montre : le joueur joue le sien.
	SaveData.set_massacre_deck(DeckRules.default_deck_ids())
	p.select_mode(GameEnums.Mode.FREE)
	not_ok(p.detail_texts().has(nouvelle), "en Libre, la fiche ne montre pas le deck de campagne")
	detach(p)
	ContentDB.levels.erase(lv.id)
	SaveData.reset_profile()
