extends TestCase
## Bestiaire (memorisation des rencontres + traduction des comportements) et
## double toucher de l ecran de deck.
##
## Ces deux ecrans reposent sur une REGLE, pas seulement sur de l affichage :
##   - un monstre n apparait au bestiaire qu apres avoir ete rencontre ;
##   - une carte n entre au deck qu au SECOND toucher.
## Les deux regles sont donc testables a froid, sans ouvrir le jeu.

func get_suite_name() -> String:
	return "bestiary"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_aucune_rencontre_au_depart()
	_test_rencontre_memorisee()
	_test_rencontre_idempotente()
	_test_liste_rendue_est_une_copie()
	_test_spawn_enregistre_la_rencontre()
	_test_tous_les_monstres_ont_une_description()
	_test_comportements_lisibles()
	_test_comportements_jamais_vides()
	_test_le_panneau_se_construit()
	_test_double_toucher_du_deck()
	SaveData.reset_profile()
	ContentDB.discover_starters()


# --- Memorisation des rencontres ---

func _test_aucune_rencontre_au_depart() -> void:
	SaveData.reset_profile()
	eq(SaveData.discovered_enemies_count(), 0, "profil neuf : aucun monstre connu")
	not_ok(SaveData.is_enemy_discovered(&"jelly"), "la gelee est inconnue au depart")


func _test_rencontre_memorisee() -> void:
	SaveData.discover_enemy(&"jelly")
	ok(SaveData.is_enemy_discovered(&"jelly"), "la gelee est memorisee apres rencontre")
	not_ok(SaveData.is_enemy_discovered(&"shade"), "un autre monstre reste inconnu")
	eq(SaveData.discovered_enemies_count(), 1, "un seul monstre au bestiaire")


## spawn_enemy appelle discover_enemy a CHAQUE apparition : la 40e gelee de la
## vague ne doit ni dupliquer l entree ni re-emettre profile_changed.
func _test_rencontre_idempotente() -> void:
	var emissions: Array[int] = [0]
	var cb: Callable = func() -> void: emissions[0] += 1
	SaveData.profile_changed.connect(cb)
	for i in 10:
		SaveData.discover_enemy(&"jelly")
	SaveData.profile_changed.disconnect(cb)
	eq(SaveData.discovered_enemies_count(), 1, "10 rencontres de plus = toujours une entree")
	eq(emissions[0], 0, "une rencontre deja connue ne reconstruit pas l interface")

	# Une cle vide ne doit jamais entrer au bestiaire.
	SaveData.discover_enemy(&"")
	eq(SaveData.discovered_enemies_count(), 1, "un id vide est ignore")


## Piege deja rencontre sur offer_choices() : rendre le tableau interne laisse
## l appelant vider le profil.
func _test_liste_rendue_est_une_copie() -> void:
	var avant: int = SaveData.discovered_enemies_count()
	var liste: Array = SaveData.discovered_enemies()
	liste.clear()
	eq(SaveData.discovered_enemies_count(), avant,
		"vider la liste rendue ne touche pas le profil")


## Le branchement reel : faire apparaitre un monstre doit l inscrire au
## bestiaire. Sans ce test, retirer la ligne de spawn_enemy passerait inapercu.
func _test_spawn_enregistre_la_rencontre() -> void:
	SaveData.reset_profile()
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	ok(packed != null, "la scene de jeu existe")
	if packed == null:
		return
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	var def: EnemyDef = ContentDB.enemies.get(&"jelly")
	ok(def != null, "la gelee existe dans le contenu")
	if def != null:
		not_ok(SaveData.is_enemy_discovered(def.id), "inconnue avant l apparition")
		g.battlefield.spawn_enemy(def, 400.0)
		ok(SaveData.is_enemy_discovered(def.id),
			"faire apparaitre un monstre l inscrit au bestiaire")
	detach(g)


# --- Traduction des comportements en texte lisible ---

## Chaque monstre du jeu doit produire au moins une phrase : une fiche vide
## ferait croire a un ecran casse.
func _test_tous_les_monstres_ont_une_description() -> void:
	for def: EnemyDef in ContentDB.enemies.values():
		var lignes: Array[String] = BestiaryPanel.behaviours(def)
		ok(lignes.size() >= 1, "%s a au moins une competence decrite" % def.id)
		for l in lignes:
			ok(l.strip_edges() != "", "%s : aucune ligne vide" % def.id)
		ok(BestiaryPanel.kind_name(def.kind) != "", "%s a un nom de famille" % def.id)


## Les phrases decrivent bien LE champ qui les declenche. On lit les champs et
## non le `kind` : un monstre cumule des comportements, le kind n en nomme qu un.
func _test_comportements_lisibles() -> void:
	var jelly: EnemyDef = ContentDB.enemies.get(&"jelly")
	if jelly != null and jelly.split_count > 0:
		ok(_contient(BestiaryPanel.behaviours(jelly), "divise"),
			"la gelee annonce qu elle se divise")

	# On teste la traduction sur une definition construite a la main plutot que
	# sur du contenu livre : un reglage d equilibrage ne doit pas casser ce test.
	var d := EnemyDef.new()
	d.id = &"test_dummy"
	d.display_name = "Mannequin"
	d.shoot_interval = 2.0
	d.shot_damage = 3
	d.immune_tags = [GameEnums.DamageTag.SLOW]
	d.dodge_chance = 0.25
	var lignes: Array[String] = BestiaryPanel.behaviours(d)
	ok(_contient(lignes, "Tire a distance"), "un tireur annonce sa portee")
	ok(_contient(lignes, "ralentissement"), "une immunite est nommee en clair")
	ok(_contient(lignes, "25"), "le pourcentage d esquive est chiffre")
	not_ok(_contient(lignes, "shoot_interval"),
		"aucun nom de champ technique ne fuit dans le texte du joueur")


func _test_comportements_jamais_vides() -> void:
	var nu := EnemyDef.new()
	nu.id = &"test_nu"
	var lignes: Array[String] = BestiaryPanel.behaviours(nu)
	eq(lignes.size(), 1, "un monstre sans particularite a une ligne de repli")

	# Et rien ne doit planter sur une definition absente.
	eq(BestiaryPanel.behaviours(null).size(), 0, "null ne fait pas planter la fiche")


## L ecran lui-meme : construction et comptage, tuiles verrouillees comprises.
func _test_le_panneau_se_construit() -> void:
	SaveData.reset_profile()
	var panel := BestiaryPanel.new()
	attach(panel)
	panel.refresh()
	var total: int = BestiaryPanel.listed_enemies().size()
	ok(total >= 1, "le bestiaire liste des monstres (%d)" % total)
	eq(total, ContentDB.enemies.size(), "tous les monstres du contenu sont listes")

	SaveData.discover_enemy(&"jelly")
	panel.refresh()
	eq(SaveData.discovered_enemies_count(), 1, "une rencontre apres refresh")
	detach(panel)


# --- Double toucher de l ecran de deck ---

## Le 1er toucher montre l effet, le 2e ajoute, une autre carte remet a zero.
func _test_double_toucher_du_deck() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var panel := DeckPanel.new()
	attach(panel)
	panel.refresh()

	var a: SpellCard = _premiere_carte_ajoutable(panel, &"")
	ok(a != null, "au moins une carte decouverte est ajoutable")
	if a == null:
		detach(panel)
		return

	var avant: int = SaveData.massacre_deck().size()
	panel._on_collection_tap(a)
	eq(panel.armed_card(), a.id, "le premier toucher arme la carte")
	eq(SaveData.massacre_deck().size(), avant,
		"le premier toucher n ajoute RIEN : il ne fait que montrer l effet")

	panel._on_collection_tap(a)
	eq(SaveData.massacre_deck().size(), avant + 1,
		"le second toucher sur la meme carte ajoute au deck")
	eq(panel.armed_card(), &"", "et desarme : le toucher suivant re-affichera l effet")

	# Une autre carte remet le compteur a zero au lieu de s ajouter.
	var b: SpellCard = _premiere_carte_ajoutable(panel, a.id)
	if b != null:
		panel._on_collection_tap(a)
		eq(panel.armed_card(), a.id, "carte A armee")
		var n: int = SaveData.massacre_deck().size()
		panel._on_collection_tap(b)
		eq(panel.armed_card(), b.id, "toucher une AUTRE carte remet le compteur a zero")
		eq(SaveData.massacre_deck().size(), n,
			"changer de carte n ajoute rien, meme si A etait armee")

	# Revenir sur l onglet doit desarmer.
	panel.refresh()
	eq(panel.armed_card(), &"", "refresh() desarme le double toucher")
	detach(panel)


func _premiere_carte_ajoutable(panel: DeckPanel, sauf: StringName) -> SpellCard:
	var ids: Array = SaveData.massacre_deck()
	for card: SpellCard in ContentDB.cards.values():
		if card.id == sauf or not SaveData.is_discovered(card.id):
			continue
		if DeckRules.can_add(ids, card, true) and ids.size() < DeckRules.MAX_CARDS:
			return card
	return null


func _contient(lignes: Array[String], motif: String) -> bool:
	for l in lignes:
		if l.findn(motif) != -1:
			return true
	return false
