class_name LegendeBordShowcase
extends RefCounted
## VITRINE (etage visual) : la LEGENDE au-dessus des monstres colles aux bords
## du terrain (vague 10, chantier C1).
##
## La boite de Fx.mech_label (420 px centres sur le monstre) n etait jamais
## ramenee dans le cadre : pres du bord gauche, « GARDE : les coups glissent »
## etait coupee (capture du 17/10). Ici, une colonne de monstres a legende
## contre CHAQUE bord — Gardien d ossements garde levee, voleur de sorts (la
## legende la plus longue), cameleon (logos) — puis :
##   - CONTROLE : chaque legende et chaque rangee de logos tient dans le
##     terrain VISIBLE : a droite a la marge (Fx.MECH_LABEL_MARGIN), a gauche au
##     bord de la jauge de vitesse (Fx.MECH_LABEL_MARGIN_LEFT) ;
##   - CAPTURE `legende_bords`, a lire.
## En headless rien n est construit (Fx inerte) : la vitrine ne tourne qu en
## fenetre reelle, ou son controle a un sens.
##
## Fichier a part du pilote (smoke_driver.gd ne porte qu une ligne d appel).

const DT: float = 1.0 / 60.0
const GAUCHE: float = 45.0
const DROITE: float = 1035.0


static func run(driver: Node) -> void:
	if not bool(driver.get("_visual")):
		return
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		driver.call("_fail", "vitrine legendes : lvl_01 introuvable")
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	driver.add_child(g)
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false          # apres start_level (piege : start_level le remet)
	var bf: Battlefield = g.battlefield
	bf.clear_all()
	RunState.draw(GameConfig.MAX_HAND_SIZE)

	var monstres: Array[Enemy] = []
	for x in [GAUCHE, DROITE]:
		# La colonne de droite est DECALEE vers le bas : deux legendes longues sur
		# la meme rangee se chevaucheraient au milieu, ce qui n arrive pas en jeu
		# et brouillerait la capture.
		var dy: float = 0.0 if x == GAUCHE else 160.0
		var garde: Enemy = bf.spawn_enemy(_gardien(), x, 1.0, Vector2(x, 460.0 + dy))
		var voleur: Enemy = bf.spawn_enemy(_voleur(), x, 1.0, Vector2(x, 780.0 + dy))
		var cam: Enemy = bf.spawn_enemy(_cameleon(), x, 1.0, Vector2(x, 1100.0 + dy))
		for e in [garde, voleur, cam]:
			if e == null:
				driver.call("_fail", "vitrine legendes : un monstre n a pas pu naitre")
			else:
				monstres.append(e)
		if garde != null:
			garde.call("_open_reflect", 60.0)   # garde LEVEE pour toute la scene
	var t: float = 0.0
	while t < 0.8:
		bf.simulate(DT)
		t += SpeedGauge.world_delta(DT)
	await driver.get_tree().process_frame

	var vues: int = 0
	for e in monstres:
		for nom in ["_mech_label", "_cham_chips"]:
			var c: Variant = e.get(nom)
			if c == null or not is_instance_valid(c) or not (c as Control).visible:
				continue
			vues += 1
			var r: Rect2 = (c as Control).get_global_rect()
			# A gauche, la jauge de vitesse du HUD couvre le terrain : la legende
			# s arrete a son bord (Fx.MECH_LABEL_MARGIN_LEFT).
			var gauche_min: float = Fx.MECH_LABEL_MARGIN_LEFT - 1.0
			var droite_max: float = GameConfig.BATTLEFIELD_WIDTH - Fx.MECH_LABEL_MARGIN + 1.0
			if r.position.x < gauche_min or r.end.x > droite_max:
				driver.call("_fail", "vitrine legendes : %s de %s hors du terrain [%.0f, %.0f]"
					% [nom, e.definition.id, r.position.x, r.end.x])
	# Six monstres : six legendes (garde, vol, et la place des logos du
	# cameleon n est une legende que s il a autre chose a dire) et deux rangees
	# de logos au moins.
	if vues < 6:
		driver.call("_fail", "vitrine legendes : %d legende(s) visible(s) seulement" % vues)
	await driver._shot("legende_bords")
	g.queue_free()
	await driver.get_tree().process_frame
	RunState.reset()
	SpeedGauge.reset()


## Le Gardien d ossements du catalogue, immobile : sa feuille et sa garde.
static func _gardien() -> EnemyDef:
	var base: EnemyDef = ContentDB.enemies.get(&"bone_guard")
	var d: EnemyDef = base.duplicate() if base != null else EnemyDef.new()
	d.id = &"vitrine_legende_garde"
	d.base_speed = 0.0
	d.max_hp = 5000.0
	if d.guard_block_pct <= 0.0:
		d.guard_block_pct = 60.0
	d.reflect_interval = maxf(d.reflect_interval, 1.0)
	d.reflect_window = maxf(d.reflect_window, 0.5)
	return d


## Un voleur de sorts qui vole tout de suite et ne lance pas avant la capture :
## « VOLE : <NOM DU SORT> (60 s) », la legende la plus longue du jeu.
static func _voleur() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"vitrine_legende_voleur"
	d.display_name = "voleur"
	d.max_hp = 5000.0
	d.base_speed = 0.0
	d.base_radius = 40.0
	d.power = 2
	d.anim_key = &"mageguardian_magenta"
	d.steal_interval = 0.3
	d.steal_cast_delay = 60.0
	d.steal_damage_per_cast_second = 1.0
	return d


static func _cameleon() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"vitrine_legende_cameleon"
	d.display_name = "cameleon"
	d.max_hp = 5000.0
	d.base_speed = 0.0
	d.base_radius = 40.0
	d.power = 2
	d.anim_key = &"slime_ghost"
	d.chameleon_interval = 30.0
	d.chameleon_elements = [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.ICE,
		GameEnums.DamageTag.POISON, GameEnums.DamageTag.LIGHTNING]
	d.chameleon_weak_mult = 1.5
	d.chameleon_resist_mult = 0.5
	return d
