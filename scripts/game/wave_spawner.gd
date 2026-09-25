class_name WaveSpawner
extends Node
## Deroule les vagues : apparitions echelonnees, fin de vague, mini-boss et boss.
## Deux modes : liste de vagues ecrites (Exploration) ou generation par budget
## sans fin (Massacre / infini).

signal wave_started(index: int, wave: WaveDef)
signal wave_cleared(index: int)
signal all_waves_cleared()
## Mode infini : on vient de changer de LIEU. `backdrop_key` est une cle de
## `assets/backdrops/`, a passer telle quelle a BattleBackdrop.setup().
##
## C est un SIGNAL et non un appel direct au decor : le spawner n a pas a
## connaitre le noeud de fond, et un ecran qui voudrait annoncer le monde (HUD,
## banniere) s y branche sans que le spawner change.
signal world_changed(world_index: int, backdrop_key: String, world_name: String)

var battlefield: Battlefield = null
var waves: Array[WaveDef] = []
var index: int = -1
var active: bool = false

## Mode infini : les vagues sont fabriquees a la volee par WaveBudget.
var procedural: bool = false
var pool: Array[EnemyDef] = []
var bosses: Array[EnemyDef] = []
## id de monstre -> index de monde (voir WaveBudget.WORLDS). C est ce qui fait
## que le LIEU pese sur le tirage : un cimetiere envoie des morts-vivants.
var membership: Dictionary = {}
## Dernier monde annonce, pour n emettre `world_changed` qu au vrai changement.
var _world: int = -1

var _elapsed: float = 0.0
var _queue: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(bf: Battlefield, wave_list: Array[WaveDef], rng_seed: int = 0) -> void:
	battlefield = bf
	waves = wave_list.duplicate()
	procedural = false
	index = -1
	active = false
	_seed(rng_seed)


## Mode infini. `world_map` (id de monstre -> index de monde) est FACULTATIF :
## omis, il est deduit du contenu par `build_membership()`. Un appelant de test
## peut imposer sa propre table.
func setup_procedural(bf: Battlefield, enemy_pool: Array[EnemyDef],
		boss_pool: Array[EnemyDef], rng_seed: int = 0,
		world_map: Dictionary = {}) -> void:
	battlefield = bf
	waves = []
	procedural = true
	pool = enemy_pool
	bosses = boss_pool
	membership = world_map if not world_map.is_empty() else build_membership()
	index = -1
	active = false
	_world = -1
	_seed(rng_seed)


## Rattache chaque monstre a un MONDE, deduit du contenu deja ecrit.
##
## POURQUOI PAS LE POOL DES NIVEAUX. Premier essai : "un monstre appartient au
## premier acte dont un niveau le liste". Mesure a la sonde : les pools de niveaux
## se CHEVAUCHENT volontairement (lvl_01 et lvl_02 listent a eux deux 18 des 27
## monstres), donc 11 monstres tombaient dans le monde 0 et les mondes 2 et 4 n en
## recevaient AUCUN. Le fond changeait et rien ne changeait avec lui — la demande
## "le fond pese sur le tirage" n etait pas tenue pour trois mondes sur cinq.
##
## CE QUI MARCHE : les VAGUES ECRITES, pas les pools. Un concepteur qui fait
## descendre 44 nuees de rats dans l acte 2 et 8 dans l acte 1 a dit ou vivent les
## rats, meme sans jamais l ecrire. On prend donc l acte ou le monstre est le plus
## DENSE, et la densite est normalisee par le volume de l acte : sans cette
## normalisation un acte a deux niveaux ecrase toujours un acte a un seul, et
## l acte 4 (lvl_07 seul, 54 corps contre 115) ne remportait aucun monstre.
##
## Mesure de la repartition obtenue : 4 / 6 / 10 / 4 monstres pour les actes 1 a 4.
## Chaque monde a une famille reelle, et c est du contenu deja ecrit qu elle sort —
## aucune table de theme inventee ici, qui serait de la conception de contenu.
##
## L ACTE 5 n a pas de niveau, donc aucun monstre ne peut lui etre attribue. Ce
## n est pas un trou a boucher : le Seuil divin est le lieu ou les quatre mondes
## CONVERGENT. N y rattacher personne lui donne exactement ce comportement — un
## tirage uniforme sur tout le bestiaire, sans famille dominante.
static func build_membership() -> Dictionary:
	var act_to_world: Dictionary = {}
	for i in WaveBudget.WORLDS.size():
		act_to_world[int(WaveBudget.WORLDS[i].get("act", 0))] = i
	# corps ecrits par monstre et par acte, et volume total de chaque acte.
	var corps: Dictionary = {}
	var volume: Dictionary = {}
	for level_id in ContentDB.levels.keys():
		var lvl: LevelDef = ContentDB.levels.get(level_id)
		if lvl == null or not act_to_world.has(lvl.act):
			continue
		for w: WaveDef in lvl.waves:
			for e: WaveEntry in w.entries:
				# Un projectile n est pas une creature du lieu : il est tire.
				if e.enemy == null or e.enemy.projectile:
					continue
				var n: int = e.count * maxi(1, e.enemy.swarm_count)
				if not corps.has(e.enemy.id):
					corps[e.enemy.id] = {}
				corps[e.enemy.id][lvl.act] = int(corps[e.enemy.id].get(lvl.act, 0)) + n
				volume[lvl.act] = int(volume.get(lvl.act, 0)) + n
	var out: Dictionary = {}
	for id in corps:
		var best_act: int = -1
		var best: float = -1.0
		for act in corps[id]:
			var densite: float = float(corps[id][act]) / maxf(volume.get(act, 1), 1.0)
			if densite > best:
				best = densite
				best_act = int(act)
		if act_to_world.has(best_act):
			out[id] = int(act_to_world[best_act])
	return out


func _seed(rng_seed: int) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func start_next() -> bool:
	index += 1
	if procedural and index >= waves.size():
		waves.append(WaveBudget.build_wave(index + 1, pool, _rng, bosses, membership))
	# Le LIEU s annonce avant la vague : le fond doit avoir change quand les
	# premiers monstres arrivent, pas apres. On n emet qu au vrai changement,
	# sinon le decor se reconstruirait a chaque vague.
	if procedural:
		var w_new: int = WaveBudget.world_index_for(index + 1)
		if w_new != _world:
			_world = w_new
			world_changed.emit(w_new, WaveBudget.backdrop_for(index + 1),
				WaveBudget.world_name_for(index + 1))
	if index >= waves.size():
		active = false
		all_waves_cleared.emit()
		return false
	var w: WaveDef = waves[index]
	_elapsed = 0.0
	_queue.clear()
	for entry in w.entries:
		if entry == null or entry.enemy == null:
			continue
		var count: int = entry.count * maxi(1, entry.enemy.swarm_count)
		# Les monstres d une meme entree descendent dans un COULOIR commun plutot
		# que disperses sur toute la largeur. Mesure au banc : disperses, une zone
		# n en attrapait jamais plus d un, et les sorts de zone ne servaient a rien.
		var lane: float = _rng.randf_range(LANE_MARGIN,
			GameConfig.BATTLEFIELD_WIDTH - LANE_MARGIN)
		for i in count:
			_queue.append({
				"def": entry.enemy,
				"at": entry.start_offset + i * entry.spawn_delay,
				"difficulty": w.difficulty,
				"lane": lane,
			})
	_queue.sort_custom(func(a, b): return a["at"] < b["at"])
	active = true
	wave_started.emit(index, w)
	return true


func tick(delta: float) -> void:
	if not active or battlefield == null:
		return
	_elapsed += SpeedGauge.world_delta(delta)
	while not _queue.is_empty() and _queue[0]["at"] <= _elapsed:
		var item: Dictionary = _queue.pop_front()
		var def: EnemyDef = item["def"]
		battlefield.spawn_enemy(def, _spawn_x(def, item.get("lane", -1.0)), item["difficulty"])
	# La vague est finie quand la file est vide et le terrain nettoye.
	if _queue.is_empty() and battlefield.alive_count() == 0:
		active = false
		wave_cleared.emit(index)


## Largeur du couloir d un groupe : assez etroit pour qu une zone en couvre
## plusieurs, assez large pour qu ils ne se superposent pas exactement.
const LANE_MARGIN: float = 220.0
const LANE_SPREAD: float = 130.0


func _spawn_x(def: EnemyDef, lane: float = -1.0) -> float:
	var margin: float = 90.0
	if def.entry_side:
		return margin if _rng.randi() % 2 == 0 else GameConfig.BATTLEFIELD_WIDTH - margin
	if lane < 0.0:
		return _rng.randf_range(margin, GameConfig.BATTLEFIELD_WIDTH - margin)
	return clampf(lane + _rng.randf_range(-LANE_SPREAD, LANE_SPREAD),
		margin, GameConfig.BATTLEFIELD_WIDTH - margin)


func current_wave() -> WaveDef:
	if index >= 0 and index < waves.size():
		return waves[index]
	return null


## Vrai seulement quand start_next() a franchi la derniere vague ecrite.
## En procedural il n y a pas de derniere vague : jamais fini.
func is_finished() -> bool:
	if procedural:
		return false
	return index >= waves.size()
