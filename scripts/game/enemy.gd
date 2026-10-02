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
## Temps de MONDE restant avant qu un coup puisse de nouveau enrager (voir
## ENRAGE_HIT_INTERVAL).
var _enrage_lock: float = 0.0

## UN COUP QUI ENRAGE, AU PLUS, PAR INTERVALLE (secondes de monde).
##
## "Accelere a chaque coup recu" etait compte a chaque APPEL de take_damage. Une
## zone de degats (Nappe de braise, Champ de givre...) inflige ses degats a
## CHAQUE FRAME : un Berserker qui la traversait recevait un "coup" toutes les
## 1/60 s et atteignait sa rage maximale (x2,5 de vitesse) en un cinquieme de
## seconde. Une regle qui dependait de la frequence d images, et qui faisait du
## Berserker la premiere source de degats de l Arene de Kaltek (lvl_11), dont
## le deck est fait de zones de givre. Mesure (90 parties, bot du banc) : lvl_11
## 44 -> 73 victoires, lvl_16 64 -> 71 ; lvl_13 inchange (60).
## Une demi-seconde : deux sorts lances a la suite comptent tous deux (une
## incantation dure plus longtemps), une zone compte comme deux coups par seconde.
const ENRAGE_HIT_INTERVAL: float = 0.5
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
## ONDE DE CHOC : compte a rebours jusqu au prochain coup de sol.
var _shockwave_timer: float = 0.0
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
	_sheet_resolved = false
	difficulty = diff
	hp = def.max_hp * diff
	_max_hp = maxf(hp, 0.001)
	_shield_up = def.first_hit_shield
	# Premier tir un peu plus tot que l intervalle : le joueur voit vite la menace.
	_shoot_timer = def.shoot_interval * 0.6
	# Premiere invocation a l intervalle PLEIN : le joueur a le temps de voir le
	# boss entrer avant que l ecran se remplisse.
	_summon_timer = def.summon_interval
	# Premiere onde a l intervalle PLEIN, comme l invocation : le joueur doit voir
	# le boss se planter et lever ses bras avant que le sol tremble. Un premier
	# coup anticipe le frapperait avant qu il ait compris d ou il vient.
	_shockwave_timer = def.shockwave_interval
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
	_v3_setup(def)
	_setup_v3(def)
	_brk_setup(def)


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
	_setup_visual_v3()


## L animation de REPOS d une feuille : ce que le monstre joue quand il ne fait
## rien de particulier.
##
## LE DEFAUT QUE CECI REPARE, attrape par l etage `visual` et par lui seul :
## le code jouait `"walk"` en dur a trois endroits (mise en place, retour de coup
## recu, retour d attaque). Godot le refusait a voix haute — « There is no
## animation with name 'walk' » — pour toute feuille sans marche, et le monstre
## restait fige sur une image.
##
## Or une feuille SANS marche n est pas une feuille incomplete : le Bourreau
## n avance pas, c est sa mecanique, et sa planche porte idle / attack / death /
## summon parce qu il n a aucune raison de marcher. Le Gardien-totem flottant est
## dans le meme cas. Le repli n est donc pas un rattrapage d erreur, c est la
## regle correcte : un monstre qui ne marche pas RESPIRE sur place.
##
## On prefere `walk` quand elle existe (c est l etat permanent d un monstre qui
## descend), `idle` sinon. Statique en plus d etre publique : les tests doivent
## pouvoir verifier le choix sans instancier une scene.
static func resting_anim(key: StringName) -> String:
	if AnimCatalog.has_anim(key, "walk"):
		return "walk"
	if AnimCatalog.has_anim(key, "idle"):
		return "idle"
	return ""


## LE REFLET DU MAGE. Un monstre dessine avec la feuille du mage lui-meme
## (`UiTheme.MAGE_DEFAULT`, aujourd hui le Miroir de Forge) n a pas une
## apparence a lui : il est le reflet du joueur. Quand le joueur a choisi une
## apprentie, le reflet doit etre cette apprentie — sinon le miroir montre un
## personnage que le joueur ne joue pas, et le monstre perd son sens.
##
## Seule la feuille monk_blue compte : monk_black et monk_purple sont aussi des
## robes du mage, mais le contenu les donne a d autres monstres (le Sonneur de
## cor, le Pretre) qui ne sont pas des reflets.
static func is_mage_reflection(def: EnemyDef) -> bool:
	return def != null and String(def.anim_key) == UiTheme.MAGE_DEFAULT


## La feuille REELLEMENT affichee pour ce monstre. C est `anim_key`, sauf pour
## un reflet du mage, qui prend le personnage joue (apprentie, ou mage dans la
## robe equipee). Statique pour que les tests la verifient sans scene.
static func shown_sheet(def: EnemyDef) -> StringName:
	if def == null:
		return &""
	if not is_mage_reflection(def):
		return def.anim_key
	var heros: String = UiTheme.hero_key()
	if heros != AccountRewardDef.CHARACTER_MAGE:
		return StringName(heros)
	# Le mage lui-meme : sa robe (UiTheme.mage_sheet_key, toujours une cle du
	# catalogue depuis la vague 8), puis la feuille d origine. Le CHAPEAU est un
	# calque de MageView : le reflet ne le porte pas, il copie la silhouette.
	for k: String in [UiTheme.mage_sheet_key(),
			SaveData.equipped_cosmetic(GameEnums.RewardKind.MAGE_COLOR)]:
		if k != "" and AnimCatalog.has(StringName(k)):
			return StringName(k)
	return def.anim_key


## Resolue UNE fois par monstre : un reflet qui changerait de feuille en cours de
## vie (profil modifie pendant la partie) melangerait les echelles de deux feuilles.
var _sheet: StringName = &""
var _sheet_resolved: bool = false


func sheet_key() -> StringName:
	if not _sheet_resolved and definition != null:
		_sheet = shown_sheet(definition)
		_sheet_resolved = true
	return _sheet


## Feuille animee du pack si le monstre en a une ; sinon la forme de secours.
func _setup_visual() -> void:
	var key: StringName = sheet_key()
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
		var repos: String = resting_anim(key)
		if repos != "":
			_anim.play(repos)
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
	var key: StringName = sheet_key()
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


## Vrai pendant le fondu : immobile et intouchable. Un jumeau A TERRE est dans le
## meme etat pour tout le reste du jeu (ni cible, ni regard, ni decor) : c est ce
## que Battlefield demande a cette fonction, et le dire ici evite d ouvrir un
## second chemin que chaque systeme devrait apprendre a tester.
func is_spawning() -> bool:
	return _spawn_fade > 0.0 or _twin_fallen


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
	# Le verrou de rage suit le temps du MONDE, meme etourdi ou endormi : un coup
	# recu pendant un sommeil doit pouvoir enrager au reveil.
	if _enrage_lock > 0.0:
		_enrage_lock = maxf(0.0, _enrage_lock - world_delta)
	# CYCLE DE RENVOI. Place AVANT le retour d etourdissement, volontairement :
	# si un stun figeait le cycle, etourdir le boss pendant sa garde la
	# verrouillerait ouverte a jamais et le joueur serait puni d avoir joue la
	# bonne carte. Le cycle tourne donc toujours, et etourdir la garde reste une
	# reponse valable — on attend qu elle retombe sans encaisser de renvoi.
	_tick_reflect(world_delta)
	# Mecaniques v3 qui tournent MEME etourdi (horloge, cameleon, jumeau a terre).
	if _tick_v3_always(world_delta):
		return
	# Sommeil (comportements v3) : il dort, il n avance pas.
	if _v3_tick_sleep(world_delta):
		return
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
	# Mecaniques v3 qu un etourdissement suspend (vol de carte, rappel des sbires).
	_tick_v3_active(world_delta)
	# BRISEUR DE TERRAIN : plante pendant son geste, il n avance pas.
	if _brk_tick(world_delta):
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
	speed *= mirror_factor()

	# Boss morcele : chaque partie tombee le ralentit. Le facteur est borne a 15 %
	# de sa vitesse d origine, sinon un boss a 4 parties finirait immobile et le
	# combat deviendrait un mur de PV sans menace.
	if definition.parts_count > 0 and definition.part_slow_pct > 0.0:
		var perdues: int = definition.parts_count - _parts.size()
		speed *= maxf(1.0 - perdues * definition.part_slow_pct * 0.01, 0.15)
	speed *= _v3_speed_factor()

	# Invocation : elle suit `world_delta`, donc le flux s accelere avec le
	# multiplicateur comme le reste du monde. Sinon a x4 le boss inviterait
	# quatre fois moins de sbires par metre parcouru.
	if definition.summon_interval > 0.0 and definition.summon_def != null and battlefield != null:
		_summon_timer -= world_delta
		if _summon_timer <= 0.0:
			_summon_timer = definition.summon_interval
			_do_summon()
	_v3_tick_reanimate(world_delta)

	# ONDE DE CHOC : il frappe le sol. Elle suit `world_delta` comme l invocation,
	# donc la cadence s accelere avec le multiplicateur — a x4 le sol tremble
	# quatre fois plus souvent, ce qui est le prix de la mecanique signature et
	# doit rester visible plutot que dissimule dans un temps reel.
	#
	# Elle part meme si le boss est immobile : c est TOUT le principe. Elle ne part
	# pas s il est cache (Ombre en phase) ni etourdi — le retour d etourdissement
	# plus haut a deja coupe la fonction, donc il n y a rien a ajouter ici.
	if definition.shockwave_interval > 0.0 and definition.shockwave_radius > 0.0 			and battlefield != null and not _hidden:
		_shockwave_timer -= world_delta
		if _shockwave_timer <= 0.0:
			_shockwave_timer = definition.shockwave_interval
			battlefield.enemy_shockwave(self, definition.shockwave_radius,
				definition.shockwave_damage)

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

	# Volte-face : le monstre remonte vers le haut, moins vite s il resiste a
	# l element de la carte (vague 5). Totalement resistant, il n est pas
	# retourne du tout et poursuit sa descente normale.
	if battlefield != null and battlefield.is_reversed():
		var recul: float = battlefield.reverse_factor_for(self)
		if recul > 0.0:
			position.y = maxf(position.y - speed * recul * world_delta, GameConfig.SPAWN_LINE_Y)
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
		var cible: TerrainProp = battlefield.taunt_target_for(position, self)
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
	_v3_apply_move_pattern(speed, world_delta)

	# Tir sur le mage.
	if definition.shoot_interval > 0.0 and battlefield != null and not _hidden:
		_shoot_timer -= world_delta
		if _shoot_timer <= 0.0:
			_shoot_timer = definition.shoot_interval
			play_shot_pose(false)
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
	if _twin_fallen:
		return false
	# Resistance TOTALE (0 %) a l ELEMENT du sort : rien ne passe, et `false`
	# coupe aussi l eclair et le son de coup — le joueur voit que son sort n a
	# pas mordu. La graduation entre 0 et 1 est appliquee en amont par
	# Battlefield._hit(), le point de passage unique des degats.
	#
	# Seuls les ELEMENTS comptent ici, jamais SLOW ni SUMMON. L ancienne boucle
	# refusait le coup des que le monstre etait immunise a N IMPORTE QUEL tag :
	# un Champ de givre [givre, ralentissement] faisait 0 degat a Chronos, au
	# golem et au Behemoth, tous immunises au RALENTISSEMENT — alors que le deck
	# du niveau 1 porte deux Champs de givre et que son boss est Chronos. Une
	# immunite au ralentissement annule le ralentissement (apply_slow), pas les
	# degats de givre. Verrouille par test_elements.
	if _immune_to_elements(tags):
		return false
	# L Ombre en phase encaisse MOINS, mais reste touchable. Une invulnerabilite
	# totale sur un cycle de 2,5 s, plus long que la plupart des incantations,
	# rendait le monstre impossible a gerer : le joueur lancait dans le vide sans
	# aucun moyen de savoir quand.
	if _hidden:
		amount *= PHASE_DAMAGE_FACTOR
	if definition.dodge_chance > 0.0 and randf() < definition.dodge_chance:
		return false
	amount *= _chameleon_factor(tags)

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
	if definition.enrage_speed_pct > 0.0 and _enrage_lock <= 0.0:
		_enrage_bonus = minf(_enrage_bonus + definition.enrage_speed_pct * 0.01, definition.enrage_cap)
		_enrage_lock = ENRAGE_HIT_INTERVAL
	if hp <= 0.0:
		kill()
	elif _anim != null and _anim.visible and AnimCatalog.has_anim(sheet_key(), "hurt"):
		_anim.play("hurt")
		if not _anim.animation_finished.is_connected(_back_to_walk):
			_anim.animation_finished.connect(_back_to_walk)
	return true


## Retour a l etat permanent apres un coup recu ou une attaque. Le nom garde le
## mot « walk » parce que c est le cas general et que tous les appelants le
## nomment ainsi ; ce qu il joue, en revanche, est l animation de repos REELLE de
## la feuille — voir `resting_anim()`.
func _back_to_walk() -> void:
	if _anim == null or _dead or definition == null:
		return
	# Un dormeur frappe se RENDORT a l ecran : sans cette ligne, le coup recu le
	# remettait en marche visuelle alors qu il dort toujours pour les regles.
	var repos: String = _rest_pose()
	if repos != "" and _anim.animation != StringName(repos):
		_anim.play(repos)
	# Feuille SANS pose de sommeil : on refige, comme a l endormissement.
	if is_sleeping() and repos != "sleep":
		_anim.pause()


## Animation d attaque (tir de l archer, coup du berserker).
func play_attack() -> void:
	if _anim != null and _anim.visible and AnimCatalog.has_anim(sheet_key(), "attack"):
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
		_apply_scale(_anim, float(AnimCatalog.frame_px(sheet_key())))
	_place_hp_bar()
	AudioBus.play_sfx(&"grow")
	_refresh_hp_bar()


## Le ralentissement passe par la MEME table de resistances que les degats :
## un monstre qui y resiste a 50 % est ralenti moitie moins, au lieu d etre
## insensible ou pas du tout. L immunite binaire ne laissait que tout ou rien,
## ce qui rendait les cartes de controle inutiles contre la moitie du bestiaire.
##
## `tags` : l element du sort qui ralentit (vague 5, voir control_factor). Vide
## pour un ralentissement sans element (passif Morsure de givre) : seule la
## ligne SLOW compte alors, comme avant.
func apply_slow(factor: float, duration: float, tags: Array = []) -> void:
	if definition == null:
		_slow_factor = clampf(factor, 0.05, 1.0)
		_slow_time = duration
		return
	var effectif: float = clampf(
		1.0 - (1.0 - clampf(factor, 0.05, 1.0)) * control_factor(tags, true), 0.05, 1.0)
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


##
## VAGUE 5 : l ELEMENT du sort compte aussi (`tags`, voir control_factor). Un
## monstre qui resiste fort a la foudre echappe a la Racine de tonnerre comme un
## golem echappe au givre ; au-dessus du seuil, la DUREE est raccourcie d autant
## — on ne peut pas etre immobile a moitie, mais on peut l etre moins longtemps.
func apply_stun(duration: float, tags: Array = []) -> bool:
	if _dead or duration <= 0.0:
		return false
	var f: float = control_factor(tags, true)
	if definition != null and f <= STUN_RESIST_THRESHOLD:
		return false
	# Le plus LONG gagne : deux etourdissements qui se superposent ne doivent pas
	# raccourcir le premier.
	_stun_time = maxf(_stun_time, duration * f)
	# Etourdi pendant son geste, le Briseur le PERD : c est la reponse de controle.
	_brk_cancel(true)
	return true


func is_stunned() -> bool:
	return _stun_time > 0.0


## RESISTANCE AUX EFFETS (vague 5) — facteur 0..1 applique a tout effet NON
## DEGAT d un sort : ralentir, etourdir, repousser, aspirer, attirer, renverser
## la marche, rendre vulnerable, dissiper. La regle est dans
## EnemyDef.control_factor ; ici s y ajoute la table TOURNANTE du Cameleon, pour
## que son element resiste du moment freine aussi les effets et pas seulement
## les degats — sinon sa teinte mentirait une fois sur deux.
func control_factor(tags: Array, slows: bool = false) -> float:
	if definition == null:
		return 1.0
	var f: float = minf(definition.resistance_to_tags(tags) * _chameleon_factor(tags), 1.0)
	if slows:
		f = minf(f, definition.resistance_to(GameEnums.DamageTag.SLOW))
	return clampf(f, 0.0, 1.0)


## Immunise a l ELEMENT du sort (tags non elementaires ignores). Meme lecture que
## les degats : le pire element du sort pour le joueur decide.
func _immune_to_elements(tags: Array) -> bool:
	for t in tags:
		if t in GameEnums.ELEMENTS:
			return definition.resistance_to_tags(tags) <= 0.0
	return false


func kill() -> void:
	if _dead:
		return
	# Tue pendant son geste, le Briseur ne brise rien — meme s il se releve.
	_brk_cancel(false)
	# RESURRECTION. Interceptee dans kill() et non dans take_damage() parce que
	# kill() est le point de passage UNIQUE de la mort : une carte d execution, un
	# effet de terrain ou un gobage futur passeraient par la aussi, et un releve
	# qui ne fonctionnerait que contre les degats directs mentirait au joueur sur
	# la regle. `absorb()` est le seul retrait qui l ignore, et c est voulu : etre
	# gobe n est pas mourir.
	if _try_revive():
		return
	# Une vie supplementaire se consomme AVANT la chute d un jumeau : perdre une
	# vie n est pas tomber, le jumeau n a pas a le savoir.
	if _v3_try_extra_life():
		return
	if _try_twin_fall():
		return
	_dead = true
	_on_final_death_v3()
	# Un boss mort ne tient plus sa garde : le halo ambre doit partir avec lui,
	# sinon il reste a l ecran accroche a un monstre qui n existe plus.
	#
	# C est aussi ce qui rend LOAD-BEARING l ordre choisi dans
	# Battlefield._hit() : la part renvoyee y est relevee AVANT d appliquer les
	# degats, parce que le coup peut tuer. La lire apres rendrait gratuit le fait
	# de tuer le boss pendant sa garde, ce qui est exactement le contraire de la
	# mecanique — elle doit faire payer le lancement mal choisi, surtout celui-la.
	_close_reflect()
	# OBJECTIFS (boss_quick_after_revive) : un monstre releve meurt pour de bon.
	if _revived: RunState.note_revived_enemy_killed(get_instance_id())
	died.emit(self)


## Tente le releve unique. Renvoie true s il s est releve : l appelant ne doit
## alors PAS le considerer comme mort (ni XP, ni division, ni retrait du terrain).
func _try_revive() -> bool:
	if definition == null or definition.revive_hp_pct <= 0.0 or _revived:
		return false
	_revived = true
	# OBJECTIFS (boss_quick_after_revive) : l instant du releve.
	RunState.note_enemy_revived(get_instance_id())
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
	if _anim != null and _anim.visible and AnimCatalog.has_anim(sheet_key(), "hurt"):
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
			and AnimCatalog.has_anim(sheet_key(), "guard"):
		_anim.play("guard")
	AudioBus.play_sfx(&"ward_deep")


func _close_reflect() -> void:
	_reflect_left = 0.0
	if _reflect_fx != null and is_instance_valid(_reflect_fx):
		_reflect_fx.queue_free()
	_reflect_fx = null
	# Meme regle qu au retour de coup : on rejoue le repos REEL de la feuille, pas
	# un « walk » suppose. Le Miroir de Forge a une marche, mais rien ne garantit
	# que le prochain monstre a renvoi en aura une.
	_back_to_walk()


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
		_apply_scale(_anim, float(AnimCatalog.frame_px(sheet_key())))
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
	_enrage_lock = 0.0
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


# =====================================================================
# COMPORTEMENTS v3 — plusieurs vies, sommeil qui coupe la magie, reanimateur,
# laser de riposte, motifs de deplacement. Tout est pilote par le groupe
# "Comportements v3" d EnemyDef ; chaque fonction est appelee par UNE ligne
# depuis un point d accroche existant (setup, advance, kill), pour que ce bloc
# se lise d un seul tenant et se fusionne sans toucher au reste.
#
# Ce qui implique D AUTRES monstres ou le mage (renaissance differee, memoire des
# morts, verrou de magie global, rayon) vit dans Battlefield, comme le veut la
# regle du fichier : l Enemy decide QUAND, le terrain sait QUOI et SUR QUI.

## Plancher du delai entre deux lasers, quel que soit le contenu. Un poison
## frappe a chaque image : sans plancher, un `laser_cooldown` oublie a 0 dans un
## .tres transformerait une Mare de venin en peloton d execution.
const LASER_MIN_COOLDOWN: float = 0.5
## Plafond d UN sommeil, quel que soit le contenu. La fenetre de magie garantie
## entre deux sommeils vit dans Battlefield (elle porte sur TOUS les dormeurs) ;
## celui-ci borne la duree d un seul, pour qu un .tres a 30 s ne coupe pas la
## magie une demi-minute.
const SLEEP_MAX_DURATION: float = 4.0
## Duree d un saut de colonne (motif HOP). Assez bref pour se lire comme un
## bond, assez long pour que l oeil suive le monstre d une colonne a l autre.
const HOP_TIME: float = 0.22
## Intervalle minimal entre deux reanimations, pour la meme raison que le
## plancher du laser : un intervalle a 0 viderait le plafond en une image.
const REANIMATE_MIN_INTERVAL: float = 0.5

var _v3_lives_used: int = 0
var _v3_sleep_timer: float = 0.0
var _v3_sleep_left: float = 0.0
var _v3_zzz: Node = null
var _v3_laser_cd: float = 0.0
var _v3_reanimate_timer: float = 0.0
var _v3_reanimated_count: int = 0
## Vrai pour un monstre RELEVE par un reanimateur : sa deuxieme mort ne paie ni
## XP ni compteur, la creature a deja ete comptee la premiere fois.
var _v3_is_reanimated: bool = false
## Generation de renaissance : 0 pour un monstre de vague, 1 pour un monstre ne
## d une marque, etc. Borne par Battlefield.REBIRTH_MAX_DEPTH.
var _v3_rebirth_depth: int = 0
## Motifs : sens lateral (+1 / -1, 0 = pas encore choisi), distance parcourue
## depuis le dernier demi-tour (ZIGZAG), minuterie et cible du saut (HOP).
var _v3_dir: int = 0
var _v3_travel: float = 0.0
var _v3_hop_timer: float = 0.0
var _v3_hopping: bool = false
var _v3_hop_target: float = 0.0


func _v3_setup(def: EnemyDef) -> void:
	_v3_lives_used = 0
	# Premier sommeil a l intervalle PLEIN, comme l invocation et l onde : le
	# joueur doit voir le dormeur entrer et avoir une chance de le tuer avant qu il
	# ne lui coupe la magie une premiere fois.
	_v3_sleep_timer = def.sleep_interval
	_v3_sleep_left = 0.0
	_v3_laser_cd = 0.0
	_v3_reanimate_timer = def.reanimate_interval
	_v3_reanimated_count = 0
	_v3_dir = 0
	_v3_travel = 0.0
	_v3_hop_timer = def.pattern_interval
	_v3_hopping = false


# --- 1. PLUSIEURS VIES ------------------------------------------------------

## Vies restantes (0 pour un monstre ordinaire).
func lives_left() -> int:
	if definition == null:
		return 0
	return maxi(0, definition.extra_lives - _v3_lives_used)


## Appele depuis kill(), APRES le releve sur place : un boss qui porte les deux
## se releve d abord la ou il est tombe, puis repart du haut a sa mort suivante.
## Renvoie true s il revient : l appelant ne doit alors PAS le traiter comme
## mort (ni XP, ni division, ni renaissance, ni retrait du terrain).
func _v3_try_extra_life() -> bool:
	if definition == null or _v3_lives_used >= definition.extra_lives:
		return false
	_v3_lives_used += 1
	hp = maxf(_max_hp * definition.extra_life_hp_pct * 0.01, 1.0)
	# La mort se VOIT la ou il tombe : sans l explosion, le joueur verrait le
	# monstre se teleporter et croirait a un bug d affichage.
	if Fx.enabled() and battlefield != null:
		Fx.death(battlefield, position, radius())
	# DEPUIS LE HAUT, dans la meme colonne : le joueur le retrouve la ou il
	# regarde deja, et le chemin a refaire est la recompense de l avoir tue.
	position = Vector2(position.x, GameConfig.SPAWN_LINE_Y)
	repath()
	_last_x = position.x
	# Une nouvelle vie efface ce qu il subissait : il n emporte pas un
	# etourdissement ou un ralentissement de sa vie precedente.
	_stun_time = 0.0
	_slow_time = 0.0
	_slow_factor = 1.0
	_v3_wake()
	# Le meme repit que le releve sur place, et pour la meme raison : le sort qui
	# vient de le tuer (zone, chaine) le retuerait dans la meme image.
	_revive_grace = REVIVE_GRACE
	_refresh_hp_bar()
	# Il ROUGIT a chaque vie perdue : c est la seule facon de lire, sans chiffre,
	# qu il revient plus vite et qu il faut le traiter avant la prochaine fois.
	var teinte: Color = _v3_life_tint()
	modulate = Color(1.6, 1.5, 1.1, modulate.a)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", teinte, REVIVE_GRACE)
	if Fx.enabled() and battlefield != null:
		Fx.impact(battlefield, position, Color(1.0, 0.45, 0.35), visual_radius() * 1.4)
	AudioBus.play_sfx(&"spell_rise")
	return true


func _v3_life_tint() -> Color:
	var k: float = clampf(0.16 * float(_v3_lives_used), 0.0, 0.6)
	return Color(1.0, 1.0 - k, 1.0 - k, 1.0)


## Facteur de vitesse du a la mecanique v3 : +x % par vie perdue.
func _v3_speed_factor() -> float:
	if definition == null or _v3_lives_used <= 0:
		return 1.0
	return 1.0 + float(_v3_lives_used) * maxf(definition.extra_life_speed_pct, 0.0) * 0.01


# --- 5. SOMMEIL QUI COUPE LA MAGIE ------------------------------------------

func is_sleeping() -> bool:
	return _v3_sleep_left > 0.0 and not _dead


## Avance les minuteries v3 qui doivent tourner meme etourdi (delai du laser),
## puis le sommeil. Renvoie true tant qu il dort : il ne bouge pas, ne tire pas,
## n invoque pas — il dort, et c est justement le moment de le tuer.
##
## Place AVANT le retour d etourdissement : si un stun figeait le sommeil, etourdir
## le dormeur PROLONGERAIT le silence du joueur, qui serait puni d avoir joue la
## bonne carte.
func _v3_tick_sleep(world_delta: float) -> bool:
	if _v3_laser_cd > 0.0:
		_v3_laser_cd = maxf(0.0, _v3_laser_cd - world_delta)
	if definition == null or definition.sleep_interval <= 0.0:
		return false
	if _v3_sleep_left > 0.0:
		_v3_sleep_left -= world_delta
		if _v3_sleep_left > 0.0:
			return true
		_v3_wake()
		return false
	_v3_sleep_timer -= world_delta
	# Le terrain peut REFUSER : un autre dormeur coupe deja la magie, ou la
	# fenetre garantie depuis le dernier sommeil n est pas ecoulee. La minuterie
	# reste alors a zero et il redemande a l image suivante — il s endormira des
	# que le joueur aura eu sa fenetre, pas avant.
	if _v3_sleep_timer <= 0.0 and _stun_time <= 0.0 and battlefield != null \
			and battlefield.v3_grant_sleep(self):
		_v3_fall_asleep()
		return true
	return false


func _v3_fall_asleep() -> void:
	_v3_sleep_left = clampf(definition.sleep_duration, 0.1, SLEEP_MAX_DURATION)
	_v3_sleep_timer = definition.sleep_interval
	# Trois canaux, comme pour la garde de renvoi : des Zzz au-dessus de lui (le
	# QUI), la main grisee dans le HUD (le QUOI), l animation figee (le COMMENT).
	if Fx.enabled() and _v3_zzz == null:
		_v3_zzz = Fx.sleep_marker(self, visual_radius())
	# La POSE de sommeil si la feuille en a une (le renard se roule en boule),
	# sinon l image figee. Le figeage n etait qu un repli : une feuille qui porte
	# une anim `sleep` a ete extraite pour etre jouee ici.
	if _anim != null and _anim.visible:
		if sleep_anim(sheet_key()) != "":
			_anim.play(sleep_anim(sheet_key()))
		else:
			_anim.pause()


func _v3_wake() -> void:
	_v3_sleep_left = 0.0
	if _v3_zzz != null and is_instance_valid(_v3_zzz):
		_v3_zzz.queue_free()
	_v3_zzz = null
	if _anim != null and _anim.visible:
		if _anim.animation == &"sleep":
			_back_to_walk()
		elif not _anim.is_playing():
			_anim.play()


# --- 3. REANIMATEUR ----------------------------------------------------------

func reanimations_done() -> int:
	return _v3_reanimated_count


func is_reanimated() -> bool:
	return _v3_is_reanimated


## Marque un monstre releve par un reanimateur. Teinte verdatre : le joueur doit
## distinguer au premier coup d oeil un revenant d un monstre de la vague, parce
## que la reponse n est pas la meme — le revenant reviendra encore tant que le
## reanimateur vit.
func mark_reanimated() -> void:
	_v3_is_reanimated = true
	modulate = Color(0.72, 1.0, 0.78, modulate.a)


func _v3_tick_reanimate(world_delta: float) -> void:
	if definition == null or battlefield == null or definition.reanimate_max <= 0 \
			or definition.reanimate_radius <= 0.0 or _hidden:
		return
	# LE PLAFOND : une fois ses releves epuises, il n est plus qu un monstre.
	if _v3_reanimated_count >= definition.reanimate_max:
		return
	_v3_reanimate_timer -= world_delta
	if _v3_reanimate_timer > 0.0:
		return
	if battlefield.v3_reanimate_near(self, definition.reanimate_radius):
		_v3_reanimated_count += 1
		_v3_reanimate_timer = maxf(definition.reanimate_interval, REANIMATE_MIN_INTERVAL)
		play_attack()
	else:
		# Personne a relever : il reessaie bientot, sans attendre un intervalle
		# plein. Un reanimateur qui arrive juste apres un massacre doit s en servir.
		_v3_reanimate_timer = 0.25


# --- 4. LASER DE RIPOSTE -----------------------------------------------------

## Le monstre accepte-t-il de riposter MAINTENANT ? Consomme le delai s il tire.
## Appele par Battlefield._hit() apres un coup qui a mordu.
func v3_try_laser() -> bool:
	if _dead or definition == null or definition.laser_damage <= 0:
		return false
	# Il vient de revenir d une vie : le coup qui l a tue n a pas a declencher un
	# tir depuis le haut du terrain, a l autre bout de l ecran.
	if _revive_grace > 0.0 or _v3_laser_cd > 0.0:
		return false
	_v3_laser_cd = maxf(definition.laser_cooldown, LASER_MIN_COOLDOWN)
	return true


# --- Renaissance : generation ------------------------------------------------

func v3_rebirth_depth() -> int:
	return _v3_rebirth_depth


func v3_set_rebirth_depth(depth: int) -> void:
	_v3_rebirth_depth = maxi(depth, 0)


# --- 6. MOTIFS DE DEPLACEMENT ------------------------------------------------

## Marge laterale : le monstre ne doit JAMAIS deborder de l ecran. Elle suit sa
## taille AFFICHEE, pas un nombre fixe — le clamp historique a 40 px laissait la
## moitie d un gros monstre hors cadre.
func _v3_side_margin() -> float:
	var r: float = visual_radius() * (definition.sprite_scale if definition != null else 1.0)
	return clampf(r, 40.0, GameConfig.BATTLEFIELD_WIDTH * 0.5 - 1.0)


## Applique le motif apres la descente. POUR UN MONSTRE AU SOL, seulement en
## descente libre (chemin A* vide) : un mur pose par le joueur doit continuer a
## le detourner, sinon le motif serait un passe-muraille. Et un ecart lateral qui
## entrerait dans une cellule bloquee est refuse (il fait demi-tour a la place).
## Un VOLANT ignore la grille : il applique toujours son motif.
func _v3_apply_move_pattern(speed: float, world_delta: float) -> void:
	if definition == null or definition.move_pattern == EnemyDef.MovePattern.STRAIGHT:
		return
	if speed <= 0.0 or world_delta <= 0.0:
		return
	var au_sol: bool = not definition.flying and nav != null
	if au_sol and not _path.is_empty():
		return
	var marge: float = _v3_side_margin()
	var gauche: float = marge
	var droite: float = GameConfig.BATTLEFIELD_WIDTH - marge
	if _v3_dir == 0:
		# Vers le centre d abord : un monstre ne en bord de terrain qui partirait
		# vers le bord toucherait le mur au premier pas.
		_v3_dir = 1 if position.x < GameConfig.BATTLEFIELD_WIDTH * 0.5 else -1
		# Premier demi-tour a mi-largeur : le zigzag oscille AUTOUR de sa colonne
		# d apparition au lieu de s en ecarter d un seul cote.
		_v3_travel = maxf(definition.pattern_width, 20.0) * 0.5
	var ratio: float = 1.0
	if definition.pattern_lateral_speed > 0.0 and definition.base_speed > 0.0:
		ratio = definition.pattern_lateral_speed / definition.base_speed
	# La vitesse laterale derive de la vitesse de descente DEJA calculee : elle
	# herite du ralentissement, de la rage, du multiplicateur et des vies perdues.
	# Un monstre gele ne doit pas continuer a zigzaguer a pleine vitesse.
	var laterale: float = speed * ratio
	var largeur: float = maxf(definition.pattern_width, 20.0)
	var dx: float = 0.0
	match definition.move_pattern:
		EnemyDef.MovePattern.ZIGZAG:
			dx = laterale * world_delta * _v3_dir
			_v3_travel += absf(dx)
			if _v3_travel >= largeur:
				_v3_travel = 0.0
				_v3_dir = -_v3_dir
		EnemyDef.MovePattern.BOUNCE:
			dx = laterale * world_delta * _v3_dir
		EnemyDef.MovePattern.HOP:
			if not _v3_hopping:
				_v3_hop_timer -= world_delta
				if _v3_hop_timer <= 0.0:
					_v3_hop_timer = maxf(definition.pattern_interval, 0.3)
					var cible: float = position.x + largeur * _v3_dir
					if cible < gauche or cible > droite:
						_v3_dir = -_v3_dir
						cible = position.x + largeur * _v3_dir
					_v3_hop_target = clampf(cible, gauche, droite)
					_v3_hopping = true
			if _v3_hopping:
				var reste: float = _v3_hop_target - position.x
				var pas: float = largeur / HOP_TIME * world_delta
				if absf(reste) <= pas:
					dx = reste
					_v3_hopping = false
					# L atterrissage se voit : sans poussiere, un saut de 240 px en
					# un quart de seconde se lit comme une teleportation.
					if Fx.enabled() and battlefield != null:
						Fx.sprite(battlefield, "dust", position + Vector2(dx, radius() * 0.6),
							radius() * 1.8)
				else:
					dx = signf(reste) * pas
	if dx == 0.0:
		return
	var nx: float = clampf(position.x + dx, gauche, droite)
	if nx != position.x + dx and definition.move_pattern != EnemyDef.MovePattern.HOP:
		# Le bord du terrain : ZIGZAG et BOUNCE repartent dans l autre sens.
		_v3_dir = -_v3_dir
		_v3_travel = 0.0
	if au_sol and nav.blocked_count() > 0 \
			and nav.is_blocked(nav.to_cell(Vector2(nx, position.y))):
		# Un mur a cote : le motif cede, il ne traverse pas. Demi-tour, et un saut
		# en cours est annule plutot que de finir dans la pierre.
		_v3_dir = -_v3_dir
		_v3_travel = 0.0
		_v3_hopping = false
		return
	var applique: float = nx - position.x
	position.x = nx
	# L ondulation historique calcule sa position depuis `_base_x` : on deplace
	# ce centre avec le motif pour que les deux se CUMULENT au lieu que
	# l ondulation ramene le monstre a sa colonne de depart a chaque image.
	_base_x += applique

# =============================================================================
# --- MECANIQUES DE BOSS v3 ---------------------------------------------------
# =============================================================================
#
# Six mecaniques pilotees par le groupe « Mecaniques de boss v3 » d EnemyDef.
# Elles vivent dans ce bloc et ne touchent le reste du fichier que par une ligne
# d accroche chacune (setup, _ready, advance, take_damage, kill) : un autre
# chantier ajoute des mecaniques dans le meme fichier, et un bloc a soi se fusionne
# sans se marcher dessus.

## Temps de monde vecu depuis la fin du fondu. Sert au Devoreur-invocateur, qui
## n avale ses sbires qu une fois « murs ».
var _age: float = 0.0

## HORLOGER : compte a rebours du prochain retour, horloge interne qui date
## l historique, historique [temps, position, pv], nombre de retours faits.
var _rewind_timer: float = 0.0
var _rewind_clock: float = 0.0
var _rewind_history: Array = []
var _rewinds_done: int = 0
## Le fantome qui montre OU il va revenir. Top-level : il vit en coordonnees du
## terrain, mais meurt avec le monstre puisqu il en est l enfant.
var _rewind_ghost: Node2D = null
## Pas d echantillonnage de l historique. Un dixieme de seconde : assez fin pour
## que le fantome glisse, assez grossier pour que 3 s tiennent en 30 entrees.
const REWIND_SAMPLE: float = 0.1
## Fenetre minimale (s) entre la fin d un retour et le debut de la zone effacee
## du suivant. C est LA garantie de fin : sans elle un intervalle egal a la duree
## du retour effacerait chaque degat et le combat ne finirait jamais.
const REWIND_MIN_WINDOW: float = 1.0

## JUMEAUX : a terre ? secondes avant de se relever, retours deja consommes.
var _twin_fallen: bool = false
var _twin_timer: float = 0.0
var _twin_returns: int = 0
## Mort forcee par la chute du dernier jumeau : ne doit plus retomber a terre.
var _twin_no_more: bool = false

## CAMELEON : compte a rebours, position dans le cycle, table courante
## (element -> multiplicateur, meme semantique que EnemyDef.resistances).
var _cham_timer: float = 0.0
var _cham_index: int = 0
var _cham_table: Dictionary = {}

## VOLEUR DE SORTS : compte a rebours du prochain vol, exemplaire tenu, et temps
## restant avant de le lancer sur le mage.
##
## `_stolen_hold` est l id de SON exemplaire dans RunState (0 = mains vides) :
## c est lui, et non la carte, qui designe ce qu il relache ou lance. Deux
## voleurs sur deux copies d une meme carte tiennent la meme ressource ; par la
## carte, l un relachait ou lancait la copie de l autre. `_stolen_card` n est
## qu une copie pour l affichage et les degats (la carte a quitte la main quand
## le coup part).
var _steal_timer: float = 0.0
var _stolen_hold: int = 0
var _stolen_card: SpellCard = null
var _steal_cast_left: float = 0.0

## Legende ecrite au-dessus du boss (element du Cameleon, carte volee, compte a
## rebours du retour ou du releve). Le mot, pas seulement la couleur : un joueur
## daltonien doit pouvoir lire la regle.
var _mech_label: Label = null


func _setup_v3(def: EnemyDef) -> void:
	_age = 0.0
	# Premier retour a l intervalle PLEIN : il faut d abord 3 s d historique pour
	# qu un retour de 3 s ait un sens, et le joueur doit voir le fantome naitre.
	_rewind_timer = _rewind_period(def)
	_rewind_clock = 0.0
	_rewind_history.clear()
	_rewinds_done = 0
	_twin_fallen = false
	_twin_timer = 0.0
	_twin_returns = 0
	_twin_no_more = false
	_cham_index = 0
	_cham_timer = def.chameleon_interval
	_cham_table.clear()
	if def.chameleon_interval > 0.0:
		_cham_apply()
	# Premier vol a l intervalle PLEIN : le joueur doit voir le voleur entrer avant
	# de perdre une carte, sinon la perte se lit comme un bug de la main.
	_steal_timer = def.steal_interval
	_stolen_hold = 0
	_stolen_card = null
	_steal_cast_left = 0.0


func _setup_visual_v3() -> void:
	if definition == null:
		return
	if definition.chameleon_interval > 0.0:
		_cham_retint()
	_refresh_mech_caption()


## Accroche AVANT l etourdissement. Renvoie true si le monstre est A TERRE (jumeau) :
## advance() doit alors s arreter, il ne bouge ni ne frappe.
func _tick_v3_always(world_delta: float) -> bool:
	if definition == null:
		return false
	_age += world_delta
	if _tick_twin(world_delta):
		_refresh_mech_caption()
		return true
	# L horloge et le cycle d element tournent MEME etourdi : figer le cycle d un
	# boss en l etourdissant recompenserait le stun deux fois, et un Horloger
	# etourdi juste avant son retour le rendrait impossible a punir.
	_tick_rewind(world_delta)
	_tick_chameleon(world_delta)
	_refresh_mech_caption()
	return false


## Accroche APRES l etourdissement : un voleur etourdi ne vole pas et ne lance
## rien, un devoreur etourdi n avale rien. C est la reponse de controle a ces deux
## boss, et elle doit exister.
func _tick_v3_active(world_delta: float) -> void:
	if definition == null:
		return
	_tick_thief(world_delta)
	_tick_recall()


## A la mort DEFINITIVE : rend la carte volee, entraine les jumeaux a terre.
func _on_final_death_v3() -> void:
	_release_stolen()
	_drop_ghost()
	_release_fallen_twins()


func _exit_tree() -> void:
	# Un voleur peut quitter le terrain sans mourir (gobe, arrive au mage, fin de
	# partie) : la carte doit revenir quel que soit le chemin, sinon elle reste
	# petrifiee pour une cause qui n existe plus.
	_release_stolen()
	# Meme raison pour la marque du Briseur : elle vit sur l ANCRE, pas sur lui.
	_brk_cancel(false)


func age() -> float:
	return _age


# --- 1. L HORLOGER -----------------------------------------------------------

## Intervalle reel entre deux retours : jamais sous la duree du retour + la
## fenetre minimale. Sans ce plancher, une valeur de contenu malheureuse (retour de
## 3 s toutes les 3 s) effacerait TOUS les degats et le boss serait immortel.
static func _rewind_period(def: EnemyDef) -> float:
	if def == null or def.rewind_interval <= 0.0:
		return 0.0
	return maxf(def.rewind_interval, maxf(def.rewind_seconds, 0.0) + REWIND_MIN_WINDOW)


func rewind_period() -> float:
	return _rewind_period(definition)


func rewinds_done() -> int:
	return _rewinds_done


## Secondes avant le prochain retour (0 s il ne revient plus jamais).
func rewind_time_left() -> float:
	return _rewind_timer if _rewind_active() else 0.0


func _rewind_active() -> bool:
	if definition == null or definition.rewind_interval <= 0.0 or definition.rewind_seconds <= 0.0:
		return false
	return definition.rewind_max <= 0 or _rewinds_done < definition.rewind_max


## Position a laquelle il reviendra si le retour avait lieu MAINTENANT. C est ce
## que le fantome montre : le joueur voit a tout instant ou le boss va reapparaitre.
func rewind_target_position() -> Vector2:
	if _rewind_history.is_empty():
		return position
	return _rewind_history[0][1]


## PV qu il retrouvera si le retour avait lieu maintenant.
func rewind_target_hp() -> float:
	if _rewind_history.is_empty():
		return hp
	return float(_rewind_history[0][2])


func _tick_rewind(world_delta: float) -> void:
	if not _rewind_active():
		_drop_ghost()
		return
	_rewind_clock += world_delta
	if _rewind_history.is_empty() \
			or _rewind_clock - float(_rewind_history.back()[0]) >= REWIND_SAMPLE:
		_rewind_history.append([_rewind_clock, position, hp])
	# On garde en tete l echantillon le plus RECENT qui a au moins
	# `rewind_seconds` : c est lui la destination du retour.
	var borne: float = _rewind_clock - definition.rewind_seconds
	while _rewind_history.size() > 1 and float(_rewind_history[1][0]) <= borne:
		_rewind_history.pop_front()
	_rewind_timer -= world_delta
	_update_ghost()
	if _rewind_timer <= 0.0:
		_rewind_timer = rewind_period()
		_do_rewind()


func _do_rewind() -> void:
	if _rewind_history.is_empty():
		return
	var avant: Vector2 = position
	var cible: Array = _rewind_history[0]
	position = cible[1]
	# Les PV d ALORS, bornes au maximum courant. On ne ressuscite pas : il est
	# vivant, donc ces PV etaient positifs.
	hp = clampf(float(cible[2]), 1.0, _max_hp)
	_rewinds_done += 1
	# L historique repart d ici : sinon le retour suivant pourrait viser un point
	# ANTERIEUR au retour, et deux retours s enchaineraient en un seul saut.
	_rewind_history.clear()
	_rewind_history.append([_rewind_clock, position, hp])
	repath()
	_last_x = position.x
	_refresh_hp_bar()
	if Fx.enabled() and battlefield != null:
		Fx.rewind_flash(battlefield, avant, position, visual_radius())
	AudioBus.play_sfx(&"spell_rise")
	if not _rewind_active():
		_drop_ghost()


func _update_ghost() -> void:
	if not Fx.enabled():
		return
	if _rewind_ghost == null or not is_instance_valid(_rewind_ghost):
		_rewind_ghost = Fx.rewind_ghost(self, _anim if (_anim != null and _anim.visible) else null,
			visual_radius())
	if _rewind_ghost == null:
		return
	_rewind_ghost.global_position = _to_global_battlefield(rewind_target_position())
	# Le fantome S ALLUME a l approche du retour : c est le signal « frappe apres ».
	var periode: float = maxf(rewind_period(), 0.001)
	var proche: float = 1.0 - clampf(_rewind_timer / periode, 0.0, 1.0)
	_rewind_ghost.modulate.a = lerpf(0.35, 0.9, proche)


## Position du monstre (locale au terrain) convertie en coordonnees globales :
## le fantome est top-level, il ne suit pas la transformation de son parent.
func _to_global_battlefield(p: Vector2) -> Vector2:
	var parent: Node2D = get_parent() as Node2D
	return parent.to_global(p) if parent != null else p


func _drop_ghost() -> void:
	if _rewind_ghost != null and is_instance_valid(_rewind_ghost):
		_rewind_ghost.queue_free()
	_rewind_ghost = null


# --- 2. LES JUMEAUX ----------------------------------------------------------

func is_fallen() -> bool:
	return _twin_fallen


func twin_returns() -> int:
	return _twin_returns


## Les autres membres VIVANTS du groupe (debout ou a terre).
func _twin_partners() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if battlefield == null or definition == null or definition.twin_group == &"":
		return out
	for e in battlefield.enemies:
		if e == self or e == null or not is_instance_valid(e) or e.is_dead():
			continue
		if e.definition != null and e.definition.twin_group == definition.twin_group:
			out.append(e)
	return out


## Tombe a terre au lieu de mourir si un jumeau tient encore debout. Renvoie true
## s il est tombe : kill() ne doit alors rien emettre (ni XP ni retrait).
func _try_twin_fall() -> bool:
	if definition == null or definition.twin_group == &"" or _twin_no_more:
		return false
	if _twin_returns >= definition.twin_max_returns:
		return false
	var debout: bool = false
	for p in _twin_partners():
		if not p.is_fallen():
			debout = true
			break
	if not debout:
		return false
	_twin_fallen = true
	_twin_timer = maxf(definition.twin_revive_delay, 0.1)
	hp = 0.0
	_refresh_hp_bar()
	# A TERRE doit se lire : grise et transparent, comme une chose qui n est plus
	# une cible. Le compte a rebours ecrit au-dessus dit combien de temps reste.
	# On teinte le CORPS et pas le noeud entier : verifie sur capture, un
	# `modulate` sur le monstre grisait aussi la legende, et le compte a rebours
	# devenait illisible au moment precis ou le joueur en a besoin.
	_twin_tint(true)
	AudioBus.play_sfx(&"shield_break")
	return true


## Renvoie true tant qu il est a terre.
func _tick_twin(world_delta: float) -> bool:
	if not _twin_fallen:
		return false
	_twin_timer -= world_delta
	if _twin_timer <= 0.0:
		_twin_rise()
	return true


func _twin_rise() -> void:
	_twin_fallen = false
	_twin_returns += 1
	hp = maxf(_max_hp * definition.twin_revive_hp_pct * 0.01, 1.0)
	_refresh_hp_bar()
	_twin_tint(false)
	modulate = Color(1.5, 1.4, 1.1)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.5)
	if Fx.enabled() and battlefield != null:
		Fx.impact(battlefield, position, Color(1.0, 0.95, 0.65), visual_radius() * 1.6)
	AudioBus.play_sfx(&"spell_rise")


## Le dernier debout vient de tomber : les jumeaux a terre meurent AVEC lui.
func _release_fallen_twins() -> void:
	for p in _twin_partners():
		if p.is_fallen():
			p._twin_final_death()


func _twin_final_death() -> void:
	_twin_fallen = false
	_twin_no_more = true
	kill()


## Grise (ou rend sa couleur a) la partie VISIBLE du monstre : feuille animee,
## sprite fixe ou forme dessinee, plus sa barre de vie.
func _twin_tint(a_terre: bool) -> void:
	if not Fx.enabled() or definition == null:
		return
	var gris := Color(0.55, 0.55, 0.65, 0.45)
	if _anim != null and _anim.visible:
		_anim.modulate = gris if a_terre else AnimCatalog.modulate_for(definition.id)
	var fixe: CanvasItem = get_node_or_null("Static") as CanvasItem
	if fixe != null:
		fixe.modulate = gris if a_terre else Color.WHITE
	if _body != null:
		_body.modulate = gris if a_terre else Color.WHITE
	if _hp_bar != null:
		_hp_bar.modulate = gris if a_terre else Color.WHITE
	# Un jumeau Cameleon reprend la teinte de son element en se relevant.
	if not a_terre and definition.chameleon_interval > 0.0:
		_cham_retint()


# --- 3. LE CAMELEON ----------------------------------------------------------

func _cham_cycle() -> Array[int]:
	if definition != null and not definition.chameleon_elements.is_empty():
		return definition.chameleon_elements
	return GameEnums.ELEMENTS


## Element qui le blesse en ce moment (-1 s il n est pas Cameleon).
func chameleon_weak() -> int:
	if definition == null or definition.chameleon_interval <= 0.0:
		return -1
	var c: Array[int] = _cham_cycle()
	return c[_cham_index % c.size()] if not c.is_empty() else -1


## Element auquel il resiste en ce moment : celui d EN FACE dans le cycle, donc
## jamais le meme que le faible tant que le cycle compte deux elements.
func chameleon_resisted() -> int:
	if definition == null or definition.chameleon_interval <= 0.0:
		return -1
	var c: Array[int] = _cham_cycle()
	if c.size() < 2:
		return -1
	return c[(_cham_index + floori(c.size() / 2.0)) % c.size()]


## Multiplicateur de degats du Cameleon pour un sort. MEME regle que
## EnemyDef.resistance_to_tags : un sort multi-element retient le PLUS FAIBLE,
## sinon ajouter un element suffirait a toujours toucher sa faiblesse.
func _chameleon_factor(tags: Array) -> float:
	if _cham_table.is_empty():
		return 1.0
	var m: float = 1.0
	var vu: bool = false
	for t in tags:
		if not (t in GameEnums.ELEMENTS):
			continue
		var r: float = float(_cham_table.get(t, 1.0))
		m = r if not vu else minf(m, r)
		vu = true
	return m


func _tick_chameleon(world_delta: float) -> void:
	if definition.chameleon_interval <= 0.0:
		return
	_cham_timer -= world_delta
	if _cham_timer > 0.0:
		return
	_cham_timer = definition.chameleon_interval
	_cham_index += 1
	_cham_apply()
	_cham_retint()
	AudioBus.play_sfx(&"ward_deep")


func _cham_apply() -> void:
	_cham_table.clear()
	var faible: int = chameleon_weak()
	var resiste: int = chameleon_resisted()
	if faible >= 0:
		_cham_table[faible] = definition.chameleon_weak_mult
	# Plancher a 0,1 : une immunite tournante obligerait le joueur a attendre.
	if resiste >= 0 and resiste != faible:
		_cham_table[resiste] = maxf(definition.chameleon_resist_mult, 0.1)


## LA TEINTE montre l element qui le BLESSE, pas celui qu il resiste : le joueur
## cherche dans sa main la carte de cette couleur. Melange a 55 % avec le blanc,
## parce qu une teinte MULTIPLIE (gotchas) : pure, elle noircirait le sprite.
func _cham_retint() -> void:
	if not Fx.enabled():
		return
	var faible: int = chameleon_weak()
	if faible < 0:
		return
	reset_flash()
	var teinte: Color = Color.WHITE.lerp(Fx.color_for([faible]), 0.55)
	if _anim != null and _anim.visible:
		_anim.modulate = teinte
	elif _body != null:
		_body.modulate = teinte


## LEGENDE EN LOGOS (vague 5) : le logo de l element FAIBLE, grand, suivi de
## « +100 % », puis celui de l element resiste, plus petit, suivi de « -70 % ».
## Les memes logos que sur les cartes : le joueur cherche dans sa main l image
## qu il voit au-dessus du boss, sans passer par un mot. La forme du cadre et le
## signe du pourcentage suffisent a un joueur qui ne lit pas les couleurs.
##
## Reconstruite seulement quand le cycle TOURNE (`_cham_chips_for`) : cette
## fonction est appelee a chaque image par _refresh_mech_caption.
const CHAM_CHIP_WEAK_PX: float = 60.0
const CHAM_CHIP_RESIST_PX: float = 42.0
var _cham_chips: HBoxContainer = null
var _cham_chips_for: int = -2


func _cham_chips_shown() -> bool:
	return _cham_chips != null and is_instance_valid(_cham_chips) and _cham_chips.visible


func _cham_refresh_chips() -> void:
	var faible: int = chameleon_weak()
	if faible < 0 or _twin_fallen or ElementIcons.texture_for_tag(faible) == null:
		if _cham_chips != null and is_instance_valid(_cham_chips):
			_cham_chips.visible = false
		return
	if _cham_chips == null or not is_instance_valid(_cham_chips):
		_cham_chips = HBoxContainer.new()
		_cham_chips.name = "ChameleonChips"
		_cham_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cham_chips.alignment = BoxContainer.ALIGNMENT_CENTER
		_cham_chips.add_theme_constant_override(&"separation", 18)
		_cham_chips.z_index = 6
		add_child(_cham_chips)
		_cham_chips_for = -2
	_cham_chips.visible = true
	if _cham_chips_for == faible:
		return
	_cham_chips_for = faible
	for c in _cham_chips.get_children():
		c.queue_free()
	var faible_chip: HBoxContainer = ElementIcons.resistance_chip(faible,
		float(_cham_table.get(faible, definition.chameleon_weak_mult)),
		CHAM_CHIP_WEAK_PX, Color(0.80, 1.0, 0.75), UiTheme.FONT_SMALL)
	_cham_chips.add_child(faible_chip)
	var resiste: int = chameleon_resisted()
	if resiste >= 0 and resiste != faible:
		_cham_chips.add_child(ElementIcons.resistance_chip(resiste,
			float(_cham_table.get(resiste, definition.chameleon_resist_mult)),
			CHAM_CHIP_RESIST_PX, Color(1.0, 0.80, 0.70), UiTheme.FONT_SMALL))
	# Contour sombre sur les pourcentages : le fond est le terrain, pas du papier.
	for chip in _cham_chips.get_children():
		for l in chip.get_children():
			if l is Label:
				(l as Label).add_theme_color_override(&"font_outline_color", Color(0.06, 0.05, 0.10))
				(l as Label).add_theme_constant_override(&"outline_size", 10)
	# Centre au-dessus du monstre, au pied de la boite de legende (Fx.mech_label).
	var large: float = 420.0
	_cham_chips.size = Vector2(large, CHAM_CHIP_WEAK_PX)
	_cham_chips.position = Vector2(-large * 0.5, -visual_radius() * 0.95 - CHAM_CHIP_WEAK_PX)


## La legende ecrite : element faible en MAJUSCULES, element resiste en clair.
func chameleon_caption() -> String:
	var faible: int = chameleon_weak()
	if faible < 0:
		return ""
	var txt: String = "FAIBLE : %s" % GameEnums.tag_name(faible).to_upper()
	var resiste: int = chameleon_resisted()
	if resiste >= 0:
		txt += "\nresiste : %s" % GameEnums.tag_name(resiste)
	return txt


# --- 4. LE VOLEUR DE SORTS ---------------------------------------------------

func stolen_card() -> SpellCard:
	return _stolen_card


## Id de l exemplaire tenu dans RunState (0 si aucun). Les tests s en servent
## pour demander a la main OU est l exemplaire de CE voleur.
func stolen_hold() -> int:
	return _stolen_hold


func steal_cast_left() -> float:
	return _steal_cast_left if _stolen_card != null else 0.0


## LA REGLE DES DEGATS : secondes d incantation de BASE de la carte, fois le
## tarif du voleur, arrondi, au moins 1. La base et non le temps effectif : le
## voleur ne profite pas de la vitesse du mage, et le joueur lit la base sur sa
## carte.
static func stolen_card_damage(def: EnemyDef, card: SpellCard) -> int:
	if def == null or card == null:
		return 0
	return maxi(1, int(round(card.base_cast_time * def.steal_damage_per_cast_second)))


func _tick_thief(world_delta: float) -> void:
	if definition.steal_interval <= 0.0:
		return
	if _stolen_hold != 0:
		# SON exemplaire a quitte la main par un autre chemin (defausse forcee, fin
		# de vague) : il n a plus rien a lancer, il retourne a la chasse. Demande par
		# id : une copie jumelle tenue par un autre voleur ne le retient pas.
		if not RunState.is_hold_stolen(_stolen_hold):
			_stolen_hold = 0
			_stolen_card = null
			_steal_timer = definition.steal_interval
			return
		_steal_cast_left -= world_delta
		if _steal_cast_left <= 0.0:
			_cast_stolen_card()
		return
	_steal_timer -= world_delta
	if _steal_timer > 0.0:
		return
	_steal_timer = definition.steal_interval
	var prise: int = RunState.steal_hold()
	if prise == 0:
		return
	var c: SpellCard = RunState.stolen_card_of(prise)
	_stolen_hold = prise
	_stolen_card = c
	_steal_cast_left = maxf(definition.steal_cast_delay, 0.1)
	play_attack()
	AudioBus.play_sfx(&"ward_deep")
	if Fx.enabled() and battlefield != null:
		Fx.sprite(battlefield, "diamond_mark", position, visual_radius() * 1.6, false,
			Fx.color_for(c.tags))


func _cast_stolen_card() -> void:
	var card: SpellCard = _stolen_card
	var prise: int = _stolen_hold
	_stolen_hold = 0
	_stolen_card = null
	_steal_timer = definition.steal_interval
	if card == null or not RunState.spend_stolen_hold(prise):
		return
	var degats: int = stolen_card_damage(definition, card)
	play_attack()
	if battlefield != null:
		battlefield.speed_before_hit = SpeedGauge.speed_percent
	# Un sort vole coute de la VITESSE, comme tout coup : la regle vit dans
	# SpeedGauge.take_hit() et n a aucune exception ici.
	SpeedGauge.take_hit(degats)
	if battlefield != null:
		battlefield.mage_hit.emit(degats, definition)
		if Fx.enabled():
			Fx.projectile(battlefield, position,
				Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y),
				Fx.color_for(card.tags), Fx.card_sheet(card))
	AudioBus.play_sfx(&"hp_lost")


func _release_stolen() -> void:
	if _stolen_hold == 0:
		return
	RunState.release_stolen_hold(_stolen_hold)
	_stolen_hold = 0
	_stolen_card = null


# --- 5. LE DEVOREUR-INVOCATEUR -----------------------------------------------

## Peut-il avaler cette proie maintenant ? Ses PROPRES sbires doivent avoir vecu
## `devour_delay` s ; toute autre proie suit la regle historique du Glouton.
func can_devour(prey: Enemy) -> bool:
	if prey == null or definition == null:
		return false
	if _summoned.has(prey):
		return prey.age() >= definition.devour_delay
	return true


## Ce que rapporte une proie. Avec `devour_heal_pct`, un SOIN borne au maximum ;
## sans, la croissance historique du Glouton, inchangee.
func devour(prey: Enemy) -> void:
	if prey == null or definition == null:
		return
	if definition.devour_heal_pct > 0.0:
		heal(maxf(prey.hp, 0.0) * definition.devour_heal_pct * 0.01)
		if Fx.enabled() and battlefield != null:
			Fx.heal_effect(battlefield, position)
		AudioBus.play_sfx(&"heal")
		return
	grow(prey.max_hp() * 0.5, 0.18)


## RAPPEL : un devoreur qui invoque avale ses sbires MURS ou qu ils soient. Sans
## ce rappel, un sbire plus rapide que lui s eloignait hors de portee et la
## combinaison invocation + devoration ne se produisait jamais.
func _tick_recall() -> void:
	if not definition.devours or definition.summon_def == null or battlefield == null:
		return
	for s in _summoned.duplicate():
		if s == null or not is_instance_valid(s) or s.is_dead() or s.is_spawning():
			continue
		if s.age() < definition.devour_delay:
			continue
		var d: Vector2 = s.position
		devour(s)
		s.absorb()
		battlefield.enemies.erase(s)
		_summoned.erase(s)
		if Fx.enabled():
			Fx.swallow_trail(battlefield, d, position)
		s.queue_free()


# --- 6. LE MIROIR DU MAGE ----------------------------------------------------

## Facteur de vitesse du Miroir : vitesse du mage / vitesse de reference, borne.
## 1 pour tout autre monstre.
func mirror_factor() -> float:
	if definition == null or definition.mirror_speed_ref <= 0:
		return 1.0
	var lo: float = minf(definition.mirror_speed_min, definition.mirror_speed_max)
	var hi: float = maxf(definition.mirror_speed_min, definition.mirror_speed_max)
	return clampf(float(SpeedGauge.speed_percent) / float(definition.mirror_speed_ref), lo, hi)


# --- Legende ecrite ------------------------------------------------------------

## Tout ce qu un boss v3 doit DIRE au joueur, en mots. Vide pour un monstre
## ordinaire : aucun noeud n est cree.
func mech_caption() -> String:
	if definition == null:
		return ""
	var lignes: Array[String] = []
	if _twin_fallen:
		lignes.append("A TERRE : releve dans %d s" % ceili(maxf(_twin_timer, 0.0)))
	var cam: String = chameleon_caption()
	# A l ecran, les LOGOS remplacent la phrase du Cameleon (vague 5, voir
	# _cham_refresh_chips) ; la phrase reste le repli sans rendu et la reponse
	# que lisent les tests.
	if cam != "" and not _cham_chips_shown():
		lignes.append(cam)
	if _stolen_card != null:
		lignes.append("VOLE : %s (%d s)" % [_stolen_card.display_name.to_upper(),
			ceili(maxf(_steal_cast_left, 0.0))])
	if _rewind_active() and not _rewind_history.is_empty():
		lignes.append("RETOUR dans %d s" % ceili(maxf(_rewind_timer, 0.0)))
	var brise: String = break_caption()
	if brise != "":
		lignes.append(brise)
	# La legende est calee par le BAS : deux lignes vides laissent la place des
	# logos du Cameleon, poses au pied de la boite, sous le texte.
	if not lignes.is_empty() and _cham_chips_shown():
		lignes.append("")
		lignes.append("")
	return "\n".join(lignes)


func _refresh_mech_caption() -> void:
	if not Fx.enabled():
		return
	_cham_refresh_chips()
	var txt: String = mech_caption()
	if txt == "":
		if _mech_label != null and is_instance_valid(_mech_label):
			_mech_label.visible = false
		return
	if _mech_label == null or not is_instance_valid(_mech_label):
		_mech_label = Fx.mech_label(self, visual_radius())
	if _mech_label == null:
		return
	_mech_label.visible = true
	if _mech_label.text != txt:
		_mech_label.text = txt
	var faible: int = chameleon_weak()
	var teinte: Color = Fx.color_for([faible]).lightened(0.35) if faible >= 0 else Color(0.96, 0.94, 0.86)
	_mech_label.add_theme_color_override(&"font_color", teinte)


# =============================================================================
# POSES DE LA FEUILLE (chantier W3) — sommeil et tir.
#
# Deux feuilles portaient des poses extraites et jamais jouees : le renard
# (`sleep`) restait fige sur une image de marche pendant son sommeil, et le golem
# a noyau (`laser`, `shoot`) jouait son attaque generique en tirant son rayon. La
# regle est GENERIQUE, lue dans le catalogue et non attachee a un id : toute
# feuille future qui porte ces poses les jouera sans une ligne de plus.
# =============================================================================

## Pose de sommeil de la feuille, "" si elle n en a pas (on fige alors l image).
## Statique pour que les tests verifient le choix sans instancier de scene.
static func sleep_anim(key: StringName) -> String:
	return "sleep" if AnimCatalog.has_anim(key, "sleep") else ""


## Pose de TIR de la feuille. Le laser de riposte prefere `laser` (le noyau qui se
## charge), puis `shoot` ; un tir ordinaire prefere `shoot`. A defaut, l attaque
## generique, qui etait jusqu ici la seule pose jouee au tir. "" = rien a jouer.
static func shot_anim(key: StringName, laser: bool) -> String:
	# Pas de ternaire entre deux litteraux : Godot 4.4 le type `Array` et refuse de
	# l affecter a un Array[String] (SCRIPT ERROR a l execution, pas a la compilation).
	var ordre: Array[String] = ["shoot", "attack"]
	if laser:
		ordre.push_front("laser")
	for a in ordre:
		if AnimCatalog.has_anim(key, a):
			return a
	return ""


func play_shot_pose(laser: bool) -> void:
	var pose: String = shot_anim(sheet_key(), laser)
	if pose == "" or _anim == null or not _anim.visible:
		return
	_anim.play(pose)
	if not _anim.animation_finished.is_connected(_back_to_walk):
		_anim.animation_finished.connect(_back_to_walk)


## Ce que le monstre joue quand il ne fait rien de particulier : sa pose de
## sommeil s il dort et que la feuille en a une, sa pose de repos sinon.
func _rest_pose() -> String:
	if is_sleeping() and sleep_anim(sheet_key()) != "":
		return sleep_anim(sheet_key())
	return resting_anim(sheet_key())


# =============================================================================
# LE BRISEUR DE TERRAIN (chantier W3) — pilote par le groupe « Briseur de
# terrain » d EnemyDef. L Enemy decide QUAND (minuterie, geste, annulation) ;
# Battlefield sait QUOI (les ancres du groupe `terrain_props`), comme pour toute
# mecanique qui touche autre chose que le monstre lui-meme.
#
# Chaque fonction est appelee par UNE ligne depuis un point d accroche existant
# (setup, advance, apply_stun, kill, _exit_tree, mech_caption).
# =============================================================================

## Delai avant de chercher a nouveau quand rien n est a portee. Court : un mur
## pose devant lui doit etre vise presque aussitot, pas a l intervalle suivant.
const BREAK_RETRY: float = 0.25
## Plancher de la preparation. En dessous le geste ne se voit plus, et un geste
## qu on ne voit pas transforme la mecanique en disparition inexpliquee.
const BREAK_MIN_WINDUP: float = 0.6
## Plancher de l intervalle, pour la meme raison que celui du laser : un .tres a
## 0,1 viderait le terrain en une seconde.
const BREAK_MIN_INTERVAL: float = 2.0
## Le coup visible part sur la FIN de la preparation : la frappe au sol de la
## feuille doit arriver quand l objet tombe, pas une demi-seconde apres.
const BREAK_SLAM_LEAD: float = 0.5

var _brk_timer: float = 0.0
var _brk_windup_left: float = 0.0
var _brk_target: Node = null
var _brk_marker: Node = null
var _brk_slammed: bool = false
var _brk_count: int = 0


static func _brk_period(def: EnemyDef) -> float:
	return maxf(def.terrain_break_interval, BREAK_MIN_INTERVAL)


func _brk_setup(def: EnemyDef) -> void:
	# Premier coup a l intervalle PLEIN, comme l onde et l invocation : le joueur
	# doit voir le Briseur entrer avant de perdre son decor.
	_brk_timer = _brk_period(def) if def.terrain_break_interval > 0.0 else 0.0
	_brk_clear()
	_brk_count = 0


## Vrai pendant la preparation du coup.
func is_breaking() -> bool:
	return _brk_windup_left > 0.0 and _brk_target != null and is_instance_valid(_brk_target)


## L ancre visee pendant la preparation, null sinon.
func break_target() -> Node:
	return _brk_target if is_breaking() else null


## Objets de terrain brises par CE monstre.
func terrain_broken() -> int:
	return _brk_count


## Renvoie true pendant le geste : il est plante, advance() s arrete la.
func _brk_tick(world_delta: float) -> bool:
	if definition == null or definition.terrain_break_interval <= 0.0 or battlefield == null:
		return false
	if _brk_windup_left > 0.0:
		# La cible est partie pendant le geste (expiree, abattue par la vague) :
		# rien a briser, il se remet en marche et cherche vite autre chose.
		if not battlefield.breaker_can_break(_brk_target):
			_brk_clear()
			_brk_timer = BREAK_RETRY
			return false
		_brk_windup_left -= world_delta
		if not _brk_slammed and _brk_windup_left <= BREAK_SLAM_LEAD:
			_brk_slammed = true
			play_attack()
		if _brk_windup_left > 0.0:
			return true
		var cible: Node = _brk_target
		_brk_clear()
		_brk_timer = _brk_period(definition)
		if battlefield.breaker_strike(self, cible):
			_brk_count += 1
		return false
	_brk_timer -= world_delta
	if _brk_timer > 0.0:
		return false
	var trouve: Node = battlefield.breaker_target(self, definition.terrain_break_reach)
	if trouve == null:
		_brk_timer = BREAK_RETRY
		return false
	_brk_begin(trouve)
	return true


func _brk_begin(cible: Node) -> void:
	_brk_target = cible
	_brk_windup_left = maxf(definition.terrain_break_windup, BREAK_MIN_WINDUP)
	_brk_slammed = false
	# Il se TOURNE vers ce qu il va briser : avec la marque sur l objet et la
	# legende au-dessus de lui, c est le troisieme canal qui relie la cause a
	# l effet.
	if _anim != null and _anim.visible and cible is Node2D:
		_anim.flip_h = (cible as Node2D).position.x < position.x
	_brk_marker = Fx.break_marker(cible as Node2D, _brk_windup_left)
	AudioBus.play_sfx(&"stone_shove")
	_refresh_mech_caption()


func _brk_clear() -> void:
	if _brk_marker != null and is_instance_valid(_brk_marker):
		_brk_marker.queue_free()
	_brk_marker = null
	_brk_target = null
	_brk_windup_left = 0.0
	_brk_slammed = false


## Annule le geste en cours. `recharge` : l etourdissement fait PAYER au Briseur
## un intervalle complet — sinon le stun ne ferait que decaler le coup d une
## fraction de seconde, et la reponse de controle ne vaudrait rien.
func _brk_cancel(recharge: bool) -> void:
	var en_geste: bool = _brk_windup_left > 0.0
	_brk_clear()
	if en_geste and recharge and definition != null and definition.terrain_break_interval > 0.0:
		_brk_timer = _brk_period(definition)


## Legende ecrite pendant le geste : CE qui va tomber, et QUAND.
func break_caption() -> String:
	if not is_breaking():
		return ""
	return "BRISE : %s (%d s)" % [TerrainProp.kind_label(int(_brk_target.get("kind"))).to_upper(),
		ceili(maxf(_brk_windup_left, 0.0))]
