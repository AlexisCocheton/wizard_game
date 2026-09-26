extends Node
## MECANIQUE SIGNATURE — LA VITESSE EST LA VIE.
##
## Le mage n a qu UNE SEULE reserve, et c est sa vitesse. Il n a plus de points
## de vie, plus de bouclier : un coup de N degats lui retire N POINTS DE
## POURCENTAGE de vitesse, et quand la vitesse touche son plancher de 100 %, il
## meurt.
##
## Avant le 26 septembre il en avait deux : 100 PV, et une vitesse de 100 a
## 500 % qui lui donnait du bouclier par-dessus. Un coup entamait le bouclier,
## puis les PV. Cette regle bouclier-puis-PV etait documentee comme la plus
## facile a casser en silence du projet ; elle n existe plus, et la raison de sa
## disparition est qu elle demandait au joueur de suivre DEUX reserves quand une
## seule portait deja tout le sens du jeu.
##
## Ce que la vitesse fait, maintenant, toutes en meme temps :
##   1. accelere la descente des monstres ET reduit le temps d incantation
##   2. multiplie l XP gagnee a chaque mort
##   3. allume les pouvoirs passifs au-dessus de leur seuil
##   4. EST la vie du mage
##
## Consequence voulue et centrale : etre blesse, c est etre LENT. Le joueur
## touche incante plus lentement, gagne moins d XP, perd ses passifs, et voit
## le monde ralentir avec lui. Le jeu ne se contente plus de le punir sur une
## barre a part, il change de rythme sous ses pieds. A l inverse, se soigner
## c est reaccelerer : un soin est aussi une arme.
##
## Le nom reste "vitesse" partout — dans le code, a l ecran, dans les textes.
## Ce n est PAS une barre de vie renommee : c est la vitesse qui devient
## mortelle.
##
## Echelle : 100 % (plancher, la mort) a 500 % (maximum, pleine forme).
##
## La vitesse n est PAS pilotable par le joueur. Elle monte toute seule, de
## GameConfig.SPEED_RISE_PER_SECOND points par seconde, en continu. C est sa
## seule facon de se soigner : tenir sans se faire toucher.
##
## Aucun noeud, aucun rendu : logique pure, pilotable par tick(delta) en headless.
## La mise a l echelle du temps est MANUELLE (jamais Engine.time_scale) pour rester
## deterministe et testable a froid.

signal multiplier_changed(old_percent: int, new_percent: int)
## Le mage vient d encaisser : la vitesse a baisse de `amount` points. Remplace
## l ancien hp_changed, qui annoncait une reserve qui n existe plus. Les
## ecouteurs (son, voix, statistiques) veulent exactement la meme chose : "il a
## pris un coup, et il a coute autant".
signal speed_lost(amount: int, new_percent: int)
## La vitesse vient de remonter d un soin (jamais de la montee naturelle, qui
## est continue et n a rien d un evenement).
signal speed_healed(amount: int, new_percent: int)
signal death_started()
signal died()

## Vitesse courante en pourcentage. 100 = plancher, et le plancher c est la mort.
var speed_percent: int = 100
var is_dying: bool = false
## Jauge residuelle qui se vide lentement une fois le plancher atteint.
var death_gauge: float = 1.0

## Reste FRACTIONNAIRE de la montee naturelle. Le pourcentage affiche est un
## entier, mais le temps ne l'est pas : sans cet accumulateur, une image de
## 1/60 s vaudrait 0 point arrondi et la vitesse ne monterait JAMAIS.
var _rise_accumulator: float = 0.0
## Secondes restantes pendant lesquelles la montee naturelle est retenue
## (apres un coup).
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


## Reserve de vie RESTANTE, en points : la distance au plancher mortel.
## C est le seul nombre qui compte pour la survie, et il remplace l ancien
## couple (PV + bouclier).
func reserve() -> int:
	return maxi(0, speed_percent - 100)


## Reserve TOTALE du mage en pleine forme. L equilibrage cale les degats de
## contact la-dessus : une valeur en dur ailleurs mentirait des que le maximum
## bougerait.
func max_reserve() -> int:
	return maxi(0, GameConfig.SPEED_MAX_PERCENT - 100)


## Position de la vitesse sur la barre, de 0 (100 %, mort) a 1 (maximum).
## C est AUSSI la fraction de vie restante : une seule barre, une seule lecture.
func speed_ratio() -> float:
	var etendue: float = float(max_reserve())
	if etendue <= 0.0:
		return 0.0
	return clampf(float(reserve()) / etendue, 0.0, 1.0)


## Il n y a VOLONTAIREMENT plus de bump_speed() ni de set_speed_from_ratio() :
## la vitesse ne se commande plus. Les laisser en place « au cas ou » aurait
## garde un chemin par lequel un bouton oublie dans une scene aurait pu la
## pousser en silence. test_speed_percent.gd verifie leur absence.
func set_speed_percent(percent: int) -> void:
	var clamped: int = clampi(percent, 100, GameConfig.SPEED_MAX_PERCENT)
	if clamped == speed_percent:
		return
	var old: int = speed_percent
	speed_percent = clamped
	multiplier_changed.emit(old, clamped)


func is_at_max() -> bool:
	return speed_percent >= GameConfig.SPEED_MAX_PERCENT


## Vrai tant que la montee naturelle est retenue (fenetre apres un coup).
## L'interface s'en sert pour expliquer pourquoi le pourcentage stagne.
func accel_locked() -> bool:
	return _accel_lock > 0.0


func accel_lock_left() -> float:
	return _accel_lock


## Un monstre atteint le mage : il perd `amount` POINTS DE VITESSE.
##
## Il n y a plus rien d autre. L ancienne version faisait trois choses — manger
## le bouclier, appliquer un forfait de chute (SPEED_DROP_ON_HIT), puis entamer
## les PV. Les deux premieres n ont plus de sens :
##   - le bouclier derivait du pourcentage au-dessus de 100, c est-a-dire de la
##     reserve elle-meme : il serait devenu "la vie protege la vie" ;
##   - le forfait s ajoutait aux degats, ce qui punirait deux fois le meme coup
##     maintenant que les degats SONT la chute.
## Voir test_speed_is_life.gd, qui verrouille ces deux suppressions.
func take_hit(amount: int = 1) -> void:
	if is_dying:
		return
	if amount <= 0:
		return
	# Le coup retient la montee quelques secondes. C est desormais un delai de
	# SOIN et non plus seulement un frein a la puissance : il est donc court par
	# construction (voir GameConfig.SPEED_LOCK_AFTER_HIT). Sans lui, la vitesse
	# repartirait dans l image suivante et un contact ne se sentirait pas.
	_accel_lock = GameConfig.SPEED_LOCK_AFTER_HIT
	# Le reste fractionnaire accumule avant le coup est perdu avec la vitesse :
	# le garder ferait regagner un point dans l instant qui suit la chute.
	_rise_accumulator = 0.0

	var avant: int = speed_percent
	set_speed_percent(speed_percent - amount)
	var perdu: int = avant - speed_percent
	if perdu > 0:
		speed_lost.emit(perdu, speed_percent)

	# LE PLANCHER EST LA MORT. On ne descend pas sous 100 % : on y meurt.
	if speed_percent <= 100:
		is_dying = true
		death_gauge = 1.0
		death_started.emit()


## Rendre de la vie, c est rendre de la VITESSE. Un soin est donc aussi
## offensif : il raccourcit les incantations, remonte l XP et rallume les
## passifs. C est voulu — sinon un soin ne serait qu une rallonge.
##
## On ne ressuscite PAS : une fois l agonie commencee, la seule issue est la
## defaite. Autoriser un soin ici rendrait la mort revocable, et la tension de
## la fin de partie disparaitrait.
func heal(amount: int) -> void:
	if is_dying or amount <= 0:
		return
	var avant: int = speed_percent
	set_speed_percent(speed_percent + amount)
	var gagne: int = speed_percent - avant
	if gagne > 0:
		speed_healed.emit(gagne, speed_percent)


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
		# Le verrou RETIENT la montee : on ne cumule meme pas le temps ecoule,
		# sinon les secondes de repit se rattraperaient d un bloc a sa levee.
		return
	if is_at_max():
		return
	# Montee CONTINUE : on accumule des points fractionnaires et on ne pousse le
	# pourcentage que lorsqu'un point entier est atteint. Le reste est conserve,
	# donc le rythme ne depend pas de la cadence d'images.
	_rise_accumulator += delta * GameConfig.SPEED_RISE_PER_SECOND
	# EPSILON : additionner 60 fois 1/60 ne redonne pas 1,0 mais
	# 0,9999999999999997. Sans cette tolerance, un point entier sur deux serait
	# AVALE par l arrondi et la vitesse monterait deux fois moins vite que le
	# reglage annonce — un ecart invisible en une seconde, enorme sur une partie.
	const EPSILON: float = 1e-9
	if _rise_accumulator < 1.0 - EPSILON:
		return
	var gagnes: int = int(floor(_rise_accumulator + EPSILON))
	_rise_accumulator -= float(gagnes)
	set_speed_percent(speed_percent + gagnes)


## Le mage commence a SPEED_START_PERCENT et non au plancher : a 100 % il serait
## deja mort. La reserve de depart est son "capital de vie", et le fait qu elle
## soit aussi sa vitesse de depart est tout le sujet.
func reset() -> void:
	speed_percent = clampi(GameConfig.SPEED_START_PERCENT, 100, GameConfig.SPEED_MAX_PERCENT)
	is_dying = false
	death_gauge = 1.0
	_rise_accumulator = 0.0
	_accel_lock = 0.0
