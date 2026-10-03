extends TestCase
## AMELIORATION DES CARTES EN COMBAT — "XP par lancer, choix parmi 3".
##
## Une carte que le joueur LANCE souvent gagne de l experience ; au palier il
## choisit une des voies proposees pour CE sort, et le choix vaut pour la
## PARTIE EN COURS seulement.
##
## Depuis la vague 5 (chantier U), les voies sont PROPRES A CHAQUE SORT : elles
## derivent de ses effets (degats, ralentissement, PV, zone, nombre de cibles,
## duree, vitesse de lancement...) et existent en deux formes, LEGERE (petit gain
## gratuit) et FORTE (gros gain paye sur un autre axe).
##
## Depuis la vague 6 (chantier U2), chaque sort a un POOL de voies plus grand que
## l ecran ; chaque maturation en TIRE trois avec le RNG de la partie, et un sort
## peut murir plusieurs fois (GameConfig.CARD_UPGRADE_TIERS), les voies se
## cumulant.
##
## POURQUOI PAS PERMANENT
## ----------------------
## Une amelioration permanente changerait la puissance du deck de depart d une
## partie a l autre. Tout l equilibrage du jeu est mesure au banc sur un depart
## connu : si le deck de la dixieme partie frappe 30 % plus fort que celui de la
## premiere, les taux mesures ne decrivent plus aucune partie reelle.
## Verrouille par _test_une_amelioration_ne_survit_pas_a_la_partie.
##
## REGLE DES TESTS
## ---------------
## Aucune valeur de REGLAGE figee. Tout s exprime en RATIOS ou contre les
## constantes de GameConfig : ecrire eq(gain, 0.30) interdirait de regler les
## voies au banc, ce qui est justement ce qu il faut pouvoir faire.

func get_suite_name() -> String:
	return "upgrades"


func run() -> void:
	_test_le_compteur_de_lancers_monte_avec_les_lancers()
	_test_le_palier_vient_du_config_et_declenche_une_offre()
	_test_jamais_une_voie_sans_objet_sur_la_carte()
	_test_les_voies_suivent_les_effets_du_sort()
	_test_chaque_sort_a_plus_de_voies_que_l_ecran()
	_test_le_tirage_melange_les_formes_et_les_axes()
	_test_le_tirage_varie_d_une_partie_a_l_autre_et_se_rejoue()
	_test_legere_gratuite_forte_payee()
	_test_aucune_voie_ne_domine_une_autre()
	_test_application_exacte_de_chaque_axe()
	_test_la_vitesse_de_lancement_est_l_inverse_du_temps()
	_test_le_nombre_est_entier_et_la_forte_depasse_la_legere()
	_test_le_ralentissement_ne_depasse_jamais_le_plafond()
	_test_toute_voie_du_catalogue_change_reellement_le_sort()
	_test_les_voies_ne_touchent_que_la_carte_amelioree()
	_test_une_carte_ne_s_ameliore_qu_une_fois_par_palier()
	_test_les_maturations_se_cumulent()
	_test_renoncer_consomme_le_palier_seulement()
	_test_le_lisere_suit_la_prochaine_maturation()
	_test_les_axes_en_cartes_piochent_et_defaussent()
	_test_l_amelioration_ne_modifie_jamais_la_ressource_partagee()
	_test_une_amelioration_ne_survit_pas_a_la_partie()
	_test_le_contrat_du_grimoire_est_respecte()
	_test_l_ecran_affiche_gain_et_prix_signes()
	_test_l_ecran_de_choix_occupe_reellement_l_ecran()


# --- Fabriques ---

func _spec(key: StringName, magnitude: float = 0.0, duration: float = 0.0,
		radius: float = 0.0, params: Dictionary = {}) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = key
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	return s


func _carte(id: String, specs: Array, cast: float = 2.0) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = "Test " + id
	c.base_cast_time = cast
	c.targeting = GameEnums.Targeting.POSITION
	var typed: Array[EffectSpec] = []
	for s in specs:
		typed.append(s)
	c.effects = typed
	return c


## Une carte de degats direct, sans zone ni nombre : la forme la plus simple.
func _carte_degats(id: String = "t_dmg", magnitude: float = 20.0) -> SpellCard:
	return _carte(id, [_spec(&"damage_single", magnitude)])


## Une carte de ZONE qui dure : degats, rayon et duree.
func _carte_zone(id: String = "t_zone") -> SpellCard:
	return _carte(id, [_spec(&"ground_zone", 12.0, 3.0, 150.0)])


## Lance la carte N fois en passant par le SEUL point de comptage.
func _lancer(card: SpellCard, fois: int) -> void:
	for i in fois:
		RunState.note_cast(card)


## Repart d une partie neuve et IMPOSE la voie `id` a la carte. Le tirage ne
## montre que trois voies du pool : pour verifier chaque voie du catalogue, on
## ne peut pas attendre que le hasard la propose.
func _prendre(card: SpellCard, id: StringName) -> bool:
	RunState.reset()
	if RunState.upgrade_path_by_id(card, id).is_empty():
		return false
	RunState.upgrades_taken[card.id] = [id]
	return true


## Indice de la voie `id` dans l offre EN ATTENTE, -1 si le tirage ne l a pas
## retenue.
func _indice_de_voie(_card: SpellCard, id: StringName) -> int:
	var voies: Array = RunState.pending_upgrade_paths
	for i in voies.size():
		if StringName(voies[i].get("id", &"")) == id:
			return i
	return -1


func _ids(voies: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in voies:
		out.append(StringName(v.get("id", &"")))
	return out


func _axes_proposes(card: SpellCard) -> Dictionary:
	var out: Dictionary = {}
	for v in RunState.upgrade_pool_for(card):
		for a in (v.get("mods", {}) as Dictionary):
			out[StringName(a)] = true
	return out


# --- Tests ---

## Le compteur suit les LANCERS, pas la pioche ni la main : c est ce que le
## testeur a demande ("XP par lancer").
func _test_le_compteur_de_lancers_monte_avec_les_lancers() -> void:
	RunState.reset()
	var c: SpellCard = _carte_degats()
	eq(RunState.casts_of(c), 0, "une carte jamais lancee est a zero")
	_lancer(c, 3)
	eq(RunState.casts_of(c), 3, "trois lancers comptent trois")
	var autre: SpellCard = _carte_degats("t_autre")
	eq(RunState.casts_of(autre), 0, "le compteur est PAR CARTE")


## Le palier est un reglage, pas une constante enfouie.
func _test_le_palier_vient_du_config_et_declenche_une_offre() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	ok(seuil >= 2, "le palier vaut au moins deux lancers, sinon tout s ameliore")
	var c: SpellCard = _carte_degats()
	_lancer(c, seuil - 1)
	ok(RunState.pending_upgrade_card == null,
		"sous le palier (%d/%d), aucune amelioration n est proposee" % [seuil - 1, seuil])
	_lancer(c, 1)
	ok(RunState.pending_upgrade_card == c,
		"au palier exact (%d lancers), l amelioration de CETTE carte est proposee" % seuil)


## LA REGLE DU CO-AUTEUR : jamais "+zone" sur un sort sans zone, jamais
## "+projectiles" sur un sort unique. Verifie sur TOUT le catalogue, avec une
## lecture des effets ecrite ICI, independante de RunState : si la table des axes
## derivait, les deux lectures divergeraient et le test mordrait.
func _test_jamais_une_voie_sans_objet_sur_la_carte() -> void:
	RunState.reset()
	var vues: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		vues += 1
		var axes: Dictionary = _axes_proposes(c)
		if axes.has(&"area"):
			ok(_a_une_zone(c), "%s : '+zone' proposee sans aucune zone" % c.id)
		if axes.has(&"count"):
			ok(_a_un_nombre(c), "%s : '+nombre' propose sur un sort unique" % c.id)
		if axes.has(&"duration"):
			ok(_dure(c), "%s : '+duree' proposee sur un effet instantane" % c.id)
		if axes.has(&"damage"):
			ok(_a_des_degats(c), "%s : '+degats' propose sur un sort sans degats" % c.id)
		if axes.has(&"slow"):
			ok(_ralentit(c), "%s : '+ralentissement' sur un sort qui ne ralentit pas" % c.id)
		if axes.has(&"hp"):
			ok(_a_des_pv(c), "%s : '+PV' sur un sort sans objet destructible" % c.id)
	ok(vues > 0, "le catalogue contient des sorts a examiner")

	# Et sur deux cartes fabriquees, pour que la regle ne depende pas du contenu.
	var unique: SpellCard = _carte_degats("t_unique")
	var a_u: Dictionary = _axes_proposes(unique)
	not_ok(a_u.has(&"area"), "un trait a cible unique ne propose pas '+zone'")
	not_ok(a_u.has(&"count"), "un trait a cible unique ne propose pas '+projectiles'")
	not_ok(a_u.has(&"duration"), "un trait instantane ne propose pas '+duree'")


func _a_une_zone(c: SpellCard) -> bool:
	for s in c.effects:
		if s != null and s.radius > 0.0 and s.key != &"build_wall":
			return true
	return false


func _a_un_nombre(c: SpellCard) -> bool:
	for s in c.effects:
		if s == null:
			continue
		if s.key == &"retain_next" and s.magnitude >= 1.0:
			return true
		for p in [&"max_targets", &"impacts", &"count", &"draw"]:
			if s.params.has(p) and int(s.params[p]) < GameConfig.UPGRADE_COUNT_UNLIMITED:
				return true
	return false


func _dure(c: SpellCard) -> bool:
	for s in c.effects:
		if s != null and s.duration >= GameConfig.UPGRADE_MIN_DURATION:
			return true
	return false


func _a_des_degats(c: SpellCard) -> bool:
	for s in c.effects:
		if s == null:
			continue
		if float(s.params.get(&"ally_damage", 0.0)) > 0.0:
			return true
		if s.magnitude > 0.0 and s.key in [&"damage_single", &"pierce_line",
				&"ground_zone", &"damage_per_enemy", &"summon_ally", &"knockback",
				&"meteor_storm", &"stun_zone", &"place_terrain", &"taunt_prop",
				# Vague 8 : le poison porte par le monstre (Dard venimeux) est un
				# debit de degats, comme une zone.
				&"poison_dot"]:
			return true
	return false


func _ralentit(c: SpellCard) -> bool:
	for s in c.effects:
		if s != null and (float(s.params.get(&"slow_pct", 0.0)) > 0.0
				or (s.key == &"slow_enemy_gauge" and s.magnitude > 0.0)):
			return true
	return false


func _a_des_pv(c: SpellCard) -> bool:
	for s in c.effects:
		if s != null and (float(s.params.get(&"prop_hp", 0.0)) > 0.0
				or float(s.params.get(&"wall_hp", 0.0)) > 0.0):
			return true
	return false


## Les voies suivent le sort : un sort de ralentissement propose le
## ralentissement, un mur solide ses PV, une ligne percante ses cibles, une
## pluie de meteores ses impacts. Sans cette verification, un systeme qui ne
## proposerait que "degats / zone / vitesse" passerait les autres tests.
func _test_les_voies_suivent_les_effets_du_sort() -> void:
	RunState.reset()
	var givre: SpellCard = _carte("t_givre", [_spec(&"ground_zone", 1.0, 5.0, 180.0,
		{&"slow_pct": 40.0})])
	ok(_axes_proposes(givre).has(&"slow"), "un champ de givre propose le RALENTISSEMENT")
	ok(StringName(RunState.upgrade_pool_for(givre)[0].get("axis", &"")) == &"slow",
		"sur un sort qui ralentit, le ralentissement passe AVANT ses degats symboliques")
	var givre_dmg: SpellCard = _carte("t_givre_dmg", [_spec(&"ground_zone", 1.0, 5.0, 180.0,
		{&"slow_pct": 40.0})])
	not_ok(_axes_proposes(givre_dmg).has(&"damage"),
		"les degats symboliques d un sort qui ralentit ne sont ni un gain ni un prix")
	var mur: SpellCard = _carte("t_mur", [_spec(&"build_wall", 0.0, 0.0, 200.0,
		{&"permanent": true, &"wall_hp": 100.0})])
	ok(_axes_proposes(mur).has(&"hp"), "un mur solide propose ses PV")
	not_ok(_axes_proposes(mur).has(&"area"),
		"un mur ne s allonge pas : sa taille est verifiee par la garantie de chemin")
	var fleche: SpellCard = _carte("t_fleche", [_spec(&"pierce_line", 10.0, 0.0, 120.0,
		{&"max_targets": 5})])
	ok(_axes_proposes(fleche).has(&"count"), "une ligne percante propose +cibles")
	var faille: SpellCard = _carte("t_faille", [_spec(&"pierce_line", 10.0, 0.0, 120.0,
		{&"max_targets": GameConfig.UPGRADE_COUNT_UNLIMITED + 10})])
	not_ok(_axes_proposes(faille).has(&"count"),
		"une ligne qui perce deja tout ne promet pas '+1 cible'")
	var pacte: SpellCard = _carte("t_pacte", [_spec(&"haste_enemies_boon", 30.0, 5.0, 0.0,
		{&"draw": 3})])
	not_ok(_axes_proposes(pacte).has(&"duration"),
		"la duree d une acceleration des MONSTRES n est pas une amelioration")
	# LA RIVIERE n a rien de chiffre : sans complement, elle n aurait que la
	# vitesse legere, et l ecran la montrerait seule a chaque partie. Elle recoit
	# la pioche au lancement, et sa vitesse forte se paie d une carte.
	var riviere: SpellCard = _carte("t_riviere", [_spec(&"terrain_river")])
	var a_r: Dictionary = _axes_proposes(riviere)
	ok(a_r.has(&"draw"), "un sort sans rien de chiffre recoit la pioche au lancement")
	ok(a_r.has(&"discard"), "sa vitesse forte se paie d une carte defaussee")
	for v in RunState.upgrade_pool_for(riviere):
		if StringName(v.get("form", &"")) == &"strong":
			ok(StringName(v.get("price_axis", &"")) != &"",
				"riviere/%s : une voie forte a toujours un prix" % v["id"])
	# La pioche de complement n est JAMAIS donnee a un sort qui a deja de quoi
	# varier : "+1 carte" sur une Boule de feu serait un bonus hors de son identite.
	not_ok(_axes_proposes(_carte_zone("t_zone_pioche")).has(&"draw"),
		"un sort riche ne recoit pas la pioche de complement")
	ok(RunState.upgrade_path_by_id(_carte_zone("t_zone_id"), &"draw_light").is_empty(),
		"meme par son id, la pioche de complement est refusee a un sort riche")
	# Ni a un sort qui PIOCHE deja : ce serait sa voie NOMBRE sous un autre nom.
	var pioche: SpellCard = _carte("t_pioche", [_spec(&"draw_cards", 0.0, 0.0, 0.0,
		{&"count": 3})])
	not_ok(_axes_proposes(pioche).has(&"draw"),
		"un sort de pioche ne recoit pas '+1 carte piochee' en plus de '+1 carte'")


## LA DEMANDE DU CO-AUTEUR : "plus que 3 ameliorations differentes par sort".
## Un pool qui n excede pas l ecran rendrait toujours la meme proposition. Le
## seuil est ecrit EN DUR en plus du rapport a LEVEL_UP_CHOICES : si l ecran
## descendait a deux voies, la regle du co-auteur ne descendrait pas avec lui.
func _test_chaque_sort_a_plus_de_voies_que_l_ecran() -> void:
	RunState.reset()
	var vus: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		vus += 1
		var pool: Array = RunState.upgrade_pool_for(c)
		ok(pool.size() > GameConfig.LEVEL_UP_CHOICES,
			"%s : %d voies, pas plus que les %d de l ecran : la proposition ne varierait pas"
			% [c.id, pool.size(), GameConfig.LEVEL_UP_CHOICES])
		ok(pool.size() >= 4, "%s : au moins quatre voies differentes (%d)" % [c.id, pool.size()])
		var ids: Array[StringName] = _ids(pool)
		var uniques: Dictionary = {}
		for id in ids:
			uniques[id] = true
		eq(uniques.size(), ids.size(), "%s : les voies du pool sont distinctes" % c.id)
		# Chaque voie du pool se RECONSTRUIT a l identique depuis son id : c est
		# par l id que la voie retenue est relue a chaque lancement.
		for v in pool:
			var r: Dictionary = RunState.upgrade_path_by_id(c, StringName(v["id"]))
			eq(String(r.get("text", "?")), String(v.get("text", "")),
				"%s/%s : l id rend la meme voie" % [c.id, v["id"]])
	ok(vus > 0, "le catalogue contient des sorts a examiner")


## Le TIRAGE : trois voies distinctes du pool, au moins une legere et une forte,
## sur au moins deux axes. Verifie sur tout le catalogue, sur plusieurs graines.
func _test_le_tirage_melange_les_formes_et_les_axes() -> void:
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		var pool_ids: Array[StringName] = _ids(RunState.upgrade_pool_for(c))
		for graine in 4:
			RunState.reset()
			RunState.set_seed(4000 + graine)
			var voies: Array = RunState.draw_upgrade_offer(c)
			eq(voies.size(), mini(GameConfig.LEVEL_UP_CHOICES, pool_ids.size()),
				"%s : l ecran montre %d voies" % [c.id, GameConfig.LEVEL_UP_CHOICES])
			var ids: Dictionary = {}
			var formes: Dictionary = {}
			var axes: Dictionary = {}
			for v in voies:
				ids[StringName(v.get("id", &""))] = true
				formes[StringName(v.get("form", &""))] = true
				axes[StringName(v.get("axis", &""))] = true
				ok(pool_ids.has(StringName(v.get("id", &""))),
					"%s/%s : une voie tiree vient du pool" % [c.id, v.get("id", "?")])
			eq(ids.size(), voies.size(), "%s : les voies tirees sont distinctes" % c.id)
			ok(formes.has(&"light") and formes.has(&"strong"),
				"%s : le tirage melange formes legere et forte" % c.id)
			ok(axes.size() >= 2, "%s : le tirage porte sur au moins deux axes" % c.id)
	RunState.reset()


## Le tirage VARIE d une partie a l autre (c est tout l objet du pool) et se
## REJOUE a graine egale (c est ce qui garde le banc et les tests reproductibles).
func _test_le_tirage_varie_d_une_partie_a_l_autre_et_se_rejoue() -> void:
	var c: SpellCard = _carte_zone("t_tirage")
	var vus: Dictionary = {}
	for graine in 12:
		RunState.reset()
		RunState.set_seed(7000 + graine)
		var a: Array[StringName] = _ids(RunState.draw_upgrade_offer(c))
		RunState.reset()
		RunState.set_seed(7000 + graine)
		var b: Array[StringName] = _ids(RunState.draw_upgrade_offer(c))
		eq(str(a), str(b), "graine %d : la meme graine rejoue le meme tirage" % graine)
		var tri: Array = a.map(func(x: StringName) -> String: return String(x))
		tri.sort()
		vus[str(tri)] = true
	ok(vus.size() >= 3, "douze parties montrent au moins trois propositions differentes (%d)"
		% vus.size())
	# Et c est bien le RNG DE LA PARTIE qui tire : l offre qui s ouvre au palier
	# est celle que rend le tirage avec la meme graine.
	RunState.reset()
	RunState.set_seed(7100)
	var attendu: Array[StringName] = _ids(RunState.draw_upgrade_offer(c))
	RunState.reset()
	RunState.set_seed(7100)
	_lancer(c, GameConfig.CARD_UPGRADE_CASTS)
	eq(str(_ids(RunState.pending_upgrade_paths)), str(attendu),
		"l offre du palier est tiree par le RNG de la partie")
	RunState.reset()


## LEGERE = un seul axe, en hausse de UPGRADE_LIGHT_GAIN, rien a payer.
## FORTE  = un gain de UPGRADE_STRONG_GAIN et un prix de UPGRADE_STRONG_COST sur
##          un AUTRE axe. Le gain fort doit depasser le leger, sinon la forme
##          forte ne serait qu un malus.
func _test_legere_gratuite_forte_payee() -> void:
	ok(GameConfig.UPGRADE_STRONG_GAIN > GameConfig.UPGRADE_LIGHT_GAIN,
		"la forme forte gagne plus que la legere")
	ok(GameConfig.UPGRADE_STRONG_COST > 0.0, "la forme forte a un prix")
	ok(GameConfig.UPGRADE_DRAW_STRONG > GameConfig.UPGRADE_DRAW_LIGHT,
		"la pioche forte donne plus que la legere")
	ok(GameConfig.UPGRADE_DISCARD_PRICE > 0, "le prix en cartes n est pas nul")
	RunState.reset()
	var fabriquees: Array = [_carte("t_lf_riviere", [_spec(&"terrain_river")])]
	for c: SpellCard in ContentDB.cards.values() + fabriquees:
		if c == null or c.is_passive:
			continue
		for v in RunState.upgrade_pool_for(c):
			var mods: Dictionary = v.get("mods", {})
			var axe: StringName = StringName(v.get("axis", &""))
			var en_cartes: bool = axe == &"draw"
			if StringName(v.get("form", &"")) == &"light":
				eq(mods.size(), 1, "%s/%s : une voie legere ne touche qu un axe" % [c.id, v["id"]])
				feq(float(mods.get(axe, 0.0)), float(GameConfig.UPGRADE_DRAW_LIGHT) if en_cartes
					else GameConfig.UPGRADE_LIGHT_GAIN, "%s/%s : gain leger" % [c.id, v["id"]])
				eq(String(v.get("cost_text", "")), "",
					"%s/%s : une voie legere n annonce aucun prix" % [c.id, v["id"]])
			else:
				eq(mods.size(), 2, "%s/%s : une voie forte = un gain + un prix" % [c.id, v["id"]])
				feq(float(mods.get(axe, 0.0)), float(GameConfig.UPGRADE_DRAW_STRONG) if en_cartes
					else GameConfig.UPGRADE_STRONG_GAIN, "%s/%s : gain fort" % [c.id, v["id"]])
				var prix: StringName = StringName(v.get("price_axis", &""))
				ok(prix != &"" and prix != axe,
					"%s/%s : le prix porte sur un AUTRE axe" % [c.id, v["id"]])
				feq(float(mods.get(prix, 0.0)), -float(GameConfig.UPGRADE_DISCARD_PRICE)
					if prix == &"discard" else -GameConfig.UPGRADE_STRONG_COST,
					"%s/%s : prix fort" % [c.id, v["id"]])
				not_ok(prix == &"count",
					"%s/%s : un nombre entier ne sert jamais de prix" % [c.id, v["id"]])
				# Le prix en cartes n est que le DERNIER recours : un sort qui a un
				# autre axe a payer le paie la, pas en vidant la main du joueur.
				if prix == &"discard":
					var autres: Dictionary = _axes_proposes(c)
					for a in [&"damage", &"slow", &"tempo", &"force", &"amplify", &"hp",
							&"area", &"duration"]:
						not_ok(autres.has(a) and a != axe,
							"%s/%s : paie en cartes alors qu il a '%s' a payer" % [c.id, v["id"], a])


## Un CHOIX, pas un classement : aucune voie n est au moins aussi bonne qu une
## autre sur tous les axes a la fois.
func _test_aucune_voie_ne_domine_une_autre() -> void:
	RunState.reset()
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		var voies: Array = RunState.upgrade_pool_for(c)
		for i in voies.size():
			for j in voies.size():
				if i == j:
					continue
				var a: Dictionary = voies[i].get("mods", {})
				var b: Dictionary = voies[j].get("mods", {})
				not_ok(_domine(a, b), "%s : '%s' domine '%s'"
					% [c.id, voies[i].get("text", "?"), voies[j].get("text", "?")])


func _domine(a: Dictionary, b: Dictionary) -> bool:
	var tous: Dictionary = {}
	for k in a:
		tous[k] = true
	for k in b:
		tous[k] = true
	var strict: bool = false
	for k in tous:
		var va: float = float(a.get(k, 0.0))
		var vb: float = float(b.get(k, 0.0))
		if va < vb:
			return false
		if va > vb:
			strict = true
	return strict


## Chaque axe modifie EXACTEMENT ce qu il annonce, y compris dans les `params`
## des effets. Une carte fabriquee par axe, la voie legere puis la forte.
func _test_application_exacte_de_chaque_axe() -> void:
	var leger: float = 1.0 + GameConfig.UPGRADE_LIGHT_GAIN
	var fort: float = 1.0 + GameConfig.UPGRADE_STRONG_GAIN
	# DEGATS (magnitude)
	var c: SpellCard = _carte_degats("t_ax_dmg", 20.0)
	if ok_prise(c, &"damage_light"):
		feq(RunState.cast_specs(c)[0].magnitude, 20.0 * leger, "degats legers exacts")
	if ok_prise(c, &"damage_strong"):
		feq(RunState.cast_specs(c)[0].magnitude, 20.0 * fort, "degats forts exacts")
	# DEGATS d un allie invoque par un autel (param ally_damage)
	var autel: SpellCard = _carte("t_ax_autel", [_spec(&"place_terrain", 0.0, 0.0, 0.0,
		{&"kind": "altar", &"prop_hp": 140.0, &"ally_damage": 8.0, &"summon_every": 6.0})])
	if ok_prise(autel, &"damage_strong"):
		feq(float(RunState.cast_specs(autel)[0].params[&"ally_damage"]), 8.0 * fort,
			"les degats d allie de l autel (params) suivent la voie")
	# RALENTISSEMENT (param slow_pct)
	var givre: SpellCard = _carte("t_ax_slow", [_spec(&"ground_zone", 0.0, 5.0, 180.0,
		{&"slow_pct": 40.0})])
	if ok_prise(givre, &"slow_strong"):
		feq(float(RunState.cast_specs(givre)[0].params[&"slow_pct"]), 40.0 * fort,
			"ralentissement fort exact (params)")
	# ACCELERATION (self_haste)
	var hate: SpellCard = _carte("t_ax_tempo", [_spec(&"self_haste", 60.0, 6.0)])
	if ok_prise(hate, &"tempo_strong"):
		feq(RunState.cast_specs(hate)[0].magnitude, 60.0 * fort, "hate forte exacte")
	# FORCE (param push)
	var souffle: SpellCard = _carte("t_ax_force", [_spec(&"knockback", 0.0, 0.0, 190.0,
		{&"push": 200.0})])
	if ok_prise(souffle, &"force_strong"):
		feq(float(RunState.cast_specs(souffle)[0].params[&"push"]), 200.0 * fort,
			"recul fort exact (params)")
	# AMPLIFICATION : l EXCEDENT au-dessus de 1
	var marque: SpellCard = _carte("t_ax_amp", [_spec(&"ground_zone", 0.0, 6.0, 200.0,
		{&"vuln_mult": 2.0})])
	if ok_prise(marque, &"amplify_strong"):
		feq(float(RunState.cast_specs(marque)[0].params[&"vuln_mult"]), 1.0 + 1.0 * fort,
			"vulnerabilite : seul l excedent au-dessus de x1 est amplifie")
	# PV (param wall_hp)
	var mur: SpellCard = _carte("t_ax_hp", [_spec(&"build_wall", 0.0, 0.0, 200.0,
		{&"permanent": true, &"wall_hp": 100.0})])
	if ok_prise(mur, &"hp_strong"):
		feq(float(RunState.cast_specs(mur)[0].params[&"wall_hp"]), 100.0 * fort,
			"PV du mur forts exacts (params)")
	# ZONE et DUREE
	var z: SpellCard = _carte_zone("t_ax_zone")
	var base: EffectSpec = z.effects[0]
	if ok_prise(z, &"area_light"):
		feq(RunState.cast_specs(z)[0].radius, base.radius * leger, "zone legere exacte")
		feq(RunState.cast_specs(z)[0].duration, base.duration,
			"la voie ZONE ne touche plus a la duree")
	var dz: SpellCard = _carte("t_ax_dur", [_spec(&"slow_enemy_gauge", 30.0, 5.0)])
	if ok_prise(dz, &"duration_light"):
		feq(RunState.cast_specs(dz)[0].duration, 5.0 * leger, "duree legere exacte")
	# PRIX : une voie forte de zone sur un sort qui fait des degats se paie en degats
	if ok_prise(z, &"area_strong"):
		feq(RunState.cast_specs(z)[0].radius, base.radius * fort, "zone forte exacte")
		feq(RunState.cast_specs(z)[0].magnitude,
			base.magnitude * (1.0 - GameConfig.UPGRADE_STRONG_COST),
			"elargir DILUE : la zone forte se paie en degats")
	# PRIX ALTERNATIF : l identite du sort peut se payer ailleurs qu en vitesse.
	var t_z: float = RunState.effective_cast_time(z)
	if ok_prise(z, &"damage_strong_area"):
		feq(RunState.cast_specs(z)[0].magnitude, base.magnitude * fort,
			"degats forts payes en zone : le gain est le meme")
		feq(RunState.cast_specs(z)[0].radius, base.radius * (1.0 - GameConfig.UPGRADE_STRONG_COST),
			"degats forts payes en zone : c est la zone qui paie")
		feq(RunState.effective_cast_time(z), t_z,
			"degats forts payes en zone : la vitesse n est pas touchee", 0.001)
	# PIOCHE de complement : un effet draw_cards AJOUTE, la carte source intacte.
	var riv: SpellCard = _carte("t_ax_riviere", [_spec(&"terrain_river")])
	if ok_prise(riv, &"draw_strong"):
		var sp: Array[EffectSpec] = RunState.cast_specs(riv)
		eq(sp.size(), riv.effects.size() + 1, "la pioche ajoute UN effet au sort")
		if sp.size() == riv.effects.size() + 1:
			eq(sp[-1].key, &"draw_cards", "l effet ajoute est la pioche existante")
			eq(int(sp[-1].params.get(&"count", 0)), GameConfig.UPGRADE_DRAW_STRONG,
				"la pioche forte pioche ce qu elle annonce")
		eq(riv.effects.size(), 1, "la carte source n a pas gagne d effet")


## IMPOSE la voie `id` a la carte, qu un tirage la propose ou non. Un tirage
## n offre que trois voies du pool ; l application de chaque axe doit pourtant
## etre exacte, et c est elle qu on verifie ici. La voie doit tout de meme AVOIR
## UN SENS pour la carte (upgrade_path_by_id non vide).
func ok_prise(card: SpellCard, id: StringName) -> bool:
	var sens: bool = _prendre(card, id)
	ok(sens, "%s : la voie '%s' a un sens pour cette carte" % [card.id, id])
	return sens


## La voie parle en VITESSE : "+x % de vitesse" divise le temps par (1 + x). Un
## prix de "-y % de vitesse" le divise par (1 - y). C est ce qui garantit que le
## libelle dit exactement ce que fait le sort.
func _test_la_vitesse_de_lancement_est_l_inverse_du_temps() -> void:
	RunState.reset()
	var c: SpellCard = _carte_degats("t_vit", 20.0)
	var avant: float = RunState.effective_cast_time(c)
	if ok_prise(c, &"cast_strong"):
		feq(RunState.effective_cast_time(c), avant / (1.0 + GameConfig.UPGRADE_STRONG_GAIN),
			"vitesse forte : temps divise par (1 + gain)", 0.001)
		feq(RunState.cast_specs(c)[0].magnitude, 20.0 * (1.0 - GameConfig.UPGRADE_STRONG_COST),
			"la vitesse forte se paie sur l identite du sort (ses degats)")
	if ok_prise(c, &"damage_strong"):
		feq(RunState.effective_cast_time(c), avant / (1.0 - GameConfig.UPGRADE_STRONG_COST),
			"degats forts : le prix en vitesse allonge le temps de 1/(1 - prix)", 0.001)
	if ok_prise(c, &"damage_light"):
		feq(RunState.effective_cast_time(c), avant,
			"une voie legere de degats ne touche pas au temps", 0.001)


## Un nombre de cibles, d impacts ou de cartes est ENTIER : la legere ajoute au
## moins un, la forte au moins un de plus que la legere.
func _test_le_nombre_est_entier_et_la_forte_depasse_la_legere() -> void:
	for n in [2, 3, 5, 14]:
		var c: SpellCard = _carte("t_nb_%d" % n, [_spec(&"pierce_line", 10.0, 0.0, 0.0,
			{&"max_targets": n})])
		var n_leger: int = -1
		var n_fort: int = -1
		if ok_prise(c, &"count_light"):
			n_leger = int(RunState.cast_specs(c)[0].params[&"max_targets"])
		if ok_prise(c, &"count_strong"):
			n_fort = int(RunState.cast_specs(c)[0].params[&"max_targets"])
		ok(n_leger >= n + 1, "%d cibles : la legere en ajoute au moins une (%d)" % [n, n_leger])
		ok(n_fort > n_leger, "%d cibles : la forte depasse la legere (%d > %d)"
			% [n, n_fort, n_leger])
		eq(int(c.effects[0].params[&"max_targets"]), n, "la carte source garde %d cibles" % n)
	# Le libelle annonce le VRAI nombre ajoute.
	var p: SpellCard = _carte("t_nb_txt", [_spec(&"meteor_storm", 30.0, 6.0, 110.0,
		{&"impacts": 14})])
	for v in RunState.upgrade_pool_for(p):
		if StringName(v.get("axis", &"")) == &"count":
			var d: int = RunState.upgrade_count_bonus(14, float(v["mods"][&"count"]))
			ok(String(v.get("gain_text", "")).begins_with("+%d " % d),
				"le libelle du nombre annonce +%d (%s)" % [d, v.get("gain_text", "")])
	# Le retour en main (retain_next) compte en magnitude.
	var r: SpellCard = _carte("t_nb_ret", [_spec(&"retain_next", 2.0)])
	if ok_prise(r, &"count_light"):
		ok(RunState.cast_specs(r)[0].magnitude > 2.0, "retenir : une carte de plus retenue")


## Aucune voie ne pousse un ralentissement au-dela du plafond, et un sort deja
## trop pres du plafond ne se voit pas proposer une promesse intenable.
func _test_le_ralentissement_ne_depasse_jamais_le_plafond() -> void:
	var cap: float = GameConfig.UPGRADE_SLOW_CAP
	var presque: float = cap / (1.0 + GameConfig.UPGRADE_LIGHT_GAIN) + 1.0
	var gel: SpellCard = _carte("t_cap", [_spec(&"ground_zone", 0.0, 4.0, 170.0,
		{&"slow_pct": presque})])
	RunState.reset()
	not_ok(_voie_de_gain(gel, &"slow"),
		"un gel a %.0f %% ne se voit pas promettre plus de ralentissement" % presque)
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		for v in RunState.upgrade_pool_for(c):
			_prendre(c, StringName(v["id"]))
			for s in RunState.cast_specs(c):
				ok(float(s.params.get(&"slow_pct", 0.0)) <= cap + 0.001,
					"%s/%s : ralentissement de zone sous le plafond" % [c.id, v["id"]])
				if s.key == &"slow_enemy_gauge":
					ok(s.magnitude <= cap + 0.001,
						"%s/%s : ralentissement global sous le plafond" % [c.id, v["id"]])
	# LE CUMUL : chaque voie tient seule sous le plafond, mais la legere puis la
	# forte ensemble le depasseraient. La seconde maturation ne doit alors plus
	# proposer l autre forme, sinon elle promet un gain qu elle ne donne pas.
	var marge: float = cap / (1.0 + GameConfig.UPGRADE_STRONG_GAIN
		+ GameConfig.UPGRADE_LIGHT_GAIN * 0.5)
	var bord: SpellCard = _carte("t_cap_cumul", [_spec(&"ground_zone", 0.0, 4.0, 170.0,
		{&"slow_pct": marge})])
	ok(_voie_de_gain(bord, &"slow"), "un gel a %.0f %% peut encore gagner du ralentissement" % marge)
	_prendre(bord, &"slow_strong")
	var encore: Array[StringName] = _ids(RunState.upgrade_offerable_for(bord))
	not_ok(encore.has(&"slow_light"),
		"apres la forte, la legere ferait passer le plafond : elle n est plus proposee")
	not_ok(encore.has(&"slow_strong"), "une voie deja prise n est plus proposee")
	RunState.reset()


func _voie_de_gain(card: SpellCard, axis: StringName) -> bool:
	for v in RunState.upgrade_pool_for(card):
		if StringName(v.get("axis", &"")) == axis:
			return true
	return false


## TOUTE voie du catalogue change reellement le sort : ce qu elle promet mord
## dans cast_specs ou dans le temps d incantation. Sans cela, une voie pourrait
## s afficher et ne rien faire — l ecran deviendrait decoratif.
func _test_toute_voie_du_catalogue_change_reellement_le_sort() -> void:
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		for v in RunState.upgrade_pool_for(c):
			RunState.reset()
			var t_avant: float = RunState.effective_cast_time(c)
			_prendre(c, StringName(v["id"]))
			var change: bool = not is_equal_approx(RunState.effective_cast_time(c), t_avant)
			var apres: Array[EffectSpec] = RunState.cast_specs(c)
			var mord: bool = apres.size() != c.effects.size()
			for i in mini(apres.size(), c.effects.size()):
				if _differe(c.effects[i], apres[i]):
					mord = true
			ok(change or mord, "%s/%s : la voie change reellement le sort" % [c.id, v["id"]])
			if StringName(v.get("axis", &"")) != &"cast":
				ok(mord, "%s/%s : le GAIN mord sur les effets du sort" % [c.id, v["id"]])
	RunState.reset()


func _differe(a: EffectSpec, b: EffectSpec) -> bool:
	if not is_equal_approx(a.magnitude, b.magnitude) \
			or not is_equal_approx(a.radius, b.radius) \
			or not is_equal_approx(a.duration, b.duration):
		return true
	for k in a.params:
		if str(a.params[k]) != str(b.params.get(k)):
			return true
	return false


## Ameliorer un sort ne doit pas ameliorer les autres.
func _test_les_voies_ne_touchent_que_la_carte_amelioree() -> void:
	RunState.reset()
	var a: SpellCard = _carte_degats("t_a")
	var b: SpellCard = _carte_degats("t_b")
	var b_avant: float = RunState.cast_specs(b)[0].magnitude
	var b_cast_avant: float = RunState.effective_cast_time(b)
	_lancer(a, GameConfig.CARD_UPGRADE_CASTS)
	RunState.pick_upgrade(maxi(0, _indice_de_voie(a, &"damage_strong")))
	feq(RunState.cast_specs(b)[0].magnitude, b_avant, "la carte voisine garde ses degats")
	feq(RunState.effective_cast_time(b), b_cast_avant,
		"la carte voisine garde son temps d incantation", 0.001)


## Une maturation par PALIER : rien entre deux paliers, une nouvelle offre au
## palier suivant tant qu il en reste, plus rien apres la derniere. Une voie deja
## prise n est plus proposee.
func _test_une_carte_ne_s_ameliore_qu_une_fois_par_palier() -> void:
	RunState.reset()
	RunState.set_seed(4242)
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var paliers: int = GameConfig.CARD_UPGRADE_TIERS
	ok(paliers >= 1, "au moins une maturation par sort")
	var c: SpellCard = _carte_zone("t_paliers")
	eq(RunState.upgrade_gap(0), seuil, "la premiere maturation vient au palier du reglage")
	# L ecart GRANDIT d une maturation a l autre : a ecart constant, les niveaux
	# longs ouvraient un ecran modal toutes les quinze secondes.
	for p in range(1, paliers):
		ok(RunState.upgrade_gap(p) > RunState.upgrade_gap(p - 1),
			"l ecart avant la maturation %d est plus long que le precedent" % (p + 1))
	var prises: Array[StringName] = []
	for p in paliers:
		_lancer(c, RunState.upgrade_gap(p) - 1)
		ok(RunState.pending_upgrade_card == null,
			"maturation %d : rien avant le palier (%d lancers)" % [p + 1, RunState.casts_of(c)])
		_lancer(c, 1)
		ok(RunState.pending_upgrade_card == c,
			"maturation %d : l offre s ouvre a %d lancers" % [p + 1, RunState.casts_of(c)])
		for id in _ids(RunState.pending_upgrade_paths):
			not_ok(prises.has(id), "maturation %d : '%s' deja prise est reproposee" % [p + 1, id])
		var v: Dictionary = RunState.pick_upgrade(0)
		ok(RunState.pending_upgrade_card == null, "l offre est consommee par le choix")
		prises.append(StringName(v.get("id", &"")))
	eq(RunState.upgrade_ids_of(c).size(), paliers, "une voie retenue par maturation")
	_lancer(c, RunState.upgrade_threshold(paliers) + seuil)
	ok(RunState.pending_upgrade_card == null,
		"apres la derniere maturation, le sort ne redemande plus rien")
	eq(RunState.upgrade_progress(c), 1.0, "le lisere est plein quand tout est muri")
	RunState.reset()


## Les voies de deux maturations S ADDITIONNENT, sur les pourcentages comme sur
## les nombres : "+30 % degats" puis "+10 % degats" font "+40 %", et le prix de
## la premiere reste du.
func _test_les_maturations_se_cumulent() -> void:
	var c: SpellCard = _carte_degats("t_cumul", 20.0)
	RunState.reset()
	var t0: float = RunState.effective_cast_time(c)
	RunState.upgrades_taken[c.id] = [&"damage_strong", &"damage_light"]
	feq(RunState.cast_specs(c)[0].magnitude,
		20.0 * (1.0 + GameConfig.UPGRADE_STRONG_GAIN + GameConfig.UPGRADE_LIGHT_GAIN),
		"les pourcentages de deux voies s additionnent")
	feq(RunState.effective_cast_time(c), t0 / (1.0 - GameConfig.UPGRADE_STRONG_COST),
		"le prix de la premiere voie reste du", 0.001)
	# Un gain et un prix sur le MEME axe se compensent au lieu de se multiplier.
	RunState.upgrades_taken[c.id] = [&"damage_strong", &"cast_strong"]
	feq(RunState.cast_specs(c)[0].magnitude,
		20.0 * (1.0 + GameConfig.UPGRADE_STRONG_GAIN - GameConfig.UPGRADE_STRONG_COST),
		"degats : +gain puis -prix")
	feq(RunState.effective_cast_time(c),
		t0 / (1.0 + GameConfig.UPGRADE_STRONG_GAIN - GameConfig.UPGRADE_STRONG_COST),
		"vitesse : -prix puis +gain", 0.001)
	# Le NOMBRE : chaque voie ajoute ce qu elle annoncait.
	var n: int = 5
	var f: SpellCard = _carte("t_cumul_nb", [_spec(&"pierce_line", 10.0, 0.0, 120.0,
		{&"max_targets": n})])
	RunState.upgrades_taken[f.id] = [&"count_light", &"count_strong"]
	eq(int(RunState.cast_specs(f)[0].params[&"max_targets"]),
		n + RunState.upgrade_count_bonus(n, GameConfig.UPGRADE_LIGHT_GAIN)
		+ RunState.upgrade_count_bonus(n, GameConfig.UPGRADE_STRONG_GAIN),
		"deux voies de nombre ajoutent la somme de leurs deux libelles")
	eq(int(f.effects[0].params[&"max_targets"]), n, "la carte source garde son nombre")
	# La carte GARDE la trace des deux : le grimoire les marque toutes les deux.
	var acquises: int = 0
	for l in RunState.upgrade_lines_for(f):
		if bool(l.get("unlocked", false)):
			acquises += 1
	eq(acquises, 2, "le grimoire marque les deux voies acquises")
	RunState.reset()


## Renoncer ferme CE palier (l ecran ne se rouvre pas au lancer suivant) mais
## pas les suivants : refuser un compromis n est pas renoncer au sort.
func _test_renoncer_consomme_le_palier_seulement() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_zone("t_refus")
	_lancer(c, seuil)
	RunState.decline_upgrade()
	ok(RunState.pending_upgrade_card == null, "renoncer ferme l offre")
	_lancer(c, 1)
	ok(RunState.pending_upgrade_card == null, "renoncer ne rouvre pas l ecran au lancer suivant")
	eq(RunState.upgrade_ids_of(c).size(), 0, "renoncer ne retient aucune voie")
	if GameConfig.CARD_UPGRADE_TIERS > 1:
		_lancer(c, RunState.upgrade_threshold(1) - RunState.casts_of(c))
		ok(RunState.pending_upgrade_card == c, "le palier suivant s ouvre malgre le refus")
	RunState.reset()


## Le LISERE de la carte en main suit la PROCHAINE maturation : il repart de zero
## apres un choix au lieu de rester plein, sinon le joueur croirait le sort fini.
func _test_le_lisere_suit_la_prochaine_maturation() -> void:
	RunState.reset()
	var seuil: int = GameConfig.CARD_UPGRADE_CASTS
	var c: SpellCard = _carte_zone("t_lisere")
	_lancer(c, seuil / 2)
	feq(RunState.upgrade_progress(c), float(seuil / 2) / float(seuil), "a mi-chemin du palier")
	_lancer(c, seuil - seuil / 2)
	RunState.pick_upgrade(0)
	ok(RunState.upgrade_of(c) != &"", "le sort est marque comme muri (lisere dore)")
	if GameConfig.CARD_UPGRADE_TIERS > 1:
		feq(RunState.upgrade_progress(c), 0.0, "le lisere repart de zero vers la maturation suivante")
		_lancer(c, 1)
		feq(RunState.upgrade_progress(c), 1.0 / float(RunState.upgrade_gap(1)),
			"et remonte lancer apres lancer, sur l ecart de la maturation suivante")
	else:
		feq(RunState.upgrade_progress(c), 1.0, "une seule maturation : lisere plein")
	RunState.reset()


## Les axes en CARTES font ce qu ils annoncent, EN JEU : la pioche de complement
## remplit la main, le prix "carte defaussee" la vide d autant, une fois par
## lancer reel — et jamais quand l apercu de visee relit les effets.
func _test_les_axes_en_cartes_piochent_et_defaussent() -> void:
	var riv: SpellCard = _carte("t_cartes_riviere", [_spec(&"terrain_river")])
	var remplissage: SpellCard = _carte_degats("t_cartes_main")
	_prendre(riv, &"cast_strong")
	for i in 4:
		RunState.hand.append(remplissage)
	var main: int = RunState.hand.size()
	RunState.cast_specs(riv)
	RunState.cast_specs(riv)
	eq(RunState.hand.size(), main, "relire les effets (apercu de visee) ne defausse rien")
	RunState.note_cast(riv)
	eq(RunState.hand.size(), main - GameConfig.UPGRADE_DISCARD_PRICE,
		"un lancer reel paie le prix en cartes annonce")
	# La pioche passe par le handler existant : on la joue comme un vrai sort.
	_prendre(riv, &"draw_light")
	RunState.deck.clear()
	for i in 6:
		RunState.deck.append(remplissage)
	var avant: int = RunState.hand.size()
	for s in RunState.cast_specs(riv):
		if s.key == &"draw_cards":
			EffectRegistry.dispatch(s, CastContext.new())
	eq(RunState.hand.size(), avant + GameConfig.UPGRADE_DRAW_LIGHT,
		"la pioche legere pioche ce qu elle annonce")
	RunState.reset()


## LE test qui protege le reste du jeu. Les EffectSpec sont des Resources
## PARTAGEES. Depuis que les voies ecrivent dans les `params`, le piege est
## double : si la copie partageait le Dictionary de la carte, "+1 cible" ecrit
## dans la copie s ecrirait dans le catalogue. (Godot 4.4 copie deja le
## Dictionary au duplicate() ; ce test garde la regle si le moteur change.)
func _test_l_amelioration_ne_modifie_jamais_la_ressource_partagee() -> void:
	var c: SpellCard = _carte("t_part", [_spec(&"pierce_line", 10.0, 0.0, 120.0,
		{&"max_targets": 5})])
	var source: EffectSpec = c.effects[0]
	var params_source: Dictionary = source.params
	ok_prise(c, &"area_strong")
	var sortie: Array[EffectSpec] = RunState.cast_specs(c)
	ok(sortie[0] != source, "cast_specs rend une COPIE, jamais le spec du .tres")
	feq(source.radius, 120.0, "le spec d origine garde son rayon")
	feq(source.magnitude, 10.0, "le spec d origine garde sa magnitude")
	ok_prise(c, &"count_strong")
	sortie = RunState.cast_specs(c)
	not_ok(is_same(sortie[0].params, params_source), "la copie a ses PROPRES params")
	eq(int(params_source[&"max_targets"]), 5, "le Dictionary params d origine n a pas bouge")
	eq(int(source.params[&"max_targets"]), 5, "la carte source garde ses cibles")
	RunState.reset()


## L amelioration vaut pour LA PARTIE EN COURS.
func _test_une_amelioration_ne_survit_pas_a_la_partie() -> void:
	var c: SpellCard = _carte_degats()
	var avant: float = RunState.cast_specs(c)[0].magnitude
	_prendre(c, &"damage_strong")
	ok(RunState.cast_specs(c)[0].magnitude > avant, "l amelioration est bien active")
	RunState.reset()
	eq(RunState.casts_of(c), 0, "reset efface les compteurs de lancers")
	ok(RunState.upgrades_taken.is_empty(), "reset efface les ameliorations prises")
	feq(RunState.cast_specs(c)[0].magnitude, avant,
		"apres reset, le sort est revenu a ses valeurs de base")


## CONTRAT DU GRIMOIRE. GalleryPanel.upgrades_of() lit `card.upgrades` et attend
## une liste de {text: String, unlocked: bool}. Le texte porte le gain ET le prix
## signes, pour que la fiche dise la meme chose que l ecran de choix.
func _test_le_contrat_du_grimoire_est_respecte() -> void:
	RunState.reset()
	var c: SpellCard = _carte_zone()
	var lignes: Array = GalleryPanel.upgrades_of(c)
	eq(lignes.size(), RunState.upgrade_pool_for(c).size(),
		"le grimoire voit TOUT le pool des le depart, pas un tirage")
	ok(lignes.size() > GameConfig.LEVEL_UP_CHOICES,
		"le grimoire montre plus de voies que l ecran de maturation")
	for l in lignes:
		ok(l is Dictionary, "chaque entree est un Dictionary")
		ok(l.has("text") and l.get("text") is String, "chaque entree porte un `text` String")
		ok(l.has("unlocked"), "chaque entree porte un `unlocked`")
		not_ok(bool(l.get("unlocked", true)), "avant tout choix, aucune voie n est acquise")
		ok(String(l.get("text", "")).contains("+"), "la ligne du grimoire porte le gain signe")
	_lancer(c, GameConfig.CARD_UPGRADE_CASTS)
	var i: int = maxi(0, _indice_de_voie(c, &"area_light"))
	var voulue: String = String(RunState.pending_upgrade_paths[i].get("text", ""))
	RunState.pick_upgrade(i)
	var acquises: int = 0
	for l in GalleryPanel.upgrades_of(c):
		if bool(l.get("unlocked", false)):
			acquises += 1
			eq(String(l.get("text", "")), voulue, "la voie acquise est celle choisie")
	eq(acquises, 1, "une seule voie est acquise apres un choix")
	RunState.reset()


## L ECRAN affiche le gain en VERT avec un "+", le prix en ROUGE avec un "-", et
## une voie legere dit qu elle ne coute rien. Le signe est exige EN PLUS de la
## couleur : la couleur seule ne se lit pas pour tout le monde.
func _test_l_ecran_affiche_gain_et_prix_signes() -> void:
	RunState.reset()
	RunState.set_seed(5150)
	var c: SpellCard = _carte_zone("t_ecran")
	var voies: Array = RunState.draw_upgrade_offer(c)
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var panneau := CardUpgradePanel.new()
	hote.add_child(panneau)
	panneau.show_paths(c, voies)
	var fortes: int = 0
	var legeres: int = 0
	for i in voies.size():
		var b: Node = panneau.find_child("Voie%d" % i, true, false)
		ok(b != null, "la voie %d a son bouton" % i)
		if b == null:
			continue
		var gain: Label = b.find_child("Gain", true, false) as Label
		var prix: Label = b.find_child("Prix", true, false) as Label
		var forme: Label = b.find_child("Forme", true, false) as Label
		ok(gain != null and prix != null and forme != null, "voie %d : gain, prix et forme" % i)
		if gain == null or prix == null or forme == null:
			continue
		ok(gain.text.begins_with("+"), "voie %d : le gain porte son signe + (%s)" % [i, gain.text])
		var cg: Color = gain.get_theme_color(&"font_color")
		ok(cg.g > cg.r and cg.g > cg.b, "voie %d : le gain est VERT" % i)
		if StringName(voies[i].get("form", &"")) == &"strong":
			fortes += 1
			ok(prix.text.begins_with("-"), "voie %d : le prix porte son signe - (%s)" % [i, prix.text])
			var cp: Color = prix.get_theme_color(&"font_color")
			ok(cp.r > cp.g and cp.r > cp.b, "voie %d : le prix est ROUGE" % i)
			eq(forme.text, "FORTE", "voie %d : la forme est ecrite" % i)
		else:
			legeres += 1
			ok(prix.text.contains("sans contrepartie"),
				"voie %d : une voie legere dit qu elle ne coute rien" % i)
			eq(forme.text, "LEGERE", "voie %d : la forme est ecrite" % i)
	ok(fortes > 0 and legeres > 0, "l ecran montre les deux formes sur une carte de zone")
	eq(panneau.find_child("Acquis", true, false), null,
		"premiere maturation : rien a declarer comme deja acquis")
	# SECONDE maturation : l ecran rappelle ce que le sort a deja, pour que le
	# joueur juge ce qu il AJOUTE.
	if GameConfig.CARD_UPGRADE_TIERS > 1:
		RunState.upgrades_taken[c.id] = [&"area_light"]
		panneau.show_paths(c, RunState.draw_upgrade_offer(c))
		var acquis: Label = panneau.find_child("Acquis", true, false) as Label
		ok(acquis != null, "seconde maturation : l ecran montre ce qui est deja acquis")
		if acquis != null:
			ok(acquis.text.contains(String(RunState.upgrade_path_by_id(c, &"area_light")
				.get("gain_text", "?"))), "la ligne 'deja acquis' cite la voie prise (%s)"
				% acquis.text)
	detach(hote)
	RunState.reset()


## L ECRAN DE CHOIX, verrouille sur ce qui a reellement casse : set_anchors_preset()
## sans offsets laissait le panneau a (0,0). Rien ne plante, seule la taille le
## trahit.
func _test_l_ecran_de_choix_occupe_reellement_l_ecran() -> void:
	RunState.reset()
	var c: SpellCard = _carte_zone()
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var panneau := CardUpgradePanel.new()
	hote.add_child(panneau)
	panneau.show_paths(c, RunState.draw_upgrade_offer(c))
	ok(panneau.size.x >= hote.size.x * 0.99 and panneau.size.y >= hote.size.y * 0.99,
		"le panneau couvre son hote (%s pour %s)" % [panneau.size, hote.size])
	detach(hote)
