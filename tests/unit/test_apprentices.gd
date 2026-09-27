extends TestCase
## LES APPRENTIS DU MAGE — changer de personnage en recompense de niveau de compte.
##
## Ce qui est verrouille ici :
##   - un profil neuf, et surtout un profil ANCIEN, se chargent avec le mage ;
##   - un apprenti non gagne ne se choisit pas, ni a l ecriture ni a la lecture ;
##   - le choix survit a la sauvegarde ;
##   - un apprenti se joue SANS CODE : feuille, taille, pieds, incantation et
##     vignette se deduisent de la seule cle d animation ;
##   - robe et chapeau sont mis de cote, pas perdus, et l ecran le dit.
##
## Aucun nombre en dur : les niveaux viennent des recompenses, les tailles de
## MAGE_CROP / MAGE_SCALE, les apprentis de ContentDB. Un sixieme apprenti
## ajoute demain passe dans chacune de ces boucles sans toucher au test.

const MAGE: String = AccountRewardDef.CHARACTER_MAGE


func get_suite_name() -> String:
	return "apprentices"


func run() -> void:
	SaveData.reset_profile()
	_test_le_catalogue_a_un_mage_et_des_apprentis()
	_test_un_profil_neuf_joue_le_mage()
	_test_un_ancien_profil_se_charge_avec_le_mage()
	_test_un_apprenti_non_gagne_n_est_pas_selectionnable()
	_test_un_apprenti_non_merite_n_est_pas_joue()
	_test_le_choix_persiste()
	_test_robe_et_chapeau_sont_mis_de_cote_pas_perdus()
	_test_chaque_apprenti_se_joue_sans_code()
	_test_la_vignette_est_recadree()
	_test_aucun_apprenti_ne_porte_un_monstre()
	_test_l_onglet_grise_robe_et_chapeau()
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


func _apprentis() -> Array[AccountRewardDef]:
	var out: Array[AccountRewardDef] = []
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.is_apprentice():
			out.append(r)
	return out


func _reward_de(kind: int, texture: String) -> AccountRewardDef:
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.kind == kind and r.texture_name == texture:
			return r
	return null


func _monter_au_niveau(n: int) -> void:
	SaveData.grant_account_xp(maxi(0, SaveData.account_xp_for_level(n) - SaveData.account_xp()))


func _test_le_catalogue_a_un_mage_et_des_apprentis() -> void:
	var mage: AccountRewardDef = _reward_de(GameEnums.RewardKind.CHARACTER, MAGE)
	ok(mage != null, "le mage est un choix de la grille PERSONNAGE")
	if mage != null:
		eq(mage.at_level, 1, "le mage est disponible des le niveau 1")
		not_ok(mage.is_apprentice(), "le mage n est pas un apprenti")
		ok(mage.is_equippable(), "on peut revenir au mage")
	ok(not _apprentis().is_empty(), "au moins un apprenti est a gagner")
	for r in _apprentis():
		ok(r.at_level > 1, "%s se GAGNE : il n est pas donne au niveau 1" % r.id)
		ok(r.is_equippable(), "%s s equipe" % r.id)


func _test_un_profil_neuf_joue_le_mage() -> void:
	SaveData.reset_profile()
	eq(SaveData.equipped_character(), MAGE, "un profil neuf joue le mage")
	not_ok(SaveData.is_apprentice_equipped(), "sans apprenti")
	eq(UiTheme.hero_key(), MAGE, "le combat affiche le mage")
	ok(UiTheme.hero_frames() == UiTheme.mage_frames(),
		"avec les animations du mage, robe et chapeau compris")
	eq(UiTheme.hero_cast_anim(UiTheme.hero_frames()), &"cast",
		"le mage incante avec sa propre pose")
	var pose: Dictionary = UiTheme.hero_pose()
	feq(float(pose["scale"]), UiTheme.MAGE_SCALE, "le mage garde son echelle d origine")
	feq(float(pose["y"]), UiTheme.MAGE_Y, "et sa hauteur d origine")


## LA MIGRATION. Deux profils d avant les apprentis : l un avait deja choisi robe,
## chapeau et tour, l autre ne connaissait meme pas les cosmetiques. Les deux se
## chargent avec le mage, sans rien perdre — et la cle est ECRITE dans le profil,
## pas seulement rattrapee a la lecture.
func _test_un_ancien_profil_se_charge_avec_le_mage() -> void:
	var haut: int = SaveData.tester_account_level()
	var robe: AccountRewardDef = null
	var chapeau: AccountRewardDef = null
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r.kind == GameEnums.RewardKind.MAGE_COLOR and r.at_level > 1:
			robe = r
		if r.kind == GameEnums.RewardKind.HAT and r.at_level > 1:
			chapeau = r
	ok(robe != null and chapeau != null, "le catalogue a une robe et un chapeau a gagner")
	if robe == null or chapeau == null:
		return

	# (a) Un profil HABILLE, au plus haut niveau : il aurait droit a tous les
	# apprentis, la migration ne doit pourtant pas en choisir un a sa place.
	var habille: Dictionary = {
		"schema_version": 1,
		"profile": {
			"discovered_cards": ["spark"],
			"campaign": {"current_node": "lvl_02", "unlocked_levels": ["lvl_01", "lvl_02"]},
			"account": {"level": haut, "xp": SaveData.account_xp_for_level(haut),
				"challenges": [], "stats": {}},
			"cosmetics": {"mage_color": robe.texture_name, "hat": chapeau.texture_name,
				"tower": "tower_sand"},
		},
		"settings": {},
	}
	SaveData.load_from_dictionary(habille)
	eq(SaveData.equipped_character(), MAGE, "un ancien profil habille joue le mage")
	eq(SaveData.equipped_cosmetic(GameEnums.RewardKind.MAGE_COLOR), robe.texture_name,
		"sa robe est conservee")
	eq(SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT), chapeau.texture_name,
		"son chapeau aussi")
	eq(SaveData.equipped_cosmetic(GameEnums.RewardKind.TOWER), "tower_sand",
		"et sa tour")
	var ecrit: Dictionary = SaveData.to_dictionary()
	eq(String(ecrit["profile"]["cosmetics"].get("character", "")), MAGE,
		"la migration ECRIT le personnage dans le profil")
	ok(SaveData.is_level_unlocked(&"lvl_02"), "la campagne n est pas touchee")

	# (b) Un profil d avant les cosmetiques : aucune cle "cosmetics".
	var nu: Dictionary = {
		"schema_version": 1,
		"profile": {"discovered_cards": [], "account": {"level": 1, "xp": 0,
			"challenges": [], "stats": {}}},
		"settings": {},
	}
	SaveData.load_from_dictionary(nu)
	eq(SaveData.equipped_character(), MAGE, "un profil sans cosmetiques joue le mage")
	eq(String(SaveData.to_dictionary()["profile"]["cosmetics"].get("character", "")), MAGE,
		"et recoit la cle lui aussi")
	SaveData.reset_profile()


func _test_un_apprenti_non_gagne_n_est_pas_selectionnable() -> void:
	for r in _apprentis():
		SaveData.reset_profile()
		_monter_au_niveau(r.at_level - 1)
		ok(SaveData.account_level() < r.at_level,
			"le compte est juste sous le palier de %s" % r.id)
		not_ok(SaveData.equip_cosmetic(r.id), "%s ne s equipe pas avant son palier" % r.id)
		eq(SaveData.equipped_character(), MAGE, "le mage reste en place")
		_monter_au_niveau(r.at_level)
		ok(SaveData.equip_cosmetic(r.id), "%s s equipe une fois le palier atteint" % r.id)
		eq(SaveData.equipped_character(), r.texture_name, "et c est lui qui est joue")
	SaveData.reset_profile()


## La LECTURE reverifie le droit. Deux chemins par lesquels un apprenti non gagne
## finit dans le profil sans passer par equip_cosmetic() : le mode testeur qu on
## eteint, et un profil ecrit a la main.
func _test_un_apprenti_non_merite_n_est_pas_joue() -> void:
	for r in _apprentis():
		SaveData.reset_profile()
		SaveData.set_tester_mode(true)
		ok(SaveData.equip_cosmetic(r.id), "%s s equipe en mode testeur" % r.id)
		eq(SaveData.equipped_character(), r.texture_name, "et il est joue")
		SaveData.set_tester_mode(false)
		eq(SaveData.equipped_character(), MAGE,
			"%s : mode testeur eteint, on revient au mage" % r.id)
		eq(UiTheme.hero_key(), MAGE, "le combat aussi")

		SaveData.reset_profile()
		var triche: Dictionary = SaveData.to_dictionary()
		triche["profile"]["cosmetics"]["character"] = r.texture_name
		SaveData.load_from_dictionary(triche)
		eq(SaveData.equipped_character(), MAGE,
			"%s ecrit a la main dans un profil de niveau 1 : ignore" % r.id)

	# Une cle inconnue (feuille renommee, apprenti retire) : le mage, jamais un
	# personnage invisible.
	SaveData.reset_profile()
	var casse: Dictionary = SaveData.to_dictionary()
	casse["profile"]["cosmetics"]["character"] = "sorciere_disparue"
	SaveData.load_from_dictionary(casse)
	eq(SaveData.equipped_character(), MAGE, "une cle inconnue rend le mage")
	SaveData.reset_profile()


## Le choix passe par le JSON ecrit sur le disque et revient a l identique.
func _test_le_choix_persiste() -> void:
	for r in _apprentis():
		SaveData.reset_profile()
		_monter_au_niveau(r.at_level)
		ok(SaveData.equip_cosmetic(r.id), "%s s equipe" % r.id)
		var texte: String = JSON.stringify(SaveData.to_dictionary())
		SaveData.reset_profile()
		eq(SaveData.equipped_character(), MAGE, "profil remis a zero : le mage")
		var relu: Variant = JSON.parse_string(texte)
		ok(relu is Dictionary, "le profil ecrit se relit")
		if not (relu is Dictionary):
			continue
		SaveData.load_from_dictionary(relu)
		eq(SaveData.equipped_character(), r.texture_name,
			"%s est toujours la apres sauvegarde et rechargement" % r.id)
		ok(SaveData.is_apprentice_equipped(), "et compte comme apprenti")
	SaveData.reset_profile()


## Un apprenti ne porte ni la robe ni le chapeau (ce sont des teintes de la
## feuille du mage), mais ils restent CHOISIS : reprendre le mage les rend.
func _test_robe_et_chapeau_sont_mis_de_cote_pas_perdus() -> void:
	var apprentis: Array[AccountRewardDef] = _apprentis()
	var mage: AccountRewardDef = _reward_de(GameEnums.RewardKind.CHARACTER, MAGE)
	if apprentis.is_empty() or mage == null:
		return
	var r: AccountRewardDef = apprentis[0]
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	var chapeau: AccountRewardDef = null
	for c: AccountRewardDef in ContentDB.rewards_list():
		if c.kind == GameEnums.RewardKind.HAT and c.at_level > 1:
			chapeau = c
	if chapeau == null:
		SaveData.set_tester_mode(false)
		return
	SaveData.equip_cosmetic(chapeau.id)
	var feuille_du_mage: String = UiTheme.mage_sheet_key()
	eq(feuille_du_mage, chapeau.texture_name, "le mage porte le chapeau choisi")

	ok(SaveData.equip_cosmetic(r.id), "on prend l apprenti")
	ok(UiTheme.hero_frames() != UiTheme.mage_frames(),
		"le combat n affiche plus le mage")
	ok(UiTheme.hero_frames() == AnimCatalog.frames(StringName(r.texture_name)),
		"mais la feuille de l apprenti, sans teinte")
	eq(UiTheme.mage_sheet_key(), feuille_du_mage, "le chapeau reste choisi")

	ok(SaveData.equip_cosmetic(mage.id), "on reprend le mage")
	eq(SaveData.equipped_character(), MAGE, "c est le mage")
	ok(UiTheme.hero_frames() == UiTheme.mage_frames(), "le combat le montre")
	eq(UiTheme.mage_sheet_key(), feuille_du_mage, "avec son chapeau, intact")
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


## Ajouter un apprenti = une recompense + une cle d animation. Tout le reste doit
## se deduire de la feuille : on le verifie pour CHAQUE apprenti du catalogue.
##
## LA TAILLE. Les cases different (192 px pour le mage, 48 pour la sorciere
## bleue) et l occupation aussi : reprendre l echelle du mage donnerait une
## apprentie minuscule. Ce que le joueur doit voir, c est la meme hauteur de
## personnage, pieds au meme endroit.
func _test_chaque_apprenti_se_joue_sans_code() -> void:
	var etalon := Rect2(UiTheme.MAGE_CROP)
	var hauteur_mage: float = etalon.size.y * UiTheme.MAGE_SCALE
	var pieds_mage: float = UiTheme.MAGE_Y \
		+ (etalon.end.y - UiTheme.MAGE_FRAME * 0.5) * UiTheme.MAGE_SCALE
	for r in _apprentis():
		var cle: StringName = StringName(r.texture_name)
		var sf: SpriteFrames = AnimCatalog.frames(cle)
		ok(sf != null and sf.has_animation(&"idle") and sf.get_frame_count(&"idle") > 0,
			"%s a une pose d attente" % r.id)
		if sf == null:
			continue
		var geste: StringName = UiTheme.hero_cast_anim(sf)
		ok(geste != &"idle", "%s a un geste d incantation (%s)" % [r.id, geste])

		var vu: Rect2 = UiTheme.hero_visible_rect(r.texture_name)
		ok(vu.size.x > 0.0 and vu.size.y > 0.0, "%s : silhouette mesuree" % r.id)
		var cellule: float = float(AnimCatalog.frame_px(cle))
		ok(vu.size.y <= cellule and vu.end.y <= cellule + 0.01,
			"%s : la silhouette tient dans sa case" % r.id)
		var pose: Dictionary = UiTheme.hero_pose(r.texture_name)
		var s: float = float(pose["scale"])
		# A 1 px pres : l ecart de hauteur entre le mage et l apprenti.
		feq(vu.size.y * s, hauteur_mage,
			"%s a la hauteur du mage a l ecran" % r.id, 1.0)
		feq(float(pose["y"]) + (vu.end.y - cellule * 0.5) * s, pieds_mage,
			"%s a les pieds au niveau de ceux du mage" % r.id, 1.0)
		ok(not is_equal_approx(s, UiTheme.MAGE_SCALE),
			"%s : l echelle est RECALCULEE, pas reprise du mage" % r.id)


## L apercu de la grille PERSONNAGE : recadre sur la silhouette, jamais la case
## entiere, sinon le personnage est un point au milieu du vide (lecon du
## chantier L). Le mage se montre avec la robe qu il porte.
func _test_la_vignette_est_recadree() -> void:
	SaveData.reset_profile()
	var mage_vignette: Texture2D = UiTheme.cosmetic_preview(
		GameEnums.RewardKind.CHARACTER, MAGE)
	ok(mage_vignette != null, "le mage a une vignette")
	if mage_vignette != null:
		ok(mage_vignette.get_width() < UiTheme.MAGE_FRAME,
			"la vignette du mage est recadree")
	for r in _apprentis():
		var v: Texture2D = UiTheme.cosmetic_preview(r.kind, r.texture_name)
		ok(v != null, "%s a une vignette" % r.id)
		if v == null:
			continue
		var cellule: int = AnimCatalog.frame_px(StringName(r.texture_name))
		ok(v.get_width() > 0 and v.get_height() > 0, "%s : vignette non vide" % r.id)
		ok(v.get_width() < cellule, "%s : recadree en largeur (%d < %d)"
			% [r.id, v.get_width(), cellule])
		ok(v.get_height() <= cellule, "%s : pas plus haute que la case" % r.id)
	eq(UiTheme.cosmetic_preview(GameEnums.RewardKind.CHARACTER, "feuille_absente"), null,
		"une feuille absente rend null (l ecran retombe sur le texte)")


## Doublon voulu de l AUDIT : le test nomme la regle la ou on la cherche.
func _test_aucun_apprenti_ne_porte_un_monstre() -> void:
	for r in _apprentis():
		for e: EnemyDef in ContentDB.enemies.values():
			if e == null:
				continue
			ok(String(e.anim_key) != r.texture_name,
				"le monstre %s ne porte pas la feuille de l apprenti %s" % [e.id, r.id])


## L ecran grise robe et chapeau quand un apprenti est joue, avec une phrase —
## il ne les cache pas. Et un apprenti non gagne y est un bouton INACTIF.
func _test_l_onglet_grise_robe_et_chapeau() -> void:
	var K := GameEnums.RewardKind
	var apprentis: Array[AccountRewardDef] = _apprentis()
	if apprentis.is_empty():
		return
	SaveData.reset_profile()
	var panel := ProfilePanel.new()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child(panel)
	panel.show_section(ProfilePanel.Section.COSMETICS)

	# Profil neuf : le mage, rien de grise, apprentis verrouilles.
	ok(panel.find_child("ApprenticeNote", true, false) == null,
		"avec le mage, pas de phrase d avertissement")
	var perso: Node = panel.find_child("Group_%d" % K.CHARACTER, true, false)
	ok(perso != null, "la grille PERSONNAGE est affichee")
	if perso != null:
		var inactifs: int = 0
		var actifs: int = 0
		for b in perso.get_children():
			if b is Button:
				if (b as Button).disabled:
					inactifs += 1
				else:
					actifs += 1
		eq(inactifs, apprentis.size(), "chaque apprenti non gagne est un bouton inactif")
		ok(actifs >= 1, "le mage, lui, est choisissable")
	var robe: CanvasItem = panel.find_child("Group_%d" % K.MAGE_COLOR, true, false)
	ok(robe != null and is_equal_approx(robe.modulate.a, 1.0), "la robe est pleinement visible")

	# Un apprenti gagne et choisi : robe et chapeau palissent, la tour non.
	_monter_au_niveau(apprentis[0].at_level)
	SaveData.equip_cosmetic(apprentis[0].id)
	panel.refresh()
	ok(panel.find_child("ApprenticeNote", true, false) != null,
		"une phrase dit pourquoi robe et chapeau sont grises")
	for k in [K.MAGE_COLOR, K.HAT]:
		var g: CanvasItem = panel.find_child("Group_%d" % k, true, false)
		ok(g != null, "la grille %d reste AFFICHEE" % k)
		if g != null:
			ok(g.modulate.a < 1.0, "la grille %d est grisee" % k)
	var tour: CanvasItem = panel.find_child("Group_%d" % K.TOWER, true, false)
	ok(tour != null and is_equal_approx(tour.modulate.a, 1.0),
		"la tour s applique aussi a l apprenti : elle n est pas grisee")

	root.remove_child(panel)
	panel.free()
	SaveData.reset_profile()
