extends Node
## Generateur de contenu de depart. Ecrit les .tres via ResourceSaver pour garantir
## un format valide. A relancer apres modification du schema des Resources.

func _ready() -> void:
	await get_tree().process_frame
	_enemies()
	_cards()
	_waves_and_level()
	print("CONTENT_OK")
	get_tree().quit(0)


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		printerr("Echec ecriture %s (err %d)" % [path, err])
	else:
		print("  ecrit ", path)


func _enemy(id: String, dname: String, kind: GameEnums.EnemyKind, power: int,
		hp: float, speed: float, xp: int, shape: GameEnums.Shape, color: Color,
		radius: float = 28.0) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = StringName(id)
	e.display_name = dname
	e.kind = kind
	e.power = power
	e.max_hp = hp
	e.base_speed = speed
	e.base_xp = xp
	e.shape = shape
	e.color = color
	e.base_radius = radius
	return e


## Hierarchie : puissance 1 (chair a canon) -> 4 (menace), boss hors budget.
## Chaque famille a SA forme et SA couleur pour etre reconnue immediatement.
func _enemies() -> void:
	var K := GameEnums.EnemyKind
	var S := GameEnums.Shape
	var E := "res://resources/enemies/"

	# --- Puissance 1 ---
	var gnome := _enemy("gnome", "Gnome", K.NORMAL, 1, 12.0, 70.0, 1, S.SQUARE, Color(0.62, 0.42, 0.28), 26.0)
	gnome.anim_key = &"pawn_red"
	_save(gnome, E + "gnome.tres")

	var sprite := _enemy("sprite", "Lutin fileur", K.FAST, 1, 6.0, 150.0, 1, S.TRIANGLE, Color(0.98, 0.82, 0.30), 18.0)
	sprite.anim_key = &"pawn_yellow"
	_save(sprite, E + "sprite.tres")

	var jelly_small := _enemy("jelly_small", "Gelee (petite)", K.SPLITTER, 1, 6.0, 85.0, 1, S.CIRCLE, Color(0.55, 0.92, 0.45), 12.0)
	jelly_small.anim_key = &"blood"
	_save(jelly_small, E + "jelly_small.tres")

	var jelly_mid := _enemy("jelly_mid", "Gelee (moyenne)", K.SPLITTER, 1, 14.0, 65.0, 1, S.CIRCLE, Color(0.50, 0.88, 0.42), 20.0)
	jelly_mid.anim_key = &"blood"
	jelly_mid.split_into = jelly_small
	jelly_mid.split_count = 2
	_save(jelly_mid, E + "jelly_mid.tres")

	# --- Puissance 2 ---
	var swarm := _enemy("rat_swarm", "Nuee de rats", K.SWARM, 2, 4.0, 110.0, 1, S.CIRCLE, Color(0.85, 0.52, 0.62), 13.0)
	swarm.anim_key = &"pawn_black"
	swarm.swarm_count = 4
	_save(swarm, E + "rat_swarm.tres")

	var wisp := _enemy("wisp", "Feu follet", K.EVASIVE, 2, 10.0, 90.0, 2, S.CIRCLE, Color(0.45, 0.90, 0.88), 22.0)
	wisp.anim_key = &"demon"
	wisp.dodge_chance = 0.35
	_save(wisp, E + "wisp.tres")

	var shade := _enemy("shade", "Ombre", K.PHASER, 2, 16.0, 80.0, 3, S.DIAMOND, Color(0.42, 0.40, 0.80), 26.0)
	shade.anim_key = &"demon"
	shade.phase_interval = 2.5
	_save(shade, E + "shade.tres")

	var archer := _enemy("imp_archer", "Lutin archer", K.SHOOTER, 2, 14.0, 48.0, 3, S.DIAMOND, Color(0.90, 0.32, 0.28), 24.0)
	archer.anim_key = &"archer_red"
	archer.shoot_interval = 3.5
	archer.shot_damage = 1
	_save(archer, E + "imp_archer.tres")

	var serpent := _enemy("sand_serpent", "Serpent des sables", K.WAVER, 2, 20.0, 75.0, 2, S.CAPSULE, Color(0.32, 0.72, 0.68), 24.0)
	serpent.anim_key = &"lancer_yellow"
	serpent.wave_amplitude = 170.0
	serpent.wave_frequency = 0.55
	_save(serpent, E + "sand_serpent.tres")

	var hopper := _enemy("hopper", "Sauterelle", K.BURSTER, 2, 10.0, 95.0, 2, S.TRIANGLE, Color(0.55, 0.85, 0.30), 20.0)
	hopper.anim_key = &"pawn_purple"
	hopper.burst_move = true
	hopper.burst_dash_time = 0.5
	hopper.burst_pause_time = 0.8
	_save(hopper, E + "hopper.tres")

	# --- Puissance 3 ---
	var horn := _enemy("hornblower", "Corniste", K.BUFFER, 3, 18.0, 55.0, 3, S.HEXAGON, Color(0.92, 0.60, 0.25), 28.0)
	horn.anim_key = &"monk_purple"
	horn.entry_side = true
	horn.buff_speed_pct = 20.0
	_save(horn, E + "hornblower.tres")

	var golem := _enemy("golem", "Golem de pierre", K.TANK, 3, 55.0, 32.0, 4, S.SQUARE, Color(0.50, 0.50, 0.56), 40.0)
	golem.anim_key = &"warrior_black"
	golem.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(golem, E + "golem.tres")

	var berserker := _enemy("berserker", "Berserker", K.ENRAGER, 3, 30.0, 58.0, 4, S.SQUARE, Color(0.70, 0.15, 0.18), 30.0)
	berserker.anim_key = &"warrior_red"
	berserker.enrage_speed_pct = 12.0
	berserker.enrage_cap = 1.5
	_save(berserker, E + "berserker.tres")

	var knight := _enemy("void_knight", "Chevalier du vide", K.SHIELDED, 3, 34.0, 55.0, 4, S.HEXAGON, Color(0.55, 0.35, 0.85), 30.0)
	knight.anim_key = &"lancer_purple"
	knight.first_hit_shield = true
	_save(knight, E + "void_knight.tres")

	var jelly := _enemy("jelly", "Gelee", K.SPLITTER, 3, 36.0, 50.0, 3, S.CIRCLE, Color(0.45, 0.85, 0.40), 32.0)
	jelly.anim_key = &"blood"
	jelly.split_into = jelly_mid
	jelly.split_count = 2
	_save(jelly, E + "jelly.tres")

	var priest := _enemy("ghoul_priest", "Pretre goule", K.HEALER, 3, 24.0, 45.0, 5, S.STAR, Color(0.78, 0.95, 0.72), 28.0)
	priest.anim_key = &"monk_black"
	priest.heal_per_second = 3.0
	_save(priest, E + "ghoul_priest.tres")

	var hive := _enemy("hive", "Ruche", K.BOMBER, 3, 40.0, 40.0, 4, S.HEXAGON, Color(0.95, 0.72, 0.20), 34.0)
	hive.anim_key = &"warrior_yellow"
	hive.split_into = sprite
	hive.split_count = 4
	_save(hive, E + "hive.tres")

	# --- Puissance 4 ---
	var totem := _enemy("totem_guardian", "Gardien-totem", K.GUARDIAN, 4, 60.0, 30.0, 8, S.STAR, Color(0.85, 0.70, 0.35), 36.0)
	totem.anim_key = &"totem_tower"
	totem.aura_shield_radius = 240.0
	_save(totem, E + "totem_guardian.tres")

	var glutton := _enemy("glutton", "Glouton", K.DEVOURER, 4, 70.0, 42.0, 8, S.CIRCLE, Color(0.60, 0.25, 0.60), 38.0)
	glutton.anim_key = &"blood"
	glutton.devours = true
	_save(glutton, E + "glutton.tres")

	var behemoth := _enemy("behemoth", "Behemoth", K.TANK, 4, 130.0, 26.0, 9, S.SQUARE, Color(0.36, 0.34, 0.40), 52.0)
	behemoth.anim_key = &"warrior_black"
	behemoth.contact_damage = 2
	behemoth.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(behemoth, E + "behemoth.tres")

	# --- Boss (hors budget) ---
	var warden := _enemy("warden", "Gardien", K.MINIBOSS, 6, 140.0, 40.0, 12, S.HEXAGON, Color(0.90, 0.40, 0.25), 62.0)
	warden.anim_key = &"lancer_red"
	_save(warden, E + "warden.tres")

	var chronos := _enemy("chronos", "Chronos", K.BOSS, 10, 320.0, 34.0, 30, S.STAR, Color(0.95, 0.20, 0.25), 84.0)
	chronos.anim_key = &"demon"
	chronos.contact_damage = 2
	chronos.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(chronos, E + "chronos.tres")


func _spec(key: String, magnitude: float, duration: float = 0.0,
		radius: float = 0.0, params: Dictionary = {}) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = StringName(key)
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	return s


func _card(id: String, dname: String, desc: String, rarity: GameEnums.Rarity,
		cast_time: float, targeting: GameEnums.Targeting,
		tags: Array[GameEnums.DamageTag], effects: Array[EffectSpec],
		copies: int = 0) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = dname
	c.description = desc
	c.rarity = rarity
	c.base_cast_time = cast_time
	c.targeting = targeting
	c.tags = tags
	c.effects = effects
	c.copies_in_starter = copies
	return c


func _cards() -> void:
	# --- Communes (deck de depart) ---
	var bolt := _card("arcane_bolt", "Trait arcanique",
		"Inflige 14 degats a une cible.", GameEnums.Rarity.COMMON, 1.6,
		GameEnums.Targeting.TARGET, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_single", 14.0)], 4)
	_save(bolt, "res://resources/cards/common/arcane_bolt.tres")

	var pierce := _card("piercing_arrow", "Fleche percante",
		"Traverse jusqu a 5 ennemis en ligne, 10 degats chacun.",
		GameEnums.Rarity.COMMON, 2.2, GameEnums.Targeting.DIRECTION,
		[GameEnums.DamageTag.PHYSICAL],
		[_spec("pierce_line", 10.0, 0.0, 120.0, {&"max_targets": 5})], 3)
	_save(pierce, "res://resources/cards/common/piercing_arrow.tres")

	var frost := _card("frost_field", "Champ de givre",
		"Zone qui ralentit de 50 pourcent pendant 5 s.", GameEnums.Rarity.COMMON, 2.0,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 5.0, 180.0, {&"slow_pct": 50.0})], 3)
	_save(frost, "res://resources/cards/common/frost_field.tres")

	var ember := _card("ember_pool", "Braises",
		"Zone infligeant 8 degats par seconde pendant 4 s.", GameEnums.Rarity.COMMON, 2.4,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 8.0, 4.0, 160.0)], 2)
	_save(ember, "res://resources/cards/common/ember_pool.tres")

	var fireball := _card("fireball", "Boule de feu",
		"Explosion de 26 degats dans une zone visee.", GameEnums.Rarity.COMMON, 2.0,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 26.0, 0.6, 170.0)], 2)
	_save(fireball, "res://resources/cards/common/fireball.tres")

	# --- Rares ---
	var haste := _card("quickening", "Precipitation",
		"Accelere l incantation de 60 pourcent pendant 6 s.", GameEnums.Rarity.RARE, 1.2,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("self_haste", 60.0, 6.0)])
	_save(haste, "res://resources/cards/rare/quickening.tres")

	var drag := _card("temporal_drag", "Entrave temporelle",
		"Ralentit tous les ennemis de 40 pourcent pendant 5 s.", GameEnums.Rarity.RARE, 2.0,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SLOW],
		[_spec("slow_enemy_gauge", 40.0, 5.0)])
	_save(drag, "res://resources/cards/rare/temporal_drag.tres")

	var cycle := _card("cycle_of_thought", "Cycle de pensee",
		"Defausse 2 cartes, en pioche 2.", GameEnums.Rarity.RARE, 0.8,
		GameEnums.Targeting.NONE, [],
		[_spec("discard_draw", 0.0, 0.0, 0.0, {&"count": 2})])
	_save(cycle, "res://resources/cards/rare/cycle_of_thought.tres")

	var wall := _card("stone_wall", "Mur de pierre",
		"Erige un mur qui force les monstres a le contourner pendant 8 s.",
		GameEnums.Rarity.RARE, 1.8, GameEnums.Targeting.POSITION, [],
		[_spec("build_wall", 0.0, 8.0, 200.0, {&"thickness": 60.0})])
	_save(wall, "res://resources/cards/rare/stone_wall.tres")

	# --- Epiques ---
	var ally := _card("mirror_apprentice", "Apprenti miroir",
		"Invoque un allie qui frappe pour 12 pendant 8 s.", GameEnums.Rarity.EPIC, 2.6,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SUMMON],
		[_spec("summon_ally", 12.0, 8.0)])
	_save(ally, "res://resources/cards/epic/mirror_apprentice.tres")

	var focus := _card("deep_focus", "Concentration",
		"Defausse ta main : moins 1 s d incantation par carte, 8 s.",
		GameEnums.Rarity.EPIC, 1.0, GameEnums.Targeting.NONE, [],
		[_spec("discard_hand_for_speed", 0.0, 8.0, 0.0, {&"seconds_per_card": 1.0})])
	_save(focus, "res://resources/cards/epic/deep_focus.tres")

	var bargain := _card("reckless_bargain", "Pacte imprudent",
		"Accelere les ennemis de 30 pourcent pendant 5 s, pioche 3 cartes.",
		GameEnums.Rarity.EPIC, 1.0, GameEnums.Targeting.NONE, [],
		[_spec("haste_enemies_boon", 30.0, 5.0, 0.0, {&"draw": 3})])
	_save(bargain, "res://resources/cards/epic/reckless_bargain.tres")

	var purge := _card("deck_purge", "Epuration",
		"Retire 2 cartes du deck.", GameEnums.Rarity.EPIC, 1.4,
		GameEnums.Targeting.NONE, [],
		[_spec("remove_cards", 0.0, 0.0, 0.0, {&"count": 2})])
	_save(purge, "res://resources/cards/epic/deck_purge.tres")

	# --- Legendaire ---
	var rift := _card("time_rift", "Faille temporelle",
		"Reduit le cout des cartes de 1.5 s pendant 10 s et frappe en ligne.",
		GameEnums.Rarity.LEGENDARY, 2.8, GameEnums.Targeting.DIRECTION,
		[GameEnums.DamageTag.ARCANE],
		[
			_spec("cost_reduction", 1.5, 10.0),
			_spec("pierce_line", 40.0, 0.0, 200.0, {&"max_targets": 99}),
		])
	_save(rift, "res://resources/cards/legendary/time_rift.tres")

	# --- Variete : cast court/long, petite/grande zone, court/long effet ---
	var spark := _card("spark", "Etincelle",
		"8 degats sur une cible. Rapide a lancer.", GameEnums.Rarity.COMMON, 0.8,
		GameEnums.Targeting.TARGET, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_single", 8.0)], 2)
	_save(spark, "res://resources/cards/common/spark.tres")

	var frost_rain := _card("frost_rain", "Pluie de givre",
		"Tres grande zone qui ralentit de 30 pourcent pendant 8 s.", GameEnums.Rarity.COMMON, 2.6,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 8.0, 260.0, {&"slow_pct": 30.0})])
	_save(frost_rain, "res://resources/cards/common/frost_rain.tres")

	var brazier := _card("brazier", "Brasier",
		"Zone de feu : 14 degats par seconde pendant 6 s.", GameEnums.Rarity.RARE, 3.0,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 14.0, 6.0, 140.0)])
	_save(brazier, "res://resources/cards/rare/brazier.tres")

	var meteor := _card("meteor", "Meteore",
		"Long a invoquer, mais 60 degats d un coup dans une petite zone.", GameEnums.Rarity.RARE, 4.0,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.PHYSICAL],
		[_spec("ground_zone", 200.0, 0.3, 120.0)])
	_save(meteor, "res://resources/cards/rare/meteor.tres")

	var about_face := _card("about_face", "Volte-face",
		"Tous les monstres font demi-tour pendant 3 s.", GameEnums.Rarity.RARE, 1.5,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("reverse_enemies", 0.0, 3.0)])
	_save(about_face, "res://resources/cards/rare/about_face.tres")

	var focalisation := _card("focus", "Focalisation",
		"Le prochain sort inflige le double de degats.", GameEnums.Rarity.RARE, 1.0,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("empower_next", 2.0)])
	_save(focalisation, "res://resources/cards/rare/focus.tres")

	var deep_freeze := _card("deep_freeze", "Gel profond",
		"Zone qui ralentit de 85 pourcent pendant 4 s. Presque un arret.", GameEnums.Rarity.EPIC, 2.2,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 4.0, 170.0, {&"slow_pct": 85.0})])
	_save(deep_freeze, "res://resources/cards/epic/deep_freeze.tres")

	var weakness := _card("weakness_mark", "Marque de faiblesse",
		"Zone ou les monstres subissent le double de degats pendant 6 s.", GameEnums.Rarity.EPIC, 1.8,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.ARCANE],
		[_spec("ground_zone", 0.0, 6.0, 200.0, {&"vuln_mult": 2.0})])
	_save(weakness, "res://resources/cards/epic/weakness_mark.tres")

	var resonance := _card("resonance", "Resonance",
		"6 degats par monstre present dans la zone, a chacun d eux. Plus ils sont serres, plus ca frappe.",
		GameEnums.Rarity.EPIC, 2.4, GameEnums.Targeting.POSITION, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_per_enemy", 6.0, 0.0, 220.0)])
	_save(resonance, "res://resources/cards/epic/resonance.tres")

	var hourglass := _card("hourglass_shard", "Sablier fendu",
		"Le temps se fige pour eux et s emballe pour toi : ennemis -60 pourcent, "
		+ "incantation +100 pourcent, pendant 6 s.",
		GameEnums.Rarity.LEGENDARY, 3.0, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE, GameEnums.DamageTag.SLOW],
		[
			_spec("slow_enemy_gauge", 60.0, 6.0),
			_spec("self_haste", 100.0, 6.0),
		])
	_save(hourglass, "res://resources/cards/legendary/hourglass_shard.tres")


## Deck pre-etabli EXPLICITE : [[chemin, exemplaires], ...] -> une entree par exemplaire.
## Ne depend pas de copies_in_starter, ce qui permet d y placer des rares.
func _deck(spec: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for pair in spec:
		var card: SpellCard = load(pair[0])
		for i in int(pair[1]):
			out.append(card)
	return out


func _entry(def_path: String, count: int, delay: float, offset: float = 0.0) -> WaveEntry:
	var w := WaveEntry.new()
	w.enemy = load(def_path)
	w.count = count
	w.spawn_delay = delay
	w.start_offset = offset
	return w


func _waves_and_level() -> void:
	var E := "res://resources/enemies/"

	var w1 := WaveDef.new()
	w1.id = &"w1"
	w1.duration = 22.0
	w1.difficulty = 1.0
	w1.entries = [_entry(E + "gnome.tres", 6, 1.2)]
	_save(w1, "res://resources/waves/w1.tres")

	var w2 := WaveDef.new()
	w2.id = &"w2"
	w2.duration = 25.0
	w2.difficulty = 1.1
	w2.entries = [
		_entry(E + "gnome.tres", 5, 1.0),
		_entry(E + "sprite.tres", 4, 0.9, 3.0),
		_entry(E + "hopper.tres", 2, 1.2, 6.0),
	]
	_save(w2, "res://resources/waves/w2.tres")

	var w3 := WaveDef.new()
	w3.id = &"w3"
	w3.duration = 26.0
	w3.difficulty = 1.2
	w3.entries = [
		_entry(E + "rat_swarm.tres", 2, 1.4),
		_entry(E + "wisp.tres", 3, 1.6, 4.0),
		_entry(E + "imp_archer.tres", 1, 1.0, 7.0),
	]
	_save(w3, "res://resources/waves/w3.tres")

	var w4 := WaveDef.new()
	w4.id = &"w4_miniboss"
	w4.duration = 30.0
	w4.difficulty = 1.0
	w4.is_miniboss = true
	w4.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "gnome.tres", 4, 1.5, 5.0),
	]
	_save(w4, "res://resources/waves/w4_miniboss.tres")

	var w5 := WaveDef.new()
	w5.id = &"w5"
	w5.duration = 28.0
	w5.difficulty = 1.35
	w5.entries = [
		_entry(E + "golem.tres", 2, 2.0),
		_entry(E + "shade.tres", 3, 1.5, 3.0),
		_entry(E + "sand_serpent.tres", 2, 1.5, 5.0),
		_entry(E + "hornblower.tres", 1, 1.0, 6.0),
	]
	_save(w5, "res://resources/waves/w5.tres")

	var w6 := WaveDef.new()
	w6.id = &"w6_boss"
	w6.duration = 40.0
	w6.difficulty = 1.0
	w6.is_boss = true
	w6.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "sprite.tres", 6, 1.2, 6.0),
	]
	_save(w6, "res://resources/waves/w6_boss.tres")

	# --- Objectifs ---
	var o1 := ObjectiveDef.new()
	o1.id = &"obj_max_speed"
	o1.description = "Gagner en gardant la vitesse au maximum des la vague 1"
	o1.check_key = &"never_dropped_speed"
	_save(o1, "res://resources/objectives/obj_max_speed.tres")

	var o2 := ObjectiveDef.new()
	o2.id = &"obj_no_legendary"
	o2.description = "Gagner sans utiliser de carte legendaire"
	o2.check_key = &"no_legendary_used"
	_save(o2, "res://resources/objectives/obj_no_legendary.tres")

	var o3 := ObjectiveDef.new()
	o3.id = &"obj_untouched"
	o3.description = "Gagner sans subir de degats"
	o3.check_key = &"no_damage_taken"
	_save(o3, "res://resources/objectives/obj_untouched.tres")

	# --- Niveau ---
	var lvl := LevelDef.new()
	lvl.id = &"lvl_01"
	lvl.display_name = "Les Marches du Temps"
	lvl.terrain = "grass"
	lvl.waves = [w1, w2, w3, w4, w5, w6]
	lvl.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "golem.tres"),
		load(E + "wisp.tres"), load(E + "rat_swarm.tres"), load(E + "hopper.tres"),
		load(E + "imp_archer.tres"), load(E + "sand_serpent.tres"),
		load(E + "hornblower.tres"), load(E + "shade.tres"),
	]
	var C := "res://resources/cards/"
	lvl.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/frost_field.tres", 2],
		[C + "common/ember_pool.tres", 2],
		[C + "common/fireball.tres", 2],
		[C + "rare/stone_wall.tres", 2],
	])
	lvl.next_levels = [&"lvl_02"]
	lvl.objectives = [o1, o2, o3]
	lvl.legendary_reward = load("res://resources/cards/legendary/time_rift.tres")
	_save(lvl, "res://resources/levels/lvl_01.tres")

	# --- Niveau 2 : plus dense, plus rapide, le boss escorte ---
	var v1 := WaveDef.new()
	v1.id = &"w2_1"
	v1.duration = 24.0
	v1.difficulty = 1.3
	v1.entries = [
		_entry(E + "gnome.tres", 5, 0.9),
		_entry(E + "sprite.tres", 4, 1.0, 4.0),
		_entry(E + "jelly.tres", 1, 1.0, 8.0),
	]
	_save(v1, "res://resources/waves/w2_1.tres")

	var v2 := WaveDef.new()
	v2.id = &"w2_2"
	v2.duration = 26.0
	v2.difficulty = 1.4
	v2.entries = [
		_entry(E + "rat_swarm.tres", 3, 1.2),
		_entry(E + "wisp.tres", 3, 1.3, 3.0),
		_entry(E + "berserker.tres", 2, 2.0, 6.0),
		_entry(E + "hornblower.tres", 1, 1.0, 8.0),
	]
	_save(v2, "res://resources/waves/w2_2.tres")

	var v3 := WaveDef.new()
	v3.id = &"w2_3"
	v3.duration = 28.0
	v3.difficulty = 1.5
	v3.entries = [
		_entry(E + "void_knight.tres", 2, 1.8),
		_entry(E + "shade.tres", 3, 1.2, 2.0),
		_entry(E + "ghoul_priest.tres", 1, 1.0, 5.0),
		_entry(E + "imp_archer.tres", 2, 1.5, 7.0),
	]
	_save(v3, "res://resources/waves/w2_3.tres")

	var v4 := WaveDef.new()
	v4.id = &"w2_4_miniboss"
	v4.duration = 32.0
	v4.difficulty = 1.3
	v4.is_miniboss = true
	v4.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "sprite.tres", 6, 1.0, 4.0),
		_entry(E + "hornblower.tres", 1, 1.0, 10.0),
	]
	_save(v4, "res://resources/waves/w2_4_miniboss.tres")

	var v5 := WaveDef.new()
	v5.id = &"w2_5"
	v5.duration = 28.0
	v5.difficulty = 1.7
	v5.entries = [
		_entry(E + "hive.tres", 2, 2.5),
		_entry(E + "golem.tres", 2, 2.0, 5.0),
		_entry(E + "sand_serpent.tres", 3, 1.0, 9.0),
	]
	_save(v5, "res://resources/waves/w2_5.tres")

	var v6 := WaveDef.new()
	v6.id = &"w2_6"
	v6.duration = 30.0
	v6.difficulty = 1.8
	v6.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "gnome.tres", 5, 0.8, 1.0),
		_entry(E + "glutton.tres", 1, 1.0, 6.0),
		_entry(E + "sprite.tres", 6, 0.8, 8.0),
	]
	_save(v6, "res://resources/waves/w2_6.tres")

	var v7 := WaveDef.new()
	v7.id = &"w2_7_boss"
	v7.duration = 45.0
	v7.difficulty = 1.4
	v7.is_boss = true
	v7.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "behemoth.tres", 1, 1.0, 5.0),
		_entry(E + "hopper.tres", 6, 1.0, 8.0),
	]
	_save(v7, "res://resources/waves/w2_7_boss.tres")

	var lvl2 := LevelDef.new()
	lvl2.id = &"lvl_02"
	lvl2.display_name = "La Tour des Sables"
	lvl2.terrain = "sand"
	lvl2.waves = [v1, v2, v3, v4, v5, v6, v7]
	lvl2.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "shade.tres"), load(E + "imp_archer.tres"),
		load(E + "sand_serpent.tres"), load(E + "hopper.tres"),
		load(E + "hornblower.tres"), load(E + "golem.tres"), load(E + "berserker.tres"),
		load(E + "void_knight.tres"), load(E + "jelly.tres"), load(E + "ghoul_priest.tres"),
		load(E + "hive.tres"), load(E + "totem_guardian.tres"), load(E + "glutton.tres"),
		load(E + "behemoth.tres"),
	]
	lvl2.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/frost_field.tres", 2],
		[C + "common/ember_pool.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/stone_wall.tres", 2],
		[C + "rare/temporal_drag.tres", 1],
	])
	lvl2.objectives = [o1, o2, o3]
	lvl2.legendary_reward = load(C + "legendary/hourglass_shard.tres")
	lvl2.next_levels = []
	_save(lvl2, "res://resources/levels/lvl_02.tres")
