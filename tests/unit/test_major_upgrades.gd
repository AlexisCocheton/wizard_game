extends TestCase
## AMELIORATIONS MAJEURES (vague 10, chantier A1) : le format (MajorUpgradeDef),
## l offre (jamais a la 1re maturation, au plus une parmi trois, une par sort et
## par partie), la STRUCTURE qu elles changent (seconde ligne, vague de plus,
## zone qui respire et residu, mur que les volants ne passent plus, objet
## incassable, incantation quasi instantanee, carte de la main qui murit),
## leurs prix, l ecran, le grimoire et le bot du banc.
##
## Les majeures d EXEMPLE vivent ici, pas dans le contenu : elles prouvent le
## moteur. Le contenu (deux par carte) vient du chantier B1, et
## _test_le_contenu_livre_est_valide le verifiera des qu il arrivera.

func get_suite_name() -> String:
	return "major_upgrades"


func run() -> void:
	_test_les_exemples_sont_valides()
	_test_les_defauts_sont_detectes()
	_test_le_contenu_livre_est_valide()
	_test_jamais_a_la_premiere_maturation()
	_test_une_majeure_au_plus_des_la_deuxieme()
	_test_une_seule_majeure_par_partie()
	_test_le_parcours_joue_des_maturations()
	_test_la_seconde_volee_double_la_ligne()
	_test_la_vague_supplementaire_rejoue_le_sort()
	_test_la_mare_respire_et_laisse_un_residu()
	_test_le_rempart_arrete_les_volants()
	_test_le_tir_reflexe_est_quasi_instantane()
	_test_les_ronces_de_fer_sont_incassables()
	_test_la_concentration_majeure_ajoute_un_choix()
	_test_l_orage_en_chaine_transmet_deux_marques()
	_test_les_prix_ont_un_plancher()
	_test_la_majeure_ne_touche_pas_la_ressource()
	_test_le_grimoire_et_le_cumul_disent_la_majeure()
	_test_reset_efface_la_majeure()
	_test_l_ecran_montre_la_majeure_et_ses_prix()
	_test_le_bot_et_les_majeures()
	_test_la_partie_headless_prend_et_joue_la_majeure()
	RunState.reset()


# --- Les sorts et les majeures d exemple -------------------------------------

func _spec(key: StringName, magnitude: float, duration: float, radius: float,
		params: Dictionary = {}) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = key
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	return s


func _sort(id: String, el: int, cible: int, specs: Array, cast: float = 1.5) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = cast
	c.element = el
	c.targeting = cible
	for s in specs:
		c.effects.append(s)
	return c


## Fleche percante : deux majeures d exemple.
func _fleche() -> SpellCard:
	var c: SpellCard = _sort("t_maj_fleche", GameEnums.DamageTag.WIND, GameEnums.Targeting.DIRECTION,
		[_spec(&"pierce_line", 10.0, 0.0, 60.0, {&"max_targets": 5})])
	c.major_upgrades = [SECONDE_VOLEE(), VAGUE_SUPPLEMENTAIRE()]
	return c


static func SECONDE_VOLEE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"seconde_volee", "Seconde volee",
		"Une seconde ligne de fleches part a 25 degres",
		[{"op": "duplicate", "key": &"pierce_line", "params": {&"angle_deg": 25.0}}],
		[{"op": "axis", "axis": &"damage", "pct": -0.5}])


static func VAGUE_SUPPLEMENTAIRE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"vague_supplementaire", "Vague supplementaire",
		"La volee repart 1,5 s plus tard, au meme endroit",
		[{"op": "repeat", "delay": 1.5}],
		[{"op": "axis", "axis": &"cast", "pct": -0.5}])


static func TIR_REFLEXE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"tir_reflexe", "Tir reflexe",
		"Incantation quasi instantanee",
		[{"op": "cast_time", "factor": 0.15}],
		[{"op": "axis", "axis": &"damage", "pct": -0.5}])


## Zone de poison : elle respire et laisse un residu.
func _mare() -> SpellCard:
	var c: SpellCard = _sort("t_maj_mare", GameEnums.DamageTag.POISON, GameEnums.Targeting.POSITION,
		[_spec(&"ground_zone", 6.0, 6.0, 120.0)])
	c.major_upgrades = [MARE_QUI_RESPIRE()]
	return c


static func MARE_QUI_RESPIRE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"mare_qui_respire", "Mare qui respire",
		"La mare grandit jusqu a x1,6 puis se retracte ; qui en sort garde le poison 3 s",
		[{"op": "set", "key": &"ground_zone", "param": &"grow_start", "value": 0.6},
		 {"op": "set", "key": &"ground_zone", "param": &"grow_peak", "value": 1.6},
		 {"op": "set", "key": &"ground_zone", "param": &"residue_dps", "value": 3.0},
		 {"op": "set", "key": &"ground_zone", "param": &"residue_duration", "value": 3.0}],
		[{"op": "axis", "axis": &"duration", "pct": -0.3}])


## Mur : il devient geant et arrete aussi les volants.
func _mur() -> SpellCard:
	var c: SpellCard = _sort("t_maj_mur", GameEnums.DamageTag.NATURE, GameEnums.Targeting.POSITION,
		[_spec(&"build_wall", 0.0, 10.0, 120.0, {&"thickness": 60.0})])
	c.major_upgrades = [REMPART_DES_CIEUX()]
	return c


static func REMPART_DES_CIEUX() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"rempart_des_cieux", "Rempart des cieux",
		"Mur deux fois plus large, que les volants ne franchissent plus",
		[{"op": "scale", "key": &"build_wall", "field": "radius", "factor": 2.0},
		 {"op": "set", "key": &"build_wall", "param": &"blocks_flyers", "value": true}],
		[{"op": "axis", "axis": &"cast", "pct": -0.5}])


## Ronces : objet INCASSABLE mais limite dans le temps, plus un effet.
func _ronces() -> SpellCard:
	var c: SpellCard = _sort("t_maj_ronces", GameEnums.DamageTag.NATURE, GameEnums.Targeting.POSITION,
		[_spec(&"place_terrain", 2.0, 0.0, 100.0,
			{&"kind": "bramble", &"prop_hp": 50.0, &"slow_pct": 35.0})])
	c.major_upgrades = [RONCES_DE_FER()]
	return c


static func RONCES_DE_FER() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"ronces_de_fer", "Ronces de fer",
		"Les ronces ne se brisent plus et durent 12 s, entourees d une zone qui ralentit",
		[{"op": "set", "key": &"place_terrain", "param": &"unbreakable", "value": true},
		 {"op": "set", "key": &"place_terrain", "field": "duration", "value": 12.0},
		 {"op": "add_effect", "key": &"ground_zone", "magnitude": 0.0, "duration": 12.0,
			"radius": 160.0, "params": {"slow_pct": 40.0}}],
		[{"op": "axis", "axis": &"cast", "pct": -0.5}])


## Carte d XP : la majeure fait murir une carte de la main au choix.
func _concentration() -> SpellCard:
	var c: SpellCard = _sort("t_maj_concentration", GameEnums.DamageTag.ARCANE,
		GameEnums.Targeting.NONE, [_spec(&"hand_card_xp", 1.0, 0.0, 0.0)])
	c.major_upgrades = [MAITRISE()]
	return c


static func MAITRISE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"maitrise", "Maitrise",
		"Monte d un niveau une carte de ta main, au choix",
		[{"op": "add_effect", "key": &"hand_card_level", "params": {&"count": 1}}],
		[{"op": "axis", "axis": &"cast", "pct": -0.5}])


## Marque electrique : chaque mort transmet DEUX marques.
func _marque() -> SpellCard:
	var c: SpellCard = _sort("t_maj_marque", GameEnums.DamageTag.LIGHTNING, GameEnums.Targeting.TARGET,
		[_spec(&"electric_mark", 6.0, 0.0, 0.0, {&"jump_range": 400.0})])
	c.major_upgrades = [ORAGE_EN_CHAINE()]
	return c


static func ORAGE_EN_CHAINE() -> MajorUpgradeDef:
	return MajorUpgradeDef.make(&"orage_en_chaine", "Orage en chaine",
		"A chaque mort, la marque saute sur DEUX monstres",
		[{"op": "set", "key": &"electric_mark", "param": &"marks_per_death", "value": 2}],
		[{"op": "axis", "axis": &"cast", "pct": -0.3}])


func _exemples() -> Array:
	return [[_fleche(), SECONDE_VOLEE()], [_fleche(), VAGUE_SUPPLEMENTAIRE()],
		[_fleche(), TIR_REFLEXE()], [_mare(), MARE_QUI_RESPIRE()],
		[_mur(), REMPART_DES_CIEUX()], [_ronces(), RONCES_DE_FER()],
		[_concentration(), MAITRISE()], [_marque(), ORAGE_EN_CHAINE()]]


func _prendre(c: SpellCard, ids: Array) -> void:
	var l: Array = []
	for id in ids:
		l.append(StringName(id))
	RunState.upgrades_taken[c.id] = l


func _a_une_majeure(offre: Array) -> int:
	var n: int = 0
	for v in offre:
		if bool((v as Dictionary).get("major", false)):
			n += 1
	return n


func _field() -> Battlefield:
	reset_gauge_at_normal_speed()
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _avancer(bf: Battlefield, secondes: float) -> void:
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	while t < secondes - 0.0000001:
		bf.simulate(dt)
		t += SpeedGauge.world_delta(dt)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)


func _def(id: String, vitesse: float = 0.0, pv: float = 100000.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = pv
	d.base_speed = vitesse
	d.base_radius = 30.0
	d.base_xp = 1
	return d


func _lancer(bf: Battlefield, c: SpellCard, ou: Vector2, dir: Vector2 = Vector2.UP,
		cible: Enemy = null) -> void:
	var ctx := CastContext.make(bf, c)
	ctx.target_position = ou
	ctx.direction = dir
	ctx.target_enemy = cible
	EffectRegistry.cast(c, ctx)


# --- FORMAT ----------------------------------------------------------------

func _test_les_exemples_sont_valides() -> void:
	for paire in _exemples():
		var c: SpellCard = paire[0]
		var m: MajorUpgradeDef = paire[1]
		var defauts: Array[String] = m.validation_errors(c)
		eq(defauts.size(), 0, "la majeure d exemple %s est valide %s" % [m.id, defauts])


## Chaque defaut du langage est vu : sinon le contenu de la phase B passerait
## une faute de frappe sans un mot.
func _test_les_defauts_sont_detectes() -> void:
	var c: SpellCard = _fleche()
	var prix: Array = [{"op": "axis", "axis": &"damage", "pct": -0.5}]
	var cas: Dictionary = {
		"op inconnue": MajorUpgradeDef.make(&"x", "X", "x", [{"op": "teleporte"}], prix),
		"cle sans handler": MajorUpgradeDef.make(&"x", "X", "x",
			[{"op": "add_effect", "key": &"cle_qui_n_existe_pas"}], prix),
		"sans prix": MajorUpgradeDef.make(&"x", "X", "x",
			[{"op": "repeat", "delay": 1.0}], []),
		"axe inconnu": MajorUpgradeDef.make(&"x", "X", "x",
			[{"op": "repeat", "delay": 1.0}], [{"op": "axis", "axis": &"bonheur", "pct": -0.5}]),
		"cle absente du sort": MajorUpgradeDef.make(&"x", "X", "x",
			[{"op": "set", "key": &"build_wall", "param": &"blocks_flyers", "value": true}], prix),
		"facteur nul": MajorUpgradeDef.make(&"x", "X", "x",
			[{"op": "scale", "key": &"pierce_line", "field": "radius", "factor": 0.0}], prix),
		"delai nul": MajorUpgradeDef.make(&"x", "X", "x", [{"op": "repeat", "delay": 0.0}], prix),
		"sans titre": MajorUpgradeDef.make(&"x", "", "x", [{"op": "repeat", "delay": 1.0}], prix),
	}
	for nom in cas:
		ok(not (cas[nom] as MajorUpgradeDef).validation_errors(c).is_empty(),
			"le defaut « %s » est detecte" % nom)


## Le contenu LIVRE : chaque majeure de chaque carte est valide, et ses ids sont
## uniques dans la carte (c est l id que la partie retient).
func _test_le_contenu_livre_est_valide() -> void:
	var defauts: Array[String] = []
	for c: SpellCard in ContentDB.cards.values():
		var vus: Dictionary = {}
		for m in c.major_upgrades:
			if m == null:
				defauts.append("%s : majeure vide" % c.id)
				continue
			if vus.has(m.id):
				defauts.append("%s : id de majeure en double %s" % [c.id, m.id])
			vus[m.id] = true
			defauts.append_array(m.validation_errors(c))
	eq(defauts.size(), 0, "les majeures du contenu sont valides %s" % [defauts.slice(0, 6)])


# --- OFFRE -----------------------------------------------------------------

func _test_jamais_a_la_premiere_maturation() -> void:
	var c: SpellCard = _fleche()
	var sans: SpellCard = _fleche()
	sans.major_upgrades = []
	for graine in 30:
		RunState.reset()
		RunState.set_seed(7000 + graine)
		var offre: Array = RunState.draw_upgrade_offer(c)
		eq(_a_une_majeure(offre), 0, "graine %d : aucune majeure a la premiere maturation" % graine)
		eq(offre.size(), GameConfig.LEVEL_UP_CHOICES, "trois propositions")
		# Et le tirage est EXACTEMENT celui d un sort sans majeure : declarer des
		# majeures ne change pas la premiere maturation (ni le RNG).
		RunState.reset()
		RunState.set_seed(7000 + graine)
		var temoin: Array = RunState.draw_upgrade_offer(sans)
		var a: Array = offre.map(func(v: Dictionary) -> StringName: return StringName(v["id"]))
		var b: Array = temoin.map(func(v: Dictionary) -> StringName: return StringName(v["id"]))
		eq(a, b, "graine %d : meme offre qu un sort sans majeure" % graine)
	RunState.reset()


func _test_une_majeure_au_plus_des_la_deuxieme() -> void:
	var c: SpellCard = _fleche()
	var vues: Dictionary = {}
	for graine in 40:
		RunState.reset()
		RunState.set_seed(7100 + graine)
		_prendre(c, [&"damage_light"])
		var offre: Array = RunState.draw_upgrade_offer(c)
		eq(offre.size(), GameConfig.LEVEL_UP_CHOICES, "graine %d : toujours trois propositions" % graine)
		eq(_a_une_majeure(offre), 1, "graine %d : exactement une majeure" % graine)
		var ids: Dictionary = {}
		var legere: bool = false
		for v in offre:
			ids[v["id"]] = true
			if StringName(v["form"]) == RunState.UP_LIGHT:
				legere = true
			if bool(v.get("major", false)):
				vues[v["major_id"]] = true
		eq(ids.size(), offre.size(), "graine %d : trois propositions distinctes" % graine)
		ok(legere, "graine %d : la voie legere sure reste a l ecran" % graine)
	eq(vues.size(), 2, "les deux majeures du sort sortent selon le tirage %s" % [vues.keys()])
	RunState.reset()


func _test_une_seule_majeure_par_partie() -> void:
	var c: SpellCard = _fleche()
	RunState.reset()
	var paliers: int = RunState.upgrade_tiers_for(c)
	_prendre(c, [&"damage_light", RunState.major_id_of(VAGUE_SUPPLEMENTAIRE())])
	eq(RunState.upgrade_tiers_for(c), paliers, "une majeure ne change pas le nombre de maturations")
	for graine in 20:
		RunState.set_seed(7200 + graine)
		var offre: Array = RunState.draw_upgrade_offer(c)
		eq(_a_une_majeure(offre), 0, "graine %d : une majeure deja prise, plus aucune" % graine)
		eq(offre.size(), GameConfig.LEVEL_UP_CHOICES, "et toujours trois propositions")
	RunState.reset()


## Le parcours JOUE : l XP fait murir, l ecran s ouvre, on prend la majeure des
## qu elle est la ; le sort fait toutes ses maturations, toujours a trois voies.
func _test_le_parcours_joue_des_maturations() -> void:
	var c: SpellCard = _fleche()
	RunState.reset()
	RunState.set_seed(7300)
	var paliers: int = RunState.upgrade_tiers_for(c)
	var vu_majeure_a: int = -1
	for k in paliers:
		RunState.grant_card_xp(c, maxi(1, RunState.next_upgrade_at(c) - RunState.card_xp(c)))
		if RunState.pending_upgrade_card != c:
			ok(false, "maturation %d : l ecran s ouvre" % (k + 1))
			break
		var voies: Array = RunState.pending_upgrade_paths
		eq(voies.size(), GameConfig.LEVEL_UP_CHOICES, "maturation %d : trois voies" % (k + 1))
		var choix: int = 0
		for i in voies.size():
			if bool(voies[i].get("major", false)):
				choix = i
				if vu_majeure_a < 0:
					vu_majeure_a = k + 1
		RunState.pick_upgrade(choix)
	eq(vu_majeure_a, GameConfig.MAJOR_UPGRADE_FROM_TIER, "la premiere majeure arrive au palier prevu")
	eq(RunState.maturations_done(c), paliers, "toutes les maturations ont eu lieu")
	eq(RunState.taken_majors(c).size(), GameConfig.MAJOR_UPGRADES_PER_CARD,
		"une seule majeure prise sur toute la partie")
	RunState.reset()


# --- STRUCTURE -------------------------------------------------------------

func _test_la_seconde_volee_double_la_ligne() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var base: float = c.effects[0].magnitude
	_prendre(c, [RunState.major_id_of(SECONDE_VOLEE())])
	var specs: Array[EffectSpec] = RunState.cast_specs(c)
	eq(specs.size(), 2, "deux lignes de fleches")
	if specs.size() == 2:
		feq(float(specs[1].get_param(&"angle_deg", 0.0)), 25.0, "la seconde part a 25 degres")
		feq(specs[0].magnitude, base * 0.5, "le prix touche la premiere ligne")
		feq(specs[1].magnitude, base * 0.5, "et la seconde")
	# Sur le terrain : un monstre sur la ligne en biais n est touche QU avec la majeure.
	var bf := _field()
	var origine := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	var biais: Vector2 = origine + Vector2.UP.rotated(deg_to_rad(25.0)) * 700.0
	var e: Enemy = bf.spawn_enemy(_def("t_maj_biais"), biais.x, 1.0, biais)
	var droit: Enemy = bf.spawn_enemy(_def("t_maj_droit"), origine.x, 1.0, origine + Vector2.UP * 700.0)
	_lancer(bf, c, origine + Vector2.UP * 700.0)
	ok(e.hp < e.max_hp(), "la seconde ligne touche le monstre en biais")
	ok(droit.hp < droit.max_hp(), "la premiere touche toujours le monstre droit devant")
	RunState.reset()
	var pv: float = e.hp
	_lancer(bf, _fleche(), origine + Vector2.UP * 700.0)
	feq(e.hp, pv, "sans la majeure, la ligne en biais n existe pas")
	detach(bf)


func _test_la_vague_supplementaire_rejoue_le_sort() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var avant: float = RunState.effective_cast_time(c)
	_prendre(c, [RunState.major_id_of(VAGUE_SUPPLEMENTAIRE())])
	feq(RunState.effective_cast_time(c) / avant, 2.0, "le prix : -50 % de vitesse, deux fois plus long",
		0.001)
	var bf := _field()
	var ou := Vector2(540, 900)
	var e: Enemy = bf.spawn_enemy(_def("t_maj_cible"), ou.x, 1.0, ou)
	_lancer(bf, c, ou)
	var un_coup: float = e.max_hp() - e.hp
	ok(un_coup > 0.0, "la volee touche")
	eq(bf.w10_pending_recasts(), 1, "une vague supplementaire est programmee")
	eq(RunState.casts_of(c), 1, "un seul lancer compte")
	_avancer(bf, 1.0)
	feq(e.max_hp() - e.hp, un_coup, "(pas avant son delai)")
	_avancer(bf, 0.6)
	feq(e.max_hp() - e.hp, un_coup * 2.0, "la seconde vague frappe autant que la premiere")
	eq(bf.w10_recasts_done, 1, "une seule vague de plus")
	eq(RunState.casts_of(c), 1, "et ce n est toujours qu un lancer")
	detach(bf)
	RunState.reset()


func _test_la_mare_respire_et_laisse_un_residu() -> void:
	RunState.reset()
	var c: SpellCard = _mare()
	var r0: float = c.effects[0].radius
	var duree: float = c.effects[0].duration
	_prendre(c, [RunState.major_id_of(MARE_QUI_RESPIRE())])
	var bf := _field()
	var centre := Vector2(540, 800)
	var e: Enemy = bf.spawn_enemy(_def("t_maj_poisson"), centre.x, 1.0, centre)
	_lancer(bf, c, centre)
	eq(bf.zones.size(), 1, "une mare")
	var z: Dictionary = bf.zones[0]
	feq(float(z["time"]), duree * 0.7, "le prix : -30 % de duree", 0.001)
	feq(float(z["radius"]), r0 * 0.6, "elle nait a x0,6", 0.5)
	_avancer(bf, duree * 0.7 * 0.5)
	feq(float(z["radius"]), r0 * 1.6, "a mi-vie, elle culmine a x1,6", 2.0)
	# Le residu : qui sort garde le poison, et pas en double tant qu il est dedans.
	var dedans: float = e.max_hp() - e.hp
	feq(dedans, 6.0 * duree * 0.7 * 0.5, "dedans, seule la mare mord (pas de residu en plus)", 0.5)
	e.position = Vector2(540, 1350)
	var hors: float = e.hp
	_avancer(bf, 1.0)
	feq(hors - e.hp, 3.0, "sorti, il garde 3 degats par seconde", 0.2)
	_avancer(bf, 4.0)
	feq(hors - e.hp, 9.0, "pendant 3 s, puis plus rien", 0.3)
	detach(bf)
	RunState.reset()


func _test_le_rempart_arrete_les_volants() -> void:
	RunState.reset()
	var c: SpellCard = _mur()
	var ou := Vector2(540, 900)
	var bf0 := _field()
	var petit: int = EffectHandlers.wall_cells(RunState.cast_specs(c)[0], bf0, ou).size()
	_prendre(c, [RunState.major_id_of(REMPART_DES_CIEUX())])
	var specs: Array[EffectSpec] = RunState.cast_specs(c)
	feq(specs[0].radius, c.effects[0].radius * 2.0, "le mur est deux fois plus large")
	ok(EffectHandlers.wall_cells(specs[0], bf0, ou).size() > petit,
		"et la garantie de chemin juge le GRAND mur (visee = resolution)")
	detach(bf0)
	var resultats: Array[float] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, [RunState.major_id_of(REMPART_DES_CIEUX())])
		var bf := _field()
		var dv := _def("t_maj_volant", 60.0)
		dv.flying = true
		var v: Enemy = bf.spawn_enemy(dv, ou.x, 1.0, Vector2(ou.x, 700))
		_lancer(bf, c, ou)
		_avancer(bf, 8.0)
		resultats.append(v.position.y)
		detach(bf)
	ok(resultats[0] > ou.y, "sans la majeure, le volant passe au-dessus du mur (%.0f)" % resultats[0])
	ok(resultats[1] < ou.y, "avec, il reste bloque devant (%.0f)" % resultats[1])
	RunState.reset()


func _test_le_tir_reflexe_est_quasi_instantane() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	c.major_upgrades = [TIR_REFLEXE()]
	var avant: float = RunState.effective_cast_time(c)
	_prendre(c, [RunState.major_id_of(TIR_REFLEXE())])
	feq(RunState.effective_cast_time(c) / avant, 0.15, "incantation x0,15", 0.001)
	feq(RunState.cast_specs(c)[0].magnitude, c.effects[0].magnitude * 0.5, "contre -50 % de degats")
	RunState.reset()


func _test_les_ronces_de_fer_sont_incassables() -> void:
	RunState.reset()
	var c: SpellCard = _ronces()
	_prendre(c, [RunState.major_id_of(RONCES_DE_FER())])
	var bf := _field()
	_lancer(bf, c, Vector2(540, 800))
	eq(bf.props.size(), 1, "les ronces sont posees")
	if bf.props.size() == 1:
		var p: TerrainProp = bf.props[0]
		not_ok(p.is_breakable(), "elles n ont plus de PV a frapper")
		not_ok(p.is_permanent(), "elles ne restent plus tout le combat")
		feq(p.time_left, 12.0, "elles durent 12 s", 0.01)
		not_ok(bf.breaker_can_break(p.anchor), "le Briseur de terrain les epargne")
	eq(bf.zones.size(), 2, "l effet ajoute : une zone de plus autour d elles")
	_avancer(bf, 12.5)
	eq(bf.props.size(), 0, "a la fin de leur duree, elles disparaissent")
	detach(bf)
	RunState.reset()


func _test_la_concentration_majeure_ajoute_un_choix() -> void:
	RunState.reset()
	var c: SpellCard = _concentration()
	_prendre(c, [RunState.major_id_of(MAITRISE())])
	var cles: Array = RunState.cast_specs(c).map(func(s: EffectSpec) -> StringName: return s.key)
	eq(cles, [&"hand_card_xp", &"hand_card_level"], "la majeure AJOUTE l effet « monte une carte »")
	var autre: SpellCard = _mare()
	RunState.hand.append(autre)
	_lancer(null, c, Vector2.ZERO)
	eq(RunState.pending_hand_level, 1, "lancer la carte ouvre le choix")
	RunState.reset()


## MARQUES MULTIPLES : avec la majeure, la mort du porteur fait sauter la marque
## sur ses DEUX plus proches voisins ; sans elle, sur un seul.
func _test_l_orage_en_chaine_transmet_deux_marques() -> void:
	var touches: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		var c: SpellCard = _marque()
		if avec:
			_prendre(c, [RunState.major_id_of(ORAGE_EN_CHAINE())])
		var bf := _field()
		var porteur: Enemy = bf.spawn_enemy(_def("t_maj_m_porteur", 0.0, 1.0), 540.0, 1.0,
			Vector2(540, 700))
		var voisins: Array[Enemy] = []
		for i in 3:
			voisins.append(bf.spawn_enemy(_def("t_maj_m_voisin%d" % i), 640.0 + i * 60.0, 1.0,
				Vector2(640.0 + i * 60.0, 700)))
		_lancer(bf, c, porteur.position, Vector2.UP, porteur)
		_avancer(bf, GameConfig.MARK_JUMP_DELAY + 0.05)
		var n: int = 0
		for v in voisins:
			if not bf.w10_marks_on(v).is_empty():
				n += 1
		touches.append(n)
		detach(bf)
	eq(touches[0], 1, "sans la majeure : la marque saute sur UN voisin")
	eq(touches[1], 2, "avec : sur DEUX voisins")
	RunState.reset()


func _test_les_prix_ont_un_plancher() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var ids: Array = [RunState.major_id_of(SECONDE_VOLEE())]
	for id in [&"cast_strong", &"area_strong", &"count_strong"]:
		var v: Dictionary = RunState.upgrade_path_by_id(c, id)
		ok(not v.is_empty() and float((v["mods"] as Dictionary).get(RunState.UP_DAMAGE, 0.0)) < 0.0,
			"(%s se paie en degats)" % id)
		ids.append(id)
	_prendre(c, ids)
	var m: float = RunState.cast_specs(c)[0].magnitude
	ok(m > 0.0, "-50 %% puis trois -15 %% : les degats restent positifs (%.3f)" % m)
	RunState.reset()


func _test_la_majeure_ne_touche_pas_la_ressource() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var spec: EffectSpec = c.effects[0]
	var base: float = spec.magnitude
	_prendre(c, [RunState.major_id_of(SECONDE_VOLEE())])
	RunState.cast_specs(c)
	eq(c.effects.size(), 1, "le .tres garde UN effet")
	feq(spec.magnitude, base, "et ses degats")
	not_ok(spec.params.has(&"angle_deg"), "et ses params")
	RunState.reset()


func _test_le_grimoire_et_le_cumul_disent_la_majeure() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var lignes: Array = RunState.upgrade_lines_for(c)
	eq(lignes.size(), RunState.upgrade_pool_for(c).size() + c.major_upgrades.size(),
		"la fiche montre les voies PUIS les majeures")
	var majeures: Array = lignes.filter(func(l: Dictionary) -> bool:
		return StringName(l["form"]) == RunState.UP_MAJOR)
	eq(majeures.size(), 2, "deux lignes de majeure")
	for l in majeures:
		ok(String(l["text"]).contains("MAJEURE") and String(l["text"]).contains("+"),
			"la ligne dit MAJEURE et porte son gain signe (%s)" % l["text"])
		ok(String(l["text"]).contains("-"), "et son prix (%s)" % l["text"])
	_prendre(c, [RunState.major_id_of(VAGUE_SUPPLEMENTAIRE())])
	var acquises: int = 0
	for l in RunState.upgrade_lines_for(c):
		if bool(l["unlocked"]):
			acquises += 1
			ok(String(l["text"]).contains("Vague supplementaire"), "la majeure prise est marquee")
	eq(acquises, 1, "une seule ligne acquise")
	var cumul: Array[String] = RunState.upgrade_cumul_lines(c)
	ok(cumul.has("MAJEURE Vague supplementaire"), "le cumul nomme la majeure %s" % [cumul])
	ok(cumul.has("-50 % vitesse de lancement"), "et compte son prix chiffre %s" % [cumul])
	ok(DeckBrowser.maturation_text(c).contains("Vague supplementaire"),
		"la fiche de deck la nomme aussi")
	RunState.reset()


func _test_reset_efface_la_majeure() -> void:
	var c: SpellCard = _fleche()
	_prendre(c, [RunState.major_id_of(VAGUE_SUPPLEMENTAIRE())])
	eq(RunState.taken_majors(c).size(), 1, "(prise)")
	RunState.reset()
	eq(RunState.taken_majors(c).size(), 0, "la majeure ne survit pas a la partie")
	eq(RunState.major_repeats(c).size(), 0, "ni son rejeu")


# --- ECRAN -----------------------------------------------------------------

func _test_l_ecran_montre_la_majeure_et_ses_prix() -> void:
	RunState.reset()
	RunState.set_seed(7400)
	var c: SpellCard = _fleche()
	c.major_upgrades = [MajorUpgradeDef.make(&"deux_prix", "Deux prix", "Une seconde ligne",
		[{"op": "duplicate", "key": &"pierce_line", "params": {&"angle_deg": 20.0}}],
		[{"op": "axis", "axis": &"damage", "pct": -0.3}, {"op": "axis", "axis": &"cast", "pct": -0.2}])]
	_prendre(c, [&"damage_light"])
	var voies: Array = RunState.draw_upgrade_offer(c)
	var k: int = -1
	for i in voies.size():
		if bool(voies[i].get("major", false)):
			k = i
	ok(k >= 0, "l offre porte la majeure")
	var hote := Control.new()
	hote.size = Vector2(GameConfig.BATTLEFIELD_WIDTH, GameConfig.BATTLEFIELD_HEIGHT)
	attach(hote)
	var panneau := CardUpgradePanel.new()
	hote.add_child(panneau)
	panneau.show_paths(c, voies)
	var b: Button = panneau.find_child("Voie%d" % k, true, false) as Button
	ok(b != null, "la majeure a son bouton")
	if b != null:
		var forme: Label = b.find_child("Forme", true, false) as Label
		var gain: Label = b.find_child("Gain", true, false) as Label
		var prix1: Label = b.find_child("Prix", true, false) as Label
		var prix2: Label = b.find_child("Prix2", true, false) as Label
		ok(forme != null and forme.text == "MAJEURE", "le mot MAJEURE est ecrit")
		ok(gain != null and gain.text.begins_with("+"), "le gain porte son +")
		ok(prix1 != null and prix2 != null, "chaque prix a sa ligne")
		for l in [prix1, prix2]:
			if l == null:
				continue
			ok((l as Label).text.begins_with("-"), "le prix porte son - (%s)" % (l as Label).text)
			var cp: Color = (l as Label).get_theme_color(&"font_color")
			ok(cp.r > cp.g and cp.r > cp.b, "le prix est ROUGE")
		ok(b.custom_minimum_size.y >= CardUpgradePanel.MIN_TOUCH, "cible tactile")
		var cadre: StyleBoxFlat = b.get_theme_stylebox(&"normal") as StyleBoxFlat
		ok(cadre != null and cadre.border_color != UiTheme.GOLD and cadre.border_color != UiTheme.TEAL,
			"son cadre n est ni celui d une forte ni celui d une legere")
	var annonce: bool = false
	for n in panneau.find_children("*", "Label", true, false):
		if (n as Label).text.contains("MAJEURE est proposee"):
			annonce = true
	ok(annonce, "l entete annonce la majeure")
	ok(panneau.size.y >= hote.size.y * 0.99, "le panneau couvre l ecran")
	detach(hote)
	RunState.reset()


# --- BOT -------------------------------------------------------------------

func _test_le_bot_et_les_majeures() -> void:
	RunState.reset()
	var c: SpellCard = _fleche()
	var vague: Dictionary = RunState.major_path(c, VAGUE_SUPPLEMENTAIRE())
	var seconde: Dictionary = RunState.major_path(c, SECONDE_VOLEE())
	ok(AutoPick.major_acceptable(c, vague), "payer la VITESSE pour une vague de plus : oui")
	not_ok(AutoPick.major_acceptable(c, seconde), "payer la moitie des DEGATS d un sort de degats : non")
	var forte: Dictionary = RunState.upgrade_path_by_id(c, &"damage_strong")
	var legere: Dictionary = RunState.upgrade_path_by_id(c, &"area_light")
	var offre: Array = [forte, vague, legere]
	eq(AutoPick.upgrade_index(c, offre), 1, "la majeure acceptable passe avant l identite forte")
	var inverse: Array = offre.duplicate()
	inverse.reverse()
	eq(AutoPick.upgrade_index(c, inverse), 1, "quel que soit l ordre")
	var refus: Array = [seconde, legere, RunState.upgrade_path_by_id(c, &"count_light")]
	var k: int = AutoPick.upgrade_index(c, refus)
	not_ok(bool(refus[k].get("major", false)),
		"une majeure refusee n est jamais prise, meme en dernier recours")
	RunState.reset()


## LE CHEMIN COMPLET dans une vraie partie headless : une carte du catalogue
## recoit une majeure le temps du test ; le bot la prend a sa 2e maturation, le
## lancer programme la vague supplementaire et elle part.
func _test_la_partie_headless_prend_et_joue_la_majeure() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	var carte: SpellCard = ContentDB.cards.get(&"piercing_arrow")
	if level == null or carte == null:
		ok(false, "lvl_01 et piercing_arrow existent")
		return
	var garde: Array[MajorUpgradeDef] = carte.major_upgrades.duplicate()
	carte.major_upgrades = [VAGUE_SUPPLEMENTAIRE()]
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.running = false
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	for k in GameConfig.MAJOR_UPGRADE_FROM_TIER:
		RunState.grant_card_xp(carte, maxi(1, RunState.next_upgrade_at(carte) - RunState.card_xp(carte)))
	ok(RunState.upgrade_ids_of(carte).has(RunState.major_id_of(VAGUE_SUPPLEMENTAIRE())),
		"le bot a pris la majeure a sa maturation %d (%s)"
			% [GameConfig.MAJOR_UPGRADE_FROM_TIER, RunState.upgrade_ids_of(carte)])
	var ctx := CastContext.make(g.battlefield, carte)
	ctx.caster = g
	ctx.direction = Vector2.UP
	ctx.target_position = Vector2(540, 700)
	EffectRegistry.cast(carte, ctx)
	eq(g.battlefield.w10_pending_recasts(), 1, "le lancer programme sa vague supplementaire")
	for i in 120:
		g.battlefield.simulate(1.0 / 60.0)
		SpeedGauge.set_speed_percent(maxi(SpeedGauge.speed_percent, 100))
	eq(g.battlefield.w10_recasts_done, 1, "et elle part")
	detach(g)
	carte.major_upgrades = garde
	RunState.reset()
