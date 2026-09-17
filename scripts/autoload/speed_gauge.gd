extends Node
## MECANIQUE SIGNATURE — multiplicateur de vitesse, bouclier et PV du mage.
##
## Le multiplicateur fait trois choses a la fois :
##   1. accelere la descente des monstres ET reduit le temps d'incantation
##   2. multiplie l'XP gagnee a chaque mort
##   3. sert de BOUCLIER DEVANT LES PV
##
## Regle d'ordre (la plus facile a casser en silence) : un coup recu alors que le
## multiplicateur est au-dessus de x1 le fait retomber a x1 et ne coute AUCUN PV.
## Seul un coup recu deja a x1 entame les PV.
##
## Aucun noeud, aucun rendu : logique pure, pilotable par tick(delta) en headless.
## La mise a l'echelle du temps est MANUELLE (jamais Engine.time_scale) pour rester
## deterministe et testable a froid.

signal multiplier_changed(old_index: int, new_index: int)
signal shield_collapsed()
signal hp_changed(hp: int)
signal death_started()
signal died()

var step_index: int = 0
var max_hp: int = 3
var hp: int = 3
var is_dying: bool = false
## Jauge residuelle qui se vide lentement une fois les PV a zero.
var death_gauge: float = 1.0

var _auto_timer: float = 0.0


func _ready() -> void:
	reset()


## Multiplicateur courant (1.0 / 1.5 / 2.0 / 4.0).
func multiplier() -> float:
	return GameConfig.SPEED_STEPS[step_index]


## Delta a utiliser par tout ce qui subit le multiplicateur :
## descente des monstres, barre d'incantation, zones au sol.
## L'UI et les timers de pioche utilisent le delta brut.
func world_delta(delta: float) -> float:
	if is_dying:
		return delta * GameConfig.DEATH_SLOWMO
	return delta * multiplier()


## Un sort de 4 s lance a x4 se resout en 1 s reelle.
func effective_cast_time(base_cast_time: float) -> float:
	return base_cast_time / multiplier()


func xp_for(base_xp: int) -> int:
	return int(round(base_xp * multiplier()))


func cycle() -> void:
	set_step((step_index + 1) % GameConfig.SPEED_STEPS.size())


func set_step(index: int) -> void:
	var clamped: int = clampi(index, 0, GameConfig.SPEED_STEPS.size() - 1)
	if clamped == step_index:
		return
	var old: int = step_index
	step_index = clamped
	multiplier_changed.emit(old, clamped)


func is_at_max() -> bool:
	return step_index == GameConfig.SPEED_STEPS.size() - 1


## Un monstre atteint le mage.
## BOUCLIER D'ABORD, PV ENSUITE — voir l'en-tete du fichier.
func take_hit(amount: int = 1) -> void:
	if is_dying:
		return
	if step_index > 0:
		set_step(0)
		shield_collapsed.emit()
		return  # ce coup ne coute aucun PV
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp)
	if hp == 0:
		is_dying = true
		death_gauge = 1.0
		death_started.emit()


## A appeler depuis UN SEUL endroit (GameController._process).
## Deux appelants doubleraient silencieusement la montee automatique.
func tick(delta: float) -> void:
	if is_dying:
		death_gauge = maxf(0.0, death_gauge - GameConfig.DEATH_DRAIN_RATE * delta)
		if death_gauge <= 0.0:
			died.emit()
		return
	_auto_timer += delta
	if _auto_timer >= GameConfig.AUTO_RISE_INTERVAL:
		_auto_timer = 0.0
		if not is_at_max():
			set_step(step_index + 1)


func reset() -> void:
	step_index = 0
	max_hp = GameConfig.MAGE_MAX_HP
	hp = max_hp
	is_dying = false
	death_gauge = 1.0
	_auto_timer = 0.0
