extends TestCase
## Carte de selection des niveaux (onglet Campagne) — UN ECRAN PAR ACTE.
##
## Ce que ce test verrouille, et POURQUOI :
##  - la carte montre TOUS les niveaux, y compris les verrouilles. Une carte qui
##    ne montre que ce qu on a deja debloque n est pas une carte, c est une liste :
##    le joueur ne voit plus ou il va. C est la demande exacte du testeur.
##  - un acte = un ecran, et les fleches gauche/droite en changent. C est la
##    navigation demandee ; un defilement vertical la remplacerait en silence.
##  - un acte dont AUCUN niveau n est debloque reste visible et navigable : le
##    joueur doit voir qu il y a une suite. C est explicitement demande.
##  - un acte SANS niveau (l acte 5 n en a encore aucun) ne doit ni planter ni
##    disparaitre : il s affiche vide, avec son fond.
##  - le fond de l ecran est celui de l acte (`LevelDef.backdrop`), pas une
##    texture choisie par l UI : les deux doivent rester d accord sans qu on ait
##    a les resynchroniser a la main.
##  - les points se posent sur le SOL du fond, jamais dans la bande decoree du
##    haut ni dans le premier plan du bas — sinon le nom devient illisible.
##  - les etoiles viennent de `SaveData.objectives_done_count`, jamais d un compteur
##    parallele qui pourrait diverger de la verite du profil.
##  - un niveau verrouille n est pas cliquable : autrement on ouvrirait le panneau
##    de detail d un niveau dont le bouton JOUER serait grise, ce qui est un cul-de-sac.

func get_suite_name() -> String:
	return "campaign_map"


func run() -> void:
	SaveData.reset_profile()
	_test_un_ecran_par_acte()
	_test_les_fleches_changent_d_acte()
	_test_un_acte_verrouille_reste_visible()
	_test_un_acte_vide_ne_plante_pas()
	_test_le_fond_est_celui_de_l_acte()
	_test_les_points_sont_sur_le_sol()
	_test_etoiles_lues_du_profil()
	_test_seuls_les_debloques_sont_cliquables()
	_test_l_ouverture_se_cale_sur_l_acte_en_cours()
	_test_le_panneau_bascule_carte_detail()
	_test_les_noms_d_actes_suivent_le_document()
	_test_chaque_niveau_a_son_illustration()
	_test_aucune_silhouette_ne_se_repete_sur_une_page()
	_test_un_niveau_a_boss_montre_son_boss()
	_test_le_verrouille_se_lit_verrouille()
	_test_le_medaillon_se_lit_sur_un_telephone()
	_test_un_embranchement_se_dessine_en_eventail()
	_test_un_acte_lineaire_reste_une_colonne()
	_test_aucune_cible_ne_chevauche_une_autre()
	_test_l_etoile_vide_se_lit_sur_chaque_fond()
	SaveData.reset_profile()


func _map() -> CampaignMap:
	var m := CampaignMap.new()
	# La carte se dimensionne sur sa taille reelle : sans taille, tous les points
	# tomberaient en (0,0) et le test des positions ne prouverait rien.
	m.size = Vector2(1040.0, 1474.0)
	attach(m)
	m.rebuild()
	return m


## La carte montre l archipel ENTIER, reparti par acte. Le testeur veut « voir les
## noms des etapes » : cacher les niveaux verrouilles reviendrait a cacher la carte.
func _test_un_ecran_par_acte() -> void:
	var m: CampaignMap = _map()
	var total: int = 0
	for a in m.acts():
		total += m.levels_in_act(a).size()
	eq(total, ContentDB.levels.size(),
		"chaque niveau du catalogue est pose sur l ecran de son acte")
	for id in ContentDB.levels.keys():
		var lv: LevelDef = ContentDB.levels[id]
		ok(m.levels_in_act(lv.act).has(id), "%s est sur l ecran de l acte %d" % [id, lv.act])
	# Le nom affiche est bien celui du niveau, pas son identifiant technique.
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	eq(m.label_for(&"lvl_01"), l1.display_name, "le point porte le nom du niveau")

	# ORDRE DE LECTURE. `Array.sort()` sur un Array non type de StringName rend
	# [lvl_02..lvl_07, lvl_01] sur 4.4.stable : l acte I affichait « La Tour des
	# Sables » AVANT « Les Marches du Temps », et le joueur lisait son voyage a
	# l envers. Le defaut etait invisible a tous les autres tests.
	var acte1: Array[StringName] = m.levels_in_act(1)
	eq(acte1[0], &"lvl_01", "le premier niveau de l acte I vient en premier")
	# Et le premier point est bien le plus HAUT : on lit l acte du fond vers soi.
	ok(m.position_of(acte1[0]).y < m.position_of(acte1[1]).y,
		"le premier niveau de l acte est pose au-dessus du suivant")
	detach(m)


## Les fleches sont la SEULE navigation entre actes. Elles bouclent sur les bornes
## en restant inertes plutot qu en sautant a l autre bout : un joueur qui appuie
## deux fois trop a droite ne doit pas se retrouver a l acte I.
func _test_les_fleches_changent_d_acte() -> void:
	var m: CampaignMap = _map()
	var actes: Array[int] = m.acts()
	# Les 4 actes qui ont du contenu PLUS l acte 5, ecrit mais encore vide. Le
	# nombre est ecrit en dur exprès : ecrire `>= 4` laissait passer la
	# disparition de l acte 5, c est-a-dire exactement le defaut a empecher.
	eq(actes.size(), 5, "les 5 actes de l histoire sont sur la carte")
	for a in [1, 2, 3, 4, 5]:
		ok(actes.has(a), "l acte %d est atteignable avec les fleches" % a)
	m.show_act(actes[0])
	eq(m.current_act(), actes[0], "on peut se poser sur le premier acte")
	not_ok(m.can_go_previous(), "pas d acte avant le premier")
	ok(m.can_go_next(), "il y a une suite apres le premier acte")

	m.go_next()
	eq(m.current_act(), actes[1], "la fleche droite avance d un acte")
	m.go_previous()
	eq(m.current_act(), actes[0], "la fleche gauche revient d un acte")
	m.go_previous()
	eq(m.current_act(), actes[0], "la fleche gauche est inerte sur le premier acte")

	m.show_act(actes[actes.size() - 1])
	not_ok(m.can_go_next(), "pas d acte apres le dernier")
	m.go_next()
	eq(m.current_act(), actes[actes.size() - 1], "la fleche droite est inerte sur le dernier")
	detach(m)


## « Un acte dont aucun niveau n est debloque reste visible mais ferme » : on
## doit pouvoir l ATTEINDRE avec les fleches, et ses points restent gris.
func _test_un_acte_verrouille_reste_visible() -> void:
	SaveData.reset_profile()
	var m: CampaignMap = _map()
	# Profil neuf : seul lvl_01 est ouvert, donc les actes 2+ sont entierement fermes.
	var dernier: int = m.acts()[m.acts().size() - 1]
	m.show_act(dernier)
	eq(m.current_act(), dernier, "on atteint le dernier acte sur un profil neuf")
	not_ok(m.act_is_open(dernier), "le dernier acte est ferme sur un profil neuf")
	ok(m.act_is_open(1), "l acte I est ouvert des le depart")
	# Ferme ne veut pas dire vide : les points sont la, gris.
	for id in m.levels_in_act(3):
		not_ok(m.is_enabled(id), "%s reste verrouille" % id)
		ok(m.position_of(id) != Vector2.ZERO, "%s est tout de meme place" % id)
	detach(m)


## L acte 5 n a encore aucun niveau. Il ne doit ni faire disparaitre l ecran ni
## planter : c est le cas qui arrive a chaque fois qu on ecrit l histoire avant
## le contenu.
func _test_un_acte_vide_ne_plante_pas() -> void:
	var m: CampaignMap = _map()
	# On demande un acte qui n existe pas dans le contenu.
	m.show_act(9)
	eq(m.levels_in_act(9).size(), 0, "un acte sans niveau n en invente pas")
	ok(m.act_title(9) != "", "un acte inconnu a tout de meme un titre")
	ok(m.empty_notice() != "", "un acte vide affiche un message, pas un ecran blanc")
	# Et on peut en repartir.
	m.show_act(1)
	eq(m.current_act(), 1, "on revient d un acte vide sans rester coince")
	detach(m)


## Le fond vient de `LevelDef.backdrop` : si un niveau change d acte ou de fond,
## la carte suit sans qu on ait a modifier une table dans l UI.
func _test_le_fond_est_celui_de_l_acte() -> void:
	var m: CampaignMap = _map()
	for a in m.acts():
		var ids: Array[StringName] = m.levels_in_act(a)
		if ids.is_empty():
			continue
		var lv: LevelDef = ContentDB.levels[ids[0]]
		if lv.backdrop == "":
			continue
		eq(m.backdrop_for_act(a), lv.backdrop,
			"l acte %d affiche le fond de ses niveaux" % a)
		ok(FileAccess.file_exists("res://assets/backdrops/%s.png" % m.backdrop_for_act(a)),
			"le fond de l acte %d existe sur le disque" % a)
	# Un acte sans niveau a quand meme un fond : sinon l ecran serait noir.
	ok(m.backdrop_for_act(5) != "", "l acte 5, sans niveau, a tout de meme un fond")
	detach(m)


## Les fonds ont une bande DECOREE en haut et un premier plan en bas. Un point
## pose dedans devient illisible (feuillage, tombes, grilles). Ils vivent sur le
## SOL, la bande mediane.
func _test_les_points_sont_sur_le_sol() -> void:
	var m: CampaignMap = _map()
	var h: float = m.size.y
	var vus: int = 0
	for a in m.acts():
		for id in m.levels_in_act(a):
			var p: Vector2 = m.position_of(id)
			vus += 1
			# Bornes ECRITES EN DUR, jamais `CampaignMap.GROUND_*` : un test qui
			# relit la constante qu il est cense contraindre passe toujours. Verifie
			# en sabotant GROUND_TOP a 0.02 — l assertion ne mordait pas.
			# 0.22 = sous la bande decoree du fond ET sous le titre de l acte ;
			# 0.84 = au-dessus du premier plan (herbes hautes, dalles).
			between(p.y, h * 0.22, h * 0.84, "%s est pose sur le sol du fond" % id)
			# Les fleches mangent les bords : un point dessous serait inatteignable.
			# 140 px couvre la fleche (120) plus son ecart au bord.
			between(p.x, 140.0, m.size.x - 140.0, "%s est entre les deux fleches" % id)
	ok(vus >= 7, "les 7 niveaux existants sont places (%d)" % vus)
	# Deux niveaux du meme acte ne se superposent pas : sinon un point en cache
	# un autre et le joueur ne peut plus le toucher.
	for a in m.acts():
		var ids: Array[StringName] = m.levels_in_act(a)
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				ok(m.position_of(ids[i]).distance_to(m.position_of(ids[j])) > CampaignMap.DOT_SIZE,
					"%s et %s ne se superposent pas" % [ids[i], ids[j]])
	detach(m)


## Les etoiles SONT les objectifs du profil. Un compteur parallele finirait par
## diverger ; on relit SaveData a chaque rebuild.
func _test_etoiles_lues_du_profil() -> void:
	SaveData.reset_profile()
	var m: CampaignMap = _map()
	eq(m.stars_for(&"lvl_01"), 0, "profil neuf : aucune etoile")
	detach(m)

	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var ids: Array[StringName] = []
	for o in l1.objectives:
		ids.append(o.id)
	SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {ids[0]: true, ids[1]: true}, 6)

	var m2: CampaignMap = _map()
	eq(m2.stars_for(&"lvl_01"), 2, "2 objectifs reussis = 2 etoiles")
	eq(m2.stars_for(&"lvl_01"), SaveData.objectives_done_count(l1),
		"l etoile est exactement le compteur du profil")
	eq(m2.max_stars_for(&"lvl_01"), 3, "3 etoiles au maximum, une par objectif")
	detach(m2)
	SaveData.reset_profile()


## Un niveau verrouille se distingue ET ne repond pas au toucher : ouvrir son
## detail menerait a un JOUER grise, un cul-de-sac pour le joueur.
func _test_seuls_les_debloques_sont_cliquables() -> void:
	SaveData.reset_profile()
	var m: CampaignMap = _map()
	ok(m.is_enabled(&"lvl_01"), "le premier niveau est cliquable d office")
	not_ok(m.is_enabled(&"lvl_02"), "un niveau verrouille ne se clique pas")
	not_ok(m.is_enabled(&"lvl_07"), "le final est verrouille sur un profil neuf")
	detach(m)

	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {}, 6)
	var m2: CampaignMap = _map()
	ok(m2.is_enabled(&"lvl_02"), "la victoire rend le niveau 2 cliquable")
	detach(m2)
	SaveData.reset_profile()


## On rouvre la campagne sur l acte ou le joueur en est, pas sur l acte I : avec
## 5 actes, retrouver son niveau demanderait sinon 4 appuis a chaque fois.
func _test_l_ouverture_se_cale_sur_l_acte_en_cours() -> void:
	SaveData.reset_profile()
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {}, 6)
	var l2: LevelDef = ContentDB.levels.get(&"lvl_02")
	SaveData.record_victory(l2, GameEnums.Mode.EXPLORATION, {}, 6)
	SaveData.set_current_level(&"lvl_03")
	var m: CampaignMap = _map()
	var l3: LevelDef = ContentDB.levels.get(&"lvl_03")
	eq(m.current_act(), l3.act, "la carte s ouvre sur l acte du niveau en cours")
	detach(m)
	SaveData.reset_profile()


## Le panneau garde le detail EXISTANT (vagues, boss, objectifs, modes, JOUER) :
## la carte est une couche de navigation par-dessus, pas un remplacement.
func _test_le_panneau_bascule_carte_detail() -> void:
	SaveData.reset_profile()
	var p := CampaignPanel.new()
	attach(p)
	p.refresh()
	ok(p.showing_map(), "on arrive sur la carte, pas sur une fiche")

	p.open_level(&"lvl_01")
	not_ok(p.showing_map(), "toucher un point ouvre le detail")
	eq(p.detail_level_id(), &"lvl_01", "c est le detail du niveau touche")
	# Le detail est bien l ancien ecran : ses commandes existent toujours.
	ok(p.has_detail_controls(), "le detail garde modes + JOUER")

	# Un niveau verrouille est refuse meme si on appelle open_level directement.
	p.open_level(&"lvl_07")
	eq(p.detail_level_id(), &"lvl_01", "un niveau verrouille n ouvre pas de detail")

	p.back_to_map()
	ok(p.showing_map(), "le retour ramene a la carte")
	detach(p)
	SaveData.reset_profile()


## Le nom d un acte affiche a l ecran doit etre celui de `docs/histoire.md`.
##
## Le defaut que ceci empeche de revenir : `ACT_NAMES` datait d une
## nomenclature en QUATRE actes abandonnee depuis. La carte annoncait
## "Le Monde volant" devant la foret de Nuri et "Le Grand Cimetiere" devant les
## Sky Lands — trois noms sur cinq nommaient le MAUVAIS LIEU. Rien ne plantait,
## aucun test ne comparait l interface au document : un joueur qui lisait
## l histoire et jouait la campagne voyait deux jeux differents.
##
## Le test lit le DOCUMENT, il ne recopie pas les noms : recopier les figerait
## une seconde fois, et la prochaine reecriture du document les separerait de
## nouveau sans que rien ne rougisse.
func _test_les_noms_d_actes_suivent_le_document() -> void:
	var f := FileAccess.open("res://docs/histoire.md", FileAccess.READ)
	ok(f != null, "docs/histoire.md est lisible")
	if f == null:
		return
	var texte: String = f.get_as_text()
	f.close()

	# Les titres de section : "## 3. ACTE 1 — La foret de Nuri"
	var lieux: Dictionary = {}
	for ligne in texte.split("
"):
		var l: String = ligne.strip_edges()
		if not l.begins_with("##"):
			continue
		var i: int = l.find("ACTE ")
		if i < 0:
			continue
		var reste: String = l.substr(i + 5)
		var num: int = int(reste)
		var tiret: int = reste.find("—")
		if tiret < 0:
			tiret = reste.find("-")
		if num <= 0 or tiret < 0:
			continue
		lieux[num] = reste.substr(tiret + 1).strip_edges()

	ok(lieux.size() >= 5, "le document decrit au moins 5 actes (%d)" % lieux.size())
	for acte in lieux:
		var attendu: String = String(lieux[acte])
		var affiche: String = String(CampaignMap.ACT_NAMES.get(acte, ""))
		ok(affiche != "", "l acte %d a un nom a l ecran" % acte)
		# On compare sur les MOTS SIGNIFIANTS : le document ecrit des accents et
		# l ecran n en a pas, et la ponctuation differe. Ce qui doit coincider,
		# c est le LIEU nomme.
		var mots: PackedStringArray = attendu.to_lower().split(" ", false)
		for mot in mots:
			# Les mots outils ne prouvent rien.
			if mot.length() < 4:
				continue
			var sans_accent: String = mot
			for paire in [["é", "e"], ["è", "e"], ["ê", "e"], ["à", "a"],
					["î", "i"], ["ô", "o"], ["û", "u"], ["ç", "c"]]:
				sans_accent = sans_accent.replace(paire[0], paire[1])
			ok(affiche.to_lower().contains(sans_accent),
				"l acte %d affiche \"%s\" et le document dit \"%s\" (mot manquant : %s)"
				% [acte, affiche, attendu, sans_accent])


# --- UI-007 : l illustration de chaque niveau ---

## Chaque niveau du catalogue porte une silhouette, et elle a une image. Un
## medaillon vide sur 21 se lirait comme un niveau casse.
func _test_chaque_niveau_a_son_illustration() -> void:
	var m: CampaignMap = _map()
	for id in ContentDB.levels.keys():
		var sig: EnemyDef = m.signature_of(StringName(id))
		ok(sig != null, "%s a un monstre signature" % id)
		if sig == null:
			continue
		ok(AnimCatalog.has(sig.anim_key), "%s : la signature %s a une feuille" % [id, sig.id])
		ok(CampaignMap.portrait(sig.anim_key) != null,
			"%s : le portrait de %s se construit" % [id, sig.anim_key])
	# Ce que le joueur VOIT : chaque medaillon de chaque page porte l image.
	for a in m.acts():
		m.show_act(a)
		for id in m.levels_in_act(a):
			var medal: Control = m.medallion_for(id)
			ok(medal != null, "%s a un medaillon a l ecran" % id)
			if medal == null:
				continue
			var art: TextureRect = medal.find_child("Silhouette", true, false) as TextureRect
			ok(art != null and art.texture != null, "%s : le medaillon montre la silhouette" % id)
	detach(m)


## LA regle de distinction : une page = un acte, et sur une page deux niveaux
## n ont jamais la meme silhouette. Sans elle l acte V montrait deux fois le
## Juggernaut (deux de ses niveaux n ont pas de boss, et le monstre le plus fort
## de leur pool est le boss du troisieme).
func _test_aucune_silhouette_ne_se_repete_sur_une_page() -> void:
	var m: CampaignMap = _map()
	var distinctes: Dictionary = {}
	for a in m.acts():
		var vus: Dictionary = {}
		for id in m.levels_in_act(a):
			var sig: EnemyDef = m.signature_of(id)
			if sig == null:
				continue
			var cle: String = String(sig.anim_key)
			not_ok(vus.has(cle), "acte %d : %s reprend la silhouette %s de %s" % [
				a, id, cle, vus.get(cle, "")])
			vus[cle] = id
			distinctes[cle] = true
	# Plus de la moitie des niveaux doivent avoir une silhouette propre a TOUT
	# le jeu : sans ce plancher, une regle qui ne garantirait que l unicite par
	# page pourrait donner le meme boss a chaque acte sans rougir.
	ok(distinctes.size() * 2 > ContentDB.levels.size(),
		"%d silhouettes distinctes pour %d niveaux" % [distinctes.size(), ContentDB.levels.size()])
	detach(m)


## Un niveau qui a une vague de boss est illustre par CE boss, le plus puissant
## de la vague. Eviter un doublon entre deux actes ne justifie jamais de lui
## substituer un sbire : l illustration mentirait sur ce qu on va affronter.
func _test_un_niveau_a_boss_montre_son_boss() -> void:
	var m: CampaignMap = _map()
	var controles: int = 0
	for id in ContentDB.levels.keys():
		var lv: LevelDef = ContentDB.levels[id]
		var boss: Array[EnemyDef] = []
		for w in lv.waves:
			if w != null and w.is_boss:
				for e in w.enemy_defs():
					if e != null and not e.projectile and AnimCatalog.has(e.anim_key):
						boss.append(e)
		if boss.is_empty():
			continue
		var fort: int = 0
		for e in boss:
			fort = maxi(fort, e.power)
		var sig: EnemyDef = m.signature_of(StringName(id))
		ok(sig != null and boss.has(sig), "%s est illustre par un monstre de sa vague de boss" % id)
		if sig != null:
			eq(sig.power, fort, "%s : c est le plus puissant de la vague (%s)" % [id, sig.id])
		controles += 1
	ok(controles > 0, "au moins un niveau a boss a ete controle")
	detach(m)


## Verrouille = une OMBRE : la silhouette garde sa forme mais perd ses couleurs.
## Jouable = la silhouette en couleurs. Mesure sur la teinte appliquee, pas sur
## l intention : un modulate oublie rendrait tous les niveaux « ouverts ».
func _test_le_verrouille_se_lit_verrouille() -> void:
	SaveData.reset_profile()
	var m: CampaignMap = _map()
	m.show_act(1)
	var ouvert: Control = m.medallion_for(&"lvl_01")
	var ferme: Control = m.medallion_for(&"lvl_02")
	ok(ouvert != null and ferme != null, "les deux medaillons de l acte I existent")
	if ouvert != null and ferme != null:
		var a_ouv: TextureRect = ouvert.find_child("Silhouette", true, false)
		var a_fer: TextureRect = ferme.find_child("Silhouette", true, false)
		# Bornes en dur : 0.2 est une ombre quelle que soit la feuille, 0.5 une
		# image dont on voit les couleurs.
		ok(a_fer.modulate.get_luminance() < 0.2,
			"le niveau verrouille montre une ombre (luminance %.2f)" % a_fer.modulate.get_luminance())
		ok(a_ouv.modulate.get_luminance() > 0.5,
			"le niveau jouable montre ses couleurs (luminance %.2f)" % a_ouv.modulate.get_luminance())
		ok(ouvert.find_child("IciHalo", true, false) != null,
			"le niveau en cours porte le halo « tu es ici »")
		ok(ferme.find_child("IciHalo", true, false) == null,
			"un niveau verrouille ne porte jamais le halo")
	detach(m)


## Taille : une silhouette de boss doit se reconnaitre sur un telephone, et la
## cible rester touchable au doigt. Bornes en dur, pas les constantes : un test
## qui relit DOT_SIZE passerait quelle que soit sa valeur.
func _test_le_medaillon_se_lit_sur_un_telephone() -> void:
	var m: CampaignMap = _map()
	m.show_act(1)
	var medal: Control = m.medallion_for(&"lvl_01")
	ok(medal != null, "le medaillon du niveau 1 existe")
	if medal != null:
		ok(medal.custom_minimum_size.x >= 130.0 and medal.custom_minimum_size.y >= 130.0,
			"le medaillon fait au moins 130 px (%s)" % medal.custom_minimum_size)
		var b: Control = medal.get_parent().get_parent() as Control
		ok(b is Button, "le medaillon est porte par le bouton du niveau")
		if b != null:
			ok(b.size.x >= 90.0 and b.size.y >= 90.0, "la cible tactile depasse 90 px")
	detach(m)


# --- L eventail : un acte non lineaire se dessine comme tel ---

## Les FRERES : les niveaux d un meme acte ouverts par la meme victoire. Lu dans
## `next_levels`, jamais recopie : le jour ou un acte gagne un embranchement, le
## test le controle sans qu on ait a l y ajouter.
func _fratries() -> Array:
	var out: Array = []
	for id in ContentDB.levels.keys():
		var lv: LevelDef = ContentDB.levels[id]
		var par_acte: Dictionary = {}
		for s in lv.next_levels:
			var sl: LevelDef = ContentDB.levels.get(StringName(s))
			if sl == null:
				continue
			if not par_acte.has(sl.act):
				par_acte[sl.act] = []
			(par_acte[sl.act] as Array).append(StringName(s))
		for a in par_acte:
			if (par_acte[a] as Array).size() >= 2:
				out.append({"parent": StringName(id), "act": int(a), "freres": par_acte[a]})
	return out


## Le niveau vers lequel TOUS les freres convergent, s il existe (le pentacle
## brise pour les quatre demons).
func _convergence(freres: Array) -> StringName:
	var communs: Dictionary = {}
	var premier: bool = true
	for f in freres:
		var lv: LevelDef = ContentDB.levels[f]
		var ici: Dictionary = {}
		for s in lv.next_levels:
			ici[StringName(s)] = true
		if premier:
			communs = ici
			premier = false
		else:
			for k in communs.keys():
				if not ici.has(k):
					communs.erase(k)
	for k in communs.keys():
		return StringName(k)
	return &""


## LE DEFAUT : l acte IV (le pentacle de Tombol ouvre les QUATRE demons d un
## coup) etait range en colonne en zigzag, comme un acte lineaire. Le joueur
## lisait « la forge d abord, puis les fosses... » alors que l ordre est libre.
##
## Ce qui doit se voir : les freres sur UNE rangee (cote a cote, pas l un sous
## l autre), et le niveau ou ils convergent SOUS eux, centre. Plus l avis
## d ordre libre sous le titre de l acte.
func _test_un_embranchement_se_dessine_en_eventail() -> void:
	var m: CampaignMap = _map()
	var fratries: Array = _fratries()
	ok(not fratries.is_empty(), "le contenu a au moins un embranchement (l acte IV)")
	var plus_grande: int = 0
	for fr in fratries:
		var freres: Array = fr["freres"]
		var a: int = fr["act"]
		plus_grande = maxi(plus_grande, freres.size())
		# Meme rangee, dans l ordre ou l auteur les a ecrits.
		var rangee_de: Dictionary = {}
		var ri: int = 0
		for r in m.rows_in_act(a):
			for id in r:
				rangee_de[id] = ri
			ri += 1
		for f in freres:
			eq(rangee_de.get(f, -1), rangee_de.get(freres[0], -2),
				"acte %d : %s et %s s ouvrent ensemble, ils partagent une rangee" % [a, freres[0], f])
		# COTE A COTE, et non en colonne : ecart horizontal d au moins un
		# medaillon (150, en dur) entre voisins, ecart vertical plus petit
		# qu un medaillon (sinon c est une colonne, meme en biais).
		var ys: Array[float] = []
		for i in freres.size():
			var p: Vector2 = m.position_of(freres[i])
			ys.append(p.y)
			if i > 0:
				var gauche: Vector2 = m.position_of(freres[i - 1])
				ok(p.x - gauche.x >= 150.0,
					"acte %d : %s est a droite de %s (ecart %.0f px)" % [a, freres[i], freres[i - 1], p.x - gauche.x])
		ok(ys.max() - ys.min() < 150.0,
			"acte %d : les freres de %s sont sur une rangee, pas en colonne (%.0f px de haut en bas)" % [
				a, fr["parent"], ys.max() - ys.min()])
		# La convergence : sous l eventail, au milieu.
		var fin: StringName = _convergence(freres)
		if fin != &"" and ContentDB.levels.has(fin) and (ContentDB.levels[fin] as LevelDef).act == a:
			var pf: Vector2 = m.position_of(fin)
			var milieu: float = 0.0
			for f in freres:
				ok(pf.y > m.position_of(f).y, "acte %d : %s est sous %s" % [a, fin, f])
				milieu += m.position_of(f).x
			milieu /= float(freres.size())
			ok(absf(pf.x - milieu) < 75.0,
				"acte %d : %s est centre sous l eventail (decale de %.0f px)" % [a, fin, pf.x - milieu])
		# L avis d ordre libre accompagne la forme.
		m.show_act(a)
		ok(m.fork_notice_visible(), "acte %d : l avis d ordre libre est affiche" % a)
	# Le cas qui a motive le chantier : quatre niveaux ouverts d un coup.
	ok(plus_grande >= 4, "l eventail le plus large compte %d niveaux (les quatre demons)" % plus_grande)
	detach(m)


## Un acte SANS embranchement garde sa lecture en colonne : un niveau par
## rangee, et pas d avis d ordre libre (il mentirait).
func _test_un_acte_lineaire_reste_une_colonne() -> void:
	var m: CampaignMap = _map()
	var lineaires: int = 0
	for a in m.acts():
		if m.levels_in_act(a).size() < 2 or m.act_has_fork(a):
			continue
		lineaires += 1
		for r in m.rows_in_act(a):
			eq((r as Array).size(), 1, "acte %d lineaire : un niveau par rangee" % a)
		m.show_act(a)
		not_ok(m.fork_notice_visible(), "acte %d lineaire : pas d avis d ordre libre" % a)
	ok(lineaires > 0, "au moins un acte lineaire a ete controle")
	detach(m)


## Deux cibles tactiles qui se chevauchent : le pouce ouvre l une ou l autre au
## hasard. L eventail serre quatre tuiles entre les fleches, c est la qu un
## chevauchement apparaitrait. Chaque cible reste aussi au-dela des 90 px et
## hors des fleches (120 px + 8 de bord, en dur).
func _test_aucune_cible_ne_chevauche_une_autre() -> void:
	var m: CampaignMap = _map()
	for a in m.acts():
		var ids: Array[StringName] = m.levels_in_act(a)
		for i in ids.size():
			var r: Rect2 = m.hit_rect_of(ids[i])
			ok(r.size.x >= 90.0 and r.size.y >= 90.0, "%s : cible de %s" % [ids[i], r.size])
			ok(r.position.x >= 128.0 and r.end.x <= m.size.x - 128.0,
				"%s : la cible ne passe pas sous une fleche (%.0f..%.0f)" % [ids[i], r.position.x, r.end.x])
			for j in range(i + 1, ids.size()):
				not_ok(r.intersects(m.hit_rect_of(ids[j])),
					"%s et %s : les cibles tactiles se chevauchent" % [ids[i], ids[j]])
	detach(m)


# --- Les etoiles vides se lisent sur tous les fonds ---

func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


## Luminance relative WCAG. `Color.get_luminance()` ne lineairise pas : il
## sur-estime les tons moyens et fausserait le ratio.
func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _ratio(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Le fond SOUS les etoiles : la bande de sol du fond de l acte, dont on garde
## le ton le plus sombre et le plus clair qu on y croise (10e et 90e centiles).
## Une moyenne cacherait les nuages orange de l acte V comme les herbes sombres
## de l acte I, c est-a-dire exactement les endroits ou une etoile disparait.
func _tons_du_sol(act_backdrop: String) -> Array[Color]:
	var out: Array[Color] = []
	var chemin: String = ProjectSettings.globalize_path(
		"res://assets/backdrops/%s.png" % act_backdrop)
	var img: Image = Image.load_from_file(chemin)
	if img == null or img.is_empty():
		return out
	if img.is_compressed():
		img.decompress()
	var px: Array = []
	var y0: int = int(img.get_height() * 0.24)
	var y1: int = int(img.get_height() * 0.83)
	for y in range(y0, y1, 8):
		for x in range(0, img.get_width(), 8):
			var c: Color = img.get_pixel(x, y)
			px.append([_lum(c), c])
	px.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	out.append(px[int(px.size() * 0.10)][1])
	out.append(px[int(px.size() * 0.90)][1])
	return out


## LE DEFAUT : sur l espace de l acte V, l etoile vide (piece sombre et
## translucide) rendait 1,14:1 contre le fond, mesure sur capture. Elle est
## maintenant un anneau a DEUX tons : sur chaque fond, l un des deux doit
## passer le plancher du projet, 4,5:1 (en dur).
##
## Et la distinction pleine / vide ne repose pas sur la seule couleur : la
## pleine est la piece d or, la vide n a PAS la piece et elle est plus petite.
func _test_l_etoile_vide_se_lit_sur_chaque_fond() -> void:
	SaveData.reset_profile()
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {l1.objectives[0].id: true}, 6)
	var m: CampaignMap = _map()
	m.show_act(l1.act)
	var etoiles: Array[Control] = m.star_nodes_for(&"lvl_01")
	eq(etoiles.size(), l1.objectives.size(), "une etoile par objectif")
	var pleine: Control = null
	var vide: Control = null
	for e in etoiles:
		if e.name == "EtoilePleine" and pleine == null:
			pleine = e
		elif e.name == "EtoileVide" and vide == null:
			vide = e
	ok(pleine != null and vide != null, "une pleine et une vide pour 1 objectif sur %d" % etoiles.size())
	if pleine == null or vide == null:
		detach(m)
		SaveData.reset_profile()
		return
	# La FORME : la pleine porte la piece, la vide non, et elle est plus petite.
	ok(pleine is TextureRect and (pleine as TextureRect).texture != null, "la pleine est la piece d or")
	not_ok(vide is TextureRect, "la vide n est pas une piece ternie : c est un creux")
	ok(vide.custom_minimum_size.x < pleine.custom_minimum_size.x, "la vide est plus petite que la pleine")

	var sb: StyleBoxFlat = vide.get_theme_stylebox(&"panel") as StyleBoxFlat
	ok(sb != null and sb.border_width_left > 0, "la vide a un liseret")
	if sb != null:
		var controles: int = 0
		for a in m.acts():
			var fond: String = m.backdrop_for_act(a)
			var tons: Array[Color] = _tons_du_sol(fond)
			ok(tons.size() == 2, "le fond %s se lit sur le disque" % fond)
			for t in tons:
				var meilleur: float = maxf(_ratio(sb.border_color, t), _ratio(sb.bg_color, t))
				ok(meilleur >= 4.5, "acte %d (%s) : l etoile vide se lit a %.2f:1 sur %s" % [
					a, fond, meilleur, t.to_html(false)])
				controles += 1
		ok(controles >= 10, "les deux tons de sol des cinq actes sont controles (%d)" % controles)
	detach(m)
	SaveData.reset_profile()
