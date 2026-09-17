class_name Caster
extends Node
## Barre d'incantation du mage : une carte a la fois.
## Le temps de charge subit le multiplicateur de vitesse ET la reduction de cout.

signal cast_started(card: SpellCard, duration: float)
signal cast_progress(ratio: float)
signal cast_finished(card: SpellCard)

var battlefield: Battlefield = null
var current: SpellCard = null
var _remaining: float = 0.0
var _total: float = 0.0
var _pending_ctx: CastContext = null


func is_busy() -> bool:
	return current != null


## Met une carte en incantation. Renvoie false si le mage est deja occupe.
func begin(card: SpellCard, ctx: CastContext) -> bool:
	if current != null or card == null:
		return false
	current = card
	_pending_ctx = ctx
	var haste: float = battlefield.cast_haste if battlefield != null else 1.0
	_total = maxf(0.05, RunState.effective_cast_time(card) / haste)
	_remaining = _total
	cast_started.emit(card, _total)
	return true


## delta BRUT : effective_cast_time a deja applique le multiplicateur.
func tick(delta: float) -> void:
	if current == null:
		return
	_remaining -= delta
	cast_progress.emit(1.0 - clampf(_remaining / _total, 0.0, 1.0))
	if _remaining <= 0.0:
		_resolve()


func _resolve() -> void:
	var card: SpellCard = current
	var ctx: CastContext = _pending_ctx
	current = null
	_pending_ctx = null
	_remaining = 0.0
	if ctx != null:
		EffectRegistry.cast(card, ctx)
	cast_finished.emit(card)


func cancel() -> void:
	current = null
	_pending_ctx = null
	_remaining = 0.0


func progress() -> float:
	if current == null or _total <= 0.0:
		return 0.0
	return 1.0 - clampf(_remaining / _total, 0.0, 1.0)
