extends TestCase
## Donnees derriere le menu : decouverte, deck, campagne, victoire, reglages.
## Tout se passe en memoire : la persistance est coupee en headless.

func get_suite_name() -> String:
	return "menu_data"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_persistance_coupee()
	_test_cartes_de_depart_decouvertes()
	_test_deck_massacre()
	_test_le_massacre_s_ouvre_a_la_fin_de_la_campagne()
	_test_plusieurs_decks()
	_test_migration_ancien_deck_unique()
	_test_reglages()
	_test_victoire_debloque_le_niveau_suivant()
	_test_legendaire_cumulative()
	_test_niveau_courant()
	_test_deck_exploration_contient_le_mur()
	_test_deck_explicite_conserve_les_exemplaires()
	_test_seuls_les_niveaux_debloques_sont_jouables()
	_test_le_hud_reste_actif_en_pause()
	_test_coquille_du_menu()
	_test_entete_affiche_niveau_et_cartes()
	_test_profil_en_superposition()
	# Etat propre pour les suites suivantes.
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _test_persistance_coupee() -> void:
	not_ok(SaveData.persistence_enabled, "en headless, le vrai profil n est jamais touche")


func _test_cartes_de_depart_decouvertes() -> void:
	ok(SaveData.is_discovered(&"arcane_bolt"), "les communes de depart sont decouvertes")
	not_ok(SaveData.is_discovered(&"time_rift"), "la legendaire ne l est pas")
	ok(SaveData.discovered_count() >= 4, "au moins les 4 communes")


func _test_deck_massacre() -> void:
	eq(SaveData.massacre_deck().size(), 0, "aucun deck au depart")
	SaveData.set_massacre_deck([&"arcane_bolt", &"arcane_bolt", "frost_field"])
	var ids: Array = SaveData.massacre_deck()
	eq(ids.size(), 3, "le deck est memorise avec ses doublons")
	eq(ids[0], "arcane_bolt", "les ids sont stockes en String")


## Le joueur peut tenir PLUSIEURS decks nommes et basculer de l un a l autre :
## il n a plus a demonter son deck de campagne pour essayer autre chose en
## Massacre. `massacre_deck()` reste l ancien nom du deck COURANT, pour que le
## reste du jeu (GameController, campagne, profil) n ait rien a changer.
func _test_plusieurs_decks() -> void:
	SaveData.reset_profile()
	eq(SaveData.deck_count(), 1, "un profil neuf a deja un deck, jamais zero")
	eq(SaveData.current_deck_index(), 0, "le premier deck est le courant")

	SaveData.set_massacre_deck(["arcane_bolt", "fireball"])
	eq(SaveData.deck_at(0).size(), 2, "ecrire le deck courant ecrit le deck 0")

	var idx: int = SaveData.create_deck("Givre")
	eq(idx, 1, "le nouveau deck est ajoute a la fin")
	eq(SaveData.deck_count(), 2, "deux decks")
	eq(SaveData.current_deck_index(), 1, "creer un deck le rend courant")
	eq(SaveData.massacre_deck().size(), 0, "un deck neuf est vide")
	eq(SaveData.deck_name(1), "Givre", "le nom est retenu")

	# Le deck 0 n a pas bouge : c est tout l interet d en avoir plusieurs.
	eq(SaveData.deck_at(0).size(), 2, "l ancien deck est intact")
	SaveData.set_current_deck(0)
	eq(SaveData.massacre_deck().size(), 2, "revenir au deck 0 rend son contenu")

	SaveData.rename_deck(0, "Feu")
	eq(SaveData.deck_name(0), "Feu", "renommage")
	# Un nom vide serait un onglet invisible : on refuse en gardant l ancien.
	SaveData.rename_deck(0, "   ")
	eq(SaveData.deck_name(0), "Feu", "un nom vide est refuse")

	SaveData.set_current_deck(1)
	SaveData.delete_deck(1)
	eq(SaveData.deck_count(), 1, "suppression")
	eq(SaveData.current_deck_index(), 0, "le courant retombe sur un deck existant")
	# Le dernier deck ne se supprime pas : sans deck, l ecran n aurait plus
	# d onglet a afficher ni le jeu de quoi composer une partie.
	SaveData.delete_deck(0)
	eq(SaveData.deck_count(), 1, "le dernier deck ne se supprime pas")

	# Index hors bornes : aucune erreur, aucune donnee perdue.
	SaveData.set_current_deck(99)
	ok(SaveData.current_deck_index() >= 0 and SaveData.current_deck_index() < SaveData.deck_count(),
		"un index hors bornes est ramene dans les clous")
	eq(SaveData.deck_at(42).size(), 0, "lire un deck inexistant rend une liste vide")
	SaveData.reset_profile()
	ContentDB.discover_starters()


## Les telephones deja en service ont un profil avec UN seul `massacre_deck`.
## La migration doit le retrouver dans le premier onglet, sinon le joueur
## rallume son jeu et son deck a disparu.
func _test_migration_ancien_deck_unique() -> void:
	SaveData.load_from_dictionary({
		"schema_version": 1,
		"profile": {
			"discovered_cards": ["arcane_bolt"],
			"massacre_deck": ["arcane_bolt", "arcane_bolt", "fireball"],
		},
	})
	eq(SaveData.deck_count(), 1, "l ancien profil donne exactement un deck")
	eq(SaveData.deck_at(0).size(), 3, "l ancien deck est repris tel quel")
	eq(SaveData.massacre_deck()[0], "arcane_bolt", "avec ses cartes")
	ok(SaveData.deck_name(0).length() > 0, "et un nom d onglet non vide")
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _test_reglages() -> void:
	SaveData.set_setting("master_volume", 0.25)
	feq(float(SaveData.get_setting("master_volume", 1.0)), 0.25, "reglage relu")
	eq(SaveData.get_setting("cle_inconnue", "defaut"), "defaut", "cle absente -> defaut")


func _test_victoire_debloque_le_niveau_suivant() -> void:
	SaveData.reset_profile()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(lvl1 != null, "lvl_01 existe")
	ok(SaveData.is_level_unlocked(&"lvl_01"), "le niveau 1 est ouvert d office")
	not_ok(SaveData.is_level_unlocked(&"lvl_02"), "le niveau 2 est verrouille au depart")

	var newly: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION, {}, 6)
	not_ok(newly, "sans objectif, pas de legendaire")
	ok(SaveData.is_level_cleared(&"lvl_01"), "le niveau 1 est marque termine")
	ok(SaveData.is_level_unlocked(&"lvl_02"), "la victoire debloque le niveau 2")
	eq(int(SaveData.level_record(&"lvl_01").get("best_wave", 0)), 6, "meilleure vague enregistree")

	SaveData.record_victory(lvl1, GameEnums.Mode.MASSACRE, {}, 3)
	eq(int(SaveData.level_record(&"lvl_01").get("best_wave", 0)), 6, "la meilleure vague ne regresse pas")
	ok(bool(SaveData.level_record(&"lvl_01").get("cleared_massacre", false)), "massacre marque aussi")


## Les objectifs s accumulent d un run a l autre : 2 puis 1 = les 3.
func _test_legendaire_cumulative() -> void:
	SaveData.reset_profile()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var ids: Array[StringName] = []
	for o in lvl1.objectives:
		ids.append(o.id)
	eq(ids.size(), 3, "3 objectifs sur le niveau 1")

	var first: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[0]: true, ids[1]: true, ids[2]: false}, 6)
	not_ok(first, "2 objectifs sur 3 : pas encore la legendaire")
	eq(SaveData.objectives_done_count(lvl1), 2, "2 objectifs acquis")

	var second: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[2]: true}, 6)
	ok(second, "le 3e objectif, meme sur un autre run, debloque la legendaire")
	ok(SaveData.is_discovered(lvl1.legendary_reward.id), "la legendaire est decouverte")
	ok(SaveData.unlocked_legendaries().has(String(lvl1.legendary_reward.id)), "et listee")

	var third: bool = SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION,
		{ids[0]: true, ids[1]: true, ids[2]: true}, 6)
	not_ok(third, "deja obtenue : pas signalee comme nouvelle")


func _test_niveau_courant() -> void:
	SaveData.set_current_level(&"lvl_02")
	eq(SaveData.current_level(), &"lvl_02", "le niveau courant est memorise")


## Regression : le mur avait copies_in_starter = 0 et n entrait jamais dans le deck.
func _test_deck_exploration_contient_le_mur() -> void:
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	var murs: int = 0
	for c in lvl1.exploration_deck:
		if c != null and c.id == &"stone_wall":
			murs += 1
	ok(murs >= 1, "le Mur de pierre est bien dans le deck d exploration (%d ex.)" % murs)
	ok(lvl1.exploration_deck.size() >= DeckRules.MIN_CARDS,
		"le deck pre-etabli est jouable (%d cartes)" % lvl1.exploration_deck.size())


func _test_deck_explicite_conserve_les_exemplaires() -> void:
	RunState.reset()
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	RunState.build_deck_from_list(lvl1.exploration_deck)
	eq(RunState.total_cards(), lvl1.exploration_deck.size(),
		"une entree de la liste = un exemplaire dans le deck")
	var murs_en_jeu: int = 0
	for c in RunState.deck:
		if c.id == &"stone_wall":
			murs_en_jeu += 1
	ok(murs_en_jeu >= 1, "le mur est piochable en partie")


## Un niveau verrouille ne doit pas etre jouable : le niveau 2 etait accessible
## avant d avoir termine le 1, la campagne listait tout sans filtrer.
func _test_seuls_les_niveaux_debloques_sont_jouables() -> void:
	SaveData.reset_profile()
	var jouables: Array[LevelDef] = SaveData.playable_levels()
	ok(jouables.size() >= 1, "au moins un niveau est jouable sur un profil neuf")
	for lv in jouables:
		ok(SaveData.is_level_unlocked(lv.id),
			"%s est bien debloque" % lv.id)
	var total: int = ContentDB.levels.size()
	ok(jouables.size() < total or total == 1,
		"tous les niveaux ne sont pas offerts d emblee")

	# Apres la victoire sur le niveau 1, le niveau 2 devient jouable.
	var l1: LevelDef = ContentDB.levels.get(&"lvl_01")
	if l1 != null and not l1.next_levels.is_empty():
		var suivant: StringName = l1.next_levels[0]
		not_ok(SaveData.is_level_unlocked(suivant), "le niveau suivant est verrouille au depart")
		SaveData.record_victory(l1, GameEnums.Mode.EXPLORATION, {}, 6)
		ok(SaveData.is_level_unlocked(suivant), "il se debloque a la victoire")
		var apres: Array[LevelDef] = SaveData.playable_levels()
		eq(apres.size(), jouables.size() + 1, "la campagne propose un niveau de plus")
	SaveData.reset_profile()


## Le bouton pause doit pouvoir RELANCER la partie. Le HUD etait mis en pause avec
## le jeu : un seul clic figeait tout, y compris le moyen de repartir.
func _test_le_hud_reste_actif_en_pause() -> void:
	var packed: PackedScene = load("res://scenes/hud/HUD.tscn")
	ok(packed != null, "la scene du HUD existe")
	if packed == null:
		return
	var hud: Node = packed.instantiate()
	# Le mode est pose dans _ready() : on l appelle via l arbre.
	Engine.get_main_loop().root.add_child(hud)
	eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"le HUD continue de tourner quand l arbre est en pause")
	hud.queue_free()


# --- La coquille du menu (chantier C) ---

## Le nom du jeu et la forme de la barre d onglets. Ce sont des demandes
## explicites du testeur, donc des regressions possibles : un agent qui
## reintroduit un onglet BESTIAIRE ou le nom "Wizard Story" doit faire rougir
## le harnais, pas attendre une relecture de capture.
func _test_coquille_du_menu() -> void:
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	ok(packed != null, "la scene du menu existe")
	if packed == null:
		return
	var menu: Control = packed.instantiate()
	attach(menu)

	var tabs: Array = menu.get("TABS")
	eq(tabs.size(), 4, "quatre onglets : le bestiaire a fusionne, le profil est monte")
	not_ok(tabs.has("BESTIAIRE"), "plus d onglet BESTIAIRE dans la barre du bas")
	not_ok(tabs.has("PROFIL"), "le profil n est plus un onglet du bas")
	for attendu in ["GALERIE", "DECK", "CAMPAGNE", "REGLAGES"]:
		ok(tabs.has(attendu), "l onglet %s est present" % attendu)
	eq(tabs[int(menu.get("HOME_TAB"))], "CAMPAGNE",
		"l onglet central sureleve reste la CAMPAGNE")

	# Une icone par onglet, et AUCUNE des icones de materiel de Tiny Swords que
	# le testeur a refusees ("pas un steak pour la campagne" : icon_04).
	var icones: Array = menu.get("TAB_ICONS")
	eq(icones.size(), tabs.size(), "une icone par onglet")
	for nom in icones:
		ok(UiTheme.tex(String(nom)) != null, "l icone %s existe sur le disque" % nom)
	not_ok(icones.has("icon_04"), "le steak n est plus l icone de la campagne")

	# Chaque onglet doit s activer sans erreur.
	for i in tabs.size():
		menu.select_tab(i)
		eq(menu.current_tab(), i, "l onglet %s s active" % tabs[i])
	detach(menu)


## Le titre affiche "TIME WIZARD", et l en-tete porte le niveau du joueur et le
## compte de cartes, tous deux lus dans SaveData.
func _test_entete_affiche_niveau_et_cartes() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	var menu: Control = packed.instantiate()
	attach(menu)

	var titre: Label = menu.find_child("Title", true, false) as Label
	ok(titre != null, "le titre existe dans la scene")
	if titre != null:
		eq(titre.text, "TIME WIZARD", "le jeu s appelle desormais Time Wizard")
		not_ok(titre.text.to_lower().contains("story"), "l ancien nom a disparu")

	var niveau: Label = menu.find_child("LevelLabel", true, false) as Label
	ok(niveau != null, "le niveau du joueur est affiche en haut")
	if niveau != null:
		ok(niveau.text.contains(str(SaveData.account_level())),
			"l en-tete montre le niveau de compte reel (%s)" % niveau.text)

	var cartes: Label = menu.find_child("CardsLabel", true, false) as Label
	ok(cartes != null, "le compteur de cartes est affiche en haut")
	if cartes != null:
		ok(cartes.text.contains(str(SaveData.discovered_count())),
			"le compteur montre les cartes reellement decouvertes (%s)" % cartes.text)
		ok(cartes.text.contains(str(ContentDB.cards.size())),
			"et le total du contenu")
	detach(menu)


## Le profil ouvert par l avatar en haut a droite, et non par un onglet du bas.
func _test_profil_en_superposition() -> void:
	var packed: PackedScene = load("res://scenes/main_menu/MainMenu.tscn")
	var menu: Control = packed.instantiate()
	attach(menu)

	var bouton: Button = menu.find_child("ProfileButton", true, false) as Button
	ok(bouton != null, "le bouton PROFIL est dans la barre du haut")
	not_ok(menu.call("profile_open"), "ferme au depart")
	menu.call("show_profile", true)
	ok(menu.call("profile_open"), "l avatar ouvre le profil")
	# Changer d onglet doit le refermer, sinon il resterait pose par-dessus.
	menu.select_tab(0)
	not_ok(menu.call("profile_open"), "changer d onglet referme le profil")
	detach(menu)


## Le Massacre est une RECOMPENSE, pas une alternative offerte des la premiere
## seconde. Sans ce verrou, un joueur pouvait passer a cote de toute l histoire
## sans s en apercevoir — le mode sans fin etant juste a cote, des le depart.
##
## Le test porte sur la DONNEE (`campaign_cleared()`) et non sur l etat du
## bouton : une regle qui ne vit que dans un ecran disparait avec lui. C est la
## lecon des decks de campagne, qui violaient la regle des 15 cartes parce que
## seul le mode Massacre passait par la validation.
func _test_le_massacre_s_ouvre_a_la_fin_de_la_campagne() -> void:
	SaveData.reset_profile()
	not_ok(SaveData.campaign_cleared(),
		"un profil neuf n a pas fini la campagne")
	var p: Array = SaveData.campaign_progress()
	eq(int(p[0]), 0, "aucun niveau fini au depart")
	ok(int(p[1]) >= 7, "la campagne compte au moins 7 niveaux (%d)" % int(p[1]))

	# On finit TOUS les niveaux sauf un : le verrou doit tenir jusqu au dernier.
	var niveaux: Array = ContentDB.levels.values()
	for i in niveaux.size():
		var lv: LevelDef = niveaux[i]
		if i == niveaux.size() - 1:
			continue
		SaveData.record_victory(lv, GameEnums.Mode.EXPLORATION, {}, 6)
	not_ok(SaveData.campaign_cleared(),
		"il reste un niveau : le Massacre est encore ferme")
	eq(int(SaveData.campaign_progress()[0]), niveaux.size() - 1,
		"tous les niveaux sauf un sont finis")

	SaveData.record_victory(niveaux[niveaux.size() - 1],
		GameEnums.Mode.EXPLORATION, {}, 6)
	ok(SaveData.campaign_cleared(),
		"le dernier niveau fini ouvre le Massacre")
	SaveData.reset_profile()
