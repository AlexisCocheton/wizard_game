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
	# Chantier L : succes a rarete, contours, cosmetiques, banniere.
	_test_chaque_succes_a_une_rarete()
	_test_l_xp_suit_la_rarete()
	_test_le_contour_de_rarete_est_distinct()
	_test_les_cosmetiques_restent_cosmetiques()
	_test_les_trois_axes_de_cosmetiques_existent()
	_test_on_n_equipe_que_ce_qu_on_a_debloque()
	_test_la_banniere_suit_le_niveau()
	_test_les_succes_accomplis_survivent_a_la_migration()
	_test_un_succes_deja_merite_est_rattrape()
	_test_chaque_cosmetique_a_un_apercu()
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
##
## Ce test listait TITLE et AVATAR en dur. C etait la liste des types existants,
## pas la REGLE : ajouter un type cosmetique legitime (une robe, un chapeau, une
## tour) le faisait rougir, alors que la regle etait respectee. On teste donc
## desormais que le type appartient aux types COSMETIQUES connus — et la liste
## noire des types interdits est vide par construction, puisque RewardKind
## n admet que du cosmetique.
func _test_les_recompenses_sont_cosmetiques() -> void:
	var cosmetiques: Array[int] = [
		GameEnums.RewardKind.TITLE, GameEnums.RewardKind.AVATAR,
		GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
		GameEnums.RewardKind.TOWER,
	]
	# Le garde-fou qui compte vraiment : si quelqu un ajoute un type a l enum
	# sans le declarer cosmetique ici, ce test rougit et la question se pose.
	eq(GameEnums.RewardKind.size(), cosmetiques.size(),
		"tous les types de recompense sont declares cosmetiques")
	for r: AccountRewardDef in ContentDB.rewards_list():
		ok(cosmetiques.has(r.kind), "la recompense %s est cosmetique" % r.id)
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


## --- SUCCES A RARETE (chantier L) ---
##
## Les "defis" sont devenus des SUCCES ranges par rarete. Le nom interne reste
## ChallengeDef : renommer la classe aurait casse les .tres deja ecrits sur les
## profils, et le type porte le meme sens. Seule la vitrine change de mot.
##
## La rarete n est pas decorative : c est ELLE qui fixe l XP verse. Un succes
## legendaire qui rapporterait autant qu un commun rendrait la rarete mensongere.


## Chaque succes porte une rarete valide, et les quatre raretes existent.
func _test_chaque_succes_a_une_rarete() -> void:
	var vues: Dictionary = {}
	for c: ChallengeDef in ContentDB.challenges_list():
		ok(c.rarity >= GameEnums.Rarity.COMMON and c.rarity <= GameEnums.Rarity.LEGENDARY,
			"le succes %s a une rarete valide" % c.id)
		vues[c.rarity] = true
	for r in [GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY]:
		ok(vues.has(r), "la rarete %s a au moins un succes" % GameEnums.rarity_name(r))


## L XP suit la rarete : un cran plus rare paie STRICTEMENT plus. Exprime en
## rapport entre paliers, pas en valeurs figees, pour ne pas bloquer le reglage.
func _test_l_xp_suit_la_rarete() -> void:
	var precedent: int = 0
	for r in [GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY]:
		var xp: int = ChallengeDef.xp_for_rarity(r)
		ok(xp > precedent, "la rarete %s paie plus que la precedente" % GameEnums.rarity_name(r))
		precedent = xp
	# Et chaque .tres respecte bien le bareme : sinon la rarete affichee ment.
	for c: ChallengeDef in ContentDB.challenges_list():
		eq(c.xp_reward, ChallengeDef.xp_for_rarity(c.rarity),
			"le succes %s paie l XP de sa rarete" % c.id)


## Un contour de rarete existe pour les quatre raretes, et il est VISIBLE :
## une bordure de 0 px ne se voit pas, et deux raretes de meme couleur ne
## distinguent rien. C est la demande "une couleur de contour par rarete".
func _test_le_contour_de_rarete_est_distinct() -> void:
	var couleurs: Array[Color] = []
	for r in [GameEnums.Rarity.COMMON, GameEnums.Rarity.RARE,
			GameEnums.Rarity.EPIC, GameEnums.Rarity.LEGENDARY]:
		var sb: StyleBoxFlat = UiTheme.rarity_border(r)
		ok(sb != null, "la rarete %s a un contour" % GameEnums.rarity_name(r))
		if sb == null:
			continue
		ok(sb.border_width_left >= 4, "le contour de %s est assez epais pour se voir"
			% GameEnums.rarity_name(r))
		couleurs.append(sb.border_color)
	for i in couleurs.size():
		for j in range(i + 1, couleurs.size()):
			ok(couleurs[i] != couleurs[j], "deux raretes n ont pas le meme contour")


## --- COSMETIQUES ---
##
## Le compte ne donne QUE du cosmetique. Cette regle protege l equilibrage mesure
## des sept niveaux : un compte qui rendrait le mage plus fort avantagerait qui
## joue beaucoup, pas qui joue bien. Les nouveaux types (robe, chapeau, tour) ne
## changent QUE des couleurs et des textures — aucune stat.
func _test_les_cosmetiques_restent_cosmetiques() -> void:
	var permis: Array[int] = [
		GameEnums.RewardKind.TITLE, GameEnums.RewardKind.AVATAR,
		GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
		GameEnums.RewardKind.TOWER,
	]
	for r: AccountRewardDef in ContentDB.rewards_list():
		ok(permis.has(r.kind), "la recompense %s est d un type cosmetique" % r.id)
		# Un cosmetique equipable doit designer une texture, sinon il ne peut
		# rien changer a l ecran et ne serait qu un titre deguise.
		if r.kind in [GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
				GameEnums.RewardKind.TOWER]:
			ok(r.texture_name != "", "le cosmetique %s designe une texture" % r.id)


## Les trois axes demandes existent bel et bien dans le catalogue.
func _test_les_trois_axes_de_cosmetiques_existent() -> void:
	var par_type: Dictionary = {}
	for r: AccountRewardDef in ContentDB.rewards_list():
		par_type[r.kind] = int(par_type.get(r.kind, 0)) + 1
	for k in [GameEnums.RewardKind.MAGE_COLOR, GameEnums.RewardKind.HAT,
			GameEnums.RewardKind.TOWER]:
		ok(int(par_type.get(k, 0)) >= 2,
			"il y a au moins deux choix pour le type %d (defaut + debloque)" % k)


## Equiper : seul un cosmetique DEBLOQUE peut etre porte, et la lecture rend
## toujours quelque chose — le mage doit s afficher meme sur un profil neuf.
func _test_on_n_equipe_que_ce_qu_on_a_debloque() -> void:
	SaveData.reset_profile()
	var K := GameEnums.RewardKind
	# Profil neuf : un defaut est servi pour chaque axe, jamais une chaine vide.
	for k in [K.MAGE_COLOR, K.HAT, K.TOWER]:
		ok(SaveData.equipped_cosmetic(k) != "",
			"un profil neuf a deja un cosmetique par defaut pour le type %d" % k)

	# Un cosmetique hors de portee du niveau se refuse.
	var haut: AccountRewardDef = null
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r.kind == K.MAGE_COLOR and r.at_level > 1:
			haut = r
	ok(haut != null, "il existe un cosmetique de mage a debloquer")
	if haut != null:
		not_ok(SaveData.equip_cosmetic(haut.id), "un cosmetique verrouille ne s equipe pas")
		SaveData.grant_account_xp(SaveData.account_xp_for_level(haut.at_level))
		ok(SaveData.equip_cosmetic(haut.id), "une fois le niveau atteint, il s equipe")
		eq(SaveData.equipped_cosmetic(K.MAGE_COLOR), haut.texture_name,
			"et c est bien lui que le jeu lira")
	SaveData.reset_profile()


## La banniere de titre change avec le niveau, et un niveau tres haut ne sort
## pas de la liste : le dernier palier tient pour toujours.
func _test_la_banniere_suit_le_niveau() -> void:
	var vues: Dictionary = {}
	for n in [1, 3, 5, 8, 12, 99]:
		var b: String = UiTheme.banner_for_level(n)
		ok(b != "", "le niveau %d a une banniere" % n)
		vues[b] = true
	ok(vues.size() >= 3, "la banniere change au moins trois fois sur la progression")
	eq(UiTheme.banner_for_level(99), UiTheme.banner_for_level(999),
		"au-dela du dernier palier la banniere ne change plus")


## Les succes deja accomplis sur un ANCIEN profil ne se perdent pas : c est la
## regle qui fait qu une migration est une migration et pas une remise a zero.
func _test_les_succes_accomplis_survivent_a_la_migration() -> void:
	SaveData.reset_profile()
	var ancien: Dictionary = {
		"schema_version": 1,
		"profile": {
			"discovered_cards": ["spark"],
			"unlocked_legendaries": [],
			"campaign": {"current_node": "lvl_02", "unlocked_levels": ["lvl_01", "lvl_02"]},
			"levels": {}, "massacre_deck": [], "discovered_enemies": [],
			# Un profil d avant les cosmetiques : le compte existe, avec des
			# defis deja valides, mais aucune cle "cosmetics".
			"account": {"level": 4, "xp": 950,
				"challenges": ["ch_first_win", "ch_slayer_100"], "stats": {}},
		},
		"settings": {},
	}
	SaveData.load_from_dictionary(ancien)
	eq(SaveData.account_level(), 4, "le niveau de compte est conserve")
	ok(SaveData.is_challenge_done(&"ch_first_win"), "le premier succes est conserve")
	ok(SaveData.is_challenge_done(&"ch_slayer_100"), "le second aussi")
	# Et la nouvelle couche cosmetique se remplit toute seule, sans effacer rien.
	ok(SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT) != "",
		"un profil d avant les cosmetiques recoit les defauts")
	SaveData.reset_profile()


## Le defaut que ce test empeche de revenir : _check() ne valide un succes qu au
## moment ou le compteur FRANCHIT le seuil. Un succes ajoute au catalogue apres
## coup n etait donc jamais accompli, meme chez un joueur tres au-dela de la
## cible — il restait affiche avec sa barre pleine parmi les non accomplis. Le
## cas s est vu a l ecran : "Le mur" a 25 / 25, non accompli.
func _test_un_succes_deja_merite_est_rattrape() -> void:
	SaveData.reset_profile()
	# Un profil qui a DEJA tue 1000 monstres, mais dont aucun succes de chasse
	# n est valide : exactement l etat d un joueur au moment ou on ajoute un
	# succes au catalogue.
	var stats: Dictionary = SaveData.challenge_stats()
	stats["enemies_killed"] = 1000
	SaveData.set_challenge_stats(stats)
	for c: ChallengeDef in ContentDB.challenges_list():
		if c.track_key == &"enemies_killed":
			not_ok(SaveData.is_challenge_done(c.id),
				"avant rattrapage, %s n est pas valide" % c.id)

	ChallengeTracker.rattraper()

	var vus: int = 0
	for c: ChallengeDef in ContentDB.challenges_list():
		if c.track_key != &"enemies_killed":
			continue
		if c.target <= 1000:
			vus += 1
			ok(SaveData.is_challenge_done(c.id),
				"%s (cible %d) est rattrape" % [c.id, c.target])
		else:
			not_ok(SaveData.is_challenge_done(c.id),
				"%s (cible %d) reste a faire" % [c.id, c.target])
	ok(vus >= 2, "plusieurs paliers de chasse sont rattrapes d un coup (%d)" % vus)

	# Le rattrapage ne donne RIEN qui ne soit merite : un compteur a zero ne
	# valide aucun succes, sinon le profil se remplirait tout seul.
	SaveData.reset_profile()
	ChallengeTracker.rattraper()
	ok(SaveData.completed_challenges().is_empty(),
		"sur un profil neuf le rattrapage ne valide rien")
	SaveData.reset_profile()


## L ecran des cosmetiques ne se lit pas en texte : "Robe d encre" ne dit pas sa
## couleur. Chaque piece doit donc rendre une vignette, sinon le joueur choisit
## a l aveugle — c est le seul objet de cet ecran.
##
## Le recadrage est verifie en plus de la presence : un apercu qui rend la case
## ENTIERE de 192 px donne une silhouette de 58 px perdue dans le vide, ce qui
## passe tous les tests de presence sans rien montrer.
func _test_chaque_cosmetique_a_un_apercu() -> void:
	var vus: int = 0
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r == null:
			continue
		if r.kind != GameEnums.RewardKind.MAGE_COLOR 				and r.kind != GameEnums.RewardKind.HAT 				and r.kind != GameEnums.RewardKind.TOWER:
			continue
		vus += 1
		var apercu: Texture2D = UiTheme.cosmetic_preview(r.kind, r.texture_name)
		ok(apercu != null, "%s a un apercu (%s)" % [r.id, r.texture_name])
		if apercu == null:
			continue
		ok(apercu.get_width() > 0 and apercu.get_height() > 0,
			"%s : l apercu n est pas vide" % r.id)
		if r.kind != GameEnums.RewardKind.TOWER:
			ok(apercu.get_width() < UiTheme.MAGE_FRAME,
				"%s : l apercu est RECADRE sur le mage, pas la case entiere"
				% r.id)
	ok(vus >= 10, "les trois axes de cosmetiques sont couverts (%d pieces)" % vus)
	# Une piece inconnue ne doit pas faire planter l ecran : il retombe sur le
	# texte seul, ce qui reste utilisable.
	eq(UiTheme.cosmetic_preview(GameEnums.RewardKind.HAT, "feuille_absente"), null,
		"une feuille absente rend null plutot que de planter")
