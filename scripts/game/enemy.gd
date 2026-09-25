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
## Secondes d immobilisation restantes (sort d etourdissement, chantier H).
## Distinct du ralentissement : un ralentissement est un FACTEUR, qui ne peut que
## tendre vers zero sans jamais l atteindre, alors qu un etourdissement est un
## ETAT — le monstre n avance pas, ne tire pas, ne frappe rien. Melanger les deux
## aurait fait d un stun un ralentissement a 100 %, que la table de resistances
## aurait ramene a 99 % chez la moitie du bestiaire : le joueur aurait vu son sort
## le plus cher ne rien figer du tout.
var _stun_time: float = 0.0
var _phase_timer: float = 0.0
var _hidden: bool = false
var _dead: bool = false
var _absorbed: bool = false
## Secondes restantes de fondu d apparition. Tant qu il est > 0 le monstre est
## IMMOBILE et INTOUCHABLE : voir GameConfig.SPAWN_FADE_TIME.
var _spawn_fade: float = 0.0

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

## Boss morcele : PV restants de chaque partie encore debout. On garde un
## TABLEAU et non un compteur, parce qu une partie a demi entamee doit retenir
## ses degats d un coup a l autre — sinon le joueur devrait la tuer en une fois.
var _parts: Array[float] = []
var _summon_timer: float = 0.0
## Sbires vivants issus de CE boss. Comptes ici plutot que sur le terrain :
## deux invocateurs ne doivent pas se voler leur plafond.
var _summoned: Array[Enemy] = []

## RESSUSCITE : vrai des qu il s est releve. Une seule fois — sans ce drapeau un
## joueur sans le bon deck ne finirait jamais le combat, et la surprise du
## premier releve deviendrait un mur de PV deguise.
var _revived: bool = false
## Secondes restantes d IMMUNITE de releve. Sans ce court repit, le sort qui
## vient de le tuer (un Meteore a degats de zone, ou simplement la deuxieme
## cible d une chaine) le retuait dans la meme frame et le joueur ne voyait
## JAMAIS le releve : la mecanique n aurait existe que dans le code.
var _revive_grace: float = 0.0
const REVIVE_GRACE: float = 0.7

## IMMUNISE AUX N PREMIERS COUPS : coups qu il peut encore ignorer.
var _hits_immune_left: int = 0

## BOUCLIER DE RENVOI : temps avant la prochaine garde, et temps de garde restant.
var _reflect_timer: float = 0.0
var _reflect_left: float = 0.0
## Halo de la garde de renvoi. Distinct de `_shield_fx`, qui ne se leve jamais et
## ne se baisse qu une fois : celui-ci clignote au rythme du cycle, et le joueur
## doit pouvoir lire les deux en meme temps sur un boss qui porterait les deux.
var _reflect_fx: Node = null

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
	# Premiere invocation a l intervalle PLEIN : le joueur a le temps de voir le
	# boss entrer avant que l ecran se remplisse.
	_summon_timer = def.summon_interval
	_hits_immune_left = def.hits_immune
	# Premiere garde de renvoi a l intervalle PLEIN : le boss entre a decouvert,
	# pour que le joueur ait le temps de le voir lever sa garde une premiere fois
	# et de comprendre le cycle avant d etre puni par lui.
	_reflect_timer = def.reflect_interval
	_reflect_left = 0.0
	_revived = false
	_revive_grace = 0.0
	_parts.clear()
	if def.parts_count > 0 and def.part_hp > 0.0:
		for i in def.parts_count:
			_parts.append(def.part_hp * diff)


func _ready() -> void:
	_base_x = position.x
	_last_x = position.x
	if definition != null and _body != null:
		# Les sceaux du boss immunise se lisent comme un bouclier : c est la meme
		# chose pour le joueur — quelque chose devant la creature.
		_body.setup(definition, _shield_up or _hits_immune_left > 0)
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
		if _shield_up or not _parts.is_empty() or _hits_immune_left > 0:
			# Le meme halo sert au bouclier de premier coup, a l armure du boss
			# morcele et aux sceaux du boss immunise aux N premiers coups : dans
			# les trois cas il signifie « ce que tu frappes n est pas encore la
			# creature ». Sans lui, le joueur du Reliquaire voit six sorts ne rien
			# faire et conclut que son deck est casse.
			_shield_fx = Fx.halo(self, visual_radius() * 1.05, Color(0.85, 0.9, 1.0, 0.9))


## Le rayon logique (gobage, contact) etait calibre pour des formes ; les sprites
## doivent etre nettement plus grands pour se lire sur un ecran 1080 de large.
## 2,1 et non 1,9 : demande du testeur, "augmente legerement la taille de tous
## les monstres". Ne touche QUE l affichage — le rayon logique (contact, gobage,
## portee des auras) reste `radius()`.
const VISUAL_FACTOR: float = 2.1

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


## Demarre le fondu d apparition. Appele par Battlefield pour les monstres qui
## naissent sur la ligne d apparition ; PAS pour ceux qu on pose a un endroit
## precis (division, invocation, vitrine), qui doivent exister tout de suite.
func begin_spawn_fade() -> void:
	_spawn_fade = GameConfig.SPAWN_FADE_TIME
	modulate.a = 0.0


## Vrai pendant le fondu : immobile et intouchable.
func is_spawning() -> bool:
	return _spawn_fade > 0.0


func radius() -> float:
	if _body != null:
		return _body.radius()
	return (definition.base_radius if definition != null else 32.0) * growth


## delta deja mis a l echelle par l appelant (Battlefield).
func advance(world_delta: float) -> void:
	if _dead or definition == null:
		return
	# APPARITION : il se montre, sans bouger et sans pouvoir etre frappe. Le
	# fondu suit le temps du MONDE comme le reste de la descente, sinon a 400 %
	# il resterait une demi-seconde fantome pendant que la vague le double.
	if _spawn_fade > 0.0:
		_spawn_fade -= world_delta
		if _spawn_fade > 0.0:
			modulate.a = 1.0 - clampf(_spawn_fade / maxf(GameConfig.SPAWN_FADE_TIME, 0.001), 0.0, 1.0)
			return
		_spawn_fade = 0.0
		modulate.a = 1.0
	# IMMUNITE DE RELEVE : le repit qui rend le releve VISIBLE. Suit le temps du
	# monde comme le reste, donc il se raccourcit avec le multiplicateur.
	if _revive_grace > 0.0:
		_revive_grace = maxf(0.0, _revive_grace - world_delta)
	# CYCLE DE RENVOI. Place AVANT le retour d etourdissement, volontairement :
	# si un stun figeait le cycle, etourdir le boss pendant sa garde la
	# verrouillerait ouverte a jamais et le joueur serait puni d avoir joue la
	# bonne carte. Le cycle tourne donc toujours, et etourdir la garde reste une
	# reponse valable — on attend qu elle retombe sans encaisser de renvoi.
	_tick_reflect(world_delta)
	# ETOURDISSEMENT : il ne bouge pas, il ne tire pas, il ne frappe rien. Le
	# compteur suit le temps du MONDE comme tout le reste, donc a 500 % de vitesse
	# une seconde d etourdissement ne dure qu un cinquieme de seconde reelle —
	# c est le prix de la mecanique signature, et il vaut mieux qu il soit paye
	# ici, visiblement, que dissimule dans un temps reel qui rendrait le stun
	# demesure en fin de partie.
	if _stun_time > 0.0:
		_stun_time -= world_delta
		if _stun_time > 0.0:
			return
		_stun_time = 0.0
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

	# Boss morcele : chaque partie tombee le ralentit. Le facteur est borne a 15 %
	# de sa vitesse d origine, sinon un boss a 4 parties finirait immobile et le
	# combat deviendrait un mur de PV sans menace.
	if definition.parts_count > 0 and definition.part_slow_pct > 0.0:
		var perdues: int = definition.parts_count - _parts.size()
		speed *= maxf(1.0 - perdues * definition.part_slow_pct * 0.01, 0.15)

	# Invocation : elle suit `world_delta`, donc le flux s accelere avec le
	# multiplicateur comme le reste du monde. Sinon a x4 le boss inviterait
	# quatre fois moins de sbires par metre parcouru.
	if definition.summon_interval > 0.0 and definition.summon_def != null and battlefield != null:
		_summon_timer -= world_delta
		if _summon_timer <= 0.0:
			_summon_timer = definition.summon_interval
			_do_summon()

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

	# PROVOCATION : un arbre plante a portee remplace le mage comme objectif. Le
	# monstre marche droit dessus au lieu de descendre, et Battlefield lui fait
	# encaisser des coups quand il arrive au pied. C est tout l achat de temps que
	# paie la carte : le monstre ne recule pas, il se DETOURNE.
	#
	# Traite AVANT `_advance_along_path` et sans passer par l A*, parce qu un arbre
	# ne bloque aucune cellule : il n y a rien a contourner, seulement une cible
	# plus proche. Le retour coupe aussi l ondulation et la ligne de tir, qui sont
	# des comportements de descente et n ont plus de sens quand la descente est
	# abandonnee.
	if battlefield != null:
		var cible: TerrainProp = battlefield.taunt_target_for(position)
		if cible != null:
			_walk_to_prop(cible, speed, world_delta)
			return

	_advance_along_path(speed, world_delta)

	# CANONNIER : il s arrete a sa ligne de tir au lieu de foncer au contact.
	# Le clamp est pose APRES le deplacement plutot qu en coupant la vitesse :
	# un souffle de repulsion ou un vortex peut l avoir pousse au-dela, et il
	# doit alors pouvoir remonter jusqu a sa ligne au lieu d y rester colle.
	if definition.keeps_distance_at > 0.0:
		var ligne: float = GameConfig.MAGE_LINE_Y - definition.keeps_distance_at
		if position.y > ligne:
			position.y = maxf(ligne, position.y - speed * world_delta)

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
	# VOLANT : il passe AU-DESSUS des murs. Pas d A*, pas de contournement, pas
	# de coup porte au decor — il descend tout droit. C est tout l interet de la
	# capacite : le joueur ne peut pas la repousser avec un mur, il doit la tuer.
	if nav == null or definition.flying:
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


## Marche vers un accessoire provocateur. Une fois au pied, il s arrete : les
## degats sont portes par Battlefield, qui voit tous les monstres autour de
## l arbre et n a pas besoin qu ils se marchent dessus pour cogner.
##
## Le sprite est retourne comme pour une descente normale (`_last_x` suffit, il est
## relu plus bas dans advance() — mais advance() sort ici, alors on le fait nous).
func _walk_to_prop(cible: TerrainProp, speed: float, world_delta: float) -> void:
	var vers: Vector2 = cible.position - position
	var d: float = vers.length()
	var arret: float = cible.reach + radius() * 0.5
	if d > arret:
		var pas: float = minf(speed * world_delta, d - arret)
		position += vers / d * pas
	# Le chemin A* memorise vise le mage : il faut l oublier, sinon le monstre
	# repart en arriere des que l arbre tombe.
	_path.clear()
	_path_index = 0
	_base_x = position.x
	if _anim != null and _anim.visible and absf(position.x - _last_x) > 0.5:
		_anim.flip_h = position.x < _last_x
	_last_x = position.x


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
	# Intouchable pendant le fondu : frapper un monstre a peine visible, qui n a
	# pas encore commence a avancer, revient a frapper un fantome.
	if _spawn_fade > 0.0:
		return false
	# REPIT DE RELEVE : il vient de se relever, il est intouchable une fraction de
	# seconde. Sans ce repit, le sort qui l a tue (zone, chaine, deuxieme cible)
	# le retuait dans la meme frame et le joueur ne voyait JAMAIS la resurrection.
	if _revive_grace > 0.0:
		return false
	# Resistance TOTALE (0 %) a l un des elements du sort : rien ne passe, et
	# `false` coupe aussi l eclair et le son de coup — le joueur voit que son
	# sort n a pas mordu. La graduation entre 0 et 1 est appliquee en amont par
	# Battlefield._hit(), le point de passage unique des degats.
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

	# IMMUNISE AUX N PREMIERS COUPS. On teste ICI, apres l esquive et avant tout
	# calcul de PV : la PUISSANCE du coup n entre pas en ligne de compte, c est un
	# COMPTEUR. Un Meteore charge et une fleche de lutin coutent exactement un
	# coup chacun — c est tout le renversement de la mecanique.
	#
	# `false` est renvoye pour que le joueur ne voie ni eclair ni son de coup :
	# il doit LIRE que son sort n a pas mordu, sinon il croit son deck en panne.
	if _hits_immune_left > 0:
		_hits_immune_left -= 1
		AudioBus.play_sfx(&"shield_break")
		# Le halo tombe au DERNIER coup absorbe : le joueur voit a l ecran que le
		# compteur est vide et que le combat vrai commence. Sans ce signal il ne
		# saurait pas quand cesser de gaspiller ses petites cartes.
		if _hits_immune_left == 0:
			if _body != null:
				_body.set_shield(false)
			if _shield_fx != null and is_instance_valid(_shield_fx):
				_shield_fx.queue_free()
				_shield_fx = null
		_refresh_hp_bar()
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

	# BOSS MORCELE : tant qu une partie tient, le coeur n encaisse rien. Le coup
	# porte sur UNE SEULE partie et le surplus est perdu — un meteore ne doit pas
	# balayer les quatre parties d un coup, sinon la mecanique se resume a des PV.
	if not _parts.is_empty():
		var i: int = _parts.size() - 1
		_parts[i] = _parts[i] - amount
		if _parts[i] <= 0.0:
			_parts.remove_at(i)
			AudioBus.play_sfx(&"shield_break")
			if _body != null:
				_body.set_shield(not _parts.is_empty())
			if _parts.is_empty() and _shield_fx != null and is_instance_valid(_shield_fx):
				_shield_fx.queue_free()
				_shield_fx = null
			# Le boss se retrecit visiblement a chaque partie perdue : c est le
			# seul retour immediat que le joueur a, sa barre de PV ne bouge pas.
			_refresh_parts_visual()
		_refresh_hp_bar()
		return true

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


## Le ralentissement passe par la MEME table de resistances que les degats :
## un monstre qui y resiste a 50 % est ralenti moitie moins, au lieu d etre
## insensible ou pas du tout. L immunite binaire ne laissait que tout ou rien,
## ce qui rendait les cartes de controle inutiles contre la moitie du bestiaire.
func apply_slow(factor: float, duration: float) -> void:
	if definition == null:
		_slow_factor = clampf(factor, 0.05, 1.0)
		_slow_time = duration
		return
	var effectif: float = definition.slow_factor(clampf(factor, 0.05, 1.0))
	# Totalement resiste : aucun effet, et surtout aucun compteur pose, sinon
	# le monstre porterait un ralentissement de 0 % qui effacerait le precedent.
	if effectif >= 1.0:
		return
	_slow_factor = effectif
	_slow_time = duration


## Immobilise le monstre. Renvoie false s il y resiste, pour que le sort puisse
## compter ses vraies victimes et que rien ne pretende avoir fige un golem.
##
## La resistance lue est celle du RALENTISSEMENT, et le seuil est binaire : sous
## une resistance de 50 % le monstre ne se fige plus du tout. Un etourdissement
## gradue n a aucun sens — on ne peut pas etre immobile a moitie — et laisser
## passer le stun sur les monstres resistants au controle aurait vide cette
## resistance de son interet, puisque le stun est la version extreme du meme
## effet. C est le point que le brief du chantier soulevait : « un stun qui ignore
## cette immunite la vide de son sens ».
##
## Le monstre le plus lourd du bestiaire garde donc une seule reponse : le tuer.
const STUN_RESIST_THRESHOLD: float = 0.5


func apply_stun(duration: float) -> bool:
	if _dead or duration <= 0.0:
		return false
	if definition != null \
			and definition.resistance_to(GameEnums.DamageTag.SLOW) <= STUN_RESIST_THRESHOLD:
		return false
	# Le plus LONG gagne : deux etourdissements qui se superposent ne doivent pas
	# raccourcir le premier.
	_stun_time = maxf(_stun_time, duration)
	return true


func is_stunned() -> bool:
	return _stun_time > 0.0


func kill() -> void:
	if _dead:
		return
	# RESURRECTION. Interceptee dans kill() et non dans take_damage() parce que
	# kill() est le point de passage UNIQUE de la mort : une carte d execution, un
	# effet de terrain ou un gobage futur passeraient par la aussi, et un releve
	# qui ne fonctionnerait que contre les degats directs mentirait au joueur sur
	# la regle. `absorb()` est le seul retrait qui l ignore, et c est voulu : etre
	# gobe n est pas mourir.
	if _try_revive():
		return
	_dead = true
	# Un boss mort ne tient plus sa garde : le halo ambre doit partir avec lui,
	# sinon il reste a l ecran accroche a un monstre qui n existe plus.
	#
	# C est aussi ce qui rend LOAD-BEARING l ordre choisi dans
	# Battlefield._hit() : la part renvoyee y est relevee AVANT d appliquer les
	# degats, parce que le coup peut tuer. La lire apres rendrait gratuit le fait
	# de tuer le boss pendant sa garde, ce qui est exactement le contraire de la
	# mecanique — elle doit faire payer le lancement mal choisi, surtout celui-la.
	_close_reflect()
	died.emit(self)


## Tente le releve unique. Renvoie true s il s est releve : l appelant ne doit
## alors PAS le considerer comme mort (ni XP, ni division, ni retrait du terrain).
func _try_revive() -> bool:
	if definition == null or definition.revive_hp_pct <= 0.0 or _revived:
		return false
	_revived = true
	hp = maxf(_max_hp * definition.revive_hp_pct * 0.01, 1.0)
	# Un boss qui se releve repart a decouvert : ses parties, son bouclier et son
	# compteur de coups ont ete payes une fois, les rendre serait deux combats.
	# Ce qu il RECUPERE est sa garde de renvoi, qui est un cycle et non une reserve.
	_revive_grace = REVIVE_GRACE
	_refresh_hp_bar()
	# LE JOUEUR DOIT LE VOIR. La barre reapparait (elle etait a zero), le monstre
	# pulse en blanc, un souffle part de lui et le son monte : quatre canaux,
	# parce que le releve arrive exactement au moment ou le joueur regarde
	# AILLEURS — il vient de croire le combat gagne.
	if Fx.enabled():
		Fx.impact(self, position, Color(1.0, 0.95, 0.65), visual_radius() * 1.8)
	AudioBus.play_sfx(&"spell_rise")
	modulate = Color(1.6, 1.5, 1.1)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, REVIVE_GRACE)
	if _anim != null and _anim.visible and AnimCatalog.has_anim(definition.anim_key, "hurt"):
		_anim.play("hurt")
		if not _anim.animation_finished.is_connected(_back_to_walk):
			_anim.animation_finished.connect(_back_to_walk)
	return true


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


# --- Boss a MECANIQUE : releve, compteur de coups, garde de renvoi -----------

## Coups que le boss peut encore ignorer (0 pour un monstre ordinaire).
func hits_immune_left() -> int:
	return _hits_immune_left


## Vrai apres son unique resurrection. Sert a l affichage comme au test.
func has_revived() -> bool:
	return _revived


## Garde de renvoi levee ? Le HUD et les FX s y raccrochent, et c est la question
## que le joueur se pose avant de lancer.
func is_reflecting() -> bool:
	return _reflect_left > 0.0


## Ouvre la garde tout de suite, pour la duree demandee. Sert aux TESTS, qui
## doivent verrouiller la REGLE du renvoi sans figer sa cadence — un test qui
## attendrait le cycle figerait un reglage d equilibrage (voir gotchas.md).
func force_reflect_window(duration: float) -> void:
	if definition == null or definition.reflect_pct <= 0.0:
		return
	_open_reflect(duration)


## Cadence de la garde : elle se leve, elle retombe, et le joueur apprend le
## rythme. Un renvoi permanent serait une interdiction de jouer, pas un choix.
func _tick_reflect(world_delta: float) -> void:
	if definition == null or definition.reflect_pct <= 0.0 \
			or definition.reflect_interval <= 0.0 or definition.reflect_window <= 0.0:
		return
	if _reflect_left > 0.0:
		_reflect_left -= world_delta
		if _reflect_left <= 0.0:
			_close_reflect()
		return
	_reflect_timer -= world_delta
	if _reflect_timer <= 0.0:
		_reflect_timer = definition.reflect_interval
		_open_reflect(definition.reflect_window)


func _open_reflect(duration: float) -> void:
	_reflect_left = maxf(duration, 0.05)
	# LE JOUEUR DOIT LE VOIR : sans retour visuel, le renvoi n est qu une punition
	# arbitraire et la mecanique n existe pas pour lui. Halo ambre (la teinte du
	# renvoi, distincte du bleu du bouclier) + pose de garde quand la feuille en a
	# une + son de ward : trois canaux, parce qu un seul se rate.
	# FACTEUR 2,0 ET PAS 1,25, et z_index force DEVANT. Mesure sur capture
	# (.testout/boss_07_miroir_garde_levee, premier jet) : le halo EXISTAIT dans
	# l arbre — la sonde le listait — mais il etait invisible, parce que le sprite
	# du monstre est mis a l echelle du rayon VISUEL et le recouvrait entierement.
	# Une garde qu on ne voit pas ne punit pas le joueur, elle le trahit : il perd
	# des PV en lancant une carte, sans aucune cause lisible a l ecran.
	if Fx.enabled() and _reflect_fx == null:
		# UNE AUTRE FEUILLE, pas seulement une autre teinte. Verifie sur capture :
		# la feuille `shield_hex` (celle de Fx.halo) porte sa propre couleur verte
		# et l ecrase le modulate — a 0,95 comme a 2,2 de saturation, la garde de
		# renvoi restait visuellement identique aux sceaux du Reliquaire. Or les
		# deux demandent au joueur des reactions OPPOSEES : continuer a frapper
		# pour user les sceaux, s ARRETER de frapper devant la garde. Deux regles
		# contraires derriere le meme halo, c est un piege, pas un signal.
		#
		# `hex_sigil` est un sigle tournant, de forme nettement differente, et il
		# remplit toute sa case (occupancy 1,00) donc il se lit a pleine taille.
		_reflect_fx = Fx.sprite(self, "hex_sigil", Vector2.ZERO,
			visual_radius() * 2.2, true, Color(1.0, 0.72, 0.25, 0.95))
		if _reflect_fx is CanvasItem:
			(_reflect_fx as CanvasItem).z_index = 5
	if _anim != null and _anim.visible and definition != null \
			and AnimCatalog.has_anim(definition.anim_key, "guard"):
		_anim.play("guard")
	AudioBus.play_sfx(&"ward_deep")


func _close_reflect() -> void:
	_reflect_left = 0.0
	if _reflect_fx != null and is_instance_valid(_reflect_fx):
		_reflect_fx.queue_free()
	_reflect_fx = null
	if _anim != null and _anim.visible and not _dead and _anim.animation != "walk":
		_anim.play("walk")


## Part des degats renvoyee au mage a cet instant. 0 hors fenetre. Lue par
## Battlefield._hit(), qui est le SEUL point de passage des degats : le renvoi
## doit donc etre resolu la et nulle part ailleurs, sinon une source de degats
## qui l oublierait offrirait au joueur un contournement gratuit.
func reflect_share() -> float:
	if _reflect_left <= 0.0 or definition == null:
		return 0.0
	return clampf(definition.reflect_pct * 0.01, 0.0, 1.0)


func enrage_bonus() -> float:
	return _enrage_bonus


## Nombre de parties encore debout (0 pour un monstre ordinaire).
func parts_left() -> int:
	return _parts.size()


## Le boss maigrit a mesure qu il perd ses parties. On ne descend pas sous 55 %
## de sa taille : plus petit, il ne se lirait plus comme un boss a l ecran.
func _refresh_parts_visual() -> void:
	if definition == null or definition.parts_count <= 0:
		return
	var reste: float = float(_parts.size()) / float(definition.parts_count)
	var facteur: float = lerpf(0.55, 1.0, reste)
	if _anim != null and _anim.visible:
		_apply_scale(_anim, float(AnimCatalog.frame_px(definition.anim_key)))
		_anim.scale *= facteur
	if _aura_fx != null and is_instance_valid(_aura_fx):
		_aura_fx.scale = Vector2.ONE * facteur


## Invocation. Les sbires naissent SUR LES COTES du boss, pas dessus : nes au
## centre ils seraient caches par sa silhouette et le joueur ne comprendrait pas
## d ou ils sortent.
func _do_summon() -> void:
	_summoned = _summoned.filter(func(s: Enemy) -> bool:
		return s != null and is_instance_valid(s) and not s.is_dead())
	var place: int = definition.summon_max_alive - _summoned.size()
	if place <= 0:
		return
	var combien: int = mini(definition.summon_count, place)
	play_attack()
	for i in combien:
		var ecart: float = (i - (combien - 1) * 0.5) * (radius() + 60.0)
		var ou := Vector2(
			clampf(position.x + ecart, 40.0, GameConfig.BATTLEFIELD_WIDTH - 40.0),
			position.y + radius() * 0.4)
		var sbire: Enemy = battlefield.spawn_enemy(definition.summon_def, ou.x, difficulty, ou)
		if sbire != null:
			_summoned.append(sbire)
	# Pas de son d invocation dedie dans assets/sfx : "grow" est le plus proche
	# (quelque chose qui sort et s etend) parmi les cles existantes.
	AudioBus.play_sfx(&"grow")


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
	# Boss morcele : tant que des parties tiennent, la barre montre LEUR etat.
	# Afficher les PV du coeur (toujours pleins) donnerait au joueur l impression
	# que ses sorts ne servent a rien pendant toute la premiere moitie du combat.
	if not _parts.is_empty() and definition != null and definition.parts_count > 0:
		var total: float = definition.part_hp * difficulty * float(definition.parts_count)
		var reste: float = 0.0
		for p in _parts:
			reste += maxf(p, 0.0)
		_hp_bar.visible = true
		_hp_bar.value = clampf(reste / maxf(total, 0.001), 0.0, 1.0) * 100.0
		# Teinte distincte : le joueur doit lire « armure » et non « PV ».
		_hp_bar.tint_progress = Color(0.70, 0.80, 1.0)
		return
	# SCEAUX RESTANTS. Tant qu ils tiennent, les PV du boss ne bougent pas : une
	# barre pleine et immobile pendant six sorts ferait croire au joueur que ses
	# cartes ne portent pas. La barre montre donc le COMPTEUR, et elle se vide
	# coup par coup — un retour immediat a chaque sort lance.
	if _hits_immune_left > 0 and definition != null and definition.hits_immune > 0:
		_hp_bar.visible = true
		_hp_bar.value = float(_hits_immune_left) / float(definition.hits_immune) * 100.0
		# Meme teinte bleue que l armure du boss morcele : c est le meme message,
		# « ce que tu vides n est pas encore sa vie ».
		_hp_bar.tint_progress = Color(0.70, 0.80, 1.0)
		return
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
	# L etourdissement est un effet SUBI, donc il part avec la dissipation. C est
	# une perte pour le joueur, et c est coherent : Lumiere purifiante « efface les
	# effets en cours », les siens compris — la carte ne peut pas etre gratuite.
	_stun_time = 0.0
	if _shield_up:
		_shield_up = false
		if _body != null:
			_body.set_shield(false)
		if _shield_fx != null and is_instance_valid(_shield_fx):
			_shield_fx.queue_free()
			_shield_fx = null
