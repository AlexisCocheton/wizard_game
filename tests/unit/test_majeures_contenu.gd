extends TestCase
## MAJEURES DU CONTENU (vague 10, chantier B1b) : deux ameliorations « enormes »
## par sort, ecrites par tools/make_content.gd (_majeures). Le MOTEUR est
## verrouille par test_major_upgrades (chantier A1) ; ici, ce que le contenu
## LIVRE promet au joueur :
##   - chaque sort du catalogue a exactement deux majeures, valides, d ids et
##     de structures differentes ;
##   - chacune change la STRUCTURE du sort (pas un simple « +X % ») ;
##   - chacun de ses PRIX mord vraiment sur ce sort (un prix affiche en rouge
##     et jamais paye serait un mensonge) ;
##   - les textes tiennent sur l ecran de maturation en portrait ;
##   - jamais offertes avant la deuxieme maturation, et chaque sort en a une ;
##   - le bot du banc sait les juger ;
##   - et, sur le terrain, les majeures cles font ce qu elles disent : la
##     seconde ligne touche une autre colonne, la muraille geante arrete les
##     volants, la marque transmise se multiplie, la Maitrise fait murir A LA
##     PLACE de l XP, le barrage frappe toute la largeur...

## A PASSER A true A LA FUSION DU CHANTIER B1a (cartes neuves de la vague 10).
## L orchestrateur previent B1b, qui finalise : tant que c est faux, les cinq
## cartes attendues de B1a peuvent manquer au catalogue ; vrai, elles sont
## EXIGEES, avec leurs deux majeures.
const B1A_FUSIONNE: bool = false
const ATTENDUES_B1A: Array[StringName] = [&"south_wind", &"electric_mark", &"heavy_rain",
	&"quicksand", &"water_jet"]

## Bornes de LISIBILITE de l ecran de maturation (CardUpgradePanel, bouton de
## majeure : titre en FONT_BUTTON sur une ligne, a cote du mot MAJEURE ; gain et
## prix en FONT_BODY, ~50 signes par ligne dans 1080 px moins les marges).
const TITRE_MAX: int = 20
const TEXTE_MAX: int = 90
const PRIX_MAX: int = 40

## Les ops qui changent la STRUCTURE d un sort. « scale » et « axis » ne font
## que pousser un chiffre : seuls, ils seraient une voie ordinaire.
const OPS_DE_STRUCTURE: Array[StringName] = [&"add_effect", &"set", &"duplicate",
	&"repeat", &"cast_time"]


func get_suite_name() -> String:
	return "majeures_contenu"


func run() -> void:
	_test_la_table_couvre_le_catalogue()
	_test_les_cartes_de_b1a()
	_test_deux_majeures_valides_et_differentes()
	_test_chaque_majeure_change_la_structure()
	_test_chaque_prix_mord()
	_test_les_textes_se_lisent_en_portrait()
	_test_offertes_a_partir_de_la_deuxieme_maturation()
	_test_le_bot_sait_les_juger()
	_test_la_seconde_ligne_touche_une_autre_colonne()
	_test_la_muraille_geante_arrete_les_volants()
	_test_l_arc_electrique_transmet_la_marque()
	_test_l_orage_en_chaine_double_la_marque()
	_test_la_maitrise_fait_murir_a_la_place()
	_test_le_barrage_frappe_toute_la_largeur()
	_test_le_venin_tenace_reste_apres_la_mare()
	_test_les_ronces_de_fer_sont_incassables_et_breves()
	_test_le_siphon_engloutit_le_centre()
	_test_le_pacte_inverse_ralentit()
	_test_le_meteore_eclair_est_quasi_instantane()
	_test_la_forteresse_arrete_tout_et_tombe()
	_test_la_faille_s_ouvre_en_croix()
	RunState.reset()


# --- Outils ------------------------------------------------------------------

func _sorts() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive:
			out.append(c)
	out.sort_custom(func(a: SpellCard, b: SpellCard) -> bool: return String(a.id) < String(b.id))
	return out


func _carte(id: String) -> SpellCard:
	return ContentDB.cards.get(StringName(id)) as SpellCard


func _majeure(c: SpellCard, id: String) -> MajorUpgradeDef:
	return c.major_upgrade(StringName(id)) if c != null else null


func _prendre(c: SpellCard, m: MajorUpgradeDef) -> void:
	RunState.upgrades_taken[c.id] = [RunState.major_id_of(m)]


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


## Tout ce qu un lancer de `c` ferait, tel que la partie le lit : incantation
## reelle, prix en cartes, et chaque effet (champs et params). Deux empreintes
## differentes = deux sorts differents.
func _empreinte(c: SpellCard) -> String:
	var morceaux: Array[String] = []
	morceaux.append("cast=%.4f" % RunState.effective_cast_time(c))
	var mods: Dictionary = RunState._summed_mods(RunState.taken_paths(c))
	morceaux.append("discard=%.2f" % float(mods.get(RunState.UP_DISCARD, 0.0)))
	for s in RunState.cast_specs(c):
		var cles: Array = s.params.keys().map(func(k: Variant) -> String: return str(k))
		cles.sort()
		var p: Array[String] = []
		for k in cles:
			p.append("%s=%s" % [k, str(s.params.get(StringName(k), s.params.get(k)))])
		morceaux.append("%s m%.4f d%.4f r%.4f {%s}" % [s.key, s.magnitude, s.duration,
			s.radius, ",".join(p)])
	return " | ".join(morceaux)


func _ascii(t: String) -> bool:
	for i in t.length():
		if t.unicode_at(i) > 126:
			return false
	return true


# --- La table et le catalogue -------------------------------------------------

## La table de make_content couvre TOUT sort du catalogue, et ne nomme que des
## sorts qui existent (sauf ceux qu on attend de B1a).
func _test_la_table_couvre_le_catalogue() -> void:
	var script: GDScript = load("res://tools/make_content.gd") as GDScript
	ok(script != null, "tools/make_content.gd se charge")
	if script == null:
		return
	var consts: Dictionary = script.get_script_constant_map()
	var table: Array = consts.get("MAJEURES_SORTS", []) as Array
	ok(not table.is_empty(), "la table des majeures existe")
	var dans_la_table: Dictionary = {}
	for id in table:
		dans_la_table[StringName(str(id))] = true
	eq(dans_la_table.size(), table.size(), "aucun sort en double dans la table")
	var oublies: Array = []
	for c in _sorts():
		if not dans_la_table.has(c.id):
			oublies.append(c.id)
	eq(oublies.size(), 0, "tout sort du catalogue est dans la table %s" % [oublies])
	var fantomes: Array = []
	for id in dans_la_table:
		if ContentDB.cards.has(id):
			continue
		if ATTENDUES_B1A.has(id) and not B1A_FUSIONNE:
			continue
		fantomes.append(id)
	eq(fantomes.size(), 0, "la table ne nomme que des sorts du catalogue %s" % [fantomes])
	var attendues: Array = consts.get("MAJEURES_ATTENDUES_B1A", []) as Array
	for id in ATTENDUES_B1A:
		ok(attendues.has(String(id)) and dans_la_table.has(id),
			"%s, attendue de B1a, a son entree dans la table" % id)


## LES CARTES DE B1a : exigees des que B1A_FUSIONNE passe a vrai. Avant, une
## carte deja la est verifiee comme les autres (par les tests suivants), une
## carte absente est seulement signalee.
func _test_les_cartes_de_b1a() -> void:
	for id in ATTENDUES_B1A:
		var c: SpellCard = ContentDB.cards.get(id) as SpellCard
		if B1A_FUSIONNE:
			ok(c != null, "B1a fusionne : %s est au catalogue" % id)
			if c != null:
				eq(c.major_upgrades.size(), 2, "et porte ses deux majeures (%s)" % id)
		elif c == null:
			ok(true, "(%s attendue de B1a, absente avant sa fusion)" % id)


func _test_deux_majeures_valides_et_differentes() -> void:
	var defauts: Array[String] = []
	for c in _sorts():
		if c.major_upgrades.size() != 2:
			defauts.append("%s : %d majeures" % [c.id, c.major_upgrades.size()])
			continue
		var a: MajorUpgradeDef = c.major_upgrades[0]
		var b: MajorUpgradeDef = c.major_upgrades[1]
		if a == null or b == null:
			defauts.append("%s : majeure vide" % c.id)
			continue
		if a.id == b.id:
			defauts.append("%s : deux fois l id %s" % [c.id, a.id])
		if a.title == b.title:
			defauts.append("%s : deux fois le titre %s" % [c.id, a.title])
		if _signature(a) == _signature(b):
			defauts.append("%s : deux fois la meme structure (%s)" % [c.id, _signature(a)])
		for m in [a, b]:
			defauts.append_array((m as MajorUpgradeDef).validation_errors(c))
	eq(defauts.size(), 0, "deux majeures valides et differentes par sort %s" % [defauts.slice(0, 6)])


## Ce que la majeure CHANGE, sans ses chiffres : ops, cles et params vises.
func _signature(m: MajorUpgradeDef) -> String:
	var morceaux: Array[String] = []
	for op in m.modifiers:
		var spec: Variant = MajorUpgradeDef.field(op, "spec", null)
		var cle: String = str((spec as EffectSpec).key) if spec is EffectSpec \
			else str(MajorUpgradeDef.field(op, "key", ""))
		morceaux.append("%s:%s:%s%s" % [MajorUpgradeDef.op_of(op), cle,
			str(MajorUpgradeDef.field(op, "param", "")), str(MajorUpgradeDef.field(op, "field", ""))])
	morceaux.sort()
	return ",".join(morceaux)


func _test_chaque_majeure_change_la_structure() -> void:
	var simples: Array[String] = []
	var prix_faux: Array[String] = []
	for c in _sorts():
		for m in c.major_upgrades:
			if m == null:
				continue
			var structure: bool = false
			for op in m.modifiers:
				if OPS_DE_STRUCTURE.has(MajorUpgradeDef.op_of(op)):
					structure = true
			if not structure:
				simples.append("%s/%s" % [c.id, m.id])
			for op in m.prices:
				var est_axe: bool = MajorUpgradeDef.op_of(op) == MajorUpgradeDef.OP_AXIS
				if not est_axe or float(MajorUpgradeDef.field(op, "pct", 0.0)) >= 0.0:
					prix_faux.append("%s/%s" % [c.id, m.id])
	eq(simples.size(), 0, "chaque majeure change la structure du sort %s" % [simples])
	eq(prix_faux.size(), 0, "chaque prix est un axe NEGATIF (texte rouge, lu par le bot) %s"
		% [prix_faux])


## CHAQUE PRIX MORD : le sort avec la majeure entiere n est pas le meme que le
## sort avec la majeure privee de ce prix. Un prix sur un axe que le sort n a
## pas (« -30 % zone » sur un sort sans zone) s afficherait sans jamais se payer.
func _test_chaque_prix_mord() -> void:
	var muets: Array[String] = []
	for c in _sorts():
		var garde: Array[MajorUpgradeDef] = c.major_upgrades.duplicate()
		for m in garde:
			if m == null:
				continue
			for k in m.prices.size():
				var reste: Array = m.prices.duplicate()
				reste.remove_at(k)
				var sans: MajorUpgradeDef = MajorUpgradeDef.make(m.id, m.title, m.description,
					m.modifiers, reste)
				c.major_upgrades = [sans]
				RunState.reset()
				_prendre(c, sans)
				var e_sans: String = _empreinte(c)
				c.major_upgrades = [m]
				RunState.reset()
				_prendre(c, m)
				var e_avec: String = _empreinte(c)
				if e_sans == e_avec:
					muets.append("%s/%s : %s" % [c.id, m.id,
						str(MajorUpgradeDef.field(m.prices[k], "axis", ""))])
		c.major_upgrades = garde
	RunState.reset()
	eq(muets.size(), 0, "chaque prix mord sur son sort %s" % [muets])


func _test_les_textes_se_lisent_en_portrait() -> void:
	var defauts: Array[String] = []
	for c in _sorts():
		for m in c.major_upgrades:
			if m == null:
				continue
			var nom: String = "%s/%s" % [c.id, m.id]
			if m.title.strip_edges() == "" or m.title.length() > TITRE_MAX:
				defauts.append("%s : titre de %d signes" % [nom, m.title.length()])
			if m.description.length() > TEXTE_MAX:
				defauts.append("%s : texte de %d signes" % [nom, m.description.length()])
			if not _ascii(m.title) or not _ascii(m.description):
				defauts.append("%s : accent ou signe hors ASCII" % nom)
			var voie: Dictionary = RunState.major_path(c, m)
			if not String(voie.get("gain_text", "")).begins_with("+"):
				defauts.append("%s : gain sans +" % nom)
			var lignes: Array = voie.get("cost_lines", []) as Array
			if lignes.size() != m.prices.size():
				defauts.append("%s : %d prix pour %d lignes" % [nom, m.prices.size(), lignes.size()])
			for l in lignes:
				if not String(l).begins_with("-") or String(l).length() > PRIX_MAX:
					defauts.append("%s : prix illisible « %s »" % [nom, l])
	eq(defauts.size(), 0, "les majeures se lisent en portrait %s" % [defauts.slice(0, 6)])


## L offre : jamais a la premiere maturation, une majeure a la deuxieme — donc
## chaque sort doit murir au moins deux fois, sinon ses majeures sont mortes.
func _test_offertes_a_partir_de_la_deuxieme_maturation() -> void:
	var defauts: Array[String] = []
	var vues: Dictionary = {}
	for c in _sorts():
		if c.major_upgrades.is_empty():
			continue
		RunState.reset()
		if RunState.upgrade_tiers_for(c) < GameConfig.MAJOR_UPGRADE_FROM_TIER:
			defauts.append("%s : %d maturations, ses majeures ne sortent jamais"
				% [c.id, RunState.upgrade_tiers_for(c)])
			continue
		for graine in 8:
			RunState.reset()
			RunState.set_seed(8100 + graine)
			var premiere: Array = RunState.draw_upgrade_offer(c)
			for v in premiere:
				if bool((v as Dictionary).get("major", false)):
					defauts.append("%s : majeure a la premiere maturation" % c.id)
			if premiere.is_empty():
				defauts.append("%s : premiere offre vide" % c.id)
				continue
			RunState.upgrades_taken[c.id] = [StringName((premiere[0] as Dictionary)["id"])]
			var seconde: Array = RunState.draw_upgrade_offer(c)
			var n: int = 0
			for v in seconde:
				if bool((v as Dictionary).get("major", false)):
					n += 1
					vues["%s/%s" % [c.id, (v as Dictionary)["major_id"]]] = true
			if n != 1 or seconde.size() != GameConfig.LEVEL_UP_CHOICES:
				defauts.append("%s : seconde offre de %d voies dont %d majeure(s)"
					% [c.id, seconde.size(), n])
	RunState.reset()
	eq(defauts.size(), 0, "majeures offertes a la deuxieme maturation, jamais avant %s"
		% [defauts.slice(0, 6)])
	ok(vues.size() >= _sorts().size(), "au moins une majeure de chaque sort sort au tirage (%d)"
		% vues.size())


## Le bot du banc juge chaque majeure par sa regle (perte sur l axe d identite) :
## il en prend et il en refuse, sinon le banc ne mesurerait qu une moitie.
func _test_le_bot_sait_les_juger() -> void:
	var prises: int = 0
	var refusees: int = 0
	for c in _sorts():
		for m in c.major_upgrades:
			if m == null:
				continue
			if AutoPick.major_acceptable(c, RunState.major_path(c, m)):
				prises += 1
			else:
				refusees += 1
	ok(prises > 0 and refusees > 0, "le bot en prend %d et en refuse %d" % [prises, refusees])
	ok(prises >= refusees, "le banc mesure la majorite des majeures (%d prises, %d refusees)"
		% [prises, refusees])


# --- Sur le terrain : les majeures cles font ce qu elles disent ---------------

## Fleche percante, Seconde ligne : une ligne PARALLELE, decalee d une colonne.
func _test_la_seconde_ligne_touche_une_autre_colonne() -> void:
	var c: SpellCard = _carte("piercing_arrow")
	var m: MajorUpgradeDef = _majeure(c, "seconde_ligne")
	ok(m != null, "piercing_arrow/seconde_ligne existe")
	if m == null:
		return
	var origine := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	var touches: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var droit: Enemy = bf.spawn_enemy(_def("t_mc_droit"), origine.x, 1.0, Vector2(origine.x, 900))
		var gauche: Enemy = bf.spawn_enemy(_def("t_mc_gauche"), origine.x - 130.0, 1.0,
			Vector2(origine.x - 130.0, 900))
		var droite: Enemy = bf.spawn_enemy(_def("t_mc_droite"), origine.x + 130.0, 1.0,
			Vector2(origine.x + 130.0, 900))
		_lancer(bf, c, Vector2(origine.x, 700))
		ok(droit.hp < droit.max_hp(), "la ligne d origine touche droit devant (%s)" % avec)
		var n: int = 0
		for e in [gauche, droite]:
			if (e as Enemy).hp < (e as Enemy).max_hp():
				n += 1
		touches.append(n)
		detach(bf)
	eq(touches[0], 0, "sans la majeure, les colonnes voisines ne sont pas touchees")
	eq(touches[1], 1, "avec, la seconde ligne touche UNE colonne voisine")
	RunState.reset()


## Mur de pierre, Muraille geante : plus large, et les volants ne passent plus.
func _test_la_muraille_geante_arrete_les_volants() -> void:
	var c: SpellCard = _carte("stone_wall")
	var m: MajorUpgradeDef = _majeure(c, "muraille_geante")
	ok(m != null, "stone_wall/muraille_geante existe")
	if m == null:
		return
	var ou := Vector2(540, 900)
	var ecart: float = c.effects[0].radius + 60.0  # hors du mur normal, dans le geant
	var ys: Array[float] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var dv := _def("t_mc_volant", 60.0)
		dv.flying = true
		var v: Enemy = bf.spawn_enemy(dv, ou.x + ecart, 1.0, Vector2(ou.x + ecart, 700))
		_lancer(bf, c, ou)
		if avec and not bf.walls.is_empty():
			feq(float(bf.walls[0]["half_width"]), c.effects[0].radius * 1.8, "le mur est 1,8 fois plus large")
			ok(bool(bf.walls[0].get("w10_blocks_flyers", false)), "il arrete les volants")
		_avancer(bf, 8.0)
		ys.append(v.position.y)
		detach(bf)
	ok(ys[0] > ou.y, "sans la majeure, le volant passe (%.0f)" % ys[0])
	ok(ys[1] < ou.y, "avec, il reste bloque devant la muraille, meme sur le cote (%.0f)" % ys[1])
	RunState.reset()


## Etincelle, Arc electrique : la cible porte une marque qui saute a sa mort.
func _test_l_arc_electrique_transmet_la_marque() -> void:
	var c: SpellCard = _carte("spark")
	var m: MajorUpgradeDef = _majeure(c, "arc_electrique")
	ok(m != null, "spark/arc_electrique existe")
	if m == null:
		return
	# La cible SURVIT a l etincelle (la marque se pose apres son coup : une cible
	# tuee net n est pas marquee) et tombe sous le coup de la marque elle-meme,
	# qui saute alors.
	RunState.reset()
	_prendre(c, m)
	var pv: float = RunState.cast_specs(c)[0].magnitude + 1.0
	var marques: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var cible: Enemy = bf.spawn_enemy(_def("t_mc_arc_cible", 0.0, pv), 540.0, 1.0, Vector2(540, 700))
		var voisin: Enemy = bf.spawn_enemy(_def("t_mc_arc_voisin"), 640.0, 1.0, Vector2(640, 700))
		_lancer(bf, c, cible.position, Vector2.UP, cible)
		_avancer(bf, GameConfig.MARK_JUMP_DELAY + 0.05)
		marques.append(bf.w10_marks_on(voisin).size())
		if avec:
			ok(voisin.hp < voisin.max_hp(), "le saut frappe le voisin")
		detach(bf)
	eq(marques[0], 0, "sans la majeure, l etincelle ne marque personne")
	eq(marques[1], 1, "avec, la marque saute de la cible morte au voisin")
	RunState.reset()


## Marque electrique (B1a), Orage en chaine : la mort transmet DEUX marques.
func _test_l_orage_en_chaine_double_la_marque() -> void:
	var c: SpellCard = _carte("electric_mark")
	if c == null:
		ok(not B1A_FUSIONNE, "(electric_mark de B1a absente : test differe a sa fusion)")
		return
	var m: MajorUpgradeDef = _majeure(c, "orage_en_chaine")
	ok(m != null, "electric_mark/orage_en_chaine existe")
	if m == null:
		return
	var touches: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var porteur: Enemy = bf.spawn_enemy(_def("t_mc_orage_porteur", 0.0, 1.0), 540.0, 1.0,
			Vector2(540, 700))
		var voisins: Array[Enemy] = []
		for i in 3:
			voisins.append(bf.spawn_enemy(_def("t_mc_orage_voisin%d" % i), 610.0 + i * 50.0, 1.0,
				Vector2(610.0 + i * 50.0, 700)))
		_lancer(bf, c, porteur.position, Vector2.UP, porteur)
		_avancer(bf, GameConfig.MARK_JUMP_DELAY + 0.05)
		var n: int = 0
		for v in voisins:
			if not bf.w10_marks_on(v).is_empty():
				n += 1
		touches.append(n)
		detach(bf)
	eq(touches[0], 1, "sans la majeure : un voisin marque")
	eq(touches[1], 2, "avec : deux voisins marques")
	RunState.reset()


## Concentration, Maitrise (l idee du co-auteur) : une carte de la main monte
## d un niveau A LA PLACE de l XP donnee a toute la main.
func _test_la_maitrise_fait_murir_a_la_place() -> void:
	var c: SpellCard = _carte("deep_focus")
	var m: MajorUpgradeDef = _majeure(c, "maitrise")
	ok(m != null, "deep_focus/maitrise existe")
	if m == null:
		return
	var a: SpellCard = _carte("fireball")
	var b: SpellCard = _carte("spark")
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		RunState.hand.append(a)
		RunState.hand.append(b)
		_lancer(null, c, Vector2.ZERO)
		if avec:
			eq(RunState.pending_hand_level, 1, "la Maitrise ouvre le choix d une carte a faire murir")
			eq(RunState.card_xp(a) + RunState.card_xp(b), 0, "et ne donne plus l XP a toute la main")
		else:
			eq(RunState.pending_hand_level, 0, "sans elle, aucun choix")
			eq(RunState.card_xp(a), 1, "mais 1 XP a chaque sort de la main")
	RunState.reset()


## Boule de feu, Barrage : trois explosions en ligne sur toute la largeur visee.
func _test_le_barrage_frappe_toute_la_largeur() -> void:
	var c: SpellCard = _carte("fireball")
	var m: MajorUpgradeDef = _majeure(c, "barrage")
	ok(m != null, "fireball/barrage existe")
	if m == null:
		return
	var ou := Vector2(540, 800)
	var cotes: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var centre: Enemy = bf.spawn_enemy(_def("t_mc_bar_centre"), ou.x, 1.0, ou)
		var g: Enemy = bf.spawn_enemy(_def("t_mc_bar_g"), ou.x - 230.0, 1.0, ou + Vector2(-230, 0))
		var d: Enemy = bf.spawn_enemy(_def("t_mc_bar_d"), ou.x + 230.0, 1.0, ou + Vector2(230, 0))
		_lancer(bf, c, ou)
		if avec:
			eq(bf.zones.size(), 3, "trois explosions")
		_avancer(bf, 0.8)
		ok(centre.hp < centre.max_hp(), "le centre brule (%s)" % avec)
		var n: int = 0
		for e in [g, d]:
			if (e as Enemy).hp < (e as Enemy).max_hp():
				n += 1
		cotes.append(n)
		detach(bf)
	eq(cotes[0], 0, "sans la majeure, les cotes sont epargnes")
	eq(cotes[1], 2, "avec, les deux cotes brulent aussi")
	RunState.reset()


## Mare de venin, Venin tenace (l idee du co-auteur) : le poison reste 5 s
## apres la sortie de la mare.
func _test_le_venin_tenace_reste_apres_la_mare() -> void:
	var c: SpellCard = _carte("venom_mire")
	var m: MajorUpgradeDef = _majeure(c, "venin_tenace")
	ok(m != null, "venom_mire/venin_tenace existe")
	if m == null:
		return
	RunState.reset()
	_prendre(c, m)
	var bf := _field()
	var centre := Vector2(540, 700)
	var e: Enemy = bf.spawn_enemy(_def("t_mc_venin"), centre.x, 1.0, centre)
	_lancer(bf, c, centre)
	_avancer(bf, 1.0)
	e.position = Vector2(540, 1400)
	var hors: float = e.hp
	_avancer(bf, 1.0)
	feq(hors - e.hp, 5.0, "sorti, il perd 5 PV par seconde", 0.3)
	_avancer(bf, 6.0)
	feq(hors - e.hp, 25.0, "pendant 5 s, puis plus rien", 0.5)
	detach(bf)
	RunState.reset()


## Ronces, Ronces de fer (le terrain du co-auteur) : incassables, plus
## mordantes, mais limitees dans le temps.
func _test_les_ronces_de_fer_sont_incassables_et_breves() -> void:
	var c: SpellCard = _carte("terrain_brambles")
	var m: MajorUpgradeDef = _majeure(c, "ronces_de_fer")
	ok(m != null, "terrain_brambles/ronces_de_fer existe")
	if m == null:
		return
	RunState.reset()
	var bf0 := _field()
	_lancer(bf0, c, Vector2(540, 800))
	ok(bf0.props.size() == 1 and (bf0.props[0] as TerrainProp).is_permanent(),
		"(sans la majeure, les ronces restent tout le combat)")
	detach(bf0)
	RunState.reset()
	_prendre(c, m)
	var bf := _field()
	_lancer(bf, c, Vector2(540, 800))
	eq(bf.props.size(), 1, "les ronces sont posees")
	if bf.props.size() == 1:
		var p: TerrainProp = bf.props[0]
		not_ok(p.is_permanent(), "elles ne restent plus tout le combat")
		feq(p.time_left, 12.0, "elles fanent en 12 s", 0.01)
		ok(p.anchor != null and p.anchor.has_meta(&"w10_unbreakable"),
			"le Briseur de terrain ne les casse plus")
		if p.zone is Dictionary and not (p.zone as Dictionary).is_empty():
			feq(float((p.zone as Dictionary)["slow_pct"]), 70.0, "elles ralentissent de 70 %")
			feq(float((p.zone as Dictionary)["dps"]), 6.0, "et mordent a 6 par seconde")
	_avancer(bf, 12.5)
	eq(bf.props.size(), 0, "a la fin, elles ont fane")
	detach(bf)
	RunState.reset()


## Maelstrom, Siphon : attirer puis engloutir ce qui est au centre.
func _test_le_siphon_engloutit_le_centre() -> void:
	var c: SpellCard = _carte("maelstrom")
	var m: MajorUpgradeDef = _majeure(c, "siphon")
	ok(m != null, "maelstrom/siphon existe")
	if m == null:
		return
	var pertes: Array[float] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var ou := Vector2(540, 700)
		var e: Enemy = bf.spawn_enemy(_def("t_mc_siphon"), ou.x, 1.0, ou)
		_lancer(bf, c, ou)
		_avancer(bf, 4.2)
		pertes.append(e.max_hp() - e.hp)
		detach(bf)
	feq(pertes[0], 0.0, "sans la majeure, le maelstrom ne fait aucun degat")
	feq(pertes[1], 40.0, "avec, ce qui est au centre encaisse 40 a la fin", 0.5)
	RunState.reset()


## Pacte imprudent, Pacte inverse : les monstres RALENTISSENT au lieu d accelerer.
func _test_le_pacte_inverse_ralentit() -> void:
	var c: SpellCard = _carte("reckless_bargain")
	var m: MajorUpgradeDef = _majeure(c, "pacte_inverse")
	ok(m != null, "reckless_bargain/pacte_inverse existe")
	if m == null:
		return
	var facteurs: Array[float] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		_lancer(bf, c, Vector2(540, 700))
		facteurs.append(float(bf.get("_global_slow_factor")))
		detach(bf)
	ok(facteurs[0] > 1.0, "sans la majeure, le pacte accelere les monstres (x%.2f)" % facteurs[0])
	feq(facteurs[1], 0.7, "avec, il les ralentit de 30 %", 0.001)
	RunState.reset()


## Meteore, Meteore eclair : la carte longue devient quasi instantanee.
func _test_le_meteore_eclair_est_quasi_instantane() -> void:
	var c: SpellCard = _carte("meteor")
	var m: MajorUpgradeDef = _majeure(c, "meteore_eclair")
	ok(m != null, "meteor/meteore_eclair existe")
	if m == null:
		return
	RunState.reset()
	var avant: float = RunState.effective_cast_time(c)
	_prendre(c, m)
	feq(RunState.effective_cast_time(c) / avant, 0.25, "incantation quatre fois plus courte", 0.001)
	feq(RunState.cast_specs(c)[0].radius, c.effects[0].radius * 0.45, "contre -55 % de zone", 0.01)
	RunState.reset()


## Bastion, Forteresse : incassable, infranchissable meme en volant, 15 s.
func _test_la_forteresse_arrete_tout_et_tombe() -> void:
	var c: SpellCard = _carte("bastion")
	var m: MajorUpgradeDef = _majeure(c, "forteresse")
	ok(m != null, "bastion/forteresse existe")
	if m == null:
		return
	RunState.reset()
	var bf0 := _field()
	_lancer(bf0, c, Vector2(540, 900))
	ok(not bf0.walls.is_empty() and float(bf0.walls[0].get("hp", 0.0)) > 0.0,
		"(sans la majeure, le Bastion a des PV)")
	detach(bf0)
	RunState.reset()
	_prendre(c, m)
	var bf := _field()
	_lancer(bf, c, Vector2(540, 900))
	eq(bf.walls.size(), 1, "le mur est pose")
	if bf.walls.size() == 1:
		var w: Dictionary = bf.walls[0]
		not_ok(w.has("hp"), "il n a plus de PV a frapper")
		ok(bool(w.get("w10_blocks_flyers", false)), "les volants ne le franchissent plus")
		feq(float(w["time"]), 15.0, "il tombe au bout de 15 s", 0.01)
		var ancre: Variant = w.get("anchor")
		ok(ancre is Node and (ancre as Node).has_meta(&"w10_unbreakable"), "le Briseur l epargne")
	_avancer(bf, 15.5)
	eq(bf.walls.size(), 0, "15 s plus tard, il est tombe")
	detach(bf)
	RunState.reset()


## Faille temporelle, Faille en croix : deux lignes de plus, a angle droit.
func _test_la_faille_s_ouvre_en_croix() -> void:
	var c: SpellCard = _carte("time_rift")
	var m: MajorUpgradeDef = _majeure(c, "faille_en_croix")
	ok(m != null, "time_rift/faille_en_croix existe")
	if m == null:
		return
	var y: float = GameConfig.MAGE_LINE_Y - 30.0
	var touches: Array[int] = []
	for avec in [false, true]:
		RunState.reset()
		if avec:
			_prendre(c, m)
		var bf := _field()
		var g: Enemy = bf.spawn_enemy(_def("t_mc_croix_g"), 240.0, 1.0, Vector2(240, y))
		var d: Enemy = bf.spawn_enemy(_def("t_mc_croix_d"), 840.0, 1.0, Vector2(840, y))
		_lancer(bf, c, Vector2(540, 700))
		var n: int = 0
		for e in [g, d]:
			if (e as Enemy).hp < (e as Enemy).max_hp():
				n += 1
		touches.append(n)
		detach(bf)
	eq(touches[0], 0, "sans la majeure, la ligne ne frappe que devant")
	eq(touches[1], 2, "avec, la croix frappe a gauche ET a droite du mage")
	RunState.reset()
