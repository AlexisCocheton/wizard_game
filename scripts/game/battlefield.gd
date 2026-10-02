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
## ONDES DE CHOC en cours d expansion. Separees des tirs : un tir est un corps
## qui voyage vers un point et disparait a l impact, une onde est un CERCLE qui
## grandit depuis un centre fixe et frappe tout ce qu il traverse, une seule fois
## chacun. Les deux ne se rangent pas dans la meme liste sans mentir sur l un ou
## l autre.
var shockwaves: Array[Dictionary] = []
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
## Element de la carte qui a pose le ralentissement global / la volte-face en
## cours. Garde pour moduler l effet MONSTRE PAR MONSTRE (vague 5, voir
## Enemy.control_factor) : l effet est global, la resistance ne l est pas.
var _global_slow_tags: Array = []
var _reverse_tags: Array = []

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
	_simulate_shockwaves(wd)
	_simulate_support(wd)

	var buff: float = _buff_multiplier()
	# Copie : la liste est modifiee pendant l iteration (morts, arrivees).
	for e in enemies.duplicate():
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		e.speed_scale = _global_slow_for(e) * buff
		var obj_depart: Array = _obj_travel_begin(e)  # OBJECTIFS (enemy_travel)
		e.advance(wd)
		# COURANT : applique APRES le deplacement, et pas comme un facteur de
		# vitesse. Un facteur ne peut que freiner (il tend vers zero) ; le
		# courant, lui, doit pouvoir RENVERSER la descente, ce qui est toute la
		# difference entre la nappe d eau et le Champ de givre.
		_apply_current(e, wd)
		_obj_travel_end(e, obj_depart)  # OBJECTIFS (enemy_travel)

	# REGARD PETRIFIANT : releve APRES le tour des monstres, donc une gorgone
	# morte pendant cette image a deja relache la main quand le HUD se
	# rafraichit. Releve a chaque image plutot que sur les signaux de mort et
	# d apparition : une gorgone peut aussi disparaitre en etant gobee par le
	# Glouton, absorbee, ou emportee par la fin de vague, et chacun de ces
	# chemins aurait demande son propre branchement — donc chacun aurait pu etre
	# oublie, laissant une main petrifiee par un monstre qui n existe plus.
	_refresh_card_block()
	_v3_simulate(delta, wd)


## Total des regards des gorgones VIVANTES, pousse dans RunState. Zero gorgone
## vivante donne zero regard : la main se degele d elle-meme, il n existe aucun
## chemin ou un blocage survit a son monstre.
func _refresh_card_block() -> void:
	var regards: int = 0
	for e in enemies:
		if _alive(e) and e.definition != null and e.definition.blocks_cards > 0:
			# Un monstre qui APPARAIT encore ne petrifie pas : le joueur ne l a pas
			# vu arriver, et perdre une carte avant meme de voir la cause se lit
			# comme un bug. Un monstre CACHE (Ombre en phase) non plus.
			if e.is_spawning() or e.is_hidden():
				continue
			regards += e.definition.blocks_cards
	RunState.set_card_block_count(regards)


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
		if not glutton.can_devour(prey):
			continue
		# Ce que rapporte la proie (soin ou croissance) est decide par le devoreur.
		glutton.devour(prey)
		prey.absorb()
		enemies.erase(prey)
		prey.queue_free()


func _simulate_zones(wd: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z["time"] -= wd
		# OBJECTIFS : la zone frappe au nom du lancer qui l a posee.
		var obj_src_avant: Dictionary = RunState.swap_damage_source(z.get("src", {}))
		for e in enemies.duplicate():
			if not _targetable(e):
				continue
			if e.position.distance_to(z["pos"]) > z["radius"]:
				continue
			if z["dps"] > 0.0:
				_hit(e, z["dps"] * wd, z["tags"])
			if z["slow_pct"] > 0.0:
				e.apply_slow(1.0 - z["slow_pct"] * 0.01, 0.4, z["tags"])
		RunState.swap_damage_source(obj_src_avant)  # OBJECTIFS
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
				# OBJECTIFS : l allie frappe au nom du lancer qui l a invoque.
				var obj_src_avant: Dictionary = RunState.swap_damage_source(a.get("src", {}))
				# L allie frappe a l ELEMENT de la carte qui l a appele (vague 8) :
				# une invocation de nature bute sur ce qui resiste a la nature.
				_hit(target, a["damage"], a.get("tags", [GameEnums.DamageTag.SUMMON]) as Array)
				RunState.swap_damage_source(obj_src_avant)  # OBJECTIFS
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
			_free_anchor(w.get("anchor"))
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
			# Une fleche coute de la VITESSE, comme un contact : depuis le
			# 26 septembre c est la seule reserve du mage.
			SpeedGauge.take_hit(int(s["damage"]))
			mage_hit.emit(int(s["damage"]), s.get("shooter"))


# --- ONDE DE CHOC ----------------------------------------------------------
#
# Le boss qui « n avance pas et tape le sol », demande par le testeur. Une onde
# n est pas un tir : elle part d un centre FIXE et son cercle grandit, frappant
# chaque chose une seule fois au passage du front.
#
# POURQUOI UN FRONT QUI GRANDIT et non un cercle instantane. Un cercle
# instantane est un de : au moment ou le boss frappe, on est dedans ou dehors, et
# le joueur n a rien a decider. Un front qui s etend donne une DEMI-SECONDE pour
# reagir — sortir du cercle, ou accepter le coup pour finir son incantation. La
# vitesse du front est donc un reglage de jouabilite, pas de mise en scene.
const SHOCKWAVE_SPEED: float = 620.0


## Le boss frappe le sol : une onde part de sa position.
func enemy_shockwave(from: Enemy, radius: float, damage: int) -> void:
	if from == null or radius <= 0.0 or damage <= 0:
		return
	shockwaves.append({
		"center": from.position,
		"radius": 0.0,
		"max": radius,
		"damage": damage,
		"source": from.definition,
		# Le monstre lui-meme (vague 8) : ses coups sur un objet de terrain
		# suivent sa relation a l element de l objet (`object_hit`).
		"by": from,
		# Ce que le front a DEJA frappe. Sans cette memoire, un monstre lent reste
		# dans l epaisseur du front plusieurs images et encaisse dix fois la meme
		# onde : le boss deviendrait une tondeuse.
		"hit_mage": false,
		"hit": [],
	})
	shockwaves_fired += 1
	from.play_attack()
	AudioBus.play_sfx(&"wall")


func _simulate_shockwaves(wd: float) -> void:
	for i in range(shockwaves.size() - 1, -1, -1):
		var w: Dictionary = shockwaves[i]
		var avant: float = float(w["radius"])
		var apres: float = avant + SHOCKWAVE_SPEED * wd
		w["radius"] = apres
		var centre: Vector2 = w["center"]
		var degats: int = int(w["damage"])

		# LE MAGE. Sa ligne est horizontale : l onde l atteint quand son front
		# depasse la distance verticale au centre. On le frappe UNE fois.
		if not bool(w["hit_mage"]):
			var d_mage: float = absf(GameConfig.MAGE_LINE_Y - centre.y)
			if apres >= d_mage and avant < d_mage and d_mage <= float(w["max"]):
				w["hit_mage"] = true
				speed_before_hit = SpeedGauge.speed_percent
				# Une onde paie le meme peage que tout le reste : elle coute de
				# la vitesse, donc de la vie. La regle entiere vit dans
				# SpeedGauge.take_hit() et n a aucune raison d etre recopiee ici.
				SpeedGauge.take_hit(degats)
				mage_hit.emit(degats, w.get("source"))

		# LE DECOR DU JOUEUR. C est ce qui distingue l onde du tir : elle abat les
		# arbres et fend les murs poses dans son cercle. Un boss immobile qu on
		# enfermerait derriere un mur ne serait pas un combat.
		var deja: Array = w["hit"]
		for j in range(props.size() - 1, -1, -1):
			if j >= props.size():
				continue
			var pr: TerrainProp = props[j]
			if pr == null or deja.has(pr):
				continue
			var dp: float = centre.distance_to(pr.position)
			if apres >= dp and avant < dp and dp <= float(w["max"]):
				deja.append(pr)
				var auteur: Enemy = null
				if is_instance_valid(w.get("by")):
					auteur = w.get("by") as Enemy
				if pr.is_breakable() and pr.take_damage(object_hit(float(degats) * 6.0,
						auteur, _prop_tags(pr))):
					_destroy_prop(j, true)

		# Le visuel du front, pose aux paliers : une seule image d impact etiree a
		# la taille du front suffit a le lire, et on ne fabrique pas un noeud par
		# image. Les feuilles viennent du pack d effets — rien n est dessine.
		var palier: int = int(apres / 110.0)
		if palier > int(avant / 110.0) and Fx.enabled():
			Fx.impact(self, centre, Fx.COL_PHYSICAL, minf(apres, float(w["max"])))

		if apres >= float(w["max"]):
			shockwaves.remove_at(i)


## Nombre d ondes EN COURS d expansion (transitoire, une demi-seconde chacune).
func shockwave_count() -> int:
	return shockwaves.size()


## Nombre total de coups de sol depuis le debut de la partie. C est ce compteur
## que les tests interrogent : `shockwave_count()` est transitoire — une onde de
## 300 px vit un peu moins d une demi-seconde, donc une sonde qui tombe entre
## deux coups lirait zero et le test serait faux une fois sur deux.
var shockwaves_fired: int = 0


func shockwave_strike_count() -> int:
	return shockwaves_fired


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
	e.position = at if not spontane else Vector2(x, v3_spawn_y(def))
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
		# Un monstre RELEVE par un reanimateur a deja ete compte a sa premiere mort.
		if not def.projectile and not e.is_reanimated():
			RunState.gain_xp(def.base_xp)
			enemy_killed.emit(def)
			_obj_note_death(e, def)  # OBJECTIFS : lancer, carte, chemin
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
	_v3_on_death(e, def, where, diff)
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
	# OBJECTIFS : l explosion est celle du PASSIF, pas du sort qui a tue. Sans
	# source, ses victimes ne sont creditees a aucune carte ni aucun lancer.
	var obj_src_avant: Dictionary = RunState.swap_damage_source({})
	_chain_depth += 1
	# Copie : _hit() peut tuer, donc modifier `enemies` pendant l iteration.
	for voisin in enemies_in_radius(where, rayon):
		var cible: Enemy = voisin as Enemy
		if cible == null or not _alive(cible):
			continue
		# Tableau de tags NON TYPE : Godot 4.4 refuse de convertir Array vers
		# Array[T] au passage d argument (piege documente en memoire).
		# Vague 8 : Combustion est une carte de FEU, son explosion aussi — un
		# monstre qui resiste au feu l encaisse moins, comme le Brasier.
		var tags: Array = [GameEnums.DamageTag.FIRE]
		_hit(cible, degats, tags)
	_chain_depth -= 1
	RunState.swap_damage_source(obj_src_avant)  # OBJECTIFS


## RENVOI : conversion des degats de SORT en degats de MAGE, et plafond par coup.
##
## Les deux echelles n ont RIEN a voir : un sort fait des dizaines a des centaines
## de points sur un monstre de 200 PV, alors que le mage a 100 PV et qu un contact
## de boss lui en coute 50 POINTS DE VITESSE. Renvoyer les degats bruts tuerait
## le joueur d un seul Meteore, ce qui n est pas une punition mais une
## interdiction de jouer.
##
## On divise donc, puis on PLAFONNE a hauteur d un contact de mini-boss : le
## renvoi le plus cher du jeu coute autant que se faire toucher par un gros
## monstre. C est la seule echelle que le joueur connaisse deja, et elle garantit
## qu un renvoi ne peut jamais le tuer a lui seul depuis la pleine vitesse.
const REFLECT_TO_MAGE_SCALE: float = 0.10
const REFLECT_MAX_PER_HIT: int = 20


## Renvoie une part des degats sur le mage. Passe par SpeedGauge.take_hit() :
## un renvoi coute de la VITESSE, comme n importe quel coup. La mecanique
## signature n a pas d exception.
func _reflect_to_mage(source: Enemy, raw: float) -> void:
	# OBJECTIFS (never_hit_reflect) : un coup a mordu pendant la garde.
	RunState.note_reflect_hit()
	var degats: int = clampi(int(round(raw * REFLECT_TO_MAGE_SCALE)), 1, REFLECT_MAX_PER_HIT)
	speed_before_hit = SpeedGauge.speed_percent
	SpeedGauge.take_hit(degats)
	# L ecran de defaite doit pouvoir dire "tue par son propre sort renvoye par le
	# Miroir" : on nomme le boss, pas le sort, parce que c est lui la lecon.
	mage_hit.emit(degats, source.definition if source != null else null)
	# LE JOUEUR DOIT LE VOIR : un eclat part du boss, la ou son sort a rebondi.
	# Sans ce retour, perdre des PV en lancant une carte est incomprehensible.
	if Fx.enabled() and source != null and is_instance_valid(source):
		Fx.impact(self, source.position, Color(1.0, 0.78, 0.35), source.radius() * 1.6)
	AudioBus.play_sfx(&"hp_lost")


## Vitesse relevee juste avant le dernier coup encaisse (passif "Verrou temporel").
var speed_before_hit: int = 100


func _on_enemy_reached_mage(e: Enemy) -> void:
	var dmg: int = e.definition.contact_hit() if e.definition != null else 5
	enemies.erase(e)
	e.queue_free()
	# Photo de la vitesse AVANT l encaissement. Le passif legendaire "Verrou
	# temporel" en a besoin deux fois : pour savoir combien la jauge a perdu, ET
	# pour juger son propre seuil — apres le coup la vitesse est deja tombee,
	# souvent sous le seuil que le passif etait cense couvrir (voir
	# GameController::_passive_equipped_at).
	speed_before_hit = SpeedGauge.speed_percent
	# Toute la regle vit dans SpeedGauge.take_hit() : un coup coute de la
	# vitesse, et le plancher de 100 % est la mort.
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
		_free_anchor(w.get("anchor"))
	walls.clear()
	# Les accessoires plantes doivent partir avec la partie : un arbre oublie
	# resterait a l ecran d une vague a la suivante et continuerait a provoquer.
	# C est aussi la SEULE fin d un objet permanent intact : « jusqu a la fin du
	# combat » veut dire jusqu ici, pas jusqu a la fin de la vague.
	for p in props:
		if p.node != null and is_instance_valid(p.node):
			p.node.queue_free()
		_free_anchor(p.anchor)
		p.anchor = null
	props.clear()
	for s in shots:
		var node: Node = s.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	shots.clear()
	_v3_clear()
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


# --- Resistance aux EFFETS (vague 5) ---------------------------------------
# Les degats passaient par la table de resistances, les effets non : une Marque
# de faiblesse d arcane rendait le Chevalier du vide (dont l armure avale la
# magie) aussi vulnerable qu une gelee. Chaque effet lit maintenant
# `Enemy.control_factor` sur l element de la carte qui le porte.

## Vulnerabilite du terrain pour CE monstre. Le bonus (et non le multiplicateur
## entier) est attenue par sa resistance a l element de la zone : une Marque x2
## sur un monstre qui resiste a moitie a l arcane donne x1,5.
func _vuln_multiplier_for(e: Enemy) -> float:
	var m: float = 1.0
	for z in zones:
		var vm: float = float(z.get("vuln_mult", 1.0))
		if vm > 1.0 and e.position.distance_to(z["pos"]) <= z["radius"]:
			m = maxf(m, 1.0 + (vm - 1.0) * e.control_factor(z.get("tags", [])))
	return m


## Facteur de vitesse du ralentissement GLOBAL pour ce monstre. Seul un
## ralentissement est attenue : une acceleration des monstres (Pacte temeraire)
## est un prix que paie le joueur, pas un effet que le monstre subit.
func _global_slow_for(e: Enemy) -> float:
	if _global_slow_factor >= 1.0:
		return _global_slow_factor
	return 1.0 - (1.0 - _global_slow_factor) * e.control_factor(_global_slow_tags, true)


## Part de la volte-face que subit ce monstre (0 = il ne se retourne pas).
func reverse_factor_for(e: Enemy) -> float:
	if not is_reversed():
		return 0.0
	return e.control_factor(_reverse_tags) if e != null else 1.0


## Element de la carte qui a pose un objet de terrain.
func _prop_tags(p: TerrainProp) -> Array:
	return p.get_meta(&"card_tags", []) as Array


## Le premier ELEMENT d un tableau de tags, NONE s il n y en a pas.
static func element_of(tags: Array) -> int:
	for t in tags:
		if int(t) in GameEnums.ELEMENTS:
			return int(t)
	return GameEnums.DamageTag.NONE


## LES COUPS D UN MONSTRE SUR UN OBJET DE TERRAIN (vague 8) — le seul endroit
## ou la regle s applique, pour le mur, l accessoire et l onde de choc :
##   relation du monstre a l element de l objet (EnemyDef.object_hit_factor :
##   faible -> frappe moins, resistant -> frappe plus, borne x0,5..x2) ;
##   passif elementaire « objets plus solides » de cet element.
## Sans monstre (test, coup sans auteur), le coup passe tel quel.
func object_hit(amount: float, who: Enemy, tags: Array) -> float:
	var f: float = 1.0
	if who != null and is_instance_valid(who):
		f = who.object_hit_factor(tags)
	var el: int = element_of(tags)
	if el != GameEnums.DamageTag.NONE:
		f *= maxf(0.0, 1.0 - RunState.element_bonus(el, RunState.ELEM_STURDY) * 0.01)
	return amount * f


func _hit(e: Enemy, amount: float, tags: Array) -> bool:
	if not _targetable(e):
		return false
	if is_shielded_by_aura(e):
		return false
	# PASSIF "Apotheose" (legendaire) : la vitesse ne multiplie plus seulement
	# l XP, elle multiplie les DEGATS. Applique ici, au point de passage unique
	# des degats, pour qu aucune carte ni aucun autre passif n y echappe.
	var total: float = amount * _vuln_multiplier_for(e) \
		* RunState.passive_damage_multiplier()
	# PASSIFS ELEMENTAIRES (vague 8) : « +X % de degats aux sorts de feu ». Lus
	# ICI, au point de passage unique, avec l element des tags : la zone, l allie
	# et l objet d une carte de feu en profitent comme le sort lui-meme.
	var el: int = element_of(tags)
	if el != GameEnums.DamageTag.NONE:
		total *= 1.0 + RunState.element_bonus(el, RunState.ELEM_DAMAGE) * 0.01
	# RESISTANCE ELEMENTAIRE du monstre. Elle s applique ICI, au point de passage
	# unique des degats, et nulle part ailleurs : une source qui la contournerait
	# ignorerait tout le bestiaire.
	# Elle vient EN DERNIER, apres la vulnerabilite de terrain et les passifs :
	# une Marque de faiblesse (x2) sur un monstre qui resiste a 50 % redonne des
	# degats normaux, ce qui est la lecture attendue par le joueur — la zone
	# COMPENSE la resistance, elle ne l ecrase pas.
	if e.definition != null:
		# Un passif « perce-resistance » (vague 8) ramene une resistance vers le
		# neutre ; il ne touche ni a une immunite ni a une faiblesse.
		total *= RunState.pierce_resistance(e.definition.resistance_to_tags(tags), el)
	# BOUCLIER DE RENVOI. Releve AVANT d appliquer les degats, parce que le coup
	# peut tuer le boss et refermer sa garde : un renvoi resolu apres coup serait
	# annule par la mort de celui qui renvoie, et tuer le boss pendant sa garde
	# deviendrait gratuit — exactement le contraire de la mecanique, qui doit
	# faire PAYER le lancement mal choisi.
	var part_renvoyee: float = e.reflect_share()

	var applied: bool = e.take_damage(total, tags)
	if applied:
		# Le renvoi ne part que si le coup a reellement mordu : un sort esquive,
		# absorbe par un bouclier ou avale par le compteur de coups n a rien a
		# renvoyer. Sinon le joueur serait puni deux fois pour un sort qui n a
		# meme pas fonctionne.
		if part_renvoyee > 0.0:
			_reflect_to_mage(e, total * part_renvoyee)
		Fx.hit_flash(e)
		AudioBus.play_sfx(&"hit")
		# PASSIF "Morsure de givre" : TOUT degat ralentit, quel que soit l element
		# du sort. C est une regle, pas un bonus chiffre : les sorts de feu se
		# mettent a freiner les monstres.
		var chill: float = RunState.passive_magnitude(&"passive_chill_on_hit")
		if chill > 0.0:
			# Vague 8 : la Morsure est de GLACE, son ralentissement suit la
			# resistance a la glace (et la ligne SLOW, comme tout ralentissement).
			e.apply_slow(maxf(0.25, 1.0 - chill * 0.01), 1.5, [GameEnums.DamageTag.ICE])
		_v3_after_hit(e)
	return applied


# --- API appelee par les handlers d effet ---

func damage_enemy(target: Object, amount: float, card: SpellCard) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var tags: Array = card.combat_tags() if card != null else []
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
	var col: Color = Fx.color_for(card.combat_tags() if card != null else [])
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
		"tags": (card.combat_tags() if card != null else []) as Array,
		"node": vis,
		# OBJECTIFS : le lancer qui la pose, remis en place a chaque morsure.
		"src": RunState.damage_source,
	}
	zones.append(z)
	return z


## `tags` : element de la carte (vague 5). Un monstre qui y resiste, ou qui
## resiste au ralentissement, est moins ralenti — voir `_global_slow_for`.
func apply_global_enemy_slow(slow_pct: float, duration: float, tags: Array = []) -> void:
	_global_slow_factor = clampf(1.0 - slow_pct * 0.01, 0.1, 3.0)
	_global_slow_time = duration
	_global_slow_tags = tags.duplicate()


func apply_cast_haste(pct: float, duration: float) -> void:
	cast_haste = clampf(1.0 + pct * 0.01, 0.1, 5.0)
	_cast_haste_time = duration


## Volte-face : tous les monstres remontent pendant `duration` secondes.
func apply_reverse(duration: float, tags: Array = []) -> void:
	_reverse_time = maxf(_reverse_time, duration)
	_reverse_tags = tags.duplicate()


## Invoque un allie qui frappe le monstre le plus proche.
##
## Il a une POSITION et un sprite : le testeur signalait qu on ne voyait pas
## l invocation. Elle existait bien, mais seulement comme une entree de donnees —
## le joueur payait une carte pour un effet invisible.
##
## `at` : lieu d apparition. Par defaut devant le mage ; un AUTEL (generateur de
## terrain) fait naitre les siens a cote de lui, sinon le joueur ne relierait pas
## les allies a l objet qu il a pose.
## `tags` (vague 8) : element de la carte qui invoque, plus SUMMON. Vide ou sans
## element (passif Compagnon fidele) : l allie frappe sans element.
func spawn_ally(duration: float, damage: float, at: Vector2 = Vector2.INF,
		tags: Array = [GameEnums.DamageTag.SUMMON]) -> void:
	# Devant le mage, decale au hasard : deux allies ne se superposent pas.
	# Hasard du MONDE de la partie (fixe par la graine), pas le hasard global.
	var r: RandomNumberGenerator = RunState.world_rng
	var pos := Vector2(
		clampf(GameConfig.BATTLEFIELD_WIDTH * 0.5 + r.randf_range(-220.0, 220.0),
			120.0, GameConfig.BATTLEFIELD_WIDTH - 120.0),
		GameConfig.MAGE_LINE_Y - 190.0)
	if at != Vector2.INF:
		pos = Vector2(clampf(at.x + r.randf_range(-70.0, 70.0), 60.0,
			GameConfig.BATTLEFIELD_WIDTH - 60.0), at.y + r.randf_range(20.0, 70.0))
	var node: Node = Fx.sprite(self, "magicbubbles", pos, 130.0, true,
		Color(Fx.COL_SUMMON.r, Fx.COL_SUMMON.g, Fx.COL_SUMMON.b, 0.95))
	allies.append({"time": duration, "damage": damage, "cooldown": 0.5,
		"pos": pos, "node": node, "tags": tags.duplicate(),
		# OBJECTIFS : le lancer qui l invoque (vide pour un allie de passif).
		"src": RunState.damage_source})


## Pose un mur qui bloque le pathfinding pendant `duration` secondes.
## `tags` (vague 8) : element de la carte qui pose le mur. Les coups des
## monstres sur ce mur en dependent (`_object_hit`).
func spawn_wall(center: Vector2, half_width: float, duration: float,
		thickness: float = 60.0, tags: Array = []) -> void:
	if nav == null:
		nav = NavGrid.new()
	var cells: Array[Vector2i] = nav.block_rect(center, half_width, thickness)
	if cells.is_empty():
		return
	AudioBus.play_sfx(&"wall")
	var node: Node = Fx.spawn_wall_visual(self, center, half_width, thickness, duration,
		element_of(tags))
	var w: Dictionary = {"cells": cells, "time": maxf(duration, 0.1), "node": node,
		"center": center, "half_width": half_width, "thickness": thickness,
		"tags": tags.duplicate()}
	walls.append(w)
	# Un mur est un objet de terrain comme un autre pour le Briseur de terrain :
	# il recoit la meme ancre, et `destroy()` le fait tomber comme s il avait ete
	# casse. On retrouve le mur par identite du dictionnaire, pas par son index,
	# qui glisse des qu un autre mur expire.
	w["anchor"] = _new_anchor(center, -1, func() -> void:
		var i: int = _wall_index(w)
		if i >= 0:
			_break_wall(i))


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
##
## `tags` : element de la carte (vague 5). Un monstre qui y resiste recule
## d autant moins ; totalement resistant, il ne bouge pas et ne compte pas.
func knockback_from(center: Vector2, radius: float, push: float, tags: Array = []) -> int:
	var touches: int = 0
	for e in enemies_in_radius(center, radius):
		var enemy: Enemy = e as Enemy
		var tenue: float = enemy.control_factor(tags)
		if tenue <= 0.0:
			continue
		var away: Vector2 = enemy.position - center
		# Pile au centre : on choisit le haut, la direction qui aide le joueur.
		var dir: Vector2 = away.normalized() if away.length() > 1.0 else Vector2.UP
		# Degressif : au bord de la zone le souffle ne porte presque plus.
		var force: float = tenue * push \
			* (1.0 - clampf(away.length() / maxf(radius, 1.0), 0.0, 1.0) * 0.5)
		var cible: Vector2 = enemy.position + dir * force
		enemy.position = Vector2(
			clampf(cible.x, 40.0, GameConfig.BATTLEFIELD_WIDTH - 40.0),
			clampf(cible.y, GameConfig.SPAWN_LINE_Y, GameConfig.MAGE_LINE_Y - 20.0))
		enemy.repath()
		touches += 1
	return touches


## Pose une spirale qui aspire. `pull` est une vitesse d aspiration en px/s a x1.
##
## `tags` : element de la carte. Il n existe pas d element « vent » : la spirale
## prend celui de la carte qui la pose (voir EnemyDef.control_factor), et un
## monstre qui y resiste est aspire d autant moins vite.
func spawn_vortex(center: Vector2, radius: float, duration: float, pull: float,
		tags: Array = []) -> void:
	var vis: Node = Fx.zone_visual(self, center, maxf(radius, 10.0), duration, Fx.COL_ARCANE)
	vortices.append({
		"pos": center,
		"radius": maxf(radius, 10.0),
		"time": maxf(duration, 0.1),
		"pull": pull,
		"tags": tags.duplicate(),
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
			var pas: float = minf(float(v["pull"]) * wd
				* (e as Enemy).control_factor(v.get("tags", [])), d)
			if pas <= 0.0:
				continue
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
##
## `tags` : element de la carte (vague 5). Dissiper est un effet TOUT OU RIEN,
## comme l etourdissement : il passe sous le meme seuil
## (`Enemy.STUN_RESIST_THRESHOLD`). Un Chevalier du vide, dont l armure avale la
## magie, garde donc son bouclier face a une Lumiere purifiante d arcane.
func dispel_at(center: Vector2, radius: float, tags: Array = []) -> int:
	var n: int = 0
	for e in enemies_in_radius(center, radius):
		if (e as Enemy).control_factor(tags) <= Enemy.STUN_RESIST_THRESHOLD:
			continue
		(e as Enemy).dispel()
		n += 1
	if n > 0:
		Fx.impact(self, center, Fx.COL_ARCANE, radius)
	return n


## Frappe le mur qui recouvre `point`. Renvoie true si un mur a bien encaisse.
## Un mur sans PV (les murs temporaires) ignore les coups : seule la duree le tue.
## `who` (vague 8) : le monstre qui frappe ; ses coups suivent sa relation a
## l element du mur (`object_hit`).
func damage_wall_at(point: Vector2, amount: float, who: Enemy = null) -> bool:
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
		w["hp"] = float(w["hp"]) - object_hit(amount, who, w.get("tags", []) as Array)
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
	_free_anchor(w.get("anchor"))
	walls.remove_at(index)


## Mur PERMANENT : il ne compte pas le temps, il compte les PV. Le seul moyen de
## le faire tomber est de le casser, ce qui donne enfin une raison aux monstres
## d attaquer le decor au lieu de l attendre.
##
## `duration = INF` traverse `_simulate_walls` sans jamais atteindre zero : aucune
## branche d expiration a ajouter, le meme code gere les deux sortes de murs.
func spawn_breakable_wall(center: Vector2, half_width: float, thickness: float,
		hp: float, tags: Array = []) -> void:
	spawn_wall(center, half_width, INF, thickness, tags)
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
	damage_wall_at(devant, float(e.definition.contact_hit()) * 4.0 * world_delta, e)


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
		sheet: String = "", tint: Color = Color.WHITE, tags: Array = []) -> TerrainProp:
	var p := TerrainProp.new()
	p.kind = kind
	# Element de la carte qui a pose l objet (vague 5) : la provocation et le
	# courant sont des effets, un monstre qui resiste a cet element y cede moins.
	# En meta plutot qu en champ : TerrainProp n a pas a connaitre les sorts.
	p.set_meta(&"card_tags", tags.duplicate())
	# Jamais sur la ligne du mage ni hors terrain : un arbre plante sous le mage
	# attirerait les monstres exactement la ou on veut qu ils n aillent pas, et un
	# arbre hors cadre serait invisible et increvable.
	p.position = Vector2(
		clampf(center.x, 60.0, GameConfig.BATTLEFIELD_WIDTH - 60.0),
		clampf(center.y, GameConfig.SPAWN_LINE_Y + 60.0, GameConfig.MAGE_LINE_Y - 80.0))
	# duration <= 0 = PERMANENT (voir TerrainProp.time_left). Le plafond est tenu
	# AVANT l ajout : le nouveau n est jamais celui qu on retire.
	p.time_left = TerrainProp.lifetime_for(duration)
	if p.is_permanent():
		_make_room_for_permanent()
	_prop_serial += 1
	p.serial = _prop_serial
	p.hp = maxf(hp, 0.0)
	p.max_hp = p.hp
	p.taunt_radius = maxf(taunt_radius, 0.0)
	p.current = current
	p.area = maxf(area, 0.0)
	# L autel se frappe comme un arbre : c est un objet de la meme taille a l ecran.
	p.reach = 40.0 if kind == TerrainProp.Kind.WATER else 70.0
	# L aire est transmise au visuel : c est elle que l anneau de la nappe trace,
	# et un anneau qui mentirait sur la portee serait pire que pas d anneau du tout
	# — le joueur s en sert pour decider ou poser le sort suivant.
	p.node = Fx.prop_visual(self, p.position, kind, p.time_left, sheet, tint, p.area)
	AudioBus.play_sfx(&"drip_frost" if kind == TerrainProp.Kind.WATER else &"wall")
	props.append(p)
	_anchor_prop(p)
	p.set_meta(&"obj_src", RunState.damage_source)  # OBJECTIFS : allies d autel
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
func damage_prop_at(point: Vector2, amount: float, who: Enemy = null) -> bool:
	for i in range(props.size() - 1, -1, -1):
		var p: TerrainProp = props[i]
		if not p.is_breakable() or not p.covers(point):
			continue
		if p.take_damage(object_hit(amount, who, _prop_tags(p))):
			_destroy_prop(i, true)
		return true
	return false


## L accessoire que ce monstre doit viser, ou null s il continue vers le mage.
##
## Le PLUS PROCHE gagne : deux arbres plantes cote a cote ne doivent pas se
## disputer un monstre a chaque frame, ce qui le ferait osciller entre les deux
## sans jamais frapper ni l un ni l autre.
##
## `who` (vague 5) : le monstre attire. Sa resistance a l element de la carte
## raccourcit la portee de provocation — un golem qui encaisse le physique ne
## sent l appel du Totem de coeur-de-bois que de pres. Sans `who`, portee pleine.
func taunt_target_for(point: Vector2, who: Enemy = null) -> TerrainProp:
	var best: TerrainProp = null
	var best_d: float = INF
	for p in props:
		if not p.attracts(point) or not p.is_alive():
			continue
		if who != null:
			var portee: float = p.taunt_radius * who.control_factor(_prop_tags(p))
			if p.position.distance_to(point) > portee:
				continue
		# Pas de provocation A TRAVERS un obstacle : le monstre marche droit sur
		# l arbre, sans A*, donc il traverserait la riviere ou le mur pour
		# l atteindre. Il suit son chemin normal jusqu a ce que la voie soit libre
		# (le pont franchi), et l arbre le reprend alors.
		if nav != null and not nav.segment_clear(point, p.position):
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
			# Ralentissement ET element de la carte (vague 5) : la Nappe montante
			# est de givre, un monstre de glace y patauge sans reculer.
			poussee += p.current * e.control_factor(_prop_tags(p), true)
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
		_tick_generator(p, wd)
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
		if p.take_damage(object_hit(float(e.definition.contact_hit()) * 4.0 * wd, e,
				_prop_tags(p))):
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
	# Un objet qui bloquait (la riviere) rend EXACTEMENT ses cellules : la grille
	# compte les blocages, un mur pose sur la meme rangee reste debout.
	if not p.cells.is_empty() and nav != null:
		nav.unblock_cells(p.cells)
		p.cells = []
	_free_anchor(p.anchor)
	p.anchor = null
	if brise:
		Fx.impact(self, p.position, Fx.COL_WALL, maxf(p.reach, 60.0))
		AudioBus.play_sfx(&"wall")
	props.remove_at(index)


# =====================================================================
# SORTS DE TERRAIN PERMANENTS — riviere, ronces, fosse, autel, arbres qui restent
#
# Trois regles tiennent toute la famille, et elles vivent ICI plutot que dans les
# handlers parce qu elles portent sur l ETAT du terrain, que seul Battlefield voit :
#   1. un objet permanent reste jusqu a `clear_all()` (fin du combat) ;
#   2. au-dela de GameConfig.TERRAIN_PERMANENT_MAX, le plus ancien est remplace ;
#   3. rien de ce qui bloque ne coupe tout chemin des monstres au sol vers le mage.

## Compteur de poses, pour retrouver le plus ancien objet permanent.
var _prop_serial: int = 0


## Objets permanents actifs, riviere NON comprise (elle a sa propre regle : une
## seule a la fois).
func permanent_prop_count() -> int:
	var n: int = 0
	for p in props:
		if p.is_permanent() and p.kind != TerrainProp.Kind.RIVER and p.is_alive():
			n += 1
	return n


## Retire le plus ancien objet permanent tant que le plafond est atteint. Appele
## AVANT d ajouter le nouveau, qui n est donc jamais celui qu on retire.
##
## Retire sans eclat de destruction (`brise = false`) : il n a pas ete abattu, il
## a ete remplace, et le joueur doit pouvoir faire la difference.
func _make_room_for_permanent() -> void:
	while permanent_prop_count() >= GameConfig.TERRAIN_PERMANENT_MAX:
		var plus_vieux: int = -1
		var serie: int = 0
		for i in props.size():
			var p: TerrainProp = props[i]
			if not p.is_permanent() or p.kind == TerrainProp.Kind.RIVER:
				continue
			if plus_vieux < 0 or p.serial < serie:
				plus_vieux = i
				serie = p.serial
		if plus_vieux < 0:
			return
		_destroy_prop(plus_vieux, false)


## Ancre du groupe `terrain_props` : voir TerrainProp.Anchor.
func _new_anchor(at: Vector2, kind: int, on_destroy: Callable) -> Node:
	var a := TerrainProp.Anchor.new()
	a.kind = kind
	a.on_destroy = on_destroy
	# Position AVANT add_child, comme pour tout noeud du jeu.
	a.position = at
	add_child(a)
	return a


func _anchor_prop(p: TerrainProp) -> void:
	p.anchor = _new_anchor(p.position, p.kind, func() -> void: destroy_terrain(p))


## Libere une ancre. Retiree du groupe TOUT DE SUITE : `queue_free` ne la libere
## qu en fin d image, et un boss qui parcourrait le groupe dans l intervalle
## frapperait un objet deja parti.
func _free_anchor(a: Variant) -> void:
	if a == null or not (a is Node) or not is_instance_valid(a):
		return
	var n: Node = a
	if n.is_in_group(TerrainProp.GROUP):
		n.remove_from_group(TerrainProp.GROUP)
	n.queue_free()


func _wall_index(w: Dictionary) -> int:
	for i in walls.size():
		if is_same(walls[i], w):
			return i
	return -1


## Retire un objet de terrain comme s il avait ete abattu. C est ce que
## `Anchor.destroy()` appelle : le futur Briseur de terrain, et tout ce qui voudra
## un jour nettoyer le terrain, passent par la.
func destroy_terrain(p: TerrainProp) -> void:
	var i: int = props.find(p)
	if i >= 0:
		_destroy_prop(i, true)


## Les ancres vivantes (accessoires ET murs). Lecture pour les tests et pour le
## futur boss ; l ordre n a aucun sens.
func terrain_anchors() -> Array[Node]:
	var out: Array[Node] = []
	for c in get_children():
		if c.is_in_group(TerrainProp.GROUP):
			out.append(c)
	return out


## GENERATEUR : un autel invoque un allie a intervalle, a cote de lui. Le compte
## a rebours suit le temps du MONDE, comme les allies eux-memes : a x4 l autel
## invoque quatre fois plus vite, et ses allies vivent quatre fois moins
## longtemps — le rapport reste celui de la carte a toutes les vitesses.
func _tick_generator(p: TerrainProp, wd: float) -> void:
	if p.summon_every <= 0.0:
		return
	p.summon_timer -= wd
	if p.summon_timer > 0.0:
		return
	p.summon_timer += p.summon_every
	# OBJECTIFS : l allie d un autel appartient au lancer qui a pose l autel.
	var obj_src_avant: Dictionary = RunState.swap_damage_source(p.get_meta(&"obj_src", {}))
	var tags_allie: Array = _prop_tags(p).duplicate()
	if not tags_allie.has(GameEnums.DamageTag.SUMMON):
		tags_allie.append(GameEnums.DamageTag.SUMMON)
	spawn_ally(p.summon_duration, p.summon_damage, p.position, tags_allie)
	RunState.swap_damage_source(obj_src_avant)  # OBJECTIFS
	Fx.impact(self, p.position, Fx.COL_SUMMON, 60.0)


## Positions des monstres AU SOL encore en jeu : ceux que la garantie de chemin
## protege. Les volants et les projectiles passent au-dessus de tout, ils n en
## ont pas besoin.
func ground_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e in enemies:
		if not _alive(e) or e.definition == null or e.definition.flying:
			continue
		out.append(e.position)
	return out


## Bloquer ces cellules laisserait-il un chemin a chaque monstre au sol, present
## ou a venir ? C est la question posee avant TOUTE pose d un objet qui bloque.
func can_block(cells: Array[Vector2i]) -> bool:
	if nav == null:
		return true
	return nav.keeps_path(cells, ground_positions())


## La riviere active, ou null.
func river() -> TerrainProp:
	for p in props:
		if p.kind == TerrainProp.Kind.RIVER:
			return p
	return null


## Colonnes ou le pont d une riviere a cette rangee garderait un chemin.
##
## Le pont ne tombe JAMAIS sur une cellule deja bloquee (un mur pose sur la meme
## rangee) : le pont serait alors un morceau de mur et il n y aurait plus aucun
## passage. Au-dela de cette regle, chaque candidat est juge par la garantie
## complete : un pont libre qui debouche dans une poche fermee par un mur ne vaut
## pas mieux qu un pont bouche.
##
## L ancienne riviere est jugee comme deja partie : la nouvelle la remplace.
## `premier_suffit` coupe au premier candidat valable (l apercu de visee n a
## besoin que de savoir s il en existe un).
func river_bridge_columns(row: int, premier_suffit: bool = false,
		ordre: Array[int] = []) -> Array[int]:
	var out: Array[int] = []
	if nav == null:
		return out
	var liberees: Array[Vector2i] = []
	var ancienne: TerrainProp = river()
	if ancienne != null:
		liberees = ancienne.cells
	var positions: Array[Vector2] = _positions_after_river(row)
	var colonnes: Array[int] = ordre.duplicate()
	if colonnes.is_empty():
		for cx in nav.cols:
			colonnes.append(cx)
	var rangee: Array[Vector2i] = nav.row_cells(row)
	for cx in colonnes:
		var pont := Vector2i(cx, row)
		# Blocages COMPTES : une cellule tenue a la fois par l ancienne riviere et
		# par un mur reste bloquee quand l ancienne riviere part.
		var restants: int = nav.block_count(pont) - (1 if liberees.has(pont) else 0)
		if restants > 0:
			continue
		var eau: Array[Vector2i] = []
		for c in rangee:
			if c != pont:
				eau.append(c)
		if nav.keeps_path(eau, positions, liberees):
			out.append(cx)
			if premier_suffit:
				break
	return out


## Une riviere visee a ce point peut-elle etre posee ? Sert a l apercu de visee :
## une ligne ROUGE avant de lacher la carte plutot qu une carte depensee pour rien.
func river_possible(y: float) -> bool:
	return not river_bridge_columns(NavGrid.river_row(y), true).is_empty()


## Les monstres deja sur la ligne d eau sont REPOUSSES en amont (voir
## `spawn_river`). La garantie doit donc juger leur position d arrivee, pas celle
## qu ils occupent encore.
func _positions_after_river(row: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var amont: float = NavGrid.row_center_y(row - 1)
	for pos in ground_positions():
		if nav != null and nav.to_cell(pos).y == row:
			out.append(Vector2(pos.x, amont))
		else:
			out.append(pos)
	return out


## Pose la RIVIERE : une ligne d eau sur toute la largeur, a la rangee visee
## (ramenee dans les bornes de GameConfig), franchie par un seul pont.
##
## DECISIONS, et pourquoi :
##   - Le joueur choisit la HAUTEUR, pas le pont. Le pont est tire au hasard parmi
##     les colonnes qui gardent un chemin : si le joueur le placait, il le mettrait
##     toujours au bord le plus eloigne de son mage et la carte deviendrait un
##     detour garanti, pas un pari.
##   - UNE seule riviere a la fois ; la nouvelle remplace l ancienne. Deux
##     rivieres paralleles avec deux ponts opposes feraient serpenter la vague sur
##     toute la largeur a chaque traversee : un labyrinthe, plus un sort.
##   - Les monstres AU SOL deja sur la ligne sont repousses en amont : une riviere
##     qu on traverse parce qu on s y trouvait au moment ou elle est apparue ne
##     serait qu une riviere a moitie. Les volants et projectiles restent ou ils
##     sont, ils passent au-dessus.
##   - Elle n a pas de PV : on ne casse pas de l eau. Elle reste jusqu a la fin du
##     combat (duree <= 0) ou jusqu a une riviere suivante.
##
## Renvoie null si aucun pont ne peut garder un chemin (terrain deja trop bouche) :
## rien n est pose, et l ancienne riviere reste en place.
func spawn_river(y: float, duration: float = 0.0, sheet: String = "",
		rng: RandomNumberGenerator = null) -> TerrainProp:
	if nav == null:
		nav = NavGrid.new()
	var row: int = NavGrid.river_row(y)
	var ordre: Array[int] = []
	for cx in nav.cols:
		ordre.append(cx)
	# Melange de Fisher-Yates avec le generateur fourni : un test peut ainsi
	# rejouer des centaines de tirages sans dependre du hasard global. Sans
	# generateur (le sort en jeu), le hasard du MONDE de la partie : la graine
	# fixe aussi le pont.
	var r: RandomNumberGenerator = rng if rng != null else RunState.world_rng
	for i in range(ordre.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var t: int = ordre[i]
		ordre[i] = ordre[j]
		ordre[j] = t
	var ponts: Array[int] = river_bridge_columns(row, true, ordre)
	if ponts.is_empty():
		return null
	var pont: int = ponts[0]

	# L ancienne part SANS eclat : elle n a pas ete detruite, elle a ete remplacee.
	var ancienne: TerrainProp = river()
	if ancienne != null:
		_destroy_prop(props.find(ancienne), false)

	var p := TerrainProp.new()
	p.kind = TerrainProp.Kind.RIVER
	p.position = Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, NavGrid.row_center_y(row))
	p.time_left = TerrainProp.lifetime_for(duration)
	_prop_serial += 1
	p.serial = _prop_serial
	p.bridge_col = pont
	for c in nav.row_cells(row):
		if c.x != pont:
			p.cells.append(c)
	nav.block_cells(p.cells)
	_wash_upstream(row, pont)
	p.node = Fx.river_visual(self, p.position.y, NavGrid.CELL_SIZE,
		nav.to_world(Vector2i(pont, row)).x, sheet)
	AudioBus.play_sfx(&"drip_frost")
	props.append(p)
	_anchor_prop(p)
	return p


## Repousse en amont les monstres au sol debout sur la ligne d eau (hors pont).
func _wash_upstream(row: int, pont: int) -> void:
	var amont: float = NavGrid.row_center_y(row - 1)
	for e in enemies:
		if not _alive(e) or e.definition == null or e.definition.flying:
			continue
		var c: Vector2i = nav.to_cell(e.position)
		if c.y == row and c.x != pont:
			e.position.y = amont
			e.repath()


## Etourdit les monstres d une zone. Renvoie le nombre de monstres figes.
##
## L immobilisation est la chose la plus forte qu on puisse faire dans un jeu en
## temps reel : elle passe donc par `Enemy.apply_stun()`, qui la refuse aux
## monstres resistants au ralentissement. Un stun qui ignorerait cette table la
## viderait de tout sens — le golem serait insensible au givre et fige par la
## foudre, ce que le joueur lirait comme une incoherence.
##
## `tags` : element de la carte (vague 5) — la Racine de tonnerre est de foudre.
func stun_at(center: Vector2, radius: float, duration: float, tags: Array = []) -> int:
	var n: int = 0
	for e in enemies_in_radius(center, radius):
		if (e as Enemy).apply_stun(duration, tags):
			n += 1
	return n


# =====================================================================
# COMPORTEMENTS v3 — ce qui, dans les mecaniques v3, implique le terrain entier :
# la renaissance differee (une marque qui survit au monstre), la memoire des
# morts du reanimateur, le verrou de magie des dormeurs (qui porte sur TOUS les
# monstres a la fois) et le laser de riposte (qui vise le mage).

## Fenetre de magie GARANTIE entre deux sommeils, tous dormeurs confondus, en
## secondes REELLES. Reelles et non de monde : a 400 % de vitesse le monde va
## quatre fois plus vite, mais le doigt du joueur non. Trois renards regles sur
## le meme intervalle ne doivent pas pouvoir enchainer leurs siestes et
## verrouiller la main : le suivant attend que cette fenetre soit passee.
const SLEEP_MIN_MAGIC_WINDOW: float = 3.0
## Generations de renaissance au plus. Un slime fantome dont la marque ferait
## renaitre un slime fantome serait une vague sans fin ; le plafond garantit
## que la chaine s arrete meme si le contenu se trompe.
const REBIRTH_MAX_DEPTH: int = 2
## Duree pendant laquelle un reanimateur se souvient d une mort, en secondes de
## monde. Au-dela, le corps est « froid » : sans oubli, un reanimateur arrive en
## fin de vague releverait tout le debut du combat.
const REANIMATE_MEMORY: float = 8.0
## Teinte du laser : rouge vif, distinct des fleches (couleur du tireur) et de
## la garde de renvoi (ambre). Le joueur doit savoir QUI l a frappe.
const LASER_COLOR := Color(1.0, 0.22, 0.18)

## Marques de renaissance au sol : {def, count, pos, time, diff, depth, node}.
var _v3_rebirths: Array[Dictionary] = []
## Morts recentes que les reanimateurs peuvent relever : {def, pos, diff, t}.
var _v3_deaths: Array[Dictionary] = []
## Horloge du MONDE, pour dater les morts.
var _v3_clock: float = 0.0
var _v3_silenced: bool = false
## Secondes REELLES ecoulees depuis la fin du dernier sommeil. Demarre pleine :
## le premier dormeur de la partie n a pas a attendre une fenetre fictive.
var _v3_since_silence: float = SLEEP_MIN_MAGIC_WINDOW
## Compteurs cumules pour les tests et le debogage : un laser dure une fraction
## de seconde, une sonde qui tomberait entre deux lirait zero.
var lasers_fired: int = 0
var reanimations: int = 0


## Vrai quand plus rien ne reste a combattre, y compris ce qui va NAITRE. C est
## la question que pose le deroule des vagues : une marque de renaissance au sol
## est un monstre a venir, et la vague ne doit pas se terminer sans lui — sinon
## le slime naitrait par-dessus l ecran de victoire.
func is_clear() -> bool:
	return alive_count() == 0 and _v3_rebirths.is_empty()


func pending_rebirth_count() -> int:
	return _v3_rebirths.size()


func is_magic_silenced() -> bool:
	return _v3_silenced


## Hauteur de naissance d un monstre de vague. La ligne d apparition pour tous,
## SAUF un monstre qui entre par le cote : il nait assez bas pour que toute sa
## silhouette affichee soit dans le cadre. Un gros monstre pose a la ligne
## d apparition dans un coin avait la moitie du corps hors de l ecran — ni
## visible, ni visable au doigt. Meme marge que WaveSpawner.spawn_margin().
func v3_spawn_y(def: EnemyDef) -> float:
	if def == null or not def.entry_side:
		return GameConfig.SPAWN_LINE_Y
	return maxf(GameConfig.SPAWN_LINE_Y, WaveSpawner.spawn_margin(def))


func _v3_simulate(delta: float, wd: float) -> void:
	_v3_clock += wd
	_v3_tick_rebirths(wd)
	# Les morts trop anciennes sont oubliees : un reanimateur releve la bataille
	# en cours, pas celle d il y a une minute.
	for i in range(_v3_deaths.size() - 1, -1, -1):
		if _v3_clock - float(_v3_deaths[i]["t"]) > REANIMATE_MEMORY:
			_v3_deaths.remove_at(i)
	_v3_refresh_silence(delta)


func _v3_clear() -> void:
	for r in _v3_rebirths:
		var n: Node = r.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_v3_rebirths.clear()
	_v3_deaths.clear()
	_v3_clock = 0.0
	_v3_silenced = false
	_v3_since_silence = SLEEP_MIN_MAGIC_WINDOW
	RunState.set_silenced(false)


func _v3_on_death(e: Enemy, def: EnemyDef, where: Vector2, diff: float) -> void:
	if def == null:
		return
	# MEMOIRE DES MORTS pour les reanimateurs. Ni boss (en relever un serait un
	# second combat de boss gratuit), ni projectile, ni reanimateur (deux
	# reanimateurs qui se relevent l un l autre ne finiraient qu a leurs plafonds,
	# ce qui est long et illisible).
	if not def.projectile and not def.is_boss() and def.reanimate_max <= 0:
		_v3_deaths.append({"def": def, "pos": where, "diff": diff, "t": _v3_clock})
	# RENAISSANCE DIFFEREE : une marque au sol, puis la naissance.
	if def.rebirth_def != null and def.rebirth_count > 0:
		var generation: int = e.v3_rebirth_depth() if e != null else 0
		if generation < REBIRTH_MAX_DEPTH:
			var delai: float = maxf(def.rebirth_delay, 0.1)
			# LE JOUEUR DOIT LE VOIR : sans marque, un monstre qui surgit trois
			# secondes apres une mort se lit comme un bug d apparition. La marque
			# dit « quelque chose va sortir d ICI », et laisse le temps d y poser
			# une zone.
			var marque: Node = Fx.rebirth_marker(self, where,
				maxf(e.radius() if e != null else 40.0, 40.0), delai)
			_v3_rebirths.append({
				"def": def.rebirth_def,
				"count": def.rebirth_count,
				"pos": where,
				"time": delai,
				"diff": diff,
				"depth": generation + 1,
				"node": marque,
			})
	# Le dormeur qui vient de mourir rend la magie TOUT DE SUITE, pas a la fin de
	# l image : le sort que le joueur lance dans la foulee doit partir.
	_v3_refresh_silence(0.0)


func _v3_tick_rebirths(wd: float) -> void:
	for i in range(_v3_rebirths.size() - 1, -1, -1):
		var r: Dictionary = _v3_rebirths[i]
		r["time"] = float(r["time"]) - wd
		if float(r["time"]) > 0.0:
			Fx.rebirth_marker_set(r.get("node"), float(r["time"]))
			continue
		var n: Node = r.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
		_v3_rebirths.remove_at(i)
		var def: EnemyDef = r["def"]
		var ou: Vector2 = r["pos"]
		var combien: int = int(r["count"])
		for k in combien:
			# Meme eventail que la division : cote a cote, pas empiles, pour que le
			# joueur compte ce qui vient de naitre.
			var ecart := Vector2((k - (combien - 1) * 0.5) * 44.0, 0.0)
			var enfant: Enemy = spawn_enemy(def, ou.x, float(r["diff"]), ou + ecart)
			if enfant != null:
				enfant.position.x = clampf(enfant.position.x, 40.0,
					GameConfig.BATTLEFIELD_WIDTH - 40.0)
				enfant.v3_set_rebirth_depth(int(r["depth"]))
		if Fx.enabled():
			Fx.impact(self, ou, Color(0.75, 0.95, 1.0), 90.0)
		AudioBus.play_sfx(&"spell_rise")


## Le verrou de magie : un dormeur vivant coupe la magie, aucun dormeur la rend.
## Recalcule a chaque image (et a chaque mort) plutot que tenu par des signaux,
## pour la meme raison que la petrification : un dormeur peut quitter le terrain
## par mille chemins (gobe, tue, fin de vague), et chacun aurait pu oublier de
## rendre la magie.
func _v3_refresh_silence(real_delta: float) -> void:
	var dort: bool = false
	for e in enemies:
		if _alive(e) and e.is_sleeping():
			dort = true
			break
	if dort:
		_v3_silenced = true
	else:
		if _v3_silenced:
			# Fin de sommeil : la fenetre garantie commence maintenant.
			_v3_since_silence = 0.0
		else:
			_v3_since_silence += real_delta
		_v3_silenced = false
	RunState.set_silenced(_v3_silenced)


## Un dormeur demande a s endormir. Refuse si la magie est deja coupee (un seul
## sommeil a la fois, les siestes ne s additionnent pas) ou si la fenetre
## garantie depuis le dernier n est pas ecoulee. Accorde, le verrou tombe TOUT DE
## SUITE : un second renard qui demande dans la meme image doit etre refuse.
func v3_grant_sleep(_sleeper: Enemy) -> bool:
	if _v3_silenced or _v3_since_silence < SLEEP_MIN_MAGIC_WINDOW:
		return false
	_v3_silenced = true
	RunState.set_silenced(true)
	AudioBus.play_sfx(&"drip_frost")
	return true


## Releve la mort la plus RECENTE dans le rayon. Renvoie true si quelqu un s est
## releve. Le plus recent d abord : c est celui que le joueur vient de voir
## tomber, donc celui dont il comprend qu il revient.
func v3_reanimate_near(source: Enemy, radius: float) -> bool:
	if source == null:
		return false
	var best: int = -1
	for i in range(_v3_deaths.size() - 1, -1, -1):
		if source.position.distance_to(_v3_deaths[i]["pos"]) <= radius:
			best = i
			break
	if best < 0:
		return false
	var m: Dictionary = _v3_deaths[best]
	_v3_deaths.remove_at(best)
	var def: EnemyDef = m["def"]
	var ou: Vector2 = m["pos"]
	var revenant: Enemy = spawn_enemy(def, ou.x, float(m["diff"]), ou)
	if revenant == null:
		return false
	revenant.mark_reanimated()
	# Il SE RELEVE : le fondu d apparition le rend visible avant de le rendre
	# dangereux, et intouchable le temps que le joueur comprenne ce qui se passe.
	revenant.begin_spawn_fade()
	reanimations += 1
	if Fx.enabled():
		Fx.reanimate_link(self, source.position, ou)
	AudioBus.play_sfx(&"heal")
	return true


## Riposte au coup : appele par _hit() apres un coup qui a mordu.
func _v3_after_hit(e: Enemy) -> void:
	if not _alive(e) or e.definition == null or e.definition.laser_damage <= 0:
		return
	if not e.v3_try_laser():
		return
	_v3_fire_laser(e)


func _v3_fire_laser(e: Enemy) -> void:
	var depart: Vector2 = e.position
	var mage := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
	lasers_fired += 1
	# La pose de TIR de la feuille (le noyau du golem qui se charge), l attaque
	# generique a defaut : voir Enemy.shot_anim().
	e.play_shot_pose(true)
	AudioBus.play_sfx(&"arrow")
	# Un mur de pierre arrete le rayon comme il arrete les fleches : le joueur
	# qui s abrite doit etre recompense, sinon le mur mentirait sur ce qu il protege.
	var arret: Vector2 = _v3_first_wall_on(depart, mage)
	if arret != Vector2.INF:
		Fx.laser(self, depart, arret, LASER_COLOR)
		Fx.impact(self, arret, Fx.COL_PHYSICAL, 50.0)
		return
	Fx.laser(self, depart, mage, LASER_COLOR)
	speed_before_hit = SpeedGauge.speed_percent
	# Un laser coute de la VITESSE comme tout le reste : la regle entiere vit dans
	# SpeedGauge.take_hit().
	SpeedGauge.take_hit(e.definition.laser_damage)
	mage_hit.emit(e.definition.laser_damage, e.definition)


## Premier point du segment qui tombe dans un mur, Vector2.INF sinon. Echantillonne
## tous les 20 px : les murs font 60 px d epaisseur, aucun ne passe entre deux
## echantillons.
func _v3_first_wall_on(from: Vector2, to: Vector2) -> Vector2:
	if walls.is_empty():
		return Vector2.INF
	var longueur: float = from.distance_to(to)
	var pas: int = maxi(1, int(longueur / 20.0))
	for i in range(1, pas + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(pas))
		if _blocked_by_wall(p):
			return p
	return Vector2.INF


# =====================================================================
# LE BRISEUR DE TERRAIN (chantier W3)
#
# L Enemy decide QUAND il frappe (minuterie, preparation, annulation par la
# mort ou l etourdissement) ; le terrain sait QUOI il peut frapper. Le Briseur ne
# connait ni `props` ni `walls` : il ne voit que les ANCRES du groupe
# `TerrainProp.GROUP`, et `destroy()` est tout le contrat. Un futur objet de
# terrain qui pose une ancre sera donc brisable sans une ligne ici.

## Genres que le Briseur EPARGNE. L eau ne se brise pas : la nappe n a meme pas
## de PV (voir TerrainProp.is_breakable), et la Riviere est une legendaire tres
## chere, une seule par combat. La couper d un geste ferait du Briseur un contre
## absolu de la carte la plus rare du jeu — le joueur qui l a tiree serait puni
## de l avoir jouee. Une breche partielle (un gue) a ete envisagee et ecartee :
## elle demandait un visuel de riviere entaillee que le pack n a pas, et une
## breche invisible est pire qu aucune.
const BREAKER_SPARED_KINDS: Array[int] = [TerrainProp.Kind.WATER, TerrainProp.Kind.RIVER]

## Objets de terrain brises par un Briseur depuis la creation du champ (lecture
## pour les tests et le banc, comme `lasers_fired`).
var terrain_broken: int = 0


## L ancre la plus PROCHE du Briseur a moins de `reach` px, null s il n y en a pas.
## La plus proche, pas la plus precieuse : le joueur doit pouvoir PREVOIR ce qui
## va tomber en regardant l ecran, sans connaitre une table de priorites.
func breaker_target(e: Enemy, reach: float) -> Node:
	if e == null or reach <= 0.0:
		return null
	var best: Node = null
	var best_d: float = reach
	for a in terrain_anchors():
		if not breaker_can_break(a):
			continue
		var d: float = e.position.distance_to((a as Node2D).position)
		if d <= best_d:
			best_d = d
			best = a
	return best


## Cette ancre est-elle une cible valable ? Encore dans le groupe (une ancre
## retiree attend son `queue_free` jusqu a la fin de l image) et pas de l eau.
func breaker_can_break(a: Node) -> bool:
	if a == null or not is_instance_valid(a) or not (a is Node2D):
		return false
	if not a.is_in_group(TerrainProp.GROUP) or not a.has_method("destroy"):
		return false
	return not (int(a.get("kind")) in BREAKER_SPARED_KINDS)


## Le coup lui-meme. La fissure part AVANT le `destroy()` : c est l ancre qui
## porte la position, et elle est liberee par la destruction.
func breaker_strike(e: Enemy, a: Node) -> bool:
	if not _alive(e) or not breaker_can_break(a):
		return false
	var ou: Vector2 = (a as Node2D).position
	Fx.ground_crack(self, e.position, ou)
	AudioBus.play_sfx(&"impact_heavy")
	a.call("destroy")
	terrain_broken += 1
	return true


# =====================================================================
# OBJECTIFS LIES AUX MONSTRES — chemin parcouru, morts attribuees
#
# Les regles sont en tete de objective_checker.gd (LANCER, CHEMIN) ; ici, les
# seuls releves que Battlefield est le seul a voir.

## Photo avant le deplacement de l image : position et nombre de retours dans
## le temps deja faits (un retour de Chronos est un saut, pas un chemin).
func _obj_travel_begin(e: Enemy) -> Array:
	return [e.position, e.rewinds_done()]


## Ajoute au compteur du monstre la distance couverte PENDANT son deplacement
## (marche et courant). Les repousses et vortex agissent hors de cette fenetre,
## ils ne comptent donc pas ; un retour dans le temps survenu dans la fenetre
## est ecarte par son compteur.
func _obj_travel_end(e: Enemy, depart: Array) -> void:
	if e == null or not is_instance_valid(e) or depart.size() < 2:
		return
	if e.rewinds_done() != int(depart[1]):
		return
	var pas: float = e.position.distance_to(depart[0])
	if pas <= 0.0:
		return
	e.set_meta(RunState.TRAVEL_META, float(e.get_meta(RunState.TRAVEL_META, 0.0)) + pas)


## Une mort qui compte (memes morts que enemy_killed) : on la credite a la source
## des degats en cours — le coup de grace vient de partir, dans cette meme pile
## d appels — et on retient le chemin qu il avait fait.
func _obj_note_death(e: Enemy, def: EnemyDef) -> void:
	RunState.note_kill_by_source(def)
	if e != null and is_instance_valid(e):
		RunState.note_travel_at_death(def, float(e.get_meta(RunState.TRAVEL_META, 0.0)))
