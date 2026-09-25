extends TestCase
## AMELIORATION DES CARTES EN COMBAT — "XP par lancer, choix parmi 3".
##
## Une carte que le joueur LANCE souvent gagne de l experience ; au palier il
## choisit une des trois voies proposees pour CE sort, et le choix vaut pour la
## PARTIE EN COURS seulement.
##
## POURQUOI PAS PERMANENT
## ----------------------
## Une amelioration permanente changerait la puissance du deck de depart d une
## partie a l autre. Tout l equilibrage du jeu est mesure au banc sur un depart
## connu (tools/sim_balance.gd rejoue les sept niveaux depuis zero) : si le deck
## de la dixieme partie frappe 40 % plus fort que celui de la premiere, les taux
## mesures ne decrivent plus aucune partie reelle. Et le joueur qui reprend au
## niveau 6 apres dix parties n y trouverait plus la difficulte annoncee.
## Ce test verrouille cette regle : reset() efface tout (voir
## _test_une_amelioration_ne_survit_pas_a_la_partie).
##
## REGLE DES TESTS
## ---------------
## Aucune valeur figee. Tout s exprime en RATIOS ou contre les constantes de
## GameConfig : ecrire eq(seuil, 8) interdirait de regler le seuil au banc, ce
## qui est justement ce qu il faut pouvoir faire.

func get_suite_name() -> String:
	return "upgrades"


func run() -> void:
	_test_le_compteur_de_lancers_monte_avec_les_lancers()
	_test_le_palier_vient_du_config_et_declenche_une_offre()
	_test_les_trois_voies_sont_des_choix_pas_un_classement()
	_test_une_voie_choisie_change_reellement_le_sort()
	_test_les_voies_ne_touchent_que_la_carte_amelioree()
	_test_une_carte_ne_s_ameliore_qu_une_fois_par_palier()
	_test_l_amelioration_ne_modifie_jamais_la_ressource_partagee()
	_test_une_amelioration_ne_survit_pas_a_la_partie()
	_test_le_contrat_du_grimoire_est_respecte()
	_test_toute_carte_du_catalogue_sait_proposer_trois_voies()
	_test_l_ecran_de_choix_occupe_reellement_l_ecran()


# --- Fabriques ---

## Une carte de degats direct, la forme la plus simple a mesurer.
func _carte_degats(id: String = "t_dmg", magnitude: float = 20.0,
		cast: float = 2.0) -> SpellCard:
	var s := EffectSpec.new()
	s.key = &"damage_single"
	s.magnitude = magnitude
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = "Test " + id
	c.base_cast_time = cast
	c.targeting = GameEnums.Targeting.TARGET
	c.effects = [s]
	return c


## Une carte de ZONE : c est la seule forme sur laquelle "plus large" a un sens.
func _carte_zone(id: String = "t_zone") -> SpellCard:
	var s := EffectSpec.new()
	s.key = &"ground_zone"
	s.magnitude = 12.0
	s.duration = 3.0
	s.radius = 150.0
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = "Test " + id
	c.base_cast_time = 2.0
	c.targeting = GameEnums.Targeting.POSITION
	c.effects = [s]
	return c


## Lance la carte N fois en passant par le SEUL point de comptage.
func _lancer(card: SpellCard, fois: int) -> void:
	for i in fois:
		RunState.note_cast(card)


# --- Tests ---

## Le compteur suit les LANCERS, pas la pioche ni la main : c est ce que le
## testeur a demande ("XP par lancer").
func _test_le_compteur_de_lancers_monte_avec_les_lancers() -> void:
	RunState.reset()
	var c: SpellCard = _carte_degats()
	eq(RunState.casts_of(c), 0, "une carte jamais lancee est a zero")
	_lancer(c, 3)
	eq(RunState.casts_of(c), 3, "trois lancers comptent trois")
	# Une autre carte n herite pas du compteur de la premiere.
	var autre: SpellCard = _carte_degats("t_autre")
	eq(RunState.casts_of(autre), 0, "le compteur est PAR CARTE")


## Le palier est un reglage, pas une constante enfouie : il vit dans GameConfig
## pour pouvoir etre deplace au banc sans toucher au code ni aux tests.
func _test_le_palier_vient_du_config_et_declenche_une_offre() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	ok(seuil >= 2, "le palier vaut au moins deux lancers, sinon tout s ameliore")
	var c: SpellCard = _carte_degats()
	# Un lancer SOUS le palier ne doit rien proposer.
	_lancer(c, seuil - 1)
	ok(RunState.pending_upgrade_card == null,
		"sous le palier (%d/%d), aucune amelioration n est proposee" % [seuil - 1, seuil])
	_lancer(c, 1)
	ok(RunState.pending_upgrade_card == c,
		"au palier exact (%d lancers), l amelioration de CETTE carte est proposee" % seuil)


func _test_les_trois_voies_sont_des_choix_pas_un_classement() -> void:
	RunState.reset()
	var c: SpellCard = _carte_zone()
	var voies: Array = RunState.upgrade_paths_for(c)
	eq(voies.size(), GameConfig.LEVEL_UP_CHOICES,
		"autant de voies que de choix de montee de niveau")
	# Un CHOIX, pas un classement : aucune voie ne doit dominer les deux autres
	# sur tous les axes a la fois. On lit les trois facteurs annonces par chaque
	# voie (degats, temps d incantation, ampleur) et on verifie qu aucune n est
	# meilleure ou egale partout.
	for i in voies.size():
		var a: Dictionary = voies[i]
		for j in voies.size():
			if i == j:
				continue
			var b: Dictionary = voies[j]
			var domine: bool = _au_moins_aussi_bien(a, b) and not _au_moins_aussi_bien(b, a)
			not_ok(domine, "la voie '%s' ne domine pas '%s' sur tous les axes"
				% [a.get("text", "?"), b.get("text", "?")])
	# CHAQUE voie doit PRENDRE quelque chose, pas seulement donner. La verification
	# de domination ci-dessus ne suffit pas : si les trois voies gagnaient chacune
	# sur un axe different SANS rien couter, aucune ne dominerait les autres et le
	# test passerait — alors que le joueur n aurait plus de decision a prendre,
	# seulement un bonus a encaisser. Constate en sabotant les trois constantes de
	# cout a zero : seuls deux tests sur onze avaient bronche.
	for v in voies:
		var gagne: bool = float(v.get("damage", 1.0)) > 1.0 			or float(v.get("cast", 1.0)) < 1.0 or float(v.get("area", 1.0)) > 1.0
		var perd: bool = float(v.get("damage", 1.0)) < 1.0 			or float(v.get("cast", 1.0)) > 1.0 or float(v.get("area", 1.0)) < 1.0
		ok(gagne, "la voie '%s' donne quelque chose" % v.get("text", "?"))
		ok(perd, "la voie '%s' PREND quelque chose : un bonus pur n est pas un choix"
			% v.get("text", "?"))

	# Chaque voie annonce un texte lisible : un ecran de choix muet est un ecran rate.
	for v in voies:
		ok(String(v.get("text", "")).length() > 8,
			"chaque voie porte un libelle lisible, pas une cle technique")
		ok(v.has("id"), "chaque voie porte un identifiant stable")


## "Au moins aussi bien" sur les trois axes : plus de degats, moins de temps
## d incantation, plus d ampleur.
func _au_moins_aussi_bien(a: Dictionary, b: Dictionary) -> bool:
	var da: float = float(a.get("damage", 1.0))
	var db: float = float(b.get("damage", 1.0))
	var ca: float = float(a.get("cast", 1.0))
	var cb: float = float(b.get("cast", 1.0))
	var aa: float = float(a.get("area", 1.0))
	var ab: float = float(b.get("area", 1.0))
	return da >= db and ca <= cb and aa >= ab


## Une voie choisie doit CHANGER le sort. Sans cette verification, tout le
## chantier pourrait se reduire a un ecran decoratif.
func _test_une_voie_choisie_change_reellement_le_sort() -> void:
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	# Voie PUISSANCE : plus de degats, incantation plus longue.
	RunState.reset()
	var c: SpellCard = _carte_degats()
	var degats_avant: float = RunState.cast_specs(c)[0].magnitude
	var cast_avant: float = RunState.effective_cast_time(c)
	_lancer(c, seuil)
	var i_puissance: int = _indice_de_voie(c, &"power")
	ok(i_puissance >= 0, "une voie PUISSANCE est proposee")
	RunState.pick_upgrade(i_puissance)
	var degats_apres: float = RunState.cast_specs(c)[0].magnitude
	var cast_apres: float = RunState.effective_cast_time(c)
	ok(degats_apres > degats_avant,
		"PUISSANCE augmente les degats (%.1f -> %.1f)" % [degats_avant, degats_apres])
	ok(cast_apres > cast_avant,
		"PUISSANCE se PAIE en temps d incantation (%.2f -> %.2f s)"
		% [cast_avant, cast_apres])

	# Voie CELERITE : incantation plus courte, degats en baisse.
	RunState.reset()
	var c2: SpellCard = _carte_degats("t_dmg2")
	var d2_avant: float = RunState.cast_specs(c2)[0].magnitude
	var t2_avant: float = RunState.effective_cast_time(c2)
	_lancer(c2, seuil)
	var i_celerite: int = _indice_de_voie(c2, &"haste")
	ok(i_celerite >= 0, "une voie CELERITE est proposee")
	RunState.pick_upgrade(i_celerite)
	ok(RunState.effective_cast_time(c2) < t2_avant,
		"CELERITE raccourcit l incantation (%.2f -> %.2f s)"
		% [t2_avant, RunState.effective_cast_time(c2)])
	ok(RunState.cast_specs(c2)[0].magnitude < d2_avant,
		"CELERITE se PAIE en degats (%.1f -> %.1f)"
		% [d2_avant, RunState.cast_specs(c2)[0].magnitude])

	# Voie AMPLEUR : rayon et duree en hausse sur une carte de zone.
	RunState.reset()
	var z: SpellCard = _carte_zone()
	var r_avant: float = RunState.cast_specs(z)[0].radius
	_lancer(z, seuil)
	var i_ampleur: int = _indice_de_voie(z, &"area")
	ok(i_ampleur >= 0, "une voie AMPLEUR est proposee sur une carte de zone")
	RunState.pick_upgrade(i_ampleur)
	ok(RunState.cast_specs(z)[0].radius > r_avant,
		"AMPLEUR elargit la zone (%.0f -> %.0f px)"
		% [r_avant, RunState.cast_specs(z)[0].radius])


func _indice_de_voie(card: SpellCard, id: StringName) -> int:
	var voies: Array = RunState.upgrade_paths_for(card)
	for i in voies.size():
		if StringName(voies[i].get("id", &"")) == id:
			return i
	return -1


## Ameliorer un sort ne doit pas ameliorer les autres : sinon le choix n est
## plus un choix mais un bonus global.
func _test_les_voies_ne_touchent_que_la_carte_amelioree() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var a: SpellCard = _carte_degats("t_a")
	var b: SpellCard = _carte_degats("t_b")
	var b_avant: float = RunState.cast_specs(b)[0].magnitude
	var b_cast_avant: float = RunState.effective_cast_time(b)
	_lancer(a, seuil)
	RunState.pick_upgrade(maxi(0, _indice_de_voie(a, &"power")))
	feq(RunState.cast_specs(b)[0].magnitude, b_avant,
		"la carte voisine garde ses degats")
	feq(RunState.effective_cast_time(b), b_cast_avant,
		"la carte voisine garde son temps d incantation", 0.001)


## Une carte deja amelioree ne repropose pas d offre au lancer suivant : sinon
## le sort favori ouvrirait un ecran modal toutes les huit incantations jusqu a
## la fin de la partie.
func _test_une_carte_ne_s_ameliore_qu_une_fois_par_palier() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_degats()
	_lancer(c, seuil)
	RunState.pick_upgrade(0)
	ok(RunState.pending_upgrade_card == null, "l offre est consommee par le choix")
	_lancer(c, seuil)
	ok(RunState.pending_upgrade_card == null,
		"une carte deja amelioree ne redemande rien au palier suivant")


## LE test qui protege le reste du jeu. Les EffectSpec sont des Resources
## PARTAGEES : le meme objet sert la carte en main, la fiche du grimoire et la
## prochaine partie. Ecrire dedans ferait fuir l amelioration partout, y compris
## dans le catalogue affiche au menu principal.
func _test_l_amelioration_ne_modifie_jamais_la_ressource_partagee() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_zone()
	var source: EffectSpec = c.effects[0]
	var mag: float = source.magnitude
	var rad: float = source.radius
	var dur: float = source.duration
	_lancer(c, seuil)
	RunState.pick_upgrade(maxi(0, _indice_de_voie(c, &"area")))
	var sortie: Array[EffectSpec] = RunState.cast_specs(c)
	ok(sortie[0] != source, "cast_specs rend une COPIE, jamais le spec du .tres")
	feq(source.magnitude, mag, "le spec d origine garde sa magnitude")
	feq(source.radius, rad, "le spec d origine garde son rayon")
	feq(source.duration, dur, "le spec d origine garde sa duree")


## L amelioration vaut pour LA PARTIE EN COURS. reset() est appele au debut de
## chaque niveau (GameController.start_level) : apres lui, plus aucune trace.
func _test_une_amelioration_ne_survit_pas_a_la_partie() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_degats()
	var avant: float = RunState.cast_specs(c)[0].magnitude
	_lancer(c, seuil)
	RunState.pick_upgrade(maxi(0, _indice_de_voie(c, &"power")))
	ok(RunState.cast_specs(c)[0].magnitude > avant, "l amelioration est bien active")
	RunState.reset()
	eq(RunState.casts_of(c), 0, "reset efface les compteurs de lancers")
	ok(RunState.upgrades_taken.is_empty(), "reset efface les ameliorations prises")
	feq(RunState.cast_specs(c)[0].magnitude, avant,
		"apres reset, le sort est revenu a ses valeurs de base")


## CONTRAT DU GRIMOIRE. GalleryPanel.upgrades_of() lit `card.upgrades` et attend
## une liste de {text: String, unlocked: bool}. Ce contrat a ete ecrit AVANT ce
## chantier pour que la fiche du grimoire n ait pas a etre retouchee : il est
## donc verrouille ici.
func _test_le_contrat_du_grimoire_est_respecte() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_zone()
	var lignes: Array = GalleryPanel.upgrades_of(c)
	eq(lignes.size(), GameConfig.LEVEL_UP_CHOICES,
		"le grimoire voit les trois voies des le depart")
	for l in lignes:
		ok(l is Dictionary, "chaque entree est un Dictionary")
		ok(l.has("text") and l.get("text") is String, "chaque entree porte un `text` String")
		ok(l.has("unlocked"), "chaque entree porte un `unlocked`")
		not_ok(bool(l.get("unlocked", true)),
			"avant tout choix, aucune voie n est marquee acquise")
	_lancer(c, seuil)
	var i: int = maxi(0, _indice_de_voie(c, &"area"))
	var voulue: String = String(RunState.upgrade_paths_for(c)[i].get("text", ""))
	RunState.pick_upgrade(i)
	var apres: Array = GalleryPanel.upgrades_of(c)
	var acquises: int = 0
	for l in apres:
		if bool(l.get("unlocked", false)):
			acquises += 1
			eq(String(l.get("text", "")), voulue, "la voie acquise est celle choisie")
	eq(acquises, 1, "une seule voie est acquise apres un choix")


## Toute carte du catalogue — y compris celles qu un autre chantier ajoutera —
## doit savoir proposer trois voies. Les voies sont DERIVEES des effets de la
## carte, pas ecrites a la main dans chaque .tres : sans cela, chaque nouveau
## sort arriverait sans amelioration et le systeme mentirait au joueur.
func _test_toute_carte_du_catalogue_sait_proposer_trois_voies() -> void:
	RunState.reset()
	var vues: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		vues += 1
		var voies: Array = RunState.upgrade_paths_for(c)
		eq(voies.size(), GameConfig.LEVEL_UP_CHOICES,
			"%s propose trois voies" % c.id)
		# Les voies doivent etre DISTINCTES : trois fois la meme n est pas un choix.
		var ids: Dictionary = {}
		for v in voies:
			ids[StringName(v.get("id", &""))] = true
		eq(ids.size(), voies.size(), "%s : les trois voies sont distinctes" % c.id)
	ok(vues > 0, "le catalogue contient des sorts a examiner")


## L ECRAN DE CHOIX, verrouille sur ce qui a reellement casse.
##
## Le panneau s est construit sans erreur, le harnais est reste vert, et la
## CAPTURE a montre un ecran inutilisable : `set_anchors_preset()` pose les
## ancres sans toucher aux offsets, le panneau restait de taille (0,0) et tout
## le contenu se dessinait a sa taille naturelle dans le coin haut-gauche. Rien
## ne plante, donc aucun etage ne le voit. Ce test mesure la seule chose qui
## trahit le defaut sans regarder l image : la taille du panneau.
func _test_l_ecran_de_choix_occupe_reellement_l_ecran() -> void:
	RunState.reset()
	var c: SpellCard = _carte_zone()
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var panneau := CardUpgradePanel.new()
	hote.add_child(panneau)
	panneau.show_paths(c, RunState.upgrade_paths_for(c))
	# Pas besoin d attendre une frame : le preset ancres+offsets pose la taille
	# immediatement. C est justement ce que l ancienne version NE faisait pas.
	ok(panneau.size.x >= hote.size.x * 0.99 and panneau.size.y >= hote.size.y * 0.99,
		"le panneau couvre son hote (%s pour %s)" % [panneau.size, hote.size])
	detach(hote)
