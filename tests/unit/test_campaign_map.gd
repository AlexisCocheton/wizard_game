extends TestCase
## Carte de selection des niveaux (onglet Campagne).
##
## Ce que ce test verrouille, et POURQUOI :
##  - la carte montre TOUS les niveaux, y compris les verrouilles. Une carte qui
##    ne montre que ce qu on a deja debloque n est pas une carte, c est une liste :
##    le joueur ne voit plus ou il va. C est la demande exacte du testeur.
##  - les liens suivent `next_levels` : la fourche de lvl_04 doit etre visible,
##    sinon l arborescence de l histoire n existe que dans le document.
##  - les etoiles viennent de `SaveData.objectives_done_count`, jamais d un compteur
##    parallele qui pourrait diverger de la verite du profil.
##  - un niveau verrouille n est pas cliquable : autrement on ouvrirait le panneau
##    de detail d un niveau dont le bouton JOUER serait grise, ce qui est un cul-de-sac.

func get_suite_name() -> String:
	return "campaign_map"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_la_carte_place_tous_les_niveaux()
	_test_les_liens_suivent_next_levels()
	_test_la_fourche_du_niveau_4()
	_test_les_rangs_respectent_la_profondeur()
	_test_etoiles_lues_du_profil()
	_test_seuls_les_debloques_sont_cliquables()
	_test_le_panneau_bascule_carte_detail()
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _map() -> CampaignMap:
	var m := CampaignMap.new()
	attach(m)
	m.rebuild()
	return m


## La carte montre l archipel ENTIER. Le testeur veut « voir les noms des etapes » :
## cacher les niveaux verrouilles reviendrait a cacher la carte.
func _test_la_carte_place_tous_les_niveaux() -> void:
	var m: CampaignMap = _map()
	eq(m.node_count(), ContentDB.levels.size(),
		"chaque niveau du catalogue a une ile sur la carte")
	for id in ContentDB.levels.keys():
		ok(m.has_node_for(id), "%s est place sur la carte" % id)
	# Le nom affiche est bien celui du niveau, pas son identifiant technique.
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	eq(m.label_for(&"lvl_01"), l1.display_name, "l ile porte le nom du niveau")
	detach(m)


## Un trait par entree de next_levels : la carte ne peut pas inventer de chemin
## ni en oublier un.
func _test_les_liens_suivent_next_levels() -> void:
	var m: CampaignMap = _map()
	var attendus: int = 0
	for id in ContentDB.levels.keys():
		var lv: LevelDef = ContentDB.levels[id]
		for nxt in lv.next_levels:
			if ContentDB.levels.has(nxt):
				attendus += 1
				ok(m.has_link(lv.id, nxt), "le chemin %s -> %s est trace" % [lv.id, nxt])
	eq(m.link_count(), attendus, "aucun chemin invente")
	ok(attendus >= 6, "l archipel est bien connecte (%d chemins)" % attendus)
	detach(m)


## La fourche de l acte II est le seul endroit ou le joueur CHOISIT son epreuve.
## Si elle n apparait pas, la carte ment sur la structure du jeu.
func _test_la_fourche_du_niveau_4() -> void:
	var m: CampaignMap = _map()
	ok(m.has_link(&"lvl_04", &"lvl_05"), "lvl_04 mene aux Forges")
	ok(m.has_link(&"lvl_04", &"lvl_06"), "lvl_04 mene a la Cour brisee")
	# Les deux branches se rejoignent : la carte doit le montrer aussi.
	ok(m.has_link(&"lvl_05", &"lvl_07"), "les Forges menent au final")
	ok(m.has_link(&"lvl_06", &"lvl_07"), "la Cour brisee mene au final")
	detach(m)


## Le placement vertical vient de la PROFONDEUR dans l arborescence, pas de
## l ordre alphabetique des ids : lvl_05 et lvl_06 sont des freres et doivent
## etre sur la meme ligne, sinon la fourche se lit comme une suite.
func _test_les_rangs_respectent_la_profondeur() -> void:
	var m: CampaignMap = _map()
	eq(m.rank_of(&"lvl_01"), 0, "le premier niveau est la racine")
	ok(m.rank_of(&"lvl_02") > m.rank_of(&"lvl_01"), "lvl_02 vient apres lvl_01")
	eq(m.rank_of(&"lvl_05"), m.rank_of(&"lvl_06"),
		"les deux branches de l acte III sont sur la meme ligne")
	ok(m.rank_of(&"lvl_07") > m.rank_of(&"lvl_05"), "le final est apres les deux branches")
	# Deux freres ne peuvent pas se superposer.
	ok(absf(m.position_of(&"lvl_05").x - m.position_of(&"lvl_06").x) > 100.0,
		"les deux branches sont ecartees horizontalement")
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
	not_ok(p.showing_map(), "toucher une ile ouvre le detail")
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
