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
	_test_le_trio_melange_les_formes_et_les_axes()
	_test_legere_gratuite_forte_payee()
	_test_aucune_voie_ne_domine_une_autre()
	_test_application_exacte_de_chaque_axe()
	_test_la_vitesse_de_lancement_est_l_inverse_du_temps()
	_test_le_nombre_est_entier_et_la_forte_depasse_la_legere()
	_test_le_ralentissement_ne_depasse_jamais_le_plafond()
	_test_toute_voie_du_catalogue_change_reellement_le_sort()
	_test_les_voies_ne_touchent_que_la_carte_amelioree()
	_test_une_carte_ne_s_ameliore_qu_une_fois_par_palier()
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


## Amene la carte au palier et retient la voie `id`. Faux si la voie n est pas
## proposee (le test appelant le signale).
func _prendre(card: SpellCard, id: StringName) -> bool:
	RunState.reset()
	_lancer(card, GameConfig.CARD_UPGRADE_CASTS)
	var i: int = _indice_de_voie(card, id)
	if i < 0:
		RunState.decline_upgrade()
		return false
	RunState.pick_upgrade(i)
	return true


func _indice_de_voie(card: SpellCard, id: StringName) -> int:
	var voies: Array = RunState.upgrade_paths_for(card)
	for i in voies.size():
		if StringName(voies[i].get("id", &"")) == id:
			return i
	return -1


func _axes_proposes(card: SpellCard) -> Dictionary:
	var out: Dictionary = {}
	for v in RunState.upgrade_paths_for(card):
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
				&"meteor_storm", &"stun_zone", &"place_terrain", &"taunt_prop"]:
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
	ok(StringName(RunState.upgrade_paths_for(givre)[0].get("axis", &"")) == &"slow",
		"sur un sort qui ralentit, le ralentissement passe AVANT ses degats symboliques")
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
	var riviere: SpellCard = _carte("t_riviere", [_spec(&"terrain_river")])
	var v_r: Array = RunState.upgrade_paths_for(riviere)
	eq(v_r.size(), 1, "un sort sans rien de chiffre ne propose que la vitesse")
	if not v_r.is_empty():
		eq(StringName(v_r[0].get("form", &"")), &"light",
			"et seulement LEGERE : une voie forte sans rien a payer serait un bonus deguise")


## Trois voies, sur des axes differents quand le sort en a, qui MELANGENT les
## deux formes. Verifie sur tout le catalogue.
func _test_le_trio_melange_les_formes_et_les_axes() -> void:
	RunState.reset()
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		var voies: Array = RunState.upgrade_paths_for(c)
		ok(voies.size() >= 1 and voies.size() <= GameConfig.LEVEL_UP_CHOICES,
			"%s : entre une et %d voies (%d)" % [c.id, GameConfig.LEVEL_UP_CHOICES, voies.size()])
		var ids: Dictionary = {}
		var formes: Dictionary = {}
		var axes: Dictionary = {}
		for v in voies:
			ids[StringName(v.get("id", &""))] = true
			formes[StringName(v.get("form", &""))] = true
			axes[StringName(v.get("axis", &""))] = true
		eq(ids.size(), voies.size(), "%s : les voies sont distinctes" % c.id)
		if voies.size() < GameConfig.LEVEL_UP_CHOICES:
			continue
		ok(formes.has(&"light") and formes.has(&"strong"),
			"%s : les voies melangent formes legere et forte" % c.id)
		ok(axes.size() >= 2, "%s : les voies portent sur au moins deux axes" % c.id)


## LEGERE = un seul axe, en hausse de UPGRADE_LIGHT_GAIN, rien a payer.
## FORTE  = un gain de UPGRADE_STRONG_GAIN et un prix de UPGRADE_STRONG_COST sur
##          un AUTRE axe. Le gain fort doit depasser le leger, sinon la forme
##          forte ne serait qu un malus.
func _test_legere_gratuite_forte_payee() -> void:
	ok(GameConfig.UPGRADE_STRONG_GAIN > GameConfig.UPGRADE_LIGHT_GAIN,
		"la forme forte gagne plus que la legere")
	ok(GameConfig.UPGRADE_STRONG_COST > 0.0, "la forme forte a un prix")
	RunState.reset()
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		for v in RunState.upgrade_paths_for(c):
			var mods: Dictionary = v.get("mods", {})
			var axe: StringName = StringName(v.get("axis", &""))
			if StringName(v.get("form", &"")) == &"light":
				eq(mods.size(), 1, "%s/%s : une voie legere ne touche qu un axe" % [c.id, v["id"]])
				feq(float(mods.get(axe, 0.0)), GameConfig.UPGRADE_LIGHT_GAIN,
					"%s/%s : gain leger" % [c.id, v["id"]])
				eq(String(v.get("cost_text", "")), "",
					"%s/%s : une voie legere n annonce aucun prix" % [c.id, v["id"]])
			else:
				eq(mods.size(), 2, "%s/%s : une voie forte = un gain + un prix" % [c.id, v["id"]])
				feq(float(mods.get(axe, 0.0)), GameConfig.UPGRADE_STRONG_GAIN,
					"%s/%s : gain fort" % [c.id, v["id"]])
				var prix: StringName = StringName(v.get("price_axis", &""))
				ok(prix != &"" and prix != axe,
					"%s/%s : le prix porte sur un AUTRE axe" % [c.id, v["id"]])
				feq(float(mods.get(prix, 0.0)), -GameConfig.UPGRADE_STRONG_COST,
					"%s/%s : prix fort" % [c.id, v["id"]])
				not_ok(prix == &"count",
					"%s/%s : un nombre entier ne sert jamais de prix" % [c.id, v["id"]])


## Un CHOIX, pas un classement : aucune voie n est au moins aussi bonne qu une
## autre sur tous les axes a la fois.
func _test_aucune_voie_ne_domine_une_autre() -> void:
	RunState.reset()
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		var voies: Array = RunState.upgrade_paths_for(c)
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


## IMPOSE la voie `id` a la carte, qu elle figure ou non dans le trio propose.
## Le trio n offre qu une partie des combinaisons (axe, forme) ; l application de
## chaque axe doit pourtant etre exacte, et c est elle qu on verifie ici. La voie
## doit tout de meme AVOIR UN SENS pour la carte (upgrade_path_by_id non vide).
func ok_prise(card: SpellCard, id: StringName) -> bool:
	RunState.reset()
	var sens: bool = not RunState.upgrade_path_by_id(card, id).is_empty()
	ok(sens, "%s : la voie '%s' a un sens pour cette carte" % [card.id, id])
	if sens:
		RunState.upgrades_taken[card.id] = id
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
	for v in RunState.upgrade_paths_for(p):
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
		for v in RunState.upgrade_paths_for(c):
			_prendre(c, StringName(v["id"]))
			for s in RunState.cast_specs(c):
				ok(float(s.params.get(&"slow_pct", 0.0)) <= cap + 0.001,
					"%s/%s : ralentissement de zone sous le plafond" % [c.id, v["id"]])
				if s.key == &"slow_enemy_gauge":
					ok(s.magnitude <= cap + 0.001,
						"%s/%s : ralentissement global sous le plafond" % [c.id, v["id"]])
	RunState.reset()


func _voie_de_gain(card: SpellCard, axis: StringName) -> bool:
	for v in RunState.upgrade_paths_for(card):
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
		for v in RunState.upgrade_paths_for(c):
			RunState.reset()
			var t_avant: float = RunState.effective_cast_time(c)
			_prendre(c, StringName(v["id"]))
			var change: bool = not is_equal_approx(RunState.effective_cast_time(c), t_avant)
			var apres: Array[EffectSpec] = RunState.cast_specs(c)
			for i in apres.size():
				if _differe(c.effects[i], apres[i]):
					change = true
			ok(change, "%s/%s : la voie change reellement le sort" % [c.id, v["id"]])
			if StringName(v.get("axis", &"")) != &"cast":
				var mord: bool = false
				for i in apres.size():
					if _differe(c.effects[i], apres[i]):
						mord = true
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


## Une carte deja amelioree ne repropose pas d offre au lancer suivant.
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
	eq(lignes.size(), RunState.upgrade_paths_for(c).size(),
		"le grimoire voit toutes les voies des le depart")
	for l in lignes:
		ok(l is Dictionary, "chaque entree est un Dictionary")
		ok(l.has("text") and l.get("text") is String, "chaque entree porte un `text` String")
		ok(l.has("unlocked"), "chaque entree porte un `unlocked`")
		not_ok(bool(l.get("unlocked", true)), "avant tout choix, aucune voie n est acquise")
		ok(String(l.get("text", "")).contains("+"), "la ligne du grimoire porte le gain signe")
	_lancer(c, GameConfig.CARD_UPGRADE_CASTS)
	var i: int = maxi(0, _indice_de_voie(c, &"area_light"))
	var voulue: String = String(RunState.upgrade_paths_for(c)[i].get("text", ""))
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
	var c: SpellCard = _carte_zone("t_ecran")
	var voies: Array = RunState.upgrade_paths_for(c)
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
	detach(hote)


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
	panneau.show_paths(c, RunState.upgrade_paths_for(c))
	ok(panneau.size.x >= hote.size.x * 0.99 and panneau.size.y >= hote.size.y * 0.99,
		"le panneau couvre son hote (%s pour %s)" % [panneau.size, hote.size])
	detach(hote)
