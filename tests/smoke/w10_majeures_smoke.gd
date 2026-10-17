class_name W10MajeuresSmoke
extends RefCounted
## SMOKE des MAJEURES SUR DES CIBLES QUI MEURENT (vague 10, chantier C1).
##
## Depuis la fusion de B1b, les bancs comptaient ~2200 SCRIPT ERROR par banc
## complet et le harnais zero : aucun etage ne jouait une majeure dont la cible
## MEURT, et est LIBEREE, avant la resolution (Barriere de givre, Triple jet,
## Barrage... sur une cible abattue pendant l incantation), ni un residu qui tue
## un monstre qui en porte plusieurs. C est pourtant le cas courant d une partie.
##
## Deux passages, chacun libere a chaque image comme le jeu (flush_freed) :
##   1. CHAQUE majeure du catalogue, prise seule, lancee deux fois sur une meute
##      de monstres freles, la cible du premier lancer tuee et liberee AVANT la
##      resolution ; puis le temps des rejeux et des residus. Chaque effet de
##      zone du lancer doit poser sa zone (un effet decale perdu en silence est
##      exactement le defaut corrige).
##   2. Une partie COURTE au bot du banc (AutoPick), chaque sort du deck portant
##      une majeure : les morts pendant l incantation y arrivent d elles-memes.
## La gate stderr du harnais fait le reste : une seule SCRIPT ERROR rougit.
##
## Fichier a part du pilote (smoke_driver.gd ne porte qu une ligne d appel) :
## plusieurs chantiers touchent le pilote en parallele.

const DT: float = 1.0 / 60.0
## Temps de monde apres les lancers : les rejeux partent a 0,8-1,2 s.
const SECONDES_APRES: float = 1.5
## Partie au bot : secondes de monde par partie, une partie par rang de majeure.
const SECONDES_DE_PARTIE: float = 75.0
const NIVEAU_DE_PARTIE: StringName = &"lvl_20"


static func run(driver: Node) -> void:
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	driver.add_child(g)
	g.running = false
	var n: int = _chaque_majeure(driver, g)
	g.queue_free()
	await driver.get_tree().process_frame
	print("[SMOKE] W10 majeures : %d majeures lancees sur des cibles liberees" % n)
	for rang in 2:
		await _partie_au_bot(driver, rang)
	RunState.reset()
	SpeedGauge.reset()


static func _monstre(pv: float) -> EnemyDef:
	var base: EnemyDef = ContentDB.enemies.get(&"gnome")
	var d: EnemyDef = base.duplicate() if base != null else EnemyDef.new()
	d.id = StringName("smoke_majeure_%d" % int(pv))
	d.max_hp = pv
	d.base_speed = 0.0
	return d


## Une meute sur trois rangees autour du point vise : les copies decalees (a
## +-150..260 px, vers le haut jusqu a 440 px) ont toutes de quoi mordre. Des
## freles (1 PV, ils meurent au premier coup) et des moyens (25 PV, ils portent
## des residus et meurent en cours de route).
static func _meute(bf: Battlefield, frele: EnemyDef, moyen: EnemyDef) -> void:
	var k: int = 0
	for y in [900.0, 690.0, 480.0]:
		for i in 9:
			var x: float = 540.0 + (i - 4) * 115.0
			bf.spawn_enemy(frele if k % 2 == 0 else moyen, x, 1.0, Vector2(x, y))
			k += 1


static func _contexte(g: GameController, c: SpellCard, ou: Vector2, cible: Enemy) -> CastContext:
	var ctx := CastContext.make(g.battlefield, c)
	ctx.caster = g
	ctx.target_position = ou
	var d: Vector2 = ou - g.mage_position()
	ctx.direction = d.normalized() if d.length() > 1.0 else Vector2.UP
	ctx.target_enemy = cible
	return ctx


## Le nombre de zones au sol que le lancer doit poser (une par effet
## ground_zone, copies decalees comprises).
static func _zones_attendues(c: SpellCard) -> int:
	var n: int = 0
	for s in RunState.cast_specs(c):
		if s != null and s.key == &"ground_zone":
			n += 1
	return n


static func _chaque_majeure(driver: Node, g: GameController) -> int:
	var bf: Battlefield = g.battlefield
	var frele: EnemyDef = _monstre(1.0)
	var moyen: EnemyDef = _monstre(25.0)
	var ou := Vector2(540.0, 900.0)
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var n: int = 0
	var attendues: int = 0
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c == null or c.is_passive:
			continue
		for m: MajorUpgradeDef in c.major_upgrades:
			if m == null:
				continue
			attendues += 1
			RunState.reset()
			SpeedGauge.reset()
			SpeedGauge.set_speed_percent(150)
			RunState.upgrades_taken[c.id] = [RunState.major_id_of(m)]
			bf.clear_all()
			_meute(bf, frele, moyen)
			# 1) La cible du lacher meurt pendant l incantation et est liberee.
			var victime: Enemy = bf.spawn_enemy(frele, ou.x, 1.0, ou)
			var ctx: CastContext = _contexte(g, c, ou, victime)
			bf.damage_enemy(victime, 999.0, null)
			g.flush_freed()
			var zones_avant: int = bf.zones.size()
			EffectRegistry.cast(c, ctx)
			var posees: int = bf.zones.size() - zones_avant
			var voulues: int = _zones_attendues(c)
			if posees < voulues:
				driver.call("_fail", "majeure %s/%s sur cible liberee : %d zone(s) posee(s) sur %d"
					% [c.id, m.id, posees, voulues])
			# 2) Un second lancer, cible vivante et frele : elle meurt au premier
			#    effet, les copies et les rejeux la voient morte.
			var frele_vivant: Enemy = bf.enemy_nearest_to(ou, 400.0)
			EffectRegistry.cast(c, _contexte(g, c, ou, frele_vivant))
			g.flush_freed()
			var t: float = 0.0
			while t < SECONDES_APRES:
				bf.simulate(DT)
				g.flush_freed()
				t += SpeedGauge.world_delta(DT)
				SpeedGauge.set_speed_percent(maxi(SpeedGauge.speed_percent, 150))
			n += 1
	if n != attendues or n == 0:
		driver.call("_fail", "W10 majeures : %d lancees sur %d au catalogue" % [n, attendues])
	bf.clear_all()
	RunState.reset()
	return n


## Une partie au bot du banc, chaque sort du deck (et de la main) portant sa
## majeure de rang `rang`. Ni victoire ni defaite exigees : seulement que tout
## se resolve sans erreur, cibles abattues pendant l incantation comprises.
static func _partie_au_bot(driver: Node, rang: int) -> void:
	var level: LevelDef = ContentDB.levels.get(NIVEAU_DE_PARTIE)
	if level == null:
		driver.call("_fail", "W10 majeures : %s introuvable" % NIVEAU_DE_PARTIE)
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	driver.add_child(g)
	RunState.set_seed(4100 + rang * 7)
	g.start_level(level, GameEnums.Mode.EXPLORATION)
	g.running = false          # apres start_level (piege : start_level le remet)
	var marquees: int = 0
	var vus: Dictionary = {}
	for c: SpellCard in RunState.deck + RunState.hand:
		if c == null or c.is_passive or vus.has(c.id) or c.major_upgrades.is_empty():
			continue
		vus[c.id] = true
		var m: MajorUpgradeDef = c.major_upgrades[mini(rang, c.major_upgrades.size() - 1)]
		RunState.upgrades_taken[c.id] = [RunState.major_id_of(m)]
		marquees += 1
	if marquees == 0:
		driver.call("_fail", "W10 majeures : aucun sort du deck de %s ne porte de majeure"
			% NIVEAU_DE_PARTIE)
	var t: float = 0.0
	var jouees: int = 0
	while t < SECONDES_DE_PARTIE:
		g.simulate(DT)
		t += DT
		if not g.caster.is_busy() and AutoPick.try_play(g):
			jouees += 1
		if RunState.pending_offer.size() > 0:
			RunState.pick_offer(AutoPick.offer_index(RunState.pending_offer, []))
		g.flush_freed()
		if (SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0) or g.spawner.is_finished():
			break
	print("[SMOKE] W10 majeures : partie au bot (rang %d) %d sorts a majeure, %d lancers, %.0f s"
		% [rang, marquees, jouees, t])
	if jouees == 0:
		driver.call("_fail", "W10 majeures : le bot n a rien lance (rang %d)" % rang)
	RunState.pending_offer.clear()
	g.queue_free()
	await driver.get_tree().process_frame
