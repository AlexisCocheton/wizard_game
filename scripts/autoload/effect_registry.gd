extends Node
## Table cle d'effet -> handler. Enregistrement explicite (pas de scan magique,
## fragile en headless). L'etage AUDIT croise cette table avec les .tres.

signal handler_registered(key: StringName)

var _handlers: Dictionary = {}  # StringName -> EffectHandler


func _ready() -> void:
	register_defaults()


func register_defaults() -> void:
	_handlers.clear()
	for h in [
		EffectHandlers.DamageSingle.new(),
		EffectHandlers.PierceLine.new(),
		EffectHandlers.GroundZone.new(),
		EffectHandlers.SlowEnemyGauge.new(),
		EffectHandlers.SelfHaste.new(),
		EffectHandlers.CostReduction.new(),
		EffectHandlers.DrawBoost.new(),
		EffectHandlers.SummonAlly.new(),
		EffectHandlers.DiscardDraw.new(),
		EffectHandlers.HasteEnemiesBoon.new(),
		EffectHandlers.RemoveCards.new(),
		EffectHandlers.BuildWall.new(),
		EffectHandlers.DamagePerEnemy.new(),
		EffectHandlers.ReverseEnemies.new(),
		EffectHandlers.EmpowerNext.new(),
		EffectHandlers.DiscardHandForSpeed.new(),
		EffectHandlers.Knockback.new(),
		EffectHandlers.VortexPull.new(),
		EffectHandlers.DispelZone.new(),
		EffectHandlers.DrawCards.new(),
		EffectHandlers.RetainNext.new(),
		EffectHandlers.DoubleCast.new(),
		EffectHandlers.MeteorStorm.new(),
	]:
		register(h)


func register(handler: EffectHandler) -> void:
	var key: StringName = handler.get_key()
	if key == &"":
		push_error("Handler sans cle : %s" % handler)
		return
	if _handlers.has(key):
		push_error("Cle d'effet dupliquee : %s" % key)
		return
	_handlers[key] = handler
	handler_registered.emit(key)


func has_key(key: StringName) -> bool:
	return _handlers.has(key)


func keys() -> Array:
	return _handlers.keys()


## Applique un effet. Renvoie false si aucun handler ne repond a la cle.
func dispatch(spec: EffectSpec, ctx: CastContext) -> bool:
	if spec == null:
		return false
	var handler: EffectHandler = _handlers.get(spec.key)
	if handler == null:
		# push_error part sur stderr : la gate du harnais transforme ca en build rouge.
		push_error("Aucun handler pour la cle d'effet '%s'" % spec.key)
		return false
	handler.apply(spec, ctx)
	return true


## Applique toute la pipeline d'effets d'une carte.
func cast(card: SpellCard, ctx: CastContext) -> void:
	if card == null:
		return
	# Un POUVOIR PASSIF ne passe pas par les handlers : il ne "s execute" pas, il
	# change une regle pour tout le combat. RunState en tient le registre.
	if card.is_passive:
		RunState.activate_passive(card)
		return
	ctx.card = card
	# Focalisation : le multiplicateur est consomme par le sort suivant, quel qu il soit.
	ctx.damage_mult = RunState.take_next_spell_multiplier()
	for spec in card.effects:
		dispatch(spec, ctx)
