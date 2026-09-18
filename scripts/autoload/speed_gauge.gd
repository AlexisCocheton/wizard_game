extends Node
## MECANIQUE SIGNATURE — vitesse en POURCENTAGE, bouclier et PV du mage.
##
## La vitesse fait trois choses a la fois :
##   1. accelere la descente des monstres ET reduit le temps d'incantation
##   2. multiplie l'XP gagnee a chaque mort
##   3. donne du BOUCLIER, absorbe avant les PV
##
## Echelle : 100 % (normal) a 500 % (maximum), par pas de 10 %. Les quatre paliers
## fixes d'origine (x1/x1.5/x2/x4) ne laissaient aucune nuance : on sautait du
## simple au double, et arrive au maximum un appui de plus repassait a x1 — un
## bug qui punissait le joueur au pire moment.
##
## Regle d'ordre (la plus facile a casser en silence) : un coup entame d'abord le
## BOUCLIER, et seul le reliquat touche les PV. Un coup fait aussi retomber la
## vitesse et interdit d'accelerer pendant quelques secondes : on ne relance pas
## la machine dans la seconde ou l'on vient d'etre touche.
##
## Aucun noeud, aucun rendu : logique pure, pilotable par tick(delta) en headless.
## La mise a l'echelle du temps est MANUELLE (jamais Engine.time_scale) pour rester
## deterministe et testable a froid.

signal multiplier_changed(old_percent: int, new_percent: int)
signal shield_collapsed()
signal hp_changed(hp: int)
signal death_started()
signal died()

## Vitesse courante en pourcentage (100 = normal).
var speed_percent: int = 100
## Valeurs de repli avant le premier reset() ; la verite est GameConfig.MAGE_MAX_HP.
var max_hp: int = GameConfig.MAGE_MAX_HP
var hp: int = GameConfig.MAGE_MAX_HP
var is_dying: bool = false
## Jauge residuelle qui se vide lentement une fois les PV a zero.
var death_gauge: float = 1.0

var _auto_timer: float = 0.0
## Secondes restantes pendant lesquelles accelerer est refuse (apres un coup).
var _accel_lock: float = 0.0


func _ready() -> void:
	reset()


## Multiplicateur applique au monde (1,0 a 5,0).
func multiplier() -> float:
	return float(speed_percent) * 0.01


## Delta a utiliser par tout ce qui subit la vitesse : descente des monstres,
## barre d'incantation, zones au sol, pioche.
func world_delta(delta: float) -> float:
	if is_dying:
		return delta * GameConfig.DEATH_SLOWMO
	return delta * multiplier()


## Un sort de 4 s lance a 400 % se resout en 1 s reelle.
func effective_cast_time(base_cast_time: float) -> float:
	return base_cast_time / maxf(multiplier(), 0.01)


func xp_for(base_xp: int) -> int:
	return int(round(base_xp * multiplier()))


## Bouclier disponible : il vient de la vitesse choisie. Aller vite est un pari
## payant, pas seulement un risque.
func shield() -> int:
	var au_dessus: int = maxi(0, speed_percent - 100)
	return int(round(float(au_dessus) * GameConfig.SHIELD_PER_PERCENT))


## Position de la vitesse sur la barre, de 0 (100 %) a 1 (maximum).
func speed_ratio() -> float:
	var etendue: float = float(GameConfig.SPEED_MAX_PERCENT - 100)
	if etendue <= 0.0:
		return 0.0
	return clampf(float(speed_percent - 100) / etendue, 0.0, 1.0)


## Un appui sur l'accelerateur : +10 %. Au maximum il ne se passe rien — surtout
## PAS de retour a 100 %, qui etait le bug le plus punitif du bouton.
func bump_speed() -> void:
	if accel_locked():
		return
	set_speed_percent(speed_percent + GameConfig.SPEED_STEP_PERCENT)


## Reglage direct : le joueur touche un point de la barre.
func set_speed_from_ratio(ratio: float) -> void:
	if accel_locked():
		return
	var etendue: float = float(GameConfig.SPEED_MAX_PERCENT - 100)
	set_speed_percent(100 + int(round(clampf(ratio, 0.0, 1.0) * etendue)))


func set_speed_percent(percent: int) -> void:
	var clamped: int = clampi(percent, 100, GameConfig.SPEED_MAX_PERCENT)
	if clamped == speed_percent:
		return
	var old: int = speed_percent
	speed_percent = clamped
	multiplier_changed.emit(old, clamped)


func is_at_max() -> bool:
	return speed_percent >= GameConfig.SPEED_MAX_PERCENT


## Vrai tant que le joueur ne peut pas accelerer (fenetre apres un coup).
func accel_locked() -> bool:
	return _accel_lock > 0.0


func accel_lock_left() -> float:
	return _accel_lock


## Un monstre atteint le mage.
## BOUCLIER D'ABORD, PV ENSUITE — voir l'en-tete du fichier.
func take_hit(amount: int = 1) -> void:
	if is_dying:
		return
	# Le coup interdit d'accelerer pendant quelques secondes, quoi qu'il arrive.
	_accel_lock = GameConfig.SPEED_LOCK_AFTER_HIT

	var absorbe: int = mini(shield(), amount)
	var reste: int = amount - absorbe
	if absorbe > 0:
		shield_collapsed.emit()

	# La vitesse retombe : le bouclier consomme, il faut le reconstruire.
	if speed_percent > 100:
		set_speed_percent(maxi(100, speed_percent - GameConfig.SPEED_DROP_ON_HIT))

	if reste <= 0:
		return
	hp = maxi(0, hp - reste)
	hp_changed.emit(hp)
	if hp == 0:
		is_dying = true
		death_gauge = 1.0
		death_started.emit()


## A appeler depuis UN SEUL endroit (GameController.simulate).
## Deux appelants doubleraient silencieusement la montee automatique.
func tick(delta: float) -> void:
	if is_dying:
		death_gauge = maxf(0.0, death_gauge - GameConfig.DEATH_DRAIN_RATE * delta)
		if death_gauge <= 0.0:
			died.emit()
		return
	if _accel_lock > 0.0:
		_accel_lock = maxf(0.0, _accel_lock - delta)
	_auto_timer += delta
	if _auto_timer >= GameConfig.AUTO_RISE_INTERVAL:
		_auto_timer = 0.0
		if not is_at_max() and not accel_locked():
			set_speed_percent(speed_percent + GameConfig.SPEED_STEP_PERCENT)


func reset() -> void:
	speed_percent = 100
	max_hp = GameConfig.MAGE_MAX_HP
	hp = max_hp
	is_dying = false
	death_gauge = 1.0
	_auto_timer = 0.0
	_accel_lock = 0.0
