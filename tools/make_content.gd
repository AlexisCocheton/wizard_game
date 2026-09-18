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
	sprite.anim_key = &"beetle"
	_save(sprite, E + "sprite.tres")

	var jelly_small := _enemy("jelly_small", "Gelee (petite)", K.SPLITTER, 1, 6.0, 85.0, 1, S.CIRCLE, Color(0.55, 0.92, 0.45), 12.0)
	jelly_small.anim_key = &"slimer"
	_save(jelly_small, E + "jelly_small.tres")

	var jelly_mid := _enemy("jelly_mid", "Gelee (moyenne)", K.SPLITTER, 1, 14.0, 65.0, 1, S.CIRCLE, Color(0.50, 0.88, 0.42), 20.0)
	jelly_mid.anim_key = &"slimer"
	jelly_mid.split_into = jelly_small
	jelly_mid.split_count = 2
	_save(jelly_mid, E + "jelly_mid.tres")

	# --- Puissance 2 ---
	var swarm := _enemy("rat_swarm", "Nuee de rats", K.SWARM, 2, 4.0, 110.0, 1, S.CIRCLE, Color(0.85, 0.52, 0.62), 13.0)
	swarm.anim_key = &"peacock"
	swarm.swarm_count = 4
	_save(swarm, E + "rat_swarm.tres")

	var wisp := _enemy("wisp", "Feu follet", K.EVASIVE, 2, 10.0, 90.0, 2, S.CIRCLE, Color(0.45, 0.90, 0.88), 22.0)
	wisp.anim_key = &"flyer"
	wisp.dodge_chance = 0.35
	_save(wisp, E + "wisp.tres")

	var shade := _enemy("shade", "Ombre", K.PHASER, 2, 16.0, 80.0, 3, S.DIAMOND, Color(0.42, 0.40, 0.80), 26.0)
	shade.anim_key = &"vulture"
	shade.phase_interval = 2.5
	_save(shade, E + "shade.tres")

	var archer := _enemy("imp_archer", "Lutin archer", K.SHOOTER, 2, 14.0, 48.0, 3, S.DIAMOND, Color(0.90, 0.32, 0.28), 24.0)
	archer.anim_key = &"archer_red"
	archer.shoot_interval = 3.5
	# L archer harcele : sa fleche pique, elle ne perce pas. Un contact de gnome
	# (4 PV) doit rester plus grave qu une fleche.
	archer.shot_damage = 2
	_save(archer, E + "imp_archer.tres")

	var serpent := _enemy("sand_serpent", "Serpent des sables", K.WAVER, 2, 20.0, 75.0, 2, S.CAPSULE, Color(0.32, 0.72, 0.68), 24.0)
	serpent.anim_key = &"lancer_yellow"
	serpent.wave_amplitude = 170.0
	serpent.wave_frequency = 0.55
	_save(serpent, E + "sand_serpent.tres")

	var hopper := _enemy("hopper", "Sauterelle", K.BURSTER, 2, 10.0, 95.0, 2, S.TRIANGLE, Color(0.55, 0.85, 0.30), 20.0)
	hopper.anim_key = &"dog"
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
	golem.anim_key = &"golem_blue"
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
	jelly.anim_key = &"slimer"
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
	glutton.anim_key = &"dino"
	glutton.devours = true
	_save(glutton, E + "glutton.tres")

	var behemoth := _enemy("behemoth", "Behemoth", K.TANK, 4, 130.0, 26.0, 9, S.SQUARE, Color(0.36, 0.34, 0.40), 52.0)
	behemoth.anim_key = &"golem_orange"
	behemoth.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(behemoth, E + "behemoth.tres")

	# --- Boss (hors budget) ---
	var warden := _enemy("warden", "Gardien", K.MINIBOSS, 6, 140.0, 40.0, 12, S.HEXAGON, Color(0.90, 0.40, 0.25), 62.0)
	warden.anim_key = &"chaosknight"
	_save(warden, E + "warden.tres")

	var chronos := _enemy("chronos", "Chronos", K.BOSS, 10, 320.0, 34.0, 30, S.STAR, Color(0.95, 0.20, 0.25), 84.0)
	chronos.anim_key = &"juggernaut"
	chronos.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(chronos, E + "chronos.tres")

	# --- Boss a MECANIQUE, hors budget (docs/histoire.md) -------------------
	# Un boss doit demander une reponse DIFFERENTE, pas plus de sorts. Les trois
	# qui suivent changent chacun une question du jeu : ou frapper (morcele),
	# quand aller chercher (canonnier), quoi tuer en premier (invocateur).

	# Le sbire de l Ensevelisseur : une goule levee a la chaine. Volontairement
	# faible et lente — la menace est le FLUX, pas l unite. Puissance 1 pour que
	# le Glouton puisse les gober : un boss qui invoque doit nourrir le terrain.
	var risen := _enemy("risen_ghoul", "Goule levee", K.NORMAL, 1, 9.0, 62.0, 1,
		S.DIAMOND, Color(0.55, 0.65, 0.45), 20.0)
	risen.anim_key = &"vulture"
	_save(risen, E + "risen_ghoul.tres")

	# INVOCATEUR — lvl_04, Le Grand Appel. Le Pretre goule qui mene le rituel :
	# il ne se bat pas, il REMPLIT l ecran. Ses PV sont volontairement bas pour
	# un boss (220 contre 320 a Chronos) parce que la vraie difficulte est le
	# flux : si le joueur coupe la source vite, il gagne le combat. C est
	# exactement la decision qu on veut lui faire prendre.
	var gravecaller := _enemy("gravecaller", "L Ensevelisseur", K.BOSS, 10, 220.0, 30.0, 30,
		S.STAR, Color(0.55, 0.85, 0.55), 76.0)
	gravecaller.anim_key = &"unhallowed"
	gravecaller.summon_def = load(E + "risen_ghoul.tres")
	gravecaller.summon_interval = 5.0
	gravecaller.summon_count = 2
	# Plafond serre : au-dela, le joueur perd par accumulation mecanique et non
	# par erreur de jeu. Six goules a l ecran suffisent a l etouffer.
	gravecaller.summon_max_alive = 6
	_save(gravecaller, E + "gravecaller.tres")

	# MORCELE — lvl_05, Forges du Mauvais Temps. Les creatures des forges ne
	# sont pas nees, elles ont ete COULEES : celle-ci se demonte plaque par
	# plaque. Le coeur (150 PV) est plus tendre que les quatre plaques (200 PV
	# cumules) : le combat est donc un travail de DEMONTAGE, pas d usure.
	# Le surplus d un coup ne coule pas d une plaque a l autre, ce qui punit le
	# gros sort unique et recompense le tir soutenu.
	var forge_colossus := _enemy("forge_colossus", "Colosse des Forges", K.BOSS, 10, 150.0, 30.0, 30,
		S.HEXAGON, Color(0.80, 0.55, 0.25), 80.0)
	forge_colossus.anim_key = &"decepticle"
	# Le decepticle occupe 33 % de sa case : sans cette correction il entrerait
	# a la taille d un gnome (voir assets.md, « cases mal remplies »).
	forge_colossus.sprite_scale = 1.15
	forge_colossus.parts_count = 4
	forge_colossus.part_hp = 50.0
	# 18 % par plaque : les quatre tombees, il avance a 28 % de sa vitesse. Assez
	# lent pour se lire comme demantele, assez vivant pour rester une menace.
	forge_colossus.part_slow_pct = 18.0
	forge_colossus.immune_tags = [GameEnums.DamageTag.SLOW]
	_save(forge_colossus, E + "forge_colossus.tres")

	# CANONNIER — lvl_06, La Cour brisee. Un seigneur demon qui ne daigne pas
	# descendre : il campe a 620 px du mage et harcele. Il ne peut donc JAMAIS
	# etre attendu sur la ligne de defense — c est le seul boss qu il faut aller
	# chercher. PV bas (170) : il est deja tres difficile a atteindre.
	var wraith_lord := _enemy("wraith_lord", "Seigneur Spectre", K.BOSS, 10, 170.0, 70.0, 30,
		S.DIAMOND, Color(0.55, 0.45, 0.85), 70.0)
	wraith_lord.anim_key = &"wraith"
	# Mesure au banc : a 620 px avec 20 % d esquive, le boss etait a la fois hors
	# de portee pratique et difficile a punir — il causait la moitie des degats du
	# niveau sans jamais rien risquer, et lvl_06 tombait a 20 % de victoires.
	# Il tient toujours ses distances, mais assez pres pour etre puni, et sans
	# esquive : sa protection est sa POSITION, pas un jet de des.
	wraith_lord.keeps_distance_at = 430.0
	wraith_lord.shoot_interval = 3.4
	# Tir de boss : plus lourd qu une fleche de lutin (2), loin du contact d un
	# boss (50). Il doit user le joueur, pas le tuer avant qu il l atteigne.
	wraith_lord.shot_damage = 5
	wraith_lord.dodge_chance = 0.0
	_save(wraith_lord, E + "wraith_lord.tres")


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
		"Inflige 26 degats a une cible.", GameEnums.Rarity.COMMON, 1.1,
		GameEnums.Targeting.TARGET, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_single", 26.0)], 4)
	_save(bolt, "res://resources/cards/common/arcane_bolt.tres")

	var pierce := _card("piercing_arrow", "Fleche percante",
		"Traverse jusqu a 5 ennemis en ligne, 10 degats chacun.",
		GameEnums.Rarity.COMMON, 1.5, GameEnums.Targeting.DIRECTION,
		[GameEnums.DamageTag.PHYSICAL],
		[_spec("pierce_line", 10.0, 0.0, 120.0, {&"max_targets": 5})], 3)
	_save(pierce, "res://resources/cards/common/piercing_arrow.tres")

	var frost := _card("frost_field", "Champ de givre",
		"Zone qui ralentit de 50 pourcent pendant 5 s.", GameEnums.Rarity.COMMON, 0.6,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 5.0, 180.0, {&"slow_pct": 50.0})], 3)
	_save(frost, "res://resources/cards/common/frost_field.tres")

	var ember := _card("ember_pool", "Braises",
		"Zone infligeant 8 degats par seconde pendant 4 s.", GameEnums.Rarity.COMMON, 1.7,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 8.0, 4.0, 160.0)], 2)
	_save(ember, "res://resources/cards/common/ember_pool.tres")

	var fireball := _card("fireball", "Boule de feu",
		"Explosion de 26 degats dans une zone visee.", GameEnums.Rarity.COMMON, 1.4,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 26.0, 0.6, 170.0)], 2)
	_save(fireball, "res://resources/cards/common/fireball.tres")

	# --- Rares ---
	var haste := _card("quickening", "Precipitation",
		"Accelere l incantation de 60 pourcent pendant 6 s.", GameEnums.Rarity.RARE, 0.8,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("self_haste", 60.0, 6.0)])
	_save(haste, "res://resources/cards/rare/quickening.tres")

	var drag := _card("temporal_drag", "Entrave temporelle",
		"Ralentit tous les ennemis de 40 pourcent pendant 5 s.", GameEnums.Rarity.RARE, 1.4,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SLOW],
		[_spec("slow_enemy_gauge", 40.0, 5.0)])
	_save(drag, "res://resources/cards/rare/temporal_drag.tres")

	var cycle := _card("cycle_of_thought", "Cycle de pensee",
		"Defausse 2 cartes, en pioche 2.", GameEnums.Rarity.RARE, 0.6,
		GameEnums.Targeting.NONE, [],
		[_spec("discard_draw", 0.0, 0.0, 0.0, {&"count": 2})])
	_save(cycle, "res://resources/cards/rare/cycle_of_thought.tres")

	# Le cahier des charges promet une pioche "ameliorable" : voici la carte qui le fait.
	var flow := _card("mana_flow", "Flux de mana",
		"Pioche deux fois plus vite pendant 12 s.", GameEnums.Rarity.RARE, 0.8,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("draw_boost", 2.0, 12.0)])
	_save(flow, "res://resources/cards/rare/mana_flow.tres")

	var wall := _card("stone_wall", "Mur de pierre",
		"Mur de 20 s : les monstres le contournent et il arrete leurs projectiles.",
		GameEnums.Rarity.RARE, 1.5, GameEnums.Targeting.POSITION, [],
		[_spec("build_wall", 0.0, 20.0, 200.0, {&"thickness": 60.0})])
	_save(wall, "res://resources/cards/rare/stone_wall.tres")

	# --- Epiques ---
	var ally := _card("mirror_apprentice", "Apprenti miroir",
		"Invoque un allie qui frappe pour 12 pendant 8 s.", GameEnums.Rarity.EPIC, 1.8,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SUMMON],
		[_spec("summon_ally", 12.0, 8.0)])
	_save(ally, "res://resources/cards/epic/mirror_apprentice.tres")

	var focus := _card("deep_focus", "Concentration",
		"Defausse ta main : moins 1 s d incantation par carte, 8 s.",
		GameEnums.Rarity.EPIC, 0.7, GameEnums.Targeting.NONE, [],
		[_spec("discard_hand_for_speed", 0.0, 8.0, 0.0, {&"seconds_per_card": 1.0})])
	_save(focus, "res://resources/cards/epic/deep_focus.tres")

	var bargain := _card("reckless_bargain", "Pacte imprudent",
		"Accelere les ennemis de 30 pourcent pendant 5 s, pioche 3 cartes.",
		GameEnums.Rarity.EPIC, 0.7, GameEnums.Targeting.NONE, [],
		[_spec("haste_enemies_boon", 30.0, 5.0, 0.0, {&"draw": 3})])
	_save(bargain, "res://resources/cards/epic/reckless_bargain.tres")

	var purge := _card("deck_purge", "Epuration",
		"Retire 2 cartes du deck.", GameEnums.Rarity.EPIC, 1.0,
		GameEnums.Targeting.NONE, [],
		[_spec("remove_cards", 0.0, 0.0, 0.0, {&"count": 2})])
	_save(purge, "res://resources/cards/epic/deck_purge.tres")

	# --- Legendaire ---
	var rift := _card("time_rift", "Faille temporelle",
		"Reduit le cout des cartes de 1.5 s pendant 10 s et frappe en ligne.",
		GameEnums.Rarity.LEGENDARY, 2.0, GameEnums.Targeting.DIRECTION,
		[GameEnums.DamageTag.ARCANE],
		[
			_spec("cost_reduction", 1.5, 10.0),
			_spec("pierce_line", 40.0, 0.0, 200.0, {&"max_targets": 99}),
		])
	_save(rift, "res://resources/cards/legendary/time_rift.tres")

	# --- Variete : cast court/long, petite/grande zone, court/long effet ---
	var spark := _card("spark", "Etincelle",
		"15 degats sur une cible. Tres rapide a lancer.", GameEnums.Rarity.COMMON, 0.45,
		GameEnums.Targeting.TARGET, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_single", 15.0)], 2)
	_save(spark, "res://resources/cards/common/spark.tres")

	var frost_rain := _card("frost_rain", "Pluie de givre",
		"Tres grande zone qui ralentit de 30 pourcent pendant 8 s.", GameEnums.Rarity.COMMON, 1.8,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 8.0, 260.0, {&"slow_pct": 30.0})])
	_save(frost_rain, "res://resources/cards/common/frost_rain.tres")

	var brazier := _card("brazier", "Brasier",
		"Zone de feu : 14 degats par seconde pendant 6 s.", GameEnums.Rarity.RARE, 2.1,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE],
		[_spec("ground_zone", 14.0, 6.0, 140.0)])
	_save(brazier, "res://resources/cards/rare/brazier.tres")

	var meteor := _card("meteor", "Meteore",
		"Long a invoquer, mais 60 degats d un coup dans une petite zone.", GameEnums.Rarity.RARE, 2.8,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.PHYSICAL],
		[_spec("ground_zone", 200.0, 0.3, 120.0)])
	_save(meteor, "res://resources/cards/rare/meteor.tres")

	var about_face := _card("about_face", "Volte-face",
		"Tous les monstres font demi-tour pendant 3 s.", GameEnums.Rarity.RARE, 1.0,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("reverse_enemies", 0.0, 3.0)])
	_save(about_face, "res://resources/cards/rare/about_face.tres")

	var focalisation := _card("focus", "Focalisation",
		"Le prochain sort inflige le double de degats.", GameEnums.Rarity.RARE, 0.7,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.ARCANE],
		[_spec("empower_next", 2.0)])
	_save(focalisation, "res://resources/cards/rare/focus.tres")

	var deep_freeze := _card("deep_freeze", "Gel profond",
		"Zone qui ralentit de 85 pourcent pendant 4 s. Presque un arret.", GameEnums.Rarity.EPIC, 1.5,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.FROST, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 0.0, 4.0, 170.0, {&"slow_pct": 85.0})])
	_save(deep_freeze, "res://resources/cards/epic/deep_freeze.tres")

	var weakness := _card("weakness_mark", "Marque de faiblesse",
		"Zone ou les monstres subissent le double de degats pendant 6 s.", GameEnums.Rarity.EPIC, 1.3,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.ARCANE],
		[_spec("ground_zone", 0.0, 6.0, 200.0, {&"vuln_mult": 2.0})])
	_save(weakness, "res://resources/cards/epic/weakness_mark.tres")

	var resonance := _card("resonance", "Resonance",
		"6 degats par monstre present dans la zone, a chacun d eux. Plus ils sont serres, plus ca frappe.",
		GameEnums.Rarity.EPIC, 1.7, GameEnums.Targeting.POSITION, [GameEnums.DamageTag.ARCANE],
		[_spec("damage_per_enemy", 6.0, 0.0, 220.0)])
	_save(resonance, "res://resources/cards/epic/resonance.tres")

	# --- Cartes d histoire : un monstre qui se rend apprend son sort au mage ---
	# Voir docs/histoire.md section 7. Chacune est placee dans le deck du niveau ou
	# elle se gagne, et chacune contre la famille du niveau SUIVANT : c est ce qui
	# fait que la progression narrative et la progression mecanique avancent ensemble.

	# Acte II / lvl_03 — enseignee par la Gelee liberee de l Ossuaire.
	# L Ossuaire envoie des nuees DISPERSEES : une zone seule y frappe un monstre a
	# la fois. Le vortex ne fait aucun degat, il rassemble pour qu un autre sort paie.
	var salt := _card("salt_spiral", "Spirale de sel",
		"Aspire les monstres vers son centre pendant 3 s. Ne fait aucun degat : "
		+ "elle prepare le sort suivant.",
		GameEnums.Rarity.RARE, 1.2, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.ARCANE],
		[_spec("vortex_pull", 150.0, 3.0, 220.0)])
	_save(salt, "res://resources/cards/rare/salt_spiral.tres")

	# Acte II / lvl_04 — enseignee par le Pretre goule repenti.
	# Le Grand Appel est le niveau le plus LONG : la penurie de cartes y tue plus que
	# les monstres. Garder ses deux prochains sorts, c est doubler sa main utile.
	var recall := _card("bone_recall", "Rappel d ossements",
		"Les 2 prochains sorts lances reviennent en main au lieu d etre defausses.",
		GameEnums.Rarity.RARE, 0.9, GameEnums.Targeting.NONE, [],
		[_spec("retain_next", 2.0)])
	_save(recall, "res://resources/cards/rare/bone_recall.tres")

	# Acte III / lvl_05 — enseignee par le Berserker libere.
	# Les Forges envoient du blindage lent. On ne le tue pas vite : on le REPOUSSE,
	# et le temps gagne vaut plus que les degats. D ou une magnitude modeste et un
	# recul important.
	var chain := _card("chain_break", "Rupture de chaine",
		"18 degats en zone, puis repousse violemment tout ce qui reste debout.",
		GameEnums.Rarity.RARE, 1.4, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.PHYSICAL],
		[_spec("knockback", 18.0, 0.0, 190.0, {&"push": 260.0})])
	_save(chain, "res://resources/cards/rare/chain_break.tres")

	# Acte III / lvl_06 — enseignee par le Chevalier du vide qui se rend.
	# La Cour brisee empile les monstres A EFFETS : rage du Berserker, bouclier de
	# premier coup du Chevalier, aura d invulnerabilite du Gardien-totem. Sans
	# dissipation, ces trois-la se protegent mutuellement.
	# Zone volontairement petite (voir le handler) : large, elle effacerait aussi
	# les ralentissements du joueur.
	var void_grip := _card("void_grip", "Vide d emprise",
		"Efface rage, boucliers et auras des monstres d une petite zone.",
		GameEnums.Rarity.EPIC, 1.1, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.ARCANE],
		[_spec("dispel_zone", 0.0, 0.0, 150.0)])
	_save(void_grip, "res://resources/cards/epic/void_grip.tres")

	# --- Legendaires de campagne (une par niveau, voir docs/histoire.md) ---

	# lvl_03 : le registre des goules. Elles comptaient les ames ; le mage compte
	# les monstres. Piocher 3 d un coup repond au seul vrai probleme de l Ossuaire.
	var ledger := _card("tide_ledger", "Registre des marees",
		"Pioche 3 cartes immediatement et lance deux sorts a la fois pendant 8 s.",
		GameEnums.Rarity.LEGENDARY, 1.6, GameEnums.Targeting.NONE, [],
		[
			_spec("draw_cards", 0.0, 0.0, 0.0, {&"count": 3}),
			_spec("double_cast", 0.0, 8.0),
		])
	_save(ledger, "res://resources/cards/legendary/tide_ledger.tres")

	# lvl_04 : la clef prise sur la porte du Grand Appel. Elle invoque a son tour.
	var key := _card("summoners_key", "Clef de l Appel",
		"Invoque deux allies frappant pour 14 pendant 10 s.",
		GameEnums.Rarity.LEGENDARY, 2.2, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.SUMMON],
		[
			_spec("summon_ally", 14.0, 10.0),
			_spec("summon_ally", 14.0, 10.0),
		])
	_save(key, "res://resources/cards/legendary/summoners_key.tres")

	# lvl_05 / lvl_06 : le cadran vole aux forges. C est l outil des demons retourne
	# contre eux — une commande passee par le mage.
	var dial := _card("forge_dial", "Cadran des forges",
		"Pluie de meteorites sur toute l ile : 14 impacts sur 6 s.",
		GameEnums.Rarity.LEGENDARY, 2.4, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.FIRE],
		[_spec("meteor_storm", 30.0, 6.0, 110.0, {&"impacts": 14})])
	_save(dial, "res://resources/cards/legendary/forge_dial.tres")

	# lvl_07 : la machine elle-meme. Elle fait tout un peu, parce qu elle fait tout.
	var loom := _card("world_loom", "Metier du monde",
		"Le temps se retisse : ennemis ralentis de 50 pourcent, incantation doublee "
		+ "et deux sorts a la fois, pendant 8 s.",
		GameEnums.Rarity.LEGENDARY, 2.6, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE, GameEnums.DamageTag.SLOW],
		[
			_spec("slow_enemy_gauge", 50.0, 8.0),
			_spec("self_haste", 100.0, 8.0),
			_spec("double_cast", 0.0, 8.0),
		])
	_save(loom, "res://resources/cards/legendary/world_loom.tres")

	var hourglass := _card("hourglass_shard", "Sablier fendu",
		"Le temps se fige pour eux et s emballe pour toi : ennemis -60 pourcent, "
		+ "incantation +100 pourcent, pendant 6 s.",
		GameEnums.Rarity.LEGENDARY, 2.1, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE, GameEnums.DamageTag.SLOW],
		[
			_spec("slow_enemy_gauge", 60.0, 6.0),
			_spec("self_haste", 100.0, 6.0),
		])
	_save(hourglass, "res://resources/cards/legendary/hourglass_shard.tres")

	# --- Sorts demandes par le testeur ---
	# Repousser, aspirer, dissiper, piocher, batir : cinq verbes qui manquaient.
	# Aucun ne fait de gros degats : ils achetent de la PLACE et du TEMPS, ce qui
	# etait le seul levier absent d un jeu ou tout se jouait sur les PV.

	# Le souffle ne tue pas : il rend au joueur la distance qu il a perdue quand
	# une vague arrive trop bas. D ou des degats modestes et une grosse poussee.
	var repulsion := _card("repulsion_wave", "Onde de repulsion",
		"Souffle une zone : 18 degats et les monstres sont violemment repousses.",
		GameEnums.Rarity.RARE, 1.2, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.ARCANE, GameEnums.DamageTag.PHYSICAL],
		[_spec("knockback", 18.0, 0.0, 220.0, {&"push": 260.0})])
	_save(repulsion, "res://resources/cards/rare/repulsion_wave.tres")

	# Le vortex ne fait AUCUN degat : c est une carte de mise en place. Elle vaut
	# une epique parce qu elle transforme n importe quelle zone en sort massif.
	var maelstrom := _card("maelstrom", "Maelstrom",
		"Spirale qui aspire les monstres vers son centre pendant 4 s. Aucun degat, "
		+ "mais tout ce qui tombe dedans est regroupe.",
		GameEnums.Rarity.EPIC, 1.6, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.ARCANE],
		[_spec("vortex_pull", 260.0, 4.0, 420.0)])
	_save(maelstrom, "res://resources/cards/epic/maelstrom.tres")

	# Zone volontairement PETITE : une dissipation large annulerait aussi les
	# ralentissements poses par le joueur et se retournerait contre lui.
	var purify := _card("purifying_light", "Lumiere purifiante",
		"Petite zone : les monstres perdent rage, boucliers et effets en cours.",
		GameEnums.Rarity.RARE, 1.0, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.ARCANE],
		[_spec("dispel_zone", 0.0, 0.0, 150.0)])
	_save(purify, "res://resources/cards/rare/purifying_light.tres")

	# Piocher SANS defausser : Cycle de pensee echange, celle-ci ajoute. Cast tres
	# court, car son interet est de sortir d une main vide au pire moment.
	var insight := _card("arcane_insight", "Intuition arcanique",
		"Pioche 3 cartes immediatement. Rien n est defausse.",
		GameEnums.Rarity.RARE, 0.5, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE],
		[_spec("draw_cards", 0.0, 0.0, 0.0, {&"count": 3})])
	_save(insight, "res://resources/cards/rare/arcane_insight.tres")

	# Mur PERMANENT : il ne compte pas les secondes, il compte les coups. Il
	# redessine le terrain pour toute la vague, et les monstres enfermes le
	# cassent — sinon la carte figerait la partie.
	var bastion := _card("bastion", "Bastion",
		"Mur permanent de 120 PV. Il ne disparait pas : les monstres doivent le briser.",
		GameEnums.Rarity.EPIC, 2.0, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.PHYSICAL],
		[_spec("build_wall", 0.0, 0.0, 200.0,
			{&"thickness": 60.0, &"permanent": true, &"wall_hp": 120.0})])
	_save(bastion, "res://resources/cards/epic/bastion.tres")

	# --- Legendaires ---

	# Garder une carte, c est pouvoir rejouer sa meilleure carte deux fois. On en
	# garde DEUX et le cast est court : la legendaire doit changer le tour, pas
	# couter le tour.
	var echo := _card("echo_of_the_hand", "Echo de la main",
		"Les 2 prochaines cartes que tu joues reviennent en main au lieu de partir.",
		GameEnums.Rarity.LEGENDARY, 1.2, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE],
		[_spec("retain_next", 2.0)])
	_save(echo, "res://resources/cards/legendary/echo_of_the_hand.tres")

	# Deux sorts a la fois change la FACON de jouer, pas la quantite de degats :
	# c est exactement ce qu on attend d une legendaire.
	var twin := _card("twin_channeling", "Canalisation jumelle",
		"Pendant 10 s, tu peux charger deux sorts en meme temps.",
		GameEnums.Rarity.LEGENDARY, 2.0, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.ARCANE],
		[_spec("double_cast", 0.0, 10.0)])
	_save(twin, "res://resources/cards/legendary/twin_channeling.tres")

	# Pluie sur TOUTE la carte : 16 impacts etales sur 5 s. Aucun ciblage — c est
	# le sort qu on lance quand on a deja perdu le controle du terrain.
	var storm := _card("meteor_storm", "Pluie de meteorites",
		"18 meteores s abattent sur tout le terrain pendant 5 s, "
		+ "70 degats chacun.",
		GameEnums.Rarity.LEGENDARY, 2.6, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.FIRE, GameEnums.DamageTag.PHYSICAL],
		[_spec("meteor_storm", 70.0, 5.0, 290.0, {&"impacts": 18})])
	_save(storm, "res://resources/cards/legendary/meteor_storm.tres")

	# Enorme et TRES longue : elle ne nettoie pas une vague, elle interdit un
	# couloir pendant presque toute la vague suivante. Degats par seconde faibles
	# expres — c est la duree qui coute cher, pas la puissance.
	var venom := _card("venom_mire", "Mare de venin",
		"Enorme mare empoisonnee : 10 degats par seconde pendant 20 s, "
		+ "et les monstres y avancent 25 pourcent moins vite.",
		GameEnums.Rarity.LEGENDARY, 2.8, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.FIRE, GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 10.0, 20.0, 340.0, {&"slow_pct": 25.0})])
	_save(venom, "res://resources/cards/legendary/venom_mire.tres")


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
	# Premiere vague : espacee, pour apprendre a viser sans etre submerge.
	w1.entries = [_entry(E + "gnome.tres", 5, 2.2)]
	_save(w1, "res://resources/waves/w1.tres")

	var w2 := WaveDef.new()
	w2.id = &"w2"
	w2.duration = 25.0
	w2.difficulty = 1.1
	w2.entries = [
		_entry(E + "gnome.tres", 4, 1.8),
		_entry(E + "sprite.tres", 3, 1.6, 5.0),
		_entry(E + "hopper.tres", 2, 2.0, 12.0),
	]
	_save(w2, "res://resources/waves/w2.tres")

	var w3 := WaveDef.new()
	w3.id = &"w3"
	w3.duration = 26.0
	w3.difficulty = 1.2
	# Cette vague precede le mini-boss : elle doit preparer le saut, pas le subir.
	w3.entries = [
		_entry(E + "rat_swarm.tres", 3, 2.0),
		_entry(E + "wisp.tres", 3, 2.0, 7.0),
		_entry(E + "imp_archer.tres", 1, 1.0, 15.0),
		_entry(E + "hopper.tres", 1, 1.0, 20.0),
	]
	_save(w3, "res://resources/waves/w3.tres")

	var w4 := WaveDef.new()
	w4.id = &"w4_miniboss"
	w4.duration = 30.0
	# Le mini-boss EST le saut de difficulte : son escorte reste legere pour que
	# le joueur puisse se concentrer sur lui.
	w4.difficulty = 0.85
	w4.is_miniboss = true
	w4.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "gnome.tres", 3, 2.5, 10.0),
	]
	_save(w4, "res://resources/waves/w4_miniboss.tres")

	var w5 := WaveDef.new()
	w5.id = &"w5"
	w5.duration = 28.0
	w5.difficulty = 1.35
	w5.entries = [
		_entry(E + "golem.tres", 2, 2.5),
		_entry(E + "shade.tres", 3, 2.0, 6.0),
		_entry(E + "sand_serpent.tres", 2, 2.0, 12.0),
		_entry(E + "hornblower.tres", 1, 1.0, 16.0),
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
	lvl.backdrop = "act1_sky"
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
	# Le niveau 1 ne debloque qu UN niveau : la campagne doit rester lineaire au
	# demarrage. La premiere fourche est en lvl_04 (voir docs/histoire.md section 8).
	lvl.next_levels = [&"lvl_02"]
	lvl.act = 1
	lvl.subtitle = "Le matin de la premiere attaque"
	lvl.intro_text = "Le royaume est tombe. Tu as remonte le temps jusqu ici, le \
premier matin, pour trouver qui a donne l ordre. Ce ne sont que des gnomes et des \
lutins — mais ils marchent en colonne, et la vermine ne marche pas en colonne."
	lvl.outro_text = "Le Gardien a ri en mourant. Il n a jamais voulu de cette \
guerre : sa tribu a recu un ordre venu de sous la terre, et refuser coutait plus cher \
qu obeir. Chronos n etait qu un huissier venu verifier les delais."
	lvl.objectives = [o1, o2, o3]
	lvl.legendary_reward = load("res://resources/cards/legendary/time_rift.tres")
	_save(lvl, "res://resources/levels/lvl_01.tres")

	# --- Niveau 2 : plus dense, plus rapide, le boss escorte ---
	var v1 := WaveDef.new()
	v1.id = &"w2_1"
	v1.duration = 26.0
	# Le niveau 2 PROLONGE la courbe du niveau 1, il ne repart pas d un mur : sa
	# premiere vague se situait au-dessus de la cinquieme du niveau precedent.
	v1.difficulty = 1.1
	v1.entries = [
		_entry(E + "gnome.tres", 4, 2.0),
		_entry(E + "sprite.tres", 3, 2.0, 8.0),
		_entry(E + "jelly_mid.tres", 2, 2.0, 16.0),
	]
	_save(v1, "res://resources/waves/w2_1.tres")

	var v2 := WaveDef.new()
	v2.id = &"w2_2"
	v2.duration = 26.0
	v2.difficulty = 1.2
	v2.entries = [
		_entry(E + "rat_swarm.tres", 3, 2.0),
		_entry(E + "wisp.tres", 3, 2.0, 7.0),
		_entry(E + "berserker.tres", 1, 2.5, 14.0),
		_entry(E + "hornblower.tres", 1, 1.0, 19.0),
	]
	_save(v2, "res://resources/waves/w2_2.tres")

	var v3 := WaveDef.new()
	v3.id = &"w2_3"
	v3.duration = 28.0
	# Chevalier du vide (annule le 1er coup) et Ombre (encaisse moins en phase)
	# demandent chacun plusieurs sorts. Les cumuler dans la meme vague rendait
	# celle-ci infranchissable : on les repartit.
	v3.difficulty = 1.3
	v3.entries = [
		_entry(E + "void_knight.tres", 1, 2.5),
		_entry(E + "shade.tres", 2, 2.5, 8.0),
		_entry(E + "ghoul_priest.tres", 1, 1.0, 15.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 20.0),
	]
	_save(v3, "res://resources/waves/w2_3.tres")

	var v4 := WaveDef.new()
	v4.id = &"w2_4_miniboss"
	v4.duration = 32.0
	v4.difficulty = 1.2
	v4.is_miniboss = true
	v4.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "sprite.tres", 5, 1.8, 6.0),
		_entry(E + "hornblower.tres", 1, 1.0, 16.0),
	]
	_save(v4, "res://resources/waves/w2_4_miniboss.tres")

	var v5 := WaveDef.new()
	v5.id = &"w2_5"
	v5.duration = 28.0
	v5.difficulty = 1.4
	v5.entries = [
		_entry(E + "hive.tres", 1, 3.0),
		_entry(E + "golem.tres", 2, 2.5, 7.0),
		_entry(E + "sand_serpent.tres", 3, 2.0, 15.0),
	]
	_save(v5, "res://resources/waves/w2_5.tres")

	var v6 := WaveDef.new()
	v6.id = &"w2_6"
	v6.duration = 30.0
	v6.difficulty = 1.55
	v6.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "gnome.tres", 4, 1.6, 3.0),
		_entry(E + "glutton.tres", 1, 1.0, 11.0),
		_entry(E + "sprite.tres", 5, 1.5, 16.0),
	]
	_save(v6, "res://resources/waves/w2_6.tres")

	var v7 := WaveDef.new()
	v7.id = &"w2_7_boss"
	v7.duration = 45.0
	v7.difficulty = 1.25
	v7.is_boss = true
	# Chronos ET Behemoth ensemble, c etait les deux plus gros monstres du jeu dans
	# la meme vague : l escorte suffit a rendre le boss difficile.
	v7.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "hopper.tres", 4, 2.0, 10.0),
		_entry(E + "sprite.tres", 4, 2.0, 22.0),
	]
	_save(v7, "res://resources/waves/w2_7_boss.tres")

	var lvl2 := LevelDef.new()
	lvl2.id = &"lvl_02"
	lvl2.display_name = "La Tour des Sables"
	lvl2.terrain = "sand"
	lvl2.backdrop = "act1_sky"
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
	# Le niveau 2 envoie le DOUBLE de PV du niveau 1 : son deck doit suivre, sinon
	# le joueur affronte deux fois plus avec les memes outils. Plus de zones, qui
	# sont la seule facon de traiter plusieurs monstres par sort.
	lvl2.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 2],
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/frost_field.tres", 2],
		[C + "common/ember_pool.tres", 3],
		[C + "common/fireball.tres", 4],
		[C + "rare/stone_wall.tres", 2],
		[C + "rare/temporal_drag.tres", 1],
		[C + "rare/meteor.tres", 2],
		[C + "rare/brazier.tres", 2],
	])
	lvl2.objectives = [o1, o2, o3]
	lvl2.legendary_reward = load(C + "legendary/hourglass_shard.tres")
	lvl2.next_levels = [&"lvl_03"]
	lvl2.act = 1
	lvl2.subtitle = "L ile qui a commence a tomber"
	lvl2.intro_text = "La Tour des Sables se decroche : le temps y coule de travers, \
et des creatures qui n ont rien a faire sur une ile volante s y entassent. Ombres, \
Chevaliers du vide, Pretres goules. Ils ne t attaquent pas. Ils FUIENT."
	lvl2.outro_text = "Ils fuyaient le puits. Sous la tour s ouvre une descente vers \
le Grand Cimetiere — et c est de la-bas qu est venu l ordre."
	_save(lvl2, "res://resources/levels/lvl_02.tres")

	_acte_2(o1, o2, o3, C, E)
	_acte_3(o1, o2, o3, C, E)
	_acte_final(o1, o2, o3, C, E)


## =====================================================================
## ACTE II — LE GRAND CIMETIERE  (voir docs/histoire.md sections 4 et 9)
##
## Intention commune aux deux niveaux : apres deux niveaux ou la menace etait la
## MASSE (golems, behemoths), l Acte II bascule sur le NOMBRE. C est un contraste
## volontaire : le joueur qui a appris a concentrer ses degats doit desapprendre.
## Les decks suivent — beaucoup de zones, peu de mono-cible.
## =====================================================================
func _acte_2(o1: ObjectiveDef, o2: ObjectiveDef, o3: ObjectiveDef,
		C: String, E: String) -> void:

	# ---------- lvl_03 : Ossuaire des Marees ----------
	# Les goules comptent les ames pendant que le mage traverse les fosses.
	# Toutes les vagues sont batie sur des monstres qui SE MULTIPLIENT (nuees,
	# gelees, ruches) : le nombre a l ecran grimpe sans que les PV explosent.
	# La courbe reprend au-dessus de la fin du niveau 2 sans jamais doubler.
	var a1 := WaveDef.new()
	a1.id = &"w3_1"
	a1.duration = 26.0
	a1.difficulty = 1.15
	# Premiere lecon de l acte : deux nuees valent 8 corps. On ouvre doucement.
	a1.entries = [
		_entry(E + "rat_swarm.tres", 2, 2.4),
		_entry(E + "gnome.tres", 4, 2.0, 7.0),
		_entry(E + "jelly_mid.tres", 2, 2.2, 15.0),
	]
	_save(a1, "res://resources/waves/w3_1.tres")

	var a2 := WaveDef.new()
	a2.id = &"w3_2"
	a2.duration = 27.0
	a2.difficulty = 1.25
	# La Gelee entiere entre en scene : 36 PV qui deviennent 6 corps si on la tue
	# mal. C est la vague qui apprend a poser une zone AVANT de frapper.
	a2.entries = [
		_entry(E + "jelly.tres", 1, 2.5),
		_entry(E + "rat_swarm.tres", 3, 2.0, 6.0),
		_entry(E + "sprite.tres", 4, 1.6, 14.0),
	]
	_save(a2, "res://resources/waves/w3_2.tres")

	var a3 := WaveDef.new()
	a3.id = &"w3_3"
	a3.duration = 28.0
	a3.difficulty = 1.3
	# Le Pretre goule soigne : tant qu il vit, les degats etales ne servent a rien.
	# Il force a choisir une cible prioritaire au milieu de la foule.
	a3.entries = [
		_entry(E + "ghoul_priest.tres", 2, 3.0),
		_entry(E + "jelly_mid.tres", 3, 2.0, 8.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 16.0),
	]
	_save(a3, "res://resources/waves/w3_3.tres")

	var a4 := WaveDef.new()
	a4.id = &"w3_4_miniboss"
	a4.duration = 32.0
	# Le mini-boss EST le saut : son escorte reste legere, comme au niveau 1.
	a4.difficulty = 1.05
	a4.is_miniboss = true
	a4.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "rat_swarm.tres", 3, 2.2, 8.0),
		_entry(E + "hopper.tres", 3, 1.8, 18.0),
	]
	_save(a4, "res://resources/waves/w3_4_miniboss.tres")

	var a5 := WaveDef.new()
	a5.id = &"w3_5"
	a5.duration = 30.0
	a5.difficulty = 1.35
	# La Ruche explose en 4 lutins : un seul monstre en vaut cinq. C est la vague
	# ou la Spirale de sel du deck paie enfin son temps d incantation.
	a5.entries = [
		_entry(E + "hive.tres", 2, 3.0),
		_entry(E + "jelly.tres", 1, 2.0, 10.0),
		_entry(E + "wisp.tres", 3, 1.8, 18.0),
	]
	_save(a5, "res://resources/waves/w3_5.tres")

	var a6 := WaveDef.new()
	a6.id = &"w3_6_boss"
	a6.duration = 42.0
	# Difficulte basse sur la vague de boss : Chronos apporte deja 320 PV bruts,
	# le multiplier reviendrait a empiler deux sauts dans la meme vague.
	a6.difficulty = 1.1
	a6.is_boss = true
	a6.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 8.0),
		_entry(E + "rat_swarm.tres", 3, 2.0, 20.0),
	]
	_save(a6, "res://resources/waves/w3_6_boss.tres")

	var lvl3 := LevelDef.new()
	lvl3.id = &"lvl_03"
	lvl3.display_name = "Ossuaire des Marees"
	lvl3.terrain = "sand"
	lvl3.backdrop = "act2_graveyard"
	lvl3.waves = [a1, a2, a3, a4, a5, a6]
	lvl3.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "hopper.tres"), load(E + "imp_archer.tres"),
		load(E + "jelly.tres"), load(E + "ghoul_priest.tres"), load(E + "hive.tres"),
		load(E + "shade.tres"),
	]
	# DECK ANTI-NOMBRE. Le contenu du niveau est fait de monstres qui se divisent et
	# qui pullulent : le mono-cible y est un piege (tuer une Gelee au Trait, c est
	# creer deux Gelees). D ou 9 cartes de zone sur 16, et la Spirale de sel qui
	# rassemble avant la frappe. Un seul Trait subsiste, pour achever les Pretres.
	lvl3.exploration_deck = _deck([
		[C + "common/fireball.tres", 3],
		[C + "common/ember_pool.tres", 3],
		[C + "common/frost_rain.tres", 2],
		[C + "common/arcane_bolt.tres", 1],
		[C + "common/piercing_arrow.tres", 2],
		[C + "rare/salt_spiral.tres", 2],
		[C + "epic/resonance.tres", 2],
		[C + "rare/stone_wall.tres", 1],
	])
	lvl3.objectives = [o1, o2, o3]
	lvl3.legendary_reward = load(C + "legendary/tide_ledger.tres")
	lvl3.next_levels = [&"lvl_04"]
	lvl3.act = 2
	lvl3.subtitle = "Une administration, pas un cimetiere"
	lvl3.intro_text = "Ici les morts sont tries, comptes, reaffectes. Les Pretres \
goules tiennent les registres et leur ile se vide : les ames partent ailleurs. Ils \
n ont pas efface ton royaume par haine. Ils l ont fait pour le STOCK."
	lvl3.outro_text = "Une Gelee prisonniere d un cercle de sel t a regarde la \
liberer, puis t a montre comment un corps se separe et se rassemble. Les registres, \
eux, sont clairs : l extinction humaine devait alimenter une Grande Invocation."
	_save(lvl3, "res://resources/levels/lvl_03.tres")

	# ---------- lvl_04 : Le Grand Appel ----------
	# Le rituel a lieu et IL REUSSIT. Le joueur ne l empeche pas — c est le
	# rebondissement. Traduction mecanique : la vague 5 change brutalement de
	# nature (les demons franchissent la porte) au milieu du niveau, pas a la fin.
	var b1 := WaveDef.new()
	b1.id = &"w4_1"
	b1.duration = 26.0
	b1.difficulty = 1.2
	b1.entries = [
		_entry(E + "jelly_mid.tres", 3, 2.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 8.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 16.0),
	]
	_save(b1, "res://resources/waves/w4_1.tres")

	var b2 := WaveDef.new()
	b2.id = &"w4_2"
	b2.duration = 28.0
	b2.difficulty = 1.3
	# Deux Pretres qui se soignent l un l autre : le premier vrai probleme
	# d ordre de cibles du jeu.
	b2.entries = [
		_entry(E + "ghoul_priest.tres", 2, 2.5),
		_entry(E + "hive.tres", 1, 2.0, 9.0),
		_entry(E + "shade.tres", 3, 2.0, 17.0),
	]
	_save(b2, "res://resources/waves/w4_2.tres")

	var b3 := WaveDef.new()
	b3.id = &"w4_3_miniboss"
	b3.duration = 34.0
	b3.difficulty = 1.1
	b3.is_miniboss = true
	# Le Gardien du seuil : il tient la porte pendant que le rituel s acheve.
	b3.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "ghoul_priest.tres", 1, 1.0, 7.0),
		_entry(E + "jelly.tres", 1, 2.0, 15.0),
		_entry(E + "sprite.tres", 4, 1.6, 24.0),
	]
	_save(b3, "res://resources/waves/w4_3_miniboss.tres")

	var b4 := WaveDef.new()
	b4.id = &"w4_4"
	b4.duration = 30.0
	b4.difficulty = 1.35
	b4.entries = [
		_entry(E + "jelly.tres", 2, 2.5),
		_entry(E + "berserker.tres", 2, 2.5, 10.0),
		_entry(E + "wisp.tres", 3, 1.8, 19.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 24.0),
	]
	_save(b4, "res://resources/waves/w4_4.tres")

	var b5 := WaveDef.new()
	b5.id = &"w4_5"
	b5.duration = 32.0
	b5.difficulty = 1.35
	# LA PORTE S OUVRE. Behemoth et Gardien-totem franchissent le seuil : ce ne
	# sont plus des goules. Le changement doit se VOIR — deux P4 d un coup, mais
	# sans escorte lourde pour que le saut de PV reste sous le double.
	b5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "behemoth.tres", 1, 1.0, 10.0),
		_entry(E + "gnome.tres", 4, 2.0, 18.0),
		_entry(E + "sprite.tres", 4, 1.5, 24.0),
	]
	_save(b5, "res://resources/waves/w4_5.tres")

	var b6 := WaveDef.new()
	b6.id = &"w4_6_boss"
	b6.duration = 45.0
	b6.difficulty = 1.05
	b6.is_boss = true
	# L ENSEVELISSEUR. Le Pretre qui mene la Grande Invocation : il ne vient pas
	# se battre, il vient FINIR SON RITUEL. Il leve deux goules toutes les 5 s
	# tant qu il vit, ce qui rend la vague ingagnable en nettoyant les sbires.
	# La seule reponse est de percer jusqu a lui — c est la lecon du niveau.
	# L escorte est volontairement LEGERE : le flux d invocation fournit deja
	# tous les corps, en ajouter transformerait la pression en noyade.
	b6.entries = [
		_entry(E + "gravecaller.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 1, 2.5, 12.0),
	]
	_save(b6, "res://resources/waves/w4_6_boss.tres")

	var lvl4 := LevelDef.new()
	lvl4.id = &"lvl_04"
	lvl4.display_name = "Le Grand Appel"
	lvl4.terrain = "sand"
	lvl4.backdrop = "act2_graveyard"
	lvl4.waves = [b1, b2, b3, b4, b5, b6]
	lvl4.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "shade.tres"), load(E + "imp_archer.tres"),
		load(E + "jelly.tres"), load(E + "ghoul_priest.tres"), load(E + "hive.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "totem_guardian.tres"), load(E + "behemoth.tres"),
		load(E + "risen_ghoul.tres"),
	]
	# DECK CHARNIERE. Le niveau commence en registre "nombre" et finit en registre
	# "masse" : le deck doit tenir les deux moities. Zones pour les goules, Meteore
	# et Marque de faiblesse pour les deux P4 de la vague 5. Le Rappel d ossements
	# repond au vrai probleme du niveau : c est le plus long de la campagne, on y
	# manque de cartes avant d y manquer de PV.
	lvl4.exploration_deck = _deck([
		[C + "common/fireball.tres", 3],
		[C + "common/ember_pool.tres", 2],
		[C + "common/arcane_bolt.tres", 2],
		[C + "common/piercing_arrow.tres", 2],
		[C + "rare/bone_recall.tres", 2],
		[C + "rare/meteor.tres", 2],
		[C + "rare/salt_spiral.tres", 1],
		[C + "epic/weakness_mark.tres", 2],
		[C + "rare/stone_wall.tres", 1],
	])
	lvl4.objectives = [o1, o2, o3]
	lvl4.legendary_reward = load(C + "legendary/summoners_key.tres")
	# PREMIERE FOURCHE de la campagne : la porte s ouvre sur deux entrees du monde
	# demoniaque, equivalentes en difficulte mais opposees en nature.
	lvl4.next_levels = [&"lvl_05", &"lvl_06"]
	lvl4.act = 2
	lvl4.subtitle = "Le rituel reussit"
	lvl4.intro_text = "Tu arrives trop tard : le cercle est deja trace et les \
Pretres chantent. Tu ne peux plus empecher la Grande Invocation. Tu peux seulement \
etre la quand la porte s ouvrira, pour voir ce qui en sortira."
	lvl4.outro_text = "Les goules croyaient invoquer un allie. Elles ont invoque un \
PROPRIETAIRE. Le Grand Cimetiere a ete annexe en une nuit. Le Pretre qui dirigeait le \
rituel, ecrase par ce qu il a fait venir, t a appris a rappeler ce qui est deja parti \
— puis t a montre la porte, encore ouverte."
	_save(lvl4, "res://resources/levels/lvl_04.tres")


## =====================================================================
## ACTE III — LE MONDE DEMONIAQUE  (docs/histoire.md sections 5 et 8)
##
## Les deux niveaux sont une FOURCHE : meme place dans la courbe, exigences
## opposees. lvl_05 = peu de monstres tres blindes (mono-cible lourd).
## lvl_06 = beaucoup de monstres varies a effets (zones + dissipation).
## Le joueur choisit son epreuve ; les deux menent au final.
## =====================================================================
func _acte_3(o1: ObjectiveDef, o2: ObjectiveDef, o3: ObjectiveDef,
		C: String, E: String) -> void:

	# ---------- lvl_05 : Forges du Mauvais Temps ----------
	# Peu de corps, enormement de PV. Les vagues sont COURTES en nombre : c est ce
	# qui permet de monter les PV sans que l ecran devienne illisible, et ce qui
	# rend le mono-cible lourd (Meteore, Focalisation) enfin superieur aux zones.
	var c1 := WaveDef.new()
	c1.id = &"w5_1"
	c1.duration = 28.0
	c1.difficulty = 1.2
	c1.entries = [
		_entry(E + "golem.tres", 2, 3.0),
		_entry(E + "gnome.tres", 4, 2.0, 10.0),
		_entry(E + "hopper.tres", 3, 1.8, 16.0),
	]
	_save(c1, "res://resources/waves/w5_1.tres")

	var c2 := WaveDef.new()
	c2.id = &"w5_2"
	c2.duration = 28.0
	c2.difficulty = 1.25
	# Le Berserker accelere a chaque coup recu : l arroser de petits degats le rend
	# plus dangereux. Premiere vague qui punit le reflexe acquis a l Acte II.
	c2.entries = [
		_entry(E + "berserker.tres", 3, 2.5),
		_entry(E + "void_knight.tres", 1, 2.0, 12.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 18.0),
	]
	_save(c2, "res://resources/waves/w5_2.tres")

	var c3 := WaveDef.new()
	c3.id = &"w5_3_miniboss"
	c3.duration = 34.0
	c3.difficulty = 1.1
	c3.is_miniboss = true
	c3.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 3.0, 10.0),
		_entry(E + "sprite.tres", 4, 1.6, 22.0),
	]
	_save(c3, "res://resources/waves/w5_3_miniboss.tres")

	var c4 := WaveDef.new()
	c4.id = &"w5_4"
	c4.duration = 30.0
	c4.difficulty = 1.3
	# Premier Behemoth seul : 130 PV qui avancent a 26 px/s et frappent pour 2.
	# Lent, donc traitable ; mais il faut y consacrer plusieurs sorts d affilee.
	c4.entries = [
		_entry(E + "behemoth.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 8.0),
		_entry(E + "berserker.tres", 2, 2.5, 18.0),
		_entry(E + "hornblower.tres", 1, 1.0, 24.0),
	]
	_save(c4, "res://resources/waves/w5_4.tres")

	var c5 := WaveDef.new()
	c5.id = &"w5_5"
	c5.duration = 32.0
	c5.difficulty = 1.3
	# Le Gardien-totem rend les autres invulnerables dans 240 px : avec deux
	# Behemoths sous son aura, il DOIT tomber en premier. La vague enseigne la
	# priorite de cible que le boss exigera.
	c5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "behemoth.tres", 1, 1.0, 9.0),
		_entry(E + "golem.tres", 2, 2.5, 18.0),
		_entry(E + "sprite.tres", 4, 1.5, 25.0),
	]
	_save(c5, "res://resources/waves/w5_5.tres")

	var c6 := WaveDef.new()
	c6.id = &"w5_6_boss"
	c6.duration = 48.0
	c6.difficulty = 1.05
	c6.is_boss = true
	# LE COLOSSE DES FORGES. Quatre plaques de 50 PV devant un coeur de 150 : le
	# joueur ne peut pas l user, il doit le DEMONTER, et le surplus d un coup ne
	# passe pas d une plaque a l autre. Le deck mono-cible du niveau (Meteore,
	# Trait) est exactement l outil qu il faut — c est le paiement du niveau.
	# Escorte reduite : demonter demande de rester concentre sur une cible, une
	# foule autour annulerait toute la mecanique.
	c6.entries = [
		_entry(E + "forge_colossus.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 3.0, 14.0),
		_entry(E + "hopper.tres", 3, 1.8, 34.0),
	]
	_save(c6, "res://resources/waves/w5_6_boss.tres")

	var lvl5 := LevelDef.new()
	lvl5.id = &"lvl_05"
	lvl5.display_name = "Forges du Mauvais Temps"
	lvl5.terrain = "sand"
	lvl5.backdrop = "act3_demon"
	lvl5.waves = [c1, c2, c3, c4, c5, c6]
	lvl5.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "golem.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "behemoth.tres"), load(E + "totem_guardian.tres"),
		load(E + "hornblower.tres"), load(E + "imp_archer.tres"),
	]
	# DECK ANTI-BLINDAGE. Contre 55 a 130 PV par corps, une zone a 8 degats/s est
	# du gaspillage : il faut des paquets de degats. Meteore (60 d un coup),
	# Focalisation (x2 sur le sort suivant) et Marque de faiblesse (x2 en zone) se
	# combinent — c est la combo que le niveau veut enseigner.
	# La Rupture de chaine est la reponse d urgence : elle n a pas besoin de tuer,
	# elle rend du temps en repoussant ce qu on n a pas fini.
	lvl5.exploration_deck = _deck([
		[C + "rare/meteor.tres", 3],
		[C + "common/arcane_bolt.tres", 3],
		[C + "rare/focus.tres", 2],
		[C + "epic/weakness_mark.tres", 2],
		[C + "rare/chain_break.tres", 2],
		[C + "common/piercing_arrow.tres", 2],
		[C + "rare/brazier.tres", 1],
		[C + "rare/stone_wall.tres", 1],
	])
	lvl5.objectives = [o1, o2, o3]
	lvl5.legendary_reward = load(C + "legendary/forge_dial.tres")
	lvl5.next_levels = [&"lvl_07"]
	lvl5.act = 3
	lvl5.subtitle = "Ils ne conquierent pas, ils fabriquent"
	lvl5.intro_text = "De l autre cote de la porte : pas de chateau, pas de trone. \
Des ateliers. Les demons fabriquent du temps, et ces creatures blindees ne sont pas \
nees — elles ont ete coulees."
	lvl5.outro_text = "Un Berserker a brise sa chaine devant toi au lieu de charger. \
Les demons ne choisissent rien : une horloge bat au centre de leur monde et les \
reveille. Elle n est pas a eux. Chaque extinction est une COMMANDE qui arrive par le \
cadran, et ils ignorent qui la passe."
	_save(lvl5, "res://resources/levels/lvl_05.tres")

	# ---------- lvl_06 : La Cour brisee ----------
	# Meme niveau de difficulte que lvl_05, nature inverse : beaucoup de corps,
	# toutes les familles melangees, et surtout des monstres A EFFETS qui se
	# protegent mutuellement (rage, bouclier de premier coup, aura d invulnerabilite).
	# C est une guerre civile ou le mage n est qu un passant.
	var d1 := WaveDef.new()
	d1.id = &"w6_1"
	d1.duration = 27.0
	d1.difficulty = 1.2
	# Mesure au banc : a 2 chevaliers du vide des la premiere vague, le niveau
	# tombait a 37 % de victoires. Le chevalier annule le premier coup recu : en
	# ouvrir la porte a deux exemplaires coutait quatre sorts avant le moindre degat.
	d1.entries = [
		_entry(E + "void_knight.tres", 1, 2.5),
		_entry(E + "sprite.tres", 4, 1.8, 8.0),
		_entry(E + "wisp.tres", 3, 2.0, 16.0),
	]
	_save(d1, "res://resources/waves/w6_1.tres")

	var d2 := WaveDef.new()
	d2.id = &"w6_2"
	d2.duration = 28.0
	d2.difficulty = 1.25
	# Le Corniste accelere tout le monde de 20 % : il transforme une vague lisible
	# en debordement. Il entre par le cote, donc il faut le chercher.
	d2.entries = [
		_entry(E + "hornblower.tres", 1, 2.5),
		_entry(E + "shade.tres", 3, 2.0, 7.0),
		_entry(E + "hopper.tres", 4, 1.8, 15.0),
	]
	_save(d2, "res://resources/waves/w6_2.tres")

	var d3 := WaveDef.new()
	d3.id = &"w6_3_miniboss"
	d3.duration = 34.0
	d3.difficulty = 1.1
	d3.is_miniboss = true
	# Mesure au banc : les nuees de rats causaient la moitie des coups recus. Une
	# nuee compte pour PLUSIEURS corps (swarm_count) et arrivait pendant que le
	# mini-boss monopolisait l attention. Deux entrees, plus espacees.
	d3.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "berserker.tres", 2, 2.5, 9.0),
		_entry(E + "rat_swarm.tres", 2, 3.0, 22.0),
	]
	_save(d3, "res://resources/waves/w6_3_miniboss.tres")

	var d4 := WaveDef.new()
	d4.id = &"w6_4"
	d4.duration = 30.0
	d4.difficulty = 1.3
	# Le Glouton gobe les faibles et grossit : le laisser vivre au milieu d une
	# nuee, c est fabriquer soi-meme le monstre qui tuera le mage.
	d4.entries = [
		_entry(E + "glutton.tres", 1, 1.0),
		_entry(E + "hive.tres", 1, 2.0, 8.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 16.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 24.0),
	]
	_save(d4, "res://resources/waves/w6_4.tres")

	var d5 := WaveDef.new()
	d5.id = &"w6_5"
	d5.duration = 32.0
	d5.difficulty = 1.3
	# Le trio qui justifie le Vide d emprise : totem (aura), berserkers (rage),
	# chevaliers (bouclier). Sans dissipation, chacun couvre les deux autres.
	d5.entries = [
		# Mesure au banc : cumuler le Gardien-totem (aura d invulnerabilite), deux
		# Berserkers (rage) et un Chevalier du vide (annule le premier coup) rendait
		# la vague infranchissable — quatre monstres dont aucun ne meurt au premier
		# sort, pendant que la Ruche libere ses lutins.
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "berserker.tres", 1, 2.5, 10.0),
		_entry(E + "sprite.tres", 3, 1.8, 22.0),
	]
	_save(d5, "res://resources/waves/w6_5.tres")

	var d6 := WaveDef.new()
	d6.id = &"w6_6_boss"
	d6.duration = 48.0
	d6.difficulty = 1.05
	d6.is_boss = true
	# LE SEIGNEUR SPECTRE. Il s arrete a 620 px du mage et harcele de loin : il
	# n arrivera jamais au contact, donc la ligne de defense ne sert a rien
	# contre lui. Le joueur doit le viser DERRIERE son escorte pendant que
	# celle-ci descend — c est la seule vague du jeu ou l ordre naturel des
	# cibles (le plus proche d abord) est le mauvais choix.
	d6.entries = [
		_entry(E + "wraith_lord.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 12.0),
		_entry(E + "shade.tres", 3, 2.0, 26.0),
	]
	_save(d6, "res://resources/waves/w6_6_boss.tres")

	var lvl6 := LevelDef.new()
	lvl6.id = &"lvl_06"
	lvl6.display_name = "La Cour brisee"
	lvl6.terrain = "sand"
	lvl6.backdrop = "act3_demon"
	lvl6.waves = [d1, d2, d3, d4, d5, d6]
	lvl6.enemy_pool = [
		load(E + "sprite.tres"), load(E + "wisp.tres"), load(E + "shade.tres"),
		load(E + "hopper.tres"), load(E + "rat_swarm.tres"),
		load(E + "imp_archer.tres"), load(E + "hornblower.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "hive.tres"), load(E + "glutton.tres"),
		load(E + "totem_guardian.tres"),
	]
	# DECK DE DEGATS + DISSIPATION. Deux hypotheses testees au banc et rejetees :
	#  - "il faut du cast court" (Etincelle + Givre) -> 13 % de victoires. Une
	#    Etincelle a 15 degats ne tue aucun corps de la Cour (30 a 60 PV) : le
	#    mage lance vite et ne tue rien.
	#  - "il faut moins de monstres" -> sans effet, le niveau a deja MOINS de PV
	#    totaux que les Forges (1340 contre 2054).
	# Ce qui marche : de la densite de degats par sort. Boule de feu et Resonance
	# frappent tout un groupe, Brasier tient un couloir, et le Vide d emprise
	# reste la carte signature — seule reponse au trio totem/berserker/chevalier
	# qui se protege mutuellement.
	lvl6.exploration_deck = _deck([
		[C + "epic/void_grip.tres", 2],
		[C + "epic/resonance.tres", 3],
		[C + "common/fireball.tres", 4],
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/piercing_arrow.tres", 2],
		[C + "rare/brazier.tres", 2],
		[C + "epic/deep_freeze.tres", 1],
		[C + "rare/chain_break.tres", 1],
		[C + "rare/stone_wall.tres", 2],
	])
	lvl6.objectives = [o1, o2, o3]
	lvl6.legendary_reward = load(C + "legendary/forge_dial.tres")
	lvl6.next_levels = [&"lvl_07"]
	lvl6.act = 3
	lvl6.subtitle = "Une guerre civile ou tu n es qu un passant"
	lvl6.intro_text = "Les seigneurs demoniaques s entretuent pour savoir qui \
portera la faute du Grand Appel rate. Personne ne t attend. Tout le monde te tuera \
quand meme, en passant."
	lvl6.outro_text = "Le Chevalier du vide qui gardait le cadran s est rendu. Il t a \
enseigne le geste des gardiens : effacer ce qui a ete inscrit sur une creature. Sur \
le cadran, tu as lu une adresse."
	_save(lvl6, "res://resources/levels/lvl_06.tres")


## =====================================================================
## ACTE FINAL — LE MONDE D ORIGINE  (docs/histoire.md section 6)
##
## Terrain `grass` a dessein : le joueur reconnait le decor du niveau 1, en faux.
## L histoire est circulaire, donc le premier ennemi est aussi le dernier.
## =====================================================================
func _acte_final(o1: ObjectiveDef, o2: ObjectiveDef, o3: ObjectiveDef,
		C: String, E: String) -> void:

	var f1 := WaveDef.new()
	f1.id = &"w7_1"
	f1.duration = 28.0
	f1.difficulty = 1.25
	# Ouverture en citation du niveau 1 : gnomes et lutins, le motif que la
	# machine repete. Sauf qu ils arrivent deux fois plus vite et accompagnes.
	f1.entries = [
		_entry(E + "gnome.tres", 5, 1.8),
		_entry(E + "sprite.tres", 5, 1.5, 8.0),
		_entry(E + "golem.tres", 2, 2.5, 17.0),
	]
	_save(f1, "res://resources/waves/w7_1.tres")

	var f2 := WaveDef.new()
	f2.id = &"w7_2"
	f2.duration = 29.0
	f2.difficulty = 1.3
	f2.entries = [
		_entry(E + "void_knight.tres", 2, 2.5),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 9.0),
		_entry(E + "wisp.tres", 4, 1.8, 18.0),
	]
	_save(f2, "res://resources/waves/w7_2.tres")

	var f3 := WaveDef.new()
	f3.id = &"w7_3_miniboss"
	f3.duration = 36.0
	f3.difficulty = 1.1
	f3.is_miniboss = true
	f3.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "berserker.tres", 2, 2.5, 9.0),
		_entry(E + "hopper.tres", 4, 1.8, 20.0),
	]
	_save(f3, "res://resources/waves/w7_3_miniboss.tres")

	var f4 := WaveDef.new()
	f4.id = &"w7_4"
	f4.duration = 32.0
	f4.difficulty = 1.3
	# Les deux registres du jeu dans la meme vague : le blindage (Behemoth) et le
	# nombre (Ruche qui eclate en 4). Le final ne laisse plus choisir son deck.
	f4.entries = [
		_entry(E + "behemoth.tres", 1, 1.0),
		_entry(E + "hive.tres", 2, 2.5, 9.0),
		_entry(E + "rat_swarm.tres", 3, 2.0, 20.0),
	]
	_save(f4, "res://resources/waves/w7_4.tres")

	var f5 := WaveDef.new()
	f5.id = &"w7_5"
	f5.duration = 34.0
	f5.difficulty = 1.3
	# Avant-derniere vague : totem + glouton + jelly, les trois monstres qui
	# fabriquent du probleme si on les laisse vivre.
	f5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "glutton.tres", 1, 1.0, 9.0),
		_entry(E + "jelly.tres", 2, 2.5, 18.0),
		_entry(E + "sprite.tres", 4, 1.5, 27.0),
	]
	_save(f5, "res://resources/waves/w7_5.tres")

	var f6 := WaveDef.new()
	f6.id = &"w7_6_boss"
	f6.duration = 55.0
	f6.difficulty = 1.05
	f6.is_boss = true
	# CHRONOS, DEUXIEME FORME. L huissier du niveau 1 revient : on comprend enfin
	# qu il est le navetteur de la machine. Un SEUL Chronos, pas deux — l escorte
	# fait la difficulte, sinon le saut de PV depasserait le double autorise et,
	# surtout, la vague deviendrait une course impossible a lire.
	f6.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 10.0),
		_entry(E + "berserker.tres", 2, 2.5, 24.0),
		_entry(E + "sprite.tres", 4, 1.5, 38.0),
	]
	_save(f6, "res://resources/waves/w7_6_boss.tres")

	var lvl7 := LevelDef.new()
	lvl7.id = &"lvl_07"
	lvl7.display_name = "Le Metier du Monde"
	# `grass` comme le niveau 1 : l herbe est FAUSSE, c est un motif que les
	# divinites repetent. Le decor doit etre reconnu.
	lvl7.terrain = "grass"
	# Acte final : MEME composition que l acte I dans une teinte fausse. Le joueur
	# doit reconnaitre le decor du premier niveau et sentir que quelque chose cloche.
	lvl7.backdrop = "act4_origin"
	lvl7.waves = [f1, f2, f3, f4, f5, f6]
	lvl7.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "wisp.tres"),
		load(E + "rat_swarm.tres"), load(E + "hopper.tres"), load(E + "golem.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "ghoul_priest.tres"), load(E + "hive.tres"), load(E + "jelly.tres"),
		load(E + "glutton.tres"), load(E + "totem_guardian.tres"),
		load(E + "behemoth.tres"), load(E + "shade.tres"),
	]
	# DECK DE SYNTHESE. Le final envoie les DEUX registres, donc le deck porte les
	# deux : Meteore et Trait pour le blindage, Boule de feu et Resonance pour le
	# nombre. Les quatre cartes d histoire sont toutes la — c est leur paiement
	# narratif : le mage entre dans la matrice avec les sorts de ses quatre allies.
	lvl7.exploration_deck = _deck([
		[C + "common/fireball.tres", 3],
		[C + "common/arcane_bolt.tres", 3],
		[C + "rare/meteor.tres", 2],
		[C + "epic/resonance.tres", 2],
		[C + "rare/salt_spiral.tres", 1],
		[C + "rare/bone_recall.tres", 1],
		[C + "rare/chain_break.tres", 1],
		[C + "epic/void_grip.tres", 1],
		[C + "epic/weakness_mark.tres", 1],
		[C + "common/piercing_arrow.tres", 2],
		[C + "rare/stone_wall.tres", 1],
	])
	lvl7.objectives = [o1, o2, o3]
	lvl7.legendary_reward = load(C + "legendary/world_loom.tres")
	lvl7.next_levels = []
	lvl7.act = 4
	lvl7.subtitle = "Ce n est pas un monde, c est une matrice"
	lvl7.intro_text = "Une grille de fils tendus entre des etoiles, ou des divinites \
tissent les evenements. Elles ne sont ni bonnes ni mauvaises : elles sont OCCUPEES. \
L herbe sous tes pieds est le meme motif qu au premier matin, repete."
	lvl7.outro_text = "Il n y a pas de coupable, il y a un calcul. Ton royaume \
generait trop de futurs possibles : on l a coupe pour simplifier le motif. Et en \
remontant le temps, tu es devenu exactement ce que la machine voulait supprimer — le \
fil qui depasse. Reste a savoir si tu le coupes, si tu prends la place, ou si tu \
laisses la boucle ouverte."
	_save(lvl7, "res://resources/levels/lvl_07.tres")
