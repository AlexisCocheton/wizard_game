extends TestCase
## LE CONTENU DE PROGRESSION LIVRE — cartes nouvelles, cartes des objectifs,
## et l ordre de difficulte des objectifs (chantier W7).
##
## Regle du co-auteur (30/09) : chaque niveau fait decouvrir TROIS cartes
## nouvelles a la montee de niveau ("sinon trop de cartes, complique pour un
## niveau 1"), et ses trois objectifs, TOUJOURS classes du plus facile au plus
## dur, debloquent une rare, une epique, une legendaire. Les objectifs parlent
## des cartes du deck et des monstres du niveau.
##
## Le moteur (pool de montee, visibilite, rang -> rarete) est teste par
## test_card_progression ; les objectifs un par un par test_level_objectives.
## Ici : le CONTENU que tools/make_content.gd ecrit dans resources/levels.
##
## Chaque regle est une fonction statique qui rend la liste des defauts d un
## niveau : _test_les_detecteurs_mordent la sabote sur un niveau fabrique, un
## detecteur qui ne verrait rien passerait sinon en silence.

func get_suite_name() -> String:
	return "level_progression"


## Parties jouees par objectif au banc pour mesurer MESURES (voir plus bas).
## 60 et non 30 : deux objectifs voisins se departagent mal sur 30 parties.
## RE-MESURER : tools/objective_bench.tscn (deterministe depuis W8, une ligne
## prete a coller par niveau ; README_equilibrage, « Le banc des objectifs »).
const PARTIES_DU_BANC: int = 60

## LES TAUX MESURES, qui verrouillent l ordre de difficulte.
##
## Un taux de reussite ne se calcule pas a froid : il faut JOUER. Chaque ligne
## vient d une sonde de PARTIES_DU_BANC parties par objectif (graines 1000 + 37 i),
## avec le bot du banc (tools/sim_balance.gd : cible le plus avance hors du halo
## des totems, zones sur le plus gros groupe, offres et ameliorations par
## AutoPick) auquel on ajoute ce que ferait un joueur qui VISE cet objectif :
##   card_casts / same_card_casts / element_casts : jouer d abord cette carte
##     (la plus nombreuse du deck, cet element) ;
##   no_card / no_card_tag / no_card_key / no_legendary_used : ne jamais la
##     jouer, ni la prendre a une montee de niveau ;
##   kill_type_one_cast : poser ses zones sur le plus gros groupe de l espece ;
##   kill_type_with_card : jouer d abord la carte, viser d abord l espece ;
##   no_hit_from : viser d abord l espece ; hit_from : ne jamais la viser ;
##   no_passive : ne prendre aucun passif ; le reste : le bot du banc tel quel.
## Un objectif est reussi si la partie est GAGNEE et l objectif valide a la
## victoire (ObjectiveChecker.evaluate).
##
## Format : niveau -> [[id d objectif, parties reussies], ...] dans l ordre du
## niveau. Les ids sont DEDUITS du controle (DEC-023) : changer un seuil change
## l id, et ce test refuse alors la ligne — un objectif retouche doit etre
## re-mesure, sinon le classement ne serait plus qu une supposition.
const MESURES: Dictionary = {
	"lvl_01": [["obj_card_casts_piercing_arrow_6", 59], ["obj_no_card_fireball", 48], ["obj_win_above_speed_250", 28]],
	"lvl_02": [["obj_boss_quick_after_revive_8", 50], ["obj_win_above_speed_300", 31], ["obj_kill_type_one_cast_4_hopper", 8]],
	"lvl_08": [["obj_kill_type_one_cast_4_rat_swarm", 39], ["obj_kill_type_with_card_fireball_8_jelly_small", 29], ["obj_multi_kill_15_1", 16]],
	"lvl_09": [["obj_no_legendary", 56], ["obj_hit_from_sleepy_fox", 19], ["obj_win_below_speed_200", 10]],
	"lvl_17": [["obj_kill_flying_21", 51], ["obj_card_casts_resonance_7", 26], ["obj_no_enemy_past_0_7", 11]],
	"lvl_18": [["obj_kill_type_with_card_fireball_5_nacelle_raider", 40], ["obj_win_below_speed_190", 21], ["obj_card_casts_weakness_mark_11", 10]],
	"lvl_03": [["obj_multi_kill_8_1", 50], ["obj_card_casts_frost_rain_26", 20], ["obj_kill_type_with_card_frost_rain_15_rat_swarm", 16]],
	"lvl_04": [["obj_kill_type_with_card_ember_pool_2_risen_ghoul", 47], ["obj_no_hit_from_imp_archer", 32], ["obj_untouched", 21]],
	"lvl_19": [["obj_kill_type_one_cast_4_pit_ghoul", 31], ["obj_element_casts_44_fire", 10], ["obj_untouched", 6]],
	"lvl_20": [["obj_no_card_void_grip", 55], ["obj_card_casts_piercing_arrow_21", 27], ["obj_win_below_speed_150", 12]],
	"lvl_05": [["obj_element_casts_48_arcane", 46], ["obj_kill_type_one_cast_2_golem", 31], ["obj_win_above_speed_310", 17]],
	"lvl_06": [["obj_element_casts_5_lightning", 53], ["obj_kill_type_one_cast_3_hopper", 36], ["obj_win_under_time_100", 9]],
	"lvl_21": [["obj_kill_type_with_card_arcane_bolt_3_fire_worm", 47], ["obj_no_card_tag_fire", 33], ["obj_win_under_time_118", 15]],
	"lvl_07": [["obj_no_card_mirror_apprentice", 56], ["obj_kill_type_with_card_mirror_apprentice_5_sprite", 24], ["obj_win_above_speed_350", 9]],
	"lvl_10": [["obj_kill_flying_1", 49], ["obj_untouched", 44], ["obj_enemy_travel_1104_0_cacodaemon", 13]],
	"lvl_11": [["obj_kill_flying_4", 46], ["obj_element_casts_32_frost", 26], ["obj_win_below_speed_150", 21]],
	"lvl_12": [["obj_card_casts_focus_14", 45], ["obj_kill_type_with_card_arcane_bolt_7_shade", 30], ["obj_same_card_casts_38", 12]],
	"lvl_13": [["obj_no_legendary", 51], ["obj_card_casts_spark_25", 35], ["obj_win_above_speed_300", 20]],
	"lvl_14": [["obj_kill_type_one_cast_3_rat_swarm", 44], ["obj_hit_from_sleepy_fox", 21], ["obj_no_hit_from_imp_archer", 6]],
	"lvl_15": [["obj_element_casts_50_fire", 37], ["obj_never_hit_reflect", 29], ["obj_win_above_speed_380", 12]],
	"lvl_16": [["obj_no_hit_from_demon_chain_echo", 56], ["obj_boss_quick_after_revive_9", 31], ["obj_element_casts_58_arcane", 13]],
}


func run() -> void:
	_test_trois_cartes_nouvelles_par_niveau()
	_test_recompenses_rare_epique_legendaire()
	_test_tout_le_catalogue_est_obtenable()
	_test_les_passifs_s_obtiennent_des_l_acte_2()
	_test_cartes_simples_en_acte_1()
	_test_objectifs_lies_au_deck_et_aux_monstres()
	_test_un_seul_sort_sans_tueur_permanent()
	_test_objectifs_classes_par_difficulte()
	_test_aucun_avertissement_de_progression()
	_test_les_detecteurs_mordent()


# --- Outils ------------------------------------------------------------------

func _niveaux() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv != null:
			out.append(lv)
	return out


static func _ids(cartes: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in cartes:
		if c != null:
			out[(c as SpellCard).id] = true
	return out


## Le parametre `nom` d un objectif, en String ("" s il est absent).
static func _param(o: ObjectiveDef, nom: String) -> String:
	if o.params.has(nom):
		return str(o.params[nom])
	if o.params.has(StringName(nom)):
		return str(o.params[StringName(nom)])
	return ""


## La carte pose-t-elle un objet PERMANENT qui tue ? (ronces, arbre empoisonne,
## autel qui fait naitre des allies). Un tel objet est UN seul lancer pour toute
## la partie (ObjectiveChecker, section LANCER) : ses morts s additionnent sans
## fin et « en tuer N d un seul sort » deviendrait gratuit.
static func pose_un_tueur_permanent(c: SpellCard) -> bool:
	if c == null:
		return false
	for spec: EffectSpec in c.effects:
		if spec == null or spec.duration > 0.0:
			continue
		if not spec.key in [&"place_terrain", &"taunt_prop"]:
			continue
		if spec.magnitude > 0.0:
			return true
		if float(spec.get_param(&"summon_every", 0.0)) > 0.0 \
				and float(spec.get_param(&"ally_damage", 0.0)) > 0.0:
			return true
	return false


# --- Detecteurs (statiques, pour etre sabotes) --------------------------------

## Trois cartes nouvelles, differentes, absentes du deck ; une carte par
## objectif, absente du deck et des cartes nouvelles, de la rarete de son rang.
static func defauts_cartes(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	out.append_array(lv.progression_errors())
	out.append_array(lv.missing_progression())
	var deck: Dictionary = _ids(lv.exploration_deck)
	var nouvelles: Dictionary = _ids(lv.levelup_cards)
	if nouvelles.size() != LevelDef.LEVELUP_NEW_CARDS:
		out.append("%d cartes nouvelles differentes, %d attendues"
			% [nouvelles.size(), LevelDef.LEVELUP_NEW_CARDS])
	if lv.objective_rewards.size() != lv.objectives.size():
		out.append("%d recompenses pour %d objectifs"
			% [lv.objective_rewards.size(), lv.objectives.size()])
	var vues: Dictionary = {}
	for i in lv.objective_rewards.size():
		var r: SpellCard = lv.objective_rewards[i]
		if r == null:
			continue
		if deck.has(r.id):
			out.append("la recompense %s est deja au deck" % r.id)
		if nouvelles.has(r.id):
			out.append("la recompense %s est deja une carte nouvelle" % r.id)
		if vues.has(r.id):
			out.append("la recompense %s revient deux fois" % r.id)
		vues[r.id] = true
		if r.rarity != LevelDef.reward_rarity_for_rank(LevelDef.objective_rank(i)):
			out.append("la recompense du rang %d (%s) n a pas la rarete du rang"
				% [LevelDef.objective_rank(i), r.id])
	return out


## Un objectif est LIE au niveau s il nomme une carte de son deck, un element,
## un tag ou un effet que ce deck porte, une legendaire qu il contient, ou s il
## parle de ses monstres (une espece, ses volants, son monstre qui se releve,
## sa garde de renvoi). Deux sur trois au moins : le troisieme peut etre un pari
## de fin de combat (vitesse, chrono), comme l exemple du co-auteur.
static func lien_de(o: ObjectiveDef, lv: LevelDef) -> String:
	var deck: Dictionary = _ids(lv.exploration_deck)
	var especes: Dictionary = {}
	for d: EnemyDef in ObjectiveChecker.level_enemies(lv):
		especes[String(d.id)] = true
	var carte: String = _param(o, "card")
	var espece: String = _param(o, "enemy")
	if carte != "" and not deck.has(StringName(carte)):
		return ""
	if espece != "" and not especes.has(espece):
		return ""
	if carte != "" and espece != "":
		return "carte+monstre"
	if carte != "":
		return "carte"
	if espece != "":
		return "monstre"
	match o.check_key:
		&"element_casts", &"no_card_tag":
			var tag: int = ObjectiveChecker.tag_from_name(
				_param(o, "element") if o.check_key == &"element_casts" else _param(o, "tag"))
			for c: SpellCard in lv.exploration_deck:
				if c != null and c.tags.has(tag):
					return "carte"
		&"no_card_key":
			for c: SpellCard in lv.exploration_deck:
				if c != null and StringName(_param(o, "key")) in c.effect_keys():
					return "carte"
		&"no_legendary_used":
			for c: SpellCard in lv.exploration_deck:
				if c != null and c.rarity == GameEnums.Rarity.LEGENDARY:
					return "carte"
		&"kill_flying", &"boss_quick_after_revive", &"never_hit_reflect":
			if ObjectiveChecker.impossible_reasons(o, lv).is_empty() \
					and ObjectiveChecker.trivial_reasons(o, lv).is_empty():
				return "monstre"
	return ""


static func defauts_liens(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	var lies: int = 0
	var deck: Dictionary = _ids(lv.exploration_deck)
	for o: ObjectiveDef in lv.objectives:
		if o == null:
			continue
		var carte: String = _param(o, "card")
		# Une carte nommee par un objectif est une carte du DECK : une carte
		# nouvelle n arrive qu au hasard d une montee de niveau, l etoile
		# deviendrait un tirage.
		if carte != "" and not deck.has(StringName(carte)):
			out.append("%s nomme %s, absente du deck" % [o.id, carte])
		if lien_de(o, lv) != "":
			lies += 1
	if lies < 2:
		out.append("%d objectif(s) lie(s) aux cartes ou aux monstres du niveau, 2 attendus"
			% lies)
	return out


## Pas de « en tuer N d un seul sort » dans un niveau ou une carte jouable (deck,
## cartes nouvelles, recompenses) pose un tueur permanent.
static func defauts_un_seul_sort(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	var vise: bool = false
	for o: ObjectiveDef in lv.objectives:
		if o != null and o.check_key == &"kill_type_one_cast":
			vise = true
	if not vise:
		return out
	for liste: Array in [lv.exploration_deck, lv.levelup_cards, lv.objective_rewards]:
		for c in liste:
			if pose_un_tueur_permanent(c):
				out.append("%s pose un tueur permanent : un seul lancer pour toute la partie"
					% (c as SpellCard).id)
	return out


## Le classement mesure : ids identiques au contenu, chaque objectif reussi ET
## rate au moins une fois, taux strictement decroissant du rang 1 au rang 3.
static func defauts_classement(lv: LevelDef, mesure: Variant) -> Array[String]:
	var out: Array[String] = []
	if not mesure is Array or (mesure as Array).size() != lv.objectives.size():
		out.append("pas de mesure pour les %d objectifs" % lv.objectives.size())
		return out
	var precedent: int = PARTIES_DU_BANC + 1
	for i in lv.objectives.size():
		var ligne: Array = mesure[i]
		if lv.objectives[i] == null or StringName(ligne[0]) != lv.objectives[i].id:
			out.append("rang %d : mesure de %s, le niveau porte %s" % [i + 1, ligne[0],
				lv.objectives[i].id if lv.objectives[i] != null else &"rien"])
			continue
		var n: int = int(ligne[1])
		if n < 1:
			out.append("%s jamais reussi au banc" % ligne[0])
		if n > PARTIES_DU_BANC - 1:
			out.append("%s jamais rate au banc" % ligne[0])
		if n >= precedent:
			out.append("%s (%d) pas plus dur que le rang precedent (%d)"
				% [ligne[0], n, precedent])
		precedent = n
	return out


# --- Tests du contenu ----------------------------------------------------------

func _test_trois_cartes_nouvelles_par_niveau() -> void:
	var niveaux: Array[LevelDef] = _niveaux()
	ok(niveaux.size() > 0, "des niveaux a controler")
	for lv in niveaux:
		var d: Array[String] = defauts_cartes(lv)
		ok(d.is_empty(), "%s : cartes nouvelles et recompenses conformes %s" % [lv.id, d])


func _test_recompenses_rare_epique_legendaire() -> void:
	# La table du moteur dit rare / epique / legendaire : le contenu la suit
	# rang par rang (defauts_cartes), et chaque rarete de la table est servie.
	for lv in _niveaux():
		var raretes: Array = []
		for r: SpellCard in lv.objective_rewards:
			raretes.append(int(r.rarity) if r != null else -1)
		var attendues: Array = []
		for rarete: int in LevelDef.REWARD_RARITY_BY_RANK:
			attendues.append(rarete)
		eq(raretes, attendues, "%s : recompenses de rarete croissante" % lv.id)


## TOUT le catalogue s obtient en campagne. Un sort qu aucun deck, aucune carte
## nouvelle, aucune recompense ne porte ne peut JAMAIS etre obtenu (le pool hors
## campagne ne contient que l obtenu). Les "cartes de depart" n y echappent plus :
## copies_in_starter ne donne plus rien au livre de sorts (01/10).
func _test_tout_le_catalogue_est_obtenable() -> void:
	var joignables: Dictionary = {}
	for lv in _niveaux():
		for liste: Array in [lv.exploration_deck, lv.levelup_cards, lv.objective_rewards]:
			joignables.merge(_ids(liste))
	var morts: Array[String] = []
	var sorts: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.is_passive:
			continue
		sorts += 1
		if not joignables.has(c.id):
			morts.append(String(c.id))
	ok(sorts > 0, "des sorts au catalogue")
	ok(morts.is_empty(), "aucun sort jamais obtenable en campagne %s" % [morts])


## Les passifs n ont pas de ligne dans la table : le pool de montee de niveau
## d un niveau d acte >= PASSIVES_FROM_ACT les contient TOUS (RunState.
## levelup_pool). Il suffit donc qu un tel niveau existe et que son pool les
## montre bien.
func _test_les_passifs_s_obtiennent_des_l_acte_2() -> void:
	var niveau: LevelDef = null
	for lv in _niveaux():
		if lv.allows_passives():
			niveau = lv
			break
	ok(niveau != null, "un niveau de campagne admet les passifs")
	if niveau == null:
		return
	var pool: Dictionary = _ids(RunState.levelup_pool(niveau, GameEnums.Mode.EXPLORATION))
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive:
			ok(pool.has(c.id), "le passif %s s obtient en campagne (%s)" % [c.id, niveau.id])


## « Seulement trois nouvelles cartes par niveau, sinon c est complique pour un
## niveau 1 » : en acte 1 les cartes nouvelles sont des communes ou des rares,
## et aucune ne pose d objet permanent (les terrains arrivent a l acte 2).
func _test_cartes_simples_en_acte_1() -> void:
	for lv in _niveaux():
		if lv.act != 1:
			continue
		for c: SpellCard in lv.levelup_cards:
			if c == null:
				continue
			ok(c.rarity <= GameEnums.Rarity.RARE,
				"%s : %s, carte nouvelle d acte 1, est commune ou rare" % [lv.id, c.id])
			var permanent: bool = false
			for spec: EffectSpec in c.effects:
				if spec != null and spec.duration <= 0.0 \
						and spec.key in SpellCard.TYPE_TERRAIN_KEYS:
					permanent = true
			not_ok(permanent, "%s : %s ne pose pas d objet permanent en acte 1" % [lv.id, c.id])


func _test_objectifs_lies_au_deck_et_aux_monstres() -> void:
	var cartes: int = 0
	var monstres: int = 0
	for lv in _niveaux():
		var d: Array[String] = defauts_liens(lv)
		ok(d.is_empty(), "%s : objectifs lies au niveau %s" % [lv.id, d])
		for o: ObjectiveDef in lv.objectives:
			var lien: String = lien_de(o, lv) if o != null else ""
			if lien.contains("carte"):
				cartes += 1
			if lien.contains("monstre"):
				monstres += 1
	# Les deux sortes de liens existent sur la campagne, et chacune pese : un
	# contenu qui ne parlerait que des cartes oublierait la moitie de la demande.
	var total: int = 3 * _niveaux().size()
	ok(cartes * 4 >= total, "%d objectifs sur %d parlent des cartes du deck" % [cartes, total])
	ok(monstres * 4 >= total, "%d objectifs sur %d parlent des monstres" % [monstres, total])


func _test_un_seul_sort_sans_tueur_permanent() -> void:
	for lv in _niveaux():
		var d: Array[String] = defauts_un_seul_sort(lv)
		ok(d.is_empty(), "%s : « d un seul sort » sans tueur permanent %s" % [lv.id, d])


func _test_objectifs_classes_par_difficulte() -> void:
	for lv in _niveaux():
		var d: Array[String] = defauts_classement(lv, MESURES.get(String(lv.id)))
		ok(d.is_empty(), "%s : objectifs classes du plus facile au plus dur %s" % [lv.id, d])


## L AUDIT ne fait qu AVERTIR sur un niveau incomplet, un objectif gratuit ou un
## sort jamais obtenable : le contenu livre n en porte aucun.
func _test_aucun_avertissement_de_progression() -> void:
	for lv in _niveaux():
		eq(lv.missing_progression(), [] as Array[String], "%s : progression complete" % lv.id)
		eq(lv.progression_errors(), [] as Array[String], "%s : progression sans erreur" % lv.id)
		for o: ObjectiveDef in lv.objectives:
			if o != null:
				eq(ObjectiveChecker.trivial_reasons(o, lv), [] as Array[String],
					"%s / %s : pas gratuit" % [lv.id, o.id])


# --- Sabotages ---------------------------------------------------------------

func _test_les_detecteurs_mordent() -> void:
	var modele: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(modele != null, "le niveau modele existe")
	if modele == null:
		return
	ok(defauts_cartes(modele).is_empty(), "le modele est conforme avant sabotage")
	# Une carte nouvelle deja au deck, puis deux fois la meme.
	var lv: LevelDef = modele.duplicate()
	var dup: Array[SpellCard] = [modele.exploration_deck[0], modele.levelup_cards[1],
		modele.levelup_cards[2]]
	lv.levelup_cards = dup
	not_ok(defauts_cartes(lv).is_empty(), "une carte nouvelle deja au deck est refusee")
	var deux: Array[SpellCard] = [modele.levelup_cards[0], modele.levelup_cards[0],
		modele.levelup_cards[1]]
	lv.levelup_cards = deux
	not_ok(defauts_cartes(lv).is_empty(), "deux fois la meme carte nouvelle est refusee")
	# Recompenses dans le desordre de rarete.
	var lv2: LevelDef = modele.duplicate()
	var inv: Array[SpellCard] = [modele.objective_rewards[2], modele.objective_rewards[1],
		modele.objective_rewards[0]]
	lv2.objective_rewards = inv
	not_ok(defauts_cartes(lv2).is_empty(), "des recompenses de rarete decroissante sont refusees")
	# Une recompense qui est deja au deck.
	var lv3: LevelDef = modele.duplicate()
	var au_deck: Array[SpellCard] = [modele.exploration_deck[0], modele.objective_rewards[1],
		modele.objective_rewards[2]]
	lv3.objective_rewards = au_deck
	not_ok(defauts_cartes(lv3).is_empty(), "une recompense deja au deck est refusee")
	# Des objectifs qui ne parlent ni des cartes ni des monstres.
	var lv4: LevelDef = modele.duplicate()
	var vide_a := ObjectiveDef.new()
	vide_a.id = &"t_a"
	vide_a.check_key = &"win_under_time"
	vide_a.params = {"seconds": 60}
	var vide_b := ObjectiveDef.new()
	vide_b.id = &"t_b"
	vide_b.check_key = &"no_damage_taken"
	var hors_deck := ObjectiveDef.new()
	hors_deck.id = &"t_c"
	hors_deck.check_key = &"card_casts"
	hors_deck.params = {"card": String(modele.levelup_cards[0].id), "count": 3}
	var objs: Array[ObjectiveDef] = [vide_a, vide_b, hors_deck]
	lv4.objectives = objs
	not_ok(defauts_liens(lv4).is_empty(),
		"un trio sans lien au niveau, ou qui nomme une carte hors du deck, est refuse")
	# « D un seul sort » avec un tueur permanent jouable.
	var tueur: SpellCard = null
	for c: SpellCard in ContentDB.cards.values():
		if pose_un_tueur_permanent(c):
			tueur = c
			break
	ok(tueur != null, "le catalogue compte un tueur permanent (ronces, arbre, autel)")
	if tueur != null:
		var lv5: LevelDef = modele.duplicate()
		var un_sort := ObjectiveDef.new()
		un_sort.id = &"t_un"
		un_sort.check_key = &"kill_type_one_cast"
		un_sort.params = {"enemy": "gnome", "count": 3}
		var objs5: Array[ObjectiveDef] = [un_sort]
		lv5.objectives = objs5
		var avec: Array[SpellCard] = [tueur]
		lv5.levelup_cards = avec
		not_ok(defauts_un_seul_sort(lv5).is_empty(),
			"« d un seul sort » a cote d un tueur permanent est refuse")
	# Un classement egal, un taux jamais rate, des ids perimes.
	var ids: Array = []
	for o: ObjectiveDef in modele.objectives:
		ids.append(String(o.id))
	var bonne: Array = [[ids[0], PARTIES_DU_BANC - 1], [ids[1], 2], [ids[2], 1]]
	ok(defauts_classement(modele, bonne).is_empty(), "un classement conforme passe")
	var egal: Array = [[ids[0], 5], [ids[1], 5], [ids[2], 1]]
	not_ok(defauts_classement(modele, egal).is_empty(), "deux rangs a egalite sont refuses")
	var jamais_rate: Array = [[ids[0], PARTIES_DU_BANC], [ids[1], 2], [ids[2], 1]]
	not_ok(defauts_classement(modele, jamais_rate).is_empty(), "un objectif jamais rate est refuse")
	var jamais_reussi: Array = [[ids[0], 3], [ids[1], 2], [ids[2], 0]]
	not_ok(defauts_classement(modele, jamais_reussi).is_empty(),
		"un objectif jamais reussi est refuse")
	var perime: Array = [[ids[1], 9], [ids[0], 5], [ids[2], 1]]
	not_ok(defauts_classement(modele, perime).is_empty(), "une mesure d un autre objectif est refusee")
	not_ok(defauts_classement(modele, null).is_empty(), "un niveau sans mesure est refuse")
