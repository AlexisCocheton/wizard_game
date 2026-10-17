extends TestCase
## LES ETOILES D UN PROFIL D AVANT LA VAGUE 10 (chantier C7a, audit du 17/10).
##
## L id d un objectif est DEDUIT de son controle et de ses parametres
## (system_objectives). B2 a refait les objectifs : entre a7cdcdc (le 03/10 au
## soir, dernier etat avant la vague 10) et la vague 10, 44 ids sur 63 ont
## change. Le co-auteur joue sur un telephone dont le profil date d avant : sans
## migration, un niveau a 3/3 retombait a 0/3, son deck de campagne a 4/4/4, et
## rien ne plantait. Le test de migration de test_campaign_progression ecrit son
## profil avec les ids ACTUELS : il ne pouvait pas le voir.
##
## LE PROFIL CI-DESSOUS EST UN VRAI PROFIL DE L EPOQUE : le format ecrit par
## save_data.gd a a7cdcdc (`git show a7cdcdc:scripts/autoload/save_data.gd` :
## fiches de niveau cleared_exploration / cleared_massacre / best_wave /
## best_wave_infinite / objectives, record du Massacre, decks nommes,
## cosmetiques) et les ids d objectif lus dans
## `git show a7cdcdc:resources/levels/lvl_XX.tres`. Il est ecrit EN JSON, tel
## que user://profile.json le contient, et relu par JSON.parse_string comme au
## lancement : les nombres y reviennent en flottants, comme sur le telephone.
## Le joueur est a l acte IV : la regle d avant ouvrait lvl_13 des le premier
## demon fini, il l a donc deja (et le garde).
##
## Ids et rangs attendus EN DUR (gotchas : un test qui relit la constante qu il
## contraint ne mord pas). Si le contenu rechange ses ids, _test_les_donnees_
## discriminent le dit avant tout le reste.
##
## Sabotage verifie : l appel a _carry_legacy_objectives retire de _migrate et
## de _on_content_loaded -> la suite rougit (lvl_04, lvl_12 a 0 / 3...).

func get_suite_name() -> String:
	return "save_migration_w10"


const PROFIL_ANCIEN: String = """{
	"schema_version": 1,
	"profile": {
		"discovered_cards": ["fireball", "spark", "arcane_bolt", "piercing_arrow", "time_rift", "resonance"],
		"unlocked_legendaries": [],
		"campaign": {
			"current_node": "lvl_12",
			"unlocked_levels": ["lvl_01", "lvl_02", "lvl_08", "lvl_09", "lvl_17", "lvl_18", "lvl_03",
				"lvl_04", "lvl_19", "lvl_20", "lvl_05", "lvl_06", "lvl_21", "lvl_07", "lvl_10",
				"lvl_11", "lvl_12", "lvl_13"]
		},
		"levels": {
			"lvl_01": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 6,
				"best_wave_infinite": 14,
				"objectives": {"obj_card_casts_piercing_arrow_9": true, "obj_no_card_fireball": true,
					"obj_win_above_speed_250": true}},
			"lvl_02": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 6,
				"objectives": {"obj_win_above_speed_300": true, "obj_boss_quick_after_revive_8": true}},
			"lvl_08": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 7,
				"objectives": {}},
			"lvl_09": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 7,
				"objectives": {}},
			"lvl_17": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 8,
				"objectives": {"obj_card_casts_resonance_7": true, "obj_kill_flying_21": true}},
			"lvl_18": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 8,
				"objectives": {}},
			"lvl_03": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 8,
				"objectives": {}},
			"lvl_04": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 9,
				"objectives": {"obj_kill_type_with_card_ember_pool_2_risen_ghoul": true,
					"obj_win_under_time_130": true, "obj_no_hit_from_imp_archer": true}},
			"lvl_19": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 8,
				"objectives": {}},
			"lvl_20": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 9,
				"objectives": {}},
			"lvl_05": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 9,
				"objectives": {}},
			"lvl_21": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 9,
				"objectives": {}},
			"lvl_12": {"cleared_exploration": true, "cleared_massacre": false, "best_wave": 10,
				"best_wave_infinite": 21,
				"objectives": {"obj_kill_type_with_card_arcane_bolt_7_shade": true,
					"obj_card_casts_focus_28": true, "obj_same_card_casts_38": true}}
		},
		"massacre_deck": [],
		"decks": [{"name": "Feu", "cards": ["fireball", "fireball", "fireball", "spark", "spark", "spark",
			"arcane_bolt", "arcane_bolt", "arcane_bolt", "piercing_arrow", "piercing_arrow", "piercing_arrow"]}],
		"current_deck": 0,
		"equipped_passives": [],
		"discovered_enemies": ["gnome", "sprite", "wisp"],
		"account": {"level": 7, "xp": 5400, "challenges": ["ch_act_one"], "stats": {"levels_cleared": 13}},
		"cosmetics": {"mage_color": "monk_blue", "hat": "", "tower": "tower_blue", "avatar": "avatar_mage",
			"outfits": {}, "character": "mage"},
		"stories_seen": ["intro_lvl_01"],
		"massacre_best_wave": 0
	},
	"settings": {"master_volume": 0.8, "sfx_volume": 1.0, "music_volume": 0.6, "haptics": true,
		"language": "fr", "tester_mode": false}
}"""

## Les ids d objectif de a7cdcdc par niveau, rang 1 a 3 (seuls ceux que le
## profil a acquis sont dans PROFIL_ANCIEN). `garde` : encore un objectif
## actuel du niveau a la vague 10.
const ANCIENS: Dictionary = {
	"lvl_01": {"perimes": ["obj_card_casts_piercing_arrow_9", "obj_win_above_speed_250"],
		"garde": ["obj_no_card_fireball"]},
	"lvl_02": {"perimes": ["obj_boss_quick_after_revive_8"],
		"garde": ["obj_win_above_speed_300"]},
	"lvl_04": {"perimes": ["obj_kill_type_with_card_ember_pool_2_risen_ghoul",
		"obj_win_under_time_130", "obj_no_hit_from_imp_archer"], "garde": []},
	"lvl_12": {"perimes": ["obj_kill_type_with_card_arcane_bolt_7_shade",
		"obj_card_casts_focus_28", "obj_same_card_casts_38"], "garde": []},
	"lvl_17": {"perimes": ["obj_card_casts_resonance_7", "obj_kill_flying_21"], "garde": []},
}

## LES RANGS ATTENDUS apres la mise a jour, ecrits a la main :
##   lvl_04, lvl_12 : 3/3, tous perimes -> 3/3 (rangs 1, 2, 3) ;
##   lvl_01 : 3/3, obj_no_card_fireball garde (rang 2) -> les deux perimes
##            rendent les rangs 1 et 3, pas 1 et 2 : un objectif actuel deja
##            reussi ne compte pas deux fois ;
##   lvl_02 : 2/3, obj_win_above_speed_300 garde mais passe du rang 1 au rang 3
##            -> il vaut le rang 3, le perime rend le rang 1 : 2 etoiles ;
##   lvl_17 : 2/3, tous perimes -> rangs 1 et 2, et JAMAIS le 3 a la relecture.
const RANGS_ATTENDUS: Dictionary = {
	"lvl_01": "[1, 2, 3]",
	"lvl_02": "[1, 3]",
	"lvl_04": "[1, 2, 3]",
	"lvl_12": "[1, 2, 3]",
	"lvl_17": "[1, 2]",
	# Fini sans etoile : rien a rendre.
	"lvl_08": "[]",
}


func run() -> void:
	SaveData.reset_profile()
	_test_les_donnees_discriminent()
	_test_les_etoiles_reviennent()
	_test_ce_que_les_rangs_ouvrent_suit()
	_test_rien_d_autre_ne_bouge()
	_test_idempotente()
	_test_un_profil_recent_n_est_pas_touche()
	_test_un_renommage_ne_compte_pas_deux_fois()
	_test_quand_le_contenu_arrive_apres_le_profil()
	SaveData.reset_profile()


# --- Outils ---------------------------------------------------------------------

func _ancien() -> Dictionary:
	var brut: Variant = JSON.parse_string(PROFIL_ANCIEN)
	ok(typeof(brut) == TYPE_DICTIONARY, "le profil ancien est un JSON lisible")
	return brut if typeof(brut) == TYPE_DICTIONARY else {}


func _lv(id: String) -> LevelDef:
	return ContentDB.levels.get(StringName(id))


## Les rangs acquis, en texte : Array[int] et Array ne se comparent pas
## toujours comme on l attend.
func _rangs(id: String) -> String:
	return str(SaveData.achieved_ranks(_lv(id)))


func _ids_actuels(id: String) -> Array:
	var out: Array = []
	var lv: LevelDef = _lv(id)
	if lv != null:
		for o in lv.objectives:
			if o != null:
				out.append(String(o.id))
	return out


func _json(d: Dictionary) -> String:
	return JSON.stringify(d, "", true)


# --- Les tests ------------------------------------------------------------------

## Le test ne vaut que si ses ids sont VRAIMENT perimes (et ceux qu il garde,
## vraiment actuels). Sans cette garde, un contenu qui reprendrait ses anciens
## ids rendrait le test vert sans rien migrer.
func _test_les_donnees_discriminent() -> void:
	for id: String in ANCIENS:
		var actuels: Array = _ids_actuels(id)
		eq(actuels.size(), 3, "%s a trois objectifs" % id)
		for ancien: String in ANCIENS[id]["perimes"]:
			not_ok(actuels.has(ancien), "%s : %s n est plus un objectif du niveau" % [id, ancien])
		for garde: String in ANCIENS[id]["garde"]:
			ok(actuels.has(garde), "%s : %s est toujours un objectif du niveau" % [id, garde])
	# Le cas de lvl_02 : l id garde a CHANGE DE RANG (1 -> 3).
	eq(_ids_actuels("lvl_02").find("obj_win_above_speed_300"), 2,
		"lvl_02 : obj_win_above_speed_300 est desormais le rang 3")
	# Le cas de lvl_04 : un ancien id devenu l objectif d un AUTRE niveau reste
	# perime pour lvl_04 (la fiche est celle de lvl_04).
	ok(_ids_actuels("lvl_03").has("obj_no_hit_from_imp_archer"),
		"(obj_no_hit_from_imp_archer est un objectif de lvl_03)")


func _test_les_etoiles_reviennent() -> void:
	SaveData.load_from_dictionary(_ancien())
	for id: String in RANGS_ATTENDUS:
		eq(_rangs(id), RANGS_ATTENDUS[id], "%s : rangs acquis apres la mise a jour" % id)
	eq(SaveData.objectives_done_count(_lv("lvl_04")), 3, "lvl_04 : 3 etoiles sur la carte, pas 0")
	eq(SaveData.objectives_done_count(_lv("lvl_12")), 3, "lvl_12 : 3 etoiles, pas 0")
	eq(SaveData.objectives_done_count(_lv("lvl_17")), 2, "lvl_17 : ses 2 etoiles, pas 0")
	eq(SaveData.objectives_done_count(_lv("lvl_02")), 2, "lvl_02 : ses 2 etoiles")
	SaveData.reset_profile()


## Tout ce qu un rang acquis ouvre suit : le deck de campagne (table du
## co-auteur), les cartes des objectifs (pool, livre), la fiche.
func _test_ce_que_les_rangs_ouvrent_suit() -> void:
	SaveData.load_from_dictionary(_ancien())
	for id: String in ["lvl_04", "lvl_12", "lvl_17", "lvl_02"]:
		var lv: LevelDef = _lv(id)
		var base: Array[SpellCard] = lv.campaign_base_cards()
		var deck: Array[SpellCard] = SaveData.campaign_deck(lv)
		# La garde de donnees : sans objectif, le deck est bien 4/4/4.
		eq(base.size(), 12, "%s : deck de base de 12" % id)
		for c: SpellCard in lv.base_commons:
			eq(base.count(c), 4, "%s : %s x4 sans objectif (4/4/4)" % [id, c.id])
		ok(deck != base, "%s : le deck de campagne n est PLUS 4/4/4" % id)
		ok(deck == lv.campaign_deck(SaveData.achieved_ranks(lv)),
			"%s : il suit la table du co-auteur pour les rangs acquis" % id)
		eq(deck.size(), 12, "%s : toujours 12 cartes" % id)
		for i in lv.objectives.size():
			var carte: SpellCard = lv.objective_reward(i)
			var acquis: bool = SaveData.is_objective_done(lv.id, lv.objectives[i].id)
			if carte == null or not acquis:
				continue
			ok(SaveData.objective_rewards_unlocked(lv).has(carte),
				"%s : la carte du rang %d (%s) est debloquee" % [id, i + 1, carte.id])
			if not carte.is_passive:
				ok(deck.has(carte), "%s : %s est entree au deck de campagne" % [id, carte.id])
				ok(SaveData.is_discovered(carte.id), "%s : %s est au livre" % [id, carte.id])
	eq(SaveData.objective_rewards_unlocked(_lv("lvl_04")).size(), 3,
		"lvl_04 : ses trois cartes d objectif sont debloquees")
	SaveData.reset_profile()


## La migration ne touche QUE les etoiles : niveaux finis et ouverts, records,
## decks, cartes prises, compte restent ; les ids perimes restent dans la fiche
## (choix documente dans SaveData._carry_legacy_objectives), notes une fois.
func _test_rien_d_autre_ne_bouge() -> void:
	SaveData.load_from_dictionary(_ancien())
	ok(SaveData.is_level_cleared(&"lvl_12"), "lvl_12 reste fini")
	ok(SaveData.is_level_unlocked(&"lvl_13"), "lvl_13, deja ouvert par l ancienne regle, le reste")
	eq(int(SaveData.level_record(&"lvl_12").get("best_wave", 0)), 10, "la meilleure vague reste")
	eq(int(SaveData.level_record(&"lvl_12").get("best_wave_infinite", 0)), 21,
		"l ancien record Infini reste dans la fiche")
	eq(SaveData.deck_count(), 1, "le deck nomme reste")
	eq(SaveData.deck_name(0), "Feu", "avec son nom")
	ok(SaveData.is_discovered(&"time_rift"), "une carte prise reste au livre")
	eq(SaveData.account_level(), 7, "le niveau de compte reste")
	var fiche: Dictionary = SaveData.level_record(&"lvl_04")
	var objs: Dictionary = fiche.get("objectives", {})
	for ancien: String in ANCIENS["lvl_04"]["perimes"]:
		ok(bool(objs.get(ancien, false)), "l id perime %s est garde dans la fiche" % ancien)
	var rendus: Array = fiche.get(SaveData.LEGACY_OBJECTIVES_KEY, [])
	eq(rendus.size(), 3, "lvl_04 : ses trois perimes sont notes comme rendus")
	var fiche1: Dictionary = SaveData.level_record(&"lvl_01")
	not_ok((fiche1.get(SaveData.LEGACY_OBJECTIVES_KEY, []) as Array).has("obj_no_card_fireball"),
		"un id ACTUEL n est jamais note comme perime")
	not_ok(SaveData.level_record(&"lvl_08").has(SaveData.LEGACY_OBJECTIVES_KEY),
		"une fiche sans perime ne recoit aucune note")
	SaveData.reset_profile()


## Une seconde lecture ne change RIEN : un id ancien ne compte qu une fois.
## lvl_17 (2/3, deux perimes) est le cas qui mord : sans la note des perimes
## rendus, la relecture leur ferait rendre le rang 3.
func _test_idempotente() -> void:
	SaveData.load_from_dictionary(_ancien())
	var une: Dictionary = SaveData.to_dictionary()
	SaveData.load_from_dictionary(une)
	var deux: Dictionary = SaveData.to_dictionary()
	eq(_json(deux), _json(une), "relire le profil migre ne change rien")
	eq(_rangs("lvl_17"), "[1, 2]", "lvl_17 : toujours 2 etoiles a la relecture, pas 3")
	eq(_rangs("lvl_02"), "[1, 3]", "lvl_02 : toujours 2 etoiles a la relecture")
	# Une troisieme passe directe sur le dictionnaire migre.
	var trois: Dictionary = SaveData._migrate(une.duplicate(true))
	eq(_json(trois), _json(une), "_migrate sur un profil migre ne change rien")
	ok(not SaveData._carry_legacy_objectives(SaveData.profile()),
		"la passe sur le profil migre rend « rien change »")
	SaveData.reset_profile()


## Un profil d APRES la vague 10 (objectifs gagnes sous les ids actuels) n est
## pas touche, octet pour octet.
func _test_un_profil_recent_n_est_pas_touche() -> void:
	SaveData.reset_profile()
	var lv1: LevelDef = _lv("lvl_01")
	var faits: Dictionary = {lv1.objectives[0].id: true, lv1.objectives[2].id: true}
	SaveData.record_victory(lv1, GameEnums.Mode.EXPLORATION, faits, 6)
	var lv2: LevelDef = _lv("lvl_02")
	SaveData.record_victory(lv2, GameEnums.Mode.EXPLORATION, {lv2.objectives[1].id: true}, 6)
	var recent: Dictionary = SaveData.to_dictionary()
	SaveData.load_from_dictionary(recent)
	eq(_json(SaveData.to_dictionary()), _json(recent), "le profil recent se relit a l identique")
	eq(_rangs("lvl_01"), "[1, 3]", "lvl_01 : ses rangs 1 et 3, pas un de plus")
	eq(_rangs("lvl_02"), "[2]", "lvl_02 : son rang 2 seul")
	not_ok(SaveData.level_record(&"lvl_01").has(SaveData.LEGACY_OBJECTIVES_KEY),
		"aucune note de migration dans un profil recent")
	SaveData.reset_profile()


## Un profil d avant la vague 8 : « 32 sorts de givre » s appelait
## obj_element_casts_32_frost (RENAMED_OBJECTIVES le porte vers ..._ice, objectif
## actuel de lvl_11). L ancien nom n est pas un perime de plus : sinon lvl_11
## gagnerait une etoile qu il n a jamais eue.
func _test_un_renommage_ne_compte_pas_deux_fois() -> void:
	ok(_ids_actuels("lvl_11").has("obj_element_casts_32_ice"), "(le givre est la glace dans lvl_11)")
	not_ok(_ids_actuels("lvl_11").has("obj_kill_flying_4"), "(obj_kill_flying_4 est perime)")
	var brut: Dictionary = _ancien()
	brut["profile"]["levels"]["lvl_11"] = {"cleared_exploration": true, "cleared_massacre": false,
		"best_wave": 7, "objectives": {"obj_element_casts_32_frost": true, "obj_kill_flying_4": true}}
	SaveData.load_from_dictionary(brut)
	eq(_rangs("lvl_11"), "[1, 2]", "lvl_11 : le renomme vaut le rang 1, le perime le rang 2, rien de plus")
	SaveData.reset_profile()


## Au lancement, SaveData lit le profil AVANT que ContentDB n ait charge les
## niveaux (ordre des autoloads) : la passe doit repartir quand le contenu
## arrive. On rejoue cet ordre : profil brut pose sans migration, puis le
## signal du contenu.
func _test_quand_le_contenu_arrive_apres_le_profil() -> void:
	ok(ContentDB.content_loaded.is_connected(SaveData._on_content_loaded),
		"SaveData ecoute le chargement du contenu")
	SaveData.reset_profile()
	SaveData._data = _ancien()
	eq(_rangs("lvl_04"), "[]", "(profil brut, avant le contenu : lvl_04 a 0 / 3)")
	ContentDB.content_loaded.emit()
	eq(_rangs("lvl_04"), "[1, 2, 3]", "le contenu charge, les etoiles de lvl_04 reviennent")
	eq(_rangs("lvl_17"), "[1, 2]", "et celles de lvl_17")
	SaveData.reset_profile()
