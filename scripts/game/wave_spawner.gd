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
## CHANTIER W8 : la vague `index` a traine (voir _w8_overtime_due) ; la suivante
## demarre alors que des monstres restent. Emis A LA PLACE de wave_cleared.
signal wave_overtime(index: int)

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
## Faux en MASSACRE (chantier M) : aucun monde, donc ni poids local au tirage ni
## annonce `world_changed` — le fond reste celui du niveau et le HUD n affiche
## aucun bandeau de monde. Vrai en Infini, qui traverse les cinq mondes.
var worlds_enabled: bool = true
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
## peut imposer sa propre table. `worlds` a faux (Massacre) retire les mondes :
## tirage uniforme sur tout le pool, aucun changement de lieu.
func setup_procedural(bf: Battlefield, enemy_pool: Array[EnemyDef],
		boss_pool: Array[EnemyDef], rng_seed: int = 0,
		world_map: Dictionary = {}, worlds: bool = true) -> void:
	battlefield = bf
	waves = []
	procedural = true
	pool = enemy_pool
	bosses = boss_pool
	worlds_enabled = worlds
	if not worlds:
		membership = {}
	else:
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
	if procedural and worlds_enabled:
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
	_last_spawn_at = -1.0  # CHANTIER W8 : aucune apparition faite
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
		_last_spawn_at = _elapsed  # CHANTIER W8 : depart du compte de la vague qui traine
	# La vague est finie quand la file est vide et le terrain nettoye — y compris
	# des marques de renaissance, qui sont des monstres a venir (is_clear).
	if _queue.is_empty() and battlefield.is_clear():
		active = false
		wave_cleared.emit(index)
	elif _w8_overtime_due():
		# CHANTIER W8 : la vague a traine, la suivante prend le relais.
		active = false
		overtime_count += 1
		wave_overtime.emit(index)


## Largeur du couloir d un groupe : assez etroit pour qu une zone en couvre
## plusieurs, assez large pour qu ils ne se superposent pas exactement.
const LANE_MARGIN: float = 220.0
const LANE_SPREAD: float = 130.0


func _spawn_x(def: EnemyDef, lane: float = -1.0) -> float:
	var margin: float = spawn_margin(def)
	if def.entry_side:
		return margin if _rng.randi() % 2 == 0 else GameConfig.BATTLEFIELD_WIDTH - margin
	if lane < 0.0:
		return _rng.randf_range(margin, GameConfig.BATTLEFIELD_WIDTH - margin)
	return clampf(lane + _rng.randf_range(-LANE_SPREAD, LANE_SPREAD),
		margin, GameConfig.BATTLEFIELD_WIDTH - margin)


## Marge laterale d apparition : 90 px, ou la demi-largeur AFFICHEE du monstre si
## elle est plus grande.
##
## LE DEFAUT QUE CECI REPARE : l entree par le cote posait tout monstre a 90 px
## du bord. Un mini-boss de 62 px de rayon logique s affiche a ~130 px de
## demi-largeur (Enemy.VISUAL_FACTOR), davantage avec son `sprite_scale` : la
## moitie de sa silhouette naissait hors de l ecran, la ou le doigt ne peut pas
## le viser. On raisonne sur la taille VUE, parce que c est elle que le joueur
## cherche a toucher.
static func spawn_margin(def: EnemyDef) -> float:
	var marge: float = 90.0
	if def == null:
		return marge
	var demi: float = def.base_radius * Enemy.VISUAL_FACTOR * maxf(def.sprite_scale, 0.1)
	return clampf(maxf(marge, demi), marge, GameConfig.BATTLEFIELD_WIDTH * 0.5 - 1.0)


func current_wave() -> WaveDef:
	if index >= 0 and index < waves.size():
		return waves[index]
	return null


## --- CHANTIER W8 : la vague qui TRAINE ---------------------------------------
##
## Avant, la vague suivante attendait la mort du DERNIER monstre (tick, plus
## haut). Deux campeurs qui se protegent (Echos d Ymoa), un tank ralenti en
## boucle contre un mur : la partie se figeait, sans rien a l ecran pour le dire.
## Desormais, GameConfig.WAVE_OVERTIME_SECONDS de MONDE apres la derniere
## apparition, la vague suivante demarre meme si des monstres restent (ils restent
## en jeu). Temps du monde : a x4 tout va quatre fois plus vite, l attente aussi.

## Elapsed (temps du monde) de la DERNIERE apparition de la vague en cours, -1 si
## aucune n a encore eu lieu.
var _last_spawn_at: float = -1.0
## Vagues ecourtees depuis le debut de la partie (lu par le banc et les tests).
var overtime_count: int = 0


## La vague en cours doit-elle ceder la place ? Toutes ses apparitions faites,
## le delai ecoule depuis la derniere, et le droit d etre ecourtee.
func _w8_overtime_due() -> bool:
	if not _queue.is_empty() or _last_spawn_at < 0.0:
		return false
	if _elapsed - _last_spawn_at < GameConfig.WAVE_OVERTIME_SECONDS:
		return false
	return can_cut_short()


## Cette vague peut-elle etre ecourtee ? Trois exceptions, chacune pour une raison :
##   - la DERNIERE vague ecrite : la victoire attend que TOUT soit mort, restants
##     des vagues ecourtees compris (is_clear regarde tout le terrain) ;
##   - une vague de BOSS ou de MINI-BOSS : le combat de boss se joue jusqu au
##     bout, on ne lui ajoute pas une vague par-dessus ;
##   - la vague SUIVANTE est une vague de boss : on ne l ouvre pas en avance sur
##     des restants. Un boss se presente sur un terrain nettoye.
func can_cut_short() -> bool:
	var w: WaveDef = current_wave()
	if w == null or w.is_boss or w.is_miniboss:
		return false
	var suivante: int = index + 1
	if procedural:
		# La vague suivante n est pas encore fabriquee : on lit la cadence.
		return not (WaveBudget.is_boss_wave(suivante + 1)
			or WaveBudget.is_miniboss_wave(suivante + 1))
	if suivante >= waves.size():
		return false
	var nw: WaveDef = waves[suivante]
	return nw != null and not nw.is_boss and not nw.is_miniboss


## Secondes de monde avant que la vague en cours cede la place, ou -1 si elle ne
## le fera pas (apparitions pas finies, ou vague qui ne s ecourte pas).
func overtime_left() -> float:
	if not active or not _queue.is_empty() or _last_spawn_at < 0.0 or not can_cut_short():
		return -1.0
	return maxf(0.0, GameConfig.WAVE_OVERTIME_SECONDS - (_elapsed - _last_spawn_at))


## Vrai seulement quand start_next() a franchi la derniere vague ecrite.
## En procedural il n y a pas de derniere vague : jamais fini.
func is_finished() -> bool:
	if procedural:
		return false
	return index >= waves.size()
