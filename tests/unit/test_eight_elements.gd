extends TestCase
## LES HUIT ELEMENTS (vague 8) — ce que l element change EN JEU, au-dela des
## degats deja verifies par test_elements et test_resist_effects :
##
##   1. un OBJET DE TERRAIN porte l element de sa carte, et les coups d un
##      monstre sur lui suivent la relation du monstre a cet element (regle du
##      co-auteur : un monstre FAIBLE a la glace frappe MOINS un mur de glace),
##      symetrique et bornee (EnemyDef.object_hit_factor) ;
##   2. un monstre immunise au VENT n est pas attire par une attraction de vent ;
##   3. un allie invoque frappe a l element de sa carte ;
##   4. les PASSIFS ELEMENTAIRES (cle generique `passive_element`) : chaque regle
##      `stat` agit sur SON element et sur lui seul, au-dela du seuil ;
##   5. tous les passifs elementaires sont proposables des l acte 2.
##
## Aucun chiffre de contenu en dur : on compare un monstre neutre a un monstre
## faible ou resistant, et on lit les bornes dans EnemyDef / RunState.

func get_suite_name() -> String:
	return "eight_elements"


const T := GameEnums.DamageTag

var _bf: Battlefield = null


func run() -> void:
	_test_la_regle_des_objets_est_symetrique_et_bornee()
	_test_un_mur_de_glace_et_ses_frappeurs()
	_test_un_objet_pose_porte_l_element_de_sa_carte()
	_test_l_immunite_au_vent_annule_l_attraction()
	_test_les_deux_exemples_existent_en_campagne()
	_test_les_detecteurs_d_exemples_mordent()
	_test_l_allie_frappe_a_l_element_de_sa_carte()
	_test_deux_passifs_par_element()
	_test_le_passif_de_degats_ne_sert_que_son_element()
	_test_le_seuil_eteint_le_passif_elementaire()
	_test_incantation_duree_rayon()
	_test_perce_resistance_et_solidite()
	_test_les_passifs_elementaires_sont_proposables()
	_test_l_etoile_du_givre_suit_la_glace()
	_cleanup()


func _cleanup() -> void:
	if _bf != null:
		detach(_bf)
		_bf = null
	RunState.reset()
	reset_gauge_at_normal_speed()


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()


func _def(id: String, table: Dictionary = {}) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 500.0
	d.base_speed = 60.0
	d.power = 1
	d.resistances = table
	return d


func _card(element: int, keys: Array = []) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName("t_" + GameEnums.tag_name(element))
	c.element = element
	for k in keys:
		var sp := EffectSpec.new()
		sp.key = StringName(k)
		c.effects.append(sp)
	return c


func _elemental(element: int, stat: StringName, pct: float, seuil: int = 100) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName("t_pass_%s_%s" % [GameEnums.tag_name(element), stat])
	c.is_passive = true
	c.speed_threshold = seuil
	c.element = element
	var sp := EffectSpec.new()
	sp.key = &"passive_element"
	sp.magnitude = pct
	sp.params = {&"stat": stat}
	c.effects = [sp]
	return c


# --- 1. LES OBJETS DE TERRAIN -------------------------------------------------

func _test_la_regle_des_objets_est_symetrique_et_bornee() -> void:
	feq(EnemyDef.object_hit_factor(1.0), 1.0, "neutre : coups inchanges")
	ok(EnemyDef.object_hit_factor(EnemyDef.WEAK_CAP) < 1.0,
		"faible a l element : il frappe l objet moins fort")
	ok(EnemyDef.object_hit_factor(0.5) > 1.0, "resistant : il le frappe plus fort")
	# Symetrique en ecart relatif : faible x2 et resistant x0,5 s annulent.
	feq(EnemyDef.object_hit_factor(2.0) * EnemyDef.object_hit_factor(0.5), 1.0,
		"la regle est symetrique", 0.001)
	feq(EnemyDef.object_hit_factor(0.0), EnemyDef.OBJECT_HIT_MAX,
		"immunise : il brise l objet au plafond")
	for i in range(1, 80):
		var r: float = float(i) * 0.05
		var f: float = EnemyDef.object_hit_factor(r)
		ok(f >= EnemyDef.OBJECT_HIT_MIN and f <= EnemyDef.OBJECT_HIT_MAX,
			"r = %.2f : facteur borne" % r)


## Le cas du co-auteur, joue sur un vrai Battlefield : un mur de GLACE, trois
## monstres qui le frappent pendant le meme temps.
func _pv_perdus_par(def: EnemyDef, tags_mur: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 600.0))
	var devant := Vector2(540.0, 600.0 + e.radius() + 20.0)
	_bf.spawn_breakable_wall(devant, 120.0, 60.0, 1000.0, tags_mur)
	var avant: float = _bf.wall_hp_at(devant)
	for i in 30:
		_bf.enemy_strikes_wall(e, 1.0 / 60.0)
	return avant - _bf.wall_hp_at(devant)


func _test_un_mur_de_glace_et_ses_frappeurs() -> void:
	var glace: Array = [T.ICE]
	var neutre: float = _pv_perdus_par(_def("neutre"), glace)
	var faible: float = _pv_perdus_par(_def("faible", {T.ICE: EnemyDef.WEAK_CAP}), glace)
	var froid: float = _pv_perdus_par(_def("froid", {T.ICE: 0.5}), glace)
	ok(neutre > 0.0, "un monstre neutre entame le mur de glace")
	ok(faible < neutre, "un monstre FAIBLE a la glace frappe moins le mur de glace")
	ok(froid > neutre, "un monstre qui RESISTE a la glace le frappe plus fort")
	feq(faible / neutre, EnemyDef.object_hit_factor(EnemyDef.WEAK_CAP),
		"exactement le facteur de la regle", 0.01)
	# Un mur d un AUTRE element ne se soucie pas de la glace.
	feq(_pv_perdus_par(_def("faible2", {T.ICE: EnemyDef.WEAK_CAP}), [T.FIRE]), neutre,
		"sur un mur de feu, sa faiblesse a la glace ne compte pas", 0.01)
	# Le passif « solidite » de l element s ajoute ; celui d un autre non.
	_fresh()
	RunState.equip_passive(_elemental(T.ICE, RunState.ELEM_STURDY, 50.0))
	var e: Enemy = _bf.spawn_enemy(_def("neutre3"), 540.0, 1.0, Vector2(540.0, 600.0))
	feq(_bf.object_hit(100.0, e, glace), 50.0, "solidite de glace : -50 % sur un objet de glace", 0.01)
	feq(_bf.object_hit(100.0, e, [T.FIRE]), 100.0, "et rien sur un objet de feu", 0.01)
	feq(_bf.object_hit(100.0, null, []), 100.0, "un coup sans auteur ni element passe tel quel", 0.01)


## Un objet POSE par une carte porte l element de cette carte (mur et accessoire).
func _test_un_objet_pose_porte_l_element_de_sa_carte() -> void:
	_fresh()
	var ctx := CastContext.new()
	ctx.battlefield = _bf
	ctx.target_position = Vector2(540.0, 800.0)
	var mur := _card(T.ICE)
	var sp := EffectSpec.new()
	sp.key = &"build_wall"
	sp.radius = 120.0
	sp.params = {&"permanent": true, &"wall_hp": 300.0}
	mur.effects = [sp]
	EffectRegistry.cast(mur, ctx)
	ok(_bf.walls.size() == 1, "le mur est pose")
	if _bf.walls.size() == 1:
		eq(Battlefield.element_of(_bf.walls[0].get("tags", []) as Array), T.ICE,
			"le mur porte l element de sa carte")
	var totem: SpellCard = ContentDB.cards.get(&"heartwood_totem")
	if totem != null:
		ctx.target_position = Vector2(300.0, 700.0)
		EffectRegistry.cast(totem, ctx)
		ok(_bf.props.size() >= 1, "le totem est plante")
		if _bf.props.size() >= 1:
			eq(Battlefield.element_of(_bf._prop_tags(_bf.props[0])), totem.main_element(),
				"l arbre porte l element de sa carte (nature)")


# --- 2. LE VENT ET L ATTRACTION ------------------------------------------------

func _aspire(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 300.0, 1.0, Vector2(300.0, 900.0))
	_bf.spawn_vortex(Vector2(540.0, 900.0), 400.0, 5.0, 60.0, tags)
	_bf.simulate(1.0 / 60.0)
	return e.position.x - 300.0


func _test_l_immunite_au_vent_annule_l_attraction() -> void:
	var vent: Array = [T.WIND]
	ok(_aspire(_def("neutre"), vent) > 0.0, "une spirale de vent aspire un monstre neutre")
	feq(_aspire(_def("ancre", {T.WIND: 0.0}), vent), 0.0,
		"immunise au VENT : la spirale de vent ne l attire pas", 0.001)
	ok(_aspire(_def("ancre2", {T.WIND: 0.0}), [T.ARCANE]) > 0.0,
		"le meme monstre est aspire par une spirale d un autre element")
	# Le contenu : la Spirale de sel et le Maelstrom sont bien de vent.
	for id in [&"salt_spiral", &"maelstrom"]:
		var c: SpellCard = ContentDB.cards.get(id)
		if c != null:
			eq(c.main_element(), T.WIND, "%s est un sort de vent" % id)


# --- 2 bis. LES DEUX EXEMPLES DANS LE CONTENU LIVRE (chantier W9) ---------------
#
# Les deux tests ci-dessus jouent les regles sur des monstres FABRIQUES. Un audit
# a releve que le joueur ne les rencontrait jamais : aucune carte ne posait
# d objet de glace (tous les objets etaient de nature, la Riviere d eau), aucun
# monstre n etait immunise au vent (0,3 au plus bas). Ici, le CONTENU : chaque
# exemple doit exister dans un niveau de campagne, la ou le joueur peut le voir.


## La carte pose-t-elle un objet que les monstres FRAPPENT (un mur cassable) ?
## Un mur a duree n a pas de PV : les monstres le contournent sans le toucher,
## la regle des objets ne s y voit pas.
static func pose_un_objet_frappe(c: SpellCard) -> bool:
	if c == null:
		return false
	for sp: EffectSpec in c.effects:
		if sp != null and sp.key == &"build_wall" \
				and bool(sp.get_param(&"permanent", false)) \
				and float(sp.get_param(&"wall_hp", 0.0)) > 0.0:
			return true
	return false


## « niveau : carte : monstre » pour chaque niveau de campagne ou une carte de
## GLACE qui pose un objet frappe est jouable (deck, cartes nouvelles,
## recompenses) ET ou descend un monstre faible a la glace (il frappera ce mur
## moins fort : l exemple du co-auteur).
static func exemples_mur_de_glace(niveaux: Array) -> Array[String]:
	var out: Array[String] = []
	for lv: LevelDef in niveaux:
		if lv == null or lv.act <= 0:
			continue
		var faibles: Array[String] = []
		for d: EnemyDef in ObjectiveChecker.level_enemies(lv):
			if d.resistance_to(GameEnums.DamageTag.ICE) > 1.0:
				faibles.append(String(d.id))
		if faibles.is_empty():
			continue
		for liste: Array in [lv.exploration_deck, lv.levelup_cards, lv.objective_rewards]:
			for c in liste:
				var carte: SpellCard = c
				if carte != null and carte.main_element() == GameEnums.DamageTag.ICE \
						and pose_un_objet_frappe(carte):
					out.append("%s : %s : %s" % [lv.id, carte.id, faibles[0]])
	return out


## « niveau : monstre : carte » pour chaque niveau de campagne ou descend un
## monstre IMMUNISE au vent et dont le DECK porte une attraction de vent (le
## joueur l a en main : il voit le monstre ne pas bouger).
static func exemples_ancre_au_vent(niveaux: Array) -> Array[String]:
	var out: Array[String] = []
	for lv: LevelDef in niveaux:
		if lv == null or lv.act <= 0:
			continue
		var attraction: String = ""
		for c in lv.exploration_deck:
			var carte: SpellCard = c
			if carte != null and carte.main_element() == GameEnums.DamageTag.WIND \
					and &"vortex_pull" in carte.effect_keys():
				attraction = String(carte.id)
		if attraction == "":
			continue
		for d: EnemyDef in ObjectiveChecker.level_enemies(lv):
			if d.resistance_to(GameEnums.DamageTag.WIND) <= 0.0:
				out.append("%s : %s : %s" % [lv.id, d.id, attraction])
	return out


func _test_les_deux_exemples_existent_en_campagne() -> void:
	var niveaux: Array = ContentDB.levels.values()
	var glace: Array[String] = exemples_mur_de_glace(niveaux)
	ok(not glace.is_empty(),
		"un mur de GLACE s obtient en campagne face a un monstre faible a la glace %s" % [glace])
	var vent: Array[String] = exemples_ancre_au_vent(niveaux)
	ok(not vent.is_empty(),
		"un monstre IMMUNISE au vent descend la ou le deck porte une attraction de vent %s" % [vent])
	# Le mur de glace livre joue vraiment la regle : pose sur un vrai terrain, il
	# porte la glace et un monstre faible a la glace le frappe moins fort.
	for c: SpellCard in ContentDB.cards.values():
		if c == null or c.main_element() != GameEnums.DamageTag.ICE \
				or not pose_un_objet_frappe(c):
			continue
		_fresh()
		var ctx := CastContext.new()
		ctx.battlefield = _bf
		ctx.target_position = Vector2(540.0, 900.0)
		EffectRegistry.cast(c, ctx)
		ok(_bf.walls.size() == 1, "%s pose un mur" % c.id)
		if _bf.walls.size() == 1:
			eq(Battlefield.element_of(_bf.walls[0].get("tags", []) as Array), T.ICE,
				"%s : le mur est de glace" % c.id)
			ok(_bf.wall_hp_at(Vector2(540.0, 900.0)) > 0.0, "%s : le mur a des PV" % c.id)
		_cleanup()


## Sabotage : les deux detecteurs ne voient rien sur des niveaux qui n ont pas
## l exemple, et le voient quand on l y met.
func _test_les_detecteurs_d_exemples_mordent() -> void:
	var lv := LevelDef.new()
	lv.id = &"t_exemples"
	lv.act = 1
	var w := WaveDef.new()
	var faible := _def("faible_glace", {T.ICE: 1.5, T.WIND: 0.0})
	w.entries = [_entree(faible)] as Array[WaveEntry]
	lv.waves = [w] as Array[WaveDef]
	var niveaux: Array = [lv]
	ok(exemples_mur_de_glace(niveaux).is_empty(), "sans carte de glace, pas d exemple de mur")
	ok(exemples_ancre_au_vent(niveaux).is_empty(), "sans attraction de vent au deck, pas d exemple")
	# Un mur de pierre cassable : un objet frappe, mais pas de glace.
	var pierre: SpellCard = _carte_mur(T.NATURE, true)
	lv.levelup_cards = [pierre] as Array[SpellCard]
	ok(exemples_mur_de_glace(niveaux).is_empty(), "un mur de nature ne fait pas l exemple")
	# Un mur de glace A DUREE : de la glace, mais aucun coup ne le touche.
	lv.levelup_cards = [_carte_mur(T.ICE, false)] as Array[SpellCard]
	ok(exemples_mur_de_glace(niveaux).is_empty(), "un mur de glace sans PV ne fait pas l exemple")
	lv.levelup_cards = [_carte_mur(T.ICE, true)] as Array[SpellCard]
	eq(exemples_mur_de_glace(niveaux).size(), 1, "un mur de glace cassable face a un faible")
	# Une attraction d ARCANE : le monstre est immunise au vent, pas a elle.
	var spirale_arcane: SpellCard = _card(T.ARCANE, ["vortex_pull"])
	lv.exploration_deck = [spirale_arcane] as Array[SpellCard]
	ok(exemples_ancre_au_vent(niveaux).is_empty(), "une attraction d un autre element ne fait pas l exemple")
	lv.exploration_deck = [_card(T.WIND, ["vortex_pull"])] as Array[SpellCard]
	eq(exemples_ancre_au_vent(niveaux).size(), 1, "attraction de vent face a une ancre")
	faible.resistances = {T.ICE: 1.5, T.WIND: 0.3}
	ok(exemples_ancre_au_vent(niveaux).is_empty(), "un monstre qui RESISTE au vent n est pas une ancre")


func _entree(d: EnemyDef) -> WaveEntry:
	var e := WaveEntry.new()
	e.enemy = d
	e.count = 1
	return e


func _carte_mur(element: int, cassable: bool) -> SpellCard:
	var c := _card(element)
	var sp := EffectSpec.new()
	sp.key = &"build_wall"
	sp.radius = 150.0
	if cassable:
		sp.params = {&"permanent": true, &"wall_hp": 70.0}
	else:
		sp.duration = 20.0
	c.effects = [sp] as Array[EffectSpec]
	return c


# --- 3. LES ALLIES ---------------------------------------------------------------

func _test_l_allie_frappe_a_l_element_de_sa_carte() -> void:
	_fresh()
	var cible: Enemy = _bf.spawn_enemy(_def("immunise", {T.NATURE: 0.0}), 540.0, 1.0,
		Vector2(540.0, 900.0))
	for i in 30:
		_bf.simulate(1.0 / 60.0)
	var pv: float = cible.hp
	_bf.spawn_ally(5.0, 20.0, Vector2.INF, [T.NATURE, T.SUMMON])
	for i in 120:
		_bf.simulate(1.0 / 60.0)
	feq(cible.hp, pv, "un allie de nature ne blesse pas un monstre immunise a la nature", 0.01)
	_fresh()
	var autre: Enemy = _bf.spawn_enemy(_def("immunise2", {T.NATURE: 0.0}), 540.0, 1.0,
		Vector2(540.0, 900.0))
	for i in 30:
		_bf.simulate(1.0 / 60.0)
	var pv2: float = autre.hp
	_bf.spawn_ally(5.0, 20.0)
	for i in 120:
		_bf.simulate(1.0 / 60.0)
	ok(autre.hp < pv2, "un allie sans element (passif) le blesse")


# --- 4. LES PASSIFS ELEMENTAIRES -------------------------------------------------

## « Au moins deux par element » (demande du co-auteur), chacun sur une regle
## connue, avec une icone dediee, sur des regles DIFFERENTES pour un meme
## element, et avec un seuil dans la fourchette de sa rarete (test_passives).
func _test_deux_passifs_par_element() -> void:
	var par_element: Dictionary = {}
	for c: SpellCard in ContentDB.cards.values():
		if c == null or not c.is_passive or not (&"passive_element" in c.effect_keys()):
			continue
		var el: int = c.main_element()
		ok(el in GameEnums.ELEMENTS, "%s amplifie un element" % c.id)
		var stat: StringName = StringName(c.effects[0].get_param(&"stat", &""))
		ok(stat in RunState.ELEMENT_STATS, "%s : regle connue (%s)" % [c.id, stat])
		ok(c.effects[0].magnitude > 0.0, "%s : un pourcentage positif" % c.id)
		ok(ResourceLoader.exists(CardIcons.art_path(c)), "%s a son icone dediee" % c.id)
		ok(c.spell_type() == SpellCard.type_of_tag(el), "%s montre le logo de son element" % c.id)
		var stats: Array = par_element.get(el, [])
		not_ok(stats.has(stat), "%s : pas deux fois la meme regle pour %s" % [c.id,
			GameEnums.tag_name(el)])
		stats.append(stat)
		par_element[el] = stats
	for e in GameEnums.ELEMENTS:
		ok((par_element.get(e, []) as Array).size() >= 2,
			"au moins deux passifs pour %s" % GameEnums.tag_name(e))


func _degats_portes(card: SpellCard, def: EnemyDef) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 600.0))
	for i in 30:
		_bf.simulate(1.0 / 60.0)
	var pv: float = e.hp
	_bf.damage_enemy(e, 40.0, card)
	return pv - e.hp


func _test_le_passif_de_degats_ne_sert_que_son_element() -> void:
	var feu := _card(T.FIRE)
	var glace := _card(T.ICE)
	var base_feu: float = _degats_portes(feu, _def("n1"))
	var base_glace: float = _degats_portes(glace, _def("n2"))
	var p := _elemental(T.FIRE, RunState.ELEM_DAMAGE, 30.0)
	_fresh()
	RunState.equip_passive(p)
	var e: Enemy = _bf.spawn_enemy(_def("n3"), 540.0, 1.0, Vector2(540.0, 600.0))
	for i in 30:
		_bf.simulate(1.0 / 60.0)
	var pv: float = e.hp
	_bf.damage_enemy(e, 40.0, feu)
	feq(pv - e.hp, base_feu * (1.0 + p.effects[0].magnitude * 0.01),
		"le passif de feu majore les degats de feu de son pourcentage", 0.01)
	pv = e.hp
	_bf.damage_enemy(e, 40.0, glace)
	feq(pv - e.hp, base_glace, "et ne touche pas a la glace", 0.01)


func _test_le_seuil_eteint_le_passif_elementaire() -> void:
	_fresh()
	var p := _elemental(T.WIND, RunState.ELEM_CAST, 20.0, 150)
	RunState.equip_passive(p)
	SpeedGauge.set_speed_percent(149)
	feq(RunState.element_bonus(T.WIND, RunState.ELEM_CAST), 0.0, "sous le seuil : rien")
	SpeedGauge.set_speed_percent(150)
	feq(RunState.element_bonus(T.WIND, RunState.ELEM_CAST), 20.0, "au seuil : actif")
	feq(RunState.element_bonus(T.FIRE, RunState.ELEM_CAST), 0.0, "pour son element seulement")
	reset_gauge_at_normal_speed()


func _test_incantation_duree_rayon() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	var vent := _card(T.WIND, ["ground_zone"])
	vent.base_cast_time = 2.0
	vent.effects[0].duration = 4.0
	vent.effects[0].radius = 100.0
	var feu := _card(T.FIRE, ["ground_zone"])
	feu.base_cast_time = 2.0
	feu.effects[0].duration = 4.0
	var t0: float = RunState.effective_cast_time(vent)
	var tf: float = RunState.effective_cast_time(feu)
	RunState.equip_passive(_elemental(T.WIND, RunState.ELEM_CAST, 25.0))
	feq(RunState.effective_cast_time(vent), t0 * 0.75, "vent : incantation -25 %", 0.01)
	feq(RunState.effective_cast_time(feu), tf, "feu : incantation inchangee", 0.001)
	# Plancher : deux passifs du meme element ne rendent pas un sort instantane.
	RunState.equip_passive(_elemental(T.WIND, RunState.ELEM_CAST, 95.0))
	feq(RunState.effective_cast_time(vent), t0 * RunState.ELEMENT_CAST_FLOOR,
		"plancher de l incantation elementaire", 0.01)
	RunState.reset()
	RunState.equip_passive(_elemental(T.WIND, RunState.ELEM_DURATION, 50.0))
	RunState.equip_passive(_elemental(T.WIND, RunState.ELEM_RADIUS, 30.0))
	var specs: Array[EffectSpec] = RunState.cast_specs(vent)
	feq(specs[0].duration, 4.0 * 1.5, "vent : duree +50 %", 0.001)
	feq(specs[0].radius, 100.0 * 1.3, "vent : rayon +30 %", 0.001)
	feq(vent.effects[0].duration, 4.0, "la ressource partagee n est jamais modifiee", 0.001)
	feq(RunState.cast_specs(feu)[0].duration, 4.0, "le feu ne profite pas d un passif de vent", 0.001)
	ok(RunState.cast_specs(feu)[0] == feu.effects[0], "sans passif, aucune copie")
	# Un objet PERMANENT (duree 0) le reste.
	vent.effects[0].duration = 0.0
	feq(RunState.cast_specs(vent)[0].duration, 0.0, "une duree nulle (permanente) reste nulle")
	RunState.reset()


func _test_perce_resistance_et_solidite() -> void:
	RunState.reset()
	reset_gauge_at_normal_speed()
	feq(RunState.pierce_resistance(0.4, T.POISON), 0.4, "sans passif, rien ne change")
	RunState.equip_passive(_elemental(T.POISON, RunState.ELEM_PIERCE, 50.0))
	feq(RunState.pierce_resistance(0.4, T.POISON), 0.7, "la resistance recule de moitie vers le neutre", 0.001)
	feq(RunState.pierce_resistance(0.0, T.POISON), 0.0, "une immunite reste une immunite")
	feq(RunState.pierce_resistance(1.5, T.POISON), 1.5, "une faiblesse ne bouge pas")
	feq(RunState.pierce_resistance(0.4, T.FIRE), 0.4, "un autre element ne bouge pas")
	RunState.reset()


# --- 5. LA PROPOSITION -------------------------------------------------------

func _test_les_passifs_elementaires_sont_proposables() -> void:
	RunState.reset()
	var vus: Dictionary = {}
	for l: LevelDef in ContentDB.levels.values():
		if not l.allows_passives():
			continue
		for c in RunState.levelup_pool(l, GameEnums.Mode.EXPLORATION):
			if c.is_passive:
				vus[c.id] = true
	var n: int = 0
	for c: SpellCard in ContentDB.cards.values():
		if c != null and c.is_passive and &"passive_element" in c.effect_keys():
			n += 1
			ok(vus.has(c.id), "%s est proposable en campagne des l acte 2" % c.id)
	ok(n >= 2 * GameEnums.ELEMENTS.size(), "au moins deux passifs par element au catalogue")


## L objectif « N sorts de givre » a change d id (le givre est la glace) : une
## etoile deja gagnee sur un telephone suit le nouvel id (SaveData._migrate).
func _test_l_etoile_du_givre_suit_la_glace() -> void:
	var ids: Dictionary = {}
	for l: LevelDef in ContentDB.levels.values():
		for o in l.objectives:
			if o != null:
				ids[String(o.id)] = true
	for ancien: String in SaveData.RENAMED_OBJECTIVES:
		not_ok(ids.has(ancien), "%s n existe plus au contenu" % ancien)
		ok(ids.has(String(SaveData.RENAMED_OBJECTIVES[ancien])),
			"%s existe au contenu" % SaveData.RENAMED_OBJECTIVES[ancien])
		var vieux: Dictionary = {"schema_version": SaveData.CURRENT_VERSION,
			"profile": {"levels": {"lvl_x": {"objectives": {ancien: true}}}}, "settings": {}}
		var neuf: Dictionary = SaveData._migrate(vieux)
		ok(bool(neuf["profile"]["levels"]["lvl_x"]["objectives"].get(
			SaveData.RENAMED_OBJECTIVES[ancien], false)), "l etoile de %s est gardee" % ancien)
