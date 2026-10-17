extends TestCase
## LA NOUVELLE STRUCTURE DE PROGRESSION (vague 10, chantier A3, regles du
## co-auteur du 14/10), hors deck de campagne (voir test_campaign_deck) :
##   - le POOL DE MONTEE DE NIVEAU = toutes les cartes OBTENUES + toutes les
##     communes de l ACTE (des le niveau 1), avec le repli documente tant que le
##     contenu n a pas de deck de base ;
##   - les PASSIFS : six de base des l acte 2, puis ceux que la victoire d un
##     niveau debloque (LevelDef.passive_unlocks) ; seuls les debloques entrent
##     au pool et a l ecran de deck (repli : tous, tant que le contenu n en ecrit
##     aucun) ;
##   - les QUETES ANNEXES : hors campaign_progress, ouvertes par une condition,
##     rattachees a un acte, sur leur PAGE de la carte. Un niveau annexe FACTICE
##     est fabrique ici, et seulement ici ;
##   - la MIGRATION : un ancien profil ne perd rien.
## Les niveaux factices sont injectes dans ContentDB le temps d un test, puis
## retires : aucun ne fuit vers les suites suivantes.

func get_suite_name() -> String:
	return "campaign_progression"


## Acte des niveaux factices du pool : aucun niveau livre ne l utilise, ses
## communes ne viennent donc que des niveaux injectes ici.
const ACTE_FACTICE: int = 9

var _injectes: Array[StringName] = []


func run() -> void:
	SaveData.reset_profile()
	_test_communes_de_l_acte_et_repli()
	_test_pool_obtenues_plus_communes_de_l_acte()
	_test_passifs_de_base()
	_test_passifs_debloques_par_la_victoire()
	_test_annexe_hors_progression()
	_test_annexe_conditions_d_ouverture()
	_test_annexe_passifs_et_communes_de_rattachement()
	_test_annexe_controle_du_contenu()
	_test_page_des_annexes()
	_test_page_des_annexes_tient_huit_quetes()
	_test_fiche_d_annexe()
	_test_migration_d_un_ancien_profil()
	_retirer_tout()
	SaveData.reset_profile()
	RunState.reset()
	RunState.current_level_def = null
	RunState.mode = GameEnums.Mode.EXPLORATION


# --- Outils ------------------------------------------------------------------

func _sorts(rarete: int) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.rarity == rarete:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	return out


## Une tranche TYPEE d une liste de cartes (slice rend un tableau dont le type
## n est pas garanti a l affectation, voir les gotchas des tableaux types).
func _tranche(cartes: Array, debut: int, fin: int) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for i in range(maxi(debut, 0), mini(fin, cartes.size())):
		out.append(cartes[i])
	return out


func _passifs_hors_base() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive and not GameConfig.BASE_PASSIVES.has(c.id):
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	return out


func _objectif(id: String) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName(id)
	o.check_key = &"no_damage_taken"
	return o


## Un niveau factice, injecte dans ContentDB jusqu a _retirer_tout().
func _niveau(id: String, acte: int, communes: Array = []) -> LevelDef:
	var lv := LevelDef.new()
	lv.id = StringName(id)
	lv.display_name = "Niveau %s" % id
	lv.act = acte
	lv.base_commons.assign(communes)
	lv.objectives = [_objectif(id + "_a"), _objectif(id + "_b"), _objectif(id + "_c")]
	var lv1: LevelDef = ContentDB.levels.get(SaveData.FIRST_LEVEL)
	if lv1 != null:
		lv.waves = lv1.waves.duplicate()
		lv.backdrop = lv1.backdrop
	ContentDB.levels[lv.id] = lv
	_injectes.append(lv.id)
	return lv


## Une QUETE ANNEXE factice (le seul niveau annexe du projet au 14/10).
func _annexe(id: String, acte: int, apres: StringName = &"", perso: String = "") -> LevelDef:
	var lv: LevelDef = _niveau(id, acte)
	lv.side_quest = true
	lv.side_quest_after = apres
	lv.side_quest_character = perso
	return lv


func _retirer_tout() -> void:
	for id in _injectes:
		ContentDB.levels.erase(id)
	_injectes.clear()


func _ids(cartes: Array) -> Array:
	var out: Array = []
	for c in cartes:
		if c != null and not out.has(String((c as SpellCard).id)):
			out.append(String((c as SpellCard).id))
	out.sort()
	return out


# --- Le pool -------------------------------------------------------------------

## Les communes de l acte : les decks de base des niveaux de CAMPAGNE de l acte ;
## en repli (aucun deck de base dans l acte), les communes de ses decks et de
## ses cartes nouvelles.
func _test_communes_de_l_acte_et_repli() -> void:
	# Repli sur le contenu livre : acte 1, aucun deck de base au 14/10.
	var attendu: Array = []
	var repli: bool = true
	for lv: LevelDef in ContentDB.campaign_levels():
		if lv.act != 1:
			continue
		repli = repli and not lv.has_base_commons()
		for liste: Array in [lv.exploration_deck, lv.levelup_cards]:
			for c in liste:
				if c != null and not (c as SpellCard).is_passive \
						and (c as SpellCard).rarity == GameEnums.Rarity.COMMON:
					attendu.append(c)
	if repli:
		eq(_ids(ContentDB.act_commons(1)), _ids(attendu),
			"repli : les communes des decks et des cartes nouvelles de l acte 1")
		ok(not attendu.is_empty(), "l acte 1 fait jouer des communes")
	# Contenu de la vague 10, sur un acte factice : SEULS les decks de base.
	var communes: Array[SpellCard] = _sorts(GameEnums.Rarity.COMMON)
	ok(communes.size() >= LevelDef.BASE_COMMONS_COUNT * 2,
		"assez de communes au catalogue pour deux decks de base")
	var a: LevelDef = _niveau("test_pool_a", ACTE_FACTICE,
		_tranche(communes, 0, LevelDef.BASE_COMMONS_COUNT))
	var b: LevelDef = _niveau("test_pool_b", ACTE_FACTICE,
		_tranche(communes, LevelDef.BASE_COMMONS_COUNT, LevelDef.BASE_COMMONS_COUNT * 2))
	var c_sans: LevelDef = _niveau("test_pool_c", ACTE_FACTICE)
	var expl: Array[SpellCard] = [communes[communes.size() - 1]]
	c_sans.exploration_deck = expl
	var union: Array = []
	union.append_array(a.base_commons)
	union.append_array(b.base_commons)
	eq(_ids(ContentDB.act_commons(ACTE_FACTICE)), _ids(union),
		"les communes de l acte = l union des decks de base, sans le deck d un niveau de repli")
	# Une annexe rattachee a l acte n en fournit pas.
	var sq: LevelDef = _annexe("test_pool_annexe", ACTE_FACTICE)
	sq.base_commons = _tranche(communes, communes.size() - LevelDef.BASE_COMMONS_COUNT, communes.size())
	eq(_ids(ContentDB.act_commons(ACTE_FACTICE)), _ids(union),
		"une quete annexe n ajoute pas ses communes a celles de l acte")
	_retirer_tout()


## « Toutes les cartes du jeu debloquees sont disponibles lors des montees de
## niveau ; toutes les communes de l acte des le niveau 1. »
func _test_pool_obtenues_plus_communes_de_l_acte() -> void:
	SaveData.reset_profile()
	var communes: Array[SpellCard] = _sorts(GameEnums.Rarity.COMMON)
	var a: LevelDef = _niveau("test_pool_a", ACTE_FACTICE,
		_tranche(communes, 0, LevelDef.BASE_COMMONS_COUNT))
	var b: LevelDef = _niveau("test_pool_b", ACTE_FACTICE,
		_tranche(communes, LevelDef.BASE_COMMONS_COUNT, LevelDef.BASE_COMMONS_COUNT * 2))
	# Des cartes NOUVELLES et des recompenses : sur un niveau de la vague 10,
	# elles ne passent plus par le pool du niveau.
	var rares: Array[SpellCard] = _sorts(GameEnums.Rarity.RARE)
	var nouvelles: Array[SpellCard] = [rares[0]]
	a.levelup_cards = nouvelles
	var rec: Array[SpellCard] = [rares[1], null, null]
	a.objective_rewards = rec
	# Une LEGENDAIRE obtenue ailleurs (prise en combat) : elle doit y etre.
	var leg: SpellCard = _sorts(GameEnums.Rarity.LEGENDARY)[0]
	SaveData.discover_card(leg.id)
	var obtenues: Array = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and SaveData.is_discovered(c.id):
			obtenues.append(c)
	var attendu: Array = obtenues.duplicate()
	attendu.append_array(a.base_commons)
	attendu.append_array(b.base_commons)
	var sorts_du_pool: Array = []
	for c2 in RunState.levelup_pool(a, GameEnums.Mode.EXPLORATION):
		if not c2.is_passive:
			sorts_du_pool.append(c2)
	eq(_ids(sorts_du_pool), _ids(attendu),
		"campagne : les cartes obtenues + les communes de TOUT l acte, rien d autre")
	ok(sorts_du_pool.has(leg), "une legendaire obtenue ailleurs est proposable")
	for c3 in b.base_commons:
		ok(sorts_du_pool.has(c3), "commune d un AUTRE niveau de l acte : proposable des le premier (%s)" % c3.id)
	not_ok(sorts_du_pool.has(rares[0]), "une carte nouvelle ne passe plus par le pool du niveau")
	not_ok(sorts_du_pool.has(rares[1]), "une recompense non obtenue n y est pas")
	# Objectif reussi sur un niveau OUVERT : la recompense entre au deck, donc au
	# livre, donc au pool de TOUS les niveaux.
	SaveData.unlock_level(a.id)
	SaveData.record_victory(a, GameEnums.Mode.EXPLORATION, {a.objectives[0].id: true}, 1)
	ok(RunState.levelup_pool(b, GameEnums.Mode.EXPLORATION).has(rares[1]),
		"la recompense obtenue est proposable dans un autre niveau")
	ok(RunState.levelup_pool(ContentDB.levels.get(SaveData.FIRST_LEVEL),
		GameEnums.Mode.EXPLORATION).has(rares[1]),
		"et dans un autre acte")
	# Le Libre a le meme pool ; le Massacre, les seules cartes obtenues.
	eq(_ids(RunState.levelup_pool(a, GameEnums.Mode.FREE)),
		_ids(RunState.levelup_pool(a, GameEnums.Mode.EXPLORATION)), "Libre : le pool de la campagne")
	var massacre: Array = []
	for c4 in RunState.levelup_pool(MassacreMode.level_def(), GameEnums.Mode.MASSACRE):
		if not c4.is_passive:
			massacre.append(c4)
	var obtenues2: Array = []
	for c5: SpellCard in ContentDB.cards.values():
		if c5 != null and not c5.is_passive and SaveData.is_discovered(c5.id):
			obtenues2.append(c5)
	eq(_ids(massacre), _ids(obtenues2), "Massacre : les cartes obtenues, sans communes d acte")
	# Toute offre tire dans ce pool, et les communes de l acte finissent par sortir.
	RunState.reset()
	RunState.current_level_def = a
	RunState.mode = GameEnums.Mode.EXPLORATION
	var pool: Array[SpellCard] = RunState.levelup_pool(a, GameEnums.Mode.EXPLORATION)
	var vues: Dictionary = {}
	var hors: int = 0
	for essai in 300:
		RunState.set_seed(11000 + essai)
		for c6 in RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES):
			vues[c6.id] = true
			if not pool.has(c6):
				hors += 1
		RunState.pending_offer.clear()
	eq(hors, 0, "aucune offre hors du pool")
	for c7 in b.base_commons:
		ok(vues.has(c7.id), "la commune %s de l acte est bien proposee" % c7.id)
	RunState.reset()
	RunState.current_level_def = null
	_retirer_tout()
	SaveData.reset_profile()


# --- Les passifs -------------------------------------------------------------

## « A partir de l acte 2, 6 passifs de base. » Le nombre est celui du co-auteur.
func _test_passifs_de_base() -> void:
	SaveData.reset_profile()
	eq(GameConfig.BASE_PASSIVES.size(), 6, "six passifs de base (regle du co-auteur)")
	var vus: Dictionary = {}
	for id: StringName in GameConfig.BASE_PASSIVES:
		var c: SpellCard = ContentDB.cards.get(id)
		ok(c != null and c.is_passive, "%s est un passif du catalogue" % id)
		not_ok(vus.has(id), "%s n est liste qu une fois" % id)
		vus[id] = true
	eq(ContentDB.base_passives().size(), GameConfig.BASE_PASSIVES.size(),
		"ContentDB les trouve tous")
	# Avant l acte 2 : aucun.
	not_ok(SaveData.passives_unlocked(), "profil neuf : l acte 2 n est pas atteint")
	for p: SpellCard in ContentDB.base_passives():
		not_ok(SaveData.is_discovered(p.id), "avant l acte 2, %s n est pas debloque" % p.id)
	# Un niveau de l acte 2 ouvert : les six sont debloques, les autres non.
	var acte2: LevelDef = null
	for lv: LevelDef in ContentDB.campaign_levels():
		if lv.allows_passives():
			acte2 = lv
			break
	ok(acte2 != null, "le contenu a un niveau de l acte des passifs")
	if acte2 == null:
		return
	SaveData.unlock_level(acte2.id)
	for p2: SpellCard in ContentDB.base_passives():
		ok(SaveData.is_discovered(p2.id), "acte 2 ouvert : %s est debloque" % p2.id)
	for p3: SpellCard in _passifs_hors_base():
		if not ContentDB.passive_unlocks_authored():
			not_ok(SaveData.is_discovered(p3.id),
				"%s, hors de la base, n est pas debloque d office" % p3.id)
	# L ecran de deck les propose a l equipement.
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	var choix: Array[SpellCard] = panel.passive_choices()
	for p4: SpellCard in ContentDB.base_passives():
		ok(choix.has(p4), "l ecran de deck propose %s" % p4.id)
	detach(panel)
	SaveData.reset_profile()


## Les passifs DEBLOQUABLES : gagnes a la VICTOIRE EN CAMPAGNE du niveau qui les
## porte. Des que le contenu en ecrit un, seuls les passifs debloques entrent au
## pool et a l ecran de deck ; avant (repli), tous restent proposables en
## campagne des l acte 2.
func _test_passifs_debloques_par_la_victoire() -> void:
	SaveData.reset_profile()
	var hors_base: Array[SpellCard] = _passifs_hors_base()
	ok(hors_base.size() >= 3, "des passifs hors de la base")
	if hors_base.size() < 3:
		return
	var avant_ecrit: bool = ContentDB.passive_unlocks_authored()
	var communes: Array[SpellCard] = _sorts(GameEnums.Rarity.COMMON)
	var gagne: LevelDef = _niveau("test_passif_campagne", ACTE_FACTICE,
		_tranche(communes, 0, LevelDef.BASE_COMMONS_COUNT))
	var libre: LevelDef = _niveau("test_passif_libre", ACTE_FACTICE,
		_tranche(communes, 0, LevelDef.BASE_COMMONS_COUNT))
	var un: Array[SpellCard] = [hors_base[0]]
	gagne.passive_unlocks = un
	var deux: Array[SpellCard] = [hors_base[1]]
	libre.passive_unlocks = deux
	ok(ContentDB.passive_unlocks_authored(), "le contenu ecrit maintenant des passifs debloquables")
	SaveData.unlock_level(gagne.id)
	SaveData.unlock_level(libre.id)
	eq(SaveData.passive_unlocks_of(gagne), un, "le niveau dit ce que sa victoire debloque")
	ok(CampaignPanel.passive_unlock_line(gagne).contains(hors_base[0].display_name),
		"la fiche le nomme (%s)" % CampaignPanel.passive_unlock_line(gagne))
	not_ok(SaveData.is_discovered(hors_base[0].id), "avant la victoire : pas debloque")
	var pool: Array[SpellCard] = RunState.levelup_pool(gagne, GameEnums.Mode.EXPLORATION)
	not_ok(pool.has(hors_base[2]), "un passif ni de base ni debloque n entre plus au pool")
	for p: SpellCard in ContentDB.base_passives():
		ok(pool.has(p), "un passif de base est au pool (%s)" % p.id)
	SaveData.record_victory(gagne, GameEnums.Mode.EXPLORATION, {}, 1)
	ok(SaveData.is_discovered(hors_base[0].id), "victoire en campagne : le passif est debloque")
	ok(RunState.levelup_pool(gagne, GameEnums.Mode.EXPLORATION).has(hors_base[0]),
		"et il entre au pool")
	SaveData.record_victory(libre, GameEnums.Mode.FREE, {}, 1)
	not_ok(SaveData.is_discovered(hors_base[1].id),
		"victoire en LIBRE : rien n est debloque (le Libre ne sert qu aux objectifs)")
	# L ecran de deck ne montre que les debloques.
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()
	ok(panel.passive_choices().has(hors_base[0]), "l ecran de deck propose le passif gagne")
	not_ok(panel.passive_choices().has(hors_base[2]), "et pas un passif non debloque")
	detach(panel)
	_retirer_tout()
	eq(ContentDB.passive_unlocks_authored(), avant_ecrit, "le contenu factice est retire")
	# REPLI : sans passif debloquable ecrit, la campagne propose tous les passifs
	# des l acte 2, comme avant la vague 10.
	if not ContentDB.passive_unlocks_authored():
		var acte2: LevelDef = null
		for lv: LevelDef in ContentDB.campaign_levels():
			if lv.allows_passives():
				acte2 = lv
				break
		if acte2 != null:
			var pool2: Array[SpellCard] = RunState.levelup_pool(acte2, GameEnums.Mode.EXPLORATION)
			for p2 in hors_base:
				ok(pool2.has(p2), "repli : %s reste proposable en campagne a l acte 2" % p2.id)
	SaveData.reset_profile()


# --- Les quetes annexes ------------------------------------------------------

## Une annexe ne compte PAS dans la progression : sinon elle deviendrait
## obligatoire pour ouvrir le Massacre.
func _test_annexe_hors_progression() -> void:
	SaveData.reset_profile()
	var avant: Array = SaveData.campaign_progress()
	var sq: LevelDef = _annexe("test_annexe", 2, SaveData.FIRST_LEVEL)
	not_ok(sq.is_campaign_level(), "une annexe n est pas un niveau de campagne")
	eq(SaveData.campaign_progress(), avant, "l annexe n entre pas dans campaign_progress")
	not_ok(ContentDB.campaign_levels().has(sq), "ni dans les niveaux de campagne")
	ok(ContentDB.side_quests().has(sq), "elle est dans la liste des annexes")
	for lv: LevelDef in ContentDB.campaign_levels():
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, 1)
	not_ok(SaveData.is_level_cleared(sq.id), "l annexe n est pas finie")
	ok(SaveData.campaign_cleared(), "la campagne est finie SANS l annexe")
	ok(SaveData.massacre_unlocked(), "et le Massacre s ouvre sans elle")
	# Finir l annexe ne change pas le compte.
	var fini: Array = SaveData.campaign_progress()
	SaveData.record_victory(sq, GameEnums.Mode.EXPLORATION, {}, 1)
	eq(SaveData.campaign_progress(), fini, "finir l annexe ne change pas la progression")
	_retirer_tout()
	SaveData.reset_profile()


func _test_annexe_conditions_d_ouverture() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = ContentDB.levels.get(SaveData.FIRST_LEVEL)
	# 1. Apres un niveau de campagne FINI.
	var apres: LevelDef = _annexe("test_annexe_apres", 1, SaveData.FIRST_LEVEL)
	not_ok(SaveData.is_level_unlocked(apres.id), "niveau 1 pas fini : l annexe est fermee")
	ok(SaveData.side_quest_lock_reason(apres).contains(lv1.display_name),
		"la raison nomme le niveau a finir (%s)" % SaveData.side_quest_lock_reason(apres))
	SaveData.record_victory(lv1, GameEnums.Mode.FREE, {}, 1)
	not_ok(SaveData.is_level_unlocked(apres.id), "une victoire LIBRE ne l ouvre pas")
	SaveData.record_victory(lv1, GameEnums.Mode.EXPLORATION, {}, 1)
	ok(SaveData.is_level_unlocked(apres.id), "niveau 1 fini en campagne : l annexe s ouvre")
	ok(SaveData.free_unlocked(apres.id), "avec ses deux modes")
	ok(SaveData.open_level_ids().has(String(apres.id)), "elle compte parmi les niveaux ouverts")
	eq(SaveData.side_quest_lock_reason(apres), "", "plus de raison de refus")
	not_ok(SaveData.unlocked_levels().has(String(apres.id)),
		"rien n est ECRIT : l ouverture se deduit")
	# 2. Un PERSONNAGE debloque au compte.
	var perso: AccountRewardDef = null
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.is_apprentice() and r.at_level > SaveData.account_level():
			perso = r
			break
	ok(perso != null, "un apprenti se debloque plus tard au compte")
	if perso != null:
		var sq_p: LevelDef = _annexe("test_annexe_perso", 1, &"", perso.texture_name)
		not_ok(SaveData.is_level_unlocked(sq_p.id), "apprenti pas debloque : l annexe est fermee")
		ok(SaveData.side_quest_lock_reason(sq_p).contains(perso.display_name),
			"la raison nomme l apprenti (%s)" % SaveData.side_quest_lock_reason(sq_p))
		SaveData.grant_account_xp(SaveData.account_xp_for_level(perso.at_level) - SaveData.account_xp())
		ok(SaveData.character_unlocked(perso.texture_name), "l apprenti est debloque")
		ok(SaveData.is_level_unlocked(sq_p.id), "et l annexe s ouvre")
	# 3. Sans condition : quand son acte de rattachement est atteint.
	var dernier_acte: int = 0
	for lv: LevelDef in ContentDB.campaign_levels():
		dernier_acte = maxi(dernier_acte, lv.act)
	var libre: LevelDef = _annexe("test_annexe_acte", dernier_acte)
	not_ok(SaveData.is_level_unlocked(libre.id), "acte %d pas atteint : fermee" % dernier_acte)
	for lv2: LevelDef in ContentDB.campaign_levels():
		if lv2.act == dernier_acte:
			SaveData.unlock_level(lv2.id)
			break
	ok(SaveData.is_level_unlocked(libre.id), "acte %d atteint : ouverte" % dernier_acte)
	# Le mode testeur ouvre tout, les annexes comprises.
	SaveData.reset_profile()
	not_ok(SaveData.is_level_unlocked(apres.id), "profil neuf : fermee")
	SaveData.set_tester_mode(true)
	ok(SaveData.is_level_unlocked(apres.id), "mode testeur : ouverte")
	SaveData.set_tester_mode(false)
	_retirer_tout()
	SaveData.reset_profile()


## « Elles autorisent les passifs selon leur acte de rattachement. »
func _test_annexe_passifs_et_communes_de_rattachement() -> void:
	SaveData.reset_profile()
	var avant: LevelDef = _annexe("test_annexe_acte1", LevelDef.PASSIVES_FROM_ACT - 1)
	var apres: LevelDef = _annexe("test_annexe_acte2", LevelDef.PASSIVES_FROM_ACT)
	not_ok(RunState.passives_allowed(avant, GameEnums.Mode.EXPLORATION),
		"annexe rattachee avant l acte des passifs : aucun passif")
	ok(RunState.passives_allowed(apres, GameEnums.Mode.EXPLORATION),
		"annexe rattachee a l acte des passifs : ils existent")
	for c in RunState.levelup_pool(avant, GameEnums.Mode.EXPLORATION):
		not_ok(c.is_passive, "aucun passif au pool d une annexe d acte 1 (%s)" % c.id)
	for c2 in ContentDB.act_commons(apres.act):
		ok(RunState.levelup_pool(apres, GameEnums.Mode.EXPLORATION).has(c2),
			"l annexe propose les communes de son acte de rattachement (%s)" % c2.id)
	_retirer_tout()
	SaveData.reset_profile()


func _test_annexe_controle_du_contenu() -> void:
	var sans_acte: LevelDef = _annexe("test_annexe_sans_acte", 0)
	ok(sans_acte.structure_errors().size() > 0, "une annexe sans acte de rattachement est refusee")
	var inconnue: LevelDef = _annexe("test_annexe_inconnue", 1, &"lvl_qui_n_existe_pas")
	ok(inconnue.structure_errors().size() > 0, "une annexe ouverte apres un niveau inconnu est refusee")
	var chaine: LevelDef = _annexe("test_annexe_chaine", 1, &"test_annexe_sans_acte")
	ok(chaine.structure_errors().size() > 0, "une annexe ouverte apres une autre annexe est refusee")
	var camp: LevelDef = _niveau("test_campagne_cond", 1)
	camp.side_quest_after = SaveData.FIRST_LEVEL
	ok(camp.structure_errors().size() > 0, "une condition d annexe sur un niveau de campagne est refusee")
	var bonne: LevelDef = _annexe("test_annexe_bonne", 1, SaveData.FIRST_LEVEL)
	eq(bonne.structure_errors().size(), 0, "une annexe bien formee passe (%s)" % str(bonne.structure_errors()))
	var trop: LevelDef = _niveau("test_trop_de_passifs", LevelDef.PASSIVES_FROM_ACT)
	var passifs: Array[SpellCard] = _tranche(_passifs_hors_base(), 0, LevelDef.MAX_PASSIVE_UNLOCKS + 1)
	trop.passive_unlocks = passifs
	ok(trop.structure_errors().size() > 0, "plus de passifs debloques que la regle n en admet")
	var tot: LevelDef = _niveau("test_passif_trop_tot", LevelDef.PASSIVES_FROM_ACT - 1)
	var un: Array[SpellCard] = [_passifs_hors_base()[0]]
	tot.passive_unlocks = un
	ok(tot.structure_errors().size() > 0, "un passif debloque avant l acte des passifs")
	var sort: LevelDef = _niveau("test_passif_sort", LevelDef.PASSIVES_FROM_ACT)
	var pas_passif: Array[SpellCard] = [_sorts(GameEnums.Rarity.RARE)[0]]
	sort.passive_unlocks = pas_passif
	ok(sort.structure_errors().size() > 0, "un sort n est pas un passif debloquable")
	_retirer_tout()


## LA PAGE « QUETES ANNEXES » : apres les actes, seulement si le contenu en a,
## et une annexe n est jamais sur la page de son acte.
func _test_page_des_annexes() -> void:
	SaveData.reset_profile()
	var m := CampaignMap.new()
	attach(m)
	m.size = Vector2(1080.0, 1500.0)
	m.rebuild()
	var avait: bool = m.has_side_page()
	if ContentDB.side_quests().is_empty():
		not_ok(avait, "sans annexe au contenu, pas de page vide")
	detach(m)
	var sq: LevelDef = _annexe("test_annexe_page", 2, SaveData.FIRST_LEVEL)
	sq.display_name = "Le sentier perdu"
	m = CampaignMap.new()
	attach(m)
	m.size = Vector2(1080.0, 1500.0)
	m.rebuild()
	ok(m.has_side_page(), "une annexe au contenu : la page existe")
	var actes: Array[int] = m.acts()
	eq(actes[actes.size() - 1], CampaignMap.SIDE_PAGE, "la page des annexes vient APRES les actes")
	ok(m.side_quest_ids().has(sq.id), "l annexe est sur sa page")
	not_ok(m.levels_in_act(sq.act).has(sq.id), "et pas sur la page de son acte")
	m.show_side_page()
	eq(m.current_act(), CampaignMap.SIDE_PAGE, "on peut afficher la page")
	eq(m.act_title(CampaignMap.SIDE_PAGE), CampaignMap.SIDE_TITLE, "titre de la page")
	ok(m.fork_notice_visible(), "l avis de la page est affiche")
	not_ok(m.is_enabled(sq.id), "fermee : le point est verrouille")
	var cond: Label = _condition_de(m, sq.id)
	ok(cond != null and cond.text == SaveData.side_quest_lock_reason(sq),
		"la tuile d une annexe fermee dit sa condition (%s)" % (cond.text if cond != null else "?"))
	SaveData.record_victory(ContentDB.levels.get(SaveData.FIRST_LEVEL),
		GameEnums.Mode.EXPLORATION, {}, 1)
	m.rebuild()
	m.show_side_page()
	ok(m.is_enabled(sq.id), "condition remplie : le point s ouvre")
	eq(_condition_de(m, sq.id), null, "et la condition disparait")
	# Aller jusqu a la page par les fleches.
	m.show_act(actes[actes.size() - 2])
	ok(m.can_go_next(), "le dernier acte mene a la page des annexes")
	m.go_next()
	eq(m.current_act(), CampaignMap.SIDE_PAGE, "par la fleche de droite")
	detach(m)
	_retirer_tout()
	SaveData.reset_profile()


func _condition_de(m: CampaignMap, id: StringName) -> Label:
	var med: Control = m.medallion_for(id)
	if med == null:
		return null
	var bouton: Node = med
	while bouton != null and not (bouton is Button):
		bouton = bouton.get_parent()
	if bouton == null:
		return null
	return bouton.find_child("Condition", true, false) as Label


## Le contenu prevoit ~8 annexes : la page doit les tenir sans que deux cibles
## se chevauchent ni qu une sorte de l ecran ou passe sous une fleche.
func _test_page_des_annexes_tient_huit_quetes() -> void:
	SaveData.reset_profile()
	# Les annexes LIVREES d abord (vague 10, B3 : il y en a huit), completees par
	# des factices jusqu a huit : la page est jugee sur huit tuiles, pas sur
	# huit factices ajoutees au contenu.
	var ids: Array[StringName] = []
	for livree: LevelDef in ContentDB.side_quests():
		ids.append(livree.id)
	var livrees: int = ids.size()
	for i in range(livrees, 8):
		var sq: LevelDef = _annexe("test_annexe_%d" % i, 1 + i % 5, SaveData.FIRST_LEVEL)
		sq.display_name = "Annexe numero %d" % i
		ids.append(sq.id)
	var m := CampaignMap.new()
	attach(m)
	m.size = Vector2(1080.0, 1500.0)
	m.rebuild()
	m.show_side_page()
	var rects: Array[Rect2] = []
	for id in ids:
		rects.append(m.hit_rect_of(id))
	for i in rects.size():
		var r: Rect2 = rects[i]
		ok(r.position.x >= CampaignMap.SIDE_MARGIN - 1.0 \
				and r.end.x <= m.size.x - CampaignMap.SIDE_MARGIN + 1.0,
			"annexe %d entre les fleches (%s)" % [i, r])
		ok(r.position.y >= m.size.y * CampaignMap.GROUND_TOP - 1.0 \
				and r.end.y <= m.size.y * CampaignMap.GROUND_BOTTOM + 1.0,
			"annexe %d sur le sol (%s)" % [i, r])
		ok(r.size.y >= CampaignMap.SIDE_HIT_H - 1.0, "annexe %d : tuile entiere" % i)
		for j in range(i + 1, rects.size()):
			not_ok(r.intersects(rects[j]), "annexes %d et %d ne se chevauchent pas" % [i, j])
	detach(m)
	_retirer_tout()
	SaveData.reset_profile()


func _test_fiche_d_annexe() -> void:
	SaveData.reset_profile()
	var sq: LevelDef = _annexe("test_annexe_fiche", 2, SaveData.FIRST_LEVEL)
	SaveData.record_victory(ContentDB.levels.get(SaveData.FIRST_LEVEL),
		GameEnums.Mode.EXPLORATION, {}, 1)
	var p := CampaignPanel.new()
	attach(p)
	p.open_level(sq.id)
	eq(p.detail_level_id(), sq.id, "la fiche de l annexe s ouvre")
	ok(p.detail_texts().has(CampaignPanel.side_quest_header(sq)),
		"son en-tete dit QUETE ANNEXE et son acte (%s)" % CampaignPanel.side_quest_header(sq))
	ok(CampaignPanel.side_quest_header(sq).contains("ANNEXE"), "le mot ANNEXE y est")
	ok(p.free_available(), "le Libre d une annexe ouverte est ouvert")
	detach(p)
	_retirer_tout()
	SaveData.reset_profile()


# --- Migration -------------------------------------------------------------------

## « Rien n est retire a un profil existant » : un profil ecrit avant la vague 10
## (cartes prises, passif pris, etoiles, niveau fini, records dont l ancien record
## Infini) se relit sans rien perdre.
func _test_migration_d_un_ancien_profil() -> void:
	var lv1: LevelDef = ContentDB.levels.get(SaveData.FIRST_LEVEL)
	var suivant: StringName = lv1.next_levels[0] if not lv1.next_levels.is_empty() else &""
	var leg: SpellCard = _sorts(GameEnums.Rarity.LEGENDARY)[0]
	var passif: SpellCard = _passifs_hors_base()[0]
	var obj: ObjectiveDef = lv1.objectives[0]
	var ancien: Dictionary = {
		"schema_version": 1,
		"profile": {
			"discovered_cards": [String(leg.id), String(passif.id)],
			"campaign": {"current_node": String(suivant),
				"unlocked_levels": [String(lv1.id), String(suivant)]},
			"levels": {
				String(lv1.id): {
					"cleared_exploration": true, "cleared_massacre": false,
					"best_wave": 6, "best_wave_infinite": 17,
					"objectives": {String(obj.id): true},
				},
			},
			"massacre_best_wave": 9,
			"equipped_passives": [String(passif.id)],
		},
	}
	SaveData.load_from_dictionary(ancien.duplicate(true))
	ok(SaveData.is_discovered(leg.id), "la legendaire prise reste obtenue")
	ok(SaveData.is_discovered(passif.id), "le passif pris reste obtenu, meme hors de la base")
	ok(SaveData.is_level_cleared(lv1.id), "le niveau fini le reste")
	ok(SaveData.is_level_unlocked(suivant), "le niveau ouvert le reste")
	ok(SaveData.is_objective_done(lv1.id, obj.id), "l etoile reste acquise")
	eq(int(SaveData.level_record(lv1.id).get("best_wave", 0)), 6, "la meilleure vague reste")
	eq(int(SaveData.level_record(lv1.id).get("best_wave_infinite", 0)), 17,
		"l ancien record Infini reste dans le profil")
	eq(SaveData.massacre_best_wave(), 9, "le record du Massacre reste")
	eq(SaveData.equipped_passives(), [String(passif.id)], "le passif equipe reste equipe")
	for c: SpellCard in lv1.exploration_deck:
		ok(SaveData.is_discovered(c.id), "carte du deck d un niveau ouvert : obtenue (%s)" % c.id)
	# Relire le profil ecrit ne perd rien non plus (aucune ecriture de migration).
	var ecrit: Dictionary = SaveData.to_dictionary()
	SaveData.load_from_dictionary(ecrit)
	eq(int(SaveData.level_record(lv1.id).get("best_wave_infinite", 0)), 17,
		"la relecture garde l ancien record Infini")
	ok(SaveData.is_discovered(passif.id), "la relecture garde le passif")
	# Une ancienne victoire « hors Exploration » (cleared_massacre) compte toujours.
	var vieux: Dictionary = ancien.duplicate(true)
	var fiche: Dictionary = vieux["profile"]["levels"][String(lv1.id)]
	fiche["cleared_exploration"] = false
	fiche["cleared_massacre"] = true
	SaveData.load_from_dictionary(vieux)
	ok(SaveData.is_level_cleared(lv1.id), "une victoire d avant notee cleared_massacre compte encore")
	SaveData.reset_profile()
