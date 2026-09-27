extends TestCase
## SORTS DE TERRAIN PERMANENTS : riviere, ronces, fosse, autel generateur, et les
## deux arbres devenus permanents.
##
## Les regles verifiees ici, dans l ordre ou elles cassent une partie :
##   - un objet qui bloque ne coupe JAMAIS tout chemin des monstres au sol ;
##   - le terrain permanent est BORNE (plafond, le plus ancien remplace) ;
##   - un objet permanent survit a la fin d une vague ;
##   - la riviere bloque le sol mais pas les volants, et son pont est libre ;
##   - l arbre qui attire tient plusieurs secondes, sans etre invulnerable ;
##   - chaque objet de terrain honore le contrat du futur Briseur de terrain.
##
## Aucune valeur d equilibrage n est figee : les bornes se lisent dans GameConfig
## ou dans les cartes livrees.

func get_suite_name() -> String:
	return "terrain"


const DT: float = 1.0 / 60.0


func run() -> void:
	_test_handlers_enregistres()
	_test_duree_nulle_veut_dire_permanent()
	_test_un_objet_permanent_survit_a_la_fin_d_une_vague()
	_test_plafond_remplace_le_plus_ancien()
	_test_le_massacre_reste_borne()
	_test_pose_maximale_garde_un_chemin()
	_test_un_mur_sur_le_pont_est_refuse()
	_test_la_visee_refuse_avant_de_depenser_la_carte()
	_test_la_riviere_bloque_le_sol_pas_les_volants()
	_test_le_pont_n_est_jamais_sur_une_case_bloquee()
	_test_les_monstres_sur_la_ligne_sont_repousses()
	_test_une_seule_riviere_a_la_fois()
	_test_la_hauteur_est_ramenee_dans_les_bornes()
	_test_pas_de_provocation_a_travers_la_riviere()
	_test_le_totem_tient_plusieurs_secondes()
	_test_le_totem_attire_encore()
	_test_le_semis_n_attire_plus()
	_test_l_autel_invoque_et_se_brise()
	_test_ronces_et_fosse()
	_test_contrat_du_briseur_de_terrain()
	_test_cartes_livrees()


# --- Outils ---

func _field() -> Battlefield:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _def(id: String, speed: float = 0.0, flying: bool = false) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 99999.0
	d.base_speed = speed
	d.base_radius = 20.0
	d.base_xp = 1
	d.flying = flying
	return d


func _card(id: StringName) -> SpellCard:
	var c: SpellCard = ContentDB.cards.get(id)
	ok(c != null, "la carte %s existe" % id)
	return c


func _cast(bf: Battlefield, card: SpellCard, at: Vector2) -> void:
	if card == null:
		return
	var ctx := CastContext.make(bf, card)
	ctx.target_position = at
	ctx.direction = Vector2.UP
	EffectRegistry.cast(card, ctx)


## Un vrai A* depuis chaque colonne d apparition atteint-il la ligne du mage ?
## Verification INDEPENDANTE du parcours a rebours de `keeps_path` : si les deux
## divergeaient, la garantie mentirait.
func _every_column_reaches_mage(bf: Battlefield) -> bool:
	for cx in bf.nav.cols:
		var depart := Vector2((cx + 0.5) * NavGrid.CELL_SIZE, GameConfig.SPAWN_LINE_Y)
		if bf.nav.find_path(depart).is_empty():
			return false
	return true


func _river_card_spec() -> EffectSpec:
	var c: SpellCard = ContentDB.cards.get(&"terrain_river")
	return c.effects[0] if c != null else null


# --- 1. Socle ---

func _test_handlers_enregistres() -> void:
	for key in [&"place_terrain", &"terrain_river", &"taunt_prop"]:
		ok(EffectRegistry.has_key(key), "handler '%s' enregistre" % key)


## La convention des cartes : duree <= 0 = jusqu a la fin du combat.
func _test_duree_nulle_veut_dire_permanent() -> void:
	ok(is_inf(TerrainProp.lifetime_for(0.0)), "duree 0 -> permanent")
	ok(is_inf(TerrainProp.lifetime_for(-1.0)), "duree negative -> permanent")
	feq(TerrainProp.lifetime_for(7.0), 7.0, "une duree positive reste une duree")
	var bf := _field()
	reset_gauge_at_normal_speed()
	var p: TerrainProp = bf.spawn_prop(TerrainProp.Kind.BRAMBLE, Vector2(540, 800), 0.0, 0.0)
	ok(p.is_permanent(), "l objet pose avec une duree nulle est permanent")
	for i in 60 * 120:
		bf.simulate(DT)
	eq(bf.prop_count(), 1, "deux minutes plus tard, il est toujours la")
	detach(bf)


## « Jusqu a la fin du combat » : la fin d une VAGUE n est pas la fin du combat.
func _test_un_objet_permanent_survit_a_la_fin_d_une_vague() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	reset_gauge_with_survivable_mage()
	_cast(g.battlefield, _card(&"terrain_brambles"), Vector2(540, 800))
	_cast(g.battlefield, _card(&"heartwood_totem"), Vector2(200, 700))
	var avant: int = g.battlefield.prop_count()
	eq(avant, 2, "deux objets permanents poses")
	var vague: int = g.spawner.index
	# On nettoie la vague a la main jusqu a ce que la suivante commence.
	for i in 60 * 90:
		if not RunState.pending_offer.is_empty():
			g.choose_card(0)
		for e in g.battlefield.enemies.duplicate():
			if e != null and is_instance_valid(e) and not e.is_dead():
				e.take_damage(999999.0, [])
		g.simulate(DT)
		if g.spawner.index > vague:
			break
	ok(g.spawner.index > vague, "la vague a bien pris fin")
	eq(g.battlefield.prop_count(), avant, "les objets permanents lui survivent")
	# Et c est bien la fin du COMBAT qui les retire.
	g.battlefield.clear_all()
	eq(g.battlefield.prop_count(), 0, "la fin du combat les retire")
	detach(g)
	RunState.reset()
	reset_gauge_at_normal_speed()


## Plafond : au-dela de TERRAIN_PERMANENT_MAX, le plus ANCIEN part.
func _test_plafond_remplace_le_plus_ancien() -> void:
	var bf := _field()
	var max_n: int = GameConfig.TERRAIN_PERMANENT_MAX
	var poses: Array[TerrainProp] = []
	for i in max_n + 3:
		var at := Vector2(120.0 + (i % 6) * 160.0, 400.0 + (i / 6) * 300.0)
		poses.append(bf.spawn_prop(TerrainProp.Kind.PIT, at, 0.0, 0.0))
	eq(bf.permanent_prop_count(), max_n, "jamais plus que le plafond")
	for i in 3:
		ok(not bf.props.has(poses[i]), "le %d-e plus ancien a ete remplace" % (i + 1))
	ok(bf.props.has(poses[poses.size() - 1]), "le plus recent est bien la")
	ok(bf.props.has(poses[3]), "le plus ancien survivant est le suivant dans l ordre")
	# Un objet TEMPORAIRE ne compte pas et n est jamais remplace par le plafond.
	var bref: TerrainProp = bf.spawn_prop(TerrainProp.Kind.TREE, Vector2(540, 900), 30.0, 50.0)
	bf.spawn_prop(TerrainProp.Kind.PIT, Vector2(540, 1100), 0.0, 0.0)
	ok(bf.props.has(bref), "un objet a duree n est pas pris par le plafond")
	eq(bf.permanent_prop_count(), max_n, "le plafond tient toujours")
	detach(bf)


## Le Massacre dure vingt vagues et plus : le terrain s y accumule. On rejoue
## vingt-cinq « vagues » de poses et on verifie que tout reste borne et sain.
func _test_le_massacre_reste_borne() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var cartes: Array[StringName] = [&"terrain_brambles", &"terrain_pit",
		&"terrain_altar", &"blight_sapling", &"heartwood_totem"]
	var mur: SpellCard = _card(&"stone_wall")
	var riv: SpellCard = _card(&"terrain_river")
	var sain: bool = true
	for vague in 25:
		var y: float = rng.randf_range(300.0, 1300.0)
		if EffectHandlers.placement_allowed(riv, Vector2(540, y), bf):
			_cast(bf, riv, Vector2(540, y))
		for k in 3:
			var at := Vector2(rng.randf_range(80, 1000), rng.randf_range(300, 1300))
			_cast(bf, _card(cartes[rng.randi_range(0, cartes.size() - 1)]), at)
		var pm := Vector2(rng.randf_range(80, 1000), rng.randf_range(300, 1300))
		if EffectHandlers.placement_allowed(mur, pm, bf):
			_cast(bf, mur, pm)
		for i in 60:
			bf.simulate(DT)
		var rivieres: int = 0
		for p in bf.props:
			if p.kind == TerrainProp.Kind.RIVER:
				rivieres += 1
		if bf.permanent_prop_count() > GameConfig.TERRAIN_PERMANENT_MAX or rivieres > 1 \
				or not bf.nav.keeps_path([]) or not _every_column_reaches_mage(bf):
			sain = false
			break
	ok(sain, "25 vagues de poses : plafond tenu, une riviere au plus, chemin garanti")
	# Les allies des autels vivent et meurent : ils ne s accumulent pas.
	ok(bf.allies.size() <= GameConfig.TERRAIN_PERMANENT_MAX * 2,
		"les allies des autels ne s entassent pas (%d)" % bf.allies.size())
	detach(bf)


# --- 2. Garantie de chemin ---

## LA regle : on pose le MAXIMUM d objets qui bloquent — une riviere, puis des
## murs partout ou la garantie les accepte — et un chemin existe toujours.
func _test_pose_maximale_garde_un_chemin() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var riv: SpellCard = _card(&"terrain_river")
	var mur: SpellCard = _card(&"stone_wall")
	var bastion: SpellCard = _card(&"bastion")
	_cast(bf, riv, Vector2(540, 800))
	ok(bf.river() != null, "la riviere est posee")
	var acceptes: int = 0
	var refuses: int = 0
	var toujours: bool = true
	for gy in range(6, 24):
		for gx in range(0, 19):
			var at := Vector2(gx * 60.0, gy * 60.0 + 30.0)
			for c in [mur, bastion]:
				if c == null:
					continue
				if EffectHandlers.placement_allowed(c, at, bf):
					var murs_avant: int = bf.wall_count()
					_cast(bf, c, at)
					if bf.wall_count() > murs_avant:
						acceptes += 1
				else:
					refuses += 1
				if not bf.nav.keeps_path([]):
					toujours = false
	ok(acceptes > 10, "beaucoup de murs ont pu etre poses (%d)" % acceptes)
	ok(refuses > 0, "et certains ont ete REFUSES (%d) : la garantie a mordu" % refuses)
	ok(toujours, "apres chaque pose, chaque colonne garde un chemin")
	ok(_every_column_reaches_mage(bf), "un vrai A* le confirme depuis chaque colonne")
	detach(bf)


## Un mur pose pile sur le pont fermerait la riviere : refuse a la visee ET a la
## resolution (le terrain a pu changer pendant l incantation).
func _test_un_mur_sur_le_pont_est_refuse() -> void:
	var bf := _field()
	var r: TerrainProp = bf.spawn_river(800.0)
	ok(r != null, "riviere posee")
	if r == null:
		detach(bf)
		return
	var pont: Vector2 = bf.nav.to_world(Vector2i(r.bridge_col, bf.nav.to_cell(r.position).y))
	var mur: SpellCard = _card(&"stone_wall")
	not_ok(EffectHandlers.placement_allowed(mur, pont, bf), "la visee refuse le mur sur le pont")
	var avant: int = bf.wall_count()
	_cast(bf, mur, pont)
	eq(bf.wall_count(), avant, "et la resolution aussi : aucun mur n est pose")
	ok(_every_column_reaches_mage(bf), "le pont reste ouvert")
	detach(bf)


## Refuser AVANT de depenser : la carte reste en main.
func _test_la_visee_refuse_avant_de_depenser_la_carte() -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	var r: TerrainProp = g.battlefield.spawn_river(800.0)
	var mur: SpellCard = _card(&"stone_wall")
	if r != null and mur != null:
		var pont: Vector2 = g.battlefield.nav.to_world(
			Vector2i(r.bridge_col, g.battlefield.nav.to_cell(r.position).y))
		not_ok(g.aim_allowed(mur, pont), "l apercu de visee est refuse sur le pont")
		RunState.hand.append(mur)
		var en_main: int = RunState.hand.size()
		not_ok(g.play_card(mur, pont), "la carte n est pas jouee")
		eq(RunState.hand.size(), en_main, "elle reste en main")
		ok(g.aim_allowed(mur, Vector2(540, 400)), "ailleurs, le meme mur est accepte")
	detach(g)
	RunState.reset()
	reset_gauge_at_normal_speed()


# --- 3. La riviere ---

## Les monstres au sol passent PAR LE PONT ; les volants passent au-dessus.
func _test_la_riviere_bloque_le_sol_pas_les_volants() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r: TerrainProp = bf.spawn_river(800.0, 0.0, "", rng)
	if r == null:
		ok(false, "riviere posee")
		detach(bf)
		return
	var ligne: float = r.position.y
	var gauche: float = r.bridge_col * NavGrid.CELL_SIZE
	var droite: float = gauche + NavGrid.CELL_SIZE
	# Le marcheur part a l oppose du pont, le volant sur une colonne d eau.
	var loin: int = (r.bridge_col + bf.nav.cols / 2) % bf.nav.cols
	var x_loin: float = (loin + 0.5) * NavGrid.CELL_SIZE
	var marcheur: Enemy = bf.spawn_enemy(_def("t_marcheur", 400.0), x_loin, 1.0,
		Vector2(x_loin, ligne - 300.0))
	var volant: Enemy = bf.spawn_enemy(_def("t_volant", 400.0, true), x_loin, 1.0,
		Vector2(x_loin, ligne - 300.0))
	var x_marcheur: float = -1.0
	var x_volant: float = -1.0
	for i in 60 * 30:
		var ym: float = marcheur.position.y
		var yv: float = volant.position.y
		bf.simulate(DT)
		if x_marcheur < 0.0 and ym < ligne and marcheur.position.y >= ligne:
			x_marcheur = marcheur.position.x
		if x_volant < 0.0 and yv < ligne and volant.position.y >= ligne:
			x_volant = volant.position.x
		if x_marcheur >= 0.0 and x_volant >= 0.0:
			break
	ok(x_marcheur >= 0.0, "le marcheur finit par franchir la riviere")
	between(x_marcheur, gauche - 1.0, droite + 1.0, "il la franchit PAR LE PONT")
	ok(x_volant >= 0.0, "le volant la franchit aussi")
	feq(x_volant, x_loin, "le volant passe au-dessus, sans detour", 1.0)
	detach(bf)


## Sur de nombreux tirages, le pont tombe sur une case LIBRE et garde un chemin,
## meme quand des murs occupent deja une partie de la rangee.
func _test_le_pont_n_est_jamais_sur_une_case_bloquee() -> void:
	var bf := _field()
	var row: int = NavGrid.river_row(800.0)
	var y: float = NavGrid.row_center_y(row)
	# Des murs sur la rangee de la riviere : 2/3 de la largeur deja bouchee.
	bf.spawn_wall(Vector2(150.0, y), 150.0, 999.0, 30.0)
	bf.spawn_wall(Vector2(620.0, y), 200.0, 999.0, 30.0)
	var murees: Dictionary = {}
	for w in bf.walls:
		for c in w["cells"]:
			murees[c] = true
	var rng := RandomNumberGenerator.new()
	var mauvais: int = 0
	var tirages: int = 300
	var vus: Dictionary = {}
	for s in tirages:
		rng.seed = s
		var r: TerrainProp = bf.spawn_river(y, 0.0, "", rng)
		if r == null:
			mauvais += 1
			continue
		vus[r.bridge_col] = true
		if murees.has(Vector2i(r.bridge_col, row)) or bf.nav.is_blocked(Vector2i(r.bridge_col, row)):
			mauvais += 1
		# Le vrai A* depuis chaque colonne coute cher : un tirage sur vingt suffit
		# a confirmer que le parcours a rebours ne ment pas.
		elif s % 20 == 0 and not _every_column_reaches_mage(bf):
			mauvais += 1
	eq(mauvais, 0, "%d tirages : le pont n est jamais sur une case bloquee" % tirages)
	ok(vus.size() > 1, "le pont change bien de place d un tirage a l autre (%d)" % vus.size())
	detach(bf)


## Un monstre au sol debout sur la ligne quand elle apparait est repousse en amont.
func _test_les_monstres_sur_la_ligne_sont_repousses() -> void:
	var bf := _field()
	var row: int = NavGrid.river_row(800.0)
	var y: float = NavGrid.row_center_y(row)
	var pieton: Enemy = bf.spawn_enemy(_def("t_pieton"), 90.0, 1.0, Vector2(90.0, y))
	var oiseau: Enemy = bf.spawn_enemy(_def("t_oiseau", 0.0, true), 150.0, 1.0, Vector2(150.0, y))
	var r: TerrainProp = bf.spawn_river(y)
	if r == null:
		ok(false, "riviere posee")
		detach(bf)
		return
	if r.bridge_col != bf.nav.to_cell(pieton.position).x:
		ok(pieton.position.y < y - NavGrid.CELL_SIZE * 0.5,
			"le monstre au sol est repousse au-dessus de l eau")
	feq(oiseau.position.y, y, "le volant reste ou il est", 0.01)
	detach(bf)


func _test_une_seule_riviere_a_la_fois() -> void:
	var bf := _field()
	var a: TerrainProp = bf.spawn_river(500.0)
	var b: TerrainProp = bf.spawn_river(1100.0)
	var n: int = 0
	for p in bf.props:
		if p.kind == TerrainProp.Kind.RIVER:
			n += 1
	eq(n, 1, "une seule riviere active")
	ok(bf.river() == b, "la nouvelle remplace l ancienne")
	ok(a != null and a.cells.is_empty(), "l ancienne a rendu ses cellules")
	eq(bf.nav.blocked_count(), b.cells.size(), "seules les cellules de la nouvelle sont bloquees")
	eq(b.cells.size(), bf.nav.cols - 1, "toute la largeur moins le pont")
	detach(bf)


## Le point vise est ramene dans les bornes, jamais refuse pour sa hauteur.
func _test_la_hauteur_est_ramenee_dans_les_bornes() -> void:
	var haut: int = NavGrid.river_row(-500.0)
	var bas: int = NavGrid.river_row(5000.0)
	var nav := NavGrid.new()
	ok(haut > nav.spawn_row(), "jamais sur la ligne d apparition")
	ok(bas < nav.goal_row(), "jamais sur la ligne du mage")
	ok(haut <= bas, "les bornes laissent au moins une rangee")
	eq(NavGrid.river_row(NavGrid.row_center_y(haut + 1)), haut + 1,
		"dans les bornes, la rangee visee est celle du doigt")


## L arbre n attire pas A TRAVERS l eau : le monstre marcherait dessus.
func _test_pas_de_provocation_a_travers_la_riviere() -> void:
	var bf := _field()
	var r: TerrainProp = bf.spawn_river(800.0)
	if r == null:
		ok(false, "riviere posee")
		detach(bf)
		return
	# Arbre et monstre sur une colonne d EAU, loin du pont : par le pont, la
	# ligne droite est libre et la provocation est legitime.
	var loin: int = (r.bridge_col + bf.nav.cols / 2) % bf.nav.cols
	var x: float = (loin + 0.5) * NavGrid.CELL_SIZE
	var arbre: TerrainProp = bf.spawn_prop(TerrainProp.Kind.TREE,
		Vector2(x, r.position.y + 150.0), 0.0, 100.0, 460.0)
	var dessus := Vector2(x, r.position.y - 150.0)
	var dessous := Vector2(clampf(x + 200.0, 60.0, 1020.0) if x < 540.0 else x - 200.0,
		r.position.y + 150.0)
	ok(bf.taunt_target_for(dessus) == null, "de l autre cote de l eau, l arbre n attire pas")
	ok(bf.taunt_target_for(dessous) == arbre, "du meme cote, il attire")
	detach(bf)


# --- 4. Les arbres ---

## L appat tient PLUSIEURS secondes au pied d une vague normale mediane, et il
## finit par tomber. La vague mediane est lue dans le contenu livre ; les bornes
## dans GameConfig ; les PV dans la carte — aucun des trois n est recopie ici.
func _test_le_totem_tient_plusieurs_secondes() -> void:
	var totem: SpellCard = _card(&"heartwood_totem")
	if totem == null:
		return
	var vagues: Array = []
	for key in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[key]
		for w: WaveDef in lvl.waves:
			if w == null or w.is_boss or w.is_miniboss:
				continue
			var dps: float = 0.0
			for en in w.entries:
				if en != null and en.enemy != null:
					dps += en.count * maxi(1, en.enemy.swarm_count) * en.enemy.contact_hit()
			vagues.append([dps, w])
	ok(vagues.size() > 10, "des vagues normales a mesurer")
	if vagues.is_empty():
		return
	vagues.sort_custom(func(a, b): return a[0] < b[0])
	var mediane: WaveDef = vagues[vagues.size() / 2][1]

	var bf := _field()
	# Mage hors de portee de la mort : un tireur de la vague ne doit pas faire
	# basculer le monde au ralenti de l agonie au milieu de la mesure. Le temps
	# est de toute facon compte en temps MONDE, celui des coups portes.
	reset_gauge_with_survivable_mage()
	var centre := Vector2(540.0, 800.0)
	_cast(bf, totem, centre)
	var p: TerrainProp = bf.taunt_target_for(centre + Vector2(0, 100))
	ok(p != null and p.is_permanent(), "le totem est pose, permanent, et il attire")
	var k: int = 0
	var n_total: int = 0
	for en in mediane.entries:
		n_total += en.count * maxi(1, en.enemy.swarm_count)
	for en in mediane.entries:
		for j in en.count * maxi(1, en.enemy.swarm_count):
			# Tous au pied de l arbre des la premiere image : c est le pire cas
			# d une vague, celui que la sonde a mesure.
			var a: float = TAU * float(k) / float(maxi(n_total, 1))
			bf.spawn_enemy(en.enemy, centre.x, mediane.difficulty,
				centre + Vector2(cos(a), sin(a)) * 60.0)
			k += 1
	var t: float = 0.0
	while bf.props.has(p) and t < GameConfig.TERRAIN_TAUNT_MAX_HOLD * 2.0:
		bf.simulate(DT)
		t += SpeedGauge.world_delta(DT)
	ok(t >= GameConfig.TERRAIN_TAUNT_MIN_HOLD,
		"il tient au moins %.1f s face a la vague mediane (%.2f s)"
			% [GameConfig.TERRAIN_TAUNT_MIN_HOLD, t])
	ok(t <= GameConfig.TERRAIN_TAUNT_MAX_HOLD,
		"et il tombe en moins de %.1f s : il n est pas invulnerable (%.2f s)"
			% [GameConfig.TERRAIN_TAUNT_MAX_HOLD, t])
	detach(bf)


func _test_le_totem_attire_encore() -> void:
	var totem: SpellCard = _card(&"heartwood_totem")
	if totem == null:
		return
	var s: EffectSpec = totem.effects[0]
	eq(s.key, &"taunt_prop", "le totem garde la cle qui ATTIRE")
	ok(s.duration <= 0.0, "il est permanent")
	ok(float(s.get_param(&"prop_hp", 0.0)) > 0.0, "il reste destructible")
	ok(s.radius > 0.0, "il a une portee de provocation")


## Le semis ne detourne plus personne : un appat permanent tiendrait la vague
## loin du mage pour toujours. Il garde sa mare de poison, permanente.
func _test_le_semis_n_attire_plus() -> void:
	var semis: SpellCard = _card(&"blight_sapling")
	if semis == null:
		return
	var bf := _field()
	reset_gauge_at_normal_speed()
	var arbre := Vector2(300.0, 900.0)
	_cast(bf, semis, arbre)
	eq(bf.prop_count(), 1, "le semis est plante")
	ok(bf.props[0].is_permanent(), "il est permanent")
	ok(not bf.props[0].zone.is_empty(), "il porte sa mare de poison")
	ok(bf.taunt_target_for(arbre + Vector2(150, 0)) == null, "il n attire plus")
	var d := _def("t_passant", 120.0)
	var e: Enemy = bf.spawn_enemy(d, 700.0, 1.0, Vector2(700.0, 900.0))
	var x0: float = e.position.x
	for i in 60:
		bf.simulate(DT)
	feq(e.position.x, x0, "un monstre a cote ne se detourne pas", 1.0)
	detach(bf)


# --- 5. Le generateur ---

func _test_l_autel_invoque_et_se_brise() -> void:
	var autel: SpellCard = _card(&"terrain_altar")
	if autel == null:
		return
	var s: EffectSpec = autel.effects[0]
	var bf := _field()
	reset_gauge_at_normal_speed()
	var at := Vector2(540.0, 900.0)
	_cast(bf, autel, at)
	eq(bf.prop_count(), 1, "l autel est pose")
	var p: TerrainProp = bf.props[0]
	ok(p.is_permanent(), "il est permanent")
	ok(p.is_breakable(), "il est destructible (sinon valeur infinie en Massacre)")
	ok(p.taunt_radius > 0.0, "il attire un peu : une vague qui passe vient le casser")
	var tous_les: float = float(s.get_param(&"summon_every", 0.0))
	ok(tous_les > 0.0, "il invoque a intervalle")
	var t: float = 0.0
	var invoques: int = 0
	var avant: int = bf.allies.size()
	while t < tous_les * 3.0:
		bf.simulate(DT)
		t += SpeedGauge.world_delta(DT)
		if bf.allies.size() > avant:
			invoques += bf.allies.size() - avant
		avant = bf.allies.size()
	ok(invoques >= 2, "plusieurs allies invoques en trois intervalles (%d)" % invoques)
	ok(not bf.allies.is_empty() and bf.allies[0]["pos"].distance_to(at) < 200.0,
		"les allies naissent a cote de l autel")
	bf.damage_prop_at(at, p.max_hp * 2.0)
	eq(bf.prop_count(), 0, "l autel tombe sous les coups")
	var apres: int = bf.allies.size()
	for i in int(tous_les * 2.0 / DT):
		bf.simulate(DT)
	ok(bf.allies.size() <= apres, "abattu, il n invoque plus")
	detach(bf)


# --- 6. Les deux affaiblissements ---

func _test_ronces_et_fosse() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var ronces: SpellCard = _card(&"terrain_brambles")
	var fosse: SpellCard = _card(&"terrain_pit")
	_cast(bf, ronces, Vector2(300.0, 900.0))
	_cast(bf, fosse, Vector2(800.0, 900.0))
	eq(bf.prop_count(), 2, "ronces et fosse posees")
	var lent: Enemy = bf.spawn_enemy(_def("t_ronce", 100.0), 300.0, 1.0, Vector2(300.0, 900.0))
	var libre: Enemy = bf.spawn_enemy(_def("t_libre", 100.0), 60.0, 1.0, Vector2(60.0, 500.0))
	var y1: float = lent.position.y
	var y2: float = libre.position.y
	for i in 30:
		bf.simulate(DT)
	ok(lent.position.y - y1 < libre.position.y - y2, "les ronces ralentissent")
	ok(bf.damage_multiplier_at(Vector2(800.0, 900.0)) > 1.0, "la fosse rend vulnerable")
	feq(bf.damage_multiplier_at(Vector2(60.0, 300.0)), 1.0, "hors de la fosse, rien", 0.0001)
	# Les deux cobayes quittent le terrain avant la longue attente : arrives au
	# mage ils le tueraient, ce qui n a rien a voir avec la regle mesuree.
	for e in [lent, libre]:
		if is_instance_valid(e) and not e.is_dead():
			e.take_damage(1e9, [])
	for i in 60 * 60:
		bf.simulate(DT)
	eq(bf.prop_count(), 2, "une minute plus tard, les deux sont toujours la")
	ok(bf.damage_multiplier_at(Vector2(800.0, 900.0)) > 1.0, "et la fosse agit toujours")
	detach(bf)


# --- 7. Contrat du Briseur de terrain ---

## Chaque objet de terrain — accessoire, riviere ou mur — est dans le groupe
## `terrain_props` et expose `destroy()`, qui le retire comme s il etait abattu.
func _test_contrat_du_briseur_de_terrain() -> void:
	var bf := _field()
	bf.spawn_river(800.0)
	bf.spawn_prop(TerrainProp.Kind.TREE, Vector2(300, 500), 0.0, 100.0, 300.0)
	bf.spawn_prop(TerrainProp.Kind.BRAMBLE, Vector2(700, 1100), 0.0, 0.0)
	bf.spawn_wall(Vector2(540, 400), 120.0, 20.0, 60.0)
	bf.spawn_breakable_wall(Vector2(540, 1200), 120.0, 60.0, 80.0)
	var ancres: Array[Node] = bf.terrain_anchors()
	eq(ancres.size(), bf.props.size() + bf.walls.size(),
		"une ancre par objet de terrain, murs compris")
	# Le boss parcourra le GROUPE, pas `terrain_anchors()` : c est donc le groupe
	# qu on interroge, restreint a ce champ de bataille (une autre suite peut en
	# laisser un dans l arbre, ce n est pas l objet de cette regle).
	eq(_members_of(bf).size(), ancres.size(),
		"toutes dans le groupe '%s'" % TerrainProp.GROUP)
	for a in ancres:
		ok(a.has_method("destroy"), "chaque ancre expose destroy()")
	for a in _members_of(bf):
		a.destroy()
	eq(bf.props.size(), 0, "destroy() retire tous les accessoires")
	eq(bf.walls.size(), 0, "et tous les murs")
	eq(bf.nav.blocked_count(), 0, "la grille est entierement liberee")
	eq(_members_of(bf).size(), 0, "plus aucun membre du groupe")
	detach(bf)


func _members_of(bf: Battlefield) -> Array[Node]:
	var out: Array[Node] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group(TerrainProp.GROUP):
		if bf.is_ancestor_of(n):
			out.append(n)
	return out


# --- 8. Contenu livre ---

func _test_cartes_livrees() -> void:
	var ids: Array[StringName] = [&"terrain_river", &"terrain_altar",
		&"terrain_brambles", &"terrain_pit"]
	for id in ids:
		var c: SpellCard = _card(id)
		if c == null:
			continue
		ok(c.effects[0].duration <= 0.0, "%s reste jusqu a la fin du combat" % id)
		ok(c.description.find("fin du combat") >= 0 or c.description.find("abatte") >= 0,
			"%s le dit dans sa description" % id)
		ok(CardIcons.art_path(c) != "", "%s a son icone dediee" % id)
	var riv: SpellCard = ContentDB.cards.get(&"terrain_river")
	if riv != null:
		eq(riv.rarity, GameEnums.Rarity.LEGENDARY, "la riviere est legendaire")
		# « Dans le haut de la hierarchie » : plus longue que les trois quarts du
		# catalogue, lu dans le catalogue et non recopie.
		var plus_courtes: int = 0
		var total: int = 0
		for c2: SpellCard in ContentDB.cards.values():
			if c2.is_passive:
				continue
			total += 1
			if c2.base_cast_time < riv.base_cast_time:
				plus_courtes += 1
		ok(plus_courtes * 4 >= total * 3,
			"incantation longue : plus longue que %d cartes sur %d" % [plus_courtes, total])
	# Aucune de ces cartes n est rangee dans un deck de campagne (regle des six
	# cartes differentes, tenue par un autre chantier).
	for key in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[key]
		for c3 in lvl.exploration_deck:
			if c3 != null:
				not_ok(ids.has((c3 as SpellCard).id),
					"%s n est pas dans le deck de %s" % [(c3 as SpellCard).id, key])
