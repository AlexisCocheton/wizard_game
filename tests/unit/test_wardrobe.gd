extends TestCase
## LA GARDE-ROBE DE LA VAGUE 8 : chapeaux dessines poses image par image, tenues
## des apprentis, tours mesurees, portraits, et le plafond d XP du compte.
##
## Ce qui est verrouille ici :
##   - chapeau et robe se CUMULENT (deux axes, deux lectures) ;
##   - chaque image jouee du mage a un ancrage de tete, et il SUIT la tete ;
##   - un vieux profil (chapeaux reteints) se charge sans perte de droit ;
##   - une tenue d apprenti est a lui, verifiee a l ecriture ET a la lecture ;
##   - la tour d origine est posee EXACTEMENT comme avant la vague 8 ;
##   - aucune recompense n est hors d atteinte du compte.
##
## Les nombres viennent des donnees (WardrobeData, ContentDB, AnimCatalog), sauf
## les faits HISTORIQUES (ancienne pose de la tour, anciens paliers des
## chapeaux) : ce sont eux que le test protege, ils doivent etre ecrits en dur.

const MAGE: String = AccountRewardDef.CHARACTER_MAGE
const NU: String = AccountRewardDef.HAT_NONE


func get_suite_name() -> String:
	return "wardrobe"


func run() -> void:
	SaveData.reset_profile()
	_test_atlas_des_chapeaux()
	_test_chaque_image_du_mage_a_un_ancrage()
	_test_l_ancrage_suit_la_tete()
	_test_chapeau_et_robe_se_cumulent()
	_test_les_anciens_chapeaux_migrent()
	_test_les_tenues_des_apprentis()
	_test_une_tenue_non_meritee_n_est_pas_portee()
	_test_les_tours()
	_test_la_tour_d_origine_ne_bouge_pas()
	_test_les_portraits()
	_test_tout_est_atteignable()
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


func _rewards(kind: int) -> Array[AccountRewardDef]:
	var out: Array[AccountRewardDef] = []
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.kind == kind:
			out.append(r)
	return out


func _monter_au_niveau(n: int) -> void:
	SaveData.grant_account_xp(maxi(0, SaveData.account_xp_for_level(n) - SaveData.account_xp()))


## Un fichier se CHARGE (pas seulement exists() : le cache d import survit au PNG).
func _charge(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as Texture2D


func _test_atlas_des_chapeaux() -> void:
	var t: Texture2D = _charge(WardrobeData.HAT_SHEET)
	ok(t != null, "l atlas des chapeaux se charge")
	if t != null:
		eq(t.get_width(), WardrobeData.HATS.size() * WardrobeData.HAT_CELL.x,
			"une case par chapeau, ni plus ni moins")
		eq(t.get_height(), WardrobeData.HAT_CELL.y, "une seule ligne")
	var vus: Dictionary = {}
	for r in _rewards(GameEnums.RewardKind.HAT):
		ok(r.texture_name == NU or WardrobeData.HATS.has(r.texture_name),
			"%s designe un chapeau dessine (%s)" % [r.id, r.texture_name])
		vus[r.texture_name] = r.id
		if r.texture_name != NU:
			ok(UiTheme.hat_texture(r.texture_name) != null, "%s a sa case" % r.id)
	for h in WardrobeData.HATS:
		ok(vus.has(h), "le chapeau %s est une recompense : dessine pour etre porte" % h)
	ok(vus.has(NU), "la tete nue reste un choix")
	var nu: AccountRewardDef = null
	for r in _rewards(GameEnums.RewardKind.HAT):
		if r.texture_name == NU:
			nu = r
	ok(nu != null and nu.at_level == 1, "la tete nue est donnee au niveau 1")
	eq(SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT), NU, "un profil neuf est tete nue")


## Chaque image de chaque animation JOUEE par une robe du mage a son ancrage :
## une image sans ancrage cacherait le chapeau le temps d un clignement.
func _test_chaque_image_du_mage_a_un_ancrage() -> void:
	for robe: String in WardrobeData.HAT_RIGS:
		ok(AnimCatalog.has(StringName(robe)), "%s est au catalogue" % robe)
		var robe_r: AccountRewardDef = null
		for r in _rewards(GameEnums.RewardKind.MAGE_COLOR):
			if r.texture_name == robe:
				robe_r = r
		ok(robe_r != null, "%s se gagne comme robe" % robe)
		var sf: SpriteFrames = AnimCatalog.frames(StringName(robe))
		if sf == null:
			continue
		for anim: StringName in [&"idle", &"walk", &"cast"]:
			ok(sf.has_animation(anim), "%s a l animation %s" % [robe, anim])
			for i in sf.get_frame_count(anim):
				var p: Vector2 = UiTheme.hat_offset(robe, anim, i)
				ok(p != Vector2.INF, "%s %s image %d a un ancrage" % [robe, anim, i])
			var rig: String = UiTheme.hat_rig(robe)
			var pts: Array = WardrobeData.HAT_ANCHORS[rig][String(anim)]
			eq(pts.size(), sf.get_frame_count(anim),
				"%s %s : autant d ancrages que d images" % [robe, anim])
	# Toutes les robes gagnables du mage ont un gabarit : sinon le chapeau
	# disparaitrait en changeant de robe.
	for r in _rewards(GameEnums.RewardKind.MAGE_COLOR):
		if not r.is_apprentice_outfit():
			ok(UiTheme.hat_rig(r.texture_name) != "", "%s porte les chapeaux" % r.id)


## L ancrage est MESURE image par image : la tete monte et descend en attente et
## part en arriere pendant l incantation. Un ancrage fixe la laisserait sous un
## chapeau immobile.
func _test_l_ancrage_suit_la_tete() -> void:
	var ys: Dictionary = {}
	for anim: StringName in [&"idle", &"cast"]:
		for i in AnimCatalog.frames(&"monk_blue").get_frame_count(anim):
			ys[UiTheme.hat_offset("monk_blue", anim, i).y] = true
	ok(ys.size() >= 3, "le sommet de la tete prend plusieurs hauteurs (%d)" % ys.size())
	var debout: Vector2 = UiTheme.hat_offset("monk_blue", &"idle", 0)
	var renverse: Vector2 = UiTheme.hat_offset("monk_blue", &"cast", 4)
	ok(renverse.y > debout.y + 2.0,
		"tete renversee pendant le sort : le chapeau descend (%.0f -> %.0f)" % [debout.y, renverse.y])
	# Le sommet de la tete est dans la moitie haute de la silhouette du mage.
	var crop := Rect2(UiTheme.MAGE_CROP)
	var y_case: float = debout.y + UiTheme.MAGE_FRAME * 0.5
	ok(y_case >= crop.position.y - 2.0 and y_case <= crop.get_center().y,
		"l ancrage est en haut du mage (%.0f dans %.0f..%.0f)" % [y_case, crop.position.y, crop.end.y])
	eq(UiTheme.hat_offset("bluewitch", &"idle", 0), Vector2.INF,
		"une feuille sans gabarit n a pas d ancrage (pas de chapeau mal pose)")


func _test_chapeau_et_robe_se_cumulent() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	for h in _rewards(GameEnums.RewardKind.HAT):
		for robe in _rewards(GameEnums.RewardKind.MAGE_COLOR):
			if robe.is_apprentice_outfit():
				continue
			SaveData.equip_cosmetic(h.id)
			SaveData.equip_cosmetic(robe.id)
			if UiTheme.hat_key() != h.texture_name or UiTheme.mage_sheet_key() != robe.texture_name:
				ok(false, "%s + %s ne se cumulent pas" % [h.id, robe.id])
				break
	ok(true, "chaque chapeau se porte avec chaque robe")
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


## LA MIGRATION. Les anciens chapeaux (feuilles reteintes) et leurs anciens
## paliers : un joueur qui en portait un garde un chapeau de la meme couleur, et
## jamais un chapeau d un palier superieur a celui qu il avait gagne.
func _test_les_anciens_chapeaux_migrent() -> void:
	const ANCIENS_PALIERS: Dictionary = {
		"monk_hat_crimson": 2, "monk_hat_emerald": 5, "monk_hat_violet": 8, "monk_hat_gold": 12,
	}
	for ancien: String in ANCIENS_PALIERS:
		var palier: int = int(ANCIENS_PALIERS[ancien])
		var vieux: Dictionary = {
			"schema_version": 1,
			"profile": {
				"account": {"level": palier, "xp": SaveData.account_xp_for_level(palier),
					"challenges": [], "stats": {}},
				"cosmetics": {"mage_color": "monk_purple", "hat": ancien, "tower": "tower_sand"},
			},
			"settings": {},
		}
		SaveData.load_from_dictionary(vieux)
		var nouveau: String = SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT)
		ok(WardrobeData.HATS.has(nouveau), "%s devient un chapeau dessine (%s)" % [ancien, nouveau])
		eq(String(SaveData.to_dictionary()["profile"]["cosmetics"]["hat"]), nouveau,
			"%s : la migration REECRIT la cle" % ancien)
		for r in _rewards(GameEnums.RewardKind.HAT):
			if r.texture_name == nouveau:
				ok(r.at_level <= palier, "%s -> %s (palier %d) : aucun droit invente"
					% [ancien, nouveau, r.at_level])
		eq(UiTheme.mage_sheet_key(), "monk_purple", "%s : la robe est gardee" % ancien)
		eq(UiTheme.hero_hat_key(), nouveau, "%s : et le combat pose le chapeau" % ancien)
	var nu_ancien: Dictionary = {"schema_version": 1, "profile": {"cosmetics": {"hat": "monk_blue"}},
		"settings": {}}
	SaveData.load_from_dictionary(nu_ancien)
	eq(SaveData.equipped_cosmetic(GameEnums.RewardKind.HAT), NU,
		"l ancien chapeau d origine (monk_blue) est la tete nue")
	var inconnu: Dictionary = {"schema_version": 1, "profile": {"cosmetics": {"hat": "chapeau_disparu"}},
		"settings": {}}
	SaveData.load_from_dictionary(inconnu)
	eq(UiTheme.hat_key(), NU, "un chapeau inconnu rend la tete nue, jamais un calque vide")
	SaveData.reset_profile()


func _test_les_tenues_des_apprentis() -> void:
	var apprentis: Dictionary = {}
	for r in _rewards(GameEnums.RewardKind.CHARACTER):
		if r.is_apprentice():
			apprentis[r.texture_name] = r
	var monstres: Dictionary = {}
	for e: EnemyDef in ContentDB.enemies.values():
		if e != null:
			monstres[String(e.anim_key)] = e.id
	var tenues: int = 0
	for r in _rewards(GameEnums.RewardKind.MAGE_COLOR):
		if not r.is_apprentice_outfit():
			continue
		tenues += 1
		ok(apprentis.has(r.for_character), "%s habille un apprenti du catalogue (%s)"
			% [r.id, r.for_character])
		if not apprentis.has(r.for_character):
			continue
		var maitre: AccountRewardDef = apprentis[r.for_character]
		ok(r.at_level >= maitre.at_level, "%s ne vient pas avant son apprenti" % r.id)
		var cle := StringName(r.texture_name)
		ok(AnimCatalog.has(cle), "%s : %s est au catalogue" % [r.id, cle])
		ok(not monstres.has(r.texture_name), "%s : aucun monstre ne porte %s" % [r.id, cle])
		eq(AnimCatalog.frame_px(cle), AnimCatalog.frame_px(StringName(r.for_character)),
			"%s : meme case que l apprenti (meme pose a l ecran)" % r.id)
		ok(AnimCatalog.has_anim(cle, "idle"), "%s a une pose d attente" % r.id)
		ok(AnimCatalog.has_anim(cle, "cast") or AnimCatalog.has_anim(cle, "attack"),
			"%s a un geste d incantation" % r.id)
	ok(tenues >= apprentis.size(), "chaque apprenti a au moins une teinte (%d tenues)" % tenues)

	# Equiper, porter, revenir a l origine : par apprenti, sans toucher la robe.
	for cle: String in apprentis:
		var maitre: AccountRewardDef = apprentis[cle]
		var siennes: Array[AccountRewardDef] = SaveData.outfit_rewards(cle)
		if siennes.is_empty():
			continue
		var t: AccountRewardDef = siennes[0]
		SaveData.reset_profile()
		_monter_au_niveau(t.at_level - 1)
		if t.at_level > 1:
			not_ok(SaveData.equip_cosmetic(t.id), "%s ne s equipe pas avant son palier" % t.id)
		_monter_au_niveau(maxi(t.at_level, maitre.at_level))
		ok(SaveData.equip_cosmetic(maitre.id), "%s s equipe" % maitre.id)
		ok(SaveData.equip_cosmetic(t.id), "%s s equipe a son palier" % t.id)
		eq(SaveData.equipped_outfit(cle), t.texture_name, "%s est portee par %s" % [t.id, cle])
		eq(UiTheme.hero_sheet_key(), t.texture_name, "le combat joue la teinte")
		ok(UiTheme.hero_frames() == AnimCatalog.frames(StringName(t.texture_name)),
			"avec ses animations")
		eq(UiTheme.mage_sheet_key(), UiTheme.MAGE_DEFAULT, "la robe du mage n a pas bouge")
		var texte: String = JSON.stringify(SaveData.to_dictionary())
		SaveData.reset_profile()
		SaveData.load_from_dictionary(JSON.parse_string(texte))
		eq(SaveData.equipped_outfit(cle), t.texture_name, "%s survit a la sauvegarde" % t.id)
		ok(SaveData.equip_outfit(cle, cle), "la teinte d origine se reprend toujours")
		eq(UiTheme.hero_sheet_key(), cle, "et le combat la montre")
		not_ok(SaveData.equip_outfit(cle, "monk_red"), "une robe du mage n habille pas %s" % cle)
	SaveData.reset_profile()


func _test_une_tenue_non_meritee_n_est_pas_portee() -> void:
	for r in _rewards(GameEnums.RewardKind.MAGE_COLOR):
		if not r.is_apprentice_outfit():
			continue
		SaveData.reset_profile()
		var triche: Dictionary = SaveData.to_dictionary()
		triche["profile"]["cosmetics"]["outfits"] = {r.for_character: r.texture_name}
		SaveData.load_from_dictionary(triche)
		eq(SaveData.equipped_outfit(r.for_character), r.for_character,
			"%s ecrite a la main dans un profil de niveau 1 : ignoree" % r.id)
	SaveData.reset_profile()
	var casse: Dictionary = SaveData.to_dictionary()
	casse["profile"]["cosmetics"]["outfits"] = {"bluewitch": "teinte_disparue"}
	SaveData.load_from_dictionary(casse)
	eq(SaveData.equipped_outfit("bluewitch"), "bluewitch", "une teinte inconnue rend l origine")
	SaveData.reset_profile()


func _test_les_tours() -> void:
	var cles: Dictionary = {}
	for r in _rewards(GameEnums.RewardKind.TOWER):
		ok(WardrobeData.TOWERS.has(r.texture_name), "%s a sa geometrie mesuree" % r.id)
		cles[r.texture_name] = true
	for key: String in WardrobeData.TOWERS:
		ok(cles.has(key), "la tour %s est une recompense" % key)
		var spec: Dictionary = WardrobeData.TOWERS[key]
		var t: Texture2D = _charge("res://assets/terrain/%s.png" % key)
		ok(t != null, "%s se charge" % key)
		if t == null:
			continue
		var fw: int = int(spec["frame"][0])
		var fh: int = int(spec["frame"][1])
		eq(t.get_width(), fw * int(spec.get("frames", 1)), "%s : largeur = cases x images" % key)
		eq(t.get_height(), fh, "%s : hauteur = une case" % key)
		var pieds := Vector2(float(spec["feet"][0]), float(spec["feet"][1]))
		ok(Rect2(0, 0, fw, fh).has_point(pieds), "%s : le point des pieds est dans la case" % key)
		var r: Rect2 = BattleBackdrop.tower_rect(key)
		ok(r.size.x > 0.0, "%s a une emprise" % key)
		ok(r.position.x >= 0.0 and r.end.x <= GameConfig.BATTLEFIELD_WIDTH,
			"%s tient dans la largeur de l ecran" % key)
		# LE RECADRAGE COMPTE AUTANT QUE LA VIGNETTE : la case entiere donnait
		# une tour minuscule dans son bouton (vu en capture).
		var v: Texture2D = UiTheme.tower_preview(key)
		ok(v != null, "%s a une vignette" % key)
		var c: Array = spec["crop"]
		ok(Rect2i(0, 0, fw, fh).encloses(Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))),
			"%s : le recadrage est dans la case" % key)
		if v != null:
			eq(Vector2i(v.get_size()), Vector2i(int(c[2]), int(c[3])),
				"%s : la vignette est la region recadree, pas la case" % key)
	var bleue: Texture2D = UiTheme.tower_preview("tower_blue")
	ok(bleue != null and bleue.get_height() < 256,
		"la tour d origine est recadree dans sa vignette (sinon minuscule dans le bouton)")
	ok(UiTheme.tower_frames("tower_tree") != null, "l arbre se balance (bande animee)")


## La tour d ORIGINE etait posee a (540, MAGE_LINE_Y + 40), echelle 1,6. La pose
## par le point des pieds doit la remettre EXACTEMENT la : un joueur qui n a rien
## change ne doit rien voir bouger.
func _test_la_tour_d_origine_ne_bouge_pas() -> void:
	var c: Vector2 = BattleBackdrop.tower_center("tower_blue")
	feq(c.x, 540.0, "tour d origine : meme abscisse", 0.01)
	feq(c.y, GameConfig.MAGE_LINE_Y + 40.0, "tour d origine : meme hauteur qu avant", 0.1)
	feq(float(UiTheme.tower_spec("tower_blue")["scale"]), 1.6, "et meme echelle", 0.001)


func _test_les_portraits() -> void:
	var t: Texture2D = _charge(WardrobeData.AVATAR_SHEET)
	ok(t != null, "la planche des portraits se charge")
	if t != null:
		var lignes: int = ceili(float(WardrobeData.AVATARS.size()) / WardrobeData.AVATAR_COLS)
		eq(t.get_width(), WardrobeData.AVATAR_COLS * WardrobeData.AVATAR_CELL, "largeur de la grille")
		eq(t.get_height(), lignes * WardrobeData.AVATAR_CELL, "hauteur de la grille")
	var vus: Dictionary = {}
	for r in _rewards(GameEnums.RewardKind.AVATAR):
		# La TETE DU MAGE (portrait par defaut, vague 8) n est pas une case de la
		# planche des portraits : elle vient de la planche du casting.
		var mage: bool = r.texture_name == WardrobeData.AVATAR_MAGE
		ok(mage or WardrobeData.AVATARS.has(r.texture_name), "%s designe un portrait" % r.id)
		ok(r.is_equippable(), "%s s equipe" % r.id)
		var img: Texture2D = UiTheme.avatar_texture(r.texture_name)
		ok(img != null, "%s a son image" % r.id)
		if mage:
			ok(img != null and (img as AtlasTexture).region == (UiTheme.mage_head() as AtlasTexture).region,
				"%s : c est la tete du mage" % r.id)
			vus[r.texture_name] = r.at_level
			continue
		if img != null:
			ok(img.get_width() < WardrobeData.AVATAR_CELL,
				"%s : le portrait est recadre sur la tete, pas la case entiere" % r.id)
		vus[r.texture_name] = r.at_level
	for a in WardrobeData.AVATARS:
		ok(vus.has(a), "le portrait %s est une recompense" % a)
	eq(int(vus.get(WardrobeData.AVATARS[0], 0)), 1, "le premier portrait est celui du niveau 1")
	eq(int(vus.get(WardrobeData.AVATAR_MAGE, 0)), 1, "la tete du mage est un portrait du niveau 1")
	SaveData.reset_profile()
	eq(UiTheme.avatar_key(), WardrobeData.AVATAR_MAGE,
		"un profil neuf a la tete du mage pour portrait")
	SaveData.set_tester_mode(true)
	var dernier: String = WardrobeData.AVATARS[WardrobeData.AVATARS.size() - 1]
	for r in _rewards(GameEnums.RewardKind.AVATAR):
		if r.texture_name == dernier:
			ok(SaveData.equip_cosmetic(r.id), "un portrait se choisit")
	eq(UiTheme.avatar_key(), dernier, "et c est lui que la carte d identite lira")
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()


## SEULS LES SUCCES DONNENT DE L XP. Une recompense posee au-dela du niveau que
## leur XP totale permet d atteindre n arriverait jamais : contenu present ET
## injoignable, le defaut deja paye deux fois (gotchas.md).
func _test_tout_est_atteignable() -> void:
	var total: int = 0
	for c: ChallengeDef in ContentDB.challenges_list():
		total += c.xp_reward
	var plafond: int = 1
	while SaveData.account_xp_for_level(plafond + 1) <= total and plafond < 200:
		plafond += 1
	for r: AccountRewardDef in ContentDB.rewards_list():
		ok(r.at_level <= plafond, "%s (niveau %d) est atteignable : le compte plafonne a %d (%d XP)"
			% [r.id, r.at_level, plafond, total])
