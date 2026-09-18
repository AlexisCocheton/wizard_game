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

## Seconde place de chargement, ouverte par le passif "Double incantation".
var _second: SpellCard = null
var _second_ctx: CastContext = null
var _second_remaining: float = 0.0
var _second_total: float = 0.0

signal queue_changed(card: SpellCard)


func is_busy() -> bool:
	return current != null


## Nombre de sorts en cours de chargement (1, ou 2 avec le passif de double
## incantation). Lu par les effets qui dependent du nombre de places occupees.
func active_count() -> int:
	var n: int = 0
	if current != null:
		n += 1
	if _second != null:
		n += 1
	return n


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
	# Passif "Double incantation" : une seconde place de chargement, donc le sort
	# prepare part TOUT DE SUITE au lieu d attendre la fin du premier.
	if RunState.cast_slots() > 1 and _second == null:
		# Les deux places servent : le malus du passif s applique a partir d ici.
		RunState.set_casting_count(2)
		_second = card
		_second_ctx = ctx
		var haste: float = battlefield.cast_haste if battlefield != null else 1.0
		_second_total = maxf(0.05, RunState.effective_cast_time(card) / haste)
		_second_remaining = _second_total
		cast_started.emit(card, _second_total)
		return true
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
	# La seconde place avance en parallele, avec son propre chargement.
	if _second != null:
		_second_remaining -= delta
		if _second_remaining <= 0.0:
			var carte: SpellCard = _second
			var ctx2: CastContext = _second_ctx
			_second = null
			_second_ctx = null
			if ctx2 != null:
				EffectRegistry.cast(carte, ctx2)
			# La seconde place se libere : le malus cesse.
			RunState.set_casting_count(1)
			cast_finished.emit(carte)
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
	_second = null
	_second_ctx = null
	_second_remaining = 0.0
	RunState.set_casting_count(1)
	queue_changed.emit(null)


func progress() -> float:
	if current == null or _total <= 0.0:
		return 0.0
	return 1.0 - clampf(_remaining / _total, 0.0, 1.0)
