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

## UNE seule place en attente : le sort prepare pendant que le premier se charge.
## Un troisieme appui remplace celui qui attendait — c est ce que fait le joueur
## quand il change d avis, et c est plus lisible qu une file qui s allonge.
var _queued: SpellCard = null
var _queued_ctx: CastContext = null

signal queue_changed(card: SpellCard)


func is_busy() -> bool:
	return current != null


func has_queued() -> bool:
	return _queued != null


func queued_card() -> SpellCard:
	return _queued


## Prepare le sort suivant. Il partira des que le premier sera resolu, avec son
## PROPRE temps d incantation : le pre-cast fait gagner le temps de reaction, pas
## le temps de chargement.
func queue_next(card: SpellCard, ctx: CastContext) -> bool:
	if card == null:
		return false
	if current == null:
		return begin(card, ctx)
	_queued = card
	_queued_ctx = ctx
	queue_changed.emit(_queued)
	return true


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
	# Le sort prepare prend le relais immediatement.
	if _queued != null:
		var suivant: SpellCard = _queued
		var suivant_ctx: CastContext = _queued_ctx
		_queued = null
		_queued_ctx = null
		queue_changed.emit(null)
		begin(suivant, suivant_ctx)


func cancel() -> void:
	current = null
	_pending_ctx = null
	_remaining = 0.0
	_queued = null
	_queued_ctx = null
	queue_changed.emit(null)


func progress() -> float:
	if current == null or _total <= 0.0:
		return 0.0
	return 1.0 - clampf(_remaining / _total, 0.0, 1.0)
