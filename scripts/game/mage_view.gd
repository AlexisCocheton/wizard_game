class_name MageView
extends Node2D
## Le personnage du joueur en combat : le mage (le moine bleu de Tiny Swords,
## animation de soin reutilisee comme incantation) ou l un de ses APPRENTIS,
## choisi dans le profil. Cercle de lancement (Free Pixel Effects) sous lui.
##
## Ce fichier ne sait pas QUI il affiche : feuille, taille et pose viennent de
## UiTheme.hero_*(). Un nouvel apprenti ne demande donc aucune ligne ici.

var _anim: AnimatedSprite2D = null
var _charge: Node = null
## La pose d incantation du personnage joue ("cast" pour le mage, "attack" pour
## les sorcieres, qui n ont pas d autre geste de sort).
var _cast_anim: StringName = &"cast"
var _casting: bool = false


func _ready() -> void:
	if not Fx.enabled():
		return
	_anim = AnimatedSprite2D.new()
	# Tout vient du profil : le compte ne donne que du cosmetique.
	_anim.sprite_frames = UiTheme.hero_frames()
	_cast_anim = UiTheme.hero_cast_anim(_anim.sprite_frames)
	# Chaque feuille remplit sa case a sa facon : l echelle et la hauteur sont
	# calculees pour que tout personnage ait la taille du mage, pieds au sol.
	var pose: Dictionary = UiTheme.hero_pose()
	_anim.scale = Vector2.ONE * float(pose["scale"])
	_anim.position = Vector2(0.0, float(pose["y"]))
	# L attaque des sorcieres ne boucle pas (le catalogue la partage avec les
	# monstres, qui frappent une fois) : on la relance tant que l incantation
	# dure, sinon l apprentie se fige sur sa derniere image.
	_anim.animation_finished.connect(_on_anim_finished)
	add_child(_anim)
	_anim.play("idle")


func _on_anim_finished() -> void:
	if _casting and _anim != null and _anim.animation == _cast_anim:
		_anim.play(_cast_anim)


func bind(caster: Caster) -> void:
	if caster == null:
		return
	if not caster.cast_started.is_connected(_on_cast_started):
		caster.cast_started.connect(_on_cast_started)
	if not caster.cast_finished.is_connected(_on_cast_finished):
		caster.cast_finished.connect(_on_cast_finished)


func _on_cast_started(_card: SpellCard, _duration: float) -> void:
	_casting = true
	if _anim != null:
		_anim.play(_cast_anim)
	if _charge == null or not is_instance_valid(_charge):
		_charge = Fx.cast_charge(self, Vector2(0.0, 30.0))
	AudioBus.play_sfx(&"cast_start")


func _on_cast_finished(_card: SpellCard) -> void:
	_casting = false
	if _anim != null:
		_anim.play("idle")
	if _charge != null and is_instance_valid(_charge):
		_charge.queue_free()
	_charge = null
	# Le son generique seulement si la carte n a pas le sien : sinon deux sons
	# se superposent a chaque lancer.
	if _card == null or _card.sfx_key == &"":
		AudioBus.play_sfx(&"cast_done")
