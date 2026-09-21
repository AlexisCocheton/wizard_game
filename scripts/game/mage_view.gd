class_name MageView
extends Node2D
## Le mage : le moine bleu de Tiny Swords. Idle en attente, animation de soin
## reutilisee comme incantation, cercle de lancement (Free Pixel Effects) sous lui.

var _anim: AnimatedSprite2D = null
var _charge: Node = null


func _ready() -> void:
	if not Fx.enabled():
		return
	_anim = AnimatedSprite2D.new()
	# Robe et chapeau viennent du profil : le compte ne donne que du cosmetique.
	_anim.sprite_frames = UiTheme.mage_frames()
	_anim.scale = Vector2(1.35, 1.35)
	_anim.position = Vector2(0.0, -20.0)
	add_child(_anim)
	_anim.play("idle")


func bind(caster: Caster) -> void:
	if caster == null:
		return
	if not caster.cast_started.is_connected(_on_cast_started):
		caster.cast_started.connect(_on_cast_started)
	if not caster.cast_finished.is_connected(_on_cast_finished):
		caster.cast_finished.connect(_on_cast_finished)


func _on_cast_started(_card: SpellCard, _duration: float) -> void:
	if _anim != null:
		_anim.play("cast")
	if _charge == null or not is_instance_valid(_charge):
		_charge = Fx.cast_charge(self, Vector2(0.0, 30.0))
	AudioBus.play_sfx(&"cast_start")


func _on_cast_finished(_card: SpellCard) -> void:
	if _anim != null:
		_anim.play("idle")
	if _charge != null and is_instance_valid(_charge):
		_charge.queue_free()
	_charge = null
	# Le son generique seulement si la carte n a pas le sien : sinon deux sons
	# se superposent a chaque lancer.
	if _card == null or _card.sfx_key == &"":
		AudioBus.play_sfx(&"cast_done")
