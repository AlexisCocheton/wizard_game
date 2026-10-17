class_name W10SortsSmoke
extends RefCounted
## SMOKE / VISUAL des verbes de la vague 10 (chantier A1) : vent du sud, pluie
## abondante, marque electrique, sable mouvant, jet d eau en I, l ecran d une
## amelioration MAJEURE et l ecran « fais murir un sort de ta main ».
##
## En headless rien n est capture mais tout est construit et joue : c est ce qui
## attrape une SCRIPT ERROR de visuel (Fx est inerte en headless, l etage
## `visual` est le seul a executer le code des feuilles et des Tween). En
## fenetre reelle, les captures sont la seule facon de juger que l effet se LIT.
##
## Fichier a part du pilote (smoke_driver.gd ne porte qu une ligne d appel) :
## plusieurs chantiers touchent le pilote en parallele.

const DT: float = 1.0 / 60.0


static func run(driver: Node) -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		driver.call("_fail", "vitrine W10 : lvl_01 introuvable")
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	driver.add_child(g)
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false          # apres start_level (piege : start_level le remet)
	var bf: Battlefield = g.battlefield
	bf.clear_all()             # la vague du niveau ne doit pas se meler a la vitrine
	var tree: SceneTree = driver.get_tree()

	await _vitrine_vent_pluie(driver, g, bf, tree)
	bf.clear_all()
	await _vitrine_marque(driver, g, bf, tree)
	bf.clear_all()
	await _vitrine_sable_jet(driver, g, bf, tree)
	bf.clear_all()
	await _vitrine_majeure(driver, g, tree)
	await _vitrine_main_murit(driver, g, tree)
	g.queue_free()
	await tree.process_frame
	RunState.reset()
	SpeedGauge.reset()


## Un monstre du catalogue, copie et retouche : sa feuille d animation reste la
## sienne (la vitrine montre de vrais monstres), ses chiffres sont ceux de la scene.
static func _monstre(id: StringName, pv: float, vitesse: float) -> EnemyDef:
	var base: EnemyDef = ContentDB.enemies.get(id)
	var d: EnemyDef = base.duplicate() if base != null else EnemyDef.new()
	d.id = StringName("vitrine_w10_" + String(id))
	d.max_hp = pv
	d.base_speed = vitesse
	return d


static func _carte(id: String, key: StringName, el: int, fx: StringName,
		magnitude: float, duration: float, radius: float, params: Dictionary,
		cible: int = GameEnums.Targeting.POSITION) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.element = el
	c.fx_key = fx
	c.targeting = cible
	c.base_cast_time = 1.0
	var s := EffectSpec.new()
	s.key = key
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	c.effects = [s]
	return c


static func _lancer(g: GameController, c: SpellCard, ou: Vector2, cible: Enemy = null) -> void:
	var ctx := CastContext.make(g.battlefield, c)
	ctx.caster = g
	ctx.target_position = ou
	ctx.direction = Vector2.UP
	ctx.target_enemy = cible
	EffectRegistry.cast(c, ctx)


static func _simuler(bf: Battlefield, secondes: float) -> void:
	var t: float = 0.0
	while t < secondes:
		bf.simulate(DT)
		t += SpeedGauge.world_delta(DT)
		SpeedGauge.set_speed_percent(maxi(SpeedGauge.speed_percent, 150))


## VENT + PLUIE : un volant fige, un rapide ramene a la normale, la pluie partout.
static func _vitrine_vent_pluie(driver: Node, g: GameController, bf: Battlefield,
		tree: SceneTree) -> void:
	var volant: EnemyDef = _monstre(&"wisp", 500.0, 60.0)
	volant.flying = true
	var v: Enemy = bf.spawn_enemy(volant, 300.0, 1.0, Vector2(300, 500))
	var rapide: Enemy = bf.spawn_enemy(_monstre(&"rat_swarm", 500.0, 150.0), 760.0, 1.0,
		Vector2(760, 400))
	bf.spawn_enemy(_monstre(&"gnome", 500.0, 40.0), 540.0, 1.0, Vector2(540, 800))
	_lancer(g, _carte("vitrine_w10_vent", &"global_wind", GameEnums.DamageTag.WIND, &"flame_gust",
		0.0, 8.0, 0.0, {}, GameEnums.Targeting.NONE), Vector2(540, 700))
	_lancer(g, _carte("vitrine_w10_pluie", &"global_rain", GameEnums.DamageTag.WATER, &"orb_cyan",
		1.0, 8.0, 0.0, {&"interval": 0.5}, GameEnums.Targeting.NONE), Vector2(540, 700))
	var y_volant: float = v.position.y
	_simuler(bf, 2.0)
	if not bf.w10_wind_active() or bf.w10_rain_count() != 1:
		driver.call("_fail", "vitrine W10 : vent ou pluie absent")
	if absf(v.position.y - y_volant) > 0.01:
		driver.call("_fail", "vitrine W10 : le volant bouge sous le vent")
	if rapide.hp >= rapide.max_hp():
		driver.call("_fail", "vitrine W10 : la pluie n a pas mordu")
	await driver._laisser_jouer(0.5)
	await driver._shot("w10_vent_pluie")


## MARQUE : une file de monstres freles ; la capture tombe pendant la chaine.
static func _vitrine_marque(driver: Node, g: GameController, bf: Battlefield,
		tree: SceneTree) -> void:
	var frele: EnemyDef = _monstre(&"gnome", 6.0, 0.0)
	var file: Array[Enemy] = []
	for i in 4:
		file.append(bf.spawn_enemy(frele, 200.0 + i * 170.0, 1.0, Vector2(200.0 + i * 170.0, 700)))
	var gros: Enemy = bf.spawn_enemy(_monstre(&"golem", 500.0, 0.0), 540.0, 1.0, Vector2(540, 1000))
	var c: SpellCard = _carte("vitrine_w10_marque", &"electric_mark", GameEnums.DamageTag.LIGHTNING,
		&"lightning_web", 9.0, 0.0, 0.0, {&"jump_range": 260.0}, GameEnums.Targeting.TARGET)
	_lancer(g, c, file[0].position, file[0])
	# Une seconde marque, sur un monstre solide : son chiffre reste affiche.
	_lancer(g, c, gros.position, gros)
	_simuler(bf, GameConfig.MARK_JUMP_DELAY + 0.02)
	if bf.w10_mark_jumps_done < 1:
		driver.call("_fail", "vitrine W10 : la marque n a pas saute")
	await driver._laisser_jouer(0.15)
	await driver._shot("w10_marque")
	_simuler(bf, 1.0)
	# Les traits des sauts suivants s effacent en temps REEL : sans cette attente
	# ils restaient sur la capture suivante.
	await driver._laisser_jouer(0.6)


## SABLE + JET : une zone qui ralentit, une bande qui repousse.
static func _vitrine_sable_jet(driver: Node, g: GameController, bf: Battlefield,
		tree: SceneTree) -> void:
	for i in 3:
		bf.spawn_enemy(_monstre(&"gnome", 500.0, 50.0), 260.0 + i * 60.0, 1.0,
			Vector2(260.0 + i * 60.0, 650.0 + i * 40.0))
	var colonne: Array[Enemy] = []
	for i in 3:
		colonne.append(bf.spawn_enemy(_monstre(&"jelly", 500.0, 40.0), 780.0, 1.0,
			Vector2(780.0, 700.0 + i * 220.0)))
	_lancer(g, _carte("vitrine_w10_sable", &"quicksand", GameEnums.DamageTag.NATURE, &"bone_shards",
		30.0, 6.0, 170.0, {&"slow_pct": 60.0}), Vector2(320, 700))
	var y0: float = colonne[2].position.y
	_lancer(g, _carte("vitrine_w10_jet", &"water_jet", GameEnums.DamageTag.WATER, &"tide_waves",
		5.0, 0.0, 60.0, {&"length": 900.0, &"push": 260.0}), Vector2(780, 950))
	if colonne[2].position.y >= y0:
		driver.call("_fail", "vitrine W10 : le jet n a pas repousse")
	await driver._laisser_jouer(0.12)
	await driver._shot("w10_sable_jet")
	_simuler(bf, 0.5)


## L ECRAN DES MAJEURES : seconde maturation de la Fleche percante, avec SES
## deux majeures du contenu (C7b : les deux a l ecran, plus une voie) — l etat
## le plus haut de l ecran, celui ou un debordement se verrait en portrait.
static func _vitrine_majeure(driver: Node, g: GameController, tree: SceneTree) -> void:
	var fleche: SpellCard = ContentDB.cards.get(&"piercing_arrow")
	if fleche == null:
		driver.call("_fail", "vitrine W10 : piercing_arrow introuvable")
		return
	var garde: Array[MajorUpgradeDef] = fleche.major_upgrades.duplicate()
	RunState.reset()
	var pool: Array = RunState.upgrade_pool_for(fleche)
	if not pool.is_empty():
		RunState.upgrades_taken[fleche.id] = [StringName(pool[0]["id"])]
	var voies: Array = RunState.draw_upgrade_offer(fleche)
	var majeures: int = 0
	for v in voies:
		if bool((v as Dictionary).get("major", false)):
			majeures += 1
	if voies.size() != GameConfig.LEVEL_UP_CHOICES or majeures != 2:
		driver.call("_fail", "vitrine W10 : %d voies dont %d majeure(s)" % [voies.size(), majeures])
	var panel: CardUpgradePanel = g.call(&"_ensure_upgrade_panel")
	panel.show_paths(fleche, voies)
	await tree.process_frame
	if panel.size.y < 1600.0:
		driver.call("_fail", "vitrine W10 : l ecran de majeure ne couvre pas l ecran")
	# Deux majeures (260 px chacune) + une voie + le refus : tout doit TENIR dans
	# le portrait, le bouton GARDER TEL QUEL compris (sinon hors d atteinte).
	await tree.process_frame
	var garder: Control = panel.find_child("Garder", true, false) as Control
	var haut: Control = panel.find_child("Voie0", true, false) as Control
	if garder == null or haut == null:
		driver.call("_fail", "vitrine W10 : boutons de l ecran de majeure introuvables")
	elif garder.get_global_rect().end.y > panel.get_global_rect().end.y + 0.5 \
			or haut.get_global_rect().position.y < panel.get_global_rect().position.y - 0.5:
		driver.call("_fail", "vitrine W10 : deux majeures debordent du portrait (%s / %s)"
			% [haut.get_global_rect(), garder.get_global_rect()])
	await driver._shot("w10_amelioration_majeure")
	panel.visible = false
	fleche.major_upgrades = garde
	RunState.reset()


## L ECRAN « FAIS MURIR UN SORT » : une main de trois sorts du catalogue.
static func _vitrine_main_murit(driver: Node, g: GameController, tree: SceneTree) -> void:
	RunState.reset()
	for id in [&"fireball", &"frost_field", &"piercing_arrow"]:
		var c: SpellCard = ContentDB.cards.get(id)
		if c != null:
			RunState.hand.append(c)
	RunState.grant_card_xp(RunState.hand[0], 3)
	var panel: HandLevelPanel = g.call(&"_ensure_hand_level_panel")
	panel.show_choices(RunState.hand_level_candidates())
	await tree.process_frame
	if panel.listed_cards().size() != RunState.hand.size():
		driver.call("_fail", "vitrine W10 : l ecran de la main ne montre pas toute la main")
	await driver._shot("w10_main_murit")
	panel.visible = false
	RunState.reset()
