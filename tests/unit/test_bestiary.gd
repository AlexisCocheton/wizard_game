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
	_test_grimoire_trois_sections()
	_test_grimoire_pagination()
	_test_grimoire_fleches_dans_la_fiche()
	_test_grimoire_compteurs_dusage()
	_test_grimoire_compteurs_branches()
	_test_grimoire_ameliorations()
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
		var lignes: Array[String] = BestiaryLore.behaviours(def)
		ok(lignes.size() >= 1, "%s a au moins une competence decrite" % def.id)
		for l in lignes:
			ok(l.strip_edges() != "", "%s : aucune ligne vide" % def.id)
		ok(BestiaryLore.kind_name(def.kind) != "", "%s a un nom de famille" % def.id)


## Les phrases decrivent bien LE champ qui les declenche. On lit les champs et
## non le `kind` : un monstre cumule des comportements, le kind n en nomme qu un.
func _test_comportements_lisibles() -> void:
	var jelly: EnemyDef = ContentDB.enemies.get(&"jelly")
	if jelly != null and jelly.split_count > 0:
		ok(_contient(BestiaryLore.behaviours(jelly), "divise"),
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
	var lignes: Array[String] = BestiaryLore.behaviours(d)
	ok(_contient(lignes, "Tire a distance"), "un tireur annonce sa portee")
	ok(_contient(lignes, "ralentissement"), "une immunite est nommee en clair")
	ok(_contient(lignes, "25"), "le pourcentage d esquive est chiffre")
	not_ok(_contient(lignes, "shoot_interval"),
		"aucun nom de champ technique ne fuit dans le texte du joueur")


func _test_comportements_jamais_vides() -> void:
	var nu := EnemyDef.new()
	nu.id = &"test_nu"
	var lignes: Array[String] = BestiaryLore.behaviours(nu)
	eq(lignes.size(), 1, "un monstre sans particularite a une ligne de repli")

	# Et rien ne doit planter sur une definition absente.
	eq(BestiaryLore.behaviours(null).size(), 0, "null ne fait pas planter la fiche")


## L ecran lui-meme : c est desormais la section BESTIAIRE du grimoire.
func _test_le_panneau_se_construit() -> void:
	SaveData.reset_profile()
	var panel := GalleryPanel.new()
	attach(panel)
	panel.show_section(GalleryPanel.Section.BEASTS)
	var total: int = GalleryPanel.entries_of(GalleryPanel.Section.BEASTS).size()
	ok(total >= 1, "le bestiaire liste des monstres (%d)" % total)
	# Toutes les CREATURES, et elles seules. Comparer au total brut de
	# ContentDB.enemies exigeait aussi les PROJECTILES (la boule de poison tiree
	# par un Planogo), alors que le commentaire d EnemyDef.projectile promet
	# l inverse : "ni bestiaire, ni XP".
	var creatures: int = 0
	for e: EnemyDef in ContentDB.enemies.values():
		if not e.projectile:
			creatures += 1
	eq(total, creatures, "toutes les creatures du contenu sont listees")

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
	# Le deck de depart fait desormais PILE 15 cartes (chantier K) : plus une
	# seule case libre, donc plus rien d ajoutable. On en retire deux pour
	# rendre au double toucher la place qu il lui faut pour s exercer.
	var place: Array = SaveData.massacre_deck()
	place.resize(maxi(0, place.size() - 2))
	SaveData.set_massacre_deck(place)
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


# --- Le grimoire (galerie + bestiaire fusionnes, DEC-018) ---

## Les trois sections ne se melangent pas : un passif n est pas un sort, et la
## somme des deux sections de cartes doit couvrir TOUT le contenu. Sans ce test,
## une carte passive ajoutee plus tard pourrait n apparaitre nulle part.
func _test_grimoire_trois_sections() -> void:
	var sorts: Array = GalleryPanel.entries_of(GalleryPanel.Section.SPELLS)
	var passifs: Array = GalleryPanel.entries_of(GalleryPanel.Section.PASSIVES)
	var betes: Array = GalleryPanel.entries_of(GalleryPanel.Section.BEASTS)
	eq(sorts.size() + passifs.size(), ContentDB.cards.size(),
		"sorts + passifs = toutes les cartes du jeu, aucune carte orpheline")
	var vraies: int = 0
	for e: EnemyDef in ContentDB.enemies.values():
		if not e.projectile:
			vraies += 1
	eq(betes.size(), vraies, "le bestiaire liste toutes les creatures")
	# Et AUCUN projectile : sans cette moitie, le test passerait encore si le
	# filtre disparaissait et que quelqu un ajoutait une creature en meme temps.
	for e: EnemyDef in betes:
		not_ok(e.projectile,
			"%s est un projectile, il n a pas de fiche de bestiaire" % e.id)
	ok(vraies < ContentDB.enemies.size(),
		"le contenu contient bien au moins un projectile a exclure (%d sur %d)"
		% [ContentDB.enemies.size() - vraies, ContentDB.enemies.size()])
	ok(passifs.size() >= 1, "il y a au moins un passif (%d)" % passifs.size())
	for c: SpellCard in sorts:
		not_ok(c.is_passive, "%s est dans SORTS donc n est pas passive" % c.id)
	for c: SpellCard in passifs:
		ok(c.is_passive, "%s est dans PASSIFS donc est passive" % c.id)


## La pagination est la regle de l ecran : 9 par page, au moins une page meme
## vide, et tourner revient au debut apres la derniere page.
func _test_grimoire_pagination() -> void:
	eq(GalleryPanel.pages_for(0), 1, "une section vide garde une page, pas zero")
	eq(GalleryPanel.pages_for(9), 1, "9 entrees tiennent sur une page")
	eq(GalleryPanel.pages_for(10), 2, "la 10e entree ouvre une deuxieme page")
	eq(GalleryPanel.pages_for(27), 3, "27 entrees = 3 pages pleines")

	var panel := GalleryPanel.new()
	attach(panel)
	panel.show_section(GalleryPanel.Section.SPELLS)
	eq(panel.current_page(), 0, "on ouvre une section a sa premiere page")
	var total: int = panel.page_count()
	ok(total >= 2, "les sorts tiennent sur plusieurs pages (%d)" % total)
	panel.turn_page(1)
	eq(panel.current_page(), 1, "la fleche droite avance d une page")
	panel.turn_page(-1)
	eq(panel.current_page(), 0, "la fleche gauche revient")
	# Boucle : depuis la premiere page, reculer mene a la DERNIERE. Le joueur qui
	# cherche une legendaire l atteint d un toucher au lieu de quatre.
	panel.turn_page(-1)
	eq(panel.current_page(), total - 1, "reculer depuis la page 1 boucle a la fin")
	panel.turn_page(1)
	eq(panel.current_page(), 0, "et avancer depuis la fin revient au debut")

	# Changer de section repart de la premiere page : rester en page 4 dans une
	# section qui n en a que 2 afficherait une page vide.
	panel.turn_page(1)
	panel.show_section(GalleryPanel.Section.PASSIVES)
	eq(panel.current_page(), 0, "changer de section remet a la page 1")
	eq(panel.current_section(), GalleryPanel.Section.PASSIVES, "la section a bien change")
	detach(panel)


## Demande explicite du testeur : "les memes fleches defilent au suivant dans le
## detail". Dans la fiche, tourner ne change donc pas de page mais d ENTREE.
func _test_grimoire_fleches_dans_la_fiche() -> void:
	var panel := GalleryPanel.new()
	attach(panel)
	panel.show_section(GalleryPanel.Section.SPELLS)
	var n: int = panel.entries().size()
	ok(n >= 2, "au moins deux sorts pour pouvoir defiler")
	eq(panel.detail_index(), -1, "aucune fiche ouverte au depart")

	panel.open_detail(0)
	eq(panel.detail_index(), 0, "la fiche 0 est ouverte")
	panel.turn_page(1)
	eq(panel.detail_index(), 1, "dans la fiche, la fleche passe a l entree suivante")
	panel.turn_page(-1)
	eq(panel.detail_index(), 0, "et l autre fleche a la precedente")
	panel.turn_page(-1)
	eq(panel.detail_index(), n - 1, "la fiche boucle comme les pages")

	# La page suit la fiche : en fermant sur la derniere entree, on ne retombe
	# pas page 1 en ayant perdu sa place.
	eq(panel.current_page(), (n - 1) / GalleryPanel.PER_PAGE,
		"la page courante suit l entree affichee")
	panel.close_detail()
	eq(panel.detail_index(), -1, "FERMER referme la fiche")

	# Un index hors liste ne doit rien ouvrir plutot que planter.
	panel.open_detail(9999)
	eq(panel.detail_index(), -1, "un index hors liste n ouvre rien")
	detach(panel)


## Les deux compteurs demandes : usages d un sort et monstres tues par espece.
## Ils passent par ChallengeTracker, donc sont persistes avec le profil.
func _test_grimoire_compteurs_dusage() -> void:
	SaveData.reset_profile()
	eq(GalleryPanel.card_uses(&"fireball"), 0, "profil neuf : aucun lancer compte")
	eq(GalleryPanel.kills_of(&"jelly"), 0, "profil neuf : aucune gelee tuee")

	ChallengeTracker.bump(&"card_uses:fireball")
	ChallengeTracker.bump(&"card_uses:fireball")
	eq(GalleryPanel.card_uses(&"fireball"), 2, "deux lancers comptes")
	eq(GalleryPanel.card_uses(&"spark"), 0, "le compteur est PAR CARTE, pas global")

	ChallengeTracker.bump(&"kills:jelly", 3)
	eq(GalleryPanel.kills_of(&"jelly"), 3, "trois gelees vaincues")
	eq(GalleryPanel.kills_of(&"shade"), 0, "le compteur est PAR ESPECE")


## Le branchement REEL des deux compteurs. Sans ces deux tests, retirer la ligne
## de EffectRegistry.cast() ou celle de GameController passerait inapercu :
## l ecran afficherait tranquillement zero pour toujours.
func _test_grimoire_compteurs_branches() -> void:
	SaveData.reset_profile()
	var card: SpellCard = ContentDB.cards.get(&"fireball")
	ok(card != null, "la boule de feu existe")
	if card == null:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)

	var avant: int = GalleryPanel.card_uses(card.id)
	var ctx: CastContext = CastContext.make(g.battlefield, card)
	ctx.target_position = Vector2(500.0, 900.0)
	EffectRegistry.cast(card, ctx)
	eq(GalleryPanel.card_uses(card.id), avant + 1,
		"lancer un sort incremente son compteur d usage")

	var def: EnemyDef = ContentDB.enemies.get(&"jelly")
	if def != null:
		var tues: int = GalleryPanel.kills_of(def.id)
		g._on_enemy_killed_for_challenges(def)
		eq(GalleryPanel.kills_of(def.id), tues + 1,
			"tuer un monstre incremente le compteur de son espece")
	detach(g)


## La section AMELIORATIONS doit exister AVANT le systeme d amelioration : elle
## annonce au joueur ce qui l attend. Tant que les cartes n ont pas le champ,
## la liste est vide et l ecran affiche "a decouvrir en combat".
func _test_grimoire_ameliorations() -> void:
	for card: SpellCard in ContentDB.cards.values():
		var ups: Array = GalleryPanel.upgrades_of(card)
		for u in ups:
			ok(u is Dictionary, "%s : une amelioration est un dictionnaire" % card.id)
			ok(String(u.get("text", "")) != "", "%s : une amelioration a un texte" % card.id)
	eq(GalleryPanel.upgrades_of(null).size(), 0, "null ne fait pas planter la fiche")
