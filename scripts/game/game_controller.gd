class_name GameController
extends Node2D
## Chef d orchestre d une partie : relie vagues, incantation, HUD et fin de niveau.
##
## IMPORTANT : SpeedGauge.tick() n est appele QUE d ici. Un second appelant
## doublerait silencieusement la montee automatique du multiplicateur.
##
## Modes :
##   Exploration : vagues ecrites du niveau, choix de carte a chaque montee de niveau.
##   Massacre    : vagues infinies par budget, choix de carte toutes les N vagues.

signal level_won()
signal level_lost()
signal cards_offered(cards: Array[SpellCard])

## Massacre : un choix de 3 cartes toutes les N vagues nettoyees.
const WAVES_PER_CHOICE: int = 2

@onready var battlefield: Battlefield = $Battlefield
@onready var caster: Caster = $Caster
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var backdrop: BattleBackdrop = get_node_or_null("Backdrop")
@onready var mage: MageView = get_node_or_null("Mage")

var level_def: LevelDef = null
var mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION
var running: bool = false
## Vrai en test headless : on ne change pas de scene a la fin.
var headless_mode: bool = false


func _ready() -> void:
	var payload: Dictionary = SceneRouter.payload
	var level_id: StringName = payload.get("level_id", &"lvl_01")
	mode = payload.get("mode", GameEnums.Mode.EXPLORATION)
	var def: LevelDef = ContentDB.levels.get(level_id)
	if def == null:
		push_error("Niveau introuvable : %s" % level_id)
		return
	start_level(def, mode)


func start_level(def: LevelDef, level_mode: GameEnums.Mode) -> void:
	level_def = def
	mode = level_mode

	SpeedGauge.reset()
	RunState.reset()
	RunState.current_level_def = def
	RunState.mode = level_mode

	caster.battlefield = battlefield
	battlefield.clear_all()

	RunState.build_deck_from_list(_build_deck())
	RunState.draw(4)

	if mode == GameEnums.Mode.MASSACRE:
		spawner.setup_procedural(battlefield, _procedural_pool(), _boss_pool())
	else:
		spawner.setup(battlefield, def.waves)

	# Branchement idempotent : start_level() peut etre rappele (rejouer, tests).
	_connect_once(spawner.wave_cleared, _on_wave_cleared)
	_connect_once(spawner.all_waves_cleared, _on_all_cleared)
	_connect_once(SpeedGauge.died, _on_died)
	_connect_once(SpeedGauge.shield_collapsed, _on_shield_collapsed)
	_connect_once(battlefield.mage_hit, _on_mage_hit)
	_connect_once(RunState.level_up, _on_level_up)

	var hud: Node = get_node_or_null("HUD")
	if hud != null and hud.has_method("bind"):
		hud.bind(self)
	if backdrop != null:
		backdrop.setup(def.terrain)
	if mage != null:
		mage.bind(caster)
	_connect_once(spawner.wave_started, _on_wave_started)
	_connect_once(SpeedGauge.hp_changed, _on_hp_changed)
	AudioBus.play_music(&"battle")

	spawner.start_next()
	running = true


func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


## Deck de la partie selon le mode.
##   Exploration : la liste pre-etablie du niveau (une entree = un exemplaire).
##   Massacre    : deck de depart SIMPLE — le deck compose par le joueur s il est
##                 valide, sinon les communes. Les cartes fortes arrivent par les choix.
func _build_deck() -> Array[SpellCard]:
	if mode == GameEnums.Mode.MASSACRE:
		var ids: Array = SaveData.massacre_deck()
		if DeckRules.is_valid(ids):
			var chosen: Array[SpellCard] = DeckRules.resolve(ids)
			if chosen.size() >= DeckRules.MIN_CARDS:
				return chosen
	if level_def != null and not level_def.exploration_deck.is_empty():
		return level_def.exploration_deck
	return DeckRules.resolve(DeckRules.default_deck_ids())


## Pool du mode infini : les monstres du niveau, boss exclus.
func _procedural_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var source: Array = level_def.enemy_pool if level_def != null else []
	if source.is_empty():
		source = ContentDB.enemies.values()
	for d in source:
		if d != null and not d.is_boss():
			out.append(d)
	return out


func _boss_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d.is_boss():
			out.append(d)
	return out


func _process(delta: float) -> void:
	if not running:
		return
	simulate(delta)


## Extrait pour que le smoke test puisse piloter la partie avec un delta fixe.
## En pause pendant un choix de carte : rien n avance tant que le joueur n a pas choisi.
func simulate(delta: float) -> void:
	if not RunState.pending_offer.is_empty():
		return
	SpeedGauge.tick(delta)   # UNIQUE appelant
	# La pioche suit le temps du MONDE : a x4, quatre fois plus de monstres
	# arrivent, il faut quatre fois plus de cartes pour y repondre.
	RunState.tick(SpeedGauge.world_delta(delta))
	caster.tick(delta)
	battlefield.simulate(delta)
	spawner.tick(delta)
	if not spawner.active and not spawner.is_finished():
		spawner.start_next()


## Joue une carte a une position visee.
##
## `target_pos` vient du glisser-deposer : c est l endroit ou le joueur a relache
## son doigt. Chaque mode de ciblage l interprete differemment :
##   POSITION  -> centre de la zone / du mur
##   DIRECTION -> definit la direction du tir depuis le mage
##   TARGET    -> le monstre le plus proche du point relache
##   NONE      -> ignore, l effet agit sur le mage
func play_card(card: SpellCard, target_pos: Vector2 = Vector2.INF,
		target_enemy: Object = null) -> bool:
	if not running or caster.is_busy() or card == null:
		return false
	if not RunState.pending_offer.is_empty():
		return false
	# Une carte a viser exige un point : sans lui, on refuse plutot que de
	# lancer le sort a un endroit arbitraire.
	if requires_aim(card) and target_pos == Vector2.INF:
		return false
	if not RunState.play_card(card):
		return false

	var ctx := CastContext.make(battlefield, card)
	ctx.caster = self
	var aim: Vector2 = target_pos if target_pos != Vector2.INF else _default_aim()

	match card.targeting:
		GameEnums.Targeting.POSITION:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy
		GameEnums.Targeting.DIRECTION:
			var origin: Vector2 = _mage_position()
			var d: Vector2 = aim - origin
			ctx.direction = d.normalized() if d.length() > 1.0 else Vector2.UP
			ctx.target_position = aim
			ctx.target_enemy = target_enemy
		GameEnums.Targeting.TARGET:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy if target_enemy != null \
				else battlefield.enemy_nearest_to(aim)
		_:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy

	return caster.begin(card, ctx)


## Vrai si la carte doit etre glissee sur le terrain pour etre jouee.
func requires_aim(card: SpellCard) -> bool:
	return card != null and card.targeting != GameEnums.Targeting.NONE


## Publique : CastContext s en sert comme origine des sorts (voir caster_position).
func mage_position() -> Vector2:
	return Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)


func _mage_position() -> Vector2:
	return mage_position()


func _default_aim() -> Vector2:
	return Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y - 400.0)


# --- Choix de cartes ---

func _offer_cards() -> void:
	var cards: Array[SpellCard] = RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES)
	if cards.is_empty():
		return
	cards_offered.emit(cards)


## Le joueur prend l option i : elle rejoint la defausse et la partie reprend.
func choose_card(i: int) -> SpellCard:
	return RunState.pick_offer(i)


func _on_level_up(_new_level: int) -> void:
	AudioBus.play_sfx(&"level_up")
	if mode == GameEnums.Mode.EXPLORATION:
		_offer_cards()


func _on_wave_started(_index: int, wave: WaveDef) -> void:
	if wave != null and (wave.is_boss or wave.is_miniboss):
		AudioBus.play_sfx(&"boss")
		if wave.is_boss:
			AudioBus.play_music(&"boss")
	else:
		AudioBus.play_sfx(&"wave_start")


func _on_hp_changed(_hp: int) -> void:
	AudioBus.play_sfx(&"hp_lost")


func _on_shield_collapsed() -> void:
	RunState.note_speed_drop()


func _on_mage_hit(_dmg: int, source: EnemyDef) -> void:
	RunState.note_damage_taken(source)


func _on_wave_cleared(index: int) -> void:
	RunState.wave_index = index + 1
	RunState.wave_changed.emit(RunState.wave_index)
	if mode == GameEnums.Mode.MASSACRE and RunState.wave_index % WAVES_PER_CHOICE == 0:
		_offer_cards()


func _on_all_cleared() -> void:
	running = false
	level_won.emit()
	AudioBus.play_music(&"victory", false)
	AudioBus.play_sfx(&"victory")
	if not headless_mode:
		SceneRouter.goto(SceneRouter.VICTORY, {"level_id": level_def.id})


func _on_died() -> void:
	running = false
	level_lost.emit()
	AudioBus.play_music(&"defeat", false)
	AudioBus.play_sfx(&"defeat")
	if not headless_mode:
		SceneRouter.goto(SceneRouter.DEFEAT, {"level_id": level_def.id,
			"waves": RunState.wave_index})
