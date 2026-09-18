extends TestCase
## Progression de COMPTE : defis, niveau de compte, recompenses cosmetiques.
##
## Choix de conception valide par l utilisateur : le compte donne des TITRES et
## des AVATARS, jamais de puissance. Un niveau de compte qui rendrait le mage plus
## fort perimerait les taux de victoire mesures au banc (7 niveaux entre 63 et
## 100 %) et rendrait le jeu plus facile pour qui joue plus, pas pour qui joue
## mieux. L XP de compte vient de DEFIS nommes, pas du simple temps passe.

func get_suite_name() -> String:
	return "account"


func run() -> void:
	SaveData.reset_profile()
	_test_un_profil_neuf_part_du_niveau_1()
	_test_un_defi_accompli_donne_de_l_xp()
	_test_un_defi_ne_paie_qu_une_fois()
	_test_le_niveau_monte_et_debloque()
	_test_les_recompenses_sont_cosmetiques()
	_test_la_progression_survit_a_un_ancien_profil()
	SaveData.reset_profile()


func _test_un_profil_neuf_part_du_niveau_1() -> void:
	SaveData.reset_profile()
	eq(SaveData.account_level(), 1, "un compte neuf est au niveau 1")
	eq(SaveData.account_xp(), 0, "sans XP")
	ok(SaveData.completed_challenges().is_empty(), "et sans defi accompli")


## Un defi accompli rapporte son XP une seule fois.
func _test_un_defi_accompli_donne_de_l_xp() -> void:
	SaveData.reset_profile()
	var defis: Array[ChallengeDef] = ContentDB.challenges_list()
	ok(not defis.is_empty(), "le catalogue contient des defis")
	if defis.is_empty():
		return
	var d: ChallengeDef = defis[0]
	var avant: int = SaveData.account_xp()
	ok(SaveData.complete_challenge(d.id), "le defi est valide")
	eq(SaveData.account_xp(), avant + d.xp_reward, "il rapporte son XP")
	ok(SaveData.is_challenge_done(d.id), "il est marque comme accompli")


func _test_un_defi_ne_paie_qu_une_fois() -> void:
	SaveData.reset_profile()
	var defis: Array[ChallengeDef] = ContentDB.challenges_list()
	if defis.is_empty():
		return
	var d: ChallengeDef = defis[0]
	SaveData.complete_challenge(d.id)
	var apres_premier: int = SaveData.account_xp()
	not_ok(SaveData.complete_challenge(d.id), "le meme defi ne se revalide pas")
	eq(SaveData.account_xp(), apres_premier, "et ne rapporte rien de plus")


## Assez d XP fait monter le niveau, et le niveau debloque des recompenses.
func _test_le_niveau_monte_et_debloque() -> void:
	SaveData.reset_profile()
	var besoin: int = SaveData.account_xp_for_level(2)
	ok(besoin > 0, "il faut de l XP pour atteindre le niveau 2")
	SaveData.grant_account_xp(besoin)
	eq(SaveData.account_level(), 2, "le compte passe au niveau 2")

	# La barre repart d un palier a l autre : elle doit rester lisible.
	ok(SaveData.account_progress() >= 0.0 and SaveData.account_progress() <= 1.0,
		"l avancement vers le palier suivant est une fraction")

	var debloque: Array[AccountRewardDef] = SaveData.rewards_unlocked_at(2)
	ok(not debloque.is_empty(), "le niveau 2 debloque au moins une recompense")


## AUCUNE recompense de compte ne touche a la puissance : c est la regle qui
## protege les sept niveaux deja equilibres.
func _test_les_recompenses_sont_cosmetiques() -> void:
	for r: AccountRewardDef in ContentDB.rewards_list():
		ok(r.kind == GameEnums.RewardKind.TITLE or r.kind == GameEnums.RewardKind.AVATAR,
			"la recompense %s est cosmetique" % r.id)
		ok(r.display_name != "", "elle a un nom affichable")


## Un profil ecrit avant l ajout des defis doit se charger sans perdre sa campagne.
func _test_la_progression_survit_a_un_ancien_profil() -> void:
	SaveData.reset_profile()
	# Profil d avant : ni compte, ni defis.
	var ancien: Dictionary = {
		"schema_version": 1,
		"profile": {
			"discovered_cards": ["spark"],
			"unlocked_legendaries": [],
			"campaign": {"current_node": "lvl_02", "unlocked_levels": ["lvl_01", "lvl_02"]},
			"levels": {}, "massacre_deck": [], "discovered_enemies": [],
		},
		"settings": {},
	}
	SaveData.load_from_dictionary(ancien)
	eq(SaveData.account_level(), 1, "le compte demarre au niveau 1")
	ok(SaveData.is_level_unlocked(&"lvl_02"), "la campagne d origine est conservee")
	SaveData.reset_profile()
