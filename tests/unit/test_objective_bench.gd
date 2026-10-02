extends TestCase
## LE BANC DES OBJECTIFS (tools/objective_bench.gd) : deterministe, et son bot
## VISE l objectif mesure (AutoPick.politique_pour).
##
## Pourquoi : la table MESURES de test_level_progression classe les 63 objectifs
## sur des taux de reussite mesures au banc. Deux defauts rendaient ces taux
## inverifiables :
##   - le banc n etait PAS deterministe : le spawner, la Pluie de meteores,
##     l esquive (et les allies, le pont d une riviere) tiraient au hasard SANS
##     la graine de la partie. Deux processus a graine egale rendaient des
##     nombres differents : on ne re-mesurait pas, on re-tirait ;
##   - la sonde qui jouait « en visant » l objectif avait ete supprimee.
##
## Un autre processus, c est : un autre etat du hasard GLOBAL de Godot, d autres
## instances. On le reproduit ici en re-semant le hasard global entre deux
## parties de meme graine : tout tirage qui lui echappe encore fait diverger les
## deux parties. Aucune valeur de reglage : tout se compare a soi-meme.

func get_suite_name() -> String:
	return "objective_bench"


const BANC_PATH: String = "res://tools/objective_bench.gd"
## Duree (temps de combat) des parties comparees : assez pour plusieurs vagues,
## des apparitions, des sorts, des offres ; pas une partie entiere.
const DUREE_PARTIE: float = 40.0
## Les cles dont la politique est le bot du banc TEL QUEL (voir le tableau en
## bas de scripts/game/auto_pick.gd). Toute autre cle doit en avoir une : une
## cle ajoutee au moteur sans politique documentee fait rougir ce test.
const NEUTRES: Array[StringName] = [
	&"never_dropped_speed", &"no_damage_taken", &"no_enemy_past",
	&"win_above_speed", &"win_under_time", &"multi_kill", &"win_below_speed",
]

var _bf: Battlefield = null
var _g: GameController = null


func run() -> void:
	_test_le_hasard_du_monde_suit_la_graine()
	_test_deux_parties_a_graine_egale()
	_test_chaque_cle_a_sa_politique()
	_test_le_contenu_livre_a_ses_politiques()
	_test_carte_interdite_jamais_jouee_ni_prise()
	_test_carte_demandee_jusqu_au_compte()
	_test_viser_d_abord_et_epargner()
	_test_jamais_une_garde_de_renvoi()
	_test_laisser_marcher_puis_viser()
	_test_zones_sur_l_espece()
	_test_politique_neutre_egale_le_bot_du_banc()
	_nettoyer()


func _nettoyer() -> void:
	if _bf != null:
		detach(_bf)
		_bf = null
	if _g != null:
		detach(_g)
		_g = null
	RunState.reset()


func _def(id: String, dodge: float = 0.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 1000000.0
	d.base_speed = 40.0
	d.power = 1
	d.base_radius = 30.0
	d.dodge_chance = dodge
	return d


# --- 1. Le hasard du monde --------------------------------------------------

## Tous les tirages du MONDE pour une graine de partie, apres avoir mis le
## hasard global dans l etat `autre_processus`.
func _monde(graine: int, autre_processus: int) -> String:
	seed(autre_processus * 104729 + 17)
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()
	RunState.set_seed(graine)
	var out: PackedStringArray = []
	# Couloirs et cotes d apparition : un spawner SANS graine explicite, comme
	# celui d une partie.
	var sp := WaveSpawner.new()
	var vide: Array[WaveDef] = []
	sp.setup(_bf, vide)
	var normal := _def("normal")
	var cote := _def("cote")
	cote.entry_side = true
	for i in 6:
		out.append("x%.2f" % sp._spawn_x(normal))
		out.append("c%.2f" % sp._spawn_x(cote))
		out.append("l%.2f" % sp._spawn_x(normal, GameConfig.BATTLEFIELD_WIDTH * 0.5))
	sp.free()
	# Esquive.
	var e: Enemy = _bf.spawn_enemy(_def("esquive", 0.5), 540.0, 1.0, Vector2(540.0, 600.0))
	for i in 24:
		out.append("e%d" % int(e.take_damage(1.0, [])))
	# Pluie de meteores.
	var pluie: SpellCard = _carte_avec(&"meteor_storm")
	ok(pluie != null, "le catalogue a une Pluie de meteores")
	if pluie != null:
		var ctx := CastContext.make(_bf, pluie)
		ctx.target_position = Vector2(540.0, 800.0)
		EffectRegistry.cast(pluie, ctx)
		for z: Dictionary in _bf.zones:
			out.append("z%.2f,%.2f" % [z["pos"].x, z["pos"].y])
	# Allies invoques, devant le mage puis pres d un autel.
	_bf.spawn_ally(5.0, 1.0)
	_bf.spawn_ally(5.0, 1.0, Vector2(300.0, 1200.0))
	for a: Dictionary in _bf.allies:
		out.append("a%.2f,%.2f" % [a["pos"].x, a["pos"].y])
	# Pont d une riviere posee par un sort (sans generateur fourni).
	var riviere: TerrainProp = _bf.spawn_river(900.0)
	out.append("r%d" % (riviere.bridge_col if riviere != null else -1))
	return ",".join(out)


func _carte_avec(cle: StringName) -> SpellCard:
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c != null and cle in c.effect_keys():
			return c
	return null


func _test_le_hasard_du_monde_suit_la_graine() -> void:
	var a: String = _monde(4242, 1)
	var b: String = _monde(4242, 2)
	eq(b, a, "meme graine de partie, autre hasard global : meme monde")
	# Le test mord : une autre graine donne un autre monde. Sans cela, une
	# empreinte vide ou constante passerait la comparaison ci-dessus.
	var c: String = _monde(4243, 1)
	ok(c != a, "une autre graine de partie donne un autre monde")
	# Et chaque famille de tirages differe bien d une graine a l autre : une
	# famille figee (tirage oublie, generateur constant) ne serait pas vue.
	for prefixe: String in ["x", "c", "l", "e", "z", "a"]:
		ok(_famille(a, prefixe) != _famille(c, prefixe),
			"les tirages « %s » dependent de la graine" % prefixe)


func _famille(monde: String, prefixe: String) -> String:
	var out: PackedStringArray = []
	for p in monde.split(","):
		if p.begins_with(prefixe):
			out.append(p)
	return ",".join(out)


# --- 2. Deux parties completes ------------------------------------------------

func _partie(graine: int, autre_processus: int, p: AutoPick.Politique) -> Dictionary:
	seed(autre_processus * 104729 + 17)
	if _g != null:
		detach(_g)
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	_g = packed.instantiate()
	_g.headless_mode = true
	attach(_g)
	_g.set_process(false)
	_g.set_physics_process(false)
	RunState.set_seed(graine)
	_g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	var banc: GDScript = load(BANC_PATH)
	return banc.play_game(_g, p, DUREE_PARTIE)


func _test_deux_parties_a_graine_egale() -> void:
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(lv != null, "lvl_01 existe")
	if lv == null:
		return
	var banc: GDScript = load(BANC_PATH)
	ok(banc != null and banc.can_instantiate(), "le banc des objectifs compile")
	if banc == null or not banc.can_instantiate():
		return
	var graine: int = banc.graine_de(0, 0)
	var r1: Dictionary = _partie(graine, 1, null)
	var r2: Dictionary = _partie(graine, 2, null)
	eq(r2["empreinte"], r1["empreinte"], "bot du banc : meme graine, meme partie")
	ok(float(r1["temps"]) > 0.0, "la partie a bien ete jouee")
	var r3: Dictionary = _partie(banc.graine_de(0, 1), 1, null)
	ok(r3["empreinte"] != r1["empreinte"], "une autre graine joue une autre partie")
	# Avec une politique orientee : les memes garanties.
	var p: AutoPick.Politique = null
	for o: ObjectiveDef in lv.objectives:
		var q: AutoPick.Politique = AutoPick.politique_pour(o, lv)
		if not q.neutre():
			p = q
			break
	ok(p != null, "lvl_01 a un objectif a politique orientee")
	if p != null:
		var o1: Dictionary = _partie(graine, 1, p)
		var o2: Dictionary = _partie(graine, 2, p)
		eq(o2["empreinte"], o1["empreinte"], "bot oriente : meme graine, meme partie")
	detach(_g)
	_g = null
	RunState.reset()


# --- 3. Une politique par cle -------------------------------------------------

## Un objectif synthetique de la cle, ses parametres remplis d apres le SCHEMA.
func _objectif(cle: StringName, lv: LevelDef) -> ObjectiveDef:
	var o := ObjectiveDef.new()
	o.id = StringName("t_%s" % cle)
	o.check_key = cle
	var schema: Dictionary = ObjectiveChecker.SCHEMA.get(cle, {})
	var especes: Array[EnemyDef] = ObjectiveChecker.level_enemies(lv)
	var params: Dictionary = {}
	for nom in schema:
		match String(schema[nom]):
			ObjectiveChecker.T_INT:
				params[nom] = 2
			ObjectiveChecker.T_NUM:
				params[nom] = 100.0 if nom != "ratio" and nom != "window" else 0.5
			ObjectiveChecker.T_TAG, ObjectiveChecker.T_ELEM:
				params[nom] = "FIRE"
			ObjectiveChecker.T_EFFECT:
				params[nom] = "damage_single"
			ObjectiveChecker.T_CARD:
				params[nom] = String(lv.exploration_deck[0].id)
			ObjectiveChecker.T_ENEMY:
				params[nom] = String(especes[0].id) if not especes.is_empty() else "x"
	o.params = params
	return o


func _test_chaque_cle_a_sa_politique() -> void:
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	if lv == null:
		return
	for cle: StringName in ObjectiveChecker.KEYS:
		var p: AutoPick.Politique = AutoPick.politique_pour(_objectif(cle, lv), lv)
		eq(p.neutre(), NEUTRES.has(cle),
			"%s : %s" % [cle, "bot tel quel, documente" if NEUTRES.has(cle)
				else "une politique qui vise l objectif"])
		ok(p.resume != "", "%s : la politique se resume au rapport" % cle)
	for cle: StringName in NEUTRES:
		ok(cle in ObjectiveChecker.KEYS, "%s est une cle du moteur" % cle)


## Chaque objectif LIVRE a sa politique : le banc les mesure tous.
func _test_le_contenu_livre_a_ses_politiques() -> void:
	var n: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		for o: ObjectiveDef in lv.objectives:
			if o == null:
				continue
			n += 1
			var p: AutoPick.Politique = AutoPick.politique_pour(o, lv)
			var attendu: bool = NEUTRES.has(o.check_key) \
				or (o.check_key == &"enemy_travel" and not o.params.has("enemy"))
			eq(p.neutre(), attendu, "%s / %s : politique %s" % [lv.id, o.id, p.resume])
	ok(n > 0, "des objectifs livres")


# --- 4. Ce que fait chaque politique ------------------------------------------

## Une partie a l arret, terrain vide, main videe : on pose ce qu on veut.
func _partie_vide() -> GameController:
	if _g != null:
		detach(_g)
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	_g = packed.instantiate()
	_g.headless_mode = true
	attach(_g)
	_g.set_process(false)
	_g.set_physics_process(false)
	RunState.set_seed(77)
	_g.start_level(ContentDB.levels.get(&"lvl_01"), GameEnums.Mode.EXPLORATION)
	_g.running = false
	_g.battlefield.clear_all()
	RunState.hand.clear()
	return _g


## Deux sorts differents du deck de lvl_01.
func _deux_sorts() -> Array[SpellCard]:
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	var out: Array[SpellCard] = []
	for c: SpellCard in lv.exploration_deck:
		if c != null and not c.is_passive and (out.is_empty() or out[0].id != c.id):
			out.append(c)
		if out.size() == 2:
			break
	return out


func _test_carte_interdite_jamais_jouee_ni_prise() -> void:
	var g: GameController = _partie_vide()
	var s: Array[SpellCard] = _deux_sorts()
	var x: SpellCard = s[0]
	var y: SpellCard = s[1]
	var o := ObjectiveDef.new()
	o.check_key = &"no_card"
	o.params = {"card": String(x.id)}
	var p: AutoPick.Politique = AutoPick.politique_pour(o, ContentDB.levels.get(&"lvl_01"))
	RunState.hand.append_array([x, y, x])
	var ordre: Array[SpellCard] = AutoPick.hand_order(g, p)
	not_ok(ordre.has(x), "la carte interdite n est jamais essayee")
	ok(ordre.has(y), "les autres le sont")
	eq(AutoPick.hand_order(g, null).size(), RunState.hand.size(), "sans politique, toute la main")
	eq(AutoPick.offer_index_for([x, y], [], p), 1, "a la montee, il prend l autre carte")
	eq(AutoPick.offer_index_for([y, x], [], p), 0, "quel que soit l ordre de l offre")
	eq(AutoPick.offer_index_for([x], [], p), 0, "sans autre choix, il la prend quand meme")


func _test_carte_demandee_jusqu_au_compte() -> void:
	var g: GameController = _partie_vide()
	var s: Array[SpellCard] = _deux_sorts()
	var x: SpellCard = s[0]
	var y: SpellCard = s[1]
	var compte: int = 2
	var o := ObjectiveDef.new()
	o.id = &"t_casts"
	o.check_key = &"card_casts"
	o.params = {"card": String(x.id), "count": compte}
	ok(ObjectiveChecker.validate(o).is_empty(), "objectif de test valide")
	var p: AutoPick.Politique = AutoPick.politique_pour(o, ContentDB.levels.get(&"lvl_01"))
	RunState.hand.append_array([y, y, x])
	eq(AutoPick.hand_order(g, p)[0], x, "la carte demandee est essayee d abord")
	eq(AutoPick.offer_index_for([y, x], [], p), 1, "et prise a la montee")
	for i in compte:
		RunState.note_cast(x)
	eq(AutoPick.hand_order(g, p)[0], y, "le compte fait, il rejoue dans l ordre de la main")


func _test_viser_d_abord_et_epargner() -> void:
	var g: GameController = _partie_vide()
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	var avance: Enemy = g.battlefield.spawn_enemy(_def("avance"), 300.0, 1.0, Vector2(300.0, 1100.0))
	var loin: Enemy = g.battlefield.spawn_enemy(_def("loin"), 700.0, 1.0, Vector2(700.0, 500.0))
	eq(AutoPick.choose_target(g, null), avance, "sans politique : le plus avance")
	var o := ObjectiveDef.new()
	o.check_key = &"no_hit_from"
	o.params = {"enemy": "loin"}
	eq(AutoPick.choose_target(g, AutoPick.politique_pour(o, lv)), loin,
		"no_hit_from : l espece qui ne doit pas toucher, d abord")
	var h := ObjectiveDef.new()
	h.id = &"t_hit"
	h.check_key = &"hit_from"
	h.params = {"enemy": "avance"}
	var ph: AutoPick.Politique = AutoPick.politique_pour(h, lv)
	eq(AutoPick.choose_target(g, ph), loin, "hit_from : l espece dont le coup est requis vit")
	ok(ph.zone_mord_un_epargne(g, avance.position, 60.0), "et aucune zone ne la mord")
	g.battlefield.clear_all()
	g.battlefield.spawn_enemy(_def("avance"), 300.0, 1.0, Vector2(300.0, 1100.0))
	eq(AutoPick.choose_target(g, ph), null, "seule sur le terrain, il ne la frappe pas")


func _test_jamais_une_garde_de_renvoi() -> void:
	var g: GameController = _partie_vide()
	var d_garde := _def("garde")
	d_garde.reflect_pct = 50.0
	var garde: Enemy = g.battlefield.spawn_enemy(d_garde, 300.0, 1.0, Vector2(300.0, 1100.0))
	var autre: Enemy = g.battlefield.spawn_enemy(_def("autre"), 700.0, 1.0, Vector2(700.0, 500.0))
	garde.force_reflect_window(5.0)
	ok(garde.is_reflecting(), "garde levee")
	var o := ObjectiveDef.new()
	o.check_key = &"never_hit_reflect"
	var p: AutoPick.Politique = AutoPick.politique_pour(o, ContentDB.levels.get(&"lvl_01"))
	eq(AutoPick.choose_target(g, p), autre, "il ne vise pas une garde levee")
	ok(p.zone_mord_un_epargne(g, garde.position, 60.0), "ni ne pose de zone dessus")
	not_ok(p.zone_mord_un_epargne(g, autre.position, 60.0), "ailleurs, la zone part")


func _test_laisser_marcher_puis_viser() -> void:
	var g: GameController = _partie_vide()
	var marcheur: Enemy = g.battlefield.spawn_enemy(_def("marcheur"), 700.0, 1.0, Vector2(700.0, 500.0))
	var avance: Enemy = g.battlefield.spawn_enemy(_def("devant"), 300.0, 1.0, Vector2(300.0, 1100.0))
	var distance: float = ObjectiveChecker.terrain_length()
	var o := ObjectiveDef.new()
	o.id = &"t_travel"
	o.check_key = &"enemy_travel"
	o.params = {"enemy": "marcheur", "distance": distance}
	var p: AutoPick.Politique = AutoPick.politique_pour(o, ContentDB.levels.get(&"lvl_01"))
	marcheur.set_meta(RunState.TRAVEL_META, distance * 0.5)
	ok(p.epargne(marcheur), "chemin pas fait : il le laisse marcher")
	eq(AutoPick.choose_target(g, p), avance, "et vise ailleurs")
	marcheur.set_meta(RunState.TRAVEL_META, distance)
	not_ok(p.epargne(marcheur), "chemin fait : plus epargne")
	eq(AutoPick.choose_target(g, p), marcheur, "il le vise d abord, meme moins avance")


func _test_zones_sur_l_espece() -> void:
	var g: GameController = _partie_vide()
	var gros := Vector2(300.0, 1000.0)
	var petit := Vector2(800.0, 600.0)
	for i in 3:
		g.battlefield.spawn_enemy(_def("foule"), gros.x, 1.0, gros + Vector2(i * 10.0, 0.0))
	for i in 2:
		g.battlefield.spawn_enemy(_def("visee"), petit.x, 1.0, petit + Vector2(i * 10.0, 0.0))
	var r: float = 80.0
	ok(AutoPick.best_cluster(g, r, Vector2.ZERO).distance_to(gros) <= r,
		"sans politique : le plus gros groupe")
	var o := ObjectiveDef.new()
	o.id = &"t_one"
	o.check_key = &"kill_type_one_cast"
	o.params = {"enemy": "visee", "count": 2}
	var p: AutoPick.Politique = AutoPick.politique_pour(o, ContentDB.levels.get(&"lvl_01"))
	ok(AutoPick.best_cluster(g, r, Vector2.ZERO, false, p).distance_to(petit) <= r,
		"kill_type_one_cast : la zone tombe sur le groupe de l espece")


func _test_politique_neutre_egale_le_bot_du_banc() -> void:
	var g: GameController = _partie_vide()
	var lv: LevelDef = ContentDB.levels.get(&"lvl_01")
	var o := ObjectiveDef.new()
	o.check_key = &"multi_kill"
	o.params = {"count": 3, "window": 1.0}
	var p: AutoPick.Politique = AutoPick.politique_pour(o, lv)
	ok(p.neutre(), "multi_kill : bot tel quel")
	var s: Array[SpellCard] = _deux_sorts()
	RunState.hand.append_array([s[1], s[0]])
	eq(AutoPick.hand_order(g, p), AutoPick.hand_order(g, null), "meme ordre de main")
	eq(AutoPick.offer_index_for(s, [], p), AutoPick.offer_index(s, []), "meme carte a la montee")
	var a: Enemy = g.battlefield.spawn_enemy(_def("a"), 300.0, 1.0, Vector2(300.0, 900.0))
	g.battlefield.spawn_enemy(_def("b"), 700.0, 1.0, Vector2(700.0, 500.0))
	eq(AutoPick.choose_target(g, p), a, "meme cible")
