class_name Enemy
extends Node2D
## Un monstre qui descend vers le mage.
## Toute la temporalite passe par SpeedGauge.world_delta() : un monstre est donc
## naturellement accelere par le multiplicateur, sans Engine.time_scale.
##
## Les comportements speciaux (a-coups, ondulation, enrage, bouclier, tir) vivent
## ici ; ceux qui impliquent D AUTRES monstres (aura, soin, gobage, division)
## vivent dans Battlefield, qui voit tout le monde.

signal died(enemy: Enemy)
signal reached_mage(enemy: Enemy)

var definition: EnemyDef = null
var hp: float = 10.0
var speed_scale: float = 1.0      ## buffs/ralentissements globaux
var battlefield: Battlefield = null
var nav: NavGrid = null
var difficulty: float = 1.0
## Facteur de taille : le Glouton grossit en gobant.
var growth: float = 1.0

var _max_hp: float = 1.0
var _slow_time: float = 0.0
var _slow_factor: float = 1.0
var _phase_timer: float = 0.0
var _hidden: bool = false
var _dead: bool = false
var _absorbed: bool = false

var _path: Array[Vector2] = []
var _path_index: int = 0
var _nav_version: int = -1
var _repath_timer: float = 0.0

var _enrage_bonus: float = 0.0
var _shield_up: bool = false
var _burst_timer: float = 0.0
var _burst_dashing: bool = true
var _wave_phase: float = 0.0
var _base_x: float = 0.0
var _shoot_timer: float = 0.0
var _flash_tween: Tween = null

const HP_BAR_WIDTH: float = 62.0

@onready var _body: EnemyBody = $Body
@onready var _anim: AnimatedSprite2D = $Anim
@onready var _hp_bar: TextureProgressBar = $HpBar

## Halo/aura (sprites du pack) attaches au monstre.
var _shield_fx: Node = null
var _aura_fx: Node = null
var _last_x: float = 0.0


func setup(def: EnemyDef, diff: float = 1.0) -> void:
	definition = def
	difficulty = diff
	hp = def.max_hp * diff
	_max_hp = maxf(hp, 0.001)
	_shield_up = def.first_hit_shield
	# Premier tir un peu plus tot que l intervalle : le joueur voit vite la menace.
	_shoot_timer = def.shoot_interval * 0.6


func _ready() -> void:
	_base_x = position.x
	_last_x = position.x
	if definition != null and _body != null:
		_body.setup(definition, _shield_up)
		_setup_visual()
		_place_hp_bar()
	_refresh_hp_bar()


## Feuille animee du pack si le monstre en a une ; sinon la forme de secours.
func _setup_visual() -> void:
	var key: StringName = definition.anim_key
	if key == &"" or not AnimCatalog.has(key) or _anim == null:
		return
	_body.draw_shape = false
	_anim.visible = true
	_anim.modulate = AnimCatalog.modulate_for(definition.id)
	if AnimCatalog.is_static(key):
		var tex: Texture2D = AnimCatalog.static_texture(key)
		if tex != null:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.name = "Static"
			add_child(sp)
			_anim.visible = false
			_apply_scale(sp, float(tex.get_height()))
			# Sans animation, le halo de la tour sert d aura.
	else:
		_anim.sprite_frames = AnimCatalog.frames(key)
		_apply_scale(_anim, float(AnimCatalog.frame_px(key)))
		_anim.play("walk")
	if Fx.enabled():
		if definition.aura_shield_radius > 0.0:
			_aura_fx = Fx.halo(self, definition.aura_shield_radius, Color(1.0, 0.92, 0.6, 0.55))
		if _shield_up:
			_shield_fx = Fx.halo(self, visual_radius() * 1.05, Color(0.85, 0.9, 1.0, 0.9))


## Le rayon logique (gobage, contact) etait calibre pour des formes ; les sprites
## doivent etre nettement plus grands pour se lire sur un ecran 1080 de large.
const VISUAL_FACTOR: float = 1.9

## Part des degats encaissee par un monstre en phase (Ombre).
const PHASE_DAMAGE_FACTOR: float = 0.4


func visual_radius() -> float:
	return radius() * VISUAL_FACTOR


## Met le sprite a l echelle du rayon visuel : un monstre P4 est gros a l ecran.
func _apply_scale(node: Node2D, frame_px: float) -> void:
	var key: StringName = definition.anim_key
	var visible_px: float = frame_px * AnimCatalog.occupancy(key)
	var wanted: float = visual_radius() * 2.0 * definition.sprite_scale
	node.scale = Vector2.ONE * (wanted / maxf(visible_px, 1.0))


func _place_hp_bar() -> void:
	if _hp_bar == null:
		return
	var r: float = visual_radius()
	# Barre a peu pres aussi large que le monstre, mais jamais enorme.
	var sc: float = clampf(r * 2.0 / 112.0 * 0.6, 0.3, 0.75)
	_hp_bar.scale = Vector2.ONE * sc
	# Posee juste au-dessus du sprite : un petit monstre ne doit pas porter sa barre
	# a la hauteur d un gros. L ecart suit le rayon, il n est pas constant.
	_hp_bar.position = Vector2(-56.0 * sc, -r * 0.78 - 51.0 * sc)


func radius() -> float:
	if _body != null:
		return _body.radius()
	return (definition.base_radius if definition != null else 32.0) * growth


## delta deja mis a l echelle par l appelant (Battlefield).
func advance(world_delta: float) -> void:
	if _dead or definition == null:
		return
	if _slow_time > 0.0:
		_slow_time -= world_delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
	if definition.phase_interval > 0.0:
		_phase_timer += world_delta
		if _phase_timer >= definition.phase_interval:
			_phase_timer = 0.0
			_hidden = not _hidden
			# Toujours VISIBLE, mais transparente : le joueur doit pouvoir la viser
			# et comprendre pourquoi elle encaisse moins.
			modulate.a = 0.35 if _hidden else 1.0

	# ENEMY_SPEED_SCALE : reglage global de la fenetre de reaction du joueur.
	# Le modifier touche TOUS les monstres d un coup, sans reecrire 22 fichiers.
	var speed: float = (definition.base_speed * GameConfig.ENEMY_SPEED_SCALE
		* speed_scale * _slow_factor * (1.0 + _enrage_bonus))

	# A-coups : fonce, puis marque une pause.
	if definition.burst_move:
		_burst_timer += world_delta
		if _burst_dashing and _burst_timer >= definition.burst_dash_time:
			_burst_dashing = false
			_burst_timer = 0.0
		elif not _burst_dashing and _burst_timer >= definition.burst_pause_time:
			_burst_dashing = true
			_burst_timer = 0.0
		speed = speed * 1.7 if _burst_dashing else 0.0

	# Volte-face : le monstre remonte vers le haut.
	if battlefield != null and battlefield.is_reversed():
		position.y = maxf(position.y - speed * world_delta, GameConfig.SPAWN_LINE_Y)
		_path.clear()
		_path_index = 0
		return

	_advance_along_path(speed, world_delta)

	# Ondulation laterale, uniquement en descente libre (le chemin A* prime).
	if definition.wave_amplitude > 0.0 and _path.is_empty():
		_wave_phase += world_delta * definition.wave_frequency * TAU
		position.x = clampf(_base_x + sin(_wave_phase) * definition.wave_amplitude,
			40.0, GameConfig.BATTLEFIELD_WIDTH - 40.0)

	# Tir sur le mage.
	if definition.shoot_interval > 0.0 and battlefield != null and not _hidden:
		_shoot_timer -= world_delta
		if _shoot_timer <= 0.0:
			_shoot_timer = definition.shoot_interval
			play_attack()
			battlefield.enemy_shoot(self, definition.shot_damage)

	# Les unites du pack regardent a droite : on les retourne quand elles vont a gauche.
	if _anim != null and _anim.visible:
		var dx: float = position.x - _last_x
		if absf(dx) > 0.5:
			_anim.flip_h = dx < 0.0
	_last_x = position.x

	if position.y >= GameConfig.MAGE_LINE_Y:
		reached_mage.emit(self)


## Descente directe tant qu aucun mur ne gene ; sinon on suit le chemin A*.
func _advance_along_path(speed: float, world_delta: float) -> void:
	if nav == null:
		position.y += speed * world_delta
		return

	_repath_timer -= world_delta
	if _nav_version != nav.version() or (_repath_timer <= 0.0 and not _path.is_empty()):
		_recompute_path()

	if _path.is_empty():
		var next_y: float = position.y + speed * world_delta
		if nav.is_blocked(nav.to_cell(Vector2(position.x, next_y))):
			_recompute_path()
			if _path.is_empty():
				# Totalement enferme. Un mur temporaire finit par expirer, mais un
				# mur PERMANENT ne partira jamais tout seul : le monstre le casse,
				# sinon la partie se fige avec une vague qui ne descend plus.
				if battlefield != null:
					battlefield.enemy_strikes_wall(self, world_delta)
				return
		else:
			position.y = next_y
			return

	while _path_index < _path.size():
		var target: Vector2 = _path[_path_index]
		var to_target: Vector2 = target - position
		var dist: float = to_target.length()
		var step: float = speed * world_delta
		if dist <= step:
			position = target
			_path_index += 1
			break
		position += to_target / dist * step
		return
	if _path_index >= _path.size():
		_path.clear()
		_path_index = 0
		_base_x = position.x


func _recompute_path() -> void:
	if nav == null:
		return
	_nav_version = nav.version()
	_repath_timer = 0.5
	_path_index = 0
	# Sans mur, la descente droite est le chemin : pas d A*, pas de zigzag entre
	# centres de cellules, et l ondulation garde la main.
	if nav.blocked_count() == 0:
		_path.clear()
		return
	_path = nav.find_path(position)


## Renvoie true si les degats ont ete appliques (false si immunise, esquive,
## invisible, ou absorbes par le bouclier du premier coup).
## `tags` est un Array NON type : Godot 4.4 refuse de convertir un Array vers un
## Array[GameEnums.DamageTag] a l appel, ce qui casserait tous les degats.
func take_damage(amount: float, tags: Array) -> bool:
	if _dead or definition == null:
		return false
	for t in tags:
		if definition.is_immune_to(t):
			return false
	# L Ombre en phase encaisse MOINS, mais reste touchable. Une invulnerabilite
	# totale sur un cycle de 2,5 s, plus long que la plupart des incantations,
	# rendait le monstre impossible a gerer : le joueur lancait dans le vide sans
	# aucun moyen de savoir quand.
	if _hidden:
		amount *= PHASE_DAMAGE_FACTOR
	if definition.dodge_chance > 0.0 and randf() < definition.dodge_chance:
		return false
	if _shield_up:
		_shield_up = false
		if _body != null:
			_body.set_shield(false)
		if _shield_fx != null and is_instance_valid(_shield_fx):
			_shield_fx.queue_free()
			_shield_fx = null
		AudioBus.play_sfx(&"shield_break")
		return false
	hp -= amount
	_refresh_hp_bar()
	if definition.enrage_speed_pct > 0.0:
		_enrage_bonus = minf(_enrage_bonus + definition.enrage_speed_pct * 0.01, definition.enrage_cap)
	if hp <= 0.0:
		kill()
	elif _anim != null and _anim.visible and AnimCatalog.has_anim(definition.anim_key, "hurt"):
		_anim.play("hurt")
		if not _anim.animation_finished.is_connected(_back_to_walk):
			_anim.animation_finished.connect(_back_to_walk)
	return true


func _back_to_walk() -> void:
	if _anim != null and not _dead and _anim.animation != "walk":
		_anim.play("walk")


## Animation d attaque (tir de l archer, coup du berserker).
func play_attack() -> void:
	if _anim != null and _anim.visible and AnimCatalog.has_anim(definition.anim_key, "attack"):
		_anim.play("attack")
		if not _anim.animation_finished.is_connected(_back_to_walk):
			_anim.animation_finished.connect(_back_to_walk)


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = minf(_max_hp, hp + amount)
	_refresh_hp_bar()


## Le Glouton gagne des PV et de la taille en gobant.
func grow(hp_gain: float, scale_gain: float) -> void:
	_max_hp += hp_gain
	hp += hp_gain
	growth += scale_gain
	if _body != null:
		_body.set_growth(growth)
	if _anim != null and _anim.visible and definition != null:
		_apply_scale(_anim, float(AnimCatalog.frame_px(definition.anim_key)))
	_place_hp_bar()
	AudioBus.play_sfx(&"grow")
	_refresh_hp_bar()


func apply_slow(factor: float, duration: float) -> void:
	if definition != null and definition.is_immune_to(GameEnums.DamageTag.SLOW):
		return
	_slow_factor = clampf(factor, 0.05, 1.0)
	_slow_time = duration


func kill() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)


## Retire du terrain sans mort (gobe par un Glouton) : ni XP ni division.
func absorb() -> void:
	_dead = true
	_absorbed = true


func is_dead() -> bool:
	return _dead


func is_hidden() -> bool:
	return _hidden


func has_shield() -> bool:
	return _shield_up


func enrage_bonus() -> float:
	return _enrage_bonus


func max_hp() -> float:
	return _max_hp


func reset_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _body != null:
		_body.modulate = Color.WHITE


func set_flash_tween(tw: Tween) -> void:
	_flash_tween = tw


## Micro barre de vie (barre du pack). Cachee tant que le monstre est intact.
func _refresh_hp_bar() -> void:
	if _hp_bar == null:
		return
	var ratio: float = clampf(hp / _max_hp, 0.0, 1.0)
	var intact: bool = ratio >= 0.999
	_hp_bar.visible = not intact
	if intact:
		return
	_hp_bar.value = ratio * 100.0
	if ratio > 0.6:
		_hp_bar.tint_progress = Color(0.55, 1.0, 0.55)
	elif ratio > 0.3:
		_hp_bar.tint_progress = Color(1.0, 0.85, 0.35)
	else:
		_hp_bar.tint_progress = Color(1.0, 0.45, 0.4)


# --- Sorts demandes par le testeur : vortex et dissipation ---

## Oblige le monstre a reconsiderer son chemin. Un sort qui le DEPLACE (souffle
## de repulsion, vortex) laisserait sinon un chemin A* calcule depuis l ancienne
## position : le monstre repartirait en arriere pour rejoindre son ancien couloir.
func repath() -> void:
	_path.clear()
	_path_index = 0
	_nav_version = -1
	_base_x = position.x


## Dissipation : le monstre perd tout ce qu il a GAGNE en cours de vague.
## On ne touche pas a ses PV ni a sa definition : un golem reste un golem, mais
## un berserker deja lance redevient un berserker frais.
func dispel() -> void:
	if _dead:
		return
	_enrage_bonus = 0.0
	_slow_factor = 1.0
	_slow_time = 0.0
	if _shield_up:
		_shield_up = false
		if _body != null:
			_body.set_shield(false)
		if _shield_fx != null and is_instance_valid(_shield_fx):
			_shield_fx.queue_free()
			_shield_fx = null
