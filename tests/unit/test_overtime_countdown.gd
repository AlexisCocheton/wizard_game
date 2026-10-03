extends TestCase
## COMPTE A REBOURS DE LA VAGUE QUI TRAINE (vague 9). WaveSpawner.overtime_left()
## existait depuis la vague 8 sans qu aucun ecran ne l affiche. Le HUD le montre
## dans ses dernieres secondes seulement, en secondes REELLES.

func get_suite_name() -> String:
	return "overtime_countdown"


func run() -> void:
	_test_le_compte_n_apparait_qu_a_la_fin()
	_test_le_compte_est_en_secondes_reelles()
	_test_pas_de_compte_sur_la_derniere_vague()


func _campeur(id: String) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 100000.0
	d.base_speed = 0.0
	d.power = 1
	return d


func _vague(id: String, d: EnemyDef) -> WaveDef:
	var w := WaveDef.new()
	w.id = StringName(id)
	var e := WaveEntry.new()
	e.enemy = d
	e.count = 1
	var entrees: Array[WaveEntry] = [e]
	w.entries = entrees
	return w


## Une partie de deux vagues de campeurs : la premiere traine forcement.
func _partie(n_vagues: int) -> GameController:
	RunState.reset()
	SpeedGauge.reset()
	var lvl: LevelDef = (ContentDB.levels.get(&"lvl_01") as LevelDef).duplicate()
	var vagues: Array[WaveDef] = []
	for k in n_vagues:
		vagues.append(_vague("t_ot_%d" % k, _campeur("t_ot_campeur_%d" % k)))
	lvl.waves = vagues
	var g: GameController = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	g.headless_mode = true
	attach(g)
	g.start_level(lvl, GameEnums.Mode.EXPLORATION)
	g.running = false
	g.set_process(false)
	return g


## La fenetre d affichage lue dans le HUD (constante de script).
func _fenetre(hud: Node) -> float:
	return float((hud.get_script() as GDScript).get_script_constant_map().get(
		"OVERTIME_COUNTDOWN_SECONDS", 0.0))


func _hud(g: GameController) -> Node:
	return g.get_node_or_null("HUD")


## Avance jusqu a ce que le compte reel passe sous `seuil` (ou que la vague cede).
func _jusqu_a(g: GameController, hud: Node, seuil: float, vitesse: int) -> float:
	var reste: float = -1.0
	for i in 20000:
		SpeedGauge.set_speed_percent(vitesse)
		g.simulate(1.0 / 30.0)
		g.flush_freed()
		reste = float(hud.call("overtime_seconds_left"))
		if g.spawner.index > 0 or (reste > 0.0 and reste <= seuil):
			break
	return reste


func _test_le_compte_n_apparait_qu_a_la_fin() -> void:
	var g := _partie(2)
	var hud: Node = _hud(g)
	ok(hud != null, "la partie a un HUD")
	if hud == null:
		detach(g)
		return
	var fenetre: float = _fenetre(hud)
	ok(fenetre > 0.0, "le HUD a une fenetre d affichage")
	var reste: float = _jusqu_a(g, hud, fenetre * 2.0, 100)
	ok(reste > fenetre, "la vague traine encore loin du delai (%.1f s)" % reste)
	hud.call("_refresh_overtime_countdown")
	eq(String(hud.call("overtime_countdown_text")), "", "loin du delai, rien ne s affiche")
	reste = _jusqu_a(g, hud, fenetre * 0.5, 100)
	hud.call("_refresh_overtime_countdown")
	var texte: String = String(hud.call("overtime_countdown_text"))
	ok(texte != "", "dans les dernieres secondes, le compte s affiche")
	ok(texte.contains(str(int(ceilf(reste)))), "il dit les secondes qui restent (%s, %.1f)" % [texte, reste])
	detach(g)


## A x2, le delai de monde fond deux fois plus vite : le compte reel est moitie.
func _test_le_compte_est_en_secondes_reelles() -> void:
	var g := _partie(2)
	var hud: Node = _hud(g)
	if hud == null:
		detach(g)
		return
	var fenetre: float = _fenetre(hud)
	_jusqu_a(g, hud, fenetre, 100)
	SpeedGauge.set_speed_percent(100)
	var a_x1: float = float(hud.call("overtime_seconds_left"))
	SpeedGauge.set_speed_percent(200)
	var a_x2: float = float(hud.call("overtime_seconds_left"))
	ok(a_x1 > 0.0, "le compte court (%.2f s)" % a_x1)
	between(a_x2 / maxf(a_x1, 0.001), 0.49, 0.51,
		"a x2 il reste moitie moins de secondes reelles (%.2f contre %.2f)" % [a_x2, a_x1])
	detach(g)


## La derniere vague ne s ecourte pas : aucun compte ne doit promettre une suite.
func _test_pas_de_compte_sur_la_derniere_vague() -> void:
	var g := _partie(1)
	var hud: Node = _hud(g)
	if hud == null:
		detach(g)
		return
	for i in 60 * 30:
		SpeedGauge.set_speed_percent(100)
		g.simulate(1.0 / 30.0)
		g.flush_freed()
	feq(float(hud.call("overtime_seconds_left")), -1.0, "la derniere vague n a pas de compte")
	hud.call("_refresh_overtime_countdown")
	eq(String(hud.call("overtime_countdown_text")), "", "et rien ne s affiche")
	detach(g)
