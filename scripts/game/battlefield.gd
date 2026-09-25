class_name Battlefield
extends Node2D
## Champ de bataille : monstres, zones au sol, allies, murs, tirs ennemis.
## Expose l API que les handlers d effet appellent via CastContext, et gere les
## comportements qui impliquent plusieurs monstres (aura, soin, gobage, division).

signal enemy_killed(definition: EnemyDef)
## `source` : le monstre responsable, pour que l ecran de defaite puisse dire au
## joueur ce qui l a tue. Null si le coup vient d un projectile dont le tireur
## est deja mort.
signal mage_hit(damage: int, source: EnemyDef)

const ENEMY_SCENE: String = "res://scenes/game/Enemy.tscn"

var enemies: Array[Enemy] = []
var zones: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var shots: Array[Dictionary] = []
## Spirales qui aspirent les monstres vers un point. Separees des zones au sol :
## une zone agit sur les PV, un vortex agit sur la POSITION, et le joueur doit
## pouvoir superposer les deux (aspirer dans une mare de venin).
var vortices: Array[Dictionary] = []
## Accessoires PLANTES : arbres provocateurs, semis empoisonnes, nappes d eau.
## Voir TerrainProp. Separes des murs, qui BLOQUENT un passage et se contournent :
## un accessoire ne bloque rien, il change ce que les monstres VEULENT faire —
## viser l arbre, ou patauger contre le courant. C est la famille de sorts que le
## testeur demandait (« arbre qui attire », « eau qui ralentit ») et qui manquait
## completement : le Mur de pierre etait le seul sort de terrain du jeu.
var props: Array[TerrainProp] = []

## Grille de navigation partagee : les monstres la consultent pour contourner
## les murs. Sans mur pose, ils descendent tout droit.
var nav: NavGrid = null

var _global_slow_factor: float = 1.0
var _global_slow_time: float = 0.0
var cast_haste: float = 1.0
var _cast_haste_time: float = 0.0
var _reverse_time: float = 0.0

## Vitesse des tirs ennemis en px/s a x1.
const SHOT_SPEED: float = 420.0


func _ready() -> void:
	if nav == null:
		nav = NavGrid.new()


## Avance toute la simulation. delta BRUT : la mise a l echelle se fait ici.
func simulate(delta: float) -> void:
	var wd: float = SpeedGauge.world_delta(delta)

	if _global_slow_time > 0.0:
		_global_slow_time -= wd
		if _global_slow_time <= 0.0:
			_global_slow_factor = 1.0
	if _cast_haste_time > 0.0:
		_cast_haste_time -= delta
		if _cast_haste_time <= 0.0:
			cast_haste = 1.0
	if _reverse_time > 0.0:
		_reverse_time -= wd

	_simulate_zones(wd)
	_simulate_vortices(wd)
	# AVANT les monstres : un accessoire qui vient d expirer ne doit pas attirer
	# une derniere fois pendant la meme frame, sinon un arbre mort detournerait un
	# monstre vers un point ou il n y a plus rien.
	_simulate_props(wd)
	_simulate_allies(wd)
	_simulate_walls(wd)
	_simulate_shots(wd)
	_simulate_support(wd)

	var buff: float = _buff_multiplier()
	# Copie : la liste est modifiee pendant l iteration (morts, arrivees).
	for e in enemies.duplicate():
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		e.speed_scale = _global_slow_factor * buff
		e.advance(wd)
		# COURANT : applique APRES le deplacement, et pas comme un facteur de
		# vitesse. Un facteur ne peut que freiner (il tend vers zero) ; le
		# courant, lui, doit pouvoir RENVERSER la descente, ce qui est toute la
		# difference entre la nappe d eau et le Champ de givre.
		_apply_current(e, wd)


func is_reversed() -> bool:
	return _reverse_time > 0.0


func _buff_multiplier() -> float:
	var m: float = 1.0
	for e in enemies:
		if e != null and is_instance_valid(e) and not e.is_dead() \
				and e.definition != null and e.definition.buff_speed_pct > 0.0:
			m += e.definition.buff_speed_pct * 0.01
	return m


func _alive(e: Enemy) -> bool:
	return e != null and is_instance_valid(e) and not e.is_dead()


## Cible valide pour un sort : vivante ET deja apparue. Distinct de `_alive`,
## qui sert aussi a compter les monstres restants — un monstre en train
## d apparaitre COMPTE (la vague ne doit pas se terminer sans lui) mais ne se
## frappe pas encore.
func _targetable(e: Enemy) -> bool:
	return _alive(e) and not e.is_spawning()


## Soigneurs et Gloutons : tout ce qui agit sur les AUTRES monstres.
func _simulate_support(wd: float) -> void:
	for e in enemies.duplicate():
		if not _alive(e) or e.definition == null:
			continue
		if e.definition.heal_per_second > 0.0:
			for other in enemies:
				if other != e and _alive(other):
					other.heal(e.definition.heal_per_second * wd)
			e.set_meta("heal_fx_t", float(e.get_meta("heal_fx_t", 0.0)) + wd)
			if float(e.get_meta("heal_fx_t")) >= 2.0:
				e.set_meta("heal_fx_t", 0.0)
				e.play_attack()
				Fx.heal_effect(self, e.position)
				AudioBus.play_sfx(&"heal")
		if e.definition.devours:
			_devour_nearby(e)


func _devour_nearby(glutton: Enemy) -> void:
	var reach: float = glutton.radius() + 30.0
	for prey in enemies.duplicate():
		if prey == glutton or not _targetable(prey) or prey.definition == null:
			continue
		if prey.definition.devours or prey.definition.is_boss():
			continue
		if prey.definition.power >= glutton.definition.power:
			continue
		if prey.position.distance_to(glutton.position) > reach:
			continue
		prey.absorb()
		enemies.erase(prey)
		prey.queue_free()
		glutton.grow(prey.max_hp() * 0.5, 0.18)


func _simulate_zones(wd: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z["time"] -= wd
		for e in enemies.duplicate():
			if not _targetable(e):
				continue
			if e.position.distance_to(z["pos"]) > z["radius"]:
				continue
			if z["dps"] > 0.0:
				_hit(e, z["dps"] * wd, z["tags"])
			if z["slow_pct"] > 0.0:
				e.apply_slow(1.0 - z["slow_pct"] * 0.01, 0.4)
		if z["time"] <= 0.0:
			var vn: Node = z.get("node")
			if vn != null and is_instance_valid(vn):
				vn.queue_free()
			zones.remove_at(i)


func _simulate_allies(wd: float) -> void:
	for i in range(allies.size() - 1, -1, -1):
		var a: Dictionary = allies[i]
		a["time"] -= wd
		a["cooldown"] -= wd
		if a["cooldown"] <= 0.0:
			var target: Enemy = _closest_enemy()
			if target != null:
				# Le tir se voit partir de l allie : sans cela le joueur ne fait
				# pas le lien entre l invocation et les degats.
				Fx.projectile(self, a.get("pos", Vector2.ZERO), target.position, Fx.COL_SUMMON)
				_hit(target, a["damage"], [GameEnums.DamageTag.SUMMON])
			a["cooldown"] = 1.0
		if a["time"] <= 0.0:
			var node: Node = a.get("node")
			if node != null and is_instance_valid(node):
				node.queue_free()
			allies.remove_at(i)


func _simulate_walls(wd: float) -> void:
	for i in range(walls.size() - 1, -1, -1):
		var w: Dictionary = walls[i]
		w["time"] -= wd
		if w["time"] <= 0.0:
			if nav != null:
				nav.unblock_cells(w["cells"])
			var node: Node = w.get("node")
			if node != null and is_instance_valid(node):
				node.queue_free()
			walls.remove_at(i)


## Projectiles ennemis : descendent vers le mage, frappent a la ligne.
func _simulate_shots(wd: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s["pos"] = s["pos"] + Vector2(0.0, SHOT_SPEED * wd)
		var node: Node2D = s.get("node")
		if node != null and is_instance_valid(node):
			node.position = s["pos"]
		# Un mur de pierre arrete les fleches : il protege du tir comme du contact.
		if _blocked_by_wall(s["pos"]):
			if node != null and is_instance_valid(node):
				node.queue_free()
			Fx.impact(self, s["pos"], Fx.COL_PHYSICAL)
			shots.remove_at(i)
			continue
		if s["pos"].y >= GameConfig.MAGE_LINE_Y:
			if node != null and is_instance_valid(node):
				node.queue_free()
			shots.remove_at(i)
			# BOUCLIER PUIS PV, comme un contact.
			SpeedGauge.take_hit(int(s["damage"]))
			mage_hit.emit(int(s["damage"]), s.get("shooter"))


## Le point est-il dans un mur ? Les murs sont peu nombreux (un ou deux), une
## boucle directe est plus claire qu un index spatial.
func _blocked_by_wall(point: Vector2) -> bool:
	for w in walls:
		var centre: Vector2 = w.get("center", Vector2.INF)
		if centre == Vector2.INF:
			continue
		var demi_large: float = float(w.get("half_width", 0.0))
		var demi_haut: float = float(w.get("thickness", 60.0)) * 0.5
		if absf(point.x - centre.x) <= demi_large and absf(point.y - centre.y) <= demi_haut:
			return true
	return false


func enemy_shoot(from: Enemy, damage: int) -> void:
	var pos: Vector2 = from.position + Vector2(0.0, from.radius())
	var node: Node = Fx.shot_visual(self, pos, from.definition.color if from.definition != null else Color.WHITE)
	AudioBus.play_sfx(&"arrow")
	# On retient le TIREUR, pas le noeud : le monstre peut mourir avant que sa
	# fleche arrive, et l ecran de defaite doit quand meme pouvoir le nommer.
	shots.append({"pos": pos, "damage": damage, "node": node,
		"shooter": from.definition})


func shot_count() -> int:
	return shots.size()


func _closest_enemy() -> Enemy:
	var best: Enemy = null
	var best_y: float = -INF
	for e in enemies:
		if not _targetable(e):
			continue
		if e.position.y > best_y:
			best_y = e.position.y
			best = e
	return best


func spawn_enemy(def: EnemyDef, x: float, difficulty: float = 1.0,
		at: Vector2 = Vector2.INF) -> Enemy:
	var packed: PackedScene = load(ENEMY_SCENE)
	if packed == null:
		push_error("Scene d ennemi introuvable : %s" % ENEMY_SCENE)
		return null
	var e: Enemy = packed.instantiate()
	# Une boule de poison n est pas une creature : elle n a rien a faire dans le
	# bestiaire, que le joueur consulte pour apprendre ce qu il affronte.
	if not def.projectile:
		# Pas les projectiles : ils ne sont pas des especes, et les compter
		# fausserait aussi bien le "N / total" du bestiaire que les succes
		# "rencontrer N especes".
		if not def.projectile:
			SaveData.discover_enemy(def.id)  # rencontre memorisee pour le bestiaire
	e.setup(def, difficulty)
	e.nav = nav
	e.battlefield = self
	# Position AVANT add_child : _ready() s execute des l ajout.
	var spontane: bool = at == Vector2.INF
	e.position = at if not spontane else Vector2(x, GameConfig.SPAWN_LINE_Y)
	e.died.connect(_on_enemy_died)
	e.reached_mage.connect(_on_enemy_reached_mage)
	enemies.append(e)
	add_child(e)
	# Fondu d apparition pour les monstres de VAGUE seulement. Un monstre pose a
	# une position explicite (division, invocation, vitrine) doit exister tout de
	# suite : le rendre intouchable au milieu du combat offrirait une demi-seconde
	# d immunite a chaque sbire, en plein dans les zones deja posees par le joueur.
	if spontane:
		e.begin_spawn_fade()
	return e


func _on_enemy_died(e: Enemy) -> void:
	var def: EnemyDef = e.definition
	var where: Vector2 = e.position
	var diff: float = e.difficulty
	enemies.erase(e)
	Fx.death(self, where, e.radius())
	AudioBus.play_sfx(&"explosion" if (def != null and def.is_boss()) else &"enemy_die")
	if def != null:
		# Une boule de poison ne rapporte ni XP ni statistique de chasse : sinon
		# le joueur monterait de niveau en tapant des munitions au lieu de
		# s en prendre au Planogo qui les tire.
		if not def.projectile:
			RunState.gain_xp(def.base_xp)
			enemy_killed.emit(def)
		# Division / explosion : les enfants naissent la ou le parent est mort.
		# PASSIF "Combustion" (le "fire boom" du testeur) : le monstre explose en
		# mourant et blesse ses voisins. C est ici et pas dans un handler d effet
		# parce qu aucune carte ne le declenche : c est la MORT elle-meme qui devient
		# une source de degats. has_passive() teste deja le seuil de vitesse.
		if not def.projectile:
			_passive_death_blast(where, e.radius())
			# PASSIF "Pulsation" : chaque mort repousse la jauge de vitesse. Le joueur
			# qui nettoie vite remonte vers ses autres seuils au lieu de les attendre.
			var poussee: float = RunState.passive_magnitude(&"passive_kill_speed")
			if poussee > 0.0:
				SpeedGauge.set_speed_percent(SpeedGauge.speed_percent + int(poussee))
		if def.split_into != null and def.split_count > 0:
			for i in def.split_count:
				var offset := Vector2((i - (def.split_count - 1) * 0.5) * 44.0, 0.0)
				var child: Enemy = spawn_enemy(def.split_into, where.x, diff, where + offset)
				if child != null:
					child.position.x = clampf(child.position.x, 40.0, GameConfig.BATTLEFIELD_WIDTH - 40.0)
	e.queue_free()


## Explosion a la mort d un monstre (passif "Combustion", et sa version
## legendaire "Reaction en chaine").
##
## `_chain_depth` borne la recursion : sans lui, une explosion qui tue un voisin
## rappellerait _on_enemy_died() pendant que la premiere est encore en cours et
## une vague dense partirait en boucle jusqu a la pile pleine. La chaine est le
## SEUL passif autorise a repartir, et seulement CHAIN_MAX fois.
const CHAIN_MAX: int = 3
var _chain_depth: int = 0


func _passive_death_blast(where: Vector2, rayon_mort: float) -> void:
	var degats: float = RunState.passive_magnitude(&"passive_death_blast")
	if degats <= 0.0:
		return
	# La chaine ne relance l explosion que si le passif legendaire est actif.
	if _chain_depth > 0 and not RunState.has_passive(&"passive_chain_blast"):
		return
	if _chain_depth >= CHAIN_MAX:
		return
	var rayon: float = maxf(rayon_mort, 40.0) * 2.6
	# Teinte de braise : l explosion doit se lire comme du feu, pas comme un sort.
	Fx.impact(self, where, Color(1.0, 0.55, 0.15), rayon)
	_chain_depth += 1
	# Copie : _hit() peut tuer, donc modifier `enemies` pendant l iteration.
	for voisin in enemies_in_radius(where, rayon):
		var cible: Enemy = voisin as Enemy
		if cible == null or not _alive(cible):
			continue
		# Tableau de tags NON TYPE : Godot 4.4 refuse de convertir Array vers
		# Array[T] au passage d argument (piege documente en memoire).
		var tags: Array = []
		_hit(cible, degats, tags)
	_chain_depth -= 1


## Vitesse relevee juste avant le dernier coup encaisse (passif "Verrou temporel").
var speed_before_hit: int = 100


func _on_enemy_reached_mage(e: Enemy) -> void:
	var dmg: int = e.definition.contact_hit() if e.definition != null else 5
	enemies.erase(e)
	e.queue_free()
	# Photo de la vitesse AVANT l encaissement : le passif legendaire "Verrou
	# temporel" en a besoin pour savoir combien la jauge a perdu. On la prend ici
	# plutot que de toucher a SpeedGauge.take_hit(), dont le chemin bouclier-puis-PV
	# doit rester le seul et rester intact (voir memoire).
	speed_before_hit = SpeedGauge.speed_percent
	# BOUCLIER PUIS PV : toute la regle vit dans SpeedGauge.take_hit().
	SpeedGauge.take_hit(dmg)
	mage_hit.emit(dmg, e.definition)


func alive_count() -> int:
	var n: int = 0
	for e in enemies:
		if _alive(e):
			n += 1
	return n


func clear_all() -> void:
	for e in enemies.duplicate():
		if e != null and is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	zones.clear()
	# Les sprites d allies doivent partir avec eux, sinon ils restent a l ecran
	# d une partie a la suivante.
	for a in allies:
		var an: Node = a.get("node")
		if an != null and is_instance_valid(an):
			an.queue_free()
	allies.clear()
	for v in vortices:
		var vnode: Node = v.get("node")
		if vnode != null and is_instance_valid(vnode):
			vnode.queue_free()
	vortices.clear()
	for w in walls:
		var node: Node = w.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	walls.clear()
	# Les accessoires plantes doivent partir avec la partie : un arbre oublie
	# resterait a l ecran d une vague a la suivante et continuerait a provoquer.
	for p in props:
		if p.node != null and is_instance_valid(p.node):
			p.node.queue_free()
	props.clear()
	for s in shots:
		var node: Node = s.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	shots.clear()
	_reverse_time = 0.0
	if nav != null:
		nav.clear()


# --- Degats : point de passage unique ---

## Un autre monstre porteur d aura le couvre-t-il ?
func is_shielded_by_aura(e: Enemy) -> bool:
	for g in enemies:
		if g == e or not _alive(g) or g.definition == null:
			continue
		if g.definition.aura_shield_radius <= 0.0:
			continue
		if g.position.distance_to(e.position) <= g.definition.aura_shield_radius:
			return true
	return false


## Multiplicateur de degats a une position (zones de vulnerabilite).
func damage_multiplier_at(pos: Vector2) -> float:
	var m: float = 1.0
	for z in zones:
		var vm: float = float(z.get("vuln_mult", 1.0))
		if vm > 1.0 and pos.distance_to(z["pos"]) <= z["radius"]:
			m = maxf(m, vm)
	return m


func _hit(e: Enemy, amount: float, tags: Array) -> bool:
	if not _targetable(e):
		return false
	if is_shielded_by_aura(e):
		return false
	# PASSIF "Apotheose" (legendaire) : la vitesse ne multiplie plus seulement
	# l XP, elle multiplie les DEGATS. Applique ici, au point de passage unique
	# des degats, pour qu aucune carte ni aucun autre passif n y echappe.
	var total: float = amount * damage_multiplier_at(e.position) \
		* RunState.passive_damage_multiplier()
	# RESISTANCE ELEMENTAIRE du monstre. Elle s applique ICI, au point de passage
	# unique des degats, et nulle part ailleurs : une source qui la contournerait
	# ignorerait tout le bestiaire.
	# Elle vient EN DERNIER, apres la vulnerabilite de terrain et les passifs :
	# une Marque de faiblesse (x2) sur un monstre qui resiste a 50 % redonne des
	# degats normaux, ce qui est la lecture attendue par le joueur — la zone
	# COMPENSE la resistance, elle ne l ecrase pas.
	if e.definition != null:
		total *= e.definition.resistance_to_tags(tags)
	var applied: bool = e.take_damage(total, tags)
	if applied:
		Fx.hit_flash(e)
		AudioBus.play_sfx(&"hit")
		# PASSIF "Morsure de givre" : TOUT degat ralentit, quel que soit l element
		# du sort. C est une regle, pas un bonus chiffre : les sorts de feu se
		# mettent a freiner les monstres.
		var chill: float = RunState.passive_magnitude(&"passive_chill_on_hit")
		if chill > 0.0:
			e.apply_slow(maxf(0.25, 1.0 - chill * 0.01), 1.5)
	return applied


# --- API appelee par les handlers d effet ---

func damage_enemy(target: Object, amount: float, card: SpellCard) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var tags: Array = card.tags if card != null else []
	return _hit(target as Enemy, amount, tags)


func enemies_in_line(origin: Vector2, dir: Vector2, width: float, max_targets: int) -> Array:
	var out: Array = []
	var d: Vector2 = dir.normalized()
	var half: float = maxf(width, 40.0) * 0.5
	for e in enemies:
		if not _targetable(e):
			continue
		var to_e: Vector2 = e.position - origin
		if to_e.dot(d) < 0.0:
			continue  # derriere le lanceur
		var perp: float = absf(to_e.x * d.y - to_e.y * d.x)
		if perp <= half:
			out.append(e)
		if out.size() >= max_targets:
			break
	return out


func enemies_in_radius(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for e in enemies:
		if _targetable(e) and e.position.distance_to(center) <= radius:
			out.append(e)
	return out


## Renvoie la zone posee. Les appelants historiques ignorent le retour ; l arbre
## empoisonne, lui, en a besoin pour ACCROCHER la zone a sa propre vie (voir
## TerrainProp.zone) : sans cette poignee, abattre l arbre laisserait le poison.
func spawn_ground_zone(pos: Vector2, radius: float, duration: float,
		dps: float, slow_pct: float, card: SpellCard, vuln_mult: float = 1.0) -> Dictionary:
	var col: Color = Fx.color_for(card.tags if card != null else [])
	if vuln_mult > 1.0:
		col = Fx.COL_VULN
	var vis: Node = Fx.zone_visual(self, pos, maxf(radius, 10.0), duration, col,
		Fx.card_sheet(card))
	var z: Dictionary = {
		"pos": pos,
		"radius": maxf(radius, 10.0),
		"time": maxf(duration, 0.1),
		"dps": dps,
		"slow_pct": slow_pct,
		"vuln_mult": vuln_mult,
		"tags": (card.tags if card != null else []) as Array,
		"node": vis,
	}
	zones.append(z)
	return z


func apply_global_enemy_slow(slow_pct: float, duration: float) -> void:
	_global_slow_factor = clampf(1.0 - slow_pct * 0.01, 0.1, 3.0)
	_global_slow_time = duration


func apply_cast_haste(pct: float, duration: float) -> void:
	cast_haste = clampf(1.0 + pct * 0.01, 0.1, 5.0)
	_cast_haste_time = duration


## Volte-face : tous les monstres remontent pendant `duration` secondes.
func apply_reverse(duration: float) -> void:
	_reverse_time = maxf(_reverse_time, duration)


## Invoque un allie qui frappe le monstre le plus proche.
##
## Il a une POSITION et un sprite : le testeur signalait qu on ne voyait pas
## l invocation. Elle existait bien, mais seulement comme une entree de donnees —
## le joueur payait une carte pour un effet invisible.
func spawn_ally(duration: float, damage: float) -> void:
	# Devant le mage, decale au hasard : deux allies ne se superposent pas.
	var pos := Vector2(
		clampf(GameConfig.BATTLEFIELD_WIDTH * 0.5 + randf_range(-220.0, 220.0),
			120.0, GameConfig.BATTLEFIELD_WIDTH - 120.0),
		GameConfig.MAGE_LINE_Y - 190.0)
	var node: Node = Fx.sprite(self, "magicbubbles", pos, 130.0, true,
		Color(Fx.COL_SUMMON.r, Fx.COL_SUMMON.g, Fx.COL_SUMMON.b, 0.95))
	allies.append({"time": duration, "damage": damage, "cooldown": 0.5,
		"pos": pos, "node": node})


## Pose un mur qui bloque le pathfinding pendant `duration` secondes.
func spawn_wall(center: Vector2, half_width: float, duration: float,
		thickness: float = 60.0) -> void:
	if nav == null:
		nav = NavGrid.new()
	var cells: Array[Vector2i] = nav.block_rect(center, half_width, thickness)
	if cells.is_empty():
		return
	AudioBus.play_sfx(&"wall")
	var node: Node = Fx.spawn_wall_visual(self, center, half_width, thickness, duration)
	walls.append({"cells": cells, "time": maxf(duration, 0.1), "node": node,
		"center": center, "half_width": half_width, "thickness": thickness})


func wall_count() -> int:
	return walls.size()


## Monstre vivant le plus proche d un point : sert au ciblage au doigt.
func enemy_nearest_to(point: Vector2, max_dist: float = 260.0) -> Enemy:
	var best: Enemy = null
	var best_d: float = max_dist
	for e in enemies:
		if not _targetable(e):
			continue
		var d: float = e.position.distance_to(point)
		if d < best_d:
			best_d = d
			best = e
	return best if best != null else _closest_enemy()


# --- Sorts demandes par le testeur : repousse, vortex, dissipation, murs cassables ---

## Repousse les monstres d un point. Le deplacement est INSTANTANE et non
## simule : un souffle doit se voir au moment ou la carte part, pas s etaler sur
## une seconde pendant laquelle le joueur ne sait plus ce qu il a lance.
##
## Le monstre est reclampe dans le terrain : pousse dehors il deviendrait
## invisible, increvable, et continuerait a descendre hors de portee des sorts.
func knockback_from(center: Vector2, radius: float, push: float) -> int:
	var touches: int = 0
	for e in enemies_in_radius(center, radius):
		var enemy: Enemy = e as Enemy
		var away: Vector2 = enemy.position - center
		# Pile au centre : on choisit le haut, la direction qui aide le joueur.
		var dir: Vector2 = away.normalized() if away.length() > 1.0 else Vector2.UP
		# Degressif : au bord de la zone le souffle ne porte presque plus.
		var force: float = push * (1.0 - clampf(away.length() / maxf(radius, 1.0), 0.0, 1.0) * 0.5)
		var cible: Vector2 = enemy.position + dir * force
		enemy.position = Vector2(
			clampf(cible.x, 40.0, GameConfig.BATTLEFIELD_WIDTH - 40.0),
			clampf(cible.y, GameConfig.SPAWN_LINE_Y, GameConfig.MAGE_LINE_Y - 20.0))
		enemy.repath()
		touches += 1
	return touches


## Pose une spirale qui aspire. `pull` est une vitesse d aspiration en px/s a x1.
func spawn_vortex(center: Vector2, radius: float, duration: float, pull: float) -> void:
	var vis: Node = Fx.zone_visual(self, center, maxf(radius, 10.0), duration, Fx.COL_ARCANE)
	vortices.append({
		"pos": center,
		"radius": maxf(radius, 10.0),
		"time": maxf(duration, 0.1),
		"pull": pull,
		"node": vis,
	})


func vortex_count() -> int:
	return vortices.size()


## Aspiration : elle passe par `wd`, donc elle s accelere avec le multiplicateur
## comme tout le reste du monde. Sinon a x4 les monstres traverseraient la spirale.
func _simulate_vortices(wd: float) -> void:
	for i in range(vortices.size() - 1, -1, -1):
		var v: Dictionary = vortices[i]
		v["time"] -= wd
		for e in enemies.duplicate():
			# Immobile pendant son fondu : une spirale ne doit pas l arracher a
			# sa ligne d apparition avant meme qu il soit visible.
			if not _targetable(e):
				continue
			var vers: Vector2 = v["pos"] - e.position
			var d: float = vers.length()
			if d > v["radius"] or d < 4.0:
				continue
			var pas: float = minf(float(v["pull"]) * wd, d)
			e.position += vers / d * pas
			# Le chemin A* memorise vise depuis l ancienne position : sans
			# recalcul le monstre revient tout droit vers son ancien couloir.
			e.repath()
		if v["time"] <= 0.0:
			var node: Node = v.get("node")
			if node != null and is_instance_valid(node):
				node.queue_free()
			vortices.remove_at(i)


## Dissipation : retire aux monstres de la zone tout ce qu ils ont GAGNE
## (rage accumulee, bouclier de premier coup, ralentissement en cours).
## Renvoie le nombre de monstres nettoyes.
func dispel_at(center: Vector2, radius: float) -> int:
	var n: int = 0
	for e in enemies_in_radius(center, radius):
		(e as Enemy).dispel()
		n += 1
	if n > 0:
		Fx.impact(self, center, Fx.COL_ARCANE, radius)
	return n


## Frappe le mur qui recouvre `point`. Renvoie true si un mur a bien encaisse.
## Un mur sans PV (les murs temporaires) ignore les coups : seule la duree le tue.
func damage_wall_at(point: Vector2, amount: float) -> bool:
	for i in range(walls.size() - 1, -1, -1):
		var w: Dictionary = walls[i]
		if float(w.get("hp", 0.0)) <= 0.0:
			continue
		var centre: Vector2 = w.get("center", Vector2.INF)
		if centre == Vector2.INF:
			continue
		var demi_large: float = float(w.get("half_width", 0.0))
		var demi_haut: float = float(w.get("thickness", 60.0)) * 0.5
		if absf(point.x - centre.x) > demi_large or absf(point.y - centre.y) > demi_haut:
			continue
		w["hp"] = float(w["hp"]) - amount
		if float(w["hp"]) <= 0.0:
			_break_wall(i)
		return true
	return false


func _break_wall(index: int) -> void:
	var w: Dictionary = walls[index]
	if nav != null:
		nav.unblock_cells(w["cells"])
	var node: Node = w.get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	Fx.impact(self, w.get("center", Vector2.ZERO), Fx.COL_WALL,
		float(w.get("half_width", 60.0)))
	AudioBus.play_sfx(&"wall")
	walls.remove_at(index)


## Mur PERMANENT : il ne compte pas le temps, il compte les PV. Le seul moyen de
## le faire tomber est de le casser, ce qui donne enfin une raison aux monstres
## d attaquer le decor au lieu de l attendre.
##
## `duration = INF` traverse `_simulate_walls` sans jamais atteindre zero : aucune
## branche d expiration a ajouter, le meme code gere les deux sortes de murs.
func spawn_breakable_wall(center: Vector2, half_width: float, thickness: float,
		hp: float) -> void:
	spawn_wall(center, half_width, INF, thickness)
	if walls.is_empty():
		return
	walls[walls.size() - 1]["hp"] = maxf(hp, 1.0)


## PV restants du mur qui couvre `point`, 0.0 si aucun mur cassable la.
func wall_hp_at(point: Vector2) -> float:
	for w in walls:
		var centre: Vector2 = w.get("center", Vector2.INF)
		if centre == Vector2.INF:
			continue
		if absf(point.x - centre.x) <= float(w.get("half_width", 0.0)) \
				and absf(point.y - centre.y) <= float(w.get("thickness", 60.0)) * 0.5:
			return float(w.get("hp", 0.0))
	return 0.0


## Un monstre bloque (aucun chemin vers le mage) tape le mur devant lui.
## Appele par Enemy quand l A* ne rend rien : c est le seul moment ou le monstre
## a une raison de s en prendre au decor plutot que de contourner.
func enemy_strikes_wall(e: Enemy, world_delta: float) -> void:
	if e == null or e.definition == null:
		return
	var devant: Vector2 = e.position + Vector2(0.0, e.radius() + 20.0)
	damage_wall_at(devant, float(e.definition.contact_hit()) * 4.0 * world_delta)


# =====================================================================
# CHANTIER H — ACCESSOIRES DE TERRAIN (arbre provocateur, semis, nappe d eau)
#
# Le jeu n avait qu UN sort de terrain, le Mur de pierre, et il ne savait faire
# qu une chose : barrer un passage. Ces accessoires en font trois autres —
# attirer, empoisonner sur pied, renverser le courant — et se distinguent du mur
# sur le point qui compte : ils ne touchent PAS a la grille de navigation. Un
# arbre qu on contourne serait un mur en bois ; un arbre qu on va frapper est une
# provocation, donc du temps achete.


## Plante un accessoire. Renvoie l objet pose, pour que le handler puisse encore
## lui accrocher une zone sans que Battlefield ait a connaitre le poison.
func spawn_prop(kind: int, center: Vector2, duration: float, hp: float,
		taunt_radius: float = 0.0, current: float = 0.0, area: float = 0.0,
		sheet: String = "", tint: Color = Color.WHITE) -> TerrainProp:
	var p := TerrainProp.new()
	p.kind = kind
	# Jamais sur la ligne du mage ni hors terrain : un arbre plante sous le mage
	# attirerait les monstres exactement la ou on veut qu ils n aillent pas, et un
	# arbre hors cadre serait invisible et increvable.
	p.position = Vector2(
		clampf(center.x, 60.0, GameConfig.BATTLEFIELD_WIDTH - 60.0),
		clampf(center.y, GameConfig.SPAWN_LINE_Y + 60.0, GameConfig.MAGE_LINE_Y - 80.0))
	p.time_left = maxf(duration, 0.1)
	p.hp = maxf(hp, 0.0)
	p.max_hp = p.hp
	p.taunt_radius = maxf(taunt_radius, 0.0)
	p.current = current
	p.area = maxf(area, 0.0)
	p.reach = 70.0 if kind == TerrainProp.Kind.TREE else 40.0
	# L aire est transmise au visuel : c est elle que l anneau de la nappe trace,
	# et un anneau qui mentirait sur la portee serait pire que pas d anneau du tout
	# — le joueur s en sert pour decider ou poser le sort suivant.
	p.node = Fx.prop_visual(self, p.position, kind, p.time_left, sheet, tint, p.area)
	AudioBus.play_sfx(&"wall" if kind == TerrainProp.Kind.TREE else &"drip_frost")
	props.append(p)
	return p


func prop_count() -> int:
	return props.size()


## PV restants de l accessoire qui couvre `point`, 0.0 s il n y en a aucun.
func prop_hp_at(point: Vector2) -> float:
	for p in props:
		if p.is_breakable() and p.covers(point):
			return p.hp
	return 0.0


## Frappe l accessoire qui couvre `point`. Renvoie true s il a encaisse.
##
## Meme forme que `damage_wall_at()` volontairement : c est ce que les monstres
## bloques appellent deja, et un joueur ne distingue pas « frapper un mur » de
## « frapper un arbre » — seul le resultat change.
func damage_prop_at(point: Vector2, amount: float) -> bool:
	for i in range(props.size() - 1, -1, -1):
		var p: TerrainProp = props[i]
		if not p.is_breakable() or not p.covers(point):
			continue
		if p.take_damage(amount):
			_destroy_prop(i, true)
		return true
	return false


## L accessoire que ce monstre doit viser, ou null s il continue vers le mage.
##
## Le PLUS PROCHE gagne : deux arbres plantes cote a cote ne doivent pas se
## disputer un monstre a chaque frame, ce qui le ferait osciller entre les deux
## sans jamais frapper ni l un ni l autre.
func taunt_target_for(point: Vector2) -> TerrainProp:
	var best: TerrainProp = null
	var best_d: float = INF
	for p in props:
		if not p.attracts(point) or not p.is_alive():
			continue
		var d: float = p.position.distance_to(point)
		if d < best_d:
			best_d = d
			best = p
	return best


func flood_count() -> int:
	var n: int = 0
	for p in props:
		if p.current != 0.0:
			n += 1
	return n


## Le courant, applique apres le deplacement du monstre. Positif = vers le HAUT.
##
## Il passe par `world_delta`, donc il s accelere avec le multiplicateur comme
## tout le reste du monde : sinon a 500 % les monstres traverseraient la nappe
## comme si elle n existait pas.
##
## La resistance au RALENTISSEMENT s applique ici aussi : une nappe qui repousse
## un golem de pierre aussi fort qu un lutin viderait la table de resistances de
## son sens du cote ou elle compte le plus, le controle.
func _apply_current(e: Enemy, world_delta: float) -> void:
	if props.is_empty() or e.is_spawning():
		return
	var poussee: float = 0.0
	for p in props:
		if p.floods(e.position):
			poussee += p.current
	if poussee == 0.0:
		return
	if e.definition != null:
		poussee *= e.definition.resistance_to(GameEnums.DamageTag.SLOW)
	if poussee == 0.0:
		return
	# Jamais au-dessus de la ligne d apparition : repousse plus haut, le monstre
	# sortirait du cadre et redescendrait ensuite gratuitement.
	var avant: float = e.position.y
	e.position.y = maxf(e.position.y - poussee * world_delta, GameConfig.SPAWN_LINE_Y)
	# `repath()` SEULEMENT si le monstre a vraiment recule, et seulement quand un
	# mur est pose. Appele a chaque frame il relancerait un A* complet par monstre
	# et par image des qu un Mur de pierre est en jeu — le courant coute alors plus
	# cher que toute la vague. Sans mur, `_recompute_path` sort immediatement, mais
	# on ne paie meme pas l appel.
	if nav != null and nav.blocked_count() > 0 and e.position.y < avant - 0.5:
		e.repath()


func _simulate_props(wd: float) -> void:
	for i in range(props.size() - 1, -1, -1):
		var p: TerrainProp = props[i]
		p.time_left -= wd
		# La zone attachee suit la VIE de l accessoire, pas sa propre duree : on la
		# maintient en vie tant que l arbre tient, et `_destroy_prop` la coupe.
		# Sans cela une zone de 60 s survivrait a un arbre abattu en 3 s.
		if not p.zone.is_empty() and p.is_alive():
			p.zone["time"] = maxf(float(p.zone["time"]), wd * 2.0)
		if not p.is_alive():
			_destroy_prop(i, p.max_hp > 0.0 and p.hp <= 0.0)
			continue
		_props_take_hits(p, wd)


## Les monstres a portee frappent l accessoire. C est le pendant de
## `enemy_strikes_wall()`, mais sans condition d enfermement : un monstre provoque
## n a pas besoin d etre bloque pour taper, il a CHOISI cette cible.
func _props_take_hits(p: TerrainProp, wd: float) -> void:
	if not p.is_breakable():
		return
	for e in enemies:
		if not _targetable(e) or e.definition == null:
			continue
		if e.is_stunned():
			continue  # etourdi : il ne frappe pas plus qu il n avance
		if e.position.distance_to(p.position) > p.reach + e.radius():
			continue
		# Meme bareme que le mur : les degats de contact, appliques en continu.
		if p.take_damage(float(e.definition.contact_hit()) * 4.0 * wd):
			var idx: int = props.find(p)
			if idx >= 0:
				_destroy_prop(idx, true)
			return


## Retire l accessoire, sa zone et son visuel. `brise` distingue l abattage (un
## eclat, un son) de l expiration tranquille : le joueur doit voir la difference
## entre « mon arbre est tombe » et « mon arbre a fini son temps ».
func _destroy_prop(index: int, brise: bool) -> void:
	if index < 0 or index >= props.size():
		return
	var p: TerrainProp = props[index]
	# La zone attachee part avec lui : c est la regle qui empeche de garder le
	# poison apres avoir perdu l arbre qui le porte.
	if not p.zone.is_empty():
		var vn: Node = p.zone.get("node")
		if vn != null and is_instance_valid(vn):
			vn.queue_free()
		zones.erase(p.zone)
		p.zone = {}
	if p.node != null and is_instance_valid(p.node):
		p.node.queue_free()
	if brise:
		Fx.impact(self, p.position, Fx.COL_WALL, maxf(p.reach, 60.0))
		AudioBus.play_sfx(&"wall")
	props.remove_at(index)


## Etourdit les monstres d une zone. Renvoie le nombre de monstres figes.
##
## L immobilisation est la chose la plus forte qu on puisse faire dans un jeu en
## temps reel : elle passe donc par `Enemy.apply_stun()`, qui la refuse aux
## monstres resistants au ralentissement. Un stun qui ignorerait cette table la
## viderait de tout sens — le golem serait insensible au givre et fige par la
## foudre, ce que le joueur lirait comme une incoherence.
func stun_at(center: Vector2, radius: float, duration: float) -> int:
	var n: int = 0
	for e in enemies_in_radius(center, radius):
		if (e as Enemy).apply_stun(duration):
			n += 1
	return n
