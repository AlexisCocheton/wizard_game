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
	ContentDB.discover_starters()
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
	SaveData.reset_profile()
	ContentDB.discover_starters()


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
	ContentDB.discover_starters()
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
	ContentDB.discover_starters()
